import SwiftUI
import AppKit
import Observation
import OnboardingCore
import FoveaKit
import FoveaStore
import FoveaPlatform
import FoveaIsland
import FoveaLook

// The first run, on the person's own Mac (docs/onboarding/REAL_MAC.md's flow, as decided Oct 9):
// the stage over the real desktop, the real island at the real notch driven by the person's own
// keys, the real System Settings opened at each list (Fovea dragged into it from the notch, seen
// live), macOS's own microphone and speech prompts, one Quit & Reopen that comes back where it was,
// the two tasks sent to the Claude Code on this Mac, and Home at the end. The other apps hide only
// when asked ("Clear my screen") and exactly those come back.

/// Where the first run picks up after Screen Recording's Quit & Reopen.
struct ResumePoint: Codable {
    var step: String
    var allowed: [String]
    var personal: Personalization
    var language: FoveaLanguage
    var agentsOn: [String]
    var email: String?
    var name: String?
    /// Apple, Google or an email (Oct 15 review, AC-01.1); missing in a point kept before it.
    var account: String?
}

/// What a run is (Oct 15 review, OB-03.1): the first run, picked up where it was; the whole tour
/// again from the start, from Home, with nothing kept about where it was; or one practice again
/// from Home's Getting Started, the rest of the first run left as it is.
package enum RunKind: Equatable, Sendable {
    case tour
    case replay
    case practice(PracticeAgain)
}

@MainActor
package final class OnboardingCoordinator: OnboardingHost {
    let model: OnboardingModel
    let island: IslandController
    /// `--smoke-first-run`: the stage invisible, nothing about the Mac changed (no Dock, no login
    /// item, no apps hidden).
    package var smoke = false
    /// `--design-shots first-run`: a smoke run with the stage on screen, to be pictured.
    package var stageShown = false
    private let prefsStore: PrefsStore
    private let state: OnboardingStateStore
    private let dictionary: DictionaryStore
    private var window: StageWindow?
    /// The stage is on the Space in front (`--design-shots first-run` pictures only then).
    package var stageInFront: Bool { window.map { $0.isOnActiveSpace && $0.occlusionState.contains(.visible) } ?? false }
    private var hosting: PassthroughHostingView<AnyView>?
    private var pointer: Any?
    private var localPointer: Any?
    private var watch: Timer?
    private var lastPane: OnboardingCore.Permission?
    /// The run is over: Home opens.
    private let onDone: () -> Void
    /// "Exit tour" (Oct 10): the run put away part way; Home opens, with a way back. A replay or a
    /// practice run again (Oct 15 review, OB-03.1) calls `onDone` instead, at its end or its exit:
    /// nothing is kept about where it was.
    package var onExit: () -> Void = {}
    /// The tour, a replay of it, or one practice again (Oct 15 review, OB-03.1).
    package let kind: RunKind
    /// The run under way, for the Review menu's stages (`registerReviewStages`).
    package private(set) static weak var current: OnboardingCoordinator?

    /// `kind`: `.tour` picks up where the first run was (as before); `.replay` walks the whole tour
    /// from the start, `.practice(_)` one practice, both from Home and back to it through `onDone`
    /// (Oct 15 review, OB-03.1).
    package init(prefs: PrefsStore, island: IslandController, dictionary: DictionaryStore, state: OnboardingStateStore,
                 kind: RunKind = .tour, onDone: @escaping () -> Void) {
        self.prefsStore = prefs
        self.island = island
        self.state = state
        self.dictionary = dictionary
        self.onDone = onDone
        self.kind = kind
        var options = Options.parse()
        // Where the last run stopped (Screen Recording's Quit & Reopen), unless a step was asked for.
        // A replay or a practice from Home starts where it starts.
        let resume = options.step == nil && kind == .tour
            ? state.state.resume.flatMap { try? JSONDecoder().decode(ResumePoint.self, from: $0) } : nil
        // Oct 18, Ryan: "for every onboarding, the information from the previous onboarding should
        // not be stored". A run from the beginning (a new tour, --reset-onboarding, Replay the Tour)
        // starts blank; a tour picked up where it was keeps what this run entered.
        if kind == .replay || (kind == .tour && options.step == nil && resume == nil) { Self.forgetLastRun(prefs) }
        if let resume, let step = Step(rawValue: resume.step) { options.step = step }
        switch kind {
        case .tour: break
        case .replay: options.step = nil
        case .practice(let practice): options.step = practice.steps.first
        }
        model = OnboardingModel(options: options)
        model.host = self
        if let resume {
            for raw in resume.allowed { if let p = OnboardingCore.Permission(rawValue: raw) { model.flow.allow(p) } }
            model.flow.language = resume.language
            model.flow.email = resume.email
            model.flow.name = resume.name
            model.flow.account = resume.account.flatMap(AccountProvider.init(rawValue:))
        } else {
            model.flow.language = prefs.prefs.language
        }
        // One practice again: only its own steps, Home again past the last (Oct 15 review, OB-03.1).
        if case .practice(let practice) = kind, let first = practice.steps.first {
            var flow = Flow(start: first, only: practice.steps)
            flow.jump(to: first)
            flow.language = prefs.prefs.language
            flow.name = prefs.prefs.accountName.isEmpty ? nil : prefs.prefs.accountName
            model.flow = flow
            model.practiceRun = practice
        }
        // Make it yours starts from the choices as they're kept (Oct 10: a resumed tour showed the
        // hue at 0° while the notch glowed at the 227° Settings had, Ocean coming out green).
        let p = prefs.prefs
        model.flow.personal = Personalization(accent: p.accent, aura: p.glowPalette, auraHue: p.glowHue, auraDrift: p.glowDrift)
        model.openAtLogin = prefs.prefs.openAtLogin
        model.typedEmail = prefs.prefs.accountEmail
        model.typedName = prefs.prefs.accountName
        // The languages asked for under More…, as kept (Oct 17, Ryan, FR-06).
        model.flow.setLanguageRequests(prefs.prefs.requestedLanguages)
        // Oct 18, Ryan: the languages chosen, and the interface in the primary from the start.
        model.languageChoice = LanguageChoice(on: prefs.prefs.languages, primary: model.flow.language)
        FoveaLocale.shared.language = model.flow.language
        model.screenCleared = !state.state.hiddenApps.isEmpty
        model.onFinished = { [weak self] _ in self?.finished() }
    }

    package func start() {
        Self.current = self
        island.director = model
        // The first run shows its choices at the notch itself, for as long as they're picked: the
        // island's own short previews would cut them off.
        island.autoPreview = false
        // An immersive tour: no Dock while Fovea is in front (Oct 9, evening). It's back whenever
        // another app is (System Settings, for the permissions), and when the tour ends.
        if !smoke { NSApp.presentationOptions = [.hideDock] }
        island.setChats([model.practiceChat])
        buildStage()
        // Back from Screen Recording's Quit & Reopen with the screen cleared: the cover again.
        if !state.state.hiddenApps.isEmpty { coverDesktop() }
        model.start()
        if kind == .tour, let resume = state.state.resume.flatMap({ try? JSONDecoder().decode(ResumePoint.self, from: $0) }) {
            model.agentsOn = Set(resume.agentsOn.compactMap(Agent.init(rawValue:)))
        }
        startWatching()
        if ProcessInfo.processInfo.environment["FOVEA_NO_ACTIVATE"] == nil, !smoke { NSApp.activate(ignoringOtherApps: true) }
    }

    // MARK: The stage

    private func buildStage() {
        let screen = Screens.island ?? NSScreen.screens[0]
        let window = StageWindow(frame: screen.frame)
        // Oct 18, Ryan: the stage's words follow the primary language, live.
        let hosting = PassthroughHostingView(rootView: AnyView(RealStage(model: model).foveaLanguage()))
        hosting.frame = NSRect(origin: .zero, size: screen.frame.size)
        hosting.autoresizingMask = [.width, .height]
        hosting.interactive = { [weak self] in
            guard let self else { return [] }
            return RealStage.interactive(self.model) ?? [CGRect(origin: .zero, size: screen.frame.size)]
        }
        window.contentView = hosting
        window.setFrame(screen.frame, display: true)
        if smoke, !stageShown { window.alphaValue = 0 }
        window.makeKeyAndOrderFront(nil)
        self.window = window
        self.hosting = hosting
        // Clicks through to the desktop where nothing of Fovea is: decided as the pointer moves.
        let update: () -> Void = { [weak self] in self?.updateClickThrough() }
        pointer = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { _ in update() }
        localPointer = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { event in update(); return event }
    }

    private func updateClickThrough() {
        guard let window, let screen = window.screen ?? Screens.island else { return }
        let p = Screens.local(appKit: NSEvent.mouseLocation, on: screen)
        let inside: Bool
        if let rects = RealStage.interactive(model) {
            inside = rects.contains { $0.contains(p) }
        } else {
            inside = true
        }
        if window.ignoresMouseEvents == inside { window.ignoresMouseEvents = !inside }
    }

    /// What the run waits on outside Fovea: a grant seen live, System Settings' window for the drag's
    /// arc, a step's list to open.
    private func startWatching() {
        watch = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        updateClickThrough()
        // Oct 27, Ryan: the guide for what the step waits for now, drawn at the notch.
        island.setGuide(model.guideMark)
        guard model.step == .permissions else { lastPane = nil; return }
        if !model.flow.allowed.contains(.accessibility), AXIsProcessTrusted() {
            model.grant(.accessibility)
        }
        if !model.flow.allowed.contains(.screenRecording), model.flow.allowed.contains(.accessibility), ScreenCapturer.allowed {
            model.grant(.screenRecording)
        }
        // Oct 15 review, OB-01.5: Input Monitoring's row as it stands, seen live (never waited on).
        if !model.flow.allowed.contains(.inputMonitoring), FoveaPlatform.Permission.inputMonitoring.granted {
            model.inputMonitoringAllowed()
        }
        // Allowed: Fovea comes back to the front.
        if let pane = model.settingsPane, pane != lastPane { lastPane = pane }
    }

    /// `--shot`: the stage drawn by SwiftUI alone, for when its window can't be on screen (a
    /// full-screen app's Space): no glass, the layout and the words as they are.
    package func renderStage(to url: URL) {
        let screen = Screens.island ?? NSScreen.screens[0]
        // Oct 21, perf: `picture`: ImageRenderer can't draw the loops' own layers (RealStage).
        let view = RealStage(model: model, picture: true)
            .foveaLanguage()
            .frame(width: screen.frame.width, height: screen.frame.height)
            .background(Color(white: 0.2))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }

    // MARK: OnboardingHost


    func endPreview() {
        previewReturn?.cancel()
        island.endPreview()
    }

    /// Make it yours, a moment at the notch, then nothing: the board for a look; for the accent, the
    /// listening bar with its aurora (Oct 28).
    func previewPanel() { preview(.panel) }
    func previewBar() { preview(.aura) }

    private func preview(_ kind: IslandController.Preview) {
        previewReturn?.cancel()
        island.showPreview(kind, seconds: 3600)
        previewReturn = Task { @MainActor in
            try? await Task.sleep(for: .seconds(OT.Motion.lookShown))
            guard !Task.isCancelled, self.model.step == .makeItYours else { return }
            self.island.endPreview()
        }
    }
    private var previewReturn: Task<Void, Never>?
    func listening(_ on: Bool) { island.showListening(on) }
    func listeningLevel(_ level: Double) { island.setListeningLevel(level) }
    func islandRest() { island.rest() }
    func clearIslandSessions() { island.clearSessions() }
    func languageChanged() { island.setChats(model.chatsOffered(for: model.step)) }
    // Oct 23, Ryan: what the first run now teaches with a session.
    func offerChats(_ chats: [IslandChat]) { island.setChats(chats) }
    func sessionTitle(_ id: String) -> String? { island.sessionTitle(id) }
    func askToEdit(_ id: String, file: String, question: String) { island.askToEdit(id, file: file, question: question) }
    func allowEdit(_ id: String) { island.allowEdit(id) }
    func pullOut(_ id: String) { island.pullOut(id) }
    func tuck(_ id: String) { island.tuck(id) }
    func bringBack(_ id: String) { island.bringBack(id) }
    func openChatSearch() { island.openChatSearch() }
    func openPastChat() { island.openPastChat() }
    func openBoard() { island.openBoard() }
    func openIslandSession(_ id: String) { island.openSession(id) }
    func stageRequest(words: String, items: [StagedReferent]) { island.stageRequest(words: words, items: items) }
    func sessionActivity(_ id: String, _ line: String) { island.updateSession(id, activity: line) }
    func sessionAnswered(_ id: String, _ answer: String, files: [String]) { island.finishSession(id, answer: answer, files: files) }

    var prefs: FoveaPrefs {
        get { prefsStore.prefs }
        set { prefsStore.prefs = newValue }
    }

    func openPermission(_ permission: OnboardingCore.Permission) {
        switch permission {
        case .accessibility: FoveaPlatform.Permission.accessibility.openSettings()
        case .screenRecording: FoveaPlatform.Permission.screenRecording.openSettings()
        case .microphone: FoveaPlatform.Permission.microphone.openSettings()
        case .inputMonitoring: FoveaPlatform.Permission.inputMonitoring.openSettings()
        case .automation: break
        }
    }

    func requestPermission(_ permission: OnboardingCore.Permission) {
        switch permission {
        case .accessibility:
            // macOS adds Fovea to the list (switched off) and offers to open it.
            let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
        case .screenRecording:
            _ = ScreenCapturer.request()
        case .inputMonitoring:
            // Oct 15 review, OB-01.5: macOS's own prompt the first time, then the list.
            FoveaPlatform.Permission.requestInputMonitoring()
        default:
            break
        }
        // The list itself, so Fovea's switch is one click away.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.8))
            self.openPermission(permission)
            if AXIsProcessTrusted() {
                try? await Task.sleep(for: .seconds(1))
                SettingsWindow.moveAboveBar()
            }
        }
    }

    func askMicrophoneAndSpeech(_ done: @escaping (Bool) -> Void) {
        Task { @MainActor in
            let mic = await VoiceInput.requestMicrophone()
            if mic { _ = await VoiceInput.requestSpeech() }
            NSApp.activate(ignoringOtherApps: true)
            done(mic)
        }
    }

    func keepResumePoint() {
        // Only the tour keeps its place: a replay or a practice from Home never writes over a tour
        // put away part way (Oct 15 review, OB-03.1).
        guard kind == .tour else { return }
        let point = ResumePoint(step: model.step.rawValue, allowed: model.flow.allowed.map(\.rawValue),
                                personal: model.flow.personal, language: model.flow.language,
                                agentsOn: model.agentsOn.map(\.rawValue), email: model.flow.email, name: model.flow.name,
                                account: model.flow.account?.rawValue)
        let data = try? JSONEncoder().encode(point)
        state.update { $0.resume = data }
    }

    func reopen() {
        keepResumePoint()
        prefsStore.flush()
        Relauncher.relaunch()
    }

    func clearScreen() {
        guard !smoke, state.state.hiddenApps.isEmpty else { return }
        let hidden = AppHider.hideOthers().map { HiddenApp(bundleID: $0.bundleID, pid: $0.pid) }
        // Something to remember even when nothing was showing, so the cover comes back after
        // Screen Recording's Quit & Reopen and goes at the end.
        state.update { $0.hiddenApps = hidden.isEmpty ? [HiddenApp(bundleID: "", pid: 0)] : hidden }
        coverDesktop()
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Tahoe Day over the desktop's icons, only the practice files on it.
    private func coverDesktop() {
        guard let screen = Screens.island else { return }
        DesktopCover.show(on: screen, picture: DesktopCover.tahoeDay())
    }

    /// Asked for Screen Recording and not yet allowed: macOS's own Quit & Reopen may be what quits
    /// Fovea now, and the cleared screen should still be cleared when it's back (Oct 9, late: it
    /// came back with everything showing). Quit from Fovea's menu still brings it all back.
    package var mayReopenForScreenRecording: Bool {
        model.step == .permissions && model.asked.contains(.screenRecording) && !model.flow.allowed.contains(.screenRecording)
    }

    var screenCleared: Bool { !state.state.hiddenApps.isEmpty }

    /// Puts back the apps the run hid (at the end, or when Fovea quits mid-run).
    package func restoreApps() {
        DesktopCover.hide()
        let hidden = state.state.hiddenApps
        guard !hidden.isEmpty else { return }
        AppHider.restore(hidden.filter { $0.pid != 0 }.map { AppHider.Hidden(bundleID: $0.bundleID, pid: $0.pid) })
        state.update { $0.hiddenApps = [] }
    }

    /// Oct 18, Ryan: what a first run entered, forgotten before a new one starts: the name, the
    /// email and how it signed up (signed out until it signs up again), the languages asked for,
    /// the language as the Mac reads, and Make it yours' choices at their defaults (the glass as
    /// the Mac's appearance is), so nothing of the old run shows anywhere.
    static func forgetLastRun(_ store: PrefsStore) {
        let d = FoveaPrefs()
        var p = store.prefs
        p.accountName = d.accountName
        p.accountEmail = d.accountEmail
        p.accountProvider = d.accountProvider
        p.signedOut = true
        p.requestedLanguages = []
        p.languages = []
        p.language = FoveaLanguage.preferred(Locale.preferredLanguages)
        p.accent = d.accent
        p.glowPalette = d.glowPalette
        p.glowHue = d.glowHue
        p.glowSpread = d.glowSpread
        p.glowDrift = d.glowDrift
        p.panels = d.panels
        p.notchAppearance = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
        // Oct 28: the app's window goes with the notch's glass.
        p.windowAppearance = p.notchAppearance == .dark ? .dark : .light
        if p != store.prefs { store.prefs = p }
    }

    /// Another run on the same Mac and stores (the smoke's practice again, OB-03.1).
    func makeRun(_ kind: RunKind, onDone: @escaping () -> Void) -> OnboardingCoordinator {
        let run = OnboardingCoordinator(prefs: prefsStore, island: island, dictionary: dictionary, state: state, kind: kind, onDone: onDone)
        run.smoke = smoke
        run.stageShown = stageShown
        return run
    }

    /// What the smoke reads back after Exit tour.
    var savedResumeStep: Step? {
        state.state.resume.flatMap { try? JSONDecoder().decode(ResumePoint.self, from: $0) }.flatMap { Step(rawValue: $0.step) }
    }
    var tourPaused: Bool { state.state.paused }
    var tourComplete: Bool { state.state.complete }

    /// "Exit tour" (Oct 10), at any step: the place kept (a step that waits on an earlier one's
    /// session goes back to the step that makes it), the apps and the desktop back, the stage away,
    /// the island as on any day; Home opens, and the tour picks up from there when asked.
    func exitTour() {
        // A replay or a practice from Home: back to Home, nothing about the first run kept or
        // changed (Oct 15 review, OB-03.1).
        guard kind == .tour else {
            putAway()
            if case .practice = kind { model.practice.remove() }
            prefsStore.flush()
            onDone()
            return
        }
        let step: Step
        switch model.step {
        case .hover: step = .weeklyUpdate
        case .followUp: step = .packList
        default: step = model.step
        }
        let point = ResumePoint(step: step.rawValue, allowed: model.flow.allowed.map(\.rawValue),
                                personal: model.flow.personal, language: model.flow.language,
                                agentsOn: model.agentsOn.map(\.rawValue), email: model.flow.email, name: model.flow.name,
                                account: model.flow.account?.rawValue)
        let data = try? JSONEncoder().encode(point)
        state.update {
            $0.resume = data
            $0.paused = true
        }
        putAway()
        prefsStore.flush()
        onExit()
    }

    /// The stage and everything the run changed, put away (the end, or Exit tour).
    private func putAway() {
        if Self.current === self { Self.current = nil }
        watch?.invalidate()
        watch = nil
        if let pointer { NSEvent.removeMonitor(pointer) }
        if let localPointer { NSEvent.removeMonitor(localPointer) }
        pointer = nil
        localPointer = nil
        island.director = nil
        island.autoPreview = true
        NSApp.presentationOptions = []
        island.setChats(nil)
        island.endPreview()
        island.clearSessions()
        island.rest()
        restoreApps()
        for site in model.sites.values { site.close() }
        model.sites = [:]
        model.runner.cancel()
        model.sound.stopAmbient()
        window?.orderOut(nil)
        window = nil
    }

    /// "You're all set" → Done: the apps back, the practice gone, the first run done, and Home.
    func finished() {
        putAway()
        model.practice.remove()
        // One practice again from Home: over, and Home; the first run as it was (OB-03.1).
        if case .practice = kind {
            prefsStore.flush()
            onDone()
            return
        }
        // The words brought in, into the dictionary.
        if !model.importedWords.isEmpty {
            dictionary.add(model.importedWords.map { (word: $0.word, heardAs: $0.heardAs) })
        }
        if !smoke { LoginItem.set(prefsStore.prefs.openAtLogin) }
        state.update {
            $0.complete = true
            $0.completedAt = Date()
            $0.resume = nil
            $0.paused = false
        }
        onDone()
    }
}

// MARK: - The Review menu's stages (Oct 15 review)

extension OnboardingCoordinator {
    /// Registers the first run's review stages: each state the Oct 15 review added that can't be
    /// reached simply by using the app, shown on the real first-run stage. `start` starts a run of
    /// that kind (the app delegate owns runs): it's called only when none is under way, or to swap
    /// a practice run for the tour's pages. A run started for a stage is a replay, so nothing kept
    /// about the first run changes.
    package static func registerReviewStages(start: @escaping @MainActor (RunKind) -> Void) {
        /// The tour's stage, at a step, starting a replay if no tour or replay is under way.
        func page(_ step: Step, _ then: @escaping @MainActor (OnboardingModel) -> Void = { _ in }) -> @MainActor () -> Void {
            {
                if let run = current, case .practice = run.kind { run.exitTour() }
                if current == nil { start(.replay) }
                guard let run = current else { return }
                run.model.alert = nil
                run.model.jump(to: step)
                then(run.model)
            }
        }
        /// A practice run again from Home, whatever was under way put away first.
        func practice(_ kind: RunKind) -> @MainActor () -> Void {
            {
                current?.exitTour()
                start(kind)
            }
        }
        let area = Review.Area.firstRun
        Review.stage("OB-01.7", "First run: Back beside the progress line", area: area, run: page(.makeItYours))
        Review.stage("AC-01.1", "First run: sign up with Apple, Google or an email", area: area, run: page(.signIn))
        Review.stage("FR-03", "First run: sign-in, waiting for Apple", area: area,
                     run: page(.signIn) { $0.stageSignIn(.waiting(.apple)) })
        Review.stage("FR-03", "First run: sign-in canceled", area: area,
                     run: page(.signIn) { $0.stageSignIn(.canceled(.google)) })
        Review.stage("FR-04", "First run: couldn't sign in", area: area,
                     run: page(.signIn) { $0.stageSignIn(.failed(.apple)) })
        Review.stage("AC-01.2", "First run: check your email", area: area,
                     run: page(.signIn) { $0.stageSignIn(.checkEmail(OT.Staging.email)) })
        Review.stage("OB-01.5", "First run: Grant Fovea Access, with Input Monitoring", area: area, run: page(.permissions))
        Review.stage("OB-01.6", "First run: what Fovea remembers", area: area, run: page(.memory))
        for each in PracticeAgain.allCases {
            Review.stage("OB-03.1", "Practice again: \(each.title.prefix(1).lowercased() + each.title.dropFirst())", area: area,
                         run: practice(.practice(each)))
        }
        Review.stage("OB-03.1", "Replay the tour from the start", area: area, run: practice(.replay))
    }
}

/// System Settings' window, from the window list (its bounds need no permission), and moved
/// beside the notch once Accessibility allows it.
enum SettingsWindow {
    static let bundleID = "com.apple.systempreferences"

    @MainActor static func frame() -> CGRect? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else { return nil }
        return WindowList.onScreen().first { $0.pid == app.processIdentifier && $0.layer == 0 && $0.bounds.width > 300 }?.bounds
    }

    /// Up toward the menu bar, so the tour's bar at the foot of the screen stays clear of it.
    @MainActor static func moveAboveBar() {
        guard AXIsProcessTrusted(),
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
              let screen = Screens.island else { return }
        let ax = AXUIElementCreateApplication(app.processIdentifier)
        var windows: CFTypeRef?
        guard AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &windows) == .success,
              let first = (windows as? [AXUIElement])?.first else { return }
        var size: CFTypeRef?
        var width: CGFloat = 780
        if AXUIElementCopyAttributeValue(first, kAXSizeAttribute as CFString, &size) == .success, let size {
            var s = CGSize.zero
            AXValueGetValue(size as! AXValue, .cgSize, &s)
            width = s.width
        }
        var point = Screens.global(CGPoint(x: (screen.frame.width - width) / 2, y: 40), on: screen)
        if let value = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(first, kAXPositionAttribute as CFString, value)
        }
    }
}

import SwiftUI
import AppKit
import Observation
import OnboardingCore
import FoveaKit
import FoveaStore
import FoveaPlatform
import FoveaIsland

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
}

@MainActor
package final class OnboardingCoordinator: OnboardingHost {
    let model: OnboardingModel
    let island: IslandController
    /// `--smoke-first-run`: the stage invisible, nothing about the Mac changed (no Dock, no login
    /// item, no apps hidden).
    package var smoke = false
    private let prefsStore: PrefsStore
    private let state: OnboardingStateStore
    private let dictionary: DictionaryStore
    private var window: StageWindow?
    private var hosting: PassthroughHostingView<AnyView>?
    private var pointer: Any?
    private var localPointer: Any?
    private var watch: Timer?
    private var lastPane: OnboardingCore.Permission?
    /// The run is over: Home opens.
    private let onDone: () -> Void
    /// "Exit tour" (Oct 10): the run put away part way; Home opens, with a way back.
    package var onExit: () -> Void = {}

    package init(prefs: PrefsStore, island: IslandController, dictionary: DictionaryStore, state: OnboardingStateStore,
                 onDone: @escaping () -> Void) {
        self.prefsStore = prefs
        self.island = island
        self.state = state
        self.dictionary = dictionary
        self.onDone = onDone
        var options = Options.parse()
        // Where the last run stopped (Screen Recording's Quit & Reopen), unless a step was asked for.
        let resume = options.step == nil ? state.state.resume.flatMap { try? JSONDecoder().decode(ResumePoint.self, from: $0) } : nil
        if let resume, let step = Step(rawValue: resume.step) { options.step = step }
        model = OnboardingModel(options: options)
        model.host = self
        if let resume {
            for raw in resume.allowed { if let p = OnboardingCore.Permission(rawValue: raw) { model.flow.allow(p) } }
            model.flow.personal = resume.personal
            model.flow.language = resume.language
            model.flow.email = resume.email
            model.flow.name = resume.name
        } else {
            model.flow.language = prefs.prefs.language
        }
        model.openAtLogin = prefs.prefs.openAtLogin
        model.typedEmail = prefs.prefs.accountEmail
        model.typedName = prefs.prefs.accountName
        model.screenCleared = !state.state.hiddenApps.isEmpty
        model.onFinished = { [weak self] _ in self?.finished() }
    }

    package func start() {
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
        if let resume = state.state.resume.flatMap({ try? JSONDecoder().decode(ResumePoint.self, from: $0) }) {
            model.agentsOn = Set(resume.agentsOn.compactMap(Agent.init(rawValue:)))
        }
        startWatching()
        if ProcessInfo.processInfo.environment["FOVEA_NO_ACTIVATE"] == nil, !smoke { NSApp.activate(ignoringOtherApps: true) }
    }

    // MARK: The stage

    private func buildStage() {
        let screen = Screens.island ?? NSScreen.screens[0]
        let window = StageWindow(frame: screen.frame)
        let hosting = PassthroughHostingView(rootView: AnyView(RealStage(model: model)))
        hosting.frame = NSRect(origin: .zero, size: screen.frame.size)
        hosting.autoresizingMask = [.width, .height]
        hosting.interactive = { [weak self] in
            guard let self else { return [] }
            return RealStage.interactive(self.model) ?? [CGRect(origin: .zero, size: screen.frame.size)]
        }
        window.contentView = hosting
        window.setFrame(screen.frame, display: true)
        if smoke { window.alphaValue = 0 }
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
        guard model.step == .permissions else { lastPane = nil; return }
        if !model.flow.allowed.contains(.accessibility), AXIsProcessTrusted() {
            model.grant(.accessibility)
        }
        if !model.flow.allowed.contains(.screenRecording), model.flow.allowed.contains(.accessibility), ScreenCapturer.allowed {
            model.grant(.screenRecording)
        }
        // Allowed: Fovea comes back to the front.
        if let pane = model.settingsPane, pane != lastPane { lastPane = pane }
    }

    /// `--shot`: the stage drawn by SwiftUI alone, for when its window can't be on screen (a
    /// full-screen app's Space): no glass, the layout and the words as they are.
    package func renderStage(to url: URL) {
        let screen = Screens.island ?? NSScreen.screens[0]
        let view = RealStage(model: model)
            .frame(width: screen.frame.width, height: screen.frame.height)
            .background(Color(white: 0.2))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }

    // MARK: OnboardingHost


    func previewAura(_ on: Bool) {
        if on { island.showPreview(.aura, seconds: 3600) } else { island.endPreview() }
    }

    /// The board a moment at the notch (Make it yours), then the glow again if a light was being
    /// picked, else nothing.
    func previewPanel() {
        island.showPreview(.panel, seconds: 3)
        previewReturn?.cancel()
        previewReturn = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.2))
            guard !Task.isCancelled else { return }
            if self.model.step == .makeItYours, self.model.island == .auraPreview { self.island.showPreview(.aura, seconds: 3600) }
        }
    }
    private var previewReturn: Task<Void, Never>?
    func listening(_ on: Bool) { island.showListening(on) }
    func listeningLevel(_ level: Double) { island.setListeningLevel(level) }
    func islandRest() { island.rest() }
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
        let point = ResumePoint(step: model.step.rawValue, allowed: model.flow.allowed.map(\.rawValue),
                                personal: model.flow.personal, language: model.flow.language,
                                agentsOn: model.agentsOn.map(\.rawValue), email: model.flow.email, name: model.flow.name)
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
        let step: Step
        switch model.step {
        case .hover: step = .weeklyUpdate
        case .followUp: step = .packList
        default: step = model.step
        }
        let point = ResumePoint(step: step.rawValue, allowed: model.flow.allowed.map(\.rawValue),
                                personal: model.flow.personal, language: model.flow.language,
                                agentsOn: model.agentsOn.map(\.rawValue), email: model.flow.email, name: model.flow.name)
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

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
    private let island: IslandController
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
        island.setChats([model.practiceChat])
        buildStage()
        model.start()
        if let resume = state.state.resume.flatMap({ try? JSONDecoder().decode(ResumePoint.self, from: $0) }) {
            model.agentsOn = Set(resume.agentsOn.compactMap(Agent.init(rawValue:)))
        }
        startWatching()
        if ProcessInfo.processInfo.environment["FOVEA_NO_ACTIVATE"] == nil { NSApp.activate(ignoringOtherApps: true) }
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
        // The second list, once the first is done: opened by its link, beside the notch.
        if let pane = model.settingsPane, pane != lastPane {
            lastPane = pane
            if pane == .screenRecording {
                keepResumePoint()
                openPermission(pane)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1))
                    SettingsWindow.moveBesideNotch()
                }
            }
        }
        // Where System Settings' list is, for the arc from the notch.
        if let frame = SettingsWindow.frame(), let screen = window?.screen {
            let local = Screens.local(frame, on: screen)
            model.settingsListFrame = CGRect(x: local.minX + local.width * 0.32, y: local.minY + 90,
                                             width: local.width * 0.64, height: max(120, local.height - 150))
        } else {
            model.settingsListFrame = .zero
        }
    }

    // MARK: OnboardingHost

    func caption(_ text: String?, draggable: Bool) { island.setCaption(text, draggable: draggable) }

    func previewAura(_ on: Bool) {
        if on { island.showPreview(.aura, seconds: 3600) } else { island.endPreview() }
    }

    func previewPanel() { island.showPreview(.panel, seconds: 3) }
    func listening(_ on: Bool) { island.showListening(on) }
    func listeningLevel(_ level: Double) { island.setListeningLevel(level) }
    func islandRest() { island.rest() }
    func openBoard() { island.openBoard() }
    func openIslandSession(_ id: String) { island.openSession(id) }
    func stageRequest(words: String, items: [StagedReferent]) { island.stageRequest(words: words, items: items) }
    func sessionActivity(_ id: String, _ line: String) { island.updateSession(id, activity: line) }
    func sessionAnswered(_ id: String, _ answer: String) { island.finishSession(id, answer: answer) }

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
        guard state.state.hiddenApps.isEmpty else { return }
        let hidden = AppHider.hideOthers().map { HiddenApp(bundleID: $0.bundleID, pid: $0.pid) }
        state.update { $0.hiddenApps = hidden }
        NSApp.activate(ignoringOtherApps: true)
    }

    var screenCleared: Bool { !state.state.hiddenApps.isEmpty }

    /// Puts back the apps the run hid (at the end, or when Fovea quits mid-run).
    package func restoreApps() {
        let hidden = state.state.hiddenApps
        guard !hidden.isEmpty else { return }
        AppHider.restore(hidden.map { AppHider.Hidden(bundleID: $0.bundleID, pid: $0.pid) })
        state.update { $0.hiddenApps = [] }
    }

    /// "You're set" → Done: the apps back, the practice gone, the first run done, and Home.
    func finished() {
        watch?.invalidate()
        watch = nil
        if let pointer { NSEvent.removeMonitor(pointer) }
        if let localPointer { NSEvent.removeMonitor(localPointer) }
        pointer = nil
        localPointer = nil
        island.director = nil
        island.setChats(nil)
        island.setCaption(nil)
        island.endPreview()
        island.clearSessions()
        restoreApps()
        model.practice.remove()
        for site in model.sites.values { site.close() }
        model.sites = [:]
        model.runner.cancel()
        model.sound.stopAmbient()
        // The words brought in, into the dictionary.
        if !model.importedWords.isEmpty {
            dictionary.add(model.importedWords.map { (word: $0.word, heardAs: $0.heardAs) })
        }
        LoginItem.set(prefsStore.prefs.openAtLogin)
        state.update {
            $0.complete = true
            $0.completedAt = Date()
            $0.resume = nil
        }
        window?.orderOut(nil)
        window = nil
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

    /// Under the notch, a little to the right, so the drag from the notch is short.
    @MainActor static func moveBesideNotch() {
        guard AXIsProcessTrusted(),
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first,
              let screen = Screens.island else { return }
        let ax = AXUIElementCreateApplication(app.processIdentifier)
        var windows: CFTypeRef?
        guard AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &windows) == .success,
              let first = (windows as? [AXUIElement])?.first else { return }
        var point = Screens.global(CGPoint(x: screen.frame.width / 2 - 60, y: 70), on: screen)
        if let value = AXValueCreate(.cgPoint, &point) {
            AXUIElementSetAttributeValue(first, kAXPositionAttribute as CFString, value)
        }
    }
}

import AppKit
import Observation
import FoveaKit
import FoveaStore
import FoveaWindow
import FoveaIsland
import FoveaOnboarding
import OnboardingCore
import FoveaPlatform
import FoveaCore

/// Fovea's dev flags. The app itself needs none.
///   --reset-onboarding     the first run again
///   --reset-all            also every capture, picture, word and setting
///   --skip-onboarding      straight to Home, the first run marked done
///   --home                 open Home at launch (it opens anyway unless Fovea started at login)
///   --data-dir=<path>      keep everything there instead of Application Support
///   --settings <pane[:id]> open Settings on a pane
///   --demo <state>         stage a notch state (IslandController.stage), no microphone
///   --smoke                the notch walked through its states, checked, then quit (LiveSmoke):
///                          its window invisible, no keys or pointer watched, its own data folder
///   --smoke-first-run      the first run's teaching walked and checked the same way (OnboardingSmoke),
///                          the practice agent answering
///   --shot <file.png>      a picture of Fovea's own windows a moment after launch, then quit
///                          (`--shot-after=<seconds>`, 2.5 by default): to look at a state without
///                          Screen Recording, since an app may always take its own windows
struct AppOptions {
    var resetOnboarding = false
    var resetAll = false
    var skipOnboarding = false
    var openHome = false
    var noActivate = ProcessInfo.processInfo.environment["FOVEA_NO_ACTIVATE"] == "1"

    static func parse(_ args: [String] = CommandLine.arguments) -> AppOptions {
        var o = AppOptions()
        o.resetAll = args.contains("--reset-all")
        o.resetOnboarding = o.resetAll || args.contains("--reset-onboarding")
        o.skipOnboarding = args.contains("--skip-onboarding")
        o.openHome = args.contains("--home") || args.contains("--settings")
        return o
    }

    /// Run as the built app bundle (not `swift run`).
    static var bundled: Bool { Bundle.main.bundleIdentifier != nil }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    let options = AppOptions.parse()
    let location = DataLocation.resolve()
    private(set) var prefs: PrefsStore!
    private(set) var captures: CaptureLibrary!
    private(set) var dictionary: DictionaryStore!
    private(set) var onboarding: OnboardingStateStore!
    private(set) var home: HomeWindowController!
    private(set) var island: IslandController!
    private var firstRun: OnboardingCoordinator?
    /// The menu bar's icon (Oct 15 review, NH-01/02) and the review's own menu.
    private var statusItem: StatusItem?
    private let reviewMenu = ReviewMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Every lookup of Fovea's words answers in the primary language (Oct 18).
        FoveaLanguageBundle.install()
        if options.resetAll { location.eraseAll() } else { location.prepare() }

        // The first run's glass follows the Mac's own appearance until the person picks.
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        var initial = FoveaPrefs()
        initial.notchAppearance = dark ? .dark : .light
        initial.language = FoveaLanguage.preferred(Locale.preferredLanguages)
        prefs = PrefsStore(location: location, initial: initial)
        FoveaLocale.shared.language = prefs.prefs.language
        captures = CaptureLibrary(location: location)
        dictionary = DictionaryStore(location: location)
        onboarding = OnboardingStateStore(location: location)
        if options.resetOnboarding { onboarding.reset() }
        if options.skipOnboarding { onboarding.update { $0.complete = true; $0.completedAt = Date() } }

        // No app bundle from SwiftPM, so the Dock icon is set at runtime there; the bundle's
        // own icon (Assets.car, the layered icon) shows otherwise.
        if !AppOptions.bundled, let url = FoveaFiles.url("AppIcon.png"), let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }

        if let i = CommandLine.arguments.firstIndex(of: "--design-shots"), i + 2 < CommandLine.arguments.count {
            designShots(CommandLine.arguments[i + 1], to: URL(fileURLWithPath: (CommandLine.arguments[i + 2] as NSString).expandingTildeInPath))
            return
        }

        // The notch lives for the whole process, whatever the window does.
        island = IslandController(prefs: prefs, captures: captures, dictionary: dictionary)
        if CommandLine.arguments.contains("--smoke-first-run") {
            island.start(smoke: true, visible: true)
            onboarding.reset()
            let run = OnboardingCoordinator(prefs: prefs, island: island, dictionary: dictionary, state: onboarding) {}
            run.smoke = true
            run.stageShown = true
            firstRun = run
            run.start()
            Task { @MainActor in
                let passed = await OnboardingSmoke.run(run)
                exit(passed ? 0 : 1)
            }
            return
        }
        if CommandLine.arguments.contains("--smoke") {
            island.start(smoke: true)
            Task { @MainActor in
                let passed = await LiveSmoke.run(self.island)
                exit(passed ? 0 : 1)
            }
            return
        }
        island.start()
        if let i = CommandLine.arguments.firstIndex(of: "--demo"), i + 1 < CommandLine.arguments.count {
            let state = CommandLine.arguments[i + 1]
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.8))
                self.island.stage(state)
            }
        }

        if let i = CommandLine.arguments.firstIndex(of: "--shot"), i + 1 < CommandLine.arguments.count {
            let url = URL(fileURLWithPath: (CommandLine.arguments[i + 1] as NSString).expandingTildeInPath)
            let after = CommandLine.arguments.first { $0.hasPrefix("--shot-after=") }
                .flatMap { Double($0.dropFirst("--shot-after=".count)) } ?? 2.5
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(after))
                OwnWindowsShot.write(to: url)
                self.firstRun?.renderStage(to: url.deletingPathExtension().appendingPathExtension("stage.png"))
                NSApp.terminate(nil)
            }
        }

        home = HomeWindowController(stores: WindowStores(prefs: prefs, captures: captures, dictionary: dictionary))
        NSApp.mainMenu = home.mainMenu(quit: #selector(quit(_:)), quitTarget: self)
        addResumeTourItem()
        home.onResumeTour = { [weak self] in self?.resumeTour(nil) }
        installReview()
        observeLanguage()

        // The first run, until it's done (and resumed where it was after Screen Recording's Quit &
        // Reopen); then Home, unless Fovea opened at login. Put away with Exit tour, it waits for
        // the person: Home, with a way back to it (Oct 10).
        if !onboarding.state.complete && !onboarding.state.paused && !options.openHome {
            startTour()
        } else {
            home.tourUnfinished = !onboarding.state.complete
            if !options.noActivate { NSApp.activate(ignoringOtherApps: true) }
            if !LoginItem.launchedAtLogin || options.openHome { home.show() }
            observeLoginItem()
        }
    }

    // MARK: Oct 15 review (docs/v1/REVIEW_2026-10-15.md)

    /// The menu bar's icon, Show in Dock, the review's menu and stages, and the offer to move to
    /// Applications.
    private func installReview() {
        let status = StatusItem(prefs: prefs)
        status.openHome = { [weak self] in
            guard let self, self.firstRun == nil else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.home.show()
        }
        status.openSettings = { [weak self] section in
            guard let self else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.home.openSettings(section ?? "account")
        }
        status.checkForUpdates = { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.home.checkForUpdates()
        }
        status.quit = { [weak self] in self?.quit(nil) }
        statusItem = status
        // The notch's notices whose fix is in Settings (NH-04): Choose Microphone…, Sign In.
        island.onOpenSettings = { [weak self] page in
            NSApp.activate(ignoringOtherApps: true)
            self?.home.openSettings(page)
        }
        // Home's Open in Notch (HI-01.3, QA25) and Send Again (a Dispatch that wasn't sent: the
        // session opens in the notch to go again; simulated sending in 1.0).
        home.onOpenInNotch = { [weak self] id in self?.reopenInNotch(id) }
        home.onSendAgain = { [weak self] id in
            self?.captures.update(id) { $0.sendFailure = nil }
            self?.reopenInNotch(id)
        }
        // The notch's "Remembered" (NH-03) opens that memory in Settings › Memory.
        island.onOpenMemory = { [weak self] id in
            NSApp.activate(ignoringOtherApps: true)
            self?.home.openMemory(id)
        }
        observeMemoryNotice()
        Review.stage("Reset", "Notch: back to rest", area: .notch) { [weak self] in self?.island.backToRest() }
        island.observeActivity { [weak status] in status?.show($0) }
        observeDock()
        if let main = NSApp.mainMenu { reviewMenu.install(in: main) }
        OnboardingCoordinator.registerReviewStages { [weak self] kind in self?.startRun(kind) }
        // Settings › Getting Started (OB-03.1): the tour again, or one practice again.
        home.onReplayTour = { [weak self] in self?.startRun(.replay) }
        home.onPractice = { [weak self] step in
            let practice: PracticeAgain? = step == "packList" ? .packingList : PracticeAgain(rawValue: step)
            if let practice { self?.startRun(.practice(practice)) }
        }
        Review.stage("NH-06", "Move to Applications (nothing is moved)", area: .menuBar) {
            MoveToApplications.ask(from: Bundle.main.bundleURL, simulated: true)
        }
        if !options.noActivate { MoveToApplications.offerIfNeeded() }
    }

    private func reopenInNotch(_ id: String) {
        guard let capture = captures.captures.first(where: { $0.id == id }) else { return }
        island.reopen(captureID: id, title: capture.text, agent: capture.destination?.agent ?? "claude-code")
    }

    /// "Tell me when a memory updates" reaches the notch, never during the first run.
    private func observeMemoryNotice() {
        island.tellsMemoryUpdates = prefs.prefs.memoryNotice && firstRun == nil
        withObservationTracking { _ = prefs.prefs.memoryNotice } onChange: { [weak self] in
            Task { @MainActor in self?.observeMemoryNotice() }
        }
    }

    /// A run of the first run from Home (OB-03.1): the whole tour again, or one practice again
    /// (Getting Started), the rest of the first run left as it was; Home again at the end.
    func startRun(_ kind: RunKind) {
        guard firstRun == nil else { return }
        if kind == .tour { startTour(); return }
        home.window.orderOut(nil)
        let run = OnboardingCoordinator(prefs: prefs, island: island, dictionary: dictionary, state: onboarding, kind: kind) { [weak self] in
            guard let self else { return }
            self.firstRun = nil
            self.home.tourUnfinished = !self.onboarding.state.complete
            self.home.show()
            NSApp.activate(ignoringOtherApps: true)
        }
        firstRun = run
        run.start()
    }

    /// The primary language (Oct 18, Ryan): Fovea's words follow it everywhere, the moment it
    /// changes (FoveaKit/Localization.swift); the menus, which AppKit doesn't redraw, are built
    /// again in it.
    private func observeLanguage() {
        let language = prefs.prefs.language
        if FoveaLocale.shared.language != language {
            FoveaLocale.shared.language = language
            rebuildMenus()
        }
        withObservationTracking { _ = prefs.prefs.language } onChange: { [weak self] in
            Task { @MainActor in self?.observeLanguage() }
        }
    }

    private func rebuildMenus() {
        guard home != nil else { return }
        NSApp.mainMenu = home.mainMenu(quit: #selector(quit(_:)), quitTarget: self)
        addResumeTourItem()
        if let main = NSApp.mainMenu { reviewMenu.reinstall(in: main) }
    }

    /// Account › Show in Dock (ST-02.5): off, Fovea leaves the Dock and the app switcher and lives
    /// in the menu bar; the window keeps working.
    private func observeDock() {
        let show = prefs.prefs.showInDock
        let policy: NSApplication.ActivationPolicy = show ? .regular : .accessory
        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
            if !show, home.window.isVisible { NSApp.activate(ignoringOtherApps: true) }
        }
        withObservationTracking { _ = prefs.prefs.showInDock } onChange: { [weak self] in
            Task { @MainActor in self?.observeDock() }
        }
    }

    /// `--design-shots notch|first-run|window <dir>`: pictures of 1.0's designs on this Mac, then
    /// quit. The notch's every state staged on the real island (`--only`); the first run walked
    /// with the practice agent; both pictured from the real screen (Screen Recording) over a clean
    /// desktop. Home and Settings from what that run left in the same `--data-dir`.
    private func designShots(_ part: String, to dir: URL) {
        let args = CommandLine.arguments
        switch part {
        case "notch":
            let only = args.firstIndex(of: "--only").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
            island = IslandController(prefs: prefs, captures: captures, dictionary: dictionary)
            island.start(smoke: true, visible: true)
            Task { @MainActor in
                await IslandDesignShots.run(self.island, prefs: self.prefs, to: dir, only: only)
                NSApp.terminate(nil)
            }
        case "first-run":
            island = IslandController(prefs: prefs, captures: captures, dictionary: dictionary)
            island.start(smoke: true, visible: true)
            onboarding.reset()
            let run = OnboardingCoordinator(prefs: prefs, island: island, dictionary: dictionary, state: onboarding) {}
            run.smoke = true
            run.stageShown = true
            firstRun = run
            run.start()
            Task { @MainActor in
                await OnboardingShots.run(run, to: dir)
                NSApp.terminate(nil)
            }
        default:
            home = HomeWindowController(stores: WindowStores(prefs: prefs, captures: captures, dictionary: dictionary))
            Task { @MainActor in
                await self.home.designShots(to: dir)
                NSApp.terminate(nil)
            }
        }
    }

    /// The first run, from the start or from where it was left.
    private func startTour() {
        let run = OnboardingCoordinator(prefs: prefs, island: island, dictionary: dictionary, state: onboarding) { [weak self] in
            guard let self else { return }
            self.firstRun = nil
            self.home.tourUnfinished = false
            self.home.show()
            self.observeLoginItem()
        }
        run.onExit = { [weak self] in
            guard let self else { return }
            self.firstRun = nil
            self.home.tourUnfinished = true
            self.home.show()
            NSApp.activate(ignoringOtherApps: true)
        }
        firstRun = run
        run.start()
    }

    /// Home's "Finish the tour", and Fovea › Resume the Tour: the first run picks up where it was.
    @objc func resumeTour(_ sender: Any?) {
        guard firstRun == nil, !onboarding.state.complete else { return }
        onboarding.update { $0.paused = false }
        home.tourUnfinished = false
        home.window.orderOut(nil)
        startTour()
    }

    /// Fovea › Resume the Tour, under About, while the tour is put away.
    private func addResumeTourItem() {
        guard let menu = NSApp.mainMenu?.items.first?.submenu else { return }
        let item = NSMenuItem(title: L("Resume the Tour"), action: #selector(resumeTour(_:)), keyEquivalent: "")
        item.target = self
        menu.insertItem(item, at: 1)
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(resumeTour(_:)) {
            item.isHidden = onboarding.state.complete
            return firstRun == nil && !onboarding.state.complete
        }
        return true
    }

    /// "Open at login" in Settings › Account: registered with macOS as it changes.
    private func observeLoginItem() {
        withObservationTracking { _ = prefs.prefs.openAtLogin } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                LoginItem.set(self.prefs.prefs.openAtLogin)
                self.observeLoginItem()
            }
        }
    }

    /// Closing the window never quits: the notch stays.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// The Dock icon: Home comes back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, firstRun == nil { home.show() }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // However Fovea quits (the Dock, the menu), the apps a first run hid come back; not when
        // it's only reopening for Screen Recording.
        if !Relauncher.relaunching, firstRun?.mayReopenForScreenRecording != true { firstRun?.restoreApps() }
        prefs.flush()
        captures.flush()
        dictionary.flush()
    }

    /// Quit from the menu: a first run under way puts back the apps it hid.
    @objc func quit(_ sender: Any?) {
        firstRun?.restoreApps()
        NSApp.terminate(sender)
    }
}

/// `--shot`: Fovea's own windows on the island's screen, as the window server composites them, in
/// their order (an app may always take its own windows, with no Screen Recording).
enum OwnWindowsShot {
    @MainActor static func write(to url: URL) {
        guard let screen = Screens.island else { return }
        let pid = ProcessInfo.processInfo.processIdentifier
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let ids = info.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == pid }
            .compactMap { $0[kCGWindowNumber as String] as? CGWindowID }
        guard !ids.isEmpty else { print("shot: no windows"); return }
        var pointers = ids.map { UnsafeRawPointer(bitPattern: UInt($0)) }
        guard let array = CFArrayCreate(nil, &pointers, pointers.count, nil) else { return }
        let bounds = Screens.global(CGRect(origin: .zero, size: screen.frame.size), on: screen)
        guard let image = CGImage(windowListFromArrayScreenBounds: bounds, windowArray: array, imageOption: [.bestResolution]),
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            print("shot: failed"); return
        }
        try? png.write(to: url)
        print("shot: \(url.path)")
    }
}

import AppKit
import Observation
import FoveaKit
import FoveaStore
import FoveaWindow
import FoveaIsland
import FoveaOnboarding
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
final class AppDelegate: NSObject, NSApplicationDelegate {
    let options = AppOptions.parse()
    let location = DataLocation.resolve()
    private(set) var prefs: PrefsStore!
    private(set) var captures: CaptureLibrary!
    private(set) var dictionary: DictionaryStore!
    private(set) var onboarding: OnboardingStateStore!
    private(set) var home: HomeWindowController!
    private(set) var island: IslandController!
    private var firstRun: OnboardingCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if options.resetAll { location.eraseAll() } else { location.prepare() }

        // The first run's glass follows the Mac's own appearance until the person picks.
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        var initial = FoveaPrefs()
        initial.notchAppearance = dark ? .dark : .light
        initial.language = FoveaLanguage.preferred(Locale.preferredLanguages)
        prefs = PrefsStore(location: location, initial: initial)
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

        // The notch lives for the whole process, whatever the window does.
        island = IslandController(prefs: prefs, captures: captures, dictionary: dictionary)
        island.start()
        if let i = CommandLine.arguments.firstIndex(of: "--demo"), i + 1 < CommandLine.arguments.count {
            let state = CommandLine.arguments[i + 1]
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.8))
                self.island.stage(state)
            }
        }

        home = HomeWindowController(stores: WindowStores(prefs: prefs, captures: captures, dictionary: dictionary))
        NSApp.mainMenu = home.mainMenu(quit: #selector(quit(_:)), quitTarget: self)

        // The first run, until it's done (and resumed where it was after Screen Recording's Quit &
        // Reopen); then Home, unless Fovea opened at login.
        if !onboarding.state.complete && !options.openHome {
            let run = OnboardingCoordinator(prefs: prefs, island: island, dictionary: dictionary, state: onboarding) { [weak self] in
                guard let self else { return }
                self.firstRun = nil
                self.home.show()
                self.observeLoginItem()
            }
            firstRun = run
            run.start()
        } else {
            if !options.noActivate { NSApp.activate(ignoringOtherApps: true) }
            if !LoginItem.launchedAtLogin || options.openHome { home.show() }
            observeLoginItem()
        }
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
        if !Relauncher.relaunching { firstRun?.restoreApps() }
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

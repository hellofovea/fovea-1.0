import AppKit
import SwiftUI
import WindowBenchCore

@MainActor
final class BenchAppDelegate: NSObject, NSApplicationDelegate {
    let options = BenchOptions.parse()
    private(set) var model: BenchModel!
    private(set) var main: MainWindowController!
    private(set) var settings: SettingsWindowController!
    private(set) var panel: ControlPanelController!
    private(set) var notch: LabNotchController!
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store: BenchStore = options.smoke ? .smoke() : (options.isAutomated ? .memory() : .standard())
        model = BenchModel(options: options, store: store)
        NSApp.mainMenu = BenchMenu.make(target: self)
        if let icon = BenchResources.appIcon { NSApp.applicationIconImage = icon }
        applyAppearance()

        main = MainWindowController(model: model)
        settings = SettingsWindowController(model: model)
        panel = ControlPanelController(model: model, follows: main.window!)
        notch = LabNotchController(model: model)

        model.openSettingsHandler = { [weak self] tab in self?.settings.show(tab) }
        model.showWindowHandler = { [weak self] in self?.showMain() }
        model.flightHandler = { [weak self] runID in await self?.notch.takeMeThere(runID: runID, window: self?.main.window) }
        model.handoffFlightHandler = { [weak self] in await self?.notch.flyHandoff(window: self?.main.window) }
        model.recordHandler = { [weak self] name in
            guard let self, let scenario = BenchRecorder.scenarios.first(where: { $0.name == name }) else { return }
            let dir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop/fovea-app-refs/v2/bench-saves", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "")
            Task { @MainActor in
                self.model.status = "Recording \(name)…"
                await BenchRecorder.capture(scenario, gifURL: dir.appendingPathComponent("\(name)-\(stamp).gif"), movieURL: nil, app: self)
                self.model.status = "Saved \(name)-\(stamp).gif"
            }
        }
        model.snapshotHandler = { [weak self] in self?.saveSnapshot() }
        model.scanHandler = { await HistoryScanner.scan() }

        main.place(preset: model.state.windowSize, panelWidth: BenchTokens.Layout.panelWidth)
        main.showWindow(nil)
        panel.attach()
        observeLook()

        if options.isAutomated {
            activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleDisplaySleepDisabled],
                                                            reason: "Window Bench automation")
        }
        if !options.noActivate { NSApp.activate(ignoringOtherApps: true) }
        if options.dumpMenus { BenchMenu.dump(); NSApp.terminate(nil) }
        if CommandLine.arguments.contains("--print-scan") {
            // Counts only: no project name is printed.
            Task {
                let start = Date()
                if let s = await HistoryScanner.scan() {
                    let decoded = s.projects.filter { $0.path != nil }.count
                    print("scan: \(Lines.scanCounts(sessions: s.sessions, agents: s.agents.count, projects: s.projects.count)); "
                          + "per agent \(s.perAgent.map { "\($0.key.name)=\($0.value)" }.sorted().joined(separator: " ")); "
                          + "projects decoded to a path: \(decoded)/\(s.projects.count); unattributed \(s.unattributed.values.reduce(0, +)); "
                          + String(format: "%.2fs", Date().timeIntervalSince(start)))
                } else {
                    print("scan: nothing found")
                }
                let agents = await AgentDetector.detect()
                print("agents: " + agents.map { "\($0.kind.name)=\($0.state.rawValue)" }.joined(separator: " "))
                exit(0)
            }
        }
        if let dir = options.snapshotDirectory {
            Task { await BenchSnapshots.run(dir: dir, filter: options.snapshotFilter, app: self); NSApp.terminate(nil) }
        } else if options.smoke {
            Task { let ok = await BenchSmoke.run(app: self); exit(ok ? 0 : 1) }
        } else if let url = options.recordURL {
            Task { await BenchRecorder.record(to: url, play: options.play ?? "drill", app: self); exit(0) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMain() }
        return true
    }

    func showMain() {
        main.showWindow(nil)
        main.window?.makeKeyAndOrderFront(nil)
        panel.attach()
    }

    // MARK: Look

    /// Mirrors the panel's appearance and window size onto AppKit.
    private func observeLook() {
        withObservationTracking {
            _ = model.state.appearance
            _ = model.state.windowSize
            _ = model.state.labNotch
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.applyAppearance()
                self.main.place(preset: self.model.state.windowSize, panelWidth: BenchTokens.Layout.panelWidth)
                self.panel.follow()
                if !self.model.state.labNotch { self.notch.hide() }
                self.observeLook()
            }
        }
    }

    func applyAppearance() {
        switch model.state.appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    // MARK: Menu actions

    @objc func openSettingsMenu(_ sender: Any?) { model.openSettings(model.settingsTab) }
    @objc func showMainMenu(_ sender: Any?) { showMain() }
    @objc func togglePanelMenu(_ sender: Any?) { panel.toggle() }

    // MARK: Snapshot of the current state (the panel's button)

    func saveSnapshot() {
        guard let window = main.window, let rep = BenchSnapshots.composited([window]),
              let data = rep.representation(using: .png, properties: [:]) else { return }
        let dir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop/fovea-app-refs/v2/bench-saves", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "")
        let url = dir.appendingPathComponent("window-\(stamp).png")
        try? data.write(to: url)
        model.status = "Saved \(url.lastPathComponent)"
    }
}

/// The menu bar, built by hand so no shortcut exists that the window doesn't intend. Kept:
/// Hide, Quit, Close and Minimize (the system's), and the Edit verbs text fields rely on.
/// Settings… has no ⌘, (the brief: the window binds no keys).
enum BenchMenu {
    static func make(target: BenchAppDelegate) -> NSMenu {
        let main = NSMenu()
        let name = "Fovea Window Bench"

        let appItem = NSMenuItem(); main.addItem(appItem)
        let app = NSMenu(title: name)
        app.addItem(withTitle: "About \(name)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        let settings = app.addItem(withTitle: "Settings…", action: #selector(BenchAppDelegate.openSettingsMenu(_:)), keyEquivalent: "")
        settings.target = target
        app.addItem(.separator())
        app.addItem(withTitle: "Hide \(name)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = app.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Quit \(name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = app

        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit

        let windowItem = NSMenuItem(); main.addItem(windowItem)
        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(.separator())
        let show = window.addItem(withTitle: "Fovea", action: #selector(BenchAppDelegate.showMainMenu(_:)), keyEquivalent: "")
        show.target = target
        let panel = window.addItem(withTitle: "Control Panel", action: #selector(BenchAppDelegate.togglePanelMenu(_:)), keyEquivalent: "")
        panel.target = target
        windowItem.submenu = window
        NSApp.windowsMenu = window
        return main
    }

    /// The shortcuts AppKit and the bench put in the menu bar, for the smoke run's allowlist.
    static func keyEquivalents(_ menu: NSMenu? = NSApp.mainMenu) -> [(title: String, key: String, modifiers: NSEvent.ModifierFlags)] {
        guard let menu else { return [] }
        menu.update()
        var out: [(String, String, NSEvent.ModifierFlags)] = []
        for item in menu.items {
            if !item.keyEquivalent.isEmpty { out.append((item.title, item.keyEquivalent, item.keyEquivalentModifierMask)) }
            if let sub = item.submenu {
                sub.delegate?.menuNeedsUpdate?(sub)
                out += keyEquivalents(sub)
            }
        }
        return out
    }

    static func dump() {
        for item in keyEquivalents() {
            print("menu: \(item.title) = \(describe(item.key, item.modifiers))")
        }
    }

    static func describe(_ key: String, _ modifiers: NSEvent.ModifierFlags) -> String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        if modifiers.contains(.function) { s += "fn " }
        return s + key.uppercased()
    }
}

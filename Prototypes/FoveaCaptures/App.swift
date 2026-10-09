import AppKit
import SwiftUI
import CapturesCore
import FoveaCore

/// `--snapshot <dir> [--only <prefix>]` renders every state to PNGs and quits;
/// `--frames <dir>` records the expanded card opening and closing at a tenth of the speed;
/// `FOVEA_NO_ACTIVATE=1` keeps it in the background.
struct Options {
    var snapshotDir: URL?
    var framesDir: URL?
    var eyeFramesDir: URL?
    var searchFramesDir: URL?
    var only: String?
    /// `--settings voice:screen`: opens on a Settings section, and a part of it by its id.
    var settings: String?
    var noActivate = ProcessInfo.processInfo.environment["FOVEA_NO_ACTIVATE"] == "1"

    static func parse() -> Options {
        var o = Options()
        let args = CommandLine.arguments
        func value(after flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        if let dir = value(after: "--snapshot") { o.snapshotDir = URL(fileURLWithPath: dir, isDirectory: true) }
        if let dir = value(after: "--frames") { o.framesDir = URL(fileURLWithPath: dir, isDirectory: true) }
        if let dir = value(after: "--eye-frames") { o.eyeFramesDir = URL(fileURLWithPath: dir, isDirectory: true) }
        if let dir = value(after: "--search-frames") { o.searchFramesDir = URL(fileURLWithPath: dir, isDirectory: true) }
        o.only = value(after: "--only")
        o.settings = value(after: "--settings")
        return o
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let options = Options.parse()
    let model = CapturesModel()
    private(set) var window: NSWindow!
    private let libraryToolbarDelegate = LibraryToolbarDelegate()
    private lazy var variants = VariantMenus(model: model)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = variants.install(into: Self.menu())
        applyIcon()
        observeIcon()

        if options.snapshotDir != nil || options.framesDir != nil { WindowMaterial.alwaysActive = true }
        let harness = options.snapshotDir != nil || options.framesDir != nil || options.eyeFramesDir != nil || options.searchFramesDir != nil
        let hosting = NSHostingController(rootView: MainView().environment(model))
        hosting.sceneBridgingOptions = [.toolbars]
        hosting.sizingOptions = []
        // One size (no .resizable), and no full screen: the size is part of the design.
        window = NSWindow(contentRect: NSRect(origin: .zero, size: T.Layout.window),
                          styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.collectionBehavior.insert(.fullScreenNone)
        window.contentViewController = hosting
        window.title = "Fovea"
        // No title in the toolbar: the filter sits where it would be.
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.setContentSize(T.Layout.window)
        window.tabbingMode = .disallowed
        place()

        window.makeKeyAndOrderFront(nil)
        applyAppearance()
        observeAppearance()
        if !options.noActivate { NSApp.activate(ignoringOtherApps: true) }
        if !harness { applySummon(); observeSummon() }
        if let target = options.settings {
            let parts = target.split(separator: ":").map(String.init)
            if let category = SettingsCategory(rawValue: parts[0]) {
                model.openSettings(category)
                if parts.count > 1 {
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.6))
                        self.model.scrollTarget = parts[1]
                    }
                }
            }
        }

        if let dir = options.snapshotDir {
            Task { await Snapshots.run(dir: dir, only: options.only, app: self); NSApp.terminate(nil) }
        } else if let dir = options.framesDir {
            Task { await Snapshots.frames(dir: dir, app: self); NSApp.terminate(nil) }
        } else if let dir = options.eyeFramesDir {
            Task { await Snapshots.eyeFrames(dir: dir, app: self); NSApp.terminate(nil) }
        } else if let dir = options.searchFramesDir {
            Task { await Snapshots.searchFrames(dir: dir, app: self); NSApp.terminate(nil) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { window.makeKeyAndOrderFront(nil) }
        return true
    }

    /// Centered on the screen, at the window's one size.
    func place() {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let v = screen.visibleFrame
        let size = T.Layout.window
        let x = v.minX + max(12, (v.width - size.width) / 2)
        let y = v.minY + max(0, (v.height - size.height) / 2)
        window.setFrame(window.frameRect(forContentRect: NSRect(x: x, y: y, width: size.width, height: size.height)), display: true)
    }

    func applyAppearance() {
        switch model.appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        applyChrome()
    }

    /// Fovea's schemes draw the toolbar's band themselves: the titlebar goes transparent over it,
    /// and over the Notch scheme's ink band the toolbar's controls take the dark appearance. With
    /// the page inset, the titlebar is transparent over the window's material, the toolbar's
    /// glass floating on it. The library has no toolbar: the traffic lights float on the
    /// material as Aside's do.
    func applyChrome() {
        guard let window else { return }
        let own = model.surface != .system || model.layout == .library || model.pageStyle == .inset
        window.titlebarAppearsTransparent = own
        window.titlebarSeparatorStyle = own ? .none : .automatic
        // The library keeps an empty toolbar, as Aside does: the titlebar is a toolbar's height
        // (the traffic lights centered 26 pt down, beside the sidebar's search), and macOS gives
        // a window with a toolbar its rounder corner, which the page's corner follows.
        if model.layout == .library {
            if window.toolbar?.identifier != Self.libraryToolbar {
                let toolbar = NSToolbar(identifier: Self.libraryToolbar)
                toolbar.delegate = libraryToolbarDelegate
                toolbar.showsBaselineSeparator = false
                toolbar.allowsUserCustomization = false
                window.toolbar = toolbar
            }
            window.toolbarStyle = .unified
            window.titleVisibility = .hidden
        } else if window.toolbar?.identifier == Self.libraryToolbar {
            window.toolbar = nil
        }
        let dark = (NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
        let titlebar = window.standardWindowButton(.closeButton)?.superview
        titlebar?.appearance = (model.surface == .notch && !dark && model.layout == .cards) ? NSAppearance(named: .darkAqua) : nil
    }

    private func observeAppearance() {
        withObservationTracking { _ = model.appearance; _ = model.surface; _ = model.layout; _ = model.pageStyle } onChange: { [weak self] in
            Task { @MainActor in self?.applyAppearance(); self?.observeAppearance() }
        }
    }

    /// The Dock icon: the app's icon, or the variant picked on the Variants menu.
    func applyIcon() {
        let url = FoveaResources.url(model.iconVariant.file) ?? FoveaResourcesURL.appIcon
        if let url, let icon = NSImage(contentsOf: url) { NSApp.applicationIconImage = icon }
    }

    private func observeIcon() {
        withObservationTracking { _ = model.iconVariant } onChange: { [weak self] in
            Task { @MainActor in self?.applyIcon(); self?.observeIcon() }
        }
    }

    // MARK: From anywhere

    /// ⌥⌘F, from any app, as Aside's ⌥⌘A: the window comes forward if it isn't, and goes away
    /// if it is, handing the keyboard back to the app you were in.
    @objc func toggleWindow() {
        if NSApp.isActive && window.isVisible && window.isKeyWindow {
            NSApp.hide(nil)
        } else {
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func applySummon() {
        if model.summon {
            GlobalHotKey.shared.register { [weak self] in self?.toggleWindow() }
        } else {
            GlobalHotKey.shared.unregister()
        }
    }

    private func observeSummon() {
        withObservationTracking { _ = model.summon } onChange: { [weak self] in
            Task { @MainActor in self?.applySummon(); self?.observeSummon() }
        }
    }

    // MARK: Menu commands (every toolbar command is in the menu bar too)

    @objc func showSettings(_ sender: Any?) { model.show(.settings) }
    @objc func reportProblem(_ sender: Any?) { model.reporting = true }
    @objc func goBack(_ sender: Any?) { model.back() }
    @objc func find(_ sender: Any?) {
        if model.page != .captures { model.back() }
        model.searchRequest += 1
    }
    @objc func showKind(_ sender: NSMenuItem) {
        if model.page != .captures { model.back() }
        model.setKind(sender.tag == 0 ? nil : CaptureKind.allCases[sender.tag - 1])
    }

    static func menu() -> NSMenu {
        let main = NSMenu()
        func add(_ title: String, _ items: [NSMenuItem]) -> NSMenu {
            let item = NSMenuItem()
            let menu = NSMenu(title: title)
            items.forEach(menu.addItem)
            item.submenu = menu
            main.addItem(item)
            return menu
        }
        func item(_ title: String, _ action: Selector?, _ key: String, _ mods: NSEvent.ModifierFlags = .command, tag: Int = 0) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
            i.keyEquivalentModifierMask = mods
            i.tag = tag
            return i
        }
        _ = add("Fovea", [
            item("About Fovea", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), ""),
            .separator(),
            item("Settings…", #selector(AppDelegate.showSettings(_:)), ","),
            .separator(),
            item("Hide Fovea", #selector(NSApplication.hide(_:)), "h"),
            item("Quit Fovea", #selector(NSApplication.terminate(_:)), "q"),
        ])
        _ = add("Edit", [
            item("Undo", Selector(("undo:")), "z"),
            .separator(),
            item("Cut", #selector(NSText.cut(_:)), "x"),
            item("Copy", #selector(NSText.copy(_:)), "c"),
            item("Paste", #selector(NSText.paste(_:)), "v"),
            item("Select All", #selector(NSText.selectAll(_:)), "a"),
            .separator(),
            item("Find", #selector(AppDelegate.find(_:)), "f"),
        ])
        _ = add("View", [
            item("All", #selector(AppDelegate.showKind(_:)), "1", tag: 0),
            item("Dictation", #selector(AppDelegate.showKind(_:)), "2", tag: 1),
            item("Dispatch", #selector(AppDelegate.showKind(_:)), "3", tag: 2),
        ])
        _ = add("Go", [
            item("Back", #selector(AppDelegate.goBack(_:)), "["),
        ])
        let windowMenu = add("Window", [
            item("Close", #selector(NSWindow.performClose(_:)), "w"),
            item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
        ])
        NSApp.windowsMenu = windowMenu
        // Help, as every Mac app's ends (row 9): the Mac adds its search field to it.
        let helpMenu = add("Help", [
            item("Report a Problem…", #selector(AppDelegate.reportProblem(_:)), ""),
        ])
        NSApp.helpMenu = helpMenu
        return main
    }
}

extension AppDelegate {
    static let libraryToolbar = "fovea.library"
}

/// The library's toolbar holds one flexible space and nothing else: enough for macOS to give the
/// titlebar a toolbar's height, nothing to draw.
final class LibraryToolbarDelegate: NSObject, NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace] }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace] }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? { nil }
}

enum FoveaResourcesURL {
    static var appIcon: URL? { FoveaResources.url("AppIcon.png") }
}

/// The designs still being compared, in the menu bar rather than on a panel (the panel is gone
/// for good): Variants holds the layouts and the icon-fit variants, View › Appearance the
/// window's Light, Dark or System. Each is a menu of choices with a check on the current one.
@MainActor
final class VariantMenus: NSObject, NSMenuDelegate {
    let model: CapturesModel
    init(model: CapturesModel) { self.model = model }

    /// A choice: what it does, and whether it's the current one.
    private final class Choice: NSObject {
        let apply: () -> Void
        let isOn: () -> Bool
        init(apply: @escaping () -> Void, isOn: @escaping () -> Bool) { self.apply = apply; self.isOn = isOn }
    }

    /// Adds View › Appearance, and the Variants menu before Window.
    func install(into main: NSMenu) -> NSMenu {
        if let view = main.items.first(where: { $0.submenu?.title == "View" })?.submenu {
            view.addItem(.separator())
            view.addItem(choices("Appearance", [Appearance.light, .dark, .system], title: { $0.title },
                                 get: { [model] in model.appearance }, set: { [model] v in model.appearance = v }))
        }
        let menu = NSMenu(title: "Variants")
        menu.addItem(choices("Window", LayoutStyle.allCases.reversed(),
                             title: { $0 == .cards ? "Cards under a toolbar (as now)" : "Sidebar: the library (Aside's layout)" },
                             get: { [model] in model.layout }, set: { [model] v in model.animate(.page) { model.layout = v } }))
        menu.addItem(choices("Settings", SettingsLayout.allCases, title: { $0.title },
                             get: { [model] in model.settingsLayout }, set: { [model] v in model.animate(.swap) { model.settingsLayout = v } }))
        menu.addItem(.separator())
        let header = NSMenuItem(title: "Fitting the window to the icon", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(choices("Focus", FocusMark.allCases, title: { $0.title },
                             get: { [model] in model.focusMark }, set: { [model] v in model.animate(.swap) { model.focusMark = v } }))
        menu.addItem(choices("Avatar", AvatarStyle.allCases, title: { $0.title },
                             get: { [model] in model.avatarStyle }, set: { [model] v in model.animate(.swap) { model.avatarStyle = v } }))
        menu.addItem(choices("Type", TitleDesign.allCases, title: { $0.title },
                             get: { [model] in model.titleDesign }, set: { [model] v in model.titleDesign = v }))
        menu.addItem(choices("App Icon", IconVariant.allCases, title: { $0.title },
                             get: { [model] in model.iconVariant }, set: { [model] v in model.iconVariant = v }))
        let item = NSMenuItem(title: "Variants", action: nil, keyEquivalent: "")
        item.submenu = menu
        let window = main.items.firstIndex { $0.submenu?.title == "Window" } ?? main.items.count
        main.insertItem(item, at: window)
        main.insertItem(states(), at: window + 1)
        return main
    }

    /// The App UI review's states (row 13), each shown where it would appear: the window that
    /// can't open its data, the plan's alerts, the updates, the photo, History, Memory and the
    /// Dictionary.
    private func states() -> NSMenuItem {
        let menu = NSMenu(title: "States")
        menu.addItem(choices("Window", [WindowError?.none] + WindowError.allCases.map { $0 }, title: { $0?.menuTitle ?? "Opens Normally" },
                             get: { [model] in model.windowError }, set: { [model] v in model.setWindowError(v) }))
        menu.addItem(choices("Plan", [PlanAlert?.none] + PlanAlert.allCases.map { $0 }, title: { $0?.title ?? "Credits Left" },
                             get: { [model] in model.planAlert }, set: { [model] v in model.setPlanAlert(v) }))
        menu.addItem(choices("Updates", [UpdateState.upToDate, .checking, .failed, .available("0.6 beta 1")], title: { $0.title },
                             get: { [model] in model.update }, set: { [model] v in model.setUpdate(v) }))
        menu.addItem(action("Photo Over 2 MB") { [model] in model.demoPhotoTooLarge() })
        menu.addItem(.separator())
        menu.addItem(choices("History", HistoryDemo.allCases, title: { $0.title },
                             get: { [model] in model.historyDemo }, set: { [model] v in model.setHistory(v) }))
        menu.addItem(choices("Memory", MemoryDemo.allCases, title: { $0.title },
                             get: { [model] in model.memoryDemo }, set: { [model] v in model.setMemory(v) }))
        menu.addItem(choices("Dictionary", DictionaryDemo.allCases, title: { $0.title },
                             get: { [model] in model.dictionaryDemo }, set: { [model] v in model.setDictionary(v) }))
        let item = NSMenuItem(title: "States", action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private func action(_ title: String, _ run: @escaping () -> Void) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: #selector(pick(_:)), keyEquivalent: "")
        i.target = self
        i.representedObject = Choice(apply: run, isOn: { false })
        return i
    }

    private func choices<V: Equatable>(_ title: String, _ values: [V], title name: (V) -> String,
                                       get: @escaping () -> V, set: @escaping (V) -> Void) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)
        menu.delegate = self
        for value in values {
            let i = NSMenuItem(title: name(value), action: #selector(pick(_:)), keyEquivalent: "")
            i.target = self
            i.representedObject = Choice(apply: { set(value) }, isOn: { get() == value })
            menu.addItem(i)
        }
        parent.submenu = menu
        return parent
    }

    @objc private func pick(_ sender: NSMenuItem) { (sender.representedObject as? Choice)?.apply() }

    func menuNeedsUpdate(_ menu: NSMenu) {
        for i in menu.items {
            if let choice = i.representedObject as? Choice { i.state = choice.isOn() ? .on : .off }
        }
    }
}

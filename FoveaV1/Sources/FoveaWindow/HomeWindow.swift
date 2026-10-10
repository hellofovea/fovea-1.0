import AppKit
import SwiftUI
import Observation
import CapturesCore
import FoveaKit
import FoveaStore
import FoveaPlatform

// The window: Home and Settings, the Captures design (Oct 6–9) on what's kept on this Mac. Every
// design variant the prototype compared is fixed at its default (no Variants or States menus).
// The captures and the dictionary are the stores' (the island adds to them as you work); the
// notch's settings are the prefs the island and the onboarding read. Account, the plan and its
// credits, Memory and eye tracking stay simulated in 1.0.

/// `--settings voice:screen` opens on a Settings section, and a part of it by its id.
struct WindowOptions {
    var settings: String?
    var noActivate = ProcessInfo.processInfo.environment["FOVEA_NO_ACTIVATE"] == "1"

    static func parse(_ args: [String] = CommandLine.arguments) -> WindowOptions {
        var o = WindowOptions()
        if let i = args.firstIndex(of: "--settings"), i + 1 < args.count { o.settings = args[i + 1] }
        return o
    }
}

/// The stores the window reads and writes.
package struct WindowStores {
    package let prefs: PrefsStore
    package let captures: CaptureLibrary
    package let dictionary: DictionaryStore

    package init(prefs: PrefsStore, captures: CaptureLibrary, dictionary: DictionaryStore) {
        self.prefs = prefs; self.captures = captures; self.dictionary = dictionary
    }
}

@MainActor
package final class HomeWindowController: NSObject {
    package let window: NSWindow
    let model: CapturesModel
    private let stores: WindowStores
    private let options = WindowOptions.parse()
    private let libraryToolbarDelegate = LibraryToolbarDelegate()
    /// Set while the stores' own change is being shown, so it isn't written back.
    private var pulling = false
    private var placed = false

    package init(stores: WindowStores) {
        self.stores = stores
        let model = CapturesModel()
        self.model = model
        let hosting = NSHostingController(rootView: MainView().environment(model))
        hosting.sceneBridgingOptions = [.toolbars]
        hosting.sizingOptions = []
        // One size (no .resizable), and no full screen: the size is part of the design.
        window = NSWindow(contentRect: NSRect(origin: .zero, size: T.Layout.window),
                          styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        super.init()
        window.collectionBehavior.insert(.fullScreenNone)
        window.contentViewController = hosting
        window.title = "Fovea"
        // No title in the toolbar: the filter sits where it would be.
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.setContentSize(T.Layout.window)
        window.tabbingMode = .disallowed

        pullAll()
        model.onLibraryEdited = { [weak self] in self?.pushLibrary() }
        model.onPrefsEdited = { [weak self] in self?.pushPrefs() }
        observeStores()
        applyAppearance()
        observeAppearance()
        pendingSettings = options.settings
    }

    /// `--settings`: opened once the window is on screen (its toolbar follows the page then).
    private var pendingSettings: String?

    /// Brings Home forward, centered the first time.
    package func show() {
        refreshNow()
        if !placed { place(); placed = true }
        window.makeKeyAndOrderFront(nil)
        if !options.noActivate { NSApp.activate(ignoringOtherApps: true) }
        if let target = pendingSettings {
            pendingSettings = nil
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                self.model.show(.settings)
                self.openSettings(target)
            }
        }
    }

    /// Opens Settings, on a category ("notch", "shortcuts:keys").
    package func openSettings(_ target: String = "account") {
        let parts = target.split(separator: ":").map(String.init)
        guard let category = SettingsCategory(rawValue: parts.first ?? "account") else { return }
        model.openSettings(category)
        if parts.count > 1 {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.6))
                self.model.scrollTarget = parts[1]
            }
        }
    }

    package func showSettings() {
        show()
        model.show(.settings)
    }

    // MARK: The stores

    /// "Now" is the clock's: the first page shows the last three days from today.
    private func refreshNow() {
        let now = Date()
        if !Lines.calendar.isDate(now, inSameDayAs: model.library.now) || now.timeIntervalSince(model.library.now) > 60 {
            pulling = true
            model.library.now = now
            pulling = false
        }
    }

    private func pullAll() {
        pulling = true
        defer { pulling = false }
        let simulated = Fixtures.library(.typical)
        model.library = Library(now: Date(), captures: stores.captures.captures, dictionary: stores.dictionary.words,
                                memories: simulated.memories, usage: simulated.usage, areas: simulated.areas)
        model.media = stores.captures.media
        model.calendarYear = Lines.calendar.component(.year, from: Date())
        pullPrefs()
    }

    private func pullPrefs() {
        let p = stores.prefs.prefs
        let was = pulling
        pulling = true
        defer { pulling = was }
        func set<V: Equatable>(_ key: WritableKeyPath<Prefs, V>, _ value: V) {
            if model.prefs[keyPath: key] != value { model.prefs[keyPath: key] = value }
        }
        set(\.glow, p.glowPalette)
        set(\.glowHue, p.glowHue)
        set(\.glowSpread, p.glowSpread)
        set(\.glowDrift, p.glowDrift)
        set(\.notchAppearance, p.notchAppearance)
        set(\.panels, p.panels)
        set(\.density, p.density)
        set(\.hoverOpens, p.hoverOpens)
        set(\.hoverWait, p.hoverWait)
        set(\.showAnswers, p.showAnswers)
        set(\.reviewFirst, p.reviewFirst)
        set(\.openAtLogin, p.openAtLogin)
        set(\.appLanguage, p.language)
        let accent = AccentChoice(rawValue: p.accent.rawValue) ?? .multicolor
        if model.accent != accent { model.accent = accent }
        if model.profileName != p.accountName { model.profileName = p.accountName }
        if model.profileEmail != p.accountEmail { model.profileEmail = p.accountEmail }
    }

    private func pushPrefs() {
        guard !pulling else { return }
        let m = model.prefs
        var p = stores.prefs.prefs
        p.glowPalette = m.glow
        p.glowHue = m.glowHue
        p.glowSpread = m.glowSpread
        p.glowDrift = m.glowDrift
        p.notchAppearance = m.notchAppearance
        p.panels = m.panels
        p.density = m.density
        p.hoverOpens = m.hoverOpens
        p.hoverWait = m.hoverWait
        p.showAnswers = m.showAnswers
        p.reviewFirst = m.reviewFirst
        p.openAtLogin = m.openAtLogin
        p.language = m.appLanguage
        p.accent = FoveaAccent(rawValue: model.accent.rawValue) ?? .multicolor
        p.accountName = model.profileName
        if p != stores.prefs.prefs { stores.prefs.prefs = p }
    }

    private func pushLibrary() {
        guard !pulling else { return }
        if model.library.captures != stores.captures.captures { stores.captures.replaceAll(model.library.captures) }
        if model.library.dictionary != stores.dictionary.words { stores.dictionary.replaceAll(model.library.dictionary) }
    }

    /// The island's new capture, a word brought in, a pref changed elsewhere: shown at once.
    private func observeStores() {
        withObservationTracking {
            _ = stores.captures.captures
            _ = stores.dictionary.words
            _ = stores.prefs.prefs
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.pulling = true
                if self.model.library.captures != self.stores.captures.captures {
                    self.model.library.now = Date()
                    self.model.library.captures = self.stores.captures.captures
                }
                if self.model.library.dictionary != self.stores.dictionary.words {
                    self.model.library.dictionary = self.stores.dictionary.words
                }
                self.pulling = false
                self.pullPrefs()
                self.observeStores()
            }
        }
    }

    // MARK: The window

    /// Centered on the screen, at the window's one size.
    private func place() {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let v = screen.visibleFrame
        let size = T.Layout.window
        let x = v.minX + max(12, (v.width - size.width) / 2)
        let y = v.minY + max(0, (v.height - size.height) / 2)
        window.setFrame(window.frameRect(forContentRect: NSRect(x: x, y: y, width: size.width, height: size.height)), display: true)
    }

    /// The window's Light, Dark or System, on the window alone: the notch has its own glass.
    private func applyAppearance() {
        switch model.appearance {
        case .system: window.appearance = nil
        case .light: window.appearance = NSAppearance(named: .aqua)
        case .dark: window.appearance = NSAppearance(named: .darkAqua)
        }
        applyChrome()
    }

    /// Fovea's schemes draw the toolbar's band themselves: the titlebar goes transparent over it.
    /// With the page inset, the titlebar is transparent over the window's material, the toolbar's
    /// glass floating on it.
    private func applyChrome() {
        let own = model.surface != .system || model.layout == .library || model.pageStyle == .inset
        window.titlebarAppearsTransparent = own
        window.titlebarSeparatorStyle = own ? .none : .automatic
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
        let dark = (window.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
        let titlebar = window.standardWindowButton(.closeButton)?.superview
        titlebar?.appearance = (model.surface == .notch && !dark && model.layout == .cards) ? NSAppearance(named: .darkAqua) : nil
    }

    private func observeAppearance() {
        withObservationTracking { _ = model.appearance; _ = model.surface; _ = model.layout; _ = model.pageStyle } onChange: { [weak self] in
            Task { @MainActor in self?.applyAppearance(); self?.observeAppearance() }
        }
    }

    static let libraryToolbar = "fovea.library"

    // MARK: The menu bar's commands (every toolbar command is in the menu bar too)

    @objc package func showSettingsCommand(_ sender: Any?) { showSettings() }
    @objc func reportProblem(_ sender: Any?) { show(); model.reporting = true }
    @objc func goBack(_ sender: Any?) { model.back() }
    @objc func find(_ sender: Any?) {
        show()
        if model.page != .captures { model.back() }
        model.searchRequest += 1
    }
    @objc func showKind(_ sender: NSMenuItem) {
        show()
        if model.page != .captures { model.back() }
        model.setKind(sender.tag == 0 ? nil : CaptureKind.allCases[sender.tag - 1])
    }
    @objc func showHome(_ sender: Any?) {
        show()
        if model.page != .captures { model.show(.captures) }
    }

    /// The main menu: Fovea, Edit, View, Go, Window, Help. `quit` is the App's (it puts back the
    /// apps a first run hid before it quits).
    package func mainMenu(quit: Selector, quitTarget: AnyObject) -> NSMenu {
        let main = NSMenu()
        func add(_ title: String, _ items: [NSMenuItem]) -> NSMenu {
            let item = NSMenuItem()
            let menu = NSMenu(title: title)
            items.forEach(menu.addItem)
            item.submenu = menu
            main.addItem(item)
            return menu
        }
        func item(_ title: String, _ action: Selector?, _ key: String, _ mods: NSEvent.ModifierFlags = .command,
                  tag: Int = 0, target: AnyObject? = nil) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
            i.keyEquivalentModifierMask = mods
            i.tag = tag
            i.target = target
            return i
        }
        _ = add("Fovea", [
            item("About Fovea", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), ""),
            .separator(),
            item("Settings…", #selector(showSettingsCommand(_:)), ",", target: self),
            .separator(),
            item("Hide Fovea", #selector(NSApplication.hide(_:)), "h"),
            item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            item("Show All", #selector(NSApplication.unhideAllApplications(_:)), ""),
            .separator(),
            item("Quit Fovea", quit, "q", target: quitTarget),
        ])
        _ = add("Edit", [
            item("Undo", Selector(("undo:")), "z"),
            item("Redo", Selector(("redo:")), "z", [.command, .shift]),
            .separator(),
            item("Cut", #selector(NSText.cut(_:)), "x"),
            item("Copy", #selector(NSText.copy(_:)), "c"),
            item("Paste", #selector(NSText.paste(_:)), "v"),
            item("Select All", #selector(NSText.selectAll(_:)), "a"),
            .separator(),
            item("Find", #selector(find(_:)), "f", target: self),
        ])
        _ = add("View", [
            item("All", #selector(showKind(_:)), "1", tag: 0, target: self),
            item("Dictation", #selector(showKind(_:)), "2", tag: 1, target: self),
            item("Dispatch", #selector(showKind(_:)), "3", tag: 2, target: self),
        ])
        _ = add("Go", [
            item("Home", #selector(showHome(_:)), "0", target: self),
            item("Back", #selector(goBack(_:)), "[", target: self),
        ])
        let windowMenu = add("Window", [
            item("Close", #selector(NSWindow.performClose(_:)), "w"),
            item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
        ])
        NSApp.windowsMenu = windowMenu
        // Help, as every Mac app's ends (row 9): the Mac adds its search field to it.
        let helpMenu = add("Help", [
            item("Report a Problem…", #selector(reportProblem(_:)), "", target: self),
        ])
        NSApp.helpMenu = helpMenu
        return main
    }
}

/// The library's toolbar holds one flexible space and nothing else: enough for macOS to give the
/// titlebar a toolbar's height, nothing to draw.
final class LibraryToolbarDelegate: NSObject, NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace] }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace] }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? { nil }
}

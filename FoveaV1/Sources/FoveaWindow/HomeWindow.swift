import AppKit
import SwiftUI
import Observation
import CapturesCore
import FoveaKit
import FoveaStore
import FoveaPlatform
import FoveaLook

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
    /// Read by the expanded card's smoke too (WindowShots.swift), to see a deletion reach them.
    let stores: WindowStores
    private let options = WindowOptions.parse()
    private let libraryToolbarDelegate = LibraryToolbarDelegate()
    /// Set while the stores' own change is being shown, so it isn't written back.
    private var pulling = false
    private var placed = false

    package init(stores: WindowStores) {
        self.stores = stores
        let model = CapturesModel()
        self.model = model
        // Oct 18, Ryan: the window in the primary language, switching live (FoveaLook's `.foveaLanguage()`);
        // literal text too, once Bundle.main answers in it (LanguageBundle.swift).
        FoveaLanguageBundle.install()
        let hosting = NSHostingController(rootView: MainView().environment(model).foveaLanguage())
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
        // Oct 15 review: signing in (AC-01.5) and "What Fovea remembers" read (OB-02) are kept in
        // the prefs every surface reads.
        model.onAccountEdited = { [weak self] email, provider in
            guard let self else { return }
            var p = self.stores.prefs.prefs
            p.accountEmail = email
            p.accountProvider = provider
            p.signedOut = false
            if p != self.stores.prefs.prefs { self.stores.prefs.prefs = p }
        }
        // Signing out is kept too, so every surface and the next launch agree (AC-01.5).
        model.onSignedOut = { [weak self] in self?.stores.prefs.prefs.signedOut = true }
        model.onMemoryDisclosureRead = { [weak self] in self?.stores.prefs.prefs.memoryDisclosureSeen = true }
        model.dataFolder = DataLocation.resolve().root
        observeStores()
        applyAppearance()
        observeAppearance()
        pendingSettings = options.settings
        // Getting Started's permissions are read again whenever the window comes back to the front.
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.permissionsChecked = Date() }
        }
        registerReviewStages()
        Self.registerSettingsPaneStages(model: model) { [weak self] in self?.show() }
    }

    // MARK: Hooks the app wires (Oct 15 review)

    /// OB-03.1: Settings › Getting Started's Replay the Tour.
    package var onReplayTour: (() -> Void)? {
        get { model.onReplayTour }
        set { model.onReplayTour = newValue }
    }
    /// OB-03.1: Practise Again, with the first run's step: "weeklyUpdate", "packList", "followUp",
    /// "dictation".
    package var onPractice: ((String) -> Void)? {
        get { model.onPractice }
        set { model.onPractice = newValue }
    }
    /// HI-01.3: an expanded Dispatch card's Open in Notch, with the capture's id.
    package var onOpenInNotch: ((String) -> Void)? {
        get { model.onOpenInNotch }
        set { model.onOpenInNotch = newValue }
    }
    /// QA25: a Dispatch that wasn't sent (`Capture.sendFailure`), sent again, with its id.
    package var onSendAgain: ((String) -> Void)? {
        get { model.onSendAgain }
        set { model.onSendAgain = newValue }
    }

    /// Opens the window on any Settings section, from anywhere (the menu bar's icon, the menus):
    /// "about", "gettingStarted", "plan", "account:earlier-data" (a part of it by its id).
    package func showSettings(section: String) {
        show()
        openSettings(section)
    }

    /// The menu bar's Check for Updates…: About, checking.
    package func checkForUpdates() {
        show()
        model.checkForUpdatesFromMenu()
    }

    /// The first run is done and the window is in front: "What Fovea remembers", once (OB-02),
    /// for someone who finished the tour before the first run said it.
    private func offerMemoryDisclosure() {
        guard !disclosureOffered, !tourUnfinished, !stores.prefs.prefs.memoryDisclosureSeen else { return }
        disclosureOffered = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.8))
            guard self.window.isVisible, !self.stores.prefs.prefs.memoryDisclosureSeen else { return }
            self.model.memoryDisclosureShown = true
        }
    }
    private var disclosureOffered = false
    /// Off for the design shots, which picture the sheet on purpose.
    var offersDisclosure = true

    /// `--settings`: opened once the window is on screen (its toolbar follows the page then).
    private var pendingSettings: String?

    /// Brings Home forward, centered the first time.
    /// The first run put away part way: Home's link back to it, and what it does.
    package var tourUnfinished: Bool {
        get { model.tourUnfinished }
        set { model.tourUnfinished = newValue }
    }
    package var onResumeTour: (() -> Void)? {
        get { model.onResumeTour }
        set { model.onResumeTour = newValue }
    }

    package func show() {
        refreshNow()
        if !placed { place(); placed = true }
        window.makeKeyAndOrderFront(nil)
        if !options.noActivate { NSApp.activate(ignoringOtherApps: true) }
        if offersDisclosure { offerMemoryDisclosure() }
        if let target = pendingSettings {
            pendingSettings = nil
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                self.model.show(.settings)
                self.openSettings(target)
            }
        }
    }

    /// Opens Settings, on a category ("notch", "shortcuts:keys"), bringing the window forward.
    package func openSettings(_ target: String = "account") {
        let parts = target.split(separator: ":").map(String.init)
        guard let category = SettingsCategory(rawValue: parts.first ?? "account") else { return }
        if !window.isVisible { show() }
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
        // The credits are simulated; they reset on the first of next month, from today (Oct 15
        // review: the fixture's own date read "resets Sep 30" in October beside a trial's end).
        var usage = simulated.usage
        let cal = Lines.calendar
        if let month = cal.date(from: cal.dateComponents([.year, .month], from: Date())),
           let next = cal.date(byAdding: .month, value: 1, to: month) { usage.resets = next }
        model.library = Library(now: Date(), captures: stores.captures.captures, dictionary: stores.dictionary.words,
                                memories: simulated.memories, usage: usage, areas: simulated.areas)
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
        // Oct 15 review, ST-02.5: Show in Dock, for real (the app sets the activation policy).
        set(\.showInDock, p.showInDock)
        set(\.appLanguage, p.language)
        // Oct 18, Ryan: the languages chosen, the primary among them (none kept yet: the primary).
        set(\.languages, p.languages.isEmpty ? [p.language] : p.languages)
        // Oct 15 review: Tidy my words, Motion, the recorded shortcuts.
        set(\.tidyWords, p.tidyWords)
        set(\.motion, p.motion)
        set(\.shortcutChords, p.shortcutChords)
        // Oct 17, Ryan (FR-06): the languages asked for, the first run's and Settings' one list.
        set(\.requestedLanguages, p.requestedLanguages)
        // Oct 15 review, MW-05.1 and OB-03.2: each shortcut's keys as the person has them.
        var keys: [String: [String]] = [:]
        for shortcut in FoveaKeys.all { keys[shortcut.id] = FoveaKeys.chord(shortcut.id, p)?.caps ?? shortcut.keys }
        if model.shortcutKeys != keys { model.shortcutKeys = keys }
        let accent = AccentChoice(rawValue: p.accent.rawValue) ?? .multicolor
        if model.accent != accent { model.accent = accent }
        if model.profileName != p.accountName { model.profileName = p.accountName }
        // Google, in 1.0, is a sign-up without an account server: no email to show.
        let email = p.accountEmail.isEmpty && p.accountProvider == .google ? L("Signed in with Google") : p.accountEmail
        if model.profileEmail != email { model.profileEmail = email }
        if model.signedOut != p.signedOut { model.signedOut = p.signedOut }
        if model.prefs.rememberNotice != p.memoryNotice { model.prefs.rememberNotice = p.memoryNotice }
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
        p.showInDock = m.showInDock
        p.language = m.appLanguage
        p.languages = m.languages
        p.tidyWords = m.tidyWords
        p.memoryNotice = m.rememberNotice
        p.motion = m.motion
        p.shortcutChords = m.shortcutChords
        p.requestedLanguages = m.requestedLanguages
        p.accent = FoveaAccent(rawValue: model.accent.rawValue) ?? .multicolor
        p.accountName = model.profileName
        if p != stores.prefs.prefs { stores.prefs.prefs = p }
    }

    private func pushLibrary() {
        guard !pulling else { return }
        // A review stage's captures are shown, never kept.
        let kept = model.stagedIDs.isEmpty ? model.library.captures : model.library.captures.filter { !model.stagedIDs.contains($0.id) }
        if kept != stores.captures.captures { stores.captures.replaceAll(kept) }
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
                let staged = self.model.library.captures.filter { self.model.stagedIDs.contains($0.id) }
                let kept = self.model.library.captures.filter { !self.model.stagedIDs.contains($0.id) }
                if kept != self.stores.captures.captures {
                    self.model.library.now = Date()
                    self.model.library.captures = (self.stores.captures.captures + staged).sorted { $0.time > $1.time }
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
    // Oct 15 review, MW-06 and MW-04a: About opens Settings › About; Go and Help reach the new
    // sections; the website's help and what's new.
    @objc func showAbout(_ sender: Any?) { showSettings(section: SettingsCategory.about.rawValue) }
    @objc func checkForUpdatesCommand(_ sender: Any?) { checkForUpdates() }
    @objc func showGettingStarted(_ sender: Any?) { showSettings(section: SettingsCategory.gettingStarted.rawValue) }
    @objc func showDictionary(_ sender: Any?) { showSettings(section: SettingsCategory.dictionary.rawValue) }
    @objc func showMemory(_ sender: Any?) { showSettings(section: SettingsCategory.memory.rawValue) }
    @objc func openHelpCenter(_ sender: Any?) { NSWorkspace.shared.open(FoveaSite.helpCenter) }
    @objc func openWhatsNew(_ sender: Any?) { NSWorkspace.shared.open(FoveaSite.whatsNew) }
    @objc func reportProblem(_ sender: Any?) { show(); model.reporting = true }
    /// The website's feedback and subscription pages (Oct 13).
    @objc func sendFeedback(_ sender: Any?) { NSWorkspace.shared.open(FoveaSite.feedback) }
    @objc func manageSubscription(_ sender: Any?) { NSWorkspace.shared.open(FoveaSite.account) }
    @objc func goBack(_ sender: Any?) { model.back() }
    /// Oct 21, Ryan: Edit › Copy. With the expanded card out and nothing else to copy (no words
    /// selected in it, no field holding the keyboard with a selection), it copies the capture as
    /// its Copy button does; otherwise it's the Mac's own Copy, for whatever holds the keyboard.
    @objc func copyCommand(_ sender: Any?) {
        // The window holds the keyboard (or none of Fovea's does, as when the smoke sends it).
        let ours = window.isKeyWindow || NSApp.keyWindow == nil
        if ours, model.page != .settings, let capture = model.detail, !model.detailClosing,
           !Self.somethingElseCopies(sender) {
            model.copy(capture)
            return
        }
        NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: sender)
    }

    /// Whether something holding the keyboard would copy now: a field or a text with words
    /// selected (whatever takes Copy in the responder chain and, asked, says it can).
    static func somethingElseCopies(_ sender: Any?) -> Bool {
        guard let target = NSApp.target(forAction: #selector(NSText.copy(_:)), to: nil, from: sender) as AnyObject? else { return false }
        if let text = target as? NSTextView { return text.selectedRange().length > 0 }
        if let check = target as? NSUserInterfaceValidations, let item = sender as? NSValidatedUserInterfaceItem {
            return check.validateUserInterfaceItem(item)
        }
        return true
    }

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
    /// Oct 18, Ryan: every title in the primary language; the App builds it again when the
    /// language changes.
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
        _ = add(L("Fovea"), [
            item(L("About Fovea"), #selector(showAbout(_:)), "", target: self),
            item(L("Check for Updates…"), #selector(checkForUpdatesCommand(_:)), "", target: self),
            .separator(),
            item(L("Settings…"), #selector(showSettingsCommand(_:)), ",", target: self),
            .separator(),
            item(L("Hide Fovea"), #selector(NSApplication.hide(_:)), "h"),
            item(L("Hide Others"), #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            item(L("Show All"), #selector(NSApplication.unhideAllApplications(_:)), ""),
            .separator(),
            item(L("Quit Fovea"), quit, "q", target: quitTarget),
        ])
        _ = add(L("Edit"), [
            item(L("Undo"), Selector(("undo:")), "z"),
            item(L("Redo"), Selector(("redo:")), "z", [.command, .shift]),
            .separator(),
            item(L("Cut"), #selector(NSText.cut(_:)), "x"),
            // Oct 21, Ryan: ⌘C copies the expanded card while nothing in it is selected.
            item(L("Copy"), #selector(copyCommand(_:)), "c", target: self),
            item(L("Paste"), #selector(NSText.paste(_:)), "v"),
            item(L("Select All"), #selector(NSText.selectAll(_:)), "a"),
            .separator(),
            item(L("Find"), #selector(find(_:)), "f", target: self),
        ])
        _ = add(L("View"), [
            item(L("All"), #selector(showKind(_:)), "1", tag: 0, target: self),
            item(L("Dictation"), #selector(showKind(_:)), "2", tag: 1, target: self),
            item(L("Dispatch"), #selector(showKind(_:)), "3", tag: 2, target: self),
        ])
        // ⇧⌘ and a letter, as Finder's Go menu has them, clear of View's ⌘1–3.
        _ = add(L("Go"), [
            item(L("Home"), #selector(showHome(_:)), "0", target: self),
            .separator(),
            item(L("Getting Started"), #selector(showGettingStarted(_:)), "g", [.command, .shift], target: self),
            item(L("Dictionary"), #selector(showDictionary(_:)), "d", [.command, .shift], target: self),
            item(L("Memory"), #selector(showMemory(_:)), "m", [.command, .shift], target: self),
            .separator(),
            item(L("Back"), #selector(goBack(_:)), "[", target: self),
        ])
        let windowMenu = add(L("Window"), [
            item(L("Close"), #selector(NSWindow.performClose(_:)), "w"),
            item(L("Minimize"), #selector(NSWindow.performMiniaturize(_:)), "m"),
        ])
        NSApp.windowsMenu = windowMenu
        // Help, as every Mac app's ends (row 9): the Mac adds its search field to it.
        let helpMenu = add(L("Help"), [
            item(L("Fovea Help Center"), #selector(openHelpCenter(_:)), "?", target: self),
            item(L("What's New in Fovea"), #selector(openWhatsNew(_:)), "", target: self),
            .separator(),
            item(L("Getting Started"), #selector(showGettingStarted(_:)), "", target: self),
            .separator(),
            item(L("Report a Problem…"), #selector(reportProblem(_:)), "", target: self),
            item(L("Send Feedback…"), #selector(sendFeedback(_:)), "", target: self),
            item(L("Manage Subscription…"), #selector(manageSubscription(_:)), "", target: self),
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

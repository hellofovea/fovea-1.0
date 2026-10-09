import AppKit
import SwiftUI
import CapturesCore

// What other prototypes may use of Fovea Captures, and the only `package` declarations in it:
// the app's entry point (FoveaCapturesApp/main.swift), and the real Home in a window of its own,
// opened by Fovea Onboarding at the end of the first run with the practice captures on top.

/// The app, as main.swift ran it before Fovea Captures became a library.
@MainActor
package func runFoveaCapturesApp() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    CapturesApp.delegate = delegate // NSApplication keeps its delegate weakly.
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}

@MainActor
private enum CapturesApp {
    static var delegate: AppDelegate?
}

/// The real Home, in the window Fovea Captures opens (AppDelegate.applicationDidFinishLaunching),
/// with captures added to the top of the history. Their times should sit in the last three days
/// of `CapturesHome.now`, the sample library's clock, or the home page won't show them.
@MainActor
package final class CapturesHome {
    package let window: NSWindow
    private let model: CapturesModel
    private let libraryToolbarDelegate = LibraryToolbarDelegate()

    /// The sample library's "now": the time a new capture should be dated near.
    package static var now: Date { CapturesCore.Fixtures.now }

    /// `accent` and `glow` are `AccentChoice` and `GlowChoice` raw values ("green", "ocean"), as a
    /// first run chose them; anything else keeps Fovea's defaults. `words` join the dictionary as
    /// added by you (brought in from another dictation app, Oct 9): the word, and what it was heard as.
    package init(adding captures: [CapturesCore.Capture], accent: String? = nil, glow: String? = nil,
                 glowHue: Double? = nil, glowDrift: Bool? = nil, words: [(word: String, heardAs: String?)] = []) {
        let model = CapturesModel()
        var library = model.library
        library.captures = captures + library.captures
        let known = Set(library.dictionary.map { $0.word.lowercased() })
        let added = words.enumerated().filter { !known.contains($0.element.word.lowercased()) }.map { index, item in
            DictionaryWord(id: "imported-\(index)", word: item.word, heardAs: item.heardAs, source: .added, date: CapturesHome.now)
        }
        library.dictionary = added + library.dictionary
        model.library = library
        if let accent, let choice = AccentChoice(rawValue: accent) { model.accent = choice }
        if let glow, let choice = GlowChoice(rawValue: glow) { model.prefs.glow = choice }
        if let glowHue { model.prefs.glowHue = glowHue }
        if let glowDrift { model.prefs.glowDrift = glowDrift }
        self.model = model

        let hosting = NSHostingController(rootView: MainView().environment(model))
        hosting.sceneBridgingOptions = [.toolbars]
        hosting.sizingOptions = []
        window = NSWindow(contentRect: NSRect(origin: .zero, size: T.Layout.window),
                          styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.collectionBehavior.insert(.fullScreenNone)
        window.contentViewController = hosting
        window.title = "Fovea"
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.setContentSize(T.Layout.window)
        window.tabbingMode = .disallowed
        applyChrome()
    }

    /// The window's one size.
    package static var size: CGSize { T.Layout.window }

    /// Shows the window with its content's top-left at `origin` (screen coordinates, bottom-left
    /// origin as AppKit's), or centered on the main screen.
    package func show(contentOrigin origin: CGPoint? = nil) {
        if let origin {
            let content = NSRect(origin: origin, size: T.Layout.window)
            window.setFrame(window.frameRect(forContentRect: content), display: true)
        } else if let screen = NSScreen.main {
            let v = screen.visibleFrame
            let x = v.minX + max(12, (v.width - T.Layout.window.width) / 2)
            let y = v.minY + max(0, (v.height - T.Layout.window.height) / 2)
            window.setFrame(window.frameRect(forContentRect: NSRect(origin: CGPoint(x: x, y: y), size: T.Layout.window)),
                            display: true)
        }
        window.makeKeyAndOrderFront(nil)
    }

    /// The same chrome as AppDelegate.applyChrome, for the model's default design.
    private func applyChrome() {
        let own = model.surface != .system || model.layout == .library || model.pageStyle == .inset
        window.titlebarAppearsTransparent = own
        window.titlebarSeparatorStyle = own ? .none : .automatic
        if model.layout == .library {
            let toolbar = NSToolbar(identifier: "CapturesHome.library")
            toolbar.delegate = libraryToolbarDelegate
            toolbar.showsBaselineSeparator = false
            toolbar.allowsUserCustomization = false
            window.toolbar = toolbar
        }
    }
}

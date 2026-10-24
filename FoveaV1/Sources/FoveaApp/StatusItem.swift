import AppKit
import FoveaKit
import FoveaStore
import FoveaIsland

// The menu bar's icon (Oct 15 review, NH-01 and NH-02; AGENTS.md's first surface): the one sign
// Fovea is alive when the window is closed and the notch is at rest, and the way back to it. One
// mark, the fo's eye (Brand/SOURCES.md), in three states: at rest, listening, and an agent that
// needs you. Its menu says whether Fovea can reach its servers, shows the person's own shortcuts,
// and opens Home, Settings, updates, or quits. With Show in Dock off, it's the only way in.

@MainActor
final class StatusItem: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let prefs: PrefsStore
    private var activity: IslandActivity = .idle
    var openHome: () -> Void = {}
    var openSettings: (String?) -> Void = { _ in }
    var checkForUpdates: () -> Void = {}
    var quit: () -> Void = {}
    /// Oct 23, Ryan: what the notch is doing, in words, read as the menu opens (the island's).
    var describe: () -> String? = { nil }
    /// Whether Fovea's servers answer. 1.0 has none, so it says it can (simulated); a review stage
    /// shows the other.
    var reachable = true { didSet { item.menu?.update() } }

    init(prefs: PrefsStore) {
        self.prefs = prefs
        super.init()
        item.button?.toolTip = "Fovea"
        item.button?.setAccessibilityLabel("Fovea")
        let menu = NSMenu(title: "Fovea")
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        draw()
        Review.stage("NH-01", "Menu bar: an agent needs you", area: .menuBar) { [weak self] in self?.show(.needsYou) }
        Review.stage("NH-01", "Menu bar: listening", area: .menuBar) { [weak self] in self?.show(.listening) }
        Review.stage("NH-01", "Menu bar: at rest", area: .menuBar) { [weak self] in self?.show(.idle) }
        Review.stage("NH-02", "Menu bar: can't reach Fovea", area: .menuBar) { [weak self] in
            self?.reachable = false
            self?.item.button?.performClick(nil)
        }
        Review.stage("NH-02", "Menu bar: connected again", area: .menuBar) { [weak self] in self?.reachable = true }
    }

    func show(_ activity: IslandActivity) {
        self.activity = activity
        draw()
    }

    // MARK: The icon

    private func draw() {
        guard let button = item.button else { return }
        button.image = Self.image(for: activity)
        switch activity {
        case .idle: button.toolTip = "Fovea"
        case .listening: button.toolTip = L("Fovea is listening")
        case .working: button.toolTip = L("Fovea · an agent is working")
        case .needsYou: button.toolTip = L("Fovea · an agent needs you")
        }
    }

    /// The eye, as a template image (the menu bar tints it): at rest as drawn; listening, the eye
    /// filled; working, a small dot beside it; needing you, the dot larger. Drawn, so the states
    /// stay one mark.
    static func image(for activity: IslandActivity) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let base = FoveaFiles.url("Brand/fovea-menubar-36.png").flatMap(NSImage.init(contentsOf:))
        let image = NSImage(size: size, flipped: false) { rect in
            let eye = NSRect(x: 2, y: 2, width: 14, height: 14)
            if activity == .listening {
                NSColor.black.setFill()
                NSBezierPath(ovalIn: eye.insetBy(dx: 1, dy: 1)).fill()
            } else if let base {
                base.draw(in: eye)
            } else {
                NSColor.black.setStroke()
                let ring = NSBezierPath(ovalIn: eye.insetBy(dx: 1.5, dy: 1.5))
                ring.lineWidth = 2
                ring.stroke()
            }
            if activity == .working || activity == .needsYou {
                let d: CGFloat = activity == .needsYou ? 6 : 4
                // A gap round the dot, so it reads apart from the eye.
                NSGraphicsContext.current?.compositingOperation = .clear
                NSBezierPath(ovalIn: NSRect(x: rect.maxX - d - 2, y: rect.maxY - d - 2, width: d + 2, height: d + 2)).fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
                NSColor.black.setFill()
                NSBezierPath(ovalIn: NSRect(x: rect.maxX - d - 1, y: rect.maxY - d - 1, width: d, height: d)).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: The menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let status: String
        switch (reachable, activity) {
        case (false, _): status = L("Can't reach Fovea. Check your connection.")
        case (_, .listening): status = describe() ?? L("Listening")
        case (_, .needsYou): status = describe() ?? L("An agent needs you")
        case (_, .working): status = describe() ?? L("An agent is working")
        case (_, .idle): status = describe() ?? L("Fovea is ready")
        }
        menu.addItem(disabled(status))
        menu.addItem(.separator())
        // The person's own keys (they can be changed now), as Settings › Shortcuts shows them.
        for shortcut in FoveaKeys.daily {
            let caps = FoveaKeys.chord(shortcut.id, prefs.prefs)?.caps ?? []
            let keys = caps.isEmpty ? L("Off") : caps.joined(separator: " ")
            menu.addItem(disabled("\(shortcut.title)    \(keys)"))
        }
        menu.addItem(.separator())
        menu.addItem(action(L("Open Fovea"), key: "") { [weak self] in self?.openHome() })
        menu.addItem(action(L("Settings…"), key: ",") { [weak self] in self?.openSettings(nil) })
        menu.addItem(action(L("Check for Updates…"), key: "") { [weak self] in self?.checkForUpdates() })
        menu.addItem(.separator())
        menu.addItem(action(L("Quit Fovea"), key: "q") { [weak self] in self?.quit() })
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, key: String, _ run: @escaping @MainActor () -> Void) -> NSMenuItem {
        let item = ClosureMenuItem(title: title, keyEquivalent: key, run: run)
        item.isEnabled = true
        return item
    }
}

/// A menu item that runs a closure.
@MainActor
final class ClosureMenuItem: NSMenuItem {
    private let run: @MainActor () -> Void
    init(title: String, keyEquivalent: String = "", run: @escaping @MainActor () -> Void) {
        self.run = run
        super.init(title: title, action: #selector(fire(_:)), keyEquivalent: keyEquivalent)
        target = self
    }
    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }
    @objc private func fire(_ sender: Any?) { run() }
}

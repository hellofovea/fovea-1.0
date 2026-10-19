import AppKit
import FoveaKit

// The Oct 15 review's own menu (FoveaKit/Review.swift, docs/v1/REVIEW_2026-10-15.md): every state
// the review added that using the app wouldn't show on demand, by where it lives, in the order of
// a walk through Fovea. Shown with `--review` only; never in the design itself.

@MainActor
final class ReviewMenu: NSObject, NSMenuDelegate {
    private var menu = NSMenu(title: "Review")
    private var installed = false

    /// Adds the Review menu before Help, with `--review`.
    func install(in main: NSMenu) {
        guard CommandLine.arguments.contains("--review"), !installed else { return }
        installed = true
        menu.delegate = self
        let item = NSMenuItem(title: "Review", action: nil, keyEquivalent: "")
        item.submenu = menu
        main.insertItem(item, at: max(0, main.items.count - 1))
    }

    /// Again into a menu built anew (the language changed).
    func reinstall(in main: NSMenu) {
        installed = false
        menu = NSMenu(title: "Review")
        install(in: main)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let header = NSMenuItem(title: "Show a state the review added:", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for area in Review.Area.allCases {
            let stages = Review.stages.filter { $0.area == area }
            guard !stages.isEmpty else { continue }
            let sub = NSMenu(title: area.rawValue)
            for stage in stages {
                sub.addItem(ClosureMenuItem(title: "\(stage.id)  ·  \(stage.title)") { stage.run() })
            }
            let item = NSMenuItem(title: "\(area.rawValue) (\(stages.count))", action: nil, keyEquivalent: "")
            item.submenu = sub
            menu.addItem(item)
        }
    }
}

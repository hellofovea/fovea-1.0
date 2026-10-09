import AppKit
import SwiftUI
import WindowBenchCore

/// `--smoke`: drives the bench through its rules on the live windows and exits 0 when every
/// check passes. Uses its own throwaway defaults suite, never Ryan's saved choices.
@MainActor
enum BenchSmoke {
    private static var failures = 0

    private static func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
        print(ok ? "ok    \(name)" : "FAIL  \(name) \(detail())")
        if !ok { failures += 1 }
    }

    /// The menu items allowed a key equivalent: the system's Hide, Quit, Close and Minimize,
    /// and the Edit verbs text fields need. AppKit's own tiling items are system's and allowed.
    static let allowed: Set<String> = ["⌘H", "⌥⌘H", "⌘Q", "⌘W", "⌥⌘W", "⌘M", "⌘Z", "⇧⌘Z", "⌘X", "⌘C", "⌘V", "⌘A"]

    static func run(app: BenchAppDelegate) async -> Bool {
        let model = app.model!
        await BenchSnapshots.settle(1.0)
        model.finishOnboarding()

        // Keys: the menu holds only the allowlist, and nothing else answers a key.
        for menu in NSApp.mainMenu?.items.compactMap(\.submenu) ?? [] {
            menu.delegate?.menuNeedsUpdate?(menu)
            menu.update()
        }
        let shortcuts = BenchMenu.keyEquivalents().map { BenchMenu.describe($0.key, $0.modifiers) }
        let extra = shortcuts.filter { !allowed.contains($0) && !$0.hasPrefix("fn ") && !$0.hasPrefix("⌃fn") }
        check("menu shortcuts are only the system's", extra.isEmpty, "extra: \(extra)")
        check("Settings… has no ⌘,", !shortcuts.contains("⌘,"))

        let window = app.main.window!
        model.goToProject("p-site")
        await BenchSnapshots.settle(0.3)
        let before = model.state
        for (key, flags) in [(",", NSEvent.ModifierFlags.command), ("f", .command), ("k", .command), ("1", .command),
                             ("[", .command), ("g", .command)] {
            if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                                            windowNumber: window.windowNumber, context: nil, characters: key,
                                            charactersIgnoringModifiers: key, isARepeat: false, keyCode: 0) {
                let handled = NSApp.mainMenu?.performKeyEquivalent(with: event) ?? false
                check("⌘\(key.uppercased()) does nothing", !handled)
            }
        }
        for (name, code, chars) in [("Esc", UInt16(53), "\u{1b}"), ("Return", 36, "\r"), ("Left arrow", 123, "\u{F702}"),
                                    ("Up arrow", 126, "\u{F700}")] {
            if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                            windowNumber: window.windowNumber, context: nil, characters: chars,
                                            charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code) {
                window.sendEvent(event)
            }
            await BenchSnapshots.settle(0.15)
            check("\(name) leaves the window where it was", model.state.projectPath == before.projectPath)
        }

        // Settings: the ⚙ and the status bar open it, on the right tab.
        model.openSettings(.connections)
        await BenchSnapshots.settle(0.6)
        check("the status bar opens Settings on Connections", app.settings.window?.isVisible == true && app.settings.selectedTab == .connections)
        model.openSettings(.general)
        await BenchSnapshots.settle(0.3)
        check("⚙ opens Settings on General", app.settings.selectedTab == .general)
        app.settings.window?.orderOut(nil)

        // The panel never takes key.
        check("the panel can't become key or main", !app.panel.panel.canBecomeKey && !app.panel.panel.canBecomeMain)
        app.main.window?.makeKeyAndOrderFront(nil)

        // Every route renders.
        for route in ["projects", "projects/p-site", "run/r-bullets", "run/r-deploy", "run/r-rate", "captures"] {
            model.apply(route: route)
            await BenchSnapshots.settle(0.25)
            check("route \(route)", model.path.last != nil)
        }

        // Drill in and back out lands where it started.
        model.show([PathEntry(level: .projects)], section: .project)
        await BenchSnapshots.settle(0.3)
        model.drill(into: .project("p-site"), from: "project/p-site")
        await model.motion.sleep(1.0)
        check("drill in", model.currentLevel == .project("p-site"))
        model.back()
        await model.motion.sleep(1.0)
        check("drill out lands on the list", model.currentLevel == .projects && model.transition == nil)

        // Every option of every decision draws without trouble.
        let saved = model.state.variants
        for decision in Variants.all {
            for option in decision.options {
                model.setVariant(id: decision.id, option: option.id)
                await BenchSnapshots.settle(0.02)
            }
        }
        model.state.variants = saved
        check("every variant cycles (\(Variants.all.count) decisions)", true)

        // A Go to that also opens a fold draws it open: the page it opens exists before the
        // fold changes, so the row hears the change (what the row drew, not what the model says).
        model.show([PathEntry(level: .projects)], section: .project)
        await BenchSnapshots.settle(0.3)
        model.goToProject("p-site")
        model.openFold = "earlier/t-copy"
        await BenchSnapshots.settle(0.5)
        let fold = ThreadRuns.earlierTitle(ThreadRuns.split(model.index.runs(in: "t-copy")).earlier.count)
        check("a fold opened with a Go to draws open", model.drawnFolds[fold] == true, "\(model.drawnFolds)")

        // A fixture change, then a Go to into onboarding, draws onboarding (the content area hears
        // the step even when the page was rebuilt between the two changes).
        model.loadFixture(.errors)
        model.goTo(onboarding: .scanning)
        await BenchSnapshots.settle(0.5)
        check("a fixture change then a Go to draws its step", model.drawnOnboarding == .scanning,
              "\(String(describing: model.drawnOnboarding))")
        model.loadFixture(.typical)
        model.finishOnboarding()
        await BenchSnapshots.settle(0.3)

        // Folds open one at a time.
        model.goToProject("p-site")
        model.toggleFold("earlier/t-copy")
        model.toggleFold("earlier/t-hero")
        await model.motion.sleep(0.8)
        check("one fold open at a time", model.openFold == "earlier/t-hero")

        // The route survives a new launch (through the smoke run's own store).
        model.goToRun("r-bullets")
        await BenchSnapshots.settle(0.6)
        let reloaded = BenchModel(options: BenchOptions(smoke: false), store: BenchStore.smokeReader())
        check("route survives a relaunch", reloaded.state.projectPath == model.state.projectPath,
              "\(reloaded.state.projectPath.map(\.id)) vs \(model.state.projectPath.map(\.id))")

        // The jump from search lands with a highlight, and the screen shows the page, not the
        // results (the field's end-of-editing commit once brought them back).
        model.search = SearchUI(expanded: true, query: SearchQuery(text: "bullets"), presented: true)
        await BenchSnapshots.settle(0.3)
        model.drawnNoResults = []
        if let hit = model.searchHits.first(where: { $0.targetID == "r-bullets" }) { model.open(hit) }
        await BenchSnapshots.settle(0.6)
        check("search jumps to the run's project with a highlight",
              model.currentLevel == .project("p-site") && model.highlight?.key == "run/t-copy/r-bullets" && !model.drawnSearchResults,
              "level \(model.currentLevel) results drawn \(model.drawnSearchResults)")
        // The results fade out as they were: never "No results" for the query the jump cleared.
        check("a jump never draws No results", model.drawnNoResults.isEmpty, "drew \(model.drawnNoResults)")

        // A jump across sections: View in Project lands on the run, washed, with the stream gone.
        model.goToCapture("c-site-shot")
        await BenchSnapshots.settle(0.4)
        model.viewInProject("c-site-shot")
        await BenchSnapshots.settle(0.6)
        check("View in Project lands on the run", model.state.section == .project && model.currentLevel == .project("p-site")
              && model.highlight?.key == "run/t-copy/r-bullets" && !model.sectionLeaving,
              "section \(model.state.section) level \(model.currentLevel) highlight \(model.highlight?.key ?? "nil")")

        // Every Play that stays in the window runs from its start without trouble.
        for scenario in BenchRecorder.scenarios where !scenario.leavesWindow {
            if let prepare = scenario.prepare {
                prepare(model)
                await BenchSnapshots.settle(0.3)
            }
            scenario.run(model)
            await BenchSnapshots.settle(0.5)
        }
        app.settings.window?.orderOut(nil)
        model.playTask(nil)
        check("every Play runs (\(BenchRecorder.scenarios.filter { !$0.leavesWindow }.count) in the window)", true)

        // Onboarding never merges on its own.
        let projects = model.library.projects.count
        model.goTo(onboarding: .merge)
        await BenchSnapshots.settle(0.4)
        check("merge waits for a click", model.library.projects.count == projects && model.bannerMerge != nil || model.inlineMerge != nil)
        model.finishOnboarding()

        print(failures == 0 ? "smoke: all checks passed" : "smoke: \(failures) failed")
        return failures == 0
    }

}

extension BenchStore {
    /// Reads what the smoke run saved, without clearing it.
    static func smokeReader() -> BenchStore {
        let defaults = UserDefaults(suiteName: "windowbench.smoke") ?? .standard
        return BenchStore(load: {
            guard let data = defaults.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(BenchState.self, from: data)
        }, save: { _ in })
    }
}

import AppKit
import SwiftUI
import WindowBenchCore

/// `--snapshot <dir> [--only <substring>]`: every page and state, Light and Dark, written as
/// the window server composites the windows (toolbar, materials and traffic lights included).
/// Fixtures only and a fixed clock, so no real project name ever lands in a shot.
@MainActor
enum BenchSnapshots {
    struct Shot {
        var name: String
        var dark = false
        var size: WindowSizePreset = .large
        /// Which windows to capture: the Fovea window, Settings, or the window with the panel.
        enum Target { case window, settings(SettingsTab), windowAndPanel, panel, compare
            /// The window with one of its own menus open (the menu's first item, as a title).
            case windowWithMenu(String) }
        var target: Target = .window
        var variants: [String: String] = [:]
        var settle: Double = 0.7
        var setup: (BenchModel) -> Void = { _ in }
    }

    static var shots: [Shot] {
        var list: [Shot] = []
        for dark in [false, true] {
            let suffix = dark ? "-dark" : ""
            list.append(Shot(name: "shell-panel\(suffix)", dark: dark, size: .fit, target: .windowAndPanel) { m in m.finishOnboarding() })
        }
        return list + pageShots
    }

    /// Pages add their shots here as they're built.
    static var pageShots: [Shot] { onboardingShots + projectListShots + projectPageShots + settingsShots + runDetailShots + captureShots + polishShots + searchShots }

    static var polishShots: [Shot] {
        var list: [Shot] = []
        for dark in [false, true] {
            let d = dark ? "-dark" : ""
            list.append(Shot(name: "07-memory\(d)", dark: dark, target: .settings(.memory)))
            list.append(Shot(name: "07-notch-lanes\(d)", dark: dark, target: .settings(.notch)))
        }
        list.append(Shot(name: "07-notch-agenda", target: .settings(.notch), variants: ["todayTimeline": "agenda"]))
        // The rest of Settings › Notch: what to include, meeting alerts, presets.
        list.append(Shot(name: "07-notch-include", target: .settings(.notch)) { m in
            m.today.hiddenProjects = ["p-mac"]; m.settingsScrollTarget = "include" })
        list.append(Shot(name: "07-notch-alerts", target: .settings(.notch)) { m in m.settingsScrollTarget = "alerts" })
        list.append(Shot(name: "07-notch-alerts-dark", dark: true, target: .settings(.notch)) { m in m.settingsScrollTarget = "alerts" })
        list.append(Shot(name: "07-memory-forgotten", target: .settings(.memory)) { $0.forget("m-second") })
        list.append(Shot(name: "07-brief-writing", settle: 0.5) { m in m.goToProject("p-site"); m.briefs["p-site"] = .writing })
        return list
    }

    static var searchShots: [Shot] {
        var list: [Shot] = []
        for dark in [false, true] {
            let d = dark ? "-dark" : ""
            list.append(Shot(name: "05-results\(d)", dark: dark) { m in m.finishOnboarding(); m.goToSearch("第二屏") })
        }
        list.append(Shot(name: "05-field-open") { m in m.finishOnboarding(); m.goToSearch(nil) })
        list.append(Shot(name: "05-dropdown", variants: ["searchResults": "dropdown"]) { m in m.finishOnboarding(); m.goToSearch("bullets") })
        list.append(Shot(name: "05-chips") { m in
            m.finishOnboarding(); m.search.query.scopes = [.runs]; m.search.query.agent = .codex; m.goToSearch("Second") })
        list.append(Shot(name: "05-native", variants: ["searchField": "native"]) { m in m.finishOnboarding(); m.goToSearch("Second.tsx") })
        list.append(Shot(name: "05-no-results") { m in m.finishOnboarding(); m.goToSearch("kubernetes") })
        // Text read off a screenshot, and an old project's hit ranked under the live ones.
        list.append(Shot(name: "05-screen-text") { m in m.finishOnboarding(); m.goToSearch("requests per second") })
        list.append(Shot(name: "05-sunk-last") { m in m.finishOnboarding(); m.goToSearch("site") })
        list.append(Shot(name: "05-jump-landed", settle: 0.5) { m in
            m.finishOnboarding()
            m.search = SearchUI(expanded: true, query: SearchQuery(text: "bullets"), presented: true)
            if let hit = m.searchHits.first(where: { $0.targetID == "r-bullets" }) { m.open(hit) } })
        // The filter menu open in the field: scopes, an agent, a date.
        list.append(Shot(name: "05-filter-menu", target: .windowWithMenu("Projects")) { m in m.finishOnboarding(); m.goToSearch("bullets") })
        // A result under the pointer, and the smaller window.
        list.append(Shot(name: "05-hover") { m in m.finishOnboarding(); m.goToSearch("bullets"); m.hoverKey = "hit/runs/r-bullets" })
        list.append(Shot(name: "05-results-compact", size: .compact) { m in m.finishOnboarding(); m.goToSearch("第二屏") })
        return list
    }

    static var captureShots: [Shot] {
        var list: [Shot] = []
        let stream: (BenchModel) -> Void = { $0.show([PathEntry(level: .captures)], section: .capture) }
        for layout in ["notes", "list", "cards", "hybrid"] {
            for dark in [false, true] {
                list.append(Shot(name: "06-\(layout)\(dark ? "-dark" : "")", dark: dark, variants: ["captureLayout": layout], setup: stream))
            }
        }
        list.append(Shot(name: "06-filter-voice") { m in m.show([PathEntry(level: .captures)], section: .capture); m.captureFilter = .voice })
        list.append(Shot(name: "06-filter-selections") { m in m.show([PathEntry(level: .captures)], section: .capture); m.captureFilter = .selection })
        list.append(Shot(name: "06-filter-files") { m in m.show([PathEntry(level: .captures)], section: .capture); m.captureFilter = .file })
        list.append(Shot(name: "06-hover") { m in m.show([PathEntry(level: .captures)], section: .capture); m.hoverKey = "capture/c-site-shot" })
        list.append(Shot(name: "06-detail-selection") { $0.goToCapture("c-draft") })
        list.append(Shot(name: "06-long") { m in m.loadFixture(.longNames); m.show([PathEntry(level: .captures)], section: .capture) })
        list.append(Shot(name: "06-filter-screenshots") { m in m.show([PathEntry(level: .captures)], section: .capture); m.captureFilter = .screenshot })
        list.append(Shot(name: "06-detail") { $0.goToCapture("c-site-shot") })
        list.append(Shot(name: "06-detail-voice") { $0.goToCapture("c-hero-voice") })
        list.append(Shot(name: "06-quicklook", variants: ["captureDetail": "quickLook"]) { m in
            m.show([PathEntry(level: .captures)], section: .capture); m.quickLook = "c-ears-1" })
        list.append(Shot(name: "06-empty") { m in m.loadFixture(.empty); m.show([PathEntry(level: .captures)], section: .capture) })
        // The jumps both ways: View in Project lands on the run, washed; a run's captures link
        // lands on its first capture in the stream, washed.
        list.append(Shot(name: "06-view-in-project", settle: 0.75) { m in m.goToCapture("c-site-shot"); m.viewInProject("c-site-shot") })
        list.append(Shot(name: "06-from-run", settle: 0.75) { m in m.goToProject("p-site"); m.showCaptures(of: "r-bullets") })
        list.append(Shot(name: "06-notes-compact", size: .compact, setup: stream))
        return list
    }

    static var runDetailShots: [Shot] {
        var list: [Shot] = []
        for dark in [false, true] {
            let d = dark ? "-dark" : ""
            list.append(Shot(name: "04-code\(d)", dark: dark) { $0.goToRun("r-bullets") })
        }
        for diff in ["monoUnified", "tinted", "split"] {
            list.append(Shot(name: "04-diff-\(diff)", variants: ["diff": diff]) { $0.goToRun("r-ears") })
        }
        // Word emphasis is off by default (the -monoUnified still); here it is on.
        list.append(Shot(name: "04-diff-words-on", variants: ["diffWords": "on"]) { $0.goToRun("r-ears") })
        list.append(Shot(name: "04-text") { $0.goToRun("r-notes") })
        list.append(Shot(name: "04-image") { $0.goToRun("r-photo") })
        list.append(Shot(name: "04-external") { $0.goToRun("r-review") })
        list.append(Shot(name: "04-external-live") { m in m.simulateScreenRecording = true; m.goToRun("r-review") })
        list.append(Shot(name: "04-code-compact", size: .compact) { $0.goToRun("r-bullets") })
        list.append(Shot(name: "04-chip-hover") { m in m.goToRun("r-bullets"); m.runScrollTarget = "captures/r-bullets"; m.hoverKey = "chip/c-site-shot" })
        // Long words: the header wraps, the signed sentence wraps, nothing overflows the measure.
        list.append(Shot(name: "04-long") { m in m.loadFixture(.longNames); m.goToRun("r-bullets") })
        list.append(Shot(name: "04-attempts-open") { m in m.goToRun("r-bullets"); m.openFold = "attempts/r-bullets" })
        list.append(Shot(name: "04-output-open") { m in m.goToRun("r-bullets"); m.openFold = "output/r-bullets" })
        list.append(Shot(name: "04-failed") { $0.goToRun("r-rate") })
        list.append(Shot(name: "04-running") { $0.goToRun("r-hero") })
        list.append(Shot(name: "04-unobserved") { $0.goToRun("r-dark") })
        list.append(Shot(name: "04-question") { $0.goToRun("r-email") })
        return list
    }

    static var settingsShots: [Shot] {
        var list: [Shot] = []
        for dark in [false, true] {
            let d = dark ? "-dark" : ""
            list.append(Shot(name: "03-general\(d)", dark: dark, target: .settings(.general)))
            list.append(Shot(name: "03-connections\(d)", dark: dark, target: .settings(.connections)))
        }
        // The brief's ●●●○ reading: filled for connected, ring for hooks missing (errors fixture shows all three).
        list.append(Shot(name: "03-connections-filled-glyphs", target: .settings(.connections), variants: ["connectionGlyphs": "brief"]) { m in
            m.loadFixture(.errors) })
        list.append(Shot(name: "03-connections-raw-always", target: .settings(.connections), variants: ["hooksDetail": "always"]) { m in
            m.settingsScrollTarget = "hooks/claudeCode" })
        list.append(Shot(name: "03-connections-other-notch", target: .settings(.connections)) { m in
            m.state.otherNotchApp = true; m.settingsScrollTarget = "other-notch" })
        // Remove restores the file and says so; the agent then needs you again.
        list.append(Shot(name: "03-connections-removed", target: .settings(.connections)) { m in
            m.hooks[.claudeCode] = .restored(BenchFixtures.now.addingTimeInterval(-600)); m.settingsScrollTarget = "hooks/claudeCode" })
        list.append(Shot(name: "03-connections-calendar-allowed", target: .settings(.connections)) { m in
            m.state.calendarGranted = true; m.settingsScrollTarget = "calendar" })
        list.append(Shot(name: "03-connections-calendar-denied", target: .settings(.connections)) { m in
            m.state.calendarDenied = true; m.settingsScrollTarget = "calendar" })
        list.append(Shot(name: "03-general-fn-conflict", target: .settings(.general)) { m in m.simulateFnConflict = true })
        list.append(Shot(name: "03-connections-errors", target: .settings(.connections)) { m in m.loadFixture(.errors) })
        list.append(Shot(name: "03-connections-errors-history", target: .settings(.connections)) { m in
            m.loadFixture(.errors); m.settingsScrollTarget = "history" })
        list.append(Shot(name: "03-connections-errors-dark", dark: true, target: .settings(.connections)) { m in m.loadFixture(.errors) })
        // Codex's hooks after install: written, but skipped until trusted inside Codex.
        list.append(Shot(name: "03-connections-codex-untrusted", target: .settings(.connections)) { m in
            m.hooks[.codex] = .untrusted(BenchFixtures.now.addingTimeInterval(-86_400 - 5 * 3600)); m.settingsScrollTarget = "hooks/codex" })
        return list
    }

    static var projectPageShots: [Shot] {
        var list: [Shot] = []
        let site: (BenchModel) -> Void = { $0.goToProject("p-site") }
        for dark in [false, true] {
            let d = dark ? "-dark" : ""
            list.append(Shot(name: "02b-page\(d)", dark: dark, setup: site))
            list.append(Shot(name: "02c-run\(d)", dark: dark) { $0.goToRun("r-bullets") })
        }
        list.append(Shot(name: "02b-page-earlier-open", settle: 1.0) { m in m.goToProject("p-site"); m.openFold = "earlier/t-copy" })
        list.append(Shot(name: "02b-hover-run") { m in m.goToProject("p-site"); m.hoverKey = "run/t-copy/r-bullets" })
        list.append(Shot(name: "02b-compact-window", size: .compact, setup: site))
        list.append(Shot(name: "02c-compact-window", size: .compact) { $0.goToRun("r-bullets") })
        list.append(Shot(name: "02b-page-codex-header", variants: ["threadHeader": "codex"], setup: site))
        list.append(Shot(name: "02b-page-large-header", variants: ["threadHeader": "large"], setup: site))
        list.append(Shot(name: "02b-page-two-lines", variants: ["runRow": "twoLines"], setup: site))
        list.append(Shot(name: "02b-page-words", variants: ["stateStyle": "wordTint"], setup: site))
        list.append(Shot(name: "02b-page-largetitle", variants: ["breadcrumb": "largeTitle"], setup: site))
        list.append(Shot(name: "02b-page-pill", variants: ["breadcrumb": "pill"], setup: site))
        list.append(Shot(name: "02b-page-toolbarback", variants: ["breadcrumb": "toolbarBack"], setup: site))
        for style in ["native", "notch", "inline"] {
            list.append(Shot(name: "02b-correction-\(style)", variants: ["correction": style], settle: 1.0) { m in
                m.goToProject("p-site"); m.correction = "thread/t-copy" })
        }
        list.append(Shot(name: "02b-brief", settle: 1.0) { m in m.goToProject("p-site"); m.briefs["p-site"] = .written })
        list.append(Shot(name: "02b-page-api") { $0.goToProject("p-api") })
        for surface in ["paper", "system"] {
            list.append(Shot(name: "02c-run-\(surface)", variants: ["receiptSurface": surface]) { $0.goToRun("r-bullets") })
        }
        for (id, name) in [("r-deploy", "permission"), ("r-email", "question"), ("r-rate", "failed"), ("r-hero", "running"),
                           ("r-dark", "unobserved"), ("r-ears", "differences")] {
            list.append(Shot(name: "02c-\(name)") { $0.goToRun(id) })
        }
        return list
    }

    static var onboardingShots: [Shot] {
        var list: [Shot] = []
        for dark in [false, true] {
            let d = dark ? "-dark" : ""
            list.append(Shot(name: "01-consent\(d)", dark: dark) { $0.goTo(onboarding: .consent) })
            list.append(Shot(name: "01-scanning\(d)", dark: dark) { $0.goTo(onboarding: .scanning) })
            list.append(Shot(name: "01-reveal\(d)", dark: dark) { $0.goTo(onboarding: .reveal) })
            list.append(Shot(name: "01-merge-banner\(d)", dark: dark) { $0.goTo(onboarding: .merge) })
            list.append(Shot(name: "01-nothing\(d)", dark: dark) { $0.goTo(onboarding: .nothingFound) })
            list.append(Shot(name: "01-handoff\(d)", dark: dark) { $0.goTo(onboarding: .handoff) })
        }
        list.append(Shot(name: "01-merge-inline", variants: ["merge": "inline"]) { $0.goTo(onboarding: .merge) })
        // After the choice: Merge says what it did, with Undo; Keep separate leaves both, with no trace.
        list.append(Shot(name: "01-merged-undo") { m in
            m.goTo(onboarding: .merge); if let s = m.bannerMerge { m.merge(s) } })
        list.append(Shot(name: "01-kept-separate") { m in
            m.goTo(onboarding: .merge); if let s = m.bannerMerge { m.keepSeparate(s) } })
        list.append(Shot(name: "01-scanning-ring", variants: ["scanProgress": "ring"]) { $0.goTo(onboarding: .scanning) })
        list.append(Shot(name: "01-scanning-hairline", variants: ["scanProgress": "hairline"]) { $0.goTo(onboarding: .scanning) })
        // A history folder the scan can't list: dashed, with why, during the scan and after it.
        list.append(Shot(name: "01-scanning-read-error") { m in m.loadFixture(.errors); m.goTo(onboarding: .scanning) })
        list.append(Shot(name: "01-scanning-read-error-dark", dark: true) { m in m.loadFixture(.errors); m.goTo(onboarding: .scanning) })
        list.append(Shot(name: "01-reveal-read-error") { m in m.loadFixture(.errors); m.goTo(onboarding: .reveal) })
        // The smaller window and long names.
        list.append(Shot(name: "01-consent-compact", size: .compact) { $0.goTo(onboarding: .consent) })
        list.append(Shot(name: "01-reveal-compact", size: .compact) { $0.goTo(onboarding: .reveal) })
        list.append(Shot(name: "01-merge-inline-compact", size: .compact, variants: ["merge": "inline"]) { $0.goTo(onboarding: .merge) })
        list.append(Shot(name: "01-reveal-long") { m in m.loadFixture(.longNames); m.goTo(onboarding: .reveal) })
        return list
    }

    static var projectListShots: [Shot] {
        var list: [Shot] = []
        let done: (BenchModel) -> Void = { $0.finishOnboarding() }
        for dark in [false, true] {
            let d = dark ? "-dark" : ""
            list.append(Shot(name: "02a-list\(d)", dark: dark, setup: done))
            list.append(Shot(name: "02a-list-paper\(d)", dark: dark, variants: ["surface": "paper"], setup: done))
        }
        list.append(Shot(name: "02a-list-older-open") { m in m.goToOlderOpen() })
        list.append(Shot(name: "02a-hover") { m in m.finishOnboarding(); m.hoverKey = "project/p-site" })
        list.append(Shot(name: "02a-compact-window", size: .compact, setup: done))
        list.append(Shot(name: "02-list", target: .compare, setup: done))
        list.append(Shot(name: "02-run", target: .compare) { $0.goToRun("r-bullets") })
        list.append(Shot(name: "02a-list-words", variants: ["stateStyle": "wordTint"], setup: done))
        list.append(Shot(name: "02a-list-glyphword", variants: ["stateStyle": "glyphWord"], setup: done))
        list.append(Shot(name: "02a-list-drawn", variants: ["glyphDrawing": "drawn"], setup: done))
        list.append(Shot(name: "02a-list-hairlines", variants: ["groupLabels": "hairlineOnly"], setup: done))
        list.append(Shot(name: "02a-list-compact-macos", variants: ["density": "compact", "typeScale": "macOS"], setup: done))
        list.append(Shot(name: "02a-list-warm", variants: ["surface": "warm"], setup: done))
        list.append(Shot(name: "02a-list-failed-last", variants: ["failedPlacement": "last"], setup: done))
        list.append(Shot(name: "02a-list-heavy") { m in m.loadFixture(.heavy); m.finishOnboarding() })
        list.append(Shot(name: "02a-list-long") { m in m.loadFixture(.longNames); m.finishOnboarding() })
        // Long names a level down: the project's header and its runs, then a run.
        list.append(Shot(name: "02b-page-long") { m in m.loadFixture(.longNames); m.goToProject("p-site") })
        list.append(Shot(name: "02c-run-long") { m in m.loadFixture(.longNames); m.goToRun("r-deploy") })
        list.append(Shot(name: "02a-list-empty") { m in m.loadFixture(.empty); m.finishOnboarding() })
        return list
    }

    static func run(dir: URL, filter: String?, app: BenchAppDelegate) async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let model = app.model!
        await settle(1.0)
        let base = model.state
        for shot in shots where filter.map({ shot.name.contains($0) }) ?? true {
            // Every shot starts from the same place.
            model.state = base
            model.state.windowSize = shot.size
            model.state.appearance = shot.dark ? .dark : .light
            for (id, option) in shot.variants { model.setVariant(id: id, option: option) }
            model.loadFixture(.typical)
            model.search = SearchUI()
            model.openFold = nil
            model.correction = nil
            model.highlight = nil
            model.briefs = [:]
            model.hoverKey = nil
            model.quickLook = nil
            model.captureFilter = nil
            model.hooks = BenchModel.defaultHooks
            model.lastForgotten = nil
            model.lastMerge = nil
            model.simulateFnConflict = false
            model.simulateScreenRecording = false
            model.runScrollTarget = nil
            model.today = TodaySettings()
            model.settingsScrollTarget = nil
            app.applyAppearance()
            app.main.place(preset: shot.size, panelWidth: BenchTokens.Layout.panelWidth)
            app.panel.follow()
            // Let a popover from the last shot close before this one starts.
            await settle(0.3)
            shot.setup(model)
            model.heal()
            await settle(shot.settle)
            var windows: [NSWindow] = []
            switch shot.target {
            case .window:
                // A popover is a window of its own, above the Fovea window: front to back.
                let popovers = NSApp.windows.filter { $0.isVisible && String(describing: type(of: $0)).contains("Popover") }
                windows = popovers + [app.main.window!]
            case .compare, .windowWithMenu:
                windows = [app.main.window!]
            case .windowAndPanel:
                // Front to back: the panel sits above the window.
                windows = [app.panel.panel, app.main.window!]
            case .panel: windows = [app.panel.panel]
            case .settings(let tab):
                app.settings.show(tab)
                await settle(0.6)
                windows = [app.settings.window!]
            }
            app.main.window?.makeKeyAndOrderFront(nil)
            if case .settings = shot.target { app.settings.window?.makeKeyAndOrderFront(nil) }
            await settle(0.15)
            if case .compare = shot.target {
                writeCompare(windows, to: dir.appendingPathComponent("compare-\(shot.name).png"))
            } else if case .windowWithMenu(let item) = shot.target, let window = app.main.window {
                writeWithOpenMenu(window, item: item, to: dir.appendingPathComponent("window-\(shot.name).png"))
            } else {
                write(windows, to: dir.appendingPathComponent("window-\(shot.name).png"))
            }
            if case .settings = shot.target { app.settings.window?.orderOut(nil) }
        }
        model.state = base
    }

    /// The notch's own rows (a Notch Workbench shot) beside the window, no logo on either: the
    /// rubric's first criterion, judged side by side.
    static func writeCompare(_ windows: [NSWindow], to url: URL) {
        let shots = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("shots")
        guard let windowRep = composited(windows), let windowImage = windowRep.cgImage,
              let notchFile = NSImage(contentsOf: shots.appendingPathComponent("workbench-chats-project.png")),
              let notchFull = notchFile.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let notch = notchFull.cropping(to: CGRect(x: 1225, y: 280, width: 555, height: 560)) else {
            print("failed \(url.lastPathComponent)"); return
        }
        let height = windowImage.height
        // Both sides at the same points per pixel: the workbench draws its mock display scaled to
        // fit its column (WorkbenchModel.scale), and in this shot the notch's 28 pt rows measure
        // 36.7 px where the window's 2× capture draws 56.
        let notchScale = 56.0 / 36.7
        let notchWidth = Int(Double(notch.width) * notchScale)
        let notchHeight = min(height, Int(Double(notch.height) * notchScale))
        let gap = 40
        guard let context = CGContext(data: nil, width: notchWidth + gap + windowImage.width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: notchWidth + gap + windowImage.width, height: height))
        context.interpolationQuality = .high
        // Top-aligned, as the notch hangs from the top of the screen.
        context.draw(notch, in: CGRect(x: 0, y: height - notchHeight, width: notchWidth, height: notchHeight))
        context.draw(windowImage, in: CGRect(x: notchWidth + gap, y: 0, width: windowImage.width, height: height))
        guard let image = context.makeImage(), let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
        print("wrote \(url.lastPathComponent)")
    }

    /// Opens the window's own pop-up menu that holds `item` (the real menu, as a click opens
    /// it), draws the menu over the window while it's open, then closes it. Opening a menu runs
    /// its own event loop until it closes, so the capture is scheduled first and closes it.
    static func writeWithOpenMenu(_ window: NSWindow, item: String, to url: URL) {
        func views(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(views) }
        let root = window.contentView?.superview ?? NSView()
        // SwiftUI's Menu is a pop-up button that builds its items when clicked, so it's found by
        // kind (the only one in the toolbar); `item` is checked once the menu is open.
        guard let button = views(root).compactMap({ $0 as? NSControl })
                .first(where: { String(describing: type(of: $0)).contains("PopupButton") }) else {
            print("failed \(url.lastPathComponent): no pop-up button"); return
        }
        // A timer in the common modes: a menu's own event loop runs in event-tracking mode, which
        // the main queue isn't drained in.
        let timer = Timer(timeInterval: 0.6, repeats: false) { _ in
            let info = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
            let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
            let menus = info.filter { ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == getpid() && ($0[kCGWindowLayer as String] as? NSNumber)?.intValue == menuLevel }
                .compactMap { $0[kCGWindowNumber as String] as? CGWindowID }
            let ids = menus + [CGWindowID(window.windowNumber)]
            let values = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: ids.count)
            defer { values.deallocate() }
            for (i, id) in ids.enumerated() { values[i] = UnsafeRawPointer(bitPattern: UInt(id)) }
            if let array = CFArrayCreate(kCFAllocatorDefault, values, ids.count, nil),
               let image = CGImage(windowListFromArrayScreenBounds: .null, windowArray: array, imageOption: [.boundsIgnoreFraming, .bestResolution]),
               let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                try? data.write(to: url)
                print("wrote \(url.lastPathComponent) (\(menus.count) menu window\(menus.count == 1 ? "" : "s"))")
            } else {
                print("failed \(url.lastPathComponent)")
            }
            if let menu = button.menu, menu.items.contains(where: { $0.title == item }) {
                menu.cancelTracking()
            } else if let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                                     windowNumber: window.windowNumber, context: nil, characters: "\u{1b}",
                                                     charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53) {
                // The menu isn't reachable from here: close it as Escape would.
                NSApp.postEvent(escape, atStart: true)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        button.performClick(nil)
    }

    static func write(_ windows: [NSWindow], to url: URL) {
        guard let rep = composited(windows), let data = rep.representation(using: .png, properties: [:]) else {
            print("failed \(url.lastPathComponent)"); return
        }
        try? data.write(to: url)
        print("wrote \(url.lastPathComponent)")
    }

    /// Lets SwiftUI and AppKit draw: async, so the app's own tasks (staggers, scans) keep running.
    static func settle(_ seconds: Double) async {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            for window in NSApp.windows where window.isVisible {
                window.layoutIfNeeded()
                window.displayIfNeeded()
            }
            try? await Task.sleep(for: .milliseconds(40))
        }
    }

    /// Windows as the window server composites them (toolbar and materials included). An app
    /// may always capture its own windows; ScreenCaptureKit would ask for Screen Recording.
    static func composited(_ windows: [NSWindow]) -> NSBitmapImageRep? {
        let ids = windows.map { CGWindowID($0.windowNumber) }
        guard let first = ids.first else { return nil }
        let image: CGImage?
        if ids.count == 1 {
            image = CGWindowListCreateImage(.null, .optionIncludingWindow, first, [.boundsIgnoreFraming, .bestResolution])
        } else {
            // The array holds the window numbers themselves, not objects.
            let values = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: ids.count)
            defer { values.deallocate() }
            for (i, id) in ids.enumerated() { values[i] = UnsafeRawPointer(bitPattern: UInt(id)) }
            guard let array = CFArrayCreate(kCFAllocatorDefault, values, ids.count, nil) else { return nil }
            image = CGImage(windowListFromArrayScreenBounds: .null, windowArray: array, imageOption: [.boundsIgnoreFraming, .bestResolution])
        }
        return image.map(NSBitmapImageRep.init(cgImage:))
    }
}

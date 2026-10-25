import SwiftUI
import AppKit
import Carbon.HIToolbox
import FoveaCore

/// `FoveaWorkbench --smoke`: the checks a person makes on the live window, without a hand on
/// the mouse. Clicks the toolbar's toggle item, sends ⌃⌘S's action down the responder chain,
/// moves the divider through the split view, and reads the material, the remembered choice,
/// the menus and the mock display. One line per check; exits 0 when every check passes.
@MainActor
enum WorkbenchSmoke {
    private static var failures = 0

    static func runIfRequested(model: WorkbenchModel) {
        guard model.options.smoke else { return }
        Task { @MainActor in
            var waited = 0
            while window == nil, waited < 30 {
                try? await Task.sleep(for: .milliseconds(100))
                waited += 1
            }
            await run(model: model)
            print(failures == 0 ? "SMOKE PASS" : "SMOKE FAIL: \(failures) check(s)")
            exit(failures == 0 ? 0 : 1)
        }
    }

    private static var window: NSWindow? {
        NSApp.windows.first { $0.styleMask.contains(.titled) }
    }

    private static func check(_ name: String, _ condition: Bool, _ detail: String = "") {
        if !condition { failures += 1 }
        print("\(condition ? "ok  " : "FAIL") \(name)\(detail.isEmpty ? "" : "  (\(detail))")")
    }

    /// Lets the app's own run loop turn: layout, display, animations, and the main-actor
    /// tasks that pump the simulated microphone (a nested run loop would starve those).
    private static func settle(_ window: NSWindow, _ seconds: TimeInterval = 0.4) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    private static func run(model: WorkbenchModel) async {
        guard let window else { check("window", false, "no titled window"); return }
        window.setContentSize(WorkbenchTokens.Snapshot.size)
        window.makeKeyAndOrderFront(nil)
        model.columnVisibility = .all
        await settle(window)
        // `--smoke --only-native`: the Native design's checks alone (docs/island/NATIVE.md).
        if CommandLine.arguments.contains("--only-native") {
            await native(model: model, window: window, check: { check($0, $1, $2) }, settle: { await settle($0, $1) })
            return
        }

        // Chrome.
        check("window title", window.title == "Notch Workbench", window.title)
        check("unified toolbar", window.toolbar != nil && window.toolbarStyle == .unified)
        let items = window.toolbar?.items ?? []
        // SwiftUI installs its own item (com.apple.SwiftUI.navigationSplitView.toggleSidebar).
        let toggleItem = items.first { $0.itemIdentifier.rawValue.hasSuffix("toggleSidebar") }
        check("system sidebar toggle in the toolbar", toggleItem != nil,
              items.map(\.itemIdentifier.rawValue).joined(separator: ", "))

        // The split view.
        guard let root = window.contentView,
              let split = findSplit(in: root),
              let controller = split.delegate as? NSSplitViewController,
              let sidebar = controller.splitViewItems.first,
              let detail = controller.splitViewItems.last, controller.splitViewItems.count == 2 else {
            check("split view controller with two columns", false, "not found"); return
        }
        check("sidebar column behavior", sidebar.behavior == .sidebar)
        check("sidebar can collapse", sidebar.canCollapse)
        check("sidebar minimum", sidebar.minimumThickness == WorkbenchTokens.Layout.sidebarMin, "\(sidebar.minimumThickness)")
        check("sidebar maximum", sidebar.maximumThickness == WorkbenchTokens.Layout.sidebarMax, "\(sidebar.maximumThickness)")
        let opened = width(sidebar)
        check("sidebar open within its limits", opened >= WorkbenchTokens.Layout.sidebarMin && opened <= WorkbenchTokens.Layout.sidebarMax, "\(opened)")
        check("sidebar material", hasSidebarMaterial(in: root), "no NSVisualEffectView with .sidebar")

        // The divider: the limits a drag is clamped to.
        split.setPosition(300, ofDividerAt: 0); await settle(window, 0.2)
        check("divider moves to 300", abs(width(sidebar) - 300) < 1, "\(width(sidebar))")
        split.setPosition(900, ofDividerAt: 0); await settle(window, 0.2)
        check("divider clamps at the maximum", abs(width(sidebar) - WorkbenchTokens.Layout.sidebarMax) < 1, "\(width(sidebar))")
        split.setPosition(WorkbenchTokens.Layout.sidebarIdeal, ofDividerAt: 0); await settle(window, 0.2)

        // The toolbar button: what a click does.
        if let toggleItem {
            let how = press(toggleItem)
            await settle(window, 0.6)
            check("toggle button collapses the panel", sidebar.isCollapsed, how)
            check("collapse reaches the model", model.columnVisibility == .detailOnly, "\(model.columnVisibility.kindName)")
            check("collapse is remembered", UserDefaults.standard.bool(forKey: WorkbenchModel.sidebarKey) == false)
            _ = press(toggleItem)
            await settle(window, 0.6)
            check("toggle button reopens the panel", !sidebar.isCollapsed)
        }

        // ⌃⌘S: perform the View menu item itself, as the key equivalent would, from both states.
        let view = NSApp.mainMenu?.item(withTitle: "View")?.submenu
        let sidebarIndex = view?.items.firstIndex { $0.keyEquivalent == "s" && $0.keyEquivalentModifierMask == [.command, .control] }
        check("View menu has the ⌃⌘S sidebar item", sidebarIndex != nil,
              sidebarIndex.flatMap { view?.items[$0].action.map { String(describing: $0) } } ?? "missing")
        if let view, let sidebarIndex {
            model.columnVisibility = .all; await settle(window, 0.6)
            view.performActionForItem(at: sidebarIndex); await settle(window, 0.6)
            check("⌃⌘S collapses the panel", sidebar.isCollapsed)
            open(view)
            check("sidebar item title follows the state", view.items[sidebarIndex].title == "Show Sidebar", view.items[sidebarIndex].title)
            check("⌃⌘S collapse reaches the model", model.columnVisibility == .detailOnly, "\(model.columnVisibility.kindName)")
            check("collapse is remembered", UserDefaults.standard.bool(forKey: WorkbenchModel.sidebarKey) == false)
            view.performActionForItem(at: sidebarIndex); await settle(window, 0.6)
            check("⌃⌘S reopens the panel", !sidebar.isCollapsed)
            check("⌃⌘S reopen reaches the model", model.columnVisibility != .detailOnly, "\(model.columnVisibility.kindName)")
            check("reopen is remembered", UserDefaults.standard.bool(forKey: WorkbenchModel.sidebarKey) == true)
        }

        // The model drives the view too.
        model.columnVisibility = .detailOnly; await settle(window, 0.6)
        check("model collapses the panel", sidebar.isCollapsed)
        model.columnVisibility = .all; await settle(window, 0.6)
        check("model reopens the panel", !sidebar.isCollapsed)

        // The Window menu is filled when it opens.
        let windowMenu = NSApp.mainMenu?.item(withTitle: "Window")?.submenu
        if let windowMenu { open(windowMenu) }
        let titles = windowMenu?.items.map(\.title).filter { !$0.isEmpty } ?? []
        check("Window menu lists the workbench once", titles.filter { $0 == "Notch Workbench" }.count == 1, titles.joined(separator: ", "))

        // The mock display: a MacBook's proportions at every window size, never above 1:1.
        let display = model.display.frame.size
        let lid = WorkbenchTokens.Layout.lid
        let aspect = display.width / display.height
        check("column size reported", abs(model.columnSize.width - width(detail)) < 1, "\(model.columnSize.width) vs \(width(detail))")
        let expected = min(1, model.columnSize.width / lid.width, model.columnSize.height / lid.height)
        check("display scaled to fit, at most 1:1", abs(model.scale - expected) < 0.001 && model.scale <= 1, "\(model.scale)")
        check("display keeps the MacBook aspect", abs(model.screenSize.width / model.screenSize.height - aspect) < 0.001, "\(model.screenSize)")
        check("display fits the column", lid.width * model.scale <= model.columnSize.width + 0.5 && lid.height * model.scale <= model.columnSize.height + 0.5)
        check("mock display is Core's notched sample", model.metrics == .sampleNotched)
        let notch = NotchGeometry.notchRect(metrics: model.metrics, spec: IslandLayoutSpec())
        check("notch centered in the display", abs(notch.midX - display.width / 2) < 0.5, "\(notch)")
        let resting = NotchGeometry.frames(density: NotchState.silent.density, metrics: model.metrics, spec: WorkbenchTokens.Island.spec)
        check("silent shape meets the Mac with the ears", resting.topRadius == 6 && resting.width == notch.width + 12 && resting.bodyWidth == notch.width,
              "top \(resting.topRadius), width \(resting.width)")
        let listening = NotchGeometry.frames(density: NotchState.voiceFlow.density, metrics: model.metrics, spec: WorkbenchTokens.Island.spec)
        check("voice bar keeps the notch's width and grows down", listening.width == resting.width && listening.minHeight == notch.height + 44)
        // Collapsing the panel widens the column: the display grows, its proportions do not.
        let before = model.scale
        model.columnVisibility = .detailOnly; await settle(window, 0.6)
        check("collapsed panel: display grows", model.scale > before, "\(before) → \(model.scale)")
        check("collapsed panel: same aspect", abs(model.screenSize.width / model.screenSize.height - aspect) < 0.001)
        model.columnVisibility = .all; await settle(window, 0.6)
        check("dock has icons", model.dockIcons.apps.count >= 6 && model.dockIcons.trash != nil, "\(model.dockIcons.apps.count) apps")

        // The waveform: edges stay at their shortest, the middle does the moving.
        let minH = WorkbenchTokens.Island.waveformMinHeight, maxH = WorkbenchTokens.Island.waveformMaxHeight
        let mid = WorkbenchTokens.Island.waveformBars / 2
        let quiet = VoiceBarView.heights(level: 0, time: 0, frozen: true)
        check("quiet: every bar at its shortest", quiet.allSatisfy { $0 <= minH + 0.5 })
        var edgeMax: CGFloat = 0, middleLow = CGFloat.infinity, middleHigh: CGFloat = 0
        for step in 0..<200 {
            let t = Double(step) * 0.025
            for level in [0.2, 0.6, 1.0] {
                let h = VoiceBarView.heights(level: level, time: t)
                edgeMax = max(edgeMax, h.first!, h.last!)
                middleLow = min(middleLow, h[mid]); middleHigh = max(middleHigh, h[mid])
            }
        }
        check("edge bars stay short at any level", edgeMax <= minH + 1.5, "edge max \(String(format: "%.1f", edgeMax)) pt")
        check("middle bar fluctuates across the range", middleHigh >= maxH - 1 && middleLow <= minH + 6,
              "middle \(String(format: "%.1f", middleLow))…\(String(format: "%.1f", middleHigh)) pt")
        let loud = VoiceBarView.heights(level: 1, time: 0, frozen: true)
        check("bars rise toward the middle", (0..<mid).allSatisfy { loud[$0] <= loud[$0 + 1] }
              && (mid..<(loud.count - 1)).allSatisfy { loud[$0] >= loud[$0 + 1] })

        // Voice flow: fn is press-to-toggle, and the panel's radio does the same.
        check("fn monitor is listening", model.functionKey.isRunning)
        if let down = fnEdge(down: true, window: window), let up = fnEdge(down: false, window: window) {
            model.functionKey.handle(down); model.functionKey.handle(up); await settle(window, 0.9)
            check("fn press shows the voice bar", model.notchState == .voiceFlow)
            check("microphone level is flowing", model.audioLevel > 0, "\(model.audioLevel)")
            model.functionKey.handle(down); model.functionKey.handle(up); await settle(window, 0.6)
            check("fn press again transcribes", model.notchState == .transcribing && model.audioLevel == 0 && !model.transcript.isEmpty,
                  model.transcript)
            let nowhere = !model.inputBoxOnScreen
            await settle(window, WorkbenchTokens.Progress.transcribeDuration.seconds + WorkbenchTokens.Progress.transcribeHold.seconds + 0.4)
            check("the transcription runs out, then it pastes or waits to be copied",
                  model.notchState == (nowhere ? .pasteNotFound : .silent) && model.transcript == WorkbenchModel.sampleTranscript,
                  model.notchState.title)
            post(key(kVK_Escape, "\u{1b}", window: window)); await settle(window, 0.4)
            // Two quick presses: nothing was said, so it thinks briefly and says so, then rests.
            model.functionKey.handle(down); model.functionKey.handle(up); await settle(window, 0.2)
            model.functionKey.handle(down); model.functionKey.handle(up); await settle(window, 0.2)
            check("a session with nothing said still thinks first", model.notchState == .transcribing)
            await settle(window, WorkbenchTokens.Progress.emptyTranscribe.seconds)
            check("then \"No speech detected\"", model.notchState == .noSpeech)
            await settle(window, WorkbenchTokens.Progress.noSpeechDuration.seconds + 0.2)
            check("then the bar rests", model.notchState == .silent)
            model.notchMode = .noSpeech; await settle(window, 0.3)
            check("the Notch list shows No speech detected", model.notchState == .noSpeech)
            post(key(kVK_Escape, "\u{1b}", window: window)); await settle(window, 0.3)
            check("esc dismisses it at once", model.notchState == .silent)
            model.functionKey.handle(down)
            if let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .function,
                                          timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                                          context: nil, characters: "a", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0) {
                model.functionKey.handle(key)
            }
            model.functionKey.handle(up); await settle(window, 0.3)
            check("fn held for another key is not a press", model.notchState == .silent)
        } else {
            check("fn edges can be made", false)
        }
        model.notchState = .voiceFlow; await settle(window, 0.6)
        check("Voice flow from the panel", model.notchState == .voiceFlow && model.audioLevel > 0)
        model.notchState = .silent; await settle(window, 0.4)
        check("Silent notch from the panel", model.notchState == .silent && model.audioLevel == 0)
        // The Notch list's two flows: Dispatch Version 2's Silent notch rests the notch as
        // Voiceflow's does, and one list at a time shows the choice.
        model.notchState = .voiceFlow; await settle(window, 0.4)
        model.v2Selection = .silent; await settle(window, 0.4)
        check("Dispatch Version 2 › Silent notch rests the notch; Voiceflow shows no choice", model.notchState == .silent
              && model.v2Selection == .silent && model.voiceflowSelection == nil)
        model.toggleVoiceFlow(); await settle(window, 0.4)
        check("fn from it: the choice moves to Voiceflow", model.notchState == .voiceFlow
              && model.v2Selection == nil && model.voiceflowSelection == .voiceFlow)
        model.voiceflowSelection = .silent; await settle(window, 0.4)
        check("Voiceflow › Silent notch: Dispatch Version 2 shows no choice", model.notchState == .silent
              && model.voiceflowSelection == .silent && model.v2Selection == nil)

        // Esc on the bar cancels; the undo window counts down, and then the request is gone.
        model.notchState = .voiceFlow; await settle(window, 0.5)
        post(key(kVK_Escape, "\u{1b}", window: window)); await settle(window, 0.3)
        let left = model.undoRemaining(at: Date())
        check("esc on the voice bar cancels, with time to undo", model.notchState == .cancelled && left > 0.8 && left < 1,
              String(format: "%.0f%% of the undo window left", left * 100))
        // The pointer on the bar holds the countdown; leaving resumes it where it was.
        model.setUndoHover(true)
        let held = model.undoRemaining(at: Date())
        await settle(window, 1.0)
        let still = model.undoRemaining(at: Date())
        check("the pointer on the bar holds the countdown", abs(still - held) < 0.001 && model.notchState == .cancelled,
              String(format: "%.0f%% → %.0f%% over 1 s", held * 100, still * 100))
        model.setUndoHover(false)
        await settle(window, 0.4)
        check("leaving resumes it", model.undoRemaining(at: Date()) < still)
        await settle(window, WorkbenchTokens.Progress.undoDuration.seconds)
        check("the undo window runs out, then the bar closes", model.notchState == .silent)

        // Measured, pointer away: from the cancel to the bar closing takes the window's length.
        model.notchState = .voiceFlow; await settle(window, 0.4)
        let cancelledAt = Date()
        model.cancel()
        while model.notchState == .cancelled, Date().timeIntervalSince(cancelledAt) < 5 {
            try? await Task.sleep(for: .milliseconds(10))
        }
        let took = Date().timeIntervalSince(cancelledAt)
        check("the undo window lasts \(Int(WorkbenchTokens.Progress.undoDuration.seconds)) s", abs(took - WorkbenchTokens.Progress.undoDuration.seconds) < 0.1,
              String(format: "%.2f s from cancel to close", took))

        // Transcribing: its progress follows the clock; esc cancels it too, and ⌘Z resumes it.
        model.playTranscribing(); await settle(window, 0.5)
        let p1 = model.transcribeProgress(at: Date())
        await settle(window, 0.5)
        let p2 = model.transcribeProgress(at: Date())
        check("transcribing: progress follows the clock", p1 > 0.1 && p2 > p1 && p2 < 1, String(format: "%.2f → %.2f", p1, p2))
        post(key(kVK_Escape, "\u{1b}", window: window)); await settle(window, 0.3)
        check("esc cancels transcribing too", model.notchState == .cancelled)
        post(key(kVK_ANSI_Z, "z", flags: .command, window: window)); await settle(window, 0.3)
        check("⌘Z resumes it", model.notchState == .transcribing)
        model.notchState = .silent; await settle(window, 0.4)

        model.notchState = .silent; await settle(window, 0.4)

        // The shape and its content keep time. Ground truth from pixels in the composited
        // window: the black run down two columns, one beside the waveform (the shape: bezel +
        // notch, plus the bar when it is out) and one through its middle (interrupted by the
        // white bars while they show), sampled after a show and after a hide.
        // Clear of the waveform (±34 pt) and of the bottom corners (from ±86 pt).
        let beside = 60 * model.scale
        let restRun = blackRun(window: window, detail: detail, offset: beside)
        model.notchState = .voiceFlow
        let showing = await blackRuns(window: window, detail: detail, offset: beside, for: 0.45)
        await settle(window, 0.2)
        let fullRun = blackRun(window: window, detail: detail, offset: beside)
        check("black run grows when the bar is out", fullRun > restRun + 20, "rest \(restRun) px, out \(fullRun) px")
        check("show: the shape grows through sizes between", showing.contains { $0.shape > restRun + 3 && $0.shape < fullRun - 3 }, timeline(showing))
        check("show: the shape is out within 300 ms", showing.last { $0.ms <= 300 }.map { $0.shape >= fullRun - 3 } ?? false)
        check("show: the waveform is in within 250 ms", showing.last { $0.ms <= 250 }.map { $0.bars } ?? false)
        model.notchState = .silent
        let hiding = await blackRuns(window: window, detail: detail, offset: beside, for: 0.45)
        // The probe samples every ~50 ms and the spring starts slowly, so the window is generous;
        // the linger check below is the one that fails when the shape waits for the bars.
        check("hide: the shape has started shrinking by 200 ms", hiding.last { $0.ms <= 200 }.map { $0.shape < fullRun - 3 } ?? false, timeline(hiding))
        check("hide: the shape shrinks through sizes between", hiding.contains { $0.shape > restRun + 3 && $0.shape < fullRun - 3 })
        check("hide: the shape is back within 300 ms", hiding.last { $0.ms <= 300 }.map { $0.shape <= restRun + 3 } ?? false)
        check("hide: the waveform never shows without the shape behind it", hiding.allSatisfy { !$0.bars || $0.shape > restRun + 3 })
        check("hide: the waveform is gone within 200 ms", hiding.last { $0.ms <= 200 }.map { !$0.bars } ?? false)
        // The complaint: the shape must not linger after the waveform has gone.
        let barsGone = hiding.last { $0.bars }?.ms ?? 0
        let shapeHome = hiding.first { $0.ms > barsGone && $0.shape <= restRun + 3 }?.ms ?? Int.max
        // Samples land about 50 ms apart, so the bound allows one sample of slack; a shape that
        // lingered (the bug this guards) stayed a whole spring's length after the bars.
        check("hide: the shape is home within 200 ms of the waveform going", shapeHome - barsGone <= 200, "bars gone by \(barsGone) ms, shape home at \(shapeHome) ms")

        // The panel's choices: appearance and background, remembered; the user's own restored.
        let (appearance, wallpaper, screen) = (model.appearance, model.wallpaperChoice, model.screenContent)
        let defaults = UserDefaults.standard
        model.screenContent = .fullScreenApp; await settle(window, 0.3)
        check("full-screen app is remembered", defaults.string(forKey: WorkbenchModel.screenKey) == "fullScreenApp")
        model.screenContent = .desktop; await settle(window, 0.3)
        model.appearance = .dark; await settle(window, 0.3)
        check("appearance is remembered", defaults.string(forKey: WorkbenchModel.appearanceKey) == "dark")
        model.wallpaperChoice = .color(.black); await settle(window, 0.3)
        check("black background paints a color", isColor(model.wallpaperFill))
        check("background is remembered", defaults.string(forKey: WorkbenchModel.wallpaperKey) == "color:black")
        model.wallpaperChoice = .photo("coast"); await settle(window, 0.3)
        check("bundled photo loads", !isColor(model.wallpaperFill))
        model.wallpaperChoice = .file(URL(fileURLWithPath: "/nowhere/missing.png")); await settle(window, 0.3)
        check("missing file falls back to a color", isColor(model.wallpaperFill))
        check("choices round-trip through their keys",
              WallpaperChoice(key: WallpaperChoice.photo("desk").key) == .photo("desk")
              && WallpaperChoice(key: "color:white") == .color(.white)
              && WallpaperChoice(key: WallpaperChoice.file(URL(fileURLWithPath: "/tmp/a.png")).key) == .file(URL(fileURLWithPath: "/tmp/a.png"))
              && WallpaperChoice(key: "nonsense") == nil)
        model.appearance = appearance; model.wallpaperChoice = wallpaper; model.screenContent = screen
        await settle(window, 0.3)
        check("user's choices restored", defaults.string(forKey: WorkbenchModel.appearanceKey) == appearance.rawValue
              && defaults.string(forKey: WorkbenchModel.wallpaperKey) == wallpaper.key
              && defaults.string(forKey: WorkbenchModel.screenKey) == screen.rawValue)

        // The screenshot flow.
        await screenshots(model: model, window: window)

        // Dispatch Version 2: its aura, its flow, and the hover that opens its control board.
        await voiceGlow(model: model, window: window)
        await dispatchV2(model: model, window: window)
        await v2Hover(model: model, window: window)

        // The Oct 6 feedback (docs/island/FEEDBACK_2026-10-06.md).
        await feedback(model: model, window: window)

        // The Native design (docs/island/NATIVE.md).
        await native(model: model, window: window, check: { check($0, $1, $2) }, settle: { await settle($0, $1) })
    }

    /// The Oct 6 feedback's behaviours: the errors' notice, the recording limit, Split View, the
    /// words landing, the model and effort, skipping the review, titles, answering again.
    private static func feedback(model: WorkbenchModel, window: NSWindow) async {
        model.resetFeedback()
        model.screenContent = .fullScreenApp
        await settle(window, 0.4)

        // #2: a notice in place of the bar, in English; Retry sends the recording again.
        model.stageFeedback(.errors)
        model.stageError(.offline); await settle(window, 0.5)
        check("#2 an error shows on the island, its title in English", model.notchState == .voiceError
              && model.voiceError?.title == "You're offline" && model.stackLayout.outline.size.width == WorkbenchTokens.Feedback.noticeWidth)
        model.performErrorAction(.offline); await settle(window, 0.3)
        check("#2 Retry sends the saved recording again", model.notchState == .transcribing)
        model.notchState = .silent
        model.stageError(.screenRecording); await settle(window, 0.4)
        check("#2 a screenshot without permission says so inside the bar, which keeps listening",
              model.notchState == .voiceFlow && model.barNotice == .screenRecording
              && model.stackLayout.outline.size.width == WorkbenchTokens.Feedback.barNoticeWidth)
        model.notchState = .silent; await settle(window, 0.3)

        // #4: ten minutes at most; at the limit it stops as fn would.
        model.selectTab(0)
        model.notchState = .voiceFlow
        model.startRecordingClock(elapsed: WorkbenchTokens.Feedback.recordingLimit - 0.8)
        await settle(window, 0.3)
        check("#4 the last minute counts down at the bar's right; the waveform moves left for it",
              model.inLastMinute && model.stackLayout.waveform.x < 0)
        await settle(window, 1.0)
        check("#4 at ten minutes it stops and transcribes", model.notchState == .transcribing)
        model.notchState = .silent; await settle(window, 0.3)

        // #6, #7: Split View lands the words in the app under the pointer, then the notch leaves.
        model.stageFeedback(.splitView)
        model.splitTargetOverride = .right
        // Longer than "no speech" (half a second), so the session has something to say.
        await settle(window, 0.9)
        model.toggleVoiceFlow()
        let P = WorkbenchTokens.Progress.self
        await settle(window, P.transcribeDuration.seconds + P.transcribeHold.seconds + 0.2)
        check("#6 the words land in the app under the pointer", model.splitPasted[.right] == WorkbenchModel.sampleTranscript
              && model.splitPasted[.left] == nil)
        check("#7 the notch waits a beat after they land", model.notchState == .transcribing || model.notchState == .silent)
        await settle(window, WorkbenchTokens.Feedback.landHold + 0.3)
        check("#7 …then leaves", model.notchState == .silent)
        model.splitTargetOverride = nil
        model.screenContent = .fullScreenApp

        // #1: Choose chat's model and effort.
        model.stageFeedback(.modelEffort); await settle(window, 0.5)
        check("#1 Choose chat: the model and effort start on Auto", model.v2ModelLabel(agent: model.v2Pick.agent) == "Auto")
        let tall = model.v2SendLayout.outline.size.height
        model.toggleModelSheet(); await settle(window, 0.4)
        model.chooseModel("sonnet-5"); model.chooseEffort("high")
        check("#1 the sheet opens under the row, and a choice shows in the pill",
              model.v2SendLayout.outline.size.height > tall && model.v2ModelLabel(agent: model.v2Pick.agent) == "Sonnet 5 · High")
        model.sendV2Now(); await settle(window, 0.4)
        check("#1 the session answers with it", model.v2Task(model.v2Session)?.modelLabel == "Sonnet 5 · High")
        model.notchState = .silent; await settle(window, 0.3)

        // #19: the review off, it goes when the voice stops; the board shows it on its way.
        model.resetFeedback()
        model.stageFeedback(.skipReview); await settle(window, 0.4)
        let notchWidth = NotchGeometry.notchRect(metrics: model.metrics, spec: WorkbenchTokens.Island.spec).width
        check("#19 the voice bar keeps the notch's width", model.stackLayout.outline.size.width <= notchWidth + 2 * WorkbenchTokens.Island.spec.compactTopRadius + 1)
        model.toggleModelSheet(); await settle(window, 0.4)
        check("#19 its icon opens the chat (Dispatch's rail), the model and the effort at Dispatch's width",
              model.v2RouteOpen && model.stackLayout.outline.size.width == WorkbenchTokens.V2.width && !model.v2BrowseRows.isEmpty)
        model.toggleModelSheet(); await settle(window, 0.3)
        let before = model.agentTasks.count
        model.finishV2Voice()
        await settle(window, WorkbenchTokens.V2.transcribeTime + 0.4)
        check("#19 no Choose chat: it goes, and the board shows it", model.notchState == .v2Board && model.agentTasks.count == before + 1)
        model.v2ReviewBeforeSend = true
        model.notchState = .silent; await settle(window, 0.3)

        // #15: a new chat is named as it goes (Oct 21: at once, no naming beat).
        model.stageFeedback(.titles)
        let named = model.v2Session
        await settle(window, 0.4)
        check("#15 a new chat has the name made from it", named.flatMap { model.v2Titles[$0] } == model.v2Request.generatedTitle)
        model.notchState = .silent; await settle(window, 0.3)

        // #9–10, #17: the board's Done line is the answer's first sentence, not a quote's.
        model.stageFeedback(.progress); await settle(window, 0.4)
        let hero = model.v2Task("t-hero").map(model.v2BoardLine) ?? ""
        check("#9–10 a Done row reads the answer's first sentence (a full stop inside quotation marks doesn't end it)",
              hero.hasSuffix("fits on one line.") && model.notchState == .v2Board, hero)
        model.notchState = .silent; await settle(window, 0.3)

        // #23: answer again, with another model.
        model.feedbackWorkStage = .done
        model.stageFeedback(.reanswer); await settle(window, 0.4)
        if let id = model.v2Focus {
            model.reanswerV2(id, model: "opus-5.5", effort: "max"); await settle(window, 0.3)
            check("#23 Answer again runs it again with the model chosen", model.v2Task(id)?.state == .working
                  && model.v2Task(id)?.modelLabel == "Opus 5.5 · Max")
            model.stopTask(id); await settle(window, 0.2)
            check("#23 Stop stops it", model.v2Task(id)?.stopped == true)
        }

        // #16, Oct 7: a session at work shows one step at a time, the step and its object, and moves on.
        model.feedbackStepsStage = .session
        model.stageFeedback(.steps); await settle(window, 0.4)
        if let task = model.v2FocusTask, model.v2LiveStep(task) != nil {
            // Over its whole run: every step comes up, one at a time, most with what they act on,
            // and an edit's lines once it ends.
            let started = model.v2Started[task.id]
            var seen: [Int: AgentLiveStep] = [:]
            var editLines = false
            for t in 0..<40 {
                model.v2Started[task.id] = Date().addingTimeInterval(-(Double(t) + 0.5) * WorkbenchTokens.Steps.tick)
                if let live = model.v2LiveStep(task) {
                    seen[live.index] = live.step
                    if live.showsResult, live.step.added != nil { editLines = true }
                }
            }
            model.v2Started[task.id] = started
            let steps = model.v2LiveSequence(task)
            let named = steps.filter { $0.object != nil }.map { "\($0.kind.verb) \($0.object!)" }
            check("#16 a session at work shows its steps one at a time, each with what it acts on, an edit's lines when it ends",
                  model.notchState == .v2Chat && seen.count == steps.count && named.count >= steps.count - 2 && editLines,
                  named.prefix(3).joined(separator: " → "))
        } else {
            check("#16 a session at work shows its current step", false, "no step")
        }
        model.notchState = .silent; await settle(window, 0.3)

        // The board's six designs (round four): each lays out the same sessions; Capsules keeps the
        // island at the notch and the capsules under it are where the pointer keeps the board.
        model.stageFeedback(.progress); await settle(window, 0.4)
        let sessions = model.v2BoardOrder
        var widths: [String] = []
        for style in BoardStyle.allCases {
            model.boardStyle = style; await settle(window, 0.15)
            let layout = model.v2BoardLayout
            widths.append("\(style.title) \(Int(layout.outline.size.width))")
        }
        model.boardStyle = .focus
        check("Board designs: Focus puts the most pressing session in its card (the one waiting on you)",
              model.v2BoardOrder.first?.state == .needsYou && model.v2BoardLayout.cardBody > 0, widths.joined(separator: " · "))
        model.boardStyle = .wings
        check("Board designs: Wings is one shape, the sessions in its wings and one on its stage",
              model.v2BoardLayout.outline.size.width == WorkbenchTokens.BoardV.wingsWidth && model.v2BoardSelected != nil)
        model.boardStyle = .capsules; await settle(window, 0.3)
        let notchH = NotchGeometry.notchRect(metrics: model.metrics, spec: WorkbenchTokens.Island.spec).height
        let mid = model.display.frame.width / 2
        check("Board designs: Capsules leaves the island at the notch, the capsules' room below it",
              model.stackLayout.outline.size.height <= notchH + 0.5
              && (model.v2BoardLayout.hoverSize?.height ?? 0) > notchH + CGFloat(sessions.count) * WorkbenchTokens.BoardV.capsuleQuietHeight)
        // Opened by the hover (not pinned): on a capsule it stays; away from them it closes.
        model.showAgentPanel(pinned: false); await settle(window, 0.3)
        model.panelPointer(CGPoint(x: mid, y: notchH + 120)); await settle(window, WorkbenchTokens.Panel.exitGrace + 0.25)
        let held = model.notchState == .v2Board
        model.panelPointer(CGPoint(x: mid + 400, y: 600)); await settle(window, WorkbenchTokens.Panel.exitGrace + 0.25)
        check("Board designs: the pointer on a capsule keeps the board; away from them, it closes",
              held && model.notchState == .silent)

        // Creatures (docs/island/CREATURES.md): every session a creature in the wings, the person's
        // turn at the left with the one waiting on them nearest the notch, the rest at the right
        // with the asleep huddled outermost; the arrows walk them as they stand; one that finishes
        // crosses to the left; at work it fills with its plan, under its face, and full once done.
        model.boardStyle = .creatures
        model.stageFeedback(.progress); await settle(window, 0.4)
        let notchRect = NotchGeometry.notchRect(metrics: model.metrics, spec: WorkbenchTokens.Island.spec)
        let boardWidth = model.v2BoardLayout.outline.size.width
        let slots = CreatureSlots.make(model: model, width: boardWidth, notch: notchRect)
        let left = slots.places.filter { $0.side < 0 }.sorted { $0.point.x > $1.point.x }
        let right = slots.places.filter { $0.side > 0 }.sorted { $0.point.x < $1.point.x }
        check("Creatures: every session stands in a wing, clear of the notch and the ears",
              slots.places.count == model.v2BoardOrder.count
              && slots.places.allSatisfy { abs($0.point.x - boardWidth / 2) > notchRect.width / 2 && $0.point.x > 0 && $0.point.x < boardWidth },
              "\(left.count) left, \(right.count) right")
        check("Creatures: the person's turn at the left, the one waiting on them nearest the notch; the rest at the right",
              left.first?.task.state == .needsYou
              && left.allSatisfy { $0.task.state == .needsYou || $0.task.state == .failed || ($0.task.state == .complete && !$0.task.statusUnknown) }
              && right.allSatisfy { $0.task.state == .working || $0.task.statusUnknown })
        let asleep = right.filter(\.task.statusUnknown)
        check("Creatures: those whose state can't be read sleep outermost, huddled close",
              asleep.isEmpty || (asleep.map(\.task.id) == right.suffix(asleep.count).map(\.task.id)
                                 && zip(asleep, asleep.dropFirst()).allSatisfy { abs($1.point.x - $0.point.x) <= WorkbenchTokens.Creatures.huddle + 0.5 }))
        let walk = slots.visualOrder
        model.v2Focus = walk.first
        _ = model.v2Key(.right); _ = model.v2Key(.right)
        let stepped = model.v2Focus
        _ = model.v2Key(.left)
        check("Creatures: ← and → walk the creatures as they stand, left to right",
              walk.count > 2 && stepped == walk[2] && model.v2Focus == walk[1])
        if let running = right.first(where: { $0.task.state == .working && !$0.task.statusUnknown }),
           let i = model.agentTasks.firstIndex(where: { $0.id == running.task.id }) {
            model.agentTasks[i].state = .complete
            model.v2FinishedAt[running.task.id] = Date()
            await settle(window, 0.3)
            let moved = CreatureSlots.make(model: model, width: boardWidth, notch: notchRect).places.first { $0.task.id == running.task.id }
            check("Creatures: one that finishes crosses to the person's side", moved?.side == -1)
        }
        let poses = model.v2BoardOrder.map { CreaturePose.of($0, model: model) }
        check("Creatures: each pose from its session (waiting, done, at work, asleep)",
              poses.contains(.needsYou) && poses.contains(.done) && poses.contains(.asleep) && poses.contains { $0.working })
        var planned = model.v2BoardOrder.first { $0.state == .working }!
        planned.plan = ["a", "b", "c", "d"]
        planned.planDone = 2
        check("Creatures: at work it fills with its plan, half of it in the lower half; none reported, a little",
              creatureProgress(planned) == 0.5 && { var bare = planned; bare.plan = []; return creatureProgress(bare) == nil }())

        // The same pet in the other designs (docs/island/CREATURES.md): every session shown at once
        // with its agent and what it does, nothing behind a hover; the Desk's arrows go by rows; the
        // Lanes stand each pet as far as its plan has got and make nothing up; at rest the most
        // pressing session's pet sits beside the notch, and pointing at it opens the board.
        model.stageFeedback(.progress); await settle(window, 0.4)
        let everyone = model.v2BoardOrder
        let PT = WorkbenchTokens.Pets.self
        model.boardStyle = .petDesk; await settle(window, 0.2)
        let desk = model.v2BoardLayout
        let deskRows = (everyone.count + PT.deskColumns - 1) / PT.deskColumns
        check("Pets · Desk: four to a row, every session on it without scrolling (up to three rows)",
              desk.outline.size.width == PT.deskWidth && (deskRows > PT.deskRowsVisible ? desk.scrolls : !desk.scrolls),
              "\(everyone.count) sessions, \(deskRows) rows")
        model.v2Focus = everyone.first?.id
        _ = model.v2Key(.down)
        let below = model.v2Focus
        _ = model.v2Key(.right)
        check("Pets · Desk: ↓ goes a row down, → one along",
              everyone.count > PT.deskColumns + 1 && below == everyone[PT.deskColumns].id && model.v2Focus == everyone[PT.deskColumns + 1].id)
        model.boardStyle = .petLanes; await settle(window, 0.2)
        let along = everyone.map { V2PetLane.progress($0) }
        check("Pets · Lanes: done at the finish, at work as far as its plan, nothing made up without one",
              zip(everyone, along).allSatisfy { task, p in
                  if task.state == .complete && !task.stopped && !task.statusUnknown { return p == 1 }
                  if task.plan.isEmpty { return p == nil }
                  return p == creatureProgress(task)
              } && along.contains { ($0 ?? 0) > 0 && ($0 ?? 1) < 1 },
              along.map { $0.map { String(format: "%.2f", Double($0)) } ?? "–" }.joined(separator: " "))
        model.boardStyle = .petList; await settle(window, 0.2)
        check("Pets · List: the board's rows and parts, parted by a seam (the pet says the state)",
              model.v2BoardLayout == V2BoardLayout.make(sections: model.v2BoardGroups.map(\.count), style: .petList, metrics: model.metrics)
              && V2BoardLayout.lead(style: .petList, first: false) == WorkbenchTokens.Board.groupGap)
        model.notchState = .silent; await settle(window, 0.3)
        let rest = model.petAtRestRect
        check("Pets at rest: beside the notch at its right, the most pressing session's pet (the one waiting on you)",
              model.petAtRestShown && model.v2RestPet?.state == .needsYou
              && rest.minX > model.display.frame.width / 2 + notchRect.width / 2 && rest.maxY <= notchRect.height + 0.5)
        model.panelPointer(CGPoint(x: model.display.frame.width / 2 + 400, y: 600)); await settle(window, 0.1)
        model.panelPointer(CGPoint(x: rest.midX, y: rest.midY))
        await settle(window, WorkbenchTokens.Panel.dwellCap + 0.4)
        let opened = model.notchState == .v2Board && !model.petAtRestShown
        model.panelPointer(CGPoint(x: model.display.frame.width / 2 + 400, y: 600))
        await settle(window, WorkbenchTokens.Panel.exitGrace + 0.3)
        check("Pets at rest: pointing at it opens the board, as the notch's hover does; it goes while the board is open",
              opened && model.notchState == .silent)
        model.petAtRest = false
        check("Pets at rest: the panel's switch takes it away", !model.petAtRestShown)
        model.petAtRest = true
        model.boardStyle = .sections
        check("Pets at rest: only in the designs with pets", !model.petAtRestShown)
        model.notchState = .silent; await settle(window, 0.3)

        // Expanding a session (docs/island/WHOLE_SESSION.md): its button or left ⌃; the whole
        // session, as tall as it is down to the display's foot, narrower than the shipping app's
        // 960, the words in one centred column; what the agent did folded under each answer; Esc
        // back to the usual size, then closed.
        model.v2Request = .code
        model.feedbackWorkStage = .done
        model.stageFeedback(.answer); await settle(window, 0.4)
        if let id = model.v2Focus, let task = model.v2FocusTask {
            let V = WorkbenchTokens.V2.self
            let usual = model.v2ChatLayout
            model.toggleV2Expanded(); await settle(window, 0.4)
            let open = model.v2ChatLayout
            let width = min(V.expandedWidth, model.display.frame.width - 2 * V.readingSideMargin)
            check("Expand: one exchange opens expanded, as tall as it is, none of it scrolling (it scrolled before)",
                  model.v2Expanded && open.outline.size.width == width && usual.scrolls && !open.scrolls,
                  String(format: "%.0f×%.0f → %.0f×%.0f", usual.outline.size.width, usual.outline.size.height,
                         open.outline.size.width, open.outline.size.height))
            check("Expand: narrower than 960, the words in a centred column of the reading measure",
                  open.outline.size.width < 960 && open.column == min(V.readingMeasure, open.contentWidth)
                  && abs(2 * open.columnX + open.column - open.outline.size.width) < 0.5,
                  String(format: "column %.0f, %.0f each side", open.column, open.columnX))
            let work = model.v2Work(task)
            let folded = open.outline.size.height
            model.v2StepsOpen.insert(id); await settle(window, 0.4)
            let unfolded = model.v2ChatLayout.outline.size.height
            check("Expand: what the agent did is folded; opened, its steps and the files it edited, the panel taller by them",
                  !work.entries.isEmpty && !work.editedFiles.isEmpty && unfolded > folded,
                  String(format: "%.0f → %.0f pt; ", folded, unfolded) + work.summary())
            model.v2StepsOpen.remove(id); await settle(window, 0.3)
            _ = model.escape(); await settle(window, 0.3)
            check("Expand: Esc comes back to the usual size first", model.notchState == .v2Chat && !model.v2Expanded)
            model.leftControlKey.onPress(); await settle(window, 0.3)
            let pressed = model.v2Expanded
            model.leftControlKey.onPress(); await settle(window, 0.3)
            check("Expand: left ⌃ expands a session, and again brings it back", pressed && !model.v2Expanded)
            _ = model.escape(); await settle(window, 0.3)
            check("Expand: Esc at the usual size closes it", model.notchState != .v2Chat)
        }
        model.notchState = .silent; await settle(window, 0.3)

        // A session asked many times, expanded: every exchange, down to the display's foot; the
        // outline lists the person's requests only, its lines closing up however many; what the
        // agent did for each exchange, folded.
        model.v2Selection = .wholeLong; await settle(window, 0.5)
        if let id = model.v2Focus {
            let V = WorkbenchTokens.V2.self
            let long = model.v2ChatLayout
            let foot = model.display.frame.height - V.readingBottomMargin
            check("Expanded session: many requests reach the display's foot and scroll, in the centred column",
                  model.v2Expanded && long.scrolls && abs(long.outline.size.height - foot) < 0.5
                  && abs(2 * long.columnX + long.column - long.outline.size.width) < 0.5,
                  String(format: "%.0f tall (foot %.0f); column %.0f at %.0f in %.0f", long.outline.size.height, foot,
                         long.column, long.columnX, long.outline.size.width))
            let turns = model.v2Turns(id)
            let items = V2Outline.items(turns)
            check("Expanded session: the outline is the person's requests, one each, nothing else",
                  turns.count > 10 && items.map(\.title) == turns.map(\.question), "\(items.count) requests")
            let roomy = V2Outline.gap(count: items.count, height: 2000)
            let tight = V2Outline.gap(count: 200, height: 700)
            check("Expanded session: the lines at most the widest spacing apart, closing up for many, never touching",
                  roomy == V.outlineGapMax && tight >= 1 && tight < V.outlineGapMin, String(format: "%.1f for 200", tight))
            let first = V2Outline.turnID(0), last = V2Outline.turnID(turns.count - 1)
            let reached = V2Outline.inView(items, tops: [first: -400, V2Outline.turnID(1): 40, last: 3000, V2Outline.endID: 3600], height: 700)
            let atEnd = V2Outline.inView(items, tops: [first: -3000, last: 420, V2Outline.endID: 680], height: 700)
            check("Expanded session: in view is the last request past the read line; read to the end, the last that shows",
                  reached == V2Outline.turnID(1) && atEnd == last, "\(reached), \(atEnd)")
            let earlier = turns.dropLast()
            check("Expanded session: every earlier exchange keeps what the agent did, folded until opened",
                  earlier.allSatisfy { $0.work != nil }
                  && !earlier.contains { model.v2StepsOpen.contains(V2Work.key(id, turn: $0.id)) })
            let before = V2SessionHistory.height(model: model, task: model.v2FocusTask!, width: long.column)
            model.v2StepsOpen.insert(V2Work.key(id, turn: 0))
            let after = V2SessionHistory.height(model: model, task: model.v2FocusTask!, width: long.column)
            model.v2StepsOpen.remove(V2Work.key(id, turn: 0))
            check("Expanded session: an earlier exchange's work opens on its own", after > before,
                  String(format: "%.0f → %.0f pt", before, after))
            let bubble = V2RequestBubble.height(turns[0].question, width: long.column)
            let words = V2Geometry.measure(turns[0].question, size: V.bubbleSize,
                                           width: V2RequestBubble.widest(long.column) - 2 * V.bubblePaddingH, spacing: V.bubbleSpacing)
            check("Expanded session: a request sits in its bubble at the right, at most its share of the column",
                  bubble == words + 2 * V.bubblePaddingV
                  && V2RequestBubble.bubbleWidth(turns[0].question, width: long.column) <= V2RequestBubble.widest(long.column),
                  String(format: "%.0f pt for %.0f of words", bubble, words))
            _ = model.escape(); _ = model.escape(); await settle(window, 0.3)
            check("Expanded session: Esc, the usual size; again, closed", model.notchState != .v2Chat && !model.v2Expanded)
        }
        // Its way out: the back button at the header's left goes to the control board, however the
        // session was opened (this one was not opened from it).
        model.v2Selection = .wholeLong; await settle(window, 0.5)
        if let id = model.v2Focus, !model.v2ChatFromBoard {
            model.exitV2ToBoard(); await settle(window, 0.4)
            check("Expanded session: the back button goes to the control board, held; the session read, off its Done",
                  model.notchState == .v2Board && model.panelPinned && model.v2Checked.contains(id) && !model.v2Expanded
                  && !model.v2BoardOrder.contains { $0.id == id },
                  "\(model.notchState), pinned \(model.panelPinned), \(model.v2BoardOrder.count) on the board")
            model.closeAgentPanel(); await settle(window, 0.3)
        }
        model.notchState = .silent; await settle(window, 0.3)

        // Density (docs/island/SPACIOUS.md): the open panels' room; the resting notch and the voice
        // bar the same in both.
        let density = model.density
        func both<T>(_ read: () -> T) -> (compact: T, spacious: T) {
            model.density = .compact
            let compact = read()
            model.density = .spacious
            return (compact, read())
        }
        model.stageFeedback(.progress); await settle(window, 0.4)
        let board = both { model.v2BoardLayout.outline.size }
        check("Density: the board is 400 wide in Compact and 460 in Spacious, and taller",
              board.compact.width == 400 && board.spacious.width == 460 && board.spacious.height > board.compact.height,
              String(format: "%.0f×%.0f vs %.0f×%.0f", board.compact.width, board.compact.height,
                     board.spacious.width, board.spacious.height))
        model.stageFeedback(.modelEffort); await settle(window, 0.4)
        let send = both { model.v2SendLayout.outline.size }
        check("Density: Choose chat keeps its width and gets room inside it",
              send.compact.width == send.spacious.width && send.spacious.height > send.compact.height,
              String(format: "%.0f vs %.0f pt tall", send.compact.height, send.spacious.height))
        model.feedbackWorkStage = .done
        model.stageFeedback(.answer); await settle(window, 0.4)
        let chat = both { (model.v2ChatLayout.outline.size, model.v2ChatLayout.textWidth, V2Geometry.contentWidth) }
        check("Density: the session is taller, its text in a margin as wide on both sides",
              chat.spacious.0.height > chat.compact.0.height && chat.spacious.1 == chat.spacious.2
              && V2Geometry.contentX * 2 + V2Geometry.contentWidth == WorkbenchTokens.V2.width,
              String(format: "%.0f vs %.0f pt tall; text %.0f wide", chat.compact.0.height, chat.spacious.0.height, chat.spacious.1))
        let bar = both { NotchGeometry.frames(density: .voice, metrics: model.metrics, spec: WorkbenchTokens.Island.spec).minHeight }
        check("Density: the voice bar is the same in both", bar.compact == bar.spacious)
        model.density = density
        model.resetFeedback()
        model.leaveFeedback()
        await settle(window, 0.3)
    }

    /// Dispatch Version 2, as one connected flow: the aura; left Option held takes a passage and
    /// a file, twice the whole screen; fn⌃ transcribes, then forwards them to Choose chat; a suggestion goes into the pill, ⌃
    /// browses every chat and one goes into the pill; the send button sends; the board shows a
    /// moment with only what matters (Ready for review on top, then Running: seven or eight); a
    /// quick answer opens by itself; fn asks more; a chat pulls out into a window, tucks into a
    /// side and comes back, asks more in its box, and ✕ closes it (it keeps working); an opened
    /// session leaves Ready for review.
    private static func dispatchV2(model: WorkbenchModel, window: NSWindow) async {
        let saved = (model.screenContent, model.appearance, model.v2Request)
        defer { model.screenContent = saved.0; model.appearance = saved.1; model.v2Request = saved.2 }
        let V = WorkbenchTokens.V2.self
        let spec = WorkbenchTokens.Island.spec
        model.appearance = .light
        model.screenContent = .fullScreenApp
        model.notchState = .silent; await settle(window, 0.4)
        model.agentTasks = AgentBoard.tasks
        model.panelPointer(nil)

        // Voice input: the aura, and the stack. Left Option held: capture; a click on a passage takes its text.
        model.v2Request = .code
        model.v2Selection = .voice; await settle(window, 0.5)
        check("Dispatch Version 2 › Voice input is the aura (no waveform), its screenshots on the stack",
              model.notchState == .v2Voice && model.liveReferents.count == 2 && model.stackLayout.cards.count == 2)
        // Oct 6, round two: ⌘ takes screenshots (one per press, twice for the whole screen); Option
        // is the highlighter, for text and files.
        let command = leftCommandEdges(window: window)
        let option = leftOptionEdges(window: window)
        model.leftCommandKey.handle(command[1])
        model.leftCommandKey.handle(command[0]); await settle(window, 0.4)
        check("…holding ⌘ turns capture on", model.capturing)
        model.leftCommandKey.handle(command[1]); await settle(window, 0.2)
        check("…letting go of it turns capture off", !model.capturing)
        for event in option { model.leftOptionKey.handle(event) }
        await settle(window, 0.3)
        check("…Option tapped on the bar picks up the highlighter", model.highlighting && !model.capturing)
        if let rect = model.agentAnchors["article.opening0"] {
            model.highlightDrag(from: CGPoint(x: rect.minX + 40, y: rect.minY + 4), to: CGPoint(x: rect.maxX - 60, y: rect.minY + 34))
            check("…a drag across the words draws the marks as it goes", (model.highlightDraft?.count ?? 0) == 2)
            model.finishHighlight(from: CGPoint(x: rect.minX + 40, y: rect.minY + 4), to: CGPoint(x: rect.maxX - 60, y: rect.minY + 34))
            await settle(window, 0.6)
        }
        check("…let go, the words are marked and taken, and the highlighter is put down: one press, one highlight",
              model.liveReferents.contains { if case .text = $0.kind { return true }; return false }
              && model.highlights.count == 1 && !model.highlighting)
        model.screenContent = .desktop; await settle(window, 0.6)
        for event in option { model.leftOptionKey.handle(event) }
        if let rect = model.agentAnchors["desktop.\(DesktopFile.all[0].name)"] {
            model.finishHighlight(from: CGPoint(x: rect.midX, y: rect.midY), to: CGPoint(x: rect.midX, y: rect.midY))
            await settle(window, 0.6)
        }
        check("…with the highlighter, a click on a desktop file marks it and takes it",
              model.liveReferents.contains { if case .file = $0.kind { return true }; return false }
              && model.highlights.contains { $0.file }, "\(model.liveReferents.count)")
        model.screenContent = .fullScreenApp; await settle(window, 0.4)
        let taken = model.liveReferents.count
        for event in command + command { model.leftCommandKey.handle(event) }
        await settle(window, 0.8)
        check("…⌘ pressed twice takes the whole screen", model.liveReferents.count == taken + 1 && !model.capturing,
              "\(taken) → \(model.liveReferents.count)")
        // Nothing of Fovea is in it: under the notch, where the voice bar hangs, is the page.
        if let whole = model.liveReferents.last?.image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let rep = NSBitmapImageRep(cgImage: whole)
            let k = CGFloat(whole.width) / model.display.frame.width
            let under = rep.colorAt(x: Int(model.display.frame.width / 2 * k), y: Int((model.metrics.safeAreaTop + 22) * k))
            let lit = under.map { ($0.redComponent + $0.greenComponent + $0.blueComponent) / 3 } ?? 0
            check("…and the island doesn't cover it: under the notch is the page, not the voice bar", lit > 0.5,
                  String(format: "brightness %.2f", lit))
        }
        model.leftCommandKey.handle(command[0]); model.leftCommandKey.handle(command[1]); await settle(window, 0.5)
        check("…a press of ⌘ turns capture on and leaves it on, for one region", model.capturing)
        model.leftCommandKey.handle(command[0]); model.leftCommandKey.handle(command[1]); await settle(window, 0.5)
        check("…another click turns it off", !model.capturing && model.liveReferents.count == taken + 1)

        // fn⌃: the session ends; Transcribing (the aura as a progress bar); then Choose chat, the
        // first suggestion in the pill.
        for event in fnControlEdges(window: window) { model.functionKey.handle(event); model.leftControlKey.handle(event) }
        await settle(window, 0.3)
        let progress = model.v2TranscribeProgress(at: Date())
        check("fn⌃ ends the session: Transcribing, the aura filling as its progress, what was taken kept",
              model.notchState == .v2Transcribing && progress > 0 && progress < 1 && model.liveReferents.count == taken + 1,
              "\(model.notchState) \(progress)")
        await settle(window, V.transcribeTime + 0.2)
        let suggestions = model.v2Request.suggestions
        check("…then Choose chat: what was taken, the first suggestion in the pill, capture off",
              model.notchState == .v2Send && model.liveReferents.count == taken + 1 && model.v2Pick == suggestions[0] && !model.capturing)
        check("…one width for every open shape; content the same margin inside the body on both sides",
              model.stackLayout.outline.size.width == V.width
              && abs(V2Geometry.contentX - (spec.expandedTopRadius + V.margin)) < 0.1
              && abs(V2Geometry.contentX * 2 + V2Geometry.contentWidth - V.width) < 0.1)
        if let first = model.liveReferents.first {
            model.v2Inspecting = first.id; await settle(window, 0.3)
            post(key(kVK_Escape, "\u{1b}", window: window)); await settle(window, 0.4)
            check("…a taken thing opens larger and Esc puts it back", model.v2Inspecting == nil && model.notchState == .v2Send)
        }
        model.chooseV2(suggestions[1]); await settle(window, 0.2)
        check("a suggested chat's chip goes into the pill", model.v2Pick == suggestions[1])
        if let down = controlEdge(right: false, down: true, window: window), let up = controlEdge(right: false, down: false, window: window) {
            model.leftControlKey.handle(down); model.leftControlKey.handle(up); await settle(window, 0.4)
        }
        let projectRow = model.v2BrowseRows.first
        check("left ⌃ opens every chat: the agents' rail and the agent's projects",
              model.v2Browsing && { if case .project = projectRow { return true }; return false }())
        if let projectRow { model.pickV2Browse(projectRow); await settle(window, 0.3) }
        if let chatRow = model.v2BrowseRows.dropFirst(2).first, case .chat(let chat) = chatRow {
            model.pickV2Browse(chatRow); await settle(window, 0.4)
            check("…a project's chat goes into the pill, and the chats fold away",
                  model.v2Pick.chat == chat.title && !model.v2Browsing && model.notchState == .v2Send)
        }
        model.sendV2Now(); await settle(window, 0.5)
        let sent = model.v2Task(model.v2Session)
        check("the send button sends it there; routing learns it was browsed; the board shows it, in focus",
              model.notchState == .v2Board && model.v2Labels.last == .browsed && model.v2Focus == sent?.id)
        let sections = model.v2BoardSections
        let part = { (section: BoardSection) in sections.first { $0.section == section }?.tasks ?? [] }
        check("…the board (round three) is parted by state: Needs you, Done, Running, Status unavailable, each row led by its agent",
              sections.map(\.section) == BoardSection.allCases
              && part(.needsYou).allSatisfy { $0.state == .needsYou || $0.state == .failed }
              && part(.done).allSatisfy { $0.state == .complete }
              && part(.running).allSatisfy { $0.state == .working && !$0.statusUnknown }
              && part(.unknown).allSatisfy(\.statusUnknown)
              && part(.running).contains { $0.id == sent?.id }
              && part(.done).allSatisfy { !model.v2BoardLine($0).isEmpty },
              sections.map { "\($0.section.title) \($0.tasks.count)" }.joined(separator: " · "))
        model.boardStyle = .badges
        let badges = model.v2BoardLayout
        model.boardStyle = .sections
        check("…both designs end on a whole row; Badges has no headers, so it is shorter",
              badges.outline.size.height < model.v2BoardLayout.outline.size.height,
              String(format: "%.0f vs %.0f pt", badges.outline.size.height, model.v2BoardLayout.outline.size.height))
        model.panelPointer(CGPoint(x: model.display.frame.width / 2 + 500, y: 500))
        await settle(window, V.boardHold + 0.6)
        check("…then the island rests (no wings); the task carries on", model.notchState == .silent && sent?.state == .working)
        if let id = sent?.id { model.stopTask(id) }

        // A quick answer: Choose chat waits for the person; Return sends it; the board shows it; it
        // opens by itself.
        model.v2Request = .calendar
        model.v2Selection = .send; await settle(window, 4.5)
        check("Choose chat waits for the person: nothing sends by itself, and there is no countdown", model.notchState == .v2Send)
        post(key(kVK_Return, "\r", window: window)); await settle(window, 0.4)
        let quick = model.v2Task(model.v2Session)
        check("Return sends it to the first suggestion (a Quick answer), and routing gets the label",
              model.notchState == .v2Board && quick?.agent == ChatAgent.fovea.id && model.v2Labels.last == .keptFirst)
        await settle(window, V.boardHold + 0.6)
        check("…it answered quickly: its expanded chat opens by itself, the agent's answer as written",
              model.notchState == .v2Chat && model.v2Focus == quick?.id && model.v2FocusTask?.answer?.contains("Two things") == true)
        let chat = model.v2ChatLayout
        check("…no screen beside it (feedback #9): the answer takes the content width",
              abs(chat.textWidth - V2Geometry.contentWidth) < 0.1)
        check("…its steps are kept, to fold under the answer (feedback #11)", model.v2FocusTask?.steps.isEmpty == false)

        // fn on the chat asks more in that session.
        if let down = fnEdge(down: true, window: window), let up = fnEdge(down: false, window: window) {
            model.functionKey.handle(down); model.functionKey.handle(up); await settle(window, 0.4)
            check("fn on the chat listens to ask more in that session", model.notchState == .v2Voice && model.v2Continuing == quick?.id)
            model.functionKey.handle(down); model.functionKey.handle(up); await settle(window, 0.3)
            check("…fn again transcribes it", model.notchState == .v2Transcribing)
            await settle(window, V.transcribeTime + 0.2)
            check("…then sends it there (no Choose chat); the board shows it",
                  model.notchState == .v2Board && model.v2Focus == quick?.id && model.v2FocusTask?.state == .working)
            await settle(window, V.boardHold + 0.6)
            check("…and its answer opens", model.notchState == .v2Chat && model.v2FocusTask?.result?.outcome.contains("tomorrow") == true)
        }

        // Pull it out of the notch: a window; to a side, a tab; back out; closed.
        if let id = quick?.id {
            let point = CGPoint(x: model.display.frame.width - 260, y: 260)
            model.dragOutV2(id, to: point); await settle(window, 0.2)
            check("pulling the grab bar: the chat follows the pointer as a window", model.v2DragOut?.id == id)
            model.endDragOutV2(id, at: point); await settle(window, 0.4)
            check("…let go: it stays a window, and the notch is the board again", model.v2Detached.map(\.id) == [id]
                  && model.v2Detached.first?.docked == nil && model.notchState == .v2Board)
            model.moveDetachedV2(id, to: CGPoint(x: 2, y: 300))
            model.endMoveDetachedV2(id, pointer: CGPoint(x: 3, y: 320)); await settle(window, 0.2)
            check("…dragged to a side, it tucks into it", model.v2Detached.first?.docked == .left)
            model.undockV2(id); await settle(window, 0.2)
            check("…and comes back out", model.v2Detached.first?.docked == nil)
            model.askMoreV2(id, text: "And on Friday?", inWindow: true); await settle(window, 0.3)
            check("…its box asks more there: the session works again, in the window; the notch stays the board",
                  model.v2Task(id)?.state == .working && model.v2Followed[id] == "And on Friday?"
                  && model.v2Detached.map(\.id) == [id] && model.notchState == .v2Board)
            model.askMoreV2(id, text: "And next week?", inWindow: true); await settle(window, 0.3)
            check("…and again while it is still at work: it waits its turn (feedback #24)",
                  model.v2Task(id)?.state == .working && model.v2Followed[id] == "And on Friday?"
                  && model.v2Queue[id]?.map(\.text) == ["And next week?"])
            if let waiting = model.v2Queue[id]?.first { model.sendQueuedNow(id, waiting) }
            await settle(window, 0.3)
            check("…Send now takes it into the session at once", model.v2Followed[id] == "And next week?"
                  && (model.v2Queue[id] ?? []).isEmpty)
            let turns = model.v2Turns(id)
            check("…the window keeps every exchange, for the rail: the answer, the one it moved on from, the one now",
                  turns.map(\.question).suffix(2) == ["And on Friday?", "And next week?"] && turns.count == 4
                  && turns[turns.count - 2].result == nil && turns.first?.result != nil, turns.map(\.question).joined(separator: " | "))
            let base = V.detachedSize
            model.resizeDetachedV2(id, to: CGSize(width: base.width * 1.3, height: base.height * 1.3)); await settle(window, 0.2)
            let resized = model.v2Detached.first
            check("…its corner resizes the window (its words keep their size), still on the screen",
                  resized.map { abs($0.size.width - base.width * 1.3) < 0.5
                      && $0.origin.x + $0.size.width <= model.detachedArea.width
                      && $0.origin.y + $0.size.height <= model.detachedArea.height } ?? false)
            model.resizeDetachedV2(id, to: CGSize(width: 9999, height: 9999)); let most = model.v2Detached.first?.size.width ?? 0
            model.resizeDetachedV2(id, to: .zero); let least = model.v2Detached.first?.size.width ?? 0
            check("…within its limits", most <= base.width * V.detachedResize.upperBound + 0.5
                  && abs(least - base.width * V.detachedResize.lowerBound) < 0.5)
            model.resizeDetachedV2(id, to: base)
            model.closeDetachedV2(id); await settle(window, 0.2)
            // Oct 15 review, QA21: closing never stops; only Stop does.
            check("…✕ closes it, and it keeps working", model.v2Detached.isEmpty && model.v2Task(id)?.stopped != true)
        }

        // Opening a session from the board: its chat; back; it is no longer Ready for review.
        model.hoverV2("t-snapshots", true); await settle(window, V.focusDwell + 0.15)
        check("resting on a session puts it in focus", model.v2Focus == "t-snapshots")
        model.openV2("t-snapshots"); await settle(window, 0.4)
        check("…a click opens its expanded chat, with Back", model.notchState == .v2Chat && model.v2ChatFromBoard)
        post(key(kVK_Escape, "\u{1b}", window: window)); await settle(window, 0.4)
        check("…Esc goes back to the board, and it has left Ready for review",
              model.notchState == .v2Board && !model.v2Ready.contains { $0.id == "t-snapshots" })
        model.panelPointer(nil)
        post(key(kVK_Escape, "\u{1b}", window: window)); await settle(window, 0.4)
        check("Esc closes the board", model.notchState == .silent)
        model.agentTasks = AgentBoard.tasks
    }

    /// The aura (libraries.dev/voice) in Dispatch Version 2's voice bar: in color, rising from the
    /// bottom edge; its driver follows the demo voice; the Voice glow section turns its colors,
    /// shows it when the notch is at rest, and is remembered. Voiceflow keeps its waveform.
    private static func voiceGlow(model: WorkbenchModel, window: NSWindow) async {
        let saved = (model.screenContent, model.appearance)
        defer { model.screenContent = saved.0; model.appearance = saved.1 }
        let center = model.display.frame.width / 2
        let notchH = model.metrics.safeAreaTop
        model.appearance = .light
        model.screenContent = .fullScreenApp
        model.notchState = .silent; await settle(window, 0.4)
        model.v2Selection = .voice; model.clearReferents()
        await settle(window, 1.2)
        if let image = WorkbenchSnapshots.composited(window) {
            var brightest = 0.0, colorful = 0.0, topBrightest = 0.0
            for x in stride(from: -99.0, through: 99.0, by: 1.5) {
                for y in stride(from: notchH + 1, through: notchH + 43, by: 1.5) {
                    let (r, g, b) = rgb(at: CGPoint(x: center + x, y: y), model: model, window: window, image: image)
                    brightest = max(brightest, (r + g + b) / 3)
                    colorful = max(colorful, max(r, g, b) - min(r, g, b))
                    if y < notchH + 12 { topBrightest = max(topBrightest, (r + g + b) / 3) }
                }
            }
            check("Dispatch Version 2 › Voice input: the aura draws in color, rising from the bottom edge",
                  brightest > 0.25 && colorful > 0.12 && topBrightest < brightest,
                  String(format: "brightest %.2f, color %.2f, top %.2f", brightest, colorful, topBrightest))
        }
        model.v2Selection = .silent; await settle(window, 0.3)
        // Its driver follows the site's demo voice: silent between phrases, then the envelope.
        let engine = VoiceGlowEngine()
        let quiet = engine.still(at: 8.95, geometry: WorkbenchTokens.VoiceGlow.wide, reduceMotion: false)
        let loud = engine.still(at: 2.2, geometry: WorkbenchTokens.VoiceGlow.wide, reduceMotion: false)
        check("the aura follows the demo voice: resting between phrases, up mid-phrase",
              quiet.level < 0.05 && loud.level > 0.3 && loud.h > quiet.h && loud.lift > quiet.lift,
              String(format: "level %.2f → %.2f", quiet.level, loud.level))

        // The Voice glow section.
        let glowSaved = (model.glowPalette, model.glowHue, model.glowSpread, model.glowDrift)
        defer {
            model.glowPalette = glowSaved.0; model.glowHue = glowSaved.1
            model.glowSpread = glowSaved.2; model.glowDrift = glowSaved.3
        }
        model.notchState = .silent; await settle(window, 0.3)
        model.glowDrift = false
        check("changing the glow with the notch at rest shows Dispatch Version 2's aura", model.notchState == .v2Voice)
        func bandColor() -> (r: Double, g: Double, b: Double) {
            guard let image = WorkbenchSnapshots.composited(window) else { return (0, 0, 0) }
            var r = 0.0, g = 0.0, b = 0.0
            for x in stride(from: -99.0, through: 99.0, by: 2) {
                for y in stride(from: notchH + 1, through: notchH + 43, by: 2) {
                    let c = rgb(at: CGPoint(x: center + x, y: y), model: model, window: window, image: image)
                    r += c.0; g += c.1; b += c.2
                }
            }
            return (r, g, b)
        }
        model.glowPalette = .custom
        model.glowSpread = 0
        model.glowHue = 120; await settle(window, 0.8)
        let green = bandColor()
        model.glowHue = 240; await settle(window, 0.8)
        let blue = bandColor()
        check("Custom at 120° glows green, at 240° blue", green.g > green.r && green.g > green.b && blue.b > blue.r && blue.b > blue.g,
              String(format: "rgb %.0f %.0f %.0f → %.0f %.0f %.0f", green.r, green.g, green.b, blue.r, blue.g, blue.b))
        check("the glow's choices are remembered", UserDefaults.standard.string(forKey: WorkbenchModel.glowPaletteKey) == "custom"
              && UserDefaults.standard.double(forKey: WorkbenchModel.glowHueKey) == 240)
        model.notchState = .silent; await settle(window, 0.3)

        // Voiceflow keeps its waveform, centered in its band.
        model.voiceflowSelection = .voiceFlow; await settle(window, 0.6)
        if let image = WorkbenchSnapshots.composited(window) {
            let mid = (-2...2).map { dy in
                brightness(at: CGPoint(x: center, y: notchH + WorkbenchTokens.Island.spec.voiceBelow / 2 + CGFloat(dy)),
                           model: model, window: window, image: image)
            }.max() ?? 0
            check("Voiceflow's waveform is still centered in its band", mid > 0.5, String(format: "%.2f", mid))
        }
        model.notchState = .silent; await settle(window, 0.4)
    }

    /// The hover opens Dispatch Version 2's control board near the notch (on it, or just beside or
    /// below it) after a short dwell; a brush across doesn't; on the board it stays; a beat after
    /// the pointer leaves it closes, and so does a session opened from it; pinned from the panel
    /// it stays; it never opens empty. The real pointer reaches it wherever the workbench is.
    private static func v2Hover(model: WorkbenchModel, window: NSWindow) async {
        let saved = (model.screenContent, model.appearance)
        defer { model.screenContent = saved.0; model.appearance = saved.1 }
        let P = WorkbenchTokens.Panel.self
        let center = model.display.frame.width / 2
        let notchH = model.metrics.safeAreaTop
        let notchW = NotchGeometry.notchRect(metrics: model.metrics, spec: WorkbenchTokens.Island.spec).width
        model.appearance = .light
        model.screenContent = .fullScreenApp
        model.notchState = .silent; await settle(window, 0.4)
        model.agentTasks = AgentBoard.tasks
        let notch = CGPoint(x: center, y: notchH / 2)
        let away = CGPoint(x: center + 400, y: 400)
        model.panelPointer(away); await settle(window, 0.4)

        // The real pointer: a point of the display, put on the screen, comes back the same.
        if let w = model.windowPoint(forDisplay: notch) {
            let back = model.displayPoint(fromScreen: window.convertPoint(toScreen: w))
            check("the real pointer maps onto the display's points", back.map { hypot($0.x - notch.x, $0.y - notch.y) < 1 } ?? false,
                  back.map { "\(Int($0.x)),\(Int($0.y))" } ?? "not over the display")
        }

        // (A loaded machine can stretch the waits past the dwell; the check says so rather than fail.)
        let brushed = Date()
        model.panelPointer(notch); await settle(window, 0.04)
        model.panelPointer(away)
        let brush = Date().timeIntervalSince(brushed)
        await settle(window, 0.4)
        check("a brush across the notch doesn't open the board", brush >= P.dwell || model.notchState == .silent,
              brush >= P.dwell ? String(format: "not judged: the brush took %.0f ms", brush * 1000) : String(format: "%.0f ms on it", brush * 1000))
        model.closeAgentPanel(); await settle(window, 0.4)
        model.panelPointer(CGPoint(x: center + notchW / 2 + P.hoverReach / 2, y: notchH + P.hoverReach / 2))
        await settle(window, P.dwell + 0.25)
        check("the pointer near the notch (just beside and below it) opens the control board",
              model.notchState == .v2Board && !model.v2BoardOrder.isEmpty)
        let board = model.v2BoardLayout.outline.size
        model.panelPointer(CGPoint(x: center + 120, y: board.height - 20)); await settle(window, 0.5)
        check("…on the board, it stays", model.notchState == .v2Board)
        model.panelPointer(away); await settle(window, P.exitGrace + 0.15)
        check("…a beat after the pointer leaves, it closes", model.notchState == .silent)
        model.panelPointer(notch); await settle(window, 0.04)
        check("…back on the notch just after: it opens at once", model.notchState == .v2Board)

        // A session opened from the hover's board: on it, it stays; the pointer leaves, it closes.
        if let id = model.v2BoardOrder.first?.id {
            model.panelPointer(CGPoint(x: center, y: board.height - 20)); await settle(window, 0.2)
            model.openV2(id); await settle(window, 0.4)
            check("a session clicked on it opens its expanded chat", model.notchState == .v2Chat && model.v2ChatFromBoard)
            model.panelPointer(CGPoint(x: center, y: model.v2ChatLayout.outline.size.height - 30)); await settle(window, 0.3)
            check("…on the chat, it stays", model.notchState == .v2Chat)
            model.panelPointer(away); await settle(window, P.exitGrace + 0.15)
            check("…the pointer leaves: it closes too", model.notchState == .silent)
        }

        // Pinned from the panel's radio, the board stays when the pointer leaves; Esc closes it.
        await settle(window, P.reopenWindow + 0.1)
        model.v2Selection = .board; await settle(window, 0.5)
        model.panelPointer(notch); await settle(window, 0.1)
        model.panelPointer(away); await settle(window, P.exitGrace + 0.2)
        check("pinned from the panel, the board stays when the pointer leaves", model.notchState == .v2Board)
        post(key(kVK_Escape, "\u{1b}", window: window)); await settle(window, 0.4)
        check("…Esc closes it", model.notchState == .silent)

        // Never empty.
        let tasks = model.agentTasks
        model.agentTasks = []
        model.panelPointer(notch); await settle(window, P.dwell + 0.25)
        check("with nothing running or to review, the hover never opens an empty board", model.notchState == .silent)
        model.panelPointer(away); await settle(window, 0.2)
        model.agentTasks = tasks
        model.panelPointer(nil)
        model.notchState = .silent; await settle(window, 0.3)
    }

    /// Left Option's edges: down, up.
    /// Left ⌘ down, then up: a tap of it alone (feedback #3).
    private static func leftCommandEdges(window: NSWindow) -> [NSEvent] {
        let flags = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.command.rawValue | ModifierHoldMonitor.leftCommandDeviceFlag)
        return [flags, []].compactMap { f in
            NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: f,
                             timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                             context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false,
                             keyCode: UInt16(kVK_Command))
        }
    }

    private static func leftOptionEdges(window: NSWindow) -> [NSEvent] {
        let flags = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.option.rawValue | ModifierHoldMonitor.leftOptionDeviceFlag)
        return [flags, []].compactMap { f in
            NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: f,
                             timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                             context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false,
                             keyCode: UInt16(kVK_Option))
        }
    }

    /// The screenshot flow, driven with events posted through the app's queue, so they pass
    /// the key monitors and SwiftUI's gestures as a person's would.
    private static func screenshots(model: WorkbenchModel, window: NSWindow) async {
        model.screenContent = .fullScreenApp
        model.selectTab(0)
        model.scrollReset += 1
        model.notchState = .silent
        await settle(window, 0.5)

        // The Notch list: Add screenshot is the bar with capture mode on.
        model.notchMode = .addScreenshot
        await settle(window, 0.3)
        check("Notch list: Add screenshot opens the bar and captures", model.notchState == .voiceFlow && model.capturing)
        model.notchMode = .voiceFlow
        await settle(window, 0.2)
        check("Notch list: Voice flow keeps the bar, stops capturing", model.notchState == .voiceFlow && !model.capturing)
        model.notchMode = .silent
        await settle(window, 0.5)
        check("Notch list: Silent notch closes it", model.notchState == .silent && model.notchMode == .silent)

        // Full screen, the bar meets the black band with rounded corners: just outside the bar's
        // side and just under the band is black (the ear); lower down it is Safari again. The
        // ear's curve passes 2.1 pt under the band 1 pt out from the side, so the sample sits
        // 1.6 pt clear of it, where edge smoothing cannot gray it at the stage's scale.
        // In the light look, where Safari's toolbar under the ear is gray, not near black.
        let appearance = model.appearance
        model.appearance = .light
        defer { model.appearance = appearance }
        model.notchState = .voiceFlow
        await settle(window, 0.5)
        if let image = WorkbenchSnapshots.composited(window) {
            let edge = model.display.frame.width / 2 - model.metrics.notchWidth! / 2
            let band = model.metrics.safeAreaTop
            let inEar = isBlack(at: CGPoint(x: edge - 1, y: band + 0.5), model: model, window: window, image: image)
            let belowEar = isBlack(at: CGPoint(x: edge - 1.5, y: band + 9), model: model, window: window, image: image)
            let rightEar = isBlack(at: CGPoint(x: model.display.frame.width - edge + 1, y: band + 0.5), model: model, window: window, image: image)
            check("full screen: the bar meets the band with rounded corners", inEar && rightEar && !belowEar,
                  "left ear \(inEar), right ear \(rightEar), below \(belowEar)")
        }
        model.notchState = .silent
        await settle(window, 0.5)

        // ⌘ is the capture key, on the bar only: at rest it is the app's (and so is left ⌃). fn
        // opens the bar; a press of ⌘ there turns capture mode on, for one region.
        let option = leftCommandEdges(window: window)
        model.leftCommandKey.handle(option[1])
        post(controlEdge(right: false, down: true, window: window)); post(controlEdge(right: false, down: false, window: window))
        model.leftCommandKey.handle(option[0]); model.leftCommandKey.handle(option[1])
        await settle(window, 0.4)
        check("at rest, neither left ⌃ nor ⌘ is the capture key", !model.capturing && model.notchState == .silent)
        if let down = fnEdge(down: true, window: window), let up = fnEdge(down: false, window: window) {
            model.functionKey.handle(down); model.functionKey.handle(up)
        }
        await settle(window, 0.4)
        model.leftCommandKey.handle(option[0]); model.leftCommandKey.handle(option[1]); await settle(window, 0.3)
        check("fn opens the bar; a press of ⌘ turns capture mode on, and it stays on until a region",
              model.capturing && model.notchState == .voiceFlow)

        // While capturing, a click still switches tabs…
        let tab2 = MockSafari.tabFrame(2, count: model.tabs.count, displayWidth: model.display.frame.width, top: model.metrics.safeAreaTop)
        await click(CGPoint(x: tab2.midX, y: tab2.midY), model: model, window: window)
        check("capturing: a click switches tabs", model.selectedTab == 2 && model.capturing, "tab \(model.selectedTab)")
        check("capturing: the bar stays open", model.notchState == .voiceFlow)

        // …the page is still what the pointer is over, and the wheel still scrolls it…
        if let p = model.windowPoint(forDisplay: CGPoint(x: 735, y: 520)) {
            var hit = window.contentView?.hitTest(p)
            while let view = hit, !(view is NSScrollView) { hit = view.superview }
            check("capturing: the page is under the pointer", hit != nil)
        }
        let before = model.pageOffsets[2] ?? 0
        for _ in 0..<6 { await scroll(CGPoint(x: 735, y: 520), by: 60, model: model, window: window) }
        await settle(window, 0.3)
        let after = model.pageOffsets[2] ?? 0
        check("capturing: the wheel scrolls the page", after > before + 100, "offset \(Int(before)) → \(Int(after)) pt")

        // Synthetic clicks reach only an active app (a real click activates it first). macOS may
        // keep another app in front when this run starts; ask again for a moment, and if it still
        // refuses, say so instead of failing checks the harness cannot make meaningful.
        guard await ensureActive(window) else { model.selectTab(0); return }

        // A drag that starts while another window has the focus still captures: the click that
        // brings the workbench forward starts the capture too, even on a Safari page.
        let other = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 120, height: 80), styleMask: [.titled],
                             backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        other.orderFrontRegardless()
        other.makeKey()
        await settle(window, 0.2)
        let unfocused = !window.isKeyWindow
        await drag(from: CGPoint(x: 400, y: 640), to: CGPoint(x: 700, y: 820), model: model, window: window)
        await settle(window, 0.8)
        check("a first drag in an unfocused window captures", unfocused && model.referents.count == 1,
              "window key: \(!unfocused), \(model.referents.count) captures")
        check("one press of Option, one screenshot: capture ends with the region (feedback #3)", !model.capturing)
        other.close()
        model.clearReferents()
        model.capturing = true
        window.makeKeyAndOrderFront(nil)
        await settle(window, 0.3)

        // …and a drag draws a region and captures it.
        guard await ensureActive(window) else { model.selectTab(0); return }
        let a = CGPoint(x: 420, y: 300), b = CGPoint(x: 900, y: 560), mid = CGPoint(x: 660, y: 430)
        guard let wa = model.windowPoint(forDisplay: a), let wm = model.windowPoint(forDisplay: mid),
              let wb = model.windowPoint(forDisplay: b) else { check("display maps into the window", false); return }
        await send(mouse(.leftMouseDown, at: wa, window: window), to: window)
        for i in 1...6 {
            let t = CGFloat(i) / 6
            await send(mouse(.leftMouseDragged, at: CGPoint(x: wa.x + (wm.x - wa.x) * t, y: wa.y + (wm.y - wa.y) * t), window: window), to: window)
        }
        await settle(window, 0.2)
        let drawn = model.selection ?? .zero
        check("capturing: the drag draws the region under the pointer", abs(drawn.minX - a.x) < 3 && abs(drawn.maxY - mid.y) < 3,
              "\(Int(drawn.minX)),\(Int(drawn.minY)) \(Int(drawn.width))×\(Int(drawn.height)), app active: \(NSApp.isActive)")
        for i in 1...6 {
            let t = CGFloat(i) / 6
            await send(mouse(.leftMouseDragged, at: CGPoint(x: wm.x + (wb.x - wm.x) * t, y: wm.y + (wb.y - wm.y) * t), window: window), to: window)
        }
        await send(mouse(.leftMouseUp, at: wb, window: window), to: window)
        await settle(window, 0.25)
        check("capture flies into the stack", !model.flights.isEmpty || model.referents.count == 1)
        await settle(window, 0.6)
        let first = model.referents.first
        check("release captures the region", model.referents.count == 1 && model.selection == nil, "\(model.referents.count) captures")
        check("the capture is the region's pixels", first.map { abs($0.image.size.width - 480) < 2 && abs($0.image.size.height - 260) < 2 } ?? false,
              first.map { "\(Int($0.image.size.width))×\(Int($0.image.size.height)) pt" } ?? "none")
        check("the capture knows its tab", first?.source == model.tabs[2].title)

        // ⌃Tab switches tabs while capturing; another capture joins the stack.
        model.capturing = true
        post(key(kVK_Tab, "\t", flags: .control, window: window))
        await settle(window, 0.3)
        check("capturing: ⌃Tab switches tabs", model.selectedTab == 3, "tab \(model.selectedTab)")
        guard await ensureActive(window) else { model.selectTab(0); return }
        await drag(from: CGPoint(x: 320, y: 220), to: CGPoint(x: 980, y: 460), model: model, window: window)
        await settle(window, 0.8)
        check("a second capture, from the other tab", model.referents.count == 2 && model.referents.last?.source == model.tabs[3].title)
        let collapsed = model.stackLayout
        check("the waveform moves right for the stack", collapsed.waveform.x > 15 && collapsed.outline.size.width == 212,
              "waveform at \(Int(collapsed.waveform.x)) pt, bar \(Int(collapsed.outline.size.width)) pt")

        // A click on the stack opens it; esc closes it; so does the pill. (Another press of
        // Option first: the checks below end capture mode with esc.)
        model.capturing = true
        guard let hit = collapsed.stackHit else { check("the stack is a control", false); return }
        let stackPoint = CGPoint(x: model.display.frame.width / 2 + hit.midX, y: hit.midY)
        await click(stackPoint, model: model, window: window)
        await settle(window, 0.5)
        let opened = model.stackLayout
        check("a click on the stack opens it", model.stackExpanded && opened.outline.size.width > 212,
              "island \(Int(opened.outline.size.width))×\(Int(opened.outline.size.height)) pt")
        check("opened: every capture laid out to the right of the first",
              opened.cards.count == 2 && opened.cards[1].cx > opened.cards[0].cx && opened.cards.allSatisfy { $0.rotation == 0 && $0.opacity == 1 })
        // A click on a capture looks closer; esc steps back to all of them.
        guard model.liveReferents.count >= 2, opened.cards.count >= 2 else {
            check("two captures to look at and remove", false, "\(model.liveReferents.count) captures")
            return
        }
        let second = model.liveReferents[1]
        let slot = opened.cards[1]
        await click(CGPoint(x: model.display.frame.width / 2 + slot.cx, y: slot.top + slot.height / 2), model: model, window: window)
        await settle(window, 0.6)
        let near = model.stackLayout
        check("a click on a capture looks closer", model.inspectedId == second.id && near.cards[1].width > slot.width
              && near.cards[0].opacity == 0 && near.caption != nil,
              "\(Int(slot.width))×\(Int(slot.height)) → \(Int(near.cards[1].width))×\(Int(near.cards[1].height)) pt")
        await click(CGPoint(x: model.display.frame.width / 2 + near.cards[1].cx, y: near.cards[1].top + near.cards[1].height / 2),
                    model: model, window: window)
        await settle(window, 0.6)
        check("a click on it again goes back", model.inspectedId == nil && model.stackExpanded)
        model.inspect(second.id)
        await settle(window, 0.5)
        post(key(kVK_Escape, "\u{1b}", window: window))
        await settle(window, 0.6)
        check("esc steps back to all of them first", model.inspectedId == nil && model.stackExpanded)

        // Hovering a capture shows its ✕; a click on the ✕ removes that one, the rest close up.
        let before2 = model.stackLayout
        guard before2.cards.count >= 2 else { check("the stack is still open", false); return }
        model.hoveredReferent = second.id
        await settle(window, 0.3)
        let card = before2.cards[1]
        let x = StackLayout.removeCenter(width: card.width, height: card.height, radius: card.radius)
        await click(CGPoint(x: model.display.frame.width / 2 + card.cx - card.width / 2 + x.x, y: card.top + x.y),
                    model: model, window: window)
        await settle(window, 0.5)
        check("the ✕ removes that capture", model.referents.count == 1 && model.referents[0].id != second.id && model.stackExpanded,
              "\(model.referents.count) left")
        check("the island fits the rest", model.stackLayout.outline.size.width < before2.outline.size.width,
              "\(Int(before2.outline.size.width)) → \(Int(model.stackLayout.outline.size.width)) pt")
        for shape in ReferentShape.allCases {
            let c = StackLayout.opened(aspects: [1.6], shape: shape, metrics: model.metrics).cards[0]
            let center = StackLayout.removeCenter(width: c.width, height: c.height, radius: c.radius)
            let half = WorkbenchTokens.Referents.removeSize / 2
            let inside: Bool
            if c.radius >= min(c.width, c.height) / 2 - 0.5 {
                let r = min(c.width, c.height) / 2
                inside = hypot(center.x - (c.width - r), center.y - c.height / 2) + half <= r
            } else {
                inside = center.x + half <= c.width && center.y - half >= 0
            }
            check("✕ sits on the card: \(shape.title)", inside, "at \(Int(center.x)),\(Int(center.y)) of \(Int(c.width))×\(Int(c.height))")
        }

        post(key(kVK_Escape, "\u{1b}", window: window))
        await settle(window, 0.5)
        check("esc closes the opened stack first", !model.stackExpanded && model.capturing)
        await click(stackPoint, model: model, window: window)
        await settle(window, 0.5)
        if let close = model.stackLayout.close {
            await click(CGPoint(x: model.display.frame.width / 2 + close.midX, y: close.midY), model: model, window: window)
            await settle(window, 0.5)
        }
        check("the esc pill closes it too", !model.stackExpanded)
        // Esc while capturing ends capture mode only, as it ends ⌘⇧4's: the bar and the
        // captures stay. A drag under way draws nothing more and captures nothing.
        post(key(kVK_Escape, "\u{1b}", window: window))
        await settle(window, 0.4)
        check("esc while capturing leaves capture mode, not the request", model.notchMode == .voiceFlow && model.referents.count == 1,
              "\(model.notchMode.title), \(model.referents.count) captures")
        model.capturing = true
        if let wa = model.windowPoint(forDisplay: CGPoint(x: 420, y: 300)), let wb = model.windowPoint(forDisplay: CGPoint(x: 700, y: 480)) {
            await send(mouse(.leftMouseDown, at: wa, window: window), to: window)
            for i in 1...4 {
                let t = CGFloat(i) / 4
                await send(mouse(.leftMouseDragged, at: CGPoint(x: wa.x + (wb.x - wa.x) * t, y: wa.y + (wb.y - wa.y) * t), window: window), to: window)
            }
            post(key(kVK_Escape, "\u{1b}", window: window)); await settle(window, 0.2)
            await send(mouse(.leftMouseDragged, at: CGPoint(x: wb.x + 20, y: wb.y - 20), window: window), to: window)
            await send(mouse(.leftMouseUp, at: CGPoint(x: wb.x + 20, y: wb.y - 20), window: window), to: window)
            await settle(window, 0.6)
            check("esc mid-drag drops the region and leaves capture mode", model.selection == nil && !model.capturing
                  && model.referents.count == 1 && model.notchState == .voiceFlow)
        }
        // On the bar, esc cancels the request; Undo (the pill, or ⌘Z) brings it all back.
        post(key(kVK_Escape, "\u{1b}", window: window))
        await settle(window, 0.4)
        check("esc on the bar cancels; the captures wait", model.notchState == .cancelled && model.referents.count == 1)
        let undo = CancelledBand.undoCenter()
        await click(CGPoint(x: model.display.frame.width / 2 + undo.x, y: model.metrics.safeAreaTop + undo.y), model: model, window: window)
        await settle(window, 0.3)
        check("Undo brings back the bar and the captures", model.notchMode == .voiceFlow && model.referents.count == 1,
              "\(model.notchMode.title), \(model.referents.count) captures")
        post(key(kVK_Escape, "\u{1b}", window: window)); await settle(window, 0.3)
        post(key(kVK_ANSI_Z, "z", flags: .command, window: window)); await settle(window, 0.4)
        check("⌘Z undoes it too", model.notchMode == .voiceFlow && model.referents.count == 1)
        // Cancelled from capture mode (the panel's Cancelled) comes back to capture mode.
        model.capturing = true
        model.notchMode = .cancelled; await settle(window, 0.3)
        post(key(kVK_ANSI_Z, "z", flags: .command, window: window)); await settle(window, 0.4)
        check("undoing a cancel made while capturing brings capture mode back", model.notchMode == .addScreenshot && model.referents.count == 1)
        // A press of ⌘ turns capture mode off, whoever turned it on (here, Undo).
        model.leftCommandKey.handle(option[0]); model.leftCommandKey.handle(option[1])
        await settle(window, 0.3)
        check("a press of ⌘ turns capture mode off again", !model.capturing && model.notchState == .voiceFlow)

        // Shapes: concentric rectangles, true squares and circles, a pill.
        for shape in ReferentShape.allCases {
            let card = StackLayout.collapsed(state: .voiceFlow, aspects: [1.6], shape: shape, peek: false, metrics: model.metrics).cards[0]
            let ok: Bool
            switch shape {
            case .roundedRectangle: ok = card.radius == 6 && abs(card.width / card.height - 1.43) < 0.03
            case .roundedSquare: ok = card.radius == 6 && card.width == card.height
            case .circle: ok = card.width == card.height && card.radius == card.height / 2
            case .capsule: ok = card.radius == card.height / 2 && abs(card.width / card.height - 1.6) < 0.03
            }
            check("shape: \(shape.title)", ok && card.height == 28, "\(Int(card.width))×\(Int(card.height)) r\(card.radius)")
        }
        let wide = StackLayout.opened(aspects: [2.0, 0.75], shape: .roundedRectangle, metrics: model.metrics).cards
        check("opened rectangles keep each capture's proportions", wide[0].width == 120 && wide[1].width == 45 && wide[0].radius == 8)

        // The reference's overshoot, capped: nearly all of it on its own 48 px move, ~12 pt on a long one.
        let fan = CappedOvershoot(x1: 0.31, y1: 1.84, x2: 0.64, y2: 1, duration: 0.41, cap: 12)
        let samples = stride(from: 0.0, through: 1.0, by: 0.005)
        let short = samples.map { fan.progress(for: 48, at: $0) }.max()! * 48 - 48
        let long = samples.map { fan.progress(for: 300, at: $0) }.max()! * 300 - 300
        check("overshoot: the reference's own move keeps its bounce", short > 8 && short < 9.3, String(format: "%.1f pt", short))
        check("overshoot: a long move stays inside the island's padding", long < 13, String(format: "%.1f pt", long))

        // fn transcribes and ends the session: on the notes, which have an input box, the words
        // are pasted into it, the bar closes and the captures go with it.
        model.pastedNote = nil
        model.selectTab(2)
        model.toggleVoiceFlow()
        await settle(window, WorkbenchTokens.Progress.transcribeDuration.seconds + WorkbenchTokens.Progress.transcribeHold.seconds
                     + WorkbenchTokens.Feedback.landHold + 0.6)
        check("transcribing ends the session", model.notchState == .silent && model.referents.isEmpty && !model.capturing)
        check("with an input box on the page, the words are pasted into it", model.pastedNote == WorkbenchModel.sampleTranscript)
        model.pastedNote = nil
        model.selectTab(0)

        await pasteNotFound(model: model, window: window)
    }

    /// Paste not found: with no input box on the page, the island holds the transcript: its
    /// first lines, ✕, the chevron, Copy, and 5 s before it rests.
    private static func pasteNotFound(model: WorkbenchModel, window: NSWindow) async {
        let P = WorkbenchTokens.Paste.self
        let center = model.display.frame.width / 2
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("FoveaWorkbench.smoke"))
        model.pasteboard = pasteboard
        defer { model.pasteboard = .general }
        model.screenContent = .fullScreenApp
        model.selectTab(0)
        check("the article has no input box", !model.inputBoxOnScreen)
        model.notchState = .voiceFlow; await settle(window, 1.0)
        model.toggleVoiceFlow()
        await settle(window, WorkbenchTokens.Progress.transcribeDuration.seconds + WorkbenchTokens.Progress.transcribeHold.seconds + 0.5)
        check("nowhere to paste: Paste not found", model.notchState == .pasteNotFound && model.notchMode == .pasteNotFound)
        var layout = model.pasteLayout
        check("the island grows to the transcript's width, expanded corners", model.stackLayout.outline == layout.outline
              && layout.outline.size.width == P.width && layout.outline.topRadius == WorkbenchTokens.Island.spec.expandedTopRadius,
              "\(layout.outline.size)")
        check("the words are measured: two lines closed, more to show", model.pasteLinesHeight > 25 && model.pasteLinesHeight < 45
              && model.pasteTextHeight > model.pasteLinesHeight && layout.truncated,
              String(format: "lines %.1f, whole %.1f", model.pasteLinesHeight, model.pasteTextHeight))

        // Pixels: the island is black under its words, and wider than the voice bar.
        if let image = WorkbenchSnapshots.composited(window) {
            let wide = isBlack(at: CGPoint(x: center + layout.bodyWidth / 2 - 4, y: layout.rowTop + 2), model: model, window: window, image: image)
            let under = isBlack(at: CGPoint(x: center, y: layout.outline.size.height + 6), model: model, window: window, image: image)
            check("drawn: the island is out to its width, and ends at its height", wide && !under,
                  "black at its right side: \(wide), below it: \(under)")
            // The countdown is the ring around ✕, lit from twelve o'clock; nothing under the controls.
            let ring = (0...6).map { i in
                brightness(at: CGPoint(x: center + layout.closeCenter.x,
                                       y: layout.closeCenter.y - P.ringDiameter / 2 + CGFloat(i) * 0.5),
                           model: model, window: window, image: image)
            }.max() ?? 0
            let noLine = [-100.0, 0, 100].allSatisfy { dx in
                isBlack(at: CGPoint(x: center + dx, y: layout.rowTop + P.rowHeight + 6), model: model, window: window, image: image)
            }
            check("the countdown is a ring around ✕, with no line under the controls", ring > 0.5 && noLine,
                  String(format: "ring top %.2f, black under the controls: %@", ring, noLine ? "yes" : "no"))
        }

        // The countdown runs from the moment the island appeared, whatever the pointer does.
        let started = model.pasteStart
        let r1 = model.pasteRemaining(at: Date())
        check("the countdown runs", r1 < 1 && r1 > 0.6, String(format: "%.0f%% left", r1 * 100))

        guard await ensureActive(window) else { return }
        // The chevron opens the whole transcript; the ring keeps draining while it is open.
        await click(CGPoint(x: center + layout.expandCenter.x, y: layout.expandCenter.y), model: model, window: window)
        await settle(window, 0.4)
        let opened = model.pasteLayout
        check("the chevron opens the whole transcript", model.pasteExpanded && opened.textHeight > layout.textHeight
              && model.stackLayout.outline.size.height > layout.outline.size.height,
              "\(Int(layout.outline.size.height)) → \(Int(model.stackLayout.outline.size.height)) pt")
        let o1 = model.pasteRemaining(at: Date())
        await settle(window, 0.5)
        let o2 = model.pasteRemaining(at: Date())
        check("opened, the ring keeps draining", o2 < o1 - 0.05 && model.pasteStart == started,
              String(format: "%.0f%% → %.0f%% over 0.5 s", o1 * 100, o2 * 100))
        if let image = WorkbenchSnapshots.composited(window) {
            let ring = (0...6).map { i in
                brightness(at: CGPoint(x: center + opened.closeCenter.x,
                                       y: opened.closeCenter.y - P.ringDiameter / 2 + CGFloat(i) * 0.5),
                           model: model, window: window, image: image)
            }.max() ?? 0
            check("opened, the ring is still drawn around ✕", ring > 0.5, String(format: "ring top %.2f", ring))
        }
        // Opened or not, the island rests about 5 s after it appeared.
        while model.notchState == .pasteNotFound, let s = started, Date().timeIntervalSince(s) < 8 {
            try? await Task.sleep(for: .milliseconds(10))
        }
        let lasted = started.map { Date().timeIntervalSince($0) } ?? 0
        check("opened, it still rests \(Int(P.duration.seconds)) s after it appeared", abs(lasted - P.duration.seconds) < 0.15,
              String(format: "%.2f s", lasted))

        // Esc closes the opened transcript first; the countdown carries on. The chevron closes it too.
        model.notchMode = .pasteNotFound; await settle(window, 0.6)
        layout = model.pasteLayout
        await click(CGPoint(x: center + layout.expandCenter.x, y: layout.expandCenter.y), model: model, window: window)
        await settle(window, 0.4)
        post(key(kVK_Escape, "\u{1b}", window: window)); await settle(window, 0.4)
        check("esc closes the transcript first, and the countdown carries on", !model.pasteExpanded
              && model.notchState == .pasteNotFound && model.pasteRemaining(at: Date()) < 0.85,
              String(format: "%.0f%% left", model.pasteRemaining(at: Date()) * 100))
        await click(CGPoint(x: center + layout.expandCenter.x, y: layout.expandCenter.y), model: model, window: window)
        await settle(window, 0.3)
        await click(CGPoint(x: center + opened.expandCenter.x, y: opened.expandCenter.y), model: model, window: window)
        await settle(window, 0.3)
        check("the chevron closes it again", !model.pasteExpanded && model.notchState == .pasteNotFound)

        // Copy: onto the pasteboard, the button says so, then the island rests.
        pasteboard.clearContents()
        await click(CGPoint(x: center + layout.copyPoint.x, y: layout.copyPoint.y), model: model, window: window)
        check("Copy puts the transcript on the pasteboard", pasteboard.string(forType: .string) == WorkbenchModel.sampleTranscript)
        check("Copied, then it rests", model.pasteCopied && model.notchState == .pasteNotFound)
        await settle(window, P.copiedHold.seconds + 0.2)
        check("…once it has said so", model.notchState == .silent)

        // ✕ lets the words go at once; so does esc.
        model.notchMode = .pasteNotFound; await settle(window, 0.6)
        check("the Notch list shows Paste not found", model.notchState == .pasteNotFound)
        layout = model.pasteLayout
        await click(CGPoint(x: center + layout.closeCenter.x, y: layout.closeCenter.y), model: model, window: window)
        check("✕ dismisses it", model.notchState == .silent)
        model.notchMode = .pasteNotFound; await settle(window, 0.4)
        post(key(kVK_Escape, "\u{1b}", window: window)); await settle(window, 0.3)
        check("esc dismisses it", model.notchState == .silent)
        model.notchMode = .pasteNotFound; await settle(window, 0.4)
        model.toggleVoiceFlow(); await settle(window, 0.3)
        check("fn starts a new listening session from it", model.notchState == .voiceFlow)
        model.notchState = .silent; await settle(window, 0.4)

        // Measured, pointer away: from showing to resting takes the countdown's length.
        model.notchMode = .pasteNotFound
        let shownAt = Date()
        while model.notchState == .pasteNotFound, Date().timeIntervalSince(shownAt) < 8 {
            try? await Task.sleep(for: .milliseconds(10))
        }
        let took = Date().timeIntervalSince(shownAt)
        check("the countdown lasts \(Int(P.duration.seconds)) s", abs(took - P.duration.seconds) < 0.15,
              String(format: "%.2f s from showing to resting", took))
        model.screenContent = .fullScreenApp
    }

    /// The color at a display point in a composited image of the window.
    private static func rgb(at point: CGPoint, model: WorkbenchModel, window: NSWindow, image: NSBitmapImageRep) -> (Double, Double, Double) {
        guard let p = model.windowPoint(forDisplay: point) else { return (0, 0, 0) }
        let k = CGFloat(image.pixelsWide) / window.frame.width
        guard let c = image.colorAt(x: Int(p.x * k), y: Int((window.frame.height - p.y) * k))?.usingColorSpace(.deviceRGB) else { return (0, 0, 0) }
        return (Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent))
    }

    /// How bright a display point is in a composited image of the window, 0…1.
    private static func brightness(at point: CGPoint, model: WorkbenchModel, window: NSWindow, image: NSBitmapImageRep) -> Double {
        guard let p = model.windowPoint(forDisplay: point) else { return 0 }
        let k = CGFloat(image.pixelsWide) / window.frame.width
        guard let c = image.colorAt(x: Int(p.x * k), y: Int((window.frame.height - p.y) * k))?.usingColorSpace(.deviceRGB) else { return 0 }
        return Double(c.redComponent + c.greenComponent + c.blueComponent) / 3
    }

    /// Whether a display point is black in a composited image of the window.
    private static func isBlack(at point: CGPoint, model: WorkbenchModel, window: NSWindow, image: NSBitmapImageRep) -> Bool {
        guard let p = model.windowPoint(forDisplay: point) else { return false }
        let k = CGFloat(image.pixelsWide) / window.frame.width
        let x = Int(p.x * k), y = Int((window.frame.height - p.y) * k)
        guard let c = image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return false }
        return c.redComponent < 0.1 && c.greenComponent < 0.1 && c.blueComponent < 0.1
    }

    // MARK: Events

    private static func post(_ event: NSEvent?) {
        if let event { NSApp.postEvent(event, atStart: false) }
    }

    private static func mouse(_ type: NSEvent.EventType, at point: CGPoint, window: NSWindow) -> NSEvent? {
        NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                           windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1,
                           pressure: type == .leftMouseUp ? 0 : 1)
    }

    private static func click(_ point: CGPoint, model: WorkbenchModel, window: NSWindow) async {
        guard let p = model.windowPoint(forDisplay: point) else { return }
        await send(mouse(.leftMouseDown, at: p, window: window), to: window)
        await send(mouse(.leftMouseUp, at: p, window: window), to: window)
        await settle(window, 0.3)
    }

    private static func drag(from a: CGPoint, to b: CGPoint, model: WorkbenchModel, window: NSWindow) async {
        guard let wa = model.windowPoint(forDisplay: a), let wb = model.windowPoint(forDisplay: b) else { return }
        await send(mouse(.leftMouseDown, at: wa, window: window), to: window)
        for i in 1...10 {
            let t = CGFloat(i) / 10
            await send(mouse(.leftMouseDragged, at: CGPoint(x: wa.x + (wb.x - wa.x) * t, y: wa.y + (wb.y - wa.y) * t), window: window), to: window)
        }
        await send(mouse(.leftMouseUp, at: wb, window: window), to: window)
    }

    /// Synthetic clicks reach only an active app (a real click activates it first), and macOS
    /// may keep another app in front, or someone may switch apps while this runs. Asks for a
    /// moment; if macOS still refuses, says so, and the checks that need clicks are skipped.
    private static func ensureActive(_ window: NSWindow) async -> Bool {
        for _ in 0..<10 where !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            await settle(window, 0.2)
        }
        if !NSApp.isActive {
            print("skip the rest of the capture flow: macOS kept another app active, and synthetic clicks only reach an active app")
        }
        return NSApp.isActive
    }

    /// Hands a mouse event straight to the window, a frame apart, so it never queues behind
    /// whatever the real mouse is doing while the check runs.
    private static func send(_ event: NSEvent?, to window: NSWindow) async {
        if let event { window.sendEvent(event) }
        try? await Task.sleep(for: .milliseconds(16))
    }

    /// A scroll-wheel notch over a point of the display, handed to the window. An event made
    /// from a CGEvent carries no window, so the app's queue would drop it; its location is then
    /// read in screen coordinates, so it is placed where the window-local point is.
    private static func scroll(_ point: CGPoint, by dy: Int32, model: WorkbenchModel, window: NSWindow) async {
        guard let p = model.windowPoint(forDisplay: point),
              let cg = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: -dy, wheel2: 0, wheel3: 0)
        else { return }
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        cg.location = CGPoint(x: p.x, y: top - p.y)
        if let event = NSEvent(cgEvent: cg) { window.sendEvent(event) }
        await settle(window, 0.03)
    }

    private static func key(_ code: Int, _ characters: String, flags: NSEvent.ModifierFlags = [], window: NSWindow) -> NSEvent? {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: ProcessInfo.processInfo.systemUptime,
                         windowNumber: window.windowNumber, context: nil, characters: characters,
                         charactersIgnoringModifiers: characters, isARepeat: false, keyCode: UInt16(code))
    }

    /// A Control key's edge; the device flag tells right from left.
    private static func controlEdge(right: Bool, down: Bool, window: NSWindow) -> NSEvent? {
        let device: UInt = right ? ModifierPressMonitor.rightControlDeviceFlag : 0x0000_0001
        let flags = down ? NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.control.rawValue | device) : []
        return NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: flags,
                                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                                context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false,
                                keyCode: UInt16(right ? kVK_RightControl : kVK_Control))
    }

    private static func width(_ item: NSSplitViewItem) -> CGFloat { item.viewController.view.frame.width }

    /// fn⌃'s edges as macOS sends them: fn down, ⌃ down with fn held, ⌃ up, fn up. Both keys'
    /// monitors see all four.
    private static func fnControlEdges(window: NSWindow) -> [NSEvent] {
        func edge(_ flags: NSEvent.ModifierFlags, _ code: Int) -> NSEvent? {
            NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: flags,
                             timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                             context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false,
                             keyCode: UInt16(code))
        }
        let control = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.control.rawValue | ModifierPressMonitor.leftControlDeviceFlag)
        return [edge(.function, kVK_Function), edge(control.union(.function), kVK_Control),
                edge(.function, kVK_Control), edge([], kVK_Function)].compactMap { $0 }
    }

    /// The edges the fn key produces, fed to the monitor as macOS would.
    private static func fnEdge(down: Bool, window: NSWindow) -> NSEvent? {
        NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: down ? .function : [],
                         timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                         context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false,
                         keyCode: UInt16(kVK_Function))
    }

    /// The length, in pixels, of the longest black run down a column of the display, `offset`
    /// points right of its center, in the composited window: the lid's bezel, the notch, and
    /// the bar below it when it is out; through the middle, the white bars interrupt it.
    private static func blackRun(window: NSWindow, detail: NSSplitViewItem, offset: CGFloat = 0, in image: NSBitmapImageRep? = nil) -> Int {
        guard let rep = image ?? WorkbenchSnapshots.composited(window), let theme = window.contentView?.superview else { return -1 }
        let view = detail.viewController.view
        let frame = view.convert(view.bounds, to: nil)          // window points, origin bottom-left
        let scale = CGFloat(rep.pixelsWide) / theme.bounds.width
        let x = Int((frame.midX + offset) * scale)
        let top = Int((theme.bounds.height - frame.maxY) * scale)
        // The longest run: the split view's hairline and the surround come first, the lid later.
        var run = 0, longest = 0
        for y in top..<min(rep.pixelsHigh, top + Int(300 * scale)) {
            guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
            let black = color.redComponent < 0.12 && color.greenComponent < 0.12 && color.blueComponent < 0.12
            run = black ? run + 1 : 0
            longest = max(longest, run)
        }
        return longest
    }

    /// One sample: when, the shape's run beside the waveform, and whether the bars show
    /// (the run through the middle is shorter than the one beside it).
    private struct Sample { let ms: Int; let shape: Int; let bars: Bool }

    /// Samples over time, as fast as the captures allow (one capture per sample).
    private static func blackRuns(window: NSWindow, detail: NSSplitViewItem, offset: CGFloat, for seconds: TimeInterval) async -> [Sample] {
        let start = Date()
        var out: [Sample] = []
        while Date().timeIntervalSince(start) < seconds {
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            let image = WorkbenchSnapshots.composited(window)
            let shape = blackRun(window: window, detail: detail, offset: offset, in: image)
            let middle = blackRun(window: window, detail: detail, offset: 0, in: image)
            out.append(Sample(ms: ms, shape: shape, bars: middle < shape - 3))
            try? await Task.sleep(for: .milliseconds(20))
        }
        return out
    }

    private static func timeline(_ samples: [Sample]) -> String {
        samples.map { "\($0.ms):\($0.shape)\($0.bars ? "*" : "")" }.joined(separator: " ")
    }

    private static func isColor(_ fill: WallpaperFill) -> Bool {
        if case .color = fill { return true }
        return false
    }

    /// What happens when a menu is about to open: SwiftUI rebuilds its items then.
    private static func open(_ menu: NSMenu) {
        menu.delegate?.menuWillOpen?(menu)
        menu.update()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        menu.delegate?.menuDidClose?(menu)
    }

    /// Presses a toolbar item the way a click reaches it: an AppKit control's click, else the
    /// hosted button's accessibility press, else the item's own action.
    private static func press(_ item: NSToolbarItem) -> String {
        let kind = item.view.map { String(describing: type(of: $0)) } ?? "no view"
        if let control = findControl(in: item.view) { control.performClick(nil); return "performClick \(type(of: control))" }
        if let element = findAXButton(in: item.view), element.accessibilityPerformPress() { return "AX press in \(kind)" }
        if let action = item.action {
            NSApp.sendAction(action, to: item.target, from: item)
            return "sendAction \(action) target=\(item.target.map { String(describing: type(of: $0)) } ?? "nil")"
        }
        return "no way to press \(kind)"
    }

    private static func findControl(in view: NSView?) -> NSControl? {
        guard let view else { return nil }
        if let control = view as? NSControl { return control }
        for sub in view.subviews { if let found = findControl(in: sub) { return found } }
        return nil
    }

    private static func findAXButton(in element: Any?) -> NSAccessibilityProtocol? {
        guard let element = element as? NSAccessibilityProtocol else { return nil }
        if element.accessibilityRole() == .button { return element }
        for child in element.accessibilityChildren() ?? [] {
            if let found = findAXButton(in: child) { return found }
        }
        return nil
    }

    private static func findSplit(in view: NSView) -> NSSplitView? {
        if let split = view as? NSSplitView, split.delegate is NSSplitViewController { return split }
        for sub in view.subviews { if let found = findSplit(in: sub) { return found } }
        return nil
    }

    private static func hasSidebarMaterial(in view: NSView) -> Bool {
        if let effect = view as? NSVisualEffectView, effect.material == .sidebar { return true }
        return view.subviews.contains { hasSidebarMaterial(in: $0) }
    }
}

private extension NavigationSplitViewVisibility {
    /// "all", "detailOnly"…: the readable part of the description.
    var kindName: String {
        let text = String(describing: self)
        return text.split(separator: ".").last.map { $0.replacingOccurrences(of: ", isAutomatic: false)", with: "") } ?? text
    }
}

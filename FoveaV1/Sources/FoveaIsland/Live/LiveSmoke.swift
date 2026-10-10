import SwiftUI
import AppKit
import Carbon.HIToolbox
import FoveaCore
import FoveaKit
import FoveaPlatform

/// `Fovea --smoke`: the notch as it runs on the real Mac, walked through its states without a hand
/// on the keyboard. The real island model and controller, its window invisible, with stand-ins only
/// at the edges (IslandLive.Smoke): scripted words for the microphone, a recorded paste, a flat
/// picture for the screen, a file where the highlighter clicks. Key presses go to the island's own
/// key handlers as macOS would send them; the person's own keys and pointer are never watched, and
/// nothing reaches another app. The Workbench's smoke (WorkbenchSmoke.swift) checks the mock; this
/// checks the real thing: no samples on the board, the first run's rules aside.
@MainActor
package enum LiveSmoke {
    private static var failures: [String] = []
    /// `--smoke-shots=<folder>`: a picture of the island's window at each state worth looking at.
    private static var shots: URL? = CommandLine.arguments.first { $0.hasPrefix("--smoke-shots=") }
        .map { URL(fileURLWithPath: (String($0.dropFirst("--smoke-shots=".count)) as NSString).expandingTildeInPath, isDirectory: true) }
    private static weak var panel: NSWindow?

    /// Every check, one line each; true when all pass.
    package static func run(_ controller: IslandController) async -> Bool {
        let model = controller.model
        guard let live = model.live, live.smoke != nil else {
            print("FAIL smoke: the island isn't in smoke mode")
            return false
        }
        panel = live.panel
        if let shots {
            try? FileManager.default.createDirectory(at: shots, withIntermediateDirectories: true)
            live.panel?.alphaValue = 1
        }
        await settle(0.6)
        await rest(model)
        await hello(model)
        await voiceflow(model, live)
        let quick = await dispatch(model, live)
        if let quick { await session(model, live, id: quick) }
        await answers(model, live)
        await looks(controller, model)
        print(failures.isEmpty ? "SMOKE PASS" : "SMOKE FAIL: \(failures.count) check(s)")
        for name in failures { print("  failed: \(name)") }
        return failures.isEmpty
    }

    // MARK: Checks

    private static func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
        if !ok { failures.append(name) }
        let more = detail()
        print("\(ok ? "ok  " : "FAIL") \(name)\(more.isEmpty ? "" : "  (\(more))")")
    }

    /// The island's window, as the window server composites it, the top of the screen.
    private static func shot(_ name: String, _ model: WorkbenchModel) async {
        guard let shots, let panel else { return }
        try? await Task.sleep(for: .milliseconds(700))
        let size = model.stackLayout.outline.size
        let screen = panel.screen ?? NSScreen.main
        let w = max(size.width + 80, 420), h = min(max(size.height + 60, 120), (screen?.frame.height ?? 900))
        let local = CGRect(x: (model.display.frame.width - w) / 2, y: 0, width: w, height: h)
        guard let screen else { return }
        let rect = Screens.global(local, on: screen)
        var ids = [UnsafeRawPointer(bitPattern: UInt(panel.windowNumber))]
        guard let array = CFArrayCreate(nil, &ids, 1, nil),
              let image = CGImage(windowListFromArrayScreenBounds: rect, windowArray: array, imageOption: [.bestResolution]),
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }
        try? png.write(to: shots.appendingPathComponent("\(name).png"))
    }

    private static func settle(_ seconds: Double = 0.3) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// Waits until `condition` holds, or `timeout` passes; whether it held.
    private static func until(_ timeout: Double, _ condition: () -> Bool) async -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }

    // MARK: Keys, as macOS sends them

    static func flags(_ flags: NSEvent.ModifierFlags, _ code: Int) -> NSEvent {
        NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: flags,
                         timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil,
                         characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: UInt16(code))!
    }

    /// fn, pressed and let go.
    static func fn(_ model: WorkbenchModel) {
        model.functionKey.handle(flags(.function, kVK_Function))
        model.functionKey.handle(flags([], kVK_Function))
    }

    /// fn ⌃: fn down, ⌃ down with it, ⌃ up, fn up; both keys' monitors see all four.
    static func fnControl(_ model: WorkbenchModel) {
        let control = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.control.rawValue | ModifierPressMonitor.leftControlDeviceFlag)
        let edges = [flags(.function, kVK_Function), flags(control.union(.function), kVK_Control),
                     flags(.function, kVK_Control), flags([], kVK_Function)]
        for e in edges { model.functionKey.handle(e); model.leftControlKey.handle(e) }
    }

    /// Left ⌃ alone.
    private static func control(_ model: WorkbenchModel) {
        let down = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.control.rawValue | ModifierPressMonitor.leftControlDeviceFlag)
        for e in [flags(down, kVK_Control), flags([], kVK_Control)] { model.leftControlKey.handle(e); model.functionKey.handle(e) }
    }

    private static func command(_ model: WorkbenchModel) {
        let down = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.command.rawValue | ModifierHoldMonitor.leftCommandDeviceFlag)
        for e in [flags(down, kVK_Command), flags([], kVK_Command)] { model.leftCommandKey.handle(e) }
    }

    private static func option(_ model: WorkbenchModel) {
        let down = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.option.rawValue | ModifierHoldMonitor.leftOptionDeviceFlag)
        for e in [flags(down, kVK_Option), flags([], kVK_Option)] { model.leftOptionKey.handle(e) }
    }

    static func notchPoint(_ model: WorkbenchModel) -> CGPoint {
        CGPoint(x: model.display.frame.width / 2, y: max(4, model.metrics.safeAreaTop / 2))
    }

    static func away(_ model: WorkbenchModel) -> CGPoint {
        CGPoint(x: 80, y: model.display.frame.height - 80)
    }

    // MARK: At rest

    private static func rest(_ model: WorkbenchModel) async {
        check("at rest the island is silent", model.notchState == .silent)
        let rest = NotchGeometry.frames(density: .resting, metrics: model.metrics, spec: WorkbenchTokens.Island.spec)
        let shapes = model.nativeShapes
        check("at rest the island is the resting outline, so no glass shows round the notch",
              abs(shapes.island.width - rest.width) < 0.5 && abs(shapes.island.height - rest.minHeight) < 0.5,
              "\(shapes.island) vs \(rest.width)×\(rest.minHeight)")
        check("the board has no samples on the real Mac", model.v2BoardOrder.isEmpty, "\(model.v2BoardOrder.count)")
    }

    // MARK: The board, empty: Hello

    private static func hello(_ model: WorkbenchModel) async {
        model.panelPointer(away(model)); await settle(0.2)
        let p = notchPoint(model)
        // The pointer comes to rest on the notch.
        let opened = await until(4) {
            model.panelPointer(p)
            return model.notchState == .v2Board
        }
        check("hovering the notch with nothing running opens the board", opened, "\(model.notchState)")
        await shot("01-hello-board", model)
        check("…which greets instead of being empty", model.v2BoardSections.isEmpty
              && abs(model.v2BoardLayout.listHeight - WorkbenchTokens.Board.helloHeight) < 0.5,
              "rows \(model.v2BoardOrder.count), list \(model.v2BoardLayout.listHeight)")
        model.panelPointer(away(model))
        let closed = await until(3) { model.notchState == .silent }
        check("…and closes once the pointer leaves", closed, "\(model.notchState)")
        await settle(0.3)
    }

    // MARK: Voiceflow

    private static func voiceflow(_ model: WorkbenchModel, _ live: IslandLive) async {
        let P = WorkbenchTokens.Progress.self
        // Paste not found: nowhere to paste.
        live.smoke?.canPaste = false
        live.smoke?.words = ["um so this is a test of fovea"]
        fn(model); await settle(0.2)
        check("fn listens (Voiceflow)", model.notchState == .voiceFlow, "\(model.notchState)")
        try? await Task.sleep(for: P.minimumSpeech + .milliseconds(200))
        fn(model)
        check("fn again transcribes", model.notchState == .transcribing, "\(model.notchState)")
        let held = await until(6) { model.notchState == .pasteNotFound }
        check("with no field to paste into, the words wait at the notch (Paste not found)", held, "\(model.notchState)")
        check("…cleaned (no um, a capital, a full stop)", model.transcript == "So this is a test of fovea.", model.transcript)
        _ = model.escape(); await settle(0.4)
        check("Esc puts Paste not found away", model.notchState == .silent, "\(model.notchState)")

        // Pasted into a field.
        live.smoke?.canPaste = true
        live.smoke?.words = ["send the notes to the team"]
        fn(model); await settle(0.2)
        try? await Task.sleep(for: P.minimumSpeech + .milliseconds(200))
        fn(model)
        let landed = await until(6) { live.smoke?.pasted.last == "Send the notes to the team." }
        check("with a field, the words paste into it", landed, "\(live.smoke?.pasted ?? [])")
        let rested = await until(4) { model.notchState == .silent }
        check("…and the island leaves", rested, "\(model.notchState)")
        check("…and Home keeps the dictation", live.captures.captures.contains { $0.kind == .dictation && $0.text.hasPrefix("Send the notes") })

        // Silence.
        live.smoke?.words = [""]
        fn(model); await settle(0.2)
        try? await Task.sleep(for: P.minimumSpeech + .milliseconds(200))
        fn(model)
        let quiet = await until(6) { model.notchState == .noSpeech }
        check("nothing said: No speech detected", quiet, "\(model.notchState)")
        _ = await until(5) { model.notchState == .silent }

        // Esc while listening cancels; ⌘Z brings it back.
        fn(model); await settle(0.3)
        _ = model.escape(); await settle(0.2)
        check("Esc while listening cancels", model.notchState == .cancelled, "\(model.notchState)")
        _ = model.undoCancel(); await settle(0.2)
        check("…and ⌘Z undoes it", model.notchState == .voiceFlow, "\(model.notchState)")
        _ = model.escape(); await settle(0.2)
        _ = await until(6) { model.notchState == .silent }
        live.smoke?.canPaste = false
    }

    // MARK: Dispatch

    /// A request with everything taken, sent; returns the quick session it made.
    private static func dispatch(_ model: WorkbenchModel, _ live: IslandLive) async -> String? {
        let P = WorkbenchTokens.Progress.self
        fnControl(model); await settle(0.3)
        check("fn ⌃ listens for an agent (Dispatch)", model.notchState == .v2Voice, "\(model.notchState)")
        check("…its bar flows with the voice, as Voiceflow's", !model.v2AsksOver && model.notchState.collects)

        // ⌘ once, then a drag: a part of the screen.
        command(model); await settle(0.1)
        check("⌘ once turns on capture", model.capturing)
        model.finishSelection(CGRect(x: 300, y: 300, width: 240, height: 160))
        let part = await until(3) { model.liveReferents.count == 1 }
        check("…a drag takes that part, and capture goes off", part && !model.capturing, "\(model.liveReferents.count)")
        // ⌘ twice: the whole screen.
        command(model); command(model)
        let whole = await until(3) { model.liveReferents.count == 2 }
        check("⌘ twice takes the whole screen", whole, "\(model.liveReferents.count)")
        await shot("02-dispatch-voice", model)

        // ⌥ and a click on a file: its mark shows, then goes; the file is taken.
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("fovea-smoke-notes.txt")
        try? "Smoke notes".write(to: file, atomically: true, encoding: .utf8)
        let fileRect = CGRect(x: 1200, y: 120, width: 64, height: 72)
        live.smoke?.file = (file, fileRect)
        option(model); await settle(0.1)
        check("⌥ picks up the highlighter", model.highlighting && !model.capturing)
        model.updateHoverMark(live, at: CGPoint(x: fileRect.midX, y: fileRect.midY))
        check("…the file under the pointer is shaded before the click", model.hoverMark != nil)
        model.finishHighlight(from: CGPoint(x: fileRect.midX, y: fileRect.midY), to: CGPoint(x: fileRect.midX, y: fileRect.midY))
        let taken = await until(3) { model.liveReferents.contains { if case .file = $0.kind { return true }; return false } }
        check("…a click takes the file", taken, "\(model.liveReferents.map(\.kind))")
        check("…and marks it", !model.highlights.isEmpty)
        let faded = await until(2.5) { model.highlights.isEmpty }
        check("…the mark goes once it's taken (nothing stays on the screen)", faded, "\(model.highlights.count)")
        check("…and the highlighter is put down", !model.highlighting)

        // fn ⌃ again: Choose chat, with the words.
        live.smoke?.words = ["what's on my calendar tomorrow"]
        try? await Task.sleep(for: P.minimumSpeech)
        fnControl(model)
        let chose = await until(6) { model.notchState == .v2Send }
        check("fn ⌃ again transcribes, then Choose chat", chose, "\(model.notchState)")
        check("…the request is the words said", model.v2Spoken.lowercased().contains("calendar"), model.v2Spoken)
        await shot("03-choose-chat", model)
        control(model); await settle(0.4)
        check("left ⌃ opens every chat", model.v2Browsing)
        control(model); await settle(0.3)
        check("…and folds them again", !model.v2Browsing)
        _ = model.v2Key(.enter)
        let sent = await until(2) { model.notchState == .v2Board }
        check("Return sends: the board shows the new session", sent, "\(model.notchState)")
        let id = model.v2BoardOrder.first?.id
        check("…one session on it, the person's", model.v2BoardOrder.count == 1, "\(model.v2BoardOrder.count)")
        await shot("04-board", model)
        check("…and Home keeps the dispatch", live.captures.captures.contains { $0.kind == .dispatch })
        // The pointer is away: the board goes after its hold; a quick answer then opens by itself.
        model.panelPointer(away(model))
        let popped = await until(20) { model.notchState == .v2Chat }
        check("a quick answer opens by itself", popped, "\(model.notchState)")
        return id
    }

    // MARK: A session

    private static func session(_ model: WorkbenchModel, _ live: IslandLive, id: String) async {
        let P = WorkbenchTokens.Progress.self
        _ = await until(2) { model.notchState == .v2Chat }
        model.openV2(id); await settle(0.4)
        check("a session opens in the notch", model.notchState == .v2Chat && model.v2Focus == id)
        await shot("05-session", model)
        let usual = model.stackLayout.outline.size
        model.toggleV2Expanded(); await settle(0.6)
        let open = model.stackLayout.outline.size
        await shot("06-session-expanded", model)
        check("expanded, the session is wider", open.width > usual.width + 1, "\(usual) → \(open)")
        check("…and its words' column wider than the usual one", model.v2ChatLayout.column > V2Geometry.contentWidth,
              "\(model.v2ChatLayout.column) vs \(V2Geometry.contentWidth)")
        _ = model.escape(); await settle(0.4)
        check("Esc comes back to the usual size first", model.notchState == .v2Chat && !model.v2Expanded)

        // Asking more by voice: the session stays, the bar a band on top of it.
        fn(model); await settle(0.4)
        check("fn on the session asks more there", model.notchState == .v2Voice && model.v2Continuing == id)
        check("…the session stays on screen, under the bar's band", model.v2AsksOver)
        await shot("07-asking-more", model)
        let band = model.stackLayout.outline.size.height - model.v2ChatLayout.outline.size.height
        check("…the band is the voice bar's height", abs(band - WorkbenchTokens.Island.spec.voiceBelow) < 0.5, "\(band)")
        _ = model.escape(); await settle(0.4)
        check("Esc while asking more goes back to the session as it was", model.notchState == .v2Chat && model.v2Focus == id,
              "\(model.notchState)")
        // Nothing said: back to the session.
        live.smoke?.words = [""]
        fn(model); try? await Task.sleep(for: P.minimumSpeech + .milliseconds(200)); fn(model)
        let back = await until(6) { model.notchState == .v2Chat }
        check("asking more and saying nothing goes back to the session", back, "\(model.notchState)")
        // Said: the question goes into the session, which stays open, working, its last answer in view.
        live.smoke?.words = ["and add the room number"]
        fn(model); try? await Task.sleep(for: P.minimumSpeech + .milliseconds(200)); fn(model)
        let asked = await until(6) { model.notchState == .v2Chat && model.v2Task(id)?.state == .working }
        check("asked more: the session stays open, working on it", asked, "\(model.notchState) \(String(describing: model.v2Task(id)?.state))")
        check("…the earlier answer kept in view", (model.v2History[id] ?? []).count == 1 && model.v2ChatLayout.history)
        await shot("08-asked-more", model)
        _ = await until(20) { model.v2Task(id)?.state == .complete }

        // ✕ (or Esc): back to the board, never stuck open.
        _ = model.escape(); await settle(0.4)
        check("closing the session goes to the board", model.notchState == .v2Board, "\(model.notchState)")
        model.panelPointer(away(model))
        _ = await until(6) { model.notchState == .silent }

        // Pulled out: a window, and the notch is the board again (Hello with nothing running).
        model.openV2(id); await settle(0.3)
        model.dragOutV2(id, to: CGPoint(x: 700, y: 400)); await settle(0.1)
        model.endDragOutV2(id, at: CGPoint(x: 700, y: 400)); await settle(0.4)
        check("pulled out, the chat is a window of its own", model.v2Detached.contains { $0.id == id })
        check("…and the notch goes back to the board, not the chat", model.notchState == .v2Board, "\(model.notchState)")
        check("…greeting, with nothing else running", model.v2BoardSections.isEmpty)
        let gone = await until(8) { model.notchState == .silent }
        check("…which goes a moment after, the pointer away", gone, "\(model.notchState)")
        // The window's own box asks more.
        model.askMoreV2(id, text: "one more thing", inWindow: true)
        check("the pulled-out window's box asks more", model.v2Task(id)?.state == .working)
        _ = await until(20) { model.v2Task(id)?.state == .complete }
    }

    // MARK: Settings › Notch › Show an answer as soon as it's back

    private static func answers(_ model: WorkbenchModel, _ live: IslandLive) async {
        let P = WorkbenchTokens.Progress.self
        model.showAnswers = false
        await settle(0.2)
        fnControl(model); await settle(0.3)
        live.smoke?.words = ["is the meeting tomorrow afternoon"]
        try? await Task.sleep(for: P.minimumSpeech)
        fnControl(model)
        _ = await until(6) { model.notchState == .v2Send }
        _ = model.v2Key(.enter)
        model.panelPointer(away(model))
        let id = model.v2BoardOrder.first?.id
        _ = await until(20) { id.flatMap { model.v2Task($0)?.state } == .complete }
        await settle(0.6)
        check("with Show answers off, a quick answer waits on the board", model.notchState != .v2Chat, "\(model.notchState)")
        model.showAnswers = true
        if model.notchState != .silent { model.notchState = .silent }
    }

    // MARK: The notch's look

    private static func looks(_ controller: IslandController, _ model: WorkbenchModel) async {
        let before = controller.prefsForSmoke
        var p = before
        p.density = .compact
        controller.prefsForSmoke = p; await settle(0.3)
        check("Compact: the panels a step smaller", WorkbenchTokens.V2.width == 600, "\(WorkbenchTokens.V2.width)")
        p.density = .spacious
        controller.prefsForSmoke = p; await settle(0.3)
        check("Spacious: the old Compact's room", WorkbenchTokens.V2.width == 660, "\(WorkbenchTokens.V2.width)")
        p.panels = .floating
        controller.prefsForSmoke = p; await settle(0.3)
        check("Floating panels: a gap under the island", WorkbenchTokens.Native.panelGap == 8)
        if shots != nil {
            model.showAgentPanel(pinned: true); await shot("09-board-floating-dark", model)
            p.notchAppearance = .light; controller.prefsForSmoke = p
            await shot("10-board-floating-light", model)
            p.panels = .attached; controller.prefsForSmoke = p
            await shot("11-board-attached-light", model)
            p.notchAppearance = .dark; controller.prefsForSmoke = p
            await shot("12-board-attached-dark", model)
            model.closeAgentPanel(); await settle(0.4)
        }
        p.panels = .attached
        controller.prefsForSmoke = p; await settle(0.3)
        check("Attached panels: no gap", WorkbenchTokens.Native.panelGap == 0)
        controller.prefsForSmoke = before
    }
}

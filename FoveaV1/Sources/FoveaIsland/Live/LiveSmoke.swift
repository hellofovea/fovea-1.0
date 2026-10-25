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
        await input(controller, model, live)
        await selectionMarks()
        await landing(model, live)
        await cases(controller, model)
        await openAnyChat(controller, model)
        await askedBefore(controller, model)
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

    // Oct 15 review, ST-03.1: the keys go to the island's shortcuts (`ShortcutMonitor`), which
    // answer to the chords recorded in Settings › Shortcuts (fn, fn ⌃ and ⌘ by default, Oct 19),
    // and left ⌃ alone to its own monitor, as macOS would send them to both.

    /// fn, pressed and let go.
    static func fn(_ model: WorkbenchModel) {
        model.live?.shortcuts.handle(flags(.function, kVK_Function))
        model.live?.shortcuts.handle(flags([], kVK_Function))
    }

    /// fn ⌃: fn down, ⌃ down with it, ⌃ up, fn up; both keys' monitors see all four.
    static func fnControl(_ model: WorkbenchModel) {
        let control = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.control.rawValue | ModifierPressMonitor.leftControlDeviceFlag)
        let edges = [flags(.function, kVK_Function), flags(control.union(.function), kVK_Control),
                     flags(.function, kVK_Control), flags([], kVK_Function)]
        for e in edges { model.live?.shortcuts.handle(e); model.leftControlKey.handle(e) }
    }

    /// Left ⌃ alone.
    private static func control(_ model: WorkbenchModel) {
        let down = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.control.rawValue | ModifierPressMonitor.leftControlDeviceFlag)
        for e in [flags(down, kVK_Control), flags([], kVK_Control)] { model.leftControlKey.handle(e); model.live?.shortcuts.handle(e) }
    }

    /// ⌘ pressed and let go: the region's key again (Oct 19).
    private static func command(_ model: WorkbenchModel) {
        let down = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.command.rawValue | ModifierHoldMonitor.leftCommandDeviceFlag)
        for e in [flags(down, kVK_Command), flags([], kVK_Command)] { model.live?.shortcuts.handle(e) }
    }

    /// ⌥ pressed and let go: the region's key from Oct 17 to Oct 19, nothing now.
    private static func option(_ model: WorkbenchModel) {
        let down = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.option.rawValue | ModifierHoldMonitor.leftOptionDeviceFlag)
        for e in [flags(down, kVK_Option), flags([], kVK_Option)] { model.live?.shortcuts.handle(e) }
    }

    /// ⌘ held for a key (⌘C), then let go.
    private static func commandWithKey(_ model: WorkbenchModel, _ code: Int, _ text: String) {
        let down = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.command.rawValue | ModifierHoldMonitor.leftCommandDeviceFlag)
        let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: down,
                                   timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil,
                                   characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: UInt16(code))!
        for e in [flags(down, kVK_Command), key, flags([], kVK_Command)] { model.live?.shortcuts.handle(e) }
    }

    /// ⌥ held for a key (⌥ E), then let go.
    private static func optionWithKey(_ model: WorkbenchModel) {
        let down = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.option.rawValue | ModifierHoldMonitor.leftOptionDeviceFlag)
        let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: down,
                                   timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil,
                                   characters: "´", charactersIgnoringModifiers: "e", isARepeat: false, keyCode: UInt16(kVK_ANSI_E))!
        for e in [flags(down, kVK_Option), key, flags([], kVK_Option)] { model.live?.shortcuts.handle(e) }
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
        // Oct 18, Ryan: the first run's lines, in English or in Chinese, read as the same steps.
        let lines: [(String, String, AgentWork, String?)] = [
            ("Looking at the chat", "正在查看 the chat", .reading, "the chat"),
            ("Editing weekly-update.md", "正在编辑 weekly-update.md", .editing, "weekly-update.md"),
            ("Writing packing-list.md", "正在写入 packing-list.md", .editing, "packing-list.md"),
            ("Reading", "正在读取", .reading, nil),
            ("Thinking", "正在思考", .thinking, nil),
        ]
        let same = lines.allSatisfy { english, chinese, work, object in
            let a = WorkbenchModel.directorStep(english), b = WorkbenchModel.directorStep(chinese)
            return a.work == work && b.work == work && a.object == object && b.object == object
        }
        check("the first run's lines read as the same steps in English and in Chinese", same,
              lines.map { "\(WorkbenchModel.directorStep($0.1))" }.joined(separator: " "))
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

        // Oct 19, Ryan: ⌘ once takes a part of the screen, ⌘ twice the whole screen; ⌥ does nothing.
        option(model); await settle(0.1)
        check("⌥ does nothing any more", !model.capturing && model.liveReferents.isEmpty)
        await settle(0.4)
        option(model); option(model); await settle(0.4)
        check("…nor ⌥ twice", !model.capturing && model.liveReferents.isEmpty)
        // ⌘ once, then a drag: a part of the screen.
        command(model); await settle(0.1)
        check("⌘ once turns on capture", model.capturing)
        model.finishSelection(CGRect(x: 300, y: 300, width: 240, height: 160))
        let part = await until(3) { model.liveReferents.count == 1 }
        check("…a drag takes that part, and capture goes off", part && !model.capturing, "\(model.liveReferents.count)")
        // ⌘ held: capture while it's held, a part for each drag; let go, it ends.
        await settle(0.4)
        let rightDown = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.command.rawValue | ModifierHoldMonitor.rightCommandDeviceFlag)
        model.live?.shortcuts.handle(flags(rightDown, kVK_RightCommand)); await settle(0.1)
        check("⌘ held (the right one): capture while it's held", model.capturing)
        model.finishSelection(CGRect(x: 320, y: 500, width: 200, height: 120))
        let held = await until(3) { model.liveReferents.count == 2 }
        check("…a drag takes a part, and capture stays while ⌘ is held", held && model.capturing, "\(model.liveReferents.count)")
        await settle(0.35)
        model.live?.shortcuts.handle(flags([], kVK_RightCommand)); await settle(0.1)
        check("…let go, capture ends", !model.capturing && model.liveReferents.count == 2)
        // ⌘ with a key (⌘C, ⌘V) is never a press: capture its down turned on goes off at the key.
        await settle(0.4)
        let leftDown = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.command.rawValue | ModifierHoldMonitor.leftCommandDeviceFlag)
        model.live?.shortcuts.handle(flags(leftDown, kVK_Command))
        model.live?.shortcuts.handle(keyEvent(.keyDown, kVK_ANSI_C, leftDown, "c"))
        check("⌘C is never a press: capture goes off at the C", !model.capturing)
        model.live?.shortcuts.handle(flags([], kVK_Command)); await settle(0.1)
        commandWithKey(model, kVK_ANSI_C, "c"); await settle(0.5)
        check("…⌘C twice, quickly, takes nothing", !model.capturing && model.liveReferents.count == 2)
        // ⌘ twice: the whole screen, capture off, nothing else taken.
        command(model); command(model)
        let screen = await until(3) { model.liveReferents.count == 3 }
        check("…⌘ twice takes the whole screen, capture off, nothing else", screen && !model.capturing
              && model.liveReferents.last?.source == L("The whole screen"), "\(model.liveReferents.count)")
        if let second = model.liveReferents.dropFirst().first?.id { model.removeReferent(second) }
        _ = await until(2) { model.liveReferents.count == 2 }
        if let whole = model.liveReferents.last?.id { model.removeReferent(whole) }
        _ = await until(2) { model.liveReferents.count == 1 }
        await shot("02-dispatch-voice", model)

        // Oct 17, Ryan: files dragged onto the notch, never a click (a click may be opening it).
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("fovea-smoke-notes.txt")
        try? "Smoke notes".write(to: file, atomically: true, encoding: .utf8)
        let fileRect = CGRect(x: 1200, y: 120, width: 64, height: 72)
        live.smoke?.file = (file, fileRect)
        let onFile = live.global(CGPoint(x: fileRect.midX, y: fileRect.midY))
        model.autoTake(live, from: onFile, to: onFile, clicks: 1)
        await settle(0.3)
        check("a click on a file takes nothing", !model.liveReferents.contains { $0.fileURL == file } && model.liveReferents.count == 1)
        live.smoke?.file = nil
        model.fileDropTargeted = true; await settle(0.2)
        check("a file dragged over the notch lights it: the drop state", model.fileDropTargeted)
        await shot("02b-drop-state", model)
        let dropped = model.dropFiles([file], at: CGPoint(x: model.display.frame.width / 2, y: 30))
        model.fileDropTargeted = false
        let took = await until(3) { model.liveReferents.contains { $0.fileURL == file } }
        check("…dropped on it, the file joins the stack with its card", dropped && took, "\(model.liveReferents.map(\.kind))")
        check("…dropped again, it isn't taken twice", !model.dropFiles([file], at: .zero)
              && model.liveReferents.filter { $0.fileURL == file }.count == 1)
        // A plain click that selects nothing takes nothing.
        let before = model.liveReferents.count
        let plain = live.global(CGPoint(x: 600, y: 500))
        model.autoTake(live, from: plain, to: plain, clicks: 1)
        await settle(0.3)
        check("a plain click takes nothing", model.liveReferents.count == before)
        // A drag that selected words takes them, highlighted where they are (the accent), and the
        // mark stays while the session lasts.
        let line = CGRect(x: 420, y: 520, width: 360, height: 20)
        live.smoke?.selection = ("Ship the notch on Friday", [line], false)
        model.autoTake(live, from: live.global(CGPoint(x: line.minX, y: line.midY)), to: live.global(CGPoint(x: line.maxX, y: line.midY)), clicks: 1)
        let words = await until(3) { model.liveReferents.contains { $0.kind == .text("Ship the notch on Friday") } }
        check("a drag across words takes them, no key", words, "\(model.liveReferents.map(\.kind))")
        try? await Task.sleep(for: .seconds(WorkbenchTokens.Feedback.liveMarkHold + 0.4))
        check("…highlighted over exactly their line, still there a moment later",
              model.highlights.contains { $0.taken && $0.rects == [line] }, "\(model.highlights.map(\.rects))")
        await shot("02c-words-highlighted", model)
        live.smoke?.selection = nil

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
        await browsing(model)
        control(model); await settle(0.3)
        check("…and folds them again", !model.v2Browsing)
        _ = model.v2Key(.enter)
        // Oct 15 review, QA06: a moment of Sending, the chat locked, before the board.
        check("Return sends: first Sending to the chat, the chat locked", model.cases.sending?.isSending == true
              && model.notchState == .v2Send, "\(String(describing: model.cases.sending)) \(model.notchState)")
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

    /// Oct 15 review, QA04/QA05: every chat's search, nothing found, Load More, and a chat that
    /// can't take the request.
    private static func browsing(_ model: WorkbenchModel) async {
        model.setBrowseQuery("zzzz")
        check("a search with nothing in it says so", model.v2BrowseRows == [.status(.noMatch("zzzz"))],
              "\(model.v2BrowseRows.map(\.id))")
        model.setBrowseQuery(L("island.search.found", english: "notch"))
        let found = model.v2BrowseRows.compactMap { row -> String? in if case .chat(let c) = row { return c.title }; return nil }
        check("…a search finds chats by title or project", found.contains(L("Notch ears match the menu bar")), "\(found)")
        model.setBrowseQuery("")
        if let project = ChatBook.projects(of: model.v2BrowseAgent, in: ChatBook.chats).first(where: { $0.folder == ChatBook.project }) {
            model.pickV2Browse(.project(project))
        }
        let paged = model.v2BrowseRows
        let more = paged.last.map { row -> Bool in if case .more = row { return true }; return false } ?? false
        check("…a long list shows a page, then Load More", more, "\(paged.count) rows")
        if more, let last = paged.last { model.pickV2Browse(last) }
        let all = model.v2BrowseRows
        check("…Load More shows the rest", all.count > paged.count && !all.contains { if case .more = $0 { return true }; return false },
              "\(paged.count) → \(all.count)")
        let pick = model.v2Pick
        let blocked = all.first { row in if case .chat(let c) = row { return model.v2ChatBlock(c) != nil }; return false }
        if let blocked { model.pickV2Browse(blocked) }
        check("…a chat that can't take the request says why, and isn't chosen", blocked != nil && model.v2Pick == pick && model.v2Browsing,
              blocked.map { if case .chat(let c) = $0 { return model.v2ChatBlock(c) ?? "" }; return "" } ?? "none")
        model.pickV2Browse(.back(ChatBook.project))
        await settle(0.2)
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
        // Oct 15 review, QA23: closing it while it works never stops it.
        model.closeV2Chat(); await settle(0.3)
        check("closing a session at work never stops it", model.v2Task(id)?.state == .working && model.v2Task(id)?.stopped == false,
              "\(String(describing: model.v2Task(id)?.state))")
        _ = await until(20) { model.v2Task(id)?.state == .complete }
        model.openV2(id); await settle(0.4)

        // Oct 15 review, QA07: the last request edited in place, sent again, replacing its answer.
        let turns = (model.v2History[id] ?? []).count
        model.startEditV2(id); await settle(0.2)
        check("Edit puts the last request in place to change", model.cases.editing == id && !model.cases.editText.isEmpty)
        await shot("08b-editing", model)
        _ = model.escape(); await settle(0.2)
        check("…Esc leaves it as it was, the session open", model.cases.editing == nil && model.notchState == .v2Chat, "\(model.notchState)")
        model.startEditV2(id)
        model.cases.editText = "and add the floor too"
        model.sendEditV2(id); await settle(0.2)
        check("…sent again, it replaces the last answer; the ones before keep their place",
              model.v2Task(id)?.state == .working && (model.v2History[id] ?? []).count == turns
              && model.v2Followed[id] == "and add the floor too", "\((model.v2History[id] ?? []).count) vs \(turns)")
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

        // Its corner resizes the window, not its words (Oct 11): the size changes, the top-left stays.
        let base = V2DetachedLayout.size
        let before = model.v2Detached.first { $0.id == id }
        model.resizeDetachedV2(id, to: CGSize(width: base.width * 1.3, height: base.height * 1.3)); await settle(0.2)
        let after = model.v2Detached.first { $0.id == id }
        check("its corner makes the window bigger (the words keep their size), kept on the screen",
              abs((after?.size.width ?? 0) - base.width * 1.3) < 0.5 && after?.origin.x == before?.origin.x
              && (after.map { $0.origin.y + $0.size.height <= model.detachedArea.height } ?? false),
              "\(after?.size ?? .zero) at \(after?.origin ?? .zero)")
        model.resizeDetachedV2(id, to: base)
        // Oct 24, Ryan: its four sides and corners resize it, as a Mac window's: the side dragged
        // moves, the one across from it stays.
        func frame() -> CGRect { model.v2Detached.first { $0.id == id }.map { CGRect(origin: $0.origin, size: $0.size) } ?? .zero }
        func drag(_ x: Int, _ y: Int, by moved: CGSize) {
            let edge = V2WindowEdge(x: x, y: y)
            model.resizeDetachedV2(id, edge: edge, from: frame(), by: moved)
            model.endResizeDetachedV2(id, edge: edge)
        }
        let start = frame()
        drag(-1, 0, by: CGSize(width: -60, height: 0))
        let left = frame()
        check("its left edge, dragged out, widens it; its right edge stays",
              abs(left.width - (start.width + 60)) < 0.5 && abs(left.maxX - start.maxX) < 0.5 && left.height == start.height, "\(left)")
        drag(0, -1, by: CGSize(width: 0, height: -40))
        let top = frame()
        check("…its top edge, up, makes it taller; its foot stays",
              abs(top.height - (left.height + 40)) < 0.5 && abs(top.maxY - left.maxY) < 0.5 && top.width == left.width, "\(top)")
        drag(-1, -1, by: CGSize(width: 30, height: 30))
        let corner = frame()
        check("…its top-left corner, in, makes it smaller both ways; its bottom-right corner stays",
              abs(corner.width - (top.width - 30)) < 0.5 && abs(corner.height - (top.height - 30)) < 0.5
              && abs(corner.maxX - top.maxX) < 0.5 && abs(corner.maxY - top.maxY) < 0.5, "\(corner)")
        drag(1, 0, by: CGSize(width: -2000, height: 0))
        let least = frame()
        check("…past its smallest, it springs back to it, its left edge where it was",
              abs(least.width - base.width * WorkbenchTokens.V2.detachedResize.lowerBound) < 0.5 && abs(least.minX - corner.minX) < 0.5,
              "\(least)")
        model.resizeDetachedV2(id, to: base)

        // Let go at a side: it tucks into a tab there; a click brings it back out.
        model.moveDetachedV2(id, to: CGPoint(x: model.detachedArea.width - 80, y: 300))
        model.endMoveDetachedV2(id, pointer: CGPoint(x: model.detachedArea.width - 2, y: 320)); await settle(0.2)
        check("let go at the screen's right side, it tucks into a tab there",
              model.v2Detached.first { $0.id == id }?.docked == .right && !model.v2DetachedMoving)
        model.undockV2(id); await settle(0.2)
        let out = model.v2Detached.first { $0.id == id }
        check("…the tab clicked, the window comes back out, on the screen",
              out?.docked == nil && (out.map { $0.origin.x + $0.size.width <= model.detachedArea.width } ?? false))

        // On another display (a 2560 × 1440 one), it keeps its place on the screen (Oct 11).
        let area = model.detachedArea
        let spot = out.map { CGPoint(x: $0.origin.x / area.width, y: $0.origin.y / area.height) } ?? .zero
        model.moveDetachedArea(to: CGSize(width: 2560, height: 1440))
        let moved = model.v2Detached.first { $0.id == id }
        check("following the pointer to a bigger display, it keeps its place on the screen",
              moved.map { abs($0.origin.x / 2560 - spot.x) < 0.02 && abs($0.origin.y / 1440 - spot.y) < 0.02 } ?? false,
              "\(moved?.origin ?? .zero)")
        model.moveDetachedArea(to: model.display.frame.size)
        model.liveDetachedArea = nil
        // Oct 15 review, QA21/DSP-24: ✕ on a chat at work never stops it; only Stop does.
        model.askMoreV2(id, text: "and the weekend too", inWindow: true)
        model.closeDetachedV2(id); await settle(0.3)
        check("…closed, none is left out", model.v2Detached.isEmpty)
        check("✕ on a chat at work never stops it: it's back on the board, still working",
              model.v2Task(id)?.state == .working && model.v2Task(id)?.stopped == false && model.v2BoardOrder.contains { $0.id == id },
              "\(String(describing: model.v2Task(id)?.state))")
        check("…the board shows it there a moment", model.notchState == .v2Board, "\(model.notchState)")
        let finished = await until(20) { model.v2Task(id)?.state == .complete }
        check("…done, it waits Ready for review", finished && model.v2Ready.contains { $0.id == id })
        if model.notchState == .v2Chat { model.closeV2Chat() }
        model.panelPointer(away(model))
        _ = await until(8) { model.notchState == .silent }
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
        await settle(0.3)
        // Oct 15 review, QA10: not sent, it stays on Choose chat and nothing is made; Return tries again.
        let known = Set(model.agentTasks.map(\.id))
        model.cases.nextSend = .notSent
        _ = model.v2Key(.enter)
        let notSent = await until(2) { if case .notSent? = model.cases.sending { return true }; return false }
        check("not sent: Choose chat says so (Try Again, Choose Another Chat), and nothing is made",
              notSent && model.notchState == .v2Send && Set(model.agentTasks.map(\.id)) == known,
              "\(String(describing: model.cases.sending)) \(model.notchState)")
        await shot("09a-not-sent", model)
        _ = model.v2Key(.enter)
        let retried = await until(2) { model.notchState == .v2Board }
        check("…Try Again (Return) sends it", retried, "\(model.notchState)")
        model.panelPointer(away(model))
        let id = model.agentTasks.first { !known.contains($0.id) }?.id
        _ = await until(20) { id.flatMap { model.v2Task($0)?.state } == .complete }
        await settle(0.6)
        check("with Show answers off, a quick answer waits on the board", model.notchState != .v2Chat, "\(model.notchState)")
        model.showAnswers = true
        if model.notchState != .silent { model.notchState = .silent }
    }

    // MARK: Oct 15 review: Dispatch's sessions (Feedback/V2Cases.swift)

    /// The review's states that using the app doesn't reach (staged, as the Review menu does), and
    /// what each way on does: approvals, a question's form, the connection, reopening from Home,
    /// Open in the agent, Remembered.
    private static func cases(_ controller: IslandController, _ model: WorkbenchModel) async {
        let C = WorkbenchTokens.Cases.self
        // QA14: an approval for the session: Allow goes on, and says so.
        controller.stage("qa:approvalCommand"); await settle(0.3)
        let asking = model.v2Focus
        check("an approval shows its command, and for how long", model.v2FocusTask?.state == .needsYou
              && model.v2ApprovalDetail(model.v2FocusTask!).command != nil && model.v2Scope(asking ?? "") == .session)
        if let id = asking { model.allowTask(id) }
        await settle(0.2)
        check("…Allow goes on, a line saying so", model.v2Task(asking)?.state == .working
              && model.cases.decisions[asking ?? ""]?.hasPrefix(L("Allowed for this session · \("")")) == true,
              model.cases.decisions[asking ?? ""] ?? "none")
        // QA15: a few questions at once: Send Answers once each has one.
        controller.stage("qa:form"); await settle(0.3)
        if let id = model.v2Focus {
            check("a few questions at once: Send Answers waits for every answer", !model.v2FormComplete(id))
            for field in model.cases.forms[id] ?? [] { model.cases.formAnswers[id, default: [:]][field.id] = field.choices.first ?? "earHeight" }
            model.answerFormV2(id); await settle(0.2)
            check("…answered, it goes on", model.v2Task(id)?.state == .working && model.cases.forms[id] == nil)
        }
        // QA16: lost, Try Again: reconnecting, then fine.
        controller.stage("qa:lost"); await settle(0.3)
        if let id = model.v2Focus {
            model.retryConnectionV2(id)
            check("lost connection: Try Again reconnects", model.cases.connection[id] == .reconnecting)
            let fine = await until(C.reconnectTime + 1.5) { model.cases.connection[id] == nil }
            check("…and the header is plain again", fine)
        }
        // QA24: not sure it arrived: Send Again sends it.
        controller.stage("qa:unconfirmed"); await settle(0.3)
        if let id = model.v2Focus {
            model.sendAgainV2(id)
            check("not sure it arrived: Send Again sends it once more", model.cases.unconfirmed[id] == nil && model.v2Task(id)?.state == .working)
        }
        // QA26 (Oct 17, Ryan: Open in the session's agent, in place of Continue in): one way, the
        // session's own agent; its bar says it opened there, and the session stays.
        controller.stage("v2Chat:code"); await settle(0.3)
        if let id = model.v2Focus, let task = model.v2Task(id) {
            check("a session offers Open in its own agent", model.v2OpensInAgent(task) && task.agent == "claude-code")
            model.openInAgentV2(id)
            check("…which says it opened there, the session still open",
                  model.cases.barLines[id]?.text == L("Opened in \("Claude Code")") && model.notchState == .v2Chat,
                  model.cases.barLines[id]?.text ?? "none")
        }
        // QA25: Home's Open in Notch: Reopening…, then the session, read only; a chat that's gone.
        controller.stage("rest")
        model.demoSamples = false
        controller.reopen(captureID: "x-smoke-1", title: "Pull up my calendar for this afternoon.", agent: "Claude Code")
        check("Open in Notch: Reopening… first", model.notchState == .v2Chat && model.v2FocusTask.map { model.cases.reopening.contains($0.id) } == true)
        let reopened = await until(C.reopenTime + 1) { model.cases.reopening.isEmpty }
        check("…then the session, from before this launch: read only", reopened && model.v2FocusTask.map { model.cases.readOnly.contains($0.id) } == true)
        controller.reopen(captureID: "x-smoke-2", title: "Fix the hotkey monitor", agent: "Cursor")
        let gone = model.v2FocusTask.map { model.cases.gone.contains($0.id) } == true
        check("…a chat whose agent is gone says so", gone)
        if let id = model.v2Focus { model.askInNewChatV2(id) }
        check("…Ask in a New Chat: the request on Choose chat, to a new chat", model.notchState == .v2Send && model.v2Pick.chat == nil
              && model.v2Spoken == "Fix the hotkey monitor", model.v2Spoken)
        // NH-03: Remembered, with the setting on; Open calls the app's hook.
        controller.stage("rest")
        model.demoSamples = false
        var opened: String?
        controller.onOpenMemory = { opened = $0 }
        model.postMemoryV2(V2MemoryNotice(id: "memory-smoke", title: "Your afternoon meetings"))
        let shown = await until(C.memoryDelay + 1) { model.cases.memoryNotice != nil && model.notchState == .v2Board }
        let drawn = !model.boardSearchShown || model.v2BoardLayout.openChat.contains { $0.kind == .notice }
        check("Remembered: a row on the board, at rest", shown && model.v2BoardLayout.notice > 0 && drawn,
              "\(model.notchState) \(model.v2BoardLayout.openChat.map(\.kind))")
        model.openMemoryNotice()
        check("…Open goes to it (the app's hook)", opened == "memory-smoke" && model.cases.memoryNotice == nil)
        controller.onOpenMemory = nil
        controller.stage("rest")
        model.demoSamples = false
        model.notchState = .silent
    }

    // MARK: Oct 24, Ryan: every session asked more than once; the outline; whose words are whose

    private static func askedBefore(_ controller: IslandController, _ model: WorkbenchModel) async {
        let V = WorkbenchTokens.V2.self
        controller.stage("chats:board"); await settle(0.3)
        let counts = model.v2BoardOrder.map { model.v2Turns($0.id).count }
        check("Every session on the board was asked more than once", !counts.isEmpty && counts.allSatisfy { $0 >= 2 }, "\(counts)")
        model.openV2("t-snapshots"); await settle(0.4)
        let usual = model.v2ChatLayout
        let turns = model.v2Turns("t-snapshots")
        check("…opened, its requests at the usual size, the outline at the right in a gutter the words leave it",
              usual.history && turns.count == 3 && abs(usual.column - (usual.contentWidth - V.outlineGutter)) < 0.5
              && abs(usual.barWidth - usual.contentWidth) < 0.5, "\(turns.count) requests, column \(usual.column)")
        check("…each request a bubble at the right, at most its share of the column; the answer open at the left",
              turns.allSatisfy { V2RequestBubble.bubbleWidth($0.question, width: usual.column) <= V2RequestBubble.widest(usual.column) + 0.5 }
              && V2RequestBubble.widest(usual.column) < usual.column)
        await shot("41-asked-before", model)
        model.setV2Size(.expanded); await settle(0.5)
        check("…expanded, every request, the outline in the margin",
              model.v2ChatLayout.size == .expanded && V2Outline.items(model.v2Turns("t-snapshots")).count == 3)
        await shot("42-asked-before-expanded", model)
        model.setV2Size(.usual); await settle(0.3)
        model.closeV2Chat(); await settle(0.3)
        // A sample chat opened from the search: its exchanges so far, the last one where it is now.
        if let chat = ChatBook.chat("cx-investors", in: ChatBook.chats) { model.openChat(chat) }
        let id = model.v2Focus ?? ""
        check("A sample chat opened from the search opens on its exchanges so far, the last where it is now",
              model.notchState == .v2Chat && model.v2Turns(id).count == 3 && model.v2FocusTask?.answer != nil
              && model.v2ChatLayout.history && !model.isBlankChat(id), "\(model.v2Turns(id).count)")
        model.askMoreV2(id, text: "Shorten it to four paragraphs", inWindow: true)
        check("…asked there, its last exchange joins the ones before", (model.v2History[id] ?? []).count == 3
              && model.v2Turns(id).last?.question == "Shorten it to four paragraphs", "\((model.v2History[id] ?? []).count)")
        controller.stage("rest")
        model.demoSamples = false
        model.notchState = .silent
    }

    // MARK: Oct 24, Ryan: open any chat from the board (Feedback/OpenChat.swift)

    private static func openAnyChat(_ controller: IslandController, _ model: WorkbenchModel) async {
        let O = WorkbenchTokens.OpenChat.self
        controller.stage("chats:hello"); await settle(0.3)
        check("Open any chat: with nothing running, the greeting and the search beside it",
              model.notchState == .v2Board && model.v2BoardLayout.openChat.first?.kind == .hello,
              "\(model.v2BoardLayout.openChat.map(\.kind))")
        controller.stage("chats:board"); await settle(0.3)
        let parts = model.v2BoardLayout.openChat.map(\.kind)
        check("…running, the search on a bar over the board, the pinned chats first",
              parts.first == .header && parts.dropFirst().first == .pinned && parts.contains(.sessions), "\(parts)")
        // Five sessions in view: their rows, and a seam before each state's part that starts in them.
        let B = WorkbenchTokens.Board.self
        var before = 0
        let seams = CGFloat(max(0, model.v2BoardSections.prefix { part in
            defer { before += part.tasks.count }
            return before < O.rowsVisible
        }.count - 1))
        let sessions = model.v2BoardLayout.openChat.first { $0.kind == .sessions }?.height ?? 0
        check("…its sessions five in view, the rest a scroll away",
              model.v2BoardOrder.count > O.rowsVisible && model.v2BoardLayout.scrolls
              && abs(sessions - (CGFloat(O.rowsVisible) * B.row + seams * B.groupGap)) < 0.5,
              "\(model.v2BoardOrder.count) sessions, \(sessions) pt")
        model.openChatPicker(); await settle(0.3)
        let listed = model.chatPickerSections.reduce(0) { $0 + $1.chats.count }
        check("…the search lists every chat", model.chatPickerOpen && listed == ChatBook.chats.count, "\(listed) of \(ChatBook.chats.count)")
        // The headers of the parts the first five chats are in (Suggested 1, Pinned 3, Recent 1).
        var seen = 0
        let heads = CGFloat(model.chatPickerSections.prefix { section in
            defer { seen += section.chats.count }
            return seen < O.rowsVisible
        }.count)
        check("…five in view, the rest a scroll away",
              abs(OpenChatResults.height(model: model) - (heads * O.sectionHeader + CGFloat(O.rowsVisible) * O.row)) < 0.5,
              "\(OpenChatResults.height(model: model))")
        model.panelPointer(away(model)); await settle(WorkbenchTokens.Panel.exitGrace + 0.4)
        check("…it stays while the pointer is away", model.notchState == .v2Board && model.chatPickerOpen, "\(model.notchState)")
        model.chatPickerQuery = "gaze"
        let found = model.chatPickerSections.flatMap(\.chats)
        check("…typed, the chats with the words", !found.isEmpty && found.allSatisfy {
            $0.title.localizedCaseInsensitiveContains("gaze") || $0.folder.localizedCaseInsensitiveContains("gaze") }, "\(found.count)")
        model.chatPickerQuery = ""
        if let blocked = ChatBook.chats.first(where: { model.v2ChatBlock($0) != nil }) {
            model.openChat(blocked)
            check("…one that can't take a request doesn't open", model.notchState == .v2Board && model.chatPickerOpen)
        }
        let picked = ChatBook.chat("cx-landing", in: ChatBook.chats)
        if let picked { model.openChat(picked) }
        let id = model.v2Focus ?? ""
        check("…a chat picked opens in the notch, nothing sent yet, its box ready",
              model.notchState == .v2Chat && model.isOpenedChat(id) && model.v2ChatFromBoard && model.v2FocusTask?.session == picked?.title,
              "\(model.notchState)")
        await shot("40-open-any-chat-opened", model)
        model.askMoreV2(id, text: "Tighten the hero copy", inWindow: true)
        check("…asked there, it works in that chat and joins the board",
              !model.isOpenedChat(id) && model.v2Task(id)?.state == .working && model.v2BoardOrder.contains { $0.id == id }
              && (model.v2History[id] ?? []).isEmpty, "\(model.v2Task(id)?.state as Any)")
        model.closeV2Chat()
        check("…and closing it comes back to the board", model.notchState == .v2Board, "\(model.notchState)")
        // Pins are kept (a staged state's aren't).
        model.demoSamples = false
        model.togglePin("cx-hotkey")
        check("…a pin is kept in the prefs", controller.prefsForSmoke.pinnedChats.last == "cx-hotkey")
        model.togglePin("cx-hotkey")
        check("…and so is unpinning", controller.prefsForSmoke.pinnedChats == model.pinnedChats
              && !controller.prefsForSmoke.pinnedChats.contains("cx-hotkey"))
        model.openChatPicker()
        _ = model.escape()
        check("…Esc closes the search first", model.notchState == .v2Board && !model.chatPickerOpen)
        _ = model.escape()
        check("…then the board", model.notchState == .silent, "\(model.notchState)")
        controller.stage("rest")
        model.demoSamples = false
        model.notchState = .silent
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

    // MARK: Oct 15 review: the notch's input side (IslandInput.swift)

    private static func keyEvent(_ type: NSEvent.EventType, _ code: Int, _ flags: NSEvent.ModifierFlags, _ text: String = "") -> NSEvent {
        NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags,
                         timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil,
                         characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: UInt16(code))!
    }

    /// Right ⌘ alone (`NX_DEVICERCMDKEYMASK`): free since Oct 17, when ⌥ took the screen.
    private static func rightCommand(_ model: WorkbenchModel) {
        let down = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.command.rawValue | ModifierHoldMonitor.rightCommandDeviceFlag)
        for e in [flags(down, kVK_RightCommand), flags([], kVK_RightCommand)] { model.live?.shortcuts.handle(e) }
    }

    /// Says something on Voiceflow's bar and stops, the words ready to wait at the notch.
    private static func dictate(_ model: WorkbenchModel, _ live: IslandLive, _ words: String) async {
        live.smoke?.words = [words]
        fn(model); await settle(0.2)
        try? await Task.sleep(for: WorkbenchTokens.Progress.minimumSpeech + .milliseconds(200))
        fn(model)
    }

    private static func toRest(_ model: WorkbenchModel) async {
        for _ in 0..<4 where model.notchState != .silent { _ = model.escape(); await settle(0.2) }
        _ = await until(6) { model.notchState == .silent }
        await settle(0.3)
    }

    private static func input(_ controller: IslandController, _ model: WorkbenchModel, _ live: IslandLive) async {
        let before = controller.prefsForSmoke
        live.smoke?.canPaste = false
        await toRest(model)

        // ST-03.1: the shortcuts answer to what Settings › Shortcuts recorded.
        var p = before
        p.shortcutChords[FoveaKeys.voiceflow.id] = KeyChord(modifiers: ["right ⌘"])
        controller.prefsForSmoke = p; await settle(0.3)
        fn(model); await settle(0.3)
        check("ST-03.1 Voiceflow recorded as right ⌘: fn no longer listens", model.notchState == .silent, "\(model.notchState)")
        rightCommand(model); await settle(0.3)
        check("…right ⌘ pressed alone listens", model.notchState == .voiceFlow, "\(model.notchState)")
        await toRest(model)
        p.shortcutChords[FoveaKeys.dispatch.id] = KeyChord(modifiers: ["⌥"], keyCode: kVK_Space, keyCap: "Space")
        controller.prefsForSmoke = p; await settle(0.3)
        check("…a plain Space at rest stays the app's",
              !live.shortcuts.handleKey(keyEvent(.keyDown, kVK_Space, [], " ")) && model.notchState == .silent)
        _ = live.shortcuts.handleKey(keyEvent(.keyUp, kVK_Space, [], " "))
        let option = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.option.rawValue | ModifierHoldMonitor.leftOptionDeviceFlag)
        live.shortcuts.handle(flags(option, kVK_Option))
        let kept = live.shortcuts.handleKey(keyEvent(.keyDown, kVK_Space, option, " "))
        await settle(0.3)
        check("…Dispatch recorded as ⌥ Space: its key's down opens Dispatch, the key kept from the app",
              kept && model.notchState == .v2Voice, "\(kept) \(model.notchState)")
        check("…its up kept too", live.shortcuts.handleKey(keyEvent(.keyUp, kVK_Space, option, " ")))
        live.shortcuts.handle(flags([], kVK_Option))
        check("…and ⌥ held with a key is no press of ⌥ (capture stays off)", !model.capturing)
        fnControl(model); await settle(0.3)
        check("…fn ⌃ is nothing now", model.notchState == .v2Voice, "\(model.notchState)")
        await toRest(model)
        p.shortcutChords[FoveaKeys.voiceflow.id] = KeyChord(modifiers: [])
        controller.prefsForSmoke = p; await settle(0.3)
        rightCommand(model); fn(model); await settle(0.3)
        check("…a cleared shortcut does nothing", model.notchState == .silent, "\(model.notchState)")
        controller.prefsForSmoke = before; await settle(0.3)
        fn(model); await settle(0.3)
        check("…back to the defaults, fn listens again", model.notchState == .voiceFlow, "\(model.notchState)")

        // VF04, QA02: past three, +N; opened, one row that scrolls, each numbered.
        model.referents = model.sampleReferents(3)
        await settle(0.3)
        check("VF04 three referents: no +N", model.stackLayout.more == nil)
        model.referents.append(contentsOf: model.sampleReferents(2))
        await settle(0.3)
        let collapsed = model.stackLayout
        check("…five: +2 on the stack", collapsed.more != nil && collapsed.moreCount == 2, "\(collapsed.moreCount)")
        check("…clear of the waveform", (collapsed.more?.maxX ?? .infinity) < collapsed.waveform.x - WorkbenchTokens.Island.waveformSpan / 2,
              "\(collapsed.more?.maxX ?? 0) vs \(collapsed.waveform.x)")
        await shot("13-stack-more", model)
        model.setExpanded(true); await settle(0.4)
        check("…opened, one row", model.stackLayout.rows == 1 && Set(model.stackLayout.cards.map(\.top)).count == 1)
        model.referents.append(contentsOf: model.sampleReferents(7, otherDisplay: 1))
        await settle(0.3)
        let wide = model.stackLayout
        check("…twelve: still one row, wider than the island, so it scrolls",
              wide.rows == 1 && wide.scrollMax > 0 && wide.scrollThumb != nil && wide.cards.count == 12, "\(wide.scrollMax)")
        let first = wide.cards[0].cx
        model.scrollStack(by: 120); await settle(0.2)
        check("…a swipe moves the row sideways", abs(model.stackLayout.cards[0].cx - (first - 120)) < 0.5,
              "\(first) → \(model.stackLayout.cards[0].cx)")
        await shot("14-stack-row-scrolled", model)
        model.scrollStack(by: 100_000)
        check("…to its end and no further", abs(model.stackLayout.scroll - model.stackLayout.scrollMax) < 0.5)
        let second = model.liveReferents[1].id
        model.inspect(second); await settle(0.4)
        check("…a click on one opens it larger, its number and where it came from under it",
              model.inspectedId == second && model.stackLayout.caption != nil)
        await shot("15-stack-inspect", model)
        check("VF05 one taken on the other display says so",
              model.liveReferents[6].whereTaken.hasPrefix(CapturedReferent.otherDisplayLine), model.liveReferents[6].whereTaken)
        model.inspect(nil); model.setExpanded(false)
        await toRest(model)
        // QA02: Choose chat keeps them, "+N" on its stack too.
        live.smoke?.words = ["fix the button on this page"]
        fnControl(model); await settle(0.3)
        model.referents = model.sampleReferents(5)
        try? await Task.sleep(for: WorkbenchTokens.Progress.minimumSpeech)
        fnControl(model)
        let choosing = await until(6) { model.notchState == .v2Send }
        check("QA02 Choose chat keeps all five referents", choosing && model.liveReferents.count == 5, "\(model.notchState)")
        await shot("16-choose-chat-more", model)
        await toRest(model)

        // VF09, VF10: the held words.
        await dictate(model, live, "hold these words")
        _ = await until(6) { model.notchState == .pasteNotFound }
        model.setPasteHover(true)
        try? await Task.sleep(for: WorkbenchTokens.Paste.duration + .milliseconds(500))
        check("VF09 the pointer on the held words keeps them past their 5 s", model.notchState == .pasteNotFound, "\(model.notchState)")
        await shot("17-held-words-paste", model)
        model.setPasteHover(false)
        check("…leaving starts the 5 s again", model.pasteRemaining(at: Date()) > 0.95, "\(model.pasteRemaining(at: Date()))")
        check("VF10 Paste with no field focused keeps the words", !model.pasteHeldWords() && model.notchState == .pasteNotFound)
        live.smoke?.canPaste = true
        let pasted = model.pasteHeldWords()
        check("…with one, Paste puts them there", pasted && live.smoke?.pasted.last == "Hold these words.", "\(live.smoke?.pasted ?? [])")
        let rested = await until(3) { model.notchState == .silent }
        check("…and the notch rests", rested, "\(model.notchState)")
        live.smoke?.canPaste = false
        await toRest(model)

        // Oct 17, Ryan: a dictation pastes what was taken after the words, into the same field: words
        // taken in quotes on their own line, a screenshot as a picture, a file as the file.
        live.smoke?.canPaste = true
        live.smoke?.pastedPieces = []
        live.smoke?.words = ["move this under the title"]
        fn(model); await settle(0.3)
        let draft = CGRect(x: 300, y: 640, width: 300, height: 20)
        live.smoke?.selection = ("my draft", [draft], true)
        model.autoTake(live, from: live.global(CGPoint(x: draft.minX, y: draft.midY)), to: live.global(CGPoint(x: draft.maxX, y: draft.midY)), clicks: 1)
        await settle(0.3)
        check("in Voiceflow, words selected in the field the words paste into stay there", model.liveReferents.isEmpty)
        let quote = CGRect(x: 300, y: 400, width: 320, height: 20)
        live.smoke?.selection = ("The quarterly numbers", [quote], false)
        model.autoTake(live, from: live.global(CGPoint(x: quote.minX, y: quote.midY)), to: live.global(CGPoint(x: quote.maxX, y: quote.midY)), clicks: 1)
        _ = await until(2) { model.liveReferents.count == 1 }
        live.smoke?.selection = nil
        // Oct 17, Ryan: a taken passage's mark stays for the session, and goes with its referent.
        let gone = CGRect(x: 300, y: 460, width: 200, height: 20)
        live.smoke?.selection = ("Remove me", [gone], false)
        model.autoTake(live, from: live.global(CGPoint(x: gone.minX, y: gone.midY)), to: live.global(CGPoint(x: gone.maxX, y: gone.midY)), clicks: 1)
        _ = await until(2) { model.liveReferents.count == 2 }
        live.smoke?.selection = nil
        if let removed = model.liveReferents.last?.id { model.removeReferent(removed) }
        _ = await until(2) { model.liveReferents.count == 1 }
        check("…a taken passage removed from the stack takes its highlight with it",
              !model.highlights.contains { $0.rects == [gone] } && model.highlights.contains { $0.taken && $0.rects == [quote] })
        LiveSmoke.command(model); await settle(0.1)
        model.finishSelection(CGRect(x: 500, y: 300, width: 200, height: 140))
        _ = await until(3) { model.liveReferents.count == 2 }
        let notes = FileManager.default.temporaryDirectory.appendingPathComponent("fovea-smoke-plan.txt")
        try? "Plan".write(to: notes, atomically: true, encoding: .utf8)
        model.dropFiles([notes], at: CGPoint(x: model.display.frame.width / 2, y: 30))
        _ = await until(2) { model.liveReferents.count == 3 }
        try? await Task.sleep(for: WorkbenchTokens.Progress.minimumSpeech)
        fn(model)
        let pastedAll = await until(6) { !(live.smoke?.pastedPieces.isEmpty ?? true) }
        let pieces = live.smoke?.pastedPieces ?? []
        let words = pieces.first == .text("Move this under the title.\n“The quarterly numbers”\n")
        let picture: Bool = { if pieces.count > 1, case .image = pieces[1] { return true }; return false }()
        check("Oct 17 dictation pastes the words, then what was taken in order: the quote, the screenshot, the file",
              pastedAll && words && picture && pieces.last == .file(notes) && pieces.count == 4, "\(pieces.count) pieces")
        check("…landed, the words it took are no longer highlighted", !model.highlights.contains(where: \.taken))
        await toRest(model)
        live.smoke?.canPaste = false

        // ST-04.2/3: Tidy my words off, the words exactly as said.
        p = before; p.tidyWords = false
        controller.prefsForSmoke = p; await settle(0.3)
        await dictate(model, live, "um so this is a test")
        _ = await until(6) { model.notchState == .pasteNotFound }
        check("ST-04.2 Tidy my words off: exactly what was said", model.transcript == "um so this is a test", model.transcript)
        await toRest(model)
        controller.prefsForSmoke = before; await settle(0.3)

        // IS02: Motion.
        p = before; p.motion = .reduce
        controller.prefsForSmoke = p; await settle(0.2)
        let reduced = model.reduceMotion
        p.motion = .full
        controller.prefsForSmoke = p; await settle(0.2)
        check("IS02 Motion: Reduce reduces, Full doesn't, whatever the Mac says", reduced && !model.reduceMotion)
        controller.prefsForSmoke = before; await settle(0.2)

        // NH-04: a fix in Settings has its button, and it opens there.
        var opened: [String] = []
        controller.onOpenSettings = { opened.append($0) }
        model.showVoiceError(.micUnavailable); await settle(0.3)
        check("NH-04 Microphone unavailable offers Choose Microphone…", model.voiceError?.action == .chooseMicrophone)
        model.setErrorHover(true)
        await shot("18-choose-microphone", model)
        model.setErrorHover(false)
        model.performErrorAction(.micUnavailable); await settle(0.3)
        model.showVoiceError(.sessionExpired); await settle(0.3)
        model.performErrorAction(.sessionExpired); await settle(0.3)
        check("…which opens Settings › Voice; Sign in opens Account; the notch rests",
              opened == ["voice", "account"] && model.notchState == .silent, "\(opened) \(model.notchState)")
        controller.onOpenSettings = nil

        // IS05: a press opens the island on the display with the pointer.
        let each = NSScreen.screens.allSatisfy { screen in
            Screens.same(Screens.forPress(at: CGPoint(x: screen.frame.midX, y: screen.frame.midY)), screen)
        }
        check("IS05 a press opens the island on the display with the pointer (\(NSScreen.screens.count) display(s))", each)
        await toRest(model)
        controller.prefsForSmoke = before
    }

    // MARK: Oct 18, Ryan: the marks over taken words, in the right place, on one window only

    private static func same(_ a: CGRect, _ b: CGRect, within e: CGFloat = 0.01) -> Bool {
        abs(a.minX - b.minX) <= e && abs(a.minY - b.minY) <= e && abs(a.width - b.width) <= e && abs(a.height - b.height) <= e
    }

    private static func selectionMarks() async {
        // A selection's shape from its bounds and its first and last lines (web content).
        let shape = SelectionShape.make(union: CGRect(x: 100, y: 100, width: 400, height: 60),
                                        first: CGRect(x: 250, y: 100, width: 250, height: 20),
                                        last: CGRect(x: 100, y: 140, width: 200, height: 20))
        check("Oct 18 a three-line selection is marked as drawn: from its start, the full line, to its end",
              shape == [CGRect(x: 250, y: 100, width: 250, height: 20), CGRect(x: 100, y: 120, width: 400, height: 20),
                        CGRect(x: 100, y: 140, width: 200, height: 20)], "\(shape)")
        let one = CGRect(x: 250, y: 100, width: 100, height: 20)
        check("…one line, its bounds", SelectionShape.make(union: one, first: one, last: one) == [one])
        let toBreak = SelectionShape.make(union: CGRect(x: 100, y: 100, width: 400, height: 40),
                                          first: CGRect(x: 250, y: 100, width: 250, height: 20),
                                          last: CGRect(x: 100, y: 140, width: 0, height: 20))
        check("…ending at a line break, nothing past it", toBreak == [CGRect(x: 250, y: 100, width: 250, height: 20),
                                                                     CGRect(x: 100, y: 120, width: 400, height: 20)], "\(toBreak)")
        // Known Accessibility rects (global, top-left) land exactly where they are in their window,
        // and the window's frame in AppKit's points is the window's own.
        let window = CGRect(x: 200, y: 150, width: 800, height: 600)
        let ax = CGRect(x: 412.5, y: 330, width: 300, height: 18)
        let h = Screens.primaryHeight
        check("…a known AX rect lands exactly in its window", same(MarkGeometry.local(ax, in: window), CGRect(x: 212.5, y: 180, width: 300, height: 18))
              && same(MarkGeometry.appKitFrame(window, primaryHeight: h), CGRect(x: 200, y: h - 750, width: 800, height: 600)))
        let everyDisplay = NSScreen.screens.allSatisfy { screen in
            let global = CGRect(x: screen.frame.minX + 100, y: h - screen.frame.maxY + 50, width: 40, height: 18)
            return same(Screens.local(global, on: screen), CGRect(x: 100, y: 50, width: 40, height: 18))
        }
        check("…and in the island's points on every display (\(NSScreen.screens.count))", everyDisplay)

        // A real window of Fovea's own with known words selected: what Accessibility says, and where
        // the mark window draws it, against where the text view itself draws the selection.
        // A panel, so it shows on the Space in front even over another app taken full screen.
        let target = NSPanel(contentRect: MarkGeometry.appKitFrame(CGRect(x: 260, y: 220, width: 480, height: 260), primaryHeight: h),
                             styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        target.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        target.alphaValue = 0.02
        target.isReleasedWhenClosed = false
        let scroll = NSScrollView(frame: target.contentView!.bounds)
        let text = NSTextView(frame: scroll.bounds)
        text.string = "The quarterly numbers are in. Revenue grew in every region, and the notch team shipped the stack on Friday. Next week we look at retention."
        text.font = .systemFont(ofSize: 16)
        scroll.documentView = text
        target.contentView = scroll
        target.orderFrontRegardless()
        target.makeFirstResponder(text)
        let selected = NSRange(location: 30, length: 70)
        text.setSelectedRange(selected)
        await settle(0.4)
        let targetBounds = CGRect(x: 260, y: 220, width: 480, height: 260)
        let id = CGWindowID(target.windowNumber)
        let onScreen = ((CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]])?.first?[kCGWindowIsOnscreen as String] as? Bool) == true
        if !onScreen {
            print("ok   …(the window checks skipped: Fovea's test window isn't on the Space in front)")
        } else {
            // Where the text view draws the selection, line by line, in the window's top-left points.
            let lm = text.layoutManager!, glyphs = lm.glyphRange(forCharacterRange: selected, actualCharacterRange: nil)
            var expected: [CGRect] = []
            lm.enumerateEnclosingRects(forGlyphRange: glyphs, withinSelectedGlyphRange: glyphs, in: text.textContainer!) { r, _ in
                var rr = r
                rr.origin.x += text.textContainerOrigin.x; rr.origin.y += text.textContainerOrigin.y
                let inWindow = text.convert(rr, to: nil)
                expected.append(CGRect(x: inWindow.minX, y: targetBounds.height - inWindow.maxY, width: inWindow.width, height: inWindow.height))
            }
            // Where Accessibility puts that selection (global top-left; Fovea's own windows can't be
            // read from inside Fovea, so the rects are the text view's, made global as AX gives them)
            // lands back on the same lines in the window, exactly.
            let global = expected.map { $0.offsetBy(dx: targetBounds.minX, dy: targetBounds.minY) }
            check("…a selection's global rects land on its lines in its window, exactly",
                  zip(global.map { MarkGeometry.local($0, in: targetBounds) }, expected).allSatisfy { same($0, $1) })
            // The mark window over it: the target's own frame, just above it.
            let marks = MarkWindow(target: id, bounds: targetBounds)
            marks.show(expected, color: .systemBlue.withAlphaComponent(0.3), radius: 3, outset: 0)
            let showing = marks.follow()
            await settle(0.2)
            let info = (CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(marks.windowNumber)) as? [[String: Any]])?.first
            let placed = (info?[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0) }
            let above = (CGWindowListCopyWindowInfo([.optionOnScreenAboveWindow], id) as? [[String: Any]])?
                .contains { ($0[kCGWindowNumber as String] as? Int) == marks.windowNumber } ?? false
            check("…the marks' window is exactly over its window, just above it", showing && placed.map { same($0, targetBounds) } == true && above,
                  "\(String(describing: placed))")
            target.close()
            await settle(0.3)
            check("…and goes when its window does", !marks.follow() && !marks.isVisible)
            marks.close()
        }
        target.close()
    }

    // MARK: Oct 18, Ryan: the words land where the pointer is as they're pasted

    private static func landing(_ model: WorkbenchModel, _ live: IslandLive) async {
        await toRest(model)
        live.smoke?.landedOn = []
        live.smoke?.canPaste = false
        live.smoke?.fieldUnderPointer = false
        // Nothing under the pointer at the press; a field there by the time the words land.
        live.smoke?.words = ["under the pointer"]
        fn(model); await settle(0.2)
        try? await Task.sleep(for: WorkbenchTokens.Progress.minimumSpeech + .milliseconds(200))
        fn(model)
        live.smoke?.fieldUnderPointer = true
        let there = await until(6) { live.smoke?.landedOn.last == "pointer" }
        check("Oct 18 the words land in the field under the pointer as they're pasted, not where it was at the press",
              there && live.smoke?.pasted.last == "Under the pointer.", "\(live.smoke?.landedOn ?? [])")
        await toRest(model)
        // No field under the pointer: the focused field.
        live.smoke?.fieldUnderPointer = false
        live.smoke?.canPaste = true
        await dictate(model, live, "into the focused field")
        let focused = await until(6) { live.smoke?.landedOn.last == "focused" && live.smoke?.pasted.last == "Into the focused field." }
        check("…with none under the pointer, the focused field", focused, "\(live.smoke?.landedOn ?? [])")
        await toRest(model)
        // Neither: the words wait at the notch, and Paste on them follows the same rule.
        live.smoke?.canPaste = false
        await dictate(model, live, "nowhere to go")
        let held = await until(6) { model.notchState == .pasteNotFound }
        check("…with neither, Paste not found", held, "\(model.notchState)")
        live.smoke?.fieldUnderPointer = true
        check("…Paste on the held words lands under the pointer too", model.pasteHeldWords() && live.smoke?.landedOn.last == "pointer")
        live.smoke?.fieldUnderPointer = false
        await toRest(model)
    }
}

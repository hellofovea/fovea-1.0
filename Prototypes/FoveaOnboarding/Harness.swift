import AppKit
import SwiftUI
import Carbon.HIToolbox
import OnboardingCore

/// The window, wherever SwiftUI put it.
@MainActor
func onboardingWindow() -> NSWindow? {
    NSApp.windows.first { $0.title == "Fovea Onboarding" && $0.isVisible }
}

/// A window as PNG data, through the window server (needs no permission for its own windows).
@MainActor
func png(of window: NSWindow) -> Data? {
    let id = CGWindowID(window.windowNumber)
    guard let image = CGWindowListCreateImage(.null, .optionIncludingWindow, id, [.boundsIgnoreFraming, .bestResolution]) else {
        return nil
    }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}

// MARK: - Snapshots

/// `--snapshot <dir> [--only <prefix>]`: every step's moments, staged directly (no timers), each
/// written as onboarding-<name>.png; the Home ending also as onboarding-home-window.png.
@MainActor
enum OnboardingSnapshots {
    struct Shot {
        let name: String
        let stage: (OnboardingModel) -> Void
    }

    static func shots() -> [Shot] {
        var list: [Shot] = []
        func add(_ name: String, _ step: Step, _ setup: @escaping (OnboardingModel) -> Void = { _ in }) {
            list.append(Shot(name: name) { m in
                m.filesCleared = false
                m.previewFile = nil
                m.keysDown = []
                m.ghost = nil
                m.alert = nil
                // A clean Island, so the step's own line is the only one drawn.
                m.island = .rest
                m.captionText = ""
                m.jump(to: step)
                setup(m)
                m.cancelWaits()
            })
        }
        add("01-hello", .hello)
        add("02-hello-more", .hello) { m in
            m.languageMoreOpen = true
            m.flow.languageRequest = "Japanese"
        }
        add("03-make-it-yours", .makeItYours) { m in
            m.flow.personal = Personalization(accent: .purple, aura: .candy, auraHue: 20, auraDrift: 0.7)
        }
        add("04-permissions", .permissions)
        add("05-permissions-dragging", .permissions) { m in
            m.dragTried = true
            let list = m.settingsListFrame
            m.tileDrag = CGPoint(x: list.midX, y: list.maxY - 30)
        }
        add("06-permissions-second-list", .permissions) { m in
            m.inList = [.accessibility]
            m.grant(.accessibility)
            m.settingsPane = .screenRecording
            m.captionText = Copy.permissionCaptions[1]
        }
        add("07-microphone", .microphone)
        add("08-microphone-listening", .microphone) { m in
            m.flow.allow(.microphone); m.micPhase = .listening; m.micLevel = 0.62; m.micVoiced = 0.45
            m.island = .voice(.dictation)
        }
        add("09-agents", .agents) { m in
            m.flow.agentWishes = ["Cursor"]
        }
        add("10-update-start", .weeklyUpdate)
        add("11-update-whole-screen", .weeklyUpdate) { m in
            m.island = .voice(.request)
            m.flow.record(.requestKey)
        }
        add("12-update-click-a-tab", .weeklyUpdate) { m in
            m.island = .voice(.request)
            m.flow.record(.requestKey)
            m.referents = [TakenReferent(kind: .wholeScreen, tab: .analytics)]
            m.capture(m.referents[0].id, name: nil)
            m.flow.record(.wholeScreen)
        }
        add("13-update-prs", .weeklyUpdate) { m in
            m.island = .voice(.request)
            m.flow.record(.requestKey)
            m.referents = [TakenReferent(kind: .wholeScreen, tab: .analytics)]
            m.capture(m.referents[0].id, tab: .analytics, name: nil)
            m.flow.record(.wholeScreen)
            m.selectTab(.github)
            m.screenshotArmed = true
            let r = m.partFrames["prs"] ?? .zero
            m.selection = r.insetBy(dx: -6, dy: -6)
        }
        add("14-update-tickets", .weeklyUpdate) { m in
            m.island = .voice(.request)
            m.flow.record(.requestKey)
            m.selectTab(.support)
            let prs = m.part("prs", in: .github)
            m.referents = [TakenReferent(kind: .wholeScreen, tab: .analytics), TakenReferent(kind: .region(prs), tab: .github)]
            m.capture(m.referents[0].id, tab: .analytics, name: nil)
            m.capture(m.referents[1].id, region: prs, tab: .github, name: nil)
            for beat in [Beat.wholeScreen, .prs] { m.flow.record(beat) }
        }
        add("15-update-review", .weeklyUpdate) { m in
            m.doItForMe()
        }
        add("16-hover-working", .hover) { m in
            m.sessions = [PracticeSession(task: .weeklyUpdate, title: "This week's update", agent: m.agentName,
                                          turns: [.init(ask: Copy.step(.weeklyUpdate).script ?? "", answer: nil)])]
            m.agentActivity = "Looking at part-3.png"
            m.island = .board
            m.flow.record(.hoverNotch)
        }
        add("17-update-done", .hover) { m in
            m.practice.write(PracticeFiles.update, OT.Send.practiceUpdate)
            m.updateWritten = true
            m.sessions = [PracticeSession(task: .weeklyUpdate, title: "This week's update", agent: m.agentName,
                                          turns: [.init(ask: Copy.step(.weeklyUpdate).script ?? "", answer: OT.Send.practiceUpdateReply)])]
            m.editedFiles = [PracticeFiles.update]
            m.showPreview(PracticeFiles.update)
            m.answered = [.weeklyUpdate]
            m.flow.record(.hoverNotch)
            m.flow.record(.answer)
            m.openSessionID = m.sessions.first?.id
            m.island = .session
        }
        add("18-pack-words", .packList) { m in
            m.island = .voice(.request)
            m.flow.record(.requestKey)
            let lines = m.paragraphLines[OT.Practice.snowParagraph] ?? []
            m.marks = lines.isEmpty ? [] : [HighlightMark(rects: lines)]
            m.referents = [TakenReferent(kind: .passage(OT.Practice.snowParagraph), tab: .trail)]
            m.flow.record(.passage)
        }
        add("19-pack-file", .packList) { m in
            m.island = .voice(.request)
            m.flow.record(.requestKey)
            let lines = m.paragraphLines[OT.Practice.snowParagraph] ?? []
            m.marks = lines.isEmpty ? [] : [HighlightMark(rects: lines)]
            if let frame = m.fileFrames[PracticeFiles.list] {
                m.marks.append(HighlightMark(rects: [frame.insetBy(dx: OT.Marks.fileInset.width, dy: OT.Marks.fileInset.height)], file: true))
            }
            m.referents = [TakenReferent(kind: .passage(OT.Practice.snowParagraph), tab: .trail), TakenReferent(kind: .file(.list))]
            for beat in [Beat.passage, .file] { m.flow.record(beat) }
        }
        add("20-pack-done", .packList) { m in
            m.practice.write(PracticeFiles.list, PracticeFiles.listStart + OT.Send.practiceAdded)
            let session = PracticeSession(task: .packList, title: "Packing for the snow", agent: m.agentName,
                                          turns: [.init(ask: Copy.step(.packList).script ?? "", answer: OT.Send.practiceReply)])
            m.sessions.append(session)
            m.openSessionID = session.id
            m.editedFiles.insert(PracticeFiles.list)
            m.showPreview(PracticeFiles.list)
            for beat in [Beat.requestKey, .passage, .file, .finish, .review, .send, .answer] { m.flow.record(beat) }
            m.island = .session
        }
        add("21-follow-up", .followUp) { m in
            m.practice.write(PracticeFiles.list, OT.Send.practiceSorted)
            if let index = m.sessions.lastIndex(where: { $0.task == .packList }) {
                m.sessions[index].turns.append(.init(ask: Copy.step(.followUp).script ?? "", answer: OT.Send.practiceSortedReply))
            }
            m.editedFiles.insert(PracticeFiles.list)
            m.showPreview(PracticeFiles.list)
            m.island = .session
        }
        add("22-dictation-intro", .dictationIntro)
        add("23-dictation-feedback", .dictation) { m in
            m.pointerOver = .feedback
            m.dictationTarget = .feedback
            m.flow.record(.feedbackKey)
            m.island = .voice(.dictation)
        }
        add("24-dictation-reply", .dictation) { m in
            m.feedbackText = OT.Dictation.sampleFeedback
            m.pointerOver = .messages
            m.dictationTarget = .messages
            for beat in [Beat.feedbackKey, .feedbackLanded, .replyKey] { m.flow.record(beat) }
            m.island = .voice(.dictation)
        }
        add("25-dictation-sent", .dictation) { m in
            m.feedbackText = OT.Dictation.sampleFeedback
            m.replyText = OT.Dictation.sampleReply
            m.feedbackSent = true
            for beat in [Beat.feedbackKey, .feedbackLanded, .replyKey, .replyLanded] { m.flow.record(beat) }
        }
        add("26-your-words", .dictionary) { m in
            m.importCandidates = []
            m.importChosen = []
            m.importMessage = nil
        }
        add("27-your-words-connected", .dictionary) { m in
            m.importCandidates = []
            m.importChosen = []
            m.connect(.wisprFlow)
        }
        add("28-you-are-set", .home)
        return list
    }

    static func run(dir: URL, only: String?, model: OnboardingModel) async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // No App Nap while shooting: a window that isn't in front still draws every change.
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical, .idleDisplaySleepDisabled],
                                                             reason: "Snapshots")
        defer { ProcessInfo.processInfo.endActivity(activity) }
        guard let window = onboardingWindow() else { print("no window"); return }
        window.setContentSize(OT.Layout.windowDefault)
        window.orderFrontRegardless()
        await waitForPage(model)
        if PlayDebug.on {
            for w in NSApp.windows {
                print("window \(w.title.isEmpty ? "(untitled)" : w.title) \(w.frame) visible=\(w.isVisible) content=\(type(of: w.contentView as Any)) occlusion=\(w.occlusionState.contains(.visible))")
            }
        }
        for shot in shots() where only.map({ shot.name.hasPrefix($0) || shot.name.contains($0) }) ?? true {
            shot.stage(model)
            if PlayDebug.on { print("staged \(shot.name): step=\(model.step) island=\(model.island) caption=\(model.captionText)") }
            try? await Task.sleep(for: .seconds(0.8))
            if PlayDebug.on { print("  at capture: step=\(model.step) island=\(model.island) waiting=\(model.flow.waitingFor ?? [])") }
            write(window, to: dir.appendingPathComponent("onboarding-\(shot.name).png"))
        }
        if only.map({ $0 == "home" || $0 == "home-window" }) ?? true {
            // The ending: what was made along the way, in the chosen accent and aura, and the words
            // brought in.
            model.jump(to: .home)
            model.flow.personal = Personalization(accent: .purple, aura: .candy, auraHue: 20)
            model.flow.add(PracticeRecord(kind: .dispatch, words: Copy.step(.weeklyUpdate).script ?? "",
                                          referents: [.wholeScreen, .region(source: "GitHub · Safari"), .region(source: "Support · Safari")],
                                          agent: model.agentName, chat: OT.Practice.chat, theme: "This week's update", secondsBeforeEnd: 300))
            model.flow.add(PracticeRecord(kind: .dispatch, words: Copy.step(.packList).script ?? "",
                                          referents: [.passage(text: PracticePage.paragraphs[0], source: "Trail report · Safari"),
                                                      .file(name: PracticeFiles.list, type: "txt", folder: "Desktop")],
                                          agent: model.agentName, chat: OT.Practice.chat, theme: "Packing for the snow", secondsBeforeEnd: 200))
            model.flow.add(PracticeRecord(kind: .dictation, words: OT.Dictation.sampleFeedback, theme: "Feedback on the first run",
                                          secondsBeforeEnd: 90))
            model.importedWords = DictionaryImport.parse(pasted: OT.Dictation.sampleWords)
            model.openHome()
            model.cancelWaits()
            if let home = model.home {
                home.show(over: window.frame)
                try? await Task.sleep(for: .seconds(1.2))
                write(home.window, to: dir.appendingPathComponent("onboarding-home-window.png"))
            }
        }
    }

    /// The blog loads in its own time; shots wait for it (and its parts' places).
    static func waitForPage(_ model: OnboardingModel) async {
        for _ in 0..<60 where !model.pageReady { try? await Task.sleep(for: .seconds(0.1)) }
        try? await Task.sleep(for: .seconds(0.5))
    }

    private static func write(_ window: NSWindow, to url: URL) {
        // A window macOS isn't drawing (the screen locked, or another Space) captures blank: draw
        // its views into a picture instead. Materials come out flat that way.
        let drawn = window.occlusionState.contains(.visible)
        guard let data = drawn ? png(of: window) : offscreenPNG(of: window) else { print("could not capture \(url.lastPathComponent)"); return }
        try? data.write(to: url)
        print("wrote \(url.lastPathComponent)\(drawn ? "" : " (drawn off screen)")")
    }

    private static func offscreenPNG(of window: NSWindow) -> Data? {
        guard let view = window.contentView else { return nil }
        // An occluded window isn't asked to display: ask it, so SwiftUI commits what's changed.
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        view.needsDisplay = true
        window.displayIfNeeded()
        CATransaction.flush()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }
}

// MARK: - Smoke

/// `--smoke`: the whole first run, driven the way a person would, the keys fed to the real
/// monitors as synthetic edges. One line per check, then `SMOKE PASS` or `SMOKE FAIL`.
@MainActor
enum OnboardingSmoke {
    private static var failures = 0

    static func run(model: OnboardingModel) async -> Bool {
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "Smoke")
        defer { ProcessInfo.processInfo.endActivity(activity) }
        guard let window = onboardingWindow() else { print("FAIL no window"); return false }
        await OnboardingSnapshots.waitForPage(model)
        let rig = model.makeRig()

        func check(_ ok: Bool, _ what: String) {
            print(ok ? "ok    \(what)" : "FAIL  \(what)")
            if !ok { failures += 1 }
        }
        func wait(_ seconds: Double = 0.25) async { try? await Task.sleep(for: .seconds(seconds)) }
        func edge(_ flags: NSEvent.ModifierFlags, _ code: Int) -> NSEvent? {
            NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: flags,
                             timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                             context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false,
                             keyCode: UInt16(code))
        }
        func pressFnControl() {
            let control = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.control.rawValue | ModifierPressMonitor.leftControlDeviceFlag)
            for e in [edge(.function, kVK_Function), edge(control.union(.function), kVK_Control),
                      edge(.function, kVK_Control), edge([], kVK_Function)].compactMap({ $0 }) { rig.fn.handle(e) }
        }
        func pressFn() {
            for e in [edge(.function, kVK_Function), edge([], kVK_Function)].compactMap({ $0 }) { rig.fn.handle(e) }
        }
        func tapCommand() {
            let flags = NSEvent.ModifierFlags(rawValue: NSEvent.ModifierFlags.command.rawValue | ModifierHoldMonitor.leftCommandDeviceFlag)
            for e in [edge(flags, kVK_Command), edge([], kVK_Command)].compactMap({ $0 }) { rig.leftCommand.handle(e) }
        }
        func center(_ r: CGRect) -> CGPoint { CGPoint(x: r.midX, y: r.midY) }

        // Hello
        check(model.step == .hello, "starts at hello: no opening animation")
        check(model.island == .caption && model.captionText == "Hi. I live up here.", "the notch says hello")
        check(model.practiceScreen == .empty && model.desktopFiles.isEmpty && model.frontApp == .finder,
              "at the start, only the notch and the bar: no windows, no files")
        check(model.copy.body.isEmpty && model.copy.title == "Point at anything, say what you want.", "hello is one line")
        check(Language.featured == [.english, .chinese], "English and Chinese on the row")
        model.openLanguageMore()
        model.requestLanguage("  Japanese ")
        check(model.languageMoreOpen && model.flow.languageRequest == "Japanese", "More… opens a box, and the language typed is kept")
        model.chooseLanguage(.chinese)
        check(model.flow.language == .chinese && !model.languageMoreOpen, "Chinese chosen; the box closes")
        model.chooseLanguage(.english)
        model.continueTapped()
        check(model.step == .makeItYours, "make it yours comes right after hello")
        check(model.island == .auraPreview, "the notch opens into the aura while choosing")
        model.setAccent(.green)
        model.setAura(.ocean)
        model.setAuraDrift(0.8)
        check(model.auraLook.driftAmount > 1.5, "drift is a dial: 0.8 wanders more than the Workbench's")
        model.setAuraDrift(0)
        check(model.auraLook.drift == false, "at 0 the aura is still")
        model.continueTapped()
        check(model.step == .permissions, "then both lists, in one step")
        check(model.personal.accent == .green && model.personal.aura == .ocean, "the accent and the aura carry on")

        // Turn things on
        await wait(0.4)
        check(model.settingsPane == .accessibility, "System Settings shows the first list")
        check(model.practiceScreen == .empty && model.frontApp == .systemSettings, "System Settings alone, no browser behind it")
        check(model.island == .dragCaption && model.captionText == Copy.permissionCaptions[0], "the notch is one line, the line to drag")
        check(model.instruction == nil && model.copy.title == "Grant Fovea Access", "the bar: Grant Fovea Access, the two lists, nothing more")
        model.tileDropped(at: CGPoint(x: model.settingsListFrame.midX, y: model.settingsListFrame.maxY - 20))
        check(model.flow.allowed.contains(.accessibility) && model.switchedOn.contains(.accessibility),
              "dropped in the list: allowed, already on")
        await wait(0.3)
        check(model.settingsPane == .screenRecording && model.captionText == Copy.permissionCaptions[1],
              "then System Settings turns to the second list")
        model.tileDropped(at: CGPoint(x: model.settingsListFrame.midX, y: model.settingsListFrame.maxY - 20))
        await wait()
        check(model.alert == .reopen, "Screen Recording asks to reopen, once")
        model.alertAnswered(true)
        await wait(0.4)
        check(model.step == .microphone, "both allowed: on to the microphone")
        check(model.copy.script == Copy.micLine, "with a line to say")
        model.continueTapped()
        check(model.alert == .microphone, "Allow the microphone asks through macOS")
        model.alertAnswered(true)
        await wait()
        check(model.step == .microphone && model.micPhase == .listening, "allowed, it listens: it has to hear the line")
        _ = model.spaceKey(true)
        await wait(1.1)
        _ = model.spaceKey(false)
        check(model.flow.heardOnce, "the line heard: \(Copy.micHeard)")
        await wait()
        check(model.step == .agents, "then the coding agents, right after the permissions")
        check(model.keyboardVisible == false, "no keyboard where no keys are taught")
        model.keysDown = ["⌘"]
        check(!model.keyboardVisible, "not even when a key is pressed")
        model.keysDown = []

        // Your agents: connected is connected; no sign-in, no demo.
        check(model.dictationApps.contains(.textReplacements), "(the Mac's own text replacements are always offered)")
        model.toggleWish("Cursor")
        check(model.flow.agentWishes == ["Cursor"], "an agent asked for next")
        model.continueTapped()
        await wait()
        check(model.step == .weeklyUpdate, "connected: straight to the weekly update")
        check(model.practiceScreen == .page && model.frontApp == .safari && model.desktopFiles.isEmpty,
              "the browser comes with the first task that uses it; no files yet")
        check(model.chatShown && model.currentTab == .analytics && model.pageReady, "Maya's ask in the chat, the analytics tab showing")
        check(model.captionText == "Dispatch from anywhere.", "the notch: Dispatch from anywhere")

        // The weekly update: the whole screen, then a part from two tabs.
        check(model.keyboardVisible && model.keyboardTargets == ["fn", "⌃"], "the keyboard is up, fn and ⌃ lit")
        tapCommand()
        check(!model.screenshotArmed, "⌘ before fn ⌃ does nothing")
        pressFnControl()
        check(model.island == .voice(.request), "fn ⌃ (through the monitor) opens the aura bar")
        pressFnControl()
        await wait()
        check(model.island == .caption && model.flow.done.isEmpty, "finishing with nothing taken starts the try over")
        pressFnControl()
        await wait(0.55)
        check(model.keyboardTargets == ["⌘"] && model.keyboardBadges["⌘"] == "×2", "the bar open: ⌘ lit, ×2")
        tapCommand()
        check(model.flow.missedBeat == nil && model.referents.isEmpty, "the first ⌘ of two only arms")
        tapCommand()
        check(model.referents.first?.kind == .wholeScreen, "⌘ twice: the whole screen")
        await wait(0.15)
        check(model.referents.first?.path.map { FileManager.default.fileExists(atPath: $0.path) } == true,
              "a real picture of it, in the practice folder")
        check(model.tabToClick == .github && model.keyboardTargets.isEmpty, "then the GitHub tab, lit; no key until it shows")
        check(model.instruction == "Now click the GitHub tab.", "and the board says so")
        model.selectTab(.github)
        await wait(0.1)
        check(model.keyboardTargets == ["⌘"] && model.keyboardBadges.isEmpty, "GitHub showing: ⌘ once")
        await wait(0.55)
        tapCommand()
        check(model.screenshotArmed && model.keyboardTargets.isEmpty, "armed: nothing to press while you drag")
        let prs = model.partFrames["prs"] ?? .zero
        check(prs != .zero, "the page says where its pull requests are")
        model.dragEnded(from: CGPoint(x: model.pageFrame.minX + 6, y: model.pageFrame.maxY - 30),
                        to: CGPoint(x: model.pageFrame.minX + 60, y: model.pageFrame.maxY - 4))
        check(model.referents.count == 1 && model.hintText != nil, "a drag off the list isn't taken, and the board says so")
        await wait(0.55)
        tapCommand()
        model.dragEnded(from: CGPoint(x: prs.minX - 6, y: prs.minY - 6), to: CGPoint(x: prs.maxX + 6, y: prs.maxY + 6))
        await wait(0.15)
        check(model.referents.count == 2 && model.referents.last?.tab == .github && model.referents.last?.image != nil,
              "the pull requests, taken from the GitHub tab, as a picture")
        check(model.tabToClick == .support, "then the Support tab")
        model.selectTab(.support)
        await wait(0.55)
        tapCommand()
        let tickets = model.partFrames["tickets"] ?? .zero
        model.dragEnded(from: CGPoint(x: tickets.minX - 6, y: tickets.minY - 6), to: CGPoint(x: tickets.maxX + 6, y: tickets.maxY + 6))
        await wait(0.15)
        check(model.referents.count == 3 && model.referents.last?.tab == .support, "the open tickets, from the Support tab")
        check(model.island == .voice(.request), "the bar stayed open across the tabs")
        check(model.keyboardTargets == ["fn", "⌃"], "then fn ⌃ again")
        pressFnControl()
        await wait()
        check(model.island == .review && model.readyToSend && model.request?.referents.count == 3, "fn ⌃ again: the review card, three referents")
        check(model.flow.waitingFor == [.send], "the card shows when it's ready: its arrow lit, not a beat behind")
        check(model.keyboardTargets == ["return"], "return lit to send")
        _ = model.returnKey()
        check(model.step == .hover, "sent: on to watching it work")
        check(model.prompt(for: model.request ?? PracticeRequest(words: "", referents: [], step: .weeklyUpdate)).isEmpty == false, "(a prompt)")
        model.pointerMoved(CGPoint(x: OT.Display.size.width / 2, y: 10))
        await wait(0.1)
        check(model.island == .board || model.island == .session, "the pointer at the notch opens the board")
        await wait(0.4)
        check(model.answered.contains(.weeklyUpdate), "the update comes back")
        check((model.practice.text(PracticeFiles.update) ?? "").contains("1,284"), "weekly-update.md is written, with the numbers")
        check(model.desktopFiles == [.update] && model.previewFile == PracticeFiles.update, "on the desktop, and open")
        check(model.flow.isComplete, "watching it work is met")
        model.continueTapped()

        // The packing list
        check(model.step == .packList && !model.chatShown && model.currentTab == .trail, "then the packing list, from the trail report")
        check(model.previewFile == nil, "the update's file closed")
        check(model.desktopFiles.map(\.name) == [PracticeFiles.update, PracticeFiles.list, PracticeFiles.map],
              "the trip's two files come with the task that uses them, below the update")
        await wait(0.3)
        model.requestKey()
        check(model.keyboardTargets == ["⌥"], "⌥ lit for the words")
        let lines = model.paragraphLines[OT.Practice.snowParagraph] ?? []
        check(!lines.isEmpty, "the page says where its lines are")
        model.optionDown()
        if let first = lines.first, let last = lines.last {
            model.dragEnded(from: CGPoint(x: first.minX + 2, y: first.midY), to: CGPoint(x: last.maxX - 4, y: last.midY))
        }
        model.optionUp(tap: false)
        check(model.referents.first.map { if case .passage = $0.kind { return true } else { return false } } == true
              && model.marks.first?.rects.count == lines.count, "⌥ and a drag mark the line about the snow, line by line")
        check(model.keyboardTargets == ["⌥"], "⌥ lit again, for the file")
        model.optionDown()
        model.optionUp(tap: true)
        if let map = model.fileFrames[PracticeFiles.map] { model.dragEnded(from: center(map), to: center(map)) }
        check(model.referents.count == 1, "the trail map isn't the packing list")
        model.optionDown()
        model.optionUp(tap: true)
        if let list = model.fileFrames[PracticeFiles.list] { model.dragEnded(from: center(list), to: center(list)) }
        check(model.referents.count == 2 && model.keyboardTargets == ["fn", "⌃"], "Packing list.txt taken; fn ⌃ lit")
        model.requestKey()
        await wait()
        check(model.readyToSend && model.flow.waitingFor == [.send], "the second task is ready to send, its arrow lit")
        model.send()
        check(model.flow.done.contains(.send), "the card's arrow sends it, as return does")
        await wait(0.4)
        check(model.answered.contains(.packList) && (model.practice.text(PracticeFiles.list) ?? "").contains("Microspikes"),
              "the packing list really changed")
        check(model.previewFile == PracticeFiles.list, "and it opens, as Quick Look would")
        check(model.flow.isComplete, "the list is met")
        model.continueTapped()
        check(model.step == .followUp, "then a follow-up")
        pressFn()
        check(model.island == .voice(.followUp), "fn in the session asks more")
        pressFn()
        await wait(0.4)
        check(model.flow.isComplete && (model.practice.text(PracticeFiles.list) ?? "").contains("Clothes"), "the follow-up changed the list again")
        model.continueTapped()

        // Dictation: two windows
        check(model.step == .dictationIntro && model.previewFile == nil, "dictation comes next; the list's preview closed")
        check(model.practiceScreen == .empty && model.desktopFiles.isEmpty, "the browser and the files go once the tasks are done")
        check(model.keyboardVisible && model.keyboardTargets == ["fn"], "the keyboard shows fn")
        model.continueTapped()
        check(model.step == .dictation && model.practiceScreen == .dictation, "Try it: the two windows")
        model.pointerMoved(CGPoint(x: 5, y: 600))
        pressFn()
        check(model.island != .voice(.dictation), "fn with the pointer on no window asks for one")
        model.pointerMoved(center(OT.Layout.messagesFrame))
        pressFn()
        check(model.island != .voice(.dictation), "the feedback window first")
        model.pointerMoved(center(OT.Layout.feedbackFrame))
        pressFn()
        check(model.island == .voice(.dictation) && model.dictationTarget == .feedback, "fn over the feedback window: it listens")
        pressFn()
        await wait(0.2)
        check(!model.feedbackText.isEmpty && model.replyText.isEmpty, "the words land in the feedback window")
        check(!model.feedbackSent, "and nothing is sent")
        model.pointerMoved(center(OT.Layout.messagesFrame))
        pressFn()
        pressFn()
        await wait(0.2)
        check(!model.replyText.isEmpty && model.flow.isComplete, "then in Messages: the window under the pointer")
        model.sendFeedback()
        check(model.feedbackSent, "Send sends the feedback")
        model.continueTapped()

        // Bring your words
        check(model.step == .dictionary, "then bring your words")
        model.connect(.wisprFlow)
        let offered = model.importCandidates.count
        check(offered >= 3 && model.importChosen.count == offered && model.importCandidates.first == ImportedWord("Fovea", heardAs: "favea"),
              "Connect brings an app's words in (a stand-in here, never yours), each ticked")
        model.toggleImport("Northwind")
        model.continueTapped()
        check(model.step == .home && model.flow.imported == offered - 1, "Add brings the ticked ones")
        check(model.filesCleared, "the practice files are cleared")
        check(model.flow.records.count == 5, "five practice captures for Home")
        let captures = CapturesHomeHandle.captures(model.flow.records)
        check(captures.count == 5 && captures.first?.kind == .dictation, "they map to Home's captures, newest first")
        check(Copy.step(.home).body.isEmpty, "the end is two short parts")
        model.askEyeTracking()
        check(model.eyeTrackingAsked, "eye tracking's beta, asked for")
        model.continueTapped()
        check(model.finished && model.homeOpened, "Done goes straight to Home: no closing animation")

        // Backups: every step has a way past (Oct 8).
        model.jump(to: .weeklyUpdate)
        model.skipShown = true
        model.skipTapped()
        await wait(0.15)
        check(model.readyToSend && model.referents.count == 3 && model.request?.referents.allSatisfy({ $0.path != nil || $0.image != nil }) == true,
              "Do it for me puts the update together, with its pictures")
        _ = model.returnKey()
        model.skipShown = true
        model.skipTapped()
        await wait(0.4)
        check(model.step == .hover && model.flow.isComplete, "Open it for me finishes watching it work")
        model.jump(to: .packList)
        model.skipShown = true
        model.skipTapped()
        check(model.readyToSend && model.referents.count == 2, "Put it together for me carries the task on")
        model.jump(to: .dictationIntro)
        model.skipTapped()
        check(model.step == .dictionary && model.flow.dictationSkipped, "Skip dictation skips all of it")
        model.skipTapped()
        check(model.step == .home, "Not now")

        // Bookmarks: any stage, as things are; or a fresh run from it.
        model.goTo(.agents)
        check(model.step == .agents, "the Your agents bookmark goes to its first step")
        model.goTo(.pointAndSay)
        check(model.step == .weeklyUpdate, "and Point and send to the weekly update")
        model.startFrom(.dictation)
        check(model.step == .dictationIntro && model.flow.records.isEmpty && model.flow.allowed.contains(.screenRecording)
              && model.flow.agentsConnected, "Start here: a fresh run from Dictation, the stages before counted as done")
        model.stepBy(1)
        check(model.step == .dictation, "Next goes a step on")
        model.stepBy(-1)
        check(model.step == .dictationIntro, "Back goes a step back")

        print(failures == 0 ? "SMOKE PASS" : "SMOKE FAIL (\(failures))")
        return failures == 0
    }
}

import SwiftUI
import AppKit
import OnboardingCore
import FoveaKit
import FoveaIsland
import CapturesCore

// The first run on the real Mac: the real island at the real notch does every key, every take and
// every send (the one island, Native, the Badges board, as the person makes it theirs); the first
// run watches it, says when something's missing, offers its own windows to point at and paste
// into, and hands the two tasks to the agent on this Mac. Before, the prototype had its own island
// and its own keys on a mock desktop (Prototypes/FoveaOnboarding).

/// What the first run asks of the rest of Fovea (OnboardingCoordinator does it).
@MainActor
protocol OnboardingHost: AnyObject {
    /// The notch shows the Dispatch bar with its glow, or the board, while choices are made.
    func previewAura(_ on: Bool)
    func previewPanel()
    /// The microphone test's bar, and its level.
    func listening(_ on: Bool)
    func listeningLevel(_ level: Double)
    func islandRest()
    func openBoard()
    func openIslandSession(_ id: String)
    /// "Do it for me": the request put together at the notch, on Choose chat, waiting for Return.
    func stageRequest(words: String, items: [StagedReferent])
    /// macOS's own prompts: the microphone, then speech recognition.
    func askMicrophoneAndSpeech(_ done: @escaping (Bool) -> Void)
    func sessionActivity(_ id: String, _ line: String)
    func sessionAnswered(_ id: String, _ answer: String, files: [String])
    /// The person's choices, as the island and the window read them.
    var prefs: FoveaPrefs { get set }
    func openPermission(_ permission: OnboardingCore.Permission)
    /// Asks macOS for a permission (its own prompt, and Fovea added to the list), then opens it.
    func requestPermission(_ permission: OnboardingCore.Permission)
    func keepResumePoint()
    func reopen()
    func clearScreen()
    var screenCleared: Bool { get }
    func finished()
}

extension OnboardingModel: IslandDirector {
    // MARK: What the island did

    func islandDidEmit(_ event: IslandEvent) {
        switch event {
        case .voiceOpened(let dispatch):
            if dispatch {
                island = .voice(.request)
                if isPracticeTry, !flow.done.contains(.send) {
                    flow.retry()
                    referents = []
                    request = nil
                    beat(.requestKey)
                }
            } else {
                island = .voice(.dictation)
                if step == .dictation, let target = pointerOver {
                    dictationTarget = target
                    let owed = flow.waitingFor
                    if owed?.contains(.feedbackKey) == true { beat(.feedbackKey) }
                    if owed?.contains(.replyKey) == true { beat(.replyKey) }
                }
            }
        case .followUpStarted:
            island = .voice(.followUp)
            if step == .followUp { beat(.followKey) }
        case .referentTaken(let kind, let rect):
            taken(kind, rect: rect)
        case .transcribing(let dispatch):
            island = .transcribing(dispatch ? .request : .dictation)
        case .chooseChatShown:
            island = .review
            if isPracticeTry {
                request = PracticeRequest(words: copy.script ?? "", referents: referents, step: step)
                beat(.review)
            }
        case .sent:
            island = .board
        case .boardOpened(let byHover):
            island = .board
            if byHover, step == .hover { beat(.hoverNotch) }
        case .sessionAnswered, .logged, .followUpAnswered:
            break
        case .dictationLanded:
            break
        case .rested:
            if case .voice = island, step == .dictation { dictationTarget = nil }
            island = .rest
        }
    }

    /// fn and fn ⌃ work only where they're taught (Oct 9: a key pressed elsewhere brings nothing).
    func allowsVoice(dispatch: Bool) -> Bool {
        if dispatch {
            if isPracticeTry { return !flow.done.contains(.send) }
            // The follow-up: asking more in the open packing session.
            if step == .followUp { return true }
            if step.stage == .home || finished { return true }
            // Pressed where it isn't taught: said on the bar, never swallowed without a word.
            if notchTaught, !step.isReading { hint("Not yet. Follow this step first.") }
            return false
        }
        if step == .dictation {
            guard pointerOver != nil else {
                hint("Put your pointer on a window first.")
                return false
            }
            let owed = flow.waitingFor
            if owed?.contains(.feedbackKey) == true, pointerOver != .feedback {
                hint("Start with the feedback window, on the left.")
                return false
            }
            if owed?.contains(.replyKey) == true, pointerOver != .messages {
                hint("Now Messages, on the right.")
                return false
            }
            return true
        }
        if finished { return true }
        if step == .followUp { hint("Open the packing list from the notch first, then press \(keys.spoken(.dictation)).") }
        else if notchTaught, !step.isReading { hint("Not yet. Follow this step first.") }
        return false
    }

    /// The board opens from the notch only once the notch is being taught, and not on a page to
    /// read (Oct 9: nothing at the notch before it's needed).
    func allowsBoard() -> Bool {
        finished || (notchTaught && !step.isReading)
    }

    /// fn ⌃ again: on, once the task's things are taken; else the board says what's missing and
    /// the bar keeps listening.
    func allowsFinish(continuing: Bool) -> Bool {
        guard isPracticeTry, !continuing else { return true }
        guard flow.waitingFor?.contains(.finish) == true else {
            hint(step == .packList
                 ? "Not quite. Take the line and the packing list, then press \(keys.spoken(.request))."
                 : "Not quite. Take the screen and the two parts, then press \(keys.spoken(.request)).")
            return false
        }
        beat(.finish)
        return true
    }

    /// A drag with ⌘. In the weekly update, a part taken in the GitHub tab is the merged pull
    /// requests, in the Support tab the open tickets; a drag that misses them there is said, and
    /// not taken.
    func acceptRegion(_ rect: CGRect) -> Bool {
        guard step == .weeklyUpdate, let beat = [Beat.prs, .tickets].first(where: { $0.tab == currentTab }),
              pageFrame.contains(rect.center) else { return true }
        let part = partFrames[beat == .prs ? "prs" : "tickets"] ?? .zero
        let overlap = part.intersection(rect)
        guard !overlap.isNull, overlap.width * overlap.height > rect.width * rect.height * OT.Practice.partCover else {
            hint(beat == .prs ? "That missed the pull requests. Press \(keys.spoken(.screenshot)) and drag over the list."
                              : "That missed the tickets. Press \(keys.spoken(.screenshot)) and drag over them.")
            return false
        }
        return true
    }

    /// ⌥ and a click on a file. The packing task wants the packing list: another file is said.
    func acceptFile(_ url: URL) -> Bool {
        guard step == .packList else { return true }
        if url.lastPathComponent != PracticeFiles.list {
            hint("For this one, take \(PracticeFiles.list).")
            return false
        }
        return true
    }

    private func taken(_ kind: IslandEvent.TakenKind, rect: CGRect) {
        switch kind {
        case .wholeScreen:
            referents.append(TakenReferent(kind: .wholeScreen, tab: currentTab))
            sound.cue(.capture)
            beat(.wholeScreen)
        case .region:
            referents.append(TakenReferent(kind: .region(rect), tab: pageFrame.contains(rect.center) ? currentTab : nil))
            sound.cue(.capture)
            if step == .weeklyUpdate, let beat = [Beat.prs, .tickets].first(where: { $0.tab == currentTab }),
               pageFrame.contains(rect.center) { self.beat(beat) }
        case .passage:
            let paragraph = paragraphFrames.first { $0.value.insetBy(dx: -4, dy: -4).intersects(rect) }?.key ?? OT.Practice.snowParagraph
            referents.append(TakenReferent(kind: .passage(paragraph), tab: currentTab))
            sound.cue(.capture)
            beat(.passage)
        case .file:
            referents.append(TakenReferent(kind: .file(.list), path: practice.url(PracticeFiles.list)))
            sound.cue(.capture)
            beat(.file)
        }
    }

    // MARK: Fovea's own windows, to point at and paste into

    func pasteTarget() -> Bool {
        step == .dictation && (dictationTarget ?? pointerOver) != nil
    }

    func paste(_ text: String) -> Bool {
        guard step == .dictation, let target = dictationTarget ?? pointerOver else { return false }
        land(text, in: target)
        return true
    }

    /// Without Screen Recording, a picture of Fovea's own practice windows, drawn here.
    func image(of rect: CGRect) -> NSImage? {
        ScreenCapture.region(rect, model: self, name: nil)?.image
    }

    func source(of rect: CGRect) -> String? {
        if pageFrame.intersects(rect) { return "\(currentTab.title) · Fovea" }
        return nil
    }

    /// The trail report's real lines (the page reports where each line of each paragraph is).
    func textRun(from a: CGPoint, to b: CGPoint) -> (rects: [CGRect], text: String)? {
        guard practiceScreen == .page, pageFrame.contains(a) || pageFrame.contains(b) else { return nil }
        let runs = markRuns(from: a, to: b)
        guard let first = runs.paragraphs.first, !runs.rects.isEmpty else { return nil }
        return (runs.rects, paragraphTexts[first] ?? "")
    }

    func paragraph(at p: CGPoint) -> (rects: [CGRect], text: String)? {
        guard practiceScreen == .page,
              let hit = paragraphFrames.first(where: { $0.value.insetBy(dx: -4, dy: -3).contains(p) }) else { return nil }
        let lines = paragraphLines[hit.key] ?? [hit.value]
        return (lines.map { $0.insetBy(dx: 0, dy: -1) }, paragraphTexts[hit.key] ?? "")
    }

    func file(at p: CGPoint) -> (url: URL, rect: CGRect)? {
        guard let file = desktopFiles.first(where: { fileFrames[$0.name]?.insetBy(dx: -6, dy: -6).contains(p) == true }),
              let frame = fileFrames[file.name] else { return nil }
        return (practice.url(file.name), frame)
    }

    /// What's made in the first run goes to Home tagged "First run", from Fovea's own windows.
    func decorate(_ capture: Capture) -> Capture {
        var c = capture
        c.tags = ["First run"]
        if c.kind == .dispatch {
            c.app = AppRef("Fovea · Practice", "app.fovea")
            c.site = currentTab.address
        } else {
            c.app = dictationTarget == .messages || pointerOver == .messages
                ? AppRef("Messages · Practice", "com.apple.MobileSMS") : AppRef("Fovea · Feedback", "app.fovea")
        }
        return c
    }

    // MARK: The agent on this Mac

    /// Return on Choose chat: the request goes to Claude Code (or the practice agent), with the
    /// pictures the island took, saved where the agent can open them.
    func runSession(_ id: String, words: String, referents taken: [IslandReferent], followUp: Bool) -> Bool {
        if followUp {
            guard let index = sessions.lastIndex(where: { $0.islandID == id }) else { return false }
            sessions[index].turns.append(.init(ask: words, answer: nil))
            openSessionID = sessions[index].id
            flow.add(PracticeRecord(kind: .dispatch, words: words, agent: agentName, chat: OT.Practice.chat,
                                    theme: "Sorting the packing list", secondsBeforeEnd: 150))
            dispatch(PracticeRequest(words: words, referents: [], step: .followUp), session: sessions[index].id,
                     turn: sessions[index].turns.count - 1)
            return true
        }
        guard isPracticeTry else { return false }
        // The pictures, as files the agent can open.
        var withPaths = referents
        for (i, r) in taken.enumerated() where i < withPaths.count {
            if let png = r.png {
                let url = practice.captureURL("part-\(i + 1).png")
                try? png.write(to: url)
                if case .file = withPaths[i].kind { continue }
                withPaths[i].path = url
            }
        }
        let practiceRequest = PracticeRequest(words: words.isEmpty ? (copy.script ?? "") : words, referents: withPaths, step: step)
        request = practiceRequest
        sound.cue(.step)
        var session = PracticeSession(task: step, title: theme(of: practiceRequest), agent: agentName,
                                      turns: [.init(ask: practiceRequest.words, answer: nil)])
        session.islandID = id
        sessions.append(session)
        openSessionID = session.id
        flow.add(PracticeRecord(kind: .dispatch, words: practiceRequest.words, referents: practiceRequest.referents.map(record),
                                agent: agentName, chat: OT.Practice.chat, theme: theme(of: practiceRequest),
                                secondsBeforeEnd: step == .weeklyUpdate ? 300 : 200))
        dispatch(practiceRequest, session: session.id, turn: 0)
        beat(.send)
        return true
    }

    /// The chat Choose chat offers in the first run: the practice chat with the agent.
    var practiceChat: IslandChat {
        IslandChat(agent: sendsToRealAgent ? "claude-code" : (connectedAgents.first?.islandID ?? "claude-code"),
                   chat: OT.Practice.chat, project: "First run")
    }
}

extension Agent {
    /// The agent's id on the island (its mark in Resources/Agents).
    var islandID: String {
        switch self {
        case .claudeCode: "claude-code"
        case .codex: "codex"
        case .cursor: "cursor"
        }
    }
}

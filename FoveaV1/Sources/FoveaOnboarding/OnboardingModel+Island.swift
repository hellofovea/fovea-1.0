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

extension OnboardingModel {
    /// Oct 21, Ryan: Reduce Motion as Settings › Motion says: as the Mac has it, always, or never.
    func readMotion() {
        let reduce: Bool
        switch host?.prefs.motion ?? .system {
        case .system: reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        case .reduce: reduce = true
        case .full: reduce = false
        }
        if reduce != reduceMotion { reduceMotion = reduce }
    }
}

/// What the first run asks of the rest of Fovea (OnboardingCoordinator does it).
@MainActor
protocol OnboardingHost: AnyObject {
    /// The notch shows the Dispatch bar with its glow, or the board, while choices are made. After
    /// the board's look has been seen, the glow again if a light was picked (`thenLight`), else
    /// nothing.
    func previewAura(_ on: Bool)
    func previewPanel(thenLight: Bool)
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
    /// "Exit tour": the place kept, everything put back, Home.
    func exitTour()
    /// The first run's sessions off the board (a task started over with Back, Oct 17).
    func clearIslandSessions()
    /// The primary language changed on the hello page (Oct 18, Ryan): the island's practice chat
    /// is named again.
    func languageChanged()
    // Oct 23, Ryan: what the first run now teaches with a session.
    /// The chats Choose chat offers now.
    func offerChats(_ chats: [IslandChat])
    func sessionTitle(_ id: String) -> String?
    /// The agent asks to edit a file (Needs you, Deny and Allow); allowed for the person.
    func askToEdit(_ id: String, file: String, question: String)
    func allowEdit(_ id: String)
    /// A session pulled out of the notch, tucked at a side, brought back ("Do it for me").
    func pullOut(_ id: String)
    func tuck(_ id: String)
    func bringBack(_ id: String)
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
                // Oct 17, Ryan: what's taken from now lands after these words.
                dictationTaken = []
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
            // Oct 23, Ryan: the undo let go by in Messages: that window's try again, from fn.
            if step == .dictation, flow.waitingFor?.contains(.replyRestored) == true {
                flow.forget([.replyKey, .replyCancelled])
                hint(L("Too late to bring it back. Point at Messages and press \(keys.spoken(.dictation)) again."))
            }
            island = .rest
        // Oct 23, Ryan (the first run teaches the rest): what the island did, as the steps wait for it.
        case .sessionOpened:
            island = .session
            if step == .hover { caughtUp(.openedSession) }
        case .chatPulledOut:
            if step == .hover { caughtUp(.pulledOut) }
        case .chatTucked:
            if step == .hover { caughtUp(.tucked) }
        case .chatBroughtBack:
            if step == .hover { caughtUp(.broughtBack) }
        case .sessionExpanded:
            if step == .followUp { softBeat(.expanded) }
        case .approvalAnswered(let allowed):
            approvalAnswered(allowed)
        case .cancelled:
            if step == .dictation { softBeat(.replyCancelled) }
        case .restored:
            if step == .dictation { softBeat(.replyRestored) }
        case .stackOpened:
            if step == .takeFew { softBeat(.stackOpened) }
        case .referentInspected:
            if step == .takeFew { softBeat(.referentInspected) }
        case .referentRemoved(let index):
            if referents.indices.contains(index) { referents.remove(at: index) }
            if step == .takeFew { softBeat(.referentRemoved) }
        case .queued:
            if step == .whileWorking { softBeat(.queued) }
        case .stopped(let id):
            stopped(id)
        case .answeredAgain:
            if step == .whileWorking { softBeat(.answeredAgain) }
        case .heldWords:
            island = .held
            if step == .nowhereToType { softBeat(.heldShown) }
        case .heldCopied:
            if step == .nowhereToType { softBeat(.heldTaken) }
        }
    }

    /// Oct 23, Ryan: a beat the first run teaches with a session, counted when it's the one waited
    /// for (or one the step takes in any order), and never a missed try: early, it's let pass.
    func softBeat(_ beat: Beat) {
        guard flow.waitingFor?.contains(beat) == true || (step.anyOrder.contains(beat) && flow.remaining.contains { $0.contains(beat) })
        else { return }
        self.beat(beat)
    }

    /// Watching the update: a beat that can only come after the ones before it (pulled out, it was
    /// open; tucked, it was out) counts them too, so a quick answer that opened by itself, pulled
    /// straight out, is no missed try.
    func caughtUp(_ beat: Beat) {
        let order: [Beat] = [.hoverNotch, .openedSession, .pulledOut, .tucked, .broughtBack]
        guard let i = order.firstIndex(of: beat) else { return }
        for earlier in order[..<i] where !flow.done.contains(earlier) { softBeat(earlier) }
        softBeat(beat)
    }

    /// The packing list's edit answered at the notch: allowed, the agent goes on; denied, it asks
    /// again, and the bar says why.
    private func approvalAnswered(_ allowed: Bool) {
        guard let waiting = awaitingApproval else { return }
        guard allowed else {
            hint(L("In practice, Allow it so the list gets made."))
            return
        }
        awaitingApproval = nil
        softBeat(.approved)
        dispatch(waiting.request, session: waiting.session, turn: waiting.turn)
    }

    /// Stop on one of the first run's sessions: its agent stops too.
    private func stopped(_ islandID: String) {
        guard let session = sessions.first(where: { $0.islandID == islandID }) else { return }
        runner.cancel()
        cancelWaits(prefixed: Self.agentWait + session.id.uuidString)
        if step == .whileWorking { softBeat(.stopped) }
    }

    /// What's missing before fn ⌃ again, said on the bar.
    var notQuite: String {
        let request = keys.spoken(.request)
        switch step {
        case .packList: return L("Not quite. Take the line and the packing list, then press \(request).")
        case .takeFew: return L("Not yet. Take two parts, open them, look at one and take one out, then press \(request).")
        case .whileWorking: return L("Not yet. Press \(request) to start.")
        default: return L("Not quite. Take the numbers and the pull requests, then press \(request).")
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
            if notchTaught, !step.isReading { hint(L("Not yet. Follow this step first.")) }
            return false
        }
        // Oct 23, Ryan: Nowhere to type: anywhere, the desktop above all.
        if step == .nowhereToType { return true }
        if step == .dictation {
            guard pointerOver != nil else {
                hint(L("Put your pointer on a window first."))
                return false
            }
            let owed = flow.waitingFor
            if owed?.contains(.feedbackKey) == true, pointerOver != .feedback {
                hint(L("Start with the feedback window, on the left."))
                return false
            }
            if owed?.contains(.replyKey) == true, pointerOver != .messages {
                hint(L("Now Messages, on the right."))
                return false
            }
            return true
        }
        if finished { return true }
        if step == .followUp { hint(L("Open the packing list from the notch first, then press \(keys.spoken(.dictation)).")) }
        else if notchTaught, !step.isReading { hint(L("Not yet. Follow this step first.")) }
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
            hint(notQuite)
            return false
        }
        beat(.finish)
        return true
    }

    /// A drag with ⌘ (Oct 19, Ryan). In the weekly update, a part taken in the Analytics tab is this week's numbers
    /// (Oct 17, Ryan, round 2: in place of the whole screen), in the GitHub tab the merged pull
    /// requests (Oct 18, Ryan: the two; the tickets went); a drag that misses them there is said,
    /// and not taken.
    func acceptRegion(_ rect: CGRect) -> Bool {
        guard step == .weeklyUpdate, let beat = Self.weeklyParts.first(where: { $0.tab == currentTab }),
              pageFrame.contains(rect.center), let name = beat.part else { return true }
        let part = partFrames[name] ?? .zero
        let overlap = part.intersection(rect)
        guard !overlap.isNull, overlap.width * overlap.height > rect.width * rect.height * OT.Practice.partCover else {
            let shot = keys.spoken(.screenshot)
            switch beat {
            case .numbers: hint(L("That missed this week's numbers. Press \(shot) and drag over them."))
            default: hint(L("That missed the pull requests. Press \(shot) and drag over the list."))
            }
            return false
        }
        return true
    }

    /// The weekly update's parts, a tab each (Oct 18, Ryan: two).
    static let weeklyParts: [Beat] = [.numbers, .prs]

    /// A file dragged onto the notch (Oct 17, Ryan, round 2; it was ⌥ and a click). The packing
    /// task wants the packing list: another file is said.
    func acceptFile(_ url: URL) -> Bool {
        guard step == .packList else { return true }
        if url.lastPathComponent != PracticeFiles.list {
            hint(L("For this one, take \(PracticeFiles.list)."))
            return false
        }
        return true
    }

    private func taken(_ kind: IslandEvent.TakenKind, rect: CGRect) {
        // Oct 17, Ryan: taken while dictating, it lands after the words (OnboardingModel+Real).
        if step == .dictation {
            takenWhileDictating(kind, rect: rect)
            return
        }
        switch kind {
        case .wholeScreen:
            // Nothing teaches it any more (Oct 17, Ryan, round 2: ⌥ twice is Claude's); kept if the
            // island ever says so, as a picture taken.
            referents.append(TakenReferent(kind: .wholeScreen, tab: currentTab))
            sound.cue(.capture)
        case .region:
            referents.append(TakenReferent(kind: .region(rect), tab: pageFrame.contains(rect.center) ? currentTab : nil))
            sound.cue(.capture)
            if step == .weeklyUpdate, let beat = Self.weeklyParts.first(where: { $0.tab == currentTab }),
               pageFrame.contains(rect.center) { self.beat(beat) }
            // Oct 23, Ryan: More to try's two parts, ⌘ held.
            if step == .takeFew, referents.filter({ if case .region = $0.kind { true } else { false } }).count >= 2 {
                softBeat(.twoTaken)
            }
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

    // Oct 18, Ryan: the words land in the window under the pointer when they land, not the one
    // under it when the listening started (that one only if the pointer's off both).
    func pasteTarget() -> Bool {
        // Oct 23, Ryan: Nowhere to type: nothing takes the words until they're held at the notch
        // and the feedback window is clicked into, for Paste.
        if step == .nowhereToType { return island == .held && typingInto != nil }
        return step == .dictation && dictationLanding != nil
    }

    func paste(_ text: String) -> Bool {
        if step == .nowhereToType, island == .held, let target = typingInto {
            land(text, in: target)
            return true
        }
        guard step == .dictation, let target = dictationLanding else { return false }
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
        c.tags = [L("First run")]
        if c.kind == .dispatch {
            c.app = AppRef(L("Fovea · Practice"), "app.fovea")
            c.site = currentTab.address
        } else {
            c.app = dictationLanding == .messages
                ? AppRef(L("Messages · Practice"), "com.apple.MobileSMS") : AppRef(L("Fovea · Feedback"), "app.fovea")
        }
        return c
    }

    // MARK: The agent on this Mac

    /// Return on Choose chat: the request goes to Claude Code (or the practice agent), with the
    /// pictures the island took, saved where the agent can open them.
    func runSession(_ id: String, words: String, referents taken: [IslandReferent], followUp: Bool) -> Bool {
        // Oct 23, Ryan: the packing list sent to the weekly update's chat goes into that session,
        // as the next request there.
        if followUp, step == .packList, !flow.done.contains(.send), let index = sessions.lastIndex(where: { $0.islandID == id }) {
            let practiceRequest = handed(words, taken)
            sessions[index].turns.append(.init(ask: practiceRequest.words, answer: nil, task: .packList))
            sent(practiceRequest, in: index, turn: sessions[index].turns.count - 1)
            return true
        }
        if followUp {
            guard let index = sessions.lastIndex(where: { $0.islandID == id }) else { return false }
            // Oct 23, Ryan: in While it works, the message that waited its turn.
            let task: Step = step == .whileWorking ? .whileWorking : .followUp
            sessions[index].turns.append(.init(ask: words, answer: nil, task: task))
            openSessionID = sessions[index].id
            if task == .followUp {
                flow.add(PracticeRecord(kind: .dispatch, words: words, agent: agentName, chat: OT.Practice.chat,
                                        theme: L("Sorting the packing list"), secondsBeforeEnd: 150))
            }
            dispatch(PracticeRequest(words: words, referents: [], step: task), session: sessions[index].id,
                     turn: sessions[index].turns.count - 1)
            return true
        }
        guard isPracticeTry else { return false }
        let practiceRequest = handed(words, taken)
        var session = PracticeSession(task: step, title: theme(of: practiceRequest), agent: agentName,
                                      turns: [.init(ask: practiceRequest.words, answer: nil, task: step)])
        session.islandID = id
        sessions.append(session)
        sent(practiceRequest, in: sessions.count - 1, turn: 0)
        return true
    }

    /// The request as the agent is handed it: the words, and what was taken, the pictures as files
    /// it can open.
    private func handed(_ words: String, _ taken: [IslandReferent]) -> PracticeRequest {
        var withPaths = referents
        for (i, r) in taken.enumerated() where i < withPaths.count {
            if let png = r.png {
                let url = practice.captureURL("part-\(i + 1).png")
                try? png.write(to: url)
                if case .file = withPaths[i].kind { continue }
                withPaths[i].path = url
            }
        }
        return PracticeRequest(words: words.isEmpty ? (copy.script ?? "") : words, referents: withPaths, step: step)
    }

    /// Sent: kept for Home, and to the agent. Oct 23, Ryan: the packing list's agent asks before it
    /// edits the list.
    private func sent(_ practiceRequest: PracticeRequest, in index: Int, turn: Int) {
        request = practiceRequest
        sound.cue(.step)
        let session = sessions[index]
        openSessionID = session.id
        flow.add(PracticeRecord(kind: .dispatch, words: practiceRequest.words, referents: practiceRequest.referents.map(record),
                                agent: agentName, chat: OT.Practice.chat, theme: theme(of: practiceRequest),
                                secondsBeforeEnd: step == .weeklyUpdate ? 300 : 200))
        if step == .packList {
            packSessionID = session.id
            beat(.send)
            askBeforeEditing(session: session.id, request: practiceRequest, turn: turn)
            return
        }
        dispatch(practiceRequest, session: session.id, turn: turn)
        beat(.send)
    }

    /// Oct 23, Ryan: the agent reads the request, then asks to edit the list: the session needs you
    /// at the notch (and the menu bar's icon says so) until it's allowed there.
    private func askBeforeEditing(session id: UUID, request: PracticeRequest, turn: Int) {
        awaitingApproval = (id, request, turn)
        guard let islandID = sessions.first(where: { $0.id == id })?.islandID else { return }
        let reading = L("Reading your words")
        agentActivity = reading
        host?.sessionActivity(islandID, reading)
        after(OT.Send.practiceBeat, Self.agentWait + id.uuidString + ":ask") { [weak self] in
            guard let self, self.awaitingApproval?.session == id else { return }
            self.host?.askToEdit(islandID, file: PracticeFiles.list, question: L("Edit \(PracticeFiles.list)?"))
        }
    }

    /// Oct 23, Ryan: Answer again on one of the first run's sessions: its last request answered
    /// again (in While it works, the practice agent takes its time, to be stopped).
    func rerunSession(_ id: String) -> Bool {
        guard let index = sessions.lastIndex(where: { $0.islandID == id }), let last = sessions[index].turns.last else { return false }
        let task = last.task ?? sessions[index].task
        sessions[index].turns.append(.init(ask: last.ask, answer: nil, task: task, rerun: true))
        dispatch(PracticeRequest(words: last.ask, referents: [], step: task), session: sessions[index].id,
                 turn: sessions[index].turns.count - 1)
        return true
    }

    /// The chats Choose chat offers in a step. Oct 23, Ryan: for the packing list, a new chat
    /// (picked) and the weekly update's, when it was sent.
    func chatsOffered(for step: Step) -> [IslandChat] {
        let chat = practiceChat
        guard step == .packList, let weekly = sessions.last(where: { $0.task == .weeklyUpdate })?.islandID,
              let title = host?.sessionTitle(weekly) else { return [chat] }
        return [IslandChat(agent: chat.agent, chat: "", project: chat.project), IslandChat(agent: chat.agent, chat: title, project: chat.project)]
    }

    /// The chat Choose chat offers in the first run: the practice chat with the agent.
    var practiceChat: IslandChat {
        IslandChat(agent: sendsToRealAgent ? "claude-code" : (connectedAgents.first?.islandID ?? "claude-code"),
                   chat: OT.Practice.chat, project: L("First run"))
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

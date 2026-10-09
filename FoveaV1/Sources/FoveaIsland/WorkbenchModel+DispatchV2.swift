import SwiftUI
import AppKit
import FoveaCore

// Dispatch Version 2's flow (its sample requests are in V2Requests.swift):
//
// fn⌃ opens the voice bar (the aura, as Dispatch's and Quick actions' bars, and the referent
// stack). Left Option held turns on capture: a drag takes a region, a click a passage's text or a
// file; pressed twice, it takes the whole screen. fn⌃ again ends it: Transcribing (the aura as a
// progress bar), then Choose chat, as Dispatch has it (the request, what was taken, the chat in a pill, the send button), with the
// suggested chats beside it; the send button's ring empties and it goes, or ⌃ opens every chat.
// Sent, the control board shows a moment and the island rests. The board holds what is running
// and what is done but not yet opened (Ready for review, on top). A quick answer opens by itself;
// any session opens to its expanded chat on a click; a chat's grab bar pulls it out of the notch
// into a window that can go anywhere, tuck into a side of the screen and come back out; its box
// asks more there, and its ✕ closes it (stopping the session if it is still at work).
// docs/island/DISPATCH_V2.md has the reasons.

/// A chat pulled out of the notch: a small window, or tucked into a side of the screen.
struct V2Detached: Identifiable, Equatable {
    enum Side { case left, right }
    /// The session it shows.
    let id: String
    /// Its top-left, in the display's points, when it is a window.
    var origin: CGPoint
    /// Tucked into a side, at this height.
    var docked: Side?
    var dockY: CGFloat
    /// How big it is, against its usual size (its corner, or a pinch, sets it).
    var scale: CGFloat = 1

    var size: CGSize {
        let base = V2DetachedLayout.size
        return CGSize(width: base.width * scale, height: base.height * scale)
    }
}

/// One exchange in a session: what was asked, and what came back (nil: the person asked the next
/// thing before it finished), the agent's own words for it, and what it did for it.
struct V2Turn: Identifiable {
    let id: Int
    let question: String
    let result: AgentResult?
    var answer: String? = nil
    var work: V2Work? = nil
}

/// A chat being pulled out of the notch by its grab bar: where the pointer is.
struct V2DragOut: Equatable {
    let id: String
    var point: CGPoint
}

extension WorkbenchModel {
    // MARK: What shows

    func v2Task(_ id: String?) -> AgentTaskItem? { id.flatMap { id in agentTasks.first { $0.id == id } } }

    /// The session in focus: the board's, the expanded chat's.
    var v2FocusTask: AgentTaskItem? { v2Task(v2Focus) }

    /// The board's sessions: the person's own and a few others, only while they matter: running
    /// (or waiting on the person), or done and not yet opened.
    private var v2Visible: [AgentTaskItem] {
        agentTasks.filter { v2Sessions.contains($0.id) || DispatchV2.sampleIds.contains($0.id) }
    }

    /// Done and not yet opened: Ready for review, the latest first.
    var v2Ready: [AgentTaskItem] {
        v2Visible.filter { !$0.statusUnknown && ($0.state == .complete || $0.state == .failed) && !$0.stopped && !v2Checked.contains($0.id) }
            .sorted {
                let a = v2FinishedAt[$0.id] ?? Date.distantPast.addingTimeInterval(-$0.inState)
                let b = v2FinishedAt[$1.id] ?? Date.distantPast.addingTimeInterval(-$1.inState)
                return a > b
            }
    }

    /// Running: those waiting on the person first, then the latest sent.
    var v2Running: [AgentTaskItem] {
        v2Visible.filter { !$0.statusUnknown && ($0.state == .working || $0.state == .needsYou) }
            .sorted {
                if ($0.state == .needsYou) != ($1.state == .needsYou) { return $0.state == .needsYou }
                let a = v2Started[$0.id] ?? Date.distantPast.addingTimeInterval(-$0.inState)
                let b = v2Started[$1.id] ?? Date.distantPast.addingTimeInterval(-$1.inState)
                return a > b
            }
    }

    /// The board's sections (Oct 6, round three), as Claude Code's agent view parts its sessions,
    /// in the hover list's order: what waits on the person (a question, then a failure), what came
    /// back and isn't opened yet, what runs, and the sessions whose state can't be read, the most
    /// recently active first. Only the sections with sessions in them.
    var v2BoardSections: [(section: BoardSection, tasks: [AgentTaskItem])] {
        let ready = v2Ready
        let needsYou = v2Running.filter { $0.state == .needsYou } + ready.filter { $0.state == .failed }
        let running = v2Running.filter { $0.state == .working }
        let done = ready.filter { $0.state == .complete }
        let unknown = v2Visible.filter(\.statusUnknown).sorted { $0.age < $1.age }
        return [(BoardSection.needsYou, needsYou), (.done, done), (.running, running), (.unknown, unknown)]
            .filter { !$0.1.isEmpty }
            .map { (section: $0.0, tasks: $0.1) }
    }

    var v2BoardGroups: [[AgentTaskItem]] { v2BoardSections.map(\.tasks) }

    var v2BoardOrder: [AgentTaskItem] { v2BoardGroups.flatMap { $0 } }

    /// A row's second line, in plain words: what it asks; why it failed; what came back (the
    /// answer's first sentence, as the agent wrote it); for one at work, its project; for one whose
    /// state can't be read, its project and when it was last active.
    func v2BoardLine(_ task: AgentTaskItem) -> String {
        let project = task.project == DispatchV2.quickProject ? "Quick answer" : task.project
        if task.statusUnknown {
            return AgentBoard.duration(task.age).map { "\(project) · last active \($0) ago" } ?? project
        }
        switch task.state {
        case .needsYou: return task.activity
        case .working: return project
        case .complete, .failed:
            return Self.firstSentence(task.answer ?? task.reply ?? task.result?.outcome ?? task.activity)
        }
    }

    /// How long since it finished: the board's Done and Failed rows.
    func v2Since(_ task: AgentTaskItem, now: Date = Date()) -> String {
        let seconds = v2FinishedAt[task.id].map { (snapshotMode ? 0 : now.timeIntervalSince($0)) } ?? task.inState
        return AgentBoard.duration(seconds) ?? "now"
    }

    /// The first sentence of a message written in Markdown, its marks taken out.
    static func firstSentence(_ text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        var plain = line.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
        while let first = plain.first, "#->* ".contains(first) { plain.removeFirst() }
        // The first full stop followed by a space, outside quotation marks.
        var quoted = false
        var previous: Character = " "
        for (i, character) in zip(plain.indices, plain) {
            if character == "\u{201C}" { quoted = true }
            if character == "\u{201D}" { quoted = false }
            if character == " ", previous == ".", !quoted { return String(plain[..<i]) }
            previous = character
        }
        return plain
    }

    /// How long a session has run: m:ss counting in its view; on the board, "now", minutes, hours.
    func v2RunTime(_ task: AgentTaskItem, clock: Bool = false, now: Date = Date()) -> String {
        let seconds: Int
        if let start = v2Started[task.id] {
            seconds = max(0, Int((v2FinishedAt[task.id] ?? (snapshotMode ? start.addingTimeInterval(72) : now)).timeIntervalSince(start)))
        } else {
            seconds = Int(task.inState)
        }
        if clock { return String(format: "%d:%02d", seconds / 60, seconds % 60) }
        if seconds < 60 { return "now" }
        return seconds < 3600 ? "\(seconds / 60)m" : "\(seconds / 3600)h"
    }

    var v2SendLayout: V2SendLayout {
        V2SendLayout.make(request: v2Request.spoken, attachments: liveReferents.count, browsing: v2Browsing,
                          browseRows: v2BrowseRows.count, sheet: v2ModelSheet, metrics: metrics)
    }
    var v2BoardLayout: V2BoardLayout {
        V2BoardLayout.variant(boardStyle, model: self, metrics: metrics)
    }
    var v2ChatLayout: V2ChatLayout {
        V2ChatLayout.make(model: self, task: v2FocusTask, followed: v2Focus.flatMap { v2Followed[$0] }, metrics: metrics)
    }

    /// The island's outline for this flow's own states (the voice bar is Voiceflow's).
    var v2Outline: StackLayout.Outline? {
        switch notchState {
        case .v2Send: return v2SendLayout.outline
        case .v2Board: return v2BoardLayout.outline
        case .v2Chat: return v2ChatLayout.outline
        default: return nil
        }
    }

    /// Where the request goes: the person's pick, else the first suggestion.
    var v2Pick: V2Suggestion { v2PickStorage ?? v2Request.suggestions[0] }

    /// How long one of the person's requests took (or has taken so far), for its status line;
    /// nil for sessions Fovea didn't send.
    func v2Elapsed(_ id: String, now: Date = Date()) -> String? {
        guard let start = v2Started[id] else { return nil }
        let end = v2FinishedAt[id] ?? (snapshotMode ? start.addingTimeInterval(12) : now)
        let s = max(0, Int(end.timeIntervalSince(start)))
        return s < 60 ? "\(s) s" : String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: Choosing the chat

    /// A suggestion (or a chat found browsing) becomes where it goes.
    func chooseV2(_ pick: V2Suggestion) {
        v2PickStorage = pick
    }

    /// ⌃, or the pill: every chat below, as Dispatch's expanded view; again, folded.
    func toggleV2Browse() {
        guard notchState == .v2Send else { return }
        v2ModelSheet = false
        v2Browsing.toggle()
        if v2Browsing {
            v2BrowseAgent = v2Pick.quick ? ChatBook.predictedAgent : v2Pick.agent
            v2BrowseProject = nil
        }
    }

    func browseV2Agent(_ id: String) {
        v2BrowseAgent = id
        v2BrowseProject = nil
    }

    /// The browser's rows: the agent's projects, or one project's chats (a New chat first).
    var v2BrowseRows: [V2BrowseRow] {
        let projects = ChatBook.projects(of: v2BrowseAgent, in: ChatBook.chats)
        if let folder = v2BrowseProject, let project = projects.first(where: { $0.folder == folder }) {
            return [.back(folder), .chat(ChatBook.newChat(agent: v2BrowseAgent, folder: folder))]
                + project.chats.map { .chat($0) }
        }
        return projects.map { .project($0) }
    }

    /// A browser row: a project opens to its chats; Back returns; a chat is chosen, and the
    /// browser folds back to the pill with it (as Dispatch's does).
    func pickV2Browse(_ row: V2BrowseRow) {
        switch row {
        case .project(let project): v2BrowseProject = project.folder
        case .back: v2BrowseProject = nil
        case .chat(let chat):
            v2PickStorage = V2Suggestion(agent: chat.agent, chat: chat.isNew ? nil : chat.title, project: chat.folder,
                                         reason: chat.isNew ? "New" : chat.age)
            // On the voice bar's sheet (#19) the chat is chosen and the sheet stays, for the model.
            if notchState != .v2Voice { v2Browsing = false }
            v2BrowseProject = nil
        }
    }

    // MARK: The panel's list

    var v2Selection: V2Mode? {
        get {
            guard currentFlow == .dispatchV2 else { return nil }
            switch notchState {
            case .v2Voice: return .voice
            case .v2Transcribing: return .transcribe
            case .v2Send: return .send
            case .v2Board: return v2Detached.isEmpty ? .board : .pulled
            case .v2Chat: return v2Expanded && !(v2History[v2Focus ?? ""] ?? []).isEmpty ? (v2StagedLong ? .wholeLong : .whole) : .chat
            default: return .silent
            }
        }
        set {
            guard let newValue else { return }
            leaveFeedback()
            restingFlow = .dispatchV2
            dropUndo()
            stageV2(newValue)
        }
    }

    /// A state from the panel, for the chosen request. Each is live from there.
    func stageV2(_ mode: V2Mode) {
        v2Pinned = false
        v2Continuing = nil
        v2StagedLong = false
        switch mode {
        case .silent:
            notchState = .silent
        case .voice:
            startV2Voice()
            stageV2Referents()
        case .transcribe:
            startV2Voice()
            stageV2Referents()
            finishV2Voice()
        case .send:
            startV2Voice()
            stageV2Referents()
            showV2Send()
        case .board:
            v2Focus = workingV2Session()
            showAgentPanel(pinned: true)
        case .chat:
            let id = makeV2Session(v2Request.suggestions[0], at: v2Request.script.count - 1)
            v2FinishedAt[id] = Date()
            v2Pinned = true
            showV2Chat(id, popped: false)
        case .whole, .wholeLong:
            // A session asked more than once, opened expanded: every exchange, what the agent did
            // folded under each answer, the outline of its requests at the right. Many requests:
            // the code change's long session.
            if mode == .wholeLong { v2Request = .code }
            let id = makeV2Session(v2Request.suggestions[0], at: v2Request.script.count - 1)
            v2FinishedAt[id] = Date()
            seedV2History(id, long: mode == .wholeLong)
            v2Pinned = true
            showV2Chat(id, popped: false)
            v2Size = .expanded
        case .pulled:
            // A finished answer pulled out into a window, and a session at work tucked into the
            // left side; the board stays for more.
            let done = makeV2Session(v2Request.suggestions[0], at: v2Request.script.count - 1)
            v2FinishedAt[done] = Date()
            // It was asked more once, and answered: the window lists both, the rail beside them.
            if let i = agentTasks.firstIndex(where: { $0.id == done }), let answer = v2Request.followUp.script.last {
                v2History[done] = [V2Turn(id: 0, question: agentTasks[i].request, result: agentTasks[i].result)]
                v2Followed[done] = v2Request.followUp.spoken
                apply(answer, to: i)
            }
            let working = workingV2Session()
            let size = V2DetachedLayout.size
            v2Detached = [
                V2Detached(id: done, origin: CGPoint(x: display.frame.width - size.width - 40, y: 120), docked: nil, dockY: 120),
                V2Detached(id: working, origin: CGPoint(x: 40, y: 220), docked: .left, dockY: 260),
            ]
            v2Checked.formUnion([done, working])
            v2Focus = working
            showAgentPanel(pinned: true)
        }
    }

    /// A session of the chosen request at work (its second beat), running on from there.
    func workingV2Session() -> String {
        if let id = v2Session, v2Task(id)?.state == .working { return id }
        let start = min(1, v2Request.script.count - 2)
        let id = makeV2Session(v2Request.suggestions[0], at: start)
        run(id, from: start)
        return id
    }

    // MARK: Asking

    /// fn⌃ (new), or fn on an expanded chat (`continuing` it): the aura listens; left Option
    /// held takes regions, passages and files, twice the whole screen. Whatever was out there carries on.
    func startV2Voice(continuing id: String? = nil) {
        restingFlow = .dispatchV2
        v2Continuing = id
        if notchState != .v2Voice { clearReferents() }
        notchState = .v2Voice
    }

    /// fn⌃ again (or Return): the session ends; what was said is transcribed (the aura's progress
    /// bar), then asking more goes straight to its session and a new request goes on to Choose
    /// chat with what was taken.
    func finishV2Voice() {
        guard notchState == .v2Voice else { return }
        capturing = false
        optionTurnedOn = nil
        v2TranscribeStart = Date()
        notchState = .v2Transcribing
        guard !snapshotMode else { return }
        v2Transcribe?.cancel()
        v2Transcribe = Task { [weak self] in
            try? await Task.sleep(for: .seconds(WorkbenchTokens.V2.transcribeTime))
            guard let self, !Task.isCancelled, self.notchState == .v2Transcribing else { return }
            if let id = self.v2Continuing, self.v2Task(id) != nil {
                self.askMoreV2(id)
            } else if !self.v2ReviewBeforeSend {
                // Feedback #19: the words aren't shown to check; it goes where the bar said, and the
                // board shows it on its way.
                self.sendWithoutReview()
            } else {
                self.showV2Send()
            }
        }
    }

    /// How far the transcription is, 0 → 1.
    func v2TranscribeProgress(at date: Date) -> Double {
        if snapshotMode { return 0.55 }
        return max(0, min(1, date.timeIntervalSince(v2TranscribeStart) / WorkbenchTokens.V2.transcribeTime))
    }

    /// Choose chat: the first suggestion in the pill. It waits for the person: nothing sends by
    /// itself.
    func showV2Send() {
        v2PickStorage = nil
        v2Browsing = false
        v2ModelSheet = false
        v2BrowseProject = nil
        v2Inspecting = nil
        notchState = .v2Send
    }

    /// It goes where the pill says: by the send button, fn⌃ or Return.
    func sendV2Now() {
        guard notchState == .v2Send else { return }
        let pick = v2Pick
        let index = v2Request.suggestions.firstIndex(of: pick)
        let label: V2RoutingLabel = index == 0 ? .keptFirst : (index.map { .picked($0 + 1) } ?? .browsed)
        send(pick, label: label)
    }

    /// Choose chat's ↑↓: the next or the previous suggestion into the pill.
    func stepV2Pick(_ step: Int) {
        let suggestions = v2Request.suggestions
        let i = suggestions.firstIndex(of: v2Pick) ?? 0
        chooseV2(suggestions[max(0, min(suggestions.count - 1, i + step))])
    }

    /// It goes there with what was taken; the board shows it a moment, then the island rests.
    func send(_ pick: V2Suggestion, label: V2RoutingLabel) {
        v2Labels.append(label)
        let images = liveReferents.map(\.image)
        let id = makeV2Session(pick, at: 0)
        if !images.isEmpty { v2Attachments[id] = images }
        run(id, from: 0)
        showBoardAfterSend(id)
    }

    /// Asking more in a session: it works again; the board shows it, then the island rests. From
    /// a pulled-out window (typed in its box), the window shows it at work instead.
    func askMoreV2(_ id: String, text: String? = nil, inWindow: Bool = false, now: Bool = false) {
        guard let i = agentTasks.firstIndex(where: { $0.id == id }) else { return }
        // Feedback #24: while it works, a new message waits its turn (Send now takes it in at once).
        if !now, agentTasks[i].state == .working || agentTasks[i].state == .needsYou {
            enqueueV2(id, text: text ?? (v2Requests[id] ?? v2Request).followUp.spoken)
            if !inWindow { showBoardAfterSend(id) }
            return
        }
        // The exchange so far is kept, so the chat can show (and the rail find) every one.
        let past = v2History[id] ?? []
        let done = agentTasks[i].state == .complete
        v2History[id] = past + [V2Turn(id: past.count, question: v2Followed[id] ?? agentTasks[i].request,
                                       result: done ? agentTasks[i].result : nil,
                                       answer: done ? agentTasks[i].answer : nil,
                                       work: done ? v2Work(agentTasks[i]) : nil)]
        let request = v2Requests[id] ?? v2Request
        let more = request.followUp
        v2Scripts[id] = more.script
        v2Followed[id] = text?.isEmpty == false ? text : more.spoken
        withAnimation(WorkbenchTokens.Panel.change) {
            agentTasks[i].state = .working
            agentTasks[i].stopped = false
            agentTasks[i].inState = 0
            agentTasks[i].age = 0
            agentTasks[i].steps = []
            agentTasks[i].answer = nil
            apply(more.script[0], to: i)
            decorateV2(id, beat: 0, followUp: true)
        }
        v2Continuing = nil
        v2Checked.remove(id)
        v2FinishedAt[id] = nil
        v2Started[id] = Date()
        run(id, from: 0, script: more.script, pace: request.pace)
        if inWindow {
            v2Sessions.insert(id)
        } else {
            showBoardAfterSend(id)
        }
    }

    /// Just sent: the board, the new session in focus, for a few seconds (longer while the
    /// pointer is on it); then a quick answer that is ready opens, or the island rests.
    func showBoardAfterSend(_ id: String) {
        v2Session = id
        v2Focus = id
        v2Sessions.insert(id)
        showAgentPanel(pinned: false, sent: id)
        v2BoardHold?.cancel()
        guard !snapshotMode else { return }
        v2BoardHold = Task { [weak self] in
            try? await Task.sleep(for: .seconds(WorkbenchTokens.V2.boardHold))
            while let self, !Task.isCancelled, self.notchState == .v2Board, self.panelZone != .outside {
                try? await Task.sleep(for: .seconds(0.3))
            }
            guard let self, !Task.isCancelled, self.notchState == .v2Board, self.panelSentTask == id else { return }
            self.panelSentTask = nil
            if self.v2Task(id)?.state == .complete, self.v2Quick(id) {
                self.showV2Chat(id, popped: true)
            } else {
                self.notchState = .silent
            }
        }
    }

    /// A session for a suggestion, at a beat of the request's script.
    @discardableResult
    func makeV2Session(_ pick: V2Suggestion, at beat: Int) -> String {
        let r = v2Request
        let script = r.script
        let id = "t-v2-\(UUID().uuidString.prefix(6))"
        let b = script[min(beat, script.count - 1)]
        var task = AgentTaskItem(id: id, agent: pick.agent,
                                 // A quick answer is titled by its question (AGENTS.md "Quick Answer").
                                 session: pick.quick ? r.spoken : (pick.chat ?? "New chat"),
                                 project: pick.project ?? DispatchV2.quickProject, request: r.spoken,
                                 state: b.state, activity: b.activity, work: b.work, object: b.object,
                                 preview: b.preview, ask: b.ask, age: 0, inState: 0)
        task.screen = b.screen
        task.result = b.result
        task.modelLabel = v2ModelLabel(agent: pick.agent)
        task.steps = script.prefix(beat + 1).enumerated().compactMap { i, s in
            s.state == .working && s.work != .done ? AgentStep(id: i, work: s.work, object: s.object, activity: s.activity) : nil
        }
        agentTasks.append(task)
        v2Sessions.insert(id)
        v2Session = id
        v2Scripts[id] = script
        v2Requests[id] = r
        decorateV2(id, beat: min(beat, script.count - 1))
        nameV2(id, pick: pick)
        v2Started[id] = Date().addingTimeInterval(beat > 0 ? -Double(beat) * r.pace : 0)
        return id
    }

    /// The agent works through its script at its own pace; when done, `v2Finished`.
    func run(_ id: String, from start: Int, script: [AgentBeat]? = nil, pace: Double? = nil) {
        guard !snapshotMode else { return }
        v2Runs[id]?.cancel()
        v2Runs[id] = Task { [weak self] in await self?.runV2(id, from: start, script: script, pace: pace) }
    }

    private func runV2(_ id: String, from start: Int, script: [AgentBeat]?, pace: Double?) async {
        guard let script = script ?? v2Scripts[id], start + 1 < script.count else { return }
        let pace = pace ?? (v2Requests[id] ?? v2Request).pace
        for i in (start + 1)..<script.count {
            try? await Task.sleep(for: .seconds(pace))
            guard !Task.isCancelled,
                  let index = agentTasks.firstIndex(where: { $0.id == id }),
                  agentTasks[index].state == .working, !agentTasks[index].stopped else { return }
            withAnimation(WorkbenchTokens.Panel.change) {
                apply(script[i], to: index)
                decorateV2(id, beat: i)
            }
            // A session waiting on the person holds its queue (feedback #24).
            if script[i].state == .needsYou { v2QueuePaused.insert(id) }
        }
        v2Runs[id] = nil
        v2Finished(id)
    }

    /// Answered quickly enough that the person is likely still waiting on it.
    func v2Quick(_ id: String) -> Bool {
        guard let start = v2Started[id], let end = v2FinishedAt[id] else { return false }
        return end.timeIntervalSince(start) <= WorkbenchTokens.V2.quickLimit
    }

    /// Done. A quick answer opens by itself (the board's hold opens it as it ends); anything that
    /// took longer waits on the board, Ready for review, on top.
    private func v2Finished(_ id: String) {
        v2FinishedAt[id] = Date()
        // Feedback #24: the next waiting message goes once this one is done.
        if takeNextQueued(id) { return }
        // Pulled out, its window shows the answer: seen there.
        if v2Detached.contains(where: { $0.id == id }) {
            v2Checked.insert(id)
            return
        }
        guard v2Quick(id) else { return }
        if notchState == .v2Board, panelSentTask == id { return }
        if notchState == .silent { showV2Chat(id, popped: true) }
    }

    /// A session's expanded chat: the request; the agent's response, formatted, with its screen;
    /// its state; what to do with it; the grab bar to pull it out. Popped up by itself it goes
    /// after a while unless the pointer is on it; opened by the person, it stays.
    func showV2Chat(_ id: String, popped: Bool, fromBoard: Bool = false, expanded: Bool = false) {
        guard v2Task(id) != nil else { return }
        v2Size = expanded ? .expanded : .usual
        v2OutlineShown = false
        v2HistoryHeld = false
        v2HistoryEpoch += 1
        v2Focus = id
        v2Copied = false
        v2ChatFromBoard = fromBoard
        v2ChatInteracted = !popped
        if !popped { v2Checked.insert(id) }
        notchState = .v2Chat
        v2ChatHold?.cancel()
        guard popped, !snapshotMode, !v2Pinned else { return }
        v2ChatHold = Task { [weak self] in
            try? await Task.sleep(for: .seconds(WorkbenchTokens.V2.chatHold))
            while let self, !Task.isCancelled, self.notchState == .v2Chat, self.v2ChatHovered {
                try? await Task.sleep(for: .seconds(0.3))
            }
            guard let self, !Task.isCancelled, self.notchState == .v2Chat, self.v2Focus == id else { return }
            self.closeV2Chat()
        }
    }

    /// Expanded, the header's way out to the control board, however the session was opened. Read,
    /// the session leaves the board's Done, as it does closed from the board; with nothing left on
    /// the board the island rests (it never opens empty). The board stays until the person leaves
    /// it: the pointer is likely outside it, where the expanded session was.
    func exitV2ToBoard() {
        guard notchState == .v2Chat else { return }
        v2ChatHold?.cancel()
        if let id = v2Focus { v2Checked.insert(id) }
        v2Expanded = false
        v2ChatFromBoard = false
        if v2BoardOrder.isEmpty { notchState = .silent } else { showAgentPanel(pinned: true) }
    }

    /// ✕ or Esc on the chat: back to the board if it came from there; otherwise the island rests.
    /// Read (the pointer was on it, or it was opened), it is no longer Ready for review.
    func closeV2Chat() {
        guard notchState == .v2Chat else { return }
        v2ChatHold?.cancel()
        if v2ChatInteracted, let id = v2Focus { v2Checked.insert(id) }
        v2Expanded = false
        if v2ChatFromBoard {
            showAgentPanel(pinned: v2BoardPinned)
        } else {
            notchState = .silent
        }
    }

    /// The pointer over the chat: it holds, and it has been read.
    func setV2ChatHovered(_ inside: Bool) {
        v2ChatHovered = inside
        if inside { v2ChatInteracted = true }
    }

    /// The board's session: after a short rest, it is the focus; passing over doesn't.
    func hoverV2(_ id: String, _ inside: Bool) {
        v2HoverFocus?.cancel()
        guard inside else { return }
        v2HoverFocus = Task { [weak self] in
            try? await Task.sleep(for: .seconds(WorkbenchTokens.V2.focusDwell))
            guard let self, !Task.isCancelled, self.notchState == .v2Board else { return }
            self.v2Focus = id
        }
    }

    /// A session clicked (or Return): its expanded chat; with `expanded`, its answer at the reading
    /// size.
    func openV2(_ id: String, expanded: Bool = false) {
        let fromBoard = notchState == .v2Board
        if fromBoard { v2BoardPinned = panelPinned }
        showV2Chat(id, popped: false, fromBoard: fromBoard, expanded: expanded)
    }

    /// The expand button, left ⌃ and the panel's toggle: expanded (the whole session), and back.
    func toggleV2Expanded() {
        setV2Size(v2Expanded ? .usual : .expanded)
    }

    /// The session's size, changed with the island's resize spring; the person is reading it, so
    /// it holds.
    func setV2Size(_ size: V2SessionSize) {
        guard notchState == .v2Chat, size != v2Size else { return }
        v2ChatInteracted = true
        v2ChatHold?.cancel()
        withAnimation(WorkbenchTokens.V2.resize) {
            v2Size = size
            v2HistoryHeld = false
            v2HistoryEpoch += 1
            if size != .expanded { v2OutlineShown = false }
        }
    }

    /// Copy what it wrote: the draft, else the outcome.
    func copyV2(_ id: String? = nil) {
        guard let task = v2Task(id ?? v2Focus), let text = task.result?.draft ?? task.result?.outcome else { return }
        if !options.smoke && !snapshotMode {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        v2Copied = true
        v2ChatInteracted = true
    }

    // MARK: Pulling a chat out of the notch

    /// The grab bar is being pulled: the chat follows the pointer as a window.
    func dragOutV2(_ id: String, to point: CGPoint) {
        v2DragOut = V2DragOut(id: id, point: point)
        v2ChatHold?.cancel()
    }

    /// Let go out of the notch: the chat is a window there, and the notch is the board again, so
    /// another can be pulled out.
    func endDragOutV2(_ id: String, at point: CGPoint) {
        v2DragOut = nil
        let size = V2DetachedLayout.size
        let origin = clampedV2(CGPoint(x: point.x - size.width / 2, y: point.y - V2DetachedLayout.grip))
        v2Detached.removeAll { $0.id == id }
        v2Detached.append(V2Detached(id: id, origin: origin, docked: nil, dockY: origin.y))
        v2Checked.insert(id)
        // The board a moment (another can be pulled out), then, with the pointer away, the island
        // rests, as after Send; a pinned board stays pinned.
        showAgentPanel(pinned: v2BoardPinned, sent: v2BoardPinned ? nil : id)
    }

    /// A window dragged by its header.
    func moveDetachedV2(_ id: String, to origin: CGPoint) {
        guard let i = v2Detached.firstIndex(where: { $0.id == id }) else { return }
        v2Detached[i].origin = origin
        v2Detached[i].docked = nil
    }

    /// Let go: with the pointer at a side of the screen, it tucks into that side; otherwise it
    /// stays where it is.
    func endMoveDetachedV2(_ id: String, pointer: CGPoint) {
        guard let i = v2Detached.firstIndex(where: { $0.id == id }) else { return }
        let V = WorkbenchTokens.V2.self
        if pointer.x <= V.edgeSnap {
            v2Detached[i].docked = .left
        } else if pointer.x >= display.frame.width - V.edgeSnap {
            v2Detached[i].docked = .right
        } else {
            v2Detached[i].origin = clampedV2(v2Detached[i].origin, size: v2Detached[i].size)
            return
        }
        v2Detached[i].dockY = min(max(metrics.menuBarHeight + 8, pointer.y - V.tabSize.height / 2),
                                  display.frame.height - V.tabSize.height - 8)
    }

    /// The tucked tab pulled (or clicked): the window comes back out beside that side.
    func undockV2(_ id: String) {
        guard let i = v2Detached.firstIndex(where: { $0.id == id }), let side = v2Detached[i].docked else { return }
        let size = v2Detached[i].size
        let x = side == .left ? 24 : display.frame.width - size.width - 24
        v2Detached[i].origin = clampedV2(CGPoint(x: x, y: v2Detached[i].dockY - 20), size: size)
        v2Detached[i].docked = nil
    }

    /// A sample session's earlier exchanges (V2History.swift): its own request and answer first,
    /// then what was asked after; the one now is the request's follow-up, answered.
    func seedV2History(_ id: String, long: Bool) {
        guard let i = agentTasks.firstIndex(where: { $0.id == id }) else { return }
        v2StagedLong = long
        let request = v2Request
        var turns = [V2Turn(id: 0, question: agentTasks[i].request, result: agentTasks[i].result,
                            answer: request.answer(followUp: false), work: request.work(followUp: false))]
        for turn in request.earlierTurns(long: long) {
            turns.append(V2Turn(id: turns.count, question: turn.question, result: nil, answer: turn.answer, work: turn.work))
        }
        v2History[id] = turns
        v2Followed[id] = request.followUp.spoken
        v2FollowUps.insert(id)
        if let last = request.followUp.script.last { apply(last, to: i) }
        decorateV2(id, beat: request.followUp.script.count - 1, followUp: true)
        agentTasks[i].state = .complete
        agentTasks[i].answer = request.answer(followUp: true)
    }

    /// A session's exchanges, oldest first: the ones before, then the one now.
    func v2Turns(_ id: String) -> [V2Turn] {
        guard let task = v2Task(id) else { return [] }
        let past = v2History[id] ?? []
        return past + [V2Turn(id: past.count, question: v2Followed[id] ?? task.request,
                              result: task.state == .complete ? task.result : nil)]
    }

    /// A pulled-out chat made bigger or smaller (its corner, or a pinch): the window and all in it
    /// scale together, its top-left staying put, and it stays on the screen.
    func scaleDetachedV2(_ id: String, to scale: CGFloat) {
        guard let i = v2Detached.firstIndex(where: { $0.id == id }) else { return }
        let range = WorkbenchTokens.V2.detachedScale
        v2Detached[i].scale = min(max(scale, range.lowerBound), range.upperBound)
        v2Detached[i].origin = clampedV2(v2Detached[i].origin, size: v2Detached[i].size)
    }

    /// ✕ on a pulled-out chat: it goes; a session still at work is stopped with it (cancelled).
    func closeDetachedV2(_ id: String) {
        if v2Task(id)?.state == .working { stopTask(id) }
        v2Detached.removeAll { $0.id == id }
    }

    private func clampedV2(_ origin: CGPoint, size: CGSize = V2DetachedLayout.size) -> CGPoint {
        return CGPoint(x: min(max(4, origin.x), display.frame.width - size.width - 4),
                       y: min(max(metrics.menuBarHeight + 4, origin.y), display.frame.height - size.height - 4))
    }

    // MARK: Keys

    /// fn⌃: a new request; again, on to Choose chat (and from there, it sends). fn does the same
    /// while listening or choosing; on an expanded chat (or the board's focus, if the person's)
    /// it asks more there; it is Voiceflow's elsewhere. Returns whether the press was this flow's.
    func v2FunctionKey(control: Bool) -> Bool {
        switch notchState {
        case .v2Voice:
            finishV2Voice()
            return true
        case .v2Transcribing:
            return true
        case .v2Send:
            sendV2Now()
            return true
        case .v2Chat, .v2Board:
            if control {
                startV2Voice()
            } else if let id = v2Focus, v2Sessions.contains(id) {
                v2Checked.insert(id)
                startV2Voice(continuing: id)
            } else {
                return false
            }
            return true
        default:
            if control { startV2Voice(); return true }
            return false
        }
    }

    /// The window's keys in this flow: in Choose chat ↑↓ step through the suggestions and Return
    /// sends (browsing, ←→ change agent); on the board the arrows move the focus and Return opens.
    func v2Key(_ key: ChatKey) -> Bool {
        switch notchState {
        case .v2Send:
            if v2Browsing, key == .left || key == .right {
                let ids = ChatAgent.all.map(\.id)
                let i = ids.firstIndex(of: v2BrowseAgent) ?? 0
                browseV2Agent(ids[(i + (key == .right ? 1 : ids.count - 1)) % ids.count])
                return true
            }
            switch key {
            case .up: stepV2Pick(-1)
            case .down: stepV2Pick(1)
            case .enter, .send: sendV2Now()
            case .left, .right: return false
            }
            return true
        case .v2Board:
            // Creatures: the arrows walk the wings left to right, as they stand.
            let ids = boardStyle == .creatures
                ? CreatureSlots.make(model: self, width: v2BoardLayout.outline.size.width,
                                     notch: NotchGeometry.notchRect(metrics: metrics, spec: WorkbenchTokens.Island.spec)).visualOrder
                : v2BoardOrder.map(\.id)
            let i = v2Focus.flatMap { ids.firstIndex(of: $0) } ?? -1
            if boardStyle == .petDesk, key == .up || key == .down {
                let columns = WorkbenchTokens.Pets.deskColumns
                let j = i < 0 ? 0 : i + (key == .down ? columns : -columns)
                if ids.indices.contains(j) { v2Focus = ids[j]; v2ScrollTarget = ids[j] }
                return true
            }
            switch key {
            case .up, .left:
                if ids.indices.contains(i - 1) { v2Focus = ids[i - 1]; v2ScrollTarget = ids[i - 1] }
            case .down, .right:
                if ids.indices.contains(i + 1) { v2Focus = ids[i + 1]; v2ScrollTarget = ids[i + 1] }
            case .enter, .send:
                if let id = v2Focus { openV2(id) }
            }
            return true
        case .v2Voice:
            if key == .enter || key == .send { finishV2Voice(); return true }
            return false
        default:
            return false
        }
    }

    // MARK: Play

    /// The whole flow, hands off: it listens, the request's referents arriving as if taken; then
    /// Choose chat counts down and sends; the board; the answer opening by itself.
    func playV2() {
        startV2Voice()
        guard !snapshotMode else { stageV2Referents(); return }
        v2Play?.cancel()
        v2Play = Task { [weak self] in
            try? await Task.sleep(for: .seconds(WorkbenchTokens.V2.listenTime / 2))
            guard let self, !Task.isCancelled, self.notchState == .v2Voice else { return }
            self.stageV2Referents()
            try? await Task.sleep(for: .seconds(WorkbenchTokens.V2.listenTime / 2))
            guard !Task.isCancelled, self.notchState == .v2Voice else { return }
            self.finishV2Voice()
            // Choose chat waits for the person; Play is the person, and sends after a look.
            try? await Task.sleep(for: .seconds(WorkbenchTokens.V2.transcribeTime + WorkbenchTokens.V2.playChoose))
            guard !Task.isCancelled, self.notchState == .v2Send else { return }
            self.sendV2Now()
        }
    }

    /// The request's referents, as if taken while speaking.
    func stageV2Referents() {
        guard liveReferents.isEmpty else { return }
        for referent in v2Request.referents {
            guard let (image, source) = V2Referents.image(referent) else { continue }
            referents.append(CapturedReferent(id: UUID(), image: image, aspect: image.size.width / max(1, image.size.height),
                                              source: source))
        }
    }

    /// What was taken with a session's request, or the chosen request's samples.
    func v2Referents(of id: String?) -> [NSImage] {
        if let id, let images = v2Attachments[id], !images.isEmpty { return images }
        let request = id.flatMap { v2Requests[$0] } ?? v2Request
        return request.referents.compactMap { V2Referents.image($0)?.image }
    }
}

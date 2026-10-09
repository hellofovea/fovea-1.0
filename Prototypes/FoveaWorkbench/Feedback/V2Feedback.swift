import SwiftUI
import AppKit
import FoveaCore

// The Oct 6 feedback's Dispatch Version 2 pieces (the views are in V2FeedbackViews.swift):
// #1 the model and thinking effort beside the chat, the referents as one stack; #9–10 progress
// from what the agents report (no picture of a screen); #11–13 the answer as the agent wrote it,
// its steps folded, what it made to open; #15 titles named from the request; #16 the activity
// line; #19 skipping the words' review; #23 answer again and stop; #24 the queue.
// docs/island/FEEDBACK_2026-10-06.md has the reasons.

/// #1's stages: the model sheet closed, or open.
enum ModelStage: String, CaseIterable, Identifiable {
    case closed, open
    var id: String { rawValue }
    var title: String { self == .closed ? "Choose chat" : "Model open" }
}

/// A message waiting for a working session (#24): its words and anything taken with it.
struct V2QueuedAsk: Identifiable, Equatable {
    let id = UUID()
    let text: String
    var images: [NSImage] = []
    static func == (a: V2QueuedAsk, b: V2QueuedAsk) -> Bool { a.id == b.id }
}

/// Something the answer made or pointed at, to open and check first-hand (#11, #13): a file it
/// changed (with its lines), the paper, the calendar, the draft.
struct V2Artifact: Identifiable, Equatable {
    let title: String
    let symbol: String
    var change: FileChange? = nil
    var id: String { title }
}

// MARK: - The models each agent offers

/// A model an agent offers and the thinking efforts it takes (the agents' own catalogs, as
/// fovea-mac reads them; these are its fixtures and today's names).
struct AgentModelOption: Identifiable, Equatable {
    let id: String
    let name: String
    let efforts: [String]
    let defaultEffort: String?
}

enum ModelCatalog {
    static func options(agent: String) -> [AgentModelOption] {
        switch agent {
        case "codex":
            return [AgentModelOption(id: "gpt-5-codex", name: "GPT-5 Codex", efforts: ["low", "medium", "high", "xhigh"], defaultEffort: "medium"),
                    AgentModelOption(id: "gpt-5", name: "GPT-5", efforts: ["minimal", "low", "medium", "high"], defaultEffort: "medium")]
        case "cursor":
            return [AgentModelOption(id: "claude-opus-5", name: "Opus 5", efforts: ["low", "medium", "high"], defaultEffort: "high"),
                    AgentModelOption(id: "gpt-5", name: "GPT-5", efforts: ["low", "medium", "high"], defaultEffort: "medium")]
        case "grok-bot":
            return [AgentModelOption(id: "grok-4", name: "Grok 4", efforts: ["low", "high"], defaultEffort: "low")]
        default:
            // Claude Code, and Fovea's quick answers (its default agent).
            return [AgentModelOption(id: "opus-5.5", name: "Opus 5.5", efforts: ["low", "medium", "high", "max"], defaultEffort: "high"),
                    AgentModelOption(id: "sonnet-5", name: "Sonnet 5", efforts: ["low", "medium", "high", "max"], defaultEffort: "medium"),
                    AgentModelOption(id: "haiku-4.5", name: "Haiku 4.5", efforts: [], defaultEffort: nil)]
        }
    }

    static func effortName(_ effort: String) -> String {
        switch effort {
        case "minimal": return "Minimal"
        case "low": return "Low"
        case "medium": return "Medium"
        case "high": return "High"
        case "xhigh": return "Extra High"
        case "max": return "Max"
        default: return effort.capitalized
        }
    }
}

// MARK: - What the sample requests report

extension V2Request {
    /// The name a small model gives a new session from its first request (as ChatGPT and Claude
    /// name a chat): a few words, never the request itself.
    var generatedTitle: String {
        switch self {
        case .formula: return "The attention formula, explained"
        case .calendar: return "This afternoon's calendar"
        case .draft: return "Reply to Sam about Thursday"
        case .code: return "Match the notch ears to the menu bar"
        }
    }

    /// The plan it makes, when it makes one: the code change does; a quick answer doesn't.
    var plan: [String] {
        switch self {
        case .code: return ["Read the request and the two screenshots", "Match the ears to the menu bar's height",
                            "Take the spacing from the second screenshot", "Build and run the tests"]
        case .formula: return ["Read the formula", "Explain each term"]
        case .calendar, .draft: return []
        }
    }

    /// How much of the plan is done at each beat of the script.
    func planDone(beat: Int, followUp: Bool) -> Int {
        guard !followUp else { return 0 }
        switch self {
        case .code: return [0, 1, 2, 3, 3, 4][min(beat, 5)]
        case .formula: return [0, 1, 2][min(beat, 2)]
        default: return 0
        }
    }

    /// The files changed by each beat, and their lines.
    func changes(beat: Int, followUp: Bool) -> [FileChange] {
        guard self == .code else { return [] }
        let shape = "Sources/Fovea/Island/IslandShape.swift", geometry = "Sources/FoveaCore/Island/NotchGeometry.swift"
        if followUp {
            return beat == 0 ? [] : [FileChange(path: "Sources/FoveaCore/Fixtures.swift", added: 9, removed: 0),
                                     FileChange(path: "Tests/FoveaCoreTests/NotchGeometryTests.swift", added: 14, removed: 0)]
        }
        switch beat {
        case 0: return []
        case 1: return [FileChange(path: shape, added: 1, removed: 1)]
        case 2: return [FileChange(path: shape, added: 1, removed: 1), FileChange(path: geometry, added: 1, removed: 1)]
        default: return [FileChange(path: shape, added: 3, removed: 1), FileChange(path: geometry, added: 2, removed: 1)]
        }
    }

    /// Its final message, as the agent wrote it (Markdown): what came back, never re-laid out.
    func answer(followUp: Bool) -> String {
        switch (self, followUp) {
        case (.code, false):
            return """
            The ears now match the menu bar's height, and the spacing follows your second screenshot.

            ### What changed
            - **Height.** The ears read `metrics.menuBarHeight` instead of a fixed 22 pt, in [IslandShape.swift](Sources/Fovea/Island/IslandShape.swift): the notch's height on this display, the menu bar's own on a display without one.
            - **Spacing.** The ears sit 6 pt from the island's body, as in your second screenshot, in [NotchGeometry.swift](Sources/FoveaCore/Island/NotchGeometry.swift).
            - **Full screen.** The black band keeps its height when an app goes full screen, so nothing jumps.

            ### Checked
            - `swift build` passes.
            - `swift test` passes, the 12 tests in `NotchGeometryTests` among them.
            """
        case (.code, true):
            return """
            It holds on an external display too: the software island takes the same ear height there.

            ### What I checked
            - **This display:** the ears read the menu bar's height, as before.
            - **An external display without a notch:** the software island sits at the top centre and takes that display's own menu bar height.
            - **Moving between them:** the island follows the display the pointer is on, and its ears change height with it.

            ### What I added
            - `externalDisplayMetrics`, a 27-inch display without a notch, in [Fixtures.swift](Sources/FoveaCore/Fixtures.swift).
            - `softwareIslandEars` in [NotchGeometryTests.swift](Tests/FoveaCoreTests/NotchGeometryTests.swift), which pins the ear height there.

            `swift test --filter NotchGeometryTests` passes.
            """
        case (.formula, false):
            return """
            It turns each word into a weighted mix of the other words' values.

            | Term | What it means |
            |---|---|
            | Q, K, V | Queries, keys and values: three views of each word |
            | QKᵀ | How well each query matches each key |
            | √dₖ | Divides the scores so they stay small |
            | softmax | Turns the scores into weights that add up to 1 |

            So a word's output is the others' values, weighted by how well they match it.
            """
        case (.formula, true):
            return """
            Without it, the scores grow with the key size and softmax saturates.

            - A dot product of two *d*-long vectors grows about as √*d*.
            - Dividing by √dₖ keeps the scores near 1, so the weights stay soft.
            """
        case (.calendar, false):
            return """
            Two things this afternoon:

            - **2:00 PM** Design review with Mia · Zoom
            - **4:30 PM** Dentist · 18 Grove St

            You're free from 3:00 to 4:30.
            """
        case (.calendar, true):
            return """
            Free from 1:00 tomorrow.

            - **12:00 PM** Lunch with Ana · Tartine
            - **1:00 PM** Free until 6:00
            """
        case (.draft, false):
            return """
            Here's a short yes, with the invite to follow:

            > Hi Sam,
            >
            > Thursday at 3 works for me. I'll send an invite this afternoon.
            >
            > Best,
            """
        case (.draft, true):
            return """
            The same yes, a little warmer:

            > Hi Sam,
            >
            > Thursday at 3 is perfect, looking forward to it. I'll send an invite this afternoon.
            >
            > Best,
            """
        }
    }

    /// What the agent did, folded under its answer (#11; Oct 7, docs/island/WHOLE_SESSION.md): its
    /// steps as it reported them, and what it said between them.
    func work(followUp: Bool) -> V2Work {
        func step(_ kind: StepKind, _ object: String? = nil, added: Int? = nil, removed: Int? = nil,
                  passed: Bool? = nil, note: String? = nil) -> V2WorkEntry {
            .step(AgentLiveStep(kind: kind, object: object, added: added, removed: removed, passed: passed, note: note))
        }
        switch (self, followUp) {
        case (.code, false):
            return V2Work(seconds: 161, entries: [
                .remark("I'll look at your two screenshots first, then find where the ears get their height."),
                step(.read, "your 2 screenshots"),
                step(.read, "IslandShape.swift"),
                step(.search, "menuBarHeight", note: "3 files"),
                step(.read, "NotchGeometry.swift"),
                .remark("The ears use a fixed 22 pt. I'll read the height from the menu bar instead, and take the spacing from your second screenshot."),
                step(.edit, "IslandShape.swift", added: 3, removed: 1),
                step(.edit, "NotchGeometry.swift", added: 2, removed: 1),
                .remark("Building and running the tests."),
                step(.build, "swift build", passed: true),
                step(.test, "swift test", passed: true),
            ])
        case (.code, true):
            return V2Work(seconds: 72, entries: [
                .remark("I'll check the island on a display without a notch."),
                step(.read, "NotchGeometry.swift"),
                step(.search, "softwareIsland", note: "2 files"),
                step(.read, "Fixtures.swift"),
                step(.edit, "Fixtures.swift", added: 9, removed: 0),
                step(.edit, "NotchGeometryTests.swift", added: 14, removed: 0),
                step(.test, "swift test --filter NotchGeometryTests", passed: true),
            ])
        case (.formula, false):
            return V2Work(seconds: 8, entries: [
                step(.read, "your screenshot"),
                .remark("This is scaled dot-product attention, from the paper's section 3.2.1."),
            ])
        case (.formula, true):
            return V2Work(seconds: 6, entries: [.remark("The scaling keeps the softmax away from its flat ends.")])
        case (.calendar, false):
            return V2Work(seconds: 4, entries: [
                .remark("Checking this afternoon in your calendar."),
                step(.tool, "calendar · list_events", note: "2 events"),
            ])
        case (.calendar, true):
            return V2Work(seconds: 4, entries: [
                .remark("Checking tomorrow."),
                step(.tool, "calendar · list_events", note: "2 events"),
            ])
        case (.draft, false):
            return V2Work(seconds: 9, entries: [
                .remark("Reading Sam's email."),
                step(.tool, "mail · read_message"),
            ])
        case (.draft, true):
            return V2Work(seconds: 5, entries: [.remark("Making the same reply a little warmer.")])
        }
    }

    /// What the answer made or points at, to open (#11, #13): the files its answer links, the paper,
    /// the calendar, the draft.
    func artifacts(followUp: Bool, changes: [FileChange]) -> [V2Artifact] {
        switch self {
        case .code:
            return changes.map { V2Artifact(title: $0.name, symbol: "swift", change: $0) }
        case .formula:
            return [V2Artifact(title: "the paper", symbol: "doc.richtext")]
        case .calendar:
            return [V2Artifact(title: "Calendar", symbol: "calendar")]
        case .draft:
            return [V2Artifact(title: "the draft in Mail", symbol: "envelope")]
        }
    }
}

extension AgentWork {
    /// #16, decided: the kind of step, never its object (the dev team's proposal).
    var kindLine: String {
        switch self {
        case .reading: return "Reading files"
        case .editing: return "Editing files"
        case .running: return "Running a command"
        case .browsing: return "Searching the web"
        case .thinking: return "Thinking"
        case .asking: return "Waiting for you"
        case .done: return "Done"
        case .failed: return "Failed"
        }
    }

    /// The step's glyph: a pencil for edits, a prompt for commands, a magnifier for searches.
    var symbol: String {
        switch self {
        case .reading: return "eye"
        case .editing: return "pencil"
        case .running: return "terminal"
        case .browsing: return "magnifyingglass"
        case .thinking: return "sparkle"
        case .asking: return "hand.raised"
        case .done: return "checkmark"
        case .failed: return "xmark"
        }
    }

    /// A finished step, in the past tense, with its object.
    func past(_ object: String?) -> String {
        let thing = object ?? ""
        switch self {
        case .reading: return object == nil ? "Read the request" : "Read \(thing)"
        case .editing: return "Edited \(thing)"
        case .running: return "Ran \(thing)"
        case .browsing: return "Searched \(thing)"
        case .thinking: return "Thought it through"
        case .asking: return "Asked you"
        case .done: return "Done"
        case .failed: return "Failed"
        }
    }
}

extension WorkbenchModel {
    // MARK: Model and effort (#1, #19, #23)

    /// The chosen model and effort as the pill says it: "Auto", or "Sonnet 5 · High".
    func v2ModelLabel(agent: String) -> String {
        let options = ModelCatalog.options(agent: agent == ChatAgent.fovea.id ? "claude-code" : agent)
        guard let id = v2Model, let model = options.first(where: { $0.id == id }) else {
            return v2Effort.map { "Auto · \(ModelCatalog.effortName($0))" } ?? "Auto"
        }
        if let effort = v2Effort ?? model.defaultEffort, model.efforts.contains(effort) {
            return "\(model.name) · \(ModelCatalog.effortName(effort))"
        }
        return model.name
    }

    /// The models the chosen chat's agent offers.
    var v2ModelOptions: [AgentModelOption] {
        ModelCatalog.options(agent: v2Pick.agent == ChatAgent.fovea.id ? "claude-code" : v2Pick.agent)
    }

    /// The efforts the chosen model takes (any of the agent's, on Auto).
    var v2EffortOptions: [String] {
        if let id = v2Model, let model = v2ModelOptions.first(where: { $0.id == id }) { return model.efforts }
        var seen: [String] = []
        for option in v2ModelOptions { for e in option.efforts where !seen.contains(e) { seen.append(e) } }
        return seen
    }

    func chooseModel(_ id: String?) {
        v2Model = id
        if let effort = v2Effort, !v2EffortOptions.contains(effort) { v2Effort = nil }
    }

    func chooseEffort(_ effort: String?) {
        v2Effort = effort
    }

    func toggleModelSheet() {
        withAnimation(WorkbenchTokens.V2.resize) {
            if notchState == .v2Voice {
                v2RouteOpen.toggle()
                if v2RouteOpen {
                    // Every chat, from the chosen one's agent, as Dispatch's rail opens.
                    v2BrowseAgent = v2Pick.quick ? ChatBook.predictedAgent : v2Pick.agent
                    v2BrowseProject = nil
                }
            } else {
                v2ModelSheet.toggle()
            }
        }
    }

    // MARK: What a session reports (#9–13)

    /// A beat's plan, files and answer, from the sample request's tables.
    func decorateV2(_ id: String, beat: Int, followUp: Bool? = nil) {
        guard let i = agentTasks.firstIndex(where: { $0.id == id }) else { return }
        let request = v2Requests[id] ?? v2Request
        let more = followUp ?? v2FollowUps.contains(id)
        if followUp == true { v2FollowUps.insert(id) }
        agentTasks[i].plan = more ? [] : request.plan
        agentTasks[i].planDone = request.planDone(beat: beat, followUp: more)
        agentTasks[i].changes = request.changes(beat: beat, followUp: more)
        if agentTasks[i].state == .complete { agentTasks[i].answer = request.answer(followUp: more) }
    }

    /// What the agent did for the exchange now, for the fold under its answer: a request's own;
    /// a sample session on the board, its steps.
    func v2Work(_ task: AgentTaskItem) -> V2Work {
        if v2Requests[task.id] == nil, let steps = AgentBoard.liveSteps[task.id] {
            return V2Work(seconds: 40 + 15 * steps.count, entries: steps.map { .step($0) })
        }
        let request = v2Requests[task.id] ?? v2Request
        return request.work(followUp: v2FollowUps.contains(task.id))
    }

    /// What it made, to open.
    func v2Artifacts(_ task: AgentTaskItem) -> [V2Artifact] {
        let request = v2Requests[task.id] ?? v2Request
        return request.artifacts(followUp: v2FollowUps.contains(task.id), changes: task.changes)
    }

    /// Open: the file in the editor, the paper, the calendar; here the island rests, as it would
    /// once the app comes forward.
    func openArtifact(_ artifact: V2Artifact) {
        if notchState == .v2Chat { closeV2Chat() }
    }

    // MARK: Titles (#15)

    /// A new chat (or a quick answer) is named from its request a moment after it goes, by a
    /// small model; until then it shows the request's first words. A chosen chat keeps its name.
    func nameV2(_ id: String, pick: V2Suggestion) {
        guard pick.chat == nil else { return }
        let request = v2Requests[id] ?? v2Request
        if snapshotMode {
            v2Titles[id] = request.generatedTitle
            return
        }
        v2Naming.insert(id)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(WorkbenchTokens.FeedbackV2.titleDelay))
            guard let self else { return }
            withAnimation(WorkbenchTokens.FeedbackV2.titleSwap) {
                self.v2Titles[id] = request.generatedTitle
                _ = self.v2Naming.remove(id)
            }
        }
    }

    /// A session's title: its chat's name, the name made for it, or (being named) its request.
    func v2Title(_ task: AgentTaskItem) -> String {
        if let title = v2Titles[task.id] { return title }
        if task.session != "New chat", task.project != DispatchV2.quickProject { return task.session }
        return task.request
    }

    // MARK: The activity line (#16)

    /// What a working session is doing, in one line: the kind of step (decided), or with its
    /// object (the research found both agents report it; the panel shows the difference).
    func v2Line(_ task: AgentTaskItem) -> String {
        if task.state == .needsYou || task.stalled || activityWithObject { return task.line }
        return task.work.kindLine
    }

    // MARK: The queue (#24)

    func enqueueV2(_ id: String, text: String, images: [NSImage] = []) {
        withAnimation(WorkbenchTokens.V2.resize) {
            v2Queue[id, default: []].append(V2QueuedAsk(text: text, images: images))
        }
    }

    /// Send now: the session takes it in at once, mid-turn (steering), out of the line.
    func sendQueuedNow(_ id: String, _ ask: V2QueuedAsk) {
        withAnimation(WorkbenchTokens.V2.resize) { v2Queue[id]?.removeAll { $0 == ask } }
        v2QueuePaused.remove(id)
        askMoreV2(id, text: ask.text, inWindow: v2Detached.contains { $0.id == id } || notchState == .v2Chat, now: true)
    }

    func cancelQueued(_ id: String, _ ask: V2QueuedAsk) {
        withAnimation(WorkbenchTokens.V2.resize) { v2Queue[id]?.removeAll { $0 == ask } }
    }

    func resumeQueue(_ id: String) {
        withAnimation(WorkbenchTokens.V2.resize) { _ = v2QueuePaused.remove(id) }
        if v2Task(id)?.state == .complete { _ = takeNextQueued(id) }
    }

    /// Done: the next waiting message goes, unless the queue holds. Returns whether one went.
    func takeNextQueued(_ id: String) -> Bool {
        guard !v2QueuePaused.contains(id), let next = v2Queue[id]?.first else { return false }
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self else { return }
            withAnimation(WorkbenchTokens.V2.resize) { self.v2Queue[id]?.removeFirst() }
            self.askMoreV2(id, text: next.text, inWindow: true, now: true)
        }
        return true
    }

    // MARK: Skipping the review (#19)

    /// The words went without a look: to the chat, model and effort the bar shows; the board
    /// shows it on its way.
    func sendWithoutReview() {
        let pick = v2Pick
        let index = v2Request.suggestions.firstIndex(of: pick)
        v2RouteOpen = false
        send(pick, label: index == 0 ? .keptFirst : (index.map { .picked($0 + 1) } ?? .browsed))
    }

    // MARK: Answer again and stop (#23)

    /// Answer again, with the model chosen: the same question, run again; the earlier answer is
    /// kept as an exchange before it.
    func reanswerV2(_ id: String, model: String? = nil, effort: String? = nil) {
        guard let i = agentTasks.firstIndex(where: { $0.id == id }), agentTasks[i].state != .working else { return }
        if let model { v2Model = model }
        if let effort { v2Effort = effort }
        let request = v2Requests[id] ?? v2Request
        let more = v2FollowUps.contains(id)
        let script = more ? request.followUp.script : request.script
        let past = v2History[id] ?? []
        v2History[id] = past + [V2Turn(id: past.count, question: v2Followed[id] ?? agentTasks[i].request,
                                       result: agentTasks[i].result, answer: agentTasks[i].answer,
                                       work: v2Work(agentTasks[i]))]
        v2Scripts[id] = script
        withAnimation(WorkbenchTokens.Panel.change) {
            agentTasks[i].state = .working
            agentTasks[i].stopped = false
            agentTasks[i].steps = []
            agentTasks[i].answer = nil
            agentTasks[i].modelLabel = v2ModelLabel(agent: agentTasks[i].agent)
            apply(script[0], to: i)
            decorateV2(id, beat: 0)
        }
        v2FinishedAt[id] = nil
        v2Started[id] = Date()
        run(id, from: 0, script: script, pace: request.pace)
    }

    // MARK: Staging the tabs

    /// #1: Choose chat with four things taken (two screenshots, a passage, a file) and the model.
    func stageModelEffort() {
        restingFlow = .dispatchV2
        v2Request = .code
        v2Model = nil
        v2Effort = nil
        screenContent = .fullScreenApp
        startV2Voice()
        stageV2Referents()
        if let card = AttachmentCards.text(ArticlePage.pass[0]) {
            referents.append(CapturedReferent(id: UUID(), image: card, aspect: card.size.width / max(1, card.size.height),
                                              source: SafariTab.all[0].title, kind: .text(ArticlePage.pass[0])))
        }
        let file = DesktopFile.all[1]
        if let card = AttachmentCards.file(file) {
            referents.append(CapturedReferent(id: UUID(), image: card, aspect: card.size.width / max(1, card.size.height),
                                              source: "Desktop", kind: .file(name: file.name, size: file.size)))
        }
        showV2Send()
        v2ModelSheet = feedbackModelStage == .open
    }

    /// A session of the chosen request at work or done, opened in the notch.
    private func stageV2Session(_ stage: WorkStage, pick: V2Suggestion? = nil) -> String {
        restingFlow = .dispatchV2
        v2Pinned = true
        let suggestion = pick ?? v2Request.suggestions[0]
        if stage == .done {
            let id = makeV2Session(suggestion, at: v2Request.script.count - 1)
            v2FinishedAt[id] = Date()
            return id
        }
        let start = min(2, v2Request.script.count - 2)
        let id = makeV2Session(suggestion, at: start)
        run(id, from: start)
        return id
    }

    /// #9–10, #17: the board, every session on the Mac: one of the person's own at work among them.
    func stageProgress() {
        restingFlow = .dispatchV2
        v2Request = .code
        v2Focus = workingV2Session()
        showAgentPanel(pinned: true)
    }

    /// #11–13: the expanded chat, done (or at work).
    func stageAnswer() {
        let id = stageV2Session(feedbackWorkStage)
        showV2Chat(id, popped: false)
    }

    /// #16, Oct 7: a code change at work, its steps one at a time; in its session, or on the board.
    /// It stays at work (no script runs it to the end), so the steps keep coming.
    func stageSteps() {
        restingFlow = .dispatchV2
        v2Request = .code
        v2Pinned = true
        let id = makeV2Session(v2Request.suggestions[0], at: 1)
        if feedbackStepsStage == .session {
            showV2Chat(id, popped: false)
        } else {
            v2Focus = id
            showAgentPanel(pinned: true)
        }
    }

    /// #15: a request sent to a new chat; its name arrives a moment later.
    func stageTitles() {
        restingFlow = .dispatchV2
        v2Pinned = false
        let pick = v2Request.suggestions.first { $0.chat == nil } ?? v2Request.suggestions[0]
        let id = makeV2Session(pick, at: 0)
        run(id, from: 0)
        showBoardAfterSend(id)
    }

    /// #19: the voice bar with the chat, model and effort a click away, the review off.
    func stageSkipReview() {
        restingFlow = .dispatchV2
        v2ReviewBeforeSend = false
        v2RouteOpen = feedbackRouteOpen
        v2PickStorage = nil
        startV2Voice()
        stageV2Referents()
    }

    /// #23: the expanded chat, at work (Stop) or done (Answer again).
    func stageReanswer() {
        let id = stageV2Session(feedbackWorkStage)
        showV2Chat(id, popped: false)
    }

    /// #24: a session at work with two messages waiting (one with a screenshot); or waiting on
    /// the person, its queue held.
    func stageQueue() {
        let id = stageV2Session(.working)
        v2Queue[id] = [V2QueuedAsk(text: "Check it on an external display too."),
                       V2QueuedAsk(text: "And use this spacing for the voice bar.",
                                   images: v2Referents(of: nil).suffix(1).map { $0 })]
        if feedbackQueueStage == .paused, let i = agentTasks.firstIndex(where: { $0.id == id }) {
            v2Runs[id]?.cancel()
            agentTasks[i].state = .needsYou
            agentTasks[i].work = .asking
            agentTasks[i].activity = "Run swift test --filter NotchGeometry?"
            agentTasks[i].ask = .approval("swift test --filter NotchGeometry")
            v2QueuePaused.insert(id)
        }
        showV2Chat(id, popped: false)
    }
}

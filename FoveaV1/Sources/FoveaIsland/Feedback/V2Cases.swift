import SwiftUI
import AppKit
import FoveaCore
import FoveaKit
import FoveaPlatform

// The dev team's review of Oct 15 (docs/v1/REVIEW_2026-10-15.md), Dispatch's sessions: the cases
// the design missed, as Ryan decided them. The flow is here; the views are in V2CaseViews.swift;
// the Review menu's stages in V2CaseStages.swift. The agents are simulated in 1.0, so each state is
// built believably and can be staged; the ones a person meets by using the app are noted.
//
// - Closing never stops (QA21, QA23, DSP-24): ✕ on a chat at work puts it back on the board.
// - Every chat (QA04, QA05): search, no results, Load More, a list that couldn't load; a chat
//   that can't take the request says why.
// - Sending (QA06, QA10): "Sending to …" with the chat locked; Not sent; Declined by the agent.
// - Edit (QA07): the last request edited in place and sent again, replacing its answer.
// - The model sheet (QA08, QA09): models that couldn't load or aren't offered; approvals.
// - Needs you (QA14, QA15): what an approval would do and for how long; a question's own answer;
//   a few questions at once; a line saying what was decided.
// - The queue (QA11, QA12): a message that couldn't send; Open in the agent from a held queue.
// - The connection (QA16, QA24): reconnecting, lost, timed out; a request that may not have arrived.
// - Reopening from Home (QA25), Open in the session's agent (QA26; Oct 17, in place of Continue
//   in another agent), what an answer made (QA20),
//   Copy Answer (DSP-18), and "Remembered" (NH-03).

// MARK: - Tokens

extension WorkbenchTokens {
    /// The Oct 15 review's Dispatch states: their sizes, faces and timing.
    enum Cases {
        // Sending (QA06, QA10): how long "Sending to …" holds before the agent takes the request.
        static let sendingTime: Double = 0.45
        // Every chat (QA04, QA05): rows before Show More, the list loading again, the search field.
        // Oct 27: four, so a folder's New chat, four chats and Show More fill the browser's six rows.
        static let browsePage = 4
        static let loadTime: Double = 0.8
        static var searchWidth: CGFloat { size(150) }
        static var searchHeight: CGFloat { size(20) }
        static var searchFont: Font { Font.system(size: typeSize(11.5)) }
        static var searchGlyph: Font { Font.system(size: typeSize(9.5), weight: .semibold) }
        static var searchFill: Color { ink(0.07) }
        static var searchPaddingH: CGFloat { size(7) }
        static var blockedTitle: Color { ink(0.42) }
        static var blockedGlyph: Font { Font.system(size: typeSize(9), weight: .semibold) }
        // A status line in place of a row of chips (Sending, Not sent, a list that couldn't load).
        static var statusFont: Font { Font.system(size: typeSize(12), weight: .medium) }
        static var statusGlyph: Font { Font.system(size: typeSize(10.5), weight: .semibold) }
        static var statusGap: CGFloat { size(6) }
        // Needs you (QA14, QA15).
        static var needsGap: CGFloat { size(6) }
        static var detailRow: CGFloat { size(18) }
        static var fileRow: CGFloat { size(17) }
        static var choiceRow: CGFloat { size(24) }
        static var answerField: CGFloat { size(26) }
        static var formRow: CGFloat { size(26) }
        static var formLabelWidth: CGFloat { size(118) }
        static var labelWidth: CGFloat { size(78) }
        static var detailFont: Font { Font.system(size: typeSize(11.5)) }
        static var codeFont: Font { Font.system(size: typeSize(11), design: .monospaced) }
        static var fieldFill: Color { ink(0.07) }
        static var fieldBorder: Color { ink(0.12) }
        static let decisionHold: Double = 3.5
        // The connection (QA16, QA24).
        static let reconnectTime: Double = 1.2
        static var pillHeight: CGFloat { size(20) }
        static var pillFont: Font { Font.system(size: typeSize(11), weight: .medium) }
        static var pillFill: Color { ink(0.08) }
        static var pillPaddingH: CGFloat { size(8) }
        static var attemptRow: CGFloat { size(16) }
        static var attemptFont: Font { Font.system(size: typeSize(11)) }
        static var attemptColor: Color { ink(0.4) }
        // Reopening from Home (QA25).
        static let reopenTime: Double = 0.7
        // A line in a session's bar a moment (QA20, QA26, DSP-18).
        static let barLineHold: Double = 4
        static let copiedHold: Double = 1.6
        // Remembered (NH-03): a row on the board, a while.
        static var memoryRow: CGFloat { size(34) }
        static let memoryHold: Double = 12
        static let memoryDelay: Double = 1.2
        static var memoryGlyph: Font { Font.system(size: typeSize(11), weight: .semibold) }
        /// A state changing in place: a line, a row of chips, a pill.
        static var change: Animation { WorkbenchTokens.Spring.fadeIn(0.18) }
    }
}

// MARK: - What each case holds

/// A list or catalog that loads from the agent: loaded, on its way, or it couldn't.
enum V2Load: Equatable { case loaded, loading, failed }

/// Choose chat after Send (QA06, QA10): on its way, the chat locked; not sent; or declined by the
/// agent, with its reason.
enum V2Sending: Equatable {
    case sending(V2Suggestion)
    case notSent(V2Suggestion)
    case declined(V2Suggestion, String)

    var pick: V2Suggestion {
        switch self { case .sending(let p), .notSent(let p), .declined(let p, _): return p }
    }
    var isSending: Bool { if case .sending = self { return true }; return false }
}

/// What the next send meets: the agent takes it (always, unless a stage says otherwise).
enum V2SendOutcome: Equatable { case accepted, notSent, declined(String) }

/// How far a session may go without asking (QA09), as the agents' own permission modes have it.
enum V2ApprovalMode: String, CaseIterable, Identifiable {
    case askFirst, allowEdits, allowAll
    var id: String { rawValue }
    var title: String {
        switch self {
        case .askFirst: return L("Ask Before Changes")
        case .allowEdits: return L("Allow Edits")
        case .allowAll: return L("Allow Everything")
        }
    }
    var help: String {
        switch self {
        case .askFirst: return L("It asks before it edits a file or runs a command.")
        case .allowEdits: return L("It edits files without asking, and asks before it runs a command.")
        case .allowAll: return L("It edits and runs commands without asking.")
        }
    }
}

/// How long an Allow holds (QA14).
enum V2ApprovalScope: String, CaseIterable, Identifiable {
    case once, session
    var id: String { rawValue }
    var title: String { self == .once ? L("Just This Once") : L("For This Session") }
}

/// One of a few questions an agent asks at once (QA15): its choices, or a field to type in.
struct V2FormField: Identifiable, Equatable {
    let id: String
    let label: String
    var choices: [String] = []
}

/// The agent's connection, when it isn't fine (QA16).
enum V2Connection: Equatable {
    case reconnecting, lost, timedOut
}

/// A line in a session's bar a moment: Opened in Claude Code, a copy that couldn't be saved.
struct V2BarLine: Equatable {
    let text: String
    var failed = false
    var symbol = "checkmark"
}

/// Remembered (NH-03): what a request taught Fovea's memory, to open in Settings › Memory.
struct V2MemoryNotice: Equatable {
    let id: String
    let title: String
}

/// The review's cases, kept beside the model (one property on it, so the shared model barely
/// changes). Observable: the views follow it.
@Observable
final class V2CaseState {
    // QA04, QA05: every chat.
    var browseQuery = ""
    var browseLoad: V2Load = .loaded
    var browseShown = WorkbenchTokens.Cases.browsePage
    /// An agent that can't take requests now: each of its chats says so.
    var downAgent: String?
    // QA06, QA10: sending.
    var sending: V2Sending?
    var nextSend: V2SendOutcome = .accepted
    // QA07: the request being edited, and its words.
    var editing: String?
    var editText = ""
    // QA08, QA09: the model sheet.
    var modelsLoad: V2Load = .loaded
    var approvalMode: V2ApprovalMode = .askFirst
    /// Why the approvals can't be changed here (set by the agent's own settings), if they can't.
    var approvalLocked: String?
    /// Models unavailable besides the catalog's own (a stage), by id, with why.
    var unavailableModels: [String: String] = [:]
    /// Each session's approvals, as chosen when it was sent.
    var sessionModes: [String: V2ApprovalMode] = [:]
    // QA14, QA15: needs you.
    var scopes: [String: V2ApprovalScope] = [:]
    var allowedForSession: Set<String> = []
    var approvalFiles: [String: [FileChange]] = [:]
    var decisions: [String: String] = [:]
    var forms: [String: [V2FormField]] = [:]
    var formAnswers: [String: [String: String]] = [:]
    var ownAnswer: [String: String] = [:]
    // QA16, QA24: the connection; a request that may not have arrived, and when it was tried.
    var connection: [String: V2Connection] = [:]
    var unconfirmed: [String: [Date]] = [:]
    // QA25: reopened from Home.
    var reopening: Set<String> = []
    var gone: Set<String> = []
    var readOnly: Set<String> = []
    /// A session reopened from a capture, by the capture's id.
    var reopened: [String: String] = [:]
    // QA20, QA26, DSP-18: a line in a session's bar; the answer just copied.
    var barLines: [String: V2BarLine] = [:]
    var copied: String?
    // NH-03: Remembered.
    var memoryNotice: V2MemoryNotice?
    /// Settings' "Tell me when a memory updates" (the lead wires it from the prefs).
    @ObservationIgnored var memoryNotices = false
    @ObservationIgnored var onOpenMemory: ((String) -> Void)?
    /// Folders where an answer's files may be (the first run's practice folder), besides each
    /// project's own.
    @ObservationIgnored var fileRoots: [URL] = []
    @ObservationIgnored var tasks: [String: Task<Void, Never>] = [:]

    /// Everything back as a fresh run has it (a staged state starts from here). The person's
    /// setting and the hooks stay.
    func reset() {
        tasks.values.forEach { $0.cancel() }
        tasks = [:]
        browseQuery = ""
        browseLoad = .loaded
        browseShown = WorkbenchTokens.Cases.browsePage
        downAgent = nil
        sending = nil
        nextSend = .accepted
        editing = nil
        editText = ""
        modelsLoad = .loaded
        approvalMode = .askFirst
        approvalLocked = nil
        unavailableModels = [:]
        sessionModes = [:]
        scopes = [:]
        allowedForSession = []
        approvalFiles = [:]
        decisions = [:]
        forms = [:]
        formAnswers = [:]
        ownAnswer = [:]
        connection = [:]
        unconfirmed = [:]
        reopening = []
        gone = []
        readOnly = []
        reopened = [:]
        barLines = [:]
        copied = nil
        memoryNotice = nil
    }
}

// MARK: - Chats that can't take a request (QA05)

/// Why a chat can't take a request, in the review's words, and the longer why for its help.
enum ChatBlock {
    static let inUse = "In use by another request"
    static let readOnly = "Read only"
    static let cantWrite = "Can't write here"
    static let agentUnavailable = "Agent unavailable"

    static func help(_ reason: String, chat: AgentChat) -> String {
        let agent = ChatAgent.named(chat.agent).name
        switch reason {
        case inUse: return L("Another request is going to this chat now. Pick another, or try again once it's in.")
        case readOnly: return L("This chat can be read in \(agent), not added to.")
        case cantWrite: return L("Fovea can't write to \(ChatBook.paths[chat.folder] ?? chat.folder): the folder is gone or locked.")
        case agentUnavailable: return L("\(agent) isn't answering on this Mac right now.")
        default: return reason
        }
    }
}

extension WorkbenchModel {
    /// A task in the review's cases, after a while, on the main actor; one per key.
    func caseTask(_ key: String, after seconds: Double, _ body: @escaping @MainActor (WorkbenchModel) -> Void) {
        cases.tasks[key]?.cancel()
        cases.tasks[key] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, !Task.isCancelled else { return }
            body(self)
        }
    }

    // MARK: Every chat (QA04, QA05)

    /// Why a chat can't take the request now, or nil: its own state, or its agent down.
    func v2ChatBlock(_ chat: AgentChat) -> String? {
        if chat.isNew { return cases.downAgent == chat.agent ? ChatBlock.agentUnavailable : nil }
        if cases.downAgent == chat.agent { return ChatBlock.agentUnavailable }
        switch chat.state {
        case .unavailable(let why): return why
        case .elsewhere(let app): return L("Open in \(app)")
        default: return nil
        }
    }

    /// The search: chats of the agent in view, by title or project, most recent first.
    func v2SearchRows(_ query: String) -> [V2BrowseRow] {
        let found = ChatBook.chats
            .filter { $0.agent == v2BrowseAgent }
            .filter { $0.title.localizedCaseInsensitiveContains(query) }
            .sorted { $0.minutesAgo < $1.minutesAgo }
        guard !found.isEmpty else { return [.status(.noMatch(query))] }
        return v2Paged(found.map { .chat($0) })
    }

    /// A long list shows its first page, then Load More.
    func v2Paged(_ rows: [V2BrowseRow]) -> [V2BrowseRow] {
        let shown = cases.browseShown
        guard rows.count > shown else { return rows }
        return Array(rows.prefix(shown)) + [.more(rows.count - shown)]
    }

    func setBrowseQuery(_ query: String) {
        cases.browseQuery = query
        cases.browseShown = WorkbenchTokens.Cases.browsePage
    }

    /// Load More: the next page.
    func loadMoreChats() {
        withAnimation(WorkbenchTokens.V2.resize) { cases.browseShown += WorkbenchTokens.Cases.browsePage }
    }

    /// The list couldn't load: Try Again loads it again (simulated, it comes this time).
    func retryBrowseLoad() {
        cases.browseLoad = .loading
        caseTask("browse", after: WorkbenchTokens.Cases.loadTime) { model in
            withAnimation(WorkbenchTokens.V2.resize) { model.cases.browseLoad = .loaded }
        }
    }

    // MARK: Sending (QA06, QA10)

    /// Sent: "Sending to …" a moment, the chat locked; then the agent takes it (the board), or it
    /// isn't sent, or the agent declines it. Nothing is logged or made until it's taken.
    func beginSendV2(_ pick: V2Suggestion, label: V2RoutingLabel) {
        withAnimation(WorkbenchTokens.V2.resize) {
            v2Browsing = false
            v2ModelSheet = false
        }
        withAnimation(WorkbenchTokens.Cases.change) { cases.sending = .sending(pick) }
        caseTask("send", after: WorkbenchTokens.Cases.sendingTime) { model in
            guard model.notchState == .v2Send, model.cases.sending == .sending(pick) else { return }
            let outcome = model.cases.nextSend
            model.cases.nextSend = .accepted
            withAnimation(WorkbenchTokens.Cases.change) {
                switch outcome {
                case .accepted: model.cases.sending = nil
                case .notSent: model.cases.sending = .notSent(pick)
                case .declined(let why): model.cases.sending = .declined(pick, why)
                }
            }
            if outcome == .accepted { model.send(pick, label: label) }
        }
    }

    /// Not sent: Try Again, to the same chat.
    func retrySendV2() {
        guard notchState == .v2Send, let sending = cases.sending, !sending.isSending else { return }
        let pick = sending.pick
        cases.sending = nil
        v2PickStorage = pick
        sendV2Now()
    }

    /// Not sent or declined: every chat opens to pick another.
    func chooseAnotherChatV2() {
        guard notchState == .v2Send else { return }
        withAnimation(WorkbenchTokens.Cases.change) { cases.sending = nil }
        if !v2Browsing { toggleV2Browse() }
    }

    // MARK: Edit (QA07)

    /// The last request can be edited once it has an answer (or failed, or was stopped): the
    /// person's own sessions, not one reopened read only.
    func canEditV2(_ task: AgentTaskItem) -> Bool {
        (task.state == .complete || task.state == .failed) && v2Sessions.contains(task.id)
            && !directorSessions.contains(task.id) && !cases.readOnly.contains(task.id) && !cases.gone.contains(task.id)
    }

    func startEditV2(_ id: String) {
        guard let task = v2Task(id), canEditV2(task) else { return }
        v2ChatInteracted = true
        v2ChatHold?.cancel()
        withAnimation(WorkbenchTokens.Cases.change) {
            cases.editText = v2Followed[id] ?? task.request
            cases.editing = id
        }
    }

    func cancelEditV2() {
        withAnimation(WorkbenchTokens.Cases.change) { cases.editing = nil }
    }

    /// Sent again, edited: it replaces the last request and its answer; the answers before it keep
    /// their place in the history.
    func sendEditV2(_ id: String) {
        let words = cases.editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty, let i = agentTasks.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(WorkbenchTokens.Cases.change) { cases.editing = nil }
        let request = v2Requests[id] ?? v2Request
        let script = v2FollowUps.contains(id) ? request.followUp.script : request.script
        // Oct 23, Ryan: what Fovea heard, put right by the person, teaches the dictionary the words
        // corrected (Learned, with what was heard as "Also heard as").
        let heard = v2Followed[id] ?? agentTasks[i].request
        live?.dictionary.learn(heard: heard, corrected: words, in: L("the notch"))
        v2Followed[id] = words
        v2Scripts[id] = script
        v2Runs[id]?.cancel()
        withAnimation(WorkbenchTokens.Panel.change) {
            agentTasks[i].state = .working
            agentTasks[i].stopped = false
            agentTasks[i].steps = []
            agentTasks[i].answer = nil
            agentTasks[i].inState = 0
            agentTasks[i].age = 0
            apply(script[0], to: i)
            decorateV2(id, beat: 0)
        }
        v2FinishedAt[id] = nil
        v2Started[id] = Date()
        run(id, from: 0, script: script, pace: request.pace)
    }

    // MARK: The model sheet (QA08, QA09)

    /// A model the chat's agent lists but can't be picked: the catalog's reason, or a stage's.
    func v2ModelUnavailable(_ option: AgentModelOption) -> String? {
        // Oct 18, Ryan: why, in the primary language.
        (cases.unavailableModels[option.id] ?? option.unavailable).map { L(key: $0) }
    }

    /// The model chosen for another chat, which this chat's agent doesn't offer: Auto stands in.
    var v2CarriedModel: (name: String, reason: String)? {
        guard let id = v2Model, !v2ModelOptions.contains(where: { $0.id == id }) else { return nil }
        // Oct 18, Ryan: only Codex and Claude Code.
        let agents = ["claude-code", "codex"]
        guard let name = agents.lazy.compactMap({ ModelCatalog.options(agent: $0).first { $0.id == id }?.name }).first else { return nil }
        return (name, L("\(ChatAgent.named(v2Pick.quick ? "claude-code" : v2Pick.agent).name) doesn't offer this model"))
    }

    /// The models couldn't load: Try Again (simulated, they come this time).
    func retryModelsLoad() {
        cases.modelsLoad = .loading
        caseTask("models", after: WorkbenchTokens.Cases.loadTime) { model in
            withAnimation(WorkbenchTokens.Cases.change) { model.cases.modelsLoad = .loaded }
        }
    }

    func chooseApprovalMode(_ mode: V2ApprovalMode) {
        guard cases.approvalLocked == nil else { return }
        cases.approvalMode = mode
    }

    // MARK: Needs you (QA14, QA15)

    /// What an approval would do: the command it runs, the files it would change.
    func v2ApprovalDetail(_ task: AgentTaskItem) -> (command: String?, files: [FileChange]) {
        var command: String?
        if case .approval(let what)? = task.ask { command = what }
        let files = cases.approvalFiles[task.id] ?? []
        // An edit to approve names its files, not a command.
        if !files.isEmpty, command?.hasPrefix("Edit") == true { command = nil }
        return (command, files)
    }

    func v2Scope(_ id: String) -> V2ApprovalScope { cases.scopes[id] ?? .once }

    func setV2Scope(_ id: String, _ scope: V2ApprovalScope) {
        cases.scopes[id] = scope
    }

    /// What was decided, a moment, where the session's line is: "Allowed · running swift test".
    func decideV2(_ id: String, _ line: String) {
        withAnimation(WorkbenchTokens.Cases.change) { cases.decisions[id] = line }
        caseTask("decision-\(id)", after: WorkbenchTokens.Cases.decisionHold) { model in
            withAnimation(WorkbenchTokens.Cases.change) { _ = model.cases.decisions.removeValue(forKey: id) }
        }
    }

    /// The decision's line after Allow: what it goes on to do.
    func allowedLine(_ id: String, scope: V2ApprovalScope) -> String {
        let next = v2PausedBeat[id].flatMap { beat in v2Scripts[id].flatMap { $0.indices.contains(beat + 1) ? $0[beat + 1] : nil } }
        let doing = next.map { $0.activity.prefix(1).lowercased() + $0.activity.dropFirst() } ?? L("going on")
        return scope == .session ? L("Allowed for this session · \(doing)") : L("Allowed · \(doing)")
    }

    /// An approval allowed for the session, or approvals off for it: the agent doesn't stop to ask.
    func v2AllowsWithoutAsking(_ id: String, ask: AgentAsk?) -> Bool {
        guard case .approval? = ask else { return false }
        return cases.allowedForSession.contains(id) || cases.sessionModes[id] == .allowAll
    }

    /// A question answered in the person's own words, or a few answered at once: it goes on.
    func answerOwnV2(_ id: String) {
        let words = (cases.ownAnswer[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return }
        cases.ownAnswer[id] = nil
        answerTask(id, words)
    }

    func answerFormV2(_ id: String) {
        guard let fields = cases.forms[id] else { return }
        let answers = cases.formAnswers[id] ?? [:]
        guard fields.allSatisfy({ !(answers[$0.id] ?? "").isEmpty }) else { return }
        cases.forms[id] = nil
        answerTask(id, fields.map { answers[$0.id] ?? "" }.joined(separator: ", "))
    }

    /// Every question in the form answered.
    func v2FormComplete(_ id: String) -> Bool {
        guard let fields = cases.forms[id] else { return false }
        let answers = cases.formAnswers[id] ?? [:]
        return fields.allSatisfy { !(answers[$0.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
    }

    // MARK: The queue (QA11, QA12)

    /// A message that couldn't send: Try Again puts it back in line (it goes once the session is free).
    func retryQueued(_ id: String, _ ask: V2QueuedAsk) {
        guard let i = v2Queue[id]?.firstIndex(of: ask) else { return }
        withAnimation(WorkbenchTokens.V2.resize) { v2Queue[id]?[i].failed = false }
        if v2Task(id)?.state == .complete { _ = takeNextQueued(id) }
    }

    /// Whether a session has an agent to open it in: not a quick answer (Fovea's own), not a chat
    /// that's gone.
    func v2OpensInAgent(_ task: AgentTaskItem) -> Bool {
        task.agent != ChatAgent.fovea.id && !cases.gone.contains(task.id)
    }

    /// Open in <agent> (Oct 17, Ryan: "don't have Continue, have Open in agent"; QA12, QA26): the
    /// session in its own agent, one way wherever it shows. Its bar says it opened there a moment
    /// (the notch, a pulled-out chat); from the board, where there's no bar, the board goes, as the
    /// agent's app comes forward. There the person manages it (and its queue). Oct 23, Ryan: it
    /// opens for real (`AgentLauncher`: Claude Code in Terminal, Codex in its app), in the app
    /// itself only, never in a smoke run or a picture; what stops it is said on the bar.
    func openInAgentV2(_ id: String) {
        guard let task = v2Task(id), v2OpensInAgent(task) else { return }
        v2ChatInteracted = true
        v2ChatHold?.cancel()
        cases.editing = nil
        let agent = ChatAgent.named(task.agent)
        var line = V2BarLine(text: L("Opened in \(agent.name)"), symbol: "arrow.up.forward")
        if let live, live.smoke == nil, !snapshotMode {
            if case .failure(let failure) = AgentLauncher.open(agent.id == ChatAgent.codex.id ? .codex : .claude) {
                line = V2BarLine(text: failure.sentence, failed: true, symbol: "exclamationmark.triangle")
            }
        }
        let shown = (notchState == .v2Chat && v2Focus == id) || v2Detached.contains { $0.id == id && $0.docked == nil }
        if shown {
            showBarLine(id, line)
        } else if panelOpen {
            closeAgentPanel()
        }
    }

    // MARK: The connection (QA16, QA24)

    /// Lost or timed out: Try Again reconnects (simulated: it does).
    func retryConnectionV2(_ id: String) {
        withAnimation(WorkbenchTokens.Cases.change) { cases.connection[id] = .reconnecting }
        caseTask("connection-\(id)", after: WorkbenchTokens.Cases.reconnectTime) { model in
            withAnimation(WorkbenchTokens.Cases.change) { _ = model.cases.connection.removeValue(forKey: id) }
        }
    }

    /// Not sure it arrived: Send Again sends it once more (this time it's taken).
    func sendAgainV2(_ id: String) {
        guard cases.unconfirmed[id] != nil, let i = agentTasks.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(WorkbenchTokens.Cases.change) { _ = cases.unconfirmed.removeValue(forKey: id) }
        let request = v2Requests[id] ?? v2Request
        let script = v2Scripts[id] ?? request.script
        v2Runs[id]?.cancel()
        withAnimation(WorkbenchTokens.Panel.change) {
            agentTasks[i].state = .working
            agentTasks[i].steps = []
            apply(script[0], to: i)
            decorateV2(id, beat: 0)
        }
        v2Started[id] = Date()
        decideV2(id, L("Sent again · \(ChatAgent.named(agentTasks[i].agent).name) has it"))
        run(id, from: 0, script: script, pace: request.pace)
    }

    /// Check in the agent: it opens there (Open in, Oct 17); there it is, at work.
    func checkInAgentV2(_ id: String) {
        guard cases.unconfirmed[id] != nil else { return }
        _ = cases.unconfirmed.removeValue(forKey: id)
        let start = max(0, (v2Task(id).flatMap { task in v2Scripts[id]?.firstIndex { $0.activity == task.activity } }) ?? 0)
        run(id, from: start)
        openInAgentV2(id)
    }

    // MARK: The bar's line (QA20, QA26, DSP-18)

    func showBarLine(_ id: String, _ line: V2BarLine) {
        withAnimation(WorkbenchTokens.Cases.change) { cases.barLines[id] = line }
        caseTask("bar-\(id)", after: WorkbenchTokens.Cases.barLineHold) { model in
            withAnimation(WorkbenchTokens.Cases.change) { _ = model.cases.barLines.removeValue(forKey: id) }
        }
    }

    // MARK: What an answer made (QA20)

    /// The file on this Mac, if it's there: as written, in its project's folder, or in a folder
    /// the first run gave.
    func v2ArtifactURL(_ artifact: V2Artifact, task: AgentTaskItem?) -> URL? {
        guard let path = artifact.path else { return nil }
        let fm = FileManager.default
        var candidates: [URL] = []
        let expanded = (path as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") { candidates.append(URL(fileURLWithPath: expanded)) }
        if let task, let folder = ChatBook.paths[task.project] {
            candidates.append(URL(fileURLWithPath: (folder as NSString).expandingTildeInPath).appendingPathComponent(path))
        }
        candidates += cases.fileRoots.map { $0.appendingPathComponent(path) }
        return candidates.first { fm.fileExists(atPath: $0.path) }
    }

    /// Open: the file in its app (where it is), and the island rests, as the app comes forward.
    func openArtifactV2(_ artifact: V2Artifact, taskID: String?) {
        let task = taskID.flatMap { v2Task($0) }
        if let url = v2ArtifactURL(artifact, task: task), !options.smoke, !snapshotMode, live?.smoke == nil {
            NSWorkspace.shared.open(url)
        }
        openArtifact(artifact)
    }

    func showArtifactInFinder(_ artifact: V2Artifact, taskID: String?) {
        let task = taskID.flatMap { v2Task($0) }
        guard let url = v2ArtifactURL(artifact, task: task) else {
            if let taskID { showBarLine(taskID, V2BarLine(text: L("\(artifact.title) isn't on this Mac"), failed: true, symbol: "exclamationmark.triangle")) }
            return
        }
        guard !options.smoke, !snapshotMode, live?.smoke == nil else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Save a Copy…: the save panel, and the file copied where the person says; a line if it
    /// can't be (it isn't on this Mac, or the copy fails).
    func saveArtifactCopy(_ artifact: V2Artifact, taskID: String?) {
        let task = taskID.flatMap { v2Task($0) }
        guard let url = v2ArtifactURL(artifact, task: task) else {
            if let taskID {
                showBarLine(taskID, V2BarLine(text: L("Couldn't save a copy: \(artifact.title) isn't on this Mac"), failed: true,
                                              symbol: "exclamationmark.triangle"))
            }
            return
        }
        guard !options.smoke, !snapshotMode, live?.smoke == nil else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = url.lastPathComponent
        panel.canCreateDirectories = true
        panel.title = L("Save a Copy")
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            MainActor.assumeIsolated {
                guard response == .OK, let target = panel.url, let self else { return }
                do {
                    if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
                    try FileManager.default.copyItem(at: url, to: target)
                    if let taskID { self.showBarLine(taskID, V2BarLine(text: L("Saved a copy to \(target.deletingLastPathComponent().lastPathComponent)"))) }
                } catch {
                    if let taskID {
                        self.showBarLine(taskID, V2BarLine(text: L("Couldn't save a copy: \(error.localizedDescription)"), failed: true,
                                                           symbol: "exclamationmark.triangle"))
                    }
                }
            }
        }
    }

    // MARK: Copy Answer (DSP-18)

    /// What Copy Answer copies: a draft as it is, else the answer as plain text.
    func v2CopyText(_ task: AgentTaskItem) -> String? {
        if let draft = task.result?.draft { return draft }
        if task.answer != nil { return v2AnswerPlain(task) }
        return task.reply ?? task.result?.outcome
    }

    // MARK: Remembered (NH-03)

    /// After a request comes back, with the setting on: what memory took from it (simulated), a
    /// quiet row on the board a while, with Open.
    func noteMemoryV2(_ id: String) {
        guard cases.memoryNotices, v2Sessions.contains(id), !directorSessions.contains(id), let task = v2Task(id),
              task.state == .complete else { return }
        let request = v2Requests[id] ?? v2Request
        postMemoryV2(V2MemoryNotice(id: "memory-\(request.rawValue)", title: request.memoryTitle))
    }

    func postMemoryV2(_ notice: V2MemoryNotice) {
        // A beat after the answer, so a quick answer opens first. At rest, the board says it a
        // moment (it goes as after Send); otherwise it waits on the board for the next time it opens.
        caseTask("memory", after: WorkbenchTokens.Cases.memoryDelay) { model in
            withAnimation(WorkbenchTokens.V2.resize) { model.cases.memoryNotice = notice }
            if model.notchState == .silent, model.live != nil { model.showAgentPanel(pinned: false, sent: model.v2Session) }
            model.caseTask("memory-hold", after: WorkbenchTokens.Cases.memoryHold) { model in
                withAnimation(WorkbenchTokens.V2.fold) { model.cases.memoryNotice = nil }
            }
        }
    }

    /// Open: Settings › Memory at that memory (the lead's hook); the board goes.
    func openMemoryNotice() {
        guard let notice = cases.memoryNotice else { return }
        cases.memoryNotice = nil
        cases.onOpenMemory?(notice.id)
        if notchState == .v2Board { closeAgentPanel() }
    }

    func dismissMemoryNotice() {
        withAnimation(WorkbenchTokens.V2.fold) { cases.memoryNotice = nil }
    }
}

extension V2Request {
    /// What Fovea's memory takes from a request like this (simulated): a short title.
    var memoryTitle: String {
        switch self {
        case .formula: return L("Papers on attention")
        case .calendar: return L("Your afternoon meetings")
        case .draft: return L("How you reply to Sam")
        case .code: return L("Notch ears follow the menu bar")
        }
    }
}

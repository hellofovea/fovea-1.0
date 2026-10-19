import SwiftUI
import AppKit
import FoveaCore
import FoveaKit

// The Oct 15 review's Dispatch states that using the app doesn't reach in 1.0 (its agents are
// simulated): each staged on the real notch from the Review menu (Live/IslandController+Cases.swift
// registers them), and Home's "Open in Notch" (QA25), which is real.

extension WorkbenchModel {
    // MARK: Reopening from Home (QA25)

    /// Home's Open in Notch: "Reopening…", then the session. One from this run opens as it is; one
    /// from before (the agents' sessions aren't kept across launches in 1.0) opens read only, its
    /// answer as it came back; one whose agent isn't here any more opens as gone, with Ask in a New
    /// Chat.
    func reopenV2(captureID: String, title: String, agent: String) {
        restingFlow = .dispatchV2
        if let id = cases.reopened[captureID] ?? agentTasks.first(where: { v2Sessions.contains($0.id) && $0.request == title })?.id,
           v2Task(id) != nil {
            cases.reopened[captureID] = id
            showReopeningV2(id)
            return
        }
        let known = (ChatAgent.all + [ChatAgent.fovea]).first { $0.name == agent || $0.id == agent }
        let request = V2Request(rawValue: RequestMatcher.match(title, tookSomething: false).rawValue) ?? .calendar
        let id = makeReopenedV2(title: title, agent: known?.id ?? ChatBook.predictedAgent, request: request, gone: known == nil)
        cases.reopened[captureID] = id
        showReopeningV2(id)
    }

    /// A session put back together from what Home kept: its request, and (simulated) its answer.
    @discardableResult
    func makeReopenedV2(title: String, agent: String, request: V2Request, gone: Bool) -> String {
        let id = "t-reopen-\(UUID().uuidString.prefix(6))"
        let last = request.script[request.script.count - 1]
        let quick = agent == ChatAgent.fovea.id
        var task = AgentTaskItem(id: id, agent: agent, session: quick ? title : request.generatedTitle,
                                 project: quick ? DispatchV2.quickProject : ChatBook.project, request: title,
                                 state: gone ? .failed : .complete, activity: gone ? "Not available" : last.activity,
                                 work: gone ? .failed : last.work, object: nil, preview: nil, ask: nil, age: 3600, inState: 3600)
        task.stopped = gone
        if !gone {
            task.result = last.result
            task.screen = last.screen
            task.answer = request.answer(followUp: false)
        }
        agentTasks.append(task)
        v2Requests[id] = request
        v2Titles[id] = TitleNamer.title(for: title, maxWords: 6)
        v2Checked.insert(id)
        v2Started[id] = Date().addingTimeInterval(-3600 - 40)
        v2FinishedAt[id] = Date().addingTimeInterval(-3600)
        if gone { cases.gone.insert(id) } else { cases.readOnly.insert(id) }
        return id
    }

    /// "Reopening…" a moment, then the session.
    func showReopeningV2(_ id: String) {
        cases.reopening.insert(id)
        showV2Chat(id, popped: false)
        caseTask("reopen", after: WorkbenchTokens.Cases.reopenTime) { model in
            withAnimation(WorkbenchTokens.V2.resize) { _ = model.cases.reopening.remove(id) }
        }
    }

    /// A chat that's gone: the same request, on Choose chat, to a new chat of its agent (Claude Code
    /// if that agent isn't here any more). It waits for the person to send.
    func askInNewChatV2(_ id: String) {
        guard let task = v2Task(id) else { return }
        let agent = (ChatAgent.all + [ChatAgent.fovea]).contains { $0.id == task.agent } ? task.agent : ChatBook.predictedAgent
        v2Words = task.request
        v2Request = V2Request(rawValue: RequestMatcher.match(task.request, tookSomething: false).rawValue) ?? .calendar
        clearReferents()
        restingFlow = .dispatchV2
        showV2Send()
        v2PickStorage = V2Suggestion(agent: agent, chat: nil, project: agent == ChatAgent.fovea.id ? nil : ChatBook.project,
                                     reason: L("island.chat.new", english: "New"))
    }

    // MARK: The stages

    /// A session of the code request in the notch, at work at its third beat (its run stopped, so it
    /// holds there), or done.
    private func caseSession(done: Bool = false, request: V2Request = .code) -> String {
        restingFlow = .dispatchV2
        v2Request = request
        v2Pinned = true
        let pick = request.suggestions[0]
        let beat = done ? request.script.count - 1 : min(2, request.script.count - 2)
        let id = makeV2Session(pick, at: beat)
        cases.sessionModes[id] = cases.approvalMode
        if done { v2FinishedAt[id] = Date() }
        return id
    }

    /// The session waiting on the person: an approval or a question, its run held where it asks.
    private func needsYouSession(_ ask: AgentAsk, activity: String) -> String {
        let id = caseSession()
        guard let i = agentTasks.firstIndex(where: { $0.id == id }) else { return id }
        v2Runs[id]?.cancel()
        agentTasks[i].state = .needsYou
        agentTasks[i].work = .asking
        agentTasks[i].activity = activity
        agentTasks[i].ask = ask
        v2QueuePaused.insert(id)
        // Where the script asks: answered, it goes on from there.
        v2PausedBeat[id] = v2Request.script.firstIndex { $0.state == .needsYou } ?? 2
        return id
    }

    /// Choose chat for the code request, its referents taken.
    private func caseChooseChat() {
        stageV2(.send)
    }

    /// The browser open on an agent (a project opened, a search typed).
    private func caseBrowser(agent: String, project: String? = nil, query: String = "") {
        caseChooseChat()
        toggleV2Browse()
        browseV2Agent(agent)
        v2BrowseProject = project
        setBrowseQuery(query)
    }

    /// One of the review's states, by its stage name (`qa:<case>`); whether it was one.
    @discardableResult
    func stageCase(_ name: String) -> Bool {
        switch name {
        // QA04, QA05: every chat.
        // Oct 18, Ryan: the sample searches in the primary language, so the Chinese titles are found.
        case "qa:browseSearch": caseBrowser(agent: "claude-code", query: L("island.search.found", english: "notch"))
        case "qa:browseEmpty": caseBrowser(agent: "claude-code", query: L("island.search.none", english: "invoices"))
        case "qa:browseMore": caseBrowser(agent: "claude-code", project: ChatBook.project)
        case "qa:browseLoading":
            caseBrowser(agent: "claude-code")
            cases.browseLoad = .loading
        case "qa:browseFailed":
            caseBrowser(agent: "claude-code")
            cases.browseLoad = .failed
        case "qa:blockedInUse": caseBrowser(agent: "codex", project: "fovea-mac")
        case "qa:blockedReadOnly": caseBrowser(agent: "claude-code", project: "Futuro")
        case "qa:blockedFolder": caseBrowser(agent: "claude-code", project: ChatBook.project)
        case "qa:blockedAgent":
            cases.downAgent = "codex"
            caseBrowser(agent: "codex", project: ChatBook.project)
        // QA06, QA10: sending.
        case "qa:sending":
            caseChooseChat()
            cases.sending = .sending(v2Pick)
        case "qa:notSent":
            caseChooseChat()
            cases.sending = .notSent(v2Pick)
        case "qa:declined":
            caseChooseChat()
            cases.sending = .declined(v2Pick, L("plan mode is on in this chat"))
        // QA07: edit.
        case "qa:edit":
            let id = caseSession(done: true)
            showV2Chat(id, popped: false)
            startEditV2(id)
        // QA08, QA09: the model sheet.
        case "qa:modelsFailed":
            caseChooseChat()
            v2ModelSheet = true
            cases.modelsLoad = .failed
        case "qa:modelUnavailable":
            caseChooseChat()
            v2Model = "opus-5.5"
            chooseV2(v2Request.suggestions[1])
            v2ModelSheet = true
        case "qa:approvals":
            caseChooseChat()
            v2ModelSheet = true
            cases.approvalMode = .allowEdits
        case "qa:approvalsLocked":
            caseChooseChat()
            v2ModelSheet = true
            cases.approvalMode = .askFirst
            cases.approvalLocked = L("Approvals: set in Claude Code's own settings")
        // QA14, QA15: needs you.
        case "qa:approval":
            let id = needsYouSession(.approval("Edit 2 files"), activity: "Apply the edit to 2 files?")
            cases.approvalFiles[id] = [FileChange(path: "Sources/Fovea/Island/IslandShape.swift", added: 3, removed: 1),
                                       FileChange(path: "Sources/FoveaCore/Island/NotchGeometry.swift", added: 2, removed: 1)]
            showV2Chat(id, popped: false)
        case "qa:approvalCommand":
            let id = needsYouSession(.approval("swift test --filter NotchGeometry"), activity: "Run swift test --filter NotchGeometry?")
            cases.scopes[id] = .session
            showV2Chat(id, popped: false)
        case "qa:allowed":
            let id = caseSession()
            showV2Chat(id, popped: false)
            cases.decisions[id] = "Allowed · running swift test"
        case "qa:question":
            let id = needsYouSession(.choice(["6 pt", "8 pt"]), activity: "Which spacing should the ears use?")
            showV2Chat(id, popped: false)
        case "qa:form":
            let id = needsYouSession(.choice([]), activity: "A few things before I change the ears:")
            cases.forms[id] = [V2FormField(id: "spacing", label: "Spacing", choices: ["6 pt", "8 pt"]),
                               V2FormField(id: "fullScreen", label: "In full screen too?", choices: ["Yes", "No"]),
                               V2FormField(id: "name", label: "Name the constant", choices: [])]
            showV2Chat(id, popped: false)
        // QA11, QA12: the queue.
        case "qa:queueFailed":
            let id = caseSession()
            v2Queue[id] = [V2QueuedAsk(text: "Check it on an external display too."),
                           V2QueuedAsk(text: "And use this spacing for the voice bar.",
                                       images: v2Referents(of: nil).suffix(1).map { $0 }, failed: true)]
            showV2Chat(id, popped: false)
        case "qa:queuePaused":
            let id = needsYouSession(.approval("swift test --filter NotchGeometry"), activity: "Run swift test --filter NotchGeometry?")
            v2Queue[id] = [V2QueuedAsk(text: "Check it on an external display too.")]
            showV2Chat(id, popped: false)
        // QA16, QA24: the connection.
        case "qa:reconnecting", "qa:lost", "qa:timedOut":
            let id = caseSession()
            v2Runs[id]?.cancel()
            cases.connection[id] = name == "qa:reconnecting" ? .reconnecting : (name == "qa:lost" ? .lost : .timedOut)
            showV2Chat(id, popped: false)
        case "qa:unconfirmed":
            let id = caseSession()
            v2Runs[id]?.cancel()
            if let i = agentTasks.firstIndex(where: { $0.id == id }), let first = v2Request.script.first {
                agentTasks[i].steps = []
                apply(first, to: i)
            }
            cases.unconfirmed[id] = [Date().addingTimeInterval(-140), Date().addingTimeInterval(-40)]
            showV2Chat(id, popped: false)
        // QA25: reopened from Home.
        case "qa:reopening":
            let id = makeReopenedV2(title: V2Request.calendar.spoken, agent: ChatAgent.fovea.id, request: .calendar, gone: false)
            cases.readOnly.remove(id)
            v2Sessions.insert(id)
            cases.reopening.insert(id)
            showV2Chat(id, popped: false)
        case "qa:reopenGone":
            let id = makeReopenedV2(title: V2Request.code.spoken, agent: "claude-code", request: .code, gone: true)
            showV2Chat(id, popped: false)
        case "qa:reopenReadOnly":
            let id = makeReopenedV2(title: V2Request.calendar.spoken, agent: ChatAgent.fovea.id, request: .calendar, gone: false)
            showV2Chat(id, popped: false)
        // QA26 (Oct 17, Ryan: Open in the session's agent, in place of Continue in): opened there.
        case "qa:openIn":
            let id = caseSession(done: true)
            showV2Chat(id, popped: false)
            openInAgentV2(id)
        // QA20: a file that can't be copied.
        case "qa:fileFailed":
            let id = caseSession(done: true, request: .code)
            showV2Chat(id, popped: false)
            cases.barLines[id] = V2BarLine(text: "Couldn't save a copy: you don't have permission to save there", failed: true,
                                           symbol: "exclamationmark.triangle")
        // QA21, QA23, DSP-24: a chat at work, closed: back on the board, still working.
        case "qa:closeWorking":
            let id = caseSession()
            run(id, from: 2)
            v2Detached = [V2Detached(id: id, origin: CGPoint(x: display.frame.width - V2DetachedLayout.size.width - 40, y: 120),
                                     docked: nil, dockY: 120)]
            closeDetachedV2(id)
            showAgentPanel(pinned: true)
            v2Focus = id
        // NH-03: remembered.
        case "qa:memory":
            let id = caseSession(done: true, request: .calendar)
            v2Focus = id
            cases.memoryNotice = V2MemoryNotice(id: "memory-calendar", title: V2Request.calendar.memoryTitle)
            showAgentPanel(pinned: true)
        default:
            return false
        }
        return true
    }

    /// Every stage name, in the order the review walks them.
    static let caseStages: [(id: String, title: String, name: String)] = [
        ("QA04", "Every chat: search", "qa:browseSearch"),
        ("QA04", "Every chat: no results", "qa:browseEmpty"),
        ("QA04", "Every chat: Load More", "qa:browseMore"),
        ("QA04", "Every chat: loading", "qa:browseLoading"),
        ("QA04", "Every chat: couldn't load", "qa:browseFailed"),
        ("QA05", "Chat in use by another request", "qa:blockedInUse"),
        ("QA05", "Chat read only", "qa:blockedReadOnly"),
        ("QA05", "Chat's folder can't be written", "qa:blockedFolder"),
        ("QA05", "Agent unavailable", "qa:blockedAgent"),
        ("QA06", "Sending to a chat", "qa:sending"),
        ("QA10", "Not sent", "qa:notSent"),
        ("QA10", "Declined by the agent", "qa:declined"),
        ("QA07", "Editing the last request", "qa:edit"),
        ("QA08", "Models couldn't load", "qa:modelsFailed"),
        ("QA08", "A model that isn't available", "qa:modelUnavailable"),
        ("QA09", "Approvals for the session", "qa:approvals"),
        ("QA09", "Approvals set by the agent", "qa:approvalsLocked"),
        ("QA14", "Approval: the files it would change", "qa:approval"),
        ("QA14", "Approval: a command, for this session", "qa:approvalCommand"),
        ("QA14", "After Allow", "qa:allowed"),
        ("QA15", "The agent's question", "qa:question"),
        ("QA15", "The agent's questions, as a form", "qa:form"),
        ("QA11", "Queued request couldn't send", "qa:queueFailed"),
        ("QA12", "Held queue: Open in Claude Code", "qa:queuePaused"),
        ("QA16", "Reconnecting to the agent", "qa:reconnecting"),
        ("QA16", "Lost connection", "qa:lost"),
        ("QA16", "Timed out", "qa:timedOut"),
        ("QA24", "Not sure it reached the agent", "qa:unconfirmed"),
        ("QA25", "Reopening from Home", "qa:reopening"),
        ("QA25", "This chat isn't available anymore", "qa:reopenGone"),
        ("QA25", "From an earlier version, read only", "qa:reopenReadOnly"),
        ("QA26", "Opened in its agent", "qa:openIn"),
        ("QA20", "A copy that couldn't be saved", "qa:fileFailed"),
        ("QA21", "Closing a working chat", "qa:closeWorking"),
        ("NH-03", "Remembered", "qa:memory"),
    ]
}

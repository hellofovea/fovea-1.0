import SwiftUI
import AppKit
import FoveaCore
import FoveaKit

// Dispatch's Choose chat: before a request goes, the island shows it (the words and the
// referents) and the chat Fovea's routing picked for it, with Send. Opened (left ⌃, ↓ or the
// pill), a rail of the agents and the active one's projects; a project opens to all its chats
// and a New chat. The person may pick another chat, never must (PRD §11–12); when Fovea isn't
// sure, it says so and asks. Anything that stands between the request and its chat is said in
// one line under the row (a notice), with what can be done about it. The chats are a sample
// (ChatBook.swift), and the panel stages the edge cases; docs/island/CHOOSE_CHAT.md has them.

/// How far Choose chat is opened.
enum ChatLevel: Equatable {
    /// The request, its referents, the chat and Send.
    case closed
    /// The rail of agents and the active one's projects.
    case projects
    /// One project's chats, scrolling, under a row back to the projects.
    case chats
}

/// Where a request is after Send, when it isn't simply gone.
enum ChatSendPhase: Equatable {
    case sending
    /// The chat didn't take it: try again (it won't be sent twice), or choose another.
    case failed
    /// Sent, but the agent hasn't confirmed it: Fovea won't send it again until it does.
    case unconfirmed
}

/// One line under the request's row: what stands between the request and its chat, and what can
/// be done about it.
struct ChatNotice: Equatable {
    enum Tone { case info, attention, failed }
    enum Action: Equatable {
        case open(String), chooseAnother, retryRouting, retrySend, checkAgain, continueInTerminal
        var title: String {
            switch self {
            case .open(let app): return "Open \(app)"
            case .chooseAnother: return "Choose another"
            case .retryRouting: return "Try again"
            case .retrySend: return "Try again"
            case .checkAgain: return "Check again"
            case .continueInTerminal: return "Continue in Terminal"
            }
        }
    }
    let tone: Tone
    let text: String
    var actions: [Action] = []
}

extension WorkbenchModel {
    /// The request Dispatch sends: it names its referents, as Fovea's requests do.
    static let dispatchTranscript = "Make the ears on this one match the menu bar's height, and use the spacing from the second one."
    /// A project's row, and the row back to the projects, in the highlight beside the chats'.
    nonisolated static let projectPrefix = "project|"
    nonisolated static let backRow = "back"

    /// The words of the request, as the case stages them (none: the screenshots go alone).
    var requestText: String {
        switch chatCase {
        case .imagesOnly: return ""
        case .longRequest: return ChatBook.longRequest
        default: return Self.dispatchTranscript
        }
    }

    func chat(_ id: String) -> AgentChat? { ChatBook.chat(id, in: chats) }

    /// The chat the request goes to; none while Fovea isn't sure, routing has failed, or the chat
    /// it picked was closed, and nothing is chosen yet.
    var chosen: AgentChat? { chosenChat.isEmpty ? nil : chat(chosenChat) }

    /// An agent Fovea isn't set up for: its chats can't be listed or sent to.
    func offline(_ agent: String) -> Bool { chatCase == .notSetUp && agent == ChatBook.notSetUp }

    /// An agent whose chats are still being read.
    func loading(_ agent: String) -> Bool { chatLoadingAgents.contains(agent) }

    func projects(of agent: String) -> [ChatProject] {
        offline(agent) || loading(agent) ? [] : ChatBook.projects(of: agent, in: chats)
    }

    /// The project open on the chats level.
    var openProject: ChatProject? {
        guard let folder = chatProject else { return nil }
        return projects(of: chatAgent).first { $0.folder == folder }
    }

    /// The rows a project opens to: a New chat, then its chats.
    func items(of project: ChatProject) -> [AgentChat] {
        [ChatBook.newChat(agent: project.agent, folder: project.folder)] + project.chats
    }

    /// Routing's pick (none while it isn't sure or fails): "Suggested" marks it once another is
    /// chosen.
    var predictedPick: String {
        switch chatCase {
        case .unsure: return ""
        case .routingFailed where !chatRetried: return ""
        default: return ChatBook.predicted
        }
    }

    /// Fovea's best guesses, while it isn't sure and nothing is chosen: they are offered under
    /// the row, a New chat here last.
    var chatGuesses: [AgentChat] {
        guard chatUnsure, chosen == nil, chatRouted else { return [] }
        return ChatBook.guesses.compactMap(chat) + [ChatBook.newChat(agent: ChatBook.predictedAgent, folder: ChatBook.project)]
    }

    /// The chosen chat's Claude Desktop is too old, and Terminal hasn't been chosen instead.
    private var desktopBlocked: Bool {
        chatCase == .desktopTooOld && chosenChat == ChatBook.predicted && !chatTerminal
    }

    /// Send needs a chat that can take the request now.
    var canSend: Bool {
        guard chatRouted, let chosen, chosen.state.choosable, !desktopBlocked else { return false }
        return chatSend == nil || chatSend == .failed
    }

    /// Why Send waits, or what it will do.
    var sendReason: String {
        if !chatRouted { return "Choosing a chat" }
        if chatSend == .sending { return "Sending" }
        if chatSend == .unconfirmed { return "Sent; waiting for the chat to confirm it" }
        guard let chosen else { return "Choose a chat first" }
        if !chosen.state.choosable { return "This chat can't take the request now: choose another" }
        if desktopBlocked { return "Update Claude, or continue in Terminal" }
        if chosen.state == .working { return "Send (↩): it goes in after the current turn" }
        return "Send (↩)"
    }

    /// The line under the row, if anything stands between the request and its chat.
    var chatNotice: ChatNotice? {
        guard chatRouted else { return nil }
        let agentName = ChatAgent.named(chosen?.agent ?? ChatBook.predictedAgent).name
        if let phase = chatSend, let chosen {
            switch phase {
            case .sending:
                return ChatNotice(tone: .info, text: "Sending to “\(chosen.title)”…")
            case .failed:
                return ChatNotice(tone: .failed, text: "Couldn't send: \(agentName) didn't open “\(chosen.title)”.",
                                  actions: [.retrySend, .chooseAnother])
            case .unconfirmed:
                return ChatNotice(tone: .info, text: "Sent to “\(chosen.title)”, not confirmed yet. Fovea won't send it twice.",
                                  actions: [.checkAgain])
            }
        }
        if chosen == nil {
            if chatRoutingFailed {
                return ChatNotice(tone: .failed, text: "Fovea couldn't pick a chat for this.", actions: [.retryRouting, .chooseAnother])
            }
            if chatUnsure {
                return ChatNotice(tone: .info, text: "Fovea isn't sure where this goes. Is it one of these?")
            }
            if let removed = chatRemovedTitle {
                return ChatNotice(tone: .attention, text: "“\(removed)” was closed in Claude Code.", actions: [.chooseAnother])
            }
            return nil
        }
        guard let chosen else { return nil }
        switch chosen.state {
        case .needsYou:
            let text = chatCase == .askedQuestion
                ? "“\(chosen.title)” asked you a question in \(agentName)."
                : "“\(chosen.title)” is waiting for your approval in \(agentName)."
            return ChatNotice(tone: .attention, text: text, actions: [.open(agentName), .chooseAnother])
        case .working:
            return ChatNotice(tone: .info, text: "\(agentName) is answering in this chat; yours goes in after this turn.")
        default:
            break
        }
        if desktopBlocked {
            return ChatNotice(tone: .attention, text: "It's open in Claude Desktop, which is too old to take it.",
                              actions: [.continueInTerminal, .chooseAnother])
        }
        return nil
    }

    var chatLevel: ChatLevel {
        switch notchState {
        case .chatsExpanded: return .projects
        case .chatsAll: return .chats
        default: return .closed
        }
    }

    /// Where Choose chat's parts go at its level.
    var chatLayout: ChatLayout {
        let C = WorkbenchTokens.Chat.self
        // Three lines at most (it scrolls in them); a quiet line when there are no words; until
        // the view has measured the words, a line is about 18 pt.
        let full = chatTextHeight > 0 ? chatTextHeight : 2 * C.emptyRequestHeight
        let textHeight = requestText.isEmpty ? C.emptyRequestHeight : (chatLinesHeight > 0 ? min(full, chatLinesHeight) : full)
        return ChatLayout.make(level: chatLevel, textHeight: textHeight, referents: liveReferents.count, notice: chatNotice,
                               guesses: chatGuesses.map(\.id), agents: ChatAgent.all, projects: projects(of: chatAgent),
                               items: openProject.map(items(of:)) ?? [], offline: offline(chatAgent),
                               loading: loading(chatAgent), metrics: metrics)
    }

    private var chatAnimated: Bool { !snapshotMode && !reduceMotion }

    /// Opens Choose chat at a level from wherever the notch is, staging the panel's edge case:
    /// routing picks the chat again, the referents captured in Voiceflow stay (or samples stand
    /// in for them).
    func showChooseChat(_ level: ChatLevel) {
        if notchState.choosingChat {
            setChatLevel(level)
            return
        }
        chats = ChatBook.chats
        chatRetried = false
        chatSendRetried = false
        chatSend = nil
        chatTerminal = false
        chatUnsure = false
        chatRemovedTitle = nil
        chatRoutingFailed = false
        chatChanged = false
        chosenChat = ""
        chatAgent = ChatBook.predictedAgent
        chatProject = ChatBook.project
        chatHighlight = nil
        chatLoadingAgents = chatCase == .loading ? Set(ChatAgent.all.map(\.id)).subtracting([ChatBook.predictedAgent]) : []
        stageReferents()
        notchState = Self.state(for: level)
        startRouting()
        if chatCase == .loading { finishLoading() }
        if level != .closed { chatHighlight = highlightOnOpen(level) }
        chatHoverMouse = NSEvent.mouseLocation
        if level != .closed { changeWhileOpen() }
    }

    /// The panel's edge case changed: Choose chat starts over with it.
    func chatCaseChanged() {
        guard notchState.choosingChat else { return }
        let level = chatLevel
        notchState = .silent
        clearReferents()
        showChooseChat(level)
    }

    private static func state(for level: ChatLevel) -> NotchState {
        switch level {
        case .closed: return .chooseChat
        case .projects: return .chatsExpanded
        case .chats: return .chatsAll
        }
    }

    /// The referents: Voiceflow's, if any; otherwise two of Fovea's own screens, or for "many
    /// screenshots" seven, the fifth of which can't be read.
    private func stageReferents() {
        chatMissingReferent = nil
        if chatCase == .manyReferents {
            clearReferents()
            let names = [("Screens/fovea-home.png", "Fovea — Home"), ("Screens/fovea-settings.png", "Fovea — Settings"),
                         ("Photos/mountain.jpg", "mountain.jpg"), ("Photos/desk.jpg", "desk.jpg"), ("Photos/coast.jpg", "coast.jpg"),
                         ("Photos/forest.jpg", "forest.jpg"), ("Photos/building.jpg", "building.jpg")]
            for (path, source) in names {
                guard let url = FoveaFiles.url(path), let image = NSImage(contentsOf: url) else { continue }
                referents.append(CapturedReferent(id: UUID(), image: image, aspect: image.size.width / max(1, image.size.height),
                                                  source: source))
            }
            if referents.indices.contains(4) { chatMissingReferent = referents[4].id }
            return
        }
        guard liveReferents.isEmpty else { return }
        for (name, source) in [("fovea-home", "Fovea — Home"), ("fovea-settings", "Fovea — Settings")] {
            guard let url = FoveaFiles.url("Screens/\(name).png"), let image = NSImage(contentsOf: url) else { continue }
            referents.append(CapturedReferent(id: UUID(), image: image, aspect: image.size.width / max(1, image.size.height),
                                              source: source))
        }
    }

    /// Routing answers after a moment; until then the pill breathes "Choosing chat" at its width.
    /// A pick the person makes first is kept: routing's late answer never replaces it.
    private func startRouting() {
        chatTask?.cancel()
        chatRoutingFailed = false
        guard chatAnimated else {
            resolveRouting()
            return
        }
        chatRouted = false
        chatTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(WorkbenchTokens.Chat.routing))
            guard let self, !Task.isCancelled, self.notchState.choosingChat else { return }
            self.resolveRouting()
        }
    }

    private func resolveRouting() {
        chatRouted = true
        guard chosenChat.isEmpty else { return }
        switch chatCase {
        case .unsure:
            // It asks: its guesses under the row, the highlight on the first.
            chatUnsure = true
            if chatLevel == .closed { chatHighlight = chatGuesses.first?.id }
            return
        case .routingFailed where !chatRetried:
            chatRoutingFailed = true
            return
        default:
            chosenChat = ChatBook.predicted
        }
        // The answer moves the rail to the pick only while it's closed: never what the person is
        // already browsing.
        if let chosen, chatLevel == .closed { chatAgent = chosen.agent; chatProject = chosen.folder }
        guard let i = chats.firstIndex(where: { $0.id == chosenChat }) else { return }
        switch chatCase {
        case .busy:
            chats[i].state = .working
        case .needsApproval, .askedQuestion:
            // The pick then started waiting on the person, where it runs.
            chats[i].state = .needsYou
        case .removed:
            // The pick is closed in Claude Code before the request goes.
            let title = chats[i].title
            let close = { [weak self] in
                guard let self, let j = self.chats.firstIndex(where: { $0.id == ChatBook.predicted }) else { return }
                self.chats.remove(at: j)
                if self.chosenChat == ChatBook.predicted { self.chosenChat = "" }
                self.chatRemovedTitle = title
            }
            if chatAnimated {
                chatCaseTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(WorkbenchTokens.Chat.caseDelay))
                    guard let self, !Task.isCancelled, self.notchState.choosingChat else { return }
                    close()
                }
            } else {
                close()
            }
        default:
            break
        }
    }

    /// "Chats still loading": the other agents' chats arrive a moment after Choose chat opens.
    private func finishLoading() {
        guard chatAnimated else { return }
        chatCaseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(WorkbenchTokens.Chat.loadingTime))
            guard let self, !Task.isCancelled else { return }
            self.chatLoadingAgents = []
        }
    }

    /// "Chats change while open": a moment after the list opens, a new chat arrives at the top of
    /// this project and two chats change state (one finishes its turn, one is answered). Rows keep
    /// their identities, so the highlight and the scroll stay where they were.
    private func changeWhileOpen() {
        guard chatCase == .changing, !chatChanged else { return }
        let apply = { [weak self] in
            guard let self, !self.chatChanged else { return }
            self.chatChanged = true
            self.chats.append(ChatBook.arriving)
            for id in ["cc-choose-chat", "cc-paste-countdown"] {
                if let i = self.chats.firstIndex(where: { $0.id == id }) { self.chats[i].state = .ready }
            }
        }
        guard chatAnimated else {
            apply()
            return
        }
        chatCaseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(WorkbenchTokens.Chat.caseDelay))
            guard let self, !Task.isCancelled, self.notchState.choosingChat else { return }
            apply()
        }
    }

    /// Retry routing, from the notice after it failed: this time it answers.
    func retryRouting() {
        guard chatRoutingFailed else { return }
        chatRetried = true
        startRouting()
    }

    /// Where the highlight starts on opening a level: the chosen chat, or its project.
    private func highlightOnOpen(_ level: ChatLevel) -> String? {
        switch level {
        case .closed: return chatGuesses.first?.id
        case .projects:
            let folder = chosen?.agent == chatAgent ? chosen?.folder : projects(of: chatAgent).first?.folder
            return folder.map { Self.projectPrefix + $0 }
        case .chats:
            guard let project = openProject else { return nil }
            if chosen?.agent == project.agent, chosen?.folder == project.folder { return chosenChat }
            return items(of: project).first { $0.state.choosable }?.id
        }
    }

    /// Opens or closes Choose chat a level; the highlight starts on the chosen chat or its project.
    func setChatLevel(_ level: ChatLevel) {
        guard notchState.choosingChat, level != chatLevel else { return }
        chooseTask?.cancel()
        if chatLevel == .closed, let chosen {
            chatAgent = chosen.agent
            chatProject = chosen.folder
        }
        if level == .chats, openProject == nil { chatProject = projects(of: chatAgent).first?.folder }
        notchState = Self.state(for: level)
        chatHighlight = highlightOnOpen(level)
        // Rows that open under a still pointer don't take the highlight from the chosen chat.
        chatHoverMouse = NSEvent.mouseLocation
        if level != .closed { changeWhileOpen() }
    }

    /// The pointer over a row moves the highlight there, but only when the pointer itself moved:
    /// rows that move under a still pointer (a chat arriving, a list scrolling to the chosen
    /// chat, a refresh) leave the highlight where it was (fovea-mac's history refresh).
    func hoverHighlight(_ id: String) {
        let p = NSEvent.mouseLocation
        defer { chatHoverMouse = p }
        if let last = chatHoverMouse, hypot(p.x - last.x, p.y - last.y) < 0.5 { return }
        chatHighlight = id
    }

    /// Left ⌃: open to the projects, or close.
    func toggleChatsExpanded() {
        guard notchState.choosingChat else { return }
        setChatLevel(chatLevel == .closed ? .projects : .closed)
    }

    /// A row clicked, or Return on the highlight: a project opens; a chat is chosen; the row back
    /// returns to the projects. A chat that can't take the request stays as it is.
    func activateChat(_ id: String) {
        if id == Self.backRow {
            setChatLevel(.projects)
        } else if id.hasPrefix(Self.projectPrefix) {
            openProject(String(id.dropFirst(Self.projectPrefix.count)))
        } else {
            choose(id)
        }
    }

    /// A project opens to its chats.
    func openProject(_ folder: String) {
        guard projects(of: chatAgent).contains(where: { $0.folder == folder }) else { return }
        chatProject = folder
        if chatLevel == .chats {
            chatHighlight = highlightOnOpen(.chats)
        } else {
            setChatLevel(.chats)
        }
    }

    /// The person picks a chat (or a New chat, or one of Fovea's guesses): the check moves to it
    /// at once, and a moment later an opened island closes with it in the pill. Routing's answer,
    /// if it is still coming, is dropped.
    func choose(_ id: String) {
        let guessing = chatLevel == .closed && chatGuesses.contains { $0.id == id }
        guard chatLevel != .closed || guessing, let chat = chat(id), chat.state.choosable else { return }
        chooseTask?.cancel()
        if !chatRouted {
            chatTask?.cancel()
            chatRouted = true
        }
        chatRoutingFailed = false
        chatRemovedTitle = nil
        if chatSend == .failed { chatSend = nil }
        chosenChat = id
        chatAgent = chat.agent
        chatProject = chat.folder
        chatHighlight = guessing ? nil : id
        guard !guessing else { return }
        chooseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(WorkbenchTokens.Chat.chooseHold))
            guard let self, !Task.isCancelled, self.chatLevel != .closed else { return }
            self.setChatLevel(.closed)
        }
    }

    /// A chat Fovea can't write to, opened in its own app instead: the island rests.
    func openElsewhere(_ id: String) {
        guard let chat = chat(id), case .elsewhere = chat.state else { return }
        notchState = .silent
    }

    /// What a notice's button does.
    func perform(_ action: ChatNotice.Action) {
        switch action {
        case .open:
            // The agent's own window, where the chat waits on the person: the island rests.
            notchState = .silent
        case .chooseAnother:
            setChatLevel(.projects)
        case .retryRouting:
            retryRouting()
        case .retrySend:
            retrySend()
        case .checkAgain:
            // The chat confirms it: the request has gone.
            sent()
        case .continueInTerminal:
            chatTerminal = true
        }
    }

    /// An agent on the rail shows its projects.
    func setChatAgent(_ agent: String) {
        guard agent != chatAgent || chatLevel == .chats else { return }
        let C = WorkbenchTokens.Chat.self
        islandAnimation = reduceMotion ? .easeOut(duration: WorkbenchTokens.Motion.reduceMotionFade) : C.agentSwap
        withAnimation(chatAnimated ? C.agentSwap : nil) { chatAgent = agent }
        if chatLevel == .chats {
            notchState = Self.state(for: .projects)
        }
        chatHighlight = highlightOnOpen(.projects)
        chatHoverMouse = NSEvent.mouseLocation
    }

    /// Send: the request goes to the chosen chat and the island rests. Staged, it fails (and can
    /// be tried again, never sent twice) or goes unconfirmed.
    func sendChat() {
        guard notchState.choosingChat, canSend else { return }
        if chatSend == .failed {
            retrySend()
            return
        }
        switch chatCase {
        case .sendFails where !chatSendRetried: deliver(then: .failed)
        case .unconfirmed: deliver(then: .unconfirmed)
        default: sent()
        }
    }

    /// The request has gone: it is a task in the Agent panel now, which opens with it
    /// highlighted (AMENDMENTS: Send shows the Agent list).
    private func sent() {
        chatSend = nil
        guard let chosen else {
            notchState = .silent
            return
        }
        deliverToPanel(chat: chosen, request: requestText.isEmpty ? "The screenshots, without words" : requestText)
    }

    /// Try again after a failed send: this time it goes.
    func retrySend() {
        chatSendRetried = true
        deliver(then: nil)
    }

    private func deliver(then outcome: ChatSendPhase?) {
        let finish = { [weak self] in
            guard let self else { return }
            if let outcome {
                self.chatSend = outcome
            } else {
                self.sent()
            }
        }
        if chatLevel != .closed { setChatLevel(.closed) }
        guard chatAnimated else {
            finish()
            return
        }
        chatSend = .sending
        chooseTask = Task {
            try? await Task.sleep(for: .seconds(WorkbenchTokens.Chat.sendTime))
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    /// Leaving Choose chat: routing, a pending close and the staged changes stop.
    func stopChat() {
        chatTask?.cancel()
        chatTask = nil
        chooseTask?.cancel()
        chooseTask = nil
        chatCaseTask?.cancel()
        chatCaseTask = nil
        chatHighlight = nil
        chatRouted = true
        chatRoutingFailed = false
        chatSend = nil
    }

    // MARK: Keys

    /// The arrows and Return while Choose chat shows. Closed: Return sends (or, with nothing to
    /// send to, chooses Fovea's highlighted guess or opens the chats), ↑↓ move among the guesses
    /// (or ↓ opens). Opened: ↑↓ move the highlight (it never animates), ←→ change agent, Return
    /// opens a project or chooses a chat, ⌘Return sends to the highlighted chat.
    func chatKey(_ key: ChatKey) -> Bool {
        guard notchState.choosingChat else { return false }
        if chatLevel == .closed {
            let guesses = chatGuesses.map(\.id)
            switch key {
            case .enter, .send:
                if let id = chatHighlight, guesses.contains(id) {
                    choose(id)
                } else if canSend {
                    sendChat()
                } else if chatSend == nil {
                    setChatLevel(.projects)
                }
                return true
            case .up, .down:
                guard !guesses.isEmpty else {
                    if key == .down { setChatLevel(.projects) }
                    return key == .down
                }
                let i = chatHighlight.flatMap { guesses.firstIndex(of: $0) }
                if key == .down, i == guesses.count - 1 {
                    setChatLevel(.projects)
                } else {
                    let next = i.map { key == .up ? max(0, $0 - 1) : $0 + 1 } ?? 0
                    chatHighlight = guesses[next]
                }
                return true
            case .left, .right:
                return false
            }
        }
        switch key {
        case .enter:
            if let id = chatHighlight { activateChat(id) }
        case .send:
            if let id = chatHighlight, let chat = chat(id), chat.state.choosable { chosenChat = id }
            sendChat()
        case .left, .right:
            let agents = ChatAgent.all.map(\.id)
            guard let a = agents.firstIndex(of: chatAgent) else { break }
            setChatAgent(agents[key == .left ? max(0, a - 1) : min(agents.count - 1, a + 1)])
        case .up, .down:
            // Every row in order, the ones that can't be chosen included: they say why.
            let ids: [String]
            if chatLevel == .chats, let project = openProject {
                ids = [Self.backRow] + items(of: project).map(\.id)
            } else {
                ids = projects(of: chatAgent).map { Self.projectPrefix + $0.folder }
            }
            guard !ids.isEmpty else { break }
            guard let current = chatHighlight, let i = ids.firstIndex(of: current) else {
                chatHighlight = ids.first
                break
            }
            chatHighlight = ids[key == .up ? max(0, i - 1) : min(ids.count - 1, i + 1)]
        }
        return true
    }
}

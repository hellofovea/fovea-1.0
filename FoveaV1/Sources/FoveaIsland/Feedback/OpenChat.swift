import SwiftUI
import AppKit
import FoveaCore
import FoveaKit

// Oct 24, Ryan: "when the user hovers their mouse over the notch, they can open any chat … it is
// simply for selecting a chat. Users will also be able to pin chats there … [the search button]
// should always be present, even when other tasks or agents are running." Of four designs he chose
// the top bar (docs/island/OPEN_ANY_CHAT.md): the greeting and the search over the board, the
// pinned chats first in its list. The search lists Fovea's pick, the pinned chats and every other
// chat, five at a time, or what a search finds; a click opens the chat in the notch, the pin on a
// row keeps it on the board. No box to write a request in on the board: the notch chooses the
// chat, and the chat opened has its own box. On the real Mac only (`boardSearch`).

// MARK: - Tokens

extension WorkbenchTokens {
    enum OpenChat {
        // The search button: a quiet disc, the glass's ink at a low opacity, as the board's Stop.
        static var button: CGFloat { pick(24, 26) }
        static var buttonGlyph: Font { pick(Font.system(size: 11, weight: .semibold), .system(size: 12, weight: .semibold)) }
        static var buttonFill: Color { ink(0.08) }
        static var buttonHover: Color { ink(0.14) }
        static var buttonGlyphColor: Color { ink(0.72) }
        // The bar over the list.
        static var header: CGFloat { pick(30, 34) }
        /// Pinned chats on the board, at most; the rest are in the search.
        static let pinsShown = 5
        // The search.
        static var field: CGFloat { pick(28, 30) }
        static var fieldGap: CGFloat { pick(5, 6) }
        static var fieldFont: Font { pick(Font.system(size: 12.5), .system(size: 13)) }
        static var fieldGlyph: Font { pick(Font.system(size: 11, weight: .semibold), .system(size: 11.5, weight: .semibold)) }
        static var fieldFill: Color { ink(0.07) }
        static var fieldPaddingH: CGFloat { pick(9, 10) }
        static var sectionHeader: CGFloat { pick(22, 24) }
        static var row: CGFloat { pick(36, 40) }
        static var rowIcon: CGFloat { pick(18, 20) }
        /// Oct 24, Ryan: "the maximum number of chats there should be 5, if more than 5, the user
        /// should scroll through all"; then "for the sessions running, if there's more than 5,
        /// also collapse to 5 and let the user scroll to find". The search's chats and the
        /// board's sessions alike.
        static let rowsVisible = 5
        static var resultFont: Font { pick(Font.system(size: 12.5), .system(size: 13.5)) }
        static var pinFont: Font { pick(Font.system(size: 9, weight: .semibold), .system(size: 9.5, weight: .semibold)) }
        static var pinColor: Color { ink(0.42) }
        static let blockedOpacity: Double = 0.45
    }
}

// MARK: - The flow

extension WorkbenchModel {
    /// The pinned chats, in the order pinned.
    var pinned: [AgentChat] { pinnedChats.compactMap { ChatBook.chat($0, in: ChatBook.chats) } }
    /// The ones the board shows; the rest are in the search's Pinned.
    var pinnedShown: [AgentChat] { Array(pinned.prefix(WorkbenchTokens.OpenChat.pinsShown)) }

    func isPinned(_ id: String) -> Bool { pinnedChats.contains(id) }

    func togglePin(_ id: String) {
        reshapeV2(growing: !isPinned(id))
        withAnimation(WorkbenchTokens.Board.move) {
            if let i = pinnedChats.firstIndex(of: id) { pinnedChats.remove(at: i) } else { pinnedChats.append(id) }
        }
    }

    /// Fovea's pick: the chat routing would send to now (the last one sent to, 4m ago).
    var chatSuggestion: AgentChat? { ChatBook.chat(ChatBook.predicted, in: ChatBook.chats) }

    /// What the search lists: Fovea's pick, the pinned chats, then every other chat, the most
    /// recent first; or, typed, the chats whose title or project has the words.
    var chatPickerSections: [OpenChatSection] {
        let all = ChatBook.chats.sorted { $0.minutesAgo < $1.minutesAgo }
        let query = chatPickerQuery.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            let found = all.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.folder.localizedCaseInsensitiveContains(query) }
            return found.isEmpty ? [] : [OpenChatSection(title: L("Chats"), chats: found)]
        }
        var sections: [OpenChatSection] = []
        var listed = Set<String>()
        if let pick = chatSuggestion {
            sections.append(OpenChatSection(title: L("Suggested"), chats: [pick], suggested: true))
            listed.insert(pick.id)
        }
        let pins = pinned.filter { !listed.contains($0.id) }
        if !pins.isEmpty {
            sections.append(OpenChatSection(title: L("Pinned"), chats: pins))
            listed.formUnion(pins.map(\.id))
        }
        sections.append(OpenChatSection(title: L("Recent"), chats: all.filter { !listed.contains($0.id) }))
        return sections
    }

    func openChatPicker() {
        reshapeV2(growing: true)
        chatPickerQuery = ""
        chatPickerHover = nil
        withAnimation(WorkbenchTokens.V2.resize) { chatPickerOpen = true }
    }

    func closeChatPicker() {
        guard chatPickerOpen else { return }
        reshapeV2(growing: false)
        withAnimation(WorkbenchTokens.V2.fold) { chatPickerOpen = false }
        chatPickerQuery = ""
        chatPickerHover = nil
    }

    /// A chat picked: it opens in the notch. One Fovea has a session in opens as it is; any other
    /// opens as a session of its own (`openedChats`) with nothing sent from Fovea yet, its box ready:
    /// what's asked there goes into that chat, and it joins the board. One that can't take a
    /// request stays where it is (it says why).
    func openChat(_ chat: AgentChat) {
        guard v2ChatBlock(chat) == nil else { return }
        chatPickerOpen = false
        chatPickerQuery = ""
        chatPickerHover = nil
        if let task = agentTasks.first(where: { $0.agent == chat.agent && $0.session == chat.title && $0.project == chat.folder }) {
            openV2(task.id)
            return
        }
        let id = "t-chat-\(chat.id)"
        if v2Task(id) == nil {
            let since = Double(chat.minutesAgo) * 60
            // Oct 24, Ryan: a chat has been asked before. A sample chat opens on its exchanges so
            // far, the last one as where it is now; the others, on when it was last active.
            var asked = (live == nil || demoSamples) ? V2SampleHistory.chat(chat.id) ?? [] : []
            let last = asked.popLast()
            var task = AgentTaskItem(id: id, agent: chat.agent, session: chat.title, project: chat.folder, request: last?.question ?? "",
                                     state: .complete, activity: "", work: .done, object: nil, preview: nil, ask: nil,
                                     age: since, inState: since)
            task.answer = last?.answer
            task.modelLabel = v2ModelLabel(agent: chat.agent)
            agentTasks.append(task)
            if !asked.isEmpty { v2History[id] = V2SampleHistory.turns(asked) }
            // What's asked there plays as a request of its kind (the agents are simulated in 1.0).
            v2Requests[id] = V2Request(rawValue: RequestMatcher.match(chat.title, tookSomething: false).rawValue) ?? .code
            openedChats.insert(id)
        }
        openV2(id)
    }

    /// An opened chat with nothing sent from Fovea yet.
    func isOpenedChat(_ id: String) -> Bool { openedChats.contains(id) }

    /// One with nothing asked in it at all (not a sample's): a line in the answer's place.
    func isBlankChat(_ id: String) -> Bool { isOpenedChat(id) && (v2Task(id)?.request.isEmpty ?? true) }

    /// The search and the pinned chats on the board: the real Mac's, not in the first run (it
    /// teaches the board as it is, with its own sessions).
    var boardSearchShown: Bool { boardSearch && live?.director == nil }

    /// Return in the search: the first chat found that can take a request.
    func openFirstFound() {
        if let first = chatPickerSections.lazy.flatMap(\.chats).first(where: { self.v2ChatBlock($0) == nil }) { openChat(first) }
    }

    /// `--demo chats:<state>`: hello (nothing running, nothing pinned), pinned (nothing running),
    /// board (the sample sessions), open (the search), search (typed, a row under the pointer
    /// offering its pin), opened (a chat opened from the search, nothing sent yet); rest (the
    /// sample sessions and pins on a board that opens only on hover, as on the person's own Mac).
    func stageOpenChat(_ state: String) {
        chatPickerOpen = false
        chatPickerQuery = ""
        chatPickerHover = nil
        pinnedChats = state == "hello" ? [] : OpenChatSection.samplePins
        if state == "hello" || state == "pinned" {
            agentTasks = []
            v2Sessions = []
            showAgentPanel(pinned: true)
        } else if state == "rest" {
            // Oct 24, Ryan: "Only when the user moves their mouse onto the notch, then that should
            // open."
            notchState = .silent
            panelArmed = true
        } else {
            stageV2(.board)
        }
        switch state {
        case "open":
            chatPickerOpen = true
        case "search":
            chatPickerOpen = true
            chatPickerQuery = "gaze"
            chatPickerHover = "cc-gaze-papers"
        case "opened":
            if let chat = ChatBook.chat("cx-investors", in: ChatBook.chats) { openChat(chat) }
        default:
            break
        }
    }
}

/// A part of the search's list.
struct OpenChatSection: Equatable {
    let title: String
    let chats: [AgentChat]
    var suggested = false

    /// The pictures' pinned chats: one of each agent's, from three projects.
    static let samplePins = ["cx-investors", "cc-gaze-drift", "cx-delivery"]
}

// MARK: - Geometry

/// One block of the board, top to bottom, and its height.
struct OpenChatPart: Equatable {
    enum Kind: Equatable {
        case hello, header, notice, pinned, seam, sessions, field, gap, results
    }
    let kind: Kind
    let height: CGFloat
}

extension V2BoardLayout {
    /// The board with the search (`base`, the list as Badges draws it): with nothing running the
    /// greeting's two lines and the search beside them; running, the greeting and the search on a
    /// bar over the list; "Remembered" under it while there is one; the pinned chats first, a seam
    /// under them; then the sessions, five in view and the rest a scroll away. The search open, its
    /// field and its list in the board's place.
    @MainActor
    static func openChat(model: WorkbenchModel, metrics: ScreenMetrics, base: V2BoardLayout) -> V2BoardLayout {
        let B = WorkbenchTokens.Board.self
        let O = WorkbenchTokens.OpenChat.self
        let running = !model.v2BoardOrder.isEmpty
        let pins = model.pinnedShown
        var parts: [OpenChatPart] = []
        var layout = base
        if model.chatPickerOpen {
            parts = [OpenChatPart(kind: .field, height: O.field), OpenChatPart(kind: .gap, height: O.fieldGap),
                     OpenChatPart(kind: .results, height: OpenChatResults.height(model: model))]
        } else {
            parts.append(running ? OpenChatPart(kind: .header, height: O.header) : OpenChatPart(kind: .hello, height: B.helloHeight))
            if base.notice > 0 { parts.append(OpenChatPart(kind: .notice, height: base.notice)) }
            if !pins.isEmpty {
                if !running { parts.append(OpenChatPart(kind: .seam, height: B.groupGap)) }
                parts.append(OpenChatPart(kind: .pinned, height: CGFloat(pins.count) * B.row))
            }
            if running {
                if !pins.isEmpty { parts.append(OpenChatPart(kind: .seam, height: B.groupGap)) }
                let list = V2BoardLayout.heights(sections: model.v2BoardGroups.map(\.count), style: model.boardStyle,
                                                 rows: O.rowsVisible)
                parts.append(OpenChatPart(kind: .sessions, height: list.visible))
                layout.listHeight = list.visible
                layout.scrolls = list.full > list.visible + 0.5
            }
        }
        layout.openChat = parts
        layout.outline.size.height = V2Geometry.top(metrics) + parts.reduce(0) { $0 + $1.height } + B.paddingBottom
        return layout
    }
}

// MARK: - The board

/// The board with the search: its blocks in a column.
struct OpenChatBoard: View {
    let model: WorkbenchModel
    let layout: V2BoardLayout

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(layout.openChat.enumerated()), id: \.offset) { _, part in
                    piece(part.kind).frame(height: part.height)
                }
            }
            .frame(width: V2BoardLayout.contentWidth, alignment: .topLeading)
            .offset(x: V2BoardLayout.contentX, y: V2Geometry.top(model.metrics))
        }
        .frame(width: layout.outline.size.width, height: layout.outline.size.height, alignment: .topLeading)
        .panelScheme()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sessions")
    }

    @ViewBuilder
    private func piece(_ kind: OpenChatPart.Kind) -> some View {
        let B = WorkbenchTokens.Board.self
        switch kind {
        case .hello:
            HStack(spacing: 0) {
                V2BoardHello(name: model.greetingName)
                OpenChatSearchButton(model: model).padding(.trailing, B.rowPaddingH)
            }
        case .header:
            HStack(spacing: 0) {
                Text(Self.greeting(model.greetingName)).font(B.titleFont).foregroundStyle(B.title)
                Spacer(minLength: 0)
                OpenChatSearchButton(model: model)
            }
            .padding(.horizontal, B.rowPaddingH)
        case .notice:
            if let notice = model.cases.memoryNotice { V2MemoryRow(model: model, notice: notice).transition(.opacity) }
        case .pinned:
            VStack(spacing: 0) {
                ForEach(model.pinnedShown) { chat in
                    OpenChatRow(model: model, chat: chat, icon: B.badgedIcon).frame(height: B.row)
                }
            }
        case .seam:
            Rectangle().fill(B.hairline).frame(height: 0.5).padding(.horizontal, B.rowPaddingH)
        case .sessions:
            OpenChatSessions(model: model, scrolls: layout.scrolls)
        case .field:
            OpenChatField(model: model)
        case .gap:
            Color.clear
        case .results:
            OpenChatResults(model: model)
        }
    }

    static func greeting(_ name: String) -> String {
        let who = name.trimmingCharacters(in: .whitespaces)
        return who.isEmpty ? "Hello." : "Hello, \(who)."
    }
}

/// The search: a magnifying glass on a quiet disc; while the search is open, ✕ closes it.
struct OpenChatSearchButton: View {
    let model: WorkbenchModel
    var size: CGFloat = WorkbenchTokens.OpenChat.button
    @State private var hovering = false

    var body: some View {
        let O = WorkbenchTokens.OpenChat.self
        let open = model.chatPickerOpen
        Button { open ? model.closeChatPicker() : model.openChatPicker() } label: {
            Image(systemName: open ? "xmark" : "magnifyingglass")
                .font(O.buttonGlyph)
                .foregroundStyle(O.buttonGlyphColor)
                .frame(width: size, height: size)
                .background(Circle().fill(hovering ? O.buttonHover : O.buttonFill))
                .contentShape(Circle())
        }
        .buttonStyle(IslandPressStyle())
        .onHover { hovering = $0 }
        .help(open ? L("Close") : L("Open any chat"))
        .accessibilityLabel(open ? L("Close the search") : L("Search chats"))
    }
}

/// The board's sessions, as the Badges list draws them (a seam between the states' parts): five in
/// view, the rest a scroll away; ↑↓ scroll the one they reach into view.
struct OpenChatSessions: View {
    let model: WorkbenchModel
    let scrolls: Bool

    var body: some View {
        let B = WorkbenchTokens.Board.self
        let rows = VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 0).id(V2BoardList.topID)
            ForEach(Array(model.v2BoardSections.enumerated()), id: \.element.section) { i, part in
                if i > 0 {
                    Rectangle().fill(B.hairline).frame(height: 0.5)
                        .padding(.horizontal, B.rowPaddingH)
                        .frame(height: B.groupGap)
                }
                ForEach(part.tasks) { task in
                    V2BoardRow(model: model, task: task, focused: model.v2Focus == task.id, style: model.boardStyle)
                        .frame(height: B.row)
                        .id(task.id)
                }
            }
        }
        if model.offscreenRender {
            rows.frame(maxHeight: .infinity, alignment: .top).clipped()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    rows.animation(model.snapshotMode ? nil : B.move, value: model.v2BoardOrder.map(\.id))
                }
                .scrollDisabled(!scrolls)
                .scrollIndicators(scrolls ? .automatic : .never)
                .onChange(of: model.v2ScrollTarget) { _, id in if let id { proxy.scrollTo(id) } }
            }
        }
    }
}

/// A chat as a row: its agent's icon, its title over its project and agent (or, Fovea's pick, why
/// it's picked), how long ago; under the pointer, the pin. A search's words are set heavier. One
/// that can't take a request is dimmed and says why.
struct OpenChatRow: View {
    let model: WorkbenchModel
    let chat: AgentChat
    var reason: String? = nil
    var query = ""
    var icon: CGFloat = WorkbenchTokens.OpenChat.rowIcon
    @State private var hovering = false

    var body: some View {
        let B = WorkbenchTokens.Board.self
        let O = WorkbenchTokens.OpenChat.self
        let blocked = model.v2ChatBlock(chat)
        let shown = hovering || model.chatPickerHover == chat.id
        let pinned = model.isPinned(chat.id)
        HStack(spacing: B.iconGap) {
            ChatAgentIcon(agent: ChatAgent.named(chat.agent), size: icon)
            VStack(alignment: .leading, spacing: B.lineGap) {
                title.lineLimit(1).truncationMode(.tail)
                Text(reason ?? "\(chat.folder) · \(ChatAgent.named(chat.agent).name)")
                    .font(B.lineFont).foregroundStyle(B.line).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(blocked == nil ? 1 : O.blockedOpacity)
            Group {
                if let blocked {
                    V2BlockedReason(reason: blocked, chat: chat)
                } else if shown {
                    Button { model.togglePin(chat.id) } label: {
                        Image(systemName: pinned ? "pin.slash" : "pin")
                            .font(O.buttonGlyph)
                            .foregroundStyle(O.buttonGlyphColor)
                            .frame(width: O.button, height: O.button)
                            .background(Circle().fill(O.buttonFill))
                            .contentShape(Circle())
                    }
                    .buttonStyle(IslandPressStyle())
                    .help(pinned ? L("Unpin") : L("Pin to the notch"))
                } else {
                    HStack(spacing: 5) {
                        if pinned { Image(systemName: "pin.fill").font(O.pinFont).foregroundStyle(O.pinColor) }
                        Text(chat.age).font(B.timeFont).foregroundStyle(B.time).monospacedDigit()
                    }
                }
            }
            .frame(minWidth: B.trailingWidth, alignment: .trailing)
        }
        .padding(.horizontal, B.rowPaddingH)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: B.rowRadius, style: .continuous)
            .fill(shown && blocked == nil ? B.highlight : .clear))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { model.openChat(chat) }
        .contextMenu { Button(pinned ? L("Unpin") : L("Pin to the notch")) { model.togglePin(chat.id) } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(chat.title), \(chat.folder), \(ChatAgent.named(chat.agent).name)")
        .accessibilityAction { model.openChat(chat) }
    }

    private var title: Text {
        let B = WorkbenchTokens.Board.self
        let O = WorkbenchTokens.OpenChat.self
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, let range = chat.title.range(of: q, options: .caseInsensitive) else {
            return Text(chat.title).font(q.isEmpty ? B.titleFont : O.resultFont).foregroundColor(B.title)
        }
        return Text(chat.title[..<range.lowerBound]).font(O.resultFont).foregroundColor(B.title)
            + Text(chat.title[range]).font(B.titleFont).foregroundColor(B.title)
            + Text(chat.title[range.upperBound...]).font(O.resultFont).foregroundColor(B.title)
    }
}

/// The search's field: what's typed finds chats by title or project; Return opens the first, Esc
/// closes. The island's window takes the keys while it's open (it hands them back when it rests).
struct OpenChatField: View {
    let model: WorkbenchModel
    @FocusState private var focused: Bool

    var body: some View {
        let O = WorkbenchTokens.OpenChat.self
        let B = WorkbenchTokens.Board.self
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass").font(O.fieldGlyph).foregroundStyle(WorkbenchTokens.V2.subColor)
            TextField(L("Search chats"), text: Binding(get: { model.chatPickerQuery }, set: { model.chatPickerQuery = $0 }))
                .textFieldStyle(.plain)
                .font(O.fieldFont)
                .foregroundStyle(WorkbenchTokens.V2.titleColor)
                .focused($focused)
                .onSubmit { model.openFirstFound() }
                .onKeyPress(.escape) { model.closeChatPicker(); return .handled }
            OpenChatSearchButton(model: model, size: O.field - 8)
        }
        .padding(.leading, O.fieldPaddingH)
        .padding(.trailing, 4)
        .frame(height: O.field)
        .background(Capsule(style: .continuous).fill(O.fieldFill))
        .padding(.horizontal, B.rowPaddingH - 4)
        .background(KeyWindowMaker())
        .onAppear { if !model.snapshotMode { focused = true } }
    }
}

/// Makes the window it's in the key one (the island's panel takes keys only when asked).
struct KeyWindowMaker: NSViewRepresentable {
    final class Probe: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in self?.window?.makeKey() }
        }
    }
    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ view: Probe, context: Context) {}
}

/// The search's list: its parts under quiet headers, five chats in view and the rest a scroll
/// away; or "No chats match".
struct OpenChatResults: View {
    let model: WorkbenchModel

    var body: some View {
        let B = WorkbenchTokens.Board.self
        let O = WorkbenchTokens.OpenChat.self
        let sections = model.chatPickerSections
        let list = VStack(alignment: .leading, spacing: 0) {
            if sections.isEmpty {
                V2CaseStatus(symbol: "magnifyingglass", text: L("No chats match \u{201C}\(model.chatPickerQuery)\u{201D}")) { EmptyView() }
                    .padding(.horizontal, B.rowPaddingH)
                    .frame(height: O.row)
            }
            ForEach(sections, id: \.title) { section in
                Text(section.title).font(B.headerFont).foregroundStyle(B.headerColor)
                    .padding(.horizontal, B.rowPaddingH)
                    .padding(.bottom, B.headerBottom)
                    .frame(maxWidth: .infinity, minHeight: O.sectionHeader, maxHeight: O.sectionHeader, alignment: .bottomLeading)
                ForEach(section.chats) { chat in
                    OpenChatRow(model: model, chat: chat,
                                reason: section.suggested ? "\(chat.folder) · " + L("Last sent here, 4m ago") : nil,
                                query: model.chatPickerQuery)
                        .frame(height: O.row)
                }
            }
        }
        if model.offscreenRender {
            list.frame(maxHeight: .infinity, alignment: .top).clipped()
        } else {
            ScrollView { list }.scrollIndicators(.automatic)
        }
    }

    /// As tall as the list down to its fifth chat (the headers before it included); past that it
    /// scrolls.
    @MainActor
    static func height(model: WorkbenchModel) -> CGFloat {
        let O = WorkbenchTokens.OpenChat.self
        let sections = model.chatPickerSections
        if sections.isEmpty { return O.row }
        var height: CGFloat = 0
        var rows = 0
        for section in sections where rows < O.rowsVisible {
            height += O.sectionHeader
            let take = min(section.chats.count, O.rowsVisible - rows)
            height += CGFloat(take) * O.row
            rows += take
        }
        return height
    }
}

// MARK: - A chat opened from the search

/// In place of an answer, for a chat opened with nothing sent from Fovea yet: when it was last
/// active, and that what's asked below goes into it.
struct OpenedChatBody: View {
    let task: AgentTaskItem

    var body: some View {
        let B = WorkbenchTokens.Board.self
        let V = WorkbenchTokens.V2.self
        let since = AgentBoard.duration(task.age).map { L("Last active \($0) ago in \(task.project).") } ?? ""
        V2CaseStatus(symbol: "bubble.left", text: since + " " + L("Ask below: it goes into this chat."), color: V.bodyColor) { EmptyView() }
            .frame(height: B.workingLine)
    }
}

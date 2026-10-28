import SwiftUI
import AppKit
import FoveaCore
import FoveaLook
import FoveaKit

// Oct 6 feedback (docs/island/FEEDBACK_2026-10-06.md):
// - The control board (#9–10, #17), round three: every session on the Mac as a two-line row led
//   by its agent's icon (who, at a glance), its title over one quieter line (what it asks, what
//   came back, or its project), and one trailing column (how long, or Allow and Deny in place).
//   Parted by state, as Claude Code's agent view parts its sessions: Needs you, Done, Running,
//   Status unavailable. Two designs to compare: Sections (a glyph and a word over each part) and
//   Badges (the state on the icon's corner). Only what the agents reliably report; no counts.
// - A session opened: the request, then while it works one quiet line (a ring, Working, the
//   time); done, its work folded, the answer as written, what to open. Under it, Open in the
//   agent's app and Answer again (Stop while it works), then a box to ask more.

// MARK: Geometry

/// The board: its groups of rows, a gap and a hairline between them, down to the last whole row of
/// six; past that it scrolls. Oct 27, Ryan ("only have the latest version that I approved"): the one
/// design, the list with each state on a badge at its icon, under Open any chat's greeting, search
/// and pinned chats (Feedback/OpenChat.swift).
struct V2BoardLayout: Equatable {
    var outline: StackLayout.Outline
    var listHeight: CGFloat
    var scrolls: Bool
    /// Oct 15 review, NH-03: a "Remembered" row over the list, while there is one.
    var notice: CGFloat = 0
    /// Oct 24, Ryan: an Open any chat design's blocks, top to bottom (Feedback/OpenChat.swift).
    var openChat: [OpenChatPart] = []

    static func make(sections: [Int], metrics: ScreenMetrics) -> V2BoardLayout {
        let B = WorkbenchTokens.Board.self
        let spec = WorkbenchTokens.Island.spec
        var (visible, full) = heights(sections: sections, rows: B.rowsVisible)
        // Nothing running: the greeting's room.
        if sections.reduce(0, +) == 0 { visible = B.helloHeight }
        let height = V2Geometry.top(metrics) + visible + B.paddingBottom
        return V2BoardLayout(outline: StackLayout.Outline(size: CGSize(width: B.width, height: height),
                                                          topRadius: spec.expandedTopRadius, bottomRadius: B.bottomRadius),
                             listHeight: visible, scrolls: full > visible + 0.5)
    }

    /// The board for the sessions on it: room for "Remembered" over the list, and Open any chat's
    /// parts round it.
    @MainActor
    static func board(model: WorkbenchModel, metrics: ScreenMetrics) -> V2BoardLayout {
        var layout = V2BoardLayout.make(sections: model.v2BoardGroups.map(\.count), metrics: metrics)
        // Oct 15 review, NH-03: room for "Remembered" over the list.
        if model.cases.memoryNotice != nil {
            layout.notice = WorkbenchTokens.Cases.memoryRow
            layout.outline.size.height += layout.notice
        }
        // Oct 24, Ryan: open any chat, pinned chats and the search on the board (OpenChat.swift).
        if model.boardSearchShown { return .openChat(model: model, metrics: metrics, base: layout) }
        return layout
    }

    /// The list down to its `rows`th row (the seam before each group included), and the whole
    /// list.
    static func heights(sections: [Int], rows limit: Int) -> (visible: CGFloat, full: CGFloat) {
        let B = WorkbenchTokens.Board.self
        var full: CGFloat = 0, visible: CGFloat = 0, rows = 0
        for (i, count) in sections.enumerated() {
            let lead = lead(first: i == 0)
            full += lead
            if rows < limit { visible += lead }
            for _ in 0..<count {
                full += B.row
                if rows < limit { visible += B.row }
                rows += 1
            }
        }
        return (visible, full)
    }

    /// What comes before a group: the seam (none before the first).
    static func lead(first: Bool) -> CGFloat {
        first ? 0 : WorkbenchTokens.Board.groupGap
    }

    static var contentX: CGFloat { WorkbenchTokens.Island.spec.expandedTopRadius + WorkbenchTokens.Board.paddingH }
    static var contentWidth: CGFloat { WorkbenchTokens.Board.width - 2 * contentX }
}

/// A session opened in the notch: header, the request, the response, what waits, the bar (Open in
/// its app; Answer again or Stop), the box to ask more, the grab bar. Expanded (Oct 7,
/// docs/island/WHOLE_SESSION.md), it holds the whole session, every exchange in it (V2History.swift):
/// wider, as tall as it needs down to the display's foot, the words in one centred column
/// (`V2.readingMeasure`), the room going to both sides; the header keeps the panel's edges.
struct V2ChatLayout: Equatable {
    var outline: StackLayout.Outline
    var question: CGFloat
    var body: CGFloat
    var scrolls: Bool
    var textWidth: CGFloat
    var queue: CGFloat = 0
    /// The header's width, between the panel's margins.
    var contentWidth: CGFloat = V2Geometry.contentWidth
    var expanded = false
    var questionLines = 2
    var size: V2SessionSize = .usual
    /// The words' column: how wide, and where it starts from the panel's left edge.
    var column: CGFloat = V2Geometry.contentWidth
    var columnX: CGFloat = V2Geometry.contentX
    /// The usual size drawing the session's exchanges (it was asked more than once).
    var history = false
    /// The bar and the box: the column's width, or with the exchanges at the usual size the
    /// content's (the outline's gutter is the words' only).
    var barWidth: CGFloat { history ? contentWidth : column }

    @MainActor
    static func make(model: WorkbenchModel, task: AgentTaskItem?, followed: String? = nil, metrics: ScreenMetrics) -> V2ChatLayout {
        let V = WorkbenchTokens.V2.self
        let F = WorkbenchTokens.FeedbackV2.self
        let B = WorkbenchTokens.Board.self
        let expanded = model.v2Size == .expanded && task != nil
        let panelWidth = expanded ? min(V.expandedWidth, model.display.frame.width - 2 * V.readingSideMargin) : V.width
        let width = panelWidth - 2 * V2Geometry.contentX
        // Usual, the column is the content's width; expanded, the reading measure, centred.
        let column = expanded ? min(V.readingMeasure, width) : width
        let columnX = (panelWidth - column) / 2
        let queued = task.map { V2QueueSection.height(count: model.v2Queue[$0.id]?.count ?? 0) } ?? 0
        let queue = queued > 0 ? queued + V.gap : 0
        if expanded, let task {
            // The header and its rule; the history (every exchange, its margins inside it), as tall
            // as it is, down to the display's foot; a rule as the header's; what waits; the bar;
            // the box.
            let fixed = V.chatHeader + V.headerRule + V.headerRule + V.gap + queue + B.actionRow + B.inputGap + V.inputHeight + V.gap
            let room = model.display.frame.height - V.readingBottomMargin - V2Geometry.top(metrics) - fixed - V.grabArea
            let full = V2SessionHistory.height(model: model, task: task, width: column)
            let history = min(full, room)
            return V2ChatLayout(outline: V2Geometry.outline(content: fixed + history, bottom: V.grabArea, width: panelWidth, metrics: metrics),
                                question: 0, body: history, scrolls: full > room + 0.5, textWidth: column, queue: queued,
                                contentWidth: width, expanded: true, questionLines: 0, size: .expanded, column: column, columnX: columnX)
        }
        // Usual, a session asked more than once shows its exchanges (the last answer stays in view
        // while the next one works: Oct 9, evening), as tall as the usual body, at the latest.
        // Oct 24, Ryan: the outline at its right too (Notion's), in a gutter the words leave it.
        if let task, !(model.v2History[task.id] ?? []).isEmpty {
            let fixed = V.chatHeader + V.headerRule + queue + B.actionRow + B.inputGap + V.inputHeight + V.gap
            let column = width - V.outlineGutter
            let columnX = V2Geometry.contentX
            let full = V2SessionHistory.height(model: model, task: task, width: column)
            let room = F.chatBodyMax + V.chatHeader
            let history = min(full, room)
            return V2ChatLayout(outline: V2Geometry.outline(content: fixed + history, bottom: V.grabArea, width: panelWidth, metrics: metrics),
                                question: 0, body: history, scrolls: full > room + 0.5, textWidth: column, queue: queued,
                                contentWidth: width, expanded: false, questionLines: 0, size: .usual, column: column,
                                columnX: columnX, history: true)
        }
        let lines = 2
        // Oct 24, Ryan: a chat opened from the search, nothing sent from Fovea yet: no request, a
        // line in the answer's place (OpenChat.swift).
        let opened = task.map { model.isBlankChat($0.id) } ?? false
        let question = opened ? 0 : V2RequestBubble.height(followed ?? task?.request ?? "", width: column, lines: lines)
        var full: CGFloat = B.workingLine
        if let task, !opened {
            // Oct 15 review: reopening, gone, not sure it arrived, what was decided; what it asks.
            if let kind = model.v2CaseBody(task) {
                full = V2CaseBodyView.height(model: model, task: task, kind: kind, width: column)
            } else {
                switch task.state {
                case .working: full = B.workingLine
                case .needsYou: full = V2NeedsYouBody.height(model: model, task: task, width: column)
                case .complete, .failed: full = V2Answer.height(model: model, task: task, width: column)
                }
            }
        }
        // The header and its rule; the question and a rule; the body; what waits; the bar; the box.
        let fixed = V.chatHeader + V.headerRule + (opened ? 0 : V.gap + question + (V.gap + 1)) + V.gap + V.gap + queue
            + B.actionRow + B.inputGap + V.inputHeight + V.gap
        let body = min(full, F.chatBodyMax)
        return V2ChatLayout(outline: V2Geometry.outline(content: fixed + body, bottom: V.grabArea, width: panelWidth, metrics: metrics),
                            question: question, body: body, scrolls: full > F.chatBodyMax + 0.5,
                            textWidth: column, queue: queued, contentWidth: width, expanded: false, questionLines: lines,
                            size: .usual, column: column, columnX: columnX)
    }
}

// MARK: The board

/// The board: the list, and with Open any chat on, its greeting, search and pinned chats round it.
/// Oct 27, Ryan: the one design ("only have the latest version that I approved"); Sections, Focus,
/// Capsules, Wings, Split, the pets and the four drafts are gone.
struct V2BoardContent: View {
    let model: WorkbenchModel
    let layout: V2BoardLayout

    @ViewBuilder var body: some View {
        if model.boardSearchShown { OpenChatBoard(model: model, layout: layout) } else { V2BoardList(model: model, layout: layout) }
    }
}

/// The board as a list: Needs you (a question, then a failure), Done (not yet opened), Running,
/// and the sessions whose state can't be read. A click opens one; ↑↓ and Return work as in a menu.
/// A session changing state moves to its section on a spring.
struct V2BoardList: View {
    let model: WorkbenchModel
    let layout: V2BoardLayout
    /// The top of a board's scroll, for `v2ScrollTarget` to scroll back to (the snapshots do,
    /// before each shot).
    static let topID = "v2-board-top"

    var body: some View {
        let B = WorkbenchTokens.Board.self
        let sections = model.v2BoardSections
        // Oct 15 review, NH-03: a "Remembered" row over the list, the list below it.
        let top = V2Geometry.top(model.metrics) + layout.notice
        ZStack(alignment: .topLeading) {
            Color.clear
            if let notice = model.cases.memoryNotice, layout.notice > 0 {
                V2MemoryRow(model: model, notice: notice)
                    .frame(width: V2BoardLayout.contentWidth, height: layout.notice)
                    .offset(x: V2BoardLayout.contentX, y: V2Geometry.top(model.metrics))
                    .transition(.opacity)
            }
            if sections.isEmpty {
                V2BoardHello(name: model.greetingName)
                    .frame(width: V2BoardLayout.contentWidth, height: layout.listHeight)
                    .offset(x: V2BoardLayout.contentX, y: top)
            } else if model.offscreenRender {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(sections.enumerated()), id: \.element.section) { i, part in
                        lead(part, first: i == 0)
                        ForEach(part.tasks) { task in
                            V2BoardRow(model: model, task: task, focused: model.v2Focus == task.id)
                                .frame(height: B.row)
                        }
                    }
                }
                .frame(width: V2BoardLayout.contentWidth, height: layout.listHeight, alignment: .top)
                .clipped()
                .offset(x: V2BoardLayout.contentX, y: top)
            } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 0).id(V2BoardList.topID)
                        ForEach(Array(sections.enumerated()), id: \.element.section) { i, part in
                            lead(part, first: i == 0)
                            ForEach(part.tasks) { task in
                                V2BoardRow(model: model, task: task, focused: model.v2Focus == task.id)
                                    .frame(height: B.row)
                                    .id(task.id)
                            }
                        }
                    }
                    .animation(model.snapshotMode ? nil : B.move, value: model.v2BoardOrder.map(\.id))
                }
                .scrollDisabled(!layout.scrolls)
                .scrollIndicators(layout.scrolls ? .automatic : .never)
                .onChange(of: model.v2ScrollTarget) { _, id in if let id { proxy.scrollTo(id) } }
            }
            .frame(width: V2BoardLayout.contentWidth, height: layout.listHeight)
            .offset(x: V2BoardLayout.contentX, y: top)
            }
        }
        .frame(width: layout.outline.size.width, height: layout.outline.size.height, alignment: .topLeading)
        .panelScheme()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sessions")
    }

    /// Before a group: a gap with a hairline in it (none before the first).
    @ViewBuilder
    private func lead(_ part: (section: BoardSection, tasks: [AgentTaskItem]), first: Bool) -> some View {
        let B = WorkbenchTokens.Board.self
        if !first {
            Rectangle().fill(B.hairline).frame(height: 0.5)
                .padding(.horizontal, B.rowPaddingH)
                .frame(height: V2BoardLayout.lead(first: first))
        }
    }
}

/// A row: the agent's icon, its state on the icon's corner; the title over one line
/// (what it asks, in amber; why it failed; the answer's first sentence; its project); at the
/// right, Allow and Deny in place, or the ring and how long it has run (under the pointer, Stop),
/// or how long since it finished (under the pointer, a chevron: it opens). A session whose state
/// can't be read is dimmed, its icon gray, with when it was last active.
struct V2BoardRow: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let focused: Bool
    @State private var hovering = false

    var body: some View {
        let B = WorkbenchTokens.Board.self
        HStack(spacing: B.iconGap) {
            V2BoardIcon(model: model, task: task)
            VStack(alignment: .leading, spacing: B.lineGap) {
                Text(model.v2Title(task)).font(B.titleFont).foregroundStyle(task.statusUnknown ? B.dimTitle : B.title).lineLimit(1)
                if task.state == .working && !task.statusUnknown {
                    V2StepLine(model: model, task: task, size: B.lineSize)
                } else {
                    line
                        .font(B.lineFont)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing
                .fixedSize()
                .frame(minWidth: task.state == .needsYou ? 0 : B.trailingWidth, alignment: .trailing)
        }
        .padding(.horizontal, B.rowPaddingH)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: B.rowRadius, style: .continuous)
            .fill(hovering || focused ? B.highlight : .clear)
            .animation(nil, value: focused))
        .contentShape(Rectangle())
        .onHover { inside in
            hovering = inside
            model.hoverV2(task.id, inside)
        }
        .onTapGesture { model.openV2(task.id) }
        .help("\(ChatAgent.named(task.agent).name) · \(task.project)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.v2Title(task)), \(ChatAgent.named(task.agent).name), \(word), \(model.v2BoardLine(task))")
        .accessibilityAction { model.openV2(task.id) }
    }

    /// The second line: a question in amber, its command set in code; a failure's word in red
    /// before why; otherwise the line in the quieter ink.
    private var line: Text {
        let B = WorkbenchTokens.Board.self
        let text = model.v2BoardLine(task)
        if task.statusUnknown { return Text(text).foregroundColor(B.time) }
        switch task.state {
        case .needsYou:
            let amber = WorkbenchTokens.Panel.needsYouColor
            if case .approval(let command) = task.ask, let range = text.range(of: command) {
                return Text(text[..<range.lowerBound]).foregroundColor(amber)
                    + Text(command).font(B.commandFont).foregroundColor(amber)
                    + Text(text[range.upperBound...]).foregroundColor(amber)
            }
            return Text(text).foregroundColor(amber)
        case .failed:
            return Text("Failed").font(B.wordFont).foregroundColor(WorkbenchTokens.Panel.failedColor)
                + Text(" · \(text)").foregroundColor(B.line)
        case .working, .complete:
            return Text(text).foregroundColor(B.line)
        }
    }

    @ViewBuilder private var trailing: some View {
        let B = WorkbenchTokens.Board.self
        if task.statusUnknown {
            chevron.opacity(hovering ? 1 : 0)
        } else {
            switch task.state {
            case .needsYou:
                AgentControls(model: model, task: task, shown: true)
            case .working:
                HStack(spacing: B.trailingGap) {
                    if hovering {
                        Button { model.stopTask(task.id) } label: { StopRing(size: B.ring) }
                            .buttonStyle(IslandPressStyle())
                            .help("Stop")
                    }
                    Text(model.v2RunTime(task)).font(B.timeFont).foregroundStyle(B.time).monospacedDigit()
                }
            case .complete, .failed:
                if hovering {
                    // Its answer at the reading size, straight from the board; a click on the row
                    // opens the session at its usual size.
                    NotchIconButton(symbol: "arrow.up.left.and.arrow.down.right", glyph: B.chevron, size: B.expandButton,
                                    help: L("Expand its answer")) {
                        model.openV2(task.id, expanded: true)
                    }
                } else {
                    Text(model.v2Since(task)).font(B.timeFont).foregroundStyle(B.time).monospacedDigit()
                }
            }
        }
    }

    private var chevron: some View {
        let B = WorkbenchTokens.Board.self
        return Image(systemName: "chevron.right").font(B.chevron).foregroundStyle(B.done)
    }

    private var word: String {
        // Oct 18, Ryan: in the primary language.
        if task.statusUnknown { return L("status unavailable") }
        return task.state == .working ? L("running, \(model.v2RunTime(task))") : task.stateWord
    }
}

/// The agent's icon, the state on its corner, cut out of it by the island's black:
/// amber with "!", waiting on the person; red with a cross, failed; white with a check, done; dark
/// with the turning ring, running. A session whose state can't be read: gray and faint, no badge.
struct V2BoardIcon: View {
    let model: WorkbenchModel
    let task: AgentTaskItem

    var body: some View {
        let B = WorkbenchTokens.Board.self
        ChatAgentIcon(agent: ChatAgent.named(task.agent), size: B.badgedIcon)
            .saturation(task.statusUnknown ? B.dimSaturation : 1)
            .opacity(task.statusUnknown ? B.dimOpacity : 1)
            .overlay(alignment: .bottomTrailing) {
                if !task.statusUnknown {
                    badge.offset(x: B.badgeOffset, y: B.badgeOffset)
                }
            }
            // The badge's ring cuts through the icon to what's under it (Native's glass).
            .compositingGroup()
    }

    private var badge: some View {
        let B = WorkbenchTokens.Board.self
        let P = WorkbenchTokens.Panel.self
        return ZStack {
            Circle().fill(Color.black).frame(width: B.badge + 2 * B.badgeRing, height: B.badge + 2 * B.badgeRing)
                .blendMode(WorkbenchTokens.isNative ? .destinationOut : .normal)
            switch task.state {
            case .needsYou: mark("exclamationmark", on: P.needsYouColor)
            case .failed: mark("xmark", on: P.failedColor)
            case .complete: mark("checkmark", on: P.completeColor)
            case .working:
                Circle().fill(WorkbenchTokens.ink(0.14)).frame(width: B.badge, height: B.badge)
                AgentStateGlyph(task: task, size: B.badge - 4, paused: model.snapshotMode)
            }
        }
    }

    private func mark(_ symbol: String, on color: Color) -> some View {
        let B = WorkbenchTokens.Board.self
        return ZStack {
            Circle().fill(color)
            Image(systemName: symbol).font(B.badgeGlyph).foregroundStyle(WorkbenchTokens.skin(Color.black, Color.white))
        }
        .frame(width: B.badge, height: B.badge)
    }
}

/// Stop, where the running ring was: a ring with a square in it, as Finder and the App Store stop a
/// download in place.
struct StopRing: View {
    let size: CGFloat
    @State private var hovering = false

    var body: some View {
        ZStack {
            Circle().strokeBorder(WorkbenchTokens.ink(hovering ? 0.95 : 0.7), lineWidth: 1.3)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(WorkbenchTokens.ink(hovering ? 0.95 : 0.7))
                .frame(width: size * 0.36, height: size * 0.36)
        }
        .frame(width: size + 2, height: size + 2)
        .contentShape(Circle())
        .onHover { hovering = $0 }
    }
}

// MARK: The session

/// A session opened: its agent and title; the request; while it works, one quiet line (the ring,
/// Working, the time it has run); done, its work folded, the answer as written, what to open; what
/// waits; Open in its app, and Answer again (or Stop); the box to ask more; the grab bar.
struct V2ChatContent: View {
    let model: WorkbenchModel
    let layout: V2ChatLayout

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let B = WorkbenchTokens.Board.self
        ZStack(alignment: .topLeading) {
            Color.clear
            if let task = model.v2FocusTask {
                VStack(alignment: .leading, spacing: 0) {
                    header(task).frame(height: V.chatHeader)
                    Rectangle().fill(V.headerRuleColor).frame(width: layout.contentWidth, height: V.headerRule)
                    if layout.history {
                        V2SessionHistory(model: model, task: task, layout: layout)
                            .frame(width: layout.contentWidth, height: layout.body)
                    } else if layout.size == .expanded {
                        // Every exchange, the outline in the right margin; under it a rule as the
                        // header's, so what scrolls passes under the two rules.
                        V2SessionHistory(model: model, task: task, layout: layout)
                            .frame(width: layout.contentWidth, height: layout.body)
                        Rectangle().fill(V.headerRuleColor).frame(width: layout.contentWidth, height: V.headerRule)
                            .padding(.bottom, V.gap)
                    } else {
                        let opened = model.isBlankChat(task.id)
                        // Oct 15 review, QA07: the request, editable in place once it's answered.
                        if !opened {
                            // Oct 24, Ryan: the request in its bubble at the right, the answer open
                            // under it at the left.
                            let asked = model.v2Followed[task.id] ?? task.request
                            V2EditableQuestion(model: model, task: task, lines: layout.questionLines,
                                               beside: V2RequestBubble.bubbleWidth(asked, width: layout.column)) {
                                V2RequestBubble(text: asked, width: layout.column, lines: layout.questionLines)
                            }
                            .frame(width: layout.column, height: layout.question, alignment: .topTrailing)
                            .padding(.top, V.gap)
                            .padding(.bottom, V.gap)
                            .padding(.leading, lead)
                            rule.padding(.leading, lead)
                        }
                        Group {
                            if opened {
                                OpenedChatBody(task: task)
                            } else if let kind = model.v2CaseBody(task) {
                                V2CaseBodyView(model: model, task: task, kind: kind, width: layout.textWidth)
                            } else {
                            switch task.state {
                            case .working:
                                V2WorkingLine(model: model, task: task)
                            case .needsYou:
                                V2Response(model: model, task: task, width: layout.textWidth)
                            case .complete, .failed:
                                if layout.scrolls {
                                    ScrollView { V2Answer(model: model, task: task, width: layout.textWidth) }
                                        .scrollIndicators(.automatic)
                                } else {
                                    V2Answer(model: model, task: task, width: layout.textWidth)
                                }
                            }
                            }
                        }
                        .frame(width: layout.textWidth, height: layout.body, alignment: .topLeading)
                        .padding(.vertical, V.gap)
                        .padding(.leading, lead)
                    }
                    if layout.queue > 0 {
                        V2QueueSection(model: model, task: task, width: layout.textWidth)
                            .frame(height: layout.queue, alignment: .top)
                            .padding(.bottom, V.gap)
                            .padding(.leading, lead)
                    }
                    V2SessionBar(model: model, task: task)
                        .frame(width: layout.barWidth, height: B.actionRow)
                        .padding(.leading, lead)
                    // Oct 15 review, QA25: read only, or gone: a line where the box was.
                    Group {
                        if model.cases.readOnly.contains(task.id) || model.cases.gone.contains(task.id) {
                            V2ReadOnlyLine(model: model, task: task)
                        } else {
                            V2FollowUpField(model: model, id: task.id)
                        }
                    }
                    .frame(width: layout.barWidth)
                    .padding(.top, B.inputGap)
                    .padding(.leading, lead)
                }
                .frame(width: layout.contentWidth, alignment: .topLeading)
                .offset(x: V2Geometry.contentX, y: V2Geometry.top(model.metrics))
                .opacity(model.v2DragOut == nil ? 1 : 0.25)
                grabBar(task)
            }
        }
        .frame(width: layout.outline.size.width, height: layout.outline.size.height, alignment: .topLeading)
        .contentShape(Rectangle())
        .onHover { model.setV2ChatHovered($0) }
        .panelScheme()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.v2FocusTask.map { model.v2Title($0) } ?? "")
    }

    private var rule: some View {
        Rectangle().fill(WorkbenchTokens.V2.rule).frame(width: layout.column, height: 1)
    }

    /// Where the words' column starts, inside the content (none at the usual size).
    private var lead: CGFloat { layout.columnX - V2Geometry.contentX }

    private func header(_ task: AgentTaskItem) -> some View {
        let V = WorkbenchTokens.V2.self
        let quick = task.project == DispatchV2.quickProject
        return HStack(spacing: V.headerSpacing) {
            // The way out to the board: from it, back; expanded, always (docs/island/WHOLE_SESSION.md),
            // to the control board, however the session was opened.
            if layout.size == .expanded {
                NotchIconButton(symbol: "chevron.left", glyph: V.backGlyph, size: V.backSize,
                                help: L("All sessions: back to the control board")) {
                    model.exitV2ToBoard()
                }
                .accessibilityLabel("Back to all sessions")
            } else if model.v2ChatFromBoard {
                NotchIconButton(symbol: "chevron.left", glyph: V.backGlyph, size: V.backSize, help: L("Back to the board (esc)")) {
                    model.closeV2Chat()
                }
            }
            ChatAgentIcon(agent: ChatAgent.named(task.agent), size: V.headerIcon)
            Text(model.v2Title(task))
                .font(V.headerTitle)
                .foregroundStyle(V.titleColor)
                .lineLimit(1)
            // Oct 15 review, QA16/QA25: the connection when it isn't fine, or read only, in the
            // badge's place.
            if V2HeaderPill.shown(model, task) {
                V2HeaderPill(model: model, task: task)
            } else {
                V2Badge(text: quick ? L("Quick answer") : task.project)
            }
            Spacer()
            // Expand (the shipping app's expand key, left ⌃): the whole session; and back. A chat
            // opened from the search with nothing sent yet has nothing to expand.
            if !model.isBlankChat(task.id),
               task.state == .complete || task.state == .failed || layout.size == .expanded || !(model.v2History[task.id] ?? []).isEmpty {
                switch layout.size {
                case .usual:
                    NotchIconButton(symbol: "arrow.up.left.and.arrow.down.right", glyph: V.expandGlyph, size: V.closeSize,
                                    help: L("Expand: every request in this session, and what the agent did (⌃)")) { model.setV2Size(.expanded) }
                        .accessibilityLabel("Expand")
                case .expanded:
                    NotchIconButton(symbol: "arrow.down.right.and.arrow.up.left", glyph: V.expandGlyph, size: V.closeSize,
                                    help: L("Back to its usual size (esc)")) { model.setV2Size(.usual) }
                        .accessibilityLabel("Back to the usual size")
                }
            }
            // Oct 15 review, QA23: closing never stops; a session at work keeps working, on the board.
            NotchIconButton(symbol: "xmark", glyph: V.closeGlyph, size: V.closeSize,
                            help: task.state == .working ? "Close (esc). It keeps working, on the board" : "Close (esc)") {
                model.closeV2Chat()
            }
        }
    }

    /// The grab bar: pulled down out of the notch, the chat comes out as a window that follows
    /// the pointer; let go, it stays there and the notch is the board again.
    private func grabBar(_ task: AgentTaskItem) -> some View {
        let V = WorkbenchTokens.V2.self
        return Capsule()
            .fill(V.grabColor)
            .frame(width: V.grabSize.width, height: V.grabSize.height)
            .frame(width: V.grabHitWidth, height: V.grabArea)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 2, coordinateSpace: .named(ScreenSpace.name))
                .onChanged { value in
                    if model.v2DragOut != nil || value.translation.height > V.pullThreshold {
                        model.dragOutV2(task.id, to: value.location)
                    }
                }
                .onEnded { value in
                    if model.v2DragOut != nil { model.endDragOutV2(task.id, at: value.location) }
                })
            .help("Pull it out of the notch")
            .position(x: layout.outline.size.width / 2, y: layout.outline.size.height - V.grabArea / 2)
            .accessibilityLabel("Pull out")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.endDragOutV2(task.id, at: CGPoint(x: model.display.frame.width - 220, y: 260)) }
    }
}

/// While it works: the ring, what it is doing now (one step at a time, as the agent reports it), and
/// how long it has run. A session whose state can't be read says so, with no ring.
struct V2WorkingLine: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    /// Oct 21, perf: its band is showing (MockIsland's `BandShown`); its clock pauses when not.
    @Environment(\.islandBandShown) private var bandShown

    var body: some View {
        let B = WorkbenchTokens.Board.self
        HStack(spacing: B.workingGap) {
            if task.statusUnknown {
                Text("Status unavailable").font(B.workingFont).foregroundStyle(B.time)
                Spacer()
                Text(AgentBoard.duration(task.age).map { L("last active \($0) ago") } ?? "")
                    .font(B.timeFont).foregroundStyle(B.time)
            } else {
                AgentStateGlyph(task: task, size: B.workingGlyph, paused: model.snapshotMode)
                V2StepLine(model: model, task: task, size: B.workingSize)
                Spacer(minLength: 8)
                // Oct 21, perf: ticks only while the board shows (each tick laid the layer out).
                TimelineView(.periodic(from: .now, by: bandShown ? 1 : WorkbenchTokens.Motion.hiddenTick)) { _ in
                    Text(model.v2RunTime(task, clock: true)).font(B.timeFont).foregroundStyle(B.time).monospacedDigit()
                }
            }
        }
        .frame(height: B.workingLine)
    }
}

/// Under a session: Open in its agent at the left; at the right, Stop while it works, Answer again
/// once it is done, the answer to its question when it waits on the person. Oct 15 review: Copy
/// Answer (DSP-18); while the request is edited, Cancel and Send (QA07); a moment's line after
/// (QA20, QA26). Oct 17, Ryan: "don't have Continue, have Open in agent": one Open in <agent> chip,
/// the session's own agent, in place of the link and Continue in… (QA26). Where it's narrow (a
/// pulled-out chat), the chips keep their glyphs only.
struct V2SessionBar: View {
    let model: WorkbenchModel
    let task: AgentTaskItem

    var body: some View {
        Group {
            if model.cases.editing == task.id {
                V2EditBar(model: model, task: task)
            } else if let line = model.cases.barLines[task.id] {
                V2BarLineView(line: line)
            } else {
                ViewThatFits(in: .horizontal) {
                    controls(compact: false)
                    controls(compact: true)
                }
            }
        }
        .animation(WorkbenchTokens.Cases.change, value: model.cases.editing)
        .animation(WorkbenchTokens.Cases.change, value: model.cases.barLines[task.id])
    }

    private func controls(compact: Bool) -> some View {
        let gone = model.cases.gone.contains(task.id)
        let readOnly = model.cases.readOnly.contains(task.id)
        let mine = !gone && !readOnly
        return HStack(spacing: WorkbenchTokens.Panel.buttonGap) {
            // Oct 17, Ryan: one way to the agent, the same chip in the notch and pulled out.
            if model.v2OpensInAgent(task) {
                V2OpenInAgentChip(model: model, task: task, iconOnly: compact)
            }
            Spacer(minLength: 6)
            switch task.state {
            case .needsYou:
                if model.cases.forms[task.id] != nil {
                    // Oct 15 review, QA15: the few answers go together.
                    let complete = model.v2FormComplete(task.id)
                    AgentPanelButton(title: L("Send Answers"), primary: true) { model.answerFormV2(task.id) }
                        .disabled(!complete)
                        .opacity(complete ? 1 : 0.5)
                } else if case .approval? = task.ask {
                    if model.cases.approvalFiles[task.id]?.isEmpty == false {
                        // Oct 15 review, QA14: an edit to approve: Allow, not a command's verb.
                        AgentPanelButton(title: L("Deny"), primary: false) { model.denyTask(task.id) }
                        AgentPanelButton(title: L("Allow"), primary: true) { model.allowTask(task.id) }
                    } else {
                        AgentControls(model: model, task: task, shown: true)
                    }
                }
                // A question's choices and own answer are in the body.
            case .working:
                if !task.statusUnknown, model.cases.unconfirmed[task.id] == nil {
                    // Oct 15 review, DSP-24: only Stop stops (closing never does).
                    V2IconChip(symbol: "stop.fill", title: L("Stop")) { model.stopTask(task.id) }
                        .help("Stop the agent here")
                }
            case .failed:
                if gone {
                    // Oct 15 review, QA25: the request again, in a new chat.
                    AgentPanelButton(title: L("Ask in a New Chat"), symbol: "plus", primary: true) { model.askInNewChatV2(task.id) }
                } else {
                    AgentPanelButton(title: L("Retry"), symbol: "arrow.clockwise", primary: false) { model.retryTask(task.id) }
                }
            case .complete:
                // Opened from the search with nothing in it: no answer to copy or answer again.
                if !model.isBlankChat(task.id) {
                    V2CopyAnswerChip(model: model, task: task, iconOnly: compact)
                    if mine { V2ReanswerMenu(model: model, task: task, iconOnly: compact) }
                }
            }
        }
    }
}

/// ✕ and back in a session's header: the glyph alone, in a circle the pointer can hit, with no plate
/// at rest or under the pointer. Oct 21, Ryan ("simpler is better"): the glyph no longer bounces as
/// the pointer comes.
struct NotchIconButton: View {
    let symbol: String
    let glyph: Font
    let size: CGFloat
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(glyph)
                .foregroundStyle(WorkbenchTokens.V2.subColor)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(IslandPressStyle())
        .help(help)
    }
}

// MARK: The voice bar's chat, model and effort (#19)

/// With the review off, one icon on the voice bar opens the chat's settings: where the request goes
/// (as Dispatch chooses a chat: the suggestions, every chat by agent and project), the model and how
/// hard it thinks. A plain settings glyph, not an agent's mark. The bar keeps the notch's width.
struct V2RouteButton: View {
    let model: WorkbenchModel
    @State private var hovering = false

    var body: some View {
        let pick = model.v2Pick
        Button { model.toggleModelSheet() } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(WorkbenchTokens.ink(hovering || model.v2RouteOpen ? 0.95 : 0.7))
                .frame(width: WorkbenchTokens.Board.routeIcon + 8, height: WorkbenchTokens.Board.routeIcon + 8)
                .background(Circle().fill(WorkbenchTokens.ink(hovering || model.v2RouteOpen ? 0.16 : 0.08)))
        }
        .buttonStyle(IslandPressStyle())
        .onHover { hovering = $0 }
        .help("\(pick.title) · \(model.v2ModelLabel(agent: pick.agent)). Click to change where it goes")
        .accessibilityLabel("Where it goes: \(pick.title)")
    }
}

/// The sheet under the voice bar: the suggestions; every chat, as Dispatch's rail of agents, their
/// projects, a project's chats; then the model and the effort.
struct V2RouteSheet: View {
    let model: WorkbenchModel

    var body: some View {
        let V = WorkbenchTokens.V2.self
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: V.chipGap) {
                Text("Suggested").font(V.labelFont).foregroundStyle(V.labelColor).padding(.trailing, V.labelTrailing)
                ForEach(model.v2Suggestions) { pick in
                    V2SuggestionChip(model: model, pick: pick, chosen: model.v2Pick == pick)
                }
                Spacer(minLength: 0)
            }
            .frame(height: V.chipRow)
            V2ChatBrowser(model: model)
                .frame(height: V2RouteSheet.browserHeight(rows: model.v2BrowseRows.count), alignment: .top)
            Rectangle().fill(V.rule).frame(height: 1).padding(.vertical, V.sheetRuleGap)
            V2ModelSheet(model: model)
        }
        .frame(width: V2Geometry.contentWidth, alignment: .topLeading)
    }

    static func browserHeight(rows: Int, suggestions: Bool = false) -> CGFloat {
        let V = WorkbenchTokens.V2.self
        return V.gap - V.browseSpacing + 1 + V.browseSpacing + V.railHeight + V.browseSpacing
            + CGFloat(min(rows, V.browseRowsVisible)) * V.browseRow
            + (suggestions ? V.chipRow + V.browseSpacing : 0)
    }

    /// The sheet's height under the bar.
    @MainActor
    static func height(model: WorkbenchModel) -> CGFloat {
        let V = WorkbenchTokens.V2.self
        return V.chipRow + browserHeight(rows: model.v2BrowseRows.count) + 1 + 2 * V.sheetRuleGap
            + V2ModelSheet.height(chats: false, notes: model.v2ModelNotes.count)
    }
}

/// The board with nothing running, on the real Mac (Oct 9, evening): a greeting, never an empty
/// panel. "Hello, Ryan." over "Start building here."
struct V2BoardHello: View {
    let name: String

    var body: some View {
        let B = WorkbenchTokens.Board.self
        let who = name.trimmingCharacters(in: .whitespaces)
        VStack(alignment: .leading, spacing: B.lineGap) {
            Text(who.isEmpty ? "Hello." : "Hello, \(who).")
                .font(B.titleFont)
                .foregroundStyle(B.title)
            Text(B.helloLead)
                .font(B.lineFont)
                .foregroundStyle(B.line)
        }
        .padding(.horizontal, B.rowPaddingH)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

extension WorkbenchModel {
    /// The answer as plain lines, its marks taken out: a paragraph a line, a point a line with a
    /// bullet.
    func v2AnswerPlain(_ task: AgentTaskItem) -> String {
        guard let answer = task.answer else { return v2BoardLine(task) }
        return MarkdownBlock.parse(answer).map { block -> String in
            switch block {
            case .heading(let t), .paragraph(let t), .quote(let t): return MarkdownBlock.plain(t)
            case .bullets(let items): return items.map { "• " + MarkdownBlock.plain($0) }.joined(separator: "\n")
            case .numbered(let items): return items.enumerated().map { "\($0.offset + 1). " + MarkdownBlock.plain($0.element) }.joined(separator: "\n")
            case .code(let t): return t
            case .table(let rows): return rows.dropFirst().map { $0.joined(separator: " — ") }.joined(separator: "\n")
            }
        }.joined(separator: "\n")
    }
}

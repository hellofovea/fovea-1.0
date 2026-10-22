import SwiftUI
import AppKit
import FoveaCore

// The control board, round four (docs/island/FEEDBACK_2026-10-06.md): four more designs beside
// Sections and Badges, each from a different family of the notch apps around today, so they can be
// compared on the same sessions.
// - Focus: the most pressing session as a card with big buttons, the rest on a shelf under it
//   (Pushary's permission card, Atoll's agents tab, Crew Tower).
// - Capsules: each session its own small island under the notch; the island itself stays the notch
//   (Droppy's split island, the Dynamic Island's detached minimal).
// - Wings: the sessions as icons in the notch's wings, their state a ring around each; the one under
//   the pointer on a stage below (DynamicLake's and Pushary's wings).
// - Split: the sessions at the left, the one under the pointer read at the right (Boring Notch's and
//   Droppy's two panes).
// All show only what the agents reliably report: who, what, its state, how long, the question, the
// answer's first lines. No counts.

// MARK: Geometry

extension V2BoardLayout {
    /// The four designs' shapes. Capsules leaves the island at the notch's size and reports the
    /// capsules' room as where the pointer may go.
    @MainActor
    static func variant(_ style: BoardStyle, model: WorkbenchModel, metrics: ScreenMetrics) -> V2BoardLayout {
        let BV = WorkbenchTokens.BoardV.self
        let B = WorkbenchTokens.Board.self
        let spec = WorkbenchTokens.Island.spec
        let order = model.v2BoardOrder
        let top = V2Geometry.top(metrics)
        func outline(_ width: CGFloat, _ height: CGFloat) -> StackLayout.Outline {
            StackLayout.Outline(size: CGSize(width: width, height: height), topRadius: spec.expandedTopRadius, bottomRadius: B.bottomRadius)
        }
        switch style {
        case .focus:
            let width = V2SessionCard.contentWidth(panel: BV.focusWidth, margin: BV.focusMargin)
            let body = order.first.map { V2SessionCard.bodyHeight(model: model, task: $0, width: width, lines: BV.focusLines) } ?? 0
            let card = order.first == nil ? 0 : V2SessionCard.height(body: body)
            let shelf = max(0, order.count - 1)
            let list = CGFloat(min(shelf, BV.shelfRowsVisible)) * BV.shelfRow
            let height = top + card + (shelf > 0 ? BV.shelfRule + list : 0) + BV.bottom
            return V2BoardLayout(outline: outline(BV.focusWidth, height), listHeight: list, scrolls: shelf > BV.shelfRowsVisible,
                                 cardBody: body)
        case .wings:
            let width = V2SessionCard.contentWidth(panel: BV.wingsWidth, margin: BV.stageMargin)
            let body = V2SessionCard.fixedBody(stage: BV.stage)
            _ = width
            return V2BoardLayout(outline: outline(BV.wingsWidth, top + BV.stage + BV.bottom), listHeight: BV.stage, scrolls: false,
                                 cardBody: body)
        case .creatures:
            // Wings' shape, a little wider: five creatures to a wing at full spacing.
            return V2BoardLayout(outline: outline(WorkbenchTokens.Creatures.width, top + BV.stage + BV.bottom), listHeight: BV.stage,
                                 scrolls: false, cardBody: V2SessionCard.fixedBody(stage: BV.stage))
        case .split:
            let rows = CGFloat(min(order.count, BV.splitRowsVisible)) * BV.splitRow
            let content = max(rows, CGFloat(BV.splitRowsVisible) * BV.splitRow)
            return V2BoardLayout(outline: outline(WorkbenchTokens.V2.width, top + content + BV.bottom), listHeight: content,
                                 scrolls: order.count > BV.splitRowsVisible,
                                 cardBody: V2SessionCard.fixedBody(stage: content))
        case .petDesk:
            let PT = WorkbenchTokens.Pets.self
            let rows = (order.count + PT.deskColumns - 1) / PT.deskColumns
            let shown = min(rows, PT.deskRowsVisible)
            let list = CGFloat(shown) * PT.deskCell + CGFloat(max(0, shown - 1)) * PT.deskGap
            let all = CGFloat(rows) * PT.deskCell + CGFloat(max(0, rows - 1)) * PT.deskGap
            return V2BoardLayout(outline: outline(PT.deskWidth, top + list + BV.bottom), listHeight: list, scrolls: all > list + 0.5)
        case .petLanes:
            let PT = WorkbenchTokens.Pets.self
            let all = order.reduce(CGFloat(0)) { $0 + ($1.statusUnknown ? PT.quietLane : PT.lane) }
            let list = min(all, PT.lanesMax)
            return V2BoardLayout(outline: outline(PT.lanesWidth, top + list + BV.bottom), listHeight: list,
                                 scrolls: all > list + 0.5)
        case .capsules, .petCapsules:
            let rest = StackLayout.make(state: .silent, aspects: [], shape: model.referentShape, expanded: false, peek: false,
                                        inspecting: nil, metrics: metrics).outline
            let notch = NotchGeometry.notchRect(metrics: metrics, spec: spec)
            let heights = order.map { V2Capsule.height($0) }
            let room = notch.height + BV.capsuleTop + heights.reduce(0, +) + CGFloat(max(0, heights.count - 1)) * BV.capsuleGap
            return V2BoardLayout(outline: rest, listHeight: 0, scrolls: false,
                                 hoverSize: CGSize(width: BV.capsuleWide, height: room))
        case .sections, .badges, .petList:
            var layout = V2BoardLayout.make(sections: model.v2BoardGroups.map(\.count), style: style, metrics: metrics)
            // Oct 15 review, NH-03: room for "Remembered" over the list.
            if model.cases.memoryNotice != nil {
                layout.notice = WorkbenchTokens.Cases.memoryRow
                layout.outline.size.height += layout.notice
            }
            return layout
        }
    }
}

extension WorkbenchModel {
    /// The session the board's stage shows (Wings, Split): the one in focus, else the most pressing.
    var v2BoardSelected: AgentTaskItem? {
        let order = v2BoardOrder
        return order.first { $0.id == v2Focus } ?? order.first
    }

    /// How long, as the board says it: running, the time it has run; waiting, how long it has
    /// waited; done, how long ago; unknown, when it was last active.
    func v2BoardTime(_ task: AgentTaskItem) -> String {
        if task.statusUnknown { return AgentBoard.duration(task.age).map { "\($0) ago" } ?? "now" }
        switch task.state {
        case .working: return v2RunTime(task)
        case .needsYou: return AgentBoard.duration(task.inState) ?? "now"
        case .complete, .failed: return v2Since(task)
        }
    }

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

// MARK: Shared pieces

/// A session's state as a word in its color.
struct BoardStateWord {
    static func text(_ task: AgentTaskItem) -> (String, Color) {
        let B = WorkbenchTokens.Board.self
        if task.statusUnknown { return ("Status unavailable", B.time) }
        switch task.state {
        case .needsYou: return ("Needs you", WorkbenchTokens.Panel.needsYouColor)
        case .working: return ("Running", B.working)
        case .complete: return ("Done", B.done)
        case .failed: return (task.stopped ? "Stopped" : "Failed", task.stopped ? B.time : WorkbenchTokens.Panel.failedColor)
        }
    }
}

/// The small state glyph of a row: the running ring, the waiting mark, the check, the cross; a dashed
/// ring when the state can't be read.
struct BoardGlyph: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let size: CGFloat

    var body: some View {
        if task.statusUnknown {
            Circle().strokeBorder(WorkbenchTokens.ink(0.3), style: StrokeStyle(lineWidth: 1.2, dash: [2, 2]))
                .frame(width: size, height: size)
        } else {
            AgentStateGlyph(task: task, size: size, paused: model.snapshotMode)
        }
    }
}

/// What the person asks of a waiting session, its command set in code.
func boardAsk(_ task: AgentTaskItem, size: CGFloat, weight: Font.Weight, color: Color) -> Text {
    let text = task.activity
    if case .approval(let command) = task.ask, let range = text.range(of: command) {
        return Text(text[..<range.lowerBound]).font(.system(size: size, weight: weight)).foregroundColor(color)
            + Text(command).font(.system(size: size - 1.5, design: .monospaced)).foregroundColor(color)
            + Text(text[range.upperBound...]).font(.system(size: size, weight: weight)).foregroundColor(color)
    }
    return Text(text).font(.system(size: size, weight: weight)).foregroundColor(color)
}

/// A big button: half the row, a capsule; the primary one white with black words.
struct BoardBigButton: View {
    let title: String
    var symbol: String? = nil
    var primary = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let BV = WorkbenchTokens.BoardV.self
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol { Image(systemName: symbol).font(.system(size: 12, weight: .semibold)) }
                Text(title).lineLimit(1)
            }
            .font(BV.actionFont)
            .foregroundStyle(primary ? WorkbenchTokens.Panel.buttonPrimaryText : WorkbenchTokens.ink(0.92))
            .frame(maxWidth: .infinity)
            .frame(height: BV.actionHeight)
            .background(Capsule(style: .continuous)
                .fill(primary ? WorkbenchTokens.Panel.buttonPrimary.opacity(hovering ? 0.85 : 1) : (hovering ? BV.actionFillHover : BV.actionFill)))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// A session's big buttons: Deny and Allow (or its answers); Read the answer and Open in its app;
/// Retry; Stop and Open. Oct 17, Ryan: Open in <agent> works as the session's own (one way).
struct BoardActions: View {
    let model: WorkbenchModel
    let task: AgentTaskItem

    var body: some View {
        let agent = ChatAgent.named(task.agent)
        HStack(spacing: WorkbenchTokens.BoardV.actionGap) {
            if task.statusUnknown {
                BoardBigButton(title: "Open in \(agent.name)", symbol: "arrow.up.forward") { model.openInAgentV2(task.id) }
            } else {
                switch task.state {
                case .needsYou:
                    if case .choice(let options) = task.ask {
                        ForEach(options, id: \.self) { option in
                            BoardBigButton(title: option) { guarded { model.answerTask(task.id, option) } }
                        }
                    } else {
                        BoardBigButton(title: "Deny") { guarded { model.denyTask(task.id) } }
                        // Native: the action's own verb (Run Tests), Allow in Original.
                        let verb: String = {
                            if case .approval(let command) = task.ask { return ApprovalVerb.of(command).title }
                            return "Allow"
                        }()
                        BoardBigButton(title: WorkbenchTokens.skin("Allow", verb), primary: true) { guarded { model.allowTask(task.id) } }
                    }
                case .complete:
                    BoardBigButton(title: "Read the answer", symbol: "arrow.up.left.and.arrow.down.right", primary: true) {
                        model.openV2(task.id, expanded: true)
                    }
                    BoardBigButton(title: "Open in \(agent.name)", symbol: "arrow.up.forward") { model.openInAgentV2(task.id) }
                case .failed:
                    BoardBigButton(title: "Retry", symbol: "arrow.clockwise", primary: true) { guarded { model.retryTask(task.id) } }
                    BoardBigButton(title: "Open in \(agent.name)", symbol: "arrow.up.forward") { model.openInAgentV2(task.id) }
                case .working:
                    BoardBigButton(title: "Stop", symbol: "stop.fill") { guarded { model.stopTask(task.id) } }
                    BoardBigButton(title: "Open", symbol: "arrow.up.forward") { model.openV2(task.id) }
                }
            }
        }
    }

    /// A click in the first moment after the board opens was meant for what was under the pointer.
    private func guarded(_ action: () -> Void) {
        if model.panelControlsLive { action() }
    }
}

/// A list that scrolls only when it must: a plain stack, clipped, when everything fits (or when
/// drawn off screen, where a scroll view can't be).
struct BoardScroll<Content: View>: View {
    let model: WorkbenchModel
    let scrolls: Bool
    let height: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        if scrolls && !model.offscreenRender {
            ScrollView { VStack(spacing: 0) { content() } }.scrollIndicators(.automatic).frame(height: height)
        } else {
            VStack(spacing: 0) { content() }.frame(height: height, alignment: .top).clipped()
        }
    }
}

// MARK: The session card (Focus's card, Wings' stage, Split's detail)

/// One session read whole: its agent and title, its project and state; what it asks, what came
/// back, or how long it has run and what was asked; its big buttons.
struct V2SessionCard: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let bodyHeight: CGFloat
    let lines: Int
    /// Creatures: the session's creature on the stage, larger, in place of its agent's icon.
    var creature = false
    /// Oct 21, perf: its band is showing (MockIsland's `BandShown`); its clock pauses when not.
    @Environment(\.islandBandShown) private var bandShown

    var body: some View {
        let BV = WorkbenchTokens.BoardV.self
        let V = WorkbenchTokens.V2.self
        let agent = ChatAgent.named(task.agent)
        VStack(alignment: .leading, spacing: BV.focusGap) {
            HStack(spacing: 12) {
                // A question for the person or a failure drops the persona: the agent's plain icon,
                // the words and the buttons (CREATURES.md); otherwise its creature, larger.
                if creature && task.state != .needsYou && task.state != .failed {
                    AgentCreature(pose: CreaturePose.of(task, model: model), agent: task.agent,
                                  size: WorkbenchTokens.Creatures.stageSize, traits: CreatureTraits(seed: task.id),
                                  progress: creatureProgress(task), still: model.snapshotMode || model.notchState != .v2Board)
                        .frame(width: WorkbenchTokens.Creatures.stageSize * 1.9, height: BV.focusHeader)
                } else {
                    ChatAgentIcon(agent: agent, size: BV.focusIcon)
                        .saturation(task.statusUnknown ? 0 : 1)
                        .opacity(task.statusUnknown ? 0.45 : 1)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.v2Title(task)).font(BV.titleFont)
                        .foregroundStyle(task.statusUnknown ? WorkbenchTokens.Board.dimTitle : V.titleColor).lineLimit(1)
                    Text("\(agent.name) · \(task.project == DispatchV2.quickProject ? "Quick answer" : task.project)")
                        .font(BV.subFont).foregroundStyle(BV.sub).lineLimit(1)
                }
                Spacer(minLength: 8)
                tag
            }
            .frame(height: BV.focusHeader)
            .contentShape(Rectangle())
            .onTapGesture { model.openV2(task.id) }
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: bodyHeight, alignment: .topLeading)
            BoardActions(model: model, task: task)
        }
    }

    /// At the header's right: Needs you as an amber tag; otherwise the glyph and how long.
    @ViewBuilder private var tag: some View {
        let BV = WorkbenchTokens.BoardV.self
        let B = WorkbenchTokens.Board.self
        if task.state == .needsYou && !task.statusUnknown {
            HStack(spacing: 5) {
                Circle().fill(WorkbenchTokens.Panel.needsYouColor).frame(width: 6, height: 6)
                Text("Needs you")
            }
            .font(BV.pillFont)
            .foregroundStyle(WorkbenchTokens.Panel.needsYouColor)
            .padding(.horizontal, 10)
            .frame(height: BV.pillHeight)
            .background(Capsule().fill(BV.pillFill))
        } else {
            HStack(spacing: 6) {
                BoardGlyph(model: model, task: task, size: B.ring)
                Text(model.v2BoardTime(task)).font(BV.timeFont).foregroundStyle(B.time).monospacedDigit()
            }
        }
    }

    @ViewBuilder private var content: some View {
        let BV = WorkbenchTokens.BoardV.self
        if task.statusUnknown {
            Text("Its state can't be read. Last active \(AgentBoard.duration(task.age) ?? "just now") ago.")
                .font(.system(size: BV.answerSize)).foregroundStyle(BV.sub).lineLimit(lines)
        } else {
            switch task.state {
            case .needsYou:
                boardAsk(task, size: BV.questionSize, weight: .medium, color: BV.question).lineLimit(lines).lineSpacing(2)
            case .complete, .failed:
                Text(lines > 3 ? model.v2AnswerPlain(task) : "\u{201C}\(model.v2BoardLine(task))\u{201D}")
                    .font(.system(size: BV.answerSize)).foregroundStyle(BV.answer).lineSpacing(3).lineLimit(lines)
            case .working:
                VStack(alignment: .leading, spacing: 6) {
                    // Oct 21, perf: ticks only while the board shows.
                    TimelineView(.periodic(from: .now, by: bandShown ? 1 : WorkbenchTokens.Motion.hiddenTick)) { _ in
                        Text(model.v2RunTime(task, clock: true)).font(BV.bigTime).foregroundStyle(WorkbenchTokens.ink(0.9))
                            .contentTransition(.numericText())
                    }
                    .frame(height: BV.bigTimeHeight, alignment: .leading)
                    V2StepLine(model: model, task: task, size: 14)
                }
            }
        }
    }

    // Its measures.
    static func contentWidth(panel: CGFloat, margin: CGFloat) -> CGFloat {
        panel - 2 * (WorkbenchTokens.Island.spec.expandedTopRadius + margin)
    }

    static func height(body: CGFloat) -> CGFloat {
        let BV = WorkbenchTokens.BoardV.self
        return BV.focusHeader + BV.focusGap + body + BV.focusGap + BV.actionHeight
    }

    /// The body's room in a stage of a given height.
    static func fixedBody(stage: CGFloat) -> CGFloat {
        let BV = WorkbenchTokens.BoardV.self
        return stage - BV.focusHeader - 2 * BV.focusGap - BV.actionHeight
    }

    @MainActor
    static func bodyHeight(model: WorkbenchModel, task: AgentTaskItem, width: CGFloat, lines: Int) -> CGFloat {
        let BV = WorkbenchTokens.BoardV.self
        if task.statusUnknown { return V2Geometry.measure("Its state", size: BV.answerSize, width: width, lines: 1) }
        switch task.state {
        case .needsYou:
            return V2Geometry.measure(task.activity, size: BV.questionSize, weight: .medium, width: width, lines: lines)
        case .complete, .failed:
            return V2Geometry.measure("\u{201C}\(model.v2BoardLine(task))\u{201D}", size: BV.answerSize, width: width,
                                      spacing: 3, lines: lines)
        case .working:
            return BV.bigTimeHeight + 6 + V2Geometry.measure("Editing", size: 14, width: width, lines: 1)
        }
    }
}

// MARK: Focus

/// The most pressing session as a card (what it asks and Deny/Allow; else what came back; else how
/// long it has run), then every other session on a shelf, one line each.
struct V2FocusBoard: View {
    let model: WorkbenchModel
    let layout: V2BoardLayout

    var body: some View {
        let BV = WorkbenchTokens.BoardV.self
        let order = model.v2BoardOrder
        let width = V2SessionCard.contentWidth(panel: BV.focusWidth, margin: BV.focusMargin)
        ZStack(alignment: .topLeading) {
            Color.clear
            if let focus = order.first {
                VStack(alignment: .leading, spacing: 0) {
                    V2SessionCard(model: model, task: focus, bodyHeight: layout.cardBody, lines: BV.focusLines)
                    if order.count > 1 {
                        Rectangle().fill(BV.hairline).frame(height: 0.5).frame(height: BV.shelfRule)
                        BoardScroll(model: model, scrolls: layout.scrolls, height: layout.listHeight) {
                            ForEach(order.dropFirst()) { task in
                                V2ShelfRow(model: model, task: task).frame(height: BV.shelfRow).id(task.id)
                            }
                        }
                    }
                }
                .frame(width: width, alignment: .topLeading)
                .offset(x: WorkbenchTokens.Island.spec.expandedTopRadius + BV.focusMargin, y: V2Geometry.top(model.metrics))
                .id(focus.id)
                .transition(.opacity)
            }
        }
        .frame(width: layout.outline.size.width, height: layout.outline.size.height, alignment: .topLeading)
        .animation(model.snapshotMode ? nil : WorkbenchTokens.Board.move, value: order.map(\.id))
    }
}

/// A session on Focus's shelf: its state, its agent, its title, one quiet line, how long.
struct V2ShelfRow: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    @State private var hovering = false

    var body: some View {
        let BV = WorkbenchTokens.BoardV.self
        let B = WorkbenchTokens.Board.self
        HStack(spacing: 10) {
            BoardGlyph(model: model, task: task, size: BV.shelfGlyph).frame(width: 14)
            ChatAgentIcon(agent: ChatAgent.named(task.agent), size: BV.shelfIcon)
                .saturation(task.statusUnknown ? 0 : 1).opacity(task.statusUnknown ? 0.45 : 1)
            Text(model.v2Title(task)).font(BV.rowTitleFont)
                .foregroundStyle(task.statusUnknown ? B.dimTitle : B.title).lineLimit(1).layoutPriority(1)
            if task.state == .working && !task.statusUnknown {
                V2StepLine(model: model, task: task, size: 12.5, glyph: false)
            } else {
                secondary.font(BV.subFont).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(model.v2BoardTime(task)).font(BV.timeFont).foregroundStyle(B.time).monospacedDigit()
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: B.rowRadius, style: .continuous).fill(hovering ? B.highlight : .clear))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { model.openV2(task.id) }
        .help("\(ChatAgent.named(task.agent).name) · \(task.project)")
    }

    private var secondary: Text {
        let B = WorkbenchTokens.Board.self
        if task.statusUnknown { return Text(task.project).foregroundColor(B.time) }
        switch task.state {
        case .needsYou: return Text(task.activity).foregroundColor(WorkbenchTokens.Panel.needsYouColor)
        case .complete: return Text("\u{201C}\(model.v2BoardLine(task))\u{201D}").foregroundColor(WorkbenchTokens.ink(0.45))
        case .failed: return Text("Failed").foregroundColor(WorkbenchTokens.Panel.failedColor)
        case .working: return Text(task.project).foregroundColor(WorkbenchTokens.ink(0.4))
        }
    }
}

// MARK: Capsules

/// Each session its own black capsule under the notch, dropping out of it one after another: the
/// one waiting on the person tallest, with its buttons; the ones whose state can't be read narrower
/// and dimmed. Drawn over the screen, outside the island, which stays the notch.
struct V2CapsuleBoard: View {
    let model: WorkbenchModel

    var body: some View {
        let BV = WorkbenchTokens.BoardV.self
        let shown = model.notchState == .v2Board && (model.boardStyle == .capsules || model.boardStyle == .petCapsules)
        let notch = NotchGeometry.notchRect(metrics: model.metrics, spec: WorkbenchTokens.Island.spec)
        let order = model.v2BoardOrder
        VStack(spacing: BV.capsuleGap) {
            ForEach(Array(order.enumerated()), id: \.element.id) { i, task in
                V2Capsule(model: model, task: task)
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : -10 - CGFloat(i) * 6)
                    .scaleEffect(shown ? 1 : 0.94, anchor: .top)
                    .animation(model.snapshotMode ? nil : BV.capsuleIn.delay(shown ? Double(i) * BV.capsuleStagger : 0), value: shown)
            }
        }
        .padding(.top, notch.height + BV.capsuleTop + (model.screenContent.fullScreen ? model.metrics.safeAreaTop - notch.height : 0))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(shown)
        .accessibilityHidden(!shown)
        .panelScheme()
    }
}

struct V2Capsule: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    @State private var hovering = false

    static func height(_ task: AgentTaskItem) -> CGFloat {
        let BV = WorkbenchTokens.BoardV.self
        if task.statusUnknown { return BV.capsuleQuietHeight }
        return task.state == .needsYou ? BV.capsuleTall : BV.capsuleHeight
    }

    var body: some View {
        let BV = WorkbenchTokens.BoardV.self
        let B = WorkbenchTokens.Board.self
        let tall = task.state == .needsYou && !task.statusUnknown
        let quiet = task.statusUnknown
        let width = tall ? BV.capsuleWide : (quiet ? BV.capsuleQuiet : BV.capsuleWidth)
        let shape = RoundedRectangle(cornerRadius: tall ? BV.capsuleTallRadius : BV.capsuleRadius, style: .continuous)
        let pets = model.boardStyle == .petCapsules
        HStack(spacing: 12) {
            if pets {
                PetFor(model: model, task: task, size: WorkbenchTokens.Pets.capsulePet)
            } else {
                ChatAgentIcon(agent: ChatAgent.named(task.agent), size: BV.capsuleIcon)
                    .saturation(quiet ? 0 : 1).opacity(quiet ? 0.45 : 1)
            }
            if tall {
                VStack(alignment: .leading, spacing: 4) {
                    AgentTitle(model: model, task: task, font: .system(size: 14, weight: .semibold), color: B.title, icon: pets)
                    boardAsk(task, size: 12.5, weight: .regular, color: WorkbenchTokens.Panel.needsYouColor).lineLimit(1)
                }
                Spacer(minLength: 8)
                AgentControls(model: model, task: task, shown: true)
            } else {
                AgentTitle(model: model, task: task, font: .system(size: 14, weight: .semibold),
                           color: quiet ? B.dimTitle : B.title, icon: pets)
                    .layoutPriority(1)
                if task.state == .working && !quiet {
                    V2StepLine(model: model, task: task, size: 12.5, glyph: false)
                } else {
                    secondary.font(BV.subFont).lineLimit(1)
                }
                Spacer(minLength: 8)
                trailing
            }
        }
        .padding(.horizontal, BV.capsulePadding)
        .frame(width: width, height: Self.height(task))
        // Native: each capsule its own glass under the notch.
        .surface(shape, original: WorkbenchTokens.Island.surface, interactive: true)
        .overlay(shape.strokeBorder(tall ? WorkbenchTokens.Panel.needsYouColor.opacity(0.45) : BV.capsuleStroke,
                                    lineWidth: tall ? 1 : 0.5))
        .overlay(shape.fill(WorkbenchTokens.ink(hovering ? 0.05 : 0)).allowsHitTesting(false))
        .shadow(color: tall ? WorkbenchTokens.Panel.needsYouColor.opacity(0.18) : BV.capsuleShadow, radius: tall ? 14 : 12, y: 4)
        .contentShape(shape)
        .onHover { inside in
            hovering = inside
            model.hoverV2(task.id, inside)
        }
        .onTapGesture { model.openV2(task.id) }
        .help("\(ChatAgent.named(task.agent).name) · \(task.project)")
    }

    private var secondary: Text {
        let B = WorkbenchTokens.Board.self
        if task.statusUnknown { return Text("last active \(AgentBoard.duration(task.age) ?? "now") ago").foregroundColor(B.time) }
        switch task.state {
        case .complete: return Text("\u{201C}\(model.v2BoardLine(task))\u{201D}").foregroundColor(WorkbenchTokens.ink(0.5))
        case .failed: return Text(model.v2BoardLine(task)).foregroundColor(WorkbenchTokens.ink(0.5))
        default: return Text(task.project).foregroundColor(WorkbenchTokens.ink(0.4))
        }
    }

    @ViewBuilder private var trailing: some View {
        let B = WorkbenchTokens.Board.self
        if !task.statusUnknown {
            HStack(spacing: 6) {
                if task.state == .failed {
                    Text(BoardStateWord.text(task).0).font(B.wordFont).foregroundStyle(BoardStateWord.text(task).1)
                } else if model.boardStyle != .petCapsules {
                    BoardGlyph(model: model, task: task, size: B.ring)
                }
                Text(model.v2BoardTime(task)).font(WorkbenchTokens.BoardV.timeFont).foregroundStyle(B.time).monospacedDigit()
            }
        }
    }
}

// MARK: Wings

/// The sessions as icons in the notch's wings, their state a ring around each: the person's turn
/// at the left (waiting, then done), the rest at the right (running, then unreadable), the most
/// pressing nearest the notch. The one under the pointer (or in focus) is read on the stage below.
struct V2WingsBoard: View {
    let model: WorkbenchModel
    let layout: V2BoardLayout

    var body: some View {
        let BV = WorkbenchTokens.BoardV.self
        let spec = WorkbenchTokens.Island.spec
        let notch = NotchGeometry.notchRect(metrics: model.metrics, spec: spec)
        let sections = model.v2BoardSections
        let left = sections.filter { $0.section == .needsYou || $0.section == .done }.flatMap(\.tasks)
        let right = sections.filter { $0.section == .running || $0.section == .unknown }.flatMap(\.tasks)
        let width = layout.outline.size.width
        let selected = model.v2BoardSelected
        ZStack(alignment: .topLeading) {
            Color.clear
            // The wings are on the island's band: dark on Original's black and on the black band of
            // a full-screen app, the display's on Native's glass.
            Group {
                wing(left, toward: -1, notch: notch, width: width, selected: selected?.id)
                wing(right, toward: 1, notch: notch, width: width, selected: selected?.id)
            }
            .panelScheme(onBlack: model.screenContent.fullScreen)
            if let selected {
                V2SessionCard(model: model, task: selected, bodyHeight: layout.cardBody, lines: 3)
                    .frame(width: V2SessionCard.contentWidth(panel: width, margin: BV.stageMargin), alignment: .topLeading)
                    .offset(x: spec.expandedTopRadius + BV.stageMargin, y: V2Geometry.top(model.metrics))
                    .id(selected.id)
                    .transition(.opacity)
            }
        }
        .frame(width: layout.outline.size.width, height: layout.outline.size.height, alignment: .topLeading)
        .animation(model.snapshotMode ? nil : .easeOut(duration: 0.12), value: selected?.id)
    }

    /// One wing: its tokens from the notch outward; past the room, the last token cycles through the rest.
    private func wing(_ tasks: [AgentTaskItem], toward side: CGFloat, notch: CGRect, width: CGFloat, selected: String?) -> some View {
        let BV = WorkbenchTokens.BoardV.self
        let room = BV.tokensPerWing
        let shown = tasks.count > room ? Array(tasks.prefix(room - 1)) : tasks
        let hidden = tasks.count > room ? Array(tasks.dropFirst(room - 1)) : []
        let start = width / 2 + side * (notch.width / 2 + BV.wingInset + BV.token / 2)
        let step = side * (BV.token + BV.tokenGap)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { i, task in
                WingToken(model: model, task: task, selected: selected == task.id)
                    .position(x: start + CGFloat(i) * step, y: notch.height / 2)
            }
            if !hidden.isEmpty {
                WingMore(model: model, hidden: hidden, selected: selected)
                    .position(x: start + CGFloat(shown.count) * step, y: notch.height / 2)
            }
        }
        .frame(width: width, height: notch.height)
    }
}

/// A session in a wing: its agent's icon in a disc, its state a ring: amber, waiting on you; a turning
/// quarter, running; a check, done; red, failed; dashed and gray, unreadable. In focus, a bar under it.
struct WingToken: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let selected: Bool

    var body: some View {
        let BV = WorkbenchTokens.BoardV.self
        ZStack {
            Circle().fill(Color.white.opacity(selected ? 0.16 : 0.07))
            ChatAgentIcon(agent: ChatAgent.named(task.agent), size: BV.tokenIcon)
                .saturation(task.statusUnknown ? 0 : 1).opacity(task.statusUnknown ? 0.4 : 1)
            WingRing(model: model, task: task)
        }
        .frame(width: BV.token, height: BV.token)
        .overlay(alignment: .bottom) {
            Capsule().fill(Color.white.opacity(selected ? 0.9 : 0)).frame(width: 12, height: 2).offset(y: 5)
        }
        .contentShape(Circle())
        .onHover { model.hoverV2(task.id, $0) }
        .onTapGesture { model.openV2(task.id) }
        .help("\(model.v2Title(task)) · \(BoardStateWord.text(task).0)")
        .accessibilityLabel("\(model.v2Title(task)), \(BoardStateWord.text(task).0)")
        .accessibilityAddTraits(.isButton)
    }
}

/// The ring around a wing's token.
struct WingRing: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Oct 21, perf: its band is showing (MockIsland's `BandShown`); its clock pauses when not.
    @Environment(\.islandBandShown) private var bandShown

    var body: some View {
        let BV = WorkbenchTokens.BoardV.self
        let amber = WorkbenchTokens.Panel.needsYouColor
        if task.statusUnknown {
            Circle().strokeBorder(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.2, dash: [2, 2]))
        } else {
            switch task.state {
            case .needsYou:
                Circle().strokeBorder(amber, lineWidth: BV.tokenRing).shadow(color: amber.opacity(0.6), radius: 4)
            case .working:
                let still = model.snapshotMode || reduceMotion
                TimelineView(.animation(minimumInterval: 1 / 30, paused: still || !bandShown)) { context in
                    let turn = still ? 0.15 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
                    ZStack {
                        Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: BV.tokenRing)
                        Circle().inset(by: BV.tokenRing / 2).trim(from: 0, to: 0.28)
                            .stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: BV.tokenRing, lineCap: .round))
                            .rotationEffect(.degrees(turn * 360 - 90))
                    }
                }
            case .complete:
                Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 1.2)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 10))
                            .foregroundStyle(Color.black, Color.white.opacity(0.9)).offset(x: 3, y: 3)
                    }
            case .failed:
                Circle().strokeBorder(WorkbenchTokens.Panel.failedColor, lineWidth: BV.tokenRing)
            }
        }
    }
}

/// The last place in a full wing: an ellipsis; a click shows the next session it holds on the stage.
struct WingMore: View {
    let model: WorkbenchModel
    let hidden: [AgentTaskItem]
    let selected: String?

    var body: some View {
        let BV = WorkbenchTokens.BoardV.self
        let holdsSelected = hidden.contains { $0.id == selected }
        Button {
            let i = hidden.firstIndex { $0.id == selected }.map { ($0 + 1) % hidden.count } ?? 0
            model.v2Focus = hidden[i].id
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.75))
                .frame(width: BV.token, height: BV.token)
                .background(Circle().fill(Color.white.opacity(holdsSelected ? 0.16 : 0.07)))
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Capsule().fill(Color.white.opacity(holdsSelected ? 0.9 : 0)).frame(width: 12, height: 2).offset(y: 5)
        }
        .help(hidden.map { model.v2Title($0) }.joined(separator: "\n"))
        .accessibilityLabel("More sessions")
    }
}

// MARK: Split

/// The sessions at the left, one line each; the one under the pointer (or in focus) read at the
/// right: what it asks, its whole answer, or how long it has run and what was asked.
struct V2SplitBoard: View {
    let model: WorkbenchModel
    let layout: V2BoardLayout

    var body: some View {
        let BV = WorkbenchTokens.BoardV.self
        let order = model.v2BoardOrder
        let width = V2Geometry.contentWidth
        let detail = width - BV.splitList - 2 * BV.splitGap - 0.5
        let selected = model.v2BoardSelected
        ZStack(alignment: .topLeading) {
            Color.clear
            HStack(alignment: .top, spacing: BV.splitGap) {
                BoardScroll(model: model, scrolls: layout.scrolls, height: layout.listHeight) {
                    ForEach(order) { task in
                        V2SplitRow(model: model, task: task, selected: selected?.id == task.id)
                            .frame(height: BV.splitRow).id(task.id)
                    }
                }
                .frame(width: BV.splitList, height: layout.listHeight, alignment: .top)
                Rectangle().fill(BV.hairline).frame(width: 0.5, height: layout.listHeight)
                if let selected {
                    V2SessionCard(model: model, task: selected, bodyHeight: layout.cardBody, lines: BV.splitDetailLines)
                        .frame(width: detail, alignment: .topLeading)
                        .id(selected.id)
                        .transition(.opacity)
                }
            }
            .frame(width: width, alignment: .topLeading)
            .offset(x: V2Geometry.contentX, y: V2Geometry.top(model.metrics))
        }
        .frame(width: layout.outline.size.width, height: layout.outline.size.height, alignment: .topLeading)
        .animation(model.snapshotMode ? nil : .easeOut(duration: 0.12), value: selected?.id)
    }
}

struct V2SplitRow: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let selected: Bool
    @State private var hovering = false

    var body: some View {
        let BV = WorkbenchTokens.BoardV.self
        let B = WorkbenchTokens.Board.self
        HStack(spacing: 10) {
            BoardGlyph(model: model, task: task, size: 11).frame(width: 14)
            ChatAgentIcon(agent: ChatAgent.named(task.agent), size: BV.splitIcon)
                .saturation(task.statusUnknown ? 0 : 1).opacity(task.statusUnknown ? 0.45 : 1)
            Text(model.v2Title(task)).font(BV.rowTitleFont)
                .foregroundStyle(task.statusUnknown ? B.dimTitle : B.title).lineLimit(1)
            Spacer(minLength: 6)
            Text(model.v2BoardTime(task)).font(BV.timeFont)
                .foregroundStyle(task.state == .needsYou && !task.statusUnknown ? WorkbenchTokens.Panel.needsYouColor : B.time)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: B.rowRadius, style: .continuous)
            .fill(selected ? BV.selectedFill : (hovering ? B.highlight : .clear)))
        .contentShape(Rectangle())
        .onHover { inside in
            hovering = inside
            model.hoverV2(task.id, inside)
        }
        .onTapGesture { model.openV2(task.id) }
        .help("\(ChatAgent.named(task.agent).name) · \(task.project)")
    }
}

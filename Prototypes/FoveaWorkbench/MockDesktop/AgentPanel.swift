import SwiftUI
import AppKit
import FoveaCore

// Dispatch's Agent panel in the island (the states are in WorkbenchModel+Panel.swift): the
// sessions Fovea sent requests to, grouped by project, five rows at most and scrolling past them,
// at Choose chat's width so the island keeps its size from one to the other. Each row answers two
// things first, which agent (its icon and the session's name) and its state, then one line of
// what it is doing. The panel's Style picks how (PanelStyle); docs/island/AGENT_PANEL.md has the
// reasons.

/// The row variations, chosen in the panel.
enum PanelStyle: String, CaseIterable, Identifiable {
    /// One line, as Claude Code's Agent View: the state in a fixed slot at the left (one column
    /// to scan), the icon, the session, what it is doing (dim), how long at the right.
    case ledger
    /// The state as a badge on the agent's icon; the session and its line; nothing else.
    case badge
    /// Two lines, the hover list's anatomy: the state, a glyph and its word, at the right with
    /// how long.
    case status
    /// Two lines; the second is the real thing: the file, command or page, and the line it is
    /// writing, the test that just passed, the page's title, typed as it comes.
    case live

    var id: String { rawValue }
    var title: String {
        switch self {
        case .ledger: return "Ledger"
        case .badge: return "Badge"
        case .status: return "Status"
        case .live: return "Live"
        }
    }

    var rowHeight: CGFloat {
        self == .ledger ? WorkbenchTokens.Panel.lineRowHeight : WorkbenchTokens.Panel.rowHeight
    }

    /// A row's height: in the Ledger, a task that needs the person takes a second line for its
    /// question and answers.
    func height(of task: AgentTaskItem) -> CGFloat {
        self == .ledger && task.state == .needsYou ? WorkbenchTokens.Panel.askRowHeight : rowHeight
    }
}

/// Where the panel's parts go. Coordinates are from the island's top-left corner.
struct PanelLayout: Equatable {
    var outline: StackLayout.Outline
    /// The visible list: the projects' headers and their rows, scrolling past the fifth row.
    var list: CGRect
    var rowHeight: CGFloat
    var scrolls: Bool

    /// `groups`: each project's tasks, in order. The list has the same room in every style (five
    /// two-line rows and two projects' names), shows five rows at most, and ends on a whole row;
    /// past that it scrolls.
    static func make(groups: [AgentProjectGroup], style: PanelStyle, metrics: ScreenMetrics) -> PanelLayout {
        let P = WorkbenchTokens.Panel.self
        let spec = WorkbenchTokens.Island.spec
        let notch = NotchGeometry.notchRect(metrics: metrics, spec: spec)
        let width = WorkbenchTokens.Chat.width
        let rowHeight = style.rowHeight
        let window = P.listWindow
        // Walk the list: the visible part ends at the last row that fits whole (never mid-row),
        // five rows at most.
        var y: CGFloat = 0
        var fits: CGFloat = 0
        var count = 0
        for (index, group) in groups.enumerated() {
            y += (index == 0 ? 0 : P.groupGap) + P.headerHeight
            for task in group.tasks {
                y += style.height(of: task)
                count += 1
                if y <= window + 0.5, count <= P.rowsVisible { fits = y }
            }
        }
        let content = groups.isEmpty ? rowHeight : y
        let listWidth = width - 2 * spec.expandedTopRadius - 2 * P.listPadding
        let list = CGRect(x: (width - listWidth) / 2, y: notch.height + P.listTop, width: listWidth,
                          height: content > window + 0.5 ? fits : content)
        return PanelLayout(
            outline: StackLayout.Outline(size: CGSize(width: width, height: list.maxY + P.listPadding),
                                         topRadius: spec.expandedTopRadius, bottomRadius: spec.expandedBottomRadius),
            list: list, rowHeight: rowHeight, scrolls: content > window + 0.5)
    }
}

extension AgentTaskItem {
    /// Working, but quiet for minutes: the panel says so rather than look busy.
    var stalled: Bool { state == .working && !stopped && age >= WorkbenchTokens.Panel.stallAfter }

    /// The line under the session: what it is doing, or how long it has been quiet.
    var line: String {
        if stalled, let quiet = AgentBoard.duration(age) { return "No activity for \(quiet)" }
        return activity
    }

    /// The state's word: Stopped (by the person) reads as itself, not as Failed.
    var stateWord: String { stopped ? "Stopped" : state.label }
}

/// The Agent panel's content in the island.
struct AgentPanelContent: View {
    let model: WorkbenchModel
    let layout: PanelLayout

    var body: some View {
        let P = WorkbenchTokens.Panel.self
        ZStack(alignment: .topLeading) {
            Color.clear
            Group {
                if layout.scrolls {
                    ScrollViewReader { proxy in
                        ScrollView {
                            groups
                        }
                        .scrollIndicators(.automatic)
                        .onAppear {
                            if let sent = model.panelSentTask { proxy.scrollTo(sent) }
                        }
                        .onChange(of: model.panelHighlight) { _, id in
                            if let id { proxy.scrollTo(id) }
                        }
                    }
                } else {
                    groups
                }
            }
            .frame(width: layout.list.width, height: layout.list.height, alignment: .top)
            .position(x: layout.list.midX, y: layout.list.midY)
        }
        .frame(width: layout.outline.size.width, height: layout.outline.size.height, alignment: .topLeading)
        .animation(model.islandAnimation, value: layout)
        .animation(P.change, value: model.panelTasks.map(\.id))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Agent tasks")
    }

    /// Each project under its name, the name staying at the top while its rows scroll under it.
    private var groups: some View {
        let P = WorkbenchTokens.Panel.self
        return LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(Array(model.panelGroups.enumerated()), id: \.element.id) { index, group in
                Section {
                    ForEach(group.tasks) { task in
                        AgentTaskRowView(model: model, task: task, style: model.panelStyle,
                                         highlighted: model.panelHighlight == task.id, sent: model.panelSentTask == task.id)
                            .frame(height: model.panelStyle.height(of: task))
                            .id(task.id)
                    }
                } header: {
                    AgentProjectHeader(project: group.project)
                        .padding(.top, index == 0 ? 0 : P.groupGap)
                        .background(Color.black)
                }
            }
        }
    }
}

/// A project's name over its rows: small, quiet, never a count.
struct AgentProjectHeader: View {
    let project: String

    var body: some View {
        let P = WorkbenchTokens.Panel.self
        Text(project)
            .font(P.headerFont)
            .foregroundStyle(P.headerColor)
            .lineLimit(1)
            .padding(.horizontal, P.rowPaddingH)
            .padding(.bottom, P.headerBottom)
            .frame(maxWidth: .infinity, alignment: .bottomLeading)
            .frame(height: P.headerHeight, alignment: .bottom)
            .accessibilityAddTraits(.isHeader)
    }
}

/// One session's task, in the chosen style. The pointer's or the keyboard's row shows its one
/// control (Stop, Retry, Open); a task that needs the person shows its answers always. A click
/// takes you to the session.
struct AgentTaskRowView: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let style: PanelStyle
    let highlighted: Bool
    let sent: Bool
    @State private var hovering = false

    var body: some View {
        let P = WorkbenchTokens.Panel.self
        let agent = ChatAgent.named(task.agent)
        Group {
            switch style {
            case .ledger: ledger(agent)
            case .badge: badge(agent)
            case .status: status(agent)
            case .live: live(agent)
            }
        }
        .padding(.horizontal, P.rowPaddingH)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The task Send just created holds a brighter fill a while, fading when it lets go; the
        // pointer's and the keyboard's fill moves at once.
        .background(
            RoundedRectangle(cornerRadius: P.rowRadius, style: .continuous)
                .fill(sent ? P.sentFill : (highlighted || hovering ? P.hoverFill : .clear))
                .animation(nil, value: hovering)
                .animation(nil, value: highlighted)
                .animation(P.sentFade, value: sent))
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { model.openTask(task.id) }
        .help("\(agent.name) · \(task.project) · \(task.request)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.session), \(agent.name), \(task.stateWord)\(AgentBoard.duration(task.inState).map { " for \($0)" } ?? ""), \(task.line)")
        .accessibilityAction { model.openTask(task.id) }
    }

    private var showControls: Bool { hovering || highlighted }

    // Ledger: one line; the state's glyph first, in a slot of its own; how long at the right,
    // or the control. A task that needs the person takes a second line: its question and answers.
    private func ledger(_ agent: ChatAgent) -> some View {
        let P = WorkbenchTokens.Panel.self
        let asking = task.state == .needsYou
        return VStack(alignment: .leading, spacing: P.lineGap) {
            HStack(spacing: P.columnGap) {
                HStack(spacing: P.slotGap) {
                    AgentStateGlyph(task: task, size: P.markGlyph, paused: model.snapshotMode)
                    ChatAgentIcon(agent: agent, size: P.lineIcon)
                }
                Text(task.session)
                    .font(P.nameFont)
                    .foregroundStyle(P.nameColor)
                    .lineLimit(1)
                    .layoutPriority(1)
                if !asking {
                    AgentTaskLine(task: task)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer(minLength: 0)
                }
                if showControls, !asking {
                    AgentControls(model: model, task: task, shown: true)
                } else if let time = AgentBoard.duration(task.inState) {
                    Text(time)
                        .font(P.timeFont)
                        .monospacedDigit()
                        .foregroundStyle(P.timeColor)
                }
            }
            if asking {
                HStack(spacing: P.columnGap) {
                    AgentTaskLine(task: task, tinted: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    AgentControls(model: model, task: task, shown: true)
                        .fixedSize()
                }
                .padding(.leading, P.markGlyph + P.slotGap + P.lineIcon + P.columnGap)
            }
        }
    }

    // Badge: the state on the agent's icon, as Warp marks its agents; the time in state at the
    // right, or the controls.
    private func badge(_ agent: ChatAgent) -> some View {
        let P = WorkbenchTokens.Panel.self
        return HStack(spacing: P.columnGap) {
            ZStack(alignment: .bottomTrailing) {
                ChatAgentIcon(agent: agent, size: P.badgeIcon)
                AgentStateGlyph(task: task, size: P.badgeGlyph, paused: model.snapshotMode)
                    .padding(P.badgeRing)
                    .background(Circle().fill(Color.black))
                    .offset(x: P.badgeOffset, y: P.badgeOffset)
            }
            twoLines(tinted: true)
            if task.state == .needsYou || showControls {
                AgentControls(model: model, task: task, shown: showControls)
            } else if let time = AgentBoard.duration(task.inState) {
                Text(time)
                    .font(P.timeFont)
                    .monospacedDigit()
                    .foregroundStyle(P.timeColor)
            }
        }
    }

    // Status: two lines; the state's glyph, word and time at the right, the controls under it.
    private func status(_ agent: ChatAgent) -> some View {
        let P = WorkbenchTokens.Panel.self
        return HStack(spacing: P.columnGap) {
            ChatAgentIcon(agent: agent, size: P.icon)
            twoLines(tinted: false)
            VStack(alignment: .trailing, spacing: P.lineGap) {
                AgentStateMark(task: task, word: true, time: true, paused: model.snapshotMode)
                if task.state == .needsYou || showControls {
                    AgentControls(model: model, task: task, shown: showControls)
                }
            }
        }
    }

    // Live: the second line is the real thing, typed as it comes.
    private func live(_ agent: ChatAgent) -> some View {
        let P = WorkbenchTokens.Panel.self
        return HStack(spacing: P.columnGap) {
            ChatAgentIcon(agent: agent, size: P.icon)
            VStack(alignment: .leading, spacing: P.lineGap) {
                Text(task.session)
                    .font(P.nameFont)
                    .foregroundStyle(P.nameColor)
                    .lineLimit(1)
                AgentLiveLine(task: task, paused: model.snapshotMode)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: P.lineGap) {
                AgentStateMark(task: task, word: true, time: false, paused: model.snapshotMode)
                if task.state == .needsYou || showControls {
                    AgentControls(model: model, task: task, shown: showControls)
                }
            }
        }
    }

    /// The session, and under it the line. `tinted`: with no state word beside it, a line that
    /// asks or failed takes the state's color.
    private func twoLines(tinted: Bool) -> some View {
        let P = WorkbenchTokens.Panel.self
        return VStack(alignment: .leading, spacing: P.lineGap) {
            Text(task.session)
                .font(P.nameFont)
                .foregroundStyle(P.nameColor)
                .lineLimit(1)
            AgentTaskLine(task: task, tinted: tinted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The one line of what it is doing (or asks, or did, or why it failed). It swaps as Thinking's
/// line does, rising out of a light blur.
struct AgentTaskLine: View {
    let task: AgentTaskItem
    var tinted = false

    var body: some View {
        let P = WorkbenchTokens.Panel.self
        let T = WorkbenchTokens.Thinking.self
        Text(task.line)
            .font(P.lineFont)
            .foregroundStyle(Self.color(task, tinted: tinted))
            .lineLimit(1)
            .truncationMode(.tail)
            .id(task.line)
            .transition(.asymmetric(
                insertion: .modifier(active: LineShift(rise: T.swapRise, progress: 0), identity: LineShift(rise: T.swapRise, progress: 1)),
                removal: .opacity))
            .animation(T.swap, value: task.line)
            .accessibilityHidden(true)
    }

    static func color(_ task: AgentTaskItem, tinted: Bool) -> Color {
        let P = WorkbenchTokens.Panel.self
        if task.stalled || task.stopped { return P.quietColor }
        switch task.state {
        case .needsYou: return tinted ? P.needsYouColor : P.askColor
        case .failed: return tinted ? P.errorColor : P.lineColor
        default: return P.lineColor
        }
    }
}

/// The Live style's second line: the file, command or page it is on (with its kind's glyph), then
/// the line it is producing, typed out as it comes, in the face code is read in. When it asks,
/// the question; when done, what it did; when it fails, the error itself.
struct AgentLiveLine: View {
    let task: AgentTaskItem
    let paused: Bool
    @State private var typedFrom = Date.distantPast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let P = WorkbenchTokens.Panel.self
        HStack(spacing: P.glyphGap) {
            if task.state == .working, !task.stalled {
                Image(systemName: Self.symbol(task))
                    .font(P.objectGlyph)
                    .foregroundStyle(P.objectColor)
                    .frame(width: P.objectGlyphWidth)
                if let object = task.object {
                    Text(object)
                        .font(P.lineFont)
                        .foregroundStyle(P.objectColor)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                if let preview = task.preview {
                    typed(preview)
                }
            } else if task.state == .failed, !task.stopped, let preview = task.preview {
                Text(preview)
                    .font(P.codeFont)
                    .foregroundStyle(P.errorColor)
                    .lineLimit(1)
            } else {
                AgentTaskLine(task: task)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: task.preview) { _, _ in typedFrom = Date() }
        .accessibilityHidden(true)
    }

    /// The preview, typed in at a reading pace from the moment it changed; whole when still.
    private func typed(_ preview: String) -> some View {
        let P = WorkbenchTokens.Panel.self
        let still = paused || reduceMotion
        return TimelineView(.animation(minimumInterval: 1 / 30, paused: still)) { context in
            let elapsed = context.date.timeIntervalSince(typedFrom)
            let shown = still ? preview.count : min(preview.count, max(0, Int(elapsed * P.typeRate)))
            Text(String(preview.prefix(shown)))
                .font(P.codeFont)
                .foregroundStyle(P.codeColor)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    static func symbol(_ task: AgentTaskItem) -> String {
        switch task.work {
        case .reading: return "doc.text"
        case .editing: return task.object?.hasSuffix(".swift") == true ? "swift" : "pencil"
        case .running: return "terminal"
        case .browsing: return "globe"
        case .thinking: return "ellipsis"
        case .asking: return "questionmark"
        case .done: return "checkmark"
        case .failed: return "exclamationmark.triangle"
        }
    }
}

/// A filled state symbol: in Original, its mark black on the disc (the island's black shows
/// through); in Native, the system's monochrome symbol in the state's color, the mark cut out.
struct StateMark: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        if WorkbenchTokens.isNative {
            content.foregroundStyle(color)
        } else {
            content.foregroundStyle(Color.black, color)
        }
    }
}

/// The state as a glyph, the way Linear and GitHub mark it: a ring turning while it works (still
/// and dashed once it has gone quiet), amber for needs you, a check when done, red when it
/// failed, a square when stopped.
struct AgentStateGlyph: View {
    let task: AgentTaskItem
    let size: CGFloat
    let paused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let P = WorkbenchTokens.Panel.self
        Group {
            if task.stopped {
                Image(systemName: "stop.circle.fill").resizable()
                    .modifier(StateMark(color: P.quietColor))
            } else {
                switch task.state {
                case .working:
                    if task.stalled {
                        Circle()
                            .strokeBorder(P.quietColor, style: StrokeStyle(lineWidth: P.ringWidth, dash: P.stallDash))
                    } else {
                        spinner
                    }
                case .needsYou:
                    Image(systemName: "exclamationmark.circle.fill").resizable()
                        .modifier(StateMark(color: P.needsYouColor))
                case .complete:
                    Image(systemName: "checkmark.circle.fill").resizable()
                        .modifier(StateMark(color: P.completeColor))
                case .failed:
                    Image(systemName: "xmark.circle.fill").resizable()
                        .modifier(StateMark(color: P.failedColor))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Working: a quarter of the ring going round, slowly.
    private var spinner: some View {
        let P = WorkbenchTokens.Panel.self
        let still = paused || reduceMotion
        return TimelineView(.animation(minimumInterval: 1 / 30, paused: still)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let turn = still ? P.spinStill : (t / P.spinPeriod).truncatingRemainder(dividingBy: 1)
            ZStack {
                Circle().strokeBorder(P.ringTrack, lineWidth: P.ringWidth)
                Circle()
                    .inset(by: P.ringWidth / 2)
                    .trim(from: 0, to: P.spinArc)
                    .stroke(P.workingColor, style: StrokeStyle(lineWidth: P.ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(turn * 360 - 90))
            }
        }
    }
}

/// The state's glyph and word, in the state's color; with how long, quietly, if asked.
struct AgentStateMark: View {
    let task: AgentTaskItem
    let word: Bool
    let time: Bool
    let paused: Bool

    var body: some View {
        let P = WorkbenchTokens.Panel.self
        HStack(spacing: P.markGap) {
            AgentStateGlyph(task: task, size: P.markGlyph, paused: paused)
            if word {
                (Text(task.stateWord).foregroundStyle(Self.color(task))
                 + Text(time ? (AgentBoard.duration(task.inState).map { " · \($0)" } ?? "") : "").foregroundStyle(P.timeColor))
                    .font(P.stateFont)
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .animation(P.change, value: task.state)
    }

    static func color(_ task: AgentTaskItem) -> Color {
        let P = WorkbenchTokens.Panel.self
        if task.stopped || task.stalled { return P.quietColor }
        switch task.state {
        case .working: return P.workingColor
        case .needsYou: return P.needsYouColor
        case .complete: return P.completeColor
        case .failed: return P.failedColor
        }
    }
}

/// A row's controls: what a task waiting on the person asks, answered here, always; otherwise
/// the one thing to do with it, under the pointer or the keyboard: Stop, Retry, Open.
struct AgentControls: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let shown: Bool
    /// Little room (a Desk card): Native's approval verb in its short form.
    var short = false

    var body: some View {
        let P = WorkbenchTokens.Panel.self
        HStack(spacing: P.buttonGap) {
            if let ask = task.ask, task.state == .needsYou {
                switch ask {
                case .approval(let command):
                    AgentPanelButton(title: "Deny", primary: false) { guarded { model.denyTask(task.id) } }
                    // Native: the action's own verb (Run Tests), Allow in Original.
                    let verb = ApprovalVerb.of(command)
                    AgentPanelButton(title: WorkbenchTokens.skin("Allow", short ? verb.short : verb.title), primary: true) {
                        guarded { model.allowTask(task.id) }
                    }
                case .choice(let options):
                    ForEach(options, id: \.self) { option in
                        AgentPanelButton(title: option, primary: false) { guarded { model.answerTask(task.id, option) } }
                    }
                }
            } else if shown {
                switch task.state {
                case .working:
                    AgentPanelButton(title: "Stop", symbol: "stop.fill", primary: false) { guarded { model.stopTask(task.id) } }
                case .failed:
                    AgentPanelButton(title: "Retry", symbol: "arrow.clockwise", primary: false) { guarded { model.retryTask(task.id) } }
                case .complete:
                    AgentPanelButton(title: "Open", symbol: "arrow.up.forward", primary: false) { model.openTask(task.id) }
                case .needsYou:
                    EmptyView()
                }
            }
        }
        .fixedSize()
        .transition(.opacity)
        .animation(P.controlsFade, value: shown)
    }

    /// A click in the first moment after the panel opens was meant for what was under the
    /// pointer, not for this: it does nothing.
    private func guarded(_ action: () -> Void) {
        if model.panelControlsLive { action() }
    }
}

/// A small capsule button in a row: the island's gray (Copy's), white words; the primary one
/// white with black words.
struct AgentPanelButton: View {
    let title: String
    var symbol: String? = nil
    let primary: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let P = WorkbenchTokens.Panel.self
        Button(action: action) {
            HStack(spacing: P.buttonSymbolGap) {
                if let symbol { Image(systemName: symbol).font(P.buttonSymbol) }
                Text(title)
            }
            .font(P.buttonFont)
            .foregroundStyle(primary ? P.buttonPrimaryText : P.buttonText)
            .padding(.horizontal, P.buttonPaddingH)
            .frame(height: P.buttonHeight)
            .background(Capsule(style: .continuous)
                .fill(primary ? (hovering ? P.buttonPrimaryHover : P.buttonPrimary) : (hovering ? P.buttonFillHover : P.buttonFill)))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(WorkbenchTokens.Chat.hover, value: hovering)
    }
}

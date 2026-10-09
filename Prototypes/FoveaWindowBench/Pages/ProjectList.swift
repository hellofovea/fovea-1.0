import SwiftUI
import WindowBenchCore

/// 2a · the project list: groups in the brief's order (stuck → to look at → running → earlier),
/// hairlines only between groups, quiet projects behind one fold. Never a catch-all bucket.
struct ProjectListPage: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if model.library.projects.isEmpty {
                    // As onboarding's Nothing found: the one gesture, and the way back to the import.
                    VStack(spacing: 18) {
                        TeachingLine()
                        Button("Read my history") { model.goTo(onboarding: .consent) }
                            .controlSize(.regular)
                    }
                    .padding(.top, 180)
                } else {
                    ProjectListContent(revealCount: nil)
                }
            }
            .frame(maxWidth: BenchTokens.Layout.column)
            .padding(.horizontal, BenchTokens.Layout.sideMargin)
            .padding(.top, BenchTokens.Layout.topMargin)
            .padding(.bottom, BenchTokens.Layout.bottomMargin)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.automatic)
    }
}

/// The list itself, shared with onboarding's reveal: `revealCount` is how many projects have
/// arrived (nil: all of them, no reveal).
struct ProjectListContent: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let revealCount: Int?
    /// Projects that just changed group. They travel above everything else, on the page's own
    /// color, so a row passing others (or a group's label) covers them instead of printing over them.
    @State private var movers: Set<String> = []

    var body: some View {
        let failed = model.v(FailedPlacementVariant.self).placement
        let items = ProjectIndex.list(model.index, failed: failed, olderOpen: false)
        let older = ProjectIndex.summaries(model.index, failed: failed).filter(\.sunk).sorted { $0.lastActivity > $1.lastActivity }
        let mergePair = model.inlineMerge
        let hidden = mergePair.map { Set([$0.first, $0.second]) } ?? []
        let reveal = model.v(RevealStyle.self)
        let layout = RevealLayout(items: items, density: model.v(DensityVariant.self), labeled: model.v(GroupLabels.self) == .labeled)
        let count = revealCount ?? Int.max
        let unfold = revealCount != nil && reveal == .unfold && !model.motion.reduce

        VStack(alignment: .leading, spacing: 0) {
            if let mergePair { InlineMergeBlock(suggestion: mergePair) }
            ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                let order = layout.order[offset]
                let arrived = order < count || unfold
                if arrived, !(item.projectID.map(hidden.contains) ?? false) {
                    Group {
                        switch item {
                        case .header(let group):
                            GroupHeader(group: group, first: offset == 0)
                        case .project(let summary):
                            ProjectRow(summary: summary)
                        case .olderFold(let n):
                            FoldRow(title: ProjectIndex.olderTitle(n), open: model.openFold == "older") {
                                model.toggleFold("older")
                            }
                            .padding(.top, BenchTokens.Layout.groupGap)
                            .overlay(alignment: .top) {
                                Rectangle().fill(palette.hairline).frame(height: BenchTokens.Layout.hairline)
                                    .padding(.top, BenchTokens.Layout.groupGap / 2)
                            }
                        }
                    }
                    .modifier(UnfoldRow(shown: !unfold || order < count))
                    .transition(revealCount == nil ? .opacity : arrival(reveal, y: layout.y[offset], header: item.isHeader))
                    .zIndex(item.projectID.map { movers.contains($0) ? 2 : 1 } ?? 0)
                }
            }
            if count == Int.max {
                InlineExpand(open: model.openFold == "older") {
                    VStack(spacing: 0) {
                        ForEach(older) { summary in ProjectRow(summary: summary) }
                    }
                }
            }
        }
        .modifier(UnfoldClip(height: layout.height(upTo: count), active: unfold))
        .animation(model.motion.animation(.open), value: items.map(\.id))
        .onChange(of: Self.groups(items)) { old, new in
            movers = Set(new.keys.filter { old[$0] != nil && old[$0] != new[$0] })
        }
    }

    private static func groups(_ items: [ProjectListItem]) -> [String: ProjectGroup] {
        var map: [String: ProjectGroup] = [:]
        for case .project(let summary) in items { map[summary.id] = summary.group }
        return map
    }

    /// How a project arrives in the reveal, per the Reveal switch.
    private func arrival(_ style: RevealStyle, y: CGFloat, header: Bool) -> AnyTransition {
        let V = BenchTokens.MotionValues.self
        if model.motion.reduce || style == .allAtOnce || header { return .opacity }
        switch style {
        case .stagger:
            return .modifier(active: Arrive(dy: V.rowRise, blur: V.rowBlur, scale: 1, opacity: 0),
                             identity: Arrive(dy: 0, blur: 0, scale: 1, opacity: 1))
        case .fromSummary:
            // Down from the counts line, a short drop: less than half a row, so rows never stack
            // on each other or on a group label.
            return .modifier(active: Arrive(dy: -V.revealDrop, blur: V.rowBlur, scale: 1, opacity: 0),
                             identity: Arrive(dy: 0, blur: 0, scale: 1, opacity: 1))
        case .fromNotch:
            // The long fall from the notch, unseen until the last stretch, so a falling row never
            // passes over one that has landed.
            return .modifier(active: Arrive(dy: -y - 150, blur: V.rowBlur, scale: 0.86, opacity: 0, fadeLate: true),
                             identity: Arrive(dy: 0, blur: 0, scale: 1, opacity: 1, fadeLate: true))
        case .unfold, .allAtOnce:
            return .opacity
        }
    }
}

private struct Arrive: ViewModifier, Animatable {
    var dy: CGFloat
    var blur: CGFloat
    var scale: CGFloat
    var opacity: Double
    var fadeLate = false
    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, Double>> {
        get { AnimatablePair(AnimatablePair(dy, blur), AnimatablePair(scale, opacity)) }
        set { dy = newValue.first.first; blur = newValue.first.second; scale = newValue.second.first; opacity = newValue.second.second }
    }
    func body(content: Content) -> some View {
        // Fading late: invisible for the first three quarters of the way.
        let shown = fadeLate ? max(0, (opacity - 0.75) / 0.25) : opacity
        content.offset(y: dy).blur(radius: blur).scaleEffect(scale, anchor: .top).opacity(shown)
    }
}

/// Unfold: the list's height grows a row at a time, like the notch opening.
private struct UnfoldClip: ViewModifier, Animatable {
    var height: CGFloat
    let active: Bool
    var animatableData: CGFloat {
        get { height }
        set { height = newValue }
    }
    func body(content: Content) -> some View {
        if active {
            content.frame(height: max(0, height), alignment: .top).clipped()
        } else {
            content
        }
    }
}

/// Unfold: a row not yet arrived keeps its place but waits, faded, behind the growing edge.
private struct UnfoldRow: ViewModifier {
    @Environment(BenchModel.self) private var model
    let shown: Bool
    func body(content: Content) -> some View {
        content.contentReveal(shown ? 1 : 0)
    }
}

/// Where each item sits, for the reveal's journeys and the unfold's height. Headers arrive with
/// their group's first project.
struct RevealLayout {
    var order: [Int] = []
    var y: [CGFloat] = []
    var heights: [CGFloat] = []

    init(items: [ProjectListItem], density: DensityVariant, labeled: Bool) {
        let L = BenchTokens.Layout.self
        let row = density == .regular ? L.projectRow.regular : L.projectRow.compact
        var projects = 0
        var cursor: CGFloat = 0
        for (i, item) in items.enumerated() {
            let height: CGFloat
            switch item {
            case .header: height = (i == 0 ? 0 : L.groupGap) + (labeled ? L.headerHeight : L.groupGap / 2)
            case .project: height = row
            case .olderFold: height = L.runRow.regular + L.groupGap
            }
            order.append(item.isHeader ? projects : projects)
            if !item.isHeader { projects += 1 }
            y.append(cursor)
            heights.append(height)
            cursor += height
        }
    }

    /// The list's height once `count` projects have arrived.
    func height(upTo count: Int) -> CGFloat {
        var total: CGFloat = 0
        for (i, h) in heights.enumerated() where order[i] < count { total += h }
        return total
    }
}

extension ProjectListItem {
    var isHeader: Bool { if case .header = self { return true } else { return false } }
    var projectID: String? { if case .project(let s) = self { return s.id } else { return nil } }
}

/// A group: a hairline from the previous one, and its name when the Group labels switch says.
struct GroupHeader: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let group: ProjectGroup
    let first: Bool

    var body: some View {
        let labeled = model.v(GroupLabels.self) == .labeled
        let L = BenchTokens.Layout.self
        VStack(alignment: .leading, spacing: 0) {
            if !first {
                Rectangle().fill(palette.hairline).frame(height: L.hairline)
                    .padding(.top, L.groupGap - L.hairline)
            }
            if labeled {
                Text(group.title)
                    .font(.system(size: BenchTokens.Type_.scale(model.v(TypeScale.self)).section, weight: .semibold))
                    .foregroundStyle(palette.tertiary)
                    .padding(.horizontal, L.rowPaddingH)
                    .frame(height: L.headerHeight, alignment: .bottomLeading)
                    .padding(.bottom, 2)
            } else if !first {
                Color.clear.frame(height: L.groupGap / 2)
            }
        }
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(group.title)
    }
}

/// glyph · name · its computed meta in mono · when it last moved, in mono. One click opens it.
struct ProjectRow: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let summary: ProjectSummary
    @State private var hover = false

    var body: some View {
        let scale = BenchTokens.Type_.scale(model.v(TypeScale.self))
        let L = BenchTokens.Layout.self
        let compact = model.v(DensityVariant.self) == .compact
        let key = "project/\(summary.id)"
        let arriving = model.index.runs(inProject: summary.id).contains { model.arrivals.contains($0.id) }
        HStack(spacing: L.glyphGap) {
            StateGlyph(state: summary.state, arriving: arriving)
                .modifier(PulseOnHighlight(key: key))
            VStack(alignment: .leading, spacing: compact ? 1 : 3) {
                Text(summary.project.name)
                    .font(.system(size: scale.body, weight: .medium))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .rowFrame("title/\(key)")
                    .opacity(model.morphingTitle == summary.id ? 0 : 1)
                Text(summary.meta)
                    .font(BenchTokens.Type_.mono(scale.meta))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 12)
            StateWord(state: summary.state)
            TrailingSlot(hover: hover || model.hoverKey == key, width: 64, actions: projectActions) {
                AgeText(date: summary.lastActivity)
            }
        }
        .padding(.horizontal, L.rowPaddingH)
        .frame(height: compact ? L.projectRow.compact : L.projectRow.regular)
        .background(RoundedRectangle(cornerRadius: L.rowRadius, style: .continuous).fill(hover || model.hoverKey == key ? palette.hover : .clear))
        // The page's color under the row, so a row that travels covers what it passes.
        .background(PageFill())
        .contentShape(Rectangle())
        .jumpHighlight(key)
        .rowFrame(key)
        .onHover { hover = $0 }
        .onTapGesture { open() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { open() }
        .help("Open \(summary.project.name)")
        .id(key)
    }

    private var projectActions: [RowAction] {
        let observable = model.index.threads(in: summary.id).contains(where: \.observable)
        guard observable, summary.project.scan == nil else { return [] }
        return [RowAction(title: "Brief") {
            model.goToProject(summary.id)
            model.requestBrief(summary.id)
        }]
    }

    private func open() {
        guard model.state.onboarding == nil else { return }
        model.drill(into: .project(summary.id), from: "project/\(summary.id)")
    }
}

/// The product's one gesture, as teaching copy: the window never binds it.
struct TeachingLine: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let copy = model.v(GestureCopy.self)
        let lead = copy.lead, tail = copy.tail
        HStack(spacing: 6) {
            Text(lead)
            KeyCap("fn")
            KeyCap("⌃")
            Text(tail)
        }
        .font(BenchTokens.Type_.teaching)
        .foregroundStyle(palette.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(lead) function and control \(tail)")
    }
}

/// A key printed on a cap: teaching copy only, never a shortcut.
struct KeyCap: View {
    @Environment(\.palette) private var palette
    let label: String
    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(palette.text)
            .padding(.horizontal, 6)
            .frame(minWidth: 22, minHeight: 20)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(palette.fill))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(palette.hairline))
    }
}

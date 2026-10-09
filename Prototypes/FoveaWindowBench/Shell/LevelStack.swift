import SwiftUI
import WindowBenchCore

/// Rows report their frames so a level can open from the row that was clicked, and close
/// back onto it. Keys carry their context (`run/<thread>/<run>`): a run can show twice.
struct RowFrames: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Marks a row as a place a level can open from and land back on.
    func rowFrame(_ key: String) -> some View {
        // Merged, not set: a row and the title inside it both report.
        transformAnchorPreference(key: RowFrames.self, value: .bounds) { value, anchor in value[key] = anchor }
    }
}

/// One section's levels, drilled into in place. Every level stays mounted (covered ones are
/// hidden and inert) so going back lands where you were, scroll and all. Push and Cross-fade
/// are plain transitions; Zoom and Notch expand run the ghost: a shape carried from the row to
/// the page on the notch's spring, the page revealed from it.
struct LevelStack: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let section: WindowSection

    /// 0 = the lower level, 1 = the upper one, while a ghost transition runs.
    @State private var progress: CGFloat = 1
    @State private var running: LevelTransition?

    var body: some View {
        let entries = section == .project ? model.state.projectPath : model.state.capturePath
        let style = model.v(DrillStyle.self)
        // A ghost transition the model just started: its first frame draws the start state,
        // before onChange hands it to `running`, so the new page never flashes in whole.
        let pending = running == nil ? pendingGhost : nil
        let active = running ?? pending
        let shown = running != nil ? progress : (pending.map { $0.direction == .into ? 0 : 1 } ?? progress)
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { depth, entry in
                    let role = role(depth: depth, count: entries.count, active: active)
                    LevelContent(level: entry.level)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .modifier(LevelPresentation(role: role, style: style, progress: shown, running: active))
                        // An arrival (带我去, a jump from the notch): the page you were on leaves on
                        // the content curve, and the arriving one comes in just after it (its
                        // transition carries its own delay), so the two are never read together.
                        .transaction { t in if model.arrivalFade { t.animation = model.motion.animation(.content) } }
                        .allowsHitTesting(role == .top && active == nil)
                        .accessibilityHidden(role != .top)
                        .zIndex(Double(depth))
                        .transition(levelTransition(style))
                }
            }
            .backgroundPreferenceValue(RowFrames.self) { anchors in
                // Notch expand: the page's surface grows from the row beneath the content.
                if let running, running.style == .notchExpand, let key = running.sourceKey, let anchor = anchors[key] {
                    let source = geo[anchor]
                    let bounds = CGRect(origin: .zero, size: geo.size)
                    if bounds.intersects(source) {
                        Ghost(style: running.style, from: source, to: bounds, progress: progress)
                            .allowsHitTesting(false)
                    }
                }
            }
            .overlayPreferenceValue(RowFrames.self) { anchors in
                if let running, running.style == .zoom, let key = running.sourceKey, let anchor = anchors[key] {
                    let source = geo[anchor]
                    let bounds = CGRect(origin: .zero, size: geo.size)
                    if bounds.intersects(source) {
                        ZStack(alignment: .topLeading) {
                            Ghost(style: running.style, from: source, to: bounds, progress: progress)
                            // Zoom: the project's name travels from its row to its page's title.
                            if running.style == .zoom, key.hasPrefix("project/"),
                               let from = anchors["title/\(key)"], let to = anchors["header/\(key)"] {
                                let id = String(key.dropFirst("project/".count))
                                GhostTitle(text: model.index.projectByID[id]?.name ?? "", from: geo[from], to: geo[to],
                                           fromSize: BenchTokens.Type_.scale(model.v(TypeScale.self)).body, progress: progress)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .onChange(of: model.transition) { _, transition in
            guard let transition, section == model.state.section else { return }
            run(transition)
        }
    }

    /// In a ghost transition, `upper` is the deeper level (shown by progress) and `lower` the one
    /// under it (shown by 1 − progress), whichever way the transition runs.
    enum Role { case top, upper, lower, covered }

    private var pendingGhost: LevelTransition? {
        guard let t = model.transition, section == model.state.section, !model.motion.reduce,
              t.style == .zoom || t.style == .notchExpand else { return nil }
        return t
    }

    private func role(depth: Int, count: Int, active: LevelTransition?) -> Role {
        if let running = active {
            if depth == running.depth { return .upper }
            if depth == running.depth - 1 { return .lower }
        }
        return depth == count - 1 ? .top : .covered
    }

    private func levelTransition(_ style: DrillStyle) -> AnyTransition {
        if model.motion.reduce { return .opacity }
        if model.arrivalFade {
            let motion = model.motion
            return .asymmetric(insertion: .modifier(active: RevealIn(progress: 0), identity: RevealIn(progress: 1))
                                .animation(motion.animation(.content).delay(motion.seconds(BenchTokens.MotionValues.contentDuration * 0.6))),
                               removal: .opacity.animation(motion.animation(.content)))
        }
        switch style {
        case .push:
            return .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                               removal: .move(edge: .trailing).combined(with: .opacity))
        case .crossFade:
            return .modifier(active: FadeBlur(progress: 0), identity: FadeBlur(progress: 1))
        case .zoom, .notchExpand:
            return .identity
        }
    }

    private func run(_ transition: LevelTransition) {
        guard !model.motion.reduce, transition.style == .zoom || transition.style == .notchExpand else {
            model.transition = nil
            return
        }
        // Turned back mid-way (in, then out of the same level, or the reverse): the motion carries
        // on from where it is, on the new spring, instead of starting over.
        let reversing = running.map { $0.depth == transition.depth && $0.direction != transition.direction } ?? false
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            running = transition
            if !reversing { progress = transition.direction == .into ? 0 : 1 }
            if transition.style == .zoom, let key = transition.sourceKey, key.hasPrefix("project/") {
                model.morphingTitle = String(key.dropFirst("project/".count))
            }
        }
        let animation = model.motion.animation(transition.direction == .into ? .expand : .collapse)
        DispatchQueue.main.async {
            withAnimation(animation, completionCriteria: .logicallyComplete) {
                progress = transition.direction == .into ? 1 : 0
            } completion: {
                // A motion that was turned back ends with the one that replaced it.
                guard running?.id == transition.id else { return }
                if transition.direction == .outOf { model.finishPop() }
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) {
                    running = nil
                    progress = 1
                    model.morphingTitle = nil
                }
                if model.transition?.id == transition.id { model.transition = nil }
            }
        }
    }
}

/// How a level shows for its role: the top one plainly; covered ones hidden (pushed aside
/// under Push); the two in a ghost transition revealed and faded by its progress.
private struct LevelPresentation: ViewModifier, Animatable {
    let role: LevelStack.Role
    let style: DrillStyle
    var progress: CGFloat
    let running: LevelTransition?

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let V = BenchTokens.MotionValues.self
        switch role {
        case .top:
            content
        case .covered:
            content
                .opacity(0)
                .offset(x: style == .push ? -BenchTokens.MotionValues.pushDistance : 0)
        case .lower:
            // Zoom clears the old level early, so the two pages never sit on each other.
            content.opacity(Double(style == .zoom ? max(0, 1 - progress * 2.2) : 1 - progress))
        case .upper:
            if style == .notchExpand {
                // The page waits a beat behind the growing surface, as the notch's content does.
                content.contentReveal(max(0, min(1, (progress - 0.2) / 0.8)))
            } else {
                // Zoom: the row's fill has grown to the page's frame before the page comes in,
                // on the notch's content entrance, inside it.
                content.contentReveal(max(0, min(1, (progress - V.zoomContentStart) / (1 - V.zoomContentStart))))
            }
        }
    }
}

/// The ghost: the clicked row's shape carried to the page's frame. Zoom grows a quiet fill out
/// of the row that dissolves as the page arrives; Notch expand grows the page's own surface,
/// opening downward like the notch, and holds until the page is in.
private struct Ghost: View, Animatable {
    @Environment(\.palette) private var palette
    let style: DrillStyle
    let from: CGRect
    let to: CGRect
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let p = progress
        let rect = CGRect(x: from.minX + (to.minX - from.minX) * p, y: from.minY + (to.minY - from.minY) * p,
                          width: from.width + (to.width - from.width) * p, height: from.height + (to.height - from.height) * p)
        let radius = BenchTokens.Layout.rowRadius * (1 - p) + (style == .notchExpand ? BenchTokens.Notch.bottomRadius * p * (1 - p) : 0)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        Group {
            if style == .notchExpand {
                // A raised surface with a hairline, under the content, dissolving as it lands.
                shape.fill(palette.raised)
                    .overlay(shape.strokeBorder(palette.hairline, lineWidth: 1))
                    .shadow(color: .black.opacity(palette.isDark ? 0.4 : 0.08), radius: 10, y: 4)
                    .opacity(Double(min(1, (1 - p) * 4)))
            } else {
                // Zoom: the row's own fill, carried all the way to the page's frame and held there
                // while the page comes in over it, then gone.
                shape.fill(palette.selected)
                    .opacity(Double(p < BenchTokens.MotionValues.zoomFillHold ? 1 : max(0, (1 - p) / (1 - BenchTokens.MotionValues.zoomFillHold))))
            }
        }
        .frame(width: max(0, rect.width), height: max(0, rect.height))
        .position(x: rect.midX, y: rect.midY)
    }
}

/// Cross-fade with the notch's light blur.
struct FadeBlur: ViewModifier, Animatable {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        content.opacity(Double(progress)).blur(radius: (1 - progress) * BenchTokens.MotionValues.crossFadeBlur)
    }
}

/// A level's page.
struct LevelContent: View {
    let level: Level

    var body: some View {
        switch level {
        case .projects: ProjectListPage()
        case .project(let id): ProjectPage(projectID: id)
        case .run(let id): RunPage(runID: id)
        case .captures: CaptureStreamPage()
        case .capture(let id): CapturePage(captureID: id)
        }
    }
}

/// The name in flight: drawn at the title's size and scaled down to the row's at the start, so
/// the type grows rather than re-wrapping.
private struct GhostTitle: View, Animatable {
    @Environment(\.palette) private var palette
    let text: String
    let from: CGRect
    let to: CGRect
    let fromSize: CGFloat
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let p = progress
        let titleSize: CGFloat = 22
        let scale = (fromSize / titleSize) + (1 - fromSize / titleSize) * p
        let x = from.minX + (to.minX - from.minX) * p
        let y = from.minY + (to.minY - from.minY) * p
        Text(text)
            .font(.system(size: titleSize, weight: p > 0.5 ? .semibold : .medium))
            .foregroundStyle(palette.text)
            .lineLimit(1)
            .fixedSize()
            .scaleEffect(scale, anchor: .topLeading)
            .offset(x: x, y: y + (to.height - to.height * scale) * 0)
    }
}

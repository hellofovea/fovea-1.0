import SwiftUI
import FoveaCore

// Quick actions' Thinking: the agent at work. The Lasso moves while one line says what the
// agent is doing on the Mac, with the app it drives and the action's symbol; never a log. docs/island/AGENT_VOICE_AND_THINKING.md has the references.

/// Where Thinking's parts go. Coordinates are from the island's top-left corner.
struct AgentLayout: Equatable {
    var outline: StackLayout.Outline
    var layout: ActivityLayout
    /// The mark's center; nil for the styles drawn on the edge.
    var markCenter: CGPoint?
    var lineRect: CGRect
    var lineCentered: Bool
    /// The app and the action's symbol, together.
    var clusterCenter: CGPoint

    static func make(_ layout: ActivityLayout, hasMark: Bool, metrics: ScreenMetrics) -> AgentLayout {
        let T = WorkbenchTokens.Thinking.self
        let spec = WorkbenchTokens.Island.spec
        let notch = NotchGeometry.notchRect(metrics: metrics, spec: spec)
        let ear = spec.compactTopRadius
        let cluster = T.appIconSize + T.clusterSpacing + T.appIconSize
        switch layout {
        case .under:
            let w = T.underWidth, h = notch.height + spec.voiceBelow
            let mid = notch.height + spec.voiceBelow / 2
            let left = ear + T.paddingH
            let right = w - ear - T.paddingH
            let mark = CGPoint(x: left + T.markSize / 2, y: mid)
            let clusterCenter = CGPoint(x: right - cluster / 2, y: mid)
            let lineX = hasMark ? left + T.markSize + T.gap : left
            let lineRight = right - cluster - T.gap
            return AgentLayout(outline: .init(size: CGSize(width: w, height: h), topRadius: spec.compactTopRadius,
                                              bottomRadius: spec.compactBottomRadius),
                               layout: layout, markCenter: hasMark ? mark : nil,
                               lineRect: CGRect(x: lineX, y: mid - 11, width: lineRight - lineX, height: 22),
                               lineCentered: false, clusterCenter: clusterCenter)
        case .beside:
            let w = notch.width + 2 * T.wingWidth + 2 * ear, h = notch.height + T.besideBand
            let wingMid = notch.height / 2
            let mark = CGPoint(x: ear + T.wingWidth / 2, y: wingMid)
            let clusterCenter = CGPoint(x: w - ear - T.wingWidth / 2, y: wingMid)
            let lineX = ear + T.paddingH
            return AgentLayout(outline: .init(size: CGSize(width: w, height: h), topRadius: spec.compactTopRadius,
                                              bottomRadius: spec.compactBottomRadius),
                               layout: layout, markCenter: hasMark ? mark : nil,
                               lineRect: CGRect(x: lineX, y: notch.height + (T.besideBand - 22) / 2 - 2, width: w - 2 * lineX, height: 22),
                               lineCentered: true, clusterCenter: clusterCenter)
        }
    }
}

/// Thinking's content in the island: the mark, the line, the app and the action.
struct AgentActivityContent: View {
    let model: WorkbenchModel
    let layout: AgentLayout

    var body: some View {
        let T = WorkbenchTokens.Thinking.self
        let action = model.agentAction ?? .think
        let needsYou = action == .needsYou
        ZStack(alignment: .topLeading) {
            Color.clear
            if let mark = layout.markCenter {
                ThinkingMark(model: model)
                    .frame(width: T.markSize, height: T.markSize)
                    .position(mark)
            }
            AgentLine(text: action.line, tone: action.tone, centered: layout.lineCentered)
                .frame(width: layout.lineRect.width, height: layout.lineRect.height)
                .position(x: layout.lineRect.midX, y: layout.lineRect.midY)
            ZStack {
                AgentCluster(app: action.app ? model.dockIcons.safari : nil, symbol: action.symbol, tone: action.tone)
                    .opacity(needsYou ? 0 : 1)
                // Needs you: the one control, in the cluster's place.
                AllowPill { model.allowAgent() }
                    .opacity(needsYou ? 1 : 0)
                    .allowsHitTesting(needsYou)
            }
            .animation(T.swap, value: needsYou)
            .position(layout.clusterCenter)
        }
        .frame(width: layout.outline.size.width, height: layout.outline.size.height, alignment: .topLeading)
        .animation(model.islandAnimation, value: layout)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Agent at work")
        .accessibilityValue(action.line)
    }
}

/// The one line: it swaps as thinking-orbs' status line does, the new words rising 8 pt out of
/// a 2 pt blur while the old ones leave upward.
struct AgentLine: View {
    let text: String
    var tone: AgentTone = .normal
    let centered: Bool

    var body: some View {
        let T = WorkbenchTokens.Thinking.self
        ZStack {
            Text(text)
                .font(T.line)
                .foregroundStyle(tone == .needsYou ? T.needsYouColor : T.lineColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
                .id(text)
                .transition(.asymmetric(
                    insertion: .modifier(active: LineShift(rise: T.swapRise, progress: 0), identity: LineShift(rise: T.swapRise, progress: 1)),
                    removal: .modifier(active: LineShift(rise: -T.swapRise, progress: 0), identity: LineShift(rise: -T.swapRise, progress: 1))))
        }
        .animation(T.swap, value: text)
    }
}

struct LineShift: ViewModifier {
    let rise: CGFloat
    let progress: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .blur(radius: (1 - progress) * WorkbenchTokens.Thinking.swapBlur)
            .offset(y: (1 - progress) * rise)
    }
}

/// The app the agent drives, in grayscale, and what it is doing to it; the symbol swaps with
/// SF Symbols' replace.
struct AgentCluster: View {
    let app: NSImage?
    let symbol: String?
    var tone: AgentTone = .normal

    var body: some View {
        let T = WorkbenchTokens.Thinking.self
        HStack(spacing: T.clusterSpacing) {
            Group {
                if let app {
                    Image(nsImage: app).resizable().interpolation(.high).grayscale(1)
                } else {
                    Color.clear
                }
            }
            .frame(width: T.appIconSize, height: T.appIconSize)
            .opacity(app == nil ? 0 : T.appIconOpacity)
            Image(systemName: symbol ?? "circle")
                .font(T.actionGlyph)
                .foregroundStyle(tone == .failed ? T.failedColor : T.actionColor)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: T.appIconSize, height: T.appIconSize)
                .opacity(symbol == nil ? 0 : 1)
        }
        .animation(T.swap, value: symbol)
        .animation(T.swap, value: app == nil)
    }
}

/// The mark: the Lasso, Fovea's own gesture (circling a thing on screen) as the orb that says
/// the agent is working. It moves while the agent works; while the agent waits on the person or
/// is done, and under Reduce Motion, it holds its loop at its most whole.
struct ThinkingMark: View {
    let model: WorkbenchModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let T = WorkbenchTokens.Thinking.self
        let frozen = model.snapshotMode || reduceMotion
        let shown = model.notchState == .quickThinking
        let still = model.agentAction?.holdsStill ?? false
        TimelineView(.animation(minimumInterval: 1 / T.frameRate, paused: !shown || frozen || still)) { context in
            Canvas { ctx, size in
                let t = still || reduceMotion ? LassoRenderer.rest
                    : frozen ? T.stillTime : context.date.timeIntervalSinceReferenceDate
                LassoRenderer.draw(in: &ctx, size: size, time: t)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Working")
    }
}

/// The Lasso: a hand-drawn circle (a little uneven, overlapping where it closes) traced and
/// erased behind its bright tip, starting somewhere new each loop.
enum LassoRenderer {
    /// The moment it holds when still: the head just round, the loop at its most whole.
    static var rest: Double {
        let L = WorkbenchTokens.Lasso.self
        return L.period / (1 + L.length)
    }

    static func draw(in ctx: inout GraphicsContext, size: CGSize, time t: Double) {
        let L = WorkbenchTokens.Lasso.self
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let loop = (t / L.period).rounded(.down)
        let head = (t / L.period - loop) * (1 + L.length)
        let from = max(0, head - L.length), to = min(1, head)
        guard to > from else { return }
        let radii = CGSize(width: L.radius, height: L.radius)
        let start = loop * L.advance, seed = t * L.waverDrift
        let path = loopPath(center: c, radii: radii, start: start, turns: L.turns, from: from, to: to, seed: seed)
        ctx.stroke(path, with: .color(.white.opacity(L.opacity)),
                   style: StrokeStyle(lineWidth: L.weight, lineCap: .round, lineJoin: .round))
        if head <= 1 {
            let p = loopPoint(center: c, radii: radii, start: start, turns: L.turns, seed: seed, at: to)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - L.head / 2, y: p.y - L.head / 2, width: L.head, height: L.head)),
                     with: .color(.white))
        }
    }

    /// A point of the hand loop, `s` (0…1) along it: a circle, or with unequal radii an ellipse,
    /// `turns` round from `start`; its radius wavers as a hand's does (`seed` turns the waver)
    /// and closes in a little as it comes round.
    static func loopPoint(center c: CGPoint, radii: CGSize, start: Double, turns: Double, seed: Double, at s: Double) -> CGPoint {
        let L = WorkbenchTokens.Lasso.self
        let theta = start + 2 * .pi * turns * s
        let k = 1 + L.waver2 * sin(2 * theta + seed) + L.waver3 * sin(3 * theta + 1.1) - L.shrink * s
        return CGPoint(x: c.x + CGFloat(cos(theta) * k) * radii.width, y: c.y + CGFloat(sin(theta) * k) * radii.height)
    }

    /// The hand loop from `from` to `to` of its length (0…1).
    static func loopPath(center: CGPoint, radii: CGSize, start: Double, turns: Double, from: Double, to: Double, seed: Double) -> Path {
        var path = Path()
        guard to > from else { return path }
        let n = max(2, Int((to - from) * turns * 90))
        path.move(to: loopPoint(center: center, radii: radii, start: start, turns: turns, seed: seed, at: from))
        for i in 1...n {
            path.addLine(to: loopPoint(center: center, radii: radii, start: start, turns: turns, seed: seed,
                                       at: from + (to - from) * Double(i) / Double(n)))
        }
        return path
    }
}

/// What is drawn from the island's outline as it is on each frame, inside its clip: the voice
/// glow for Dispatch's and Quick actions' voice bars.
struct AgentEdgeLayer: View {
    let model: WorkbenchModel
    let edge: IslandEdge
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let state = model.notchState
        let voice = state == .dispatchVoice || state == .quickVoice || state == .v2Voice
        // Dispatch Version 2 transcribing: the same aura is its progress bar, filling the edge
        // leading to trailing.
        let transcribing = state == .v2Transcribing
        let shown = voice || transcribing
        let still = model.snapshotMode || reduceMotion
        TimelineView(.animation(minimumInterval: 1 / WorkbenchTokens.VoiceGlow.frameRate, paused: !shown || still)) { context in
            Canvas { ctx, size in
                if shown {
                    let V = WorkbenchTokens.VoiceGlow.self
                    let frame = still ? model.voiceGlow.still(at: V.stillTime, geometry: V.wide, reduceMotion: reduceMotion)
                        : model.voiceGlow.frame(at: context.date, geometry: V.wide, reduceMotion: reduceMotion)
                    if transcribing {
                        let p = model.v2TranscribeProgress(at: context.date)
                        ctx.clip(to: Path(CGRect(x: 0, y: 0, width: size.width * CGFloat(p), height: size.height)))
                    }
                    // On Native's light glass the colors are laid over white, not lit on black:
                    // stronger, so the aura still reads as itself.
                    var look = model.glowLook
                    if WorkbenchTokens.isNative, scheme == .light { look.opacity *= V.lightGlassBoost }
                    VoiceGlowRenderer.draw(in: &ctx, edge: edge, frame: frame, look: look)
                }
            }
        }
        .frame(width: edge.size.width, height: edge.size.height)
        .opacity(shown ? 1 : 0)
        .animation(shown ? WorkbenchTokens.Thinking.contentIn : WorkbenchTokens.Motion.contentOut, value: shown)
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(voice ? "Listening" : (transcribing ? "Transcribing" : ""))
        .accessibilityHidden(!shown)
    }
}

/// A click's ring where the agent's pointer pressed: it opens and fades.
struct AgentRippleView: View {
    let ripple: AgentRipple
    @State private var open = false

    var body: some View {
        let T = WorkbenchTokens.Thinking.self
        Circle()
            .strokeBorder(Color.white, lineWidth: 1.5)
            .background(Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 2.5))
            .frame(width: T.rippleSize, height: T.rippleSize)
            .scaleEffect(open ? 1 : 0.2)
            .opacity(open ? 0 : 0.9)
            .position(ripple.location)
            .onAppear { withAnimation(.easeOut(duration: T.rippleDuration)) { open = true } }
    }
}

/// Allow: the one control Needs you shows, the island's gray capsule.
struct AllowPill: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let T = WorkbenchTokens.Thinking.self
        Button(action: action) {
            Text("Allow")
                .font(T.allowFont)
                .foregroundStyle(Color.white)
                .padding(.horizontal, T.allowPaddingH)
                .frame(height: T.allowHeight)
                .background(Capsule(style: .continuous).fill(hovering ? T.allowFillHover : T.allowFill))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Let the agent go on")
        .accessibilityLabel("Allow")
    }
}

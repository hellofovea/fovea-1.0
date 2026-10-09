import SwiftUI
import WindowBenchCore

/// A run's (or project's, or thread's) state in its fixed 16 pt slot, drawn the way the
/// panel's State, Glyphs and Running switches say. Seen leaves the slot empty.
struct StateGlyph: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let state: RunState?
    /// Set when the glyph should play the needs-you arrival (the run just arrived).
    var arriving = false

    var body: some View {
        // The notch's grammar has no glyph column; in Words + tint the word sits at the row's end.
        if model.v(StateStyle.self) != .wordTint {
            shape
                .frame(width: BenchTokens.Layout.glyphSlot, height: BenchTokens.Layout.glyphSlot)
                .accessibilityElement()
                .accessibilityLabel(state?.accessibilityLabel ?? "")
        }
    }

    @ViewBuilder private var shape: some View {
        let drawing = model.v(GlyphDrawing.self)
        switch state {
        case .waiting?:
            ArrivalGlyph(arriving: arriving) {
                if drawing == .symbols {
                    Image(systemName: "circle.fill").font(.system(size: BenchTokens.Glyph.symbolSize))
                } else {
                    Circle().frame(width: BenchTokens.Glyph.diameter, height: BenchTokens.Glyph.diameter)
                }
            }
            .foregroundStyle(palette.text)
        case .failed?:
            Group {
                if drawing == .symbols {
                    Image(systemName: "exclamationmark.circle").font(.system(size: BenchTokens.Glyph.symbolSize + 1, weight: .medium))
                } else {
                    Text("!").font(BenchTokens.Glyph.bangFont)
                }
            }
            .foregroundStyle(palette.text)
        case .finished?:
            Group {
                if drawing == .symbols {
                    Image(systemName: "circle").font(.system(size: BenchTokens.Glyph.symbolSize, weight: .medium))
                } else {
                    Circle().strokeBorder(lineWidth: BenchTokens.Glyph.stroke)
                        .frame(width: BenchTokens.Glyph.diameter, height: BenchTokens.Glyph.diameter)
                }
            }
            .foregroundStyle(palette.text)
        case .running?:
            RunningGlyph(drawing: drawing)
        case .unobserved?:
            Group {
                if drawing == .symbols {
                    // Light and pale next to running's heavy dots: "can't see" reads as absence.
                    Image(systemName: "circle.dashed").font(.system(size: BenchTokens.Glyph.symbolSize, weight: .light))
                } else {
                    Circle().strokeBorder(style: StrokeStyle(lineWidth: BenchTokens.Glyph.stroke, dash: BenchTokens.Glyph.dash))
                        .frame(width: BenchTokens.Glyph.diameter, height: BenchTokens.Glyph.diameter)
                }
            }
            .foregroundStyle(palette.tertiary)
        case .seen?, nil:
            Color.clear
        }
    }
}

/// The waiting glyph's entrance: from a smaller size on the arrival animation the panel picks
/// (bounce, capped overshoot or none). Plays once per arrival.
private struct ArrivalGlyph<Content: View>: View {
    let arriving: Bool
    @ViewBuilder let content: Content
    @State private var landed = true
    @Environment(BenchModel.self) private var model

    var body: some View {
        content
            .scaleEffect(landed ? 1 : 0.4)
            .onAppear { if arriving { land() } }
            .onChange(of: arriving) { _, now in if now { land() } }
    }

    private func land() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { landed = false }
        DispatchQueue.main.async {
            withAnimation(model.motion.arrivalAnimation) { landed = true }
        }
    }
}

/// Running, never a spinner: a dotted circle that breathes, holds still, or the notch's Lasso.
struct RunningGlyph: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let drawing: GlyphDrawing

    var body: some View {
        let mark = model.v(RunningMark.self)
        let motion = model.motion
        let still = motion.reduce || model.options.snapshotDirectory != nil
        if mark == .lasso {
            TimelineView(.animation(minimumInterval: 1 / BenchTokens.Glyph.frameRate, paused: still)) { context in
                Canvas { ctx, size in
                    let t = still ? LassoMark.rest : motion.clock(context.date)
                    LassoMark.draw(in: &ctx, size: size, time: t, color: palette.text)
                }
            }
        } else {
            let dotted = Group {
                if drawing == .symbols {
                    Image(systemName: "circle.dotted").font(.system(size: BenchTokens.Glyph.symbolSize, weight: .heavy))
                } else {
                    Circle().strokeBorder(style: StrokeStyle(lineWidth: BenchTokens.Glyph.stroke + 0.2, lineCap: .round,
                                                             dash: BenchTokens.Glyph.dot))
                        .frame(width: BenchTokens.Glyph.diameter, height: BenchTokens.Glyph.diameter)
                }
            }
            .foregroundStyle(palette.text)
            if mark == .breathing && !still {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    let G = BenchTokens.Glyph.self
                    let phase = motion.clock(context.date).truncatingRemainder(dividingBy: G.breathePeriod) / G.breathePeriod
                    let k = (cos(phase * 2 * .pi) + 1) / 2
                    dotted.opacity(G.breatheLow + (1 - G.breatheLow) * k)
                }
            } else {
                dotted
            }
        }
    }
}

/// The notch's Lasso (Prototypes/FoveaWorkbench/MockDesktop/AgentThinking.swift, copied and
/// scaled to the glyph slot; may drift): a hand-drawn loop traced and erased behind its tip.
enum LassoMark {
    private typealias G = BenchTokens.Glyph

    static var rest: Double { G.lassoPeriod / (1 + G.lassoLength) }

    static func draw(in ctx: inout GraphicsContext, size: CGSize, time t: Double, color: Color) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let loop = (t / G.lassoPeriod).rounded(.down)
        let head = (t / G.lassoPeriod - loop) * (1 + G.lassoLength)
        let from = max(0, head - G.lassoLength), to = min(1, head)
        guard to > from else { return }
        let start = loop * G.lassoAdvance, seed = t * G.lassoDrift
        var path = Path()
        let n = max(2, Int((to - from) * G.lassoTurns * 60))
        path.move(to: point(c, start: start, seed: seed, at: from))
        for i in 1...n { path.addLine(to: point(c, start: start, seed: seed, at: from + (to - from) * Double(i) / Double(n))) }
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: G.lassoWeight, lineCap: .round, lineJoin: .round))
        if head <= 1 {
            let p = point(c, start: start, seed: seed, at: to)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - G.lassoHead / 2, y: p.y - G.lassoHead / 2, width: G.lassoHead, height: G.lassoHead)),
                     with: .color(color))
        }
    }

    private static func point(_ c: CGPoint, start: Double, seed: Double, at s: Double) -> CGPoint {
        let theta = start + 2 * .pi * G.lassoTurns * s
        let k = 1 + G.lassoWaver2 * sin(2 * theta + seed) + G.lassoWaver3 * sin(3 * theta + 1.1) - G.lassoShrink * s
        return CGPoint(x: c.x + CGFloat(cos(theta) * k) * G.lassoRadius, y: c.y + CGFloat(sin(theta) * k) * G.lassoRadius)
    }
}

/// The notch's word for a state, for the Words + tint and Glyph + word styles. Tint only in
/// Words + tint; in ink otherwise.
struct StateWord: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let state: RunState?
    var font: Font = BenchTokens.Notch.statusFont

    var body: some View {
        let style = model.v(StateStyle.self)
        if style != .glyph, let state, state != .seen {
            HStack(spacing: 4) {
                if state == .running {
                    Circle().frame(width: BenchTokens.Notch.workingDot, height: BenchTokens.Notch.workingDot)
                }
                Text(state.word)
            }
            .font(font)
            .foregroundStyle(color(state, tinted: style == .wordTint))
            .fixedSize()
        }
    }

    private func color(_ state: RunState, tinted: Bool) -> Color {
        guard tinted else { return state == .running || state == .unobserved ? palette.secondary : palette.text }
        switch state {
        case .waiting: return palette.needsYou
        case .failed: return palette.failed
        case .running, .unobserved: return palette.secondary
        case .finished, .seen: return palette.text
        }
    }
}

extension RunState {
    /// The state's shape as an SF Symbol, for places that draw it small and plain (the Today lanes).
    var symbol: String {
        switch self {
        case .waiting: return "circle.fill"
        case .failed: return "exclamationmark.circle"
        case .finished: return "circle"
        case .running: return "circle.dotted"
        case .unobserved: return "circle.dashed"
        case .seen: return "smallcircle.filled.circle"
        }
    }
}

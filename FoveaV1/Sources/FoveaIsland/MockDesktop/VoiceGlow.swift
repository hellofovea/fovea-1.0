import SwiftUI
import FoveaKit

// Voice input for agents: libraries.dev/voice (voice-glow, © 2026 Jakub Antalik, MIT) ported to
// the notch, driven by the site's own demo voice, on the dark theme. The host is the island: the
// glow rises from its bottom edge, clipped to its outline.
//
// The layers are the package's (src/styles.ts), in its order:
//   · the inner light: soft lobes inside the edge, faded off toward the corners;
//   · the bloom: the lobes blurred and taller, the halo;
//   · the stroke: the lobes painted into the 1 pt edge ring, with a white hot core;
//   · the band: the bend's contour, an organic bell with red, green and blue fringes.
// The driver is src/voiceDriver.ts: the level shaped and followed (attack 325 ms, release
// 860 ms), bands synthesised from the level, the flow, the idle breath, the bend, the hue drift.
// Its distortion (an SVG displacement map under the band line) is drawn here as strips.
//
// The style is Wide: the package's chat-input tuning fitted to the band, so the glow spans the bar,
// its colors flow sideways with the voice and the ridge rises into the corners. Colors: any of the
// package's palettes, turned around the wheel, or a custom spread of hues. Numbers:
// WorkbenchTokens.VoiceGlow; reasons: docs/island/AGENT_VOICE_AND_THINKING.md.

/// The site's demo voice (sites/home/src/examples/voice-mocks.tsx): phrases of 6.6 s with
/// 2.4 s of silence between, syllables at 3.1 Hz, words at 0.55 Hz.
enum DemoVoice {
    static func level(_ t: Double) -> Double {
        let phrase = t - 9 * (t / 9).rounded(.down)
        if phrase > 6.6 { return 0 }
        let syllable = 0.5 + 0.5 * sin(t * .pi * 2 * 3.1)
        let word = 0.5 + 0.5 * sin(t * .pi * 2 * 0.55 + 1)
        let rough = 0.86 + 0.14 * sin(t * 23.7)
        let v = pow(syllable, 1.6) * (0.5 + 0.5 * word) * rough
        return min(1, v * 1.05)
    }
}

/// One host type's tuning, the package's props resolved (src/presets.ts), with the scale that
/// fits it to the notch's band. Lengths are px at scale 1; the renderer scales them as the
/// component does.
struct VoiceGlowGeometry {
    var scale: CGFloat
    var reach: Double, spread: Double
    /// px a second the lobes slide sideways at full voice; 0 holds them.
    var flow: CGFloat
    var bend: CGFloat
    var bandStrength: Double, bandWidth: CGFloat, bandPosition: CGFloat, bandCurve: Double, bandSpread: Double, bandSkew: Double
    var bandOffset: CGFloat
    /// How far the band's ends rise toward the corners, where the rise starts, its exponent, and
    /// how far past the sides it runs.
    var bandTail: Double, bandTailPosition: Double, bandTailCurve: Double, bandTailOverflow: CGFloat
    var bandAberration: Double
    var distortion: Double, distortionDetail: Double
    var glowWidth: CGFloat, glowHeight: CGFloat, lobeSpacing: CGFloat, rangeWidth: CGFloat, rangeHeight: CGFloat
    var softness: Double
    var coreSize: CGFloat, strokeScale: CGFloat, innerScale: CGFloat, innerHeight: CGFloat, bloomScale: CGFloat,
        bloomHeight: CGFloat, glowSize: CGFloat
    var strokeOpacity: Double, innerOpacity: Double, bloomOpacity: Double
    var brightness: Double, saturation: Double
}

// The glow's colors (`GlowPalette`) are FoveaKit's: the package's eight palettes, or Custom.

/// What the panel chose: the palette's colors before the filters, the hue they are turned by,
/// whether they drift, and mono's softening.
struct VoiceGlowLook {
    var colors: [(Double, Double, Double)]
    /// Degrees added to every layer's hue (the package's `--voice-hue-base`).
    var hueBase: Double
    var drift: Bool
    /// How far the drift wanders, times the Workbench's swing: still at 0, the Workbench's own at
    /// 1, twice that at 2 (the person's dial, 0…1, doubled).
    var driftAmount: Double = 1
    var opacity: Double
    /// The band's fringes: the package's own red, green and blue, or, for Custom, the chosen hues
    /// (the far ends of the fan above and below, the centre between), so the whole glow follows
    /// the spectrum.
    var bandAbove: (Double, Double, Double) = WorkbenchTokens.VoiceGlow.bandAbove
    var bandMid: (Double, Double, Double) = WorkbenchTokens.VoiceGlow.bandMid
    var bandBelow: (Double, Double, Double) = WorkbenchTokens.VoiceGlow.bandBelow

    static func make(palette: GlowPalette, hue: Double, spread: Double, drift: Bool) -> VoiceGlowLook {
        let V = WorkbenchTokens.VoiceGlow.self
        if palette == .custom {
            let colors = V.customOffsets.map { hsb(hue + spread * $0, V.customSaturation, V.customBrightness) }
            return VoiceGlowLook(colors: colors, hueBase: 0, drift: drift, opacity: 1,
                                 bandAbove: hsb(hue + spread / 2, 0.85, 1), bandMid: hsb(hue, 0.85, 1),
                                 bandBelow: hsb(hue - spread / 2, 0.85, 1))
        }
        let mono = palette == .mono
        return VoiceGlowLook(colors: V.palettes[palette] ?? [], hueBase: mono ? 0 : hue, drift: drift && !mono,
                             opacity: mono ? V.monoOpacity : 1)
    }

    static func hsb(_ hue: Double, _ s: Double, _ b: Double) -> (Double, Double, Double) {
        let h = ((hue.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360) / 60
        let c = b * s, x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1)), m = b - c
        let (r, g, bl): (Double, Double, Double)
        switch Int(h) {
        case 0: (r, g, bl) = (c, x, 0)
        case 1: (r, g, bl) = (x, c, 0)
        case 2: (r, g, bl) = (0, c, x)
        case 3: (r, g, bl) = (0, x, c)
        case 4: (r, g, bl) = (x, 0, c)
        default: (r, g, bl) = (c, 0, x)
        }
        return ((r + m) * 255, (g + m) * 255, (bl + m) * 255)
    }
}

/// One frame of the glow: what the package's driver writes as custom properties.
struct VoiceGlowFrame {
    var t: Double
    /// The followed level, and with the idle breath under it.
    var level: Double
    var eff: Double
    /// Presence, height and width multipliers.
    var glow: Double
    var h: CGFloat
    var w: CGFloat
    /// The bend's extra height at the centre, px, and its strength 0–1.
    var lift: CGFloat
    var bendA: Double
    /// The hue drift, degrees.
    var drift: Double
    /// Each lobe's offset (before the width) and amplitude.
    var lobeX: [CGFloat]
    var lobeL: [CGFloat]
    /// The distortion's displacement scale, px.
    var warp: CGFloat
}

/// The driver, one per island: the envelope and the flow are kept across frames, as the
/// package keeps them per element.
final class VoiceGlowEngine {
    /// The level to follow, 0…1, when there is a real voice (Fovea).
    var liveLevel: (() -> Double)?
    private var level = 0.0
    private var bands = [0.0, 0.0, 0.0]
    private var phase: CGFloat = 0
    private var clock = 0.0
    private var last: Date?

    func reset() {
        level = 0
        bands = [0, 0, 0]
        phase = 0
        clock = 0
        last = nil
    }

    /// Steps the driver to `date`, reading the demo voice.
    func frame(at date: Date, geometry g: VoiceGlowGeometry, reduceMotion: Bool) -> VoiceGlowFrame {
        let dt = last.map { min(0.05, max(0, date.timeIntervalSince($0))) } ?? 1.0 / 60
        last = date
        return advance(dt: dt, voiceTime: date.timeIntervalSinceReferenceDate, geometry: g, reduceMotion: reduceMotion)
    }

    /// A still frame: the driver run for three seconds up to `time` of the demo voice.
    func still(at time: Double, geometry g: VoiceGlowGeometry, reduceMotion: Bool) -> VoiceGlowFrame {
        reset()
        var frame = advance(dt: 1.0 / 60, voiceTime: time - 3, geometry: g, reduceMotion: reduceMotion)
        for i in 1...180 {
            frame = advance(dt: 1.0 / 60, voiceTime: time - 3 + Double(i) / 60, geometry: g, reduceMotion: reduceMotion)
        }
        return frame
    }

    private func advance(dt: Double, voiceTime: Double, geometry g: VoiceGlowGeometry, reduceMotion: Bool) -> VoiceGlowFrame {
        let V = WorkbenchTokens.VoiceGlow.self
        let S = g.scale
        clock += dt
        let t = clock
        // No spectrum to read: the bands are the level with slow, out-of-phase wobbles.
        // Fovea: the microphone's own level; the Workbench's demo voice otherwise.
        let raw = min(1, max(0, liveLevel?() ?? DemoVoice.level(voiceTime)))
        let rawBands = [raw, raw * (0.72 + 0.28 * sin(t * 9.1)), raw * (0.6 + 0.4 * sin(t * 13.7 + 2))]
        level = Self.follow(level, Self.shape(raw, V.threshold), dt, V.attack, V.release)
        for b in 0..<3 {
            bands[b] = Self.follow(bands[b], Self.shape(rawBands[b], V.threshold * 0.6), dt, V.attack, V.release * 1.15)
        }
        let breathe = reduceMotion ? 0.5 : 0.5 + 0.5 * sin(2 * .pi * t / V.breathe)
        let eff = level + (1 - level) * V.idle * breathe
        // The flow: the spectrum slides sideways while a voice is heard, and rests when it stops.
        let span = V.lobeSpan * g.lobeSpacing * S
        if g.flow != 0, !reduceMotion {
            phase = ((phase + g.flow * S * CGFloat(eff * dt)).truncatingRemainder(dividingBy: span) + span)
                .truncatingRemainder(dividingBy: span)
        }
        var xs: [CGFloat] = [], ls: [CGFloat] = []
        for lobe in V.lobes {
            let x = Self.wrap(lobe.x * g.lobeSpacing * S + phase, span)
            xs.append(x)
            ls.append(CGFloat(0.6 + 0.7 * bands[lobe.band]) * Self.edgeEnvelope(x, span))
        }
        let drift = reduceMotion ? 0 : -V.hueRange + 2 * V.hueRange * (1 - cos(2 * .pi * t / V.hueDuration)) / 2
        let warp = reduceMotion ? 0 : CGFloat(g.distortion * 120) * S * CGFloat(0.15 + 0.85 * eff)
        return VoiceGlowFrame(t: t, level: level, eff: eff, glow: 0.15 + 0.85 * eff,
                              h: CGFloat(0.5 + g.reach * eff), w: CGFloat(0.85 + g.spread * eff),
                              lift: g.bend * S * CGFloat(eff), bendA: min(1, eff), drift: drift,
                              lobeX: xs, lobeL: ls, warp: warp)
    }

    /// Noise gate, then soft saturation, so a shout rounds off instead of clipping.
    static func shape(_ raw: Double, _ threshold: Double) -> Double {
        guard raw > threshold else { return 0 }
        let t = (raw - threshold) / max(0.001, 1 - threshold)
        return min(1, max(0, (1 - exp(-3 * t)) / (1 - exp(-3))))
    }

    /// One-pole follower: fast up, slow down.
    static func follow(_ prev: Double, _ target: Double, _ dt: Double, _ attack: Double, _ release: Double) -> Double {
        let tau = target > prev ? attack : release
        return prev + (target - prev) * (1 - exp(-dt / max(0.001, tau)))
    }

    static func wrap(_ x: CGFloat, _ span: CGFloat) -> CGFloat {
        let half = span / 2
        let m = (x + half).truncatingRemainder(dividingBy: span)
        return (m < 0 ? m + span : m) - half
    }

    /// A lobe fades out toward the wrap, so it never pops from one side to the other.
    static func edgeEnvelope(_ x: CGFloat, _ span: CGFloat) -> CGFloat {
        let t = x / (span / 2 + 4)
        return max(0, 1 - t * t)
    }
}

/// The glow drawn into the island, from its outline as it is on this frame.
enum VoiceGlowRenderer {
    typealias RGB = (Double, Double, Double)

    static func draw(in ctx: inout GraphicsContext, edge: IslandEdge, frame f: VoiceGlowFrame, look: VoiceGlowLook) {
        let V = WorkbenchTokens.VoiceGlow.self
        let g = V.wide
        let cw = edge.size.width, ch = edge.size.height
        guard cw > 1, ch > 1, !look.colors.isEmpty else { return }
        let hue = look.hueBase + (look.drift ? f.drift * look.driftAmount : 0)
        let colors = look.colors.map { color(filtered($0, hue: hue, g)) }
        let fade = min(95, max(40, (70 * g.softness).rounded())) / 100
        let pts = bandPoints(width: cw, height: ch, frame: f, geometry: g)

        // The soft layers: above the band line as they are; under it, warped sideways in strips.
        // Each layer's masks are made once, then every strip draws into them.
        var above = ctx
        above.clip(to: polygonAbove(pts, width: cw, height: ch))
        let top = softLayers(in: above, edge: edge, frame: f, geometry: g, look: look)
        drawSoft(top, edge: edge, frame: f, geometry: g, colors: colors, fade: fade, strip: nil, dx: 0)
        var below = ctx
        below.clip(to: polygonBelow(pts, width: cw, height: ch))
        let under = softLayers(in: below, edge: edge, frame: f, geometry: g, look: look)
        if f.warp > 0.5 {
            var y = max(0, (pts.map(\.y).min() ?? ch).rounded(.down) - 1)
            while y < ch {
                let strip = Path(CGRect(x: -cw, y: y, width: 3 * cw, height: V.warpStrip + 0.5))
                drawSoft(under, edge: edge, frame: f, geometry: g, colors: colors, fade: fade, strip: strip,
                         dx: f.warp * warpNoise(y: y, t: f.t, geometry: g))
                y += V.warpStrip
            }
        } else {
            drawSoft(under, edge: edge, frame: f, geometry: g, colors: colors, fade: fade, strip: nil, dx: 0)
        }

        drawStroke(in: ctx, edge: edge, frame: f, geometry: g, look: look, colors: colors, fade: fade)
        drawBand(in: ctx, points: pts, frame: f, geometry: g, look: look, hue: hue)
    }

    /// The seven lobe colors as the glow shows them (drift aside), for the panel's swatches.
    static func swatches(look: VoiceGlowLook) -> [Color] {
        look.colors.map { color(filtered($0, hue: look.hueBase, WorkbenchTokens.VoiceGlow.wide)) }
    }

    // MARK: Layers

    /// The inner light's and the bloom's contexts: their opacities and masks. The inner light is
    /// masked to the ceiling and to within a corner fade of the edges; the bloom to the wider
    /// ceiling.
    private static func softLayers(in ctx: GraphicsContext, edge: IslandEdge, frame f: VoiceGlowFrame,
                                   geometry g: VoiceGlowGeometry, look: VoiceGlowLook)
        -> (inner: GraphicsContext, bloom: GraphicsContext) {
        let V = WorkbenchTokens.VoiceGlow.self
        let cw = edge.size.width, ch = edge.size.height
        var inner = ctx
        inner.opacity = f.glow * g.innerOpacity * look.opacity
        inner.clipToLayer { m in
            mask(in: &m, width: cw, height: ch, frame: f, geometry: g, halfWidth: V.ceilingHalfWidth,
                 ceiling: V.ceilingHeight, mid: 0.45, tail: 0.3)
        }
        let fadeLength = V.cornerFade * g.scale
        inner.clipToLayer { m in
            let rect = Path(CGRect(x: 0, y: 0, width: cw, height: ch))
            let v = fadeLength / ch, u = fadeLength / cw
            m.fill(rect, with: .linearGradient(Gradient(stops: [
                .init(color: .white, location: 0), .init(color: .clear, location: v),
                .init(color: .clear, location: 1 - v), .init(color: .white, location: 1),
            ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: ch)))
            m.blendMode = .plusLighter
            m.fill(rect, with: .linearGradient(Gradient(stops: [
                .init(color: .white, location: 0), .init(color: .clear, location: u),
                .init(color: .clear, location: 1 - u), .init(color: .white, location: 1),
            ]), startPoint: .zero, endPoint: CGPoint(x: cw, y: 0)))
        }
        var bloom = ctx
        bloom.opacity = f.glow * g.bloomOpacity * look.opacity
        bloom.clipToLayer { m in
            mask(in: &m, width: cw, height: ch, frame: f, geometry: g, halfWidth: V.bloomCeilingHalfWidth,
                 ceiling: V.bloomCeilingHeight, mid: 0.35, tail: nil)
        }
        return (inner, bloom)
    }

    /// The inner light and the bloom, within a strip, shifted `dx` sideways (the distortion; the
    /// masks stay put).
    private static func drawSoft(_ layers: (inner: GraphicsContext, bloom: GraphicsContext), edge: IslandEdge,
                                 frame f: VoiceGlowFrame, geometry g: VoiceGlowGeometry, colors: [Color],
                                 fade: Double, strip: Path?, dx: CGFloat) {
        let V = WorkbenchTokens.VoiceGlow.self
        let S = g.scale
        let cw = edge.size.width, ch = edge.size.height
        let gw = g.glowWidth * S, gh = g.glowHeight * S
        var inner = layers.inner
        if let strip { inner.clip(to: strip) }
        inner.drawLayer { l in
            var shadow = l
            shadow.addFilter(.blur(radius: V.insetBlur * S / 2))
            shadow.stroke(edge.path(inset: 1), with: .color(.white.opacity(V.innerShadow)), lineWidth: 2)
            l.translateBy(x: dx, y: 0)
            lobes(in: &l, width: cw, height: ch, frame: f, colors: colors, sw: gw * 0.9 * g.innerScale,
                  sh: gh * 0.9 * g.innerScale * g.innerHeight, y: 0, alpha: 0.46, fade: fade)
        }
        var bloom = layers.bloom
        if let strip { bloom.clip(to: strip) }
        bloom.drawLayer { l in
            l.addFilter(.blur(radius: max(0.5, V.bloomBlur * g.glowSize * S)))
            l.translateBy(x: dx, y: 0)
            lobes(in: &l, width: cw, height: ch, frame: f, colors: colors, sw: gw * 1.15 * g.bloomScale,
                  sh: gh * 1.5 * g.bloomScale * g.bloomHeight, y: 0, alpha: 0.9, fade: min(0.95, fade + 0.02))
        }
    }

    /// The stroke: the lobes and the white core painted into the 1 pt ring inside the edge.
    private static func drawStroke(in ctx: GraphicsContext, edge: IslandEdge, frame f: VoiceGlowFrame,
                                   geometry g: VoiceGlowGeometry, look: VoiceGlowLook, colors: [Color], fade: Double) {
        let V = WorkbenchTokens.VoiceGlow.self
        let S = g.scale
        let cw = edge.size.width, ch = edge.size.height
        var stroke = ctx
        stroke.opacity = min(1, f.glow * g.strokeOpacity * look.opacity)
        stroke.clipToLayer { m in
            mask(in: &m, width: cw, height: ch, frame: f, geometry: g, halfWidth: V.ceilingHalfWidth,
                 ceiling: V.ceilingHeight, mid: 0.45, tail: nil)
        }
        stroke.clipToLayer { m in
            m.stroke(edge.path(inset: 0.5), with: .color(.white), lineWidth: 1)
        }
        stroke.drawLayer { l in
            lobes(in: &l, width: cw, height: ch, frame: f, colors: colors, sw: g.glowWidth * S * g.strokeScale,
                  sh: g.glowHeight * S * g.strokeScale, y: 2, alpha: 1, fade: fade)
            let core = 30 * g.coreSize * S
            ellipse(in: &l, center: CGPoint(x: cw / 2, y: ch + 2), rx: core * f.w, ry: core * f.h, stops: [
                .init(color: .white.opacity(0.45), location: 0), .init(color: .white.opacity(0.14), location: 0.3),
                .init(color: .white.opacity(0), location: 0.65),
            ])
        }
    }

    /// The band: the bend's contour as a luminous ridge, the red fringe above, blue below, green
    /// between, over a wide soft halo; the ends faded into the edge.
    private static func drawBand(in ctx: GraphicsContext, points pts: [CGPoint], frame f: VoiceGlowFrame,
                                 geometry g: VoiceGlowGeometry, look: VoiceGlowLook, hue: Double) {
        let V = WorkbenchTokens.VoiceGlow.self
        let S = g.scale
        let alpha = min(1, 0.6 * g.bandStrength * f.bendA)
        guard alpha > 0.005, pts.count > 1 else { return }
        let bw = g.bandWidth * S * (1 + 0.35 * CGFloat(f.level))
        let split = g.bandAberration * (0.35 + 0.65 * f.level)
        let dy = CGFloat(4 + 12 * split) * S
        let dx = CGFloat(4 * split) * S
        let base = 0.42 * alpha
        let thickness = 14 * bw
        let blur = 3.5 * g.bandWidth * S / 2
        let x0 = pts[0].x, x1 = pts[pts.count - 1].x
        let endFade = g.bandTail > 0 ? 0.015 : 0.18
        func faded(_ rgb: RGB, _ a: Double) -> GraphicsContext.Shading {
            let c = color(filtered(rgb, hue: hue, g))
            return .linearGradient(Gradient(stops: [
                .init(color: c.opacity(0), location: 0), .init(color: c.opacity(a), location: endFade),
                .init(color: c.opacity(a), location: 1 - endFade), .init(color: c.opacity(0), location: 1),
            ]), startPoint: CGPoint(x: x0, y: 0), endPoint: CGPoint(x: x1, y: 0))
        }
        func trace(_ ox: CGFloat, _ oy: CGFloat) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: pts[0].x + ox, y: pts[0].y + oy))
            for q in pts.dropFirst() { p.addLine(to: CGPoint(x: q.x + ox, y: q.y + oy)) }
            return p
        }
        var halo = ctx
        halo.addFilter(.blur(radius: blur * 3))
        halo.stroke(trace(0, 0), with: faded(V.bandCore, base * 0.3),
                    style: StrokeStyle(lineWidth: thickness * 2.2, lineCap: .round, lineJoin: .round))
        var ridge = ctx
        ridge.addFilter(.blur(radius: blur))
        let ridges: [(RGB, Double, CGFloat, CGFloat)] = [
            (look.bandAbove, 1, dx, -dy), (look.bandMid, 0.55, dx * 0.35, -dy * 0.35), (look.bandBelow, 1, -dx, dy), (V.bandCore, 0.9, 0, 0),
        ]
        let ramp: [(CGFloat, Double)] = [(1, 0.16), (0.72, 0.2), (0.46, 0.26), (0.22, 0.34)]
        for (rgb, a, ox, oy) in ridges {
            let path = trace(ox, oy)
            for (widthMul, alphaMul) in ramp {
                ridge.stroke(path, with: faded(rgb, base * a * alphaMul),
                             style: StrokeStyle(lineWidth: max(0.6, thickness * widthMul), lineCap: .round, lineJoin: .round))
            }
        }
    }

    // MARK: Geometry

    /// The lobes as radial ellipses fanning out from the bottom centre.
    private static func lobes(in ctx: inout GraphicsContext, width cw: CGFloat, height ch: CGFloat, frame f: VoiceGlowFrame,
                              colors: [Color], sw: CGFloat, sh: CGFloat, y: CGFloat, alpha: Double, fade: Double) {
        let V = WorkbenchTokens.VoiceGlow.self
        for (i, lobe) in V.lobes.enumerated() {
            let c = colors[i % colors.count]
            ellipse(in: &ctx, center: CGPoint(x: cw / 2 + f.lobeX[i] * f.w, y: ch + y),
                    rx: lobe.w * sw * f.w, ry: lobe.h * sh * f.h * f.lobeL[i], stops: [
                        .init(color: c.opacity(alpha), location: 0), .init(color: c.opacity(0), location: fade),
                    ])
        }
    }

    /// The ceiling a layer is masked to: an ellipse on the bottom centre that grows with the
    /// voice, humped up by the bend.
    private static func mask(in ctx: inout GraphicsContext, width cw: CGFloat, height ch: CGFloat, frame f: VoiceGlowFrame,
                             geometry g: VoiceGlowGeometry, halfWidth: CGFloat, ceiling: CGFloat, mid: Double, tail: Double?) {
        let S = g.scale
        var stops: [Gradient.Stop] = [.init(color: .white, location: 0), .init(color: .white.opacity(0.5), location: mid)]
        if let tail { stops.append(.init(color: .white.opacity(tail), location: 0.85)) }
        stops.append(.init(color: .white.opacity(0), location: 1))
        ellipse(in: &ctx, center: CGPoint(x: cw / 2, y: ch), rx: halfWidth * g.rangeWidth * S * f.w,
                ry: ceiling * g.rangeHeight * S * f.h + f.lift, stops: stops)
    }

    /// CSS's `radial-gradient(ellipse rx ry at center, stops…)`.
    private static func ellipse(in ctx: inout GraphicsContext, center: CGPoint, rx: CGFloat, ry: CGFloat, stops: [Gradient.Stop]) {
        guard rx > 0.01, ry > 0.01 else { return }
        var e = ctx
        e.translateBy(x: center.x, y: center.y)
        e.scaleBy(x: rx, y: ry)
        e.fill(Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2)),
               with: .radialGradient(Gradient(stops: stops), center: .zero, startRadius: 0, endRadius: 1))
    }

    /// The band line: an organic bell sitting on the ceiling, left to right; with a tail, it runs
    /// the island's full width and a little past it, its ends rising toward the corners.
    static func bandPoints(width cw: CGFloat, height ch: CGFloat, frame f: VoiceGlowFrame, geometry g: VoiceGlowGeometry) -> [CGPoint] {
        let V = WorkbenchTokens.VoiceGlow.self
        let S = g.scale
        let centre = cw / 2
        let half = V.ceilingHalfWidth * g.rangeWidth * S * f.w
        let apexCap = ch * 0.82 * min(1, S)
        let apex = min(apexCap, (V.ceilingHeight * g.rangeHeight * S * f.h + f.lift) * g.bandPosition)
        let base = ch - g.bandOffset * S
        let withTail = g.bandTail > 0.001
        let over = withTail ? g.bandTailOverflow * S : 0
        let x0 = withTail ? -over : centre - half
        let x1 = withTail ? cw + over : centre + half
        return (0...V.bandSamples).map { i in
            let x = x0 + (x1 - x0) * CGFloat(i) / CGFloat(V.bandSamples)
            let t = Double(max(-1, min(1, (x - centre) / max(1, half))))
            let edgeDistance = (x < centre ? centre : cw - centre) + over
            let y = bell(t, g) + tailLift(Double(abs(x - centre)), Double(edgeDistance), g)
            return CGPoint(x: x, y: base - apex * CGFloat(y))
        }
    }

    /// exp(-(|t| / σ)^p), normalised to 1 at the centre and 0 at the ends; skew widens one side.
    static func bell(_ t: Double, _ g: VoiceGlowGeometry) -> Double {
        let side = t < 0 ? 1 - g.bandSkew : 1 + g.bandSkew
        let s = max(0.05, g.bandSpread * side)
        let v = exp(-pow(abs(t) / s, g.bandCurve))
        let tail = exp(-pow(1 / s, g.bandCurve))
        return max(0, (v - tail) / (1 - tail))
    }

    /// The band's ends rising again toward the corners, from `bandTailPosition` of the way out.
    static func tailLift(_ distance: Double, _ edge: Double, _ g: VoiceGlowGeometry) -> Double {
        guard g.bandTail > 0, edge > 0 else { return 0 }
        let start = edge * max(0, min(0.98, g.bandTailPosition))
        guard distance > start else { return 0 }
        let u = min(1, (distance - start) / max(1, edge - start))
        return g.bandTail * pow(u, max(0.5, g.bandTailCurve))
    }

    private static func polygonAbove(_ pts: [CGPoint], width cw: CGFloat, height ch: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: min(0, pts.first?.x ?? 0), y: 0))
        p.addLine(to: CGPoint(x: max(cw, pts.last?.x ?? cw), y: 0))
        p.addLine(to: CGPoint(x: max(cw, pts.last?.x ?? cw), y: ch))
        for q in pts.reversed() { p.addLine(to: q) }
        p.addLine(to: CGPoint(x: min(0, pts.first?.x ?? 0), y: ch))
        p.closeSubpath()
        return p
    }

    private static func polygonBelow(_ pts: [CGPoint], width cw: CGFloat, height ch: CGFloat) -> Path {
        var p = Path()
        let left = min(0, pts.first?.x ?? 0), right = max(cw, pts.last?.x ?? cw)
        p.move(to: CGPoint(x: left, y: ch + 40))
        p.addLine(to: CGPoint(x: left, y: ch))
        for q in pts { p.addLine(to: q) }
        p.addLine(to: CGPoint(x: right, y: ch))
        p.addLine(to: CGPoint(x: right, y: ch + 40))
        p.closeSubpath()
        return p
    }

    /// The displacement at a height: drifting fractal noise, as the package's turbulence reads
    /// through a strip (−0.3…0.3 of the scale).
    private static func warpNoise(y: CGFloat, t: Double, geometry g: VoiceGlowGeometry) -> CGFloat {
        let f = 0.05 * g.distortionDetail / Double(g.scale) / 4
        let shift = 4 * Double(g.scale) * sin(t * 0.6 + 1.3)
        let yy = Double(y) + shift
        let n = 0.2 * sin(2 * .pi * f * yy + 0.8 * Double(g.scale) * sin(t * 0.9))
            + 0.1 * sin(2 * .pi * f * 2.1 * yy + 1.7 + t * 0.4)
        return CGFloat(n)
    }

    // MARK: Color

    /// CSS's `hue-rotate(h) brightness(b) saturate(s)`, in that order, on one colour.
    static func filtered(_ rgb: RGB, hue: Double, _ g: VoiceGlowGeometry) -> RGB {
        func clamp(_ v: Double) -> Double { min(1, max(0, v)) }
        let r = rgb.0 / 255, gr = rgb.1 / 255, b = rgb.2 / 255
        let a = hue * .pi / 180, c = cos(a), s = sin(a)
        let r1 = clamp((0.213 + c * 0.787 - s * 0.213) * r + (0.715 - c * 0.715 - s * 0.715) * gr + (0.072 - c * 0.072 + s * 0.928) * b)
        let g1 = clamp((0.213 - c * 0.213 + s * 0.143) * r + (0.715 + c * 0.285 + s * 0.140) * gr + (0.072 - c * 0.072 - s * 0.283) * b)
        let b1 = clamp((0.213 - c * 0.213 - s * 0.787) * r + (0.715 - c * 0.715 + s * 0.715) * gr + (0.072 + c * 0.928 + s * 0.072) * b)
        let br = g.brightness
        let r2 = clamp(r1 * br), g2 = clamp(g1 * br), b2 = clamp(b1 * br)
        let sa = g.saturation
        let r3 = clamp((0.213 + 0.787 * sa) * r2 + (0.715 - 0.715 * sa) * g2 + (0.072 - 0.072 * sa) * b2)
        let g3 = clamp((0.213 - 0.213 * sa) * r2 + (0.715 + 0.285 * sa) * g2 + (0.072 - 0.072 * sa) * b2)
        let b3 = clamp((0.213 - 0.213 * sa) * r2 + (0.715 - 0.715 * sa) * g2 + (0.072 + 0.928 * sa) * b2)
        return (r3 * 255, g3 * 255, b3 * 255)
    }

    static func color(_ rgb: RGB) -> Color {
        Color(.sRGB, red: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255)
    }
}

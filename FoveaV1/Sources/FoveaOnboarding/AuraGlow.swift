import SwiftUI

// The voice glow's palettes, for Make it yours' swatches (Copied from Prototypes/FoveaCaptures/
// NotchGlow.swift on Oct 7; may drift). The glow itself is drawn by the real notch (FoveaIsland);
// Oct 21, Ryan ("simpler is better"): the copy of its renderer, driver and demo voice the first
// run no longer drew is gone, and only the colors are left.
//
// Voice input for agents: libraries.dev/voice (voice-glow, © 2026 Jakub Antalik, MIT). Its
// palettes and color filters (src/styles.ts, presets.ts); reasons:
// docs/island/AGENT_VOICE_AND_THINKING.md.

/// What the panel chose: the palette's colors before the filters, the hue they are turned by,
/// whether they drift, and mono's softening.
struct VoiceGlowLook {
    var colors: [(Double, Double, Double)]
    /// Degrees added to every layer's hue (the package's `--voice-hue-base`).
    var hueBase: Double
    var drift: Bool
    var opacity: Double

    static func make(palette: GlowChoice, hue: Double, spread: Double, drift: Bool) -> VoiceGlowLook {
        let V = GlowTokens.self
        if palette == .custom {
            let colors = V.customOffsets.map { hsb(hue + spread * $0, V.customSaturation, V.customBrightness) }
            return VoiceGlowLook(colors: colors, hueBase: 0, drift: drift, opacity: 1)
        }
        let mono = palette == .mono
        return VoiceGlowLook(colors: palette.rgb, hueBase: mono ? 0 : hue, drift: drift && !mono,
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

/// The palettes' colors as the glow shows them.
enum VoiceGlowRenderer {
    typealias RGB = (Double, Double, Double)

    /// The seven lobe colors as the glow shows them (drift aside), for the panel's swatches.
    static func swatches(look: VoiceGlowLook) -> [Color] {
        look.colors.map { color(filtered($0, hue: look.hueBase)) }
    }

    // MARK: Color

    /// CSS's `hue-rotate(h) brightness(b) saturate(s)`, in that order, on one colour.
    static func filtered(_ rgb: RGB, hue: Double) -> RGB {
        func clamp(_ v: Double) -> Double { min(1, max(0, v)) }
        let r = rgb.0 / 255, gr = rgb.1 / 255, b = rgb.2 / 255
        let a = hue * .pi / 180, c = cos(a), s = sin(a)
        let r1 = clamp((0.213 + c * 0.787 - s * 0.213) * r + (0.715 - c * 0.715 - s * 0.715) * gr + (0.072 - c * 0.072 + s * 0.928) * b)
        let g1 = clamp((0.213 - c * 0.213 + s * 0.143) * r + (0.715 + c * 0.285 + s * 0.140) * gr + (0.072 - c * 0.072 - s * 0.283) * b)
        let b1 = clamp((0.213 - c * 0.213 - s * 0.787) * r + (0.715 - c * 0.715 + s * 0.715) * gr + (0.072 + c * 0.928 + s * 0.072) * b)
        let br = GlowTokens.brightness
        let r2 = clamp(r1 * br), g2 = clamp(g1 * br), b2 = clamp(b1 * br)
        let sa = GlowTokens.saturation
        let r3 = clamp((0.213 + 0.787 * sa) * r2 + (0.715 - 0.715 * sa) * g2 + (0.072 - 0.072 * sa) * b2)
        let g3 = clamp((0.213 - 0.213 * sa) * r2 + (0.715 + 0.285 * sa) * g2 + (0.072 - 0.072 * sa) * b2)
        let b3 = clamp((0.213 - 0.213 * sa) * r2 + (0.715 - 0.715 * sa) * g2 + (0.072 + 0.928 * sa) * b2)
        return (r3 * 255, g3 * 255, b3 * 255)
    }

    static func color(_ rgb: RGB) -> Color {
        Color(.sRGB, red: rgb.0 / 255, green: rgb.1 / 255, blue: rgb.2 / 255)
    }
}

/// The glow's numbers the swatches need (WorkbenchTokens.VoiceGlow).
enum GlowTokens {
    /// The Wide style's filters (the package's chat-input tuning).
    static let brightness = 1.15
    static let saturation = 1.2
    /// Mono's layers are softened: uniform gray at full opacity reads as a harsh bar.
    static let monoOpacity = 0.6
    /// Custom: seven hues fanned across `spread` degrees around the chosen one, centre lobe
    /// first, then the pairs outward; at this saturation and brightness.
    static let customOffsets: [Double] = [0, -1.0 / 6, 1.0 / 6, -2.0 / 6, 2.0 / 6, -3.0 / 6, 3.0 / 6]
    static let customSaturation = 0.72
    static let customBrightness = 1.0
}

// MARK: - The palettes (FoveaCaptures/NotchSettings.swift, `GlowChoice`, copied)

/// The glow in the voice bar while Fovea listens for an agent: the Workbench's palettes to start
/// from, and Custom, seven hues fanned round the one picked.
enum GlowChoice: String, CaseIterable {
    case colorful, ocean, sunset, forest, candy, ice, gold, mono, custom
    var title: String { rawValue.capitalized }
    static let templates: [GlowChoice] = [.colorful, .ocean, .sunset, .forest, .candy, .ice, .gold, .mono]

    /// The glow as picked, for the renderer (NotchGlow.swift, the Workbench's own): a template
    /// turned `hue` degrees round the wheel (Mono stays gray), or Custom fanned across `spread`
    /// degrees round `hue`.
    func look(hue: Double, spread: Double, drift: Bool) -> VoiceGlowLook {
        VoiceGlowLook.make(palette: self, hue: hue, spread: spread, drift: drift)
    }

    /// The seven colors as the glow shows them, the drift aside: the Workbench's swatches.
    func colors(hue: Double, spread: Double) -> [Color] {
        VoiceGlowRenderer.swatches(look: look(hue: hue, spread: spread, drift: false))
    }

    /// Copied from Prototypes/FoveaWorkbench/WorkbenchTokens.swift `VoiceGlow.palettes` (may drift),
    /// centre lobe first.
    var rgb: [(Double, Double, Double)] {
        switch self {
        case .colorful: return [(255, 70, 120), (60, 190, 255), (175, 70, 255), (60, 220, 130), (255, 150, 40), (90, 100, 255), (40, 200, 190)]
        case .mono: return [(215, 215, 215), (180, 180, 180), (190, 190, 190), (160, 160, 160), (170, 170, 170), (150, 150, 150), (155, 155, 155)]
        case .ocean: return [(80, 140, 255), (40, 200, 230), (120, 90, 255), (30, 170, 210), (160, 80, 240), (60, 110, 255), (40, 190, 180)]
        case .sunset: return [(255, 110, 60), (255, 180, 40), (255, 60, 90), (255, 210, 80), (240, 70, 140), (255, 140, 50), (230, 50, 110)]
        case .forest: return [(70, 220, 120), (40, 200, 180), (140, 230, 80), (30, 170, 140), (190, 235, 70), (50, 190, 110), (30, 150, 120)]
        case .candy: return [(255, 90, 170), (255, 120, 220), (210, 80, 255), (255, 150, 190), (180, 110, 255), (255, 70, 140), (230, 100, 240)]
        case .ice: return [(150, 230, 255), (90, 200, 255), (190, 240, 255), (120, 190, 255), (160, 220, 250), (80, 170, 255), (200, 235, 255)]
        case .gold: return [(255, 200, 70), (255, 170, 40), (255, 220, 110), (240, 150, 30), (255, 235, 140), (230, 160, 40), (250, 210, 90)]
        case .custom: return []
        }
    }
}

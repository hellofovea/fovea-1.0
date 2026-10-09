import SwiftUI
import AppKit
import WindowBenchCore

// Single source of truth for the window bench's color, type, spacing, shape and motion
// constants. Views never hardcode one. The notch's values are copied from
// Prototypes/FoveaWorkbench/WorkbenchTokens.swift and may drift from it; the paper values come
// from Sources/Fovea/Tokens.swift ("the Island is the same system inverted").

enum BenchTokens {

    // MARK: - The notch (black, white at opacities)

    enum Notch {
        static let surface = Color.black
        /// White at the notch's opacities: text, secondary, tertiary, hover, hairline.
        static let text = Color.white.opacity(0.85)
        static let textStrong = Color.white.opacity(0.95)
        static let secondary = Color.white.opacity(0.55)
        static let tertiary = Color.white.opacity(0.4)
        static let working = Color.white.opacity(0.62)
        static let fill = Color.white.opacity(0.08)
        static let hover = Color.white.opacity(0.12)
        static let hairline = Color.white.opacity(0.1)
        static let track = Color.white.opacity(0.14)
        static let pillFill = Color.white.opacity(0.17)
        static let pillHover = Color.white.opacity(0.23)
        /// Needs you and Failed, mixed for black.
        static let amber = Color(.sRGB, red: 0xF5 / 255.0, green: 0xB8 / 255.0, blue: 0x4B / 255.0)
        static let coral = Color(.sRGB, red: 0xF0 / 255.0, green: 0x6A / 255.0, blue: 0x6A / 255.0)
        /// The island's expanded corners and the Quick Answer slab's bottom radius.
        static let topRadius: CGFloat = 19
        static let bottomRadius: CGFloat = 24
        static let slabRadius: CGFloat = 20
        static let compactTop: CGFloat = 6
        static let compactBottom: CGFloat = 14
        static let rowRadius: CGFloat = 7
        static let pillRadius: CGFloat = 9
        static let thumbRadius: CGFloat = 6
        static let thumb = CGSize(width: 44, height: 32)
        static let rowFont = Font.system(size: 13.5)
        static let metaFont = Font.system(size: 11.5)
        static let statusFont = Font.system(size: 11.5, weight: .medium)
        static let sectionFont = Font.system(size: 11, weight: .semibold)
        static let pillFont = Font.system(size: 12, weight: .semibold)
        static let paddingH: CGFloat = 16
        static let paddingV: CGFloat = 12
        static let slabWidth: CGFloat = 560
        static let workingDot: CGFloat = 5
    }

    // MARK: - Paper (ink on canvas)

    enum Paper {
        static let ink = Color(.sRGB, red: 0x0C / 255.0, green: 0x0C / 255.0, blue: 0x0C / 255.0)
        static let canvas = Color(.sRGB, red: 0xFB / 255.0, green: 0xFA / 255.0, blue: 0xF7 / 255.0)
        static let elevated = Color.white
        static let needsYou = Color(.sRGB, red: 0x8A / 255.0, green: 0x5A / 255.0, blue: 0x00 / 255.0)
        static let failed = Color(.sRGB, red: 0xB9 / 255.0, green: 0x3A / 255.0, blue: 0x1A / 255.0)
        /// Dark Paper is the notch: black, white at its ladder.
        static let night = Color.black
    }

    /// Spec v1's warm tint over the system's content background.
    enum Warm {
        static let light = Color(.sRGB, red: 0.965, green: 0.949, blue: 0.918)
        static let dark = Color(.sRGB, red: 0.102, green: 0.098, blue: 0.090)
        static let opacity = 0.35
    }

    // MARK: - Type

    enum Type_ {
        struct Scale {
            let body: CGFloat
            let meta: CGFloat
            let section: CGFloat
            let crumb: CGFloat
        }
        static let notch = Scale(body: 13.5, meta: 11, section: 11, crumb: 12)
        static let macOS = Scale(body: 13, meta: 10.5, section: 11, crumb: 12)
        static func scale(_ variant: TypeScale) -> Scale { variant == .notch ? notch : macOS }

        static let pageTitle = Font.system(size: 22, weight: .semibold)
        static let largeTitle = Font.system(size: 26, weight: .bold)
        static let runWords = Font.system(size: 19, weight: .medium)
        static let heroTitle = Font.system(size: 24, weight: .semibold)
        static let heroBody = Font.system(size: 14)
        static let teaching = Font.system(size: 15)
        static let threadTitle = Font.system(size: 13.5, weight: .semibold)
        static let threadLarge = Font.system(size: 17, weight: .semibold)
        static let button = Font.system(size: 13)
        /// ▲ lines: computed by Fovea, so mono; the receipt's only emphasis, so semibold.
        static let difference = Font.system(size: 12.5, weight: .semibold, design: .monospaced)
        static let markdownBody = Font.system(size: 13.5)
        static let code = Font.system(size: 11.5, design: .monospaced)
        static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }

    // MARK: - Layout

    enum Layout {
        static let windowDefault = CGSize(width: 1240, height: 820)
        static let windowCompact = CGSize(width: 1000, height: 660)
        static let windowMin = CGSize(width: 900, height: 600)
        static let column: CGFloat = 860
        /// The run page's one measure: the receipt and every block of the body share it.
        static let runMeasure: CGFloat = 720
        /// Your words' share of a one-line run row, so the evidence after them stays legible.
        static let runWordsMax: CGFloat = 320
        static let evidenceMin: CGFloat = 150
        static let wideColumn: CGFloat = 900
        static let sideMargin: CGFloat = 32
        static let topMargin: CGFloat = 12
        static let bottomMargin: CGFloat = 40
        static let crumbBar: CGFloat = 40
        static let statusBar: CGFloat = 28
        static let glyphSlot: CGFloat = 16
        static let glyphGap: CGFloat = 10
        static let rowRadius: CGFloat = 7
        static let rowPaddingH: CGFloat = 10
        static let projectRow: (regular: CGFloat, compact: CGFloat) = (46, 38)
        static let runRow: (regular: CGFloat, compact: CGFloat) = (30, 26)
        static let runRowTwoLines: (regular: CGFloat, compact: CGFloat) = (46, 40)
        static let groupGap: CGFloat = 14
        static let headerHeight: CGFloat = 26
        static let hairline: CGFloat = 0.5
        static let timeColumn: CGFloat = 52
        static let actionSlot: CGFloat = 132
        static let threadGap: CGFloat = 26
        static let chipHeight: CGFloat = 22
        static let chipRadius: CGFloat = 11
        static let cardRadius: CGFloat = 12
        static let wellRadius: CGFloat = 8
        static let panelWidth: CGFloat = 300
        static let panelGap: CGFloat = 10
        static let settingsSize = CGSize(width: 680, height: 600)
        /// Preview 120, two lines of words, two of the mono line, and the hover slot for View in Project.
        static let captureCard = CGSize(width: 220, height: 238)
        /// A grid tile's shape: a screen's, near enough (most captures are of one).
        static let captureTileAspect: CGFloat = 16 / 10
        static let captureThumb = CGSize(width: 44, height: 32)
        static let hybridPreview = CGSize(width: 220, height: 132)
        static let searchCollapsed: CGFloat = 28
        static let searchExpanded: CGFloat = 300
        static let searchHeight: CGFloat = 28
        static let dropdownWidth: CGFloat = 520
        static let dropdownMaxHeight: CGFloat = 420
        static let popoverWidth: CGFloat = 320
        static let consentWidth: CGFloat = 520
        static let progressWidth: CGFloat = 240
        static let notchLine: CGFloat = 4

        /// The ink button at the system push button's sizes (font, height, side padding, radius).
        static func prominentButton(_ size: ControlSize) -> (font: CGFloat, height: CGFloat, padding: CGFloat, radius: CGFloat) {
            switch size {
            case .mini, .small: return (11, 19, 8, 5)
            case .large, .extraLarge: return (13, 28, 14, 7)
            default: return (13, 22, 11, 6)
            }
        }
    }

    // MARK: - Glyphs

    enum Glyph {
        /// Drawn circles: diameter and the notch Lasso's stroke weight.
        static let diameter: CGFloat = 9
        static let stroke: CGFloat = 1.4
        static let dash: [CGFloat] = [1.6, 1.9]
        static let dot: [CGFloat] = [0.01, 2.6]
        /// The inference underline's dots: round, 1.2 pt, every 2.6 pt.
        static let dotRule: CGFloat = 1.2
        static let symbolSize: CGFloat = 10
        static let bangFont = Font.system(size: 12, weight: .bold)
        /// The routing placeholder's breath (Choose chat): full to 0.45 and back.
        static let breatheLow = 0.45
        static let breathePeriod = 1.8
        /// The Lasso at glyph size (the notch draws it at 8.6 in a 24 pt mark).
        static let lassoRadius: CGFloat = 5.2
        static let lassoWeight: CGFloat = 1.3
        static let lassoHead: CGFloat = 2.0
        static let lassoPeriod = 1.5
        static let lassoLength = 0.75
        static let lassoTurns = 1.12
        static let lassoAdvance = 0.9
        static let lassoWaver2 = 0.05
        static let lassoWaver3 = 0.03
        static let lassoDrift = 0.7
        static let lassoShrink = 0.06
        static let frameRate = 60.0
    }

    // MARK: - Motion values (Motion.swift turns these into animations)

    enum MotionValues {
        // The notch's large surfaces (Paste, Choose chat), interpolating, bounce 0.
        static let open = 0.3, close = 0.22, expand = 0.32, collapse = 0.26, swap = 0.22
        static let flight = 0.45
        static let contentDuration = 0.10
        /// Zoom: the share of the drill at which the page starts to show inside the row's fill,
        /// and the share the fill holds full before it fades over the page.
        static let zoomContentStart: CGFloat = 0.55
        static let zoomFillHold: CGFloat = 0.6
        static let contentDelay = 0.08
        static let contentCurve = (0.23, 1.0, 0.32, 1.0)
        static let contentBlur: CGFloat = 4
        static let contentScale: CGFloat = 0.97
        static let lineRise: CGFloat = 8
        static let lineBlur: CGFloat = 2
        static let lineSwap = 0.15
        static let hover = 0.1
        static let select = 0.18
        static let reduced = 0.12
        /// Spec v1 §10.
        static let v1Transition = 0.30, v1Selection = 0.18, v1Arrival = 0.35, v1Reduced = 0.15
        /// docs/motion/NOTES.md's recommended springs (before AMENDMENTS §14).
        static let notesOpen = (0.38, 0.15), notesClose = (0.30, 0.0), notesConvert = (0.32, 0.1), notesHover = (0.26, 0.05)
        static let notesContent = 0.15
        /// Needs-you arrival.
        static let bounce = (0.5, 0.3)
        static let overshoot = (x1: 0.31, y1: 1.84, x2: 0.64, y2: 1.0, duration: 0.41, cap: 12.0)
        /// Stagger: the notch's 30 ms capped at 6; the reveal's own slider default.
        static let stagger = 0.03
        static let staggerCap = 6
        static let revealDefault = 80.0
        static let revealRange = 30.0...200.0
        static let rowRise: CGFloat = 8
        /// From the counts: the drop each row makes into its slot (under half a project row).
        static let revealDrop: CGFloat = 20
        static let rowBlur: CGFloat = 2
        /// Jump highlight: in, hold, fade (shipping highlightFade 0.24 s).
        static let highlightIn = 0.24
        static let highlightDefault = 1.4
        static let highlightRange = 0.6...3.0
        static let ringScale: CGFloat = 1.035
        static let pulseScale: CGFloat = 1.5
        /// Onboarding's scan: how long the counts take to land, and the tick.
        static let scanDuration = 2.6
        static let scanTick = 0.07
        /// Ticker digits.
        static let tickerRise: CGFloat = 12
        static let tickerBlur: CGFloat = 2
        /// The ghost's hand-off: the real view shows, then the ghost fades.
        static let ghostFade = 0.09
        static let crossFadeBlur: CGFloat = 4
        static let crossFade = 0.2
        static let pushDistance: CGFloat = 60
        static let speeds: [Double] = [1, 0.5, 0.25, 0.1]
    }

    // MARK: - Diff (the Tinted variant only: a counter-example to the no-hue rule)

    enum DiffTint {
        static let added = Color(.sRGB, red: 0.20, green: 0.62, blue: 0.32)
        static let removed = Color(.sRGB, red: 0.86, green: 0.27, blue: 0.24)
        static let line = 0.12
        static let word = 0.28
    }

    // MARK: - Opacities on paper (ink at an opacity, mirrored for the notch)

    enum Ink {
        static let secondary = 0.58
        /// 0.46 ink on canvas is 3.2:1 (the notch's 0.40 white on black is 3.7:1).
        static let tertiary = 0.46
        static let quaternary = 0.26
        /// The System surface's tertiary text, over labelColor (itself 0.85 ink): 0.45 ink, so
        /// ages and signatures stay at 3.3:1 in Light and 4.4:1 in Dark. The system's own
        /// tertiaryLabelColor (0.26) is under 2:1, too faint for words.
        static let systemTertiary = 0.53
        static let hairline = 0.09
        static let hover = 0.045
        static let pressed = 0.08
        static let selected = 0.07
        static let wash = 0.09
        static let fill = 0.05
        static let well = 0.035
    }
}

/// The colors a view draws with, for one surface in one appearance.
struct Palette: Equatable {
    var background: Color
    var raised: Color
    var text: Color
    var secondary: Color
    var tertiary: Color
    var quaternary: Color
    var hairline: Color
    var hover: Color
    var pressed: Color
    var selected: Color
    var wash: Color
    var fill: Color
    var well: Color
    var needsYou: Color
    var failed: Color
    var prominentFill: Color
    var prominentText: Color
    var isDark: Bool
    /// The warm tint's overlay color, when the surface has one.
    var tint: Color?

    static func make(_ surface: SurfaceVariant, dark: Bool) -> Palette {
        let I = BenchTokens.Ink.self
        switch surface {
        case .paper where !dark:
            let ink = BenchTokens.Paper.ink
            return Palette(background: BenchTokens.Paper.canvas, raised: BenchTokens.Paper.elevated, text: ink,
                           secondary: ink.opacity(I.secondary), tertiary: ink.opacity(I.tertiary),
                           quaternary: ink.opacity(I.quaternary), hairline: ink.opacity(I.hairline),
                           hover: ink.opacity(I.hover), pressed: ink.opacity(I.pressed), selected: ink.opacity(I.selected),
                           wash: ink.opacity(I.wash), fill: ink.opacity(I.fill), well: ink.opacity(I.well),
                           needsYou: BenchTokens.Paper.needsYou, failed: BenchTokens.Paper.failed,
                           prominentFill: ink, prominentText: BenchTokens.Paper.canvas, isDark: false, tint: nil)
        case .paper:
            let N = BenchTokens.Notch.self
            return Palette(background: BenchTokens.Paper.night, raised: Color.white.opacity(0.06), text: N.text,
                           secondary: N.secondary, tertiary: N.tertiary, quaternary: Color.white.opacity(0.25),
                           hairline: N.hairline, hover: Color.white.opacity(0.06), pressed: Color.white.opacity(0.1),
                           selected: Color.white.opacity(0.09), wash: Color.white.opacity(0.12), fill: N.fill,
                           well: Color.white.opacity(0.05), needsYou: N.amber, failed: N.coral,
                           prominentFill: Color.white, prominentText: Color.black, isDark: true, tint: nil)
        case .system, .warm:
            let label = Color(nsColor: .labelColor)
            let state: (Color, Color) = dark ? (BenchTokens.Notch.amber, BenchTokens.Notch.coral)
                                             : (BenchTokens.Paper.needsYou, BenchTokens.Paper.failed)
            return Palette(background: Color(nsColor: .textBackgroundColor), raised: Color(nsColor: .controlBackgroundColor),
                           text: label, secondary: Color(nsColor: .secondaryLabelColor),
                           tertiary: label.opacity(I.systemTertiary), quaternary: Color(nsColor: .quaternaryLabelColor),
                           hairline: Color(nsColor: .separatorColor), hover: label.opacity(I.hover),
                           pressed: label.opacity(I.pressed), selected: label.opacity(I.selected), wash: label.opacity(I.wash),
                           fill: label.opacity(I.fill), well: label.opacity(I.well), needsYou: state.0, failed: state.1,
                           prominentFill: label, prominentText: Color(nsColor: .textBackgroundColor), isDark: dark,
                           tint: surface == .warm ? (dark ? BenchTokens.Warm.dark : BenchTokens.Warm.light).opacity(BenchTokens.Warm.opacity) : nil)
        }
    }

    /// The notch's own palette: the receipt card in Notch black, the lab notch.
    static let notch = Palette(background: BenchTokens.Notch.surface, raised: BenchTokens.Notch.fill,
                               text: BenchTokens.Notch.text, secondary: BenchTokens.Notch.secondary,
                               tertiary: BenchTokens.Notch.tertiary, quaternary: Color.white.opacity(0.25),
                               hairline: BenchTokens.Notch.hairline, hover: BenchTokens.Notch.hover,
                               pressed: Color.white.opacity(0.16), selected: BenchTokens.Notch.hover,
                               wash: Color.white.opacity(0.14), fill: BenchTokens.Notch.fill, well: Color.white.opacity(0.06),
                               needsYou: BenchTokens.Notch.amber, failed: BenchTokens.Notch.coral,
                               prominentFill: Color.white, prominentText: Color.black, isDark: true, tint: nil)
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.make(.system, dark: false)
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

import AppKit
import SwiftUI
import CapturesCore
import FoveaKit

/// Every color, size and duration in Fovea Captures.
///
/// Fovea's surfaces (System is the design; the others are kept for comparison shots):
/// - **System** (default): macOS's own semantic colors, sampled from AppKit on this Mac
///   (windowBackground #ECECEC / controlBackground #1E1E1E under the cards; label, secondary and
///   tertiary label at 85 / 50 / 26 % ink, 85 / 55 / 25 % white; separators at 10 %; the
///   system fills at 10 / 8 / 5 / 3 %; find highlights in the system's yellow).
/// - **Paper**: Fovea's window as `Sources/Fovea/Tokens.swift` draws it, ink #0C0C0C on canvas
///   #FBFAF7 with every neutral the ink at an opacity (AGENTS.md's rule for the window).
enum T {
    enum Paper {
        static let ink = Color(.sRGB, red: 0x0C / 255.0, green: 0x0C / 255.0, blue: 0x0C / 255.0)
        static let canvas = Color(.sRGB, red: 0xFB / 255.0, green: 0xFA / 255.0, blue: 0xF7 / 255.0)
        static let night = Color(.sRGB, red: 0.07, green: 0.07, blue: 0.075)
        static let nightCard = Color(.sRGB, red: 0.12, green: 0.12, blue: 0.125)
    }

    /// Spacing sits on one scale, 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 (design engineers' 4-pt
    /// scale leaning on 8; Apple's 8 pt between siblings and 20 pt to a window's edge), with
    /// more space between groups than within one. The few off-scale numbers are named as what
    /// they are: proportions (a card's inset) or optical nudges.
    enum Layout {
        /// The window's one size, as Wispr Flow's and Typeless's are fixed: it can't be resized
        /// or made full screen. 1112 × 784 is the size it had on Ryan's 13-inch Air; four columns
        /// of cards fit in it.
        static let window = CGSize(width: 1112, height: 784)

        // The grid: one centered block, as wide as its columns.
        /// The least space either side of the grid.
        static let sideMargin: CGFloat = 24
        static let maxColumns = 6
        /// Between cards, both ways: twice Apple's sibling spacing; wider on Paper, where white
        /// cards on #FBFAF7 barely show their edges and the space has to do the grouping.
        static func gridGap(_ surface: Surface) -> CGFloat { surface.quietEdges ? 20 : 16 }
        /// Under the toolbar, above the first day.
        static let contentInset: CGFloat = 20
        /// Above each later day: a break clearly larger than the gap between cards.
        static let sectionGap: CGFloat = 40
        /// A day's title to its cards: closer to what it names than to the day before.
        static let headerGap: CGFloat = 12

        /// The page inset in the window's material, Aside's way: 8 pt in from the window's
        /// edges, its corners concentric with the window's. macOS 27 rounds this window 17 pt
        /// (measured), so the page is rounded 17 − 8, up to 10 (Aside: 26 and 18 on its site, 20
        /// and 12 in the app on macOS 27).
        static let pageInset: CGFloat = 8
        static let pageRadius: CGFloat = 10
        /// Aside's card radius (its "Next up" card): a little rounder than the page's corner, as a
        /// small thing reads rounder at the same radius.
        static let cardRadius: CGFloat = 12
        /// Paste 5's header band, for the corner icon.
        static let headerHeight: CGFloat = 50
        /// The small, whole app icon (its artwork is about 80 % of this).
        static let smallIcon: CGFloat = 20

        /// The expanded card: Aside's reading card, rounder than the card it grew from, as a
        /// window is.
        static let detailRadius: CGFloat = 18
        /// With pictures: wide enough for two regions side by side.
        static let detailMaxWidth: CGFloat = 720
        /// Words only: no wider than its line of text needs.
        static let detailTextWidth: CGFloat = 600
        static let detailMargin: CGFloat = 40
        static let detailPadding: CGFloat = 32
        static let detailTextPadding: CGFloat = 40
        /// About 75 characters of 15 pt text per line.
        static let detailMeasure: CGFloat = 520
        static let detailBar: CGFloat = 48
        /// How far an icon's glyph sits inside its 28-pt button, so a button can be placed by
        /// where its glyph is (aligned with the text below it), not by its hit area.
        static let glyphInset: CGFloat = 9
        /// Settings' grouped form: a label stays near the switch it names.
        static let column: CGFloat = 560
        /// The other arrangements: a wider column; the titles' column beside the cards, and the
        /// gap to them; half of two columns, and the gap between them.
        static let wideColumn: CGFloat = 720
        static let besideTitles: CGFloat = 224
        static let besideGap: CGFloat = 32
        /// Titles beside: from a section to the rule under it, and from the rule to the next.
        static let besideRuleGap: CGFloat = 32
        static let halfColumn: CGFloat = 440
        static let columnGap: CGFloat = 24
        static let searchWidth: CGFloat = 240
        /// The toolbar's glass, as tall as macOS 27 draws its own (36.5 pt, measured): search's
        /// circle and capsule, and the circle around you.
        static let toolbarControl: CGFloat = 36
        /// Below this window width the open search is shorter (the toolbar's center control
        /// spans about 360 pt; search and you must clear it).
        static let compactWidth: CGFloat = 1000
        static let compactSearchWidth: CGFloat = 150
        /// A macOS icon's artwork fills 824 of its 1024-pt canvas: the rest is margin and shadow.
        static let iconArtFraction: CGFloat = 824.0 / 1024.0
    }

    /// The library, Aside's layout: the window's own material at the left, and an opaque page
    /// inset at the right whose corners are concentric with the window's (Aside: 8 pt in, about
    /// 12 pt round, measured on macOS 27).
    enum Library {
        static let sidebarWidth: CGFloat = 288
        static let pageInset = Layout.pageInset
        static let pageRadius = Layout.pageRadius
        /// The traffic lights' row, which holds the sidebar's search centered on the lights (26 pt
        /// down, as Aside's), and the room the lights take at its left.
        static let titlebar: CGFloat = 52
        static let trafficLights: CGFloat = 78
        /// The page's header: the back button, the island, you.
        static let header: CGFloat = 56
        /// The island hanging from the page's top edge: its height, its ears, its round foot.
        static let islandHeight: CGFloat = 36
        static let islandEars: CGFloat = 8
        static let islandFoot: CGFloat = 16
        static let rowRadius: CGFloat = 8
        /// The note's widest line of content (its words are held narrower by `detailMeasure`).
        static let noteWidth: CGFloat = 720
    }

    /// Settings as the Mac draws its own: measured from SwiftUI's grouped Form rendered on macOS
    /// 27 (the reference `Form { Section }.formStyle(.grouped)`), so the sidebar layout's page
    /// reads as a native settings page while keeping Fovea's controls where a picture says more.
    enum Native {
        static let sidebarWidth: CGFloat = 220
        /// The page column: a settings page's width, centered in what's left of the window.
        static let column: CGFloat = 600
        /// Group boxes: white at 97.5 % on the white page; dark, 19.3 % on 15.7 %.
        static let groupLight: Double = 0.975, groupDark: Double = 0.193
        static let pageLight: Double = 1.0, pageDark: Double = 0.157
        /// Rows' hairlines, 1 pt, inset 10 pt at both ends.
        static let separatorLight: Double = 0.937, separatorDark: Double = 0.242
        static let groupRadius: CGFloat = 10
        static let rowInset: CGFloat = 10
        static let rowHeight: CGFloat = 36
        static let rowHeightWithDetail: CGFloat = 52
        /// A section's header over its group, and the gap between sections.
        static let headerGap: CGFloat = 8
        static let sectionGap: CGFloat = 22
        /// Between one sidebar section's sections and the next's.
        static let categoryGap: CGFloat = 40
    }

    /// Aside's shading, measured from the CSS of heyaside.com (whose app views are rebuilt at the
    /// app's own point sizes) and checked against the app on macOS 27. Every neutral is the ink
    /// at an opacity. A surface is told from what it sits on by a 0.5 pt edge just inside it and
    /// a soft shadow in two layers (a tight one where it touches, a wide one around it), never by
    /// a gray box; in dark, a rim of light along its top edge as well. What floats over content
    /// is glass.
    enum Shade {
        /// The ink, at: a segmented control's track 6 %, a chip's or a search field's fill 7 %,
        /// a chosen row 9 %, the same fill hovered 10 %, a surface's own edge 8 %, a separator
        /// 12 %, a field's focus edge 25 %, an active chip 90 %.
        static let track = 0.06, fill = 0.07, chosen = 0.09, fillHover = 0.10, pressed = 0.14
        static let edge = 0.08, line = 0.12, focus = 0.25, active = 0.90
        /// A primary button's ink (Aside's Start recording: black at 95 %; white at 85 % in dark).
        static let prominent = 0.95
        /// One shadow: CSS `0 y blur rgba(0,0,0,opacity)`, with SwiftUI's radius about half the
        /// blur.
        struct Layer: Equatable { var opacity: Double; var radius: CGFloat; var y: CGFloat }
        /// How high a surface sits: on the page at rest, lifted by the pointer, floating over
        /// everything (the expanded card), or the page itself in the window.
        enum Level: Equatable { case flat, resting, raised, floating, page, control }

        /// The two layers of a level. Light: Aside's controls `0 1 3 .07`, its reading card
        /// `0 1 12 .08`, its window `0 18 44 .45, 0 3 10 .3` (over a painting; lighter here, over
        /// the page). Dark needs about four times the opacity to show at all.
        static func layers(_ level: Level, dark: Bool) -> (Layer, Layer) {
            let k = dark ? 4.0 : 1.0
            switch level {
            case .flat: return (Layer(opacity: 0, radius: 0, y: 0), Layer(opacity: 0, radius: 0, y: 0))
            case .control: return (Layer(opacity: 0.07 * k, radius: 1.5, y: 1), Layer(opacity: 0, radius: 0, y: 0))
            case .resting: return (Layer(opacity: 0.05 * k, radius: 1.5, y: 1), Layer(opacity: 0.04 * k, radius: 6, y: 2))
            case .raised: return (Layer(opacity: 0.06 * k, radius: 2, y: 1), Layer(opacity: 0.09 * k, radius: 12, y: 5))
            case .floating: return (Layer(opacity: 0.08 * k, radius: 4, y: 2), Layer(opacity: min(0.5, 0.18 * k), radius: 24, y: 12))
            case .page: return (Layer(opacity: 0.04 * k, radius: 1, y: 0.5), Layer(opacity: 0.08 * k, radius: 6, y: 1))
            }
        }
    }

    /// macOS's text styles (HIG): Headline 13 bold, Body 13, Callout 12, Subheadline 11,
    /// Title 3 15. Nothing smaller than 10.
    enum Text {
        static let cardTitle = Font.headline
        static let cardTime = Font.subheadline
        static let cardBody: CGFloat = 13
        static let detailBody: CGFloat = 15
    }

    enum Motion {
        /// The card growing into the expanded card, and back. Springs with no bounce; the way back
        /// a little quicker than the way out (Emil Kowalski: exits shorter than entries), both
        /// under 300 ms of travel.
        static let open = 0.32, close = 0.26
        static let swap = 0.22, page = 0.24, hover = 0.12, press = 0.08
        /// A segmented control's pill, sliding to the segment pressed: quick, as a control
        /// answers, not as a page moves.
        static let pill = 0.12
        static let content = 0.10, reduced = 0.15
        static let contentBlur: CGFloat = 4
        /// How far a page slides as it fades (forward: from the right).
        static let pageShift: CGFloat = 10
    }
}

/// The window's color scheme. Three of Fovea's own, from the design-language study (OKLCH-built,
/// contrast measured against the card; notes in the scratchpad's research-language/), and the
/// two it started from, for comparison.
enum Surface: String, CaseIterable {
    /// Ink and ivory, and a highlighter yellow used only as a fill behind ink. The fovea sits in
    /// the macula lutea, the "yellow spot"; highlighting what you point at is what Fovea does.
    case macula
    /// Ink and ivory, and an ultramarine pencil for what's chosen and what you pointed at.
    case bluePencil
    /// The window as the Island grown out: an ink toolbar, and yellow only for what's live.
    case notch
    /// AGENTS.md's window: ink on #FBFAF7, every neutral the ink at an opacity.
    case paper
    /// macOS's own colors.
    case system

    var title: String {
        switch self {
        case .macula: return "Macula: ink, ivory, highlighter"
        case .bluePencil: return "Blue Pencil: ink, ivory, ultramarine"
        case .notch: return "Notch: the Island, grown out"
        case .paper: return "Paper: ink on canvas"
        case .system: return "System: macOS colors"
        }
    }

    /// Cards whose edges barely show against the canvas: the space between them does the
    /// grouping, so it's wider.
    var quietEdges: Bool { self != .system }
}

/// How the words you pointed with are marked.
enum BindingMark { case highlighter, underline }

/// The colors a view draws with in one appearance.
struct Palette {
    var background: Color
    var card: Color
    var raised: Color
    var header: Color
    var text: Color
    var secondary: Color
    var tertiary: Color
    var hairline: Color
    var fill: Color
    var fillStrong: Color
    var dim: Color
    /// Search's hit marker (nil: hits are set heavier and underlined instead).
    var highlight: Color?
    /// What's chosen and what has focus: the selection ring, the focus ring, a chosen tab.
    var accent: Color
    var isDark: Bool
    var surface: Surface
    /// The signature fill behind ink: referent tabs, the words you pointed with, the busiest
    /// days. What's drawn on it.
    var mark: Color = .black
    var onMark: Color = .white
    /// The wash behind the words you pointed with, or the color of their underline.
    var bindingWash: Color = .clear
    var binding: BindingMark = .underline
    /// The island pill (the chosen filter) and what's written on it.
    var pill: Color = .black
    var onPill: Color = .white
    /// Dictation, Capture, Dispatch.
    var kinds: [Color] = [.teal, .blue, .purple]
    /// The toolbar's band (nil: the system's own toolbar).
    var band: Color?
    var bandIsDark = false
    /// Something that needs you (a permission missing), and something that can't be undone.
    var warning: Color = Color(nsColor: .systemOrange)
    var danger: Color = Color(nsColor: .systemRed)
    /// The calendar's five shades: no captures, then four levels; and text on the darkest two.
    var heat: [Color] = []
    var onHeat: Color = .white
    /// The library's page, inset in the window's material (nil: the canvas).
    var pageColor: Color?
    var page: Color { pageColor ?? background }

    /// The ink at an opacity (Aside's every neutral): black, Fovea's #0C0C0C, or white in dark.
    func ink(_ opacity: Double) -> Color {
        (isDark ? Color.white : (surface == .system ? Color.black : T.Paper.ink)).opacity(opacity)
    }
    /// A surface's own edge, just inside it.
    var edge: Color { ink(T.Shade.edge) }
    /// Native settings: the page, a group's box, a row's hairline (`T.Native`).
    var nativePage: Color { Color(white: isDark ? T.Native.pageDark : T.Native.pageLight) }
    var nativeGroup: Color { Color(white: isDark ? T.Native.groupDark : T.Native.groupLight) }
    var nativeSeparator: Color { Color(white: isDark ? T.Native.separatorDark : T.Native.separatorLight) }
    /// Behind a destructive control the pointer is on (Aside's Delete): a pink wash, or the
    /// system red at 20 % in dark.
    var dangerWash: Color { isDark ? Color(nsColor: .systemRed).opacity(0.2) : Color(hex: 0xFAE7EC) }
    /// The window around the inset page, for Fovea's own schemes (System's is the window's
    /// material): the Notch scheme's ink, or the canvas a step darker.
    var frame: Color { bandIsDark ? Color(hex: 0x0C0C0C) : background }

    func kind(_ k: CaptureKind) -> Color {
        switch k { case .dictation: return kinds[0]; case .dispatch: return kinds[2] }
    }

    /// `accent`: the one the person chose in Settings › Appearance; nil keeps the theme's own.
    static func make(dark: Bool, surface: Surface, accent: Color? = nil) -> Palette {
        var p: Palette
        switch surface {
        case .macula: p = macula(dark)
        case .bluePencil: p = bluePencil(dark)
        case .notch: p = notch(dark)
        case .paper, .system: p = classic(dark: dark, surface: surface)
        }
        // A chosen accent goes through the whole window, whatever the theme: what's chosen, the
        // things you took, the words you pointed with, the calendar's shades.
        if let accent {
            p.accent = accent
            p.mark = accent
            p.onMark = .white
            p.bindingWash = accent.opacity(dark ? 0.34 : 0.2)
            p.binding = .highlighter
            p.heat = [p.fill, accent.opacity(dark ? 0.35 : 0.22), accent.opacity(dark ? 0.55 : 0.42), accent.opacity(dark ? 0.78 : 0.68), accent]
            p.onHeat = .white
        }
        return p
    }

    /// A palette from its hexes: text ladder, canvas, card, raised, hairline.
    private static func base(_ dark: Bool, _ surface: Surface, canvas: UInt32, card: UInt32, raised: UInt32,
                             text: UInt32, secondary: UInt32, tertiary: UInt32, hairline: UInt32, accent: Color) -> Palette {
        let ink = dark ? Color(hex: 0xF8F6EF) : Color(hex: 0x0C0C0C)
        return Palette(background: Color(hex: canvas), card: Color(hex: card), raised: Color(hex: raised),
                       header: ink.opacity(dark ? 0.04 : 0.03),
                       text: Color(hex: text), secondary: Color(hex: secondary), tertiary: Color(hex: tertiary),
                       hairline: Color(hex: hairline), fill: ink.opacity(dark ? 0.06 : 0.05), fillStrong: ink.opacity(dark ? 0.12 : 0.1),
                       dim: Color.black.opacity(dark ? 0.5 : 0.2), highlight: nil, accent: accent, isDark: dark, surface: surface)
    }

    private static func macula(_ dark: Bool) -> Palette {
        var p = dark
            ? base(true, .macula, canvas: 0x100F0D, card: 0x1A1917, raised: 0x242320, text: 0xE6E4DE, secondary: 0xA8A6A1,
                   tertiary: 0x85837F, hairline: 0x302F2D, accent: Color(hex: 0xFCDE3D))
            : base(false, .macula, canvas: 0xF8F6EF, card: 0xFEFDFB, raised: 0xFFFFFF, text: 0x1F1F1F, secondary: 0x595958,
                   tertiary: 0x727170, hairline: 0xE6E5E3, accent: Color(hex: 0x0C0C0C))
        p.mark = Color(hex: 0xFCDE3D); p.onMark = Color(hex: 0x0C0C0C)
        p.binding = .highlighter
        p.bindingWash = dark ? Color(hex: 0xFCDE3D).opacity(0.32) : Color(hex: 0xFFE772)
        p.pill = dark ? Color(hex: 0xF8F6EF) : Color(hex: 0x0C0C0C); p.onPill = dark ? Color(hex: 0x0C0C0C) : Color(hex: 0xF8F6EF)
        p.kinds = dark ? [Color(hex: 0x65D2D2), Color(hex: 0x8DC2FE), Color(hex: 0xD0AAFC)]
                       : [Color(hex: 0x077B7C), Color(hex: 0x136DBF), Color(hex: 0x834BB9)]
        p.heat = dark ? [0x2A2826, 0x453D14, 0x817221, 0xC7AE19, 0xFFE976].map { Color(hex: $0) }
                      : [0xEDECEA, 0xF8E68E, 0xECC825, 0xAC8717, 0x0C0C0C].map { Color(hex: $0) }
        p.onHeat = dark ? Color(hex: 0x0C0C0C) : .white
        p.band = p.background
        p.warning = dark ? Color(hex: 0xF5B84B) : Color(hex: 0x8A5A00)
        p.danger = dark ? Color(hex: 0xF06A6A) : Color(hex: 0xB93A1A)
        return p
    }

    private static func bluePencil(_ dark: Bool) -> Palette {
        let blue = dark ? Color(hex: 0x8AA6FE) : Color(hex: 0x283DDE)
        var p = dark
            ? base(true, .bluePencil, canvas: 0x0C0C0C, card: 0x181716, raised: 0x21201E, text: 0xE6E4DE, secondary: 0xA7A6A1,
                   tertiary: 0x84827E, hairline: 0x2E2D2C, accent: blue)
            : base(false, .bluePencil, canvas: 0xEFEDE5, card: 0xF8F6EF, raised: 0xFDFCF9, text: 0x1F1F1E, secondary: 0x585755,
                   tertiary: 0x6F6E6B, hairline: 0xE0DFD8, accent: blue)
        p.mark = blue; p.onMark = dark ? Color(hex: 0x0C0C0C) : .white
        p.binding = .underline
        p.bindingWash = blue
        p.highlight = dark ? Color(hex: 0x3C4560) : Color(hex: 0xCACDEB)
        p.pill = dark ? Color(hex: 0xF8F6EF) : Color(hex: 0x0C0C0C); p.onPill = dark ? Color(hex: 0x0C0C0C) : Color(hex: 0xF8F6EF)
        p.kinds = dark ? [Color(hex: 0x65D2D2), Color(hex: 0xF09FD9), Color(hex: 0xF8F6EF)]
                       : [Color(hex: 0x077B7C), Color(hex: 0xA63A8D), Color(hex: 0x0C0C0C)]
        p.heat = dark ? [0x282725, 0x212E60, 0x364BA7, 0x5D7BF1, 0xAEC2FE].map { Color(hex: $0) }
                      : [0xE7E6DF, 0xC8D6FF, 0x8DA7F7, 0x4366E8, 0x1A2C94].map { Color(hex: $0) }
        p.onHeat = dark ? Color(hex: 0x0C0C0C) : .white
        p.band = p.background
        p.warning = dark ? Color(hex: 0xF5B84B) : Color(hex: 0x8A5A00)
        p.danger = dark ? Color(hex: 0xF06A6A) : Color(hex: 0xB93A1A)
        return p
    }

    private static func notch(_ dark: Bool) -> Palette {
        var p = dark
            ? base(true, .notch, canvas: 0x000000, card: 0x131312, raised: 0x1C1C1A, text: 0xE6E4DD, secondary: 0xA6A49F,
                   tertiary: 0x81807C, hairline: 0x2A2A28, accent: Color(hex: 0xF8F6EF))
            : base(false, .notch, canvas: 0xF1F0EC, card: 0xFBFAF7, raised: 0xFFFFFF, text: 0x1F1F1F, secondary: 0x585857,
                   tertiary: 0x70706F, hairline: 0xE3E2E0, accent: Color(hex: 0x0C0C0C))
        p.mark = Color(hex: 0xFCDE3D); p.onMark = Color(hex: 0x0C0C0C)
        p.binding = .highlighter
        p.bindingWash = dark ? Color(hex: 0xFCDE3D).opacity(0.3) : Color(hex: 0xFFE772)
        p.pill = dark ? Color(hex: 0xF8F6EF) : Color(hex: 0x0C0C0C); p.onPill = dark ? Color(hex: 0x0C0C0C) : Color(hex: 0xF8F6EF)
        p.kinds = dark ? [Color(hex: 0x65D2D2), Color(hex: 0x8DC2FE), Color(hex: 0xD0AAFC)]
                       : [Color(hex: 0x077B7C), Color(hex: 0x136DBF), Color(hex: 0x834BB9)]
        p.heat = dark ? [0x232321, 0x454543, 0x7A7975, 0xC6C4BE, 0xFCDE3D].map { Color(hex: $0) }
                      : [0xEAE9E7, 0xC6C6C3, 0x8F8F8D, 0x4F4F4E, 0x0C0C0C].map { Color(hex: $0) }
        p.onHeat = dark ? Color(hex: 0x0C0C0C) : .white
        // The Island's ink, across the top of the window.
        p.band = Color(hex: 0x0C0C0C); p.bandIsDark = true
        p.warning = dark ? Color(hex: 0xF5B84B) : Color(hex: 0x8A5A00)
        p.danger = dark ? Color(hex: 0xF06A6A) : Color(hex: 0xB93A1A)
        return p
    }

    /// The two the study started from: macOS's colors, and AGENTS.md's ink on canvas.
    private static func classic(dark: Bool, surface: Surface) -> Palette {
        var p: Palette
        switch (surface, dark) {
        // macOS 26's colors, sampled on macOS 27 (so 14 and 15 draw the same): the window white or
        // #1E1E1E, the under-page #F6F6F6 or #282828; the label ladder at 85 / 50 / 26 % black and
        // 85 / 55 / 25 % white; separators and fills at 10 / 5 %; the accent the person chose.
        // The page is the under-page gray with white cards in light, the window's #1E1E1E with
        // #282828 cards in dark: what's raised is lighter in both.
        case (.system, false):
            let k = Color.black
            p = Palette(background: Color(hex: 0xF6F6F6), card: .white, raised: .white, header: k.opacity(0.03),
                        text: k.opacity(0.85), secondary: k.opacity(0.5), tertiary: k.opacity(0.26), hairline: k.opacity(0.1),
                        fill: k.opacity(0.05), fillStrong: k.opacity(0.1), dim: k.opacity(0.18),
                        highlight: Color(nsColor: .findHighlightColor).opacity(0.45), accent: Color(nsColor: .controlAccentColor),
                        isDark: false, surface: surface)
        case (.system, true):
            let w = Color.white
            p = Palette(background: Color(hex: 0x1E1E1E), card: Color(hex: 0x282828), raised: Color(hex: 0x323232),
                        header: w.opacity(0.04), text: w.opacity(0.85), secondary: w.opacity(0.55), tertiary: w.opacity(0.25),
                        hairline: w.opacity(0.1), fill: w.opacity(0.05), fillStrong: w.opacity(0.1), dim: Color.black.opacity(0.45),
                        highlight: Color(nsColor: .findHighlightColor).opacity(0.38), accent: Color(nsColor: .controlAccentColor),
                        isDark: true, surface: surface)
        case (_, false):
            let ink = T.Paper.ink
            p = Palette(background: T.Paper.canvas, card: .white, raised: .white, header: ink.opacity(0.04),
                        text: ink, secondary: ink.opacity(0.58), tertiary: ink.opacity(0.4), hairline: ink.opacity(0.09),
                        fill: ink.opacity(0.05), fillStrong: ink.opacity(0.1), dim: ink.opacity(0.2),
                        highlight: nil, accent: ink, isDark: false, surface: surface)
            p.warning = Color(hex: 0x8A5A00); p.danger = Color(hex: 0xB93A1A)
        case (_, true):
            let w = Color.white
            p = Palette(background: T.Paper.night, card: T.Paper.nightCard, raised: T.Paper.nightCard, header: w.opacity(0.05),
                        text: w.opacity(0.88), secondary: w.opacity(0.58), tertiary: w.opacity(0.4), hairline: w.opacity(0.1),
                        fill: w.opacity(0.06), fillStrong: w.opacity(0.12), dim: Color.black.opacity(0.55),
                        highlight: nil, accent: w.opacity(0.88), isDark: true, surface: surface)
            p.warning = Color(hex: 0xF5B84B); p.danger = Color(hex: 0xF06A6A)
        }
        let a = p.accent
        p.mark = surface == .system ? a : p.text
        p.onMark = surface == .system ? .white : (dark ? .black : .white)
        // The words you pointed with: the selection's own wash (the accent, light), as text you
        // select is marked; Paper underlines in ink.
        p.bindingWash = surface == .system ? a.opacity(dark ? 0.34 : 0.2) : p.text.opacity(0.6)
        p.binding = surface == .system ? .highlighter : .underline
        // The island: the notch's black, in every appearance.
        p.pill = surface == .system ? .black : p.text
        p.onPill = .white
        p.kinds = surface == .system ? [Color(nsColor: .systemTeal), Color(nsColor: .systemBlue), Color(nsColor: .systemPurple)]
                                     : [p.text, p.text, p.text]
        p.heat = [p.fill, a.opacity(dark ? 0.35 : 0.22), a.opacity(dark ? 0.55 : 0.42), a.opacity(dark ? 0.78 : 0.68), a]
        p.onHeat = dark && surface == .paper ? .black : .white
        p.band = surface == .system ? nil : p.background
        return p
    }

    /// AppKit's version of a color for drawing outside SwiftUI (the inline chips).
    func ns(_ color: Color) -> NSColor { NSColor(color) }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

private struct PaletteKey: EnvironmentKey { static let defaultValue = Palette.make(dark: false, surface: .macula) }
extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

/// Every animation in the window, at the model's speed (the frame recorder slows it); Reduce
/// Motion is a short fade.
struct MotionSpec: Equatable {
    var speed: Double = 1
    var reduce = false

    enum Role { case open, close, swap, page, content, hover, press }

    func animation(_ role: Role) -> Animation {
        if reduce { return .easeOut(duration: T.Motion.reduced).speed(speed) }
        let base: Animation
        switch role {
        case .open: base = .interpolatingSpring(duration: T.Motion.open, bounce: 0)
        case .close: base = .interpolatingSpring(duration: T.Motion.close, bounce: 0)
        case .swap: base = .interpolatingSpring(duration: T.Motion.swap, bounce: 0)
        case .page: base = .interpolatingSpring(duration: T.Motion.page, bounce: 0)
        // Emil Kowalski's ease-out (0.23, 1, 0.32, 1): quick to start, soft to land.
        case .content: base = .timingCurve(0.23, 1, 0.32, 1, duration: T.Motion.content)
        case .hover: base = .easeOut(duration: T.Motion.hover)
        case .press: base = .easeOut(duration: T.Motion.press)
        }
        return base.speed(speed)
    }

    func seconds(_ s: Double) -> Double { s / max(speed, 0.01) }
}

private struct MotionKey: EnvironmentKey { static let defaultValue = MotionSpec() }
extension EnvironmentValues {
    var motion: MotionSpec {
        get { self[MotionKey.self] }
        set { self[MotionKey.self] = newValue }
    }
}

// MARK: - Curves

enum Curve {
    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

    static func lerp(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
        CGRect(x: lerp(a.minX, b.minX, t), y: lerp(a.minY, b.minY, t),
               width: lerp(a.width, b.width, t), height: lerp(a.height, b.height, t))
    }

    /// 0 before `a`, 1 after `b`, smooth between.
    static func step(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = min(1, max(0, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
}

// MARK: - Transitions (Animatable, so their curves apply at every step)

/// Content arriving after its container: opacity, a 4 pt blur and 0.97 scale from the top
/// (the notch's content entrance). Reduce Motion keeps only the fade.
struct ContentReveal: ViewModifier, Animatable {
    @Environment(\.motion) private var motion
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        let travel = motion.reduce ? 0 : 1 - progress
        content
            .opacity(progress)
            .blur(radius: travel * T.Motion.contentBlur)
            .scaleEffect(1 - 0.03 * travel, anchor: .top)
    }
}

/// A block swapped for another in place: the old one gone by 40% of the way, the new one from
/// 50%, so the two are never read together.
struct BlockFade: ViewModifier, Animatable {
    var progress: CGFloat
    let entering: Bool
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        content.opacity(Double(entering ? max(0, (progress - 0.5) / 0.5) : max(0, 1 - progress / 0.4)))
    }
}

/// A page replacing another: the old one fades out quickly as it drifts back; the new one fades
/// in from `shift` points ahead (forward: from the right; back: from the left).
struct PageShift: ViewModifier, Animatable {
    @Environment(\.motion) private var motion
    var progress: CGFloat
    let entering: Bool
    let forward: Bool
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        let sign: CGFloat = forward ? 1 : -1
        let shift = motion.reduce ? 0 : T.Motion.pageShift
        if entering {
            let t = Curve.step(0.25, 1, progress)
            content.opacity(Double(t)).offset(x: sign * shift * (1 - progress))
        } else {
            let t = Curve.step(0, 0.45, progress)
            content.opacity(Double(1 - t)).offset(x: -sign * shift * 0.6 * progress)
        }
    }
}

extension AnyTransition {
    static var reveal: AnyTransition {
        .modifier(active: ContentReveal(progress: 0), identity: ContentReveal(progress: 1))
    }
    static var blockSwap: AnyTransition {
        .asymmetric(insertion: .modifier(active: BlockFade(progress: 0, entering: true), identity: BlockFade(progress: 1, entering: true)),
                    removal: .modifier(active: BlockFade(progress: 1, entering: false), identity: BlockFade(progress: 0, entering: false)))
    }
    static func page(forward: Bool) -> AnyTransition {
        .asymmetric(insertion: .modifier(active: PageShift(progress: 0, entering: true, forward: forward),
                                         identity: PageShift(progress: 1, entering: true, forward: forward)),
                    removal: .modifier(active: PageShift(progress: 1, entering: false, forward: forward),
                                       identity: PageShift(progress: 0, entering: false, forward: forward)))
    }
}

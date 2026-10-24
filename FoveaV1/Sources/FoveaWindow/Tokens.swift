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
        /// or made full screen. 1112 × 784 was the size it had on Ryan's 13-inch Air; Oct 13, "a
        /// little bit smaller": 1024 × 720, the same shape at 92 %.
        static let window = CGSize(width: 1024, height: 720)

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
        static var cardRadius: CGFloat { WindowLook.isAligned ? T.Aligned.cardRadius : 12 }
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
    /// one soft shadow (`Shading` draws the wide layer where a level has one), never by a gray
    /// box. What floats over content is glass.
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

    /// Oct 21, Ryan: "research what spring animation is, then apply it ... use Emil Kowalski's
    /// skills to refine the animations", and then: "for other places, don't always use spring
    /// animations; use the correct animations." Nothing in the window is dragged, thrown or alive
    /// the way the island is, so it moves on curves (Emil Kowalski's): a strong ease-out for what
    /// enters or leaves, a strong ease-in-out for what moves or changes shape on screen, `ease` for
    /// a hover, linear for time passing. Every value per transition: docs/motion/SPRINGS.md › Window.
    enum Motion {
        /// A cubic Bézier timing curve and how long it runs.
        struct Timing: Equatable {
            let curve: (Double, Double, Double, Double)
            let duration: Double
            init(_ curve: (Double, Double, Double, Double), _ duration: Double) { self.curve = curve; self.duration = duration }
            static func == (a: Timing, b: Timing) -> Bool {
                a.curve == b.curve && a.duration == b.duration
            }
        }

        // MARK: The curves

        /// Emil Kowalski's strong ease-out: starts fast, so what arrives feels like an answer.
        static let easeOut = (0.23, 1.0, 0.32, 1.0)
        /// Ease-in-out cubic: for something already on screen that moves or changes shape.
        static let easeInOut = (0.645, 0.045, 0.355, 1.0)
        /// CSS's `ease`: a hover's color or shadow.
        static let ease = (0.25, 0.1, 0.25, 1.0)

        // MARK: Moving or changing shape on screen (ease-in-out)

        /// Cards reflowing (one deleted, one back with Undo), a block changing height, the rows
        /// under a new row making room: a short move.
        static let layout = Timing(easeInOut, 0.28)
        /// A card growing into its expanded card from its own frame: the window's one large move.
        /// Oct 21, Ryan ("simpler is better"): 0.3 s, the frame and the grey only (it was 0.4 s
        /// with blurs, a scale, flying pictures and a growing shadow on top).
        static let zoomOpen = Timing(easeInOut, 0.3)
        /// The expanded card going home into its card: the same path, shorter (exits are).
        static let zoomClose = Timing(easeInOut, 0.25)
        /// A selection pill sliding to the segment pressed (the kinds, the years, the panes).
        static let select = Timing(easeInOut, 0.2)

        // MARK: Arriving and leaving (ease-out)

        /// Content arriving (a banner, a row) and leaving, quicker.
        static let fadeIn = Timing(easeOut, 0.2), fadeOut = Timing(easeOut, 0.14)
        /// The search field opening out of its icon, its words with it, and folding back.
        static let searchOpen = Timing(easeOut, 0.2), searchClose = Timing(easeOut, 0.15)
        /// A toast fading in at the window's foot, and away (Oct 21, Ryan: it rose out of a blur).
        static let toastIn = Timing(easeOut, 0.2), toastOut = Timing(easeOut, 0.15)

        // MARK: Hover

        /// A hover's color or fill; nothing moves.
        static let hover = Timing(ease, 0.12)

        // MARK: Sizes and moments

        /// Oct 21, Ryan: Copy's checkmark stays this long, then turns back into Copy.
        static let copiedHold = 1.2
        /// Oct 21, Ryan: Delete's checkmark shows this long before the card folds away: long
        /// enough to be seen, short enough not to feel like a wait.
        static let deleteBeat = 0.32
        /// A calibration dot filling: time passing, so linear.
        static let calibrationHold = 0.9
        /// The avatar's popover (the Mac's own, from the avatar) waits this long under the pointer
        /// before it opens, so passing over it doesn't open it, and lingers this long after.
        static let popoverWait = 0.4, popoverLinger = 0.15
        /// Reduce Motion (Appearance › Motion, or the Mac's): every change an opacity fade this
        /// long on the ease-out, nothing travelling, scaling or bouncing.
        static let reduced = 0.15
        /// On the way home the expanded card's grey has gone by this share of the zoom's time, and
        /// its own content by this one, each on the ease-out from the first frame, so a close
        /// answers at once and the window never sits in grey while the card lands.
        static let dimLeaves = 0.6, contentLeaves = 0.6
        /// ...and the card's own face comes back from this share of it.
        static let faceReturns = 0.15
    }
}

/// Oct 24, Ryan: "do you think the app itself is aligned with the design of the onboarding and the
/// notch… generate a new version of the app ui for me to compare with the old." Two looks of one
/// window: as it is (Current), or drawn in the notch's and the first run's language (Aligned).
/// View › Window Design switches them, at once; `--window-look=aligned` starts with Aligned. Every
/// change and its reason: docs/window/ALIGNED.md.
enum WindowLook: String, CaseIterable {
    case current, aligned

    /// The look being drawn. The views read it through `T.Aligned` and the palette; the window's
    /// content is drawn again when it changes (MainView's `.id`).
    static var shown: WindowLook = {
        let args = CommandLine.arguments
        if let flag = args.first(where: { $0.hasPrefix("--window-look=") }) {
            return WindowLook(rawValue: String(flag.dropFirst("--window-look=".count))) ?? .current
        }
        return UserDefaults.standard.string(forKey: storeKey).flatMap(WindowLook.init(rawValue:)) ?? .current
    }()
    static var isAligned: Bool { shown == .aligned }
    static let storeKey = "fovea.window.look"

    var title: String { self == .current ? "Current Design" : "Aligned Design" }
}

extension T {
    /// The Aligned look (`WindowLook`): the window in the notch's and the first run's language.
    /// Values are the notch's (WorkbenchTokens `Board`, `V2`, `Native`) or the first run's
    /// (OnboardingTokens `OT`), named where they come from; docs/window/ALIGNED.md.
    enum Aligned {
        // The label ladder: the notch's board (title .92, line .60, time .40) and the first run's
        // (.94 / .62 / .40). The Mac's own is lighter (.85 / .50 / .26).
        static let text = 0.92, secondary = 0.60, tertiary = 0.40
        /// Hairlines and a surface's rule: the board's .08.
        static let hairline = 0.08

        // Surfaces: content is opaque (HIG: glass is for controls), so the page is the window's
        // own color, and what sits on it is a fill, as the first run's cards and the notch's rows
        // are: no edge, no shadow. Light: the window white with cards at ink 4.5 %; dark: #1E1E1E
        // with cards at white 7 % (the first run: 5 % and 9 %), each laid down as one opaque
        // color (`cardOpaqueLight` / `cardOpaqueDark`), so a card's color can also be drawn on.
        static let pageLight: UInt32 = 0xFFFFFF, pageDark: UInt32 = 0x1E1E1E
        /// A card's and a Settings group's corner: the first run's cards and the notch's outline
        /// card (14, rows 8 inside 6 of padding).
        static let cardRadius: CGFloat = 14

        // Type: the notch's row (title 13.5 semibold, line 11.5); display titles in New York, as
        // the first run's pages are titled (30 semibold there), tracked tighter as they grow
        // (Apple's tracking tables; Emil Kowalski: hierarchy from weight, size and leading).
        static let title = Font.system(size: 13.5, weight: .semibold)
        static let meta = Font.system(size: 11.5)
        /// The first run's display face: New York, or the system face in Chinese (OT.Board).
        static var displayDesign: Font.Design { FoveaLocale.shared.language == .chinese ? .default : .serif }
        static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold, design: displayDesign) }
        /// -2 % of the size: large type reads loose at the tracking small type wants.
        static func displayTracking(_ size: CGFloat) -> CGFloat { -0.02 * size }
        static let paneTitle: CGFloat = 26
        static let dayTitle: CGFloat = 19
        static let emptyTitle: CGFloat = 22

        // Buttons: one family with the notch's (Native: the accent, lighter under the pointer,
        // lighter again pressed; the secondary a fill with no edge) at the first run's heights.
        static let primaryHover = 0.85, primaryPressed = 0.72
        static let secondaryFill = 0.07, secondaryHover = 0.11, secondaryPressed = 0.15
        static let buttonHeight: CGFloat = 28, buttonHeightLarge: CGFloat = 32
        /// A press: 0.97, on the press itself, quick on the ease-out (Emil Kowalski: 100–160 ms;
        /// the notch's and the first run's `press`, 0.14 s).
        static let pressScale: CGFloat = 0.97
        static let press = Motion.Timing(Motion.easeOut, 0.12)
        /// A round icon button's plate at rest and under the pointer (the notch's .08 / .14).
        static let iconPlate = 0.06, iconPlateHover = 0.12

        // A choice of a few: the first run's (NotchChoiceRow): a track, the chosen one solid ink
        // (white in dark) with the page's color for its words; 0.12 s on the ease-out.
        static let trackLight = 0.05, trackDark = 0.09
        static let select = Motion.Timing(Motion.easeOut, 0.12)

        // The sidebar: the Mac's symbols, in ink; the chosen row a fill, its symbol in the accent
        // (the board's highlighted row is the ink at 6 %). Oct 24, Ryan: "the icons here are way
        // too big… a better fit with the words beside them": the symbol a point under the words
        // (the Mac's sidebar list had scaled it up to its own icon size), in a column as wide as
        // the widest, 7 pt to the words.
        static let sidebarSymbol: CGFloat = 12
        static let sidebarSymbolColumn: CGFloat = 16
        static let sidebarGap: CGFloat = 7
        static let sidebarText: CGFloat = 13
        static let sidebarChosen = 0.07

        // States, the notch's: done green, needs you orange, failed red with a cross.
        static let stateGlyph: CGFloat = 12
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
    /// Something done (the notch's Complete): the system green.
    var done: Color = Color(nsColor: .systemGreen)
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
        if WindowLook.isAligned { p.align() }
        return p
    }

    /// The Aligned look (`T.Aligned`): the notch's label ladder and hairline, the page the
    /// window's own color with cards as fills on it, and no color for a capture's kind (the
    /// notch's Voiceflow is "never a color"; Dispatch's color is the person's light, not purple).
    private mutating func align() {
        let A = T.Aligned.self
        let k: Color = isDark ? .white : .black
        text = k.opacity(A.text)
        secondary = k.opacity(A.secondary)
        tertiary = k.opacity(A.tertiary)
        hairline = k.opacity(A.hairline)
        background = Color(hex: isDark ? A.pageDark : A.pageLight)
        pageColor = nil
        card = Color(hex: isDark ? A.cardOpaqueDark : A.cardOpaqueLight)
        raised = Color(hex: isDark ? 0x2A2A2A : 0xFFFFFF)
        kinds = [secondary, secondary, secondary]
        // The island pill (the chosen filter, a chosen segment): the first run's, solid ink, white
        // in dark, with the page's color for its words.
        pill = isDark ? .white : .black
        onPill = Color(hex: isDark ? A.pageDark : A.pageLight)
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
/// Motion is a short fade. Oct 21, Ryan: one role per kind of change, each a `T.Motion` timing.
struct MotionSpec: Equatable {
    var speed: Double = 1
    var reduce = false

    enum Role {
        /// Moving or changing shape on screen: ease-in-out.
        case layout, zoomOpen, zoomClose, select
        /// Arriving and leaving: ease-out.
        case fadeIn, fadeOut, searchOpen, searchClose, toastIn, toastOut
        /// A hover's color: `ease`.
        case hover
        /// Aligned: a button giving to the press (`T.Aligned.press`).
        case press
    }

    static func timing(_ role: Role) -> T.Motion.Timing {
        switch role {
        case .layout: return T.Motion.layout
        case .zoomOpen: return T.Motion.zoomOpen
        case .zoomClose: return T.Motion.zoomClose
        // Aligned: the first run's quick ease-out (a choice made often; the slow start lagged).
        case .select: return WindowLook.isAligned ? T.Aligned.select : T.Motion.select
        case .press: return T.Aligned.press
        case .searchOpen: return T.Motion.searchOpen
        case .searchClose: return T.Motion.searchClose
        case .fadeIn: return T.Motion.fadeIn
        case .fadeOut: return T.Motion.fadeOut
        case .toastIn: return T.Motion.toastIn
        case .toastOut: return T.Motion.toastOut
        case .hover: return T.Motion.hover
        }
    }

    func animation(_ role: Role) -> Animation {
        if reduce { return .timingCurve(T.Motion.easeOut.0, T.Motion.easeOut.1, T.Motion.easeOut.2, T.Motion.easeOut.3,
                                        duration: T.Motion.reduced).speed(speed) }
        let t = Self.timing(role)
        return Animation.timingCurve(t.curve.0, t.curve.1, t.curve.2, t.curve.3, duration: t.duration).speed(speed)
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

    /// A cubic Bézier timing curve's progress at `x`, the fraction of its time gone.
    static func bezier(_ c: (Double, Double, Double, Double), _ x: Double) -> Double {
        func at(_ t: Double, _ p1: Double, _ p2: Double) -> Double { 3 * (1 - t) * (1 - t) * t * p1 + 3 * (1 - t) * t * t * p2 + t * t * t }
        var lo = 0.0, hi = 1.0
        for _ in 0..<24 {
            let m = (lo + hi) / 2
            if at(m, c.0, c.2) < x { lo = m } else { hi = m }
        }
        return at((lo + hi) / 2, c.1, c.3)
    }

    /// The fraction of a timing curve's time gone when it has reached `progress` (its inverse).
    static func timeGone(_ c: (Double, Double, Double, Double), at progress: Double) -> Double {
        var lo = 0.0, hi = 1.0
        for _ in 0..<24 {
            let m = (lo + hi) / 2
            if bezier(c, m) < progress { lo = m } else { hi = m }
        }
        return (lo + hi) / 2
    }

    /// 0 before `a`, 1 after `b`, smooth between.
    static func step(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = min(1, max(0, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
}

// MARK: - Transitions

extension AnyTransition {
    /// Oct 21, Ryan: a row, a note or a line arriving fades in on the ease-out (`fadeIn`, 0.2 s)
    /// and leaves quicker (`fadeOut`, 0.14 s), whatever moves the rows around it (`layout`).
    static var arrive: AnyTransition {
        let i = T.Motion.fadeIn, o = T.Motion.fadeOut
        return .asymmetric(insertion: .opacity.animation(.timingCurve(i.curve.0, i.curve.1, i.curve.2, i.curve.3, duration: i.duration)),
                           removal: .opacity.animation(.timingCurve(o.curve.0, o.curve.1, o.curve.2, o.curve.3, duration: o.duration)))
    }
}

// MARK: Aligned · Home

extension T.Aligned {
    /// A card's header, the notch board row's: where it went at the front (the board's 26 pt agent
    /// icon, a step smaller on a card), 10 pt to the words, 2 pt between the title and its line.
    static let cardIcon: CGFloat = 24
    static let cardIconGap: CGFloat = 10
    static let cardLineGap: CGFloat = 2
    /// The card's fill laid on the page, as one opaque color: the card is drawn twice where it
    /// grows into the expanded card, and over the window's grey there (light: white with ink at
    /// 4.5 %; dark: #1E1E1E with white at 7 %).
    static let cardOpaqueLight: UInt32 = 0xF4F4F4, cardOpaqueDark: UInt32 = 0x2E2E2E
    /// A day's count beside its title, and the calendar's total: the system face's even digits.
    static let countSize: CGFloat = 13
    /// A day's own page: its date as the first run titles a page.
    static let dayPageTitle: CGFloat = 26
    /// The toast: on the toolbar's glass, its words in the label color, its action in the accent.
    static let toastHeight: CGFloat = 34
}

// MARK: Aligned · Settings

extension T.Aligned {
    /// A choice of a few in Settings: the first run's (NotchChoiceRow): 22 pt pills, each 10 pt in
    /// on its words, on a track that holds them 2 pt in; 11.5 pt words.
    static let segmentHeight: CGFloat = 22, segmentInset: CGFloat = 2, segmentPadding: CGFloat = 10, segmentFont: CGFloat = 11.5
    /// A pane's title over its line, as the first run titles a page over its body.
    static let paneTitleGap: CGFloat = 6
    static let paneLine: CGFloat = 13
    /// A row's description: the notch's line.
    static let rowDetail: CGFloat = 11.5
    /// A section's header over its group: the notch's titles are semibold, never bold.
    static let sectionHeader = Font.system(size: 13, weight: .semibold)
    /// The light's tiles: the first run's AuraChip, the seven colors as dots on the notch's black,
    /// three to a row as the first run lays them; the chosen one ringed in the secondary ink.
    static let auraChipBack = Color.black
    static let auraChipHeight: CGFloat = 26, auraChipRadius: CGFloat = 8
    static let auraDot: CGFloat = 8, auraDotGap: CGFloat = 3, auraColumns = 3
    static let chosenRing: CGFloat = 1.5, chosenRingRadius: CGFloat = 10, chosenRingPadding: CGFloat = 4
    /// The accent's swatches: the first run's (16 pt, a 7 pt white dot on the chosen one, a
    /// hairline round each, the chosen one ringed 2 pt out).
    static let swatch: CGFloat = 16, swatchDot: CGFloat = 7, swatchGap: CGFloat = 10, swatchRingGap: CGFloat = 2
    static let swatchDotColor = Color.white
    static let multicolor: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red]
    /// The hue and the drift: the first run's sliders (a 10 pt spectrum and a 6 pt track filled in
    /// the accent, a 16 pt white knob).
    static let hueTrack: CGFloat = 10, driftTrack: CGFloat = 6, sliderThumb: CGFloat = 16
    static let knobEdge = Color.white, knobShadow = Color.black.opacity(0.3)
    /// A text field on a pane: a fill rounded 8, as the notch's model menu and the first run's
    /// fields are; its accent ring while it has the keyboard.
    static let fieldRadius: CGFloat = 8
}

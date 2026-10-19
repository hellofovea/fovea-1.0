import AppKit
import SwiftUI
import CapturesCore
import FoveaStore
import FoveaKit

/// The window's pages. Captures is home; Settings replaces it in place (from the profile icon,
/// which opens it on Account), with a back arrow at the toolbar's leading edge.
enum Page: String, CaseIterable {
    /// The first page: the last seven days, then the calendar of every day before.
    case captures
    /// One day's archive, opened from the calendar.
    case day
    case settings
    /// How deep a page sits, so a change knows which way to slide.
    var depth: Int { self == .captures ? 0 : 1 }
}

/// How the window is laid out.
enum LayoutStyle: String, CaseIterable {
    /// Aside's: the captures listed in the window's own translucent material at the left, and an
    /// opaque page inset at the right that shows this week's cards, a capture opened as a note,
    /// one day, or Settings.
    case library
    /// The cards alone under a toolbar (the earlier rounds).
    case cards
    var title: String { self == .library ? "Library (the Aside layout study)" : "Cards under a toolbar" }
}

/// Where the cards' page sits in the window.
enum PageStyle: String, CaseIterable {
    /// Aside's shading: the window is the system's material, and the page an opaque sheet inset
    /// 8 pt in it, its corners concentric with the window's.
    case inset
    /// The page fills the window, under the toolbar (the earlier rounds).
    case full
    var title: String { self == .inset ? "Inset in the window (Aside)" : "Fills the window" }
}

/// The island that hangs from the top of the page, as the notch hangs from the screen.
enum PageIslandStyle: String, CaseIterable {
    /// Solid black, exactly the notch's color, its words white at opacities (the Island's own
    /// language). Liquid Glass can't be black: the system lightens it over a light page.
    case solid
    /// The system's Liquid Glass in the island's shape (macOS 26 and later; black before).
    case glass
    /// No island: the system's segmented control.
    case segmented
    var title: String {
        switch self {
        case .solid: return "Black island (the notch)"
        case .glass: return "Liquid Glass island"
        case .segmented: return "System segmented control"
        }
    }
}

/// How the days before this week are shown under (or over) the week's cards.
enum HistoryStyle: String, CaseIterable {
    /// A year as a contribution graph: a square per day, shaded by how much you said (GitHub's).
    case yearGraph
    /// The same graph, first on the page, over the week's cards (GitHub's profile order).
    case yearGraphTop
    /// The months as small calendars, each day a dated square shaded the same way.
    case months
    /// A strip of days pinned under the toolbar, a bar per day, scrolling back through the year.
    case timeline
    var title: String {
        switch self {
        case .yearGraph: return "Year graph, below the week"
        case .yearGraphTop: return "Year graph, above the week"
        case .months: return "Month calendars, below the week"
        case .timeline: return "Timeline, pinned on top"
        }
    }
}

/// Where a day opens when you click it in the calendar.
enum ArchiveStyle: String, CaseIterable {
    /// A page of its own, with a back arrow and the days before and after.
    case page
    /// In place, right under the calendar.
    case inline
    var title: String { self == .page ? "A page of its own" : "In place, under the calendar" }
}

enum CardSize: String, CaseIterable {
    case small, medium, large
    var title: String { rawValue.capitalized }
    /// Medium was 236 (Pinterest's column); 220 since Oct 13, so four cards fit a row in the
    /// 1024-pt window, the calendar above as wide as the four.
    var width: CGFloat {
        switch self { case .small: return 200; case .medium: return 220; case .large: return 276 }
    }
    /// The card's inset, about 6 % of its width (Paste's proportion).
    var padding: CGFloat {
        switch self { case .small: return 12; case .medium: return 14; case .large: return 16 }
    }
}

/// How much room the cards have: inside a card (its insets, the gaps in its header and under it,
/// its line spacing, how many lines it shows over a preview) and around them (between cards,
/// between days). The anatomy, sizes and colors stay the same in all of them.
///
/// Research (notes in the scratchpad's `research-cards/cards.md`):
/// - The cramped feeling is the padding and the gaps, not the line spacing.
/// - Proximity: the space between cards should be clearly larger than the space inside one (NN/g).
///   Fovea had 16 between and 14 inside, 1.14×. Paste's cards, measured, are about 1.7×: 24
///   between, 14 inside.
/// - Apple's widgets, smaller than these cards, take a 16 pt margin.
/// - Narrow text wants about 1.5× line height (Refactoring UI).
/// - Every preset keeps the order header line gap < header to body < inset < card gap < day gap.
enum CardSpacing: String, CaseIterable {
    /// The earlier rounds' spacing.
    case current
    /// A little air: Apple's widget margin, the gaps a step larger.
    case little
    /// Airy: Paste's gap between cards, 1.5× lines.
    case airy
    /// Air by showing less: a line fewer over a preview, at most seven alone.
    case quiet

    var title: String {
        switch self {
        case .current: return "As before"
        case .little: return "A little more air"
        case .airy: return "Airy"
        case .quiet: return "Less in each card"
        }
    }

    struct Metrics {
        /// Added to the card size's own inset (12 · 14 · 16).
        var inset: CGFloat
        /// The header's top inset, against the side inset (the icon's artwork margin makes up
        /// the 2 pt).
        var headerTop: CGFloat
        /// Between the theme and the type line under it.
        var headerLineGap: CGFloat
        /// From the header to the words.
        var bodyGap: CGFloat
        var lineSpacing: CGFloat
        /// Lines of words over a preview of what you took.
        var previewLines: Int
        /// Lines of words with nothing taken (nil: as many as fit).
        var textLines: Int?
        /// The least space between the words and the preview.
        var previewGap: CGFloat
        var gridGap: CGFloat
        var sectionGap: CGFloat
        /// From a day's label to its cards.
        var dayLabelGap: CGFloat
        /// Under the toolbar, above the first day.
        var contentInset: CGFloat
    }

    var metrics: Metrics {
        switch self {
        case .current:
            return Metrics(inset: 0, headerTop: -2, headerLineGap: 1, bodyGap: 12, lineSpacing: 3, previewLines: 3,
                           textLines: nil, previewGap: 10, gridGap: 16, sectionGap: 40, dayLabelGap: 12, contentInset: 20)
        case .little:
            return Metrics(inset: 2, headerTop: -2, headerLineGap: 2, bodyGap: 14, lineSpacing: 3, previewLines: 3,
                           textLines: nil, previewGap: 12, gridGap: 20, sectionGap: 44, dayLabelGap: 14, contentInset: 24)
        case .airy:
            return Metrics(inset: 4, headerTop: -2, headerLineGap: 3, bodyGap: 16, lineSpacing: 4, previewLines: 3,
                           textLines: nil, previewGap: 14, gridGap: 24, sectionGap: 48, dayLabelGap: 16, contentInset: 28)
        case .quiet:
            return Metrics(inset: 2, headerTop: -2, headerLineGap: 2, bodyGap: 16, lineSpacing: 4, previewLines: 2,
                           textLines: 7, previewGap: 14, gridGap: 20, sectionGap: 44, dayLabelGap: 14, contentInset: 24)
        }
    }

    /// The card's side inset at a size.
    func padding(_ size: CardSize) -> CGFloat { size.padding + metrics.inset }
    /// Between cards, both ways; wider on Fovea's quiet-edged schemes, where the space does the
    /// grouping the edges don't.
    func gridGap(_ surface: Surface) -> CGFloat { metrics.gridGap + (surface.quietEdges ? 4 : 0) }
}

/// What the card's header names.
enum HeaderStyle: String, CaseIterable {
    /// Dictation, Capture or Dispatch: the type, as Paste names a clip's type.
    case type
    /// Three or four words on what it's about.
    case theme
    /// The theme, with the type beside the time.
    case themeAndType
    var title: String {
        switch self {
        case .type: return "Type"
        case .theme: return "Theme (3–4 words)"
        case .themeAndType: return "Theme, then type"
        }
    }
}

enum IconStyle: String, CaseIterable {
    /// Paste 6, and the HIG's rule for app icons: whole and small, at the header's trailing end.
    case small
    /// Paste 5: a header band, with the icon's artwork as tall as the band, cut by the card's corner.
    case corner
    /// Small, before the type.
    case leading
    var title: String {
        switch self {
        case .small: return "Small, whole (Paste 6)"
        case .corner: return "Large, cut by the corner (Paste 5)"
        case .leading: return "Small, before the type"
        }
    }
}

/// What a card shows of what you took, besides the chip at its place in your words.
enum CardAttachments: String, CaseIterable {
    case inlineAndPreview, inlineOnly
    var title: String { self == .inlineAndPreview ? "Chips + preview below" : "Chips only" }
}

enum DetailStyle: String, CaseIterable {
    /// The card grows into a larger card over the dimmed grid (Quick Look).
    case quickLook
    /// The card grows to fill the window's content.
    case page
    var title: String { self == .quickLook ? "Over the grid" : "Fills the window" }
}

/// What the expanded card does with what you took while it grows.
enum AttachmentMotion: String, CaseIterable {
    /// Each one flies from its place on the card to its place in the expanded card.
    case fly
    /// The card's preview fades out as the expanded card's fades in.
    case crossfade
    var title: String { self == .fly ? "Fly to place" : "Crossfade" }
}

enum HitStyle: String, CaseIterable {
    /// The system's find highlight (yellow), as Mail, Notes and Safari mark a match.
    case highlight
    /// A heavier weight in the same ink.
    case weight
    var title: String { self == .highlight ? "Find highlight" : "Heavier weight" }
}

/// The toolbar's center, by the window's width: room for the tabs at the widest one's width;
/// for them at their own widths; or for them closer together.
enum ToolbarFit { case roomy, natural, tight }

/// How a Settings pane uses the page's width.
enum SettingsArrangement: String, CaseIterable {
    /// One centered column, 560 pt (the earlier rounds).
    case column
    /// One centered column, 720 pt: the same page with more of the width.
    case wide
    /// Each section's title and note in a column at the left, its card at the right (Stripe's and
    /// Tailwind UI's "two columns with descriptions"); untitled cards across both.
    case beside
    /// The sections flowing into two columns, each into the shorter one.
    case twoColumns

    var title: String {
        switch self {
        case .column: return "One column (as before)"
        case .wide: return "One wider column"
        case .beside: return "Titles beside the cards"
        case .twoColumns: return "Two columns"
        }
    }

    /// The width it lays out at.
    var width: CGFloat {
        switch self {
        case .column: return T.Layout.column
        case .wide: return T.Layout.wideColumn
        case .beside: return T.Layout.besideTitles + T.Layout.besideGap + T.Layout.column
        case .twoColumns: return 2 * T.Layout.halfColumn + T.Layout.columnGap
        }
    }

    /// Itself where the page has room; otherwise the widest that fits, down to the one column.
    func fitting(_ available: CGFloat) -> SettingsArrangement {
        let order: [SettingsArrangement] = [self, .wide, .column]
        return order.first { $0.width <= available } ?? .column
    }
}

private struct SettingsArrangementKey: EnvironmentKey { static let defaultValue = SettingsArrangement.column }
extension EnvironmentValues {
    /// The arrangement a Settings pane is laid out in, after it's fitted to the page.
    var settingsArrangement: SettingsArrangement {
        get { self[SettingsArrangementKey.self] }
        set { self[SettingsArrangementKey.self] = newValue }
    }
}

enum SettingsLayout: String, CaseIterable {
    /// The sidebar leading one scrolling page: the sidebar follows the page as it scrolls and
    /// takes you to a section with a click.
    case sidebar
    /// Ryan's call (October): System Settings' own. The sidebar of tiles at the left, and the
    /// section picked shown alone beside it.
    case sidebarPanes
    /// One pane at a time, picked from tabs across the top (a Settings window's toolbar): the
    /// earlier rounds.
    case tabs
    /// Every pane on one scrolling page, no sidebar.
    case onePage
    var title: String {
        switch self {
        case .sidebar: return "Sidebar, everything on one page"
        case .sidebarPanes: return "Sidebar, one section at a time (as now)"
        case .tabs: return "Tabs across the top"
        case .onePage: return "One page, no sidebar"
        }
    }
    var hasSidebar: Bool { self == .sidebar || self == .sidebarPanes }
}

/// The Settings sidebar's sections, in System Settings' manner: each a tile of color with a white
/// symbol (`SettingsIcon`), grouped as its sidebar groups them. AGENTS.md's categories, with
/// Dictionary renamed Memory (it holds the dictionary and the memories), and two Ryan asked for
/// (October): Appearance (light or dark, the accent) and Notch (the Island's look, its glow, how
/// it opens). Language came with the App UI review (row 6): Fovea's words and the notch's.
/// Memory, Appearance, Notch and Language go past AGENTS.md's list; DESIGN.md says so.
///
/// Oct 15 review, MW-04 (Ryan: "we already have all of these in the settings tab; you can
/// re-organise it"): Dictionary is a section of its own again, Getting Started is new (the tour,
/// practice, the permissions and your keys), and About takes the version, updates, beta, help
/// and the legal links out of Account.
enum SettingsCategory: String, CaseIterable, Identifiable {
    case account, plan, gettingStarted, appearance, notch, language, voice, dictionary, memory, shortcuts, connectors,
         eyeTracking, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .account: return L("Account")
        case .plan: return L("Plan")
        case .gettingStarted: return L("Getting Started")
        case .appearance: return L("Appearance")
        case .notch: return L("Notch")
        case .language: return L("Language")
        case .voice: return L("Voice & Capture")
        case .dictionary: return L("Dictionary")
        case .memory: return L("Memory")
        case .shortcuts: return L("Shortcuts")
        case .connectors: return L("Connectors")
        case .eyeTracking: return L("Eye Tracking")
        case .about: return L("About")
        }
    }
    /// The sidebar's groups, divided by space as System Settings' are (Oct 15 review, MW-04).
    static let groups: [[SettingsCategory]] = [
        [.account, .plan], [.gettingStarted], [.appearance, .notch, .language],
        [.voice, .dictionary, .memory, .shortcuts], [.connectors, .eyeTracking], [.about],
    ]
    /// The white symbol on the tile: filled, as System Settings' are (`nil`: drawn, the notch).
    var symbol: String? {
        switch self {
        case .account: return "person.fill"
        case .plan: return "creditcard.fill"
        case .gettingStarted: return "flag.fill"
        case .appearance: return "circle.lefthalf.filled"
        case .notch: return nil
        case .language: return "globe"
        case .voice: return "waveform"
        case .dictionary: return "character.book.closed.fill"
        case .memory: return "brain.head.profile.fill"
        case .shortcuts: return "keyboard.fill"
        case .connectors: return "app.connected.to.app.below.fill"
        case .eyeTracking: return "eye.fill"
        case .about: return "info"
        }
    }
    /// The tile's color, from System Settings' own: blue as Users & Groups, black as Appearance and
    /// Desktop & Dock, red as Sound, gray as Keyboard and General, indigo as Focus, purple as
    /// Screen Time, pink as Notifications' neighbours.
    var tile: SettingsTileColor {
        switch self {
        case .account: return .blue
        case .plan: return .green
        case .gettingStarted: return .purple
        case .appearance, .notch: return .black
        case .language: return .blue
        case .voice: return .red
        case .dictionary: return .pink
        case .memory: return .orange
        case .shortcuts: return .gray
        case .connectors: return .teal
        case .eyeTracking: return .indigo
        case .about: return .gray
        }
    }
    /// What the section is for, under its name at the top of the pane.
    var summary: String {
        switch self {
        case .account: return L("Your Fovea account, and how Fovea runs on this Mac.")
        case .plan: return L("Your credits this month, and the plans.")
        case .gettingStarted: return L("The tour again, a task to practise, and what Fovea needs to work.")
        case .appearance: return L("Light or dark, and the color that marks what you choose.")
        case .notch: return L("How Fovea looks around your MacBook's notch, and how it opens.")
        case .language: return L("The language Fovea and the notch speak, and the one you speak.")
        case .voice: return L("Your microphone, what Fovea reads from your screen, and how long it keeps your captures.")
        case .dictionary: return L("The names and terms Fovea writes your way.")
        case .memory: return L("What Fovea has come to know about you, and what it may remember.")
        case .shortcuts: return L("The keys that start Fovea from any app.")
        case .connectors: return L("The agents your dispatches go to, and what they can see.")
        case .eyeTracking: return L("Look at something, say \u{201C}this\u{201D}, and Fovea knows what you mean.")
        case .about: return L("Fovea's version and its updates, help, and the small print.")
        }
    }
    /// The tab a section lives on in the layouts without a sidebar.
    var pane: SettingsPane {
        switch self {
        case .account, .memory, .dictionary, .appearance, .language, .gettingStarted, .about: return .account
        case .plan: return .plan
        case .voice, .notch: return .voice
        case .shortcuts: return .shortcuts
        case .connectors: return .connectors
        case .eyeTracking: return .eyeTracking
        }
    }
}

/// The colors System Settings draws its tiles in.
enum SettingsTileColor {
    case blue, green, black, red, orange, gray, teal, indigo, purple, pink
    var nsColor: NSColor {
        switch self {
        case .blue: return NSColor(srgbRed: 0.04, green: 0.52, blue: 1.0, alpha: 1)
        case .green: return NSColor(srgbRed: 0.19, green: 0.78, blue: 0.35, alpha: 1)
        case .black: return NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        case .red: return NSColor(srgbRed: 1.0, green: 0.22, blue: 0.37, alpha: 1)
        case .orange: return NSColor(srgbRed: 1.0, green: 0.58, blue: 0.0, alpha: 1)
        case .gray: return NSColor(srgbRed: 0.56, green: 0.56, blue: 0.58, alpha: 1)
        case .teal: return NSColor(srgbRed: 0.19, green: 0.69, blue: 0.78, alpha: 1)
        case .indigo: return NSColor(srgbRed: 0.37, green: 0.36, blue: 0.90, alpha: 1)
        // Oct 15 review, MW-04: Getting Started's and Dictionary's tiles.
        case .purple: return NSColor(srgbRed: 0.69, green: 0.32, blue: 0.87, alpha: 1)
        case .pink: return NSColor(srgbRed: 1.0, green: 0.18, blue: 0.53, alpha: 1)
        }
    }
}

/// The accent, as macOS offers it: Multicolor follows the Mac's own accent, and the eight colors
/// put one accent through the whole window. Only these: no color well.
enum AccentChoice: String, CaseIterable {
    case multicolor, blue, purple, pink, red, orange, yellow, green, graphite
    var title: String { rawValue.capitalized }
    /// nil: the theme's own accent.
    var color: Color? {
        switch self {
        case .multicolor: return nil
        case .blue: return Color(nsColor: .systemBlue)
        case .purple: return Color(nsColor: .systemPurple)
        case .pink: return Color(nsColor: .systemPink)
        case .red: return Color(nsColor: .systemRed)
        case .orange: return Color(nsColor: .systemOrange)
        case .yellow: return Color(nsColor: .systemYellow)
        case .green: return Color(nsColor: .systemGreen)
        case .graphite: return Color(nsColor: .systemGray)
        }
    }
}

// MARK: - The icon, in the window

/// How a focused thing is marked, now the icon's o is an eye: the ring as before; the icon's dot
/// (on the selected card, and on today in the calendar); or the o itself, a thick rounded ring.
enum FocusMark: String, CaseIterable {
    case ring, dot, eye
    var title: String {
        switch self {
        case .ring: return "Ring (as now)"
        case .dot: return "The dot"
        case .eye: return "The o's thick ring"
        }
    }
}

/// You at the top right: your initial in a circle with the credits as an arc (as now); or in the
/// icon's rounded square, the credits running round it as the o's ring.
enum AvatarStyle: String, CaseIterable {
    case circle, eye
    var title: String { self == .circle ? "Circle and arc (as now)" : "The o: rounded square and ring" }
}

/// The window's type: SF Pro, or SF Pro Rounded, nearer the icon's round letters.
enum TitleDesign: String, CaseIterable {
    case standard, rounded
    var title: String { self == .standard ? "SF Pro" : "SF Pro Rounded" }
    var design: Font.Design { self == .standard ? .default : .rounded }
}

/// The app icon in the Dock, from the variants `scripts/fovea-icon.swift` draws.
enum IconVariant: String, CaseIterable {
    /// The pressed loop (Oct 13): the app's icon. The flat yellow loop (Oct 10), Ryan's serif f
    /// (Oct 6) and the geometric fo before it stay below, to compare.
    case pressed, loop, serif, serifDark, balanced, asDrawn, looking, round, dark
    var title: String {
        switch self {
        case .pressed: return "Pressed loop (the app's icon)"
        case .loop: return "Highlighter loop, yellow"
        case .serif: return "Serif f"
        case .serifDark: return "Serif f, dark"
        case .balanced: return "Geometric fo"
        case .asDrawn: return "Geometric fo, as drawn"
        case .looking: return "Geometric fo, looking"
        case .round: return "Geometric fo, round o"
        case .dark: return "Geometric fo, dark"
        }
    }
    var file: String {
        switch self {
        case .pressed: return "Brand/Variants/icon-pressed-light.png"
        case .loop: return "Brand/Variants/icon-loop-light.png"
        case .serif: return "Brand/Variants/icon-serif-light.png"
        case .serifDark: return "Brand/Variants/icon-serif-dark.png"
        case .balanced: return "Brand/Variants/icon-balanced-light.png"
        case .asDrawn: return "Brand/Variants/icon-as-drawn-light.png"
        case .looking: return "Brand/Variants/icon-looking-light.png"
        case .round: return "Brand/Variants/icon-round-light.png"
        case .dark: return "Brand/Variants/icon-balanced-dark.png"
        }
    }
}

/// A picture opened large from the expanded card (row 28).
struct Viewing: Equatable {
    let capture: String
    let index: Int
}

enum Appearance: String, CaseIterable {
    case system, light, dark
    var title: String { rawValue.capitalized }
}

enum SettingsPane: String, CaseIterable {
    case account, plan, voice, shortcuts, connectors, eyeTracking
    var title: String {
        switch self {
        case .account: return L("Account")
        case .plan: return L("Plan")
        case .voice: return L("Voice & Capture")
        case .shortcuts: return L("Shortcuts")
        case .connectors: return L("Connectors")
        case .eyeTracking: return L("Eye Tracking")
        }
    }
    var symbol: String {
        switch self {
        case .account: return "person.crop.circle"
        case .plan: return "creditcard"
        case .voice: return "waveform"
        case .shortcuts: return "keyboard"
        case .connectors: return "point.3.connected.trianglepath.dotted"
        case .eyeTracking: return "eye"
        }
    }
}

/// Fovea's plans, as the prototype has them. The names, prices and limits are placeholders to
/// confirm; nothing is charged or changed anywhere but here.
enum Plan: String, CaseIterable, Comparable {
    case free, pro, max

    var title: String {
        switch self {
        case .free: return L("Free")
        case .pro: return L("Pro")
        // Oct 18, Ryan: "Max" alone is also a level of thinking (最高), so the plan has a key of its own.
        case .max: return L("Max (plan)", english: "Max")
        }
    }

    /// The line under its name: who it's for.
    var line: String {
        switch self {
        case .free: return L("For speaking instead of typing.")
        case .pro: return L("For pointing at things and sending them on.")
        case .max: return L("For handing work to agents all day.")
        }
    }

    var credits: Int {
        switch self {
        case .free: return 300
        case .pro: return 5_000
        case .max: return 20_000
        }
    }

    /// Dollars a month, or a year.
    func price(yearly: Bool) -> Int {
        switch self {
        case .free: return 0
        case .pro: return yearly ? 120 : 12
        case .max: return yearly ? 300 : 30
        }
    }

    var includes: [String] {
        let n = self.credits.formatted()
        let credits = L("\(n) credits a month")
        switch self {
        case .free: return [L("Dictation, as much as you like"), credits, L("History for 30 days")]
        case .pro: return [L("Dictation, as much as you like"), credits, L("History kept for good")]
        case .max: return [L("Dictation, as much as you like"), credits, L("History kept for good"), L("Eye tracking first")]
        }
    }

    static func < (a: Plan, b: Plan) -> Bool { allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)! }
}

enum DictionaryTab: String, CaseIterable {
    case all, learned, added
    var title: String {
        switch self { case .all: return L("All"); case .learned: return L("Learned"); case .added: return L("Added by you") }
    }
}

@MainActor @Observable
final class CapturesModel {
    var fixture: FixtureSet = .typical
    var library: Library = Fixtures.library(.empty) { didSet { refresh(); onLibraryEdited?() } }
    /// The captures or the dictionary changed here (a deletion, a tag, a word): the window's
    /// controller writes them to the stores.
    @ObservationIgnored var onLibraryEdited: (() -> Void)?
    /// A setting changed here: the controller writes it to the prefs the island reads.
    @ObservationIgnored var onPrefsEdited: (() -> Void)?
    /// Where the pictures taken with captures are kept (`art = "media:…"`).
    @ObservationIgnored var media: MediaStore?

    // What's on screen.
    var page: Page = .captures
    /// Which way the last page change went, so the pages slide the right way.
    var pageForward = true
    var settingsPane: SettingsPane = .account
    var query = CaptureQuery() { didSet { if query != oldValue { refresh() } } }
    /// The day open in the archive (its first moment), on the day page or in place.
    var archiveDay: Date?

    /// The expanded card: which capture, and how far it has grown from its card (0 at the card,
    /// 1 open). The overlay stays while `detailID` is set, so the way back can run to 0.
    var detailID: String?
    var detailProgress: CGFloat = 0
    var detailClosing = false
    /// Opened, waiting for the expanded card to measure itself before it grows.
    @ObservationIgnored var detailPending = false
    /// The capture whose card to grow from and shrink back into (stepping changes it).
    var detailSourceID: String?
    /// Where each card sits in the window, for the expanded card to grow out of.
    @ObservationIgnored var cardFrames: [String: CGRect] = [:]
    /// Asks the grid to bring a card into view (stepping in the expanded card).
    var scrollTarget: String?
    /// The library's list: the row to bring into view.
    var listScrollTarget: String?
    /// The capture open in the library's page, as a note.
    var noteID: String?
    /// The year the first page's calendar shows.
    var calendarYear: Int = Lines.calendar.component(.year, from: Date())
    /// The month the library's calendar shows (its first day).
    var calendarMonth: Date = Lines.calendar.date(from: Lines.calendar.dateComponents([.year, .month], from: Date()))!
    /// The card the keyboard is on (arrows move it, Space or Return opens it), ringed as Finder
    /// and Paste ring a selected item.
    var selectedID: String?
    /// The grid's width, for how many cards fit a row (up and down move by a row).
    @ObservationIgnored var gridWidth: CGFloat = 1100 {
        didSet {
            let compact = gridWidth < T.Layout.compactWidth
            if compact != compactToolbar { compactToolbar = compact }
            let fit: ToolbarFit = gridWidth >= 1100 ? .roomy : (gridWidth >= 900 ? .natural : .tight)
            if fit != toolbarFit { toolbarFit = fit }
        }
    }
    /// A narrow window: search opens shorter, so the type control keeps the toolbar's center.
    var compactToolbar = false
    /// How much room the toolbar's center has for Settings' six tabs (watched, so they re-lay
    /// out when the window crosses a step, not on every point of a resize).
    var toolbarFit: ToolbarFit = .roomy

    /// Settings' values (the prototype's own, in memory; nothing reaches the system).
    var prefs = Prefs() { didSet { onPrefsEdited?() } }
    /// Your plan, and a smaller one waiting for this month's credits to reset (a move down
    /// takes effect then; a move up, at once). Simulated.
    var plan: Plan = .pro
    var nextPlan: Plan?
    var yearlyBilling = false

    /// This month's credits, on the plan you're on.
    var usage: Usage {
        var u = library.usage
        u.plan = plan.title
        u.total = plan.credits
        // The States menu's plan alerts (row 13).
        switch planAlert {
        case .usedUp: u.used = u.total
        case .almostOut: u.used = Int(Double(u.total) * 0.93)
        // Paying for Pro from Free, a little of Free used (as in the Mac app's own picture).
        case .paymentProcessing: u.used = Int(Double(u.total) * 0.12)
        // Oct 15 review, AC-02.1: a week into the trial; just moved to Free.
        case .trial: u.used = Int(Double(u.total) * 0.31)
        case .trialEnded, .expired: u.used = Int(Double(u.total) * 0.08)
        case .subscriptionEnding, .paymentFailed, .billingUnavailable, nil: break
        }
        return u
    }

    /// Moves to a plan: up at once, down when the credits reset; your own plan again cancels a
    /// move down.
    func choose(_ next: Plan) {
        if next == plan {
            animate(.swap) { nextPlan = nil }
            say(L("You're staying on \(plan.title)"))
        } else if next > plan {
            animate(.swap) { plan = next; nextPlan = nil }
            say(L("You're on \(next.title) (simulated: nothing was charged)"))
        } else {
            animate(.swap) { nextPlan = next }
            say(L("\(next.title) starts \(Lines.day(usage.resets)) (simulated)"))
        }
    }

    var usageShown = false
    /// Edit › Find asks the toolbar's search to open and take the keyboard.
    var searchRequest = 0
    var dictionaryTab: DictionaryTab = .all
    var wordShown: String?
    var lastForgotten: (memory: Memory, index: Int)?
    /// The capture deleted last, and where it was, until Undo or the toast leaves.
    var lastDeleted: (capture: Capture, index: Int)?
    var toast: String?
    /// The id of the capture just copied, for the Copy button's checkmark.
    var copiedID: String?
    /// A picture open large over the window (row 28).
    var viewing: Viewing?
    /// Failed recordings being transcribed again.
    var transcribing: Set<String> = []

    // The App UI review (Oct 6): you, support, updates, and the states the window draws.
    /// Your name and photo (row 8): yours to change; the email comes from how you signed in.
    var profileName = "" { didSet { if profileName != oldValue { onPrefsEdited?() } } }
    /// The email you signed in with (the first run).
    var profileEmail = ""
    /// The name Home greets you by.
    var greetingName: String { profileName.trimmingCharacters(in: .whitespaces) }
    /// The first run was put away part way (Exit tour, Oct 10): Home offers to finish it.
    var tourUnfinished = false
    @ObservationIgnored var onResumeTour: (() -> Void)?
    var profilePhoto: NSImage?
    /// A photo over 2 MB was chosen: said under it for a moment.
    var photoTooLarge = false
    /// The Report a Problem sheet (row 9), from Account or the Help menu.
    var reporting = false
    var update: UpdateState = .upToDate
    /// Simulated from the States menu (row 13): a plan alert, a window that can't open its data,
    /// Memory that hasn't loaded, being signed out.
    var planAlert: PlanAlert?
    var windowError: WindowError?
    var memoryState: LoadState = .loaded
    var signedOut = false
    @ObservationIgnored var onSignedOut: (() -> Void)?
    /// The memory browser (row 24): open, its filter, what's selected; the memories deleted last,
    /// for Undo.
    var browsingMemories = false
    var memoryFilter: MemoryFilter = .recent
    var memorySelection: Set<String> = []
    var lastDeletedMemories: [String] = []
    var accessLogShown = false
    /// Oct 15 review: the rebuilt Settings panes' own state (SettingsPanesState.swift).
    let panes = PanesState()
    /// The harness's stand-in for the pointer.
    var hoverKey: String?

    // MARK: Oct 15 review: Home's and Account's new states (docs/v1/REVIEW_2026-10-15.md)

    /// MW-02a: the session the window opens with; nothing of the captures shows until it's ready.
    var session: SessionState = .ready
    /// HI-01.6: Home's captures loading, or failed to load.
    var capturesLoad: LoadState = .loaded
    /// MW-05.1 (the empty Home) and Getting Started: the keys each shortcut answers to now, by
    /// `FoveaShortcut.id` (`FoveaKeys.chord`, from the prefs the controller reads).
    var shortcutKeys: [String: [String]] = [:]
    /// RC-01, RC-02: captures from an earlier version or account (simulated; a stage adds them).
    var earlierData: [EarlierData] = []
    /// AC-01.4, AC-01.5: signing in, while the sheet is up.
    var signIn: SignInFlow?
    /// ST-02.4: your name couldn't be saved (staged: 1.0 saves it on this Mac).
    var nameSaveFailed = false
    /// IS04: a save that failed, shown as an alert.
    var saveFailure: SaveFailure?
    /// OB-02: "What Fovea remembers", shown once in Home.
    var memoryDisclosureShown = false
    /// ST-10.3: Get Beta Updates is being turned off, waiting on "Leave the Beta?".
    var leavingBeta = false
    /// MW-04c: Report a Problem's sending fails (staged; 1.0 has no server to send to).
    var reportFails = false
    /// MW-05.1's review stage: Home drawn empty without touching the captures.
    var stagedEmpty = false
    /// VF13: failed recordings wait here instead of being tried again (a review stage holds them).
    var holdRetries = false
    /// MW-04d: Refresh, asking whether a payment went through.
    var refreshingPayment = false
    /// Getting Started's permissions are read again when this changes (the window became key).
    var permissionsChecked = Date()
    /// Captures a review stage put in: shown, never written to the store.
    @ObservationIgnored var stagedIDs: Set<String> = []
    /// Failed recordings already waiting to be tried again.
    @ObservationIgnored var retryScheduled: Set<String> = []
    /// The diagnostics' data folder, for Open Diagnostics (MW-02b).
    @ObservationIgnored var dataFolder: URL?

    // Hooks the app wires (the report's "Wiring needed").
    /// OB-03.1: Getting Started's Replay the Tour.
    @ObservationIgnored var onReplayTour: (() -> Void)?
    /// OB-03.1: Practise Again, with the first run's step ("weeklyUpdate", "packList", "followUp",
    /// "dictation").
    @ObservationIgnored var onPractice: ((String) -> Void)?
    /// HI-01.3, QA25: an expanded Dispatch card's Open in Notch, and a failed one's Send Again.
    @ObservationIgnored var onOpenInNotch: ((String) -> Void)?
    @ObservationIgnored var onSendAgain: ((String) -> Void)?
    /// A change to the prefs the window keeps only in FoveaPrefs (signed in, the disclosure read).
    @ObservationIgnored var onAccountEdited: ((_ email: String, _ provider: AccountProvider) -> Void)?
    @ObservationIgnored var onMemoryDisclosureRead: (() -> Void)?

    // The design, settled (Ryan's choices on the control panel, since removed). The other
    // values of each are kept for the snapshot harness's comparison shots.
    var surface: Surface = .system
    var headerStyle: HeaderStyle = .themeAndType
    var cardSize: CardSize = .medium
    // Ryan's panel: less in each card, the year graph above the cards.
    var cardSpacing: CardSpacing = .quiet
    var iconStyle: IconStyle = .small
    var detailIcon = false
    var cardAttachments: CardAttachments = .inlineAndPreview
    var detailStyle: DetailStyle = .quickLook
    var attachmentMotion: AttachmentMotion = .fly
    var hitStyle: HitStyle = .highlight
    var settingsLayout: SettingsLayout = .sidebarPanes
    var settingsArrangement: SettingsArrangement = .beside
    /// The sidebar's section: the one the page is on, or the one clicked.
    var settingsCategory: SettingsCategory = .account
    /// A click in the sidebar, for the page to scroll to (counted, so the same one twice still
    /// scrolls).
    var settingsScroll: (category: SettingsCategory, count: Int)?
    // Ryan's variants for fitting the window to the new icon (the Variants menu).
    var focusMark: FocusMark = .ring
    var avatarStyle: AvatarStyle = .circle
    var titleDesign: TitleDesign = .standard
    var iconVariant: IconVariant = .pressed
    var historyStyle: HistoryStyle = .yearGraphTop
    var archiveStyle: ArchiveStyle = .page
    var layout: LayoutStyle = .cards
    var pageStyle: PageStyle = .inset
    var windowMaterial: WindowMaterialStyle = .vibrant
    var liquidGlass = true
    var pageIsland: PageIslandStyle = .glass
    /// ⌥⌘F shows and hides the window from any app (Aside's ⌥⌘A). Off unless turned on: while
    /// it's on, other apps don't get ⌥⌘F.
    var summon = false
    var appearance: Appearance = .light
    /// The accent the person chose in Settings › Appearance (Multicolor: the theme's own).
    var accent: AccentChoice = .multicolor { didSet { if accent != oldValue { onPrefsEdited?() } } }
    var speed: Double = 1
    var reduceMotion = false

    init() { refresh() }

    @ObservationIgnored var play: Task<Void, Never>?
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    // Oct 15 review, IS02: Appearance › Motion decides; Match the Mac follows Reduce Motion.
    var motion: MotionSpec { MotionSpec(speed: speed, reduce: Self.reduces(prefs.motion, harness: reduceMotion)) }
    var now: Date { library.now }

    func load(_ set: FixtureSet) {
        fixture = set
        library = Fixtures.library(set)
        calendarYear = Lines.calendar.component(.year, from: library.now)
        archiveDay = nil
        noteID = nil
        detailID = nil
        detailSourceID = nil
        detailProgress = 0
        lastForgotten = nil
        lastDeleted = nil
    }

    // MARK: What's shown (searched once per change, not once per card)

    /// The cards: what the query matches within the first page's period, newest first.
    private(set) var matches: [CaptureMatch] = []
    /// Matches per day, whenever they were, for the calendar: every filter applies but the
    /// period, so the calendar is where anything older is found.
    private(set) var dayCounts: [Date: Int] = [:]
    private(set) var levels = History.Levels([])
    /// The years there are captures in, newest first: the calendar's tabs.
    private(set) var years: [Int] = []
    @ObservationIgnored private var matchIndex: [String: CaptureMatch] = [:]
    @ObservationIgnored private var byDay: [Date: [CaptureMatch]] = [:]

    func refresh() {
        let cal = Lines.calendar
        var anyTime = query
        anyTime.date = nil
        let all = CaptureSearch.search(anyTime, in: library.captures, now: library.now, calendar: cal)
        let scope = self.scope
        matches = all.filter { CaptureSearch.within(scope, $0.capture.time, now: library.now, calendar: cal) }
        matchIndex = Dictionary(all.map { ($0.capture.id, $0) }, uniquingKeysWith: { a, _ in a })
        byDay = Dictionary(grouping: all) { cal.startOfDay(for: $0.capture.time) }
        dayCounts = byDay.mapValues(\.count)
        levels = History.Levels(Array(dayCounts.values))
        years = History.years(library.captures, now: library.now, calendar: cal)
        // Oct 15 review, MW-05.3: each Dispatch session's requests; VF13: failed recordings retried.
        requestCounts = Self.sessions(library.captures)
        scheduleRetries()
    }

    /// Oct 15 review, MW-05.3: how many requests each Dispatch session has had, by its agent and
    /// chat ("New chat" is every new one's name until it has its own, so it counts once).
    private(set) var requestCounts: [String: Int] = [:]

    static func sessionKey(_ d: Destination) -> String { "\(d.agent)\u{1F}\(d.chat)" }

    static func sessions(_ captures: [Capture]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for c in captures where c.kind == .dispatch {
            guard let d = c.destination, d.chat != "New chat" else { continue }
            counts[sessionKey(d), default: 0] += 1
        }
        return counts
    }

    /// The requests in this capture's Dispatch session: those Home has, or its turn if later.
    func requests(_ c: Capture) -> Int {
        guard c.kind == .dispatch, let d = c.destination else { return 1 }
        return max(d.turn, requestCounts[Self.sessionKey(d)] ?? 1)
    }

    /// What the first page's cards cover: the last three days (when no period is picked), or
    /// today. Never more: any other day is the calendar's, above them (Ryan, Oct 7: a week of
    /// cards was too much).
    var scope: CaptureQuery.DateFilter { query.date ?? .threeDays }

    /// Words or an app picked: the cards are matches, and the calendar marks where the rest are.
    var filtering: Bool { !query.text.isEmpty || query.app != nil || query.tag != nil }

    /// One day's cards, newest first.
    func matches(on day: Date) -> [CaptureMatch] { byDay[Lines.calendar.startOfDay(for: day)] ?? [] }

    /// What the keyboard and the expanded card's ‹ › step through: the cards on screen.
    var visible: [CaptureMatch] {
        if page == .day, let day = archiveDay { return matches(on: day) }
        if archiveStyle == .inline, let day = archiveDay { return matches + matches(on: day) }
        return matches
    }

    var detail: Capture? { detailID.flatMap { id in matchIndex[id]?.capture ?? library.captures.first { $0.id == id } } }

    var note: Capture? { noteID.flatMap { id in matchIndex[id]?.capture ?? library.captures.first { $0.id == id } } }

    func match(for capture: Capture) -> CaptureMatch {
        matchIndex[capture.id] ?? CaptureMatch(capture: capture, ranges: [:])
    }

    // MARK: Days

    /// Opens a day from the calendar: its own page, or in place (a second click closes it).
    func openDay(_ day: Date) {
        let d = Lines.calendar.startOfDay(for: day)
        if layout == .library {
            listScrollTarget = matches(on: d).isEmpty ? nil : LibraryIDs.day(d)
            // The calendar shows the month of the day opened.
            calendarMonth = Lines.calendar.date(from: Lines.calendar.dateComponents([.year, .month], from: d))!
            cut { noteID = nil; archiveDay = d }
            if page == .day { cut { scrollTarget = "top" } } else { show(.day) }
            return
        }
        // The calendar turns to the year of the day opened.
        calendarYear = Lines.calendar.component(.year, from: d)
        if archiveStyle == .inline && page == .captures {
            animate(.swap) { archiveDay = archiveDay == d ? nil : d }
            return
        }
        cut { archiveDay = d }
        show(.day)
    }

    /// The busiest day between `from` and `to` days ago (for the shots).
    func busiestDay(daysAgo range: ClosedRange<Int>) -> Date {
        let cal = Lines.calendar
        let today = cal.startOfDay(for: now)
        let days = range.map { cal.date(byAdding: .day, value: -$0, to: today)! }
        return days.max { (dayCounts[$0] ?? 0) < (dayCounts[$1] ?? 0) } ?? today
    }

    /// The day with captures before or after the open one.
    func neighborDay(_ delta: Int) -> Date? {
        guard let day = archiveDay else { return nil }
        let days = dayCounts.filter { $0.value > 0 }.keys.sorted()
        if delta < 0 { return days.last { $0 < day } }
        return days.first { $0 > day && $0 <= Lines.calendar.startOfDay(for: now) }
    }

    func stepDay(_ delta: Int) {
        guard let d = neighborDay(delta) else { return }
        cut { archiveDay = d; selectedID = nil }
        if page == .day { scrollTarget = "top" }
    }

    func animate(_ role: MotionSpec.Role, _ body: () -> Void) { withAnimation(motion.animation(role), body) }

    func cut(_ body: () -> Void) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t, body)
    }

    // MARK: The expanded card

    /// Grows the card into the expanded card. The overlay first appears exactly over the card
    /// (progress 0, drawn as the card); once it has measured its content it calls `grow()`.
    /// In the library, the capture opens in the page instead, as a note.
    func open(_ id: String) {
        if layout == .library { openNote(id); return }
        play?.cancel()
        cut {
            selectedID = id
            detailID = id
            detailSourceID = id
            detailClosing = false
            detailProgress = 0
            detailPending = true
            usageShown = false
        }
        Task { @MainActor in
            // In case the measurement never reports (it always should).
            try? await Task.sleep(for: .milliseconds(120))
            if self.detailID == id { self.grow() }
        }
    }

    /// Starts the growth, once.
    func grow() {
        guard detailPending, detailID != nil, !detailClosing else { return }
        detailPending = false
        withAnimation(motion.animation(.open)) { detailProgress = 1 }
    }

    /// Shrinks the expanded card back into its card, then takes the overlay away in the same
    /// frame the card shows again.
    /// Closes the expanded card at once (Ryan, Oct 7): shrinking back into its place in the grid
    /// took the whole window through grey on the way, so closing has no animation now. Opening
    /// still grows from the card.
    func closeDetail() {
        guard detailID != nil else { return }
        cut {
            detailPending = false
            detailProgress = 0
            // The keyboard picks up where the expanded card left off.
            selectedID = detailSourceID ?? selectedID
            detailID = nil
            detailSourceID = nil
            detailClosing = false
        }
    }

    /// The next or previous capture in what's shown; the grid scrolls so the way back lands on it.
    func step(_ delta: Int) {
        let ids = visible.map(\.capture.id)
        guard let id = detailID, !detailClosing, let i = ids.firstIndex(of: id), ids.indices.contains(i + delta) else { return }
        let next = ids[i + delta]
        scrollTarget = next
        // A keyboard step switches at once (Emil Kowalski: don't animate what people repeat).
        cut {
            detailID = next
            detailSourceID = next
        }
    }

    var columns: Int { GridLayout(width: gridWidth, side: cardSize.width, gap: cardSpacing.gridGap(surface)).columns }

    /// Moves the keyboard's card through what's shown; at once, never animated.
    func moveSelection(_ delta: Int) {
        let ids = visible.map(\.capture.id)
        guard !ids.isEmpty else { return }
        guard let id = selectedID, let i = ids.firstIndex(of: id) else {
            selectedID = delta < 0 ? ids.last : ids.first
            return
        }
        let j = min(ids.count - 1, max(0, i + delta))
        selectedID = ids[j]
        scrollTarget = ids[j]
    }

    func canStep(_ delta: Int) -> Bool {
        let ids = visible.map(\.capture.id)
        guard let id = detailID, let i = ids.firstIndex(of: id) else { return false }
        return ids.indices.contains(i + delta)
    }

    // MARK: The library

    /// Opens a capture in the page, as a note, and selects its row in the list.
    func openNote(_ id: String) {
        play?.cancel()
        if page == .settings { cut { page = .captures } }
        listScrollTarget = id
        animate(.swap) {
            selectedID = id
            noteID = id
            usageShown = false
        }
    }

    /// Back from the note to what the page showed before it (this week, or a day).
    func closeNote() {
        guard noteID != nil else { return }
        animate(.swap) { noteID = nil }
    }

    /// The library's list, in order: every match, newest first.
    var listed: [CaptureMatch] { matches }

    /// ↑ ↓ in the list: the note follows the selection, at once (a keyboard step isn't animated).
    func moveNote(_ delta: Int) {
        let ids = listed.map(\.capture.id)
        guard !ids.isEmpty else { return }
        let current = noteID ?? selectedID
        let next: String
        if let current, let i = ids.firstIndex(of: current) {
            next = ids[min(ids.count - 1, max(0, i + delta))]
        } else {
            next = delta < 0 ? ids.last! : ids.first!
        }
        if page == .settings { cut { page = .captures } }
        listScrollTarget = next
        cut { selectedID = next; noteID = next }
    }

    /// The calendar's month, a month earlier or later (never past this one).
    func stepMonth(_ delta: Int) {
        let cal = Lines.calendar
        guard let m = cal.date(byAdding: .month, value: delta, to: calendarMonth) else { return }
        let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        guard m <= thisMonth else { return }
        animate(.swap) { calendarMonth = m }
    }

    var canStepMonthForward: Bool {
        let cal = Lines.calendar
        let thisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        return calendarMonth < thisMonth
    }

    // MARK: Pages

    func setKind(_ kind: CaptureKind?) {
        guard query.kind != kind else { return }
        animate(.swap) { query.kind = kind }
    }

    func show(_ page: Page, pane: SettingsPane? = nil) {
        if let pane, page == .settings {
            settingsPane = pane
            settingsCategory = SettingsCategory.allCases.first { $0.pane == pane } ?? .account
            settingsScroll = (settingsCategory, (settingsScroll?.count ?? 0) + 1)
        }
        guard self.page != page else { return }
        if page == .settings { cameFromDay = self.page == .day }
        usageShown = false
        cut {
            pageForward = page.depth >= self.page.depth
            detailID = nil
            detailSourceID = nil
            detailProgress = 0
            if page != .captures { noteID = nil }
        }
        animate(.page) { self.page = page }
    }

    func back() {
        if noteID != nil, page != .settings { closeNote(); return }
        if page == .settings, archiveDay != nil, archiveStyle == .page, cameFromDay { show(.day); return }
        show(.captures)
    }
    /// Settings opened from a day's page goes back to that day.
    @ObservationIgnored var cameFromDay = false

    /// The profile icon: Settings, opened on Account; again, back to the captures.
    func profile() {
        if page == .settings && (settingsLayout.hasSidebar || settingsPane == .account) { back() } else { show(.settings, pane: .account) }
    }

    /// A section picked in the Settings sidebar: the page scrolls to it (or, one section at a
    /// time, shows it).
    func pickSettings(_ category: SettingsCategory) {
        settingsPane = category.pane
        if settingsLayout == .sidebarPanes {
            animate(.swap) { settingsCategory = category }
        } else {
            settingsCategory = category
            settingsScroll = (category, (settingsScroll?.count ?? 0) + 1)
        }
    }

    /// The Gaze Collector's download, simulated: nothing is fetched.
    func downloadCollector() {
        guard case .idle = prefs.gaze else { return }
        withAnimation(motion.animation(.swap)) { prefs.gaze = .downloading(0) }
        play = Task { @MainActor in
            for step in 1...24 {
                try? await Task.sleep(for: .seconds(motion.seconds(0.09)))
                guard !Task.isCancelled, case .downloading = prefs.gaze else { return }
                prefs.gaze = .downloading(Double(step) / 24)
            }
            withAnimation(motion.animation(.swap)) { prefs.gaze = .downloaded }
        }
    }

    func cancelCollector() {
        play?.cancel()
        withAnimation(motion.animation(.swap)) { prefs.gaze = .idle }
    }

    // MARK: Actions

    /// One Copy (row 28): the words, then what you took. An app that takes only text pastes the
    /// words; one that takes pictures gets those too.
    func copy(_ capture: Capture) {
        var items: [NSPasteboardWriting] = [capture.text as NSString]
        for a in capture.attachments {
            switch a.kind {
            case .region: if let image = Art.region(a) { items.append(image) }
            case .passage: items.append(a.text as NSString)
            case .file: break
            }
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(items)
        cut { copiedID = capture.id }
        let id = capture.id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            if self.copiedID == id { withAnimation(self.motion.animation(.content)) { self.copiedID = nil } }
        }
    }

    /// Deleted at once, with Undo in the toast (and ⌘Z) while it shows; no confirmation.
    func delete(_ id: String) {
        guard let i = library.captures.firstIndex(where: { $0.id == id }) else { return }
        let capture = library.captures[i]
        if detailID == id {
            // The card it would shrink into is going away: fade the expanded card where it is.
            cut { detailClosing = true; detailSourceID = nil }
            withAnimation(motion.animation(.close), completionCriteria: .logicallyComplete) {
                detailProgress = 0
            } completion: { [weak self] in
                guard let self else { return }
                self.cut { self.detailID = nil; self.detailClosing = false }
                self.animate(.swap) { self.library.captures.removeAll { $0.id == id } }
            }
        } else {
            animate(.swap) { library.captures.removeAll { $0.id == id } }
        }
        if noteID == id {
            // The next one down takes its place, as Mail's list does.
            let ids = listed.map(\.capture.id)
            let next = ids.firstIndex(of: id).flatMap { j in ids.indices.contains(j + 1) ? ids[j + 1] : (j > 0 ? ids[j - 1] : nil) }
            animate(.swap) { noteID = next; selectedID = next }
        }
        lastDeleted = (capture, i)
        say(capture.kind == .dictation ? L("Deleted the dictation") : L("Deleted the dispatch"), undo: true)
    }

    func undoDelete() {
        if !lastDeletedMemories.isEmpty { undoMemoryDelete(); return }
        guard let d = lastDeleted else { return }
        lastDeleted = nil
        animate(.swap) { library.captures.insert(d.capture, at: min(d.index, library.captures.count)) }
        withAnimation(motion.animation(.content)) { toast = nil }
    }

    // Oct 15 review, IS04: Save writes real files (`saveToDisk`, Saving.swift); VF11 and QA19:
    // there's no recording to save.

    /// Oct 15 review, VF13 (Ryan: "recordings are only saved for failed cases, and then it will
    /// automatically try to re-transcribe; no audio will be seen by the users"): a recording whose
    /// words didn't come back is tried again on its own a moment after it shows, and its words take
    /// its place when they're back. Nothing to press. Simulated: 1.0 transcribes on this Mac as you
    /// speak, so a retry brings back only the words a review stage left for it (`recovered`).
    func scheduleRetries() {
        guard !holdRetries else { return }
        for c in library.captures where c.failed && !retryScheduled.contains(c.id) {
            retryScheduled.insert(c.id)
            let id = c.id
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(self.motion.seconds(T.Simulated.retryWait)))
                self.retryTranscription(id)
            }
        }
    }

    /// One more try at a recording's words: "Trying again…" on its card, then its words.
    func retryTranscription(_ id: String) {
        guard !holdRetries, !transcribing.contains(id), library.captures.contains(where: { $0.id == id && $0.failed }) else {
            retryScheduled.remove(id)
            return
        }
        cut { transcribing.insert(id) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(self.motion.seconds(T.Simulated.retranscribing)))
            guard let i = self.library.captures.firstIndex(where: { $0.id == id }) else { return }
            self.animate(.swap) {
                self.transcribing.remove(id)
                if let back = Self.recovered[id] {
                    self.library.captures[i].text = back.text
                    self.library.captures[i].theme = back.theme
                    self.library.captures[i].tags = back.tags
                    self.library.captures[i].failure = nil
                }
            }
            // Still not back: it stays "trying again" until Fovea opens next.
        }
    }

    /// What the two failed recordings said, for when they're tried again.
    static let recovered: [String: (text: String, theme: String, tags: [String])] = [
        "d-failed-notes": ("Errands for tonight: pick up the dry cleaning before six, and call the landlord about the heater on the second floor, because it's been clicking all week. Then send Lin the notch study before Thursday's review, with the two island materials side by side and a line on which one I'd pick, so she isn't seeing them cold in the room.", "Errands and the notch study", ["Errands", "Design review"]),
        // Oct 15 review, VF13: the review stage's recording, whose words come back.
        "review-failed-notes": ("Errands for tonight: pick up the dry cleaning before six, and call the landlord about the heater on the second floor, because it's been clicking all week. Then send Lin the notch study before Thursday's review, with the two island materials side by side and a line on which one I'd pick, so she isn't seeing them cold in the room.", "Errands and the notch study", ["Errands", "Design review"]),
        "d-failed-mail": ("Hi Mei, thanks for sending the interview recordings. I listened to the first three last night, and the part where people point at their screen and say this one keeps coming up, so I think we're onto something. Could you send the other two by Friday? I'd also love your notes on who seemed most excited, since I want to invite those people first.", "Interview recordings", ["Interviews"]),
    ]

    func addTag(_ text: String, to id: String) {
        let tag = text.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, let i = library.captures.firstIndex(where: { $0.id == id }),
              !library.captures[i].tags.contains(tag) else { return }
        animate(.swap) { library.captures[i].tags.append(tag) }
    }

    func removeTag(_ tag: String, from id: String) {
        guard let i = library.captures.firstIndex(where: { $0.id == id }) else { return }
        animate(.swap) { library.captures[i].tags.removeAll { $0 == tag } }
    }

    /// Shows the captures with one tag (from a tag on a card, or one of Memory's).
    func show(tag: String) {
        if detailID != nil { closeDetail() }
        if page != .captures { back() }
        animate(.swap) { query.tag = tag }
    }

    func view(_ captureID: String, _ index: Int) {
        animate(.open) { viewing = Viewing(capture: captureID, index: index) }
    }

    /// Closed at once, as the expanded card is (Oct 7): fading out took the window through grey.
    func closeViewer() { cut { viewing = nil } }

    /// A short line at the window's foot, for a moment (longer when it offers Undo).
    func say(_ message: String, undo: Bool = false) {
        toastTask?.cancel()
        withAnimation(motion.animation(.open)) { toast = message }
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(undo ? 5 : 1.8))
            guard !Task.isCancelled, self.toast == message else { return }
            withAnimation(self.motion.animation(.close)) { self.toast = nil }
            if undo { self.lastDeleted = nil; self.lastDeletedMemories = [] }
        }
    }

    // MARK: Memory and dictionary

    func forget(_ id: String) {
        cut {
            settleForgotten()
            if let j = library.memories.firstIndex(where: { $0.id == id }) { lastForgotten = (library.memories[j], j) }
        }
    }

    func undoForget() { cut { lastForgotten = nil } }

    func settleForgotten() {
        guard let f = lastForgotten else { return }
        library.memories.removeAll { $0.id == f.memory.id }
        lastForgotten = nil
    }

    func removeWord(_ id: String) {
        animate(.swap) {
            library.dictionary.removeAll { $0.id == id }
            wordShown = nil
        }
    }

    func addWord(_ text: String) {
        let word = text.trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty, !library.dictionary.contains(where: { $0.word == word }) else { return }
        animate(.swap) {
            library.dictionary.insert(DictionaryWord(id: "w-\(UUID().uuidString.prefix(6))", word: word, source: .added, date: now), at: 0)
        }
    }
}

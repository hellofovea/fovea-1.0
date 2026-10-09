import Foundation

// Every open design decision, as one enum each. The first case is the default. The control
// panel, the saved state and the smoke run's cycling all come from `Variants.all`, so adding a
// decision is adding an enum here and reading it where it's drawn.

public enum BenchPage: String, CaseIterable, Codable, Hashable, Sendable {
    case global, onboarding, projects, settings, runDetail, search, captures, polish

    public var title: String {
        switch self {
        case .global: return "Everywhere"
        case .onboarding: return "01 Onboarding"
        case .projects: return "02 Projects"
        case .settings: return "03 Settings"
        case .runDetail: return "04 Run detail"
        case .search: return "05 Search"
        case .captures: return "06 Captures"
        case .polish: return "07 Polish"
        }
    }
}

public struct OptionInfo: Hashable, Sendable {
    public var id: String
    public var title: String
    public var help: String
}

public struct DecisionInfo: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var page: BenchPage
    public var help: String
    public var options: [OptionInfo]
    public var defaultID: String { options[0].id }
}

public protocol Variant: RawRepresentable, CaseIterable, Hashable, Sendable where RawValue == String {
    static var id: String { get }
    static var title: String { get }
    static var page: BenchPage { get }
    static var help: String { get }
    var title: String { get }
    var help: String { get }
}

extension Variant {
    public static var info: DecisionInfo {
        DecisionInfo(id: id, title: title, page: page, help: help,
                     options: allCases.map { OptionInfo(id: $0.rawValue, title: $0.title, help: $0.help) })
    }
    public static var defaultValue: Self { allCases.first! }
}

/// The chosen option of every decision, by id; anything missing reads as its default.
public struct VariantValues: Codable, Hashable, Sendable {
    public var values: [String: String] = [:]
    public init(_ values: [String: String] = [:]) { self.values = values }

    public func get<V: Variant>(_ type: V.Type) -> V {
        values[V.id].flatMap(V.init(rawValue:)) ?? V.defaultValue
    }

    public mutating func set<V: Variant>(_ value: V) { values[V.id] = value.rawValue }

    public subscript(id: String) -> String? {
        get { values[id] }
        set { values[id] = newValue }
    }
}

// MARK: - Everywhere

public enum StateStyle: String, Variant {
    case glyph, wordTint, glyphWord
    public static let id = "stateStyle", title = "State", page = BenchPage.global
    public static let help = "The brief draws state by shape; the notch today writes the word in amber or coral."
    public var title: String {
        switch self { case .glyph: return "Shape glyphs"; case .wordTint: return "Words + tint"; case .glyphWord: return "Glyph + word" }
    }
    public var help: String {
        switch self {
        case .glyph: return "● ! ○ ◌ (nothing) and a dashed circle, never color (brief §2)"
        case .wordTint: return "Needs you in amber, Failed in coral, • Working: the notch's Choose chat rows"
        case .glyphWord: return "The shape and the notch's word, both in ink, no tint"
        }
    }
}

public enum GlyphDrawing: String, Variant {
    case symbols, drawn
    public static let id = "glyphDrawing", title = "Glyphs", page = BenchPage.global
    public static let help = "How the six shapes are drawn."
    public var title: String { self == .symbols ? "SF Symbols" : "Drawn" }
    public var help: String {
        self == .symbols ? "circle.fill · exclamationmark.circle · circle · circle.dotted · circle.dashed (spec v1 §8)"
                         : "A bare ! as the brief writes it; strokes at the notch's 1.6 pt Lasso weight"
    }
}

public enum RunningMark: String, Variant {
    case breathing, still, lasso
    public static let id = "runningMark", title = "Running", page = BenchPage.global
    public static let help = "How running shows without a spinner (motion shortlist 8)."
    public var title: String {
        switch self { case .breathing: return "Breathing ◌"; case .still: return "Still ◌"; case .lasso: return "Lasso" }
    }
    public var help: String {
        switch self {
        case .breathing: return "The dotted circle breathes 1 → 0.45 like Choose chat's routing placeholder"
        case .still: return "A dotted circle that never moves"
        case .lasso: return "The notch's Thinking mark at glyph size: a hand-drawn loop traced and erased"
        }
    }
}

public enum WaitingArrival: String, Variant {
    case bounce, overshoot, none
    public static let id = "waitingArrival", title = "Needs-you arrival", page = BenchPage.global
    public static let help = "The brief keeps bounce for \"waiting for you\"; the notch has none (AMENDMENTS §14)."
    public var title: String {
        switch self { case .bounce: return "Spring bounce"; case .overshoot: return "Capped overshoot"; case .none: return "None" }
    }
    public var help: String {
        switch self {
        case .bounce: return "An interpolating spring with bounce 0.3 on the glyph as the run arrives"
        case .overshoot: return "The notch's card-fan curve, overshoot capped in points (not interruptible)"
        case .none: return "Critically damped, like every other notch spring"
        }
    }
}

public enum FailedPlacementVariant: String, Variant {
    case withStuck, last
    public static let id = "failedPlacement", title = "Failed sits", page = BenchPage.global
    public static let help = "Where a failed project goes in the list."
    public var title: String { self == .withStuck ? "With stuck" : "Last" }
    public var help: String {
        self == .withStuck ? "stuck → to look at → running → earlier (brief §3)" : "After running, as the notch's hover list orders Failed (PRD §4)"
    }
    public var placement: FailedPlacement { self == .withStuck ? .withStuck : .last }
}

public enum GroupLabels: String, Variant {
    case labeled, hairlineOnly
    public static let id = "groupLabels", title = "Group labels", page = BenchPage.global
    public static let help = "The brief asks for hairlines between groups and doesn't say whether groups are named."
    public var title: String { self == .labeled ? "Label + hairline" : "Hairline only" }
    public var help: String { self == .labeled ? "A small section label over each group, Things-style" : "Just the hairline; the glyphs name the group" }
}

public enum SurfaceVariant: String, Variant {
    case system, paper, warm
    public static let id = "surface", title = "Surface", page = BenchPage.global
    public static let help = "The window's paper."
    public var title: String {
        switch self { case .system: return "System"; case .paper: return "Paper"; case .warm: return "Warm" }
    }
    public var help: String {
        switch self {
        case .system: return "macOS's window and text colors, nothing custom"
        case .paper: return "Ink #0C0C0C on canvas #FBFAF7: the shipping Home; in Dark it is the notch's white on black"
        case .warm: return "System colors with spec v1's warm tint behind the content"
        }
    }
}

public enum TypeScale: String, Variant {
    case notch, macOS
    public static let id = "typeScale", title = "Type", page = BenchPage.global
    public static let help = "Row type sizes."
    public var title: String { self == .notch ? "Notch 13.5" : "macOS 13" }
    public var help: String { self == .notch ? "13.5 rows, 11.5 meta: the notch's rows" : "13 body, 11 meta: AppKit's list sizes" }
}

public enum DensityVariant: String, Variant {
    case regular, compact
    public static let id = "density", title = "Density", page = BenchPage.global
    public static let help = "Row heights."
    public var title: String { self == .regular ? "Regular" : "Compact" }
    public var help: String { self == .regular ? "Rows breathe: 44 pt projects, 30 pt runs" : "36 pt projects, 26 pt runs" }
}

public enum BreadcrumbStyle: String, Variant {
    case chevron, pill, largeTitle, toolbarBack
    public static let id = "breadcrumb", title = "Breadcrumb", page = BenchPage.global
    public static let help = "The way back up: crumbs plus a visible back button (brief, window shell)."
    public var title: String {
        switch self {
        case .chevron: return "Back + crumbs"; case .pill: return "Labeled back"
        case .largeTitle: return "Large title"; case .toolbarBack: return "Toolbar back"
        }
    }
    public var help: String {
        switch self {
        case .chevron: return "A back chevron, then Projects › fovea-site › 第二屏文案 · Codex"
        case .pill: return "‹ fovea-site as a button, the crumbs after it"
        case .largeTitle: return "Photos-style: small crumbs above the level's large title"
        case .toolbarBack: return "HIG: the circular Back at the toolbar's leading edge, the crumbs alone in the body (R02-04)"
        }
    }
}

public enum VerbLabels: String, Variant {
    case chinese, english
    public static let id = "verbLabels", title = "Verbs", page = BenchPage.global
    public static let help = "The brief writes three verbs in Chinese."
    public var title: String { self == .chinese ? "中文" : "English" }
    public var help: String { self == .chinese ? "接着改 · 带我去 · 过" : "Follow up · Take me there · Pass" }
}

/// How the window teaches the voice gesture. The brief says hold; the shipping hotkeys are
/// press-to-toggle (AGENTS.md). Every teaching line reads its copy from here.
public enum GestureCopy: String, Variant {
    case hold, press
    public static let id = "gestureCopy", title = "Gesture copy", page = BenchPage.global
    public static let help = "The brief teaches holding fn; the shipping hotkeys are press-to-toggle."
    public var title: String { self == .hold ? "Hold (brief)" : "Press to toggle" }
    public var help: String { self == .hold ? "Hold fn ⌃ and say what you want done." : "Press fn ⌃, say what you want done, press again." }

    /// The word before the keys.
    public var lead: String { self == .hold ? "Hold" : "Press" }
    /// After the keys, for the one gesture the window teaches.
    public var tail: String { self == .hold ? "and say what you want done." : "say what you want done, press again." }
    /// After the keys, where there's room for a few words only.
    public var short: String { self == .hold ? "and say it." : "say it, press again." }
    /// How the gestures work, under them in Settings › General.
    public var howTo: String {
        self == .hold ? "Hold to talk; let go to send." : "Press once to start and again to send."
    }
}

public enum MotionSystem: String, Variant {
    case notch, v1, notes
    public static let id = "motionSystem", title = "Motion", page = BenchPage.global
    public static let help = "Which set of springs and curves everything uses."
    public var title: String {
        switch self { case .notch: return "Notch springs"; case .v1: return "Spec v1"; case .notes: return "Motion notes" }
    }
    public var help: String {
        switch self {
        case .notch: return "Interpolating springs, no bounce: open 0.3, close 0.22, expand 0.32, collapse 0.26 (WorkbenchTokens)"
        case .v1: return ".smooth 0.30, selection 0.18, arrival .snappy 0.35 (spec v1 §10)"
        case .notes: return "open 0.38/0.15, close 0.30, convert 0.32/0.1 (docs/motion/NOTES.md, before AMENDMENTS §14)"
        }
    }
}

public enum RowActions: String, Variant {
    case hoverSlot, moreButton, always
    public static let id = "rowActions", title = "Row actions", page = BenchPage.global
    public static let help = "Secondary actions on a row; never hover-only, never reflowing."
    public var title: String {
        switch self { case .hoverSlot: return "Hover slot"; case .moreButton: return "••• button"; case .always: return "Always shown" }
    }
    public var help: String {
        switch self {
        case .hoverSlot: return "Hover swaps the time for the buttons in a fixed slot; the run page has them all"
        case .moreButton: return "A ••• menu always there, the hover slot too"
        case .always: return "The buttons always shown, dimmed until hover"
        }
    }
}

public enum StatusBarStyle: String, Variant {
    case glyphs, names, count
    public static let id = "statusBar", title = "Status bar", page = BenchPage.global
    public static let help = "The bottom bar's connections. The brief's ●●●○ reuses the run glyphs (research flag, page 02)."
    public var title: String {
        switch self { case .glyphs: return "Glyphs"; case .names: return "Names"; case .count: return "Count" }
    }
    public var help: String {
        switch self {
        case .glyphs: return "●●●○ 3 agents connected: filled connected, hollow hooks missing, dashed not found (brief)"
        case .names: return "Each agent's name after a 5 pt dot, the notch's Working dot; missing ones dimmed"
        case .count: return "Only 3 agents connected, in mono"
        }
    }
}

// MARK: - 01 Onboarding

public enum RevealStyle: String, Variant {
    case stagger, fromSummary, fromNotch, unfold, allAtOnce
    public static let id = "reveal", title = "Reveal", page = BenchPage.onboarding
    public static let help = "How the projects arrive (motion shortlist 2; the hero animation)."
    public var title: String {
        switch self {
        case .stagger: return "Stagger rise"; case .fromSummary: return "From the counts"; case .fromNotch: return "From the notch"
        case .unfold: return "Unfold"; case .allAtOnce: return "All at once"
        }
    }
    public var help: String {
        switch self {
        case .stagger: return "Each row rises 8 pt out of a 2 pt blur, one after another (the notch's line swap)"
        case .fromSummary: return "Each row travels from the counts line into its slot, headers fading in place (Family's regroup, R01-05)"
        case .fromNotch: return "Each row drops from the top center, where the notch is, into its place"
        case .unfold: return "The list grows a row at a time like the notch opening, the row fading in behind it"
        case .allAtOnce: return "The counts finish, then the whole list cross-fades in"
        }
    }
}

public enum CountStyle: String, Variant {
    case rolling, ticker, plain
    public static let id = "counts", title = "Counts", page = BenchPage.onboarding
    public static let help = "Numbers changing (motion shortlist 3)."
    public var title: String {
        switch self { case .rolling: return "Rolling digits"; case .ticker: return "Ticker"; case .plain: return "Plain" }
    }
    public var help: String {
        switch self {
        case .rolling: return "SwiftUI's numeric text transition with tabular digits"
        case .ticker: return "Each changed digit slides 12 pt with a 2 pt blur (motion notes)"
        case .plain: return "The number just changes"
        }
    }
}

public enum ScanProgress: String, Variant {
    case notchLine, hairline, ring
    public static let id = "scanProgress", title = "Progress", page = BenchPage.onboarding
    public static let help = "The one indicator while the scan runs."
    public var title: String {
        switch self { case .notchLine: return "4 pt line"; case .hairline: return "Hairline"; case .ring: return "Ring" }
    }
    public var help: String {
        switch self {
        case .notchLine: return "The notch's Transcribing line: a 4 pt capsule that fills"
        case .hairline: return "A 2 pt line under the toolbar, Safari's page load"
        case .ring: return "A small determinate ring beside the counts"
        }
    }
}

public enum HandoffCue: String, Variant {
    case arrow, fly, notchTip
    public static let id = "handoffCue", title = "Hand-off", page = BenchPage.onboarding
    public static let help = "The last step points to the notch."
    public var title: String {
        switch self { case .arrow: return "Arrow"; case .fly: return "Fly to the notch"; case .notchTip: return "Notch tip" }
    }
    public var help: String {
        switch self {
        case .arrow: return "One line and an arrow up toward the notch, inside the window"
        case .fly: return "The line's glyph leaves the window and flies up into the notch, which answers once (Family, R01-06)"
        case .notchTip: return "The notch itself opens a little and says it"
        }
    }
}

public enum MergeStyle: String, Variant {
    case banner, inline
    public static let id = "merge", title = "Merge", page = BenchPage.onboarding
    public static let help = "A suggestion that two projects are one; onboarding never merges on its own."
    public var title: String { self == .banner ? "Banner" : "On the pair" }
    public var help: String {
        self == .banner ? "One inline banner above the list, one suggestion at a time (brief)"
                        : "A heading line on the two rows themselves, Merge · Keep separate, then Merged · Undo (Photos Duplicates, R01-02)"
    }
}

// MARK: - 02 Projects

public enum DrillStyle: String, Variant {
    case zoom, notchExpand, push, crossFade
    public static let id = "drill", title = "Drill", page = BenchPage.projects
    public static let help = "Going in and out a level (motion shortlist 1)."
    public var title: String {
        switch self {
        case .zoom: return "Zoom from row"; case .notchExpand: return "Notch expand"
        case .push: return "Push"; case .crossFade: return "Cross-fade"
        }
    }
    public var help: String {
        switch self {
        case .zoom: return "The row's frame grows into the page, Photos' year → month (A1)"
        case .notchExpand: return "The row opens downward like the notch growing, the page fading in behind"
        case .push: return "The level slides in from the trailing edge, Finder and System Settings"
        case .crossFade: return "A 0.2 s cross-fade with a 4 pt blur"
        }
    }
}

public enum InlineExpandStyle: String, Variant {
    case clip, disclosure
    public static let id = "inlineExpand", title = "Fold", page = BenchPage.projects
    public static let help = "\"12 earlier runs\" and \"12 older projects\" opening in place (motion shortlist 4)."
    public var title: String { self == .clip ? "Clip reveal" : "Disclosure" }
    public var help: String {
        self == .clip ? "The rows are revealed as the fold grows, the notch's Paste chevron (0.32 / 0.26)"
                      : "AppKit's disclosure: rows slide down from under the fold row"
    }
}

public enum InlineSequence: String, Variant {
    case together, sequence
    public static let id = "inlineSequence", title = "One open", page = BenchPage.projects
    public static let help = "Opening one fold closes the other."
    public var title: String { self == .together ? "Together" : "In sequence" }
    public var help: String { self == .together ? "The open one closes as the new one opens" : "Close first, then open" }
}

public enum ThreadHeaderStyle: String, Variant {
    case things, codex, large
    public static let id = "threadHeader", title = "Thread header", page = BenchPage.projects
    public static let help = "A thread as a section inside the project page."
    public var title: String {
        switch self { case .things: return "Things heading"; case .codex: return "Codex label"; case .large: return "Large title" }
    }
    public var help: String {
        switch self {
        case .things: return "Semibold title over a hairline (A2)"
        case .codex: return "A quiet secondary label like Codex's project list (A4)"
        case .large: return "A larger title with the inference on its own mono line"
        }
    }
}

public enum RunRowStyle: String, Variant {
    case oneLine, twoLines
    public static let id = "runRow", title = "Run row", page = BenchPage.projects
    public static let help = "glyph · words · evidence · time."
    public var title: String { self == .oneLine ? "One line" : "Two lines" }
    public var help: String { self == .oneLine ? "Everything on one line, the words truncating first (brief)" : "Your words, the evidence under them" }
}

public enum ContinuityStyle: String, Variant {
    case raise, flight, neck
    public static let id = "continuity", title = "带我去 from notch", page = BenchPage.projects
    public static let help = "Opening a run in the window from the notch (motion shortlist 7)."
    public var title: String {
        switch self { case .raise: return "Raise + highlight"; case .flight: return "Flight"; case .neck: return "Neck" }
    }
    public var help: String {
        switch self {
        case .raise: return "The window comes forward on the run, which highlights"
        case .flight: return "The notch's card flies to the run's place in the window and becomes it"
        case .neck: return "A black neck joins the notch to the window while it opens (FoveaLab's dock)"
        }
    }
}

// MARK: - 03 Settings

public enum ConnectionGlyphs: String, Variant {
    case needsYou, brief
    public static let id = "connectionGlyphs", title = "Connection glyphs", page = BenchPage.settings
    public static let help = "A connection's state by shape, in Connections and the status bar."
    public var title: String { self == .brief ? "Filled = connected" : "● = needs you" }
    public var help: String {
        self == .brief ? "● connected, ○ hooks not installed, dashed not found (the brief's ●●●○)"
                       : "Nothing when connected, ● when hooks need installing, dashed when not found: the run glyphs' meanings (R03 research)"
    }
}

public enum HooksDetail: String, Variant {
    case disclosure, always
    public static let id = "hooksDetail", title = "What Fovea added", page = BenchPage.settings
    public static let help = "The raw lines a hook install adds to an agent's file."
    public var title: String { self == .disclosure ? "Disclosure" : "Always shown" }
    public var help: String {
        self == .disclosure ? "A disclosure under the file's path, closed until you open it (R03 gap 1)"
                            : "The lines always visible, selectable, under the path"
    }
}

// MARK: - 04 Run detail

public enum ReceiptSurface: String, Variant {
    case notch, paper, system
    public static let id = "receiptSurface", title = "Receipt", page = BenchPage.runDetail
    public static let help = "The receipt card the notch and the window share (§8)."
    public var title: String {
        switch self { case .notch: return "Notch black"; case .paper: return "Paper"; case .system: return "System" }
    }
    public var help: String {
        switch self {
        case .notch: return "Drawn exactly as the notch draws it: white at its opacities on black"
        case .paper: return "The same card inverted: ink at the same opacities on paper"
        case .system: return "The same anatomy in macOS's grouped-box style"
        }
    }
}

public enum DiffStyle: String, Variant {
    case monoUnified, tinted, split
    public static let id = "diff", title = "Diff", page = BenchPage.runDetail
    public static let help = "A file's changes, keeping state out of color."
    public var title: String {
        switch self { case .monoUnified: return "Monochrome"; case .tinted: return "Tinted"; case .split: return "Split" }
    }
    public var help: String {
        switch self {
        case .monoUnified: return "+ and − in the gutter, removed lines struck and dimmed, no hue"
        case .tinted: return "Green and red washes, Codex (A4). A counter-example to the no-hue rule"
        case .split: return "Before | after side by side, monochrome, Kaleidoscope's layout"
        }
    }
}

public enum DiffWords: String, Variant {
    case off, on
    public static let id = "diffWords", title = "Word emphasis", page = BenchPage.runDetail
    public static let help = "The changed words inside a changed line. Off by default: ▲ is the page's only emphasis."
    public var title: String { self == .on ? "On" : "Off" }
    public var help: String { self == .on ? "Changed spans in medium weight, never a whole line" : "Whole lines only: + and − in the gutter, removed lines struck" }
}

// MARK: - 05 Search

public enum SearchFieldStyle: String, Variant {
    case expanding, native
    public static let id = "searchField", title = "Field", page = BenchPage.search
    public static let help = "The toolbar's search, opened by clicking."
    public var title: String { self == .expanding ? "Expanding" : "Native" }
    public var help: String {
        self == .expanding ? "A magnifier that grows into a field with scope chips, on the notch's spring"
                           : "AppKit's search field, always open, chips under it"
    }
}

public enum SearchResultsStyle: String, Variant {
    case inPlace, dropdown
    public static let id = "searchResults", title = "Results", page = BenchPage.search
    public static let help = "Where results show."
    public var title: String { self == .inPlace ? "In place" : "Dropdown" }
    public var help: String {
        self == .inPlace ? "The results take the content area, with a crumb back" : "A panel under the field over the content, Spotlight-like"
    }
}

public enum JumpHighlight: String, Variant {
    case wash, ring, pulse
    public static let id = "jumpHighlight", title = "Jump highlight", page = BenchPage.search
    public static let help = "The item you jumped to, in place (motion shortlist 5)."
    public var title: String {
        switch self { case .wash: return "Wash"; case .ring: return "Ring"; case .pulse: return "Glyph pulse" }
    }
    public var help: String {
        switch self {
        case .wash: return "A tint behind the row that fades out (shipping highlightFade, B3)"
        case .ring: return "An outline that settles onto the row and fades"
        case .pulse: return "The row's glyph scales once; nothing else moves"
        }
    }
}

// MARK: - 06 Captures

public enum CaptureLayout: String, Variant {
    case notes, list, cards, hybrid
    public static let id = "captureLayout", title = "Layout", page = BenchPage.captures
    public static let help = "Cards or list is undecided (v3.3 §15); the page 06 research favours Notes' list."
    public var title: String {
        switch self {
        case .notes: return "Notes list"; case .list: return "List"; case .cards: return "Cards"; case .hybrid: return "Hybrid"
        }
    }
    public var help: String {
        switch self {
        case .notes: return "Your words over the mono line, a thumbnail at the end only when there is one (Notes, R06-01); Screenshots as a grid (Photos, R06-03)"
        case .list: return "One row each: preview chip, your words, the mono line"
        case .cards: return "A grid of cards, Paste-style (B1)"
        case .hybrid: return "Rows, with a large preview only when the capture has something to see"
        }
    }
}

public enum CaptureDetailStyle: String, Variant {
    case zoom, quickLook
    public static let id = "captureDetail", title = "Detail", page = BenchPage.captures
    public static let help = "Opening a capture."
    public var title: String { self == .zoom ? "In place" : "Quick Look" }
    public var help: String {
        self == .zoom ? "The item grows into its detail page, a level like any other" : "A centered card over the stream, which dims; the stream stays where it was"
    }
}

// MARK: - 07 Polish

public enum CorrectionStyle: String, Variant {
    case native, notch, inline
    public static let id = "correction", title = "Correction", page = BenchPage.polish
    public static let help = "Fixing an inferred value (7c; motion shortlist 6)."
    public var title: String {
        switch self { case .native: return "Popover"; case .notch: return "Notch popover"; case .inline: return "Inline" }
    }
    public var help: String {
        switch self {
        case .native: return "AppKit's popover with its arrow"
        case .notch: return "A black card in the notch's language, scaling from the underline"
        case .inline: return "The choices open under the line, pushing what follows"
        }
    }
}

public enum TodayTimelineStyle: String, Variant {
    case lanes, agenda
    public static let id = "todayTimeline", title = "Today", page = BenchPage.polish
    public static let help = "The notch's Today view, previewed in Settings › Notch (7b)."
    public var title: String { self == .lanes ? "Lanes" : "Agenda" }
    public var help: String {
        self == .lanes ? "One lane per row kind, time running left to right, now as a line" : "One list down the day, now as a rule"
    }
}

public enum Variants {
    /// Every decision in panel order.
    public static let all: [DecisionInfo] = [
        StateStyle.info, GlyphDrawing.info, RunningMark.info, WaitingArrival.info, FailedPlacementVariant.info,
        GroupLabels.info, SurfaceVariant.info, TypeScale.info, DensityVariant.info, BreadcrumbStyle.info,
        VerbLabels.info, GestureCopy.info, MotionSystem.info, RowActions.info, StatusBarStyle.info,
        RevealStyle.info, CountStyle.info, ScanProgress.info, MergeStyle.info, HandoffCue.info,
        DrillStyle.info, InlineExpandStyle.info, InlineSequence.info, ThreadHeaderStyle.info, RunRowStyle.info,
        ContinuityStyle.info,
        ConnectionGlyphs.info, HooksDetail.info,
        ReceiptSurface.info, DiffStyle.info, DiffWords.info,
        SearchFieldStyle.info, SearchResultsStyle.info, JumpHighlight.info,
        CaptureLayout.info, CaptureDetailStyle.info,
        CorrectionStyle.info, TodayTimelineStyle.info,
    ]

    public static func decisions(on page: BenchPage) -> [DecisionInfo] { all.filter { $0.page == page } }
}

import Foundation

// What the person makes theirs, once, for every surface: the onboarding's Make it yours writes it,
// Settings changes it, and the island, the window and the transcriber read it. One value, kept in
// `prefs.json` (FoveaStore), so the notch, the window's page island and Settings never disagree.

/// The accent, as macOS offers it: Multicolor follows the Mac's own accent; the eight colors put
/// one accent through Fovea. The color itself is FoveaLook's (`FoveaAccent.color`).
public enum FoveaAccent: String, CaseIterable, Identifiable, Codable, Sendable {
    case multicolor, blue, purple, pink, red, orange, yellow, green, graphite
    public var id: String { rawValue }
    public var title: String { L(key: rawValue.capitalized) }
}

/// The glow in the Dispatch voice bar, Fovea's aura: a palette to start from, turned round the
/// color wheel, or Custom, seven hues fanned round the one picked.
public enum GlowPalette: String, CaseIterable, Identifiable, Codable, Sendable {
    case colorful, mono, ocean, sunset, forest, candy, ice, gold, custom
    public var id: String { rawValue }
    public var title: String { L(key: rawValue.prefix(1).uppercased() + rawValue.dropFirst()) }
    /// The palettes to start from, in the order Settings and the onboarding list them.
    public static let templates: [GlowPalette] = [.colorful, .ocean, .sunset, .forest, .candy, .ice, .gold, .mono]
    /// Mono is gray: there's no hue to turn and nothing to drift.
    public var turns: Bool { self != .mono }
}

/// The notch's glass: light glass with ink words, or dark glass with white words. The person's
/// choice (Oct 9), not the Mac's appearance; only the hardware notch stays black.
public enum NotchAppearance: String, CaseIterable, Identifiable, Codable, Sendable {
    case light, dark
    public var id: String { rawValue }
    public var title: String { L(key: rawValue.capitalized) }
}

/// How what drops below meets the notch: one glass shape hanging from the top edge with its ears
/// (Attached), or a glass panel a gap below the notch, as Control Center is (Floating).
public enum NativePanels: String, CaseIterable, Identifiable, Codable, Sendable {
    case attached, floating
    public var id: String { rawValue }
    public var title: String { L(key: self == .attached ? "Attached" : "Floating") }
}

/// How much room what opens below the notch takes: Compact, as the notch was drawn through Oct 8,
/// or Spacious, after the Mac's own sizes and Fovea Captures (docs/island/SPACIOUS.md).
public enum NotchDensity: String, CaseIterable, Identifiable, Codable, Sendable {
    case compact, spacious
    public var id: String { rawValue }
    public var title: String { L(key: rawValue.capitalized) }
}

/// How the person signed up in the first run (Oct 15: Apple too, the dev team's review AC-01.1).
public enum AccountProvider: String, Codable, Sendable {
    case email, google, apple
}

/// Motion in the window and the notch (Oct 15, review IS02): as the Mac's Reduce Motion says, or
/// always reduced, or always full.
public enum MotionPreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case system, reduce, full
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .system: return L("Match the Mac")
        case .reduce: return L("Reduce")
        case .full: return L("Full")
        }
    }
}

/// A shortcut the person recorded (Oct 15, review ST-03.1: shortcuts can be changed). Modifiers
/// alone, pressed once to start and again to stop (fn, fn ⌃, right ⌥), or modifiers with a key
/// (⌥ Space). Kept by the shortcut's id (`FoveaShortcut.id`); a missing one is the default.
public struct KeyChord: Codable, Equatable, Hashable, Sendable {
    /// Modifier caps in the Mac's order: "fn", "⌃", "⌥", "⇧", "⌘". A right-hand key is written
    /// "right ⌥" and so on.
    public var modifiers: [String]
    /// The key pressed with them (its virtual key code and its cap), or nil for modifiers alone.
    public var keyCode: Int?
    public var keyCap: String?

    public init(modifiers: [String], keyCode: Int? = nil, keyCap: String? = nil) {
        self.modifiers = modifiers; self.keyCode = keyCode; self.keyCap = keyCap
    }

    /// The caps as Settings draws them.
    public var caps: [String] { modifiers + (keyCap.map { [$0] } ?? []) }
}

/// How long the pointer rests at the notch before the board opens: named, never in milliseconds.
public enum HoverWait: String, CaseIterable, Identifiable, Codable, Sendable {
    case quick, normal, relaxed
    public var id: String { rawValue }
    public var title: String { L(key: rawValue.capitalized) }
    /// The dwell before the board opens, and the most it may take, in seconds.
    public var dwell: (start: Double, cap: Double) {
        switch self {
        // Oct 21, Ryan: "expand faster when my mouse hovers" — each about half what it was.
        case .quick: return (0.03, 0.1)
        case .normal: return (0.06, 0.16)
        case .relaxed: return (0.18, 0.36)
        }
    }
}

/// The language Fovea listens and speaks in. English and Chinese for now; any other is typed
/// under More… in the first run and kept as a request.
public enum FoveaLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case english, chinese
    public var id: String { rawValue }
    public var title: String { L(key: rawValue.capitalized) }
    /// As the language writes itself.
    public var nativeName: String { self == .english ? "English" : "简体中文" }
    /// The locale speech recognition listens in.
    public var speechLocale: String { self == .english ? "en-US" : "zh-CN" }
    /// On the hello board's row, before More….
    public static let featured: [FoveaLanguage] = [.english, .chinese]
    /// What to start on: Chinese for a Mac that reads Chinese first, English otherwise.
    public static func preferred(_ identifiers: [String]) -> FoveaLanguage {
        identifiers.first?.lowercased().hasPrefix("zh") == true ? .chinese : .english
    }
}

/// The window's look (Settings › Appearance): the Mac's, or always light or dark.
public enum WindowAppearance: String, Codable, Sendable, CaseIterable {
    case system, light, dark
}

/// Everything the person chose, in one value.
public struct FoveaPrefs: Codable, Equatable, Sendable {
    // Make it yours.
    public var accent: FoveaAccent = .multicolor
    public var glowPalette: GlowPalette = .colorful
    /// Degrees the palette turns round the color wheel; Custom's own hue.
    public var glowHue: Double = 0
    /// Degrees Custom's seven colors fan across.
    public var glowSpread: Double = 120
    /// How much the colors wander, from still (0) to lively (1), 0.5 the Workbench's own swing.
    public var glowDrift: Double = 0.5
    // The notch.
    public var notchAppearance: NotchAppearance = .dark
    public var panels: NativePanels = .attached
    public var density: NotchDensity = .spacious
    public var hoverOpens = true
    public var hoverWait: HoverWait = .normal
    /// An answer that comes back while you're elsewhere opens by itself.
    public var showAnswers = true
    /// Choose chat before a Dispatch goes ("Review the words first").
    public var reviewFirst = true
    /// Oct 24, Ryan: the chats pinned to the notch's board, by id, in the order pinned.
    public var pinnedChats: [String] = []
    // You: the email you signed in with, and what Fovea calls you (the first run asks).
    public var accountEmail = ""
    public var accountName = ""
    /// How the first run signed up: an email, or Google (1.0 has no account server: both are kept
    /// on this Mac only).
    public var accountProvider: AccountProvider = .email
    // Fovea.
    public var language: FoveaLanguage = .english
    /// Languages typed under More…, kept to choose what comes next.
    public var requestedLanguages: [String] = []
    /// Oct 18 (Ryan): "Choose your languages." The supported ones the person speaks (English,
    /// Chinese, or both). `language` is the primary of them: Fovea's interface is in it and
    /// speech recognition listens in it. Empty means just `language`.
    public var languages: [FoveaLanguage] = []
    /// The chosen languages, the primary first.
    public var chosenLanguages: [FoveaLanguage] {
        [language] + languages.filter { $0 != language }
    }
    public var openAtLogin = true
    // Oct 15, the dev team's review (docs/v1/REVIEW_2026-10-15.md).
    /// Voice & Capture's "Tidy my words" (ST-04.2/3): on, fillers out, capitals and punctuation;
    /// off, exactly what was said.
    public var tidyWords = true
    /// Appearance's Motion (IS02).
    public var motion: MotionPreference = .system
    /// "What Fovea remembers" has been read: in the first run, or once in Home for someone who
    /// finished the tour before it existed (OB-01.6, OB-02).
    public var memoryDisclosureSeen = false
    /// Recorded shortcuts by `FoveaShortcut.id` (ST-03.1); a missing one is the default.
    public var shortcutChords: [String: KeyChord] = [:]
    /// Account › On this Mac › Show in Dock (ST-02.5). Off, Fovea lives in the menu bar alone.
    public var showInDock = true
    /// Signed out from Account (AC-01.5): the captures stay on this Mac; Account offers Sign In…,
    /// the dictionary is read-only, until signing in again.
    public var signedOut = false
    /// Settings › Memory's "Tell me when a memory updates" (NH-03): the notch says "Remembered"
    /// after a request. Off by default: the notch stays quiet unless asked.
    public var memoryNotice = false
    /// Settings › Appearance's Light, Dark or Auto for the window (Oct 23, Ryan: it applied but
    /// wasn't kept, so every launch came back light).
    public var windowAppearance: WindowAppearance = .light

    public init() {}

    /// The glow as drawn (Oct 18, Ryan: the palettes are fixed; only Custom has a hue and a drift
    /// to change): a template's hue turn is always 0 and its drift the default; Custom's are the
    /// person's.
    public var drawnGlowHue: Double { glowPalette == .custom ? glowHue : 0 }
    public var drawnGlowDrift: Double { glowPalette == .custom ? glowDrift : FoveaPrefs().glowDrift }
    public var drawnGlowSpread: Double { glowPalette == .custom ? glowSpread : FoveaPrefs().glowSpread }

    /// The notch's settings as they ship: Restore Defaults puts these back.
    public var notchIsDefault: Bool {
        let d = FoveaPrefs()
        return glowPalette == d.glowPalette && glowHue == d.glowHue && glowSpread == d.glowSpread
            && glowDrift == d.glowDrift && panels == d.panels && density == d.density && hoverOpens == d.hoverOpens
            && hoverWait == d.hoverWait && showAnswers == d.showAnswers && reviewFirst == d.reviewFirst
    }

    /// Restores the notch's settings, keeping the glass's light or dark, which is a look the
    /// person picked, not a setting that can break.
    public mutating func restoreNotch() {
        let d = FoveaPrefs()
        glowPalette = d.glowPalette; glowHue = d.glowHue; glowSpread = d.glowSpread; glowDrift = d.glowDrift
        panels = d.panels; density = d.density; hoverOpens = d.hoverOpens; hoverWait = d.hoverWait
        showAnswers = d.showAnswers; reviewFirst = d.reviewFirst
    }

    // Decoding tolerates a file written before a field existed: every missing key keeps its default.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = FoveaPrefs()
        accent = (try? c.decode(FoveaAccent.self, forKey: .accent)) ?? d.accent
        glowPalette = (try? c.decode(GlowPalette.self, forKey: .glowPalette)) ?? d.glowPalette
        glowHue = (try? c.decode(Double.self, forKey: .glowHue)) ?? d.glowHue
        glowSpread = (try? c.decode(Double.self, forKey: .glowSpread)) ?? d.glowSpread
        glowDrift = (try? c.decode(Double.self, forKey: .glowDrift)) ?? d.glowDrift
        notchAppearance = (try? c.decode(NotchAppearance.self, forKey: .notchAppearance)) ?? d.notchAppearance
        panels = (try? c.decode(NativePanels.self, forKey: .panels)) ?? d.panels
        density = (try? c.decode(NotchDensity.self, forKey: .density)) ?? d.density
        hoverOpens = (try? c.decode(Bool.self, forKey: .hoverOpens)) ?? d.hoverOpens
        hoverWait = (try? c.decode(HoverWait.self, forKey: .hoverWait)) ?? d.hoverWait
        showAnswers = (try? c.decode(Bool.self, forKey: .showAnswers)) ?? d.showAnswers
        reviewFirst = (try? c.decode(Bool.self, forKey: .reviewFirst)) ?? d.reviewFirst
        accountEmail = (try? c.decode(String.self, forKey: .accountEmail)) ?? d.accountEmail
        accountName = (try? c.decode(String.self, forKey: .accountName)) ?? d.accountName
        accountProvider = (try? c.decode(AccountProvider.self, forKey: .accountProvider)) ?? d.accountProvider
        language = (try? c.decode(FoveaLanguage.self, forKey: .language)) ?? d.language
        requestedLanguages = (try? c.decode([String].self, forKey: .requestedLanguages)) ?? d.requestedLanguages
        openAtLogin = (try? c.decode(Bool.self, forKey: .openAtLogin)) ?? d.openAtLogin
        languages = (try? c.decode([FoveaLanguage].self, forKey: .languages)) ?? d.languages
        tidyWords = (try? c.decode(Bool.self, forKey: .tidyWords)) ?? d.tidyWords
        motion = (try? c.decode(MotionPreference.self, forKey: .motion)) ?? d.motion
        memoryDisclosureSeen = (try? c.decode(Bool.self, forKey: .memoryDisclosureSeen)) ?? d.memoryDisclosureSeen
        shortcutChords = (try? c.decode([String: KeyChord].self, forKey: .shortcutChords)) ?? d.shortcutChords
        showInDock = (try? c.decode(Bool.self, forKey: .showInDock)) ?? d.showInDock
        signedOut = (try? c.decode(Bool.self, forKey: .signedOut)) ?? d.signedOut
        memoryNotice = (try? c.decode(Bool.self, forKey: .memoryNotice)) ?? d.memoryNotice
        windowAppearance = (try? c.decode(WindowAppearance.self, forKey: .windowAppearance)) ?? d.windowAppearance
        pinnedChats = (try? c.decode([String].self, forKey: .pinnedChats)) ?? d.pinnedChats
    }
}

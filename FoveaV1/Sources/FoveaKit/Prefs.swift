import Foundation

// What the person makes theirs, once, for every surface: the onboarding's Make it yours writes it,
// Settings changes it, and the island, the window and the transcriber read it. One value, kept in
// `prefs.json` (FoveaStore), so the notch, the window's page island and Settings never disagree.

/// The accent, as macOS offers it: Multicolor follows the Mac's own accent; the eight colors put
/// one accent through Fovea. The color itself is FoveaLook's (`FoveaAccent.color`).
public enum FoveaAccent: String, CaseIterable, Identifiable, Codable, Sendable {
    case multicolor, blue, purple, pink, red, orange, yellow, green, graphite
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

/// The glow in the Dispatch voice bar, Fovea's aura: a palette to start from, turned round the
/// color wheel, or Custom, seven hues fanned round the one picked.
public enum GlowPalette: String, CaseIterable, Identifiable, Codable, Sendable {
    case colorful, mono, ocean, sunset, forest, candy, ice, gold, custom
    public var id: String { rawValue }
    public var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
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
    public var title: String { rawValue.capitalized }
}

/// How what drops below meets the notch: one glass shape hanging from the top edge with its ears
/// (Attached), or a glass panel a gap below the notch, as Control Center is (Floating).
public enum NativePanels: String, CaseIterable, Identifiable, Codable, Sendable {
    case attached, floating
    public var id: String { rawValue }
    public var title: String { self == .attached ? "Attached" : "Floating" }
}

/// How much room what opens below the notch takes: Compact, as the notch was drawn through Oct 8,
/// or Spacious, after the Mac's own sizes and Fovea Captures (docs/island/SPACIOUS.md).
public enum NotchDensity: String, CaseIterable, Identifiable, Codable, Sendable {
    case compact, spacious
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

/// How long the pointer rests at the notch before the board opens: named, never in milliseconds.
public enum HoverWait: String, CaseIterable, Identifiable, Codable, Sendable {
    case quick, normal, relaxed
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    /// The dwell before the board opens, and the most it may take, in seconds.
    public var dwell: (start: Double, cap: Double) {
        switch self {
        case .quick: return (0.06, 0.18)
        case .normal: return (0.12, 0.3)
        case .relaxed: return (0.3, 0.6)
        }
    }
}

/// The language Fovea listens and speaks in. English and Chinese for now; any other is typed
/// under More… in the first run and kept as a request.
public enum FoveaLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case english, chinese
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
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
    // You: the email you signed in with, and what Fovea calls you (the first run asks).
    public var accountEmail = ""
    public var accountName = ""
    // Fovea.
    public var language: FoveaLanguage = .english
    /// Languages typed under More…, kept to choose what comes next.
    public var requestedLanguages: [String] = []
    public var openAtLogin = true

    public init() {}

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
        language = (try? c.decode(FoveaLanguage.self, forKey: .language)) ?? d.language
        requestedLanguages = (try? c.decode([String].self, forKey: .requestedLanguages)) ?? d.requestedLanguages
        openAtLogin = (try? c.decode(Bool.self, forKey: .openAtLogin)) ?? d.openAtLogin
    }
}

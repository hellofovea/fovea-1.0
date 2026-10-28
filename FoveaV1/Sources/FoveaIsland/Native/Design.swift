import SwiftUI
import AppKit
import Observation
import FoveaKit

// The notch's two designs (docs/island/NATIVE.md), switched in the window's toolbar like density:
// Original, the notch as drawn through Oct 8 (one black shape, white at opacities); Native, the same
// content in the language of the app (Prototypes/FoveaCaptures) and the onboarding
// (Prototypes/FoveaOnboarding). In Native the island and what drops below it are Liquid Glass in the
// Mac's appearance, light or dark, only the notch black; what drops below hangs from the top edge
// (Attached) or floats under the notch (Floating); the accent and the system's state colors, and
// Voiceflow's waveform white, never a color.
// Every view is shared, so every Voiceflow and Dispatch state shows in either design with the same
// words; in Original every value is the one it was.

/// The notch's design: the toolbar's Original · Native, View › Original Design (⌥⌘1) and Native
/// Design (⌥⌘2), or `--design=original|native`.
enum NotchDesign: String, CaseIterable, Identifiable {
    case original, native
    var id: String { rawValue }
    var title: String { self == .original ? "Original" : "Native" }
}

// How Native's panels meet the notch (`NativePanels`, attached or floating) is FoveaKit's.

/// The design in force, and the accent the Native tokens draw with. Observable, so a view or a
/// layout that reads a token that follows the design is drawn again when it changes.
@Observable
final class DesignStore {
    static let shared = DesignStore()
    var value: NotchDesign = .original
    var accent: FoveaAccent = .blue
    var panels: NativePanels = .attached
}

extension WorkbenchTokens {
    static var design: NotchDesign { DesignStore.shared.value }
    static var isNative: Bool { DesignStore.shared.value == .native }
    /// Native with its panels floating under the notch (the gap, the separate panel).
    static var floatsPanels: Bool { isNative && DesignStore.shared.panels == .floating }
    /// Attached (Oct 27, Ryan: Halo "is supposed to replace the attached part"): one shape from the
    /// top edge, the notch's black blurred into the glass round it.
    static var blendsPanels: Bool { isNative && !floatsPanels }
    /// What drops below is one shape with the island, hanging from the top edge (attached; floating
    /// stays as it was, the panel a gap under the notch).
    static var panelsHangFromTop: Bool { !floatsPanels }

    /// A token's value in each design.
    static func skin<T>(_ original: T, _ native: T) -> T {
        DesignStore.shared.value == .native ? native : original
    }

    /// Ink at an opacity. Original: white, on the island's black. Native: the system's own ink,
    /// white at that opacity in dark and black at it in light, resolved by the color scheme of the
    /// view it is drawn in (so on the black island it is still white).
    static func ink(_ opacity: Double) -> Color {
        skin(Color.white.opacity(opacity), Ink.dynamic(opacity))
    }

    /// The opposite ink, for a glyph or a word on a solid ink fill (black on white in dark).
    static func inverseInk(_ opacity: Double) -> Color {
        skin(Color.black.opacity(opacity), Ink.dynamic(opacity, inverse: true))
    }
}

/// The dynamic inks, one per opacity, made once (the same color each time, so SwiftUI sees no
/// change where nothing changed). Read from the main thread only, as every token is.
enum Ink {
    nonisolated(unsafe) private static var cache: [String: Color] = [:]

    static func dynamic(_ opacity: Double, inverse: Bool = false) -> Color {
        let key = "\(inverse ? "-" : "+")\(opacity)"
        if let color = cache[key] { return color }
        let color = Color(nsColor: NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return (dark != inverse ? NSColor.white : NSColor.black).withAlphaComponent(opacity)
        })
        cache[key] = color
        return color
    }
}

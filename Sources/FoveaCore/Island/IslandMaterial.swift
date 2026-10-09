import Foundation

/// What the Island's surface is made of below the notch: the five options of the material
/// study. `.black` is the PRD's surface (§2.7, §6: no gradients, no glassmorphism); the
/// others are prototypes to be judged on the real notch, and any of them needs a PRD
/// amendment before it can become the default.
public enum IslandMaterial: String, CaseIterable, Codable, Hashable, Sendable {
    /// A: solid black, no edge.
    case black
    /// B: solid black with a 1 pt keyline on the sides and bottom.
    case keyline
    /// C: black through the top half, then glass down to a low floor (after VoiceOS).
    case proportionalFade
    /// D: black through the notch band, easing to a floor measured from the top of the screen.
    case graded
    /// E: glass everywhere; the physical notch shows through.
    case glass

    public static let `default`: IslandMaterial = .black

    /// The study's letter, A to E.
    public var letter: String {
        switch self {
        case .black: return "A"
        case .keyline: return "B"
        case .proportionalFade: return "C"
        case .graded: return "D"
        case .glass: return "E"
        }
    }

    public var title: String {
        switch self {
        case .black: return "Black"
        case .keyline: return "Black with a keyline"
        case .proportionalFade: return "Proportional fade"
        case .graded: return "Graded black"
        case .glass: return "Full glass"
        }
    }

    /// Whether any of the desktop shows through (a behind-window blur under the black).
    public var isTranslucent: Bool {
        switch self {
        case .black, .keyline: return false
        case .proportionalFade, .graded, .glass: return true
        }
    }

    /// Accepts the raw value (`graded`) or the study's letter (`d`).
    public static func parse(_ string: String) -> IslandMaterial? {
        let s = string.lowercased()
        return allCases.first { $0.rawValue.lowercased() == s || $0.letter.lowercased() == s }
    }
}

/// How much black the graded surface (D) holds at a depth measured from the top of the
/// screen. Two layers: a floor of black over the whole panel, and a ramp above it that is
/// solid through `solidDepth` and eases out over `fade`. Anchored to the screen, not to the
/// panel, so the material never stretches while the island grows.
public struct IslandMaterialRamp: Hashable, Sendable {
    /// Opacity of black everywhere, and so under any text.
    public var floor: Double
    /// Depth from the top of the screen that stays fully black (notch band plus a hold).
    public var solidDepth: CGFloat
    /// Distance over which black eases from solid down to the floor.
    public var fade: CGFloat

    public init(floor: Double, solidDepth: CGFloat, fade: CGFloat) {
        self.floor = min(1, max(0, floor)); self.solidDepth = max(0, solidDepth); self.fade = max(1, fade)
    }

    /// Total height of the ramp layer.
    public var height: CGFloat { solidDepth + fade }

    /// Opacity of the ramp layer alone at `depth`: 1 through the solid band, then a
    /// smoothstep down to 0 (a linear ramp shows a band where it meets the floor).
    public func rampOpacity(atDepth depth: CGFloat) -> Double {
        guard depth > solidDepth else { return 1 }
        let t = min(1, Double((depth - solidDepth) / fade))
        return 1 - t * t * (3 - 2 * t)
    }

    /// Composite opacity of black at `depth`: never below `floor`, 1 through the solid band.
    public func opacity(atDepth depth: CGFloat) -> Double {
        floor + (1 - floor) * rampOpacity(atDepth: depth)
    }

    /// Stops for the ramp layer: `location` in 0…1 of `height`, `opacity` of black there.
    public func rampStops(samples: Int = 8) -> [(location: Double, opacity: Double)] {
        let total = Double(height)
        var stops: [(location: Double, opacity: Double)] = [(0, 1), (Double(solidDepth) / total, 1)]
        for i in 1...max(1, samples) {
            let depth = solidDepth + fade * CGFloat(i) / CGFloat(max(1, samples))
            stops.append((Double(depth) / total, rampOpacity(atDepth: depth)))
        }
        return stops
    }
}

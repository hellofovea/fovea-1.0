import Observation

// How much room the notch's open panels take (docs/island/SPACIOUS.md). Fovea 1.0, Oct 9: the
// Workbench drew its Mac at about two thirds of its size, so on the real screen every panel read
// a size too big (Choose chat's words larger than a coding agent's). Each size moved down a step:
// Spacious is now what Compact was (14 pt words, 32 pt controls: a coding agent's own), Compact
// about an eighth smaller again (13 pt, 28 pt: the Mac's menus and buttons). The two keep their
// own looks (rules, weights, plates). The resting notch and the voice bar are the same in both.

/// The two densities, switched in the Workbench panel or with `--density=compact|spacious`.
enum PanelDensity: String, CaseIterable, Identifiable {
    case compact, spacious
    var id: String { rawValue }
    var title: String { self == .compact ? "Compact" : "Spacious" }
}

/// The density in force. Observable, so a view or a layout that reads a token that follows the
/// density is drawn again when it changes.
@Observable
final class DensityStore {
    static let shared = DensityStore()
    var value: PanelDensity = .spacious
}

extension WorkbenchTokens {
    static var density: PanelDensity { DensityStore.shared.value }

    /// A token's value for each density.
    static func pick<T>(_ compact: T, _ spacious: T) -> T {
        DensityStore.shared.value == .compact ? compact : spacious
    }
}

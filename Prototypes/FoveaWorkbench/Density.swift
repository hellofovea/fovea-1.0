import Observation

// How much room the notch's open panels take (docs/island/SPACIOUS.md): Compact, as the panels
// were through Oct 6; Spacious, after the Mac's own baselines and Fovea Captures (13 pt text and
// up, 28 pt controls, more space between groups than inside one). The resting notch and the voice
// bar are the same in both.

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

import SwiftUI
import FoveaKit

// The look the island and the window share. Filled as the surfaces move onto it.

extension FoveaAccent {
    /// The system color for the accent; Multicolor is the Mac's own.
    public var color: Color {
        switch self {
        case .multicolor: return Color(nsColor: .controlAccentColor)
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

extension NotchAppearance {
    public var colorScheme: ColorScheme { self == .light ? .light : .dark }
    public var nsAppearance: NSAppearance? { NSAppearance(named: self == .light ? .aqua : .darkAqua) }
}

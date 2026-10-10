import SwiftUI
import AppKit
import OnboardingCore
import FoveaCore
import FoveaKit

/// System Settings as macOS 27 shows Privacy & Security's lists: Fovea isn't in a list until it's
/// dragged in from the notch, and joins it switched on (REAL_MAC.md). The drop zone breathes in the
/// accent until then (Oct 9: make the drag obvious). Simulated: nothing here touches the real
/// System Settings.
enum FoveaIcon {
    static let image: NSImage? = FoveaFiles.url("AppIcon.png").flatMap { NSImage(contentsOf: $0) }
}

/// Where Fovea goes: a dashed place at the foot of the list, breathing in the accent until it's
/// dropped on.
/// Fovea, as it's dragged: the icon and the name, lifted.
struct TileView: View {
    var dragging = false

    var body: some View {
        HStack(spacing: 8) {
            if let icon = FoveaIcon.image { Image(nsImage: icon).resizable().frame(width: 22, height: 22) }
            Text("Fovea").font(.system(size: 12.5, weight: .semibold))
        }
        .foregroundStyle(dragging ? OT.Colors.tileLiftedText : OT.Colors.islandText)
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(dragging ? OT.Colors.tileLifted : OT.Colors.islandFill))
        .shadow(color: OT.Colors.tileShadow.opacity(dragging ? 1 : 0), radius: 10, y: 4)
    }
}


/// An agent's mark, from the brand's Destinations (the agents step, the notes on the board).
enum AgentIcon {
    static func image(_ name: String) -> NSImage? {
        let file: String
        switch name {
        case "Claude Code": file = "Destinations/claude-code.png"
        case "Codex": file = "Destinations/codex.png"
        case "Cursor": file = "Destinations/cursor.png"
        default: return FoveaIcon.image
        }
        return FoveaFiles.url(file).flatMap { NSImage(contentsOf: $0) }
    }
}

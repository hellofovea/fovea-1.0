import SwiftUI
import AppKit
import OnboardingCore
import FoveaCore
import FoveaKit

/// Fovea's own icon (an agent's fallback mark).
enum FoveaIcon {
    static let image: NSImage? = FoveaFiles.url("AppIcon.png").flatMap { NSImage(contentsOf: $0) }
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

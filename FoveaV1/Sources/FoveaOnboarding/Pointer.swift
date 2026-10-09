import SwiftUI
import AppKit
import OnboardingCore

// Copied from FoveaWorkbench/Feedback/VoiceflowFeedbackViews.swift (AccentArrow, screenCursor):
// round three of the Oct 6 feedback, #3 and #8. May drift. Keyed by the onboarding's AccentName.

/// The highlighter's pointer: the system's arrow, filled with the accent color (nothing else
/// changes; no pen rides on it). Drawn once per color, its tip the hot spot.
@MainActor
enum AccentArrow {
    private static var cache: [AccentName: NSImage] = [:]

    static func image(_ accent: AccentName) -> NSImage {
        if let hit = cache[accent] { return hit }
        let P = OT.Pointer.self
        let fill = AccentPalette.nsColor(accent)
        let image = NSImage(size: P.size, flipped: true) { _ in
            let arrow = NSBezierPath()
            arrow.move(to: NSPoint(x: 5, y: 3))
            arrow.line(to: NSPoint(x: 5, y: 19.5))
            arrow.line(to: NSPoint(x: 9, y: 15.6))
            arrow.line(to: NSPoint(x: 11.6, y: 21.4))
            arrow.line(to: NSPoint(x: 14.2, y: 20.2))
            arrow.line(to: NSPoint(x: 11.7, y: 14.6))
            arrow.line(to: NSPoint(x: 17, y: 14.6))
            arrow.close()
            arrow.lineJoinStyle = .round
            NSGraphicsContext.current?.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = P.shadow
            shadow.shadowBlurRadius = P.shadowBlur
            shadow.shadowOffset = P.shadowOffset
            shadow.set()
            let outline = arrow.copy() as! NSBezierPath
            outline.lineWidth = P.edgeWidth
            P.edge.setStroke()
            outline.stroke()
            NSGraphicsContext.current?.restoreGraphicsState()
            fill.setFill()
            arrow.fill()
            return true
        }
        // Multicolor follows the system's accent, which can change while the app runs.
        if accent != .multicolor { cache[accent] = image }
        return image
    }

    static func cursor(_ accent: AccentName) -> NSCursor { NSCursor(image: image(accent), hotSpot: OT.Pointer.tip) }
}

extension View {
    /// The pointer over the practice screen: the selection crosshair while ⌘ is armed, the accent
    /// arrow while the highlighter is on, the system's otherwise. One modifier decides, so the two
    /// never fight.
    @ViewBuilder
    func screenPointer(screenshot: Bool, highlighting: Bool, accent: AccentName) -> some View {
        if #available(macOS 15, *) {
            pointerStyle(screenshot ? .rectSelection
                         : highlighting ? .image(Image(nsImage: AccentArrow.image(accent)),
                                                 hotSpot: UnitPoint(x: OT.Pointer.tip.x / OT.Pointer.size.width,
                                                                    y: OT.Pointer.tip.y / OT.Pointer.size.height))
                         : nil)
        } else {
            onContinuousHover { phase in
                guard screenshot || highlighting else { return }
                switch phase {
                case .active: (screenshot ? NSCursor.crosshair : AccentArrow.cursor(accent)).set()
                case .ended: NSCursor.arrow.set()
                }
            }
        }
    }
}

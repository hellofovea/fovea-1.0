import AppKit

// Oct 18, Ryan: the highlights over words taken "should only stay in that one screen, it shouldn't
// be moving to other screens". They were drawn in the island's layer, which is on every Space (and
// on the island's display, not necessarily the words'). Now each window they were taken from gets
// a clear, click-through window of Fovea's of its own size, ordered just above it: on its display,
// on its Space, under whatever covers it. It follows that window (moved, it moves; minimised, on
// another Space or hidden, it's put away; back, it's back above it).

/// Rects as a mark window places them.
public enum MarkGeometry {
    /// A global top-left rect (Quartz, Accessibility) as AppKit's bottom-left screen frame.
    public static func appKitFrame(_ quartz: CGRect, primaryHeight: CGFloat) -> NSRect {
        NSRect(x: quartz.minX, y: primaryHeight - quartz.maxY, width: quartz.width, height: quartz.height)
    }

    /// A global top-left rect, in a window's own top-left points (`window` its global bounds).
    public static func local(_ rect: CGRect, in window: CGRect) -> CGRect {
        rect.offsetBy(dx: -window.minX, dy: -window.minY)
    }
}

/// The marks over one window of another app.
@MainActor
public final class MarkWindow: NSPanel {
    public let target: CGWindowID
    /// The target's bounds as last seen (global top-left points).
    public private(set) var targetBounds: CGRect
    private let view = MarkView()

    public init(target: CGWindowID, bounds: CGRect) {
        self.target = target
        self.targetBounds = bounds
        super.init(contentRect: MarkGeometry.appKitFrame(bounds, primaryHeight: Screens.primaryHeight),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        level = .normal
        // One Space (the target's), never every Space; allowed over a full-screen app's.
        collectionBehavior = [.managed, .ignoresCycle, .fullScreenAuxiliary]
        view.frame = NSRect(origin: .zero, size: bounds.size)
        view.autoresizingMask = [.width, .height]
        contentView = view
        setAccessibilityElement(false)
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }

    /// The marks, in the target window's own top-left points, and their look.
    public func show(_ rects: [CGRect], color: NSColor, radius: CGFloat, outset: CGFloat) {
        guard view.rects != rects || view.color != color || view.radius != radius || view.outset != outset else { return }
        view.rects = rects
        view.color = color
        view.radius = radius
        view.outset = outset
        view.needsDisplay = true
    }

    /// Where the target is now: on screen (on the Space in front, not minimised or hidden), the marks
    /// go with it, just above it; otherwise they're put away. Returns whether they show.
    @discardableResult
    public func follow() -> Bool {
        guard let info = (CGWindowListCopyWindowInfo([.optionIncludingWindow], target) as? [[String: Any]])?.first,
              (info[kCGWindowIsOnscreen as String] as? Bool) == true,
              let dict = info[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: dict) else {
            if isVisible { orderOut(nil) }
            return false
        }
        if bounds != targetBounds || !isVisible {
            targetBounds = bounds
            setFrame(MarkGeometry.appKitFrame(bounds, primaryHeight: Screens.primaryHeight), display: false)
        }
        order(.above, relativeTo: Int(target))
        return true
    }
}

/// Draws the marks: rounded rects in the given color, top-left points.
final class MarkView: NSView {
    var rects: [CGRect] = []
    var color: NSColor = .clear
    var radius: CGFloat = 3
    var outset: CGFloat = 0

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        for r in rects {
            NSBezierPath(roundedRect: r.insetBy(dx: -outset, dy: -outset), xRadius: radius, yRadius: radius).fill()
        }
    }
}

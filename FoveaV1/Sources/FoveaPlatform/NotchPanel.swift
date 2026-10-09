import AppKit
import SwiftUI
import FoveaCore

// The transparent, always-on-top window the island draws in, the size of the whole screen: the
// island at the top, capture mode's marks over everything, the chats pulled out of the notch.
// Patterns from DynamicNotchKit, NotchDrop, OpenDictation and opennook (all MIT), as the shipping
// app's NotchPanel has them:
//  • .nonactivatingPanel + canBecomeKey: the island can host a text field without activating
//    Fovea, so the frontmost app keeps its menu bar and active title bar.
//  • becomesKeyOnlyIfNeeded: a click makes it key only when it lands on a text view.
//  • level = statusBar + 8: above the menu bar, below .screenSaver (which breaks drags).
//  • Clicks go through it everywhere but where Fovea draws (`interactive`), so the desktop, the
//    menu bar and every app under it stay as they were.

public final class NotchPanel: NSPanel {
    public static let islandLevel = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 8)
    public static let islandBehavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

    public init(frame: NSRect) {
        super.init(contentRect: frame,
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        acceptsMouseMovedEvents = true
        animationBehavior = .none
        ignoresMouseEvents = true
        setAccessibilityIdentifier("fovea.island")
        reassert()
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }

    /// macOS occasionally demotes panels after sleep or a Space switch; re-apply on show.
    public func reassert() {
        level = Self.islandLevel
        collectionBehavior = Self.islandBehavior
    }

    /// The panel covers the screen and never moves of its own accord.
    public override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Hosting view that takes clicks only where Fovea draws: `interactive` gives those places in the
/// view's own top-down points; everywhere else the click falls through to what's under it.
public final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    public var interactive: () -> [CGRect] = { [] }
    /// Everything takes clicks (capture mode, a drag out of the notch).
    public var takesAll: () -> Bool = { false }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        // `point` is in the superview's coordinates; the hosting view fills the window.
        let local = convert(point, from: superview)
        let top = CGPoint(x: local.x, y: bounds.height - local.y)
        guard takesAll() || interactive().contains(where: { $0.contains(top) }) else { return nil }
        return super.hitTest(point)
    }

    /// The panel is rarely key; the first click on a button must still be the click.
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// The screens Fovea lives on.
public enum Screens {
    /// The display with the notch (the built-in one), else the main display.
    @MainActor public static var island: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    /// The screen under the pointer.
    @MainActor public static var underPointer: NSScreen? {
        let p = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) }
    }

    /// A screen as the island's geometry reads it: its own points from zero, the menu bar's height,
    /// and the room either side of the notch (none on a display without one).
    @MainActor public static func metrics(for screen: NSScreen) -> ScreenMetrics {
        let f = screen.frame
        let v = screen.visibleFrame
        let visible = CGRect(x: v.minX - f.minX, y: v.minY - f.minY, width: v.width, height: v.height)
        let notched = screen.safeAreaInsets.top > 0
        let left = notched ? (screen.auxiliaryTopLeftArea?.width ?? 0) : 0
        let right = notched ? (screen.auxiliaryTopRightArea?.width ?? 0) : 0
        // The menu bar: the safe area on a notched display; else the band the visible frame leaves.
        let menuBar = notched ? screen.safeAreaInsets.top : max(0, f.maxY - v.maxY)
        return ScreenMetrics(frame: CGRect(origin: .zero, size: f.size), visibleFrame: visible,
                             safeAreaTop: notched ? menuBar : 0, auxLeftWidth: left, auxRightWidth: right)
    }

    /// The height of the primary display, which global top-left coordinates (Accessibility,
    /// Quartz window lists) are measured from.
    @MainActor public static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? NSScreen.main?.frame.height ?? 0
    }

    /// A point on `screen`, in its own top-down points, as Quartz's global top-left point.
    @MainActor public static func global(_ p: CGPoint, on screen: NSScreen) -> CGPoint {
        CGPoint(x: screen.frame.minX + p.x, y: primaryHeight - screen.frame.maxY + p.y)
    }

    /// A rect on `screen`, in its own top-down points, as a Quartz global top-left rect.
    @MainActor public static func global(_ r: CGRect, on screen: NSScreen) -> CGRect {
        CGRect(origin: global(r.origin, on: screen), size: r.size)
    }

    /// A Quartz global top-left rect as `screen`'s own top-down points.
    @MainActor public static func local(_ r: CGRect, on screen: NSScreen) -> CGRect {
        CGRect(x: r.minX - screen.frame.minX, y: r.minY - (primaryHeight - screen.frame.maxY),
               width: r.width, height: r.height)
    }

    /// AppKit's bottom-up screen point as `screen`'s own top-down point.
    @MainActor public static func local(appKit p: CGPoint, on screen: NSScreen) -> CGPoint {
        CGPoint(x: p.x - screen.frame.minX, y: screen.frame.maxY - p.y)
    }

    /// The Quartz display a screen is.
    @MainActor public static func displayID(_ screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }
}

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
        // SwiftUI's hosting view is flipped: its own points already run top-down.
        let top = isFlipped ? local : CGPoint(x: local.x, y: bounds.height - local.y)
        guard takesAll() || interactive().contains(where: { $0.contains(top) }) else { return nil }
        return super.hitTest(point)
    }

    /// The panel is rarely key; the first click on a button must still be the click.
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Oct 17, Ryan: files dragged onto the notch. A clear view over the island (and a little past it)
/// that takes a drop of files from Finder or the desktop; it's put up only while such a drag is
/// under way, so no other drag, and no click, ever lands on it.
public final class FileDropView: NSView {
    /// The drag is over it, with how many files it carries (Oct 25, Ryan: many at once), or has
    /// left (0).
    public var onTargeted: (Int) -> Void = { _ in }
    /// The files let go on it, and where (AppKit's screen point). True when they were taken.
    public var onDrop: ([URL], NSPoint) -> Bool = { _, _ in false }

    public override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Drawn all but invisible, so the window server counts it as there.
    public override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.002).setFill()
        dirtyRect.fill()
    }

    private func files(_ info: NSDraggingInfo) -> [URL] {
        info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    }

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let count = files(sender).count
        guard count > 0 else { return [] }
        onTargeted(count)
        return .copy
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        files(sender).isEmpty ? [] : .copy
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) { onTargeted(0) }

    public override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { !files(sender).isEmpty }

    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = files(sender)
        onTargeted(0)
        let point = window.map { $0.convertPoint(toScreen: sender.draggingLocation) } ?? NSEvent.mouseLocation
        return onDrop(urls, point)
    }

    public override func draggingEnded(_ sender: NSDraggingInfo) { onTargeted(0) }
}

/// The screens Fovea lives on.
public enum Screens {
    /// The app in front fills `screen` (taken full screen): the menu bar is gone and macOS leaves
    /// the band beside the notch black. A window's bounds need no permission to read.
    @MainActor public static func frontAppFillsScreen(_ screen: NSScreen) -> Bool {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return false }
        return fullScreenWindow(on: screen) { $0 == pid }
    }

    /// An app `owner` accepts has taken `screen` full screen: its windows together span the screen's
    /// width down to its foot, their top at the screen's top or just under the notch (where macOS
    /// puts a full-screen app on a Mac with one). Oct 11: comparing one window with the whole screen
    /// missed every one of them (Chrome full screen is several windows, from y 33 down). An ordinary
    /// window can't go above the menu bar, which is lower than the notch, so it never counts.
    @MainActor public static func fullScreenWindow(on screen: NSScreen, owner: (Int32) -> Bool) -> Bool {
        let area = global(CGRect(origin: .zero, size: screen.frame.size), on: screen)
        let notch = screen.safeAreaInsets.top
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var byApp: [Int32: CGRect] = [:]
        for window in info {
            guard let pid = window[kCGWindowOwnerPID as String] as? Int32, owner(pid),
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let dict = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: dict), rect.intersects(area) else { continue }
            byApp[pid] = byApp[pid].map { $0.union(rect) } ?? rect
        }
        return byApp.values.contains { u in
            u.minX - area.minX < 1 && area.maxX - u.maxX < 1 && area.maxY - u.maxY < 1 && u.minY - area.minY <= notch + 1
        }
    }

    /// The display with the notch (the built-in one), else the main display.
    @MainActor public static var island: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    /// The screen under the pointer.
    @MainActor public static var underPointer: NSScreen? {
        let p = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) }
    }

    /// Oct 15 review, IS05 ("where you're working"): the display a press opens the island on, the
    /// one with the pointer (AppKit's point); the notch's when the pointer is on none.
    @MainActor public static func forPress(at appKitPoint: CGPoint = NSEvent.mouseLocation) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(appKitPoint, $0.frame, false) } ?? island
    }

    /// Two screens are one display.
    @MainActor public static func same(_ a: NSScreen?, _ b: NSScreen?) -> Bool {
        guard let a, let b else { return a == nil && b == nil }
        return displayID(a) == displayID(b)
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

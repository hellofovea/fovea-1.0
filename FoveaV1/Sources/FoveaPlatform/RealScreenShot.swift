import AppKit

// `Fovea --design-shots` (FoveaV1/README.md): pictures of the real screen with Fovea on it, for the
// dev team's design document. Needs Screen Recording (Fovea's own, granted in the first run).
// Under Fovea, a clean desktop: the person's own windows covered by the first run's picture, so
// nothing of theirs is in a picture; the menu bar, the Dock, the stage and the island stay above it.

@MainActor
public enum RealScreenShot {
    private static var backdrop: NSWindow?

    public static var allowed: Bool { CGPreflightScreenCaptureAccess() }

    /// The screen as the window server composites it, every window on it.
    public static func png(of screen: NSScreen) -> Data? {
        let bounds = Screens.global(CGRect(origin: .zero, size: screen.frame.size), on: screen)
        guard let image = CGWindowListCreateImage(bounds, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution]) else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    /// Without Screen Recording (each new build of Fovea loses it): Fovea's own windows on the
    /// screen, stacked as the window server stacks them, and nothing else. No menu bar, no Dock;
    /// the glass shows only what Fovea itself draws under it.
    /// Oct 27: the same, as an image (clear where Fovea draws nothing), for laying over a desktop
    /// drawn off screen, so the pictures need nothing over the person's screen.
    public static func ownWindowsImage(of screen: NSScreen) -> CGImage? {
        let pid = ProcessInfo.processInfo.processIdentifier
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return nil }
        let ids = info.compactMap { w -> CGWindowID? in
            guard (w[kCGWindowOwnerPID as String] as? pid_t) == pid else { return nil }
            return w[kCGWindowNumber as String] as? CGWindowID
        }
        var pointers = ids.map { UnsafeRawPointer(bitPattern: UInt($0)) }
        let bounds = Screens.global(CGRect(origin: .zero, size: screen.frame.size), on: screen)
        guard !ids.isEmpty, let array = CFArrayCreate(nil, &pointers, pointers.count, nil) else { return nil }
        return CGImage(windowListFromArrayScreenBounds: bounds, windowArray: array, imageOption: [.bestResolution])
    }

    public static func ownWindowsPNG(of screen: NSScreen) -> Data? {
        let pid = ProcessInfo.processInfo.processIdentifier
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return nil }
        let ids = info.compactMap { w -> CGWindowID? in
            guard (w[kCGWindowOwnerPID as String] as? pid_t) == pid else { return nil }
            return w[kCGWindowNumber as String] as? CGWindowID
        }
        var pointers = ids.map { UnsafeRawPointer(bitPattern: UInt($0)) }
        let bounds = Screens.global(CGRect(origin: .zero, size: screen.frame.size), on: screen)
        guard !ids.isEmpty, let array = CFArrayCreate(nil, &pointers, pointers.count, nil),
              let image = CGImage(windowListFromArrayScreenBounds: bounds, windowArray: array, imageOption: [.bestResolution])
        else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    /// Just above ordinary windows, below the first run's stage (floating), the Dock, the menu bar
    /// and the island; takes no clicks.
    public static func showBackdrop(on screen: NSScreen, picture: NSImage?) {
        guard backdrop == nil else { return }
        let window = BackdropPanel(screen: screen)
        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(white: 0.16, alpha: 1).cgColor
        if let picture {
            view.layer?.contents = picture
            view.layer?.contentsGravity = .resizeAspectFill
        }
        window.contentView = view
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
        backdrop = window
    }

    /// The clean desktop is what's on screen: its panel on the Space in front and a menu bar showing
    /// (not an app taken full screen), so no picture holds anything of the person's.
    public static func onCleanDesktop(_ window: NSWindow, menuBar: Bool = true) -> Bool {
        guard window.isOnActiveSpace, window.occlusionState.contains(.visible) else { return false }
        guard menuBar else { return true }
        return NSMenu.menuBarVisible() && !(window.screen.map(fullScreenSpaceInFront) ?? false)
    }

    /// A full-screen app's Space is in front (another app's window fills the screen): its menu bar
    /// is gone, the band beside the notch black, not the desktop the pictures are meant to show.
    public static func fullScreenSpaceInFront(_ screen: NSScreen) -> Bool {
        let pid = ProcessInfo.processInfo.processIdentifier
        return Screens.fullScreenWindow(on: screen) { $0 != pid }
    }

    /// Waits for the clean desktop (the person may be on another Space); false if it never comes.
    public static func waitForCleanDesktop(_ window: NSWindow, menuBar: Bool = true, timeout: Double = 45) async -> Bool {
        let end = Date().addingTimeInterval(timeout)
        var said = false
        while !onCleanDesktop(window, menuBar: menuBar) {
            if Date() > end { return false }
            if !said { print("design-shots: waiting for the desktop (another Space or a full-screen app is in front)"); said = true }
            NSApp.activate(ignoringOtherApps: true)
            try? await Task.sleep(for: .seconds(1))
        }
        return true
    }

    public static var backdropWindow: NSWindow? { backdrop }

    public static func hideBackdrop() {
        backdrop?.orderOut(nil)
        backdrop = nil
    }

    /// The notch's place on `screen`, in its top-down points, for drawing it over a picture (the
    /// hardware notch isn't in a screenshot).
    public static func notchRect(on screen: NSScreen) -> CGRect? {
        guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else { return nil }
        let width = screen.frame.width - left.width - right.width
        return CGRect(x: left.width, y: 0, width: width, height: screen.safeAreaInsets.top)
    }
}

/// The clean desktop's window: a panel, so it can join a full-screen app's Space as the island
/// does (an ordinary window can't); just above ordinary windows, below the first run's stage
/// (floating), the Dock, the menu bar and the island; it takes no clicks.
public final class BackdropPanel: NSPanel {
    public init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        collectionBehavior = NotchPanel.islandBehavior
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hasShadow = false
        hidesOnDeactivate = false
        animationBehavior = .none
        setFrame(screen.frame, display: false)
    }
    public override var canBecomeKey: Bool { false }
    public override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

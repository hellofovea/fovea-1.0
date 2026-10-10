import AppKit

// "Clear my screen", the desktop half (Oct 9, evening): a clean picture laid over the desktop's
// icons, so only the first run's practice files are on it, as the prototype's clean desktop was:
// Tahoe Day (Oct 9, late; macOS reports its own default, the Golden Gate, as the wallpaper here,
// whatever the person's is). One window just above the desktop's icons and below every ordinary
// window, so System Settings and the apps still open over it; it takes no clicks. Gone at the end,
// or when Fovea quits.

@MainActor
public enum DesktopCover {
    private static var window: NSWindow?

    public static var shown: Bool { window != nil }

    /// Covers the desktop's icons on `screen` with `picture` (Tahoe Day, Oct 9, late), or with the
    /// desktop's own color while there's none.
    public static func show(on screen: NSScreen, picture: NSImage?) {
        guard window == nil else { return }
        let iconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
        let cover = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        cover.level = NSWindow.Level(rawValue: iconLevel + 1)
        // Its own Space only: a window on every Space showed in Mission Control over the others.
        cover.collectionBehavior = [.stationary, .ignoresCycle]
        cover.ignoresMouseEvents = true
        cover.isReleasedWhenClosed = false
        cover.hasShadow = false
        cover.animationBehavior = .none
        cover.setAccessibilityIdentifier("fovea.desktop-cover")
        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(white: 0.16, alpha: 1).cgColor
        if let picture {
            view.layer?.contents = picture
            view.layer?.contentsGravity = .resizeAspectFill
        }
        cover.contentView = view
        cover.setFrame(screen.frame, display: true)
        cover.orderFront(nil)
        window = cover
    }

    /// Tahoe Day, the first run's desktop (Oct 9, late), kept on this Mac only: Apple's picture is
    /// never in Fovea's repository. `~/Library/Application Support/app.fovea/Wallpapers/`.
    nonisolated public static func tahoeDay() -> NSImage? {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = support.appendingPathComponent("app.fovea/Wallpapers", isDirectory: true)
        for name in ["Tahoe Day.png", "Tahoe Day.jpg", "Tahoe Day.heic"] {
            let url = folder.appendingPathComponent(name)
            if FileManager.default.isReadableFile(atPath: url.path), let image = NSImage(contentsOf: url) { return image }
        }
        return nil
    }

    public static func hide() {
        window?.orderOut(nil)
        window = nil
    }
}

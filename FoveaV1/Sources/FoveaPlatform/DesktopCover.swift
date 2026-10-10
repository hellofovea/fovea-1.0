import AppKit
import UniformTypeIdentifiers

// "Clear my screen", the desktop half (Oct 9, evening): the person's own wallpaper laid over the
// desktop's icons, so only the first run's practice files are on it, as the prototype's clean
// desktop was. One window just above the desktop's icons and below every ordinary window, so
// System Settings and the apps still open over it; it takes no clicks. Gone at the end, or when
// Fovea quits.

@MainActor
public enum DesktopCover {
    private static var window: NSWindow?

    public static var shown: Bool { window != nil }

    /// Covers the desktop's icons on `screen` with its wallpaper (`fallback` when the picture can't
    /// be read without asking for a protected folder).
    public static func show(on screen: NSScreen, fallback: NSImage?) {
        guard window == nil else { return }
        let iconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
        let cover = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        cover.level = NSWindow.Level(rawValue: iconLevel + 1)
        cover.collectionBehavior = [.stationary, .ignoresCycle, .canJoinAllSpaces]
        cover.ignoresMouseEvents = true
        cover.isReleasedWhenClosed = false
        cover.hasShadow = false
        cover.animationBehavior = .none
        cover.setAccessibilityIdentifier("fovea.desktop-cover")
        let view = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        let options = NSWorkspace.shared.desktopImageOptions(for: screen)
        view.layer?.backgroundColor = (options?[.fillColor] as? NSColor ?? .black).cgColor
        if let image = wallpaper(for: screen) ?? fallback {
            view.layer?.contents = image
            view.layer?.contentsGravity = .resizeAspectFill
        }
        cover.contentView = view
        cover.setFrame(screen.frame, display: true)
        cover.orderFront(nil)
        window = cover
    }

    public static func hide() {
        window?.orderOut(nil)
        window = nil
    }

    /// The desktop picture, when it can be read without a prompt: a still image outside the
    /// protected folders, or the still macOS keeps for an aerial.
    private static func wallpaper(for screen: NSScreen) -> NSImage? {
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return nil }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let guarded = ["Desktop", "Documents", "Downloads", "Library/Mobile Documents"].map { "\(home)/\($0)" }
        if guarded.contains(where: { url.path.hasPrefix($0) }) { return nil }
        let files = FileManager.default
        if UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true, files.isReadableFile(atPath: url.path) {
            return NSImage(contentsOf: url)
        }
        let still = URL(fileURLWithPath: "/Library/Application Support/com.apple.idleassetsd/snapshots")
            .appendingPathComponent("asset-preview-\(url.deletingPathExtension().lastPathComponent).jpg")
        return files.isReadableFile(atPath: still.path) ? NSImage(contentsOf: still) : nil
    }
}

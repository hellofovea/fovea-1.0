import AppKit
import FoveaCore

/// Bundled images, from FoveaCore's resources (photos, window screenshots, the app icon).
@MainActor
enum BenchResources {
    private static var cache: [String: NSImage] = [:]

    static var appIcon: NSImage? { image("AppIcon.png") }

    /// `Photos/mountain.jpg`, `Screens/fovea-home.png`, or `Art/<name>` for a capture's region
    /// drawn by CaptureArt.
    static func image(_ path: String) -> NSImage? {
        if let hit = cache[path] { return hit }
        let image: NSImage?
        if path.hasPrefix("Art/") {
            image = CaptureArt.image(String(path.dropFirst(4)))
        } else {
            image = FoveaResources.url(path).flatMap { NSImage(contentsOf: $0) }
        }
        guard let image else { return nil }
        cache[path] = image
        return image
    }
}

/// The notch's geometry on a real display, from FoveaCore.
enum NotchPlacement {
    /// The display with a notch, else the main one (a software island sits top center there).
    @MainActor static var screen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens.first
    }

    /// The notch, or the software island, in screen coordinates (AppKit, y up).
    @MainActor static func notchRect(on screen: NSScreen) -> CGRect {
        let metrics = ScreenMetrics(frame: screen.frame, visibleFrame: screen.visibleFrame,
                                    safeAreaTop: screen.safeAreaInsets.top,
                                    auxLeftWidth: screen.auxiliaryTopLeftArea?.width ?? 0,
                                    auxRightWidth: screen.auxiliaryTopRightArea?.width ?? 0)
        let spec = IslandLayoutSpec()
        let local = NotchGeometry.notchRect(metrics: metrics, spec: spec)
        return CGRect(x: screen.frame.minX + local.minX, y: screen.frame.maxY - local.maxY,
                      width: local.width, height: local.height)
    }

    @MainActor static func hasNotch(_ screen: NSScreen) -> Bool {
        screen.safeAreaInsets.top > 0 && (screen.auxiliaryTopLeftArea?.width ?? 0) > 0
    }
}

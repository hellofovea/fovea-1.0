import AppKit
import ScreenCaptureKit

// Pictures of the screen, only what the person points at: a part they dragged over, the lines
// they highlighted, or the whole screen (⌘ twice). Screen Recording's job (the first run asks for
// it). Fovea's island and its marks are left out; its own windows (the first run's practice
// windows, Home) are not, so they can be taken like any app's.

public enum ScreenCapturer {
    /// Screen Recording is allowed (known only at launch: macOS asks Fovea to quit and reopen).
    public static var allowed: Bool { CGPreflightScreenCaptureAccess() }

    /// Asks once (macOS's own prompt, which opens System Settings). Asking through Quartz alone
    /// left Fovea out of Screen & System Audio Recording's list on this Mac (Oct 9): ScreenCaptureKit
    /// is asked too, which is what puts an app in the list on the macOS of today.
    @discardableResult
    public static func request() -> Bool {
        let allowed = CGRequestScreenCaptureAccess()
        if !allowed {
            Task { _ = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) }
        }
        return allowed
    }

    public enum Failure: Error { case notAllowed, noDisplay, failed }

    /// A part of a display, in its own top-down points, at the display's pixel density.
    /// `excluding` are Fovea's surface windows (by window number) to leave out.
    @MainActor
    public static func capture(_ rect: CGRect, on screen: NSScreen, excluding windowNumbers: [Int]) async throws -> CGImage {
        guard allowed else { throw Failure.notAllowed }
        guard let displayID = Screens.displayID(screen) else { throw Failure.noDisplay }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else { throw Failure.noDisplay }
        let excluded = content.windows.filter { windowNumbers.contains(Int($0.windowID)) }
        let filter = SCContentFilter(display: display, excludingWindows: excluded)
        let config = SCStreamConfiguration()
        let scale = screen.backingScaleFactor
        let clipped = rect.intersection(CGRect(origin: .zero, size: screen.frame.size))
        guard !clipped.isEmpty else { throw Failure.failed }
        config.sourceRect = clipped
        config.width = max(1, Int(clipped.width * scale))
        config.height = max(1, Int(clipped.height * scale))
        config.showsCursor = false
        config.scalesToFit = false
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    /// PNG bytes for a picture.
    public static func png(_ image: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .png, properties: [:])
    }
}

import AppKit

// The pointer while ⌘ takes a part of the screen (the crosshair) or ⌥ highlights (the accent
// arrow), over whatever app is in front (Oct 9: pressing ⌘ has to say a picture is being taken).
// macOS lets only the app in front set the pointer; the island's panel is never in front, so the
// window server is asked to let Fovea set it from behind (the connection property screenshot and
// window tools use), and Fovea sets it again as the pointer moves, since nothing else under the
// island's panel gets the moves while it takes every click.

public enum ScreenPointer {
    public enum Style: Equatable { case system, crosshair, custom(NSCursor) }

    private static var allowed = false
    private static var current: Style = .system

    /// The pointer for now; `.system` gives it back to the app under it.
    @MainActor public static func set(_ style: Style) {
        if style != .system { allowInBackground() }
        current = style
        apply()
    }

    /// Again, as the pointer moves (an app under it may have set its own).
    @MainActor public static func reassert() {
        guard current != .system else { return }
        apply()
    }

    @MainActor private static func apply() {
        switch current {
        case .system: NSCursor.arrow.set()
        case .crosshair: NSCursor.crosshair.set()
        case .custom(let cursor): cursor.set()
        }
    }

    /// The window server's "sets cursor in background" property on Fovea's connection, looked up
    /// at run time (it's SkyLight's, not in the SDK). If it isn't there, the pointer changes only
    /// while Fovea is in front.
    private static func allowInBackground() {
        guard !allowed else { return }
        allowed = true
        typealias MainConnection = @convention(c) () -> Int32
        typealias SetProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
        guard let handle = dlopen(nil, RTLD_NOW),
              let main = dlsym(handle, "CGSMainConnectionID") ?? dlsym(handle, "_CGSDefaultConnection"),
              let setter = dlsym(handle, "CGSSetConnectionProperty") else { return }
        let connection = unsafeBitCast(main, to: MainConnection.self)()
        _ = unsafeBitCast(setter, to: SetProperty.self)(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
    }
}

extension ScreenPointer.Style {
    public static func == (a: Self, b: Self) -> Bool {
        switch (a, b) {
        case (.system, .system), (.crosshair, .crosshair): return true
        case (.custom(let x), .custom(let y)): return x === y
        default: return false
        }
    }
}

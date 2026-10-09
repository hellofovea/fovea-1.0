import AppKit
import ApplicationServices
import Carbon.HIToolbox
import FoveaKit

// What Fovea reads and does through Accessibility (the person allows it in the first run):
// where the text cursor is, so the words have somewhere to go; the words under a highlight; the
// file under the pointer; and the ⌘V that pastes. Coordinates here are Quartz's global top-left
// points; `Screens` converts.

/// The text field the person is typing in, if any.
public struct FocusedInput: Sendable {
    public var role: String?
    public var subrole: String?
    public var app: String?
    public var bundleID: String?
    /// Its frame, global top-left points.
    public var frame: CGRect?
}

public enum AXReader {
    public static var trusted: Bool { AXIsProcessTrusted() }

    /// The element holding the keyboard, when it takes text (PasteTarget's judgment).
    @MainActor public static func focusedTextInput() -> FocusedInput? {
        guard trusted else { return nil }
        let system = AXUIElementCreateSystemWide()
        guard let focused: AXUIElement = copy(system, kAXFocusedUIElementAttribute) else { return nil }
        let role: String? = copy(focused, kAXRoleAttribute)
        let subrole: String? = copy(focused, kAXSubroleAttribute)
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(focused, kAXValueAttribute as CFString, &settable)
        let editable = (copy(focused, "AXEditable") as Bool?) ?? false
        guard PasteTarget.accepts(role: role, subrole: subrole, editable: editable || (settable.boolValue && role == "AXWebArea")) else {
            return nil
        }
        var pid: pid_t = 0
        AXUIElementGetPid(focused, &pid)
        let app = NSRunningApplication(processIdentifier: pid)
        return FocusedInput(role: role, subrole: subrole, app: app?.localizedName, bundleID: app?.bundleIdentifier,
                            frame: frame(of: focused))
    }

    /// The app in front, by name and bundle ID.
    @MainActor public static var frontmostApp: (name: String, bundleID: String)? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return (app.localizedName ?? "App", app.bundleIdentifier ?? "")
    }

    /// The element of another app at a global point (Fovea's own windows skipped: the hit-test is
    /// asked of the app whose window is under the point).
    @MainActor public static func element(at point: CGPoint, excluding pid: pid_t = getpid()) -> AXUIElement? {
        guard trusted, let owner = WindowList.owner(at: point, excluding: pid) else { return nil }
        let app = AXUIElementCreateApplication(owner)
        // Chromium and Electron build their tree only when asked.
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(app, Float(point.x), Float(point.y), &element) == .success else { return nil }
        return element
    }

    /// The words between two points of a drag, line by line: each line's frame and the text.
    /// nil when the app under the drag doesn't say (a picture, a canvas).
    @MainActor public static func textRun(from a: CGPoint, to b: CGPoint) -> (lines: [CGRect], text: String)? {
        guard let element = element(at: a) ?? element(at: b) else { return nil }
        guard let start = index(at: a, in: element), let end = index(at: b, in: element) else { return nil }
        let lo = min(start, end), hi = max(start, end)
        guard hi > lo else { return nil }
        guard let text: String = string(in: element, range: CFRange(location: lo, length: hi - lo)),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var lines: [CGRect] = []
        if let first = line(at: lo, in: element), let last = line(at: hi - 1, in: element) {
            for n in first...max(first, last) {
                guard let lineRange = range(ofLine: n, in: element) else { continue }
                let s = max(lineRange.location, lo), e = min(lineRange.location + lineRange.length, hi)
                guard e > s, let r = bounds(in: element, range: CFRange(location: s, length: e - s)) else { continue }
                lines.append(r)
            }
        }
        if lines.isEmpty, let r = bounds(in: element, range: CFRange(location: lo, length: hi - lo)) { lines = [r] }
        return (lines, text)
    }

    /// The paragraph under a click: its text and the frames of its lines.
    @MainActor public static func paragraph(at point: CGPoint) -> (lines: [CGRect], text: String)? {
        guard let element = element(at: point), let i = index(at: point, in: element),
              let all: String = copy(element, kAXValueAttribute) else { return nil }
        let ns = all as NSString
        guard i <= ns.length else { return nil }
        let r = ns.paragraphRange(for: NSRange(location: min(i, max(0, ns.length - 1)), length: 0))
        let text = ns.substring(with: r).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        var lines: [CGRect] = []
        if let first = line(at: r.location, in: element), let last = line(at: r.location + max(0, r.length - 1), in: element) {
            for n in first...max(first, last) {
                if let lr = range(ofLine: n, in: element), let b = bounds(in: element, range: lr) { lines.append(b) }
            }
        }
        if lines.isEmpty, let b = bounds(in: element, range: CFRange(location: r.location, length: r.length)) { lines = [b] }
        return (lines, text)
    }

    /// The file under the pointer (a Finder icon, a desktop file): its URL and the icon's frame.
    @MainActor public static func file(at point: CGPoint) -> (url: URL, frame: CGRect?)? {
        guard var element = element(at: point) else { return nil }
        for _ in 0..<6 {
            if let url: URL = copy(element, kAXURLAttribute), url.isFileURL { return (url, frame(of: element)) }
            if let path: String = copy(element, kAXFilenameAttribute) { return (URL(fileURLWithPath: path), frame(of: element)) }
            guard let parent: AXUIElement = copy(element, kAXParentAttribute) else { break }
            element = parent
        }
        return nil
    }

    // MARK: -

    static func copy<T>(_ element: AXUIElement, _ attribute: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success, let value else { return nil }
        if T.self == AXUIElement.self, CFGetTypeID(value) == AXUIElementGetTypeID() { return (value as! T) }
        if T.self == URL.self, let url = value as? URL { return url as? T }
        return value as? T
    }

    static func frame(of element: AXUIElement) -> CGRect? {
        var pos: CFTypeRef?, size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &pos) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let pos, let size else { return nil }
        var p = CGPoint.zero, s = CGSize.zero
        AXValueGetValue(pos as! AXValue, .cgPoint, &p)
        AXValueGetValue(size as! AXValue, .cgSize, &s)
        return CGRect(origin: p, size: s)
    }

    static func parameterized<T>(_ element: AXUIElement, _ attribute: String, _ parameter: CFTypeRef) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, attribute as CFString, parameter, &value) == .success,
              let value else { return nil }
        return value as? T
    }

    static func index(at point: CGPoint, in element: AXUIElement) -> Int? {
        var p = point
        guard let param = AXValueCreate(.cgPoint, &p),
              let value: AXValue = parameterized(element, kAXRangeForPositionParameterizedAttribute, param) else { return nil }
        var range = CFRange()
        AXValueGetValue(value, .cfRange, &range)
        return range.location
    }

    static func line(at index: Int, in element: AXUIElement) -> Int? {
        let n: NSNumber? = parameterized(element, kAXLineForIndexParameterizedAttribute, index as CFNumber)
        return n?.intValue
    }

    static func range(ofLine line: Int, in element: AXUIElement) -> CFRange? {
        guard let value: AXValue = parameterized(element, kAXRangeForLineParameterizedAttribute, line as CFNumber) else { return nil }
        var range = CFRange()
        AXValueGetValue(value, .cfRange, &range)
        return range
    }

    static func string(in element: AXUIElement, range: CFRange) -> String? {
        var r = range
        guard let param = AXValueCreate(.cfRange, &r) else { return nil }
        return parameterized(element, kAXStringForRangeParameterizedAttribute, param)
    }

    static func bounds(in element: AXUIElement, range: CFRange) -> CGRect? {
        var r = range
        guard let param = AXValueCreate(.cfRange, &r),
              let value: AXValue = parameterized(element, kAXBoundsForRangeParameterizedAttribute, param) else { return nil }
        var rect = CGRect.zero
        AXValueGetValue(value, .cgRect, &rect)
        return rect.isEmpty ? nil : rect
    }
}

/// The windows on screen, from Quartz: who owns the one under a point, and its title. Names and
/// frames need no permission; titles do (Screen Recording), and are nil without it.
public enum WindowList {
    public struct Window: Sendable {
        public var id: CGWindowID
        public var pid: pid_t
        public var owner: String
        public var title: String?
        public var bounds: CGRect
        public var layer: Int
    }

    public static func onScreen() -> [Window] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return info.compactMap { d in
            guard let id = d[kCGWindowNumber as String] as? CGWindowID,
                  let pid = d[kCGWindowOwnerPID as String] as? pid_t,
                  let b = d[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
            let rect = CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)
            return Window(id: id, pid: pid, owner: d[kCGWindowOwnerName as String] as? String ?? "",
                          title: d[kCGWindowName as String] as? String, bounds: rect,
                          layer: d[kCGWindowLayer as String] as? Int ?? 0)
        }
    }

    /// The frontmost ordinary window under a global point, not Fovea's.
    public static func window(at point: CGPoint, excluding pid: pid_t = getpid()) -> Window? {
        onScreen().first { $0.pid != pid && $0.layer == 0 && $0.bounds.contains(point) }
    }

    public static func owner(at point: CGPoint, excluding pid: pid_t = getpid()) -> pid_t? {
        window(at: point, excluding: pid)?.pid
    }
}

/// The words go where the text cursor is: on the pasteboard, then ⌘V, then the pasteboard as it
/// was. Needs Accessibility (to post the key).
public enum Paster {
    @MainActor public static func paste(_ text: String) {
        let board = NSPasteboard.general
        // What was on the pasteboard, item by item, to put back.
        let saved: [[NSPasteboard.PasteboardType: Data]] = (board.pasteboardItems ?? []).map { item in
            var out: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { if let data = item.data(forType: type) { out[type] = data } }
            return out
        }
        board.clearContents()
        board.setString(text, forType: .string)
        let changed = board.changeCount
        postCommandV()
        // Put the pasteboard back once the app has read it, unless something else wrote to it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard board.changeCount == changed else { return }
            board.clearContents()
            let items = saved.map { entry -> NSPasteboardItem in
                let item = NSPasteboardItem()
                for (type, data) in entry { item.setData(data, forType: type) }
                return item
            }
            if !items.isEmpty { board.writeObjects(items) }
        }
    }

    static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let v: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    /// Text typed into a secure field (a password) is never pasted into.
    public static var secureInput: Bool { IsSecureEventInputEnabled() }
}

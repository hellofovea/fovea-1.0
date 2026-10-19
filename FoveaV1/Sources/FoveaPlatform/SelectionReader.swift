import AppKit
import ApplicationServices
import FoveaKit

// Oct 18, Ryan: words selected while Fovea listens are seen being taken, as the cursor moves, in the
// right place. What the app selected is read through Accessibility, off the main thread (the app is
// asked many times a drag), and its shape is read as the app draws it:
//  • web content (Chromium apps such as Claude, WebKit in Safari and Mail) through text markers:
//    the selection's bounds, and its first and last lines'. Their character ranges are each node's
//    own, so ranges there gave bars in the wrong places (Oct 18: shifted left of the words, not
//    matching the lines), and WebKit gives no selected text at all;
//  • Cocoa text (TextEdit, Notes, Xcode) through character ranges, line by line.
// Every rect is global, top-left, in points, as Accessibility gives it; `MarkWindow` draws them over
// the window they're in.

/// What the person selected in another app's window.
public struct SelectionRead: Equatable, Sendable {
    public var text: String
    /// The shape the selection covers, global top-left points: its first line from where it starts,
    /// the full lines between, its last line to where it ends (or each line, where the app gives them).
    public var rects: [CGRect]
    /// In a field that takes text, the focused one: where dictated words would paste, over it.
    public var editable: Bool
    /// The window it's in, and that window's bounds then (global top-left points).
    public var window: CGWindowID
    public var windowBounds: CGRect

    public init(text: String, rects: [CGRect], editable: Bool, window: CGWindowID, windowBounds: CGRect) {
        self.text = text; self.rects = rects; self.editable = editable; self.window = window; self.windowBounds = windowBounds
    }
}

/// The shape a selection covers, from its bounds and its first and last lines' bounds.
public enum SelectionShape {
    /// One line: the bounds. More: the first line from where it starts to the block's right edge,
    /// the full lines between, the last line from the block's left edge to where it ends. A last
    /// line found past the bounds (a selection ending at a line break) is left out.
    public static func make(union u: CGRect, first: CGRect?, last: CGRect?) -> [CGRect] {
        guard let first, let last, first.height > 1, !u.isEmpty else { return u.isEmpty ? [] : [u] }
        let f = first.intersection(u)
        guard !f.isNull, f.height > 1 else { return [u] }
        let endsInside = last.minY < u.maxY - 1 && last.height > 1
        let l = endsInside ? last.intersection(u) : .null
        // One line.
        if endsInside, !l.isNull, abs(l.midY - f.midY) < min(f.height, l.height) / 2 { return [u] }
        var out = [CGRect(x: f.minX, y: f.minY, width: u.maxX - f.minX, height: f.height)]
        let bottom = (endsInside && !l.isNull) ? l.minY : u.maxY
        if bottom - f.maxY > 1 { out.append(CGRect(x: u.minX, y: f.maxY, width: u.width, height: bottom - f.maxY)) }
        if endsInside, !l.isNull, l.maxX - u.minX > 1 {
            out.append(CGRect(x: u.minX, y: l.minY, width: l.maxX - u.minX, height: l.height))
        }
        return out
    }
}

/// Reading a selection through Accessibility. Every call is safe off the main thread.
public enum SelectionAX {
    /// An app that doesn't answer gets half a second, not the system's six.
    static let timeout: Float = 0.5
    /// How long web content gets to wake its tree before it's asked again (microseconds).
    static let wakeWait: useconds_t = 150_000

    /// The selection in the window under a global point (never one of `excluding`'s).
    public static func read(at point: CGPoint, excluding pid: pid_t = getpid()) -> SelectionRead? {
        guard AXIsProcessTrusted(), let window = WindowList.window(at: point, excluding: pid) else { return nil }
        let app = AXUIElementCreateApplication(window.pid)
        AXUIElementSetMessagingTimeout(app, timeout)
        guard let found = selection(among: candidates(at: point, app: app)) else { return nil }
        return SelectionRead(text: found.text, rects: found.rects, editable: editable(app, over: found.rects),
                             window: window.id, windowBounds: window.bounds)
    }

    /// Web content answers in text markers somewhere up the chain (the web area at least); its text
    /// nodes may also answer ranges, but each in its own terms (Chromium), which put the marks in the
    /// wrong places. So markers first, across the whole chain; ranges only where nothing has markers
    /// (Cocoa text).
    static func selection(among chain: [AXUIElement]) -> (text: String, rects: [CGRect])? {
        for element in chain {
            guard let range = markerRange(element) else { continue }
            guard let text: String = AXReader.parameterized(element, "AXStringForTextMarkerRange", range),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return (text.trimmingCharacters(in: .whitespacesAndNewlines), markerShape(element, range))
        }
        for element in chain {
            if let found = rangeSelection(in: element) { return found }
        }
        return nil
    }

    /// Only the words selected there (to tell a new selection from one already made).
    public static func text(at point: CGPoint, excluding pid: pid_t = getpid()) -> String? {
        guard AXIsProcessTrusted(), let window = WindowList.window(at: point, excluding: pid) else { return nil }
        let app = AXUIElementCreateApplication(window.pid)
        AXUIElementSetMessagingTimeout(app, timeout)
        let chain = candidates(at: point, app: app)
        for element in chain {
            guard let range = markerRange(element) else { continue }
            let text: String? = AXReader.parameterized(element, "AXStringForTextMarkerRange", range)
            return text?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for element in chain {
            if let text: String = AXReader.copy(element, kAXSelectedTextAttribute), !text.isEmpty {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    /// The element under the point and those above it, then the app's focused element.
    static func candidates(at point: CGPoint, app: AXUIElement) -> [AXUIElement] {
        // Chromium and Electron build their tree only when asked.
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        var out: [AXUIElement] = []
        var hit: AXUIElement?
        var found = AXUIElementCopyElementAtPosition(app, Float(point.x), Float(point.y), &hit)
        // Web content wakes its tree on the first ask (WebKit, Chromium): asked again a moment later.
        if found != .success {
            usleep(wakeWait)
            found = AXUIElementCopyElementAtPosition(app, Float(point.x), Float(point.y), &hit)
        }
        if found == .success, var element = hit {
            // A chat's words sit deep in its page: far enough up to reach the web area.
            for _ in 0..<24 {
                AXUIElementSetMessagingTimeout(element, timeout)
                out.append(element)
                guard let parent: AXUIElement = AXReader.copy(element, kAXParentAttribute) else { break }
                element = parent
            }
        }
        if let focused: AXUIElement = AXReader.copy(app, kAXFocusedUIElementAttribute) {
            AXUIElementSetMessagingTimeout(focused, timeout)
            out.append(focused)
        }
        return out
    }

    static func markerRange(_ element: AXUIElement) -> AXTextMarkerRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXSelectedTextMarkerRange" as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXTextMarkerRangeGetTypeID() else { return nil }
        return (value as! AXTextMarkerRange)
    }

    /// The words selected in a Cocoa text element and its lines, by character ranges.
    static func rangeSelection(in element: AXUIElement) -> (text: String, rects: [CGRect])? {
        guard let text: String = AXReader.copy(element, kAXSelectedTextAttribute),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var rects: [CGRect] = []
        if let value: AXValue = AXReader.copy(element, kAXSelectedTextRangeAttribute) {
            var range = CFRange()
            AXValueGetValue(value, .cfRange, &range)
            if range.length > 0 { rects = AXReader.lineFrames(in: element, from: range.location, to: range.location + range.length) }
        }
        return (text.trimmingCharacters(in: .whitespacesAndNewlines), rects)
    }

    static func markerBounds(_ element: AXUIElement, _ range: AXTextMarkerRange) -> CGRect? {
        guard let value: AXValue = AXReader.parameterized(element, "AXBoundsForTextMarkerRange", range) else { return nil }
        var rect = CGRect.zero
        AXValueGetValue(value, .cgRect, &rect)
        return rect.isNull || (rect.width <= 0 && rect.height <= 0) ? nil : rect
    }

    static func lineRange(_ element: AXUIElement, _ marker: AXTextMarker) -> AXTextMarkerRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, "AXLineTextMarkerRangeForTextMarker" as CFString, marker, &value) == .success,
              let value, CFGetTypeID(value) == AXTextMarkerRangeGetTypeID() else { return nil }
        return (value as! AXTextMarkerRange)
    }

    /// A web selection's shape: its bounds, and its first and last lines' (each clipped to it).
    static func markerShape(_ element: AXUIElement, _ range: AXTextMarkerRange) -> [CGRect] {
        guard let union = markerBounds(element, range) else { return [] }
        let start = AXTextMarkerRangeCopyStartMarker(range), end = AXTextMarkerRangeCopyEndMarker(range)
        var first: CGRect?, last: CGRect?
        if let line = lineRange(element, start) {
            first = markerBounds(element, AXTextMarkerRangeCreate(nil, start, AXTextMarkerRangeCopyEndMarker(line)))
        }
        if let line = lineRange(element, end) {
            last = markerBounds(element, AXTextMarkerRangeCreate(nil, AXTextMarkerRangeCopyStartMarker(line), end))
        }
        return SelectionShape.make(union: union, first: first, last: last)
    }

    /// Whether the selection sits in the app's focused field that takes text.
    static func editable(_ app: AXUIElement, over rects: [CGRect]) -> Bool {
        guard let focused: AXUIElement = AXReader.copy(app, kAXFocusedUIElementAttribute) else { return false }
        let role: String? = AXReader.copy(focused, kAXRoleAttribute)
        let subrole: String? = AXReader.copy(focused, kAXSubroleAttribute)
        let flag = (AXReader.copy(focused, "AXEditable") as Bool?) ?? false
        guard PasteTarget.accepts(role: role, subrole: subrole, editable: flag) else { return false }
        guard let frame = AXReader.frame(of: focused), let first = rects.first else { return true }
        return frame.insetBy(dx: -2, dy: -2).intersects(first)
    }
}

/// Reads off the main thread, in turn; a drag's reads keep only the latest waiting.
public final class SelectionReader: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.fovea.selection", qos: .userInitiated)
    private let lock = NSLock()
    private var latest: (point: CGPoint, done: @MainActor @Sendable (SelectionRead?) -> Void)?
    private var dragging = false
    /// For the smoke's own window: whose windows are never read (Fovea's, normally).
    public var excluding: pid_t = getpid()

    public init() {}

    /// One read, after any asked before it.
    public func read(at point: CGPoint, _ done: @escaping @MainActor @Sendable (SelectionRead?) -> Void) {
        let pid = excluding
        queue.async {
            let found = SelectionAX.read(at: point, excluding: pid)
            DispatchQueue.main.async { MainActor.assumeIsolated { done(found) } }
        }
    }

    /// The words selected there, after any read asked before.
    public func text(at point: CGPoint, _ done: @escaping @MainActor @Sendable (String?) -> Void) {
        let pid = excluding
        queue.async {
            let found = SelectionAX.text(at: point, excluding: pid)
            DispatchQueue.main.async { MainActor.assumeIsolated { done(found) } }
        }
    }

    /// A read while a drag goes on: one at a time, only the newest point waiting for its turn.
    public func readLatest(at point: CGPoint, _ done: @escaping @MainActor @Sendable (SelectionRead?) -> Void) {
        lock.lock()
        latest = (point, done)
        let start = !dragging
        dragging = true
        lock.unlock()
        guard start else { return }
        drain()
    }

    private func drain() {
        let pid = excluding
        queue.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            guard let next = self.latest else { self.dragging = false; self.lock.unlock(); return }
            self.latest = nil
            self.lock.unlock()
            let found = SelectionAX.read(at: next.point, excluding: pid)
            DispatchQueue.main.async { MainActor.assumeIsolated { next.done(found) } }
            self.drain()
        }
    }
}

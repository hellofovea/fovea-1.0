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

    /// Oct 18, Ryan: a text field under the pointer, where dictated words land ("the place where the
    /// user's mouse is hovering at the very last moment before sending").
    public struct TextField {
        public let element: AXUIElement
        public let pid: pid_t
        /// Its frame, global top-left points.
        public let frame: CGRect?
        /// It already holds the keyboard.
        public let focused: Bool
    }

    /// The field that takes text under a global point: the element there, or the nearest above it
    /// that does (a text field or area, a combo or search box, an editable web area or its editable
    /// root). Never a secure field, never one of Fovea's own.
    @MainActor public static func textField(at point: CGPoint) -> TextField? {
        guard trusted, let owner = WindowList.owner(at: point) else { return nil }
        let app = AXUIElementCreateApplication(owner)
        AXUIElementSetMessagingTimeout(app, 0.5)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(app, Float(point.x), Float(point.y), &hit) == .success, var element = hit else { return nil }
        for _ in 0..<12 {
            AXUIElementSetMessagingTimeout(element, 0.5)
            if let field = takesText(element) {
                let focused: AXUIElement? = copy(app, kAXFocusedUIElementAttribute)
                return TextField(element: field, pid: owner, frame: frame(of: field),
                                 focused: focused.map { CFEqual($0, field) } ?? false)
            }
            guard let parent: AXUIElement = copy(element, kAXParentAttribute) else { break }
            element = parent
        }
        return nil
    }

    /// The element itself when it takes text, or the editable root it's in (web content).
    static func takesText(_ element: AXUIElement) -> AXUIElement? {
        let role: String? = copy(element, kAXRoleAttribute)
        let subrole: String? = copy(element, kAXSubroleAttribute)
        if subrole == "AXSecureTextField" { return nil }
        if let root: AXUIElement = copy(element, "AXEditableAncestor") { return root }
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
        let editable = (copy(element, "AXEditable") as Bool?) ?? false
        let accepts = PasteTarget.accepts(role: role, subrole: subrole, editable: editable || (settable.boolValue && role == "AXWebArea"))
        return accepts ? element : nil
    }

    /// Brings a field forward to take the words: its app in front, its window raised and main, the
    /// field focused. Never a click.
    @MainActor public static func focus(_ field: TextField) {
        let app = AXUIElementCreateApplication(field.pid)
        AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        if let window: AXUIElement = copy(field.element, kAXWindowAttribute) {
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }
        AXUIElementSetAttributeValue(field.element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        NSRunningApplication(processIdentifier: field.pid)?.activate()
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

    // MARK: Oct 17, Ryan: words and files with no key

    // Oct 18, Ryan: what the person selected is read by `SelectionAX` (SelectionReader.swift), off
    // the main thread: text markers for web content, character ranges (below) for Cocoa text.

    /// The frames of the lines a range runs across, as a selection is drawn.
    static func lineFrames(in element: AXUIElement, from lo: Int, to hi: Int) -> [CGRect] {
        var lines: [CGRect] = []
        if let first = line(at: lo, in: element), let last = line(at: max(lo, hi - 1), in: element) {
            for n in first...max(first, last) {
                guard let lineRange = range(ofLine: n, in: element) else { continue }
                let s = max(lineRange.location, lo), e = min(lineRange.location + lineRange.length, hi)
                guard e > s, let r = bounds(in: element, range: CFRange(location: s, length: e - s)) else { continue }
                lines.append(r)
            }
        }
        if lines.isEmpty, let r = bounds(in: element, range: CFRange(location: lo, length: hi - lo)) { lines = [r] }
        return lines
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
    /// Oct 17, Ryan ("paste them after the words"): one part of what a dictation pastes, in turn,
    /// into the same field: words, a picture (PNG), or a file.
    public enum Piece: Equatable, Sendable {
        case text(String)
        case image(Data)
        case file(URL)
    }

    /// How long the app in front gets to read one piece before the next is put on the pasteboard.
    static let pieceGap: Duration = .milliseconds(220)
    /// How long the last piece stays before the pasteboard is put back.
    static let restoreAfter: Duration = .milliseconds(600)

    @MainActor public static func paste(_ text: String) {
        Task { await paste([.text(text)]) }
    }

    /// Each piece in turn: on the pasteboard, then ⌘V; the pasteboard as it was once the last has
    /// been read (unless something else wrote to it). The words go first, so a field that takes
    /// text only still gets them when it refuses a picture or a file.
    @MainActor public static func paste(_ pieces: [Piece]) async {
        let board = NSPasteboard.general
        // What was on the pasteboard, item by item, to put back.
        let saved: [[NSPasteboard.PasteboardType: Data]] = (board.pasteboardItems ?? []).map { item in
            var out: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { if let data = item.data(forType: type) { out[type] = data } }
            return out
        }
        for (i, piece) in pieces.enumerated() {
            if i > 0 { try? await Task.sleep(for: pieceGap) }
            board.clearContents()
            switch piece {
            case .text(let text):
                board.setString(text, forType: .string)
            case .image(let png):
                let item = NSPasteboardItem()
                item.setData(png, forType: .png)
                if let tiff = NSImage(data: png)?.tiffRepresentation { item.setData(tiff, forType: .tiff) }
                board.writeObjects([item])
            case .file(let url):
                board.writeObjects([url as NSURL])
            }
            postCommandV()
        }
        let changed = board.changeCount
        // Put the pasteboard back once the app has read it, unless something else wrote to it.
        try? await Task.sleep(for: restoreAfter)
        guard board.changeCount == changed else { return }
        board.clearContents()
        let items = saved.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entry { item.setData(data, forType: type) }
            return item
        }
        if !items.isEmpty { board.writeObjects(items) }
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

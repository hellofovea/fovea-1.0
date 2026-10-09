import AppKit
import CoreGraphics

// The few keys the island takes for itself while it's open, from any app: Esc steps out, the
// arrows and Return work Choose chat and the board, ⌘Z undoes a cancel. A session event tap sees
// them before the app in front does, and keeps them only when the island says it used them; every
// other key goes on as it was. It needs Accessibility; before that the island's own window still
// sees its keys (a local monitor), and the tap is made again when the person allows it.

@MainActor
public final class KeyboardTap {
    /// Return true to keep the key from the app in front.
    public var handler: ((NSEvent) -> Bool)?
    public private(set) var isRunning = false
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var local: Any?

    public init() {}

    /// Starts the tap (when Accessibility allows it) and the local monitor. Safe to call again:
    /// a tap that couldn't be made is tried once more.
    public func start() {
        if local == nil {
            local = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, !self.isRunning else { return event }
                return self.handler?(event) == true ? nil : event
            }
        }
        guard tap == nil, AXIsProcessTrusted() else { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let me = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                           eventsOfInterest: mask, callback: keyboardTapCallback, userInfo: me) else { return }
        tap = port
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        isRunning = true
    }

    public func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        isRunning = false
        if let local { NSEvent.removeMonitor(local) }
        local = nil
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown, let ns = NSEvent(cgEvent: event) else { return Unmanaged.passUnretained(event) }
        // Fovea's own windows get their keys the usual way (a field in a pulled-out chat).
        if NSApp.isActive, NSApp.keyWindow?.firstResponder is NSTextView { return Unmanaged.passUnretained(event) }
        return handler?(ns) == true ? nil : Unmanaged.passUnretained(event)
    }
}

private func keyboardTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<KeyboardTap>.fromOpaque(refcon).takeUnretainedValue()
    return MainActor.assumeIsolated { tap.handle(type, event) }
}

/// Polls a permission until it changes, for the moments Fovea waits on the person in System
/// Settings (Accessibility is seen live, without a relaunch).
@MainActor
public final class PermissionWatcher {
    private var timer: Timer?
    private var last: [Permission: Bool] = [:]
    public var onChange: ((Permission, Bool) -> Void)?

    public init() {}

    public func start(interval: TimeInterval = 0.5) {
        for p in Permission.allCases { last[p] = p.granted }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    public func stop() { timer?.invalidate(); timer = nil }

    private func poll() {
        for p in [Permission.accessibility, .microphone, .speechRecognition] {
            let now = p.granted
            if last[p] != now {
                last[p] = now
                onChange?(p, now)
            }
        }
    }
}

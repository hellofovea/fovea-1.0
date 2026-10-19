import AppKit
import Carbon.HIToolbox

/// The first run's own keys: the modifiers held, to light the guide's keycaps; and Return, Esc and
/// space in Fovea's windows (Continue; the microphone test's space for a Mac without one). fn, fn ⌃,
/// ⌘ and left ⌥ are the real island's (FoveaIsland), heard as its events.
@MainActor
final class KeyRig {
    var onFlags: (Set<String>) -> Void = { _ in }
    var onReturn: () -> Bool = { false }
    var onEscape: () -> Bool = { false }
    /// ⌘[: Back, on the pages that have it (Oct 15 review, OB-01.7).
    var onBack: () -> Bool = { false }
    /// Space down or up: talking, for the microphone test on a Mac without a microphone.
    var onSpace: (_ down: Bool) -> Bool = { _ in false }
    private var monitors: [Any] = []

    func start() {
        if let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.onFlags(Self.labels(event.modifierFlags))
            return event
        }) { monitors.append(local) }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.onFlags(Self.labels(event.modifierFlags))
        }) { monitors.append(global) }
        if let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard let self else { return event }
            return self.handleKey(event) ? nil : event
        }) { monitors.append(keys) }
        if let ups = NSEvent.addLocalMonitorForEvents(matching: .keyUp, handler: { [weak self] event in
            guard let self, Int(event.keyCode) == kVK_Space else { return event }
            return self.onSpace(false) ? nil : event
        }) { monitors.append(ups) }
    }

    func stop() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
    }

    func handleKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.numericPad, .function])
        // ⌘[ goes Back, as in Finder and Safari, even from a box (a text box has no use for it).
        if Int(event.keyCode) == kVK_ANSI_LeftBracket, flags == .command { return onBack() }
        // Typing in a box (the language under More…): Return and space are the box's.
        if event.window?.firstResponder is NSTextView { return false }
        switch Int(event.keyCode) {
        case kVK_Return where flags.isEmpty, kVK_ANSI_KeypadEnter: return onReturn()
        case kVK_Escape where flags.isEmpty: return onEscape()
        case kVK_Space where flags.isEmpty && !event.isARepeat: return onSpace(true)
        case kVK_Space where event.isARepeat: return true
        default: return false
        }
    }

    static func labels(_ flags: NSEvent.ModifierFlags) -> Set<String> {
        var down: Set<String> = []
        if flags.contains(.function) { down.insert("fn") }
        if flags.contains(.control) { down.insert("⌃") }
        if flags.contains(.option) { down.insert("⌥") }
        if flags.contains(.command) { down.insert("⌘") }
        return down
    }
}

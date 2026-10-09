import AppKit
import Carbon.HIToolbox

/// The first run's keys, from the copied monitors: fn alone (dictation, or asking more), fn ⌃ (a
/// request), ⌘ either side (a screenshot: a tap for one drag, held while dragging, twice for the
/// whole screen), left ⌥ (the highlighter: a tap for one mark, held while dragging), and Return
/// and Esc in the window. The modifiers held light the guide's keycaps.
@MainActor
final class KeyRig {
    var onRequest: () -> Void = {}
    var onDictation: () -> Void = {}
    var onCommandDown: () -> Void = {}
    var onCommandUp: (_ tap: Bool) -> Void = { _ in }
    var onCommandDouble: () -> Void = {}
    var onOptionDown: () -> Void = {}
    var onOptionUp: (_ tap: Bool) -> Void = { _ in }
    var onFlags: (Set<String>) -> Void = { _ in }
    var onReturn: () -> Bool = { false }
    var onEscape: () -> Bool = { false }
    /// Space down or up: talking, for the microphone test on a Mac without a microphone.
    var onSpace: (_ down: Bool) -> Bool = { _ in false }

    let fn = ModifierPressMonitor.function()
    let leftCommand = ModifierHoldMonitor.leftCommand()
    let rightCommand = ModifierHoldMonitor.rightCommand()
    let leftOption = ModifierHoldMonitor.leftOption()
    private var monitors: [Any] = []

    func start() {
        wire()
        fn.start()
        leftCommand.start()
        rightCommand.start()
        leftOption.start()
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

    /// The closures each monitor calls. Separate from `start` so the smoke run can feed the
    /// monitors synthetic edges without installing event monitors.
    func wire() {
        fn.onPress = { [weak self] in
            guard let self else { return }
            if self.fn.heldDuring.contains(.control) { self.onRequest() } else { self.onDictation() }
        }
        for command in [leftCommand, rightCommand] {
            command.onDown = { [weak self] in self?.onCommandDown() }
            command.onUp = { [weak self] tap in self?.onCommandUp(tap) }
            command.onDoublePress = { [weak self] in self?.onCommandDouble() }
        }
        leftOption.onDown = { [weak self] in self?.onOptionDown() }
        leftOption.onUp = { [weak self] tap in self?.onOptionUp(tap) }
    }

    func handleKey(_ event: NSEvent) -> Bool {
        // Typing in a box (the language under More…): Return and space are the box's.
        if event.window?.firstResponder is NSTextView { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.numericPad, .function])
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

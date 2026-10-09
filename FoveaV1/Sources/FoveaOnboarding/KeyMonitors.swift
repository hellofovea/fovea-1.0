// Copied from Prototypes/FoveaWorkbench/KeyMonitors.swift on Oct 7, without the Workbench's own
// key monitor; it may drift. The onboarding adds nothing to these: its steps listen through the
// closures, set in OnboardingModel.startKeys().
import AppKit
import Carbon.HIToolbox

/// A modifier key used on its own as a press-to-toggle key: a bare press, the key down then up
/// with no other key in between, fires once on release; the key held as a modifier for another
/// key (fn+←, ⌃Tab) does not. The local monitor sees the workbench's own events and needs no
/// permission; the global one sees other apps' events once the process is trusted for
/// Accessibility, and is harmless otherwise.
///
/// fn (Globe): the system's own Globe action (the emoji picker or dictation) is not swallowed
/// here, since that takes an event tap (Fovea's `FunctionKeyTap`): set System Settings ›
/// Keyboard › "Press 🌐 key to" to Do Nothing if it gets in the way.
/// Right Control: told apart from the left one by its key code and its device flag.
@MainActor
final class ModifierPressMonitor {
    var onPress: () -> Void = {}
    /// The other modifiers held at some point during the last press: fn⌃ is fn's press with ⌃
    /// among them (and ⌃'s press with fn among them, so it isn't ⌃ alone).
    private(set) var heldDuring: NSEvent.ModifierFlags = []
    private let keyCode: Int
    private let isDown: (NSEvent) -> Bool
    private var monitors: [Any] = []
    private var down = false
    private var usedWithKey = false

    init(keyCode: Int, isDown: @escaping (NSEvent) -> Bool) {
        self.keyCode = keyCode
        self.isDown = isDown
    }

    /// fn (Globe).
    static func function() -> ModifierPressMonitor {
        ModifierPressMonitor(keyCode: kVK_Function) { $0.modifierFlags.contains(.function) }
    }

    /// Right Control. `NX_DEVICERCTLKEYMASK` marks the right key in the device-dependent flags.
    static let rightControlDeviceFlag: UInt = 0x0000_2000
    static func rightControl() -> ModifierPressMonitor {
        ModifierPressMonitor(keyCode: kVK_RightControl) { $0.modifierFlags.rawValue & rightControlDeviceFlag != 0 }
    }

    /// Left Control, a MacBook's only one. `NX_DEVICELCTLKEYMASK` marks it.
    static let leftControlDeviceFlag: UInt = 0x0000_0001
    static func leftControl() -> ModifierPressMonitor {
        ModifierPressMonitor(keyCode: kVK_Control) { $0.modifierFlags.rawValue & leftControlDeviceFlag != 0 }
    }

    var isRunning: Bool { !monitors.isEmpty }

    func start() {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
            return event
        }) {
            monitors.append(local)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
        }) {
            monitors.append(global)
        }
    }

    func stop() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
    }

    /// One key event. Public so the smoke can feed it the edges a press produces.
    func handle(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            if down { usedWithKey = true }
        case .flagsChanged where Int(event.keyCode) == keyCode:
            if isDown(event) {
                if !down {
                    down = true
                    usedWithKey = false
                    heldDuring = []
                }
                heldDuring.formUnion(Self.others(event, than: keyCode))
            } else if down {
                down = false
                if !usedWithKey { onPress() }
            }
        case .flagsChanged where down:
            heldDuring.formUnion(Self.others(event, than: keyCode))
        default:
            break
        }
    }

    /// The modifiers down in an event besides this key's own.
    private static func others(_ event: NSEvent, than keyCode: Int) -> NSEvent.ModifierFlags {
        var flags = event.modifierFlags.intersection([.function, .control, .option, .command, .shift])
        if keyCode == kVK_Function { flags.remove(.function) }
        if keyCode == kVK_Control || keyCode == kVK_RightControl { flags.remove(.control) }
        return flags
    }
}

/// A modifier key pressed: down as it happens, up with whether it was a click (short, nothing
/// pressed or clicked with it) or a hold, and a double click (two clicks within a moment) as its
/// own action. Left Option: a click turns capture on or off, a hold is capture while held, a
/// double click takes the whole screen.
@MainActor
final class ModifierHoldMonitor {
    var onDown: () -> Void = {}
    var onUp: (_ click: Bool) -> Void = { _ in }
    var onDoublePress: () -> Void = {}
    private let keyCode: Int
    private let isDown: (NSEvent) -> Bool
    private var monitors: [Any] = []
    private var down = false
    private var downAt = Date.distantPast
    private var usedWithKey = false
    private var lastTap: Date?

    init(keyCode: Int, isDown: @escaping (NSEvent) -> Bool) {
        self.keyCode = keyCode
        self.isDown = isDown
    }

    /// Left Option. `NX_DEVICELALTKEYMASK` marks it.
    static let leftOptionDeviceFlag: UInt = 0x0000_0020
    static func leftOption() -> ModifierHoldMonitor {
        ModifierHoldMonitor(keyCode: kVK_Option) { $0.modifierFlags.rawValue & leftOptionDeviceFlag != 0 }
    }

    /// ⌘, either side (`NX_DEVICELCMDKEYMASK`, `NX_DEVICERCMDKEYMASK`): tapped alone on a voice
    /// bar, it picks text or a file (feedback #3). A ⌘ held for a shortcut or a ⌘-click is not a tap.
    static let leftCommandDeviceFlag: UInt = 0x0000_0008
    static let rightCommandDeviceFlag: UInt = 0x0000_0010
    static func leftCommand() -> ModifierHoldMonitor {
        ModifierHoldMonitor(keyCode: kVK_Command) { $0.modifierFlags.rawValue & leftCommandDeviceFlag != 0 }
    }
    static func rightCommand() -> ModifierHoldMonitor {
        ModifierHoldMonitor(keyCode: kVK_RightCommand) { $0.modifierFlags.rawValue & rightCommandDeviceFlag != 0 }
    }

    var isRunning: Bool { !monitors.isEmpty }

    func start() {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown]
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
            return event
        }) {
            monitors.append(local)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
        }) {
            monitors.append(global)
        }
    }

    /// One key event. Public so the smoke can feed it the edges a hold produces.
    func handle(_ event: NSEvent) {
        switch event.type {
        case .keyDown, .leftMouseDown, .rightMouseDown:
            // Something pressed or clicked while it is down: a hold, not a click of the key.
            if down { usedWithKey = true }
        case .flagsChanged where Int(event.keyCode) == keyCode:
            if isDown(event) {
                if !down {
                    down = true
                    downAt = Date()
                    usedWithKey = false
                    onDown()
                }
            } else if down {
                down = false
                // A click: short, nothing pressed with it. Two within the window are a double click.
                let tap = !usedWithKey && Date().timeIntervalSince(downAt) < OT.Timing.tapLength
                onUp(tap)
                guard tap else { lastTap = nil; return }
                if let last = lastTap, Date().timeIntervalSince(last) < OT.Timing.doubleTapWindow {
                    lastTap = nil
                    onDoublePress()
                } else {
                    lastTap = Date()
                }
            }
        default:
            break
        }
    }
}

/// The pointer's moves, wherever the workbench is among the apps: a notch answers the pointer
/// whether or not its app is in front. Watching the mouse needs no permission.
final class PointerMonitor {
    var onMove: (CGPoint) -> Void = { _ in }
    private var monitors: [Any] = []

    var isRunning: Bool { !monitors.isEmpty }

    func start() {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.onMove(NSEvent.mouseLocation)
            return event
        }) {
            monitors.append(local)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            self?.onMove(NSEvent.mouseLocation)
        }) {
            monitors.append(global)
        }
    }
}

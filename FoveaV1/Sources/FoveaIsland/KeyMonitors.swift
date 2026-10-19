import AppKit
import Carbon.HIToolbox
import FoveaKit

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

    func stop() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
    }

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
                let tap = !usedWithKey && Date().timeIntervalSince(downAt) < WorkbenchTokens.Capture.tapLength
                onUp(tap)
                guard tap else { lastTap = nil; return }
                if let last = lastTap, Date().timeIntervalSince(last) < WorkbenchTokens.Capture.doubleTapWindow {
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

/// Choose chat's keys: the arrows move the highlight, Return chooses (or, closed, sends),
/// ⌘Return sends.
enum ChatKey {
    case up, down, left, right, enter, send
}

/// The workbench window's own keys, seen before the views: Esc closes the innermost thing
/// (the close look, the opened stack) or cancels the request on the bar; ⌘Z undoes a cancel; ⌃Tab / ⌃⇧Tab and ⌘⇧] / ⌘⇧[ switch Safari tabs,
/// as Safari does; the arrows and Return work Choose chat while it shows. Everything else passes through.
@MainActor
final class WorkbenchKeyMonitor {
    /// Returns true when the key was used.
    var onEscape: () -> Bool = { false }
    var onTabStep: (Int) -> Bool = { _ in false }
    /// ⌘Z: undo a cancel while it can be undone.
    var onUndo: () -> Bool = { false }
    var onChatKey: (ChatKey) -> Bool = { _ in false }
    private var monitor: Any?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        }
    }

    func handle(_ event: NSEvent) -> Bool {
        // Typing in a field (a pulled-out chat's follow-up box): its keys are its own.
        if NSApp.keyWindow?.firstResponder is NSTextView { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // The arrow keys carry these two on every press.
        let plain = flags.subtracting([.numericPad, .function]).isEmpty
        switch Int(event.keyCode) {
        case kVK_UpArrow where plain: return onChatKey(.up)
        case kVK_DownArrow where plain: return onChatKey(.down)
        case kVK_LeftArrow where plain: return onChatKey(.left)
        case kVK_RightArrow where plain: return onChatKey(.right)
        case kVK_Return where flags.isEmpty, kVK_ANSI_KeypadEnter where plain: return onChatKey(.enter)
        case kVK_Return where flags == [.command]: return onChatKey(.send)
        case kVK_Escape where flags.isEmpty:
            return onEscape()
        case kVK_Tab where flags.contains(.control):
            return onTabStep(flags.contains(.shift) ? -1 : 1)
        case kVK_ANSI_RightBracket where flags == [.command, .shift]:
            return onTabStep(1)
        case kVK_ANSI_LeftBracket where flags == [.command, .shift]:
            return onTabStep(-1)
        case kVK_ANSI_Z where flags == [.command]:
            return onUndo()
        default:
            return false
        }
    }
}

// MARK: - Changeable shortcuts (Oct 15 review, ST-03.1)

// Oct 15 review, ST-03.1: Voiceflow, Dispatch, the region (⌘) and the highlighter (left ⌥) answer
// to the chords Settings › Shortcuts records (`FoveaKeys.chord`), not to fixed keys. Modifiers
// alone work as fn always has: a press (a key down, then up, with no other key or click while it
// was down, the chord's other caps held with it) starts, the next stops; the region and the
// highlighter keep ⌘'s and ⌥'s down, up (a tap or a hold) and double press (`ModifierGesture`). A
// chord with a key (⌥ Space) acts on the key's down, and only then is the key kept from the app in
// front. A cleared chord does nothing.

/// The modifier keys, each side apart: a chord names them ("fn", "⌃", "right ⌥"), an event's
/// flags say which are down.
struct ModifierKeys: OptionSet, Hashable {
    let rawValue: UInt16
    init(rawValue: UInt16) { self.rawValue = rawValue }

    static let fn = ModifierKeys(rawValue: 1 << 0)
    static let leftControl = ModifierKeys(rawValue: 1 << 1)
    static let rightControl = ModifierKeys(rawValue: 1 << 2)
    static let leftOption = ModifierKeys(rawValue: 1 << 3)
    static let rightOption = ModifierKeys(rawValue: 1 << 4)
    static let leftShift = ModifierKeys(rawValue: 1 << 5)
    static let rightShift = ModifierKeys(rawValue: 1 << 6)
    static let leftCommand = ModifierKeys(rawValue: 1 << 7)
    static let rightCommand = ModifierKeys(rawValue: 1 << 8)
    static let control: ModifierKeys = [.leftControl, .rightControl]
    static let option: ModifierKeys = [.leftOption, .rightOption]
    static let shift: ModifierKeys = [.leftShift, .rightShift]
    static let command: ModifierKeys = [.leftCommand, .rightCommand]
    static let left: ModifierKeys = [.leftControl, .leftOption, .leftShift, .leftCommand]
    static let right: ModifierKeys = [.rightControl, .rightOption, .rightShift, .rightCommand]

    /// `NX_DEVICE…KEYMASK`: which side of each modifier is down, in the device-dependent flags.
    private static let sides: [(ModifierKeys, UInt)] = [
        (.leftControl, 0x0001), (.leftShift, 0x0002), (.rightShift, 0x0004), (.leftCommand, 0x0008),
        (.rightCommand, 0x0010), (.leftOption, 0x0020), (.rightOption, 0x0040), (.rightControl, 0x2000),
    ]

    /// The keys down in an event's flags. A flag without its side (as some apps post them) is the
    /// left key, the one every Mac has.
    init(flags: NSEvent.ModifierFlags) {
        var keys: ModifierKeys = flags.contains(.function) ? .fn : []
        let raw = flags.rawValue
        let kinds: [(NSEvent.ModifierFlags, ModifierKeys)] = [(.control, .control), (.option, .option),
                                                              (.shift, .shift), (.command, .command)]
        for (flag, both) in kinds where flags.contains(flag) {
            var found: ModifierKeys = []
            for (key, bit) in Self.sides where both.contains(key) && raw & bit != 0 { found.insert(key) }
            keys.formUnion(found.isEmpty ? both.intersection(.left) : found)
        }
        self = keys
    }

    /// Each key on its own.
    var keys: [ModifierKeys] {
        (0..<9).map { ModifierKeys(rawValue: 1 << $0) }.filter { contains($0) }
    }

    /// One cap as a chord writes it ("fn", "⌃", "left ⌥", "right ⌘"…); nil for one Fovea can't read.
    static func cap(_ cap: String) -> ModifierKeys? {
        let words = cap.lowercased().split(separator: " ").map(String.init)
        guard let symbol = words.last, words.count <= 2 else { return nil }
        let both: ModifierKeys
        switch symbol {
        case "fn", "🌐", "globe": return words.count == 1 ? .fn : nil
        case "⌃", "ctrl", "control": both = .control
        case "⌥", "opt", "option", "alt": both = .option
        case "⇧", "shift": both = .shift
        case "⌘", "cmd", "command": both = .command
        default: return nil
        }
        switch words.count == 2 ? words[0] : nil {
        case nil: return both
        case "left": return both.intersection(.left)
        case "right": return both.intersection(.right)
        default: return nil
        }
    }
}

/// A recorded chord, ready to match: each cap's keys, and the key pressed with them (if any).
struct ChordPattern: Equatable {
    let caps: [ModifierKeys]
    let keyCode: Int?

    /// nil for a cleared chord (no keys at all) or one with a cap Fovea can't read: it does nothing.
    init?(_ chord: KeyChord?) {
        guard let chord, !(chord.modifiers.isEmpty && chord.keyCode == nil) else { return nil }
        var caps: [ModifierKeys] = []
        for cap in chord.modifiers {
            guard let keys = ModifierKeys.cap(cap) else { return nil }
            caps.append(keys)
        }
        self.caps = caps
        keyCode = chord.keyCode
    }

    var allowed: ModifierKeys { caps.reduce([]) { $0.union($1) } }
    /// Each cap held, whatever else is.
    func held(_ down: ModifierKeys) -> Bool { caps.allSatisfy { !down.intersection($0).isEmpty } }
    /// Exactly these modifiers: each cap held, and nothing else.
    func matches(_ down: ModifierKeys) -> Bool { held(down) && down.subtracting(allowed).isEmpty }
}

/// Fovea's changeable shortcuts, from any app: the modifiers through NSEvent's monitors (as fn's
/// always were), a chord's key through the keyboard tap (`handleKey`), which may keep it.
@MainActor
final class ShortcutMonitor {
    /// What a shortcut does. A toggle acts once a press (on the modifiers' release, or its key's
    /// down) and says whether the press was its; a hold has a down, an up (a tap or not) and a
    /// double press, as ⌘ has.
    struct Action {
        enum Kind { case toggle, hold }
        var kind: Kind
        var toggle: () -> Bool = { false }
        /// A hold's key is taken from the app in front only while this holds (on a voice bar).
        var active: () -> Bool = { true }
        var down: () -> Void = {}
        var up: (_ tap: Bool) -> Void = { _ in }
        var doublePress: () -> Void = {}
    }

    var actions: [String: Action] = [:]
    /// Nothing acts (Settings › Shortcuts is recording one).
    var paused: () -> Bool = { false }
    /// The chords in force, by shortcut, in `order` (the first of two equal chords wins).
    private(set) var patterns: [String: ChordPattern] = [:]
    private var order: [String] = []
    private var monitors: [Any] = []
    /// The modifiers down now.
    private var down: ModifierKeys = []
    /// Each modifier key's own press, as fn's monitor always had it: the others held at some point
    /// while it was down, whether a key or a click came while it was down, and whether a shortcut
    /// already fired from the keys held with it (the last to go up doesn't fire it twice).
    private var heldWith: [UInt16: ModifierKeys] = [:]
    private var usedWith: Set<UInt16> = []
    private var spent: Set<UInt16> = []
    private var gestures: [String: ModifierGesture] = [:]
    /// Holds under way: by their modifiers, and by a chord's key.
    private var holding: Set<String> = []
    private var keyHolds: [Int: String] = [:]
    /// Keys whose down was ours: their repeats and their up are kept too.
    private var kept: Set<Int> = []

    var isRunning: Bool { !monitors.isEmpty }

    /// The chords now, by shortcut id, in the order given; one that changed starts afresh (a hold
    /// under way is let go).
    func set(_ chords: [(id: String, chord: KeyChord?)]) {
        var next: [String: ChordPattern] = [:]
        for (id, chord) in chords { if let pattern = ChordPattern(chord) { next[id] = pattern } }
        order = chords.map(\.id)
        guard next != patterns else { return }
        for id in Set(patterns.keys).union(next.keys) where patterns[id] != next[id] {
            if holding.remove(id) != nil { actions[id]?.up(false) }
            gestures[id] = nil
            keyHolds = keyHolds.filter { $0.value != id }
        }
        patterns = next
    }

    func chord(_ id: String) -> ChordPattern? { patterns[id] }

    /// A shortcut is these modifiers pressed alone (left ⌃ alone stays Choose chat's only if not).
    func claims(_ keys: ModifierKeys) -> Bool {
        patterns.values.contains { $0.keyCode == nil && $0.matches(keys) }
    }

    func start() {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
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
        down = []
        heldWith = [:]
        usedWith = []
        spent = []
    }

    /// One event from the monitors (the smoke feeds it the edges a press makes).
    func handle(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            modifiers(ModifierKeys(flags: event.modifierFlags), at: event.timestamp)
        case .keyDown:
            // A chord's own key is the tap's to judge (`handleKey`).
            guard !kept.contains(Int(event.keyCode)) else { return }
            used(except: Int(event.keyCode))
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            used(except: nil)
        default:
            break
        }
    }

    /// Something pressed or clicked during a press: the modifiers weren't pressed alone, and a hold
    /// under way is a hold, not a tap.
    private func used(except keyCode: Int?) {
        for key in down.keys { usedWith.insert(key.rawValue) }
        for id in holding { gestures[id]?.used() }
        // Oct 18, Ryan: two presses are a double press only with nothing between them.
        for (id, gesture) in gestures where !gesture.isDown && !holding.contains(id) { gestures[id] = ModifierGesture() }
        for (code, id) in keyHolds where code != keyCode { gestures[id]?.used() }
    }

    private func modifiers(_ new: ModifierKeys, at t: TimeInterval) {
        let old = down
        down = new
        for key in new.subtracting(old).keys {
            heldWith[key.rawValue] = []
            usedWith.remove(key.rawValue)
            spent.remove(key.rawValue)
        }
        for key in new.keys { heldWith[key.rawValue, default: []].formUnion(new.subtracting(key)) }
        // Oct 18, Ryan: another modifier pressed between two presses breaks their double press.
        let pressed = new.subtracting(old)
        if !pressed.isEmpty {
            for (id, gesture) in gestures where !gesture.isDown && !holding.contains(id) {
                if !pressed.subtracting(patterns[id]?.allowed ?? []).isEmpty { gestures[id] = ModifierGesture() }
            }
        }
        // Holds by their modifiers: let go once a cap is up; started the moment the chord is held
        // exactly (as ⌘'s down always started capture).
        for id in order {
            guard let pattern = patterns[id], pattern.keyCode == nil, actions[id]?.kind == .hold else { continue }
            if holding.contains(id) {
                if !pattern.held(new) {
                    holding.remove(id)
                    release(id, at: t)
                } else if !new.subtracting(pattern.allowed).isEmpty {
                    gestures[id]?.used()
                }
            } else if pattern.matches(new), !pattern.held(old), !paused() {
                holding.insert(id)
                var gesture = gestures[id] ?? ModifierGesture()
                let edges = gesture.down(at: t)
                gestures[id] = gesture
                if edges.contains(.down) { actions[id]?.down() }
            }
        }
        // Toggles by their modifiers, as fn always worked: one of the chord's keys let go after a
        // press of its own (no key or click while it was down), every cap held at some point with
        // it. Of the chords that fit, the one with the most caps: fn with ⌃ held is fn ⌃, fn with ⌘
        // held is still fn.
        for key in old.subtracting(new).keys {
            let raw = key.rawValue
            let with = heldWith.removeValue(forKey: raw) ?? []
            let quiet = !usedWith.contains(raw) && !spent.contains(raw)
            usedWith.remove(raw)
            spent.remove(raw)
            guard quiet, !paused() else { continue }
            let pressed = with.union(key)
            var best: (id: String, caps: Int)?
            for id in order {
                guard let pattern = patterns[id], pattern.keyCode == nil, actions[id]?.kind == .toggle,
                      !key.intersection(pattern.allowed).isEmpty, pattern.held(pressed) else { continue }
                if pattern.caps.count > (best?.caps ?? 0) { best = (id, pattern.caps.count) }
            }
            guard let id = best?.id else { continue }
            // The keys still held with it have had their press.
            for other in new.keys { spent.insert(other.rawValue) }
            _ = actions[id]?.toggle()
        }
    }

    private func release(_ id: String, at t: TimeInterval) {
        var gesture = gestures[id] ?? ModifierGesture()
        let edges = gesture.up(at: t)
        gestures[id] = gesture
        for edge in edges {
            switch edge {
            case .up(let tap): actions[id]?.up(tap)
            case .doublePress: actions[id]?.doublePress()
            case .down: break
            }
        }
    }

    /// A key down or up, from the keyboard tap (any app) or Fovea's own windows. True keeps it from
    /// the app in front: only a chord's own key, and only while the press is Fovea's.
    func handleKey(_ event: NSEvent) -> Bool {
        let code = Int(event.keyCode)
        let t = event.timestamp
        if event.type == .keyUp {
            if let id = keyHolds.removeValue(forKey: code) { release(id, at: t) }
            return kept.remove(code) != nil
        }
        guard event.type == .keyDown else { return false }
        if kept.contains(code) {
            if event.isARepeat { return true }
            // Its up never came: a new press.
            kept.remove(code)
            if let id = keyHolds.removeValue(forKey: code) { release(id, at: t) }
        }
        var mods = ModifierKeys(flags: event.modifierFlags)
        // The arrows and the function keys carry fn's flag on every press.
        if !down.contains(.fn) { mods.remove(.fn) }
        guard !paused(), let id = order.first(where: { id in
            guard let pattern = patterns[id] else { return false }
            return pattern.keyCode == code && pattern.matches(mods)
        }), let action = actions[id] else { return false }
        // Not a press of the modifiers alone, and a hold of them (⌥ under ⌥ Space) isn't a tap.
        used(except: code)
        guard !event.isARepeat else { return false }
        switch action.kind {
        case .toggle:
            guard action.toggle() else { return false }
        case .hold:
            guard action.active() else { return false }
            var gesture = gestures[id] ?? ModifierGesture()
            let edges = gesture.down(at: t)
            gestures[id] = gesture
            keyHolds[code] = id
            if edges.contains(.down) { action.down() }
        }
        kept.insert(code)
        return true
    }
}

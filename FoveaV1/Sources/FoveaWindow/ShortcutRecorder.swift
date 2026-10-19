import AppKit
import Combine
import SwiftUI
import FoveaKit
import FoveaLook
import FoveaPlatform

// Settings › Shortcuts (Oct 15 review, ST-03.1 and ST-03.2): every shortcut in
// `FoveaKeys.changeable` can be recorded. Click its keys and press new ones: modifiers alone (fn,
// right ⌥, fn ⌃), pressed and let go, or modifiers with a key (⌥ Space); Esc cancels. A shortcut
// can be cleared, put back to its default, or all of them at once. Keys another Fovea shortcut
// uses, or that the Mac uses (⌘ Space, ⌃ Space, ⌘ Tab, ⌥⌘ Esc…), say so in place before anything's
// saved. What's recorded goes to `FoveaPrefs.shortcutChords`; the notch's key engine follows it.
// Without Accessibility the keys work only in Fovea, and the pane says so first. While a recorder
// listens, `ShortcutRecording.active` (FoveaPlatform) is set, so the notch's key engine steps aside
// and pressing fn to record it doesn't start Voice Flow.
//
// Caps are written as the engine reads them: "fn", "⌃", "⌥", "⇧", "⌘" for either side (a left-hand
// key is recorded so), "right ⌥" for a right-hand one; the defaults may name a side ("left ⌥").

/// A recorded chord waiting on a clash, said in place before it's saved (ST-03.2).
struct PendingChord: Equatable {
    enum Clash: Equatable {
        /// Another of Fovea's shortcuts has these keys: using them here clears that one.
        case shortcut(id: String, title: String)
        /// The Mac (or the notch's fixed keys) uses them.
        case system(String)
    }
    var id: String
    var chord: KeyChord
    var clash: Clash
}

/// Chords as Settings draws, compares and names them.
enum Chords {
    static let order = ["fn", "⌃", "⌥", "⇧", "⌘"]

    /// "left ⌥" is ⌥: a left-hand key is written plain, a right-hand one "right ⌥".
    static func plain(_ m: String) -> String { m.hasPrefix("left ") ? String(m.dropFirst(5)) : m }
    static func base(_ m: String) -> String { plain(m).replacingOccurrences(of: "right ", with: "") }

    /// The chord as compared with another of Fovea's.
    static func key(_ c: KeyChord) -> [String] {
        c.modifiers.map(plain).sorted { rank($0) < rank($1) } + (c.keyCap.map { [$0.uppercased()] } ?? [])
    }

    /// The chord as compared with the Mac's (sides don't count).
    static func loose(_ c: KeyChord) -> [String] {
        c.modifiers.map(base).sorted { rank($0) < rank($1) } + (c.keyCap.map { [$0.uppercased()] } ?? [])
    }

    private static func rank(_ m: String) -> Int { order.firstIndex(of: base(m)) ?? 9 }

    static func same(_ a: KeyChord, _ b: KeyChord) -> Bool { key(a) == key(b) }

    /// Whether two chords answer to the same press: the same key, and the same modifiers where an
    /// either-side cap ("⌘") meets its sided forms ("left ⌘", "right ⌘"), and left meets right only
    /// when neither names a side.
    static func overlap(_ a: KeyChord, _ b: KeyChord) -> Bool {
        guard a.keyCap?.uppercased() == b.keyCap?.uppercased(), a.modifiers.count == b.modifiers.count,
              !isEmpty(a), !isEmpty(b) else { return false }
        func side(_ m: String) -> String? { m.hasPrefix("left ") ? "left" : (m.hasPrefix("right ") ? "right" : nil) }
        var rest = b.modifiers
        for m in a.modifiers {
            guard let i = rest.firstIndex(where: { base($0) == base(m) && (side($0) == nil || side(m) == nil || side($0) == side(m)) })
            else { return false }
            rest.remove(at: i)
        }
        return true
    }

    /// Left ⌃ by itself is taken: in Choose chat it shows every chat by agent.
    static func isLeftControlAlone(_ c: KeyChord) -> Bool {
        c.keyCap == nil && (c.modifiers == ["⌃"] || c.modifiers == ["left ⌃"])
    }
    static func isEmpty(_ c: KeyChord) -> Bool { c.modifiers.isEmpty && c.keyCap == nil }

    /// Caps to draw: a side as a muted word before its key ("~Right", "⌥").
    static func caps(_ c: KeyChord) -> [String] {
        c.modifiers.flatMap { m -> [String] in
            if m.hasPrefix("left ") { return ["~Left", String(m.dropFirst(5))] }
            if m.hasPrefix("right ") { return ["~Right", String(m.dropFirst(6))] }
            return [m]
        } + (c.keyCap.map { [$0] } ?? [])
    }

    /// The chord in words, for a sentence: "fn ⌃", "right ⌥", "⌘ Space".
    /// Oct 18, Ryan: in the primary language ("右 ⌥", "⌘ 空格"); the chord itself keeps its names.
    static func spoken(_ c: KeyChord) -> String {
        (c.modifiers.map(word) + (c.keyCap.map { [label($0)] } ?? [])).joined(separator: " ")
    }

    /// A modifier with its side, in words: "right ⌥" → "右 ⌥".
    static func word(_ m: String) -> String {
        if m.hasPrefix("left ") { return L("left \(String(m.dropFirst(5)))") }
        if m.hasPrefix("right ") { return L("right \(String(m.dropFirst(6)))") }
        return m
    }

    /// A key's cap as the primary language labels it (the space bar is 空格 in Chinese).
    static func label(_ cap: String) -> String { cap == "Space" ? L("Space") : cap }

    /// What the Mac (and the notch's fixed keys) do with some chords, to warn before taking them.
    static let mac: [([String], String)] = [
        (["⌘", "SPACE"], "opens Spotlight"),
        (["⌃", "SPACE"], "switches to the previous input source"),
        (["⌃", "⌥", "SPACE"], "switches to the next input source"),
        (["⌃", "⌘", "SPACE"], "opens Emoji & Symbols"),
        (["⌘", "⇥"], "switches apps"),
        (["⌘", "`"], "switches between an app's windows"),
        (["⌥", "⌘", "ESC"], "opens Force Quit"),
        (["⇧", "⌘", "3"], "takes a screenshot"),
        (["⇧", "⌘", "4"], "takes part of the screen"),
        (["⇧", "⌘", "5"], "opens Screenshot"),
        (["⌃", "⌘", "Q"], "locks the screen"),
        (["⌃", "↑"], "opens Mission Control"),
        (["⌃", "↓"], "shows an app's windows"),
        (["⌃", "←"], "moves a Space left"),
        (["⌃", "→"], "moves a Space right"),
        (["⌥", "⌘", "D"], "hides the Dock"),
        (["fn", "E"], "opens Emoji & Symbols"),
        (["fn", "Q"], "opens a Quick Note"),
        (["fn", "F"], "makes a window full screen"),
        (["fn", "A"], "shows the Dock"),
        (["fn", "C"], "opens Control Center"),
        (["fn", "N"], "opens Notification Center"),
        (["⌘", "Q"], "quits the app in front"),
        (["⌘", "W"], "closes a window"),
        (["⌘", "H"], "hides the app in front"),
        (["⌘", "M"], "minimizes a window"),
        (["⌘", "Z"], "is Undo (and Fovea's Undo a cancel)"),
        (["⌘", "C"], "is Copy"),
        (["⌘", "V"], "is Paste"),
        (["⌘", "X"], "is Cut"),
        (["⌘", "A"], "is Select All"),
    ]

    /// A key's cap as Settings draws it.
    static func cap(_ e: NSEvent) -> String {
        switch e.keyCode {
        case 49: return "Space"
        case 36, 76: return "↩"
        case 48: return "⇥"
        case 51: return "⌫"
        case 117: return "⌦"
        case 53: return "esc"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 115: return "↖"
        case 119: return "↘"
        case 116: return "⇞"
        case 121: return "⇟"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default: return (e.charactersIgnoringModifiers ?? "?").uppercased()
        }
    }

    /// F1–F12, which work alone without getting in typing's way.
    static func isFunctionKey(_ code: UInt16) -> Bool { [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111].contains(code) }
}

/// Listens to the keys while a shortcut records, in Fovea's window only (a local monitor, which
/// swallows them): the modifiers held, from their device bits so left and right are told apart;
/// all let go, the most held at once is the chord; or a key pressed with them.
@MainActor
final class ChordListener {
    private var monitor: Any?
    private var peak: [String] = []
    private var fnHeld = false
    var onHeld: ([String]) -> Void = { _ in }
    var onChord: (KeyChord) -> Void = { _ in }
    var onCancel: () -> Void = {}
    var onRefused: (String) -> Void = { _ in }

    var listening: Bool { monitor != nil }

    func start() {
        stop()
        peak = []
        fnHeld = false
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            guard let self else { return event }
            self.handle(event)
            return nil
        }
        ShortcutRecording.active = true
    }

    func stop() {
        ShortcutRecording.active = false
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }

    private func handle(_ e: NSEvent) {
        switch e.type {
        case .flagsChanged:
            // fn (63, the globe key 179) is told from the fn flag arrows and F-keys also carry.
            if e.keyCode == 63 || e.keyCode == 179 { fnHeld = e.modifierFlags.contains(.function) }
            let held = Self.held(e.modifierFlags, fn: fnHeld)
            for m in held where !peak.contains(m) { peak.append(m) }
            peak.sort { Chords.order.firstIndex(of: Chords.base($0)) ?? 9 < Chords.order.firstIndex(of: Chords.base($1)) ?? 9 }
            onHeld(held.isEmpty ? peak : held)
            if held.isEmpty, !peak.isEmpty {
                let chord = KeyChord(modifiers: peak)
                peak = []
                onChord(chord)
            }
        case .keyDown:
            let mods = Self.held(e.modifierFlags, fn: fnHeld)
            if e.keyCode == 53 && mods.isEmpty { peak = []; onCancel(); return }
            guard !e.isARepeat else { return }
            if mods.isEmpty && !Chords.isFunctionKey(e.keyCode) {
                onRefused(L("Add fn, ⌃, ⌥ or ⌘ to a key, so typing still works."))
                return
            }
            peak = []
            onChord(KeyChord(modifiers: mods, keyCode: Int(e.keyCode), keyCap: Chords.cap(e)))
        default:
            break
        }
    }

    /// The modifiers held, sides from the device-dependent bits (NX_DEVICE…KEYMASK).
    static func held(_ flags: NSEvent.ModifierFlags, fn: Bool) -> [String] {
        let raw = flags.rawValue
        func side(_ name: String, left: UInt, right: UInt) -> String {
            raw & right != 0 && raw & left == 0 ? "right \(name)" : name
        }
        var out: [String] = []
        if fn { out.append("fn") }
        if flags.contains(.control) { out.append(side("⌃", left: 0x0001, right: 0x2000)) }
        if flags.contains(.option) { out.append(side("⌥", left: 0x0020, right: 0x0040)) }
        if flags.contains(.shift) { out.append(side("⇧", left: 0x0002, right: 0x0004)) }
        if flags.contains(.command) { out.append(side("⌘", left: 0x0008, right: 0x0010)) }
        return out
    }
}

// MARK: - Actions

extension CapturesModel {
    /// The chord a shortcut answers to now.
    func chord(_ id: String) -> KeyChord { prefs.shortcutChords[id] ?? FoveaKeys.defaultChords[id] ?? KeyChord(modifiers: []) }

    func isDefaultChord(_ id: String) -> Bool {
        guard let recorded = prefs.shortcutChords[id] else { return true }
        return FoveaKeys.defaultChords[id].map { Chords.same($0, recorded) } ?? false
    }

    var allShortcutsDefault: Bool { FoveaKeys.changeable.allSatisfy { isDefaultChord($0.id) } }

    /// Starts recording a shortcut: the keys pressed next are its new ones (Esc cancels).
    func startRecording(_ id: String) {
        let p = panes
        p.pending = nil
        p.heldCaps = []
        p.recordingHint = nil
        p.recording = id
        p.listener.onHeld = { [weak p] held in p?.heldCaps = held; p?.recordingHint = nil }
        p.listener.onCancel = { [weak self] in self?.stopRecording() }
        p.listener.onRefused = { [weak p] line in p?.recordingHint = line }
        p.listener.onChord = { [weak self, weak p] chord in
            guard let self else { return }
            // Taken by the notch itself: say so, and keep listening.
            if Chords.isLeftControlAlone(chord) {
                p?.heldCaps = []
                p?.recordingHint = L("Left ⌃ by itself shows every chat in Choose chat. Try other keys.")
                return
            }
            self.stopRecording()
            self.offer(chord, for: id)
        }
        p.listener.start()
    }

    func stopRecording() {
        panes.listener.stop()
        panes.recording = nil
        panes.heldCaps = []
        panes.recordingHint = nil
    }

    /// A recorded chord: saved, unless something else uses those keys; then said in place first.
    func offer(_ chord: KeyChord, for id: String) {
        if let clash = clash(chord, for: id) {
            animate(.swap) { panes.pending = PendingChord(id: id, chord: chord, clash: clash) }
        } else {
            save(chord, for: id)
        }
    }

    /// What else uses these keys: another Fovea shortcut, then the Mac.
    func clash(_ chord: KeyChord, for id: String) -> PendingChord.Clash? {
        guard !Chords.isEmpty(chord) else { return nil }
        for other in FoveaKeys.changeable where other.id != id {
            if Chords.overlap(chord, self.chord(other.id)) { return .shortcut(id: other.id, title: other.title) }
        }
        // Oct 18, Ryan: ⌘ by itself is Fovea's too: pressed twice, the whole screen.
        if chord.keyCap == nil, chord.modifiers.map(Chords.base) == ["⌘"] {
            return .system(L("⌘ pressed twice takes the whole screen while Fovea listens."))
        }
        let loose = Chords.loose(chord)
        if let hit = Chords.mac.first(where: { $0.0 == loose }) {
            return .system(L("\(Chords.spoken(chord)) \(L(key: hit.1)) on your Mac."))
        }
        return nil
    }

    /// Keeps a chord (the default kept as no change); a clashing Fovea shortcut it was taken from is
    /// cleared.
    func save(_ chord: KeyChord, for id: String) {
        animate(.swap) {
            if case .shortcut(let other, _)? = panes.pending?.clash, panes.pending?.id == id {
                prefs.shortcutChords[other] = KeyChord(modifiers: [])
            }
            if let d = FoveaKeys.defaultChords[id], Chords.same(d, chord) {
                prefs.shortcutChords[id] = nil
            } else {
                prefs.shortcutChords[id] = chord
            }
            panes.pending = nil
        }
        let title = FoveaKeys.changeable.first { $0.id == id }?.title ?? L("Shortcut")
        say(Chords.isEmpty(chord) ? L("\(title) has no shortcut") : L("\(title): \(Chords.spoken(chord))"))
    }

    func resetShortcut(_ id: String) {
        animate(.swap) { prefs.shortcutChords[id] = nil; if panes.pending?.id == id { panes.pending = nil } }
    }

    func resetAllShortcuts() {
        stopRecording()
        animate(.swap) { prefs.shortcutChords = [:]; panes.pending = nil }
        say(L("Every shortcut is back as it was"))
    }
}

// MARK: - The pane

struct ShortcutsPane: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var panes = model.panes
        AccessibilityBanner()

        // Fovea's keys, from the one table every surface reads (FoveaKit's `FoveaKeys`): the
        // round the onboarding teaches and the notch acts on; the two daily ones recordable here.
        SettingsSection(nil, note: "Press once to start, again to stop. Click a shortcut's keys to record new ones.") {
            HStack(alignment: .top, spacing: 12) {
                ForEach(FoveaKeys.daily) { key in MainKey(shortcut: key).frame(maxHeight: .infinity, alignment: .top) }
            }
            .fixedSize(horizontal: false, vertical: true)
        }

        SettingsSection("While you speak") {
            SettingsCard {
                // Oct 17, Ryan: ⌥ (either side) by default, since ⌘ clashed with Codex. One press only:
                // ⌥ twice is the Claude app's, so there's no whole-screen row any more.
                ShortcutRow(shortcut: FoveaKeys.region, detail: L("Press \(Chords.spoken(model.chord(FoveaKeys.region.id))), then drag over what to take. Hold it to take more than one."))
                RowDivider()
                // Oct 18, Ryan: ⌘ twice for the whole screen: fixed (a double press isn't recorded).
                SettingsRow(FoveaKeys.wholeScreen.title, detail: FoveaKeys.wholeScreen.detail) {
                    HStack(spacing: 4) {
                        CapsView(caps: FoveaKeys.wholeScreen.keys)
                        Text("×\(FoveaKeys.wholeScreen.presses)").font(.system(size: 11, weight: .semibold)).foregroundStyle(palette.secondary)
                    }
                }
                RowDivider()
                // Oct 17, Ryan: no key for words and files: while Fovea listens, words selected are
                // taken, and a file dragged onto the notch. A plain row, nothing to record.
                SettingsRow(FoveaKeys.highlighter.title, detail: FoveaKeys.highlighter.detail) { EmptyView() }
            }
        }

        SettingsSection("In the notch", note: "The board opens when the pointer rests at the notch (Settings › Notch).") {
            SettingsCard {
                ForEach(Array(FoveaKeys.inTheNotch.enumerated()), id: \.element.id) { i, key in
                    if i > 0 { RowDivider() }
                    SettingsRow(key.title, detail: key.detail) { CapsView(caps: key.keys) }
                }
            }
        }

        SettingsSection(nil) {
            SettingsCard {
                SettingsRow("Reset All Shortcuts", detail: "Back to fn for Voice Flow, fn ⌃ for Dispatch and ⌥ to take part of the screen.") {
                    TextButton("Reset All…") { panes.confirmResetAll = true }
                        .disabled(model.allShortcutsDefault)
                }
            }
        }
        .alert("Put every shortcut back as it was?", isPresented: $panes.confirmResetAll) {
            Button("Reset All") { model.resetAllShortcuts() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Voice Flow, Dispatch and taking part of the screen go back to their first keys.")
        }

        SettingsSection("Permissions", note: "Fovea needs these to hear its keys in any app.") {
            SettingsCard {
                PermissionRows(permissions: [.accessibility, .inputMonitoring]) { p in
                    p == .accessibility ? "Fovea's keys in any app, and typing your words where you are." : "The shortcuts, heard in every app."
                }
            }
        }
        .id("permissions")
        .onDisappear { model.stopRecording() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in model.stopRecording() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { note in
            if (note.object as? NSWindow)?.attachedSheet == nil { model.stopRecording() }
        }
    }
}

/// Without Accessibility the keys work only while Fovea is in front: said first, with the way to
/// System Settings (kept from before the review; the notch says it too).
private struct AccessibilityBanner: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var granted = Permission.accessibility.granted
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if !granted || model.panes.stagedMissing.contains(.accessibility) {
                SettingsSection(nil) {
                    SettingsCard {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(palette.warning)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Fovea's keys work only in Fovea for now").font(.system(size: 13, weight: .medium)).foregroundStyle(palette.text)
                                Text("Allow Fovea in \(Permission.accessibility.paneName), then come back. Nothing needs restarting.")
                                    .font(.system(size: 11.5)).foregroundStyle(palette.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            TextButton("Open Privacy Settings…") { Permission.accessibility.openSettings() }
                        }
                        .cardPadding()
                    }
                }
            }
        }
        .onReceive(tick) { _ in granted = Permission.accessibility.granted }
    }
}

/// One of the two keys you'll use every day, given room: its keys large (click to record), its
/// name and a line, and Clear and Reset to Default under them.
private struct MainKey: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let shortcut: FoveaShortcut

    var body: some View {
        // Concentric: the well inset 6 pt in a card rounded 14, so rounded 8.
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            ChordRecorder(id: shortcut.id, large: true)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(palette.ink(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.text)
                Text(shortcut.detail).font(.system(size: 11.5)).foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
            .padding(.top, 10)
            ChordNotes(id: shortcut.id)
                .padding(.horizontal, 4)
            if model.panes.recording != shortcut.id && model.panes.pending?.id != shortcut.id {
                HStack(spacing: 6) {
                    Button("Clear") { model.save(KeyChord(modifiers: []), for: shortcut.id) }
                        .disabled(Chords.isEmpty(model.chord(shortcut.id)))
                    if !model.isDefaultChord(shortcut.id) {
                        Button("Reset to Default") { model.resetShortcut(shortcut.id) }
                    }
                }
                .controlSize(.small)
                .padding(.horizontal, 4)
                .padding(.top, 8)
            }
            Spacer(minLength: 4)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .settingsSurface(shape)
    }
}

/// A changeable shortcut as a row: its name and how it's used, its keys (click to record), Reset to
/// Default when changed, and a clear button under the pointer.
private struct ShortcutRow: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let shortcut: FoveaShortcut
    let detail: String
    @State private var hover = false

    var body: some View {
        let chord = model.chord(shortcut.id)
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow(shortcut.title, detail: detail) {
                HStack(spacing: 6) {
                    if !model.isDefaultChord(shortcut.id) {
                        Button("Reset to Default") { model.resetShortcut(shortcut.id) }
                            .controlSize(.small)
                    }
                    ChordRecorder(id: shortcut.id)
                        // Clear, under the pointer: a badge on the keys, so nothing moves.
                        .overlay(alignment: .topTrailing) {
                            if hover && !Chords.isEmpty(chord) && model.panes.recording != shortcut.id {
                                Button { model.save(KeyChord(modifiers: []), for: shortcut.id) } label: {
                                    Image(systemName: "xmark.circle.fill").font(.system(size: 12))
                                        .foregroundStyle(palette.secondary)
                                        .background(Circle().fill(palette.nativeGroup))
                                }
                                .buttonStyle(.plain)
                                .help("Clear")
                                .accessibilityLabel("Clear \(shortcut.title)")
                                .offset(x: 6, y: -6)
                            }
                        }
                }
            }
            ChordNotes(id: shortcut.id)
                .padding(.horizontal, T.Native.rowInset)
                .padding(.bottom, model.panes.recording == shortcut.id || model.panes.pending?.id == shortcut.id ? 10 : 0)
        }
        .onHover { hover = $0 }
    }
}

/// A shortcut's keys as a button: click to record, and while recording the keys held so far in an
/// accent well (or what to do); a chord waiting on a clash shows its keys.
struct ChordRecorder: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let id: String
    var large = false

    var body: some View {
        let p = model.panes
        let recording = p.recording == id
        let chord = p.pending?.id == id ? p.pending!.chord : model.chord(id)
        let h: CGFloat = large ? 32 : 22
        Button {
            if recording { model.stopRecording() } else { model.startRecording(id) }
        } label: {
            Group {
                if recording {
                    Group {
                        if p.heldCaps.isEmpty {
                            Text("Press the new keys").font(.system(size: large ? 13 : 12, weight: .medium)).foregroundStyle(palette.secondary)
                        } else {
                            CapsView(caps: Chords.caps(KeyChord(modifiers: p.heldCaps)), large: large)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(minHeight: h + 6)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(palette.accent.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(palette.accent, lineWidth: 1.5))
                } else if Chords.isEmpty(chord) {
                    Text("Not set").font(.system(size: large ? 13 : 12)).foregroundStyle(palette.tertiary)
                        .padding(.horizontal, 10)
                        .frame(minHeight: h)
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(palette.tertiary, style: StrokeStyle(lineWidth: 1, dash: [3, 2.5])))
                } else {
                    CapsView(caps: Chords.caps(chord), large: large)
                        .opacity(p.pending?.id == id ? 0.6 : 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(recording ? L("Press the new keys. Esc cancels.") : L("Click, then press the new keys"))
        .accessibilityLabel(recording ? L("Recording. Press the new keys, or Escape to cancel.") : Chords.spoken(chord))
    }
}

/// Under a shortcut while it records (what to press, or why a key alone won't do), or while a
/// chord waits on a clash (what uses it, Cancel, and Use Anyway or Use Here).
private struct ChordNotes: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let id: String

    var body: some View {
        let p = model.panes
        if p.recording == id {
            VStack(alignment: .leading, spacing: 3) {
                Text("Modifier keys alone work too, like fn or fn\u{00A0}⌃. Esc cancels.")
                    .foregroundStyle(palette.secondary)
                if let hint = p.recordingHint {
                    Text(hint).foregroundStyle(palette.warning)
                }
            }
            .font(.system(size: 11))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 6)
            .transition(.opacity)
        } else if let pending = p.pending, pending.id == id {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Circle().fill(palette.warning).frame(width: 6, height: 6)
                    Text(line(pending)).foregroundStyle(palette.text).fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 6) {
                    Button("Cancel") { model.animate(.swap) { model.panes.pending = nil } }
                    Button(isShortcut(pending) ? L("Use Here") : L("Use Anyway")) { model.save(pending.chord, for: id) }
                        .keyboardShortcut(.defaultAction)
                }
                .controlSize(.small)
            }
            .font(.system(size: 11.5))
            .padding(.top, 6)
            .transition(.opacity)
        }
    }

    private func isShortcut(_ p: PendingChord) -> Bool {
        if case .shortcut = p.clash { return true }
        return false
    }

    private func line(_ p: PendingChord) -> String {
        switch p.clash {
        case .shortcut(_, let title): return L("\(title) already uses \(Chords.spoken(p.chord)). Use it here instead, and clear \(title)?")
        case .system(let what): return what
        }
    }
}

/// Keys as caps: one per key, a side or "twice" as a muted word.
struct CapsView: View {
    @Environment(\.palette) private var palette
    let caps: [String]
    var large = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(caps.enumerated()), id: \.offset) { _, key in
                // Oct 18, Ryan: in the primary language (a side's word, the space bar's name).
                if key.hasPrefix("~") {
                    Text(L(key: String(key.dropFirst()))).font(.system(size: large ? 13 : 11.5)).foregroundStyle(palette.tertiary)
                } else {
                    KeyCapView(key: Chords.label(key), large: large)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(caps.map { $0.hasPrefix("~") ? L(key: String($0.dropFirst())) : Chords.label($0) }.joined(separator: " "))
    }
}

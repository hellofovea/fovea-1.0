import AppKit
import Carbon.HIToolbox
import FoveaCore

/// 'FOVM': our own signature, so these chords never reach `HotkeyMonitor`'s handler.
private let materialHotkeySignature: OSType = 0x464F564D

/// ⌃⌥⌘1…5 pick the Island's material (the study's A–E) from any app, so the options can be
/// compared over whatever is in front. Carbon chords like the session shortcuts: no
/// permission needed, and the chord never reaches the frontmost app.
@MainActor
final class MaterialHotkeys {
    private var handler: EventHandlerRef?
    private var refs: [EventHotKeyRef] = []
    private let onPick: (IslandMaterial) -> Void

    private static let keyCodes = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5]

    init(onPick: @escaping (IslandMaterial) -> Void) { self.onPick = onPick }

    func start() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            guard hotKeyID.signature == materialHotkeySignature else { return OSStatus(eventNotHandledErr) }
            let hotkeys = Unmanaged<MaterialHotkeys>.fromOpaque(userData).takeUnretainedValue()
            let index = Int(hotKeyID.id)
            // Carbon delivers on the main thread.
            MainActor.assumeIsolated { hotkeys.pick(index) }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { return }
        let modifiers = UInt32(cmdKey | optionKey | controlKey)
        for (index, keyCode) in Self.keyCodes.enumerated() {
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: materialHotkeySignature, id: UInt32(index))
            if RegisterEventHotKey(UInt32(keyCode), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref) == noErr,
               let ref {
                refs.append(ref)
            }
        }
    }

    private func pick(_ index: Int) {
        let all = IslandMaterial.allCases
        guard all.indices.contains(index) else { return }
        onPick(all[index])
    }
}

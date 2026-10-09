import AppKit
import Carbon.HIToolbox

/// A shortcut that works from any app, as Aside's ⌥⌘A shows and hides it: Carbon's hot keys,
/// which need no permission. One at a time; registering again replaces it.
@MainActor
final class GlobalHotKey {
    static let shared = GlobalHotKey()

    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var action: (() -> Void)?

    /// ⌥⌘F: F for Fovea, where Aside uses ⌥⌘A. While it's registered, apps that use ⌥⌘F for
    /// their own command (an editor's Replace) don't receive it: it's off unless `summon` is on.
    func register(keyCode: UInt32 = UInt32(kVK_ANSI_F), modifiers: UInt32 = UInt32(optionKey | cmdKey),
                  action: @escaping () -> Void) {
        unregister()
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            Task { @MainActor in GlobalHotKey.shared.action?() }
            return noErr
        }, 1, &spec, nil, &handler)
        guard status == noErr else { return }
        let id = EventHotKeyID(signature: OSType(0x46_4F_56_41), id: 1) // "FOVA"
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
        ref = nil
        handler = nil
        action = nil
    }

    var isRegistered: Bool { ref != nil }
}

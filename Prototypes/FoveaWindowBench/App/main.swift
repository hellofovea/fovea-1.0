import AppKit

// Registered before the menu bar exists: AppKit would otherwise add Start Dictation,
// Emoji & Symbols and Enter Full Screen, each with a keyboard shortcut. The window binds none.
UserDefaults.standard.register(defaults: [
    "NSDisabledDictationMenuItem": true,
    "NSDisabledCharacterPaletteMenuItem": true,
    "NSFullScreenMenuItemEverywhere": false,
])

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { BenchAppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()

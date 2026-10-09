import AppKit

// Fovea 1.0's composition root (filled in as the surfaces arrive).
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    app.run()
}

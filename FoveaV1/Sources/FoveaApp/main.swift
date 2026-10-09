import AppKit

// Fovea 1.0. One process, three surfaces: the first run (the onboarding), the window (Home and
// Settings) and the notch. The delegate is the composition root (AppDelegate.swift).
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    FoveaAppMain.delegate = delegate // NSApplication keeps its delegate weakly.
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}

@MainActor
enum FoveaAppMain {
    static var delegate: AppDelegate?
}

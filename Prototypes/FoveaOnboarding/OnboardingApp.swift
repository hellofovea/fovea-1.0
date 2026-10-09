import SwiftUI
import AppKit
import OnboardingCore

/// Fovea Onboarding: the first run as a prototype on a mock desktop. The black Island at the notch
/// answers real key presses (fn ⌃, ⌘, ⌥, fn); permissions are asked over a mock System Settings; two
/// real tasks go to the agent on this Mac; it ends in the real Home from Fovea Captures.
/// docs/onboarding/ONBOARDING.md is the design.
@main
struct OnboardingApp: App {
    @NSApplicationDelegateAdaptor(OnboardingAppDelegate.self) private var delegate

    var body: some Scene {
        Window("Fovea Onboarding", id: "onboarding") {
            RootView(model: delegate.model)
                .frame(minWidth: OT.Layout.windowMin.width, minHeight: OT.Layout.windowMin.height)
        }
        .defaultSize(width: OT.Layout.windowDefault.width, height: OT.Layout.windowDefault.height)
        .windowResizability(.contentMinSize)
    }
}

@MainActor
final class OnboardingAppDelegate: NSObject, NSApplicationDelegate {
    let options = Options.parse()
    lazy var model = OnboardingModel(options: options)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if !options.noActivate { NSApp.activate(ignoringOtherApps: true) }
        model.start()
        if let dir = options.snapshotDir {
            Task { await OnboardingSnapshots.run(dir: dir, only: options.only, model: model); NSApp.terminate(nil) }
        } else if options.smoke {
            Task {
                let ok = await OnboardingSmoke.run(model: model)
                exit(ok ? 0 : 1)
            }
        } else if options.play {
            model.play(from: options.playFrom.flatMap { Options.stages[$0] } ?? .arrive)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// The window: the control panel at the left, the MacBook on its stage at the right.
struct RootView: View {
    let model: OnboardingModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            ControlPanel(model: model)
                .frame(width: OT.Layout.panelWidth)
            Divider()
            StageView(model: model)
                .background(scheme == .dark ? OT.Colors.stageDark : OT.Colors.stage)
        }
    }
}

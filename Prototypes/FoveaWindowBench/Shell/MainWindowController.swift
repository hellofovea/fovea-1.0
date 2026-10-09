import AppKit
import SwiftUI
import WindowBenchCore

/// The Fovea window: a real titled window whose toolbar comes from SwiftUI's `.toolbar`
/// (bridged), traffic lights and all. Closing it hides it; the app keeps running.
@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    let model: BenchModel

    init(model: BenchModel) {
        self.model = model
        let hosting = NSHostingController(rootView: MainView().environment(model))
        hosting.sceneBridgingOptions = [.toolbars]
        hosting.sizingOptions = []
        let size = BenchTokens.Layout.windowDefault
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.contentViewController = hosting
        window.title = "Fovea"
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.minSize = BenchTokens.Layout.windowMin
        window.setContentSize(size)
        window.setAccessibilityIdentifier("fovea.window")
        window.tabbingMode = .disallowed
        super.init(window: window)
        window.delegate = self
        // Lays the window out now, whether or not AppKit has asked yet: SwiftUI brings the page up
        // to date first, so nothing changed afterwards meets a half-built page.
        model.commitHandler = { [weak hosting] in
            guard let view = hosting?.view else { return }
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Sizes and places the window for a preset. "Fit" is the largest default-shaped window
    /// that leaves the control panel room beside it on this display.
    func place(preset: WindowSizePreset, panelWidth: CGFloat) {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        let v = screen.visibleFrame
        let margin: CGFloat = 12
        let gap = BenchTokens.Layout.panelGap
        var size: CGSize
        switch preset {
        case .large: size = BenchTokens.Layout.windowDefault
        case .compact: size = BenchTokens.Layout.windowCompact
        case .fit:
            let def = BenchTokens.Layout.windowDefault
            size = CGSize(width: min(def.width, v.width - panelWidth - gap - margin * 2),
                          height: min(def.height, v.height - margin * 2))
        }
        size.width = max(BenchTokens.Layout.windowMin.width, min(size.width, v.width - margin * 2))
        size.height = max(BenchTokens.Layout.windowMin.height, min(size.height, v.height - margin * 2))
        let total = size.width + gap + panelWidth
        let x = total <= v.width - margin * 2 ? v.minX + (v.width - total) / 2 : v.minX + margin
        let y = v.minY + (v.height - size.height) / 2
        let frame = window.frameRect(forContentRect: NSRect(x: x, y: y, width: size.width, height: size.height))
        window.setFrame(NSRect(x: x, y: y + (size.height - frame.height), width: frame.width, height: frame.height), display: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}

import AppKit
import SwiftUI
import WindowBenchCore

/// A panel that never takes key or main status, so clicking a switch never takes focus from
/// the Fovea window, and the window keeps looking active while you compare designs.
final class BenchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The panel is never key: the first click on a control has to be the click.
final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// The control panel: attached to the Fovea window as a child, so it moves with it and stays
/// on its Space. Beside the window when the display has room; otherwise over the content's
/// top-left corner, collapsible to a tab, never over the status bar.
@MainActor
final class ControlPanelController {
    let panel: BenchPanel
    private let model: BenchModel
    private weak var follows: NSWindow?
    private var observers: [Any] = []

    init(model: BenchModel, follows window: NSWindow) {
        self.model = model
        self.follows = window
        let width = BenchTokens.Layout.panelWidth
        panel = BenchPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: 640),
                           styleMask: [.titled, .utilityWindow, .nonactivatingPanel],
                           backing: .buffered, defer: false)
        panel.title = "Window Bench"
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.fullScreenAuxiliary]
        panel.setAccessibilityIdentifier("fovea.bench-panel")
        let host = FirstClickHostingView(rootView: PanelView().environment(model))
        host.sizingOptions = []
        panel.contentView = host
        let center = NotificationCenter.default
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            observers.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.follow() }
            })
        }
        observers.append(center.addObserver(forName: NSWindow.didChangeScreenNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.follow() }
        })
    }

    func attach() {
        guard let window = follows else { return }
        if panel.parent == nil { window.addChildWindow(panel, ordered: .above) }
        follow()
        panel.orderFront(nil)
    }

    func toggle() {
        if panel.isVisible { panel.orderOut(nil) } else { attach() }
    }

    /// Whether the panel sits beside the window (true) or over its content (false).
    private(set) var beside = true

    func follow() {
        guard let window = follows, let screen = window.screen ?? NSScreen.main else { return }
        let f = window.frame
        let v = screen.visibleFrame
        let gap = BenchTokens.Layout.panelGap
        let width = BenchTokens.Layout.panelWidth
        let collapsed = model.state.panelCollapsed
        if f.maxX + gap + width <= v.maxX {
            beside = true
            panel.setFrame(NSRect(x: f.maxX + gap, y: f.minY, width: width, height: f.height), display: true)
        } else if f.minX - gap - width >= v.minX {
            beside = true
            panel.setFrame(NSRect(x: f.minX - gap - width, y: f.minY, width: width, height: f.height), display: true)
        } else {
            // Over the content's top-left, under the toolbar, clear of the status bar.
            beside = false
            let top = f.maxY - 52
            let bottom = f.minY + BenchTokens.Layout.statusBar + 8
            let height = collapsed ? 44 : max(200, top - bottom)
            panel.setFrame(NSRect(x: f.minX + 8, y: top - height, width: width, height: height), display: true)
        }
    }
}

import AppKit
import SwiftUI
import WindowBenchCore

/// Settings: a standard macOS settings window with toolbar tabs, opened only from the ⚙
/// button, the status bar and the app menu's Settings… (which has no shortcut).
@MainActor
final class SettingsWindowController: NSWindowController {
    let model: BenchModel
    let tabs = NSTabViewController()

    init(model: BenchModel) {
        self.model = model
        tabs.tabStyle = .toolbar
        tabs.transitionOptions = [.crossfade, .allowUserInteraction]
        for tab in SettingsTab.allCases {
            let host = NSHostingController(rootView: SettingsPage(tab: tab).environment(model))
            host.sizingOptions = []
            host.preferredContentSize = BenchTokens.Layout.settingsSize
            host.title = tab.title
            let item = NSTabViewItem(viewController: host)
            item.label = tab.title
            item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
            item.identifier = tab.rawValue
            tabs.addTabViewItem(item)
        }
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.setContentSize(BenchTokens.Layout.settingsSize)
        window.isReleasedWhenClosed = false
        window.setAccessibilityIdentifier("fovea.settings")
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(_ tab: SettingsTab) {
        if let i = SettingsTab.allCases.firstIndex(of: tab) { tabs.selectedTabViewItemIndex = i }
        guard let window else { return }
        if !window.isVisible { window.center() }
        if !model.options.noActivate { NSApp.activate(ignoringOtherApps: true) }
        window.makeKeyAndOrderFront(nil)
    }

    var selectedTab: SettingsTab { SettingsTab.allCases[tabs.selectedTabViewItemIndex] }
}

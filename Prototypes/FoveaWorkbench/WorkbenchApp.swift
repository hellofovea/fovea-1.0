import SwiftUI
import AppKit
import FoveaCore

/// Notch Workbench: a mock macOS desktop with a control panel beside it, for testing notch
/// designs. A SwiftUI App, so the sidebar, its toggle button, the toolbar and the menus are
/// the system's own. Nothing here ships.
@main
struct FoveaWorkbenchApp: App {
    @NSApplicationDelegateAdaptor(WorkbenchAppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Notch Workbench", id: "workbench") {
            WorkbenchView(model: appDelegate.model)
        }
        .defaultSize(width: WorkbenchTokens.Layout.windowDefault.width,
                     height: WorkbenchTokens.Layout.windowDefault.height)
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        .commands {
            // View › Show/Hide Sidebar (⌃⌘S). Its `toggleSidebar:` ends at the delegate below.
            SidebarCommands()
            CommandGroup(replacing: .newItem) {}
            // View › Compact and Spacious: the open panels' room (also in the toolbar).
            CommandGroup(after: .sidebar) {
                Divider()
                Button("Compact Panels") { appDelegate.model.density = .compact }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Spacious Panels") { appDelegate.model.density = .spacious }
                    .keyboardShortcut("2", modifiers: .command)
                // The notch's design (also the toolbar's tabs; docs/island/NATIVE.md).
                Divider()
                Button("Original Design") { appDelegate.model.design = .original }
                    .keyboardShortcut("1", modifiers: [.command, .option])
                Button("Native Design") { appDelegate.model.design = .native }
                    .keyboardShortcut("2", modifiers: [.command, .option])
            }
        }
    }
}

@MainActor
final class WorkbenchAppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    let model = WorkbenchModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Running from `swift run` does not come to the foreground on its own.
        NSApp.setActivationPolicy(.regular)
        if ProcessInfo.processInfo.environment["FOVEA_NO_ACTIVATE"] == nil {
            NSApp.activate(ignoringOtherApps: true)
        }
        // No app bundle from SwiftPM, so the Dock icon is set at runtime.
        if let url = FoveaResources.url("AppIcon.png"), let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
        }
        model.functionKey.start()
        model.leftControlKey.start()
        model.leftOptionKey.start()
        model.leftCommandKey.start()
        model.rightCommandKey.start()
        model.keys.start()
        model.pointer.start()
        model.startLiveSteps()
        // A Window scene closed when the app last quit (a snapshot or smoke run closes it) stays
        // closed at the next launch; the workbench always opens it, from the Window menu's item.
        // The Window menu is filled a moment after launch, so it is looked for a few times.
        Task { @MainActor in
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(250))
                if NSApp.windows.contains(where: { $0.styleMask.contains(.titled) && $0.isVisible }) { return }
                if let (menu, index) = Self.windowItem(in: NSApp.mainMenu) {
                    menu.performActionForItem(at: index)
                }
            }
        }
        WorkbenchSnapshots.runIfRequested(model: model)
        WorkbenchSmoke.runIfRequested(model: model)
        FeedbackTrace.runIfRequested(model: model)
        if let i = CommandLine.arguments.firstIndex(of: "--record-creatures"), CommandLine.arguments.count > i + 1 {
            let url = URL(fileURLWithPath: CommandLine.arguments[i + 1])
            Task { await model.recordCreatures(to: url) }
        } else if let i = CommandLine.arguments.firstIndex(of: "--record-native"), CommandLine.arguments.count > i + 1 {
            let url = URL(fileURLWithPath: CommandLine.arguments[i + 1])
            Task { await model.recordNative(to: url) }
        } else if let i = CommandLine.arguments.firstIndex(of: "--record-pets"), CommandLine.arguments.count > i + 1 {
            let url = URL(fileURLWithPath: CommandLine.arguments[i + 1])
            Task { await model.recordPets(to: url) }
        } else if let url = model.options.recording {
            Task { await model.recordDemo(to: url) }
        } else if model.options.playDemo {
            Task {
                try? await Task.sleep(for: .milliseconds(800))
                model.playDemo()
            }
        }
    }

    /// The menu item that opens the workbench's window (the Window menu lists it), wherever it is.
    static func windowItem(in menu: NSMenu?) -> (NSMenu, Int)? {
        guard let menu else { return nil }
        for (i, item) in menu.items.enumerated() {
            if item.title == "Notch Workbench", item.action != nil { return (menu, i) }
            if let found = windowItem(in: item.submenu) { return found }
        }
        return nil
    }

    /// The View menu's item sends `toggleSidebar:` down the responder chain. The split view
    /// controller only sees it when a focusable view inside the split view has focus, and the
    /// panel has none yet, so the chain ends here: the model flips, and its binding drives the
    /// same split view the toolbar button does.
    @objc func toggleSidebar(_ sender: Any?) {
        model.toggleSidebar()
    }

    /// AppKit asks before the menu opens; the title says what the item will do.
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(toggleSidebar(_:)) {
            item.title = model.columnVisibility == .detailOnly ? "Show Sidebar" : "Hide Sidebar"
        }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    /// A tool, not the product: closing the window quits, as the Lab does. The root AGENTS.md
    /// rule that closing never quits is for Fovea's own window.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

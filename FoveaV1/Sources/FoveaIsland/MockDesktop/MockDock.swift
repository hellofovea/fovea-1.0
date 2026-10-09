import SwiftUI
import AppKit

/// The Dock: the system's own app icons in the Dock's pill, so the stage reads as a desktop.
/// Scenery, not a control.
struct MockDock: View {
    let icons: DockIcons

    var body: some View {
        HStack(spacing: WorkbenchTokens.Layout.dockSpacing) {
            ForEach(Array(icons.apps.enumerated()), id: \.offset) { _, image in
                icon(image)
            }
            Divider().frame(height: WorkbenchTokens.Layout.dockDividerHeight)
            if let trash = icons.trash { icon(trash) }
        }
        .padding(WorkbenchTokens.Layout.dockPadding)
        .background(
            RoundedRectangle(cornerRadius: WorkbenchTokens.Layout.dockRadius, style: .continuous)
                .fill(WorkbenchTokens.Materials.dock)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WorkbenchTokens.Layout.dockRadius, style: .continuous)
                .strokeBorder(WorkbenchTokens.Colors.dockHairline)
        )
    }

    private func icon(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .frame(width: WorkbenchTokens.Layout.dockIconSize, height: WorkbenchTokens.Layout.dockIconSize)
    }
}

/// The icons the system hands out for its own apps. An app that is not installed is skipped.
struct DockIcons {
    let apps: [NSImage]
    let trash: NSImage?
    /// The app the agent drives in Thinking.
    var safari: NSImage?

    static func load() -> DockIcons {
        let workspace = NSWorkspace.shared
        var urls = [URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")]
        let ids = ["com.apple.Safari", "com.apple.MobileSMS", "com.apple.mail", "com.apple.iCal",
                   "com.apple.Notes", "com.apple.Music", "com.apple.systempreferences"]
        urls += ids.compactMap { workspace.urlForApplication(withBundleIdentifier: $0) }
        let apps = urls
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map { workspace.icon(forFile: $0.path) }
        let safari = workspace.urlForApplication(withBundleIdentifier: "com.apple.Safari").map { workspace.icon(forFile: $0.path) }
        return DockIcons(apps: apps, trash: NSImage(named: NSImage.trashEmptyName), safari: safari)
    }
}

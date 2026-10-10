import SwiftUI
import AppKit
import FoveaCore
import FoveaKit
import FoveaPlatform

// The practice desktop's scenery: the wallpaper, the menu bar with the notch cut from it, the Dock,
// and three files at the right. The menu bar and the Dock are copied from the Workbench
// (MockDesktop/MockMenuBar.swift, MockDock.swift) on Oct 7, and may drift.

struct WallpaperView: View {
    /// The first run's desktop, as Clear my screen lays it: Tahoe Day (DesktopCover), else the coast.
    private static let image: NSImage? = DesktopCover.tahoeDay()
        ?? FoveaFiles.url("Photos/coast.jpg").flatMap { NSImage(contentsOf: $0) }

    var body: some View {
        Color.clear
            .overlay {
                if let image = Self.image {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    OT.Colors.wallpaperFallback
                }
            }
            .clipped()
    }
}

struct MenuBarView: View {
    /// The app in front: the one whose window is up.
    var app: FrontApp = .finder
    /// Solid, for a picture of the screen (a material has nothing behind it to blur off screen).
    var solid = false
    private let status = ["wifi", "battery.100percent", "magnifyingglass", "switch.2"]
    private static let clock: String = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE MMM d  h:mm a"
        return formatter.string(from: Date())
    }()

    var body: some View {
        HStack(spacing: OT.Layout.menuBarItemSpacing) {
            Image(systemName: "apple.logo")
            Text(app.name).font(OT.Type_.menuBarApp)
            ForEach(app.menus, id: \.self) { Text($0) }
            Spacer(minLength: OT.Display.notchWidth + 40)
            HStack(spacing: OT.Layout.menuBarStatusSpacing) {
                ForEach(status, id: \.self) { name in
                    Image(systemName: name).font(.system(size: OT.Layout.menuBarStatusIconSize))
                }
                Text(Self.clock)
            }
        }
        .font(OT.Type_.menuBar)
        .foregroundStyle(.primary)
        .lineLimit(1)
        .padding(.horizontal, OT.Layout.menuBarSidePadding)
        .frame(height: OT.Display.menuBarHeight)
        .frame(maxWidth: .infinity)
        .background {
            if solid { OT.Colors.menuBarSolid } else { Rectangle().fill(OT.Materials.menuBar) }
        }
    }
}

struct DockView: View {
    var solid = false
    private static let icons = DockIcons.load()

    var body: some View {
        HStack(spacing: OT.Layout.dockSpacing) {
            ForEach(Array(Self.icons.apps.enumerated()), id: \.offset) { _, image in icon(image) }
            Divider().frame(height: OT.Layout.dockDividerHeight)
            if let trash = Self.icons.trash { icon(trash) }
        }
        .padding(OT.Layout.dockPadding)
        .background {
            if solid {
                RoundedRectangle(cornerRadius: OT.Layout.dockRadius, style: .continuous).fill(OT.Colors.dockSolid)
            } else {
                RoundedRectangle(cornerRadius: OT.Layout.dockRadius, style: .continuous).fill(OT.Materials.dock)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: OT.Layout.dockRadius, style: .continuous).strokeBorder(OT.Colors.dockHairline))
    }

    private func icon(_ image: NSImage) -> some View {
        Image(nsImage: image).resizable().interpolation(.high)
            .frame(width: OT.Layout.dockIconSize, height: OT.Layout.dockIconSize)
    }
}

/// The system's own icons for its apps; one not installed is skipped (the Workbench's DockIcons).
struct DockIcons {
    let apps: [NSImage]
    let trash: NSImage?

    static func load() -> DockIcons {
        let workspace = NSWorkspace.shared
        var urls = [URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")]
        let ids = ["com.apple.Safari", "com.apple.MobileSMS", "com.apple.mail", "com.apple.iCal",
                   "com.apple.Notes", "com.apple.Music", "com.apple.systempreferences"]
        urls += ids.compactMap { workspace.urlForApplication(withBundleIdentifier: $0) }
        let apps = urls.filter { FileManager.default.fileExists(atPath: $0.path) }.map { workspace.icon(forFile: $0.path) }
        return DockIcons(apps: apps, trash: NSImage(named: NSImage.trashEmptyName))
    }
}

/// The desktop's files, a column at the right as macOS lays them out: the practice files, real
/// ones (PracticeFiles.swift), each shown from the task that uses it (`desktopFiles`) and cleared
/// at the run's end (Oct 8): the weekly update once the agent writes it, the packing list and a
/// trail map. With the highlighter on, a click
/// takes one (the Workbench's `DesktopFiles`); otherwise a click opens a text file, as Quick Look
/// would. A file the agent changed or wrote carries a dot.
struct DesktopFilesView: View {
    let model: OnboardingModel

    var body: some View {
        VStack(spacing: OT.Layout.fileSpacing) {
            ForEach(model.desktopFiles) { file in
                VStack(spacing: 4) {
                    Image(nsImage: file.icon)
                        .resizable()
                        .frame(width: OT.Layout.fileIconSize, height: OT.Layout.fileIconSize)
                        .padding(4)
                        .overlay(alignment: .topTrailing) {
                            if model.editedFiles.contains(file.name) {
                                Circle().fill(model.accentColor)
                                    .frame(width: 10, height: 10)
                                    .overlay(Circle().strokeBorder(OT.Colors.fileLabel, lineWidth: 1.5))
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    Text(file.name)
                        .font(OT.Type_.fileName)
                        .foregroundStyle(OT.Colors.fileLabel)
                        .shadow(color: OT.Colors.fileLabelShadow, radius: 2, y: 1)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !model.highlighterOn, !model.screenshotArmed, file.type == "txt" || file.type == "md" else { return }
                    model.previewFile == file.name ? model.hidePreview() : model.showPreview(file.name)
                }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(ScreenSpace.name)) } action: { frame in
                    model.fileFrames[file.name] = frame
                }
                .opacity(model.filesCleared ? 0 : 1)
                .scaleEffect(model.filesCleared ? 0.6 : 1)
                .animation(OT.Motion.slow, value: model.filesCleared)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .frame(width: 110)
        .animation(OT.Motion.calm, value: model.desktopFiles)
    }
}

enum ScreenSpace {
    static let name = "screen"
}

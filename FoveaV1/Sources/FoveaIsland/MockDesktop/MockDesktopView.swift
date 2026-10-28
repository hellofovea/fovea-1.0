import SwiftUI
import AppKit
import FoveaCore

/// The stage: a MacBook display scaled to fit the detail column, never above 1:1, centered,
/// with the lid's bezel around it. Its proportions are the display's whatever the window or
/// the panel does. It reports the column's size; the model derives the scale from it.
struct MockDesktopView: View {
    let model: WorkbenchModel

    var body: some View {
        let display = model.display.frame.size
        let bezel = WorkbenchTokens.Layout.bezel
        let screenRadius = WorkbenchTokens.Layout.screenCornerRadius
        // A clear base, so a display larger than the column never sets the column's minimum.
        Color.clear
            .overlay {
                if model.columnSize != .zero {
                    MockScreen(model: model)
                        .frame(width: display.width, height: display.height)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: screenRadius, topTrailingRadius: screenRadius))
                        .padding(bezel)
                        .background(
                            RoundedRectangle(cornerRadius: WorkbenchTokens.Layout.bezelRadius, style: .continuous)
                                .fill(WorkbenchTokens.Colors.bezel)
                        )
                        .scaleEffect(model.scale)
                }
            }
            .onGeometryChange(for: CGSize.self) { $0.size } action: { model.columnSize = $0 }
            .background(StageProbe(model: model))
    }
}

/// The screen at the display's own size, in display points: the desktop (wallpaper, the menu
/// bar with the notch cut out of it, the Dock) or an app taken full screen.
struct MockScreen: View {
    let model: WorkbenchModel
    /// The window's own scheme: the display's when its Appearance is System.
    @Environment(\.colorScheme) private var windowScheme

    var body: some View {
        let metrics = model.metrics
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                switch model.screenContent {
                case .desktop:
                    WallpaperView(fill: model.wallpaperFill)
                    // The desktop's files, at its right, as macOS lays them out.
                    DesktopFiles(model: model)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, metrics.menuBarHeight + WorkbenchTokens.Layout.desktopFilesTop)
                        .padding(.trailing, WorkbenchTokens.Layout.desktopFilesTrailing)
                    VStack(spacing: 0) {
                        MockMenuBar(height: metrics.menuBarHeight, clock: model.clock)
                        Spacer(minLength: 0)
                        MockDock(icons: model.dockIcons)
                            .padding(.bottom, WorkbenchTokens.Layout.dockBottomInset)
                    }
                case .fullScreenApp:
                    // Full screen sits below the notch: the band beside it is black, the menu bar
                    // and the Dock are gone.
                    MockSafari(model: model)
                        .padding(.top, metrics.safeAreaTop)
                    WorkbenchTokens.Colors.notchBand
                        .frame(height: metrics.safeAreaTop)
                case .splitView:
                    // Split View is full screen too: two apps under the black band (feedback #6).
                    SplitViewScreen(model: model)
                        .padding(.top, metrics.safeAreaTop)
                        .environment(\.colorScheme, .light)
                    WorkbenchTokens.Colors.notchBand
                        .frame(height: metrics.safeAreaTop)
                }
            }
            // Capture mode works on whatever is on screen; the island above it stays live.
            .modifier(CaptureSurface(model: model))
            // Dispatch Version 2's chats pulled out of the notch: windows over the apps, under the island.
            // Fovea's own surfaces; hidden at once while the whole screen is taken.
            Group {
                V2DetachedLayer(model: model)
                MockIsland(model: model)
                CaptureOverlay(model: model)
            }
            .opacity(model.hidingOwnSurfaces ? 0 : 1)
            .animation(nil, value: model.hidingOwnSurfaces)
            // Native's panels take the display's scheme back inside the dark island.
            .environment(\.displayScheme, model.appearance.colorScheme ?? windowScheme)
        }
        // The pointer near the notch opens the control board: `PointerMonitor` feeds the hover, so
        // it answers whether or not the workbench is in front, as a real notch does.
        .coordinateSpace(name: ScreenSpace.name)
        // A real display answers the first click even when another app is in front: a drag to
        // capture, a tab, the stack, a ✕ all work on the click that brings the window forward.
        .answersActivatingClick()
        // The panel's appearance choice: the display alone goes light or dark.
        .transformEnvironment(\.colorScheme) { scheme in
            if let chosen = model.appearance.colorScheme { scheme = chosen }
        }
    }
}

/// The picture fills the screen and never asks for its own size.
struct WallpaperView: View {
    let fill: WallpaperFill

    var body: some View {
        Color.clear
            .overlay {
                switch fill {
                case .image(let image): Image(nsImage: image).resizable().scaledToFill()
                case .color(let color): color
                }
            }
            .clipped()
    }
}

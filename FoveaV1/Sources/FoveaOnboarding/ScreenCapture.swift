import SwiftUI
import AppKit
import OnboardingCore
import FoveaLook

/// The pictures Fovea takes (Oct 9): the whole screen, or part of it, as real images. They show on
/// the referent stack, and go to the agent as files in the practice folder's `.captures`. Drawn
/// from the desktop alone, as Fovea leaves itself out of what it takes: no Island, no board, no
/// keyboard, no pointer.
@MainActor
enum ScreenCapture {
    struct Shot {
        let image: NSImage
        let path: URL?
    }

    /// The whole screen, with a tab showing (the one showing now, unless one is given).
    static func whole(model: OnboardingModel, tab: PracticeTab? = nil, name: String?) -> Shot? {
        guard let image = render(model, tab: tab ?? model.currentTab, scale: 1) else { return nil }
        return Shot(image: image, path: name.flatMap { write(image, to: model.practice, name: $0) })
    }

    /// Part of the screen, in display points, at twice the detail.
    static func region(_ rect: CGRect, model: OnboardingModel, tab: PracticeTab? = nil, name: String?) -> Shot? {
        let bounds = CGRect(origin: .zero, size: OT.Display.size)
        let clipped = rect.intersection(bounds)
        guard !clipped.isNull, clipped.width > 2, clipped.height > 2,
              let full = render(model, tab: tab ?? model.currentTab, scale: 2),
              let cg = full.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let pixels = CGRect(x: clipped.minX * 2, y: clipped.minY * 2, width: clipped.width * 2, height: clipped.height * 2).integral
        guard let cropped = cg.cropping(to: pixels) else { return nil }
        let image = NSImage(cgImage: cropped, size: clipped.size)
        return Shot(image: image, path: name.flatMap { write(image, to: model.practice, name: $0) })
    }

    private static func render(_ model: OnboardingModel, tab: PracticeTab, scale: CGFloat) -> NSImage? {
        let renderer = ImageRenderer(content: DesktopPicture(model: model, tab: tab)
            .foveaLanguage()
            .frame(width: OT.Display.size.width, height: OT.Display.size.height)
            .environment(\.colorScheme, .light))
        renderer.scale = scale
        return renderer.nsImage
    }

    private static func write(_ image: NSImage, to files: PracticeFiles, name: String) -> URL? {
        let folder = files.url(OT.Site.capturesFolder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { return nil }
        do { try data.write(to: url) } catch { return nil }
        return url
    }
}

extension OnboardingModel {
    /// Takes a referent's picture a moment after it's taken, apart from the change that asked for
    /// it (drawn in the middle of a change, the window missed the rest of that change), and fills
    /// it in: in the stack, and in the request if it's already put together. `name`: the file the
    /// agent gets; nil keeps it a picture only.
    func capture(_ id: UUID, region: CGRect? = nil, tab: PracticeTab? = nil, name: String?) {
        let tab = tab ?? currentTab
        DispatchQueue.main.asyncAfter(deadline: .now() + OT.Timing.captureAfter) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                let shot: ScreenCapture.Shot?
                if let region {
                    shot = ScreenCapture.region(region, model: self, tab: tab, name: name)
                } else {
                    shot = ScreenCapture.whole(model: self, tab: tab, name: name)
                }
                guard let shot else { return }
                if let i = self.referents.firstIndex(where: { $0.id == id }) {
                    self.referents[i].image = shot.image
                    self.referents[i].path = shot.path
                }
                if let i = self.request?.referents.firstIndex(where: { $0.id == id }) {
                    self.request?.referents[i].image = shot.image
                    self.request?.referents[i].path = shot.path
                }
            }
        }
    }
}

/// The desktop as a picture: the wallpaper, the menu bar and the Dock (solid, as there's nothing
/// behind them to blur off screen), the files, the browser with a tab showing, and the team chat.
/// Plain shapes only, so it renders off screen.
struct DesktopPicture: View {
    let model: OnboardingModel
    let tab: PracticeTab

    var body: some View {
        ZStack(alignment: .topLeading) {
            WallpaperView()
                .frame(width: OT.Display.size.width, height: OT.Display.size.height)
            VStack(spacing: OT.Layout.fileSpacing) {
                ForEach(model.desktopFiles) { file in
                    VStack(spacing: 4) {
                        Image(nsImage: file.icon).resizable()
                            .frame(width: OT.Layout.fileIconSize, height: OT.Layout.fileIconSize)
                            .padding(4)
                        Text(file.name).font(OT.Type_.fileName).foregroundStyle(OT.Colors.fileLabel)
                            .shadow(color: OT.Colors.fileLabelShadow, radius: 2, y: 1)
                    }
                }
            }
            .frame(width: 110)
            .frame(width: OT.Display.size.width, alignment: .trailing)
            .padding(.top, OT.Display.menuBarHeight + OT.Layout.filesTop)
            .padding(.trailing, OT.Layout.filesTrailing)
            if model.practiceScreen == .dictation {
                // Oct 17, Ryan: dictation takes pictures too; its two windows are what's there.
                FeedbackWindow(model: model, picture: true)
                    .frame(width: OT.Layout.feedbackFrame.width, height: OT.Layout.feedbackFrame.height)
                    .offset(x: OT.Layout.feedbackFrame.minX, y: OT.Layout.feedbackFrame.minY)
                MessagesWindow(model: model, picture: true)
                    .frame(width: OT.Layout.messagesFrame.width, height: OT.Layout.messagesFrame.height)
                    .offset(x: OT.Layout.messagesFrame.minX, y: OT.Layout.messagesFrame.minY)
            } else {
                BrowserPicture(model: model, tab: tab)
                    .frame(width: OT.Layout.practiceFrame.width, height: OT.Layout.practiceFrame.height)
                    .offset(x: OT.Layout.practiceFrame.minX, y: OT.Layout.practiceFrame.minY)
                if model.chatShown {
                    ChatWindow()
                        .frame(width: OT.Layout.chatFrame.width, height: OT.Layout.chatFrame.height)
                        .offset(x: OT.Layout.chatFrame.minX, y: OT.Layout.chatFrame.minY)
                }
            }
            VStack(spacing: 0) {
                MenuBarView(app: model.frontApp, solid: true)
                Spacer(minLength: 0)
                DockView(solid: true).padding(.bottom, OT.Layout.dockBottomInset)
            }
            .frame(width: OT.Display.size.width, height: OT.Display.size.height)
        }
        .frame(width: OT.Display.size.width, height: OT.Display.size.height, alignment: .topLeading)
    }
}

/// The browser with a tab showing, drawn plainly for a picture.
struct BrowserPicture: View {
    let model: OnboardingModel
    let tab: PracticeTab

    var body: some View {
        VStack(spacing: 0) {
            BrowserToolbar(address: tab.address)
            HStack(spacing: 4) {
                ForEach(model.openTabs, id: \.self) { open in
                    Text(open.title)
                        .font(.system(size: 12, weight: open == tab ? .semibold : .regular))
                        .foregroundStyle(open == tab ? OT.Colors.pageText : OT.Colors.toolbarGlyph)
                        .frame(maxWidth: .infinity)
                        .frame(height: OT.Layout.tabBar - 8)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(open == tab ? OT.Colors.practiceWindow : .clear))
                }
            }
            .padding(.horizontal, 10)
            .frame(height: OT.Layout.tabBar)
            .background(OT.Colors.toolbar)
            Rectangle().fill(OT.Colors.practiceEdge).frame(height: 1)
            PageImage(model: model, tab: tab)
        }
        .background(OT.Colors.practiceWindow)
        .clipShape(RoundedRectangle(cornerRadius: OT.Layout.practiceRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OT.Layout.practiceRadius, style: .continuous).strokeBorder(OT.Colors.practiceEdge))
    }
}

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

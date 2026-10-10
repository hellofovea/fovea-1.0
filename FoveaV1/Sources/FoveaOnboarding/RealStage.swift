import SwiftUI
import AppKit
import OnboardingCore
import FoveaKit
import FoveaPlatform

// The first run on the person's own desktop. One transparent window the size of the screen holds
// what Fovea puts there: the reading pages (the desktop frosted and dark behind the words), the
// glass bar while you do, Fovea's own practice windows (the browser and its tabs, the team chat,
// the feedback window, Messages), the trip's files at the right, a file opened as Quick Look would,
// and the arc that shows where to drag Fovea. Everything else is the person's real desktop, and
// clicks go through to it. The island is the real one, above it all (FoveaIsland).

/// The stage, laid out in the screen's own top-down points (the prototype's display points: on a
/// 13-inch MacBook Air they're the same).
struct RealStage: View {
    let model: OnboardingModel

    var body: some View {
        let size = OT.Display.size
        ZStack(alignment: .topLeading) {
            Color.clear.frame(width: size.width, height: size.height)
            DesktopFilesView(model: model)
                .frame(width: size.width, alignment: .trailing)
                .padding(.top, OT.Display.menuBarHeight + OT.Layout.filesTop)
                .padding(.trailing, OT.Layout.filesTrailing)
            windows
            if let name = model.previewFile, let frame = model.fileFrames[name] {
                FilePreview(model: model, name: name)
                    .position(x: frame.minX - OT.Layout.previewSize.width / 2 - 14, y: frame.minY + OT.Layout.previewSize.height / 2)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .trailing)))
            }
            BoardView(model: model)
            OT.Colors.flash
                .frame(width: size.width, height: size.height)
                .opacity(model.flash ? OT.Marks.captureFlash : 0)
                .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .coordinateSpace(name: ScreenSpace.name)
        .onContinuousHover(coordinateSpace: .named(ScreenSpace.name)) { phase in
            if case .active(let point) = phase { model.pointerMoved(point) }
        }
        .environment(\.colorScheme, .light)
        // A click works the first time, even with System Settings in front.
        .clicksWhenInactive()
    }

    /// The windows the step uses: none at first, then the browser and the team chat, or
    /// dictation's two.
    @ViewBuilder
    private var windows: some View {
        switch model.practiceScreen {
        case .empty:
            EmptyView()
        case .page:
            PracticeWindow(model: model)
                .frame(width: OT.Layout.practiceFrame.width, height: OT.Layout.practiceFrame.height)
                .offset(x: OT.Layout.practiceFrame.minX, y: OT.Layout.practiceFrame.minY)
                .transition(.opacity)
            if model.chatShown {
                ChatWindow()
                    .frame(width: OT.Layout.chatFrame.width, height: OT.Layout.chatFrame.height)
                    .offset(x: OT.Layout.chatFrame.minX, y: OT.Layout.chatFrame.minY)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        case .dictation:
            FeedbackWindow(model: model)
                .frame(width: OT.Layout.feedbackFrame.width, height: OT.Layout.feedbackFrame.height)
                .offset(x: OT.Layout.feedbackFrame.minX, y: OT.Layout.feedbackFrame.minY)
                .transition(.opacity)
            MessagesWindow(model: model)
                .frame(width: OT.Layout.messagesFrame.width, height: OT.Layout.messagesFrame.height)
                .offset(x: OT.Layout.messagesFrame.minX, y: OT.Layout.messagesFrame.minY)
                .transition(.opacity)
        }
    }

    /// Where the stage takes clicks: the whole screen on a reading page; else the bar, the
    /// windows, the files and an open file. Everywhere else is the desktop's.
    static func interactive(_ model: OnboardingModel) -> [CGRect]? {
        if model.finished { return [] }
        if model.step.isReading { return nil }
        var rects: [CGRect] = []
        if let bar = model.targets[.board] { rects.append(bar) }
        switch model.practiceScreen {
        case .empty: break
        case .page:
            rects.append(OT.Layout.practiceFrame)
            if model.chatShown { rects.append(OT.Layout.chatFrame) }
        case .dictation:
            rects.append(OT.Layout.feedbackFrame)
            rects.append(OT.Layout.messagesFrame)
        }
        rects.append(contentsOf: model.fileFrames.filter { name, _ in model.desktopFiles.contains { $0.name == name } }.values)
        if let name = model.previewFile, let frame = model.fileFrames[name] {
            rects.append(CGRect(x: frame.minX - OT.Layout.previewSize.width - 14, y: frame.minY,
                                width: OT.Layout.previewSize.width, height: OT.Layout.previewSize.height))
        }
        return rects
    }
}

/// A file opened on the desktop, as Quick Look would: what the agent really changed (Oct 8).
struct FilePreview: View {
    let model: OnboardingModel
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(name).font(.system(size: 12, weight: .semibold)).foregroundStyle(OT.Colors.ink(0.8))
                Spacer()
                if model.editedFiles.contains(name) {
                    Text("Edited by \(model.agentName)").font(.system(size: 11)).foregroundStyle(model.accentColor)
                }
                Button(action: { model.hidePreview() }) {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(OT.Colors.ink(0.45))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(OT.Colors.toolbar)
            Rectangle().fill(OT.Colors.practiceEdge).frame(height: 1)
            Text(model.previewText)
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(OT.Colors.ink(0.85))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
        }
        .frame(width: OT.Layout.previewSize.width, height: OT.Layout.previewSize.height)
        .background(OT.Colors.previewPaper)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(OT.Colors.practiceEdge))
        .shadow(color: OT.Colors.practiceShadow, radius: 24, y: 12)
    }
}

/// The stage's window: borderless, clear, the size of the screen, among the ordinary windows (so
/// System Settings, opened by its link, comes over it). It can take the keyboard (a language typed
/// under More…, words pasted in), and lets clicks through where nothing of Fovea is.
final class StageWindow: NSWindow {
    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        // Over the other windows while the tour runs, so its bar stays in sight with System
        // Settings open; clicks go through it everywhere it doesn't draw.
        level = .floating
        collectionBehavior = [.fullScreenNone, .moveToActiveSpace]
        acceptsMouseMovedEvents = true
        animationBehavior = .none
        setAccessibilityIdentifier("fovea.first-run")
        title = "Fovea"
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

extension View {
    /// A click on the stage works the first time, even with another app in front (macOS 15 and
    /// later): it stands for a whole screen, where nothing asks for a click to bring it forward.
    @ViewBuilder
    func clicksWhenInactive() -> some View {
        if #available(macOS 15.0, *) { allowsWindowActivationEvents(true) } else { self }
    }
}

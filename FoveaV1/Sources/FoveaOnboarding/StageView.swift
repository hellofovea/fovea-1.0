import SwiftUI
import AppKit
import OnboardingCore

/// The stage: a MacBook display, scaled to fit and never above 1:1, inside its bezel.
struct StageView: View {
    let model: OnboardingModel

    var body: some View {
        GeometryReader { geo in
            let lid = OT.Display.lid
            let scale = min(1, min((geo.size.width - 48) / lid.width, (geo.size.height - 48) / lid.height))
            ScreenView(model: model)
                .frame(width: OT.Display.size.width, height: OT.Display.size.height)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: OT.Display.screenRadius,
                                                  topTrailingRadius: OT.Display.screenRadius, style: .continuous))
                .padding(OT.Display.bezel)
                .background(RoundedRectangle(cornerRadius: OT.Display.bezelRadius, style: .continuous).fill(OT.Colors.bezel))
                .frame(width: lid.width, height: lid.height)
                .scaleEffect(max(0.2, scale))
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .clicksWhenInactive()
    }
}

extension View {
    /// A click on the stage works the first time, even with the window behind another app's: it
    /// stands for a whole screen, where nothing asks for a click to bring it forward first (Oct 9:
    /// a first click that only woke the window read as a send button that didn't work).
    @ViewBuilder
    func clicksWhenInactive() -> some View {
        if #available(macOS 15.0, *) { allowsWindowActivationEvents(true) } else { self }
    }
}

/// The screen at the display's own size, in display points: the desktop, the practice windows,
/// System Settings when it's asked for, the board, the alerts, and the Island over everything.
struct ScreenView: View {
    let model: OnboardingModel

    private var size: CGSize { OT.Display.size }

    var body: some View {
        ZStack(alignment: .topLeading) {
            WallpaperView()
                .frame(width: size.width, height: size.height)
            DesktopFilesView(model: model)
                .frame(width: size.width, alignment: .trailing)
                .padding(.top, OT.Display.menuBarHeight + OT.Layout.filesTop)
                .padding(.trailing, OT.Layout.filesTrailing)
            windows
            if let pane = model.settingsPane {
                SystemSettingsWindow(model: model, pane: pane)
                    .frame(width: OT.Layout.settingsFrame.width, height: OT.Layout.settingsFrame.height)
                    .offset(x: OT.Layout.settingsFrame.minX, y: OT.Layout.settingsFrame.minY)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            HighlightMarks(model: model)
            // A macOS alert dims what's behind it.
            OT.Colors.dim
                .frame(width: size.width, height: size.height)
                .opacity(model.alert != nil ? 1 : 0)
                .allowsHitTesting(false)
            if let selection = model.selection {
                SelectionView(rect: selection, accent: model.accentColor)
            }
            VStack(spacing: 0) {
                MenuBarView(app: model.frontApp)
                Spacer(minLength: 0)
                DockView().padding(.bottom, OT.Layout.dockBottomInset)
            }
            .frame(width: size.width, height: size.height)
            if model.screenshotArmed || model.highlighterOn {
                CaptureLayer(model: model)
            }
            if let name = model.previewFile, let frame = model.fileFrames[name] {
                FilePreview(model: model, name: name)
                    .position(x: frame.minX - OT.Layout.previewSize.width / 2 - 14, y: frame.minY + OT.Layout.previewSize.height / 2)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .trailing)))
            }
            BoardView(model: model)
            if let alert = model.alert {
                MockAlertView(model: model, alert: alert)
                    .frame(width: size.width, height: size.height)
                    .transition(.opacity)
            }
            if model.step == .permissions {
                DragHint(model: model)
            }
            if let drag = model.tileDrag {
                TileView(dragging: true)
                    .position(drag)
                    .allowsHitTesting(false)
            }
            IslandView(model: model)
                .frame(width: size.width, alignment: .top)
            if let ghost = model.ghost {
                GhostPointer(ghost: ghost)
                    .position(ghost.position)
                    .allowsHitTesting(false)
            }
            OT.Colors.flash
                .frame(width: size.width, height: size.height)
                .opacity(model.flash ? (model.step == .permissions ? OT.Marks.reopenFlash : OT.Marks.captureFlash) : 0)
                .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .coordinateSpace(name: ScreenSpace.name)
        .onContinuousHover(coordinateSpace: .named(ScreenSpace.name)) { phase in
            // While the run plays itself, its own pointer is the one at the notch.
            if case .active(let point) = phase, !model.playing { model.pointerMoved(point) }
        }
        .environment(\.colorScheme, .light)
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
}

/// While ⌘ or the highlighter is on: the whole screen takes the drag (or the click), under a
/// crosshair for ⌘ and the accent arrow for the highlighter.
struct CaptureLayer: View {
    let model: OnboardingModel
    @State private var start: CGPoint?

    var body: some View {
        OT.Colors.hitLayer
            .frame(width: OT.Display.size.width, height: OT.Display.size.height)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(ScreenSpace.name))
                    .onChanged { value in
                        if start == nil { start = value.startLocation }
                        model.dragChanged(from: value.startLocation, to: value.location)
                    }
                    .onEnded { value in
                        start = nil
                        model.dragEnded(from: value.startLocation, to: value.location)
                    }
            )
            .screenPointer(screenshot: model.screenshotArmed, highlighting: model.highlighterOn, accent: model.personal.accent)
    }
}

/// A screenshot's drag in progress: its rectangle.
struct SelectionView: View {
    let rect: CGRect
    let accent: Color

    var body: some View {
        Rectangle()
            .fill(accent.opacity(OT.Marks.selectionOpacity))
            .overlay(Rectangle().strokeBorder(accent.opacity(OT.Marks.selectionEdgeOpacity), lineWidth: OT.Marks.selectionEdgeWidth))
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .allowsHitTesting(false)
    }
}

/// The highlighter's marks, in the accent color: a marker's strokes over the words (multiplied
/// into the page, as ink is), a ring round a file, and the strokes being drawn (the Workbench's
/// HighlightMarks). They stay while the request lasts.
struct HighlightMarks: View {
    let model: OnboardingModel

    var body: some View {
        let ink = model.accentColor
        ZStack(alignment: .topLeading) {
            ForEach(model.marks) { mark in
                ForEach(Array(mark.rects.enumerated()), id: \.offset) { _, rect in
                    if mark.file {
                        RoundedRectangle(cornerRadius: OT.Marks.fileRadius, style: .continuous)
                            .fill(ink.opacity(OT.Marks.fileOpacity))
                            .overlay(RoundedRectangle(cornerRadius: OT.Marks.fileRadius, style: .continuous)
                                .strokeBorder(ink.opacity(OT.Marks.fileEdgeOpacity), lineWidth: OT.Marks.fileEdgeWidth))
                            .frame(width: rect.width, height: rect.height)
                            .offset(x: rect.minX, y: rect.minY)
                    } else {
                        stroke(rect, ink: ink)
                    }
                }
            }
            .transition(.opacity)
            if let draft = model.markDraft {
                ForEach(Array(draft.enumerated()), id: \.offset) { _, rect in stroke(rect, ink: ink) }
            }
        }
        .frame(width: OT.Display.size.width, height: OT.Display.size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func stroke(_ rect: CGRect, ink: Color) -> some View {
        RoundedRectangle(cornerRadius: OT.Marks.radius, style: .continuous)
            .fill(ink.opacity(OT.Marks.opacity))
            .blendMode(.multiply)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }
}

/// The ghost's pointer, for "watch once" and the play. Its keys show on the keyboard in the bar.
struct GhostPointer: View {
    let ghost: Ghost

    var body: some View {
        Image(systemName: "cursorarrow")
            .font(.system(size: OT.Layout.pointerSize, weight: .regular))
            .foregroundStyle(OT.Colors.ghostArrow)
            .background(Image(systemName: "cursorarrow").font(.system(size: OT.Layout.pointerSize + 3)).foregroundStyle(OT.Colors.ghostArrowEdge))
            .scaleEffect(ghost.pressing ? 0.9 : 1)
            .frame(width: 40, height: 40, alignment: .topLeading)
            .offset(x: 14, y: 14)
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

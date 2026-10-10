import SwiftUI
import AppKit
import FoveaCore
import FoveaKit

// The Oct 6 feedback's Voiceflow views (Feedback.swift has the flow): the errors' notice (#2),
// picking text and files with ⌘ (#3), the last minute's countdown (#4), Split View (#6) and the
// words landing in their field (#7). docs/island/FEEDBACK_2026-10-06.md has the reasons.

// MARK: - #2 The notice

/// Where the notice's island goes: Paste not found's width and corners, one row (and a line of
/// message under it when there is one); inside the listening bar, the bar a little wider.
enum VoiceErrorLayout {
    static func outline(_ error: VoiceError, metrics: ScreenMetrics) -> StackLayout.Outline {
        let F = WorkbenchTokens.Feedback.self
        let spec = WorkbenchTokens.Island.spec
        let notch = NotchGeometry.notchRect(metrics: metrics, spec: spec)
        let message = error.message == nil ? 0 : F.noticeMessageGap + F.noticeMessageHeight
        let height = notch.height + F.noticePaddingTop + F.noticeRow + message + F.noticePaddingBottom
        return StackLayout.Outline(size: CGSize(width: F.noticeWidth, height: height),
                                   topRadius: spec.expandedTopRadius, bottomRadius: F.noticeBottomRadius)
    }

    /// The listening bar holding a notice: its own height and corners, wider.
    static func barOutline(metrics: ScreenMetrics) -> StackLayout.Outline {
        let spec = WorkbenchTokens.Island.spec
        let frames = NotchGeometry.frames(density: .voice, metrics: metrics, spec: spec)
        return StackLayout.Outline(size: CGSize(width: WorkbenchTokens.Feedback.barNoticeWidth, height: frames.minHeight),
                                   topRadius: frames.topRadius, bottomRadius: frames.bottomRadius)
    }

    static var bodyWidth: CGFloat {
        WorkbenchTokens.Feedback.noticeWidth - 2 * WorkbenchTokens.Island.spec.expandedTopRadius
    }
}

extension VoiceError {
    var toneColor: Color {
        let F = WorkbenchTokens.Feedback.self
        switch tone {
        case .info: return F.infoColor
        case .yours: return F.yoursColor
        case .failure: return F.failureColor
        }
    }
}

/// The island in place of the bar: the glyph in the tone's color, what happened, the one action,
/// ✕ in the ring of the time left; a line of what to do under it.
struct VoiceErrorContent: View {
    let model: WorkbenchModel

    var body: some View {
        let F = WorkbenchTokens.Feedback.self
        let error = model.voiceError ?? .offline
        VStack(alignment: .leading, spacing: F.noticeMessageGap) {
            HStack(spacing: F.noticeSpacing) {
                Image(systemName: error.symbol)
                    .font(F.noticeGlyph)
                    .foregroundStyle(error.toneColor)
                    .frame(width: F.noticeGlyphWidth)
                Text(error.title)
                    .font(F.noticeTitle)
                    .foregroundStyle(F.noticeTitleColor)
                    .lineLimit(1)
                Spacer(minLength: F.noticeSpacing)
                if let action = error.action {
                    NoticeActionButton(title: action.rawValue) { model.performErrorAction(error) }
                }
                ErrorCloseButton(model: model)
            }
            .frame(height: F.noticeRow)
            if let message = error.message {
                Text(message)
                    .font(F.noticeMessage)
                    .foregroundStyle(F.noticeMessageColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, F.noticeGlyphWidth + F.noticeSpacing)
                    .frame(height: F.noticeMessageHeight, alignment: .topLeading)
            }
        }
        .padding(.horizontal, F.noticePaddingH)
        .padding(.top, F.noticePaddingTop)
        .frame(width: VoiceErrorLayout.bodyWidth, alignment: .topLeading)
        .contentShape(Rectangle())
        .onHover { model.setErrorHover($0) }
        .panelScheme()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(error.title). \(error.message ?? "")")
    }
}

/// The notice's one action: Paste not found's gray capsule.
struct NoticeActionButton: View {
    let title: String
    /// Inside the listening bar: the voice bar's size, whatever the density.
    var inBar = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let F = WorkbenchTokens.Feedback.self
        Button(action: action) {
            Text(title)
                .font(inBar ? F.barActionFont : F.actionFont)
                .foregroundStyle(WorkbenchTokens.ink(1))
                .padding(.horizontal, inBar ? F.barActionPaddingH : F.actionPaddingH)
                .frame(height: inBar ? F.barActionHeight : F.actionHeight)
        }
        .buttonStyle(PasteCapsuleStyle(hovering: hovering))
        .onHover { hovering = $0 }
        .animation(WorkbenchTokens.Paste.hover, value: hovering)
        .accessibilityLabel(title)
    }
}

/// ✕ in the ring of the time left, as Paste not found's.
struct ErrorCloseButton: View {
    let model: WorkbenchModel
    @State private var hovering = false

    var body: some View {
        let P = WorkbenchTokens.Paste.self
        let running = model.notchState == .voiceError && model.errorStart != nil && model.errorPausedAt == nil && !model.snapshotMode
        Button { model.dismissVoiceError() } label: {
            ZStack {
                Circle().fill(hovering ? P.closeFillHover : .clear).frame(width: P.closeDiscSize, height: P.closeDiscSize)
                TimelineView(.animation(minimumInterval: 1 / 60, paused: !running)) { context in
                    PasteRing(fraction: model.errorRemaining(at: context.date))
                }
                Image(systemName: "xmark")
                    .font(P.closeGlyph)
                    .foregroundStyle(hovering ? P.closeGlyphHover : P.closeGlyphColor)
            }
            .frame(width: P.ringDiameter, height: P.ringDiameter)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(P.hover, value: hovering)
        .help("Dismiss (esc)")
        .accessibilityLabel("Dismiss")
    }
}

/// Inside the listening bar: one line and its action; the bar goes on listening under it.
struct BarNoticeBand: View {
    let model: WorkbenchModel

    var body: some View {
        let F = WorkbenchTokens.Feedback.self
        let error = model.barNotice ?? .screenRecording
        HStack(spacing: F.barNoticeSpacing) {
            Image(systemName: error.symbol)
                .font(F.barNoticeGlyph)
                .foregroundStyle(error.toneColor)
            Text(error.title)
                .font(F.barNoticeTitle)
                .foregroundStyle(F.noticeTitleColor)
                .lineLimit(1)
            Spacer(minLength: F.barNoticeTrailing)
            if let action = error.action {
                NoticeActionButton(title: action.rawValue, inBar: true) { model.performErrorAction(error) }
            }
        }
        .padding(.horizontal, F.barNoticePaddingH)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .panelScheme()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(error.title)
    }
}

// MARK: - #3, #8 The highlighter

/// The highlighter's marks, in the accent color: a marker's strokes over the words (multiplied
/// into the page, as ink is), a rounded mark round a file, and the stroke being drawn.
struct HighlightMarks: View {
    let model: WorkbenchModel

    var body: some View {
        let F = WorkbenchTokens.Feedback.self
        let ink = model.accent.color
        let live = model.live != nil
        ZStack(alignment: .topLeading) {
            // ⌥ on: the file under the pointer, shaded before it's clicked.
            if live, let hover = model.hoverMark {
                neutral(hover, radius: F.fileMarkRadius, fill: F.liveHoverFill, outline: true)
                    .transition(.opacity)
            }
            ForEach(model.highlights) { mark in
                ForEach(Array(mark.rects.enumerated()), id: \.offset) { _, rect in
                    if live {
                        neutral(rect, radius: mark.file ? F.fileMarkRadius : F.markRadius, fill: F.liveMarkFill, outline: mark.file)
                    } else if mark.file {
                        RoundedRectangle(cornerRadius: F.fileMarkRadius, style: .continuous)
                            .fill(ink.opacity(F.fileMarkOpacity))
                            .overlay(RoundedRectangle(cornerRadius: F.fileMarkRadius, style: .continuous)
                                .strokeBorder(ink.opacity(0.9), lineWidth: 1.5))
                            .frame(width: rect.width, height: rect.height)
                            .offset(x: rect.minX, y: rect.minY)
                    } else {
                        stroke(rect, ink: ink)
                    }
                }
            }
            .transition(.opacity)
            if let draft = model.highlightDraft {
                ForEach(Array(draft.enumerated()), id: \.offset) { _, rect in
                    if live { neutral(rect, radius: F.markRadius, fill: F.liveMarkFill, outline: false) } else { stroke(rect, ink: ink) }
                }
            }
        }
        .animation(live ? F.liveMarkFade : F.markFade, value: model.highlights)
        .animation(F.markFade, value: model.hoverMark)
    }

    private func stroke(_ rect: CGRect, ink: Color) -> some View {
        let F = WorkbenchTokens.Feedback.self
        return RoundedRectangle(cornerRadius: F.markRadius, style: .continuous)
            .fill(ink.opacity(F.markOpacity))
            .blendMode(.multiply)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }

    /// The real Mac's mark: light gray, a thin outline where it rings a thing.
    private func neutral(_ rect: CGRect, radius: CGFloat, fill: Color, outline: Bool) -> some View {
        let F = WorkbenchTokens.Feedback.self
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return shape.fill(fill)
            .overlay(shape.strokeBorder(outline ? F.liveMarkStroke : .clear, lineWidth: F.liveMarkStrokeWidth))
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }
}

/// The highlighter's pointer: the system's arrow, filled with the accent color (nothing else
/// changes; no pen rides on it). Drawn once per color, its tip the hot spot.
@MainActor
enum AccentArrow {
    private static var cache: [FoveaAccent: NSImage] = [:]
    static let size = NSSize(width: 24, height: 24)
    static let tip = NSPoint(x: 5, y: 3)

    static func image(_ accent: FoveaAccent) -> NSImage {
        if let hit = cache[accent] { return hit }
        let image = NSImage(size: size, flipped: true) { _ in
            let arrow = NSBezierPath()
            arrow.move(to: NSPoint(x: 5, y: 3))
            arrow.line(to: NSPoint(x: 5, y: 19.5))
            arrow.line(to: NSPoint(x: 9, y: 15.6))
            arrow.line(to: NSPoint(x: 11.6, y: 21.4))
            arrow.line(to: NSPoint(x: 14.2, y: 20.2))
            arrow.line(to: NSPoint(x: 11.7, y: 14.6))
            arrow.line(to: NSPoint(x: 17, y: 14.6))
            arrow.close()
            arrow.lineJoinStyle = .round
            NSGraphicsContext.current?.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
            shadow.shadowBlurRadius = 1.5
            shadow.shadowOffset = NSSize(width: 0, height: -0.5)
            shadow.set()
            NSColor.white.setFill()
            let outline = arrow.copy() as! NSBezierPath
            outline.lineWidth = 2.6
            NSColor.white.setStroke()
            outline.stroke()
            NSGraphicsContext.current?.restoreGraphicsState()
            NSColor(accent.color).setFill()
            arrow.fill()
            return true
        }
        cache[accent] = image
        return image
    }

    static func cursor(_ accent: FoveaAccent) -> NSCursor { NSCursor(image: image(accent), hotSpot: tip) }
}

extension View {
    /// The pointer over the mock screen: the selection crosshair while capturing, the accent arrow
    /// while highlighting, the system's otherwise. One modifier decides, so the two never fight
    /// (two styles on one view made the pointer flicker).
    @ViewBuilder
    func screenCursor(capturing: Bool, highlighting: Bool, accent: FoveaAccent) -> some View {
        if #available(macOS 15, *) {
            pointerStyle(capturing ? .rectSelection
                         : highlighting ? .image(Image(nsImage: AccentArrow.image(accent)),
                                                 hotSpot: UnitPoint(x: AccentArrow.tip.x / AccentArrow.size.width,
                                                                    y: AccentArrow.tip.y / AccentArrow.size.height))
                         : nil)
        } else {
            onContinuousHover { phase in
                guard capturing || highlighting else { return }
                switch phase {
                case .active: (capturing ? NSCursor.crosshair : AccentArrow.cursor(accent)).set()
                case .ended: NSCursor.arrow.set()
                }
            }
        }
    }
}

/// Fovea's accent, as System Settings › Appearance lays its colors out: a row of discs, the chosen
/// one ringed.
struct AccentPicker: View {
    @Binding var accent: FoveaAccent

    var body: some View {
        HStack(spacing: 8) {
            ForEach(FoveaAccent.allCases) { choice in
                Button { accent = choice } label: {
                    Circle()
                        .fill(choice == .multicolor
                              ? AnyShapeStyle(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red],
                                                              center: .center))
                              : AnyShapeStyle(choice.color))
                        .frame(width: 16, height: 16)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
                        .overlay(Circle().fill(Color.white).frame(width: 6, height: 6).opacity(choice == accent ? 1 : 0))
                        .padding(2)
                        .overlay(Circle().strokeBorder(choice.color.opacity(choice == accent ? 0.6 : 0), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .help(choice == .multicolor ? "Multicolor: follows your Mac" : choice.title)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Accent color")
    }
}

// MARK: - #4 The countdown

/// The last minute, at the bar's right (the stack is at its left): white, amber in the last
/// ten seconds.
struct RecordingCountdown: View {
    let model: WorkbenchModel

    var body: some View {
        let F = WorkbenchTokens.Feedback.self
        let running = model.notchState.collects && !model.snapshotMode
        TimelineView(.animation(minimumInterval: 1 / 10, paused: !running)) { context in
            let left = model.recordingRemaining(at: context.date) ?? F.countdownFrom
            let seconds = Int(left.rounded(.up))
            Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                .font(F.countdownFont)
                .foregroundStyle(left <= F.countdownWarn ? F.countdownWarnColor : F.countdownColor)
                .contentTransition(.numericText(countsDown: true))
                .frame(width: F.countdownWidth, alignment: .trailing)
                .accessibilityLabel("\(seconds) seconds left")
        }
    }
}

// MARK: - #7 The words landing

/// Words in a field: just landed, they sit on the selection's blue for a moment, which fades, and
/// they settle from a hair smaller (the field lights as the notch leaves). While the bar listens,
/// the field the words will go to shows the insertion caret in the accent color, blinking.
struct LandingText: View {
    let text: String?
    let placeholder: String
    let landedAt: Date?
    var font: Font = WorkbenchTokens.Safari.commentFont
    var caret: Color? = nil
    /// Snapshots hold the caret on.
    var steady = false

    var body: some View {
        let F = WorkbenchTokens.Feedback.self
        let glowing = landedAt.map { Date().timeIntervalSince($0) <= F.landGlow } ?? false
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !glowing && caret == nil)) { context in
            let t = landedAt.map { context.date.timeIntervalSince($0) } ?? F.landGlow
            let glow = text == nil ? 0 : max(0, 1 - t / F.landGlow)
            let settle = min(1, t / 0.25)
            let on = steady || Int(context.date.timeIntervalSinceReferenceDate / F.caretBlink) % 2 == 0
            let mark = caret.map { Text("▏").foregroundColor(on ? $0 : .clear) } ?? Text("")
            Group {
                if let text {
                    Text(text).foregroundColor(.primary) + mark
                } else {
                    mark + Text(placeholder).foregroundColor(Color.primary.opacity(0.3))
                }
            }
            .font(font)
            .background(F.landHighlight.opacity(glow).padding(-2))
            .scaleEffect(text == nil ? 1 : F.landScale + (1 - F.landScale) * settle, anchor: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - #6 Split View

/// Two apps side by side in Split View, as macOS draws it full screen: the band beside the notch
/// black, a thin divider, Mail's new message at the left and Messages at the right. Each has a
/// field; while the bar listens, the one under the pointer shows the caret in the accent color,
/// and that is where the words go.
struct SplitViewScreen: View {
    let model: WorkbenchModel

    var body: some View {
        let F = WorkbenchTokens.Feedback.self
        let listening = model.dictating
        let target = model.splitTarget
        HStack(spacing: F.splitDivider) {
            SplitMailWindow(text: model.splitPasted[.left], landedAt: model.pasteLanding,
                            caret: listening && target == .left ? model.accent.color : nil, steady: model.snapshotMode)
            SplitMessagesWindow(text: model.splitPasted[.right], landedAt: model.pasteLanding,
                                caret: listening && target == .right ? model.accent.color : nil, steady: model.snapshotMode)
        }
        .padding(.top, 2)
        .background(Color.black)
    }
}

struct SplitMailWindow: View {
    let text: String?
    let landedAt: Date?
    let caret: Color?
    var steady = false

    var body: some View {
        let F = WorkbenchTokens.Feedback.self
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "paperplane.fill").foregroundStyle(Color.accentColor)
                Text("New Message").font(.system(size: 13, weight: .semibold))
                Spacer()
                Image(systemName: "paperclip")
                Image(systemName: "textformat")
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .background(WorkbenchTokens.Materials.menuBar)
            Divider()
            field("To:", "Sam Lee")
            field("Subject:", "Launch plan")
            VStack(alignment: .leading) {
                LandingText(text: text, placeholder: "Write your message…", landedAt: landedAt,
                            font: .system(size: 14), caret: caret, steady: steady)
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                Spacer()
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(WorkbenchTokens.Colors.page)
        .clipShape(RoundedRectangle(cornerRadius: F.splitWindowRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mail, New Message")
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(label).foregroundStyle(.secondary)
                Text(value)
                Spacer()
            }
            .font(.system(size: 13))
            .padding(.horizontal, 16)
            .frame(height: 34)
            Divider().padding(.leading, 16)
        }
    }
}

struct SplitMessagesWindow: View {
    let text: String?
    let landedAt: Date?
    let caret: Color?
    var steady = false

    var body: some View {
        let F = WorkbenchTokens.Feedback.self
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Circle().fill(Color(red: 0.55, green: 0.6, blue: 0.68)).frame(width: 26, height: 26)
                    .overlay(Text("MW").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Mia Wong").font(.system(size: 13, weight: .semibold))
                    Text("iMessage").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "video").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(WorkbenchTokens.Materials.menuBar)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                bubble("Are we still on for the design review at two?", mine: false)
                bubble("Yes! Sending notes in a sec.", mine: true)
                bubble("Great — can you include the notch spacing numbers?", mine: false)
                Spacer()
            }
            .padding(16)
            HStack {
                LandingText(text: text, placeholder: "iMessage", landedAt: landedAt, font: .system(size: 13.5), caret: caret, steady: steady)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule(style: .continuous).strokeBorder(Color.primary.opacity(0.18)))
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(WorkbenchTokens.Colors.page)
        .clipShape(RoundedRectangle(cornerRadius: F.splitWindowRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Messages, Mia Wong")
    }

    private func bubble(_ text: String, mine: Bool) -> some View {
        HStack {
            if mine { Spacer(minLength: 60) }
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(mine ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(mine ? Color.accentColor : Color.primary.opacity(0.09)))
            if !mine { Spacer(minLength: 60) }
        }
    }
}

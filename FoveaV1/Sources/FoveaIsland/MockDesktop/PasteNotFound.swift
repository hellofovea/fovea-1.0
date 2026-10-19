import SwiftUI
import FoveaCore
import FoveaLook

// Paste not found, drawn in the island under the notch: the transcript's first lines (cut at
// the tail), then ✕ at the left in the countdown's ring, the chevron in the middle, Copy at the
// right. The chevron opens the island downward to the whole transcript.
// Geometry is pure (`PasteLayout`), so the outline, the views and the checks share one answer.
// docs/island/PASTE_NOT_FOUND.md has the reasons.

/// Where Paste not found's parts go. x is measured from the island's center, y from its top.
struct PasteLayout: Equatable {
    var outline: StackLayout.Outline
    /// Between the ears: what the content can use, padding included.
    var bodyWidth: CGFloat
    var textWidth: CGFloat
    /// The transcript's area as shown, closed (the fixed lines) and opened (all of it, up to
    /// the maximum, scrolling past it).
    var textHeight: CGFloat
    var closedTextHeight: CGFloat
    var openTextHeight: CGFloat
    /// The whole transcript is taller than the closed lines: the chevron shows.
    var truncated: Bool
    /// Opened, it scrolls.
    var scrolls: Bool
    var textTop: CGFloat
    var rowTop: CGFloat
    /// ✕ and the ring around it.
    var closeCenter: CGPoint
    var expandCenter: CGPoint
    /// Inside the Copy button, whatever its label.
    var copyPoint: CGPoint

    static func make(expanded: Bool, textHeight: CGFloat, linesHeight: CGFloat, metrics: ScreenMetrics) -> PasteLayout {
        let P = WorkbenchTokens.Paste.self
        let spec = WorkbenchTokens.Island.spec
        let notch = NotchGeometry.notchRect(metrics: metrics, spec: spec)
        let bodyWidth = P.width - 2 * spec.expandedTopRadius
        let textWidth = bodyWidth - 2 * P.paddingH
        // Until the view has measured the words, a line is about 18 pt.
        let closed = linesHeight > 0 ? linesHeight : CGFloat(P.lines) * 18
        let full = textHeight > 0 ? textHeight : closed
        let truncated = full > closed + 0.5
        let open = truncated ? min(full, P.maxTextHeight) : closed
        let shown = expanded ? open : closed
        let textTop = notch.height + P.paddingTop
        let rowTop = textTop + shown + P.rowGap
        let height = rowTop + P.rowHeight + P.paddingBottom
        let rowMid = rowTop + P.rowHeight / 2
        let left = -bodyWidth / 2 + P.paddingH
        return PasteLayout(
            outline: StackLayout.Outline(size: CGSize(width: P.width, height: height),
                                         topRadius: spec.expandedTopRadius, bottomRadius: P.bottomRadius),
            bodyWidth: bodyWidth, textWidth: textWidth,
            textHeight: shown, closedTextHeight: closed, openTextHeight: open,
            truncated: truncated, scrolls: full > P.maxTextHeight + 0.5,
            textTop: textTop, rowTop: rowTop,
            closeCenter: CGPoint(x: left + P.ringDiameter / 2, y: rowMid),
            expandCenter: CGPoint(x: 0, y: rowMid),
            copyPoint: CGPoint(x: bodyWidth / 2 - P.paddingH - 22, y: rowMid))
    }
}

/// The island's content for Paste not found, under the notch.
struct PasteNotFoundContent: View {
    let model: WorkbenchModel
    let layout: PasteLayout

    var body: some View {
        let P = WorkbenchTokens.Paste.self
        VStack(spacing: 0) {
            PasteTranscript(text: model.transcript, expanded: model.pasteExpanded, layout: layout)
                .modifier(RevealHeight(height: layout.textHeight))
                .animation(model.islandAnimation, value: layout.textHeight)
            PasteControls(model: model, truncated: layout.truncated)
                .frame(height: P.rowHeight)
                .padding(.top, P.rowGap)
        }
        .padding(.horizontal, P.paddingH)
        .padding(.top, P.paddingTop)
        .padding(.bottom, P.paddingBottom)
        .frame(width: layout.bodyWidth, alignment: .top)
        // Oct 15 review, VF09: the pointer on the held words holds the close; leaving starts it again.
        .contentShape(Rectangle())
        .onHover { model.setPasteHover($0) }
        // White on black, whatever the display's appearance: the scroller included.
        .panelScheme()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Paste not found")
    }
}

/// The words: the first lines cut at the tail with an ellipsis, or all of them. Both are drawn
/// top-aligned in the same place, so opening only dissolves the ellipsis while the island
/// uncovers the lines below.
struct PasteTranscript: View {
    let text: String
    let expanded: Bool
    let layout: PasteLayout

    var body: some View {
        let P = WorkbenchTokens.Paste.self
        ZStack(alignment: .topLeading) {
            Text(text)
                .lineLimit(P.lines)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .opacity(expanded ? 0 : 1)
            // A scroll view is an AppKit view that takes clicks even when hidden, so it is only in
            // the tree while the transcript is open.
            if layout.scrolls {
                if expanded {
                    ScrollView {
                        Text(text)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .scrollIndicators(.automatic)
                    .frame(height: layout.openTextHeight)
                    .transition(.opacity)
                }
            } else {
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .opacity(expanded ? 1 : 0)
            }
        }
        .font(P.text)
        .lineSpacing(P.lineSpacing)
        .foregroundStyle(P.textColor)
        .animation(P.textSwap, value: expanded)
    }
}

/// A height that moves through real layout on every frame, clipping what is below it: the
/// transcript's lines are uncovered as the island grows, never drawn past it.
struct RevealHeight: ViewModifier, Animatable {
    var height: CGFloat
    var animatableData: CGFloat {
        get { height }
        set { height = newValue }
    }

    func body(content: Content) -> some View {
        content
            .frame(height: max(0, height), alignment: .top)
            .clipped()
    }
}

/// ✕ at the left, the chevron centered under the words, Paste and Copy at the right (Copy keeps
/// its place at the edge).
struct PasteControls: View {
    let model: WorkbenchModel
    let truncated: Bool

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                PasteCloseButton(model: model)
                Spacer(minLength: 8)
                // Oct 15 review, VF10: Paste beside Copy, into the field focused now.
                PastePasteButton(model: model)
                    .padding(.trailing, WorkbenchTokens.Paste.buttonGap)
                PasteCopyButton(copied: model.pasteCopied) { model.copyTranscript() }
            }
            if truncated {
                PasteExpandButton(expanded: model.pasteExpanded) { model.setPasteExpanded(!model.pasteExpanded) }
                    .transition(.opacity)
            }
        }
    }
}

/// ✕ in the countdown's ring: the time left drains around the control that would end it
/// sooner, opened or not. A plain glyph, the island's quietest control; a disc lifts inside the
/// ring under the pointer, and the target reaches past the ring.
struct PasteCloseButton: View {
    let model: WorkbenchModel
    @State private var hovering = false

    var body: some View {
        let P = WorkbenchTokens.Paste.self
        let running = model.notchState == .pasteNotFound && model.pasteStart != nil
            && model.pastePausedAt == nil && !model.snapshotMode
        Button { model.dismissPaste() } label: {
            ZStack {
                Circle()
                    .fill(hovering ? P.closeFillHover : .clear)
                    .frame(width: P.closeDiscSize, height: P.closeDiscSize)
                TimelineView(.animation(minimumInterval: 1 / 60, paused: !running)) { context in
                    PasteRing(fraction: model.pasteRemaining(at: context.date))
                }
                Image(systemName: "xmark")
                    .font(P.closeGlyph)
                    .foregroundStyle(hovering ? P.closeGlyphHover : P.closeGlyphColor)
            }
            .frame(width: P.ringDiameter, height: P.ringDiameter)
            .frame(width: P.closeHitSize, height: P.closeHitSize)
            .contentShape(Circle())
            .padding(.horizontal, -(P.closeHitSize - P.ringDiameter) / 2)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(P.hover, value: hovering)
        .help("Dismiss (esc)")
        .accessibilityLabel("Dismiss")
        .accessibilityValue("Closes in \(Int((model.pasteRemaining(at: Date()) * P.duration.seconds).rounded(.up))) seconds")
    }
}

/// The countdown's ring: the track all the way round, the time left from twelve o'clock
/// clockwise, its end drawing back toward twelve as it drains (the undo line's drain, bent
/// round). Round caps, the lines' white on their track.
struct PasteRing: View {
    let fraction: Double

    var body: some View {
        let P = WorkbenchTokens.Paste.self
        ZStack {
            Circle().strokeBorder(P.ringTrack, lineWidth: P.ringWeight)
            Circle()
                .inset(by: P.ringWeight / 2)
                .trim(from: 0, to: max(0, min(1, fraction)))
                .stroke(P.ringFill, style: StrokeStyle(lineWidth: P.ringWeight, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityHidden(true)
    }
}

/// The chevron: down to open the whole transcript, turned up to close it, on the island's own
/// spring so the glyph and the surface arrive together.
struct PasteExpandButton: View {
    let expanded: Bool
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let P = WorkbenchTokens.Paste.self
        Button(action: action) {
            Image(systemName: "chevron.down")
                .font(P.expandGlyph)
                .foregroundStyle(hovering ? P.expandColorHover : P.expandColor)
                .rotationEffect(.degrees(expanded ? 180 : 0))
                .animation(reduceMotion ? nil : (expanded ? P.expand : P.collapse), value: expanded)
                .frame(width: P.expandWidth, height: P.expandHeight)
                .background(Capsule(style: .continuous).fill(hovering ? P.expandFillHover : .clear))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(P.hover, value: hovering)
        .help(expanded ? "Show less" : "Show the whole transcript")
        .accessibilityLabel(expanded ? "Show less" : "Show more")
    }
}

/// Copy: a gray capsule with white words; once pressed it says Copied, with a checkmark.
struct PasteCopyButton: View {
    let copied: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let P = WorkbenchTokens.Paste.self
        Button(action: action) {
            HStack(spacing: P.copySpacing) {
                if copied {
                    Image(systemName: "checkmark")
                        .font(P.copyGlyph)
                        .transition(.opacity.combined(with: .scale(scale: 0.6)))
                }
                Text(copied ? "Copied" : "Copy")
                    .contentTransition(.interpolate)
            }
            .font(P.copyFont)
            .foregroundStyle(P.copyText)
            .padding(.horizontal, P.copyPaddingH)
            .frame(height: P.copyHeight)
        }
        .buttonStyle(PasteCapsuleStyle(hovering: hovering))
        .onHover { hovering = $0 }
        .animation(P.hover, value: hovering)
        .animation(P.copiedSwap, value: copied)
        .help("Copy the transcript")
        .accessibilityLabel(copied ? "Copied" : "Copy")
    }
}

/// Oct 15 review, VF10: Paste, beside Copy: the held words into the field that's focused now, by
/// the path dictation takes, and the notch rests. Quieter than Copy, which keeps its place and its
/// fill; "No field" a moment when nothing takes a paste (the words stay).
struct PastePasteButton: View {
    let model: WorkbenchModel
    @State private var hovering = false
    @State private var missed = false

    var body: some View {
        let P = WorkbenchTokens.Paste.self
        Button {
            if !model.pasteHeldWords() { showMissed() }
        } label: {
            Text(missed ? "No field" : "Paste")
                .contentTransition(.interpolate)
                .font(P.copyFont)
                .foregroundStyle(P.pasteText)
                .padding(.horizontal, P.copyPaddingH)
                .frame(height: P.copyHeight)
        }
        .buttonStyle(PasteQuietStyle(hovering: hovering))
        .onHover { hovering = $0 }
        .animation(P.hover, value: hovering)
        .animation(P.copiedSwap, value: missed)
        .disabled(model.pasteCopied)
        .help(missed ? "Click into a field, then Paste." : "Paste into the field you're typing in")
        .accessibilityLabel(missed ? "No field to paste into" : "Paste")
    }

    private func showMissed() {
        missed = true
        Task { @MainActor in
            try? await Task.sleep(for: WorkbenchTokens.Paste.missedHold)
            missed = false
        }
    }
}

/// Paste's quieter capsule: the ink's own fill, lighter under the pointer, darker while pressed.
struct PasteQuietStyle: ButtonStyle {
    let hovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        let P = WorkbenchTokens.Paste.self
        configuration.label
            .background(Capsule(style: .continuous)
                .fill(configuration.isPressed ? P.pasteFillPressed : (hovering ? P.pasteFillHover : P.pasteFill)))
            .contentShape(Capsule(style: .continuous))
    }
}

/// The gray capsule: lighter under the pointer, darker while pressed.
struct PasteCapsuleStyle: ButtonStyle {
    let hovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        let P = WorkbenchTokens.Paste.self
        configuration.label
            .background(Capsule(style: .continuous)
                .fill(configuration.isPressed ? P.copyFillPressed : (hovering ? P.copyFillHover : P.copyFill)))
            .contentShape(Capsule(style: .continuous))
    }
}

/// Measures the transcript at the island's text width, whole and as the closed lines, for the
/// layout. Drawn hidden, behind the island's content.
struct PasteMeasure: View {
    let text: String
    let width: CGFloat
    let model: WorkbenchModel

    var body: some View {
        let P = WorkbenchTokens.Paste.self
        VStack(spacing: 0) {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: width, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { model.pasteTextHeight = $0 }
            Text(" ")
                .lineLimit(P.lines, reservesSpace: true)
                .frame(width: width, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { model.pasteLinesHeight = $0 }
        }
        .font(P.text)
        .lineSpacing(P.lineSpacing)
        .fixedSize(horizontal: false, vertical: true)
        .hidden()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

import AppKit
import SwiftUI
import CapturesCore
import FoveaKit

/// The expanded card: your full words, what you took (large, each opening larger), its tags and,
/// for a dispatch, the chat it went to with a way back there at the notch (the App UI review,
/// Oct 6, rows 25, 27 and 28; Oct 15 review, HI-01.3). Words that haven't come back say so first,
/// while Fovea tries again on its own (VF13).
///
/// How it moves (Quick Look's zoom):
/// - One value, `progress`, drives everything, 0 at the card and 1 open, so nothing can show
///   up before the motion or lag behind it.
/// - The surface grows from the card's own frame to the expanded frame, its corners with it,
///   and the grid steps back under the grey. The card in the grid is hidden while the surface
///   stands in for it.
/// - What the card showed fades out over the first 30 % of the way; the expanded content fades
///   in from 16 % to 70 %, laid out at its final width so no line re-wraps. Opacity only.
/// - Closing runs the same path backwards, a little quicker, the grey gone first
///   (`T.Motion.dimLeaves`); a click on it on its way home turns it round.
/// - Reduce Motion: a short fade in place.
/// - Oct 21, Ryan ("simpler is better"): the frame and the grey, nothing else (it also blurred,
///   scaled, flew the pictures to their places and grew a second shadow); 0.3 s out, 0.25 s home.
struct DetailOverlay: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let capture: Capture
    let container: CGSize
    @State private var bodyHeight: CGFloat = 0

    var body: some View {
        let reduce = model.motion.reduce
        let target = targetFrame
        let sourceID = model.detailSourceID
        let source = sourceID.flatMap { model.cardFrames[$0] }.flatMap { visible($0) ? $0 : nil }
        let sourceCapture = sourceID.flatMap { id in model.library.captures.first { $0.id == id } } ?? capture
        ExpandingCard(
            progress: model.detailProgress,
            targetHeight: target.height,
            container: container,
            target: target,
            source: reduce ? nil : source,
            closing: model.detailClosing,
            reduce: reduce,
            capture: capture,
            sourceMatch: model.match(for: sourceCapture),
            match: model.match(for: capture)
        )
        // The expanded content's natural height at its final width, measured off screen.
        .background(alignment: .topLeading) {
            DetailBody(match: model.match(for: capture), width: contentWidth)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: contentWidth)
                .hidden()
                .background(GeometryReader { geo in Color.clear.preference(key: BodyHeightKey.self, value: geo.size.height) })
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .onPreferenceChange(BodyHeightKey.self) { h in
            guard h > 0 else { return }
            // Stepping to another capture resizes at once (keyboard steps don't animate).
            if abs(h - bodyHeight) > 0.5 { bodyHeight = h }
            // Measured: grow on the next turn, from a frame already drawn at the card.
            DispatchQueue.main.async { model.grow() }
        }
        .accessibilityAddTraits(.isModal)
    }

    private var contentWidth: CGFloat {
        model.detailStyle == .page
            ? container.width - 32
            : min(DetailMetrics(capture).width, container.width - 2 * T.Layout.detailMargin)
    }

    private var targetFrame: CGRect {
        let w = contentWidth
        if model.detailStyle == .page {
            return CGRect(x: 16, y: 10, width: w, height: container.height - 26)
        }
        let maxH = container.height - 2 * T.Layout.detailMargin + 16
        // Oct 21, Ryan ("simpler is better"): it hugs what it holds (a line of words stood in a
        // card at least 220 pt tall, most of it empty).
        let h = min(maxH, max(120, DetailMetrics(capture).bar + bodyHeight))
        // A little above center, where the eye rests in a window.
        let y = max(T.Layout.detailMargin - 16, (container.height - h) / 2 - 12)
        return CGRect(x: (container.width - w) / 2, y: y, width: w, height: h)
    }

    /// A card scrolled out of view can't be grown from: the expanded card fades in place instead.
    private func visible(_ r: CGRect) -> Bool {
        r.maxY > 8 && r.minY < container.height - 8 && r.width > 10
    }
}

private struct BodyHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Everything drawn at one `progress`. Animatable, so SwiftUI hands it every in-between value
/// and the layout follows the curve frame by frame.
private struct ExpandingCard: View, Animatable {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var progress: CGFloat
    var targetHeight: CGFloat
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, targetHeight) }
        set { progress = newValue.first; targetHeight = newValue.second }
    }

    let container: CGSize
    let target: CGRect
    let source: CGRect?
    let closing: Bool
    let reduce: Bool
    let capture: Capture
    let sourceMatch: CaptureMatch
    let match: CaptureMatch

    var body: some View {
        let p = min(1, max(0, progress))
        let end = CGRect(x: target.minX, y: target.minY, width: target.width, height: targetHeight)
        // No card to grow from: grow from 94 % of the expanded card, in place.
        let start = source ?? end.insetBy(dx: end.width * 0.03, dy: end.height * 0.03)
        let f = reduce ? end : Curve.lerp(start, end, p)
        let radius = Curve.lerp(source == nil ? T.Layout.detailRadius : T.Layout.cardRadius, T.Layout.detailRadius, p)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        // What the card showed, leaving early; on the way home it comes back from `faceReturns`
        // of the time, as the expanded content goes, so the surface is never a blank card in flight.
        let cardFace: CGFloat = source == nil || reduce ? 0 : (closing ? homeward(p, from: T.Motion.faceReturns, within: 0.85) : 1 - Curve.step(0, 0.3, p))
        // What only the expanded card has.
        let content: CGFloat = reduce ? p : (closing ? 1 - homeward(p, within: T.Motion.contentLeaves) : Curve.step(0.16, 0.7, p))

        ZStack(alignment: .topLeading) {
            // The grid steps back. The grey answers the click at once, both ways: it comes and goes
            // on the ease-out over the zoom's time; on the way home it has gone by `dimLeaves`.
            palette.dim
                .opacity(model.detailStyle == .page ? 0 : Double(dim(p)))
                .contentShape(Rectangle())
                .onTapGesture { model.closeDetail() }
                .accessibilityHidden(true)

            ZStack(alignment: .topLeading) {
                palette.detailSurface

                if let source, cardFace > 0.001 {
                    CardFace(match: sourceMatch, side: source.width, height: source.height, headerWidth: f.width)
                        .opacity(Double(cardFace))
                        .allowsHitTesting(false)
                }

                DetailContent(match: match, width: target.width, barWidth: f.width)
                    .frame(width: target.width, height: targetHeight, alignment: .topLeading)
                    .opacity(Double(content))
                    .allowsHitTesting(p > 0.5 && !closing)
            }
            .frame(width: f.width, height: f.height, alignment: .topLeading)
            .clipShape(shape)
            // Oct 21, Ryan: caught on its way home, a click turns it round.
            .contentShape(shape)
            // Oct 21, Ryan ("the interface is not responsive"): `.none` switched off every gesture in
            // the card, its buttons too, so ✕, Copy, Save and Delete took no clicks while it was
            // open. Open, only the card's own buttons answer (`.subviews`); closing, the tap too.
            .simultaneousGesture(TapGesture().onEnded { if closing { model.reopen() } }, including: closing ? .all : .subviews)
            // A hairline just inside its edge and one soft shadow, floating over the page.
            .overlay(shape.strokeBorder(palette.edge, lineWidth: 0.5))
            .background(shape.fill(palette.detailSurface).shadow(color: .black.opacity(palette.isDark ? 0.4 : 0.14), radius: 24, y: 10))
            .opacity(reduce ? Double(p) : 1)
            .offset(x: f.minX, y: f.minY)
        }
        .frame(width: container.width, height: container.height, alignment: .topLeading)
    }
}

extension ExpandingCard {
    /// How much the grid steps back at `p`.
    func dim(_ p: CGFloat) -> CGFloat {
        if reduce { return p }
        if closing { return 1 - homeward(p, within: T.Motion.dimLeaves) }
        let time = Curve.timeGone(T.Motion.zoomOpen.curve, at: Double(p))
        return CGFloat(Curve.bezier(T.Motion.easeOut, time))
    }

    /// On the way home, something changing on the ease-out between two shares of the zoom's
    /// time (0 before `from`, 1 by `within`), read from where the card is (`p`, 1 open).
    func homeward(_ p: CGFloat, from start: Double = 0, within share: Double) -> CGFloat {
        let time = Curve.timeGone(T.Motion.zoomClose.curve, at: Double(1 - p))
        return CGFloat(Curve.bezier(T.Motion.easeOut, min(1, max(0, (time - start) / (share - start)))))
    }
}

// MARK: - The expanded content

/// The bar along the top (close; previous, next, copy, save, delete) and the body under it.
struct DetailContent: View {
    let match: CaptureMatch
    let width: CGFloat
    /// The bar spans the surface as it grows, so its trailing buttons ride the edge.
    let barWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DetailBar(capture: match.capture)
                .frame(width: barWidth, height: DetailMetrics(match.capture).bar)
            ScrollView {
                DetailBody(match: match, width: width)
            }
            .scrollIndicators(.automatic)
            .frame(width: width)
        }
    }
}

/// Close at the leading edge, where a window keeps its own; the actions at the trailing edge.
/// Borderless icon buttons as a toolbar draws them, each with a tooltip and a key.
struct DetailBar: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let capture: Capture

    var body: some View {
        HStack(spacing: 2) {
            GlassBar {
                IconButton(symbol: "xmark", help: "Close (Esc)") { model.closeDetail() }
                    .keyboardShortcut(.cancelAction)
            }
            if model.detailIcon {
                Image(nsImage: Art.cardIcon(capture))
                    .resizable().interpolation(.high)
                    .frame(width: T.Layout.smallIcon, height: T.Layout.smallIcon)
                    .padding(.leading, 6)
                    .help(CardHeader.whereItWent(capture))
            }
            Spacer(minLength: 8)
            // Aside's note actions: one glass capsule. Oct 21, Ryan: "Don't have the left and right
            // buttons. Make sure copy, download and delete all work as expected." ← and → still
            // step through the cards from the keyboard (the grid keeps it while this is out).
            GlassBar {
                // One Copy: the words, with what you took (row 28). ⌘C copies it too while nothing
                // in the card is selected (the Edit menu's Copy, `HomeWindowController`).
                let copied = model.copiedID == capture.id
                IconButton(symbol: copied ? "checkmark" : "doc.on.doc", help: copied ? "Copied" : "Copy (⌘C)",
                           confirmed: copied, label: copied ? "Copied" : "Copy") { model.copy(capture) }
                    .disabled(capture.failed)
                // One click saves it all: the words, or a folder with what you took (Saving.swift).
                SaveButton(capture: capture)
                    .keyboardShortcut("s", modifiers: .command)
                let deleting = model.deleteConfirmID == capture.id
                IconButton(symbol: deleting ? "checkmark" : "trash", help: deleting ? "Deleted" : "Delete (⌘⌫)",
                           confirmed: deleting, role: deleting ? nil : .destructive,
                           label: deleting ? "Deleted" : "Delete") { model.confirmDelete(capture.id) }
                    .keyboardShortcut(.delete, modifiers: .command)
            }
        }
        // Both in glass, 12 pt in from the top and the sides: the same room on both sides of
        // each corner.
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}

/// The expanded card's proportions for one capture: words only get a narrower card with more
/// room around them; a capture with pictures gets the full width for them, its words still held
/// to a readable line.
struct DetailMetrics {
    let width: CGFloat
    let padding: CGFloat
    /// The bar along the top: 36 pt glass, 12 pt from the top edge, 8 pt clear under it.
    let bar: CGFloat

    init(_ capture: Capture) {
        let wordsOnly = capture.attachments.isEmpty
        width = wordsOnly ? T.Layout.detailTextWidth : T.Layout.detailMaxWidth
        padding = wordsOnly ? T.Layout.detailTextPadding : T.Layout.detailPadding
        bar = 56
    }
}

/// The words (or, if they haven't come back, why, while Fovea tries again), what you took, and the
/// foot: the tags, and for a dispatch where it went and the way back to it at the notch.
struct DetailBody: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let match: CaptureMatch
    let width: CGFloat

    var body: some View {
        let c = match.capture
        let metrics = DetailMetrics(c)
        let inner = width - 2 * metrics.padding
        VStack(alignment: .leading, spacing: 20) {
            if c.failed {
                FailedNotice(capture: c)
            } else {
                // Oct 15 review, QA25: a Dispatch that didn't go says why, with Send Again.
                if c.notSent { NotSentNotice(capture: c) }
                // Held to about 75 characters a line, however wide the card.
                InlineText.make(c, hits: match.ranges[.text] ?? [], size: T.Text.detailBody, palette: palette, hitStyle: model.hitStyle,
                                thumbnails: true)
                    .font(T.Look.wordsInGaramond(c.text) ? Garamond.text(T.Text.detailBody * T.Look.garamondWordsScale) : .system(size: T.Text.detailBody))
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .frame(maxWidth: min(inner, T.Layout.detailMeasure), alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Pictures use the card's full width, under a narrower column of words.
            if !c.attachments.isEmpty {
                DetailAttachments(capture: c, width: inner)
            }

            // The tags at the left; the recording and, for a dispatch, its chat, small at the right.
            CaptureFooter(capture: c)
                .frame(width: inner)
        }
        .padding(.horizontal, metrics.padding)
        .padding(.bottom, metrics.padding)
        .frame(width: width, alignment: .leading)
    }
}

/// What you took, large and in order: regions as pictures (side by side when there are two; a
/// click opens one larger, to see at its own size or save), passages as quotes, files with their
/// icons and a way to save a copy.
struct DetailAttachments: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let capture: Capture
    let width: CGFloat

    var body: some View {
        let regions = capture.attachments.filter { $0.kind == .region }
        let others = capture.attachments.filter { $0.kind != .region }
        VStack(alignment: .leading, spacing: 12) {
            if !regions.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(regions, id: \.index) { a in
                        let size = fit(a, count: regions.count)
                        VStack(alignment: .leading, spacing: 6) {
                            RegionImage(attachment: a)
                                .frame(width: size.width, height: size.height)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(palette.hairline, lineWidth: 0.5))
                                .contentShape(Rectangle())
                                .onTapGesture { model.view(capture.id, a.index) }
                                .help("Open Larger")
                            // Where it came from, under the picture.
                            Text(a.source)
                                .font(.subheadline)
                                .foregroundStyle(palette.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(width: size.width, alignment: .leading)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(Lines.name(a)), from \(a.source)")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { model.view(capture.id, a.index) }
                    }
                }
            }
            ForEach(others, id: \.index) { a in
                switch a.kind {
                case .passage: PassageRow(attachment: a)
                case .file: FileRow(attachment: a, save: { model.saveToDisk(capture, .file(a.index)) })
                case .region: EmptyView()
                }
            }
        }
    }

    /// A region at its own shape: as wide as the column allows (half of it for two), no taller
    /// than 300 pt (220 for two), never larger than it was on screen.
    private func fit(_ a: Attachment, count: Int) -> CGSize {
        let natural = Art.region(a)?.size ?? CGSize(width: 320, height: 200)
        let maxW = count == 1 ? width : (width - 12 * CGFloat(count - 1)) / CGFloat(count)
        let maxH: CGFloat = count == 1 ? 300 : 220
        let scale = min(1, maxW / natural.width, maxH / natural.height)
        return CGSize(width: (natural.width * scale).rounded(), height: (natural.height * scale).rounded())
    }
}

/// A passage you clicked, as a quote with where it came from.
struct PassageRow: View {
    @Environment(\.palette) private var palette
    let attachment: Attachment
    var body: some View {
        let code = attachment.source.hasSuffix(".swift")
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(attachment.text)
                    .font(code ? .system(size: 12, design: .monospaced) : .system(size: 13))
                    .foregroundStyle(palette.text)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) { Rectangle().fill(palette.tertiary).frame(width: 2) }
                Text(attachment.source).font(.subheadline).foregroundStyle(palette.secondary)
                    .padding(.leading, 12)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A file you clicked: its icon, its name, its folder, and a way to save a copy.
struct FileRow: View {
    @Environment(\.palette) private var palette
    let attachment: Attachment
    var save: (() -> Void)?
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: Art.fileIcon(attachment.fileType)).resizable().frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(attachment.text).font(.system(size: 13)).foregroundStyle(palette.text)
                Text(attachment.source).font(.subheadline).foregroundStyle(palette.secondary)
            }
            Spacer(minLength: 0)
            if let save { IconButton(symbol: "square.and.arrow.down", help: "Save a Copy…", action: save) }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(palette.fill))
        .accessibilityElement(children: .combine)
    }
}

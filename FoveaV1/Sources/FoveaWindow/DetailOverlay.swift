import AppKit
import SwiftUI
import CapturesCore
import FoveaKit

/// The expanded card: your full words, what you took (large, each opening larger), its tags and,
/// for a dispatch, the chat it went to with a way back there at the notch (the App UI review,
/// Oct 6, rows 25, 27 and 28; Oct 15 review, HI-01.3). Words that haven't come back say so first,
/// while Fovea tries again on its own (VF13).
///
/// How it moves (Quick Look's zoom, and the container transform Material documents):
/// - One value, `progress`, drives everything, 0 at the card and 1 open, so nothing can show
///   up before the motion or lag behind it.
/// - The surface grows from the card's own frame to the expanded frame, corners and shadow with
///   it. The card in the grid is hidden while the surface stands in for it.
/// - What the card showed (its header and icon riding the growing edge, its words) fades out
///   over the first 30 % of the way; the expanded content fades in from 16 % to 70 %, out of a
///   4 pt blur, laid out at its final width so no line re-wraps.
/// - The regions you took fly from the card's preview to their places in the expanded card.
/// - Closing runs the same path backwards, a little quicker; the expanded content is gone in
///   the first third of the time, and the card's own content returns over the last 30 % of the way.
/// - A click or Esc mid-flight reverses from wherever it is (springs keep their velocity).
/// - Reduce Motion: no travel, no blur, no scale; a short fade in place.
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
            DetailBody(match: model.match(for: capture), width: contentWidth, lendTiles: false)
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
        let h = min(maxH, max(220, DetailMetrics(capture).bar + bodyHeight))
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
/// and the layout follows the spring frame by frame.
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

        // What the card showed, leaving early (and returning late on the way back).
        let cardFace: CGFloat = source == nil || reduce ? 0 : 1 - Curve.step(0, 0.3, p)
        // What only the expanded card has.
        let content: CGFloat = reduce ? p : (closing ? Curve.step(0.45, 0.92, p) : Curve.step(0.16, 0.7, p))
        let flying = source != nil && !reduce && p < 1 && model.attachmentMotion == .fly
            && model.cardAttachments == .inlineAndPreview

        ZStack(alignment: .topLeading) {
            // The grid steps back.
            palette.dim
                .opacity(model.detailStyle == .page ? 0 : Double(p))
                .contentShape(Rectangle())
                .onTapGesture { model.closeDetail() }
                .accessibilityHidden(true)

            ZStack(alignment: .topLeading) {
                palette.card

                // Kept while it's faded too: its preview's places are where the regions fly from.
                if let source, cardFace > 0.001 || flying {
                    CardFace(match: sourceMatch, side: source.width, headerWidth: f.width, lendTiles: flying)
                        .opacity(Double(cardFace))
                        .blur(radius: (1 - cardFace) * 3)
                        .allowsHitTesting(false)
                }

                DetailContent(match: match, width: target.width, barWidth: f.width, lendTiles: flying)
                    .frame(width: target.width, height: targetHeight, alignment: .topLeading)
                    .opacity(Double(content))
                    .blur(radius: reduce ? 0 : (1 - content) * T.Motion.contentBlur)
                    .scaleEffect(reduce ? 1 : 0.985 + 0.015 * content, anchor: .topLeading)
                    .allowsHitTesting(p > 0.5 && !closing)
            }
            .overlayPreferenceValue(TileAnchorsKey.self) { anchors in
                if flying {
                    GeometryReader { proxy in
                        ForEach(capture.attachments.filter { $0.kind == .region }, id: \.index) { a in
                            if let from = anchors["card/\(a.index)"], let to = anchors["detail/\(a.index)"] {
                                FlyingRegion(attachment: a, frame: Curve.lerp(proxy[from], proxy[to], p), progress: p)
                            }
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(width: f.width, height: f.height, alignment: .topLeading)
            .clipShape(shape)
            // Aside's shading, from the card's resting level to floating over the page: the edge
            // just inside, the contact shadow and the wide one growing with it.
            .overlay(shape.strokeBorder(palette.edge, lineWidth: 0.5))
            .overlay { if palette.isDark { shape.strokeBorder(Rim.gradient, lineWidth: 1) } }
            .background {
                let (r0, r1) = T.Shade.layers(.resting, dark: palette.isDark)
                let (f0, f1) = T.Shade.layers(.floating, dark: palette.isDark)
                ZStack {
                    shape.fill(palette.card)
                        .shadow(color: .black.opacity(Curve.lerp(r1.opacity, f1.opacity, Double(p))),
                                radius: Curve.lerp(r1.radius, f1.radius, p), y: Curve.lerp(r1.y, f1.y, p))
                    shape.fill(palette.card)
                        .shadow(color: .black.opacity(Curve.lerp(r0.opacity, f0.opacity, Double(p))),
                                radius: Curve.lerp(r0.radius, f0.radius, p), y: Curve.lerp(r0.y, f0.y, p))
                }
            }
            .opacity(reduce ? Double(p) : 1)
            .offset(x: f.minX, y: f.minY)
        }
        .frame(width: container.width, height: container.height, alignment: .topLeading)
    }
}

/// A region on its way between the card's preview and the expanded card: the same picture,
/// re-cropped as its frame changes shape, its corners and number growing with it.
private struct FlyingRegion: View {
    let attachment: Attachment
    let frame: CGRect
    let progress: CGFloat
    var body: some View {
        RegionImage(attachment: attachment)
            .frame(width: frame.width, height: frame.height)
            .clipShape(RoundedRectangle(cornerRadius: Curve.lerp(0, 8, progress), style: .continuous))
            .offset(x: frame.minX, y: frame.minY)
    }
}

// MARK: - The expanded content

/// The bar along the top (close; previous, next, copy, save, delete) and the body under it.
struct DetailContent: View {
    let match: CaptureMatch
    let width: CGFloat
    /// The bar spans the surface as it grows, so its trailing buttons ride the edge.
    let barWidth: CGFloat
    let lendTiles: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DetailBar(capture: match.capture)
                .frame(width: barWidth, height: DetailMetrics(match.capture).bar)
            ScrollView {
                DetailBody(match: match, width: width, lendTiles: lendTiles)
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
            // Aside's note actions: one glass capsule. ← and → reach the first two through the
            // grid, which keeps the keyboard while this is out.
            GlassBar {
                IconButton(symbol: "chevron.left", help: "Previous (←)") { model.step(-1) }
                    .disabled(!model.canStep(-1))
                IconButton(symbol: "chevron.right", help: "Next (→)") { model.step(1) }
                    .disabled(!model.canStep(1))
                BarDivider()
                // One Copy: the words, with what you took (row 28).
                IconButton(symbol: model.copiedID == capture.id ? "checkmark" : "doc.on.doc",
                           help: "Copy", confirmed: model.copiedID == capture.id) { model.copy(capture) }
                    .disabled(capture.failed)
                SaveMenu(capture: capture)
                IconButton(symbol: "trash", help: "Delete (⌘⌫)", role: .destructive) { model.delete(capture.id) }
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
    let lendTiles: Bool

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
                    .font(.system(size: T.Text.detailBody))
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .frame(maxWidth: min(inner, T.Layout.detailMeasure), alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Pictures use the card's full width, under a narrower column of words.
            if !c.attachments.isEmpty {
                DetailAttachments(capture: c, width: inner, lendTiles: lendTiles)
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
    let lendTiles: Bool

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
                                .anchorPreference(key: TileAnchorsKey.self, value: .bounds) { ["detail/\(a.index)": $0] }
                                .opacity(lendTiles ? 0 : 1)
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

import AppKit
import SwiftUI
import CapturesCore
import FoveaKit

/// Where each card sits in the window, so the expanded card can grow out of it and shrink back.
struct CardFramesKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Where each picture of what you took sits inside a card or the expanded card, so it can fly
/// from one to the other.
struct TileAnchorsKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

enum Space { static let root = "captures-root" }

/// A capture as Paste draws a clipboard item: a header naming what it is and when, the app it
/// went into as a large icon cut by the corner, and the thing itself filling the body. No footer.
struct CaptureCard: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let match: CaptureMatch
    @State private var hover = false

    var body: some View {
        let c = match.capture
        let side = model.cardSize.width
        // While the expanded card is out, it draws this card itself.
        let lent = model.detailSourceID == c.id
        let hovered = hover || model.hoverKey == c.id
        Button { model.open(c.id) } label: {
            CardFace(match: match, side: side)
                .modifier(CardChrome(hovered: hovered))
        }
        .buttonStyle(CardPressStyle())
        .overlay { if model.selectedID == c.id && !lent { SelectionRing() } }
        .opacity(lent ? 0 : 1)
        .frame(width: side, height: side)
        .background(GeometryReader { geo in
            Color.clear.preference(key: CardFramesKey.self, value: [c.id: geo.frame(in: .named(Space.root))])
        })
        .onHover { hover = $0 }
        .id(c.id)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(Lines.label(c)), \(Lines.relative(c.time, now: model.now)), \(c.kind == .dispatch ? "to \(c.destination?.agent ?? "an agent")" : "in \(c.app.name)"). \(Lines.spoken(c))")
    }
}

/// The keyboard's card: an accent ring just outside it (Aside's focus ring, Finder's
/// selection); gray while the window isn't key. Concentric: the card's radius plus the ring's
/// offset.
struct SelectionRing: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.controlActiveState) private var active
    var body: some View {
        let key = active == .key
        switch model.focusMark {
        case .ring:
            let offset: CGFloat = 3.5
            RoundedRectangle(cornerRadius: T.Layout.cardRadius + offset, style: .continuous)
                .strokeBorder(key ? palette.accent : palette.tertiary, lineWidth: 2.5)
                .padding(-offset)
                .allowsHitTesting(false)
        case .eye:
            // The icon's o: a thick ring of ink, concentric with the card.
            let offset: CGFloat = 5
            RoundedRectangle(cornerRadius: T.Layout.cardRadius + offset, style: .continuous)
                .strokeBorder(key ? palette.text : palette.tertiary, lineWidth: 4)
                .padding(-offset)
                .allowsHitTesting(false)
        case .dot:
            // The icon's dot, on the card's top edge at its middle, where the notch's camera sits
            // on the screen; a hairline of ink round the card so the one picked still reads.
            RoundedRectangle(cornerRadius: T.Layout.cardRadius, style: .continuous)
                .strokeBorder(palette.ink(key ? 0.35 : 0.2), lineWidth: 1)
                .overlay(alignment: .top) {
                    Circle().fill(key ? palette.text : palette.tertiary)
                        .frame(width: 9, height: 9)
                        .offset(y: -4.5)
                }
                .allowsHitTesting(false)
        }
    }
}

/// A card's edge and shadow, Aside's way: the ink at 8 % just inside its edge and two soft
/// shadows at rest; under the pointer the wide shadow grows, as Aside's buttons lift, and
/// nothing moves (Finder's and Photos' items don't jump either).
struct CardChrome: ViewModifier {
    @Environment(\.motion) private var motion
    let hovered: Bool

    func body(content: Content) -> some View {
        content
            .shading(RoundedRectangle(cornerRadius: T.Layout.cardRadius, style: .continuous), hovered ? .raised : .resting)
            .animation(motion.animation(.hover), value: hovered)
    }
}

/// A press settles the card a hair, and lets go as quickly.
struct CardPressStyle: ButtonStyle {
    @Environment(\.motion) private var motion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !motion.reduce ? 0.985 : 1)
            .animation(motion.animation(.press), value: configuration.isPressed)
    }
}

/// The card itself, at `side` points square: the header, then what it holds. The expanded card
/// draws the same face while it grows from it.
struct CardFace: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let match: CaptureMatch
    let side: CGFloat
    /// The header's width when it's stretched across the growing expanded card.
    var headerWidth: CGFloat?
    /// Leaves the preview's pictures out while their flying copies stand in for them.
    var lendTiles = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CardHeader(capture: match.capture)
                .frame(width: headerWidth ?? side)
            CardBody(match: match, lendTiles: lendTiles)
                .frame(width: side)
        }
        .frame(width: headerWidth ?? side, height: side, alignment: .topLeading)
        .background(palette.card)
        .clipShape(RoundedRectangle(cornerRadius: T.Layout.cardRadius, style: .continuous))
    }
}

/// The type (or a theme) and when, then the app it went into. Paste 6's anatomy by default: one
/// line, no band, the app's icon small and whole at the trailing end (the HIG doesn't crop app
/// icons). Paste 5's band with the icon cut by the corner is kept as an alternative.
struct CardHeader: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let capture: Capture

    var body: some View {
        switch model.iconStyle {
        case .corner: band
        case .small, .leading: line
        }
    }

    /// One line: the type in bold, the compact time on its baseline, the icon at the end,
    /// centered on the title's capitals rather than on the row's box.
    private var line: some View {
        let icon = T.Layout.smallIcon
        let spacing = model.cardSpacing
        let pad = spacing.padding(model.cardSize)
        let twoLines = model.headerStyle == .themeAndType
        return HStack(alignment: twoLines ? .top : .firstTextBaseline, spacing: 6) {
            if model.iconStyle == .leading { appIcon(icon).alignmentGuide(.firstTextBaseline) { Self.onCaps($0) } }
            if twoLines {
                VStack(alignment: .leading, spacing: spacing.metrics.headerLineGap) {
                    HStack(spacing: 5) {
                        if capture.failed { FailedMark() }
                        Text(title).font(T.Text.cardTitle).foregroundStyle(palette.text)
                    }
                    HStack(spacing: 5) {
                        KindMark(kind: capture.kind)
                        Text("\(capture.kind.title) · \(when)")
                            .font(T.Text.cardTime).foregroundStyle(palette.secondary).monospacedDigit()
                    }
                }
            } else {
                if model.headerStyle == .type {
                    KindMark(kind: capture.kind).alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 3.5 }
                }
                if capture.failed { FailedMark() }
                Text(title).font(T.Text.cardTitle).foregroundStyle(palette.text)
                Text(when)
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(palette.tertiary)
                    .layoutPriority(1)
            }
            Spacer(minLength: 4)
            if model.iconStyle == .small { appIcon(icon).alignmentGuide(.firstTextBaseline) { Self.onCaps($0) } }
        }
        .lineLimit(1)
        .padding(.leading, pad)
        // Optical nudge: an icon's artwork sits inside a margin of its own, so the icon's box
        // goes 2 pt past the text's inset for the artwork to line up with it.
        .padding(.trailing, pad - 2)
        .padding(.top, pad + spacing.metrics.headerTop)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Where an icon's "baseline" goes so that its middle meets the middle of the title's
    /// capitals: half its height, plus half the headline's cap height.
    static func onCaps(_ d: ViewDimensions) -> CGFloat {
        d.height / 2 + NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .bold).capHeight / 2
    }

    /// Paste 5: a band as tall as the icon's artwork, the artwork flush with the card's top and
    /// trailing edges and its outer corner rounded off by the card's own.
    private var band: some View {
        let h = T.Layout.headerHeight
        let iconFrame = (h / T.Layout.iconArtFraction).rounded()
        let margin = (iconFrame - h) / 2
        return VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 5) {
                if capture.failed { FailedMark() }
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(palette.text)
            }
            Text(model.headerStyle == .themeAndType
                 ? "\(capture.kind.title) · \(Lines.relative(capture.time, now: model.now))"
                 : Lines.relative(capture.time, now: model.now))
                .font(T.Text.cardTime).foregroundStyle(palette.secondary)
        }
        .lineLimit(1)
        .padding(.leading, model.cardSpacing.padding(model.cardSize))
        .padding(.trailing, h + 8)
        .frame(maxWidth: .infinity, minHeight: h, maxHeight: h, alignment: .leading)
        .background(palette.header)
        .overlay(alignment: .topTrailing) {
            Image(nsImage: Art.cardIcon(capture))
                .resizable()
                .interpolation(.high)
                .frame(width: iconFrame, height: iconFrame)
                .offset(x: margin, y: -margin)
                .help(Self.whereItWent(capture))
                .accessibilityHidden(true)
        }
    }

    private func appIcon(_ size: CGFloat) -> some View {
        Image(nsImage: Art.cardIcon(capture))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .help(Self.whereItWent(capture))
            .accessibilityHidden(true)
    }

    /// The icon's tooltip: the app, or the agent a dispatch went to.
    static func whereItWent(_ c: Capture) -> String {
        if c.kind == .dispatch, let d = c.destination { return "Sent to \(d.agent)" }
        // A browser names the site too (row 38): "Chrome · chatgpt.com".
        return c.target
    }

    /// This week: how long ago ("3m", "2d"). Before it, under a day's name: the time of day.
    private var when: String {
        History.isRecent(capture.time, now: model.now, calendar: Lines.calendar)
            ? Lines.compact(capture.time, now: model.now)
            : Lines.time(capture.time)
    }

    private var title: String {
        switch model.headerStyle {
        case .type: return Lines.label(capture)
        case .theme, .themeAndType: return capture.theme
        }
    }
}

/// What the capture holds: your words with a chip where you took each thing, then (the default)
/// a preview of what you took filling the rest of the card.
struct CardBody: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let match: CaptureMatch
    var lendTiles = false

    var body: some View {
        let c = match.capture
        let preview = model.cardAttachments == .inlineAndPreview && !c.attachments.isEmpty
        let spacing = model.cardSpacing.metrics
        let pad = model.cardSpacing.padding(model.cardSize)
        VStack(alignment: .leading, spacing: 0) {
            // Found only by what you took: say where, with the hit.
            if let hit = match.ranges[.attachments]?.first, match.ranges[.text] == nil {
                let text = CaptureSearch.attachmentText(c)
                HStack(spacing: 4) {
                    Text(Highlight.attributed(Snippet.around(text, hit), hits: Snippet.shift(text, hit), palette: palette,
                                              style: model.hitStyle, color: palette.secondary))
                        .font(.system(size: 11))
                        .lineLimit(1)
                }
                .padding(.horizontal, pad)
                .padding(.top, 8)
            }
            if c.failed {
                FailedNotice(capture: c, compact: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, pad)
                    .padding(.top, spacing.bodyGap)
                    .padding(.bottom, pad)
            } else {
            InlineText.make(c, hits: match.ranges[.text] ?? [], size: T.Text.cardBody, palette: palette, hitStyle: model.hitStyle,
                            thumbnails: model.cardAttachments == .inlineOnly)
                .font(.system(size: T.Text.cardBody))
                .lineSpacing(spacing.lineSpacing)
                .lineLimit(preview ? spacing.previewLines : spacing.textLines)
                .fixedSize(horizontal: false, vertical: preview)
                .frame(maxWidth: .infinity, maxHeight: preview ? nil : .infinity, alignment: .topLeading)
                .padding(.horizontal, pad)
                .padding(.top, spacing.bodyGap)
                .padding(.bottom, preview ? 0 : pad)
            }
            if preview {
                Spacer(minLength: spacing.previewGap)
                AttachmentStrip(captureID: c.id, attachments: c.attachments, lendTiles: lendTiles)
                    .frame(minHeight: 60, maxHeight: .infinity)
            }
        }
    }
}

/// What you took, side by side at the card's foot, edge to edge, in the order taken.
struct AttachmentStrip: View {
    @Environment(\.palette) private var palette
    let captureID: String
    let attachments: [Attachment]
    var lendTiles = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(attachments.enumerated()), id: \.element.index) { i, a in
                if i > 0 { Rectangle().fill(palette.hairline).frame(width: 1) }
                AttachmentTile(attachment: a, compact: true)
                    .opacity(lendTiles && a.kind == .region ? 0 : 1)
                    .anchorPreference(key: TileAnchorsKey.self, value: .bounds) { ["card/\(a.index)": $0] }
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(palette.hairline).frame(height: 1) }
    }
}

/// One thing you took, drawn as itself: the region, the passage's first lines, the file's icon
/// and name; numbered at its bottom-leading corner, off the top line where a screen starts.
struct AttachmentTile: View {
    @Environment(\.palette) private var palette
    let attachment: Attachment
    var compact = true
    /// The referent tab, numbered as the words named it: off until the binding is kept (row 32).
    var showsBadge = false

    var body: some View {
        let a = attachment
        ZStack(alignment: .bottomLeading) {
            switch a.kind {
            case .region:
                RegionImage(attachment: a)
            case .passage:
                Text(a.text)
                    .font(.system(size: compact ? 10.5 : 13, design: a.source.hasSuffix(".swift") ? .monospaced : .default))
                    .foregroundStyle(palette.secondary)
                    .lineSpacing(1.5)
                    .padding(.top, 8)
                    .padding(.bottom, 26)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(palette.card.overlay(palette.header))
            case .file:
                VStack(spacing: 4) {
                    Image(nsImage: Art.fileIcon(a.fileType)).resizable().frame(width: compact ? 34 : 44, height: compact ? 34 : 44)
                    Text(a.text)
                        .font(.system(size: compact ? 10 : 11.5))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(palette.card.overlay(palette.header))
            }
            if showsBadge { AttachmentBadge(index: a.index, size: 15).padding(6) }
        }
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Lines.name(a) + (a.kind == .file ? ", \(a.text)" : ""))
    }
}

/// A region, filled from its top-leading corner (where a screen starts to read).
struct RegionImage: View {
    let attachment: Attachment
    var body: some View {
        Color.clear
            .overlay(alignment: .topLeading) {
                if let image = Art.region(attachment) {
                    Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
                } else {
                    Color.gray.opacity(0.2)
                }
            }
            .clipped()
    }
}

/// An attachment's number on a picture: the referent tab, as it sits in your words.
struct AttachmentBadge: View {
    @Environment(\.palette) private var palette
    let index: Int
    var size: CGFloat = 16
    var body: some View {
        Text(verbatim: "\(index)")
            .font(.system(size: size * 0.66, weight: .semibold, design: .monospaced))
            .foregroundStyle(palette.onMark)
            .frame(minWidth: size, minHeight: size)
            .padding(.horizontal, 1)
            .background(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous).fill(palette.mark))
            .accessibilityHidden(true)
    }
}

/// A type's mark, beside its name: Dictation a ring (the voice), Dispatch a small island (it went
/// to an agent). Shape and color both say it; the word stays in ink.
struct KindMark: View {
    @Environment(\.palette) private var palette
    let kind: CaptureKind
    var size: CGFloat = 9

    var body: some View {
        let color = palette.kind(kind)
        Group {
            switch kind {
            case .dictation:
                Circle().strokeBorder(color, lineWidth: 1.6).frame(width: size, height: size)
            case .dispatch:
                Capsule().fill(color).frame(width: size * 1.25, height: size * 0.62)
            }
        }
        .frame(width: size * 1.25, height: size)
        .accessibilityHidden(true)
    }
}


/// A recording whose words never came back, beside its title: Messages' red exclamation mark.
struct FailedMark: View {
    @Environment(\.palette) private var palette
    var body: some View {
        Image(systemName: "exclamationmark.circle.fill")
            .font(.system(size: 12))
            .foregroundStyle(palette.danger)
            .help("Not transcribed: the recording is kept")
            .accessibilityLabel("Not transcribed")
    }
}

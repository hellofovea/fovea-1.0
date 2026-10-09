import SwiftUI
import AppKit
import FoveaCore

// The referent stack: captures in the voice bar, collapsed as a small pile left of the
// waveform, fanned to the right on hover, laid out in rows when opened. Geometry is pure
// (`StackLayout`), so the views, the flight into the stack and the checks share one answer.
// docs/island/REFERENT_STACK.md has the reasons for every number.

/// One capture: the pixels of a region of the display, taken from the window itself.
struct CapturedReferent: Identifiable, Equatable {
    let id: UUID
    let image: NSImage
    /// Width over height of the captured region.
    let aspect: CGFloat
    /// Where it came from: the Safari tab's title, or Desktop.
    let source: String
    /// A region of the screen, a passage of text, or a file: each drawn as a card, so all three
    /// ride the same stack, flights and looks closer.
    var kind: ReferentKind = .screenshot

    static func == (a: CapturedReferent, b: CapturedReferent) -> Bool { a.id == b.id }
}

/// What was taken in capture mode (left Option held in Dispatch Version 2): a region (a drag), the
/// text of a passage (a click on it), or a file (a click on it).
enum ReferentKind: Equatable {
    case screenshot
    case text(String)
    case file(name: String, size: String)

    var label: String {
        switch self {
        case .screenshot: return "Screenshot"
        case .text: return "Text"
        case .file(let name, _): return name
        }
    }
}

/// The shapes a referent can take in the island, to compare. Radii follow the island: the
/// rectangles are concentric with its corners (inner = outer − inset); the circle and the
/// capsule are round whatever their size.
enum ReferentShape: String, CaseIterable, Identifiable {
    case roundedRectangle, roundedSquare, circle, capsule
    var id: String { rawValue }
    var title: String {
        switch self {
        case .roundedRectangle: return "Rounded rectangle"
        case .roundedSquare: return "Rounded square"
        case .circle: return "Circle"
        case .capsule: return "Capsule"
        }
    }
    var symbol: String {
        switch self {
        case .roundedRectangle: return "rectangle"
        case .roundedSquare: return "square"
        case .circle: return "circle"
        case .capsule: return "capsule"
        }
    }

    /// A card's width for its height. Stacked cards share one footprint; laid out, a rounded
    /// rectangle keeps the capture's own proportions, within bounds.
    func width(height: CGFloat, aspect: CGFloat, stacked: Bool) -> CGFloat {
        let T = WorkbenchTokens.Referents.self
        switch self {
        case .roundedRectangle:
            let a = stacked ? T.stackAspect : min(max(aspect, T.aspectRange.lowerBound), T.aspectRange.upperBound)
            return (height * a).rounded()
        case .roundedSquare, .circle: return height
        case .capsule: return (height * T.capsuleAspect).rounded()
        }
    }

    func radius(height: CGFloat, concentric: CGFloat) -> CGFloat {
        switch self {
        case .roundedRectangle, .roundedSquare: return concentric
        case .circle, .capsule: return height / 2
        }
    }
}

/// Where everything in the island goes for one state: the outline, each card, the waveform,
/// the stack's hit area and the close control. x is measured from the island's center, y
/// from its top (row 0 of the display).
struct StackLayout: Equatable {
    struct Card: Equatable {
        var cx: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat
        var rotation: Double, opacity: Double, z: Double
        var vector: CardVector {
            CardVector(x: Double(cx), y: Double(top), w: Double(width), h: Double(height),
                       r: Double(radius), rot: rotation, o: opacity)
        }
    }
    struct Outline: Equatable {
        var size: CGSize, topRadius: CGFloat, bottomRadius: CGFloat
    }

    var outline: Outline
    var cards: [Card]
    /// The waveform's center.
    var waveform: CGPoint
    /// The collapsed stack, as one control: hover fans it, a click opens it.
    var stackHit: CGRect?
    var close: CGRect?
    /// Where the looked-at capture's tab is named, beside the pill.
    var caption: CGRect?
    /// Rows when opened.
    var rows = 0

    static func make(state: NotchState, aspects: [CGFloat], shape: ReferentShape, expanded: Bool,
                     peek: Bool, inspecting: Int? = nil, metrics: ScreenMetrics) -> StackLayout {
        if state.collects, expanded, !aspects.isEmpty {
            if let inspecting, aspects.indices.contains(inspecting) {
                return inspected(inspecting, aspects: aspects, shape: shape, metrics: metrics)
            }
            return opened(aspects: aspects, shape: shape, metrics: metrics)
        }
        return collapsed(state: state, aspects: aspects, shape: shape, peek: peek, metrics: metrics)
    }

    /// One capture looked at closely: its card grows to the capture's own proportions, up to
    /// the review width and 300 pt tall, centered; the others fade where they were, so going
    /// back is the same move reversed. The island fits the one card; the pill steps back, the
    /// caption names the tab it came from.
    static func inspected(_ index: Int, aspects: [CGFloat], shape: ReferentShape, metrics: ScreenMetrics) -> StackLayout {
        let T = WorkbenchTokens.Referents.self
        let spec = WorkbenchTokens.Island.spec
        let notch = NotchGeometry.notchRect(metrics: metrics, spec: spec)
        var layout = opened(aspects: aspects, shape: shape, metrics: metrics)
        let pad = T.expandedPadding
        let maxW = T.expandedMaxWidth - 2 * spec.expandedTopRadius - 2 * pad
        let a = min(max(aspects[index], T.inspectAspectRange.lowerBound), T.inspectAspectRange.upperBound)
        var w = min(maxW, T.inspectMaxHeight * a)
        var h = w / a
        if h > T.inspectMaxHeight { h = T.inspectMaxHeight; w = h * a }
        w = w.rounded(); h = h.rounded()
        let span = WorkbenchTokens.Island.waveformSpan
        let footerMin = T.closeWidth + 2 * T.expandedSpacing + span + 120
        let body = max(w + 2 * pad, footerMin + 2 * pad, notch.width)
        // In Native the opened stack is a panel under the island: its top moves down by the gap.
        let top = notch.height + pad + WorkbenchTokens.Native.panelGap
        for i in layout.cards.indices where i != index {
            layout.cards[i].opacity = 0
        }
        layout.cards[index] = Card(cx: 0, top: top, width: w, height: h, radius: T.expandedRadius,
                                   rotation: 0, opacity: 1, z: Double(aspects.count + 1))
        let footerTop = top + h + T.footerGap
        let left = -body / 2 + pad
        let close = CGRect(x: left, y: footerTop + (T.footerHeight - T.closeHeight) / 2, width: T.closeWidth, height: T.closeHeight)
        let waveX = body / 2 - pad - span / 2
        let captionX = close.maxX + T.captionGap
        layout.close = close
        layout.caption = CGRect(x: captionX, y: footerTop, width: max(0, waveX - span / 2 - T.captionGap - captionX),
                                height: T.footerHeight)
        layout.waveform = CGPoint(x: waveX, y: footerTop + T.footerHeight / 2)
        layout.outline = Outline(size: CGSize(width: body + 2 * spec.expandedTopRadius, height: footerTop + T.footerHeight + pad),
                                 topRadius: spec.expandedTopRadius, bottomRadius: spec.expandedBottomRadius)
        return layout
    }

    /// Where a card's remove button is centered, from the card's top-left: inset in the
    /// top-right corner of a rectangle; on the round shapes, 45° up the right-hand curve, far
    /// enough in that the whole disc stays on the card.
    static func removeCenter(width w: CGFloat, height h: CGFloat, radius r: CGFloat) -> CGPoint {
        let T = WorkbenchTokens.Referents.self
        let half = T.removeSize / 2
        let roundness = min(w, h) / 2
        if r >= roundness - 0.5 {
            let capCenter = CGPoint(x: w - roundness, y: h / 2)
            let d = max(0, roundness - half - 2) * 0.7071
            return CGPoint(x: capCenter.x + d, y: capCenter.y - d)
        }
        return CGPoint(x: w - T.removeInset - half, y: T.removeInset + half)
    }

    /// The bar as it is while listening: the notch's width, 44 pt below it. The first capture
    /// in front at the left, up to two more peeking out behind it to the right, smaller,
    /// dimmer and tilted; the rest hidden behind them. The waveform moves right to make room.
    static func collapsed(state: NotchState, aspects: [CGFloat], shape: ReferentShape, peek: Bool,
                          metrics: ScreenMetrics) -> StackLayout {
        let T = WorkbenchTokens.Referents.self
        let spec = WorkbenchTokens.Island.spec
        let notch = NotchGeometry.notchRect(metrics: metrics, spec: spec)
        let frames = NotchGeometry.frames(density: state.density, metrics: metrics, spec: spec)
        let voice = state.collects
        let half = notch.width / 2
        let bandTop = notch.height
        let h = T.thumbHeight
        let n = aspects.count
        let frontW = shape.width(height: h, aspect: aspects.first ?? 1, stacked: true)
        let frontLeft = -half + T.inset
        let frontRight = frontLeft + frontW
        let offset = peek ? T.peekOffset : T.layerOffset
        let rotations = peek ? T.peekRotation : T.restRotation
        var cards: [Card] = []
        for i in 0..<n {
            let layer = min(i, T.maxLayers - 1)
            let s = 1 - CGFloat(layer) * T.layerShrink
            let w = frontW * s, hh = h * s
            let right = frontRight + CGFloat(layer) * offset
            let opacity: Double = !voice ? 0 : (i == 0 ? 1 : (i < T.maxLayers ? T.layerOpacity : 0))
            cards.append(Card(cx: right - w / 2, top: bandTop + T.inset + (h - hh) / 2, width: w, height: hh,
                              radius: shape.radius(height: hh, concentric: T.radius * s),
                              rotation: rotations[layer], opacity: opacity, z: Double(n - i)))
        }
        let layers = min(n, T.maxLayers)
        // The waveform sits between the stack at rest and the band's right inset; a hover
        // fanning the stack does not push it.
        let restRight = frontRight + CGFloat(max(0, layers - 1)) * T.layerOffset
        let waveX: CGFloat = n == 0 ? 0 : ((restRight + T.waveformGap) + (half - T.inset)) / 2
        let fanRight = frontRight + CGFloat(max(0, layers - 1)) * offset
        let hit: CGRect? = (voice && n > 0)
            ? CGRect(x: frontLeft, y: bandTop + T.inset, width: fanRight - frontLeft, height: h).insetBy(dx: -3, dy: -3)
            : nil
        return StackLayout(outline: Outline(size: CGSize(width: frames.width, height: frames.minHeight),
                                            topRadius: frames.topRadius, bottomRadius: frames.bottomRadius),
                           cards: cards, waveform: CGPoint(x: waveX, y: bandTop + spec.voiceBelow / 2),
                           stackHit: hit, close: nil)
    }

    /// Every capture, left to right from the first, in rows that wrap at the review width;
    /// cards shrink before a fourth row is needed. The island is as wide as its widest row
    /// (never narrower than the notch), with the close control and the waveform in a footer.
    static func opened(aspects: [CGFloat], shape: ReferentShape, metrics: ScreenMetrics) -> StackLayout {
        let T = WorkbenchTokens.Referents.self
        let spec = WorkbenchTokens.Island.spec
        let notch = NotchGeometry.notchRect(metrics: metrics, spec: spec)
        let pad = T.expandedPadding
        let maxContent = T.expandedMaxWidth - 2 * spec.expandedTopRadius - 2 * pad
        func rows(_ h: CGFloat) -> [[Int]] {
            var rows: [[Int]] = [[]]
            var x: CGFloat = 0
            for (i, a) in aspects.enumerated() {
                let w = shape.width(height: h, aspect: a, stacked: false)
                let needed = rows[rows.count - 1].isEmpty ? w : x + T.expandedSpacing + w
                if needed > maxContent, !rows[rows.count - 1].isEmpty {
                    rows.append([i]); x = w
                } else {
                    rows[rows.count - 1].append(i); x = needed
                }
            }
            return rows
        }
        var h = T.expandedThumbHeight
        while h > T.expandedMinThumbHeight, rows(h).count > T.expandedMaxRows { h -= 4 }
        let laidOut = rows(h)
        let widths = aspects.map { shape.width(height: h, aspect: $0, stacked: false) }
        let rowWidths = laidOut.map { row in
            row.map { widths[$0] }.reduce(0, +) + CGFloat(max(0, row.count - 1)) * T.expandedSpacing
        }
        let span = WorkbenchTokens.Island.waveformSpan
        let content = max(rowWidths.max() ?? 0, T.closeWidth + 2 * T.expandedSpacing + span)
        let body = max(content + 2 * pad, notch.width)
        let left = -body / 2 + pad
        let top0 = notch.height + pad + WorkbenchTokens.Native.panelGap
        var cards = [Card](repeating: Card(cx: 0, top: 0, width: 0, height: 0, radius: 0, rotation: 0, opacity: 0, z: 0),
                           count: aspects.count)
        for (r, row) in laidOut.enumerated() {
            var x = left
            let top = top0 + CGFloat(r) * (h + T.expandedSpacing)
            for i in row {
                let w = widths[i]
                cards[i] = Card(cx: x + w / 2, top: top, width: w, height: h,
                                radius: shape.radius(height: h, concentric: T.expandedRadius),
                                rotation: 0, opacity: 1, z: Double(aspects.count - i))
                x += w + T.expandedSpacing
            }
        }
        let rowsHeight = CGFloat(laidOut.count) * h + CGFloat(laidOut.count - 1) * T.expandedSpacing
        let footerTop = top0 + rowsHeight + T.footerGap
        let close = CGRect(x: left, y: footerTop + (T.footerHeight - T.closeHeight) / 2,
                           width: T.closeWidth, height: T.closeHeight)
        return StackLayout(outline: Outline(size: CGSize(width: body + 2 * spec.expandedTopRadius,
                                                         height: footerTop + T.footerHeight + pad),
                                            topRadius: spec.expandedTopRadius, bottomRadius: spec.expandedBottomRadius),
                           cards: cards,
                           waveform: CGPoint(x: body / 2 - pad - span / 2, y: footerTop + T.footerHeight / 2),
                           stackHit: nil, close: close, rows: laidOut.count)
    }
}

// MARK: - Motion

/// transitions.dev's card-stack-hover curves as they are, except that the overshoot is capped
/// in points: the reference's 19 % overshoot is 9 px on its 48 px move, and would be 57 pt on
/// a 300 pt move, flinging the card out of the island. Past the target the distance still
/// follows the curve's shape, through a sharp-kneed saturation: a short move keeps nearly all
/// of its overshoot (9.2 → 8.5 pt on the reference's move), a long one tops out near `cap`.
struct CappedOvershoot: CustomAnimation {
    let x1: Double, y1: Double, x2: Double, y2: Double
    let duration: TimeInterval
    /// The most a value may pass its target, in its own units (points for positions).
    let cap: Double

    func animate<V: VectorArithmetic>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        guard time < duration else { return nil }
        return value.scaled(by: progress(for: sqrt(value.magnitudeSquared), at: time / duration))
    }

    /// The fraction of the way a value of `distance` has travelled at `x` (0…1) of the time.
    func progress(for distance: Double, at x: Double) -> Double {
        let p = Self.curve(x, x1, y1, x2, y2)
        guard p > 1, distance > 0 else { return p }
        let over = (p - 1) * distance
        let limited = over / pow(1 + pow(over / cap, 4), 0.25)
        return 1 + limited / distance
    }

    /// A CSS cubic-bezier's y for its x.
    static func curve(_ x: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        func bezier(_ t: Double, _ a: Double, _ b: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
        }
        var lo = 0.0, hi = 1.0, t = x
        for _ in 0..<24 {
            let xt = bezier(t, x1, x2)
            if abs(xt - x) < 1e-6 { break }
            if xt < x { lo = t } else { hi = t }
            t = (lo + hi) / 2
        }
        return bezier(t, y1, y2)
    }
}

/// Everything about a card that moves, as one vector, so one animation moves it all
/// together: position, size, corner radius, tilt and opacity.
struct CardVector: VectorArithmetic {
    var x = 0.0, y = 0.0, w = 0.0, h = 0.0, r = 0.0, rot = 0.0, o = 0.0

    static var zero: CardVector { CardVector() }
    static func + (a: CardVector, b: CardVector) -> CardVector {
        CardVector(x: a.x + b.x, y: a.y + b.y, w: a.w + b.w, h: a.h + b.h, r: a.r + b.r, rot: a.rot + b.rot, o: a.o + b.o)
    }
    static func - (a: CardVector, b: CardVector) -> CardVector {
        CardVector(x: a.x - b.x, y: a.y - b.y, w: a.w - b.w, h: a.h - b.h, r: a.r - b.r, rot: a.rot - b.rot, o: a.o - b.o)
    }
    mutating func scale(by k: Double) {
        x *= k; y *= k; w *= k; h *= k; r *= k; rot *= k; o *= k
    }
    var magnitudeSquared: Double { x * x + y * y + w * w + h * h + r * r + rot * rot + o * o }
}

/// Places a card: sized, clipped to its shape with a hairline so it reads on the black,
/// tilted, faded, and offset from its container's alignment point (top center in the island,
/// top leading for a capture in flight). Hover scaling rides on top, on its own curve.
struct CardPlacement: ViewModifier, Animatable {
    var vector: CardVector
    var hoverScale: CGFloat = 1
    var hoverAnimation: Animation? = nil
    /// The card's remove button, shown while `removeVisible`.
    var remove: (() -> Void)? = nil
    var removeVisible = false

    var animatableData: CardVector {
        get { vector }
        set { vector = newValue }
    }

    func body(content: Content) -> some View {
        let v = vector
        let shape = RoundedRectangle(cornerRadius: max(0, v.r), style: .continuous)
        content
            .frame(width: max(0, v.w), height: max(0, v.h))
            .clipShape(shape)
            .overlay(shape.strokeBorder(WorkbenchTokens.Referents.border, lineWidth: WorkbenchTokens.Referents.borderWidth))
            .contentShape(shape)
            .overlay(alignment: .topLeading) {
                if let remove {
                    ReferentRemoveButton(visible: removeVisible, action: remove)
                        .position(StackLayout.removeCenter(width: max(0, v.w), height: max(0, v.h), radius: max(0, v.r)))
                }
            }
            .scaleEffect(hoverScale)
            .animation(hoverAnimation, value: hoverScale)
            .rotationEffect(.degrees(v.rot))
            .opacity(min(1, max(0, v.o)))
            .offset(x: v.x, y: v.y)
    }
}

// MARK: - Views

/// A capture's pixels, filling whatever shape its placement gives it.
struct ReferentCard: View {
    let referent: CapturedReferent
    var body: some View {
        Image(nsImage: referent.image)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
    }
}

/// The opened stack's way out: a small pill with the key that also closes it.
struct StackCloseButton: View {
    /// Looking at one capture, the pill steps back to all of them rather than closing.
    var back = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let T = WorkbenchTokens.Referents.self
        Button(action: action) {
            HStack(spacing: T.closeSpacing) {
                Image(systemName: back ? "chevron.left" : "xmark").font(T.closeGlyph)
                Text("esc").font(T.closeLabel)
            }
            .foregroundStyle(T.closeText)
            .frame(width: T.closeWidth, height: T.closeHeight)
            .background(Capsule(style: .continuous).fill(hovering ? T.closeFillHover : T.closeFill))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(back ? "All screenshots (esc)" : "Close (esc)")
        .accessibilityLabel(back ? "All screenshots" : "Close")
    }
}

/// Removes one capture: a small disc in the island's raised black with a white cross and a
/// faint ring, so it reads on white pages and on photos alike; brighter under the pointer.
/// Fades and grows in with the hover, and takes no clicks while hidden.
struct ReferentRemoveButton: View {
    let visible: Bool
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let T = WorkbenchTokens.Referents.self
        Button(action: action) {
            Image(systemName: "xmark")
                .font(T.removeGlyph)
                .foregroundStyle(T.removeGlyphColor)
                .frame(width: T.removeSize, height: T.removeSize)
                .background(Circle().fill(hovering ? T.removeFillHover : T.removeFill))
                .overlay(Circle().strokeBorder(T.removeRing, lineWidth: 0.75))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .opacity(visible ? 1 : 0)
        .scaleEffect(visible || reduceMotion ? 1 : T.removeHiddenScale)
        .animation(T.removeAppear, value: visible)
        .allowsHitTesting(visible)
        .help("Remove this screenshot")
        .accessibilityLabel("Remove screenshot")
        .accessibilityHidden(!visible)
    }
}

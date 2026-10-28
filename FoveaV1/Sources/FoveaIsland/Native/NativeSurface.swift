import SwiftUI
import FoveaCore

// The Native design's surface (docs/island/NATIVE.md), in place of `IslandOutline`: the island
// stays black, and what drops below it (Paste not found, an error, the opened stack, Choose chat,
// the control board, a session) floats under the notch as a Liquid Glass panel, a gap below the
// island's foot, as Control Center and a Mac Live Activity's card hang under the menu bar. The
// content is laid out exactly as in Original (only each panel's top moves down by the gap), so
// every state shows the same words in the same places.

/// What the notch's surface is for the state on show, in Native.
enum NotchSurfaceKind: Equatable {
    /// All island: the notch, the listening bar and its stack, the bands, the aura bar.
    case island
    /// A panel under the resting notch.
    case panel
    /// The island holds part of it (the Wings designs' band beside the notch; the bar over #19's
    /// route sheet), the panel the rest.
    case split
}

extension WorkbenchModel {
    var notchSurface: NotchSurfaceKind {
        // Oct 27: whatever Wings draws is the island, at the menu bar's height (Wings.swift); over a
        // panel, the bar and the panel under it.
        if wingsPose != nil { return wingsOverPanel ? .split : .island }
        switch notchState {
        case .pasteNotFound, .voiceError, .v2Send, .v2Chat, .v2Alert:
            return .panel
        case .v2Board:
            return .panel
        case .voiceFlow, .v2Voice:
            if stackExpanded { return .panel }
            if v2AsksOver { return .split }
            if notchState == .v2Voice, !v2ReviewBeforeSend, v2RouteOpen { return .split }
            return .island
        case .v2Transcribing:
            return v2AsksOver ? .split : .island
        default:
            return .island
        }
    }

    /// The shapes the Native surface draws for the state on show: the outline (as Original's, the
    /// gap included), the black island inside it, and whether a panel shows.
    var nativeShapes: NativeShapes {
        let layout = stackLayout
        let outline = layout.outline
        let spec = WorkbenchTokens.Island.spec
        let notch = NotchGeometry.notchRect(metrics: metrics, spec: spec)
        var shapes = NativeShapes(outline: outline)
        // Attached: one glass shape hanging from the top edge, Original's outline, its shoulders
        // Wings' (the notch's angle) and the notch's black blurred into it (Halo, Oct 27). Floating
        // panels, the opened captures' strip and the drop zone float under the island.
        guard layout.floats || WorkbenchTokens.floatsPanels else {
            if WorkbenchTokens.blendsPanels { shapes.islandTop = min(shapes.islandTop, WorkbenchTokens.Bar.wingsEar) }
            return barFilled(shapes, layout)
        }
        switch notchSurface {
        case .island:
            break
        case .panel:
            let rest = NotchGeometry.frames(density: .resting, metrics: metrics, spec: spec)
            shapes.island = CGSize(width: rest.width, height: rest.minHeight)
            shapes.islandTop = rest.topRadius
            shapes.islandBottom = rest.bottomRadius
            shapes.presence = 1
        case .split:
            if let bar = layout.wingsBar {
                // Wings over a panel: the bar, black, at the notch's height.
                shapes.island = bar.size
                shapes.islandTop = bar.topRadius
                shapes.islandBottom = bar.bottomRadius
            } else if notchState == .v2Board {
                // The band over the wings: as wide as the board, the notch's height and a little.
                let rest = NotchGeometry.frames(density: .resting, metrics: metrics, spec: spec)
                shapes.island = CGSize(width: outline.size.width, height: notch.height + WorkbenchTokens.Native.bandExtra)
                shapes.islandTop = outline.topRadius
                shapes.islandBottom = rest.bottomRadius
            } else {
                // #19: the bar, at Dispatch's width, over the route sheet.
                let voice = NotchGeometry.frames(density: .voice, metrics: metrics, spec: spec)
                shapes.island = CGSize(width: outline.size.width, height: voice.minHeight)
                shapes.islandTop = outline.topRadius
                shapes.islandBottom = voice.bottomRadius
            }
            shapes.presence = 1
        }
        return barFilled(shapes, layout)
    }

    /// Oct 27, Ryan: the bar is Wings, black as the notch, and so are a session popping up and a
    /// board design (Wings.swift). An island that's only the notch (at rest, over a floating panel)
    /// is drawn black too, so coming out and going back never pass through glass.
    private func barFilled(_ shapes: NativeShapes, _ layout: StackLayout) -> NativeShapes {
        var shapes = shapes
        let spec = WorkbenchTokens.Island.spec
        let rest = NotchGeometry.frames(density: .resting, metrics: metrics, spec: spec)
        let atNotch = abs(shapes.island.width - rest.width) < 0.5 && abs(shapes.island.height - rest.minHeight) < 0.5
        // Wings over a panel, attached: the shape is the panel's, the bar drawn black on it as the
        // notch is (MockIsland's `WingsBarOnGlass`).
        let barOnGlass = layout.wingsBar != nil && WorkbenchTokens.panelsHangFromTop && !layout.floats
        if (layout.fill == .black && !barOnGlass) || (atNotch && WorkbenchTokens.isNative) { shapes.black = 1 }
        return shapes
    }
}

/// The Native surface's shapes as one animatable value: the outline, the island inside it, the
/// panel's presence. Every part moves on the island's spring together, so the island springs back
/// to the notch while the panel grows out of its foot.
struct NativeShapes: Equatable {
    var width: CGFloat
    var height: CGFloat
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var island: CGSize
    var islandTop: CGFloat
    var islandBottom: CGFloat
    /// 0: no panel (an island state); 1: the panel shows.
    var presence: CGFloat = 0
    /// Oct 27: 0 (today's glass) to 1: the island black, as Wings is (Wings.swift).
    var black: CGFloat = 0

    init(outline: StackLayout.Outline) {
        width = outline.size.width
        height = outline.size.height
        topRadius = outline.topRadius
        bottomRadius = outline.bottomRadius
        island = outline.size
        islandTop = outline.topRadius
        islandBottom = outline.bottomRadius
    }

    var vector: NativeVector {
        NativeVector(values: [width, height, topRadius, bottomRadius, island.width, island.height, islandTop, islandBottom, presence,
                              black])
    }

    init(vector v: NativeVector) {
        let x = v.values + Array(repeating: 0, count: max(0, NativeVector.count - v.values.count))
        width = x[0]; height = x[1]; topRadius = x[2]; bottomRadius = x[3]
        island = CGSize(width: x[4], height: x[5]); islandTop = x[6]; islandBottom = x[7]; presence = x[8]
        black = x[9]
    }
}

/// Ten numbers that animate together.
struct NativeVector: VectorArithmetic {
    var values: [CGFloat]
    static let count = 10

    static var zero: NativeVector { NativeVector(values: Array(repeating: 0, count: count)) }

    private static func zip(_ a: NativeVector, _ b: NativeVector, _ f: (CGFloat, CGFloat) -> CGFloat) -> NativeVector {
        let n = max(a.values.count, b.values.count)
        let x = a.values + Array(repeating: 0, count: n - a.values.count)
        let y = b.values + Array(repeating: 0, count: n - b.values.count)
        return NativeVector(values: (0..<n).map { f(x[$0], y[$0]) })
    }

    static func + (a: NativeVector, b: NativeVector) -> NativeVector { zip(a, b, +) }
    static func - (a: NativeVector, b: NativeVector) -> NativeVector { zip(a, b, -) }
    mutating func scale(by rhs: Double) { values = values.map { $0 * CGFloat(rhs) } }
    var magnitudeSquared: Double { values.reduce(0) { $0 + Double($1 * $1) } }
}

/// The surface: the content sized to the outline as `IslandOutline` sizes it; the black island at
/// the top and, under it by the gap, the Liquid Glass panel (in the display's color scheme), both
/// behind the content; the content clipped to the two; the edge layer (the aura) drawn along the
/// island's own edge.
struct NativeSurface<Edge: View>: ViewModifier, Animatable {
    var shapes: NativeShapes
    var earY: CGFloat
    var gap: CGFloat
    /// The notch itself, black as the hardware is, at the top of the glass.
    var notch: StackLayout.Outline
    /// The resting island: the glass comes in as the island grows past it.
    var rest: StackLayout.Outline
    /// The real Mac: once the glass is out, the notch blends into it as the Workbench drew it,
    /// black with its concave ears, over the hardware's (Oct 9, late: the hardware notch's square
    /// edge against the glass read blunt; a black band beside it stuck out over the menu bar).
    /// At rest only the hardware's notch shows.
    var blendNotch = false
    var edge: (IslandEdge) -> Edge
    @Environment(\.displayScheme) private var displayScheme

    var animatableData: NativeVector {
        get { shapes.vector }
        set { shapes = NativeShapes(vector: newValue) }
    }

    func body(content: Content) -> some View {
        let s = shapes
        let island = CGRect(x: (s.width - s.island.width) / 2, y: 0, width: s.island.width, height: s.island.height)
        let panelTop = island.maxY + gap
        let panel = CGRect(x: s.topRadius, y: panelTop,
                           width: max(0, s.width - 2 * s.topRadius), height: max(0, s.height - panelTop))
        let radius = max(0, min(s.bottomRadius, panel.width / 2, panel.height / 2))
        let islandShape = IslandShape(topRadius: s.islandTop, bottomRadius: s.islandBottom, earY: earY)
        let grown = max(island.width - rest.size.width, island.height - rest.size.height)
        let ramp = min(1, max(0, grown / WorkbenchTokens.Native.islandGlassRamp))
        // Oct 27: Wings' island is black, no glass under it.
        let islandGlass = ramp * max(0, 1 - s.black)
        content
            .frame(width: s.width, height: s.height, alignment: .bottom)
            .overlay(alignment: .topLeading) {
                edge(IslandEdge(size: island.size, topRadius: s.islandTop, bottomRadius: s.islandBottom, earY: earY))
                    .frame(width: island.width, height: island.height)
                    .offset(x: island.minX)
            }
            .clipShape(NativeClip(island: island, islandShape: islandShape, panel: panel, radius: radius,
                                  presence: s.presence))
            .background(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    Color.clear
                    if s.presence > 0.001 && panel.height > 0.5 {
                        Color.clear
                            .frame(width: panel.width, height: panel.height)
                            .glass(RoundedRectangle(cornerRadius: radius, style: .continuous),
                                   tint: displayScheme == .dark ? WorkbenchTokens.Native.panelTintDark : WorkbenchTokens.Native.panelTintLight)
                            .environment(\.colorScheme, displayScheme)
                            .opacity(Double(s.presence))
                            .offset(x: panel.minX, y: panel.minY)
                    }
                    // The island is glass too (Oct 9: the bars as the panels are), in the display's
                    // scheme, coming in as it grows past the notch, so at rest only the notch shows.
                    // It runs on above what it hangs from (the screen's top edge, or a full-screen
                    // app's black band) and is cut there, so it has no top edge: Liquid Glass draws
                    // its rim over whatever is drawn after it, so the edge can't be covered.
                    if islandGlass > 0.001 {
                        let N = WorkbenchTokens.Native.self
                        Color.clear
                            .frame(width: island.width, height: island.height + N.glassLift)
                            .glass(IslandShape(topRadius: s.islandTop, bottomRadius: s.islandBottom, earY: earY + N.glassLift),
                                   tint: displayScheme == .dark ? N.panelTintDark : N.panelTintLight)
                            .environment(\.colorScheme, displayScheme)
                            .opacity(Double(islandGlass))
                            .mask(alignment: .topLeading) {
                                Rectangle().padding(EdgeInsets(top: N.glassLift + earY, leading: -N.glassShadowRoom,
                                                               bottom: -N.glassShadowRoom, trailing: -N.glassShadowRoom))
                            }
                            .offset(x: island.minX, y: -N.glassLift)
                        // Oct 27, Ryan: the notch's black into the glass "smooth and almost
                        // seamless", attached (HaloBlend).
                        if WorkbenchTokens.blendsPanels {
                            HaloBlend(shape: IslandShape(topRadius: s.islandTop, bottomRadius: s.islandBottom, earY: earY),
                                          size: island.size, band: rest.size.height, notchWidth: rest.size.width,
                                          notchRadius: rest.bottomRadius, light: displayScheme == .light)
                                .opacity(Double(islandGlass))
                                .offset(x: island.minX)
                        }
                    }
                    // The real Mac: the notch with its ears, black, blending the hardware's into the
                    // glass, coming in with it.
                    if blendNotch, islandGlass > 0.001 {
                        IslandShape(topRadius: rest.topRadius, bottomRadius: rest.bottomRadius, earY: earY)
                            .fill(WorkbenchTokens.Island.surface)
                            .frame(width: rest.size.width, height: rest.size.height)
                            .opacity(Double(islandGlass))
                            .offset(x: (s.width - rest.size.width) / 2)
                    }
                    // The notch on it stays black, as the hardware is.
                    IslandShape(topRadius: notch.topRadius, bottomRadius: notch.bottomRadius, earY: earY)
                        .fill(WorkbenchTokens.Island.surface)
                        .frame(width: notch.size.width, height: notch.size.height)
                        .offset(x: (s.width - notch.size.width) / 2)
                    // Oct 27: Wings, black as the notch (Wings.swift).
                    if s.black > 0.001 {
                        islandShape.fill(WorkbenchTokens.Island.surface)
                            .frame(width: island.width, height: island.height)
                            .opacity(Double(min(1, s.black)))
                            .offset(x: island.minX)
                    }
                }
                .frame(width: s.width, height: s.height, alignment: .topLeading)
            }
    }
}

/// Oct 27, Ryan: the notch's black, clearing into the glass "smooth and almost seamless", then "halo
/// but much smaller so that it barely touches more than what the notch covers", "go with halo now
/// and delete the other ones" (Ease and Dusk, black down the panel, are gone), and "the floating
/// stays as it was. it is supposed to replace the attached part": attached panels. The notch's own
/// shape, a little larger, blurred: black over the notch and just past it, gone some 20 pt further
/// on, the glass meeting the menu bar beside it. A blur has no start or end to see, as a linear fade
/// has; a fine grain dithers it against 8-bit banding; the glass's rim is covered where the black is.
struct HaloBlend<S: Shape>: View {
    let shape: S
    let size: CGSize
    /// The notch's height: black to here, the same as the notch beside it.
    let band: CGFloat
    let notchWidth: CGFloat
    let notchRadius: CGFloat
    /// On light glass, closer in (the first line under the notch stays clear).
    var light = false

    var body: some View {
        let N = WorkbenchTokens.Native.self
        let black = WorkbenchTokens.Island.surface
        ZStack(alignment: .topLeading) {
            fill.mask(shape)
            // The rim (the glass's own hairline) hidden under the black, clearing with it.
            shape.stroke(black, lineWidth: N.blendRimCover).mask(fill)
            // A fine grain over the blur, against banding.
            Rectangle().fill(ImagePaint(image: Dither.image, scale: 1))
                .opacity(N.ditherOpacity).blendMode(.overlay)
                .mask(fill.mask(shape))
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    /// The black round the notch, drawn up past the top edge so the blur doesn't lighten it there.
    private var fill: some View {
        let N = WorkbenchTokens.Native.self
        let spread = light ? N.haloSpreadLight : N.haloSpread
        let blur = light ? N.haloBlurLight : N.haloBlur
        let above = blur * 3
        return UnevenRoundedRectangle(bottomLeadingRadius: notchRadius + spread, bottomTrailingRadius: notchRadius + spread,
                                      style: .continuous)
            .fill(.black)
            .frame(width: notchWidth + spread * 2, height: band + spread + above)
            .blur(radius: blur)
            .position(x: size.width / 2, y: (band + spread - above) / 2)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// A fine grain, the same every time (a fixed seed), for dithering gradients.
enum Dither {
    static let image: Image = {
        let side = 128
        var bytes = [UInt8](repeating: 255, count: side * side * 4)
        var seed: UInt32 = 0x9E3779B9
        for i in 0..<(side * side) {
            seed = seed &* 1664525 &+ 1013904223
            let v = UInt8(truncatingIfNeeded: seed >> 24)
            bytes[i * 4] = v; bytes[i * 4 + 1] = v; bytes[i * 4 + 2] = v
        }
        let space = CGColorSpaceCreateDeviceRGB()
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        let cg = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: side * 4, space: space,
                         bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: provider,
                         decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        return Image(decorative: cg, scale: 2)
    }()
}

/// Where the content shows in Native: inside the island, and inside the panel while it shows.
struct NativeClip: Shape {
    var island: CGRect
    var islandShape: IslandShape
    var panel: CGRect
    var radius: CGFloat
    var presence: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = islandShape.path(in: island)
        if presence > 0.001, panel.height > 0.5 {
            p.addPath(RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: panel))
        }
        return p
    }
}

extension IslandSurface {
    /// On a real Mac the notch is the hardware's: the black drawn on the glass sits just inside it
    /// (no ears, a rounder foot), so none of it shows past the real notch, and nothing is drawn at
    /// all on a display without one. (The Workbench's mock drew the notch itself, ears and all:
    /// 6 pt wider each side than the hardware, Oct 9.)
    static func hardwareNotch(_ model: WorkbenchModel) -> StackLayout.Outline {
        guard model.metrics.notchWidth != nil else { return StackLayout.Outline(size: .zero, topRadius: 0, bottomRadius: 0) }
        let notch = NotchGeometry.notchRect(metrics: model.metrics, spec: WorkbenchTokens.Island.spec)
        return StackLayout.Outline(size: CGSize(width: max(0, notch.width - 2), height: max(0, notch.height - 1)),
                                   topRadius: 0, bottomRadius: 11)
    }
}

/// The island's surface in the design in force: Original's one black outline, or Native's glass
/// (one shape hanging from the top edge, or the island and a panel floating under it), the notch
/// black on it. In Native everything on the glass takes the display's scheme (`.panelScheme()`).
struct IslandSurface: ViewModifier {
    let model: WorkbenchModel
    let layout: StackLayout

    func body(content: Content) -> some View {
        // Full screen, the island hangs from the black band, not the screen's top edge.
        let live = model.live != nil
        let earY = model.screenContent.fullScreen ? model.metrics.safeAreaTop : 0
        if WorkbenchTokens.isNative {
            let rest = NotchGeometry.frames(density: .resting, metrics: model.metrics, spec: WorkbenchTokens.Island.spec)
            let resting = StackLayout.Outline(size: CGSize(width: rest.width, height: rest.minHeight),
                                              topRadius: rest.topRadius, bottomRadius: rest.bottomRadius)
            content
                .modifier(NativeSurface(shapes: model.nativeShapes, earY: earY,
                                        gap: layout.floats ? WorkbenchTokens.Native.floatGap : WorkbenchTokens.Native.panelGap,
                                        notch: live ? Self.hardwareNotch(model) : resting,
                                        rest: resting,
                                        blendNotch: live && model.metrics.notchWidth != nil) { _ in
                    // Oct 27, Ryan: no aura on the bar's edge ("abandon the orbs and aurora completely").
                    EmptyView()
                })
                .animation(model.islandAnimation, value: model.nativeShapes)
        } else {
            content
                .modifier(IslandOutline(width: layout.outline.size.width, height: layout.outline.size.height,
                                        topRadius: layout.outline.topRadius, bottomRadius: layout.outline.bottomRadius,
                                        earY: earY) { _ in
                    // Oct 27, Ryan: no aura on the bar's edge ("abandon the orbs and aurora completely").
                    EmptyView()
                })
                .animation(model.islandAnimation, value: layout.outline)
        }
    }
}

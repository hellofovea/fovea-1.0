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
        switch notchState {
        case .pasteNotFound, .voiceError, .v2Send, .v2Chat:
            return .panel
        case .v2Board:
            switch boardStyle {
            // The island stays the notch; each capsule is its own glass.
            case .capsules, .petCapsules: return .island
            case .wings, .creatures: return .split
            default: return .panel
            }
        case .voiceFlow, .v2Voice:
            if stackExpanded { return .panel }
            if notchState == .v2Voice, !v2ReviewBeforeSend, v2RouteOpen { return .split }
            return .island
        default:
            return .island
        }
    }

    /// The shapes the Native surface draws for the state on show: the outline (as Original's, the
    /// gap included), the black island inside it, and whether a panel shows.
    var nativeShapes: NativeShapes {
        let outline = stackLayout.outline
        let spec = WorkbenchTokens.Island.spec
        let notch = NotchGeometry.notchRect(metrics: metrics, spec: spec)
        var shapes = NativeShapes(outline: outline)
        // Attached panels: one glass shape hanging from the top edge, Original's outline.
        guard WorkbenchTokens.floatsPanels else { return shapes }
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
            if notchState == .v2Board {
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
        NativeVector(values: [width, height, topRadius, bottomRadius, island.width, island.height, islandTop, islandBottom, presence])
    }

    init(vector v: NativeVector) {
        let x = v.values + Array(repeating: 0, count: max(0, 9 - v.values.count))
        width = x[0]; height = x[1]; topRadius = x[2]; bottomRadius = x[3]
        island = CGSize(width: x[4], height: x[5]); islandTop = x[6]; islandBottom = x[7]; presence = x[8]
    }
}

/// Nine numbers that animate together.
struct NativeVector: VectorArithmetic {
    var values: [CGFloat]

    static var zero: NativeVector { NativeVector(values: Array(repeating: 0, count: 9)) }

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
        let grown = max(island.width - notch.size.width, island.height - notch.size.height)
        let islandGlass = min(1, max(0, grown / WorkbenchTokens.Native.islandGlassRamp))
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
                    }
                    // The notch on it stays black, as the hardware is.
                    IslandShape(topRadius: notch.topRadius, bottomRadius: notch.bottomRadius, earY: earY)
                        .fill(WorkbenchTokens.Island.surface)
                        .frame(width: notch.size.width, height: notch.size.height)
                        .offset(x: (s.width - notch.size.width) / 2)
                }
                .frame(width: s.width, height: s.height, alignment: .topLeading)
            }
    }
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

/// The island's surface in the design in force: Original's one black outline, or Native's glass
/// (one shape hanging from the top edge, or the island and a panel floating under it), the notch
/// black on it. In Native everything on the glass takes the display's scheme (`.panelScheme()`).
struct IslandSurface: ViewModifier {
    let model: WorkbenchModel
    let layout: StackLayout

    func body(content: Content) -> some View {
        // Full screen, the island hangs from the black band, not the screen's top edge.
        let earY = model.screenContent.fullScreen ? model.metrics.safeAreaTop : 0
        if WorkbenchTokens.isNative {
            let rest = NotchGeometry.frames(density: .resting, metrics: model.metrics, spec: WorkbenchTokens.Island.spec)
            content
                .modifier(NativeSurface(shapes: model.nativeShapes, earY: earY, gap: WorkbenchTokens.Native.panelGap,
                                        notch: StackLayout.Outline(size: CGSize(width: rest.width, height: rest.minHeight),
                                                                   topRadius: rest.topRadius, bottomRadius: rest.bottomRadius)) { edge in
                    AgentEdgeLayer(model: model, edge: edge)
                })
                .animation(model.islandAnimation, value: model.nativeShapes)
        } else {
            content
                .modifier(IslandOutline(width: layout.outline.size.width, height: layout.outline.size.height,
                                        topRadius: layout.outline.topRadius, bottomRadius: layout.outline.bottomRadius,
                                        earY: earY) { edge in
                    AgentEdgeLayer(model: model, edge: edge)
                })
                .animation(model.islandAnimation, value: layout.outline)
        }
    }
}

// Copied from Prototypes/FoveaWorkbench/MockDesktop/IslandShape.swift (itself copied from
// Sources/Fovea/Island/IslandShape.swift) on Oct 7. It may drift from both.

import SwiftUI

/// The island outline: concave "ears" at the top that fuse into the menu bar, straight
/// sides, convex bottom corners. With `topRadius == 0` the top corners are square: the
/// physical notch.
///
/// Path after DynamicNotchKit's NotchShape (MIT, © Kai Azim). Both radii animate, in
/// the same transaction as the width and the content inset, so the ears, sides and
/// corners move as one shape instead of the ears snapping ahead of the rest.
struct IslandShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    /// Where the ears sit: 0 on the desktop, where the island hangs from the screen's top edge;
    /// the black band's bottom edge when an app is full screen, so the bar still meets what it
    /// hangs from with a rounded corner. Above it the shape is square, inside the band. It never
    /// sits lower than the shape has room for, so a resting island stays inside the band.
    var earY: CGFloat = 0

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let tr = max(0, min(topRadius, rect.width / 2))
        let br = max(0, min(bottomRadius, rect.height, rect.width / 2 - tr))
        let ey = rect.minY + max(0, min(earY, rect.height - br - tr))
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: ey))
        if tr > 0 {
            p.addQuadCurve(to: CGPoint(x: rect.minX + tr, y: ey + tr),
                           control: CGPoint(x: rect.minX + tr, y: ey))
        }
        p.addLine(to: CGPoint(x: rect.minX + tr, y: rect.maxY - br))
        p.addQuadCurve(to: CGPoint(x: rect.minX + tr + br, y: rect.maxY),
                       control: CGPoint(x: rect.minX + tr, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - tr - br, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - tr, y: rect.maxY - br),
                       control: CGPoint(x: rect.maxX - tr, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: ey + tr))
        if tr > 0 {
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: ey),
                           control: CGPoint(x: rect.maxX - tr, y: ey))
        }
        if ey > rect.minY {
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        }
        p.closeSubpath()
        return p
    }
}

/// How the bar's content shows and hides: opacity with a light blur and a small scale from
/// the top, one modifier for both directions so the exit is the entrance played backwards.
/// Driven as a plain animatable value (`progress`), never as an insert/remove transition.
struct VoiceContentTransition: ViewModifier, Animatable {
    /// 0 = hidden, 1 = shown.
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .blur(radius: (1 - progress) * OT.Motion.contentBlur)
            .scaleEffect(OT.Motion.contentScale + (1 - OT.Motion.contentScale) * progress, anchor: .top)
    }
}

/// The island's outline as one animatable value: size and corners move through real layout
/// on every frame of the spring. (A plain `.frame` change is animated at render time only,
/// which grows in a jump and starts its shrink late.) Draws the surface, sizes the content
/// to the outline with the content along its bottom edge, and clips to it. An edge layer (the
/// agent studies' rim light, comet, beam) is drawn from the outline as it is on each frame,
/// inside the clip, so it follows the spring and never spills past the island.
struct IslandOutline<Edge: View>: ViewModifier, Animatable {
    var width: CGFloat
    var height: CGFloat
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    /// See `IslandShape.earY`.
    var earY: CGFloat = 0
    var edge: (IslandEdge) -> Edge

    init(width: CGFloat, height: CGFloat, topRadius: CGFloat, bottomRadius: CGFloat, earY: CGFloat = 0,
         @ViewBuilder edge: @escaping (IslandEdge) -> Edge) {
        self.width = width
        self.height = height
        self.topRadius = topRadius
        self.bottomRadius = bottomRadius
        self.earY = earY
        self.edge = edge
    }

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(width, height), AnimatablePair(topRadius, bottomRadius)) }
        set {
            width = newValue.first.first; height = newValue.first.second
            topRadius = newValue.second.first; bottomRadius = newValue.second.second
        }
    }

    func body(content: Content) -> some View {
        let shape = IslandShape(topRadius: topRadius, bottomRadius: bottomRadius, earY: earY)
        content
            .frame(width: width, height: height, alignment: .bottom)
            .overlay(alignment: .topLeading) {
                edge(IslandEdge(size: CGSize(width: width, height: height), topRadius: topRadius,
                                bottomRadius: bottomRadius, earY: earY))
            }
            .background(shape.fill(OT.Island.surface))
            .clipShape(shape)
    }
}

extension IslandOutline where Edge == EmptyView {
    init(width: CGFloat, height: CGFloat, topRadius: CGFloat, bottomRadius: CGFloat, earY: CGFloat = 0) {
        self.init(width: width, height: height, topRadius: topRadius, bottomRadius: bottomRadius, earY: earY) { _ in EmptyView() }
    }
}

/// The island's visible edge on one frame: down one side from under the ear, round the bottom
/// corners, up the other side. No top (that is the screen's edge, or the band), no ears.
struct IslandEdge: Equatable {
    var size: CGSize
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    var earY: CGFloat

    private var corners: (tr: CGFloat, br: CGFloat, top: CGFloat) {
        let tr = max(0, min(topRadius, size.width / 2))
        let br = max(0, min(bottomRadius, size.height, size.width / 2 - tr))
        let ey = max(0, min(earY, size.height - br - tr))
        return (tr, br, ey + tr)
    }

    /// The edge, or a line `inset` inside it (the island clips at the edge itself, so what should
    /// show whole runs a little inside).
    func path(inset: CGFloat = 0) -> Path {
        let (tr0, br0, top) = corners
        let tr = tr0 + inset, br = max(0, br0 - inset)
        let right = size.width - tr, h = size.height - inset
        var p = Path()
        p.move(to: CGPoint(x: tr, y: top))
        p.addLine(to: CGPoint(x: tr, y: h - br))
        p.addQuadCurve(to: CGPoint(x: tr + br, y: h), control: CGPoint(x: tr, y: h))
        p.addLine(to: CGPoint(x: right - br, y: h))
        p.addQuadCurve(to: CGPoint(x: right, y: h - br), control: CGPoint(x: right, y: h))
        p.addLine(to: CGPoint(x: right, y: top))
        return p
    }

    /// Points along the edge (or `inset` inside it), about a point apart, each with its
    /// distance from the start.
    func samples(inset: CGFloat = 0) -> [(point: CGPoint, distance: CGFloat)] {
        let (tr0, br0, top) = corners
        let tr = tr0 + inset, br = max(0, br0 - inset)
        let h = size.height - inset
        var points: [CGPoint] = []
        func line(_ a: CGPoint, _ b: CGPoint) {
            let n = max(1, Int(hypot(b.x - a.x, b.y - a.y)))
            for i in 0..<n { let t = CGFloat(i) / CGFloat(n); points.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)) }
        }
        func quad(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint) {
            let n = max(2, Int(br))
            for i in 0..<n {
                let t = CGFloat(i) / CGFloat(n), u = 1 - t
                points.append(CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x, y: u * u * a.y + 2 * u * t * c.y + t * t * b.y))
            }
        }
        let right = size.width - tr
        line(CGPoint(x: tr, y: top), CGPoint(x: tr, y: h - br))
        quad(CGPoint(x: tr, y: h - br), CGPoint(x: tr, y: h), CGPoint(x: tr + br, y: h))
        line(CGPoint(x: tr + br, y: h), CGPoint(x: right - br, y: h))
        quad(CGPoint(x: right - br, y: h), CGPoint(x: right, y: h), CGPoint(x: right, y: h - br))
        line(CGPoint(x: right, y: h - br), CGPoint(x: right, y: top))
        points.append(CGPoint(x: right, y: top))
        var out: [(CGPoint, CGFloat)] = []
        var d: CGFloat = 0
        for (i, p) in points.enumerated() {
            if i > 0 { d += hypot(p.x - points[i - 1].x, p.y - points[i - 1].y) }
            out.append((p, d))
        }
        return out
    }
}

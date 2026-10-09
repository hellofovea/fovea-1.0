// Copied from Prototypes/FoveaWorkbench/MockDesktop/IslandShape.swift (the shape only).
// It may drift from the workbench file.

import SwiftUI

/// The island outline: concave "ears" at the top that fuse into the menu bar, straight sides,
/// convex bottom corners. With `topRadius == 0` the top corners are square: the physical notch.
struct IslandShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let tr = max(0, min(topRadius, rect.width / 2))
        let br = max(0, min(bottomRadius, rect.height, rect.width / 2 - tr))
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        if tr > 0 {
            p.addQuadCurve(to: CGPoint(x: rect.minX + tr, y: rect.minY + tr), control: CGPoint(x: rect.minX + tr, y: rect.minY))
        }
        p.addLine(to: CGPoint(x: rect.minX + tr, y: rect.maxY - br))
        p.addQuadCurve(to: CGPoint(x: rect.minX + tr + br, y: rect.maxY), control: CGPoint(x: rect.minX + tr, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - tr - br, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - tr, y: rect.maxY - br), control: CGPoint(x: rect.maxX - tr, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY + tr))
        if tr > 0 {
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.maxX - tr, y: rect.minY))
        }
        p.closeSubpath()
        return p
    }
}

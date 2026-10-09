#!/usr/bin/env swift
// Fovea's app icon. Since Oct 6 it's Ryan's serif f, its hook curling into the o: traced from his
// artwork (Brand/Source/fovea-serif-f.png), not drawn, so the mark is his to the curve. The
// geometric "fo" it replaced (the o an eye, the dot in it the fovea, the point the eye sees
// sharpest) is still drawn from measurements, for the variants and the menu bar's eye. One
// outline drives every export, so the SVG masters, the PNGs, the layered macOS 26 icon and the
// variants never drift.
//
//   swift scripts/fovea-icon.swift            write the brand assets, AppIcon.png and the variants
//   swift scripts/fovea-icon.swift --check    compare the as-drawn fo with the original drawing
//
// Design units are the original drawing's: its icon tile is 988 units square at (140, 118), y down.
// Every mark is placed by mapping that tile onto the target (the 824-unit body of a 1024 macOS
// icon, or the full 1024 canvas of a layered icon), so the drawing's placement is kept; the serif
// f's artwork tile is mapped onto the same one.

import AppKit
import CoreGraphics
import Foundation

// MARK: - The mark

struct Mark {
    var name: String
    var title: String
    // The f: a stem, a hook (two arcs and a band to the terminal) and a crossbar.
    var stemLeft: CGFloat = 318
    var stemRight: CGFloat = 439
    var baseline: CGFloat = 902
    var top: CGFloat = 307
    var hookOuterRadius: CGFloat = 200
    var bandBottom: CGFloat = 412
    var hookInnerRadius: CGFloat = 76
    var terminalRight: CGFloat = 605
    var barLeft: CGFloat = 251
    var barRight: CGFloat = 551
    var barTop: CGFloat = 501
    var barBottom: CGFloat = 596
    /// The small corners: the stem's foot, the terminal, the crossbar's ends.
    var soft: CGFloat = 22
    // The o: a rounded square ring (or a circle), and the dot.
    var oLeft: CGFloat = 563
    var oRight: CGFloat = 1016
    var oTop: CGFloat = 493
    var oBottom: CGFloat = 907
    /// Ring weight at the sides and at the top and bottom.
    var oSide: CGFloat = 100
    var oCap: CGFloat = 83
    var oRadius: CGFloat = 158
    var innerRadius: CGFloat = 86
    var smoothing: CGFloat = 0.6
    var round = false
    var dot: CGFloat = 84
    /// The dot's center, from the counter's center.
    var dotOffset = CGPoint(x: -1.5, y: -5)

    /// The drawing as it was handed over, rebuilt as vector.
    static let asDrawn = Mark(name: "as-drawn", title: "As drawn")

    /// Weights evened out: the f's stem was heavier than the o's sides (121 against 97 to 102
    /// units), so the stem comes down and the ring goes up, a little heavier at the sides than at
    /// the top and bottom, as a round letter needs to look as heavy as a straight one.
    static var balanced: Mark {
        var m = Mark(name: "balanced", title: "Balanced")
        m.stemLeft = 323; m.stemRight = 434
        m.hookOuterRadius = 196
        m.bandBottom = 405
        m.hookInnerRadius = 80
        m.barTop = 503; m.barBottom = 595
        m.oSide = 112; m.oCap = 96
        m.innerRadius = 84
        m.dot = 86
        m.dotOffset = CGPoint(x: 0, y: -4)
        return m
    }

    /// The dot off center, up and to the right: an eye looking, not a lens staring back.
    static var looking: Mark {
        var m = balanced
        m.name = "looking"; m.title = "Looking"
        m.dotOffset = CGPoint(x: 26, y: -22)
        return m
    }

    /// A round o: the eye reads first, the camera less.
    static var round: Mark {
        var m = balanced
        m.name = "round"; m.title = "Round o"
        m.round = true
        return m
    }

    /// For 16 and 32 pixels: a wider gap, a heavier ring and a bigger dot, so neither the gap nor
    /// the counter closes up.
    static var small: Mark {
        var m = balanced
        m.name = "small"; m.title = "Small sizes"
        m.barRight = 536
        m.terminalRight = 598
        m.oLeft += 22; m.oRight += 22
        m.oSide = 118; m.oCap = 104
        m.dot = 104
        m.dotOffset = .zero
        return m
    }
}

// MARK: - Paths (y down)

func rad(_ d: CGFloat) -> CGFloat { d * .pi / 180 }

/// A rounded rectangle with Figma-style corner smoothing (Apple's continuous corner is about 0.6).
func squircle(_ rect: CGRect, radius r0: CGFloat, smoothing s0: CGFloat) -> CGPath {
    let budget = min(rect.width, rect.height) / 2
    let r = min(r0, budget)
    var s = s0
    var p = (1 + s) * r
    if p > budget { s = max(0, min(s, budget / r - 1)); p = min((1 + s) * r, budget) }
    let arcMeasure = 90 * (1 - s)
    let arcSection = sin(rad(arcMeasure / 2)) * r * sqrt(2)
    let alpha = (90 - arcMeasure) / 2
    let p3p4 = r * tan(rad(alpha / 2))
    let beta = 45 * s
    let c = p3p4 * cos(rad(beta))
    let d = c * tan(rad(beta))
    let b = (p - arcSection - c - d) / 3
    let a = 2 * b
    let (x0, y0, x1, y1) = (rect.minX, rect.minY, rect.maxX, rect.maxY)
    let path = CGMutablePath()
    // Each corner: a cubic onto the arc, the arc, a cubic off it. Angles grow clockwise (y down).
    func corner(center: CGPoint, from p1: CGPoint, c1: CGPoint, c2: CGPoint, p2: CGPoint,
                arcEnd: CGPoint, c3: CGPoint, c4: CGPoint, p3: CGPoint) {
        path.addLine(to: p1)
        path.addCurve(to: p2, control1: c1, control2: c2)
        let start = atan2(p2.y - center.y, p2.x - center.x)
        let end = atan2(arcEnd.y - center.y, arcEnd.x - center.x)
        var sweepEnd = end
        while sweepEnd < start { sweepEnd += 2 * .pi }
        if r > 0.01 { path.addArc(center: center, radius: r, startAngle: start, endAngle: sweepEnd, clockwise: false) }
        path.addCurve(to: p3, control1: c3, control2: c4)
    }
    path.move(to: CGPoint(x: x0 + p, y: y0))
    // Top right.
    do {
        let p1 = CGPoint(x: x1 - p, y: y0)
        let p2 = CGPoint(x: p1.x + a + b + c, y: y0 + d)
        let e = CGPoint(x: p2.x + arcSection, y: p2.y + arcSection)
        corner(center: CGPoint(x: x1 - r, y: y0 + r), from: p1,
               c1: CGPoint(x: p1.x + a, y: y0), c2: CGPoint(x: p1.x + a + b, y: y0), p2: p2, arcEnd: e,
               c3: CGPoint(x: e.x + d, y: e.y + c), c4: CGPoint(x: e.x + d, y: e.y + b + c),
               p3: CGPoint(x: e.x + d, y: e.y + a + b + c))
    }
    // Bottom right.
    do {
        let p1 = CGPoint(x: x1, y: y1 - p)
        let p2 = CGPoint(x: x1 - d, y: p1.y + a + b + c)
        let e = CGPoint(x: p2.x - arcSection, y: p2.y + arcSection)
        corner(center: CGPoint(x: x1 - r, y: y1 - r), from: p1,
               c1: CGPoint(x: x1, y: p1.y + a), c2: CGPoint(x: x1, y: p1.y + a + b), p2: p2, arcEnd: e,
               c3: CGPoint(x: e.x - c, y: e.y + d), c4: CGPoint(x: e.x - b - c, y: e.y + d),
               p3: CGPoint(x: e.x - a - b - c, y: e.y + d))
    }
    // Bottom left.
    do {
        let p1 = CGPoint(x: x0 + p, y: y1)
        let p2 = CGPoint(x: p1.x - a - b - c, y: y1 - d)
        let e = CGPoint(x: p2.x - arcSection, y: p2.y - arcSection)
        corner(center: CGPoint(x: x0 + r, y: y1 - r), from: p1,
               c1: CGPoint(x: p1.x - a, y: y1), c2: CGPoint(x: p1.x - a - b, y: y1), p2: p2, arcEnd: e,
               c3: CGPoint(x: e.x - d, y: e.y - c), c4: CGPoint(x: e.x - d, y: e.y - b - c),
               p3: CGPoint(x: e.x - d, y: e.y - a - b - c))
    }
    // Top left.
    do {
        let p1 = CGPoint(x: x0, y: y0 + p)
        let p2 = CGPoint(x: x0 + d, y: p1.y - a - b - c)
        let e = CGPoint(x: p2.x + arcSection, y: p2.y - arcSection)
        corner(center: CGPoint(x: x0 + r, y: y0 + r), from: p1,
               c1: CGPoint(x: x0, y: p1.y - a), c2: CGPoint(x: x0, y: p1.y - a - b), p2: p2, arcEnd: e,
               c3: CGPoint(x: e.x + c, y: e.y - d), c4: CGPoint(x: e.x + b + c, y: e.y - d),
               p3: CGPoint(x: e.x + a + b + c, y: e.y - d))
    }
    path.closeSubpath()
    return path
}

/// A rectangle with its own radius at each corner (circular, for the small corners).
func roundedRect(_ r: CGRect, tl: CGFloat = 0, tr: CGFloat = 0, br: CGFloat = 0, bl: CGFloat = 0) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: r.minX + tl, y: r.minY))
    p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.maxY), radius: tr)
    p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY), radius: br)
    p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.minY), radius: bl)
    p.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY), radius: tl)
    p.closeSubpath()
    return p
}

extension Mark {
    var f: CGPath {
        let outerCenter = CGPoint(x: stemLeft + hookOuterRadius, y: top + hookOuterRadius)
        let innerCenter = CGPoint(x: stemRight + hookInnerRadius, y: bandBottom + hookInnerRadius)
        let hook = CGMutablePath()
        hook.move(to: CGPoint(x: stemLeft, y: outerCenter.y))
        hook.addArc(center: outerCenter, radius: hookOuterRadius, startAngle: .pi, endAngle: 1.5 * .pi, clockwise: false)
        hook.addArc(tangent1End: CGPoint(x: terminalRight, y: top), tangent2End: CGPoint(x: terminalRight, y: bandBottom), radius: soft)
        hook.addArc(tangent1End: CGPoint(x: terminalRight, y: bandBottom), tangent2End: CGPoint(x: innerCenter.x, y: bandBottom), radius: soft)
        hook.addLine(to: CGPoint(x: innerCenter.x, y: bandBottom))
        hook.addArc(center: innerCenter, radius: hookInnerRadius, startAngle: 1.5 * .pi, endAngle: .pi, clockwise: true)
        let joinY = max(outerCenter.y, innerCenter.y) + 2
        hook.addLine(to: CGPoint(x: stemRight, y: joinY))
        hook.addLine(to: CGPoint(x: stemLeft, y: joinY))
        hook.closeSubpath()
        // The stem starts where the outer arc ends, so its edge carries the arc's tangent with no
        // step; the hook covers everything above that across the stem's width.
        let stemTop = max(outerCenter.y, innerCenter.y)
        let stem = roundedRect(CGRect(x: stemLeft, y: stemTop, width: stemRight - stemLeft, height: baseline - stemTop),
                               br: soft, bl: soft)
        let bar = roundedRect(CGRect(x: barLeft, y: barTop, width: barRight - barLeft, height: barBottom - barTop),
                              tl: soft, tr: soft, br: soft, bl: soft)
        return hook.union(stem).union(bar)
    }

    var counter: CGRect {
        CGRect(x: oLeft + oSide, y: oTop + oCap, width: oRight - oLeft - 2 * oSide, height: oBottom - oTop - 2 * oCap)
    }

    var o: CGPath {
        if round {
            let d = oBottom - oTop
            let center = CGPoint(x: (oLeft + oRight) / 2, y: (oTop + oBottom) / 2)
            let outer = CGPath(ellipseIn: CGRect(x: center.x - d / 2, y: oTop, width: d, height: d), transform: nil)
            let w = (oSide + oCap) / 2
            let inner = CGPath(ellipseIn: CGRect(x: center.x - d / 2 + w, y: oTop + w, width: d - 2 * w, height: d - 2 * w), transform: nil)
            return outer.subtracting(inner)
        }
        let outer = squircle(CGRect(x: oLeft, y: oTop, width: oRight - oLeft, height: oBottom - oTop), radius: oRadius, smoothing: smoothing)
        let inner = squircle(counter, radius: innerRadius, smoothing: smoothing)
        return outer.subtracting(inner)
    }

    var dotCenter: CGPoint {
        let c: CGPoint
        if round {
            c = CGPoint(x: (oLeft + oRight) / 2, y: (oTop + oBottom) / 2)
        } else {
            c = CGPoint(x: counter.midX, y: counter.midY)
        }
        return CGPoint(x: c.x + dotOffset.x, y: c.y + dotOffset.y)
    }

    var dotPath: CGPath {
        let c = dotCenter
        return CGPath(ellipseIn: CGRect(x: c.x - dot / 2, y: c.y - dot / 2, width: dot, height: dot), transform: nil)
    }

    /// The whole mark as one outline.
    var glyph: CGPath { f.union(o).union(dotPath) }
    /// The o and its dot alone: the eye, for the menu bar.
    var eye: CGPath { o.union(dotPath) }
}

// MARK: - Placement

/// The original drawing's icon tile, in design units.
let tile = CGRect(x: 140, y: 118, width: 988, height: 988)

/// Maps the drawing's tile onto `target`.
func placing(onto target: CGRect) -> CGAffineTransform {
    let k = target.width / tile.width
    return CGAffineTransform(translationX: target.minX - tile.minX * k, y: target.minY - tile.minY * k).scaledBy(x: k, y: k)
}

// MARK: - The serif f (traced)

/// Ryan's serif f (Oct 6), traced from his artwork. The glyph's coverage (one minus the luminance)
/// is followed at one half by marching squares, from a point in the stem (the glyph is one shape:
/// the hairlines and the ring all join the stem, so nothing else in the picture is taken); the
/// outline is thinned to within a third of a pixel (Ramer–Douglas–Peucker), and the artwork's tile
/// is mapped onto the drawing's, so the glyph sits as Ryan placed it.
enum Serif {
    /// The artwork's white tile, measured: x 119–1133, y 131–1126. It's 2 % wider than tall, so
    /// it's taken as a square on its center, keeping the glyph's proportions.
    static let sourceTile = CGRect(x: 626 - 502.5, y: 628.5 - 502.5, width: 1005, height: 1005)
    /// A point in the stem.
    static let seed = (x: 505, y: 798)
    /// How far the thinned outline may stray from the traced one, in the artwork's pixels.
    static let tolerance: CGFloat = 0.33

    static func glyph(from url: URL) -> CGPath {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fatalError("no artwork at \(url.path)") }
        let w = image.width, h = image.height
        // Coverage, the top row first.
        var cover = [Float](repeating: 0, count: w * h)
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        rgba.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        for i in 0..<(w * h) {
            let l = 0.2126 * Float(rgba[4 * i]) + 0.7152 * Float(rgba[4 * i + 1]) + 0.0722 * Float(rgba[4 * i + 2])
            cover[i] = 1 - l / 255
        }
        // The glyph: everything darker than mid grey joined to the stem.
        var inGlyph = [Bool](repeating: false, count: w * h)
        let start = seed.y * w + seed.x
        precondition(cover[start] > 0.5, "the seed isn't in the glyph")
        inGlyph[start] = true
        var stack = [start]
        var bx0 = w, bx1 = 0, by0 = h, by1 = 0
        while let i = stack.popLast() {
            let x = i % w, y = i / w
            bx0 = min(bx0, x); bx1 = max(bx1, x); by0 = min(by0, y); by1 = max(by1, y)
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let nx = x + dx, ny = y + dy
                guard nx >= 0, ny >= 0, nx < w, ny < h else { continue }
                let j = ny * w + nx
                if !inGlyph[j] && cover[j] > 0.5 { inGlyph[j] = true; stack.append(j) }
            }
        }
        // Its soft edge too: the coverage counts within two pixels of it, and nowhere else.
        var near = [Bool](repeating: false, count: w * h)
        for y in max(0, by0 - 2)...min(h - 1, by1 + 2) {
            for x in max(0, bx0 - 2)...min(w - 1, bx1 + 2) where inGlyph[y * w + x] {
                for ny in max(0, y - 2)...min(h - 1, y + 2) { for nx in max(0, x - 2)...min(w - 1, x + 2) { near[ny * w + nx] = true } }
            }
        }
        func v(_ x: Int, _ y: Int) -> Float {
            guard x >= 0, y >= 0, x < w, y < h, near[y * w + x] else { return 0 }
            return cover[y * w + x]
        }
        // Marching squares over the pixel centres; each crossing is keyed by its edge.
        let t: Float = 0.5
        var points: [Int: CGPoint] = [:]
        var links: [Int: [Int]] = [:]
        func crossing(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int) -> Int {
            let k = ((y0 + 4) * (w + 8) + (x0 + 4)) * 2 + (y0 == y1 ? 1 : 0)
            if points[k] == nil {
                let a = v(x0, y0), b = v(x1, y1)
                let f = CGFloat((t - a) / (b - a))
                points[k] = CGPoint(x: CGFloat(x0) + 0.5 + f * CGFloat(x1 - x0), y: CGFloat(y0) + 0.5 + f * CGFloat(y1 - y0))
            }
            return k
        }
        func link(_ a: Int, _ b: Int) { links[a, default: []].append(b); links[b, default: []].append(a) }
        for y in (by0 - 3)...(by1 + 2) {
            for x in (bx0 - 3)...(bx1 + 2) {
                let a = v(x, y), b = v(x + 1, y), c = v(x + 1, y + 1), d = v(x, y + 1)
                let index = (a >= t ? 8 : 0) | (b >= t ? 4 : 0) | (c >= t ? 2 : 0) | (d >= t ? 1 : 0)
                if index == 0 || index == 15 { continue }
                let top = { crossing(x, y, x + 1, y) }, bottom = { crossing(x, y + 1, x + 1, y + 1) }
                let left = { crossing(x, y, x, y + 1) }, right = { crossing(x + 1, y, x + 1, y + 1) }
                let joined = (a + b + c + d) / 4 >= t
                switch index {
                case 1, 14: link(left(), bottom())
                case 2, 13: link(bottom(), right())
                case 3, 12: link(left(), right())
                case 4, 11: link(top(), right())
                case 6, 9: link(top(), bottom())
                case 7, 8: link(left(), top())
                case 5: if joined { link(left(), top()); link(bottom(), right()) } else { link(top(), right()); link(left(), bottom()) }
                case 10: if joined { link(top(), right()); link(left(), bottom()) } else { link(left(), top()); link(bottom(), right()) }
                default: break
                }
            }
        }
        // The crossings joined into closed outlines.
        var loops: [[CGPoint]] = []
        var visited = Set<Int>()
        for first in links.keys where !visited.contains(first) {
            var loop: [CGPoint] = []
            var previous = -1, current = first
            while !visited.contains(current) {
                visited.insert(current)
                loop.append(points[current]!)
                let next = links[current]!
                let onward = next.first { $0 != previous && !visited.contains($0) } ?? next.first { $0 != previous } ?? first
                previous = current; current = onward
            }
            loops.append(loop)
        }
        // Thinned, specks dropped, and placed on the drawing's tile.
        func thin(_ pts: [CGPoint]) -> [CGPoint] {
            guard pts.count > 2 else { return pts }
            var keep = [Bool](repeating: false, count: pts.count)
            keep[0] = true; keep[pts.count - 1] = true
            var spans = [(0, pts.count - 1)]
            while let (s, e) = spans.popLast() {
                guard e > s + 1 else { continue }
                let a = pts[s], b = pts[e]
                let dx = b.x - a.x, dy = b.y - a.y, length = max(1e-9, (dx * dx + dy * dy).squareRoot())
                var far: CGFloat = 0, index = s
                for i in (s + 1)..<e {
                    let d = abs((pts[i].x - a.x) * dy - (pts[i].y - a.y) * dx) / length
                    if d > far { far = d; index = i }
                }
                if far > tolerance { keep[index] = true; spans.append((s, index)); spans.append((index, e)) }
            }
            return pts.indices.filter { keep[$0] }.map { pts[$0] }
        }
        func area(_ pts: [CGPoint]) -> CGFloat {
            var sum: CGFloat = 0
            for i in pts.indices { let p = pts[i], q = pts[(i + 1) % pts.count]; sum += p.x * q.y - q.x * p.y }
            return abs(sum) / 2
        }
        let k = tile.width / sourceTile.width
        func place(_ p: CGPoint) -> CGPoint {
            CGPoint(x: tile.minX + (p.x - sourceTile.minX) * k, y: tile.minY + (p.y - sourceTile.minY) * k)
        }
        let path = CGMutablePath()
        for loop in loops where loop.count > 8 && area(loop) > 20 {
            // Split at the point farthest from the start, so each half thins as an open line.
            let start = loop[0]
            let far = loop.indices.max { a, b in
                hypot(loop[a].x - start.x, loop[a].y - start.y) < hypot(loop[b].x - start.x, loop[b].y - start.y)
            }!
            let outline = thin(Array(loop[0...far])) + thin(Array(loop[far...]) + [start]).dropFirst().dropLast()
            path.addLines(between: outline.map(place))
            path.closeSubpath()
        }
        return path.normalized(using: .evenOdd)
    }
}

/// One design the generator exports: its outline in the drawing's units, and the outline drawn
/// for 16 and 32 pixels.
struct Design {
    var name: String
    var title: String
    var glyph: CGPath
    var smallGlyph: CGPath

    /// A geometric fo, with the small-size master shaped as the mark is (its o round or not, its
    /// eye looking where the mark's does, a little less).
    init(_ mark: Mark) {
        name = mark.name; title = mark.title; glyph = mark.glyph
        var small = Mark.small
        small.round = mark.round
        small.dotOffset = mark.dotOffset == .zero ? .zero : CGPoint(x: mark.dotOffset.x * 0.8, y: mark.dotOffset.y * 0.8)
        smallGlyph = small.glyph
    }

    /// A traced mark: one outline at every size.
    init(name: String, title: String, glyph: CGPath) {
        self.name = name; self.title = title; self.glyph = glyph; smallGlyph = glyph
    }
}

/// The body of a 1024 macOS icon (Apple's grid: 824 square, 100 in from each edge).
let iconBody = CGRect(x: 100, y: 100, width: 824, height: 824)
let iconBodyRadius: CGFloat = 185.4

struct Look {
    var name: String
    var field: NSColor
    var ink: NSColor
    var edge: NSColor
}
let ink = NSColor(srgbRed: 0x0C / 255, green: 0x0C / 255, blue: 0x0C / 255, alpha: 1)
let lightLook = Look(name: "light", field: .white, ink: ink, edge: NSColor(white: 0, alpha: 0.07))
let darkLook = Look(name: "dark", field: .black, ink: .white, edge: NSColor(white: 1, alpha: 0.14))

// MARK: - Rendering

func bitmap(_ w: Int, _ h: Int, _ draw: (CGContext) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!.retagging(with: .sRGB)!
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gc
    let ctx = gc.cgContext
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    // Design space is y down.
    ctx.translateBy(x: 0, y: CGFloat(h))
    ctx.scaleBy(x: 1, y: -1)
    draw(ctx)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, _ url: URL) {
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

/// A full macOS app icon at `px` pixels: the body with its shadow, the mark on it.
func renderIcon(_ outline: CGPath, _ look: Look, px: Int) -> NSBitmapImageRep {
    bitmap(px, px) { ctx in
        let k = CGFloat(px) / 1024
        ctx.scaleBy(x: k, y: k)
        let body = squircle(iconBody, radius: iconBodyRadius, smoothing: 0.6)
        // Apple's grid shadow: soft, straight down. The context is flipped, so the offset is
        // given in the bitmap's own (y up) space.
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10 * k), blur: 22 * k, color: NSColor(white: 0, alpha: 0.28).cgColor)
        ctx.addPath(body); ctx.setFillColor(look.field.cgColor); ctx.fillPath()
        ctx.restoreGState()
        // A hairline inside the edge, so the white field holds its shape on a white desktop.
        ctx.saveGState()
        ctx.addPath(body); ctx.clip()
        ctx.addPath(body); ctx.setStrokeColor(look.edge.cgColor); ctx.setLineWidth(3); ctx.strokePath()
        ctx.restoreGState()
        var t = placing(onto: iconBody)
        let glyph = outline.copy(using: &t)!
        ctx.addPath(glyph); ctx.setFillColor(look.ink.cgColor); ctx.fillPath()
    }
}

/// The mark alone on transparency, fitted into `px` square with `pad` pixels around it.
func renderMark(_ path: CGPath, color: NSColor, px: Int, pad: CGFloat) -> NSBitmapImageRep {
    bitmap(px, px) { ctx in
        let b = path.boundingBoxOfPath
        let side = CGFloat(px) - 2 * pad
        let k = side / max(b.width, b.height)
        ctx.translateBy(x: pad + (side - b.width * k) / 2, y: pad + (side - b.height * k) / 2)
        ctx.scaleBy(x: k, y: k)
        ctx.translateBy(x: -b.minX, y: -b.minY)
        ctx.addPath(path); ctx.setFillColor(color.cgColor); ctx.fillPath()
    }
}

// MARK: - SVG

func svgPath(_ path: CGPath) -> String {
    var d = ""
    func f(_ v: CGFloat) -> String {
        let r = (v * 100).rounded() / 100
        return r == r.rounded() ? String(Int(r)) : String(format: "%.2f", r)
    }
    path.applyWithBlock { e in
        let p = e.pointee.points
        switch e.pointee.type {
        case .moveToPoint: d += "M\(f(p[0].x)) \(f(p[0].y))"
        case .addLineToPoint: d += "L\(f(p[0].x)) \(f(p[0].y))"
        case .addQuadCurveToPoint: d += "Q\(f(p[0].x)) \(f(p[0].y)) \(f(p[1].x)) \(f(p[1].y))"
        case .addCurveToPoint: d += "C\(f(p[0].x)) \(f(p[0].y)) \(f(p[1].x)) \(f(p[1].y)) \(f(p[2].x)) \(f(p[2].y))"
        case .closeSubpath: d += "Z"
        @unknown default: break
        }
    }
    return d
}

func hex(_ c: NSColor) -> String {
    let s = c.usingColorSpace(.sRGB)!
    return String(format: "#%02X%02X%02X", Int((s.redComponent * 255).rounded()), Int((s.greenComponent * 255).rounded()), Int((s.blueComponent * 255).rounded()))
}

func writeSVG(_ text: String, _ url: URL) {
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! text.write(to: url, atomically: true, encoding: .utf8)
}

func iconSVG(_ outline: CGPath, _ look: Look) -> String {
    var t = placing(onto: iconBody)
    let glyph = outline.copy(using: &t)!
    let body = squircle(iconBody, radius: iconBodyRadius, smoothing: 0.6)
    return """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="Fovea app icon">
      <path d="\(svgPath(body))" fill="\(hex(look.field))"/>
      <path d="\(svgPath(glyph))" fill="\(hex(look.ink))"/>
    </svg>

    """
}

/// The mark on transparency, in a viewBox fitted to it.
func markSVG(_ path: CGPath, _ color: NSColor, label: String) -> String {
    let b = path.boundingBoxOfPath.insetBy(dx: -2, dy: -2)
    var t = CGAffineTransform(translationX: -b.minX, y: -b.minY)
    let p = path.copy(using: &t)!
    return """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(Int(b.width.rounded(.up))) \(Int(b.height.rounded(.up)))" role="img" aria-label="\(label)">
      <path d="\(svgPath(p))" fill="\(hex(color))"/>
    </svg>

    """
}

// MARK: - The layered icon (Icon Composer's .icon, for macOS 26 and later)

/// One layer, the mark, on the system's light fill. macOS gives it the glass edge and shadow, and
/// renders the dark, clear and tinted appearances: in dark the field goes dark and the mark light.
func writeLayeredIcon(_ outline: CGPath, to dir: URL) {
    let fm = FileManager.default
    try? fm.removeItem(at: dir)
    try! fm.createDirectory(at: dir.appendingPathComponent("Assets"), withIntermediateDirectories: true)
    // The layer is the full 1024 canvas, so it needs no scale or offset.
    var t = placing(onto: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    let glyph = outline.copy(using: &t)!
    writeSVG("""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" role="img" aria-label="Fovea mark">
      <path d="\(svgPath(glyph))" fill="\(hex(ink))"/>
    </svg>

    """, dir.appendingPathComponent("Assets/fovea-mark.svg"))
    let json = """
    {
      "fill" : "system-light",
      "groups" : [
        {
          "layers" : [
            {
              "fill-specializations" : [
                { "appearance" : "dark", "value" : "system-light" },
                { "appearance" : "tinted", "value" : "system-light" }
              ],
              "glass" : false,
              "image-name" : "fovea-mark.svg",
              "name" : "fovea-mark",
              "opacity" : 1,
              "position" : { "scale" : 1, "translation-in-points" : [ 0, 0 ] }
            }
          ],
          "shadow" : { "kind" : "neutral", "opacity" : 0.5 },
          "translucency" : { "enabled" : false, "value" : 0.5 }
        }
      ],
      "supported-platforms" : { "squares" : "shared" }
    }

    """
    try! json.write(to: dir.appendingPathComponent("icon.json"), atomically: true, encoding: .utf8)
}

// MARK: - The comparison sheet

func drawText(_ s: String, at p: CGPoint, size: CGFloat, color: NSColor, weight: NSFont.Weight = .medium) {
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]
    NSAttributedString(string: s, attributes: attrs).draw(at: p)
}

/// Each variant at 256, 128, 64, 32 and 16 points on a light and a dark desktop, and the menu
/// bar's eye at its size.
func comparisonSheet(_ variants: [(Design, Look)], small: Mark) -> NSBitmapImageRep {
    let sizes: [CGFloat] = [256, 128, 64, 32, 16]
    let rowH: CGFloat = 300
    let width: CGFloat = 1400
    let height = CGFloat(variants.count) * rowH + 120
    let scale: CGFloat = 2
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!.retagging(with: .sRGB)!
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    // A flipped context (y down), so images and text both draw upright at top-left positions.
    let base = NSGraphicsContext(bitmapImageRep: rep)!
    let cg = base.cgContext
    cg.translateBy(x: 0, y: height); cg.scaleBy(x: 1, y: -1)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    NSColor(white: 0.95, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
    func image(_ rep: NSBitmapImageRep) -> NSImage { let i = NSImage(size: rep.size); i.addRepresentation(rep); return i }
    drawTextFlipped("Fovea app icon: variants at Dock and Finder sizes; 32 and 16 use the small-size master", at: CGPoint(x: 40, y: 34), size: 22, color: .black, weight: .semibold)
    for (i, (design, look)) in variants.enumerated() {
        let y0 = 100 + CGFloat(i) * rowH
        // Dark half under the smaller sizes, so each reads on both desktops.
        NSColor(white: 0.12, alpha: 1).setFill()
        NSRect(x: 920, y: y0, width: 480, height: rowH - 20).fill()
        drawTextFlipped("\(design.title) · \(look.name)", at: CGPoint(x: 40, y: y0), size: 17, color: .black, weight: .semibold)
        var x: CGFloat = 40
        for s in sizes {
            let r = renderIcon(s <= 32 ? design.smallGlyph : design.glyph, look, px: Int(s * scale))
            r.size = NSSize(width: s, height: s)
            image(r).draw(in: NSRect(x: x, y: y0 + 30, width: s, height: s), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            x += s + 34
        }
        // The same small sizes again, on the dark desktop.
        var xd: CGFloat = 950
        for s in [64, 32, 16] as [CGFloat] {
            let r = renderIcon(s <= 32 ? design.smallGlyph : design.glyph, look, px: Int(s * scale))
            r.size = NSSize(width: s, height: s)
            image(r).draw(in: NSRect(x: xd, y: y0 + 30, width: s, height: s), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            xd += s + 34
        }
        // The menu bar's eye, at 16 points, on a light and a dark bar.
        for (j, bar) in [NSColor(white: 0.9, alpha: 1), NSColor(white: 0.18, alpha: 1)].enumerated() {
            let bx: CGFloat = 950 + CGFloat(j) * 200, by = y0 + 180
            bar.setFill(); NSRect(x: bx, y: by, width: 160, height: 24).fill()
            var em = small; em.dotOffset = .zero
            let r = renderMark(em.eye, color: j == 0 ? .black : .white, px: Int(16 * scale), pad: 0)
            r.size = NSSize(width: 16, height: 16)
            image(r).draw(in: NSRect(x: bx + 72, y: by + 4, width: 16, height: 16), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func drawTextFlipped(_ s: String, at p: CGPoint, size: CGFloat, color: NSColor, weight: NSFont.Weight = .medium) {
    // The sheet's context is flipped, so text draws upright from its top-left corner.
    drawText(s, at: p, size: size, color: color, weight: weight)
}

// MARK: - Check against the drawing

func check() {
    let original = "/private/tmp/claude-501/-Users-yulunryanwu-Desktop-things-fovea-app-ui-v1/e2a5dc0f-ce18-4f6a-a5d1-a2a1791e9e57/images/14.webp"
    let mark = Mark.asDrawn
    let rep = bitmap(1269, 1239) { ctx in
        ctx.addPath(mark.glyph); ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
    }
    func dark(_ x: Int, _ y: Int) -> Bool { (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 }
    func runs(row y: Int) -> [(Int, Int)] { var r: [(Int, Int)] = []; var s: Int? = nil
        for x in 0..<1269 { if dark(x, y) { if s == nil { s = x } } else if let a = s { r.append((a, x - 1)); s = nil } }; return r }
    func runs(col x: Int) -> [(Int, Int)] { var r: [(Int, Int)] = []; var s: Int? = nil
        for y in 0..<1239 { if dark(x, y) { if s == nil { s = y } } else if let a = s { r.append((a, y - 1)); s = nil } }; return r }
    for y in [320, 360, 400, 450, 520, 560, 600, 650, 694, 750, 800, 850, 890] { print("row", y, runs(row: y)) }
    for x in [260, 340, 380, 420, 470, 520, 570, 600, 620, 700, 785, 870, 950, 1000] { print("col", x, runs(col: x)) }
    // An overlay: the drawing, and the rebuilt outline over it in red.
    if let img = NSImage(contentsOfFile: original) {
        let overlay = bitmap(1269, 1239) { ctx in
            NSGraphicsContext.saveGraphicsState()
            ctx.saveGState(); ctx.translateBy(x: 0, y: 1239); ctx.scaleBy(x: 1, y: -1)
            img.draw(in: NSRect(x: 0, y: 0, width: 1269, height: 1239))
            ctx.restoreGState()
            NSGraphicsContext.restoreGraphicsState()
            ctx.addPath(mark.glyph); ctx.setStrokeColor(NSColor.red.cgColor); ctx.setLineWidth(2); ctx.strokePath()
        }
        writePNG(overlay, URL(fileURLWithPath: "/private/tmp/claude-501/-Users-yulunryanwu-Desktop-things-fovea-app-ui-v1/e2a5dc0f-ce18-4f6a-a5d1-a2a1791e9e57/scratchpad/icon/overlay.png"))
    }
}

// MARK: - Main

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let resources = root.appendingPathComponent("Sources/FoveaCore/Resources")
let brand = resources.appendingPathComponent("Brand")

if CommandLine.arguments.contains("--check") {
    check()
    exit(0)
}

// The app's icon: Ryan's serif f (Oct 6), traced from his artwork. The geometric fo stays as
// variants, for the window's Variants menu and the comparison sheet, and its eye stays the menu
// bar's mark.
let main = Design(name: "serif", title: "Serif f", glyph: Serif.glyph(from: brand.appendingPathComponent("Source/fovea-serif-f.png")))
let small = Mark.small

// The app icon: the PNG the apps show in the Dock at runtime, and the full iconset the bundle's
// .icns is made from.
writePNG(renderIcon(main.glyph, lightLook, px: 1024), resources.appendingPathComponent("AppIcon.png"))
let iconset = brand.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let suffix = scale == 2 ? "@2x" : ""
        writePNG(renderIcon(px <= 32 ? main.smallGlyph : main.glyph, lightLook, px: px), iconset.appendingPathComponent("icon_\(base)x\(base)\(suffix).png"))
    }
}
writePNG(renderIcon(main.glyph, darkLook, px: 1024), brand.appendingPathComponent("fovea-app-icon-dark-1024.png"))

// SVG masters.
writeSVG(iconSVG(main.glyph, lightLook), brand.appendingPathComponent("fovea-app-icon.svg"))
writeSVG(iconSVG(main.glyph, darkLook), brand.appendingPathComponent("fovea-app-icon-dark.svg"))
writeSVG(markSVG(main.glyph, ink, label: "Fovea mark"), brand.appendingPathComponent("fovea-mark.svg"))
writeSVG(markSVG(main.glyph, .white, label: "Fovea mark"), brand.appendingPathComponent("fovea-mark-reversed.svg"))
writeSVG(markSVG(small.eye, ink, label: "Fovea eye"), brand.appendingPathComponent("fovea-eye.svg"))

// The menu bar's eye: template images (ink, and white for anywhere a template can't be used).
for px in [16, 18, 32, 36] {
    writePNG(renderMark(small.eye, color: .black, px: px, pad: px >= 32 ? 2 : 1), brand.appendingPathComponent("fovea-menubar-\(px).png"))
    writePNG(renderMark(small.eye, color: .white, px: px, pad: px >= 32 ? 2 : 1), brand.appendingPathComponent("fovea-menubar-\(px)-reversed.png"))
}

// The layered icon for macOS 26 and later.
writeLayeredIcon(main.glyph, to: brand.appendingPathComponent("AppIcon.icon"))

// Variants, at Dock size, for the window's Variants menu and the comparison sheet.
let variants: [(Design, Look)] = [
    (main, lightLook), (main, darkLook),
    (Design(.asDrawn), lightLook), (Design(.balanced), lightLook), (Design(.looking), lightLook), (Design(.round), lightLook),
    (Design(.balanced), darkLook),
]
for (design, look) in variants {
    writePNG(renderIcon(design.glyph, look, px: 1024), brand.appendingPathComponent("Variants/icon-\(design.name)-\(look.name).png"))
}
let sheet = comparisonSheet(variants, small: small)
writePNG(sheet, root.appendingPathComponent("Prototypes/shots/captures/icon-variants.png"))
print("wrote AppIcon.png, Brand/AppIcon.iconset, Brand/AppIcon.icon, masters, menu bar marks and \(variants.count) variants")

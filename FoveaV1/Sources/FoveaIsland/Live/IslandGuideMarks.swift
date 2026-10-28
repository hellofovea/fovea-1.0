import SwiftUI
import FoveaCore
import FoveaKit

// Oct 27, Ryan: "for the part of dragging the chat out, make sure to have more illustrations of
// what to do, like where to drag, have a circle around the place to hold while dragging and an
// arrow of where to put the chat to." The first run's guides, drawn by the island over everything
// on its display and never in the way of a click:
// - pull out: a ring round the session's grab bar, an arrow down to a window's ghost;
// - tuck: a ring round the pulled-out window's top, an arrow to the nearer side, a tab's ghost there;
// - search: a ring round the notch until the board is open, then round its search button.
// Each with a few words. The first run says which one is up (`IslandController.setGuide`).

/// The guide up now.
package enum IslandGuideMark: Equatable {
    case pullOut, tuck, search
}

extension WorkbenchTokens {
    enum Guide {
        static let ring: CGFloat = 40
        static let ringOutset: CGFloat = 10
        static let ringStroke: CGFloat = 2.5
        static let ringPulse: CGFloat = 1.18
        static let pulseTime: Double = 1.1
        static let arrowStroke: CGFloat = 2.5
        static let arrowHead: CGFloat = 11
        /// How far the arrow reaches: down out of the notch; short of the screen's side.
        static let pullDistance: CGFloat = 150
        static let edgeInset: CGFloat = 34
        /// Where the pulled-out window will be, and the tab at a side, as dashed ghosts.
        static let ghost = CGSize(width: 150, height: 92)
        static let tab = CGSize(width: 26, height: 72)
        static let ghostRadius: CGFloat = 12
        static let ghostDash: [CGFloat] = [5, 4]
        static let ghostStroke: CGFloat = 1.5
        static let labelFont = Font.system(size: 12, weight: .semibold)
        static let labelPadding = EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
        static let labelGap: CGFloat = 12
        static let shadow = Color.black.opacity(0.35)
        static var appear: Animation { Spring.fadeIn(0.2) }
    }
}

/// A ring in the accent round where to hold, breathing out a little (still with Reduce Motion).
struct GuideRing: View {
    let diameter: CGFloat
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var out = false

    var body: some View {
        let G = WorkbenchTokens.Guide.self
        Circle()
            .strokeBorder(color, lineWidth: G.ringStroke)
            .shadow(color: G.shadow, radius: 3)
            .frame(width: diameter, height: diameter)
            .scaleEffect(out && !reduceMotion ? G.ringPulse : 1)
            .opacity(out && !reduceMotion ? 0.75 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: G.pulseTime).repeatForever(autoreverses: true)) { out = true }
            }
    }
}

/// An arrow from `from` to `to`, bowed a little, its head at `to`.
struct GuideArrow: Shape {
    var from: CGPoint
    var to: CGPoint

    func path(in rect: CGRect) -> Path {
        let G = WorkbenchTokens.Guide.self
        var p = Path()
        let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        let dx = to.x - from.x, dy = to.y - from.y
        let length = max(1, (dx * dx + dy * dy).squareRoot())
        // Bowed to one side by a tenth of its length.
        let bow = CGPoint(x: mid.x - dy / length * length * 0.1, y: mid.y + dx / length * length * 0.1)
        p.move(to: from)
        p.addQuadCurve(to: to, control: bow)
        // The head, along the curve's last direction.
        let angle = atan2(to.y - bow.y, to.x - bow.x)
        for turn in [CGFloat.pi * 0.8, -CGFloat.pi * 0.8] {
            p.move(to: to)
            p.addLine(to: CGPoint(x: to.x + cos(angle + turn) * G.arrowHead, y: to.y + sin(angle + turn) * G.arrowHead))
        }
        return p
    }
}

/// A few words by the ring, on the panels' glass.
struct GuideLabel: View {
    let text: String

    var body: some View {
        let G = WorkbenchTokens.Guide.self
        Text(text)
            .font(G.labelFont)
            .foregroundStyle(WorkbenchTokens.V2.titleColor)
            .padding(G.labelPadding)
            .glass(Capsule(style: .continuous), tint: nil)
            .shadow(color: G.shadow, radius: 4, y: 1)
            .panelScheme()
            .fixedSize()
    }
}

/// The guides, the size of the island's display.
struct GuideLayer: View {
    let model: WorkbenchModel

    private struct Placed {
        var hold: CGPoint
        var ring: CGFloat
        var to: CGPoint?
        var ghost: CGRect?
        var label: String
        var labelAt: CGPoint
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            if let mark = model.guideMark, let g = placed(mark) {
                let accent = model.accent.color
                let G = WorkbenchTokens.Guide.self
                if let ghost = g.ghost {
                    RoundedRectangle(cornerRadius: G.ghostRadius, style: .continuous)
                        .strokeBorder(accent, style: StrokeStyle(lineWidth: G.ghostStroke, dash: G.ghostDash))
                        .background(RoundedRectangle(cornerRadius: G.ghostRadius, style: .continuous).fill(accent.opacity(0.08)))
                        .frame(width: ghost.width, height: ghost.height)
                        .position(x: ghost.midX, y: ghost.midY)
                }
                if let to = g.to {
                    GuideArrow(from: CGPoint(x: g.hold.x, y: g.hold.y + (to.y > g.hold.y ? g.ring / 2 : 0)), to: to)
                        .stroke(accent, style: StrokeStyle(lineWidth: G.arrowStroke, lineCap: .round, lineJoin: .round))
                        .shadow(color: G.shadow, radius: 3)
                }
                GuideRing(diameter: g.ring, color: accent)
                    .position(g.hold)
                GuideLabel(text: g.label)
                    .position(g.labelAt)
            }
        }
        .frame(width: model.display.frame.width, height: model.display.frame.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Where each guide goes, from the island as it is now; nil while what it points at isn't
    /// there (the session not open yet, the window being moved).
    private func placed(_ mark: IslandGuideMark) -> Placed? {
        let G = WorkbenchTokens.Guide.self
        let V = WorkbenchTokens.V2.self
        let width = model.display.frame.width
        let mid = width / 2
        let notch = NotchGeometry.notchRect(metrics: model.metrics, spec: WorkbenchTokens.Island.spec)
        switch mark {
        case .pullOut:
            guard model.notchState == .v2Chat, model.v2DragOut == nil else { return nil }
            let hold = CGPoint(x: mid, y: model.v2ChatLayout.outline.size.height - V.grabArea / 2)
            let to = CGPoint(x: mid, y: hold.y + G.pullDistance)
            let ghost = CGRect(x: mid - G.ghost.width / 2, y: to.y + 8, width: G.ghost.width, height: G.ghost.height)
            return Placed(hold: hold, ring: G.ring, to: to, ghost: ghost, label: L("Hold here, drag down"),
                          labelAt: CGPoint(x: mid + G.ring / 2 + G.labelGap + 70, y: hold.y))
        case .tuck:
            guard !model.v2DetachedMoving, let window = model.v2Detached.last(where: { $0.docked == nil }) else { return nil }
            let hold = CGPoint(x: window.origin.x + window.size.width / 2, y: window.origin.y + V2DetachedLayout.grip / 2)
            let left = hold.x < mid
            let to = CGPoint(x: left ? G.edgeInset : width - G.edgeInset, y: hold.y + 40)
            let ghost = CGRect(x: left ? 0 : width - G.tab.width, y: to.y - G.tab.height / 2, width: G.tab.width, height: G.tab.height)
            return Placed(hold: hold, ring: G.ring, to: to, ghost: ghost, label: L("Hold the top, drop it at the side"),
                          labelAt: CGPoint(x: hold.x, y: hold.y - G.ring / 2 - G.labelGap - 4))
        case .search:
            // The board up, the ring is on its search button (OpenChatSearchButton); till then, round
            // the notch, where the pointer opens it.
            guard model.notchState == .silent else { return nil }
            let hold = CGPoint(x: mid, y: notch.height / 2)
            return Placed(hold: hold, ring: notch.width + G.ringOutset, to: nil, ghost: nil, label: L("Move your pointer here"),
                          labelAt: CGPoint(x: mid, y: notch.height + G.labelGap + 12))
        }
    }
}

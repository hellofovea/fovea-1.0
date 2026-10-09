import SwiftUI
import OnboardingCore

/// How to drag Fovea into the list, shown rather than told (Oct 9: "more obvious"): a ghost of
/// the line in the notch lifts off, glides along an arc to the list's drop zone and fades there,
/// again every few seconds, until Fovea is dragged. The arc stays faintly drawn between glides.
struct DragHint: View {
    let model: OnboardingModel

    private var showing: Bool {
        guard let pane = model.settingsPane, model.alert == nil, model.tileDrag == nil, !model.dragTried else { return false }
        return !model.inList.contains(pane) && model.settingsListFrame != .zero
    }

    private var start: CGPoint {
        CGPoint(x: OT.Display.size.width / 2, y: OT.Display.notchHeight + OT.Island.dragCaptionHeight / 2)
    }

    private var end: CGPoint {
        let list = model.settingsListFrame
        return CGPoint(x: list.midX, y: list.maxY - OT.Layout.dropZoneHeight / 2 - 6)
    }

    /// The arc's control point: out level with the notch first, then down onto the list, so the
    /// path reads as carrying it across, not a slide.
    private var control: CGPoint {
        CGPoint(x: end.x, y: start.y + OT.DragHint.sag)
    }

    var body: some View {
        if showing {
            Group {
                if model.options.harness {
                    frame(at: OT.DragHint.lifted + OT.DragHint.glide * 0.6)
                } else {
                    TimelineView(.animation) { context in
                        frame(at: context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: OT.DragHint.loop))
                    }
                }
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private func frame(at t: Double) -> some View {
        let travel = min(1, max(0, (t - OT.DragHint.lifted) / OT.DragHint.glide))
        let eased = travel < 0.5 ? 2 * travel * travel : 1 - pow(-2 * travel + 2, 2) / 2
        let point = bezier(eased)
        let fadeIn = min(1, t / OT.DragHint.lifted)
        let fadeOut = 1 - min(1, max(0, (t - OT.DragHint.lifted - OT.DragHint.glide) / OT.DragHint.fade))
        return ZStack(alignment: .topLeading) {
            Path { path in
                path.move(to: start)
                path.addQuadCurve(to: end, control: control)
            }
            .stroke(model.accentColor.opacity(OT.DragHint.pathOpacity), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 7]))
            ZStack(alignment: .bottomTrailing) {
                TileView(dragging: true)
                Image(systemName: "cursorarrow")
                    .font(.system(size: OT.Layout.pointerSize))
                    .foregroundStyle(OT.Colors.ghostArrow)
                    .background(Image(systemName: "cursorarrow").font(.system(size: OT.Layout.pointerSize + 3)).foregroundStyle(OT.Colors.ghostArrowEdge))
                    .offset(x: 14, y: 18)
            }
            .scaleEffect(travel > 0 && travel < 1 ? 1.04 : 1)
            .opacity(OT.DragHint.ghostOpacity * fadeIn * fadeOut)
            .position(point)
        }
        .frame(width: OT.Display.size.width, height: OT.Display.size.height, alignment: .topLeading)
    }

    private func bezier(_ t: Double) -> CGPoint {
        let u = 1 - t
        return CGPoint(x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
                       y: u * u * start.y + 2 * u * t * control.y + t * t * end.y)
    }
}

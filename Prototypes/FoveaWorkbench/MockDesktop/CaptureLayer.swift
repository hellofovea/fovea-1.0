import SwiftUI
import AppKit

/// The mock screen's coordinate space: display points, origin top left.
enum ScreenSpace {
    static let name = "screen"
}

/// Capture mode on whatever the screen shows. A drag draws a region and captures it on
/// release; a click without a drag, the scroll wheel and the keyboard reach the page as
/// usual, so the pages keep scrolling and the tabs keep switching while capturing. The
/// gesture is simultaneous with the page's own and switched off outside capture mode.
struct CaptureSurface: ViewModifier {
    let model: WorkbenchModel

    func body(content: Content) -> some View {
        let T = WorkbenchTokens.Capture.self
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: T.dragThreshold, coordinateSpace: .named(ScreenSpace.name))
                    .onChanged { value in
                        guard model.capturing else { return }
                        model.selection = CGRect(from: value.startLocation, to: value.location)
                    }
                    .onEnded { value in
                        model.finishSelection(CGRect(from: value.startLocation, to: value.location))
                    },
                including: model.capturing ? .all : .subviews)
            // The highlighter (Option, feedback #8): a drag marks the words it crosses, a click a
            // whole passage or a file.
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(ScreenSpace.name))
                    .onChanged { value in model.highlightDrag(from: value.startLocation, to: value.location) }
                    .onEnded { value in model.finishHighlight(from: value.startLocation, to: value.location) },
                including: model.highlighting ? .all : .subviews)
            .screenCursor(capturing: model.capturing, highlighting: model.highlighting, accent: model.accent)
    }
}

extension View {
    /// The system's pointer for selecting a rectangle while capturing (a crosshair before
    /// macOS 15). Applied on the pages too, inside their scroll views, whose clip views keep
    /// their own cursor otherwise.
    @ViewBuilder
    func captureCursor(_ on: Bool) -> some View {
        if #available(macOS 15, *) {
            pointerStyle(on ? .rectSelection : nil)
        } else {
            onContinuousHover { phase in
                guard on else { return }
                switch phase {
                case .active: NSCursor.crosshair.set()
                case .ended: NSCursor.arrow.set()
                }
            }
        }
    }

    /// Gestures here handle the click that activates the window (macOS 15).
    @ViewBuilder
    func answersActivatingClick() -> some View {
        if #available(macOS 15, *) {
            allowsWindowActivationEvents(true)
        } else {
            self
        }
    }

    /// The pointing hand over a control drawn as a shape (the collapsed stack).
    @ViewBuilder
    func linkCursor() -> some View {
        if #available(macOS 15, *) {
            pointerStyle(.link)
        } else {
            onHover { inside in (inside ? NSCursor.pointingHand : NSCursor.arrow).set() }
        }
    }
}

extension CGRect {
    init(from a: CGPoint, to b: CGPoint) {
        self.init(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
}

/// Drawn over the screen, never hit: the region being drawn, captures flying into the
/// stack, and the demo's pointer.
struct CaptureOverlay: View {
    let model: WorkbenchModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            if let rect = model.selection {
                SelectionView(rect: rect)
            }
            // The highlighter's marks, in the accent color, and the one being drawn.
            HighlightMarks(model: model)
            // A passage taken in capture mode flashes as macOS selects text.
            if let rect = model.capturedFlash {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(WorkbenchTokens.AgentScreen.selection)
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
                    .transition(.opacity)
            }
            ForEach(model.flights) { flight in
                Image(nsImage: flight.image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .modifier(CardPlacement(vector: flight.landed ? flight.to : flight.from))
                    .animation(WorkbenchTokens.Capture.flight, value: flight.landed)
            }
            if let pointer = model.demoPointer {
                DemoPointerView(pointer: pointer)
            }
            AgentScreenOverlay(model: model)
            ForEach(model.agentRipples) { AgentRippleView(ripple: $0) }
            if let pointer = model.agentPointer {
                DemoPointerView(pointer: pointer)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The region being drawn, shaded as macOS shades a ⌘⇧4 selection: translucent gray with a
/// thin gray outline over the selected area only.
struct SelectionView: View {
    let rect: CGRect

    var body: some View {
        let T = WorkbenchTokens.Capture.self
        Rectangle()
            .fill(T.fill)
            .overlay(Rectangle().strokeBorder(T.stroke, lineWidth: T.strokeWidth))
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }
}

/// Where the demo's hand is: an arrow, or the selection crosshair while capturing.
struct DemoPointer: Equatable {
    /// The agent's pointer is the arrow inverted, white with a dark edge, so it never passes for
    /// the person's own.
    enum Style { case arrow, crosshair, agent }
    var location: CGPoint
    var style: Style
    var pressed = false
}

struct DemoPointerView: View {
    let pointer: DemoPointer

    var body: some View {
        let crosshair = pointer.style == .crosshair
        let agent = pointer.style == .agent
        Image(systemName: crosshair ? "plus" : "cursorarrow")
            .font(.system(size: crosshair ? 26 : 22, weight: crosshair ? .light : .regular))
            .foregroundStyle(crosshair || agent ? Color.white : Color.black)
            .shadow(color: crosshair || agent ? .black.opacity(0.8) : .white, radius: crosshair || agent ? 1 : 0.5)
            .scaleEffect(pointer.pressed ? 0.85 : 1)
            .frame(width: 30, height: 30)
            .offset(x: pointer.location.x - (crosshair ? 15 : 7), y: pointer.location.y - (crosshair ? 15 : 5))
    }
}

/// An empty view in the stage's base, handed to the model: its place in the window says where
/// the scaled display is, so a capture can read the right pixels.
struct StageProbe: NSViewRepresentable {
    let model: WorkbenchModel

    func makeNSView(context: Context) -> NSView {
        let view = PassthroughView()
        model.stageProbe = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        model.stageProbe = view
    }

    final class PassthroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

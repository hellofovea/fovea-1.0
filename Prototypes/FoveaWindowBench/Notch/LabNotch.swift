import AppKit
import SwiftUI
import WindowBenchCore

/// What the lab notch shows.
enum LabNotchMode: Equatable {
    case resting
    /// The hand-off's tip: "Start here" with the gesture.
    case tip
    /// The notch answering a hand-off: a ring that closes into a check (Family's island, R01-07).
    case ack
    /// A run's receipt card, dropped from the notch.
    case card(String)
}

@MainActor @Observable
final class LabNotchState {
    var mode: LabNotchMode = .resting
    /// The notch in the panel's top-down coordinates.
    var notch = CGRect(x: 0, y: 0, width: 200, height: 32)
    var panelWidth: CGFloat = 1470
    /// 0 → 1 drives the ring-to-check.
    var ack: CGFloat = 0
    /// The card fades as it leaves for the window (the flight carries it on).
    var cardOpacity: Double = 1
}

/// The bench's own island at the real notch (top center on a display without one): black on the
/// black notch at rest, so it disappears; it opens for the hand-off and for 带我去. Never takes key.
@MainActor
final class LabNotchController {
    let model: BenchModel
    let state = LabNotchState()
    private var panel: NotchPanel?
    private var overlay: FlightOverlay?

    init(model: BenchModel) {
        self.model = model
        observe()
    }

    // MARK: Panel

    private func ensurePanel() -> NotchPanel? {
        guard model.state.labNotch, let screen = NotchPlacement.screen else { return nil }
        let height: CGFloat = 460
        let frame = NSRect(x: screen.frame.minX, y: screen.frame.maxY - height, width: screen.frame.width, height: height)
        let notch = NotchPlacement.notchRect(on: screen)
        state.notch = CGRect(x: notch.minX - frame.minX, y: frame.maxY - notch.maxY, width: notch.width, height: notch.height)
        state.panelWidth = frame.width
        if let panel {
            panel.setFrame(frame, display: true)
            return panel
        }
        let panel = NotchPanel(frame: frame)
        let host = PassthroughHostingView(rootView: LabNotchView(state: state).environment(model))
        host.hitRegion = { [weak self] in self?.islandRect }
        panel.contentView = host
        self.panel = panel
        return panel
    }

    /// The island's current target rect in the panel (top-down), for hit testing.
    private var islandRect: CGRect? {
        let size = LabNotchView.size(for: state.mode, notch: state.notch)
        return CGRect(x: state.notch.midX - size.width / 2, y: 0, width: size.width, height: size.height)
    }

    /// Creates the notch panel and the flight overlay ahead of a recording, so their windows exist.
    func prepare() -> [CGWindowID] {
        var ids: [CGWindowID] = []
        if let panel = ensurePanel() { ids.append(CGWindowID(panel.windowNumber)) }
        if let screen = NotchPlacement.screen { ids.append(CGWindowID(ensureOverlay(on: screen).windowNumber)) }
        return ids.filter { $0 > 0 }
    }

    func show(_ mode: LabNotchMode) {
        guard let panel = ensurePanel() else { return }
        panel.orderFrontRegardless()
        withAnimation(model.motion.animation(mode == .resting ? .close : .open)) { state.mode = mode }
    }

    func hide() {
        withAnimation(model.motion.animation(.close)) { state.mode = .resting }
        Task { @MainActor in
            await model.motion.sleep(BenchTokens.MotionValues.close + 0.1)
            if state.mode == .resting { panel?.orderOut(nil) }
        }
    }

    /// Follows the model: the 带我去 card and the hand-off tip.
    private func observe() {
        withObservationTracking {
            _ = model.notchCard
            _ = model.handoffTip
            _ = model.state.labNotch
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if !self.model.state.labNotch {
                    self.hide()
                } else if let card = self.model.notchCard {
                    self.state.cardOpacity = 1
                    self.show(.card(card))
                } else if self.model.handoffTip {
                    self.show(.tip)
                    Task { @MainActor in
                        await self.model.motion.sleep(3.2)
                        if self.state.mode == .tip { self.model.handoffTip = false }
                    }
                } else if self.state.mode != .resting, self.state.mode != .ack {
                    self.hide()
                }
                self.observe()
            }
        }
    }

    // MARK: Hand-off: the glyph flies into the notch, which answers once

    func flyHandoff(window: NSWindow?) async {
        guard let window, let screen = NotchPlacement.screen, ensurePanel() != nil,
              let source = model.screenRect(of: "handoff-glyph", in: window) else { return }
        let notch = NotchPlacement.notchRect(on: screen)
        let target = CGRect(x: notch.midX - 4, y: notch.minY + notch.height / 2 - 4, width: 8, height: 8)
        model.handoffFlown = true
        // The ↑ itself flies (● means waiting; this cue isn't a state), shrinking into the notch.
        let arrow = AnyView(Image(systemName: "arrow.up")
            .font(.system(size: source.height * 0.8, weight: .semibold))
            .foregroundStyle(model.paletteForFlight.text)
            .frame(width: source.width, height: source.height))
        await flight(from: source, to: target, startRadius: source.height / 2, endRadius: 4, fill: .clear,
                     on: screen, content: arrow)
        panel?.orderFrontRegardless()
        withAnimation(model.motion.animation(.open)) { state.mode = .ack }
        state.ack = 0
        withAnimation(.easeOut(duration: model.motion.seconds(0.45)).delay(model.motion.seconds(0.12))) { state.ack = 1 }
        await model.motion.sleep(1.3)
        hide()
    }

    // MARK: 带我去 from the notch

    func takeMeThere(runID: String, window: NSWindow?) async {
        let style = model.v(ContinuityStyle.self)
        guard let window, let screen = NotchPlacement.screen else {
            model.notchCard = nil
            model.jump(toRun: runID)
            return
        }
        let canFly = window.isVisible && !window.isMiniaturized && window.screen == screen
            && !window.styleMask.contains(.fullScreen) && !model.motion.reduce
        let cardRect = self.cardScreenRect(on: screen)
        // The window comes forward and the run arrives in it (the notch's content entrance), so
        // the flight has somewhere to land and nothing swaps in one frame.
        window.orderFrontRegardless()
        if !model.options.noActivate { NSApp.activate(ignoringOtherApps: true) }
        // The Flight carries the receipt: the page's own stays hidden from its first frame.
        if style == .flight && canFly { model.receiptHidden = true }
        model.arrive(atRun: runID)
        await BenchSnapshots.settle(0.36)
        let target = model.screenRect(of: "receipt/\(runID)", in: window)
        switch (style, canFly, target) {
        case (.flight, true, let target?):
            // The card leaves the notch as a slab carrying it: the card's own content first,
            // then (once that has gone) the page's receipt at its landing size, so it lands as
            // exactly what the page draws there and the page takes over without a seam.
            let run = model.index.runByID[runID]
            let surface = model.v(ReceiptSurface.self)
            let windowPalette = model.paletteForFlight
            model.receiptHidden = true
            await flight(from: cardRect, to: target, startRadius: BenchTokens.Notch.slabRadius,
                         endRadius: surface == .system ? 10 : BenchTokens.Notch.slabRadius,
                         fill: BenchTokens.Notch.surface,
                         endFill: surface == .notch ? BenchTokens.Notch.surface
                             : (surface == .paper ? windowPalette.raised : Color(nsColor: .controlBackgroundColor)),
                         on: screen,
                         content: run.map { run in AnyView(ReceiptContent(run: run)
                            .padding(.horizontal, BenchTokens.Notch.paddingH + 4).padding(.top, state.notch.height + 6)
                            .environment(model).environment(\.palette, .notch).environment(\.colorScheme, .dark)) },
                         arrival: run.map { run in AnyView(RunReceipt(run: run, inFlight: true)
                            .environment(model).environment(\.palette, windowPalette).environment(\.motion, model.motion)
                            .environment(\.colorScheme, windowPalette.isDark ? .dark : .light)) },
                         departed: { [weak self] in
                            // The slab is on screen over the card: now the notch can close behind it.
                            guard let self else { return }
                            self.state.cardOpacity = 0
                            self.model.notchCard = nil
                            self.hide()
                         }) { [weak self] in
                self?.model.receiptHidden = false
            }
            model.flash("run-header/\(runID)")
        case (.neck, true, _):
            await neck(to: window, on: screen)
            model.notchCard = nil
            hide()
            model.flash("run-header/\(runID)")
        default:
            model.notchCard = nil
            hide()
            model.flash("run-header/\(runID)")
        }
    }

    /// The card's rect in screen coordinates, under the notch.
    private func cardScreenRect(on screen: NSScreen) -> CGRect {
        let size = LabNotchView.size(for: state.mode, notch: state.notch)
        let notch = NotchPlacement.notchRect(on: screen)
        return CGRect(x: notch.midX - size.width / 2, y: screen.frame.maxY - size.height, width: size.width, height: size.height)
    }

    // MARK: Flight

    private func ensureOverlay(on screen: NSScreen) -> FlightOverlay {
        if let overlay, overlay.frame == screen.frame { return overlay }
        let overlay = FlightOverlay(frame: screen.frame)
        self.overlay = overlay
        return overlay
    }

    /// A shape carried between two screen rects on the flight spring. It can carry what it left
    /// (`content`, at the start size) and what it becomes (`arrival`, at the end size), one out
    /// before the other comes in. `departed` runs once the shape is on screen (the source can
    /// go), `landed` once it's there (the destination shows under it), then the shape fades.
    func flight(from: CGRect, to: CGRect, startRadius: CGFloat, endRadius: CGFloat, fill: Color, endFill: Color? = nil,
                on screen: NSScreen, content: AnyView? = nil, arrival: AnyView? = nil,
                departed: (() -> Void)? = nil, landed: (() -> Void)? = nil) async {
        let overlay = ensureOverlay(on: screen)
        let local = { (r: CGRect) in CGRect(x: r.minX - screen.frame.minX, y: screen.frame.maxY - r.maxY, width: r.width, height: r.height) }
        let flight = FlightState(from: local(from), to: local(to), startRadius: startRadius, endRadius: endRadius,
                                 fill: fill, endFill: endFill ?? fill)
        flight.content = content
        flight.arrival = arrival
        overlay.present(flight)
        await BenchSnapshots.settle(0.05)
        departed?()
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            withAnimation(model.motion.animation(.flight), completionCriteria: .logicallyComplete) {
                flight.progress = 1
            } completion: { done.resume() }
        }
        landed?()
        await model.motion.sleep(BenchTokens.MotionValues.ghostFade)
        withAnimation(.easeOut(duration: model.motion.seconds(BenchTokens.MotionValues.ghostFade))) { flight.opacity = 0 }
        await model.motion.sleep(BenchTokens.MotionValues.ghostFade + 0.02)
        overlay.orderOut(nil)
    }

    /// FoveaLab's neck: a black band from the notch down to the window's top while it comes forward.
    private func neck(to window: NSWindow, on screen: NSScreen) async {
        let notch = NotchPlacement.notchRect(on: screen)
        let top = window.frame.maxY
        let band = CGRect(x: notch.minX, y: top, width: notch.width, height: max(0, notch.minY - top))
        await flight(from: CGRect(x: notch.minX, y: notch.minY, width: notch.width, height: 1), to: band,
                     startRadius: 0, endRadius: BenchTokens.Notch.compactBottom, fill: BenchTokens.Notch.surface, on: screen)
    }
}

@MainActor @Observable
final class FlightState {
    let from: CGRect
    let to: CGRect
    let startRadius: CGFloat
    let endRadius: CGFloat
    let fill: Color
    let endFill: Color
    var progress: CGFloat = 0
    var opacity: Double = 1
    /// What the shape leaves with (the card's content), drawn at the start size.
    var content: AnyView?
    /// What it lands as (the page's receipt), drawn at the end size.
    var arrival: AnyView?

    init(from: CGRect, to: CGRect, startRadius: CGFloat, endRadius: CGFloat, fill: Color, endFill: Color) {
        self.from = from; self.to = to; self.startRadius = startRadius; self.endRadius = endRadius
        self.fill = fill; self.endFill = endFill
    }
}

/// A transparent window over the whole notch display that only draws the flying shape; it never
/// takes a click, on every Space, above the menu bar and under the lab notch.
final class FlightOverlay: NSPanel {
    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = NSWindow.Level(rawValue: NotchPanel.islandLevel.rawValue - 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        animationBehavior = .none
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    @MainActor func present(_ flight: FlightState) {
        contentView = NSHostingView(rootView: FlightView(flight: flight).ignoresSafeArea())
        orderFrontRegardless()
    }
}

private struct FlightView: View {
    let flight: FlightState

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            FlyingShape(from: flight.from, to: flight.to, startRadius: flight.startRadius, endRadius: flight.endRadius,
                        fill: flight.fill, endFill: flight.endFill, content: flight.content, arrival: flight.arrival,
                        progress: flight.progress)
                .opacity(flight.opacity)
        }
    }
}

private struct FlyingShape: View, Animatable {
    let from: CGRect
    let to: CGRect
    let startRadius: CGFloat
    let endRadius: CGFloat
    let fill: Color
    let endFill: Color
    let content: AnyView?
    let arrival: AnyView?
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let p = progress
        let rect = CGRect(x: from.minX + (to.minX - from.minX) * p, y: from.minY + (to.minY - from.minY) * p,
                          width: from.width + (to.width - from.width) * p, height: from.height + (to.height - from.height) * p)
        let shape = RoundedRectangle(cornerRadius: startRadius + (endRadius - startRadius) * p, style: .continuous)
        ZStack(alignment: .topLeading) {
            shape.fill(endFill)
            shape.fill(fill).opacity(Double(1 - p))
            // What it left with, gone by 0.4; what it lands as, from 0.5 (the line swap's order).
            if let content {
                content
                    .frame(width: from.width, height: rect.height * from.width / max(1, rect.width), alignment: .topLeading)
                    .scaleEffect(rect.width / max(1, from.width), anchor: .topLeading)
                    // Handed over to what it lands as, if anything; else carried all the way.
                    .opacity(arrival == nil ? 1 : Double(max(0, 1 - p / 0.4)))
            }
            if let arrival {
                arrival
                    .frame(width: to.width, height: rect.height * to.width / max(1, rect.width), alignment: .topLeading)
                    .scaleEffect(rect.width / max(1, to.width), anchor: .topLeading)
                    .opacity(Double(max(0, (p - 0.5) / 0.5)))
            }
        }
        .frame(width: max(1, rect.width), height: max(1, rect.height), alignment: .topLeading)
        .clipShape(shape)
        .position(x: rect.midX, y: rect.midY)
    }
}

/// The lab notch's content: the island at its size for the mode, content a beat behind it.
struct LabNotchView: View {
    @Environment(BenchModel.self) private var model
    let state: LabNotchState

    static func size(for mode: LabNotchMode, notch: CGRect) -> CGSize {
        switch mode {
        case .resting: return CGSize(width: notch.width + BenchTokens.Notch.compactTop * 2, height: notch.height)
        case .tip: return CGSize(width: max(340, notch.width + 40), height: notch.height + 44)
        case .ack: return CGSize(width: notch.width + BenchTokens.Notch.compactTop * 2, height: notch.height + 44)
        case .card: return CGSize(width: BenchTokens.Notch.slabWidth, height: notch.height + 236)
        }
    }

    var body: some View {
        let size = Self.size(for: state.mode, notch: state.notch)
        let expanded: Bool = { if case .card = state.mode { return true } else { return false } }()
        let radii = expanded ? (BenchTokens.Notch.topRadius, BenchTokens.Notch.bottomRadius)
                             : (BenchTokens.Notch.compactTop, BenchTokens.Notch.compactBottom)
        ZStack(alignment: .top) {
            Color.clear
            VStack(spacing: 0) {
                Color.clear.frame(height: state.notch.height)
                content
                    .contentReveal(state.mode == .resting ? 0 : 1)
                    .animation(model.motion.animation(.content).delay(model.motion.contentDelay), value: state.mode)
                Spacer(minLength: 0)
            }
            .modifier(IslandOutline(width: size.width, height: size.height, topRadius: radii.0, bottomRadius: radii.1))
            .position(x: state.notch.midX, y: size.height / 2)
        }
        .environment(\.colorScheme, .dark)
        .environment(\.palette, .notch)
        .environment(\.motion, model.motion)
        .ignoresSafeArea()
    }

    @ViewBuilder private var content: some View {
        switch state.mode {
        case .resting:
            EmptyView()
        case .tip:
            HStack(spacing: 6) {
                Text("Start here.")
                    .foregroundStyle(BenchTokens.Notch.text)
                Text("\(model.v(GestureCopy.self).lead) fn ⌃ \(model.v(GestureCopy.self).short)")
                    .foregroundStyle(BenchTokens.Notch.secondary)
            }
            .font(.system(size: 12.5, weight: .medium))
            .frame(height: 44)
        case .ack:
            AckMark(progress: state.ack).frame(height: 44)
        case .card(let id):
            if let run = model.index.runByID[id] {
                VStack(alignment: .leading, spacing: 10) {
                    ReceiptContent(run: run)
                    HStack {
                        Spacer()
                        Button(model.verbs.takeMeThere) {
                            Task { await model.flightHandler(id) }
                        }
                        .buttonStyle(NotchSendStyle())
                    }
                }
                .padding(.horizontal, BenchTokens.Notch.paddingH + 4)
                .padding(.top, 6)
                .opacity(state.cardOpacity)
            }
        }
    }
}

/// The notch's white Send pill with black text.
struct NotchSendStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BenchTokens.Notch.pillFont)
            .foregroundStyle(Color.black)
            .padding(.horizontal, 12)
            .frame(height: 24)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.85 : 1)))
    }
}

/// A white ring that closes into a check.
private struct AckMark: View, Animatable {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        ZStack {
            Circle().trim(from: 0, to: min(1, progress * 1.6))
                .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            CheckPath()
                .trim(from: 0, to: max(0, (progress - 0.55) / 0.45))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .padding(6)
        }
        .frame(width: 22, height: 22)
    }
}

private struct CheckPath: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

// MARK: - Panels (copied from Prototypes/FoveaLab/Shared/NotchPanel.swift, key handling removed)

/// The transparent, always-on-top window the lab island draws in. Never key: it takes clicks
/// on its buttons only.
final class NotchPanel: NSPanel {
    static let islandLevel = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 8)

    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        animationBehavior = .none
        appearance = NSAppearance(named: .darkAqua)
        level = Self.islandLevel
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        setAccessibilityIdentifier("fovea.bench-notch")
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Hosting view that exists only where the island is drawn; everywhere else clicks fall through.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    var hitRegion: () -> CGRect? = { nil }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let region = hitRegion() else { return nil }
        let flipped = CGPoint(x: point.x, y: bounds.height - point.y)
        guard region.contains(flipped) else { return nil }
        return super.hitTest(point)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - Probes: where things are in the window, for flights

/// Reports a view's frame in the window (SwiftUI's global space: the content view, top-down).
struct Probe: ViewModifier {
    @Environment(BenchModel.self) private var model
    let key: String

    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
            model.probes[key] = frame
        }
    }
}

extension View {
    func probe(_ key: String) -> some View { modifier(Probe(key: key)) }
}

extension BenchModel {
    /// A probed view's rect in screen coordinates (AppKit, y up).
    func screenRect(of key: String, in window: NSWindow) -> CGRect? {
        guard let local = probes[key], let content = window.contentView else { return nil }
        // SwiftUI's global space is the hosting view's, top-down; the hosting view is flipped
        // too, so the rect converts as it is. (Flipping it here mirrored every flight.)
        let rect = content.isFlipped ? NSRect(x: local.minX, y: local.minY, width: local.width, height: local.height)
                                     : NSRect(x: local.minX, y: content.bounds.height - local.maxY, width: local.width, height: local.height)
        return window.convertToScreen(content.convert(rect, to: nil))
    }

    /// The palette the window is drawn with, for shapes that fly into it.
    var paletteForFlight: Palette {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return Palette.make(v(SurfaceVariant.self), dark: dark)
    }
}

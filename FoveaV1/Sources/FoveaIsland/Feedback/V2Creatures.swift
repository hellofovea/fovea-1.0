import SwiftUI
import AppKit
import FoveaCore

// The control board's pet (Oct 8, docs/island/CREATURES.md): Fovea's Lasso with two eyes, the same
// pet in every design with pets (V2PetBoards.swift: List, Capsules, Desk, Lanes, at rest beside the
// notch; and here, Wings). It is the session's state glyph: its loop drawn as far as its agent has
// got through its plan, whole and amber when it waits on the person, coral when it failed, dashed
// and asleep when its state can't be read. Simple shapes read as agents when they move (Heider and
// Simmel), and motion onsets, not loops, catch the eye: at rest they barely move; each real event is
// one short gesture; the one waiting on the person calls once and holds still. The pen at the
// loop's tip is its agent, in that agent's own working glyph: Claude Code's spinner (✢ ✳ ✶ ✻ ✽),
// Codex's bullet.

// MARK: Poses

/// What a creature is doing: from its session's state and, at work, the step it is on.
enum CreaturePose: Equatable {
    case reading, searching, typing, running, thinking
    case needsYou, done, failed, stopped, asleep
    /// At ease: beside an answer it gave earlier in the session.
    case idle

    var working: Bool { [.reading, .searching, .typing, .running, .thinking].contains(self) }

    @MainActor
    static func of(_ task: AgentTaskItem, model: WorkbenchModel) -> CreaturePose {
        if task.statusUnknown { return .asleep }
        switch task.state {
        case .needsYou: return .needsYou
        case .complete: return task.stopped ? .stopped : .done
        case .failed: return task.stopped ? .stopped : .failed
        case .working:
            switch model.v2LiveStep(task)?.step.kind ?? .think {
            case .read, .fetch, .list, .tool: return .reading
            case .search, .web, .subagent: return .searching
            case .edit, .create, .answer: return .typing
            case .run, .build, .test: return .running
            case .plan, .think: return .thinking
            }
        }
    }
}

/// Small differences between pets, the same every time for a session: its size, its timing, the
/// waver of its hand-drawn loop.
struct CreatureTraits: Equatable {
    var scale: CGFloat = 1
    var phase: Double = 0
    /// Its own blink: every 2.6–5.3 s, the odd one doubled.
    var blinkEvery: Double = 3.7

    init(seed: String) {
        let h = seed.unicodeScalars.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1.value)) &* 1099511628211 }
        scale = 0.94 + CGFloat(h % 13) / 100
        phase = Double((h >> 8) % 1000) / 1000 * 3
        blinkEvery = 2.6 + Double((h >> 24) % 28) / 10
    }
}

// MARK: The creature

/// How full a creature is: at work, how far through the plan its agent reported (Codex's
/// update_plan, Claude's TodoWrite); nil when it reported none, and it shows only a little, never a
/// made-up progress.
@MainActor
func creatureProgress(_ task: AgentTaskItem) -> CGFloat? {
    guard !task.plan.isEmpty else { return nil }
    return min(1, CGFloat(task.planDone) / CGFloat(task.plan.count))
}

/// The pet: the Lasso, alive (docs/island/CREATURES.md). Fovea's own mark, the hand-drawn circle it
/// works under (Thinking's Lasso: a little uneven, overlapping where it closes, each loop its own),
/// with two eyes inside. The loop is drawn as far as the work has gone: a faint whole loop is its
/// body, the bright stroke over it how far the agent has got through the plan it reported, the pen
/// at its tip (Claude Code's spinner glyph, Codex's bullet) and the eyes on the pen. Done, the loop
/// closes. Waiting on the person, it is whole and amber, a little larger, and looks at them.
/// Failed, the stroke stops in coral where it got to, and the face goes (the persona drops). Asleep
/// when its state can't be read: a dashed loop, eyes closed. `size`: the loop's height.
///
/// Calm by default (the psychology in CREATURES.md): at rest a breath of a point or so, one rhythm
/// for all; each real event a single gesture of half a second (a new step: the pen circles once
/// where it is; progress: the stroke draws on; waiting: one call; the board opening: a small hop).
/// Still in snapshots and with Reduce Motion.
struct AgentCreature: View {
    let pose: CreaturePose
    let agent: String
    let size: CGFloat
    var traits = CreatureTraits(seed: "")
    var progress: CGFloat? = nil
    /// Waiting on the person: where it looks, -1…1 on each axis.
    var look: CGVector? = nil
    /// The board opening: a small hop.
    var notice: Date? = nil
    /// When its current step began: the pen circles once.
    var beat: Date? = nil
    /// When it began waiting on the person (or the board opened on it): its one call.
    var onset: Date? = nil
    var still = false
    /// Beside the notch at rest (PRD §8's breathing point): its agent's spinner holds still.
    var calm = false
    /// Drawn at this moment of its motion instead of now, its step and call begun at 0 (the
    /// contact sheets).
    var clock: Double? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Oct 21, perf: its band is showing (MockIsland's `BandShown`); its clock pauses when not.
    @Environment(\.islandBandShown) private var bandShown
    /// The stroke drawing on: from where it was to where it is going, since when.
    @State private var arcFrom: Double?
    @State private var arcSince = Date.distantPast

    var body: some View {
        let C = WorkbenchTokens.Creatures.self
        let frozen = still || reduceMotion
        let target = arc
        Group {
            if let clock {
                figure(t: clock + traits.phase, arc: target, notice: .infinity, beat: clock, onset: clock)
            } else {
                TimelineView(.animation(minimumInterval: 1 / C.frameRate, paused: frozen || !bandShown)) { context in
                    let now = context.date
                    let since = { (date: Date?) in frozen ? .infinity : date.map { now.timeIntervalSince($0) } ?? .infinity }
                    // The stroke draws on to where the work has got, eased.
                    let k = frozen ? 1 : min(1, now.timeIntervalSince(arcSince) / C.drawOn)
                    let shown = arcFrom.map { $0 + (target - $0) * (1 - pow(1 - k, 3)) } ?? target
                    figure(t: frozen ? 0.62 + traits.phase : now.timeIntervalSinceReferenceDate + traits.phase,
                           arc: shown, notice: since(notice), beat: since(beat), onset: since(onset))
                }
            }
        }
        .frame(width: size * C.frameWidth, height: size * C.frameHeight)
        .onChange(of: target) { old, _ in
            arcFrom = old
            arcSince = Date()
        }
        .accessibilityElement()
        .accessibilityLabel(Self.words(pose))
    }

    /// What it is doing, for VoiceOver and the help text.
    static func words(_ pose: CreaturePose) -> String {
        switch pose {
        case .reading: return "Reading"
        case .searching: return "Searching"
        case .typing: return "Writing"
        case .running: return "Running a command"
        case .thinking: return "Thinking"
        case .needsYou: return "Needs you"
        case .done: return "Done"
        case .failed: return "Failed"
        case .stopped: return "Stopped"
        case .asleep: return "Status unavailable"
        case .idle: return "Answered"
        }
    }

    /// How far the loop is drawn (of its 1.12 turns): at work, a little to start and its plan's
    /// share after; whole once done, waiting on the person, or asleep; failed and stopped, as far
    /// as it got.
    private var arc: Double {
        let C = WorkbenchTokens.Creatures.self
        let worked = progress.map { C.arcStart + (1 - C.arcStart) * Double($0) * C.arcWorking }
        switch pose {
        case .needsYou, .done, .idle, .asleep: return 1
        case .failed, .stopped: return worked ?? C.arcUnknown
        default: return worked ?? C.arcStart
        }
    }

    private var tint: Color {
        let C = WorkbenchTokens.Creatures.self
        switch pose {
        case .needsYou: return WorkbenchTokens.Panel.needsYouColor
        case .failed: return WorkbenchTokens.Panel.failedColor
        case .asleep: return C.bodyAsleep
        case .stopped: return C.bodyStopped
        default: return C.body
        }
    }

    /// `notice`, `beat`, `onset`: seconds since each (infinity: not playing).
    private func figure(t: Double, arc: Double, notice: Double, beat: Double, onset: Double) -> some View {
        let C = WorkbenchTokens.Creatures.self
        let L = WorkbenchTokens.Lasso.self
        let s = size * traits.scale
        let p = 2 * Double.pi
        // At rest: one breath for every pet (no moving among moving).
        let shared = t - traits.phase
        var grow = CGFloat(1 + C.breathDepth * sin(p * shared / C.breath))
        var dy: CGFloat = 0
        // Its call, waiting on the person: a wind-up, rising larger, then held there, still.
        if pose == .needsYou {
            let k = onset / C.callLength
            if k >= 0 && k < 1 {
                grow *= k < 0.2 ? CGFloat(1 - 0.06 * k / 0.2) : 1 + (C.callScale - 1) * CGFloat(min(1, (k - 0.2) / 0.8 * 1.6))
                dy = k < 0.2 ? 0 : -s * 0.16 * CGFloat(sin(Double.pi * (k - 0.2) / 0.8))
            } else {
                grow *= C.callScale
            }
        }
        // The board opening: a small hop each.
        if notice >= 0 && notice < C.noticeLength { dy -= s * 0.16 * CGFloat(sin(Double.pi * notice / C.noticeLength)) }
        // A new step: the pen circles once where it is.
        let g = pose.working && beat >= 0 && beat < C.gesture ? beat / C.gesture : nil
        // Blinks: each its own rhythm, about one in five doubled.
        let cycle = t / traits.blinkEvery
        let into = (cycle - cycle.rounded(.down)) * traits.blinkEvery
        let blinking = [.reading, .searching, .typing, .running, .needsYou, .done, .idle].contains(pose)
            && (into < C.blinkLength || (Int(cycle.rounded(.down)) % 5 == 2 && into > 2.2 * C.blinkLength && into < 3.2 * C.blinkLength))
        let seed = traits.phase * 2.1
        let spinner = ["·", "✢", "✳", "✶", "✻", "✽", "✻", "✶", "✳", "✢"]
        let glyph = pose.working && !calm ? spinner[Int(t / C.spinnerFrame) % spinner.count] : "✻"
        let pose = self.pose, agent = self.agent, tint = self.tint, look = self.look
        return Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2 + s * 0.04)
            let radii = CGSize(width: s * C.loopWide, height: s * 0.5)
            let start = -Double.pi / 2 - 0.5
            let line = max(1.2, s * C.lineRatio)
            func point(_ at: Double) -> CGPoint {
                LassoRenderer.loopPoint(center: c, radii: radii, start: start, turns: L.turns, seed: seed, at: at)
            }
            // Its body: the whole loop, faint; asleep, dashed.
            let whole = LassoRenderer.loopPath(center: c, radii: radii, start: start, turns: L.turns, from: 0, to: 1, seed: seed)
            if pose == .asleep {
                ctx.stroke(whole, with: .color(tint), style: StrokeStyle(lineWidth: line, lineCap: .round, dash: [s * 0.07, s * 0.12]))
            } else {
                ctx.stroke(whole, with: .color(tint.opacity(C.trackOpacity)), style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
                // How far it has got, bright over it.
                let drawn = LassoRenderer.loopPath(center: c, radii: radii, start: start, turns: L.turns, from: 0, to: arc, seed: seed)
                ctx.stroke(drawn, with: .color(tint), style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
            }
            // The pen, where the loop has got to, while it works (and where it stopped).
            var pen = point(arc)
            if let g {
                // Circling once where it is.
                let r = s * 0.07
                pen.x += CGFloat(cos(p * g - .pi / 2)) * r
                pen.y += CGFloat(sin(p * g - .pi / 2)) * r + r
            }
            if pose.working || pose == .failed || pose == .stopped {
                if agent == "claude-code" && pose.working {
                    ctx.draw(Text(glyph).font(.system(size: s * 0.36, weight: .bold)).foregroundColor(tint), at: pen)
                } else {
                    let d = s * C.penSize
                    ctx.fill(Path(ellipseIn: CGRect(x: pen.x - d / 2, y: pen.y - d / 2, width: d, height: d)), with: .color(tint))
                }
            }
            // The eyes: on the pen while it works, on the person while it waits, ahead otherwise;
            // none once it failed.
            guard pose != .failed else { return }
            var gaze = CGVector(dx: 0, dy: 0.2)
            if pose.working && pose != .thinking {
                let dx = pen.x - c.x, dyy = pen.y - c.y, d = max(1, hypot(dx, dyy))
                gaze = CGVector(dx: dx / d, dy: dyy / d)
            }
            if pose == .needsYou { gaze = look ?? CGVector(dx: 0, dy: -0.6) }
            let closed = pose == .asleep || pose == .stopped || pose == .thinking || blinking
            let w = s * C.eyeWidth * (closed ? 1.5 : 1)
            let h = closed ? max(1, s * 0.035) : s * (pose == .needsYou ? C.eyeHeight * 1.18 : C.eyeHeight)
            for side in [-1.0, 1.0] {
                let x = c.x + CGFloat(side) * s * C.eyeGap / 2 + CGFloat(gaze.dx) * s * 0.08
                let y = c.y - s * 0.02 + CGFloat(gaze.dy) * s * 0.06
                ctx.fill(Path(roundedRect: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h), cornerRadius: min(w, h) / 2),
                         with: .color(pose == .asleep ? C.zColor : C.eyeOnDark))
            }
            if pose == .asleep {
                ctx.draw(Text("z").font(.system(size: s * 0.34, weight: .semibold)).foregroundColor(C.zColor),
                         at: CGPoint(x: c.x + radii.width * 1.05, y: c.y - radii.height * 1.05))
            }
        }
        .scaleEffect(grow, anchor: .bottom)
        .offset(y: dy)
    }
}

// MARK: The board

/// Where each creature stands. The person's turn in the left wing (waiting on them, then done), the
/// rest in the right (running, then those whose state can't be read, asleep and huddled together),
/// the most pressing nearest the notch; a little more room between kinds. A full wing draws its
/// creatures closer, down to a huddle; never a count.
struct CreatureSlots: Equatable {
    struct Place: Equatable {
        let task: AgentTaskItem
        let point: CGPoint
        /// -1: the left wing, the person's turn; 1: the right, at work.
        let side: CGFloat
    }
    var places: [Place] = []

    /// Left to right, as the arrows walk them.
    var visualOrder: [String] { places.sorted { $0.point.x < $1.point.x }.map(\.task.id) }

    @MainActor
    static func make(model: WorkbenchModel, width: CGFloat, notch: CGRect) -> CreatureSlots {
        let C = WorkbenchTokens.Creatures.self
        let sections = model.v2BoardSections
        func groups(_ kinds: [BoardSection]) -> [(kind: BoardSection, tasks: [AgentTaskItem])] {
            kinds.compactMap { kind in sections.first { $0.section == kind }.map { (kind, $0.tasks) } }.filter { !$0.tasks.isEmpty }
        }
        let ear = WorkbenchTokens.Island.spec.expandedTopRadius
        let body = C.size * C.footprint
        let first = notch.width / 2 + C.wingInset + body / 2
        let last = width / 2 - ear - body * 0.6
        // Standing on the band's foot: the loop's foot just over half its height below the frame's middle.
        let y = notch.height - C.footLift - C.size * 0.56
        var out = CreatureSlots()
        for (side, wing) in [(CGFloat(-1), groups([.needsYou, .done])), (CGFloat(1), groups([.running, .unknown]))] {
            // Each creature's distance from the first, at a spacing; the asleep always huddle.
            func walk(_ pitch: CGFloat) -> [CGFloat] {
                var xs: [CGFloat] = [], x: CGFloat = 0
                for (g, group) in wing.enumerated() {
                    let step = group.kind == .unknown ? C.huddle : pitch
                    for i in group.tasks.indices {
                        if !xs.isEmpty { x += i == 0 && g > 0 ? C.groupGap + step : step }
                        xs.append(x)
                    }
                }
                return xs
            }
            var pitch = C.pitch
            while pitch > C.huddle, (walk(pitch).last ?? 0) > last - first { pitch -= 1 }
            let xs = walk(pitch)
            for (task, x) in zip(wing.flatMap(\.tasks), xs) {
                out.places.append(Place(task: task, point: CGPoint(x: width / 2 + side * (first + x), y: y), side: side))
            }
        }
        return out
    }
}

/// Pets · Wings (round one): the sessions' pets in the notch's wings, each in its pose; the one
/// under the pointer (or in focus) on the stage below, larger, with what it asks or brought back
/// and its big buttons. Opening, each looks up at the person; one that finishes hops over to the
/// person's side; a new one comes out of the notch, and one that has been read goes back into it.
struct V2CreatureBoard: View {
    let model: WorkbenchModel
    let layout: V2BoardLayout

    var body: some View {
        let C = WorkbenchTokens.Creatures.self
        let BV = WorkbenchTokens.BoardV.self
        let spec = WorkbenchTokens.Island.spec
        let notch = NotchGeometry.notchRect(metrics: model.metrics, spec: spec)
        let width = layout.outline.size.width
        let slots = CreatureSlots.make(model: model, width: width, notch: notch)
        let selected = model.v2BoardSelected
        ZStack(alignment: .topLeading) {
            Color.clear
            // The pets stand on the island's band: dark on Original's black and on the black band of a
            // full-screen app, the display's on Native's glass.
            ForEach(Array(slots.places.enumerated()), id: \.element.task.id) { i, place in
                CreatureToken(model: model, place: place, band: notch.height, selected: selected?.id == place.task.id, order: i)
                    .position(place.point)
                    .transition(.creatureHome(dx: width / 2 - place.point.x, dy: -place.point.y / 2))
                    .panelScheme(onBlack: model.screenContent.fullScreen)
            }
            if let selected {
                V2SessionCard(model: model, task: selected, bodyHeight: layout.cardBody, lines: 3, creature: true)
                    .frame(width: V2SessionCard.contentWidth(panel: width, margin: BV.stageMargin), alignment: .topLeading)
                    .offset(x: spec.expandedTopRadius + BV.stageMargin, y: V2Geometry.top(model.metrics))
                    .id(selected.id)
                    .transition(.opacity)
            }
        }
        .frame(width: layout.outline.size.width, height: layout.outline.size.height, alignment: .topLeading)
        .animation(model.snapshotMode ? nil : C.move, value: slots.places.map { "\($0.task.id)@\(Int($0.point.x))" })
        .animation(model.snapshotMode ? nil : .easeOut(duration: 0.12), value: selected?.id)
    }
}

/// A creature in a wing: it grows under the pointer (and its neighbours a little); near the
/// pointer it looks at it, and one waiting on the person always does; in focus, it stands in a
/// small pool of light. Hovered, it is on the stage; clicked, its session opens.
struct CreatureToken: View {
    let model: WorkbenchModel
    let place: CreatureSlots.Place
    let band: CGFloat
    let selected: Bool
    let order: Int
    /// Counts the failures it has had here, for one shake of the head each.
    @State private var shakes = 0
    /// When its current step began, and when it began waiting on the person: its gesture, its call.
    @State private var beatAt: Date?
    @State private var waitingAt: Date?

    var body: some View {
        let C = WorkbenchTokens.Creatures.self
        let task = place.task
        let pose = CreaturePose.of(task, model: model)
        let pointer = model.v2BoardPointer
        let over = pointer.map { $0.y < band + 8 ? max(0, 1 - abs($0.x - place.point.x) / C.magnifyReach) : 0 } ?? 0
        // Only the one waiting on the person looks at them; the others keep their eyes on their work.
        let look: CGVector? = pose == .needsYou ? pointer.map { p in
            let dx = p.x - place.point.x, dy = p.y - place.point.y
            let d = max(1, hypot(dx, dy))
            return CGVector(dx: dx / d, dy: dy / d)
        } : nil
        // It calls when it begins to wait, and again when the board opens on it.
        let onset = pose == .needsYou ? max(waitingAt ?? .distantPast, model.panelOpened) : nil
        AgentCreature(pose: pose, agent: task.agent, size: C.size, traits: CreatureTraits(seed: task.id),
                      progress: creatureProgress(task), look: look,
                      notice: model.panelOpened.addingTimeInterval(Double(order) * C.noticeStagger),
                      beat: beatAt, onset: onset,
                      still: model.snapshotMode || model.notchState != .v2Board)
            .onChange(of: model.v2LiveStep(task)?.index) { _, _ in beatAt = Date() }
            .onChange(of: pose == .needsYou) { _, waiting in if waiting { waitingAt = Date() } }
            .scaleEffect(1 + C.magnify * over, anchor: .bottom)
            .animation(C.lift, value: over)
            .background(alignment: .bottom) {
                Ellipse().fill(WorkbenchTokens.ink(selected ? 0.2 : 0))
                    .frame(width: C.size * C.footprint * 1.1, height: C.size * 0.24)
                    .offset(y: -C.size * 0.0)
            }
            .keyframeAnimator(initialValue: CGFloat(0), trigger: place.side) { content, lift in
                content.offset(y: lift)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(-C.hopHeight, duration: C.hopDuration * 0.45)
                    CubicKeyframe(0, duration: C.hopDuration * 0.55)
                }
            }
            .keyframeAnimator(initialValue: CGFloat(0), trigger: shakes) { content, x in
                content.offset(x: x)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(-C.shake, duration: C.shakeDuration * 0.2)
                    LinearKeyframe(C.shake, duration: C.shakeDuration * 0.3)
                    LinearKeyframe(-C.shake * 0.5, duration: C.shakeDuration * 0.25)
                    LinearKeyframe(0, duration: C.shakeDuration * 0.25)
                }
            }
            .onChange(of: pose == .failed) { _, failed in if failed && !model.snapshotMode { shakes += 1 } }
            .contentShape(Rectangle())
            .onHover { model.hoverV2(task.id, $0) }
            .onTapGesture { model.openV2(task.id) }
            .help("\(model.v2Title(task)) · \(AgentCreature.words(pose))")
            .accessibilityElement()
            .accessibilityLabel("\(model.v2Title(task)), \(AgentCreature.words(pose))")
            .accessibilityAddTraits(.isButton)
    }
}

extension AnyTransition {
    /// Coming out of the notch (a new session), and going back into it (read, it leaves the board).
    static func creatureHome(dx: CGFloat, dy: CGFloat) -> AnyTransition {
        .modifier(active: CreatureHome(dx: dx, dy: dy, k: 0), identity: CreatureHome(dx: dx, dy: dy, k: 1))
    }
}

private struct CreatureHome: ViewModifier {
    let dx: CGFloat
    let dy: CGFloat
    let k: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(0.3 + 0.7 * k)
            .offset(x: dx * (1 - k), y: dy * (1 - k))
            .opacity(Double(k))
    }
}

// MARK: Contact sheet

/// `--render-creatures=<dir>`: every pose over a few moments of its motion, at the stage's size and
/// the wing's, for reading the motion from a still (docs/island/CREATURES.md).
struct CreatureSheet: View {
    var body: some View {
        let C = WorkbenchTokens.Creatures.self
        let rows: [(String, CreaturePose, CGFloat?, String)] = [
            ("Reading, a quarter through", .reading, 0.25, "claude-code"),
            ("Searching", .searching, nil, "codex"),
            ("Writing, half through", .typing, 0.5, "claude-code"),
            ("Running the tests, nearly done", .running, 0.85, "codex"),
            ("Thinking", .thinking, nil, "claude-code"),
            ("Needs you", .needsYou, nil, "claude-code"),
            ("Done", .done, nil, "codex"),
            ("Failed", .failed, 0.6, "claude-code"),
            ("Stopped", .stopped, 0.4, "codex"),
            ("Status unavailable", .asleep, nil, "claude-code"),
        ]
        let times: [Double] = [0, 0.15, 0.3, 0.45, 0.6, 0.9, 1.2, 1.8]
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    Text(row.0).font(.system(size: 12)).foregroundStyle(Color.white.opacity(0.6))
                        .frame(width: 190, alignment: .leading)
                    ForEach(Array(times.enumerated()), id: \.offset) { _, t in
                        AgentCreature(pose: row.1, agent: row.3, size: 28, progress: row.2, clock: t)
                    }
                    AgentCreature(pose: row.1, agent: row.3, size: C.size, progress: row.2, clock: 0.6)
                        .padding(.leading, 18)
                }
            }
        }
        .padding(24)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
    }
}

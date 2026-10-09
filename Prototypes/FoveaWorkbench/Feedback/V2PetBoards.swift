import SwiftUI
import AppKit
import FoveaCore

// The same pet in the board's designs (Oct 8, docs/island/CREATURES.md). Wings put the pets alone
// in the notch's wings, and the person had to point at each to learn whose it was and what it did.
// Here every design shows every session at once, its agent and what it is doing written beside its
// pet, so nothing needs a hover:
// - List: the board's rows, each led by its pet; the agent's icon by the title.
// - Capsules: each session its own small island under the notch, its pet at the front.
// - Desk: the sessions as a team, four to a row, each pet at its desk with its name under it.
// - Lanes: a lane each, its pet along a track as far as its plan has got, the end its finish.
// - At rest: beside the notch, the pet of the session most in need, in a small black circle.
// One pet: the Lasso, alive (V2Creatures.swift), the same in each, drawn as far as its work has got.

// MARK: The pet of a session

/// A session's pet, alive while it is shown: a gesture at each new step, its one call when it
/// begins waiting on the person (or the board opens on it), a small hop as the board opens, a shake
/// when it fails.
struct PetFor: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let size: CGFloat
    /// Moving while this is on screen; nil: while the board is open.
    var live: Bool? = nil
    /// Its turn in the board's opening hops; nil: its place on the board.
    var order: Int? = nil
    /// Its agent's spinner held still (at rest beside the notch).
    var calm = false
    @State private var beatAt: Date?
    @State private var waitingAt: Date?
    @State private var shakes = 0

    var body: some View {
        let C = WorkbenchTokens.Creatures.self
        let pose = CreaturePose.of(task, model: model)
        let shown = live ?? (model.notchState == .v2Board)
        let turn = order ?? model.v2BoardOrder.firstIndex { $0.id == task.id } ?? 0
        let onset = pose == .needsYou ? max(waitingAt ?? .distantPast, model.panelOpened) : nil
        AgentCreature(pose: pose, agent: task.agent, size: size, traits: CreatureTraits(seed: task.id),
                      progress: creatureProgress(task),
                      notice: model.panelOpened.addingTimeInterval(Double(turn) * C.noticeStagger),
                      beat: beatAt, onset: onset, still: model.snapshotMode || !shown, calm: calm)
            .onChange(of: model.v2LiveStep(task)?.index) { _, _ in beatAt = Date() }
            .onChange(of: pose == .needsYou) { _, waiting in if waiting { waitingAt = Date() } }
            .onChange(of: pose == .failed) { _, failed in if failed && !model.snapshotMode { shakes += 1 } }
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
            .help(AgentCreature.words(pose))
    }
}

/// A session's title, after its agent's icon where the pet has taken the icon's place: whose it
/// is, without a hover.
struct AgentTitle: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let font: Font
    let color: Color
    var icon = false
    var iconSize: CGFloat = WorkbenchTokens.Pets.listAgentIcon

    var body: some View {
        let B = WorkbenchTokens.Board.self
        HStack(spacing: WorkbenchTokens.Pets.agentGap) {
            if icon {
                ChatAgentIcon(agent: ChatAgent.named(task.agent), size: iconSize)
                    .saturation(task.statusUnknown ? B.dimSaturation : 1)
                    .opacity(task.statusUnknown ? B.dimOpacity : 1)
                    .accessibilityHidden(true)
            }
            Text(model.v2Title(task)).font(font).foregroundStyle(color).lineLimit(1)
        }
    }
}

extension WorkbenchModel {
    /// The pet at rest beside the notch: the session most in need, in Codex Pets' order (waiting
    /// on the person, failed, done, running); none whose state can't be read.
    var v2RestPet: AgentTaskItem? { v2BoardOrder.first { !$0.statusUnknown } }

    /// The pet at rest is shown: a design with pets, the island at rest, something on the board.
    var petAtRestShown: Bool {
        petAtRest && boardStyle.hasPets && notchState == .silent && v2RestPet != nil && !hidingOwnSurfaces
    }

    /// The circle the pet at rest sits in, on the display: beside the notch, at its right.
    var petAtRestRect: CGRect {
        let PT = WorkbenchTokens.Pets.self
        let notch = NotchGeometry.notchRect(metrics: metrics, spec: WorkbenchTokens.Island.spec)
        let d = notch.height - 2 * PT.restInset
        return CGRect(x: display.frame.width / 2 + notch.width / 2 + PT.restGap, y: PT.restInset, width: d, height: d)
    }
}

// MARK: Shared

/// A scroll of the board's sessions, or (drawn off screen, where a scroll view can't be) the same
/// content cut to the room.
private struct PetScroll<Content: View>: View {
    let model: WorkbenchModel
    let layout: V2BoardLayout
    let width: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        if model.offscreenRender {
            content().frame(width: width, height: layout.listHeight, alignment: .top).clipped()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 0).id(V2BoardList.topID)
                        content()
                    }
                }
                    .scrollDisabled(!layout.scrolls)
                    .scrollIndicators(layout.scrolls ? .automatic : .never)
                    .onChange(of: model.v2ScrollTarget) { _, id in if let id { proxy.scrollTo(id) } }
            }
            .frame(width: width, height: layout.listHeight)
        }
    }
}

/// What a session's quieter line says: the question (amber), why it failed, the answer's first
/// sentence, or when it was last active.
@MainActor
private func petLine(_ model: WorkbenchModel, _ task: AgentTaskItem, size: CGFloat) -> Text {
    let B = WorkbenchTokens.Board.self
    if task.statusUnknown {
        return Text("last active \(AgentBoard.duration(task.age) ?? "now") ago").font(.system(size: size)).foregroundColor(B.time)
    }
    switch task.state {
    case .needsYou:
        return boardAsk(task, size: size, weight: .regular, color: WorkbenchTokens.Panel.needsYouColor)
    case .failed:
        let word = BoardStateWord.text(task)
        return Text(word.0).font(.system(size: size, weight: .medium)).foregroundColor(word.1)
            + Text(" · \(model.v2BoardLine(task))").font(.system(size: size)).foregroundColor(B.line)
    case .working, .complete:
        return Text(model.v2BoardLine(task)).font(.system(size: size)).foregroundColor(B.line)
    }
}

// MARK: Desk

/// The sessions as a team, four to a row in the board's order: each pet at its desk, its agent's
/// icon in the desk's corner and how long at the other, its name under it, then what it is doing,
/// what it asks (Allow and Deny in place), or what it brought back. One waiting on the person is
/// outlined in amber. A click opens one.
struct V2PetDesk: View {
    let model: WorkbenchModel
    let layout: V2BoardLayout

    static var contentX: CGFloat { WorkbenchTokens.Island.spec.expandedTopRadius + WorkbenchTokens.Pets.deskMargin }
    static var contentWidth: CGFloat { WorkbenchTokens.Pets.deskWidth - 2 * contentX }
    static var cellWidth: CGFloat {
        let PT = WorkbenchTokens.Pets.self
        return (contentWidth - CGFloat(PT.deskColumns - 1) * PT.deskGap) / CGFloat(PT.deskColumns)
    }

    var body: some View {
        let PT = WorkbenchTokens.Pets.self
        let order = model.v2BoardOrder
        let rows = (order.count + PT.deskColumns - 1) / PT.deskColumns
        let height = CGFloat(rows) * PT.deskCell + CGFloat(max(0, rows - 1)) * PT.deskGap
        ZStack(alignment: .topLeading) {
            Color.clear
            PetScroll(model: model, layout: layout, width: Self.contentWidth) {
                ZStack(alignment: .topLeading) {
                    Color.clear.frame(width: Self.contentWidth, height: height)
                    ForEach(Array(order.enumerated()), id: \.element.id) { i, task in
                        V2PetDeskCell(model: model, task: task, focused: model.v2Focus == task.id, order: i)
                            .frame(width: Self.cellWidth, height: PT.deskCell)
                            .padding(.leading, CGFloat(i % PT.deskColumns) * (Self.cellWidth + PT.deskGap))
                            .padding(.top, CGFloat(i / PT.deskColumns) * (PT.deskCell + PT.deskGap))
                            .id(task.id)
                    }
                }
                .animation(model.snapshotMode ? nil : WorkbenchTokens.Board.move, value: order.map(\.id))
            }
            .offset(x: Self.contentX, y: V2Geometry.top(model.metrics))
        }
        .frame(width: layout.outline.size.width, height: layout.outline.size.height, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sessions")
    }
}

struct V2PetDeskCell: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let focused: Bool
    let order: Int
    @State private var hovering = false

    var body: some View {
        let PT = WorkbenchTokens.Pets.self
        let B = WorkbenchTokens.Board.self
        let waiting = task.state == .needsYou && !task.statusUnknown
        let shape = RoundedRectangle(cornerRadius: PT.deskRadius, style: .continuous)
        VStack(spacing: 3) {
            PetFor(model: model, task: task, size: PT.deskPet, order: order)
            Text(model.v2Title(task))
                .font(PT.deskTitle)
                .foregroundStyle(task.statusUnknown ? B.dimTitle : B.title)
                .multilineTextAlignment(.center)
                .lineLimit(waiting ? 1 : 2)
                .fixedSize(horizontal: false, vertical: true)
            if task.state == .working && !task.statusUnknown {
                V2StepLine(model: model, task: task, size: PT.deskLineSize, glyph: false, lines: 2, alignment: .center)
                    .frame(maxWidth: .infinity)
            } else {
                petLine(model, task, size: PT.deskLineSize)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    // A question keeps its end (the command's tail, the question mark); the rest
                    // their beginning.
                    .truncationMode(waiting ? .middle : .tail)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if waiting {
                Spacer(minLength: 0)
                AgentControls(model: model, task: task, shown: true, short: true)
            }
        }
        .padding(.horizontal, PT.deskPadding)
        .padding(.vertical, PT.deskPadding - 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Whose it is, and how long: the desk's two top corners.
        .overlay(alignment: .topLeading) {
            ChatAgentIcon(agent: ChatAgent.named(task.agent), size: PT.deskAgentIcon)
                .saturation(task.statusUnknown ? B.dimSaturation : 1)
                .opacity(task.statusUnknown ? B.dimOpacity : 1)
                .padding(PT.deskPadding)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topTrailing) {
            if !waiting && !task.statusUnknown {
                Text(model.v2BoardTime(task)).font(PT.deskTime).foregroundStyle(B.time).monospacedDigit()
                    .padding(.top, PT.deskPadding)
                    .padding(.trailing, PT.deskPadding + 1)
            }
        }
        .background(shape.fill(waiting ? PT.deskWaitingFill : (hovering || focused ? PT.deskFillHover : PT.deskFill)))
        .overlay(shape.strokeBorder(waiting ? PT.deskWaiting : .clear, lineWidth: 1))
        .contentShape(shape)
        .onHover { inside in
            hovering = inside
            model.hoverV2(task.id, inside)
        }
        .onTapGesture { model.openV2(task.id) }
        .help("\(ChatAgent.named(task.agent).name) · \(task.project)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.v2Title(task)), \(ChatAgent.named(task.agent).name), \(BoardStateWord.text(task).0), \(model.v2BoardLine(task))")
        .accessibilityAction { model.openV2(task.id) }
    }
}

// MARK: Lanes

/// A lane each, in the board's order: the agent's icon, the title and what it is doing over a
/// track; its pet stands on the track as far as its plan has got (Codex's update_plan, Claude's
/// TodoWrite), the travelled part brighter, the finish a tick at the end. Done, it stands at the
/// finish; waiting on the person, amber where it stopped, Allow and Deny in place; failed, coral
/// where it stopped. A session that reported no plan stands at the start of a dotted track: how far
/// it has to go isn't known, and the board doesn't make it up. One whose state can't be read has no
/// track: a quiet line, its pet asleep at the start.
struct V2PetLanes: View {
    let model: WorkbenchModel
    let layout: V2BoardLayout

    static var contentX: CGFloat { WorkbenchTokens.Island.spec.expandedTopRadius + WorkbenchTokens.Pets.lanesMargin }
    static var contentWidth: CGFloat { WorkbenchTokens.Pets.lanesWidth - 2 * contentX }

    var body: some View {
        let PT = WorkbenchTokens.Pets.self
        let order = model.v2BoardOrder
        ZStack(alignment: .topLeading) {
            Color.clear
            PetScroll(model: model, layout: layout, width: Self.contentWidth) {
                VStack(spacing: 0) {
                    ForEach(Array(order.enumerated()), id: \.element.id) { i, task in
                        V2PetLane(model: model, task: task, focused: model.v2Focus == task.id, order: i)
                            .frame(height: task.statusUnknown ? PT.quietLane : PT.lane)
                            .id(task.id)
                    }
                }
                .animation(model.snapshotMode ? nil : WorkbenchTokens.Board.move, value: order.map(\.id))
            }
            .offset(x: Self.contentX, y: V2Geometry.top(model.metrics))
        }
        .frame(width: layout.outline.size.width, height: layout.outline.size.height, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sessions")
    }
}

struct V2PetLane: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let focused: Bool
    let order: Int
    @State private var hovering = false

    /// How far along the track: its plan's share; done, the end; nil when no plan was reported.
    static func progress(_ task: AgentTaskItem) -> CGFloat? {
        if task.state == .complete && !task.stopped && !task.statusUnknown { return 1 }
        return creatureProgress(task)
    }

    var body: some View {
        let B = WorkbenchTokens.Board.self
        Group {
            if task.statusUnknown { quiet } else { lane }
        }
        .background(RoundedRectangle(cornerRadius: B.rowRadius, style: .continuous)
            .fill(hovering || focused ? B.highlight : .clear))
        .contentShape(Rectangle())
        .onHover { inside in
            hovering = inside
            model.hoverV2(task.id, inside)
        }
        .onTapGesture { model.openV2(task.id) }
        .help("\(ChatAgent.named(task.agent).name) · \(task.project)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.v2Title(task)), \(ChatAgent.named(task.agent).name), \(BoardStateWord.text(task).0), \(model.v2BoardLine(task))")
        .accessibilityAction { model.openV2(task.id) }
    }

    /// Its state can't be read: no track to show, one quiet line, its pet asleep at the start.
    private var quiet: some View {
        let PT = WorkbenchTokens.Pets.self
        let B = WorkbenchTokens.Board.self
        return HStack(spacing: 6) {
            PetFor(model: model, task: task, size: PT.lanePet, order: order)
                .frame(width: 2 * PT.laneStart)
            ChatAgentIcon(agent: ChatAgent.named(task.agent), size: PT.laneIcon)
                .saturation(B.dimSaturation).opacity(B.dimOpacity)
                .accessibilityHidden(true)
            Text(model.v2Title(task)).font(PT.laneTitle).foregroundStyle(B.dimTitle).lineLimit(1)
            petLine(model, task, size: PT.laneStepSize).lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
    }

    private var lane: some View {
        let PT = WorkbenchTokens.Pets.self
        let B = WorkbenchTokens.Board.self
        let waiting = task.state == .needsYou && !task.statusUnknown
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ChatAgentIcon(agent: ChatAgent.named(task.agent), size: PT.laneIcon)
                    .saturation(task.statusUnknown ? B.dimSaturation : 1)
                    .opacity(task.statusUnknown ? B.dimOpacity : 1)
                    .accessibilityHidden(true)
                Text(model.v2Title(task)).font(PT.laneTitle)
                    .foregroundStyle(task.statusUnknown ? B.dimTitle : B.title)
                    .lineLimit(1)
                    .layoutPriority(1)
                Group {
                    if task.state == .working && !task.statusUnknown {
                        V2StepLine(model: model, task: task, size: PT.laneStepSize, glyph: false)
                    } else {
                        petLine(model, task, size: PT.laneStepSize).lineLimit(1).truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if waiting {
                    AgentControls(model: model, task: task, shown: true)
                } else if !task.statusUnknown {
                    Text(model.v2BoardTime(task)).font(B.timeFont).foregroundStyle(B.time).monospacedDigit()
                }
            }
            .padding(.top, 5)
            .padding(.horizontal, 8)
            track
                .frame(maxHeight: .infinity)
        }
    }

    /// The track, and the pet on it.
    private var track: some View {
        let PT = WorkbenchTokens.Pets.self
        let known = Self.progress(task)
        let p = known ?? 0
        let quiet = task.statusUnknown
        let s = PT.lanePet
        return GeometryReader { geo in
            let x0 = PT.laneStart, x1 = geo.size.width - PT.laneEnd
            let y = geo.size.height - 7
            let x = x0 + (x1 - x0) * p
            ZStack(alignment: .topLeading) {
                // The whole way; dotted when how far isn't known.
                Path { $0.move(to: CGPoint(x: x0, y: y)); $0.addLine(to: CGPoint(x: x1, y: y)) }
                    .stroke(PT.laneTrack.opacity(quiet ? 0.6 : 1),
                            style: StrokeStyle(lineWidth: PT.laneLine, lineCap: .round, dash: known == nil ? [1.5, 4] : []))
                // How far it has come.
                if known != nil && p > 0 {
                    Path { $0.move(to: CGPoint(x: x0, y: y)); $0.addLine(to: CGPoint(x: x, y: y)) }
                        .stroke(PT.laneTravelled, style: StrokeStyle(lineWidth: PT.laneLine, lineCap: .round))
                }
                // The finish (none drawn under a pet standing on it).
                if p < 1 {
                    Path { $0.move(to: CGPoint(x: x1, y: y - 5)); $0.addLine(to: CGPoint(x: x1, y: y + 3)) }
                        .stroke(PT.laneFinish.opacity(quiet || known == nil ? 0.5 : 1),
                                style: StrokeStyle(lineWidth: PT.laneLine, lineCap: .round))
                }
                // The pet, standing on the track: its loop's foot on the line.
                PetFor(model: model, task: task, size: s, order: order)
                    .position(x: x, y: y - s * (0.5 + 0.04) - PT.laneLine / 2)
                    .animation(model.snapshotMode ? nil : PT.laneMove, value: p)
            }
        }
    }
}

// MARK: At rest

/// Beside the notch while the island is at rest (a design with pets): a small black circle (glass in
/// Native) with
/// the pet of the session most in need, as the Dynamic Island holds a second activity in its own
/// small circle: PRD §8's breathing point, grown into the pet. Calm: it breathes and blinks, its
/// agent's spinner held still; it gestures only when its step changes; waiting on the person it
/// calls once, amber, and holds. Pointed at, the board opens, as the notch's own hover does; a
/// click opens it and keeps it open.
struct PetAtRest: View {
    let model: WorkbenchModel

    var body: some View {
        let PT = WorkbenchTokens.Pets.self
        let shown = model.petAtRestShown
        let rect = model.petAtRestRect
        let notch = NotchGeometry.notchRect(metrics: model.metrics, spec: WorkbenchTokens.Island.spec)
        ZStack {
            // Original: a black circle, as the Dynamic Island holds a second activity. Native: a
            // glass circle, as the island itself is.
            Color.clear.surface(Circle(), original: WorkbenchTokens.Island.surface)
            if let lead = model.v2RestPet {
                PetFor(model: model, task: lead, size: PT.restPet, live: shown, order: 0, calm: true)
                    .id(lead.id)
                    .transition(.opacity)
            }
        }
        .frame(width: rect.width, height: rect.height)
        // Out of the notch's side, and back into it.
        .scaleEffect(shown ? 1 : 0.5)
        .offset(x: shown ? 0 : -(rect.minX - (model.display.frame.width / 2 + notch.width / 2)) - rect.width / 2)
        .opacity(shown ? 1 : 0)
        .animation(model.snapshotMode ? nil : PT.restIn, value: shown)
        .animation(model.snapshotMode ? nil : PT.restIn, value: model.v2RestPet?.id)
        .contentShape(Circle())
        .onTapGesture { model.showAgentPanel(pinned: true) }
        .allowsHitTesting(shown)
        .help(model.v2RestPet.map { "\(model.v2Title($0)) · \(AgentCreature.words(CreaturePose.of($0, model: model)))" } ?? "")
        .accessibilityElement()
        .accessibilityLabel(model.v2RestPet.map { "\(model.v2Title($0)), \(AgentCreature.words(CreaturePose.of($0, model: model)))" } ?? "")
        .accessibilityAddTraits(.isButton)
        .accessibilityHidden(!shown)
        .padding(.leading, rect.minX)
        .padding(.top, rect.minY)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .panelScheme()
    }
}

// MARK: The designs side by side

extension FeedbackTrace {
    /// `--render-pets=<dir>`: the same pet in each design, side by side on one sheet, rendered off
    /// screen, then quits (docs/island/CREATURES.md): at rest beside the notch; the board as List,
    /// Capsules, Desk, Lanes and Wings. Each also as its own file. (A session opened has a text
    /// field, which can't be drawn off screen: `--snapshot` shows it, fb-09-board-pet-opened.)
    static func renderPets(model: WorkbenchModel, to dir: URL) async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        model.offscreenRender = true
        let width = model.display.frame.width
        /// The display's top, the island and what stands by it, cut to `crop`.
        let notch = NotchGeometry.notchRect(metrics: model.metrics, spec: WorkbenchTokens.Island.spec)
        func snap(_ crop: CGRect) -> NSImage? {
            let view = ZStack(alignment: .top) {
                Color(white: 0.55)
                // The display's own notch, which the island grows out of.
                UnevenRoundedRectangle(bottomLeadingRadius: notch.height * 0.3, bottomTrailingRadius: notch.height * 0.3,
                                       style: .continuous)
                    .fill(Color.black)
                    .frame(width: notch.width, height: notch.height)
                MockIsland(model: model)
                V2CapsuleBoard(model: model)
                PetAtRest(model: model)
            }
            .frame(width: width, height: max(crop.maxY, 900), alignment: .top)
            .environment(\.colorScheme, .dark)
            .environment(\.liquidGlass, false)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.cgImage,
                  let cut = image.cropping(to: CGRect(x: crop.minX * 2, y: crop.minY * 2, width: crop.width * 2, height: crop.height * 2))
            else { return nil }
            return NSImage(cgImage: cut, size: crop.size)
        }
        // The real pointer plays no part; the focus is the one the stage gives (the session just sent).
        model.pointerScripted = true
        func stage(_ style: BoardStyle) async {
            model.boardStyle = style
            model.stageFeedback(.progress)
            try? await Task.sleep(for: .milliseconds(400))
            model.v2Focus = model.v2Session
        }
        func around(_ size: CGSize) -> CGRect {
            CGRect(x: (width - size.width) / 2 - 24, y: 0, width: size.width + 48, height: size.height + 24)
        }
        var shots: [(name: String, title: String, image: NSImage)] = []
        // At rest.
        await stage(.petList)
        model.notchState = .silent
        try? await Task.sleep(for: .milliseconds(400))
        print("at rest:", model.petAtRestShown, model.notchState, model.v2RestPet?.id ?? "none", model.hidingOwnSurfaces)
        if let image = snap(CGRect(x: width / 2 - 190, y: 0, width: 380, height: 64)) {
            shots.append(("rest", "At rest: beside the notch, the pet of the session most in need", image))
        }
        // The board in each design.
        let designs: [(BoardStyle, String, String)] = [
            (.petList, "list", "List: each row led by its pet, the agent's icon by the title"),
            (.petCapsules, "capsules", "Capsules: each session its own small island, its pet at the front"),
            (.petDesk, "desk", "Desk: the team, four to a row, each pet at its desk"),
            (.petLanes, "lanes", "Lanes: each pet along its own track, as far as its plan has got"),
            (.creatures, "wings", "Wings (the earlier design): the pets alone in the notch's wings"),
        ]
        for (style, name, title) in designs {
            await stage(style)
            let layout = model.v2BoardLayout
            if let image = snap(around(layout.hoverSize ?? layout.outline.size)) { shots.append((name, title, image)) }
        }
        func write(_ image: NSImage, _ name: String) {
            guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                  let data = rep.representation(using: .png, properties: [:]) else { return }
            try? data.write(to: dir.appendingPathComponent(name))
            print("wrote \(name)")
        }
        for shot in shots { write(shot.image, "pet-\(shot.name).png") }
        // The sheet: two columns.
        func panel(_ shot: (name: String, title: String, image: NSImage)) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(shot.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.white.opacity(0.85))
                Image(nsImage: shot.image)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        let left = shots.filter { ["rest", "list", "desk"].contains($0.name) }
        let right = shots.filter { ["capsules", "lanes", "wings"].contains($0.name) }
        let sheet = HStack(alignment: .top, spacing: 36) {
            VStack(alignment: .leading, spacing: 30) { ForEach(left, id: \.name) { panel($0) } }
            VStack(alignment: .leading, spacing: 30) { ForEach(right, id: \.name) { panel($0) } }
        }
        .padding(36)
        .background(Color(white: 0.12))
        .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: sheet)
        renderer.scale = 2
        if let image = renderer.nsImage { write(image, "pet-designs.png") }
    }
}

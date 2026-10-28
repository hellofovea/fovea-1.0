import SwiftUI
import AppKit
import FoveaCore
import FoveaLook

// The session expanded (Oct 7, docs/island/WHOLE_SESSION.md): the whole session, every exchange
// in it, oldest first, each request with what the agent did folded and the answer it wrote, in one
// centred reading column, as tall as it needs down to the display's foot; and at the right, in the
// margin, an outline after Notion's page outline: a short line per request (the person's requests
// only), the one in view bright. Hovered, it opens to a card of the requests, each a way there.
// However many there are, the column keeps its width and the room stays on both sides: the lines
// draw closer, and the card scrolls.

// MARK: The outline

/// One entry in a session's outline: one of the person's requests.
struct V2OutlineItem: Identifiable, Equatable {
    let id: String
    let title: String
}

enum V2Outline {
    static func turnID(_ turn: Int) -> String { "turn-\(turn)" }
    /// The foot of the history, to tell when it has been read to the end.
    static let endID = "end"

    /// A session's outline: each of the person's requests, oldest first.
    static func items(_ turns: [V2Turn]) -> [V2OutlineItem] {
        turns.map { V2OutlineItem(id: turnID($0.id), title: $0.question) }
    }

    /// The lines' spacing for this height: as far apart as fits, no more than the most, and no
    /// closer than a point however many there are.
    static func gap(count: Int, height: CGFloat) -> CGFloat {
        let V = WorkbenchTokens.V2.self
        guard count > 1 else { return V.outlineGapMax }
        let fits = (height - CGFloat(count) * V.outlineTick) / CGFloat(count - 1)
        return max(1, min(V.outlineGapMax, fits))
    }

    /// The request in view: the last whose top has reached the read line; before any has, the
    /// first. Read to the end (the foot in view, `height` being the history's), the last whose top
    /// shows: the last requests never reach the line, and the one now is what the end shows.
    static func inView(_ items: [V2OutlineItem], tops: [String: CGFloat], height: CGFloat? = nil) -> String {
        if let height, let end = tops[endID], end <= height + 0.5,
           let last = items.last(where: { (tops[$0.id] ?? .infinity) < height }) {
            return last.id
        }
        let line = WorkbenchTokens.V2.outlineReadLine
        return items.last { (tops[$0.id] ?? .infinity) <= line }?.id ?? items.first?.id ?? ""
    }
}

/// Where each request starts in the history's scroll, to tell which is in view.
struct V2OutlineTops: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Reports this view's top in the named scroll space, under an outline entry's id.
    func outlineTop(_ id: String, in space: String) -> some View {
        background {
            GeometryReader { geo in
                Color.clear.preference(key: V2OutlineTops.self, value: [id: geo.frame(in: .named(space)).minY])
            }
        }
    }
}

/// The outline at a session's right (Notion's page outline): a line per request, the one in view
/// bright. Hovered (or `shown`), a card of the requests; a click goes there.
struct V2OutlineRail: View {
    let items: [V2OutlineItem]
    let inView: String
    /// The room the lines may take, top to bottom.
    let height: CGFloat
    var shown = false
    let go: (String) -> Void
    @State private var open = false
    @State private var hovered: String?

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let isOpen = open || shown
        ZStack(alignment: .trailing) {
            VStack(alignment: .trailing, spacing: V2Outline.gap(count: items.count, height: height)) {
                ForEach(items) { item in
                    Capsule()
                        .fill(item.id == inView ? V.outlineOn : V.outlineOff)
                        .frame(width: V.outlineTickRequest, height: V.outlineTick)
                }
            }
            .padding(.vertical, V.outlineGapMax)
            .frame(width: V.outlineWidth, alignment: .trailing)
            .contentShape(Rectangle())
            .opacity(isOpen ? 0 : 1)
            if isOpen { card }
        }
        .onHover { inside in withAnimation(V.outlineMotion) { open = inside } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your requests in this session")
    }

    private var card: some View {
        let V = WorkbenchTokens.V2.self
        let full = CGFloat(items.count) * V.outlineRowRequest + 2 * V.outlineCardPadding
        let list = VStack(alignment: .leading, spacing: 0) {
            ForEach(items) { item in row(item) }
        }
        .padding(V.outlineCardPadding)
        return Group {
            if full > height {
                ScrollView { list }
                    .scrollIndicators(.automatic)
                    .frame(height: height)
            } else {
                list
            }
        }
        .frame(width: V.outlineCardWidth)
        .background(RoundedRectangle(cornerRadius: V.outlineCardRadius, style: .continuous).fill(V.outlineCardFill))
        .overlay(RoundedRectangle(cornerRadius: V.outlineCardRadius, style: .continuous)
            .strokeBorder(V.outlineCardBorder, lineWidth: 0.5))
        // Oct 21, Ryan ("simpler is better"): a lighter shadow, and it fades (no scale).
        .shadow(color: V.outlineCardShadow, radius: V.outlineCardShadowRadius, y: 3)
        .transition(.opacity)
    }

    private func row(_ item: V2OutlineItem) -> some View {
        let V = WorkbenchTokens.V2.self
        let on = item.id == inView
        return Button { go(item.id) } label: {
            Text(item.title)
                .font(on ? V.outlineRequestFontOn : V.outlineRequestFont)
                .foregroundStyle(on ? V.outlineTextOn : V.outlineTextOff)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: V.outlineRowRequest, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: V.outlineCardRadius - V.outlineCardPadding, style: .continuous)
                    .fill(hovered == item.id ? V.outlineRowHover : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? item.id : (hovered == item.id ? nil : hovered) }
        .help(item.title)
        .accessibilityLabel("Your request: \(item.title)")
    }
}

// MARK: The history

/// The whole session: every exchange, oldest first, each its request, what the agent did (folded)
/// and what came back, in the reading column; the one now as the session shows it (at work,
/// waiting on the person, or done). It opens on the one now: at its request when the one now is
/// taller than the room, else at the foot with the earlier ones above it, as a conversation reads.
/// The outline is in the margin from two requests. Scrolled, the words pass under the rules above
/// and below (the hard edge HIG's scroll views give a bar that does not float), never into blank
/// space.
struct V2SessionHistory: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let layout: V2ChatLayout
    @State private var tops: [String: CGFloat] = [:]

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let turns = model.v2Turns(task.id)
        let now = turns.count - 1
        let items = V2Outline.items(turns)
        let space = "v2-history-\(task.id)"
        let inView = V2Outline.inView(items, tops: tops, height: layout.body)
        // A request gone to lands a margin below the rule, where the first one rests.
        let landing = UnitPoint(x: 0.5, y: V.gap / max(layout.body, 1))
        // Drawn off the screen, where a scroll view draws nothing: the stack, clipped, at the end it
        // would open at.
        Group { if model.offscreenRender {
            stack(turns, now: now, space: space)
                .frame(width: layout.contentWidth, height: layout.body, alignment: layout.scrolls ? .bottom : .top)
                .clipped()
                .overlay(alignment: .trailing) {
                    if items.count > 1 {
                        V2OutlineRail(items: items, inView: items.last?.id ?? "", height: layout.body - 2 * V.gap,
                                      shown: model.v2OutlineShown) { _ in }
                            .padding(.trailing, layout.size == .expanded ? V.outlineInset : 0)
                    }
                }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    stack(turns, now: now, space: space)
                }
                .scrollIndicators(.never)
                // Taller than the room, it opens at the foot, the one now in view, and keeps to it as
                // it grows; once the person opens what an agent did, it grows downward from there.
                .defaultScrollAnchor(layout.scrolls && !model.v2HistoryHeld ? .bottom : .top)
                // A new scroll each time the session is expanded, and for each new request, so each
                // opens where it should rather than where the last one was left.
                .id("\(task.id)-\(turns.count)-\(model.v2HistoryEpoch)")
                .coordinateSpace(name: space)
                .onPreferenceChange(V2OutlineTops.self) { tops = $0 }
                .overlay(alignment: .trailing) {
                    if items.count > 1 {
                        V2OutlineRail(items: items, inView: inView, height: layout.body - 2 * V.gap, shown: model.v2OutlineShown) { id in
                            withAnimation(WorkbenchTokens.Spring.rows) { proxy.scrollTo(id, anchor: landing) }
                        }
                        .padding(.trailing, layout.size == .expanded ? V.outlineInset : 0)
                    }
                }
                // The one now alone taller than the room: once laid out, its request comes to the top,
                // so the person keeps their place.
                .onAppear {
                    guard let last = turns.last,
                          Self.turnHeight(model: model, task: task, turn: last, now: true, width: layout.column) > layout.body - 2 * V.gap
                    else { return }
                    // A run-loop timer, which also fires inside the snapshot runs (they hold the main
                    // queue while they render).
                    Timer.scheduledTimer(withTimeInterval: V.historySettle, repeats: false) { _ in
                        MainActor.assumeIsolated {
                            model.v2HistoryHeld = true
                            proxy.scrollTo(V2Outline.turnID(now), anchor: landing)
                        }
                    }
                }
            }
        } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Every request in this session")
    }

    /// Every exchange, top to bottom.
    private func stack(_ turns: [V2Turn], now: Int, space: String) -> some View {
        let V = WorkbenchTokens.V2.self
        return VStack(alignment: .leading, spacing: V.historyTurnGap) {
            ForEach(turns) { turn in
                VStack(alignment: .leading, spacing: V.historyQuestionGap) {
                    // The person's request in its bubble at the right, gone to by it (a
                    // short view, so the landing's margin holds however tall the exchange
                    // is); the agent's answer open at the left. Oct 21, Ryan ("simpler is
                    // better"): no creature in the margin beside it.
                    // Oct 15 review, QA07: the last request, editable once it's answered.
                    Group {
                        if turn.id == now {
                            V2EditableQuestion(model: model, task: task, lines: 3,
                                               beside: V2RequestBubble.bubbleWidth(turn.question, width: layout.column)) {
                                V2RequestBubble(text: turn.question, width: layout.column)
                            }
                            .frame(width: layout.column)
                        } else {
                            V2RequestBubble(text: turn.question, width: layout.column)
                        }
                    }
                    .id(V2Outline.turnID(turn.id))
                    Group { if turn.id == now { current } else { past(turn) } }
                }
                .outlineTop(V2Outline.turnID(turn.id), in: space)
            }
        }
        .overlay(alignment: .bottom) { Color.clear.frame(height: 0).outlineTop(V2Outline.endID, in: space) }
        .padding(.vertical, V.gap)
        .padding(.leading, layout.columnX - V2Geometry.contentX)
        .frame(width: layout.contentWidth, alignment: .leading)
    }

    @ViewBuilder private var current: some View {
        // Oct 15 review: reopening, gone, not sure it arrived, what was decided.
        if let kind = model.v2CaseBody(task) {
            V2CaseBodyView(model: model, task: task, kind: kind, width: layout.column)
        } else {
            currentUsual
        }
    }

    @ViewBuilder private var currentUsual: some View {
        switch task.state {
        case .working: V2WorkingLine(model: model, task: task).frame(width: layout.column)
        case .needsYou: V2Response(model: model, task: task, width: layout.column)
        case .complete, .failed: V2Answer(model: model, task: task, width: layout.column)
        }
    }

    @ViewBuilder private func past(_ turn: V2Turn) -> some View {
        let V = WorkbenchTokens.V2.self
        if let answer = turn.answer {
            VStack(alignment: .leading, spacing: WorkbenchTokens.FeedbackV2.answerGap) {
                if let work = turn.work {
                    V2WorkFold(model: model, work: work, key: V2Work.key(task.id, turn: turn.id), width: layout.column)
                }
                MarkdownView(markdown: answer, width: layout.column)
            }
        } else if let result = turn.result {
            V2Response(model: model, task: answered(result), width: layout.column)
        } else {
            Text(V.movedOn).font(V.movedOnFont).foregroundStyle(V.subColor)
        }
    }

    /// An earlier exchange's result, drawn as a finished one.
    private func answered(_ result: AgentResult) -> AgentTaskItem {
        var past = task
        past.result = result
        past.state = .complete
        return past
    }

    /// The history's height at a column's width, its margins in it, for the island's outline:
    /// the panel is as tall as this, down to the display's foot.
    static func height(model: WorkbenchModel, task: AgentTaskItem, width: CGFloat) -> CGFloat {
        let V = WorkbenchTokens.V2.self
        let turns = model.v2Turns(task.id)
        var h = 2 * V.gap
        for (k, turn) in turns.enumerated() {
            if k > 0 { h += V.historyTurnGap }
            h += turnHeight(model: model, task: task, turn: turn, now: k == turns.count - 1, width: width)
        }
        return h
    }

    /// One exchange's height: its request, and what came back as the history draws it.
    static func turnHeight(model: WorkbenchModel, task: AgentTaskItem, turn: V2Turn, now: Bool, width: CGFloat) -> CGFloat {
        let V = WorkbenchTokens.V2.self
        let F = WorkbenchTokens.FeedbackV2.self
        var h = V2RequestBubble.height(turn.question, width: width) + V.historyQuestionGap
        if now {
            if let kind = model.v2CaseBody(task) {
                h += V2CaseBodyView.height(model: model, task: task, kind: kind, width: width)
            } else {
                switch task.state {
                case .working: h += WorkbenchTokens.Board.workingLine
                case .needsYou: h += V2NeedsYouBody.height(model: model, task: task, width: width)
                case .complete, .failed: h += V2Answer.height(model: model, task: task, width: width)
                }
            }
        } else if let answer = turn.answer {
            if let work = turn.work {
                h += V2WorkFold.height(work, open: model.v2StepsOpen.contains(V2Work.key(task.id, turn: turn.id)), width: width)
                    + F.answerGap
            }
            h += MarkdownBlock.height(answer, width: width)
        } else if turn.result != nil {
            h += V.needsYouBody
        } else {
            h += V2Geometry.measure(V.movedOn, size: 13, width: width)
        }
        return h
    }
}

// MARK: Sample exchanges

/// An earlier exchange of a sample session: what was asked, what the agent wrote back, what it did.
struct V2SampleTurn {
    let question: String
    let answer: String
    /// None when it answered without using a tool.
    let work: V2Work?
}

extension V2Request {
    /// What a sample session was asked between its request and its follow-up, each with the
    /// answer as the agent wrote it and what it did for it. `long`: a session asked many times
    /// over, for the outline's crowded case (the code change's; the others keep their two).
    func earlierTurns(long: Bool) -> [V2SampleTurn] {
        guard self == .code else { return [] }
        func step(_ kind: StepKind, _ object: String? = nil, added: Int? = nil, removed: Int? = nil,
                  passed: Bool? = nil, note: String? = nil) -> V2WorkEntry {
            .step(AgentLiveStep(kind: kind, object: object, added: added, removed: removed, passed: passed, note: note))
        }
        var turns: [V2SampleTurn] = [
            V2SampleTurn(question: "Why did the expanded state move down a point after that?", answer: """
            The expanded state still added the old fixed height once, on top of the new one.

            ### What moved
            - `IslandOutline` drew the ears from the menu bar's height, but the expanded state's top padding still added the old 22 pt, so its content sat a point lower than the collapsed state's.

            ### What I changed
            - The padding reads `metrics.menuBarHeight` too, in [IslandShape.swift](Sources/Fovea/Island/IslandShape.swift).
            - A snapshot test pins the expanded state's top to the menu bar, in [IslandSnapshotTests.swift](Tests/FoveaTests/IslandSnapshotTests.swift).

            `swift test --filter Island` passes.
            """, work: V2Work(seconds: 48, entries: [
                .remark("I'll compare where the collapsed and expanded states start."),
                step(.search, "expandedTopPadding", note: "2 files"),
                step(.read, "IslandShape.swift"),
                .remark("The expanded state still adds the old 22 pt."),
                step(.edit, "IslandShape.swift", added: 2, removed: 2),
                step(.create, "IslandSnapshotTests.swift", added: 18, removed: 0),
                step(.test, "swift test --filter Island", passed: true),
            ])),
            V2SampleTurn(question: "Keep the bottom corners at 32 in Spacious, and take the screenshots again.", answer: """
            The bottom corners stay at 32 pt in Spacious, and the screenshots are new.

            ### Corners
            - `V2.bottomRadius` is 32 in Spacious and 28 in Compact, in [WorkbenchTokens.swift](Prototypes/FoveaWorkbench/WorkbenchTokens.swift). The ears stay at 19 pt.

            ### Screenshots
            - Took `fb-11` and `workbench-v2-chat-*` again in both densities: ten images in `Prototypes/shots`.
            - Against the last set, only the bottom corners moved.
            """, work: V2Work(seconds: 65, entries: [
                step(.read, "WorkbenchTokens.swift"),
                step(.edit, "WorkbenchTokens.swift", added: 1, removed: 1),
                step(.run, "swift run FoveaWorkbench --snapshot shots --only fb-11", passed: true),
                step(.run, "swift run FoveaWorkbench --snapshot shots --only workbench-v2-chat", passed: true),
                .remark("Comparing them with the last set."),
            ])),
        ]
        guard long else { return turns }
        turns += [
            V2SampleTurn(question: "Rename the fixed height so nobody reaches for it again.", answer: """
            Renamed it `legacyEarHeight` and marked it deprecated, so anything that reads it gets a warning.

            - Nothing reads it now: its last two uses moved to `metrics.menuBarHeight`.
            - `swift build` passes with no new warnings.
            """, work: V2Work(seconds: 22, entries: [
                step(.search, "fixedEarHeight", note: "4 files"),
                step(.edit, "IslandShape.swift", added: 2, removed: 2),
                step(.edit, "NotchGeometry.swift", added: 1, removed: 1),
                step(.build, "swift build", passed: true),
            ])),
            V2SampleTurn(question: "Does the software island still sit in the middle of an ultrawide display?", answer: """
            Yes. It centres on the display's own width, so it sits in the middle at 3440 pt wide too, with the same ears.

            - `NotchGeometry.softwareIslandRect` takes the display's own `frame.midX`, not the main display's.
            - The ultrawide case in `NotchGeometryTests` passes.
            """, work: V2Work(seconds: 34, entries: [
                step(.read, "NotchGeometry.swift"),
                step(.test, "swift test --filter softwareIsland", passed: true),
            ])),
            V2SampleTurn(question: "Make the ears' radius follow the notch as well.", answer: """
            The ears' radius now follows the notch's corner instead of a fixed 19 pt.

            ### Where
            - `NotchGeometry.earRadius` derives the corner from the screen's safe area, in [NotchGeometry.swift](Sources/FoveaCore/Island/NotchGeometry.swift).
            - Displays without a notch keep 19 pt.

            ### Tests
            - [NotchRadiusTests.swift](Tests/FoveaCoreTests/NotchRadiusTests.swift) pins the radius on the 14-inch, the 16-inch and a display without a notch.
            """, work: V2Work(seconds: 90, entries: [
                step(.read, "NotchGeometry.swift"),
                .remark("macOS doesn't report the notch's corner radius, so I'll derive it from the safe area."),
                step(.edit, "NotchGeometry.swift", added: 16, removed: 4),
                step(.create, "NotchRadiusTests.swift", added: 31, removed: 0),
                step(.test, "swift test", passed: true),
            ])),
            V2SampleTurn(question: "What else reads the menu bar's height?", answer: """
            Three places:

            - `IslandShape.swift`, for the ears
            - `NotchGeometry.swift`, for the notch's rectangle
            - `VoiceBar.swift`, for the bar's top padding

            Nothing else reads it; the tests use `ScreenMetrics.sampleNotched`.
            """, work: V2Work(seconds: 12, entries: [
                step(.search, "menuBarHeight", note: "3 files"),
            ])),
            V2SampleTurn(question: "Run the smoke test.", answer: """
            The smoke test passes, every check of it.

            - It took about two minutes, most of it in the motion checks.
            """, work: V2Work(seconds: 123, entries: [
                step(.run, "swift run FoveaWorkbench --smoke", passed: true),
            ])),
            V2SampleTurn(question: "Undo the radius change; it looks too round on the 14-inch.", answer: """
            Undone. The ears are back to 19 pt everywhere, and the test for the notch's corner is gone.

            ### Kept
            - The height still follows the menu bar.
            - The spacing from your second screenshot stays.

            `swift test` passes.
            """, work: V2Work(seconds: 41, entries: [
                step(.run, "git checkout -- NotchGeometry.swift", passed: true),
                step(.run, "git rm NotchRadiusTests.swift", passed: true),
                step(.test, "swift test", passed: true),
            ])),
            V2SampleTurn(question: "Add a line about it to AMENDMENTS.md.", answer: """
            Added one under Oct 7:

            > The ears, the notch and the voice bar all read the menu bar's height; the ears' radius stays 19 pt.
            """, work: V2Work(seconds: 15, entries: [
                step(.read, "AMENDMENTS.md"),
                step(.edit, "AMENDMENTS.md", added: 4, removed: 0),
            ])),
            V2SampleTurn(question: "Commit what we have.", answer: """
            Committed as "Notch ears follow the menu bar" on `notch-ears`. Not pushed.

            - `IslandShape.swift`, `NotchGeometry.swift`, `WorkbenchTokens.swift`
            - `IslandSnapshotTests.swift`, `NotchGeometryTests.swift`
            - `AMENDMENTS.md`
            """, work: V2Work(seconds: 9, entries: [
                step(.run, "git status", passed: true),
                step(.run, "git commit -m \"Notch ears follow the menu bar\"", passed: true),
            ])),
        ]
        return turns
    }
}

// MARK: The person's request

/// The person's request: a bubble at the column's right (Oct 24, Ryan), hugging its words up to
/// `V2.bubbleShare` of the column; the agent's answer sits open at the left under it.
struct V2RequestBubble: View {
    let text: String
    /// The column it sits in.
    let width: CGFloat
    var lines: Int? = nil

    var body: some View {
        let V = WorkbenchTokens.V2.self
        Text(text)
            .font(.system(size: V.bubbleSize))
            .lineSpacing(V.bubbleSpacing)
            .foregroundStyle(V.bubbleColor)
            .lineLimit(lines)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, V.bubblePaddingH)
            .padding(.vertical, V.bubblePaddingV)
            .background(RoundedRectangle(cornerRadius: V.bubbleRadius, style: .continuous).fill(V.bubbleFill))
            .frame(maxWidth: Self.widest(width), alignment: .trailing)
            .frame(width: width, alignment: .trailing)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("You asked: \(text)")
    }

    /// The widest a bubble gets in a column.
    static func widest(_ width: CGFloat) -> CGFloat { (width * WorkbenchTokens.V2.bubbleShare).rounded(.down) }

    /// Its width in a column: its words on one line, up to the widest, and its padding.
    static func bubbleWidth(_ text: String, width: CGFloat) -> CGFloat {
        let V = WorkbenchTokens.V2.self
        let inner = widest(width) - 2 * V.bubblePaddingH
        return min(V2Geometry.lineWidth(text, size: V.bubbleSize), inner) + 2 * V.bubblePaddingH
    }

    static func height(_ text: String, width: CGFloat, lines: Int? = nil) -> CGFloat {
        let V = WorkbenchTokens.V2.self
        return V2Geometry.measure(text, size: V.bubbleSize, width: widest(width) - 2 * V.bubblePaddingH,
                                  spacing: V.bubbleSpacing, lines: lines)
            + 2 * V.bubblePaddingV
    }
}

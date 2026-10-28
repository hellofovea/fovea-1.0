import SwiftUI
import FoveaCore
import FoveaKit

// Oct 26, Ryan: "vibe island pops up when the agent needs approval/work is done. do that for ours as
// well." Vibe Island's notch expands with Allow and Deny when Claude Code asks permission, and says
// Done when a session finishes. Here a session that needs you (an approval, a question, a failure)
// or is done pops out of the notch by itself while the notch rests:
// - one line over its row, in the state's color: "Claude Code needs you", "Codex is done";
// - its row as the board draws it: the icon, the title, what it asks (Allow and Deny in place) or its
//   answer's first line;
// - Oct 27, Ryan ("they should also suit the new notch design", with the glass board he kept): the
//   board's glass, as wide as the board, attached or floating as the panels are: one of its rows
//   come out by itself (it was Wings' black).
// A done one goes after a few seconds, one that needs you after longer, and neither while the
// pointer is on it; once it's answered (Allowed, Denied), it goes a moment later. A click opens the
// session; Esc puts it away, and it stays on the board. A quick answer still opens itself whole
// (`v2Finished`), and nothing pops up while the notch is in use, in the first run, or with Settings'
// "Show answers when they come back" off.

/// The session popped up, and why.
struct V2Alert: Equatable {
    enum Kind { case needsYou, done, failed }
    let id: String
    let kind: Kind
}

/// Where the pop-up's parts go: its outline, its line over the row, the row.
struct V2AlertLayout: Equatable {
    var outline: StackLayout.Outline
    /// The line over the row, from the island's top.
    var top: CGFloat
    var width: CGFloat

    static func make(metrics: ScreenMetrics) -> V2AlertLayout {
        let A = WorkbenchTokens.Alert.self
        let B = WorkbenchTokens.Board.self
        let top = V2Geometry.top(metrics)
        let height = top + A.eyebrowHeight + A.eyebrowGap + B.row + B.paddingBottom
        return V2AlertLayout(outline: StackLayout.Outline(size: CGSize(width: B.width, height: height),
                                                          topRadius: WorkbenchTokens.Island.spec.expandedTopRadius,
                                                          bottomRadius: B.bottomRadius),
                             top: top, width: V2BoardLayout.contentWidth)
    }
}

extension WorkbenchModel {
    var v2AlertLayout: V2AlertLayout { V2AlertLayout.make(metrics: metrics) }

    /// A session needs you, or is done: it pops up, if the notch rests. `force`: staged.
    func popV2Alert(_ id: String, force: Bool = false) {
        guard force || (showAnswers && notchState == .silent && !previewing && !snapshotMode && live?.director == nil),
              let task = v2Task(id) else { return }
        let kind: V2Alert.Kind
        switch task.state {
        case .needsYou: kind = .needsYou
        case .complete: kind = .done
        case .failed: kind = .failed
        case .working: return
        }
        if notchState == .v2Alert, v2Alert == V2Alert(id: id, kind: kind) { return }
        v2Alert = V2Alert(id: id, kind: kind)
        v2AlertHovered = false
        v2Focus = id
        notchState = .v2Alert
        holdV2Alert()
    }

    /// Its time up, or answered a moment ago, it goes; the pointer on it holds it.
    private func holdV2Alert() {
        v2AlertClose?.cancel()
        guard let alert = v2Alert, !snapshotMode else { return }
        let A = WorkbenchTokens.Alert.self
        v2AlertClose = Task { [weak self] in
            let end = Date().addingTimeInterval(alert.kind == .done ? A.doneHold : A.needsYouHold)
            var answered: Date?
            while let self, !Task.isCancelled, self.notchState == .v2Alert, self.v2Alert == alert {
                let now = Date()
                if alert.kind == .needsYou, answered == nil, self.v2Task(alert.id)?.state != .needsYou {
                    answered = now.addingTimeInterval(A.answeredHold)
                }
                if let answered, now >= answered { break }
                if answered == nil, now >= end, !self.v2AlertHovered { break }
                try? await Task.sleep(for: .seconds(0.25))
            }
            guard let self, !Task.isCancelled, self.notchState == .v2Alert, self.v2Alert == alert else { return }
            self.dismissV2Alert()
        }
    }

    /// Esc, its time, or answered: the island rests; the session stays on the board.
    func dismissV2Alert() {
        v2AlertClose?.cancel()
        guard notchState == .v2Alert else { return }
        notchState = .silent
    }

    /// `--demo alert:needsYou|done|failed`: a sample session of that state pops up.
    func stageV2Alert(_ option: String?) {
        let want: AgentTaskState = option == "done" ? .complete : option == "failed" ? .failed : .needsYou
        if v2BoardOrder.first(where: { $0.state == want }) == nil {
            let id = workingV2Session()
            // No sample failed: one at work fails, as a build does.
            if want == .failed, let i = agentTasks.firstIndex(where: { $0.id == id }) {
                v2Runs[id]?.cancel()
                agentTasks[i].state = .failed
                agentTasks[i].activity = L("The build failed: 2 errors in PayloadCompiler.swift")
            }
        }
        guard let task = v2BoardOrder.first(where: { $0.state == want }) else { return }
        popV2Alert(task.id, force: true)
    }
}

/// The pop-up: the line in the state's color over the session's row, on the board's glass in the
/// Mac's look. (Oct 27, Ryan: no glow at its foot.)
struct V2AlertContent: View {
    let model: WorkbenchModel

    var body: some View {
        let A = WorkbenchTokens.Alert.self
        let B = WorkbenchTokens.Board.self
        let layout = model.v2AlertLayout
        let size = layout.outline.size
        ZStack(alignment: .top) {
            if let alert = model.v2Alert, let task = model.v2Task(alert.id) {
                let color = Self.color(alert.kind)
                VStack(alignment: .leading, spacing: A.eyebrowGap) {
                    Text(Self.line(alert.kind, agent: ChatAgent.named(task.agent).name))
                        .font(A.eyebrowFont)
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .padding(.leading, B.rowPaddingH)
                        .frame(height: A.eyebrowHeight)
                    V2BoardRow(model: model, task: task, focused: false)
                        .frame(height: B.row)
                }
                .frame(width: layout.width, alignment: .leading)
                .offset(y: layout.top)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipped()
        .panelScheme()
        .contentShape(Rectangle())
        .onHover { model.v2AlertHovered = $0 }
        .accessibilityElement(children: .contain)
    }

    static func color(_ kind: V2Alert.Kind) -> Color {
        switch kind {
        case .needsYou: return WorkbenchTokens.Panel.needsYouColor
        case .done: return WorkbenchTokens.Alert.doneColor
        case .failed: return WorkbenchTokens.Panel.failedColor
        }
    }

    static func line(_ kind: V2Alert.Kind, agent: String) -> String {
        switch kind {
        case .needsYou: return L("\(agent) needs you")
        case .done: return L("\(agent) is done")
        case .failed: return L("\(agent) couldn't finish")
        }
    }
}

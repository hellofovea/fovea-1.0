import SwiftUI
import FoveaCore
import FoveaKit

// Oct 7 (docs/island/FEEDBACK_2026-10-06.md, #16 revisited): while an agent works, its session shows
// what it is doing, one step at a time, the step and the thing it acts on, as Claude Code and Codex
// report them and as the notch apps show them (coucou, CodeIsland, Notchi, Open Island, Crew Tower,
// Vibe Island). One line, each step replacing the last; an edit's lines and a command's outcome
// arrive when the step ends. Nothing the agents don't report: no streamed text, no thinking text, no
// command output while it runs. Codex and Claude Code only.

/// A step's kind, from what the agent reports.
/// - Claude Code, each `tool_use` (stream-json for the sessions Fovea starts, the PreToolUse hook for
///   the person's own): Read{file_path}, Edit/MultiEdit/Write{file_path}, Bash{command, description},
///   Grep/Glob{pattern}, WebSearch{query}, WebFetch{url}, TodoWrite/TaskUpdate{todos}, Agent/Task
///   {description}, mcp__server__tool; a thinking block (its text hidden).
/// - Codex, each item (app-server for Fovea's own, the PreToolUse hook otherwise):
///   commandExecution with its `commandActions` (read, search, listFiles, unknown), fileChange
///   {changes[].path, diff}, webSearch{query}, mcpToolCall{server, tool}, turn/plan/updated, reasoning,
///   agentMessage (phase commentary or final_answer).
/// When it ends: an edit's lines (Claude's structuredPatch/gitDiff, Codex's diff), a command's exit
/// (Claude's is_error, Codex's exitCode).
enum StepKind: Equatable {
    case read, search, list, edit, create, run, build, test, web, fetch, plan, subagent, tool, think, answer

    var verb: String {
        switch self {
        case .read, .fetch: return L("Reading")
        case .search: return L("Searching for")
        case .list: return L("Listing")
        case .edit: return L("Editing")
        case .create: return L("Creating")
        case .run: return L("island.step.running", english: "Running")
        case .build: return L("Building with")
        case .test: return L("Testing with")
        case .web: return L("Searching the web for")
        case .plan: return L("Planning")
        case .subagent: return L("Subagent")
        case .tool: return L("Using")
        case .think: return L("island.thinking", english: "Thinking")
        case .answer: return L("Writing the answer")
        }
    }

    var symbol: String {
        switch self {
        case .read: return "doc.text"
        case .fetch: return "link"
        case .search: return "magnifyingglass"
        case .list: return "folder"
        case .edit: return "pencil"
        case .create: return "doc.badge.plus"
        case .run: return "terminal"
        case .build: return "hammer"
        case .test: return "checkmark.seal"
        case .web: return "globe"
        case .plan: return "list.bullet"
        case .subagent: return "arrow.triangle.branch"
        case .tool: return "puzzlepiece.extension"
        case .think: return "sparkle"
        case .answer: return "text.alignleft"
        }
    }

    /// Done, as the list of what it did says it (V2Work).
    var pastVerb: String {
        switch self {
        case .read, .fetch: return L("Read")
        case .search: return L("Searched for")
        case .list: return L("Listed")
        case .edit: return L("Edited")
        case .create: return L("Created")
        case .run: return L("Ran")
        case .build: return L("Built with")
        case .test: return L("Tested with")
        case .web: return L("Searched the web for")
        case .plan: return L("Planned")
        case .subagent: return L("Subagent")
        case .tool: return L("Used")
        case .think: return L("Thought")
        case .answer: return L("Wrote the answer")
        }
    }

    /// Commands and patterns are set in code; files, pages and plans in the text face.
    var codeObject: Bool { self == .run || self == .build || self == .test || self == .search }
}

/// One step: its kind and object, and what came of it once it ended.
struct AgentLiveStep: Equatable {
    var kind: StepKind
    var object: String? = nil
    var added: Int? = nil
    var removed: Int? = nil
    var passed: Bool? = nil
    var done: Int? = nil
    var total: Int? = nil
    /// What else came of it, as the agent reports it: a search's matches ("3 files").
    var note: String? = nil

    /// Shown a moment longer: the edit's lines, the command's outcome.
    var hasResult: Bool { added != nil || passed != nil }
}

/// What the agent did for one exchange (Oct 7, docs/island/WHOLE_SESSION.md), folded under its
/// answer: its steps in order (the tool, what it acted on, what came of it) and, between them, what
/// it said along the way. All of it is what the agents report (above); no command output, no
/// thinking text.
struct V2Work: Equatable {
    var seconds: Int
    var entries: [V2WorkEntry]

    /// The files it edited or made, in order, each once.
    var editedFiles: [String] {
        var out: [String] = []
        for case .step(let step) in entries where step.kind == .edit || step.kind == .create {
            if let file = step.object, !out.contains(file) { out.append(file) }
        }
        return out
    }

    /// The folded line: how long it worked, and what it edited.
    func summary(seconds measured: Int? = nil) -> String {
        // Oct 18, Ryan: in the primary language.
        var line = L("Worked for \(Self.duration(measured ?? seconds))")
        let files = editedFiles
        if !files.isEmpty { line += L(" · Edited \(files.count == 1 ? files[0] : L("\(files.count) files"))") }
        return line
    }

    static func duration(_ s: Int) -> String {
        // Oct 18, Ryan: in the primary language. Oct 21: written as the board writes its times
        // ("2m 41s", as "10m"), not "2 m 41 s"; minutes keep their seconds, "2m" being the
        // board's "2 minutes ago" in Chinese.
        s < 60 ? L("\(s)s") : L("\(s / 60)m \(s % 60)s")
    }

    /// Whose fold is open: the session's id for the exchange now, this for an earlier one.
    static func key(_ session: String, turn: Int) -> String { "\(session)#\(turn)" }
}

enum V2WorkEntry: Equatable {
    case step(AgentLiveStep)
    /// The agent's own words between its steps (Claude's text before a tool_use; Codex's
    /// commentary phase).
    case remark(String)
}

extension V2Request {
    /// What the agent reports while it works on this request, step by step.
    var liveSteps: [AgentLiveStep] {
        switch self {
        case .code:
            return [
                AgentLiveStep(kind: .read, object: "IslandShape.swift"),
                AgentLiveStep(kind: .search, object: "menuBarHeight"),
                AgentLiveStep(kind: .read, object: "NotchGeometry.swift"),
                AgentLiveStep(kind: .plan, object: L("Match the ears to the menu bar"), done: 1, total: 4),
                AgentLiveStep(kind: .edit, object: "IslandShape.swift", added: 3, removed: 1),
                AgentLiveStep(kind: .edit, object: "NotchGeometry.swift", added: 2, removed: 1),
                AgentLiveStep(kind: .build, object: "swift build", passed: true),
                AgentLiveStep(kind: .test, object: "swift test --filter NotchGeometryTests", passed: true),
                AgentLiveStep(kind: .think),
                AgentLiveStep(kind: .answer),
            ]
        case .formula:
            return [AgentLiveStep(kind: .read, object: L("your screenshot")), AgentLiveStep(kind: .think), AgentLiveStep(kind: .answer)]
        case .calendar:
            return [AgentLiveStep(kind: .tool, object: "calendar · list_events"), AgentLiveStep(kind: .think), AgentLiveStep(kind: .answer)]
        case .draft:
            return [AgentLiveStep(kind: .tool, object: "mail · read_message"), AgentLiveStep(kind: .think), AgentLiveStep(kind: .answer)]
        }
    }
}

extension AgentBoard {
    /// The sample sessions at work, step by step (Codex and Claude Code).
    static let liveSteps: [String: [AgentLiveStep]] = [
        "t-shortcuts": [
            AgentLiveStep(kind: .read, object: "ShortcutRecorder.swift"),
            AgentLiveStep(kind: .search, object: "onChange"),
            AgentLiveStep(kind: .edit, object: "ShortcutRecorder.swift", added: 12, removed: 3),
            AgentLiveStep(kind: .read, object: "ShortcutStore.swift"),
            AgentLiveStep(kind: .edit, object: "ShortcutStore.swift", added: 4, removed: 0),
            AgentLiveStep(kind: .build, object: "swift build", passed: true),
        ],
        "t-payload": [
            AgentLiveStep(kind: .test, object: "swift test", passed: false),
            AgentLiveStep(kind: .read, object: "PayloadCompiler.swift"),
            AgentLiveStep(kind: .subagent, object: "Find every caller of compile(_:)"),
            AgentLiveStep(kind: .edit, object: "PayloadCompiler.swift", added: 6, removed: 2),
            AgentLiveStep(kind: .test, object: "swift test", passed: true),
        ],
        "t-launch": [
            AgentLiveStep(kind: .fetch, object: "linear.app/method"),
            AgentLiveStep(kind: .fetch, object: "raycast.com"),
            AgentLiveStep(kind: .web, object: "notch app landing pages"),
            AgentLiveStep(kind: .create, object: "hero.md", added: 18, removed: 0),
        ],
    ]
}

extension AgentWork {
    /// A step from the beat's own kind and object, for a session with no stream of its own.
    func liveStep(_ object: String?) -> AgentLiveStep? {
        switch self {
        case .reading: return AgentLiveStep(kind: .read, object: object)
        case .editing: return AgentLiveStep(kind: .edit, object: object)
        case .running: return AgentLiveStep(kind: .run, object: object)
        case .browsing: return AgentLiveStep(kind: .fetch, object: object)
        case .thinking: return AgentLiveStep(kind: .think)
        case .asking, .done, .failed: return nil
        }
    }
}

extension WorkbenchModel {
    /// The steps a working session reports, in order.
    func v2LiveSequence(_ task: AgentTaskItem) -> [AgentLiveStep] {
        if let request = v2Requests[task.id] { return request.liveSteps }
        if let steps = AgentBoard.liveSteps[task.id] { return steps }
        return task.work.liveStep(task.object).map { [$0] } ?? []
    }

    /// The step a working session is on now, which of its steps it is, and whether its result is in.
    /// Each step takes two ticks from the session's start, three with a result (the last showing
    /// it). Oct 21, Ryan ("simpler is better"): it moves on as the session works and stays on its
    /// last step until the answer comes; it no longer loops through the steps. A session with no
    /// start (a sample) shows its last. Snapshots hold the first step with a result.
    func v2LiveStep(_ task: AgentTaskItem) -> (index: Int, step: AgentLiveStep, showsResult: Bool)? {
        guard task.state == .working, !task.statusUnknown, !task.stopped else { return nil }
        let steps = v2LiveSequence(task)
        guard !steps.isEmpty else { return nil }
        if snapshotMode {
            let i = steps.firstIndex(where: \.hasResult) ?? 0
            return (i, steps[i], steps[i].hasResult)
        }
        // The clock that moves it on (`startLiveSteps`).
        _ = v2LiveTick
        let last = (steps.count - 1, steps[steps.count - 1], steps[steps.count - 1].hasResult)
        guard let start = v2Started[task.id] else { return last }
        var t = Int(max(0, Date().timeIntervalSince(start)) / WorkbenchTokens.Steps.tick)
        for (i, step) in steps.enumerated() {
            let n = step.hasResult ? 3 : 2
            if t < n { return (i, step, step.hasResult && t == n - 1) }
            t -= n
        }
        return last
    }

    /// The tick the steps move on, while the workbench runs (not in snapshots).
    func startLiveSteps() {
        guard !snapshotMode, liveStepClock == nil else { return }
        liveStepClock = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(WorkbenchTokens.Steps.tick))
                guard let self else { return }
                // Oct 21, perf: unanimated while the island is off the screen (`islandOffScreen`).
                self.withIslandAnimation(WorkbenchTokens.Steps.change) { self.v2LiveTick += 1 }
            }
        }
    }
}

/// One step, in a line: its glyph, what it is doing and to what, and when it ended, the edit's
/// lines or the command's outcome. A new step crossfades with the last (Oct 21, Ryan, "simpler is
/// better": it pushed the last one up and out).
struct V2StepLine: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    var size: CGFloat = 13
    var glyph = true
    /// Two lines, centred (the Desk's cards): the end cut off rather than the middle.
    var lines = 1
    var alignment: Alignment = .leading

    var body: some View {
        let S = WorkbenchTokens.Steps.self
        ZStack(alignment: alignment) {
            if let live = model.v2LiveStep(task) {
                HStack(spacing: 6) {
                    if glyph {
                        Image(systemName: live.step.kind.symbol)
                            .font(.system(size: size - 1.5, weight: .medium))
                            .foregroundStyle(S.glyph)
                            .frame(width: size + 2)
                    }
                    text(live.step, showsResult: live.showsResult)
                        .lineLimit(lines)
                        .truncationMode(lines > 1 ? .tail : .middle)
                        .multilineTextAlignment(alignment == .center ? .center : .leading)
                        .fixedSize(horizontal: false, vertical: lines > 1)
                }
                .id(live.index)
                .transition(.opacity)
                .accessibilityElement(children: .combine)
            } else {
                Text(task.project).font(.system(size: size)).foregroundStyle(S.verb).lineLimit(1)
            }
        }
        .clipped()
        .animation(model.snapshotMode ? nil : S.change, value: model.v2LiveStep(task)?.index)
    }

    private func text(_ step: AgentLiveStep, showsResult: Bool) -> Text {
        let S = WorkbenchTokens.Steps.self
        var line = Text(step.kind.verb).font(.system(size: size)).foregroundColor(S.verb)
        if let object = step.kind == .search ? step.object.map({ "\u{201C}\($0)\u{201D}" }) : step.object {
            line = line + Text(" ") + Text(object)
                .font(step.kind.codeObject ? .system(size: size - 1, design: .monospaced) : .system(size: size, weight: .medium))
                .foregroundColor(S.object)
        }
        if let done = step.done, let total = step.total {
            line = line + Text("  \(done) of \(total)").font(.system(size: size)).foregroundColor(S.verb)
        }
        guard showsResult else { return line }
        if let added = step.added, let removed = step.removed {
            // Only what moved: a file only added to shows +N.
            if added > 0 || removed == 0 {
                line = line + Text("  +\(added)").font(.system(size: size, weight: .medium).monospacedDigit()).foregroundColor(S.added)
            }
            if removed > 0 {
                line = line + Text(added > 0 ? " −\(removed)" : "  −\(removed)").font(.system(size: size, weight: .medium).monospacedDigit())
                    .foregroundColor(S.removed)
            }
        }
        if let passed = step.passed {
            line = line + Text(passed ? "  passed" : "  failed").font(.system(size: size))
                .foregroundColor(passed ? S.verb : WorkbenchTokens.Panel.failedColor)
        }
        return line
    }
}

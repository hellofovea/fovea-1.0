import Foundation
import FoveaKit

// The Agent panel's tasks: the sessions Fovea sent requests to, grouped by the project they
// work in (several agents can work on one project), each with its state and one line of what
// it is doing, on what. A sample, with a script for the working ones so the panel is live;
// docs/island/AGENT_PANEL.md has the reasons.

/// An Agent task's state: the four words of the hover list (AGENTS.md "Agent task").
enum AgentTaskState: Equatable {
    case working, needsYou, complete, failed

    var label: String {
        switch self {
        case .working: return "Working"
        case .needsYou: return "Needs you"
        case .complete: return "Complete"
        case .failed: return "Failed"
        }
    }

    /// The hover list's order: what needs the person first, then what is done, then what is
    /// running, then what failed (PRD §8).
    var rank: Int {
        switch self {
        case .needsYou: return 0
        case .complete: return 1
        case .working: return 2
        case .failed: return 3
        }
    }
}

/// The kind of work an agent is doing right now.
enum AgentWork: Equatable {
    case reading, editing, running, browsing, thinking, asking, done, failed
}

/// What a task waiting on the person wants: a yes or no to a command, or one of a few answers.
enum AgentAsk: Equatable {
    case approval(String)
    case choice([String])
}

/// The yes of an approval as the action's own verb, the way Apple's confirmation snippets label
/// their button (Order, not OK): "swift test --filter X" is Run Tests. Native shows it in place of
/// Allow (approved by Yulun, Oct 9; docs/island/NATIVE.md); `short` is for where the long one
/// doesn't fit (a Desk card). Title case, as the system's buttons are.
enum ApprovalVerb {
    static func of(_ command: String) -> (title: String, short: String) {
        let words = command.split(separator: " ").map { $0.lowercased() }.filter { !$0.hasPrefix("-") }
        let tool = words.first ?? ""
        let sub = words.dropFirst().first ?? ""
        // `npm run test`, `pnpm run build`: the script is the action.
        let action = sub == "run" ? (words.dropFirst(2).first ?? "") : sub
        if tool == "rm" || (tool == "git" && sub == "clean") { return (L("Delete"), L("Delete")) }
        if tool == "pytest" || action == "test" || tool == "xcodebuild" && words.contains("test") { return (L("Run Tests"), L("Run")) }
        if action == "build" || tool == "make" || tool == "xcodebuild" { return (L("Build"), L("Build")) }
        if tool == "git" && sub == "push" { return (L("Push"), L("Push")) }
        if tool == "git" && sub == "commit" { return (L("Commit"), L("Commit")) }
        if action == "install" || (action == "add" && ["npm", "pnpm", "yarn", "brew"].contains(tool)) { return (L("Install"), L("Install")) }
        return (L("Run"), L("Run"))
    }
}

/// One delivered request an agent is working on, in one of its sessions.
struct AgentTaskItem: Identifiable, Equatable {
    var id: String
    let agent: String
    /// The session (the Chat) it went to: what the row is called.
    let session: String
    /// The project (folder) the session works in: what the row is grouped under.
    let project: String
    /// The request itself, for the help text.
    let request: String
    var state: AgentTaskState
    /// One line: what it is doing; what it asks; what it did; why it failed. Never a log.
    var activity: String
    var work: AgentWork
    /// The thing it is on: a file, a command, a page.
    var object: String?
    /// What it is producing right now, one line of it: the code it types, the test that just
    /// passed, the page it has open.
    var preview: String?
    var ask: AgentAsk?
    /// Seconds since its activity last changed: the order, and a stall.
    var age: Double
    /// Seconds in its state.
    var inState: Double
    /// Stopped by the person: shown as Stopped, quietly, not as a failure.
    var stopped = false
    /// What it said when it finished (or why it failed): the reply its card shows. A few lines,
    /// never its steps.
    var reply: String? = nil
    /// Something it wrote for the person to take: a draft to copy.
    var draft: String? = nil
    /// What it made or changed: the files and documents its card links to.
    var artifacts: [String] = []
    /// What it has in front of it, or what it made, as a picture (Dispatch Version 2).
    var screen: AgentScreen? = nil
    /// What it gives back, formatted to read at a glance (Dispatch Version 2's result).
    var result: AgentResult? = nil
    // Feedback, Oct 6 (Feedback/V2Feedback.swift): what the agents really report, in place of a
    // picture of their screen.
    /// Its plan, when it made one (Codex's update_plan, Claude's TodoWrite), and how much is done.
    var plan: [String] = []
    var planDone = 0
    /// The files it changed so far, with lines added and removed.
    var changes: [FileChange] = []
    /// What it did this turn, oldest first: folded under the answer once it is done.
    var steps: [AgentStep] = []
    /// Its final message, as the agent wrote it: Markdown.
    var answer: String? = nil
    /// The model and effort it answered with (or is answering with).
    var modelLabel: String? = nil
    /// Found on the Mac but its state can't be read (a Claude Code session in a terminal, an old
    /// CLI without `claude agents`, a Codex session without hooks): the board says when it was
    /// last active, and nothing more (#17).
    var statusUnknown = false
}

/// A file a session changed: its path and its lines added and removed (Codex's fileChange, Claude
/// Code's Edit/Write results, or `git diff --numstat`).
struct FileChange: Equatable, Identifiable {
    let path: String
    var added: Int
    var removed: Int
    var id: String { path }
    var name: String { (path as NSString).lastPathComponent }
}

/// One thing a session did: its kind and the thing it was on.
struct AgentStep: Equatable, Identifiable {
    let id: Int
    let work: AgentWork
    let object: String?
    let activity: String
}

/// A line of the file an agent edits: its number, the code, and how it changed.
struct AgentCodeLine: Equatable {
    enum Change { case same, removed, added, typing }
    let number: Int
    let text: String
    var change: Change = .same
}

/// What a session gives back, shaped to be read at a glance: the outcome in one sentence first;
/// then what fits it: a few points, the terms of what was asked about, rows of data, a draft to
/// take, what it made; and what needs the person's eyes. Rewritten from the agent's last message
/// by a small model; the full reply stays in the agent's app.
struct AgentResult: Equatable {
    var outcome: String
    var points: [String] = []
    var terms: [AgentResultTerm] = []
    var rows: [AgentResultRow] = []
    /// One more line, in plain words.
    var plainly: String? = nil
    var draft: String? = nil
    var artifacts: [String] = []
    var attention: [String] = []
    /// The referent the person circled heads the card: the answer is about it.
    var anchored = false
}

/// A term of what was asked about (a formula's symbol) and what it means.
struct AgentResultTerm: Equatable, Identifiable {
    let term: String
    let meaning: String
    var id: String { term }
}

/// A row of data: when or what first (aligned), then what, then where, and its one action.
struct AgentResultRow: Equatable, Identifiable {
    let lead: String
    let text: String
    var detail: String? = nil
    var action: String? = nil
    var id: String { lead + text }
}

/// One beat of a working task's script: what it does next.
struct AgentBeat {
    let activity: String
    let work: AgentWork
    var object: String? = nil
    var preview: String? = nil
    var state: AgentTaskState = .working
    var ask: AgentAsk? = nil
    var reply: String? = nil
    var draft: String? = nil
    var artifacts: [String] = []
    var screen: AgentScreen? = nil
    var result: AgentResult? = nil
}

/// One project's tasks, in the panel's order.
struct AgentProjectGroup: Identifiable, Equatable {
    let project: String
    let tasks: [AgentTaskItem]
    var id: String { project }
}

enum AgentBoard {
    /// The sample: three projects; Claude Code, Codex and Cursor in this one; two sessions
    /// waiting on the person, two done, four working (one of them gone quiet), one failed; more
    /// than the five rows the panel shows at once.
    static let tasks: [AgentTaskItem] = [
        AgentTaskItem(id: "t-paste", agent: "claude-code", session: "Paste not found countdown", project: "app-ui-v1",
                      request: "Make the countdown pause while the pointer is on the bar, and test it.",
                      state: .needsYou, activity: "Run swift test --filter PasteNotFound?", work: .asking,
                      object: "swift test --filter PasteNotFound", preview: nil,
                      ask: .approval("swift test --filter PasteNotFound"), age: 190, inState: 190,
                      plan: ["Pause the countdown on hover", "Resume it when the pointer leaves", "Test it"], planDone: 2),
        AgentTaskItem(id: "t-snapshots", agent: "codex", session: "Snapshot tests", project: "app-ui-v1",
                      request: "Find out why two snapshot tests fail on CI only, and fix them.",
                      state: .complete, activity: "Fixed the two flaky snapshot tests", work: .done,
                      object: "SnapshotTests.swift", preview: nil, ask: nil, age: 600, inState: 600,
                      reply: "Both pass on CI now: they compared a 2x baseline on CI's 1x runner, and render at a fixed scale instead.",
                      artifacts: ["SnapshotTests.swift"]),
        AgentTaskItem(id: "t-shortcuts", agent: "codex", session: "Shortcuts recorder", project: "app-ui-v1",
                      request: "Let people record a shortcut by pressing it, and save it as they do.",
                      state: .working, activity: "Editing ShortcutRecorder.swift", work: .editing,
                      object: "ShortcutRecorder.swift", preview: "recorder.onChange { shortcut in store.save(shortcut) }",
                      ask: nil, age: 20, inState: 300,
                      plan: ["Read the recorder", "Record on key down", "Save as it records", "Build"], planDone: 2),
        AgentTaskItem(id: "t-capture", agent: "codex", session: "ScreenCaptureKit capture", project: "fovea-mac",
                      request: "Move the capture path to ScreenCaptureKit.",
                      state: .needsYou, activity: "Keep the old capture path behind a flag?", work: .asking,
                      object: nil, preview: nil, ask: .choice(["Keep", "Remove"]), age: 260, inState: 260,
                      plan: ["Read the capture path", "Capture with ScreenCaptureKit", "Retire the old path", "Test on two displays"],
                      planDone: 2),
        AgentTaskItem(id: "t-payload", agent: "claude-code", session: "Payload compiler", project: "fovea-mac",
                      request: "Order the referents by draw order in the payload, and cover it with tests.",
                      state: .working, activity: "Running swift test", work: .running,
                      object: "swift test", preview: "✓ PayloadTests.ordersReferentsByDrawOrder",
                      ask: nil, age: 30, inState: 900,
                      plan: ["Find why the order test fails", "Order by draw order", "Cover it with tests"], planDone: 1),
        AgentTaskItem(id: "t-locale", agent: "codex", session: "Speech locale fallback", project: "fovea-mac",
                      request: "Fall back to English when the system locale has no speech model.",
                      state: .working, activity: "Reading SpeechTranscriber.swift", work: .reading,
                      object: "SpeechTranscriber.swift", preview: "let locale = Locale.current.language",
                      ask: nil, age: 420, inState: 1260),
        AgentTaskItem(id: "t-fnkey", agent: "claude-code", session: "fn key press-to-toggle", project: "fovea-mac",
                      request: "Make fn press-to-toggle: one press starts, the next stops.",
                      state: .failed, activity: "Build failed in HotkeyMonitor.swift", work: .failed,
                      object: "HotkeyMonitor.swift:48", preview: "error: cannot find 'flagsChanged' in scope",
                      ask: nil, age: 3400, inState: 3400,
                      reply: "The build stops at HotkeyMonitor.swift:48: flagsChanged isn't in scope in the monitor's closure.",
                      plan: ["Read the monitor", "Toggle on each press", "Build", "Test the toggle"], planDone: 2),
        AgentTaskItem(id: "t-launch", agent: "claude-code", session: "Launch copy", project: "Futuro",
                      request: "Draft the hero copy from these three competitor pages.",
                      state: .working, activity: "Reading linear.app/method", work: .browsing,
                      object: "linear.app/method", preview: "Linear Method: practices for building software",
                      ask: nil, age: 70, inState: 2100,
                      plan: ["Read the three pages", "Note what each leads with", "Find what none of them says", "Draft the headline",
                             "Draft the subhead"], planDone: 3),
        AgentTaskItem(id: "t-docs", agent: "claude-code", session: "Docs link check", project: "fovea-site",
                      request: "Check every link in the docs and fix the broken ones.",
                      state: .working, activity: "", work: .reading, object: nil, preview: nil, ask: nil,
                      age: 7200, inState: 7200, statusUnknown: true),
        AgentTaskItem(id: "t-tokens", agent: "codex", session: "Token audit", project: "fovea-mac",
                      request: "List every hard-coded color outside Tokens.swift.",
                      state: .working, activity: "", work: .reading, object: nil, preview: nil, ask: nil,
                      age: 2700, inState: 2700, statusUnknown: true),
        AgentTaskItem(id: "t-hero", agent: "claude-code", session: "Marketing site hero", project: "Futuro",
                      request: "Tighten the hero headline and subhead.",
                      state: .complete, activity: "Rewrote the headline and subhead", work: .done,
                      object: "Hero.tsx", preview: nil, ask: nil, age: 2200, inState: 2200,
                      reply: "The headline is now \u{201C}Point at it. Say it. It\u{2019}s sent.\u{201D} and the subhead fits on one line.",
                      artifacts: ["Hero.tsx"]),
    ]

    /// The working tasks' scripts: each loops through its beats so the panel is alive.
    static let scripts: [String: [AgentBeat]] = [
        "t-shortcuts": [
            AgentBeat(activity: "Editing ShortcutRecorder.swift", work: .editing, object: "ShortcutRecorder.swift",
                      preview: "recorder.onChange { shortcut in store.save(shortcut) }"),
            AgentBeat(activity: "Reading ShortcutStore.swift", work: .reading, object: "ShortcutStore.swift",
                      preview: "func save(_ shortcut: Shortcut) throws"),
            AgentBeat(activity: "Editing ShortcutRecorder.swift", work: .editing, object: "ShortcutRecorder.swift",
                      preview: "if event.modifierFlags.isEmpty { return }"),
            AgentBeat(activity: "Running swift build", work: .running, object: "swift build",
                      preview: "Compiling ShortcutRecorder.swift"),
        ],
        "t-payload": [
            AgentBeat(activity: "Running swift test", work: .running, object: "swift test",
                      preview: "✓ PayloadTests.ordersReferentsByDrawOrder"),
            AgentBeat(activity: "Running swift test", work: .running, object: "swift test",
                      preview: "✓ PayloadTests.keepsTheIntentVerbatim"),
            AgentBeat(activity: "Editing PayloadCompiler.swift", work: .editing, object: "PayloadCompiler.swift",
                      preview: "referents.sorted { $0.index < $1.index }"),
        ],
        "t-launch": [
            AgentBeat(activity: "Reading linear.app/method", work: .browsing, object: "linear.app/method",
                      preview: "Linear Method: practices for building software"),
            AgentBeat(activity: "Reading raycast.com", work: .browsing, object: "raycast.com",
                      preview: "Your shortcut to everything"),
            AgentBeat(activity: "Editing hero.md", work: .editing, object: "hero.md",
                      preview: "Point at it. Say it. It's sent."),
        ],
    ]

    /// A request just sent from Choose chat: it reads the request, edits, builds, and is done.
    static func sentScript() -> [AgentBeat] {
        [
            AgentBeat(activity: "Reading your request", work: .reading, object: "2 screenshots",
                      preview: "Make the ears on this one match the menu bar's height"),
            AgentBeat(activity: "Editing IslandShape.swift", work: .editing, object: "IslandShape.swift",
                      preview: "let earHeight = metrics.menuBarHeight"),
            AgentBeat(activity: "Editing NotchGeometry.swift", work: .editing, object: "NotchGeometry.swift",
                      preview: "spacing: referents[1].spacing"),
            AgentBeat(activity: "Running swift build", work: .running, object: "swift build",
                      preview: "Compiling NotchGeometry.swift"),
            AgentBeat(activity: "Matched the ears to the menu bar", work: .done, object: "IslandShape.swift",
                      state: .complete,
                      reply: "The ears now match the menu bar's height, with the second screenshot's spacing. Full screen, they keep the black band's height.",
                      artifacts: ["IslandShape.swift", "NotchGeometry.swift"]),
        ]
    }

    /// How long, for the time in state: minutes, then hours; nothing under a minute.
    static func duration(_ seconds: Double) -> String? {
        let minutes = Int(seconds / 60)
        if minutes < 1 { return nil }
        // Oct 18, Ryan: in the primary language ("5m", "5 分钟").
        return minutes < 60 ? L("\(minutes)m") : L("\(minutes / 60)h")
    }

    /// A project's order: state first, then the latest to reach it (so rows don't swap places
    /// each time an activity line changes).
    static func sorted(_ tasks: [AgentTaskItem]) -> [AgentTaskItem] {
        tasks.sorted {
            if $0.state.rank != $1.state.rank { return $0.state.rank < $1.state.rank }
            if $0.inState != $1.inState { return $0.inState < $1.inState }
            return $0.id < $1.id
        }
    }

    /// The panel's groups: each project's tasks in order; the project with the most pressing
    /// task first (then the most recent), so what needs the person stays on top.
    static func grouped(_ tasks: [AgentTaskItem]) -> [AgentProjectGroup] {
        let projects = Dictionary(grouping: tasks, by: \.project)
        return projects.map { AgentProjectGroup(project: $0.key, tasks: sorted($0.value)) }
            .sorted { a, b in
                let x = a.tasks[0], y = b.tasks[0]
                if x.state.rank != y.state.rank { return x.state.rank < y.state.rank }
                if x.inState != y.inState { return x.inState < y.inState }
                return a.project < b.project
            }
    }
}

extension AgentTaskItem {
    /// The same session under another id (Fovea's preview of the board).
    func renamed(_ id: String) -> AgentTaskItem {
        var copy = self
        copy.id = id
        return copy
    }
}

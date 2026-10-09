import Foundation

// The window's object model: Projects hold Threads, Threads hold Runs. A Run is one thing you
// asked an agent to do; a Capture is what you pointed at or said on the way. Nothing here is
// written by Fovea in prose: every line the window shows is computed from these fields, except
// the agent's own sentence and a Brief, which the agent writes and signs.

public enum AgentKind: String, Codable, CaseIterable, Hashable, Sendable {
    case claudeCode, codex, cursor, gemini

    public var name: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        case .gemini: return "Gemini CLI"
        }
    }
}

/// The six states, each drawn by shape (brief §2): ● waiting for you · ! failed ·
/// ○ finished, not yet seen · ◌ running · nothing once seen · a dashed circle when Fovea
/// handed the run to a session it can't watch.
public enum RunState: String, Codable, CaseIterable, Hashable, Sendable {
    case waiting, failed, finished, running, unobserved, seen

    /// Most urgent first: what a project's or a thread's glyph shows.
    public var urgency: Int {
        switch self {
        case .waiting: return 0
        case .failed: return 1
        case .finished: return 2
        case .running: return 3
        case .unobserved: return 4
        case .seen: return 5
        }
    }

    /// The notch's word for the state (Words + tint and Glyph + word styles).
    public var word: String {
        switch self {
        case .waiting: return "Needs you"
        case .failed: return "Failed"
        case .finished: return "Complete"
        case .running: return "Working"
        case .unobserved: return "Can't see"
        case .seen: return "Seen"
        }
    }

    /// What VoiceOver reads for the glyph.
    public var accessibilityLabel: String {
        switch self {
        case .waiting: return "Waiting for you"
        case .failed: return "Failed"
        case .finished: return "Finished, not yet seen"
        case .running: return "Running"
        case .unobserved: return "Fovea can't see this run"
        case .seen: return "Seen"
        }
    }
}

public enum ChangeKind: String, Codable, Hashable, Sendable {
    case added = "A", modified = "M", deleted = "D"
}

public enum DiffLineKind: String, Codable, Hashable, Sendable {
    case context, added, removed
}

/// One line of a hunk. `changed` marks the words that differ from the paired line, as UTF-16
/// offsets (location, length), for the word-emphasis variant.
public struct DiffLine: Codable, Hashable, Sendable {
    public var kind: DiffLineKind
    public var oldNumber: Int?
    public var newNumber: Int?
    public var text: String
    public var changed: [[Int]]

    public init(_ kind: DiffLineKind, old: Int?, new: Int?, _ text: String, changed: [[Int]] = []) {
        self.kind = kind; oldNumber = old; newNumber = new; self.text = text; self.changed = changed
    }
}

public struct DiffHunk: Codable, Hashable, Sendable {
    public var header: String
    public var lines: [DiffLine]
    public init(header: String, lines: [DiffLine]) { self.header = header; self.lines = lines }
}

public struct FileChange: Codable, Hashable, Sendable {
    public var path: String
    public var kind: ChangeKind
    public var added: Int
    public var removed: Int
    public var hunks: [DiffHunk]

    /// With hunks, the counts are the hunks' own lines, so the +/− line never contradicts the
    /// diff under it; without them (a binary file, a change Fovea only counted), as given.
    public init(path: String, kind: ChangeKind = .modified, added: Int, removed: Int, hunks: [DiffHunk] = []) {
        self.path = path; self.kind = kind
        self.hunks = hunks.map { $0.annotated() }
        let lines = hunks.flatMap(\.lines)
        self.added = hunks.isEmpty ? added : lines.filter { $0.kind == .added }.count
        self.removed = hunks.isEmpty ? removed : lines.filter { $0.kind == .removed }.count
    }

    public var fileName: String { (path as NSString).lastPathComponent }
}

public struct CommandResult: Codable, Hashable, Sendable {
    public var command: String
    public var exitCode: Int
    public init(_ command: String, exit: Int = 0) { self.command = command; exitCode = exit }
}

/// What the agent did that Fovea saw, in order.
public enum EvidenceItem: Codable, Hashable, Sendable {
    case edit(FileChange)
    case command(CommandResult)
    case search(String)
    case read(String)
}

public enum PermissionKind: String, Codable, Hashable, Sendable {
    case command, diff, url
}

/// Why a run waits for you.
public enum StuckReason: Codable, Hashable, Sendable {
    case permission(PermissionKind, raw: String)
    case question(String, options: [String])
}

public struct Failure: Codable, Hashable, Sendable {
    public var command: String
    public var exitCode: Int
    /// The last lines of the command's own output, as it printed them.
    public var tail: String
    public init(command: String, exitCode: Int, tail: String) {
        self.command = command; self.exitCode = exitCode; self.tail = tail
    }
}

/// What a finished run produced, by where it lives.
public enum RunResult: Codable, Hashable, Sendable {
    /// Files changed; the diff comes from the run's edits.
    case code
    /// A document the agent wrote, rendered as typeset text.
    case text(String)
    /// An image (a bundled resource path, e.g. `Photos/mountain.jpg`).
    case image(String, caption: String)
    /// Something that lives in another app: a calendar event, an email draft, a web page, a Figma file.
    case external(app: String, title: String, detail: String)
    case none
}

/// An earlier try at the same request, folded above the current one.
public struct Attempt: Codable, Hashable, Sendable {
    public var number: Int
    public var started: Date
    /// Computed from that attempt's evidence, like a run row's line.
    public var line: String
    public init(number: Int, started: Date, line: String) { self.number = number; self.started = started; self.line = line }
}

public struct Run: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var threadID: String
    /// What you said, verbatim.
    public var words: String
    public var state: RunState
    public var stuck: StuckReason?
    public var failure: Failure?
    public var evidence: [EvidenceItem]
    /// ▲ What differs from what you asked, at most three; the only emphasized content on a run.
    public var differences: [String]
    /// The agent's one sentence about what it did, signed with the agent's name.
    public var agentLine: String?
    public var started: Date
    public var finished: Date?
    public var attempt: Int
    public var earlierAttempts: [Attempt]
    public var captureIDs: [String]
    public var result: RunResult
    /// The agent's raw output, shown as received in a collapsed disclosure.
    public var output: String?
    /// While running: the last actions Fovea saw, newest last.
    public var lastActions: [String]
    /// 过 was pressed: the verdict log's entry.
    public var reviewed: Bool

    public init(id: String, threadID: String, words: String, state: RunState, stuck: StuckReason? = nil,
                failure: Failure? = nil, evidence: [EvidenceItem] = [], differences: [String] = [],
                agentLine: String? = nil, started: Date, finished: Date? = nil, attempt: Int = 1,
                earlierAttempts: [Attempt] = [], captureIDs: [String] = [], result: RunResult = .none,
                output: String? = nil, lastActions: [String] = [], reviewed: Bool = false) {
        self.id = id; self.threadID = threadID; self.words = words; self.state = state; self.stuck = stuck
        self.failure = failure; self.evidence = evidence; self.differences = differences
        self.agentLine = agentLine; self.started = started; self.finished = finished; self.attempt = attempt
        self.earlierAttempts = earlierAttempts; self.captureIDs = captureIDs; self.result = result
        self.output = output; self.lastActions = lastActions; self.reviewed = reviewed
    }

    public var edits: [FileChange] {
        evidence.compactMap { if case .edit(let change) = $0 { return change } else { return nil } }
    }

    public var commands: [CommandResult] {
        evidence.compactMap { if case .command(let result) = $0 { return result } else { return nil } }
    }

    public var lastActivity: Date { finished ?? started }
}

/// A value Fovea inferred, shown with a dotted underline and correctable in place (7c).
public struct Inference: Codable, Hashable, Sendable {
    /// The computed sentence, e.g. "dispatched to Codex · 12 copy tasks here went to it".
    public var text: String
    /// Where it came from, in mono, shown in the correction popover.
    public var source: String
    public var alternatives: [String]
    public init(text: String, source: String, alternatives: [String]) {
        self.text = text; self.source = source; self.alternatives = alternatives
    }
}

/// A conversation inside an agent that runs land in (AGENTS.md's Chat).
public struct ProjectThread: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var projectID: String
    public var name: String
    public var agent: AgentKind
    public var routing: Inference
    /// False when Fovea handed the thread to a session it can't watch: its runs are unobserved
    /// and it can't ask for a Brief.
    public var observable: Bool
    /// Runs in other projects that belong to this conversation, shown as ↗ rows.
    public var references: [String]

    public init(id: String, projectID: String, name: String, agent: AgentKind, routing: Inference,
                observable: Bool = true, references: [String] = []) {
        self.id = id; self.projectID = projectID; self.name = name; self.agent = agent
        self.routing = routing; self.observable = observable; self.references = references
    }

    /// `第二屏文案 · Codex`
    public var title: String { "\(name) · \(agent.name)" }
}

public struct Project: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    /// The folders or repositories the project's runs worked in.
    public var paths: [String]
    public var lastVisit: Date?
    /// Set for a project the history scan found: counts from folder listings, no runs.
    public var scan: ScanInfo?
    public init(id: String, name: String, paths: [String], lastVisit: Date? = nil) {
        self.id = id; self.name = name; self.paths = paths; self.lastVisit = lastVisit
    }
}

/// What a history scan knows about a project without opening a session.
public struct ScanInfo: Codable, Hashable, Sendable {
    public var sessions: Int
    public var agents: [AgentKind]
    public var lastActive: Date
    public init(sessions: Int, agents: [AgentKind], lastActive: Date) {
        self.sessions = sessions; self.agents = agents; self.lastActive = lastActive
    }
}

public enum CaptureKind: String, Codable, CaseIterable, Hashable, Sendable {
    case screenshot, selection, voice, file

    public var title: String {
        switch self {
        case .screenshot: return "Screenshots"
        case .selection: return "Selections"
        case .voice: return "Voice"
        case .file: return "Files"
        }
    }
}

public enum CapturePreview: Codable, Hashable, Sendable {
    /// A bundled image path, e.g. `Screens/fovea-home.png`.
    case image(String)
    case text(String)
    case voice(seconds: Double)
    case file(name: String, kind: String)
}

public enum CaptureDestination: Codable, Hashable, Sendable {
    case run(String)
    case quickTask
    case notUsed
}

/// One capture: what you pointed at or said, where it went, and why.
public struct Capture: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var kind: CaptureKind
    public var time: Date
    public var sourceApp: String?
    public var windowTitle: String?
    /// What you said with it, verbatim.
    public var transcript: String
    public var preview: CapturePreview
    public var destination: CaptureDestination
    /// Why it went where it went, e.g. "the frontmost window was localhost:3000".
    public var reason: Inference?
    /// Text recognized inside a screenshot; searchable, never shown as prose.
    public var recognizedText: String?

    public init(id: String, kind: CaptureKind, time: Date, sourceApp: String?, windowTitle: String? = nil,
                transcript: String, preview: CapturePreview, destination: CaptureDestination,
                reason: Inference? = nil, recognizedText: String? = nil) {
        self.id = id; self.kind = kind; self.time = time; self.sourceApp = sourceApp
        self.windowTitle = windowTitle; self.transcript = transcript; self.preview = preview
        self.destination = destination; self.reason = reason; self.recognizedText = recognizedText
    }
}

public enum ConnectionState: String, Codable, Hashable, Sendable {
    case connected, hooksMissing, notFound

    public var title: String {
        switch self {
        case .connected: return "Connected"
        case .hooksMissing: return "Hooks not installed"
        case .notFound: return "Not found"
        }
    }
}

/// Why the scan couldn't list a history folder. Drawn dashed: Fovea can't see into it.
public enum FolderReadError: String, Codable, Hashable, Sendable {
    case notFound, denied

    /// The mono line: `no such folder`, `permission denied`.
    public var line: String {
        switch self {
        case .notFound: return "no such folder"
        case .denied: return "permission denied"
        }
    }
}

public struct AgentConnection: Identifiable, Codable, Hashable, Sendable {
    public var kind: AgentKind
    public var state: ConnectionState
    public var version: String?
    public var binaryPath: String?
    public var lastEvent: Date?
    /// The exact file installing hooks changes.
    public var hooksFile: String
    /// What installing adds to that file, verbatim.
    public var hooksText: String
    /// The folders history import reads for this agent.
    public var historyFolders: [String]
    public var historyAccess: Bool
    /// History folders the last scan couldn't list, by path as shown.
    public var historyReadErrors: [String: FolderReadError] = [:]

    public var id: String { kind.rawValue }

    public init(kind: AgentKind, state: ConnectionState, version: String?, binaryPath: String?,
                lastEvent: Date?, hooksFile: String, hooksText: String, historyFolders: [String],
                historyAccess: Bool = true) {
        self.kind = kind; self.state = state; self.version = version; self.binaryPath = binaryPath
        self.lastEvent = lastEvent; self.hooksFile = hooksFile; self.hooksText = hooksText
        self.historyFolders = historyFolders; self.historyAccess = historyAccess
    }
}

public enum MemoryKind: String, Codable, Hashable, Sendable {
    case term, memory
}

/// Something Fovea keeps because you said it: a term ("主仓" = api-server) or a preference.
public struct MemoryItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var kind: MemoryKind
    public var content: String
    public var sourceDate: Date
    /// Your words it came from, verbatim.
    public var sourceQuote: String
    /// A project's name, or nil for Global.
    public var scope: String?

    public init(id: String, kind: MemoryKind, content: String, sourceDate: Date, sourceQuote: String, scope: String? = nil) {
        self.id = id; self.kind = kind; self.content = content; self.sourceDate = sourceDate
        self.sourceQuote = sourceQuote; self.scope = scope
    }
}

/// Two projects that look like one, with the evidence; onboarding never merges on its own.
/// One reason two projects look like one: what matched (`same repo`) and the matching value
/// (`~/code/fovea-site`). Both computed, so both mono; the labels line up as a column.
public struct MergeEvidence: Codable, Hashable, Sendable {
    public var label: String
    public var value: String
    public init(_ label: String, _ value: String) { self.label = label; self.value = value }
}

public struct MergeSuggestion: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var first: String
    public var second: String
    public var evidence: [MergeEvidence]
    public init(id: String, first: String, second: String, evidence: [MergeEvidence]) {
        self.id = id; self.first = first; self.second = second; self.evidence = evidence
    }
}

/// A Brief: written by an agent on request, signed, rendered as received.
public struct BriefDoc: Codable, Hashable, Sendable {
    public var agent: AgentKind
    public var written: Date
    public var markdown: String
    public init(agent: AgentKind, written: Date, markdown: String) {
        self.agent = agent; self.written = written; self.markdown = markdown
    }
}

/// Everything the window shows.
public struct Library: Codable, Hashable, Sendable {
    public var now: Date
    public var projects: [Project]
    public var threads: [ProjectThread]
    public var runs: [Run]
    public var captures: [Capture]
    public var agents: [AgentConnection]
    public var memory: [MemoryItem]
    public var merges: [MergeSuggestion]
    /// Briefs the agents wrote, by project id.
    public var briefs: [String: BriefDoc]

    public init(now: Date, projects: [Project] = [], threads: [ProjectThread] = [], runs: [Run] = [],
                captures: [Capture] = [], agents: [AgentConnection] = [], memory: [MemoryItem] = [],
                merges: [MergeSuggestion] = [], briefs: [String: BriefDoc] = [:]) {
        self.now = now; self.projects = projects; self.threads = threads; self.runs = runs
        self.captures = captures; self.agents = agents; self.memory = memory; self.merges = merges
        self.briefs = briefs
    }
}

/// Lookups over a library, built once per change.
public struct LibraryIndex: Sendable {
    public let library: Library
    public let projectByID: [String: Project]
    public let threadByID: [String: ProjectThread]
    public let runByID: [String: Run]
    public let captureByID: [String: Capture]
    /// A project's threads in library order.
    public let threadsByProject: [String: [ProjectThread]]
    /// A thread's runs, newest first.
    public let runsByThread: [String: [Run]]

    public init(_ library: Library) {
        self.library = library
        projectByID = Dictionary(library.projects.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        threadByID = Dictionary(library.threads.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        runByID = Dictionary(library.runs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        captureByID = Dictionary(library.captures.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        threadsByProject = Dictionary(grouping: library.threads, by: \.projectID)
        runsByThread = Dictionary(grouping: library.runs, by: \.threadID)
            .mapValues { $0.sorted { $0.started > $1.started } }
    }

    public var now: Date { library.now }

    public func threads(in projectID: String) -> [ProjectThread] { threadsByProject[projectID] ?? [] }
    public func runs(in threadID: String) -> [Run] { runsByThread[threadID] ?? [] }
    public func runs(inProject projectID: String) -> [Run] { threads(in: projectID).flatMap { runs(in: $0.id) } }
    public func thread(of run: Run) -> ProjectThread? { threadByID[run.threadID] }
    public func project(of run: Run) -> Project? { thread(of: run).flatMap { projectByID[$0.projectID] } }

    /// The runs a capture went to or was used by.
    public func runs(using captureID: String) -> [Run] {
        library.runs.filter { $0.captureIDs.contains(captureID) }
    }

    public func agent(_ kind: AgentKind) -> AgentConnection? { library.agents.first { $0.kind == kind } }
}

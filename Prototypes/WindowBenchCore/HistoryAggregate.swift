import Foundation

/// One session file the scan found. The scan lists folders and reads modification dates only:
/// it never opens a session, so a session knows its project only when the folder name says it
/// (Claude Code keeps one folder per working directory).
public struct SessionRecord: Hashable, Sendable {
    public var agent: AgentKind
    /// The working directory, when the folder name decodes to one.
    public var projectPath: String?
    /// What to call the project: the directory's name, or the raw folder name if it didn't decode.
    public var projectName: String?
    public var modified: Date

    public init(agent: AgentKind, projectPath: String? = nil, projectName: String? = nil, modified: Date) {
        self.agent = agent; self.projectPath = projectPath; self.projectName = projectName; self.modified = modified
    }
}

public struct ScannedProject: Identifiable, Hashable, Sendable {
    public var name: String
    public var path: String?
    public var sessions: Int
    public var agents: [AgentKind]
    public var lastActive: Date
    public var id: String { name }
}

public struct HistorySummary: Hashable, Sendable {
    /// Sessions active in the window.
    public var sessions: Int
    public var agents: [AgentKind]
    public var projects: [ScannedProject]
    /// Sessions whose project the scan can't tell without opening them, by agent.
    public var unattributed: [AgentKind: Int]
    /// Sessions per agent.
    public var perAgent: [AgentKind: Int]
    /// Folders the scan couldn't list, by path as shown (`~/.cursor/chats`).
    public var readErrors: [String: FolderReadError] = [:]
}

public enum HistoryAggregate {
    /// Only sessions active in the last 30 days.
    public static let window: TimeInterval = 30 * 86_400

    public static func summarize(_ records: [SessionRecord], now: Date) -> HistorySummary {
        let recent = records.filter { now.timeIntervalSince($0.modified) <= window && $0.modified <= now.addingTimeInterval(60) }
        var agents: [AgentKind] = []
        for kind in AgentKind.allCases where recent.contains(where: { $0.agent == kind }) { agents.append(kind) }
        var byName: [String: ScannedProject] = [:]
        var unattributed: [AgentKind: Int] = [:]
        var perAgent: [AgentKind: Int] = [:]
        for record in recent {
            perAgent[record.agent, default: 0] += 1
            guard let name = record.projectName else { unattributed[record.agent, default: 0] += 1; continue }
            var project = byName[name] ?? ScannedProject(name: name, path: record.projectPath, sessions: 0, agents: [], lastActive: .distantPast)
            project.sessions += 1
            if !project.agents.contains(record.agent) { project.agents.append(record.agent) }
            project.lastActive = max(project.lastActive, record.modified)
            byName[name] = project
        }
        let projects = byName.values.sorted { $0.lastActive > $1.lastActive }
        return HistorySummary(sessions: recent.count, agents: agents, projects: projects, unattributed: unattributed,
                              perAgent: perAgent)
    }

    /// Claude Code names a project's folder after its working directory with every separator
    /// turned into "-" (`/Users/me/code/app-ui-v1` → `-Users-me-code-app-ui-v1`), which is
    /// ambiguous where names hold "-" themselves. Decodes by asking `exists` which candidate
    /// directories are real, longest name first; falls back to the folder name.
    public static func decodeClaudeFolder(_ name: String, exists: (String) -> Bool) -> (path: String?, display: String) {
        let tokens = name.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard tokens.first == "", tokens.count > 1 else { return (nil, name) }
        let joiners = ["-", " ", ".", "_"]
        var visited = 0

        func walk(_ i: Int, _ path: String) -> String? {
            if i == tokens.count { return path }
            visited += 1
            if visited > 4_000 { return nil }
            for j in stride(from: tokens.count - 1, through: i, by: -1) {
                let parts = Array(tokens[i...j])
                for joiner in (parts.count == 1 ? ["-"] : joiners) {
                    let component = parts.joined(separator: joiner)
                    guard !component.isEmpty else { continue }
                    let candidate = path + "/" + component
                    if exists(candidate), let done = walk(j + 1, candidate) { return done }
                }
            }
            return nil
        }

        if let path = walk(1, "") {
            return (path, (path as NSString).lastPathComponent)
        }
        return (nil, name)
    }

    /// The scanned projects as library projects: no threads or runs (the scan never opens a
    /// session), a scan note instead.
    public static func projects(from summary: HistorySummary) -> [Project] {
        summary.projects.map { scanned in
            var project = Project(id: "scan/\(scanned.name)", name: scanned.name, paths: scanned.path.map { [$0] } ?? [])
            project.scan = ScanInfo(sessions: scanned.sessions, agents: scanned.agents, lastActive: scanned.lastActive)
            return project
        }
    }
}

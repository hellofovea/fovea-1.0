import Foundation
import WindowBenchCore

/// "This Mac": lists the agents' history folders and reads modification dates. It never opens a
/// session file. The folders are the ones the product reads
/// (fovea-mac/FoveaMac/Models/QuickAnswerExternalSessionDirectory.swift), except Codex, which the
/// product reads through `codex app-server`; `~/.codex/sessions` is counted here and flagged.
enum HistoryScanner {
    static func scan() async -> HistorySummary? {
        await Task.detached(priority: .userInitiated) { scanNow() }.value
    }

    /// The scan itself, off the main thread.
    static func scanNow() -> HistorySummary? {
        do {
            let fm = FileManager.default
            let home = fm.homeDirectoryForCurrentUser
            var records: [SessionRecord] = []
            let cutoff = Date().addingTimeInterval(-HistoryAggregate.window)

            func modified(_ url: URL) -> Date? {
                (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            }
            func children(_ url: URL) -> [URL] {
                (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                                             options: [.skipsHiddenFiles])) ?? []
            }
            // A history folder that isn't there, or that can't be listed (permissions, or macOS
            // privacy protection, which only the listing itself reveals), by path as shown.
            var readErrors: [String: FolderReadError] = [:]
            for folder in [".claude/projects", ".codex/sessions", ".cursor/acp-sessions", ".cursor/chats"] {
                let path = home.appendingPathComponent(folder).path
                if !fm.fileExists(atPath: path) {
                    readErrors["~/" + folder] = .notFound
                } else if (try? fm.contentsOfDirectory(atPath: path)) == nil {
                    readErrors["~/" + folder] = .denied
                }
            }

            // Claude Code: one folder per working directory, one .jsonl per session.
            let claude = home.appendingPathComponent(".claude/projects")
            for folder in children(claude) {
                let decoded = HistoryAggregate.decodeClaudeFolder(folder.lastPathComponent) { path in
                    var isDirectory: ObjCBool = false
                    return fm.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
                }
                for file in children(folder) where file.pathExtension == "jsonl" {
                    guard let date = modified(file), date >= cutoff else { continue }
                    records.append(SessionRecord(agent: .claudeCode, projectPath: decoded.path, projectName: decoded.display, modified: date))
                }
            }

            // Codex: rollout files by date; their folder doesn't say the project.
            let codex = home.appendingPathComponent(".codex/sessions")
            if let walker = fm.enumerator(at: codex, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) {
                for case let file as URL in walker where file.pathExtension == "jsonl" {
                    guard let date = modified(file), date >= cutoff else { continue }
                    records.append(SessionRecord(agent: .codex, modified: date))
                }
            }

            // Cursor: a folder per session.
            for sessions in [home.appendingPathComponent(".cursor/acp-sessions")] {
                for session in children(sessions) {
                    guard let date = modified(session), date >= cutoff else { continue }
                    records.append(SessionRecord(agent: .cursor, modified: date))
                }
            }
            for workspace in children(home.appendingPathComponent(".cursor/chats")) {
                for session in children(workspace) {
                    guard let date = modified(session), date >= cutoff else { continue }
                    records.append(SessionRecord(agent: .cursor, modified: date))
                }
            }
            guard !records.isEmpty else { return nil }
            var summary = HistoryAggregate.summarize(records, now: Date())
            summary.readErrors = readErrors
            return summary
        }
    }
}

/// Which agents are on this Mac, by whether their binaries exist at the paths the product looks
/// in (fovea-mac's AgentBridge, CodexAppServerBridge, CursorACPBridge). Nothing is run, so the
/// version stays unknown, and no hooks are Fovea's yet.
enum AgentDetector {
    static func detect() async -> [AgentConnection] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let candidates: [(AgentKind, [String])] = [
            (.claudeCode, ["/opt/homebrew/bin/claude", "/usr/local/bin/claude", "\(home)/.local/bin/claude"]),
            (.codex, ["/Applications/Codex.app/Contents/Resources/codex", "/opt/homebrew/bin/codex", "/usr/local/bin/codex"]),
            (.cursor, ["\(home)/.local/bin/cursor-agent", "/opt/homebrew/bin/cursor-agent", "/usr/local/bin/cursor-agent"]),
        ]
        let fixtures = BenchFixtures.agents()
        return candidates.map { kind, paths in
            let found = paths.first { fm.isExecutableFile(atPath: $0) }
            var agent = fixtures.first { $0.kind == kind }!
            agent.state = found == nil ? .notFound : .hooksMissing
            agent.binaryPath = found.map { $0.replacingOccurrences(of: home, with: "~") }
            agent.version = nil
            agent.lastEvent = nil
            return agent
        }
    }
}

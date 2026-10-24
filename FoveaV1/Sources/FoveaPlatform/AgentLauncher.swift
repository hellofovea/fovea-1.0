import AppKit
import FoveaKit

// Oct 23, Ryan ("include all"): Open in <agent> opens it, for real. Claude Code is a command, so it
// opens in a new Terminal window: the session itself (`claude --resume <id>`) where Fovea knows its
// id, else Claude Code in the session's folder (or the home folder). Codex opens in its app where
// it's installed, else in Terminal the same way. The window comes from a small `.command` file
// Terminal opens (no Automation needed); it runs that one command and nothing else.

public enum AgentLauncher {
    /// Why it couldn't open, in a sentence.
    public enum Failure: Error, Equatable {
        case notInstalled(String)
        case couldntOpen(String)

        public var sentence: String {
            switch self {
            case .notInstalled(let agent): return L("\(agent) isn't on this Mac.")
            case .couldntOpen(let agent): return L("Couldn't open \(agent).")
            }
        }
    }

    /// Opens the agent where the person can carry on: `resume` is the agent's own session id, when
    /// Fovea has it; `folder` is where the session works, when it's a real folder.
    @MainActor
    @discardableResult
    public static func open(_ agent: AgentCLI, resume: String? = nil, folder: URL? = nil) -> Result<Void, Failure> {
        if agent == .codex, resume == nil, let app = codexApp {
            NSWorkspace.shared.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
            return .success(())
        }
        guard let path = AgentCheck.locate(agent.command) else { return .failure(.notInstalled(agent.title)) }
        var line = shellQuoted(path)
        if let resume, !resume.isEmpty {
            line += agent == .claude ? " --resume " + shellQuoted(resume) : " resume " + shellQuoted(resume)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        var isFolder: ObjCBool = false
        let place = folder.flatMap { FileManager.default.fileExists(atPath: $0.path, isDirectory: &isFolder) && isFolder.boolValue ? $0 : nil } ?? home
        let script = "#!/bin/zsh -l\ncd " + shellQuoted(place.path) + " || exit 1\nexec " + line + "\n"
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fovea-open", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(agent.command)-\(UUID().uuidString.prefix(8)).command")
        do {
            try script.write(to: file, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
        } catch {
            return .failure(.couldntOpen(agent.title))
        }
        guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            return .failure(.couldntOpen(agent.title))
        }
        NSWorkspace.shared.open([file], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
        return .success(())
    }

    /// Codex's own app, where it's installed.
    static var codexApp: URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["/Applications/Codex.app", "\(home)/Applications/Codex.app"]
            .map(URL.init(fileURLWithPath:)).first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// One word for the shell, whatever is in it.
    static func shellQuoted(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
}

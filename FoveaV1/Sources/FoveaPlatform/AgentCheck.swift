import Foundation
import FoveaKit

// Oct 15 review, ST-05.2 and ST-06.1: the coding agents on this Mac, found for real. Settings ›
// Connectors asks here which of Claude Code and Codex are installed (on the PATH, or in the places
// their installers put them), their versions (`--version`), and whether they're signed in (Claude
// Code's `claude auth status --json`, Codex's `codex login status`, where they answer). Node, for
// the memory server, is found the same way. Everything runs off the main thread, each command with
// a time limit, and nothing is changed: no command here signs in, installs or writes.

/// A coding agent Fovea sends to (Oct 13: Claude Code and Codex).
public enum AgentCLI: String, CaseIterable, Identifiable, Sendable {
    case claude, codex

    public var id: String { rawValue }
    public var title: String { self == .claude ? "Claude Code" : "Codex" }
    /// The command it's run by.
    public var command: String { rawValue }
    /// What its makers say to paste in Terminal to install it.
    public var installCommand: String {
        switch self {
        case .claude: return "curl -fsSL https://claude.ai/install.sh | bash"
        case .codex: return "npm install -g @openai/codex"
        }
    }
    /// What signs it in, in Terminal.
    public var signInCommand: String { self == .claude ? "claude auth login" : "codex login" }
    /// Its page, for Get It ↗.
    public var page: URL {
        switch self {
        case .claude: return URL(string: "https://docs.claude.com/en/docs/claude-code/setup")!
        case .codex: return URL(string: "https://developers.openai.com/codex/cli")!
        }
    }
}

/// What a check found.
public struct AgentCheckResult: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case ready
        case notInstalled
        case notSignedIn
        case signInExpired
        /// The reason, in a sentence.
        case couldntCheck(String)
    }

    public var agent: AgentCLI
    public var state: State
    /// Where it was found.
    public var path: String?
    /// "2.1.92".
    public var version: String?
    /// Who it's signed in as, where it says ("you@example.com", "ChatGPT").
    public var account: String?

    public init(agent: AgentCLI, state: State, path: String? = nil, version: String? = nil, account: String? = nil) {
        self.agent = agent; self.state = state; self.path = path; self.version = version; self.account = account
    }
}

/// Node.js, found: where, and its version ("v24.15.0").
public struct NodeInstall: Equatable, Sendable {
    public var path: String
    public var version: String?
    public init(path: String, version: String?) { self.path = path; self.version = version }
}

public enum AgentCheck {
    /// How long one command may take before it's given up on.
    public static let timeout: TimeInterval = 6

    /// The places the agents' installers put them, after the PATH (an app opened from the Finder
    /// gets a short PATH, so the person's own isn't enough to go on).
    public static var installPlaces: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["/usr/local/bin", "/opt/homebrew/bin", "\(home)/.local/bin", "\(home)/.claude/local",
                "\(home)/.npm-global/bin", "\(home)/bin", "\(home)/.volta/bin", "\(home)/.bun/bin",
                "\(home)/Library/pnpm", "/opt/local/bin"] + nvmBins
    }

    /// nvm's Node versions, newest first.
    private static var nvmBins: [String] {
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".nvm/versions/node")
        let versions = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        return versions.sorted { $0.compare($1, options: .numeric) == .orderedDescending }
            .map { root.appendingPathComponent($0).appendingPathComponent("bin").path }
    }

    /// The directories searched, in order: the PATH, then the install places.
    public static var searchPath: [String] {
        let path = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        var seen = Set<String>()
        return (path + installPlaces).filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// The first executable of this name.
    public static func locate(_ name: String) -> String? {
        for dir in searchPath {
            let file = (dir as NSString).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: file) { return file }
        }
        return nil
    }

    /// Checks one agent: found, its version, signed in.
    public static func check(_ agent: AgentCLI) async -> AgentCheckResult {
        guard let path = locate(agent.command) else { return AgentCheckResult(agent: agent, state: .notInstalled) }
        guard let out = await run(path, ["--version"]) else {
            return AgentCheckResult(agent: agent, state: .couldntCheck(L("\(agent.title) couldn't be started.")), path: path)
        }
        if out.timedOut {
            return AgentCheckResult(agent: agent, state: .couldntCheck(L("\(agent.title) didn't answer within \(Int(timeout)) seconds.")), path: path)
        }
        let version = Self.version(in: out.stdout + " " + out.stderr)
        guard out.status == 0 else {
            let line = out.stderr.split(separator: "\n").first.map(String.init) ?? L("It stopped with code \(out.status).")
            return AgentCheckResult(agent: agent, state: .couldntCheck(line), path: path, version: version)
        }
        let (state, account) = await signIn(agent, path: path)
        return AgentCheckResult(agent: agent, state: state, path: path, version: version, account: account)
    }

    /// Whether it's signed in, where the agent says. An agent too old to say is taken as ready.
    private static func signIn(_ agent: AgentCLI, path: String) async -> (AgentCheckResult.State, String?) {
        switch agent {
        case .claude:
            guard let out = await run(path, ["auth", "status", "--json"]) else { return (.ready, nil) }
            if out.timedOut {
                return (.couldntCheck(L("Claude Code didn't say whether you're signed in within \(Int(timeout)) seconds.")), nil)
            }
            guard let data = out.stdout.data(using: .utf8),
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                // `auth status` came after 1.0 of Claude Code: no answer isn't a no.
                return (.ready, nil)
            }
            let text = out.stdout.lowercased()
            if (json["expired"] as? Bool) == true || (json["tokenExpired"] as? Bool) == true || text.contains("\"expired\"") {
                return (.signInExpired, nil)
            }
            if (json["loggedIn"] as? Bool) == false { return (.notSignedIn, nil) }
            let account = (json["email"] as? String) ?? (json["emailAddress"] as? String) ?? (json["orgName"] as? String)
            return (.ready, account)
        case .codex:
            guard let out = await run(path, ["login", "status"]) else { return (.ready, nil) }
            if out.timedOut {
                return (.couldntCheck(L("Codex didn't say whether you're signed in within \(Int(timeout)) seconds.")), nil)
            }
            let text = (out.stdout + "\n" + out.stderr).lowercased()
            if text.contains("expired") { return (.signInExpired, nil) }
            if text.contains("not logged in") { return (.notSignedIn, nil) }
            if text.contains("logged in") {
                return (.ready, text.contains("chatgpt") ? "ChatGPT" : (text.contains("api key") ? L("an API key") : nil))
            }
            return (.ready, nil)
        }
    }

    /// Node.js, for the memory server: where, and its version.
    public static func node() async -> NodeInstall? {
        guard let path = locate("node") else { return nil }
        let out = await run(path, ["--version"])
        let version = out.flatMap { $0.timedOut ? nil : $0.stdout.trimmingCharacters(in: .whitespacesAndNewlines) }
        return NodeInstall(path: path, version: version?.isEmpty == false ? version : nil)
    }

    /// Which agents have Fovea's memory server in their settings: Claude Code's `~/.claude.json`
    /// (`mcpServers`) and Codex's `~/.codex/config.toml` (`[mcp_servers.…]`), read, never written.
    public static func memoryServerSetUp() -> Set<AgentCLI> {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var found = Set<AgentCLI>()
        if let data = try? Data(contentsOf: home.appendingPathComponent(".claude.json")),
           let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           let servers = json["mcpServers"] as? [String: Any],
           servers.keys.contains(where: { $0.lowercased().contains("fovea") }) {
            found.insert(.claude)
        }
        if let toml = try? String(contentsOf: home.appendingPathComponent(".codex/config.toml"), encoding: .utf8),
           toml.lowercased().contains("[mcp_servers.fovea") {
            found.insert(.codex)
        }
        return found
    }

    /// The first version number in the text ("2.1.92 (Claude Code)", "codex-cli 0.47.0").
    static func version(in text: String) -> String? {
        guard let range = text.range(of: #"\d+(\.\d+)+"#, options: .regularExpression) else { return nil }
        return String(text[range])
    }

    // MARK: Running a command

    public struct Output: Sendable {
        public var status: Int32
        public var stdout: String
        public var stderr: String
        public var timedOut: Bool
    }

    /// Runs a command off the main thread and waits for it, at most `timeout` seconds (then it's
    /// stopped). Nil when it can't be started. Its PATH has the install places, so a CLI that's a
    /// Node script finds Node.
    public static func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = AgentCheck.timeout) async -> Output? {
        await withCheckedContinuation { (done: CheckedContinuation<Output?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                done.resume(returning: runBlocking(executable, arguments, timeout: timeout))
            }
        }
    }

    private final class Collected: @unchecked Sendable {
        let lock = NSLock()
        var out = Data()
        var err = Data()
    }

    private static func runBlocking(_ executable: String, _ arguments: [String], timeout: TimeInterval) -> Output? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        let dir = (executable as NSString).deletingLastPathComponent
        env["PATH"] = ([dir] + searchPath).joined(separator: ":")
        env["NO_COLOR"] = "1"
        env["TERM"] = "dumb"
        process.environment = env
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch { return nil }

        // Read both pipes as they fill, so a chatty command can't block on a full pipe.
        let collected = Collected()
        let reading = DispatchGroup()
        for (pipe, isOut) in [(out, true), (err, false)] {
            reading.enter()
            DispatchQueue.global(qos: .utility).async {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                collected.lock.lock()
                if isOut { collected.out = data } else { collected.err = data }
                collected.lock.unlock()
                reading.leave()
            }
        }
        if finished.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if finished.wait(timeout: .now() + 1) == .timedOut { kill(process.processIdentifier, SIGKILL) }
            return Output(status: -1, stdout: "", stderr: "", timedOut: true)
        }
        _ = reading.wait(timeout: .now() + 1)
        collected.lock.lock()
        defer { collected.lock.unlock() }
        return Output(status: process.terminationStatus,
                      stdout: String(decoding: collected.out, as: UTF8.self),
                      stderr: String(decoding: collected.err, as: UTF8.self),
                      timedOut: false)
    }
}

import Foundation
import FoveaKit

/// The real send (Oct 8: no mock sendings). Fovea hands the request to the agent on this Mac:
/// Claude Code's command-line tool, run in the practice folder, allowed to edit files there and
/// nothing else (`--permission-mode acceptEdits`, the folder as its working directory). It reports
/// one line of what it's doing (the Island's one line of activity), then its one-sentence reply.
/// A follow-up resumes the same session.
@MainActor
final class AgentRunner {
    enum Event {
        case activity(String)
        case done(reply: String, session: String?)
        case failed(String)
    }

    private var process: Process?
    private var buffer = Data()
    private var finished = true
    private var session: String?
    private var lastText: String?
    private var deadline: DispatchWorkItem?
    private var onEvent: ((Event) -> Void)?

    var isRunning: Bool { !finished }

    func run(executable: URL, prompt: String, folder: URL, resume: String? = nil,
             timeout: TimeInterval = OT.Send.timeout, onEvent: @escaping (Event) -> Void) {
        cancel()
        finished = false
        buffer = Data()
        session = resume
        lastText = nil
        self.onEvent = onEvent

        let process = Process()
        process.executableURL = executable
        var arguments = ["-p", prompt, "--output-format", "stream-json", "--verbose", "--permission-mode", "acceptEdits"]
        if let resume { arguments += ["--resume", resume] }
        process.arguments = arguments
        process.currentDirectoryURL = folder
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        environment["PATH"] = [environment["PATH"] ?? "/usr/bin:/bin", "\(home)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin"]
            .joined(separator: ":")
        process.environment = environment
        let output = Pipe(), errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = FileHandle.nullDevice
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.consume(data) } }
        }
        process.terminationHandler = { [weak self] ended in
            let status = ended.terminationStatus
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    output.fileHandleForReading.readabilityHandler = nil
                    guard let self, !self.finished else { return }
                    if status == 0, let text = self.lastText {
                        self.finish(.done(reply: text, session: self.session))
                    } else {
                        let line = message.split(separator: "\n").last.map(String.init) ?? L("It stopped (\(String(status))).")
                        self.finish(.failed(line))
                    }
                }
            }
        }
        do {
            try process.run()
        } catch {
            finish(.failed(L("Couldn't start \(executable.lastPathComponent).")))
            return
        }
        self.process = process
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.finished else { return }
                self.process?.terminate()
                self.finish(.failed(L("It's taking too long.")))
            }
        }
        deadline = work
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: work)
    }

    func cancel() {
        deadline?.cancel()
        if let process, process.isRunning { process.terminate() }
        process = nil
        finished = true
        onEvent = nil
    }

    // MARK: Reading the stream

    private func consume(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            handle(object)
        }
    }

    private func handle(_ object: [String: Any]) {
        if let id = object["session_id"] as? String { session = id }
        switch object["type"] as? String {
        case "assistant":
            let content = ((object["message"] as? [String: Any])?["content"] as? [[String: Any]]) ?? []
            for part in content {
                switch part["type"] as? String {
                case "tool_use":
                    let input = part["input"] as? [String: Any] ?? [:]
                    let file = (input["file_path"] as? String).map { URL(fileURLWithPath: $0).lastPathComponent }
                    onEvent?(.activity(Self.describe(tool: part["name"] as? String ?? "", file: file)))
                case "text":
                    if let text = part["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        lastText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                default:
                    break
                }
            }
        case "result":
            let text = ((object["result"] as? String) ?? lastText ?? L("Done.")).trimmingCharacters(in: .whitespacesAndNewlines)
            let failed = (object["is_error"] as? Bool) == true || ((object["subtype"] as? String)?.hasPrefix("error") ?? false)
            finish(failed ? .failed(text) : .done(reply: text, session: session))
        default:
            break
        }
    }

    private func finish(_ event: Event) {
        guard !finished else { return }
        finished = true
        deadline?.cancel()
        let callback = onEvent
        onEvent = nil
        callback?(event)
    }

    /// One line of what the agent is doing, from the tool it reached for.
    static func describe(tool: String, file: String?) -> String {
        switch tool {
        // Oct 18, Ryan: in the primary language (the island shows the line as it is).
        case "Read": file.map { L("Looking at \($0)") } ?? L("Reading")
        case "Edit", "MultiEdit", "Write": file.map { L("Editing \($0)") } ?? L("Editing")
        case "Glob", "Grep", "LS": L("Looking around the folder")
        default: L("Working on it")
        }
    }
}

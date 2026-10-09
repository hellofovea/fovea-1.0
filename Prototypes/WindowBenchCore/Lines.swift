import Foundation

/// Every computed line the window shows. Mono in the UI: these are what a machine counted,
/// never prose Fovea wrote.
public enum Lines {

    // MARK: Times

    /// Times read in this calendar; tests pin it to UTC.
    public static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }()

    /// The notch's age: `now`, `4m`, `1h`, `3d`, then the date (`09-18`).
    public static func age(_ date: Date, now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86_400 { return "\(Int(seconds / 3600))h" }
        if seconds < 7 * 86_400 { return "\(Int(seconds / 86_400))d" }
        return day(date)
    }

    /// `14:02`
    public static func clock(_ date: Date) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// `09-18`
    public static func day(_ date: Date) -> String {
        let c = calendar.dateComponents([.month, .day], from: date)
        return String(format: "%02d-%02d", c.month ?? 0, c.day ?? 0)
    }

    /// `14:02` today, `09-18 14:02` before.
    public static func stamp(_ date: Date, now: Date) -> String {
        calendar.isDate(date, inSameDayAs: now) ? clock(date) : "\(day(date)) \(clock(date))"
    }

    /// `6m 40s`, `1h 12m`
    public static func duration(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds))
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m \(String(format: "%02d", s % 60))s" }
        return "\(s / 3600)h \(String(format: "%02d", (s % 3600) / 60))m"
    }

    static func plural(_ n: Int, _ one: String, _ many: String? = nil) -> String {
        "\(n) \(n == 1 ? one : (many ?? one + "s"))"
    }

    // MARK: Projects

    /// `3 threads · Claude Code, Codex · 4 runs this week`; a quiet project says when it last ran.
    public static func projectMeta(_ project: Project, index: LibraryIndex) -> String {
        if let scan = project.scan {
            // `12 sessions · Claude Code, Codex · last active 09-29`
            return [plural(scan.sessions, "session"), scan.agents.map(\.name).joined(separator: ", "),
                    "last active \(age(scan.lastActive, now: index.now))"]
                .filter { !$0.isEmpty }.joined(separator: " · ")
        }
        let threads = index.threads(in: project.id)
        var agents: [String] = []
        for thread in threads where !agents.contains(thread.agent.name) { agents.append(thread.agent.name) }
        let runs = index.runs(inProject: project.id)
        let weekAgo = index.now.addingTimeInterval(-7 * 86_400)
        let thisWeek = runs.filter { $0.started >= weekAgo }.count
        var parts = [plural(threads.count, "thread")]
        if !agents.isEmpty { parts.append(agents.joined(separator: ", ")) }
        // A quiet project's last run is its row's age; the meta doesn't say it twice.
        if thisWeek > 0 { parts.append("\(plural(thisWeek, "run")) this week") }
        return parts.joined(separator: " · ")
    }

    /// The header's second line: where the project lives and who worked in it.
    public static func projectHeaderMeta(_ project: Project, index: LibraryIndex) -> String {
        var agents: [String] = []
        for thread in index.threads(in: project.id) where !agents.contains(thread.agent.name) { agents.append(thread.agent.name) }
        return (project.paths + [agents.joined(separator: ", ")]).filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// `3 runs · 4 files changed · 1 waiting for you`, or nil when there is nothing to report.
    public static func sinceLastVisit(_ project: Project, index: LibraryIndex) -> String? {
        guard let visit = project.lastVisit else { return nil }
        let runs = index.runs(inProject: project.id)
        let newRuns = runs.filter { $0.started > visit }
        var files = Set<String>()
        for run in newRuns { for edit in run.edits { files.insert(edit.path) } }
        let waiting = runs.filter { $0.state == .waiting }.count
        var parts: [String] = []
        if !newRuns.isEmpty { parts.append(plural(newRuns.count, "run")) }
        if !files.isEmpty { parts.append("\(plural(files.count, "file")) changed") }
        if waiting > 0 { parts.append("\(waiting) waiting for you") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: Runs

    /// A command's result as the row reads it: `npm test passed`, `npm test · exit 1`.
    public static func command(_ result: CommandResult) -> String {
        result.exitCode == 0 ? "\(result.command) passed" : "\(result.command) · exit \(result.exitCode)"
    }

    /// `Edited hero.tsx +16 −6`, `Edited 3 files +48 −12`
    public static func edits(_ edits: [FileChange]) -> String? {
        guard !edits.isEmpty else { return nil }
        let added = edits.reduce(0) { $0 + $1.added }
        let removed = edits.reduce(0) { $0 + $1.removed }
        let what = edits.count == 1 ? edits[0].fileName : plural(edits.count, "file")
        return "Edited \(what) +\(added) −\(removed)"
    }

    /// The evidence line of a run row, at the density of a Codex row.
    public static func evidence(_ run: Run) -> String {
        switch run.state {
        case .running:
            return run.lastActions.last ?? "Started \(clock(run.started))"
        case .waiting:
            switch run.stuck {
            case .permission(let kind, let raw)?:
                switch kind {
                case .command: return "Asks to run \(raw)"
                case .diff: return "Asks to apply a change to \(raw)"
                case .url: return "Asks to open \(raw)"
                }
            case .question(let text, _)?:
                return "Asks: \(text)"
            case nil:
                return "Waiting for you"
            }
        case .failed:
            if let failure = run.failure {
                return [edits(run.edits), "\(failure.command) · exit \(failure.exitCode)"].compactMap { $0 }.joined(separator: " · ")
            }
            return "Failed"
        case .unobserved:
            return "Handed to your open session"
        case .finished, .seen:
            var parts: [String] = []
            if let e = edits(run.edits) { parts.append(e) }
            parts += run.commands.prefix(2).map(command)
            if parts.isEmpty {
                switch run.result {
                case .text: parts.append("Wrote a document")
                case .image: parts.append("Made an image")
                case .external(let app, let title, _): parts.append("\(app) · \(title)")
                case .code, .none: parts.append("No changes")
                }
            }
            return parts.joined(separator: " · ")
        }
    }

    /// The run header's meta: `Codex · fovea-site · 第二屏文案 · started 14:02 · 6m 40s · 2nd attempt`
    public static func runMeta(_ run: Run, index: LibraryIndex) -> String {
        let thread = index.thread(of: run)
        var parts: [String] = []
        if let thread { parts.append(thread.agent.name) }
        if let project = index.project(of: run) { parts.append(project.name) }
        if let thread { parts.append(thread.name) }
        parts.append("started \(stamp(run.started, now: index.now))")
        if run.state != .unobserved {
            let end = run.finished ?? (run.state == .running || run.state == .waiting ? index.now : nil)
            if let end { parts.append(duration(end.timeIntervalSince(run.started))) }
        }
        if run.attempt > 1 { parts.append("\(ordinal(run.attempt)) attempt") }
        return parts.joined(separator: " · ")
    }

    public static func ordinal(_ n: Int) -> String {
        let tens = (n / 10) % 10
        let suffix: String
        switch (tens == 1, n % 10) {
        case (true, _): suffix = "th"
        case (false, 1): suffix = "st"
        case (false, 2): suffix = "nd"
        case (false, 3): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }

    /// `Used 3 captures`
    public static func usedCaptures(_ count: Int) -> String? {
        count == 0 ? nil : "Used \(plural(count, "capture"))"
    }

    // MARK: Captures

    /// `screenshot · Safari · 14:02 · → 第二屏文案 · Codex`
    public static func capture(_ capture: Capture, index: LibraryIndex) -> String {
        var parts = [capture.kind.rawValue]
        if let app = capture.sourceApp { parts.append(app) }
        parts.append(stamp(capture.time, now: index.now))
        parts.append(destination(capture, index: index))
        return parts.joined(separator: " · ")
    }

    public static func destination(_ capture: Capture, index: LibraryIndex) -> String {
        switch capture.destination {
        case .run(let id):
            if let run = index.runByID[id], let thread = index.thread(of: run) { return "→ \(thread.title)" }
            return "→ a run"
        case .quickTask: return "→ quick task"
        case .notUsed: return "not used"
        }
    }

    // MARK: Search

    /// `14 results in 3 projects` (Xcode's count line, R05-03).
    public static func searchCount(_ hits: [SearchHit]) -> String {
        let projects = Set(hits.compactMap(\.projectID)).count
        let results = plural(hits.count, "result")
        return projects == 0 ? results : "\(results) in \(plural(projects, "project"))"
    }

    // MARK: Status bar

    /// `3 agents connected`
    /// The agent's signature after its line: "— Claude Code", never broken across lines.
    public static func signature(_ agent: String) -> String {
        "  —\u{00A0}" + agent.replacingOccurrences(of: " ", with: "\u{00A0}")
    }

    /// A computed line that may wrap only between its parts: inside a part nothing breaks (its
    /// spaces are no-break spaces and its characters are joined, which holds Chinese too), and a
    /// line never starts with "·" or leaves "→" at its end.
    public static func unbroken(_ line: String) -> String {
        line.components(separatedBy: " · ")
            .map { part in part.map { $0 == " " ? "\u{00A0}" : String($0) }.joined(separator: "\u{2060}") }
            .joined(separator: "\u{00A0}· ")
    }

    public static func connected(_ agents: [AgentConnection]) -> String {
        let n = agents.filter { $0.state == .connected }.count
        return n == 1 ? "1 agent connected" : "\(n) agents connected"
    }

    // MARK: Onboarding

    /// `142 sessions · 3 agents · 9 projects found`
    public static func scanCounts(sessions: Int, agents: Int, projects: Int) -> String {
        "\(plural(sessions, "session")) · \(plural(agents, "agent")) · \(plural(projects, "project")) found"
    }
}

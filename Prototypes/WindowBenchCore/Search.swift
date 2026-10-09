import Foundation

public enum SearchScope: String, CaseIterable, Codable, Hashable, Sendable {
    case projects, threads, runs, captures

    public var title: String {
        switch self {
        case .projects: return "Projects"
        case .threads: return "Threads"
        case .runs: return "Runs"
        case .captures: return "Captures"
        }
    }
}

public enum DateChip: String, CaseIterable, Codable, Hashable, Sendable {
    case today, week, month

    public var title: String {
        switch self {
        case .today: return "Today"
        case .week: return "This week"
        case .month: return "Last 30 days"
        }
    }

    public func contains(_ date: Date, now: Date) -> Bool {
        switch self {
        case .today: return Lines.calendar.isDate(date, inSameDayAs: now)
        case .week: return now.timeIntervalSince(date) <= 7 * 86_400
        case .month: return now.timeIntervalSince(date) <= 30 * 86_400
        }
    }
}

public struct SearchQuery: Codable, Hashable, Sendable {
    public var text: String
    /// Empty means every scope.
    public var scopes: Set<SearchScope>
    public var agent: AgentKind?
    public var date: DateChip?

    public init(text: String = "", scopes: Set<SearchScope> = [], agent: AgentKind? = nil, date: DateChip? = nil) {
        self.text = text; self.scopes = scopes; self.agent = agent; self.date = date
    }

    public var isEmpty: Bool { text.trimmingCharacters(in: .whitespaces).isEmpty && agent == nil && date == nil }
}

/// One result: the matched text with the hit's ranges (shown by weight, never color) and the
/// path to where it lives, in mono.
public struct SearchHit: Identifiable, Hashable, Sendable {
    public var scope: SearchScope
    public var targetID: String
    public var state: RunState?
    public var text: String
    /// UTF-16 (location, length) pairs inside `text`.
    public var ranges: [[Int]]
    public var context: String
    public var date: Date
    /// The project the hit lives in (nil for a capture that went to a quick task).
    public var projectID: String? = nil
    /// Which field matched: what a person said or named (sans), or something computed or typed
    /// into a machine (a path, a command, text read off a screenshot: mono).
    public var field: HitField = .words
    /// For a run found by a path or a command, the run's words, so the row says which run.
    public var title: String? = nil

    public var id: String { "\(scope.rawValue)/\(targetID)" }
}

public enum HitField: String, Hashable, Sendable {
    case words, name, path, command, screenText

    /// A path, a command or text read off a screen is set in mono.
    public var isComputed: Bool { self == .path || self == .command || self == .screenText }
}

public enum SearchEngine {
    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    static func tokens(_ query: String) -> [String] {
        query.split(whereSeparator: \.isWhitespace).map { fold(String($0)) }.filter { !$0.isEmpty }
    }

    /// Ranges of every token in `field`, or nil unless all of them are in it.
    static func match(_ tokens: [String], in field: String) -> [[Int]]? {
        guard !tokens.isEmpty else { return [] }
        let folded = fold(field) as NSString
        var ranges: [[Int]] = []
        for token in tokens {
            let r = folded.range(of: token)
            guard r.location != NSNotFound else { return nil }
            ranges.append([r.location, r.length])
        }
        return ranges
    }

    /// A window of `text` around its first hit, so long recognized text still shows the match.
    /// It starts and ends on whole words, and the text's line breaks read as single spaces.
    static func snippet(_ text: String, ranges: [[Int]], radius: Int = 36) -> (String, [[Int]]) {
        let ns = text as NSString
        guard let first = ranges.map({ $0[0] }).min(), ns.length > radius * 2 + 8 else { return (flatten(text), ranges) }
        let hitEnd = ranges.filter { $0[0] == first }.map { $0[0] + $0[1] }.max() ?? first
        let space = CharacterSet.whitespacesAndNewlines
        func isSpace(_ i: Int) -> Bool {
            guard i >= 0, i < ns.length, let scalar = Unicode.Scalar(ns.character(at: i)) else { return true }
            return space.contains(scalar)
        }
        // Back from the cut to the start of its word, forward past the space; never into the hit.
        var start = max(0, first - radius)
        if start > 0 && !isSpace(start - 1) {
            while start < first && !isSpace(start) { start += 1 }
        }
        while start < first && isSpace(start) { start += 1 }
        var end = min(ns.length, max(hitEnd, first + radius))
        if end < ns.length && !isSpace(end) {
            while end > hitEnd && !isSpace(end - 1) { end -= 1 }
        }
        while end > hitEnd && isSpace(end - 1) { end -= 1 }
        let lead = start > 0 ? "…" : ""
        let tail = end < ns.length ? "…" : ""
        let body = flatten(ns.substring(with: NSRange(location: start, length: end - start)))
        let shift = (lead as NSString).length - start
        let shifted = ranges.compactMap { r -> [Int]? in
            let loc = r[0] + shift
            return loc >= (lead as NSString).length && r[0] + r[1] <= end ? [loc, r[1]] : nil
        }
        return (lead + body + tail, shifted)
    }

    /// Line breaks and tabs as spaces, one for one, so the hit's ranges still point at it.
    static func flatten(_ text: String) -> String {
        String(text.map { $0.isNewline || $0 == "\t" ? " " : $0 })
    }

    public static func search(_ query: SearchQuery, in index: LibraryIndex) -> [SearchHit] {
        let tokens = tokens(query.text)
        guard !tokens.isEmpty || query.agent != nil || query.date != nil else { return [] }
        let scopes = query.scopes.isEmpty ? Set(SearchScope.allCases) : query.scopes
        let now = index.now
        var hits: [SearchHit] = []

        func agentOK(_ kinds: [AgentKind]) -> Bool { query.agent.map(kinds.contains) ?? true }
        func dateOK(_ date: Date) -> Bool { query.date?.contains(date, now: now) ?? true }

        if scopes.contains(.projects) {
            for project in index.library.projects {
                let threads = index.threads(in: project.id)
                let runs = index.runs(inProject: project.id)
                let last = runs.map(\.lastActivity).max() ?? .distantPast
                guard agentOK(threads.map(\.agent)), dateOK(last) else { continue }
                let fields: [(String, HitField)] = [(project.name, .name)] + project.paths.map { ($0, .path) }
                for (field, kind) in fields {
                    if let ranges = match(tokens, in: field) {
                        hits.append(SearchHit(scope: .projects, targetID: project.id, state: ProjectIndex.mostUrgent(runs),
                                              text: field, ranges: ranges,
                                              // Found by its path: the name is the row's title, so no context line.
                                              context: kind == .name ? (project.paths.first ?? "") : "",
                                              date: last, projectID: project.id, field: kind,
                                              title: kind == .name ? nil : project.name))
                        break
                    }
                }
            }
        }
        if scopes.contains(.threads) {
            for thread in index.library.threads {
                guard let project = index.projectByID[thread.projectID] else { continue }
                let runs = index.runs(in: thread.id)
                let last = runs.map(\.lastActivity).max() ?? .distantPast
                guard agentOK([thread.agent]), dateOK(last) else { continue }
                if let ranges = match(tokens, in: thread.title) {
                    hits.append(SearchHit(scope: .threads, targetID: thread.id, state: ProjectIndex.mostUrgent(runs),
                                          text: thread.title, ranges: ranges, context: project.name, date: last,
                                          projectID: project.id, field: .name))
                }
            }
        }
        if scopes.contains(.runs) {
            for run in index.library.runs {
                guard let thread = index.thread(of: run), let project = index.projectByID[thread.projectID] else { continue }
                guard agentOK([thread.agent]), dateOK(run.started) else { continue }
                let context = "\(project.name) › \(thread.title) · \(Lines.day(run.started))"
                let fields: [(String, HitField)] = [(run.words, .words)] + run.edits.map { ($0.path, .path) }
                    + run.commands.map { ($0.command, .command) }
                for (field, kind) in fields {
                    if let ranges = match(tokens, in: field) {
                        hits.append(SearchHit(scope: .runs, targetID: run.id, state: run.state, text: field,
                                              ranges: ranges, context: context, date: run.started, projectID: project.id,
                                              field: kind, title: kind == .words ? nil : run.words))
                        break
                    }
                }
            }
        }
        if scopes.contains(.captures) {
            for capture in index.library.captures {
                var kinds: [AgentKind] = []
                var projectID: String?
                if case .run(let id) = capture.destination, let run = index.runByID[id], let thread = index.thread(of: run) {
                    kinds = [thread.agent]
                    projectID = thread.projectID
                }
                guard query.agent == nil || agentOK(kinds), dateOK(capture.time) else { continue }
                let context = Lines.capture(capture, index: index)
                if let ranges = match(tokens, in: capture.transcript) {
                    hits.append(SearchHit(scope: .captures, targetID: capture.id, state: nil, text: capture.transcript,
                                          ranges: ranges, context: context, date: capture.time, projectID: projectID))
                } else if let ocr = capture.recognizedText, let ranges = match(tokens, in: ocr) {
                    let (text, shifted) = snippet(ocr, ranges: ranges)
                    hits.append(SearchHit(scope: .captures, targetID: capture.id, state: nil, text: text,
                                          ranges: shifted, context: context, date: capture.time, projectID: projectID,
                                          field: .screenText, title: capture.transcript.isEmpty ? nil : capture.transcript))
                }
            }
        }
        // By scope, then by state the way the list groups (waiting and failed first, seen last,
        // so a sunk project's hits come last without being hidden; Linear, R05-05), then newest.
        let order = SearchScope.allCases
        func urgency(_ hit: SearchHit) -> Int { hit.state?.urgency ?? RunState.seen.urgency }
        return hits.sorted {
            let a = order.firstIndex(of: $0.scope)!, b = order.firstIndex(of: $1.scope)!
            if a != b { return a < b }
            if urgency($0) != urgency($1) { return urgency($0) < urgency($1) }
            return $0.date > $1.date
        }
    }
}

import Foundation
import FoveaKit

/// The search field's contents: typed words, plus the filters the field holds as chips
/// (picked from its menu, never typed as syntax).
public struct CaptureQuery: Hashable, Sendable {
    public enum DateFilter: String, CaseIterable, Hashable, Sendable {
        case today, threeDays, week, month
        public var title: String {
            switch self {
            // Oct 18, Ryan: in the primary language.
            case .today: return L("Today")
            case .threeDays: return L("Last 3 days")
            case .week: return L("This week")
            case .month: return L("This month")
            }
        }
    }

    public var text: String
    public var kind: CaptureKind?
    /// Where it went (`Capture.target`): an app (with its website, in a browser), or a dispatch's agent.
    public var app: String?
    public var date: DateFilter?
    /// One of its tags.
    public var tag: String?

    public init(text: String = "", kind: CaptureKind? = nil, app: String? = nil, date: DateFilter? = nil, tag: String? = nil) {
        self.text = text; self.kind = kind; self.app = app; self.date = date; self.tag = tag
    }

    public var isEmpty: Bool { tokens.isEmpty && kind == nil && app == nil && date == nil && tag == nil }
    public var tokens: [String] { text.split(whereSeparator: { $0.isWhitespace }).map { String($0).lowercased() } }
}

/// Where a capture matched, so a card can set the words it matched in a heavier weight.
public enum MatchField: String, Hashable, Sendable {
    /// The words as Fovea put them.
    case text
    /// What you took: the text read off a region, a passage, a file's name (joined by newlines).
    case attachments
    case app
    /// Where a dispatch went: the agent and the chat. Searchable, never drawn.
    case destination
    /// Its tags.
    case tags
}

public struct CaptureMatch: Hashable, Sendable {
    public var capture: Capture
    /// The fields that matched, and the UTF-16 (location, length) ranges in each.
    public var ranges: [MatchField: [[Int]]]
    public init(capture: Capture, ranges: [MatchField: [[Int]]]) { self.capture = capture; self.ranges = ranges }
}

public enum CaptureSearch {
    /// Captures matching every typed word somewhere (its words, what you took, its app, where it
    /// went) and every chip; newest first. An empty query matches all.
    public static func search(_ query: CaptureQuery, in captures: [Capture], now: Date, calendar: Calendar = .current) -> [CaptureMatch] {
        let tokens = query.tokens
        var out: [CaptureMatch] = []
        for capture in captures.sorted(by: { $0.time > $1.time }) {
            if let kind = query.kind, capture.kind != kind { continue }
            if let app = query.app, capture.target != app { continue }
            if let date = query.date, !within(date, capture.time, now: now, calendar: calendar) { continue }
            if let tag = query.tag, !capture.tags.contains(tag) { continue }
            let fields: [(MatchField, String)] = [
                (.text, capture.text),
                (.attachments, attachmentText(capture)),
                (.app, capture.site.map { "\(capture.app.name) \($0)" } ?? capture.app.name),
                (.destination, capture.destination.map { "\($0.agent) \($0.chat)" } ?? ""),
                (.tags, capture.tags.joined(separator: " ")),
            ]
            var ranges: [MatchField: [[Int]]] = [:]
            var allFound = true
            for token in tokens {
                var found = false
                for (field, text) in fields where !text.isEmpty {
                    let hits = Self.ranges(of: token, in: text)
                    if !hits.isEmpty {
                        ranges[field, default: []] += hits
                        found = true
                    }
                }
                if !found { allFound = false; break }
            }
            if allFound { out.append(CaptureMatch(capture: capture, ranges: ranges)) }
        }
        return out
    }

    /// What a capture's attachments hold, in order, one per line: what search reads of them.
    public static func attachmentText(_ capture: Capture) -> String {
        capture.attachments.map(\.text).joined(separator: "\n")
    }

    /// Whether a date falls in the calendar's own period: today, the last three days (today and
    /// the two before it), this week (from the locale's first weekday), this month. The first
    /// page's cards cover the last three days (Ryan, Oct 7); older captures are in the calendar.
    public static func within(_ filter: CaptureQuery.DateFilter, _ date: Date, now: Date, calendar: Calendar) -> Bool {
        switch filter {
        case .today: return calendar.isDate(date, inSameDayAs: now)
        case .threeDays:
            let start = calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: now))!
            return date >= start
        case .week: return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
        case .month: return calendar.isDate(date, equalTo: now, toGranularity: .month)
        }
    }

    static func ranges(of token: String, in text: String) -> [[Int]] {
        let ns = text as NSString
        var out: [[Int]] = []
        var search = NSRange(location: 0, length: ns.length)
        while true {
            let r = ns.range(of: token, options: [.caseInsensitive, .diacriticInsensitive], range: search)
            if r.location == NSNotFound { break }
            out.append([r.location, r.length])
            let next = r.location + max(1, r.length)
            guard next < ns.length else { break }
            search = NSRange(location: next, length: ns.length - next)
        }
        return out
    }

    /// Where captures went (the app in front, with its website in a browser, or a dispatch's
    /// agent), most used first: the app filter's menu.
    public static func apps(in captures: [Capture]) -> [String] {
        let counts = Dictionary(grouping: captures, by: \.target).mapValues(\.count)
        return counts.keys.sorted { (counts[$0]!, $1) > (counts[$1]!, $0) }
    }

    /// Every tag, most used first, with how many captures carry it: the tag filter's menu, and
    /// what Memory's areas weigh.
    public static func tags(in captures: [Capture]) -> [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for c in captures { for t in c.tags { counts[t, default: 0] += 1 } }
        return counts.map { (tag: $0.key, count: $0.value) }.sorted { ($0.count, $1.tag) > ($1.count, $0.tag) }
    }
}

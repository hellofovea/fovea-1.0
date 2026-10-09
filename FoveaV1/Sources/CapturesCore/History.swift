import Foundation

/// The week on the first page, and every day before it as a calendar of how much you said.
public enum History {
    /// How many days the first page shows: today and the six before it.
    public static let recentDays = 7

    /// The first moment of the first page's oldest day.
    public static func recentStart(now: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: -(recentDays - 1), to: calendar.startOfDay(for: now))!
    }

    public static func isRecent(_ date: Date, now: Date, calendar: Calendar) -> Bool {
        date >= recentStart(now: now, calendar: calendar)
    }

    /// Captures per day, keyed by each day's first moment.
    public static func dayCounts(_ captures: [Capture], calendar: Calendar) -> [Date: Int] {
        var out: [Date: Int] = [:]
        for c in captures { out[calendar.startOfDay(for: c.time), default: 0] += 1 }
        return out
    }

    /// GitHub's way of shading a contribution calendar: no captures is level 0; the rest split
    /// into four levels at the quartiles of the busy days, so a quiet year still shows its
    /// shape and one huge day doesn't wash out the rest.
    public struct Levels: Hashable, Sendable {
        public let bounds: [Int]   // the upper count of levels 1, 2 and 3
        public init(_ counts: [Int]) {
            let busy = counts.filter { $0 > 0 }.sorted()
            guard !busy.isEmpty else { bounds = [1, 2, 3]; return }
            func q(_ p: Double) -> Int { busy[min(busy.count - 1, Int(Double(busy.count - 1) * p))] }
            bounds = [q(0.25), max(q(0.5), q(0.25) + 1), max(q(0.75), max(q(0.5), q(0.25) + 1) + 1)]
        }
        public func level(_ count: Int) -> Int {
            if count <= 0 { return 0 }
            if count <= bounds[0] { return 1 }
            if count <= bounds[1] { return 2 }
            if count <= bounds[2] { return 3 }
            return 4
        }
    }

    /// The calendar's columns: `count` weeks ending with the week that holds `now`, each seven
    /// days from the calendar's first weekday. Days after `now` are nil.
    public static func weeks(count: Int, now: Date, calendar: Calendar) -> [[Date?]] {
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        let thisWeek = calendar.date(byAdding: .day, value: -offset, to: today)!
        return (0..<count).map { w in
            let start = calendar.date(byAdding: .day, value: -7 * (count - 1 - w), to: thisWeek)!
            return (0..<7).map { d in
                let day = calendar.date(byAdding: .day, value: d, to: start)!
                return day > today ? nil : day
            }
        }
    }

    /// The months a span of days covers, newest first, each as its weeks (rows) of seven days
    /// (nil outside the month), for the month-calendar layout.
    public struct Month: Hashable, Sendable {
        public let first: Date
        public let rows: [[Date?]]
    }

    /// One calendar year as GitHub draws it: a column per week, from the week that holds
    /// 1 January to the one that holds 31 December, a day per row in the locale's order; nil
    /// outside the year.
    public static func weeks(year: Int, calendar: Calendar) -> [[Date?]] {
        let first = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let next = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))!
        let lead = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        var day = calendar.date(byAdding: .day, value: -lead, to: first)!
        var weeks: [[Date?]] = []
        while day < next {
            weeks.append((0..<7).map { d in
                let date = calendar.date(byAdding: .day, value: d, to: day)!
                return date >= first && date < next ? date : nil
            })
            day = calendar.date(byAdding: .day, value: 7, to: day)!
        }
        return weeks
    }

    /// The years there are captures in, newest first, this year always among them.
    public static func years(_ captures: [Capture], now: Date, calendar: Calendar) -> [Int] {
        let years = Set(captures.map { calendar.component(.year, from: $0.time) } + [calendar.component(.year, from: now)])
        return years.sorted(by: >)
    }

    /// A year's months, newest first; this year's stop at this month.
    public static func months(year: Int, now: Date, calendar: Calendar) -> [Month] {
        let thisYear = calendar.component(.year, from: now)
        let last = year == thisYear ? calendar.component(.month, from: now) : 12
        return (1...last).reversed().map { m in month(calendar.date(from: DateComponents(year: year, month: m, day: 1))!, calendar: calendar) }
    }

    public static func months(count: Int, now: Date, calendar: Calendar) -> [Month] {
        let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        return (0..<count).map { m in month(calendar.date(byAdding: .month, value: -m, to: thisMonth)!, calendar: calendar) }
    }

    /// The month that holds `date`, as weeks (rows) of seven days, nil outside the month.
    public static func month(_ date: Date, calendar: Calendar) -> Month {
        let first = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let days = calendar.range(of: .day, in: .month, for: first)!.count
        let lead = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: lead)
        for d in 0..<days { cells.append(calendar.date(byAdding: .day, value: d, to: first)) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return Month(first: first, rows: stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) })
    }
}

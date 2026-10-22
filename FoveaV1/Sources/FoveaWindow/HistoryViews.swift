import AppKit
import SwiftUI
import CapturesCore
import FoveaKit

// MARK: - The first page

/// The last three days' cards (or today's: the filter's periods, never more), then
/// every year before as a calendar of how much you said each day, a year at a time (GitHub's
/// contribution graph, or the months as calendars; or a timeline pinned on top). A day in the
/// calendar opens its archive. A search or an app shows its matches in the cards and marks
/// the days of the rest in the calendar: any time is the calendar's.
struct HomeFeed: View {
    @Environment(CapturesModel.self) private var model
    let layout: GridLayout

    var body: some View {
        let hasHistory = !model.library.captures.isEmpty
        VStack(alignment: .leading, spacing: model.cardSpacing.metrics.sectionGap) {
            if hasHistory && model.historyStyle == .yearGraphTop {
                CalendarSection { YearGraph(width: layout.contentWidth) }
                    .id("earlier")
            }
            VStack(alignment: .leading, spacing: 16) {
                if model.query.app != nil || model.query.date != nil || model.query.tag != nil { FilteredLine() }
                CaptureGrid(matches: model.matches, columns: layout.columns, emptyNote: emptyNote)
            }
            if hasHistory {
                switch model.historyStyle {
                case .yearGraph:
                    CalendarSection { YearGraph(width: layout.contentWidth) }.id("earlier")
                case .months:
                    CalendarSection { MonthCalendars(width: layout.contentWidth) }.id("earlier")
                case .yearGraphTop, .timeline:
                    EmptyView()
                }
            }
            if model.archiveStyle == .inline, let day = model.archiveDay {
                InlineDay(day: day, columns: layout.columns)
                    .transition(.opacity)
            }
        }
    }

    /// Oct 18, Ryan: in the primary language, a whole sentence for each period.
    private var emptyNote: String {
        switch (model.scope, model.filtering) {
        case (.today, true): return L("No matches today. The calendar marks the days with older ones.")
        case (.threeDays, true): return L("No matches in the last 3 days. The calendar marks the days with older ones.")
        case (.week, true): return L("No matches this week. The calendar marks the days with older ones.")
        case (.month, true): return L("No matches this month. The calendar marks the days with older ones.")
        case (.today, false): return L("Nothing today.")
        case (.threeDays, false): return L("Nothing in the last 3 days.")
        case (.week, false): return L("Nothing this week.")
        case (.month, false): return L("Nothing this month.")
        }
    }
}

/// The calendar's head: a tab for each year of use (Fovea's sliding pill), or the year alone
/// when there's one; and how much the shown year holds.
struct CalendarSection<Content: View>: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @ViewBuilder let content: () -> Content

    var body: some View {
        let cal = Lines.calendar
        let year = model.calendarYear
        let total = model.dayCounts.filter { cal.component(.year, from: $0.key) == year }.values.reduce(0, +)
        VStack(alignment: .leading, spacing: model.cardSpacing.metrics.dayLabelGap + 2) {
            HStack(alignment: .center) {
                if model.years.count > 1 {
                    SlidingSegments(segments: model.years.map { .init(value: $0, title: String($0), help: L("Show \(String($0))")) },
                                    selection: year, height: 22, fontSize: 11.5, padding: 10) { y in
                        model.cut { model.calendarYear = y }
                    }
                    .accessibilityLabel("Year")
                } else {
                    DayTitle(title: String(year), count: nil)
                }
                Spacer()
                Text(Self.yearTotal(total, String(year), matches: model.filtering))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(palette.tertiary)
            }
            // Oct 21, Ryan ("simpler is better"): another year shows at once (it faded out and in,
            // its total rolling).
            content()
                .id(year)
                .transition(.identity)
        }
    }

    /// "128 captures in 2026". Oct 18, Ryan: in the primary language, a sentence for each count.
    static func yearTotal(_ n: Int, _ year: String, matches: Bool) -> String {
        switch (matches, n == 1) {
        case (true, true): return L("1 match in \(year)")
        case (true, false): return L("\(n.formatted()) matches in \(year)")
        case (false, true): return L("1 capture in \(year)")
        case (false, false): return L("\(n.formatted()) captures in \(year)")
        }
    }
}

/// Oct 18, Ryan: the calendar's month and weekday names in the primary language. `Lines.calendar`
/// writes English (en_US_POSIX), which stays exactly as it was; Chinese takes the system's own
/// names for zh-Hans ("10月", "周一", "一").
enum CalendarWords {
    static var chinese: Bool { FoveaLocale.shared.language == .chinese }

    /// A month's name: the English format as written, or the Chinese template's.
    static func formatter(_ english: String, chinese template: String) -> DateFormatter {
        let cal = Lines.calendar
        // Oct 21, perf: made once per format, language and calendar (CapturesCore's `FormatterMemo`).
        let chinese = chinese
        let language = FoveaLocale.shared.locale.identifier
        return FormatterMemo.shared.formatter(["calendar", chinese ? language : "en", english, template, FormatterMemo.key(cal)]) {
            let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone
            if chinese {
                f.locale = FoveaLocale.shared.locale
                f.setLocalizedDateFormatFromTemplate(template)
            } else {
                f.locale = cal.locale
                f.dateFormat = english
            }
            return f
        }
    }

    /// The calendar whose weekday names to show (its layout stays `Lines.calendar`'s).
    static var names: Calendar {
        var c = Lines.calendar
        if chinese { c.locale = FoveaLocale.shared.locale }
        return c
    }
}

// MARK: - Year graph

/// A year as GitHub draws contributions: a column per week, a square per day, shaded by how
/// many captures you made (four levels at the quartiles of your busy days, none left empty).
/// The pointer is followed by one ring that jumps to the day under it at once, read off the
/// pointer's place over the whole graph (a hover area per square loses its enters and exits when
/// the pointer moves fast, and a tooltip per square waits a second and stays put); the line under
/// the graph names the day. A click opens it. Days still to come are left as outlines.
struct YearGraph: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let width: CGFloat
    @State private var hovered: Date?

    var body: some View {
        let cal = Lines.calendar
        let labelWidth: CGFloat = 30
        let weeks = History.weeks(year: model.calendarYear, calendar: cal)
        let pitch = floor((width - labelWidth) / CGFloat(max(weeks.count, 53)) * 2) / 2
        let gap: CGFloat = pitch >= 16 ? 4 : 3
        let cell = pitch - gap
        let today = cal.startOfDay(for: model.now)
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                MonthLabels(weeks: weeks, pitch: pitch)
                    .padding(.leading, labelWidth)
                HStack(alignment: .top, spacing: 0) {
                    WeekdayLabels(cell: cell, gap: gap)
                        .frame(width: labelWidth, alignment: .leading)
                    HStack(alignment: .top, spacing: gap) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                            VStack(spacing: gap) {
                                ForEach(0..<7, id: \.self) { i in
                                    if let day = week[i] {
                                        DayCell(day: day, size: cell, future: day > today)
                                    } else {
                                        Color.clear.frame(width: cell, height: cell)
                                    }
                                }
                            }
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        // The pointer's ring: no animation, as a cursor's highlight never has.
                        if let hovered, let place = Self.place(of: hovered, in: weeks) {
                            RoundedRectangle(cornerRadius: max(2, cell * 0.24) + 1.5, style: .continuous)
                                .strokeBorder(palette.text, lineWidth: 1.5)
                                .frame(width: cell + 3, height: cell + 3)
                                .offset(x: CGFloat(place.column) * pitch - 1.5, y: CGFloat(place.row) * pitch - 1.5)
                                .allowsHitTesting(false)
                        }
                    }
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        var t = Transaction()
                        t.disablesAnimations = true
                        withTransaction(t) {
                            switch phase {
                            case .active(let p): hovered = Self.day(at: p, in: weeks, pitch: pitch, today: today)
                            case .ended: hovered = nil
                            }
                        }
                    }
                    .onTapGesture { p in
                        if let day = Self.day(at: p, in: weeks, pitch: pitch, today: today) { model.openDay(day) }
                    }
                }
            }
            HStack {
                Text(hovered.map { caption($0) } ?? L("Click a day to see what you said."))
                    .font(.system(size: 12))
                    .foregroundStyle(hovered == nil ? palette.tertiary : palette.secondary)
                Spacer()
                HeatLegend(cell: min(cell, 12))
            }
            .padding(.leading, labelWidth)
        }
    }

    /// The day under a point of the grid: its week's column and its row, the gaps counting as
    /// the square before them, so the ring never drops out between squares. Days to come don't
    /// answer.
    static func day(at p: CGPoint, in weeks: [[Date?]], pitch: CGFloat, today: Date) -> Date? {
        guard p.x >= 0, p.y >= 0 else { return nil }
        let column = Int(p.x / pitch), row = Int(p.y / pitch)
        guard weeks.indices.contains(column), (0..<7).contains(row), let day = weeks[column][row], day <= today else { return nil }
        return day
    }

    static func place(of day: Date, in weeks: [[Date?]]) -> (column: Int, row: Int)? {
        for (c, week) in weeks.enumerated() {
            if let r = week.firstIndex(where: { $0 == day }) { return (c, r) }
        }
        return nil
    }

    private func caption(_ day: Date) -> String {
        let n = model.dayCounts[day] ?? 0
        let when = Lines.longDay(day, now: model.now)
        if n == 0 { return L("Nothing on \(when)") }
        guard model.filtering else { return L("\(n) on \(when)") }
        return n == 1 ? L("1 match on \(when)") : L("\(n) matches on \(when)")
    }
}

/// The month names over the graph, each over its month's first week (none crowding the last).
private struct MonthLabels: View {
    @Environment(\.palette) private var palette
    let weeks: [[Date?]]
    let pitch: CGFloat

    var body: some View {
        let cal = Lines.calendar
        let f = CalendarWords.formatter("MMM", chinese: "MMM")
        var marks: [(Int, String)] = []
        var lastMonth = -1
        for (i, week) in weeks.enumerated() {
            guard let first = week.compactMap({ $0 }).first(where: { cal.component(.day, from: $0) <= 7 }) ?? (i == 0 ? week.compactMap({ $0 }).first : nil) else { continue }
            let m = cal.component(.month, from: first)
            if m != lastMonth {
                if let last = marks.last, i - last.0 < 3 { marks.removeLast() }
                marks.append((i, f.string(from: first)))
                lastMonth = m
            }
        }
        return ZStack(alignment: .topLeading) {
            Color.clear.frame(height: 14)
            ForEach(marks, id: \.0) { mark in
                Text(mark.1)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.secondary)
                    .offset(x: CGFloat(mark.0) * pitch)
            }
        }
    }
}

private struct WeekdayLabels: View {
    @Environment(\.palette) private var palette
    let cell: CGFloat
    let gap: CGFloat

    var body: some View {
        let cal = Lines.calendar
        let symbols = CalendarWords.names.shortWeekdaySymbols
        VStack(alignment: .leading, spacing: gap) {
            ForEach(0..<7, id: \.self) { row in
                let weekday = (cal.firstWeekday - 1 + row) % 7
                // Every other day named, as GitHub does: Mon, Wed, Fri.
                Text(row % 2 == 1 ? symbols[weekday] : "")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.tertiary)
                    .frame(height: cell, alignment: .center)
            }
        }
    }
}

/// One day: shaded by its level, ringed in ink while it's open; a day to come only outlined.
/// The pointer's ring is the graph's, drawn once over all of them.
private struct DayCell: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let day: Date
    let size: CGFloat
    var future = false

    var body: some View {
        let n = model.dayCounts[day] ?? 0
        let level = model.levels.level(n)
        let open = model.archiveDay == day && (model.page == .day || model.archiveStyle == .inline)
        let shape = RoundedRectangle(cornerRadius: max(2, size * 0.24), style: .continuous)
        Group {
            if future {
                shape.strokeBorder(palette.hairline, lineWidth: 0.5)
            } else {
                shape
                    .fill(palette.heat[level])
                    .overlay(shape.strokeBorder(level == 0 ? palette.hairline : Color.black.opacity(palette.isDark ? 0 : 0.06), lineWidth: 0.5))
                    .overlay {
                        if open { shape.strokeBorder(palette.text, lineWidth: 1.5).padding(-1.5) }
                    }
            }
        }
        .overlay {
            // Today, marked as the icon marks focus: its dot, or its o (a ring with the dot).
            if Lines.calendar.isDate(day, inSameDayAs: model.now) && model.focusMark != .ring {
                ZStack {
                    if model.focusMark == .eye {
                        shape.strokeBorder(palette.text, lineWidth: max(1.5, size * 0.16))
                    }
                    Circle().fill(level >= 3 ? palette.onHeat : palette.text).frame(width: size * 0.36, height: size * 0.36)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(future ? "" : Self.tooltip(n, day, now: model.now))
        .accessibilityAddTraits(future ? [] : .isButton)
        .accessibilityAction { if !future { model.openDay(day) } }
        .accessibilityHidden(future)
    }

    static func tooltip(_ n: Int, _ day: Date, now: Date) -> String {
        let when = Lines.longDay(day, now: now)
        return n == 0 ? L("Nothing on \(when)") : L("\(n) on \(when)")
    }
}

/// Less ▢▢▢▢▢ More.
struct HeatLegend: View {
    @Environment(\.palette) private var palette
    let cell: CGFloat
    var body: some View {
        HStack(spacing: 4) {
            Text("Less").font(.system(size: 11)).foregroundStyle(palette.tertiary)
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: max(2, cell * 0.24), style: .continuous)
                    .fill(palette.heat[level])
                    .overlay(RoundedRectangle(cornerRadius: max(2, cell * 0.24), style: .continuous)
                        .strokeBorder(level == 0 ? palette.hairline : .clear, lineWidth: 0.5))
                    .frame(width: cell, height: cell)
            }
            Text("More").font(.system(size: 11)).foregroundStyle(palette.tertiary)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Month calendars

/// The year as twelve small calendars, newest first: every day dated, shaded the same way as
/// the graph, today ringed. Easier to find a date in than the graph; it shows less at once.
struct MonthCalendars: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let width: CGFloat

    var body: some View {
        let cal = Lines.calendar
        let months = History.months(year: model.calendarYear, now: model.now, calendar: cal)
        let gap: CGFloat = 24
        let perRow = max(2, min(4, Int((width + gap) / (7 * 26 + gap))))
        let monthWidth = (width - CGFloat(perRow - 1) * gap) / CGFloat(perRow)
        let cell = floor((monthWidth - 6 * 3) / 7)
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(monthWidth), spacing: gap, alignment: .top), count: perRow),
                  alignment: .leading, spacing: 28) {
            ForEach(months, id: \.first) { month in
                MonthView(month: month, cell: cell)
            }
        }
    }
}

private struct MonthView: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let month: History.Month
    let cell: CGFloat
    /// The day under the pointer, read off its place over the month (see `YearGraph`).
    @State private var hovered: Date?

    var body: some View {
        let cal = Lines.calendar
        let total = month.rows.flatMap { $0 }.compactMap { $0 }.map { model.dayCounts[$0] ?? 0 }.reduce(0, +)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(Self.title(month.first, now: model.now)).font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.text)
                Spacer()
                Text(total == 0 ? "—" : "\(total)").font(.system(size: 11)).foregroundStyle(palette.tertiary).monospacedDigit()
            }
            VStack(spacing: 3) {
                HStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(CalendarWords.names.veryShortWeekdaySymbols[(cal.firstWeekday - 1 + i) % 7])
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(palette.tertiary)
                            .frame(width: cell)
                    }
                }
                VStack(spacing: 3) {
                    ForEach(Array(month.rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { i in
                                if let day = row[i] {
                                    DatedCell(day: day, size: cell, hovered: hovered == day)
                                } else {
                                    Color.clear.frame(width: cell, height: cell)
                                }
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    var t = Transaction()
                    t.disablesAnimations = true
                    withTransaction(t) {
                        switch phase {
                        case .active(let p): hovered = day(at: p)
                        case .ended: hovered = nil
                        }
                    }
                }
                .onTapGesture { p in if let d = day(at: p) { model.openDay(d) } }
            }
        }
    }

    static func title(_ first: Date, now: Date) -> String {
        let cal = Lines.calendar
        let sameYear = cal.component(.year, from: first) == cal.component(.year, from: now)
        return CalendarWords.formatter(sameYear ? "MMMM" : "MMMM yyyy", chinese: sameYear ? "MMM" : "yyyyMMM").string(from: first)
    }

    /// The day at a point of the month's grid (gaps count as the day before them); none to come.
    private func day(at p: CGPoint) -> Date? {
        let pitch = cell + 3
        guard p.x >= 0, p.y >= 0 else { return nil }
        let column = Int(p.x / pitch), row = Int(p.y / pitch)
        guard month.rows.indices.contains(row), (0..<7).contains(column), let day = month.rows[row][column],
              day <= Lines.calendar.startOfDay(for: model.now) else { return nil }
        return day
    }
}

/// A day with its date on it, shaded by how much you said; future days are left blank.
private struct DatedCell: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let day: Date
    let size: CGFloat
    let hovered: Bool

    var body: some View {
        let cal = Lines.calendar
        let future = day > cal.startOfDay(for: model.now)
        let n = model.dayCounts[day] ?? 0
        let level = model.levels.level(n)
        let today = cal.isDate(day, inSameDayAs: model.now)
        let open = model.archiveDay == day && (model.page == .day || model.archiveStyle == .inline)
        let hover = hovered && !future
        let shape = RoundedRectangle(cornerRadius: max(3, size * 0.22), style: .continuous)
        Text("\(cal.component(.day, from: day))")
            .font(.system(size: 10.5, weight: today ? .bold : .regular))
            .monospacedDigit()
            .foregroundStyle(future ? palette.tertiary.opacity(0.6) : (level >= 3 ? palette.onHeat : palette.secondary))
            .frame(width: size, height: size)
            .background(shape.fill(future ? Color.clear : palette.heat[level]))
            .overlay {
                if open || hover || today {
                    shape.strokeBorder(palette.text, lineWidth: open || hover ? 1.5 : 1).padding(open || hover ? -1.5 : 0)
                        .opacity(open || hover ? 1 : 0.5)
                }
            }
            .accessibilityLabel(DayCell.tooltip(n, day, now: model.now))
            .accessibilityAddTraits(future ? [] : .isButton)
            .accessibilityAction { if !future { model.openDay(day) } }
    }
}

// MARK: - Timeline

/// A slim strip of days pinned under the toolbar: a bar per day, as tall as that day was busy,
/// scrolling back through the year. This week is marked; the bar under the pointer names its
/// day; a click opens it.
struct TimelineStrip: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let width: CGFloat
    @State private var hovered: Date?

    var body: some View {
        let cal = Lines.calendar
        let today = cal.startOfDay(for: model.now)
        let days: [Date] = (0..<400).reversed().map { cal.date(byAdding: .day, value: -$0, to: today)! }
        let maxCount = max(1, model.dayCounts.values.max() ?? 1)
        let barWidth: CGFloat = 5, spacing: CGFloat = 2, height: CGFloat = 40
        let recentStart = History.recentStart(now: model.now, calendar: cal)
        let monthFormatter = CalendarWords.formatter("MMM", chinese: "MMM")
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(hovered.map { DayCell.tooltip(model.dayCounts[$0] ?? 0, $0, now: model.now) } ?? L("Every day, back a year. Click one to see it."))
                    .font(.system(size: 12))
                    .foregroundStyle(hovered == nil ? palette.tertiary : palette.secondary)
                Spacer()
                HeatLegend(cell: 10)
            }
            ScrollViewReader { reader in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: spacing) {
                        ForEach(days, id: \.self) { day in
                            let n = model.dayCounts[day] ?? 0
                            let first = cal.component(.day, from: day) == 1
                            VStack(spacing: 4) {
                                ZStack(alignment: .bottom) {
                                    Color.clear.frame(width: barWidth, height: height)
                                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                        .fill(n == 0 ? palette.hairline : palette.heat[model.levels.level(n)])
                                        .frame(width: barWidth, height: n == 0 ? 2 : max(4, height * CGFloat(n) / CGFloat(maxCount)))
                                }
                                .background(day >= recentStart ? palette.fill : Color.clear)
                                .overlay(alignment: .bottom) {
                                    if hovered == day || model.archiveDay == day {
                                        RoundedRectangle(cornerRadius: 2).strokeBorder(palette.text, lineWidth: 1.25)
                                            .frame(width: barWidth + 3, height: max(6, height * CGFloat(n) / CGFloat(maxCount)) + 3)
                                    }
                                }
                                // A month's name under its first day.
                                Text(first ? monthFormatter.string(from: day) : " ")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(palette.tertiary)
                                    .fixedSize()
                                    .frame(width: barWidth, alignment: .leading)
                            }
                            .contentShape(Rectangle())
                            .onHover { inside in if inside { hovered = day } else if hovered == day { hovered = nil } }
                            .onTapGesture { model.openDay(day) }
                            .help(DayCell.tooltip(n, day, now: model.now))
                            .id(day)
                        }
                    }
                    .padding(.trailing, 2)
                }
                .onAppear { reader.scrollTo(today, anchor: .trailing) }
            }
        }
        .frame(width: width)
    }
}

// MARK: - A day

/// The day's name in large type, what it held by type, and the days with captures before and
/// after it.
struct DayHeader: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let day: Date
    var closable = false

    var body: some View {
        let captures = model.matches(on: day).map(\.capture)
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Lines.longDay(day, now: model.now))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.text)
                if captures.isEmpty {
                    Text("Nothing on this day.").font(.system(size: 13)).foregroundStyle(palette.secondary)
                } else {
                    HStack(spacing: 14) {
                        ForEach(CaptureKind.allCases, id: \.self) { kind in
                            let n = captures.filter { $0.kind == kind }.count
                            if n > 0 {
                                HStack(spacing: 6) {
                                    KindMark(kind: kind)
                                    Text(Lines.count(n, of: kind))
                                }
                            }
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(palette.secondary)
                    .accessibilityLabel(Lines.breakdown(captures))
                }
            }
            Spacer()
            // Aside's actions capsule: the days either side, and closing an open day.
            GlassBar {
                IconButton(symbol: "chevron.left", help: "The day before, with captures") { model.stepDay(-1) }
                    .disabled(model.neighborDay(-1) == nil)
                IconButton(symbol: "chevron.right", help: "The day after, with captures") { model.stepDay(1) }
                    .disabled(model.neighborDay(1) == nil)
                if closable {
                    BarDivider()
                    IconButton(symbol: "xmark", help: "Close the day") { model.animate(.layout) { model.archiveDay = nil } }
                }
            }
        }
    }
}

/// A day opened in place, under the calendar.
struct InlineDay: View {
    @Environment(CapturesModel.self) private var model
    let day: Date
    let columns: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            DayHeader(day: day, closable: true)
            CaptureGrid(matches: model.matches(on: day), columns: columns, dayHeaders: false, emptyNote: "")
                .id(day)
                .transition(.identity)
        }
    }
}

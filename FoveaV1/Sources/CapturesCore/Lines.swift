import Foundation
import FoveaKit

/// Oct 21, perf: date formatters, each made once for what makes it (its formats, the language,
/// the calendar) and shared: making one loads ICU's data for its locale (~1 ms), and view bodies
/// asked for one per line drawn. Formatting with a shared DateFormatter is thread-safe; none is
/// changed after it's made.
public final class FormatterMemo: @unchecked Sendable {
    public static let shared = FormatterMemo()
    private let lock = NSLock()
    private var formatters: [[String]: DateFormatter] = [:]

    public func formatter(_ key: [String], make: () -> DateFormatter) -> DateFormatter {
        lock.lock()
        if let hit = formatters[key] { lock.unlock(); return hit }
        lock.unlock()
        let made = make()
        lock.lock()
        formatters[key] = made
        lock.unlock()
        return made
    }

    /// What of a calendar a formatter takes.
    public static func key(_ calendar: Calendar) -> String {
        "\(calendar.identifier)|\(calendar.timeZone.identifier)|\(calendar.locale?.identifier ?? "")"
    }
}

/// Every line Fovea computes about a capture, worded once, so the card, the detail and search say
/// the same thing.
public enum Lines {
    public static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()

    /// Oct 18, Ryan: the lines are in the primary language. English keeps its exact formats; Chinese
    /// takes the system's own for its locale ("10月18日 星期日", "下午2:30").
    static var chinese: Bool { FoveaLocale.shared.language == .chinese }

    static func formatter(_ english: String, chinese template: String) -> DateFormatter {
        // Oct 21, perf: made once per format, language and calendar (`FormatterMemo`): Home's year
        // made one for every day's tooltip on every draw (~50 ms opening a day).
        let chinese = chinese
        return FormatterMemo.shared.formatter([chinese ? "zh" : "en", english, template, FormatterMemo.key(calendar)]) {
            let f = DateFormatter()
            f.calendar = calendar; f.timeZone = calendar.timeZone
            if chinese {
                f.locale = Locale(identifier: "zh-Hans")
                f.setLocalizedDateFormatFromTemplate(template)
            } else {
                f.locale = calendar.locale
                f.dateFormat = english
            }
            return f
        }
    }

    /// Paste's header time: "just now", "3 minutes ago", "2 hours ago", "Yesterday", "3 days ago",
    /// then the date.
    public static func relative(_ date: Date, now: Date) -> String {
        let s = max(0, now.timeIntervalSince(date))
        if s < 60 { return L("just now") }
        if s < 3_600 { let m = Int(s / 60); return m == 1 ? L("1 minute ago") : L("\(m) minutes ago") }
        if calendar.isDate(date, inSameDayAs: now) { let h = Int(s / 3_600); return h == 1 ? L("1 hour ago") : L("\(h) hours ago") }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days == 1 { return L("Yesterday") }
        if days < 7 { return L("\(days) days ago") }
        return day(date)
    }

    /// Paste 6's compact time: "now", "3m", "2h", "1d", "3w", then the date.
    public static func compact(_ date: Date, now: Date) -> String {
        let s = max(0, now.timeIntervalSince(date))
        if s < 60 { return L("now") }
        if s < 3_600 { let m = Int(s / 60); return L("\(m)m") }
        if calendar.isDate(date, inSameDayAs: now) { let h = Int(s / 3_600); return L("\(h)h") }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days < 7 { let d = max(1, days); return L("\(d)d") }
        if days < 35 { let w = days / 7; return L("\(w)w") }
        return day(date)
    }

    /// "Oct 1" (no year this year); "10月1日".
    public static func day(_ date: Date) -> String {
        formatter("MMM d", chinese: "MMMd").string(from: date)
    }

    public static func clock(_ date: Date) -> String {
        formatter("HH:mm", chinese: "HHmm").string(from: date)
    }

    /// A day group's title: Today, Yesterday, then the weekday and date.
    public static func dayGroup(_ date: Date, now: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return L("Today") }
        if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: y) { return L("Yesterday") }
        return formatter("EEEE, MMM d", chinese: "MMMdEEEE").string(from: date)
    }

    /// A time of day as an archived card shows it, under a header that already names the day:
    /// "10:42 AM".
    public static func time(_ date: Date) -> String {
        formatter("h:mm a", chinese: "hmm").string(from: date)
    }

    /// A day as the archive names it: "Today", "Yesterday", then "Thursday, September 24", with
    /// the year when it isn't this one.
    public static func longDay(_ date: Date, now: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return L("Today") }
        if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: y) { return L("Yesterday") }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        return formatter(sameYear ? "EEEE, MMMM d" : "EEEE, MMMM d, yyyy", chinese: sameYear ? "MMMMdEEEE" : "yyyyMMMMdEEEE").string(from: date)
    }

    /// One type's count: "6 dictations", "1 dispatch".
    public static func count(_ n: Int, of kind: CaptureKind) -> String {
        switch kind {
        case .dictation: return n == 1 ? L("1 dictation") : L("\(n) dictations")
        case .dispatch: return n == 1 ? L("1 dispatch") : L("\(n) dispatches")
        }
    }

    /// A day's captures by type: "6 dictations · 5 captures · 3 dispatches" (types it has).
    public static func breakdown(_ captures: [Capture]) -> String {
        CaptureKind.allCases.compactMap { kind -> String? in
            let n = captures.filter { $0.kind == kind }.count
            guard n > 0 else { return nil }
            return count(n, of: kind)
        }
        .joined(separator: " · ")
    }

    /// A recording's length, as a player shows it: "0:31", "1:04".
    public static func duration(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }

    /// The card's header label: the type, nothing else (what it holds is the card's body).
    public static func label(_ capture: Capture) -> String { capture.kind.title }

    /// An attachment as VoiceOver and the copy menu name it: "Region 1", "Passage 2", "File 3".
    public static func name(_ attachment: Attachment) -> String {
        let i = attachment.index
        switch attachment.kind {
        case .region: return L("Region \(i)")
        case .passage: return L("Passage \(i)")
        case .file: return L("File \(i)")
        }
    }

    /// The words with each attachment named where it was taken, for VoiceOver:
    /// "Make the ears on this one (region 1) match…".
    public static func spoken(_ capture: Capture) -> String {
        capture.segments.map { segment -> String in
            switch segment {
            case .run(_, let text): return text
            case .attachment(let a):
                let what = a.kind == .file ? "\(name(a).lowercased()), \(a.text)" : name(a).lowercased()
                return " (\(what))"
            }
        }
        .joined()
    }

    /// "1,240 of 5,000 credits left · resets Oct 7"
    public static func credits(_ usage: Usage) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        let left = f.string(from: NSNumber(value: usage.left)) ?? "\(usage.left)"
        let total = f.string(from: NSNumber(value: usage.total)) ?? "\(usage.total)"
        let resets = day(usage.resets)
        return L("\(left) of \(total) credits left · resets \(resets)")
    }

    /// A count line over the grid: "21 captures", "3 dictations".
    public static func count(_ n: Int, kind: CaptureKind?) -> String {
        if let kind { return count(n, of: kind) }
        return n == 1 ? L("1 item") : L("\(n) items")
    }
}

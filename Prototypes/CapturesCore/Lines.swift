import Foundation

/// Every line Fovea computes about a capture, worded once, so the card, the detail and search say
/// the same thing.
public enum Lines {
    public static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()

    /// Paste's header time: "just now", "3 minutes ago", "2 hours ago", "Yesterday", "3 days ago",
    /// then the date.
    public static func relative(_ date: Date, now: Date) -> String {
        let s = max(0, now.timeIntervalSince(date))
        if s < 60 { return "just now" }
        if s < 3_600 { let m = Int(s / 60); return m == 1 ? "1 minute ago" : "\(m) minutes ago" }
        if calendar.isDate(date, inSameDayAs: now) { let h = Int(s / 3_600); return h == 1 ? "1 hour ago" : "\(h) hours ago" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days) days ago" }
        return day(date)
    }

    /// Paste 6's compact time: "now", "3m", "2h", "1d", "3w", then the date.
    public static func compact(_ date: Date, now: Date) -> String {
        let s = max(0, now.timeIntervalSince(date))
        if s < 60 { return "now" }
        if s < 3_600 { return "\(Int(s / 60))m" }
        if calendar.isDate(date, inSameDayAs: now) { return "\(Int(s / 3_600))h" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        if days < 7 { return "\(max(1, days))d" }
        if days < 35 { return "\(days / 7)w" }
        return day(date)
    }

    /// "Oct 1" (no year this year).
    public static func day(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = calendar; f.timeZone = calendar.timeZone; f.locale = calendar.locale
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    public static func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = calendar; f.timeZone = calendar.timeZone; f.locale = calendar.locale
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// A day group's title: Today, Yesterday, then the weekday and date.
    public static func dayGroup(_ date: Date, now: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: y) { return "Yesterday" }
        let f = DateFormatter()
        f.calendar = calendar; f.timeZone = calendar.timeZone; f.locale = calendar.locale
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    /// A time of day as an archived card shows it, under a header that already names the day:
    /// "10:42 AM".
    public static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = calendar; f.timeZone = calendar.timeZone; f.locale = calendar.locale
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    /// A day as the archive names it: "Today", "Yesterday", then "Thursday, September 24", with
    /// the year when it isn't this one.
    public static func longDay(_ date: Date, now: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: y) { return "Yesterday" }
        let f = DateFormatter()
        f.calendar = calendar; f.timeZone = calendar.timeZone; f.locale = calendar.locale
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        f.dateFormat = sameYear ? "EEEE, MMMM d" : "EEEE, MMMM d, yyyy"
        return f.string(from: date)
    }

    /// A day's captures by type: "6 dictations · 5 captures · 3 dispatches" (types it has).
    public static func breakdown(_ captures: [Capture]) -> String {
        CaptureKind.allCases.compactMap { kind -> String? in
            let n = captures.filter { $0.kind == kind }.count
            guard n > 0 else { return nil }
            return "\(n) \(n == 1 ? kind.title.lowercased() : kind.plural.lowercased())"
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
        switch attachment.kind {
        case .region: return "Region \(attachment.index)"
        case .passage: return "Passage \(attachment.index)"
        case .file: return "File \(attachment.index)"
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
        return "\(left) of \(total) credits left · resets \(day(usage.resets))"
    }

    /// A count line over the grid: "21 captures", "3 dictations".
    public static func count(_ n: Int, kind: CaptureKind?) -> String {
        let noun = kind.map { n == 1 ? $0.title.lowercased() : $0.plural.lowercased() } ?? (n == 1 ? "item" : "items")
        return "\(n) \(noun)"
    }
}

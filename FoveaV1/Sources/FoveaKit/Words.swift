import Foundation

// What Fovea does with the words it hears, before they go anywhere: cleaned for a paste, named for
// a title, and matched to one of Dispatch's scripted requests (Dispatch is simulated in 1.0: the
// words are real, the agent's work and answer are the Workbench's).

/// Spoken words written up: no ums, a capital, a full stop. The onboarding's own rule
/// (OnboardingModel.cleaned), now for every paste.
public enum TranscriptCleaner {
    static let fillers: Set<String> = ["um", "uh", "umm", "uhh", "erm", "er", "hmm", "mm"]

    public static func clean(_ text: String) -> String {
        var words = text.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init)
        words.removeAll { fillers.contains($0.lowercased().trimmingCharacters(in: .punctuationCharacters)) }
        var out = words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        // Commas left hanging by a dropped filler.
        while out.contains(" ,") { out = out.replacingOccurrences(of: " ,", with: ",") }
        while out.hasPrefix(",") { out.removeFirst(); out = out.trimmingCharacters(in: .whitespaces) }
        guard let first = out.first else { return "" }
        out = first.uppercased() + out.dropFirst()
        if let last = out.last, !".!?…。！？".contains(last) {
            out += containsCJK(out) ? "。" : "."
        }
        return out
    }

    static func containsCJK(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
    }
}

/// A short title from the words, until a model names it: the first few words, no filler.
public enum TitleNamer {
    public static func title(for words: String, maxWords: Int = 6) -> String {
        let cleaned = TranscriptCleaner.clean(words).trimmingCharacters(in: CharacterSet(charactersIn: ".!?。！？"))
        if TranscriptCleaner.containsCJK(cleaned) {
            return String(cleaned.prefix(14))
        }
        let parts = cleaned.split(separator: " ")
        let title = parts.prefix(maxWords).joined(separator: " ")
        return parts.count > maxWords ? title + "…" : title
    }
}

/// The four scripted requests Dispatch's simulation can play (the Workbench's `V2Request`).
public enum ScriptedRequest: String, CaseIterable, Sendable {
    case formula, calendar, draft, code
}

/// Real words to the script that fits them best: keywords first (English and Chinese), then
/// whether anything was taken off the screen.
public enum RequestMatcher {
    static let keywords: [(ScriptedRequest, [String])] = [
        (.formula, ["formula", "equation", "math", "integral", "derivative", "mean", "average", "solve",
                    "公式", "方程", "数学", "平均", "求解"]),
        (.calendar, ["calendar", "meeting", "afternoon", "morning", "schedule", "tomorrow", "free", "event", "invite",
                     "日历", "会议", "下午", "上午", "安排", "明天", "日程"]),
        (.draft, ["draft", "reply", "email", "write to", "message", "respond", "letter", "note to",
                  "草稿", "回复", "邮件", "写信", "消息"]),
        (.code, ["code", "bug", "fix", "test", "build", "function", "error", "crash", "refactor", "button", "page",
                 "代码", "修复", "测试", "报错", "函数"]),
    ]

    public static func match(_ words: String, tookSomething: Bool) -> ScriptedRequest {
        let text = words.lowercased()
        var best: (ScriptedRequest, Int)?
        for (request, list) in keywords {
            let hits = list.reduce(0) { $0 + (text.contains($1) ? 1 : 0) }
            if hits > 0, hits > (best?.1 ?? 0) { best = (request, hits) }
        }
        if let best { return best.0 }
        return tookSomething ? .code : .calendar
    }
}

/// Whether a focused element takes a paste: a text field, a text area, a combo or search box, or
/// editable web content. Read from Accessibility (AXReader) and judged here.
public enum PasteTarget {
    static let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]

    public static func accepts(role: String?, subrole: String?, editable: Bool) -> Bool {
        if subrole == "AXSecureTextField" { return false }
        if let role, textRoles.contains(role) { return true }
        return editable
    }
}

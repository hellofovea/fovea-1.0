import Foundation

// Oct 23, Ryan ("include all"): the dictionary, wired. Settings › Dictionary's On/Off and its
// "Also heard as" spellings reach speech recognition and the words as they're written, and a word
// the person corrects is learned. Pure, so the rules are tested without a microphone
// (Tests/CapturesCoreTests/DictionaryRulesTests.swift).

/// A word's other spellings past `DictionaryWord.heardAs`, and whether it's on: what Settings ›
/// Dictionary keeps beside the words (`dictionary-extras.json`, by the word's id).
public struct WordSpellings: Codable, Equatable, Sendable {
    public var variants: [String] = []
    public var on = true
    public init(variants: [String] = [], on: Bool = true) { self.variants = variants; self.on = on }
}

public enum DictionaryRules {
    /// The words speech recognition listens for: the ones that are on.
    public static func contextual(_ words: [DictionaryWord], extras: [String: WordSpellings]) -> [String] {
        words.filter { extras[$0.id]?.on ?? true }.map(\.word)
    }

    /// What's heard → the word, for every spelling of the words that are on, the longest first (so
    /// "fovia app" is made before "fovia").
    public static func replacements(_ words: [DictionaryWord], extras: [String: WordSpellings]) -> [(heard: String, word: String)] {
        var pairs: [(heard: String, word: String)] = []
        for w in words where extras[w.id]?.on ?? true {
            let heard = ([w.heardAs].compactMap { $0 } + (extras[w.id]?.variants ?? []))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0.lowercased() != w.word.lowercased() }
            for h in heard where !pairs.contains(where: { $0.heard.lowercased() == h.lowercased() }) {
                pairs.append((h, w.word))
            }
        }
        return pairs.sorted { $0.heard.count > $1.heard.count }
    }

    /// The words as the dictionary writes them: each spelling heard becomes its word, matched
    /// whole (not inside a longer Latin word: "fovia" isn't changed in "fovian"), case aside. A
    /// spelling in Chinese or Japanese is matched wherever it is, those scripts having no spaces.
    public static func apply(_ text: String, _ pairs: [(heard: String, word: String)]) -> String {
        var out = text
        for (heard, word) in pairs where !heard.isEmpty {
            let escaped = NSRegularExpression.escapedPattern(for: heard)
            let first = heard.unicodeScalars.first.map(isLatin) ?? false
            let last = heard.unicodeScalars.last.map(isLatin) ?? false
            let pattern = (first ? "(?<![A-Za-z0-9\\u00C0-\\u024F])" : "") + escaped + (last ? "(?![A-Za-z0-9\\u00C0-\\u024F])" : "")
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            out = regex.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out),
                                                 withTemplate: NSRegularExpression.escapedTemplate(for: word))
        }
        return out
    }

    /// The words to learn from a correction: what Fovea heard and what the person changed it to.
    /// Only a small change counts (a word or a name put right), never a rewrite: each changed span
    /// is at most three words (or six characters of Chinese) on each side; spans that differ only
    /// in case or punctuation, or that only add or only remove words, teach nothing; more than half
    /// of the words changed is a rewrite; at most three words come from one correction.
    public static func learned(heard: String, corrected: String) -> [(word: String, heardAs: String)] {
        let a = tokens(heard), b = tokens(corrected)
        guard !a.isEmpty, !b.isEmpty else { return [] }
        let spans = changes(a.map(\.key), b.map(\.key))
        let changed = spans.reduce(0) { $0 + max($1.a.count, $1.b.count) }
        guard changed * 2 <= max(a.count, b.count) else { return [] }
        var out: [(word: String, heardAs: String)] = []
        for span in spans {
            guard !span.a.isEmpty, !span.b.isEmpty else { continue }
            var was = Array(a[span.a]), now = Array(b[span.b])
            let cjk = (was + now).contains { $0.cjk }
            guard cjk ? (was.count <= 6 && now.count <= 6) : (was.count <= 3 && now.count <= 3) else { continue }
            // A character of Chinese put right is a word's, not a word: it's learned with the
            // characters beside it, up to three ("零动岛" → "灵动岛").
            if cjk, now.count < 3 {
                var after = span.b.upperBound, before = span.b.lowerBound - 1
                var beforeA = span.a.lowerBound - 1
                while now.count < 3, after < b.count, b[after].cjk {
                    now.append(b[after]); was.append(b[after]); after += 1
                }
                while now.count < 3, before >= 0, beforeA >= 0, b[before].cjk {
                    now.insert(b[before], at: 0); was.insert(a[beforeA], at: 0); before -= 1; beforeA -= 1
                }
            }
            let heardAs = join(was), word = join(now)
            guard heardAs.lowercased() != word.lowercased(), word.count >= 2 else { continue }
            if !out.contains(where: { $0.word.lowercased() == word.lowercased() }) { out.append((word, heardAs)) }
            if out.count == 3 { break }
        }
        return out
    }

    // MARK: Words, as the rules count them

    /// A Latin word (letters, digits, an apostrophe or a hyphen inside), or one CJK character;
    /// punctuation and spaces aren't words.
    struct Token: Equatable {
        var text: String
        var cjk: Bool
        var key: String { text.lowercased() }
    }

    static func tokens(_ s: String) -> [Token] {
        var out: [Token] = []
        var word = ""
        func flush() { if !word.isEmpty { out.append(Token(text: word, cjk: false)); word = "" } }
        for ch in s {
            if ch.unicodeScalars.allSatisfy(isCJK) {
                flush()
                out.append(Token(text: String(ch), cjk: true))
            } else if ch.isLetter || ch.isNumber || (!word.isEmpty && (ch == "'" || ch == "’" || ch == "-")) {
                word.append(ch)
            } else {
                flush()
            }
        }
        flush()
        return out.map { t in
            var t = t
            while let l = t.text.last, l == "'" || l == "’" || l == "-" { t.text.removeLast() }
            return t
        }
    }

    /// Words joined as they're written: a space between Latin words, none beside Chinese.
    static func join(_ ts: [Token]) -> String {
        var s = ""
        for (i, t) in ts.enumerated() {
            if i > 0, !t.cjk, !ts[i - 1].cjk { s += " " }
            s += t.text
        }
        return s
    }

    /// Where two lists of words differ: each run of the first replaced by a run of the second, by
    /// their longest common subsequence.
    static func changes(_ a: [String], _ b: [String]) -> [(a: Range<Int>, b: Range<Int>)] {
        let n = a.count, m = b.count
        var lcs = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                lcs[i][j] = a[i] == b[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
            }
        }
        var out: [(a: Range<Int>, b: Range<Int>)] = []
        var i = 0, j = 0, si = 0, sj = 0
        while i < n || j < m {
            if i < n, j < m, a[i] == b[j] {
                if si < i || sj < j { out.append((si..<i, sj..<j)) }
                i += 1; j += 1; si = i; sj = j
            } else if j < m, i == n || lcs[i][j + 1] >= lcs[i + 1][j] {
                j += 1
            } else {
                i += 1
            }
        }
        if si < n || sj < m { out.append((si..<n, sj..<m)) }
        return out
    }

    static func isLatin(_ u: Unicode.Scalar) -> Bool {
        (u.value >= 0x41 && u.value <= 0x5A) || (u.value >= 0x61 && u.value <= 0x7A) || (u.value >= 0x30 && u.value <= 0x39)
            || (u.value >= 0xC0 && u.value <= 0x24F)
    }

    static func isCJK(_ u: Unicode.Scalar) -> Bool {
        switch u.value {
        case 0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2FA1F: true
        default: false
        }
    }
}

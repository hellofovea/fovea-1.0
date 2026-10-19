import Foundation

/// A word brought in from another dictation app: the spelling to write, and, when the app kept
/// one, what it used to hear instead.
public struct ImportedWord: Equatable, Hashable, Sendable {
    public var word: String
    public var heardAs: String?

    public init(_ word: String, heardAs: String? = nil) {
        self.word = word
        self.heardAs = heardAs
    }
}

/// Reading a dictionary from another dictation app (Oct 9). None of Wispr Flow, Typeless or
/// Superwhisper documents an export, so it takes what people can get out of them:
/// - a CSV in Wispr Flow's own import layout: one column of words, or two, heard then written;
/// - a text file or a paste, one word a line ("heard → written" also reads);
/// - JSON: a list of words, or of objects with a word and what it replaces (MacWhisper's list);
/// - the property list the Mac's Text Replacements drag out (each `phrase`).
/// Then it's cleaned: trimmed, duplicates dropped regardless of case, at most `limit` words.
public enum DictionaryImport {
    public enum Format: Equatable, Sendable { case csv, text, json, plist }

    /// Wispr Flow's own import limit.
    public static let limit = 1000
    /// Longer than this is a sentence, not a word.
    public static let longest = 64

    public static func format(forFilename name: String) -> Format? {
        switch (name as NSString).pathExtension.lowercased() {
        case "csv", "tsv": .csv
        case "txt", "text", "md": .text
        case "json": .json
        case "plist": .plist
        default: nil
        }
    }

    /// A file's words, cleaned. Nil when the file isn't one it reads.
    public static func parse(_ data: Data, filename: String, existing: Set<String> = []) -> [ImportedWord]? {
        guard let format = format(forFilename: filename) else { return nil }
        let words: [ImportedWord]
        switch format {
        case .csv: words = csv(String(decoding: data, as: UTF8.self))
        case .text: words = text(String(decoding: data, as: UTF8.self))
        case .json: words = json(data)
        case .plist: words = plist(data)
        }
        return clean(words, existing: existing)
    }

    /// Pasted words, cleaned.
    public static func parse(pasted: String, existing: Set<String> = []) -> [ImportedWord] {
        clean(text(pasted), existing: existing)
    }

    /// Rows read from another app's own store (`DictationApp.localStore`): the word, and what it
    /// replaces where the app keeps one (Wispr Flow writes "phrase → replacement"), cleaned.
    public static func rows(_ rows: [(word: String, replacement: String?)], existing: Set<String> = []) -> [ImportedWord] {
        clean(rows.map { row in
            if let replacement = row.replacement, !replacement.trimmingCharacters(in: .whitespaces).isEmpty {
                return ImportedWord(replacement, heardAs: row.word)
            }
            return ImportedWord(row.word)
        }, existing: existing)
    }

    // MARK: Formats

    /// Words a line; a single line with commas is a list. "heard → written", "heard -> written"
    /// and a tab between them keep both.
    public static func text(_ text: String) -> [ImportedWord] {
        var lines = text.components(separatedBy: .newlines)
        if lines.filter({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }).count == 1, let line = lines.first(where: { $0.contains(",") }) {
            lines = line.components(separatedBy: ",")
        }
        return lines.compactMap { line in
            for arrow in ["→", "->", "=>", "\t"] where line.contains(arrow) {
                let parts = line.components(separatedBy: arrow)
                guard parts.count >= 2 else { continue }
                return ImportedWord(parts[1], heardAs: parts[0])
            }
            return ImportedWord(line)
        }
    }

    /// One column: words. Two: what it heard, then what it should write (Wispr Flow's
    /// "misspelling,correction"). A header row is skipped.
    public static func csv(_ text: String) -> [ImportedWord] {
        var rows = csvRows(text)
        if let first = rows.first, first.contains(where: { headerNames.contains($0.trimmingCharacters(in: .whitespaces).lowercased()) }) {
            rows.removeFirst()
        }
        return rows.compactMap { row in
            let cells = row.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            switch cells.count {
            case 0: return nil
            case 1: return ImportedWord(cells[0])
            default: return ImportedWord(cells[1], heardAs: cells[0])
            }
        }
    }

    private static let headerNames: Set<String> = [
        "word", "words", "phrase", "term", "terms", "vocabulary", "spelling", "misspelling", "correction",
        "heard", "heard as", "replacement", "replace", "find", "from", "to", "original",
    ]

    /// Rows of cells, with quoted cells that hold commas, quotes ("") or line breaks.
    static func csvRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var cell = ""
        var quoted = false
        var chars = Array(text)
        if text.contains("\t") && !text.contains(",") {
            chars = chars.map { $0 == "\t" ? "," : $0 }
        }
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { cell.append("\""); i += 1 } else { quoted = false }
                } else {
                    cell.append(c)
                }
            } else {
                switch c {
                case "\"": quoted = true
                case ",": row.append(cell); cell = ""
                case "\n", "\r", "\r\n":
                    row.append(cell); cell = ""
                    if row.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) { rows.append(row) }
                    row = []
                default: cell.append(c)
                }
            }
            i += 1
        }
        row.append(cell)
        if row.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) { rows.append(row) }
        return rows
    }

    private static let wordKeys = ["word", "phrase", "text", "replace", "replacement", "to", "correction", "value", "term"]
    private static let heardKeys = ["find", "original", "from", "heard", "heardAs", "heard_as", "misspelling", "search"]
    private static let listKeys = ["words", "dictionary", "vocabulary", "replacements", "items", "entries", "terms"]

    /// A list of words, or of objects naming a word and what it replaces; or an object holding
    /// such a list under `words`, `dictionary`, `vocabulary`, `replacements`….
    public static func json(_ data: Data) -> [ImportedWord] {
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return [] }
        return entries(object)
    }

    /// The Mac's Text Replacements, dragged out: each entry's `phrase` (people say the phrase;
    /// they rarely say the shortcut). A plain list of strings reads too.
    public static func plist(_ data: Data) -> [ImportedWord] {
        guard let object = try? PropertyListSerialization.propertyList(from: data, format: nil) else { return [] }
        if let list = object as? [[String: Any]] {
            return list.compactMap { ($0["phrase"] as? String).map { ImportedWord($0) } }
        }
        return entries(object)
    }

    private static func entries(_ object: Any) -> [ImportedWord] {
        if let strings = object as? [String] { return strings.map { ImportedWord($0) } }
        if let list = object as? [[String: Any]] {
            return list.compactMap { item in
                guard let word = wordKeys.lazy.compactMap({ item[$0] as? String }).first else { return nil }
                return ImportedWord(word, heardAs: heardKeys.lazy.compactMap { item[$0] as? String }.first)
            }
        }
        if let dictionary = object as? [String: Any] {
            for key in listKeys {
                if let inner = dictionary[key] { return entries(inner) }
            }
        }
        return []
    }

    // MARK: Cleaning

    /// Trimmed, spaces collapsed, quotes taken off, empty and over-long ones dropped, duplicates
    /// (and words Fovea already has) dropped regardless of case, at most `limit`.
    public static func clean(_ words: [ImportedWord], existing: Set<String> = []) -> [ImportedWord] {
        var seen = Set(existing.map { $0.lowercased() })
        var out: [ImportedWord] = []
        for item in words {
            let word = tidy(item.word)
            guard !word.isEmpty, word.count <= longest, !seen.contains(word.lowercased()) else { continue }
            seen.insert(word.lowercased())
            let heard = item.heardAs.map(tidy).flatMap { $0.isEmpty || $0.lowercased() == word.lowercased() ? nil : $0 }
            out.append(ImportedWord(word, heardAs: heard))
            if out.count == limit { break }
        }
        return out
    }

    static func tidy(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”'")))
        return trimmed.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}

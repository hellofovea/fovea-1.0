import Foundation

extension DiffHunk {
    /// The hunk with each removed line paired to the added line that replaced it (in order,
    /// within a block of removals followed by additions) and the differing middle of each pair
    /// marked, widened to whole words. Lines with no partner stay unmarked.
    public func annotated() -> DiffHunk {
        var lines = self.lines
        var i = 0
        while i < lines.count {
            guard lines[i].kind == .removed else { i += 1; continue }
            var removedEnd = i
            while removedEnd < lines.count, lines[removedEnd].kind == .removed { removedEnd += 1 }
            var addedEnd = removedEnd
            while addedEnd < lines.count, lines[addedEnd].kind == .added { addedEnd += 1 }
            let pairs = min(removedEnd - i, addedEnd - removedEnd)
            for k in 0..<pairs {
                let (old, new) = Self.changedRanges(lines[i + k].text, lines[removedEnd + k].text)
                lines[i + k].changed = old.map { [$0] } ?? []
                lines[removedEnd + k].changed = new.map { [$0] } ?? []
            }
            i = max(addedEnd, i + 1)
        }
        return DiffHunk(header: Self.header(header, counting: lines), lines: lines)
    }

    /// The `@@ -a,b +c,d @@` header with its counts made the lines' own (old = context and
    /// removed, new = context and added), so it never disagrees with the hunk under it.
    static func header(_ header: String, counting lines: [DiffLine]) -> String {
        let old = lines.filter { $0.kind != .added }.count
        let new = lines.filter { $0.kind != .removed }.count
        let parts = header.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 3, parts[0] == "@@", parts[1].hasPrefix("-"), parts[2].hasPrefix("+") else { return header }
        func recount(_ part: String, _ n: Int) -> String {
            let sign = part.prefix(1)
            let start = part.dropFirst().split(separator: ",").first.map(String.init) ?? "0"
            return "\(sign)\(start),\(n)"
        }
        var out = parts
        out[1] = recount(parts[1], old)
        out[2] = recount(parts[2], new)
        return out.joined(separator: " ")
    }

    /// UTF-16 (location, length) of the part of each string that differs from the other.
    static func changedRanges(_ a: String, _ b: String) -> ([Int]?, [Int]?) {
        let x = Array(a), y = Array(b)
        var prefix = 0
        while prefix < x.count, prefix < y.count, x[prefix] == y[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < x.count - prefix, suffix < y.count - prefix, x[x.count - 1 - suffix] == y[y.count - 1 - suffix] { suffix += 1 }
        func widen(_ chars: [Character], _ start: Int, _ end: Int) -> (Int, Int) {
            var s = start, e = end
            while s > 0, chars[s - 1].isLetter || chars[s - 1].isNumber { s -= 1 }
            while e < chars.count, chars[e].isLetter || chars[e].isNumber { e += 1 }
            return (s, e)
        }
        func utf16(_ chars: [Character], _ start: Int, _ end: Int) -> [Int]? {
            guard end > start else { return nil }
            let (s, e) = widen(chars, start, end)
            let before = String(chars[0..<s]).utf16.count
            let length = String(chars[s..<e]).utf16.count
            return [before, length]
        }
        return (utf16(x, prefix, x.count - suffix), utf16(y, prefix, y.count - suffix))
    }
}

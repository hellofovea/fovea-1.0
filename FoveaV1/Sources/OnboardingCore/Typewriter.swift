import Foundation

/// When each letter of a line appears, for the board's instructions and the notch's lines, typed
/// out as if Fovea were talking (Oct 9). Faster than reading (about 45 letters a second, where
/// reading runs near 20–25), a beat after a sentence and a shorter one after a comma, one pause for
/// an ellipsis, and never longer than about two seconds a line: a long line is typed faster.
public enum Typewriter {
    public struct Pace: Equatable, Sendable {
        public var perSecond: Double
        public var sentencePause: Double
        public var clausePause: Double
        /// The longest a line may take, pauses included.
        public var longest: Double

        public init(perSecond: Double = 45, sentencePause: Double = 0.3, clausePause: Double = 0.1, longest: Double = 2.2) {
            self.perSecond = perSecond; self.sentencePause = sentencePause; self.clausePause = clausePause
            self.longest = longest
        }
    }

    private static let sentenceEnds: Set<Character> = [".", "?", "!", "…"]
    private static let clauseEnds: Set<Character> = [",", ";", ":", "–", "—"]
    private static let closers: Set<Character> = ["\"", "”", "’", ")", "]"]
    /// Oct 18, Ryan (the first run in Chinese): Chinese marks, which no space follows.
    private static let wideSentenceEnds: Set<Character> = ["。", "？", "！"]
    private static let wideClauseEnds: Set<Character> = ["，", "；", "：", "、"]

    /// The wait before each character appears, in seconds; one per character of `text`.
    public static func delays(for text: String, pace: Pace = Pace()) -> [Double] {
        let characters = Array(text)
        guard !characters.isEmpty else { return [] }
        let step = 1 / max(1, pace.perSecond)
        var delays = [Double](repeating: step, count: characters.count)
        delays[0] = 0
        for i in 0..<(characters.count - 1) {
            let c = characters[i]
            let next = characters[i + 1]
            if wideSentenceEnds.contains(c) { delays[i + 1] += pace.sentencePause; continue }
            if wideClauseEnds.contains(c) { delays[i + 1] += pace.clausePause; continue }
            // A pause belongs after the mark (and after a closing quote that follows it), before
            // the space: never inside "..." or before a closing quote.
            guard next.isWhitespace else { continue }
            let mark = closers.contains(c) && i > 0 ? characters[i - 1] : c
            if sentenceEnds.contains(mark) {
                delays[i + 1] += pace.sentencePause
            } else if clauseEnds.contains(mark) {
                delays[i + 1] += pace.clausePause
            }
        }
        let total = delays.reduce(0, +)
        if total > pace.longest {
            let scale = pace.longest / total
            return delays.map { $0 * scale }
        }
        return delays
    }

    /// How long the whole line takes.
    public static func duration(of text: String, pace: Pace = Pace()) -> Double {
        delays(for: text, pace: pace).reduce(0, +)
    }
}

import Foundation

/// What one language's recognizer heard, and how sure it was (0…1).
public struct SpeechCandidate: Equatable, Sendable {
    public var text: String
    public var confidence: Float
    public init(text: String, confidence: Float) { self.text = text; self.confidence = confidence }

    /// Oct 23, Ryan: listening in English and Chinese at once, the words kept are the surer
    /// recognizer's; the primary language's (the first) on a tie, and whichever heard anything
    /// when the other heard nothing. Nil when none heard a word.
    public static let tie: Float = 0.05

    public static func pick(_ candidates: [SpeechCandidate]) -> Int? {
        let heard = candidates.indices.filter { !candidates[$0].text.isEmpty }
        guard let first = heard.first else { return nil }
        var best = first
        for i in heard.dropFirst() where candidates[i].confidence > candidates[best].confidence + tie { best = i }
        return best
    }
}

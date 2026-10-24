import XCTest
@testable import FoveaKit

/// Oct 23: English and Chinese listening at once; the surer words are kept.
final class SpeechPickTests: XCTestCase {
    func testTheSurerRecognizerWins() {
        let heard = [SpeechCandidate(text: "Boo lie knee the PT", confidence: 0.31), SpeechCandidate(text: "不让你the pt", confidence: 0.82)]
        XCTAssertEqual(SpeechCandidate.pick(heard), 1)
    }

    func testThePrimaryLanguageWinsATie() {
        let heard = [SpeechCandidate(text: "Fix the build", confidence: 0.80), SpeechCandidate(text: "费克斯", confidence: 0.83)]
        XCTAssertEqual(SpeechCandidate.pick(heard), 0)
    }

    func testWhicheverHeardSomething() {
        XCTAssertEqual(SpeechCandidate.pick([SpeechCandidate(text: "", confidence: 0), SpeechCandidate(text: "好的", confidence: 0)]), 1)
        XCTAssertNil(SpeechCandidate.pick([SpeechCandidate(text: "", confidence: 0.9)]))
    }
}

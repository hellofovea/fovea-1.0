import XCTest
@testable import CapturesCore

/// Oct 23: Settings › Dictionary, wired (On/Off, "Also heard as", words learned from a correction).
final class DictionaryRulesTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 0)

    func word(_ id: String, _ w: String, heard: String? = nil) -> DictionaryWord {
        DictionaryWord(id: id, word: w, heardAs: heard, source: .added, date: now)
    }

    func testOffWordsLeaveTheRecognizerAndTheReplacements() {
        let words = [word("a", "Fovea", heard: "fovia"), word("b", "Kubernetes", heard: "cooper netties")]
        let extras = ["b": WordSpellings(on: false)]
        XCTAssertEqual(DictionaryRules.contextual(words, extras: extras), ["Fovea"])
        XCTAssertEqual(DictionaryRules.replacements(words, extras: extras).map(\.word), ["Fovea"])
    }

    func testEverySpellingBecomesTheWordLongestFirst() {
        let words = [word("a", "Fovea", heard: "fovia")]
        let extras = ["a": WordSpellings(variants: ["fovia app", "four via"])]
        let pairs = DictionaryRules.replacements(words, extras: extras)
        XCTAssertEqual(pairs.first?.heard, "fovia app")
        XCTAssertEqual(DictionaryRules.apply("open four via and the fovia app", pairs), "open Fovea and the Fovea")
    }

    func testWholeWordsCaseAside() {
        let pairs = DictionaryRules.replacements([word("a", "Fovea", heard: "fovia")], extras: [:])
        XCTAssertEqual(DictionaryRules.apply("Fovia is fovian, FOVIA.", pairs), "Fovea is fovian, Fovea.")
    }

    func testChineseSpellingsMatchWithoutSpaces() {
        let pairs = DictionaryRules.replacements([word("a", "灵动岛", heard: "零动岛"), word("b", "Fovea", heard: "fovia")], extras: [:])
        XCTAssertEqual(DictionaryRules.apply("打开零动岛，用fovia发送", pairs), "打开灵动岛，用Fovea发送")
    }

    func testANameCorrectedIsLearned() {
        let learned = DictionaryRules.learned(heard: "Ask Maya and Lynn about the fovia launch.",
                                              corrected: "Ask Maya and Lin about the Fovea launch.")
        XCTAssertEqual(learned.map(\.word), ["Lin", "Fovea"])
        XCTAssertEqual(learned.map(\.heardAs), ["Lynn", "fovia"])
    }

    func testCaseOrPunctuationOnlyTeachesNothing() {
        XCTAssertTrue(DictionaryRules.learned(heard: "send it to maya", corrected: "Send it to Maya.").isEmpty)
    }

    func testAddingOrRemovingWordsTeachesNothing() {
        XCTAssertTrue(DictionaryRules.learned(heard: "fix the build", corrected: "fix the build on main please").isEmpty)
        XCTAssertTrue(DictionaryRules.learned(heard: "fix the build on main", corrected: "fix the build").isEmpty)
    }

    func testARewriteTeachesNothing() {
        XCTAssertTrue(DictionaryRules.learned(heard: "make the header blue", corrected: "move the footer down a bit").isEmpty)
    }

    func testChineseCorrection() {
        let learned = DictionaryRules.learned(heard: "把零动岛的高度改一下", corrected: "把灵动岛的高度改一下")
        XCTAssertEqual(learned.first?.word, "灵动岛")
        XCTAssertEqual(learned.first?.heardAs, "零动岛")
    }
}

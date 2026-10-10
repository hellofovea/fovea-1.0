import XCTest
import CoreGraphics
@testable import FoveaKit
import FoveaStore
import CapturesCore
import FoveaCore

final class PrefsTests: XCTestCase {
    func testPrefsRoundTripThroughTheFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fovea-prefs-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = FileStore<FoveaPrefs>(url: dir.appendingPathComponent("prefs.json"))
        var prefs = FoveaPrefs()
        prefs.notchAppearance = .light
        prefs.panels = .floating
        prefs.density = .compact
        prefs.accent = .green
        prefs.glowPalette = .ocean
        prefs.glowDrift = 0.8
        store.save(prefs)
        XCTAssertEqual(store.load(), prefs)
    }

    func testAFileWrittenBeforeAFieldExistedKeepsItsDefault() throws {
        let old = #"{"accent":"red","glowPalette":"gold"}"#.data(using: .utf8)!
        let prefs = try JSONDecoder().decode(FoveaPrefs.self, from: old)
        XCTAssertEqual(prefs.accent, .red)
        XCTAssertEqual(prefs.glowPalette, .gold)
        XCTAssertEqual(prefs.density, .spacious)
        XCTAssertEqual(prefs.panels, .attached)
        XCTAssertTrue(prefs.reviewFirst)
    }

    func testRestoringTheNotchKeepsTheGlass() {
        var prefs = FoveaPrefs()
        prefs.notchAppearance = .light
        prefs.panels = .floating
        prefs.density = .compact
        prefs.glowHue = 120
        XCTAssertFalse(prefs.notchIsDefault)
        prefs.restoreNotch()
        XCTAssertTrue(prefs.notchIsDefault)
        XCTAssertEqual(prefs.notchAppearance, .light, "Light or dark is a look the person picked, not a setting that breaks")
    }

    func testTheTemplatesLeaveOutCustom() {
        XCTAssertEqual(GlowPalette.templates.count, 8)
        XCTAssertFalse(GlowPalette.templates.contains(.custom))
    }
}

final class KeysTests: XCTestCase {
    func testATapIsShortAndAlone() {
        var g = ModifierGesture()
        XCTAssertEqual(g.down(at: 0), [.down])
        XCTAssertEqual(g.up(at: 0.1), [.up(tap: true)])
    }

    func testAHoldIsNotATap() {
        var g = ModifierGesture()
        _ = g.down(at: 0)
        XCTAssertEqual(g.up(at: 0.5), [.up(tap: false)])
    }

    func testAKeyPressedWithItIsNotATap() {
        var g = ModifierGesture()
        _ = g.down(at: 0)
        g.used()
        XCTAssertEqual(g.up(at: 0.1), [.up(tap: false)])
    }

    func testTwoTapsCloseTogetherAreADoublePress() {
        var g = ModifierGesture()
        _ = g.down(at: 0); _ = g.up(at: 0.1)
        _ = g.down(at: 0.25)
        XCTAssertEqual(g.up(at: 0.3), [.up(tap: true), .doublePress])
        // A third press starts afresh.
        _ = g.down(at: 0.4)
        XCTAssertEqual(g.up(at: 0.45), [.up(tap: true)])
    }

    func testTwoTapsFarApartAreTwoTaps() {
        var g = ModifierGesture()
        _ = g.down(at: 0); _ = g.up(at: 0.1)
        _ = g.down(at: 1)
        XCTAssertEqual(g.up(at: 1.1), [.up(tap: true)])
    }

    func testTheKeysAreRoundTwo() {
        XCTAssertEqual(FoveaKeys.voiceflow.keys, ["fn"])
        XCTAssertEqual(FoveaKeys.dispatch.keys, ["fn", "⌃"])
        XCTAssertEqual(FoveaKeys.region.keys, ["⌘"])
        XCTAssertEqual(FoveaKeys.wholeScreen.presses, 2)
        XCTAssertEqual(FoveaKeys.highlighter.keys, ["⌥"])
        XCTAssertEqual(Set(FoveaKeys.all.map(\.id)).count, FoveaKeys.all.count)
    }
}

final class WordsTests: XCTestCase {
    func testCleaningTakesTheFillersOutAndEndsTheSentence() {
        XCTAssertEqual(TranscriptCleaner.clean("um so move this up uh a little"), "So move this up a little.")
        XCTAssertEqual(TranscriptCleaner.clean("Is it done?"), "Is it done?")
        XCTAssertEqual(TranscriptCleaner.clean(""), "")
        XCTAssertEqual(TranscriptCleaner.clean("把这个移上去"), "把这个移上去。")
    }

    func testTitlesAreTheFirstWords() {
        XCTAssertEqual(TitleNamer.title(for: "fix the spacing on the second screen please", maxWords: 4), "Fix the spacing on…")
        XCTAssertEqual(TitleNamer.title(for: "Pull up my calendar"), "Pull up my calendar")
    }

    func testRequestsMatchTheirScript() {
        XCTAssertEqual(RequestMatcher.match("what does this formula mean", tookSomething: true), .formula)
        XCTAssertEqual(RequestMatcher.match("am I free this afternoon", tookSomething: false), .calendar)
        XCTAssertEqual(RequestMatcher.match("draft a reply to Sam", tookSomething: false), .draft)
        XCTAssertEqual(RequestMatcher.match("fix this bug in the button", tookSomething: true), .code)
        XCTAssertEqual(RequestMatcher.match("帮我回复这封邮件", tookSomething: false), .draft)
        // Nothing to go on: what was taken decides.
        XCTAssertEqual(RequestMatcher.match("hmm", tookSomething: true), .code)
        XCTAssertEqual(RequestMatcher.match("hmm", tookSomething: false), .calendar)
    }

    func testOnlyTextTakesAPaste() {
        XCTAssertTrue(PasteTarget.accepts(role: "AXTextArea", subrole: nil, editable: false))
        XCTAssertTrue(PasteTarget.accepts(role: "AXWebArea", subrole: nil, editable: true))
        XCTAssertFalse(PasteTarget.accepts(role: "AXButton", subrole: nil, editable: false))
        XCTAssertFalse(PasteTarget.accepts(role: "AXTextField", subrole: "AXSecureTextField", editable: true))
    }
}

final class StoreTests: XCTestCase {
    @MainActor
    func testCapturesAreKeptNewestFirst() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fovea-store-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let location = DataLocation(root: dir)
        location.prepare()
        let library = CaptureLibrary(location: location)
        XCTAssertTrue(library.captures.isEmpty, "Home starts empty: no samples")
        let older = Capture(id: "a", kind: .dictation, time: Date(timeIntervalSinceNow: -60), app: AppRef("Notes", "com.apple.Notes"),
                            text: "First", theme: "First", seconds: 2)
        let newer = Capture(id: "b", kind: .dispatch, time: Date(), app: AppRef("Safari", "com.apple.Safari"),
                            text: "Second", destination: Destination("Claude Code", chat: "New chat"), theme: "Second", seconds: 3)
        library.add(older)
        library.add(newer)
        XCTAssertEqual(library.captures.map(\.id), ["b", "a"])
        library.flush()
        let reopened = CaptureLibrary(location: location)
        XCTAssertEqual(reopened.captures.map(\.id), ["b", "a"])
    }

    @MainActor
    func testTheDictionaryAddsEachWordOnce() {
        let words = DictionaryStore(location: nil)
        XCTAssertEqual(words.add([(word: "Fovea", heardAs: "for via"), (word: "fovea", heardAs: nil), (word: " ", heardAs: nil)]), 1)
        XCTAssertEqual(words.contextualStrings, ["Fovea"])
        XCTAssertEqual(words.replacements.first?.word, "Fovea")
    }
}

final class GeometryTests: XCTestCase {
    /// This Mac's notch: 179 pt wide on a 1470×956 display (the mock was 200). The island must still
    /// be centered on it and wider than it.
    func testTheVoiceBarFitsTheRealNotch() {
        let metrics = ScreenMetrics.notched(size: CGSize(width: 1470, height: 956), notchWidth: 179)
        let spec = IslandLayoutSpec()
        let notch = NotchGeometry.notchRect(metrics: metrics, spec: spec)
        XCTAssertEqual(notch.width, 179, accuracy: 0.5)
        XCTAssertEqual(notch.midX, 735, accuracy: 0.5)
        let voice = NotchGeometry.frames(density: .voice, metrics: metrics, spec: spec)
        XCTAssertGreaterThan(voice.width, notch.width)
    }
}

import XCTest
@testable import OnboardingCore

final class OnboardingCoreTests: XCTestCase {
    func testStagesRunInOrderWithDictationNearTheEnd() {
        let stages = Step.allCases.map(\.stage)
        XCTAssertEqual(stages, stages.sorted { $0.rawValue < $1.rawValue }, "steps are grouped by stage, in order")
        let first = { (stage: Stage) in Step.allCases.firstIndex { $0.stage == stage }! }
        XCTAssertLessThan(first(.turnOn), first(.agents))
        XCTAssertLessThan(first(.agents), first(.pointAndSay))
        XCTAssertLessThan(first(.pointAndSay), first(.dictation))
        XCTAssertEqual(Step.allCases.first, .name, "Fovea 1.0 (Oct 9): the run opens on the name, then the email, then hello")
        XCTAssertEqual(Array(Step.allCases.prefix(3)), [.name, .signIn, .hello])
        XCTAssertEqual(Step.allCases.last, .home)
    }

    func testHelloThenMakeItYoursComeFirst() {
        var flow = Flow()
        XCTAssertEqual(flow.step, .name)
        XCTAssertNil(flow.advance(), "a name first")
        flow.record(.named)
        XCTAssertEqual(flow.advance(), .signIn)
        XCTAssertNil(flow.advance(), "then an email")
        flow.record(.signedIn)
        XCTAssertEqual(flow.advance(), .hello)
        XCTAssertTrue(flow.isComplete)
        XCTAssertEqual(flow.advance(), .makeItYours)
        XCTAssertEqual(flow.step.stage, .arrive)
        flow.personal.accent = .green
        flow.personal.aura = .ocean
        XCTAssertEqual(flow.advance(), .permissions)
        XCTAssertEqual(flow.personal, Personalization(accent: .green, aura: .ocean), "the choices carry on")
    }

    func testPersonalizationDefaultsMatchSettings() {
        let defaults = Personalization()
        XCTAssertEqual(defaults.accent, .multicolor)
        XCTAssertEqual(defaults.aura, .colorful)
        XCTAssertEqual(defaults.auraHue, 0)
        XCTAssertEqual(defaults.auraDrift, 0.5, "drift is a spectrum, from still to lively")
        XCTAssertFalse(AuraPalette.mono.turns)
        XCTAssertEqual(AccentName.allCases.count, 9)
        // The first run offers the eight templates; Custom is Settings' (one palette type, FoveaKit's).
        XCTAssertEqual(AuraPalette.templates.count, 8)
        XCTAssertFalse(AuraPalette.templates.contains(.custom))
    }

    /// The keys the first run teaches are the ones Settings › Shortcuts shows and the notch acts on.
    func testTheFirstRunTeachesFoveasKeys() {
        let keys = KeyMap.current
        XCTAssertEqual(keys.request, FoveaKeys.dispatch.keys)
        XCTAssertEqual(keys.dictation, FoveaKeys.voiceflow.keys)
        XCTAssertEqual(keys.screenshot, FoveaKeys.region.keys)
        XCTAssertEqual(keys.highlighter, FoveaKeys.highlighter.keys)
        XCTAssertEqual(keys.presses(for: .wholeScreen), FoveaKeys.wholeScreen.presses)
    }

    func testBothListsAreOneStepThenTheMicrophone() {
        var flow = Flow(start: .permissions)
        XCTAssertNil(flow.advance(), "can't move on before it's allowed")
        flow.allow(.accessibility)
        XCTAssertNil(flow.advance(), "one list isn't both")
        flow.allow(.screenRecording)
        XCTAssertEqual(flow.advance(), .microphone)
        flow.allow(.microphone)
        XCTAssertNil(flow.advance(), "allowed isn't enough: the microphone has to hear you")
        flow.record(.heard)
        XCTAssertEqual(flow.advance(), .agents, "the coding agents come right after the permissions")
        XCTAssertEqual(flow.allowed, [.accessibility, .microphone, .screenRecording])

        var other = Flow(start: .permissions)
        other.allow(.screenRecording)
        other.allow(.accessibility)
        XCTAssertTrue(other.isComplete, "either list first")
    }

    func testTheMicrophoneTestHasALineToSay() {
        XCTAssertEqual(Copy.step(.microphone).script, "Hey Fovea, can you hear me?")
        XCTAssertEqual(Copy.micHeard, "Loud and clear.")
        XCTAssertFalse(Copy.step(.microphone).body.lowercased().contains("anything"))
    }

    func testTheWorkTabsAndTheTrip() {
        XCTAssertEqual(PracticeTab.open(for: .weeklyUpdate), [.analytics, .github, .support])
        XCTAssertEqual(PracticeTab.open(for: .packList).last, .trail, "the trip's tab joins for the packing list")
        XCTAssertEqual(Beat.prs.tab, .github)
        XCTAssertEqual(Beat.tickets.tab, .support)
    }

    func testAgentsConnectThenTheWorkStartsNoSignInNoDemo() {
        var flow = Flow(start: .agents)
        XCTAssertNil(flow.advance())
        flow.record(.agentsConnected)
        XCTAssertEqual(flow.advance(), .weeklyUpdate, "connected is connected: straight to doing it")
        // Signing in is the run's first step (Fovea 1.0), never after the agents.
        XCTAssertLessThan(Step.allCases.firstIndex(of: .signIn)!, Step.allCases.firstIndex(of: .agents)!)
        XCTAssertFalse(Step.allCases.map(\.rawValue).contains("captureShow"), "you learn by doing: no demo")
        XCTAssertEqual(Agent.supported, [.claudeCode, .codex])
        XCTAssertFalse(Agent.comingNext.isEmpty, "a say in what comes next")
    }

    func testThePracticeCoversEveryKindOfCapture() {
        let practice = Step.allCases.filter { $0.stage == .pointAndSay }
        let beats = Set(practice.flatMap { $0.beats.flatMap { $0 } })
        for kind in [Beat.requestKey, .wholeScreen, .prs, .tickets, .passage, .file, .send, .answer] {
            XCTAssertTrue(beats.contains(kind), "\(kind) is practiced")
        }
        XCTAssertEqual(Step.weeklyUpdate.beats.filter { $0.contains(.wholeScreen) || $0.contains(.prs) || $0.contains(.tickets) }.count, 3,
                       "the work task gathers three things: the screen and two parts")
        XCTAssertNotEqual(Beat.prs.tab, Beat.tickets.tab, "from two different tabs")
        XCTAssertTrue(Step.packList.beats.contains([.passage]) && Step.packList.beats.contains([.file]),
                      "the other takes words and a file")
    }

    func testTheUpdateTeachesTheWholeScreenFirstButTakesAnyOrder() {
        var flow = Flow(start: .weeklyUpdate)
        XCTAssertTrue(flow.record(.requestKey))
        XCTAssertEqual(flow.waitingFor, [.wholeScreen], "the keyboard asks for ⌘ twice first")
        XCTAssertEqual(KeyMap.current.keys(for: .wholeScreen), ["⌘"])
        XCTAssertEqual(KeyMap.current.presses(for: .wholeScreen), 2, "shown as ×2")
        XCTAssertEqual(KeyMap.current.presses(for: .prs), 1)

        // The tickets first, then the pull requests, then the screen, still counts.
        XCTAssertTrue(flow.record(.tickets))
        XCTAssertFalse(flow.record(.tickets), "the tickets again: nothing new")
        XCTAssertNil(flow.missedBeat, "and nothing wrong")
        XCTAssertTrue(flow.record(.prs))
        XCTAssertTrue(flow.record(.wholeScreen))
        XCTAssertEqual(flow.waitingFor, [.finish])
        for beat in [Beat.finish, .review, .send] { XCTAssertTrue(flow.record(beat), "\(beat)") }
        XCTAssertTrue(flow.isComplete)
        XCTAssertEqual(flow.advance(), .hover, "sent: watch it work")
    }

    func testFinishingBeforeTakingAnythingIsMissed() {
        var flow = Flow(start: .packList)
        XCTAssertTrue(flow.record(.requestKey))
        XCTAssertFalse(flow.record(.finish))
        XCTAssertEqual(flow.missedBeat, .finish)
        flow.retry()
        for beat in [Beat.requestKey, .file, .passage, .finish, .review, .send, .answer] {
            XCTAssertTrue(flow.record(beat), "\(beat)")
        }
        XCTAssertTrue(flow.isComplete)
        XCTAssertEqual(flow.advance(), .followUp)
    }

    func testTheHoverWaitsForTheNotchAndTheAnswerInEitherOrder() {
        for order in [[Beat.hoverNotch, .answer], [.answer, .hoverNotch]] {
            var flow = Flow(start: .hover)
            for beat in order { XCTAssertTrue(flow.record(beat), "\(order): \(beat)") }
            XCTAssertTrue(flow.isComplete, "\(order)")
        }
    }

    func testDictationTakesTwoWindows() {
        var flow = Flow(start: .dictation)
        for beat in [Beat.feedbackKey, .feedbackLanded] { XCTAssertTrue(flow.record(beat)) }
        XCTAssertFalse(flow.isComplete, "the feedback alone isn't both windows")
        for beat in [Beat.replyKey, .replyLanded] { XCTAssertTrue(flow.record(beat)) }
        XCTAssertTrue(flow.isComplete)
        XCTAssertEqual(flow.advance(), .dictionary)
        XCTAssertEqual(flow.advance(), .home)
    }

    func testEveryStepHasAWayPast() {
        // Hello, Make it yours and Home can't fail: their button always works.
        // Signing in and the name are asked for, not skipped (Fovea 1.0).
        let alwaysOpen: Set<Step> = [.signIn, .name, .hello, .makeItYours, .home]
        for step in Step.allCases where !alwaysOpen.contains(step) {
            XCTAssertTrue(step.skip.allowed, "\(step) needs a backup")
            var flow = Flow(start: step)
            XCTAssertNotNil(flow.skip(), "\(step)")
        }
        XCTAssertEqual(Step.weeklyUpdate.skip, .after(15), "a task waits before offering Skip")
    }

    func testSkippingDictationSkipsAllOfItButNotTheDictionary() {
        var flow = Flow(start: .dictationIntro)
        XCTAssertEqual(flow.skip(), .dictionary)
        XCTAssertTrue(flow.dictationSkipped)
        XCTAssertEqual(flow.skip(), .home, "Not now")
    }

    func testLanguagesAreEnglishAndChineseWithMoreTyped() {
        XCTAssertEqual(Language.allCases, [.english, .chinese])
        XCTAssertEqual(Language.featured, [.english, .chinese])
        XCTAssertEqual(Language.chinese.title, "Chinese")
        XCTAssertEqual(Language.preferred(["zh-Hans-CN", "en-US"]), .chinese)
        XCTAssertEqual(Language.preferred(["en-GB"]), .english)
        XCTAssertEqual(Language.preferred(["fr-FR"]), .english)
        var flow = Flow()
        XCTAssertEqual(flow.language, .english)
        flow.languageRequest = "Japanese"
        XCTAssertEqual(flow.languageRequest, "Japanese", "kept as a request")
    }

    func testJumpingPastStepsCountsThemDone() {
        var flow = Flow()
        flow.jump(to: .weeklyUpdate)
        XCTAssertEqual(flow.allowed, [.accessibility, .microphone, .screenRecording])
        XCTAssertTrue(flow.agentsConnected)
        XCTAssertEqual(flow.done, [])
    }

    func testTheKeyboardLightsTheKeysForNow() {
        let keys = KeyMap.current
        var flow = Flow(start: .weeklyUpdate)
        XCTAssertEqual(keys.keys(for: flow.waitingFor!.first!), ["fn", "⌃"], "first, fn ⌃")
        flow.record(.requestKey)
        XCTAssertEqual(keys.keys(for: flow.waitingFor!.first!), ["⌘"], "then ⌘, twice")
        flow.record(.wholeScreen)
        XCTAssertEqual(keys.keys(for: flow.waitingFor!.first!), ["⌘"], "then ⌘ once in the GitHub tab")
        flow.record(.prs)
        XCTAssertEqual(keys.keys(for: flow.waitingFor!.first!), ["⌘"], "and once in the Support tab")
        flow.record(.tickets)
        XCTAssertEqual(keys.keys(for: flow.waitingFor!.first!), ["fn", "⌃"], "fn ⌃ again to finish")
        XCTAssertEqual(keys.keys(for: .send), ["return"])
        XCTAssertEqual(keys.keys(for: .passage), ["⌥"])
        XCTAssertEqual(keys.keys(for: .feedbackKey), ["fn"])
        XCTAssertTrue(Step.weeklyUpdate.showsKeyboard && Step.dictation.showsKeyboard)
        XCTAssertFalse(Step.permissions.showsKeyboard || Step.makeItYours.showsKeyboard || Step.home.showsKeyboard,
                       "no keyboard where no keys are taught")
    }

    func testInstructionsFollowTheStepTheTabAndWhetherAKeyIsArmed() {
        XCTAssertEqual(Copy.instruction(.prs, step: .weeklyUpdate, tab: .analytics), "Now click the GitHub tab.")
        XCTAssertEqual(Copy.instruction(.prs, step: .weeklyUpdate, tab: .github), "Press ⌘ once, then drag over the merged pull requests.")
        XCTAssertEqual(Copy.instruction(.prs, step: .weeklyUpdate, armed: true, tab: .github), "Drag over the merged pull requests.")
        XCTAssertEqual(Copy.instruction(.tickets, step: .weeklyUpdate, tab: .github), "Now click the Support tab.")
        XCTAssertTrue(Copy.instruction(.wholeScreen, step: .weeklyUpdate)!.contains("twice"))
        XCTAssertEqual(Copy.instruction(.send, step: .packList, agent: "Claude Code"), "Press return to send it to Claude Code.")
        XCTAssertNil(Copy.instruction(.allowedAccessibility, step: .permissions), "the lists say enough by their names")
        XCTAssertNil(Copy.instruction(.heard, step: .microphone), "the line says enough")
        let swapped = KeyMap(screenshot: ["⌥"], highlighter: ["⌘"])
        XCTAssertTrue(Copy.instruction(.passage, step: .packList, keys: swapped)!.contains("Hold ⌘"), "key names come from the map")
    }

    func testCopyMakesNoSpeedClaims() {
        for step in Step.allCases {
            let copy = Copy.step(step, agents: Agent.allCases)
            var text = [copy.caption, copy.title, copy.body, copy.script ?? "", copy.help ?? "", copy.skipNote ?? ""]
            for beat in Beat.allCases { text.append(Copy.instruction(beat, step: step) ?? "") }
            let joined = text.joined(separator: " ").lowercased()
            for banned in ["faster", "wpm", "words per minute", "time saved", "!"] {
                XCTAssertFalse(joined.contains(banned), "\(step) says \(banned)")
            }
        }
    }

    func testFewWords() {
        XCTAssertEqual(Copy.step(.agents, agents: [.claudeCode]).button, "Connect")
        XCTAssertEqual(Copy.step(.agents, agents: []).button, "Use the practice agent")
        XCTAssertEqual(Copy.step(.hover, agents: [.claudeCode]).caption, "Claude Code is on it.")
        XCTAssertEqual(Copy.step(.hello, name: "Ryan").title, "Hello, Ryan.", "hello greets you by name")
        XCTAssertEqual(Copy.step(.hello).body, "Talk to any agent from your window.", "and then the one line")
        XCTAssertEqual(Copy.step(.permissions).title, "Grant Fovea Access")
        XCTAssertEqual(Copy.step(.permissions).body, "")
        XCTAssertEqual(Copy.step(.weeklyUpdate).caption, "Dispatch from anywhere.")
        for step in Step.allCases where !step.isReading {
            XCTAssertEqual(Copy.step(step).body, "", "\(step): a doing step has one caption, no paragraph")
        }
        XCTAssertEqual(Copy.step(.home).body, "", "the end is two short parts")
    }

    // MARK: Typed out, letter by letter

    func testTypingPausesAfterSentencesAndClauses() {
        let text = "Hi. I live up here."
        let delays = Typewriter.delays(for: text)
        XCTAssertEqual(delays.count, text.count)
        XCTAssertEqual(delays[0], 0, "the first letter at once")
        let space = Array(text).firstIndex(of: " ")!
        XCTAssertEqual(delays[space], 1.0 / 45 + 0.3, accuracy: 0.0001, "a beat after the sentence")
        XCTAssertEqual(delays[space + 1], 1.0 / 45, accuracy: 0.0001)

        let clause = Typewriter.delays(for: "Hold ⌥, then drag.")
        let comma = Array("Hold ⌥, then drag.").firstIndex(of: ",")!
        XCTAssertEqual(clause[comma + 1], 1.0 / 45 + 0.1, accuracy: 0.0001, "a shorter one after a comma")

        let quote = Typewriter.delays(for: "Say “can you hear me?” now")
        let close = Array("Say “can you hear me?” now").firstIndex(of: "”")!
        XCTAssertEqual(quote[close], 1.0 / 45, accuracy: 0.0001, "no pause before the closing quote")
        XCTAssertEqual(quote[close + 1], 1.0 / 45 + 0.3, accuracy: 0.0001, "the pause comes after it")

        let dots = Typewriter.delays(for: "Wait... now")
        XCTAssertEqual(dots.filter { $0 > 0.2 }.count, 1, "one pause for an ellipsis")
    }

    func testALongLineIsTypedFaster() {
        let long = String(repeating: "A long instruction, with words. ", count: 8)
        XCTAssertLessThanOrEqual(Typewriter.duration(of: long), 2.2 + 0.0001)
        XCTAssertEqual(Typewriter.duration(of: ""), 0)
    }

    // MARK: Bringing your words

    func testACSVOfWordsWithAHeader() {
        let csv = "word\nFovea\nClaude Code\n\nfovea\n"
        let words = DictionaryImport.parse(Data(csv.utf8), filename: "words.csv")!
        XCTAssertEqual(words, [ImportedWord("Fovea"), ImportedWord("Claude Code")], "header gone, blank gone, duplicate gone")
    }

    func testACSVOfHeardThenWritten() {
        let csv = "misspelling,correction\nfavea,Fovea\n\"cloud, code\",Claude Code\n"
        let words = DictionaryImport.parse(Data(csv.utf8), filename: "wispr.csv")!
        XCTAssertEqual(words, [ImportedWord("Fovea", heardAs: "favea"), ImportedWord("Claude Code", heardAs: "cloud, code")])
    }

    func testTextAndPastes() {
        XCTAssertEqual(DictionaryImport.parse(pasted: "  Fovea  \nHeyClicky\n\n Wispr   Flow "),
                       [ImportedWord("Fovea"), ImportedWord("HeyClicky"), ImportedWord("Wispr Flow")])
        XCTAssertEqual(DictionaryImport.parse(pasted: "Fovea, Codex, Cursor"),
                       [ImportedWord("Fovea"), ImportedWord("Codex"), ImportedWord("Cursor")], "one line with commas is a list")
        XCTAssertEqual(DictionaryImport.parse(pasted: "favea → Fovea\nkodex -> Codex"),
                       [ImportedWord("Fovea", heardAs: "favea"), ImportedWord("Codex", heardAs: "kodex")])
    }

    func testJSONListsAndReplacements() {
        let strings = #"["Fovea", "Typeless"]"#
        XCTAssertEqual(DictionaryImport.parse(Data(strings.utf8), filename: "a.json"), [ImportedWord("Fovea"), ImportedWord("Typeless")])
        let pairs = #"[{"find": "favea", "replace": "Fovea"}, {"word": "Codex"}]"#
        XCTAssertEqual(DictionaryImport.parse(Data(pairs.utf8), filename: "b.json"),
                       [ImportedWord("Fovea", heardAs: "favea"), ImportedWord("Codex")])
        let nested = #"{"vocabulary": ["Notch", "Island"]}"#
        XCTAssertEqual(DictionaryImport.parse(Data(nested.utf8), filename: "c.json"), [ImportedWord("Notch"), ImportedWord("Island")])
    }

    func testTextReplacementsPlistTakesThePhrase() throws {
        let list: [[String: String]] = [["phrase": "On my way", "shortcut": "omw"], ["phrase": "Fovea", "shortcut": "fv"]]
        let data = try PropertyListSerialization.data(fromPropertyList: list, format: .xml, options: 0)
        XCTAssertEqual(DictionaryImport.parse(data, filename: "Text Substitutions.plist"),
                       [ImportedWord("On my way"), ImportedWord("Fovea")])
    }

    func testCleaningDropsWhatFoveaHasAndCapsTheCount() {
        let words = DictionaryImport.clean([ImportedWord("fovea"), ImportedWord("New"), ImportedWord("new"),
                                            ImportedWord(String(repeating: "x", count: 80)), ImportedWord("Same", heardAs: "same")],
                                           existing: ["Fovea"])
        XCTAssertEqual(words, [ImportedWord("New"), ImportedWord("Same")], "known, repeated and over-long words dropped")
        let many = (0..<1500).map { ImportedWord("word\($0)") }
        XCTAssertEqual(DictionaryImport.clean(many).count, DictionaryImport.limit)
        XCTAssertNil(DictionaryImport.parse(Data(), filename: "words.docx"), "not a format it reads")
    }

    func testRowsFromAnotherAppsStore() {
        let words = DictionaryImport.rows([(word: "favea", replacement: "Fovea"), (word: "Codex", replacement: nil),
                                           (word: "codex", replacement: ""), (word: "  ", replacement: nil)])
        XCTAssertEqual(words, [ImportedWord("Fovea", heardAs: "favea"), ImportedWord("Codex")],
                       "a replacement is the word, what it replaced is what it's heard as; duplicates and blanks gone")
        XCTAssertTrue(DictationApp.wisprFlow.connects && DictationApp.voiceOS.connects, "these keep their words on this Mac")
        XCTAssertFalse(DictationApp.typeless.connects, "Typeless keeps them online")
        XCTAssertTrue(DictationApp.wisprFlow.localStore!.query.contains("isDeleted = 0"), "deleted words stay behind")
        XCTAssertTrue(DictationApp.wisprFlow.localStore!.query.contains("isSnippet = 0"), "and snippets aren't words")
    }

    func testDictationAppsAreFoundByNameOnly() {
        for app in DictationApp.allCases where !app.isSystem {
            XCTAssertFalse(app.bundleIDs.isEmpty && app.appNames.isEmpty, "\(app) can be found")
        }
        XCTAssertTrue(DictationApp.typeless.howTo.contains("paste"), "words online: a paste")
        XCTAssertTrue(DictationApp.macWhisper.howTo.contains("drop"), "an export: a drop")
    }
}

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
        // The eight templates, then Customize (Oct 18, Ryan): one palette type, FoveaKit's.
        XCTAssertEqual(AuraPalette.templates.count, 8)
        XCTAssertFalse(AuraPalette.templates.contains(.custom))
        XCTAssertEqual(Personalization.tiles, AuraPalette.templates + [.custom])
        XCTAssertEqual(Copy.customizeAura, "Customize")
    }

    /// Oct 18, Ryan: "changing the hue should not change the color scheme provided". A palette is
    /// drawn at its own colors and the default drift; only Customize at the person's. The same
    /// rule as FoveaPrefs' drawn glow, which the notch draws with.
    func testThePalettesAreFixedAndOnlyCustomizeTurns() {
        for aura in Personalization.tiles {
            let mine = Personalization(aura: aura, auraHue: 200, auraDrift: 0.9)
            var prefs = FoveaPrefs()
            prefs.glowPalette = aura
            prefs.glowHue = 200
            prefs.glowDrift = 0.9
            XCTAssertEqual(mine.drawnHue, prefs.drawnGlowHue, "\(aura)")
            XCTAssertEqual(mine.drawnDrift, prefs.drawnGlowDrift, "\(aura)")
            XCTAssertEqual(mine.drawnHue, aura == .custom ? 200 : 0, "\(aura)")
            XCTAssertEqual(mine.drawnDrift, aura == .custom ? 0.9 : 0.5, "\(aura)")
        }
    }

    /// The keys the first run teaches are the ones Settings › Shortcuts shows and the notch acts on.
    func testTheFirstRunTeachesFoveasKeys() {
        let keys = KeyMap.current
        XCTAssertEqual(keys.request, FoveaKeys.dispatch.keys)
        XCTAssertEqual(keys.dictation, FoveaKeys.voiceflow.keys)
        XCTAssertEqual(keys.screenshot, FoveaKeys.region.keys)
        // Oct 17, Ryan: ⌥ takes pictures, not ⌘; words and files need no key.
        XCTAssertEqual(keys.screenshot, ["⌥"])
        XCTAssertEqual(FoveaKeys.highlighter.keys, [])
        XCTAssertNil(FoveaKeys.chord(FoveaKeys.highlighter.id, FoveaPrefs()))
        XCTAssertEqual(keys.keys(for: .passage), [], "select the words: no key lights")
        XCTAssertEqual(keys.keys(for: .file), [], "click the file: no key lights")
        XCTAssertFalse(Step.packList.keys.contains(.screenshot))
        // Round 2: ⌥ once only (twice brings up Claude). Oct 18, Ryan: ⌘ twice is the whole screen.
        XCTAssertTrue(FoveaKeys.whileSpeaking.contains(FoveaKeys.wholeScreen))
        XCTAssertEqual(keys.wholeScreen, FoveaKeys.wholeScreen.keys)
        XCTAssertEqual(keys.presses(.wholeScreen), FoveaKeys.wholeScreen.presses)
        XCTAssertEqual(keys.presses(.screenshot), 1, "⌥ once")
        XCTAssertTrue(Beat.allCases.allSatisfy { keys.presses(for: $0) == 1 }, "the weekly update's parts are ⌥ once each")
    }

    /// Oct 17, Ryan (round 2): "right now it just jumps over". The permissions page is never passed
    /// over, even with everything allowed already; it shows them allowed, and Continue goes on.
    func testThePermissionsPageNeverJumps() {
        var flow = Flow(start: .makeItYours)
        flow.allow(.accessibility)
        flow.allow(.screenRecording)
        XCTAssertEqual(flow.advance(), .permissions, "not passed over")
        XCTAssertTrue(flow.isComplete, "both shown allowed: Continue goes on")
        XCTAssertEqual(flow.advance(), .microphone)
        var resumed = Flow()
        resumed.allow(.accessibility)
        resumed.jump(to: .permissions)
        XCTAssertFalse(resumed.isComplete, "one allowed isn't both")
        XCTAssertEqual(resumed.done, [.allowedAccessibility], "but it shows as allowed")
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
        XCTAssertEqual(PracticeTab.open(for: .weeklyUpdate), [.analytics, .github], "Oct 18, Ryan: two parts, two tabs")
        XCTAssertEqual(PracticeTab.open(for: .packList).last, .trail, "the trip's tab joins for the packing list")
        XCTAssertEqual(Beat.numbers.tab, .analytics)
        XCTAssertEqual(Beat.prs.tab, .github)
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
        for kind in [Beat.requestKey, .numbers, .prs, .passage, .file, .send, .answer] {
            XCTAssertTrue(beats.contains(kind), "\(kind) is practiced")
        }
        // Oct 18, Ryan: "only have two screenshot tasks".
        XCTAssertEqual(Step.weeklyUpdate.beats.filter { group in group.contains { KeyMap.current.keys(for: $0) == ["⌥"] } }.count, 2,
                       "the work task takes two parts with ⌥")
        XCTAssertNotEqual(Beat.numbers.tab, Beat.prs.tab, "from two different tabs")
        XCTAssertTrue(Step.packList.beats.contains([.passage]) && Step.packList.beats.contains([.file]),
                      "the other takes words and a file")
    }

    /// Oct 17, Ryan (round 2): ⌥ once each, no whole screen. Oct 18: two parts, from two tabs.
    func testTheUpdateTeachesTheNumbersFirstButTakesAnyOrder() {
        var flow = Flow(start: .weeklyUpdate)
        XCTAssertTrue(flow.record(.requestKey))
        XCTAssertEqual(flow.waitingFor, [.numbers], "the keyboard asks for this week's numbers first")
        XCTAssertEqual(KeyMap.current.keys(for: .numbers), ["⌥"])
        XCTAssertEqual(KeyMap.current.presses(for: .numbers), 1, "once")
        XCTAssertEqual(Beat.numbers.tab, .analytics)
        XCTAssertEqual(Set([Beat.numbers, .prs].compactMap(\.tab)).count, 2, "a part from each tab")
        XCTAssertEqual([Beat.numbers, .prs].compactMap(\.part), ["numbers", "prs"])

        // The pull requests first, then the numbers, still counts.
        XCTAssertTrue(flow.record(.prs))
        XCTAssertFalse(flow.record(.prs), "the pull requests again: nothing new")
        XCTAssertNil(flow.missedBeat, "and nothing wrong")
        XCTAssertTrue(flow.record(.numbers))
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

    /// Oct 17, Ryan: the intro lists what works while talking; in the feedback, something is taken
    /// while talking, and it lands after the words.
    func testDictationTeachesTakingWhileTalking() {
        let lines = Copy.whileDictating()
        XCTAssertEqual(lines.map(\.caps), [["⌥"], ["⌘"], []], "⌥, ⌘ twice, and no key for words or a file")
        XCTAssertEqual(lines.map(\.presses), [1, 2, 1])
        // Oct 18, Ryan: named for what they take, how in a second line.
        XCTAssertEqual(lines.map(\.title), ["Screenshot", "Whole screen", "Selected text and files"])
        XCTAssertEqual(lines.map(\.detail), ["Press ⌥, then drag over it.", "Press ⌘ twice.", "Select words, or drag a file onto the notch."])
        XCTAssertTrue(Copy.step(.dictationIntro).body.contains("what you take lands after them"))
        var recorded = FoveaPrefs()
        recorded.shortcutChords[FoveaKeys.region.id] = KeyChord(modifiers: ["right ⌥"])
        XCTAssertEqual(Copy.whileDictating(keys: KeyMap(prefs: recorded))[0].caps, ["right ⌥"], "the person's own keys")
        XCTAssertEqual(KeyMap.current.keys(for: .feedbackTaken), ["⌥", "⌘"], "the keyboard lights ⌥, and ⌘ for the whole screen")
        XCTAssertEqual(KeyMap.current.badges(for: .feedbackTaken), ["⌘": "×2"], "⌘ twice")
        XCTAssertEqual(KeyMap.current.badges(for: .numbers), [:], "the weekly update's parts: ⌥ once")
        XCTAssertTrue(Copy.instruction(.feedbackTaken, step: .dictation)!.contains("press ⌥, then drag"))
        XCTAssertTrue(Copy.instruction(.feedbackTaken, step: .dictation)!.contains("press ⌘ twice for all of it"))

        var flow = Flow(start: .dictation)
        XCTAssertTrue(flow.record(.feedbackKey))
        XCTAssertFalse(flow.record(.feedbackLanded), "words landed before anything was taken")
        XCTAssertEqual(flow.missedBeat, .feedbackLanded, "missed: said, and tried again")
        XCTAssertTrue(Copy.dictationMissed().contains("press ⌥ and drag"))
        flow.retry()
        for beat in [Beat.feedbackKey, .feedbackTaken, .feedbackLanded] { XCTAssertTrue(flow.record(beat), "\(beat)") }
        XCTAssertEqual(Step.dictation.skip, .now, "skippable, as the rest of dictation")
    }

    func testDictationTakesTwoWindows() {
        var flow = Flow(start: .dictation)
        for beat in [Beat.feedbackKey, .feedbackTaken, .feedbackLanded] { XCTAssertTrue(flow.record(beat)) }
        XCTAssertFalse(flow.isComplete, "the feedback alone isn't both windows")
        for beat in [Beat.replyKey, .replyLanded] { XCTAssertTrue(flow.record(beat)) }
        XCTAssertTrue(flow.isComplete)
        XCTAssertEqual(flow.advance(), .dictionary)
        XCTAssertEqual(flow.advance(), .memory, "what Fovea remembers, before the end (Oct 15 review, OB-01.6)")
        XCTAssertEqual(flow.advance(), .home)
    }

    func testEveryStepHasAWayPast() {
        // Hello, Make it yours and Home can't fail: their button always works.
        // Signing in and the name are asked for, not skipped (Fovea 1.0).
        let alwaysOpen: Set<Step> = [.signIn, .name, .hello, .makeItYours, .memory, .home]
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
        XCTAssertEqual(flow.skip(), .memory, "Not now")
        XCTAssertEqual(flow.advance(), .home)
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
        XCTAssertTrue(flow.requestLanguage("Japanese"))
        XCTAssertEqual(flow.languageRequests, ["Japanese"], "kept as a request")
    }

    /// Oct 18, Ryan: "Choose your languages": English and Chinese on or off, one always on, and a
    /// primary among them (the interface's language) when both are.
    func testChooseYourLanguages() {
        var choice = LanguageChoice(on: [], primary: .english)
        XCTAssertEqual(choice.on, [.english], "the primary is always on")
        XCTAssertFalse(choice.asksPrimary)
        choice.toggle(.chinese)
        XCTAssertEqual(choice.on, [.english, .chinese])
        XCTAssertTrue(choice.asksPrimary, "both on: which is primary")
        choice.setPrimary(.chinese)
        XCTAssertEqual(choice.primary, .chinese)
        choice.toggle(.chinese)
        XCTAssertEqual(choice, LanguageChoice(on: [.english], primary: .english), "the primary off: the other is primary")
        choice.toggle(.english)
        XCTAssertEqual(choice.on, [.english], "the last one stays on")
        choice.setPrimary(.chinese)
        XCTAssertEqual(choice.primary, .english, "only a language that's on can be primary")
        var prefs = FoveaPrefs()
        prefs.languages = [.chinese, .english]
        prefs.language = .chinese
        XCTAssertEqual(LanguageChoice(prefs: prefs), LanguageChoice(on: [.english, .chinese], primary: .chinese))
        XCTAssertEqual(Copy.languageLead, "Choose your languages")
        XCTAssertEqual(Copy.languageName(.chinese), "中文", "each in its own name")
    }

    /// Oct 17, Ryan (FR-06): more than one language under More….
    func testMoreThanOneLanguageCanBeAskedFor() {
        var flow = Flow()
        XCTAssertTrue(flow.requestLanguage("  Japanese "))
        XCTAssertTrue(flow.requestLanguage("Korean"))
        XCTAssertFalse(flow.requestLanguage("japanese"), "not twice, in any case")
        XCTAssertFalse(flow.requestLanguage("   "), "not empty")
        XCTAssertFalse(flow.requestLanguage("English"), "Fovea listens in it already")
        XCTAssertFalse(flow.requestLanguage("简体中文"))
        XCTAssertEqual(flow.languageRequests, ["Japanese", "Korean"])
        flow.dropLanguageRequest("Japanese")
        XCTAssertEqual(flow.languageRequests, ["Korean"], "a chip's ✕ takes it off")
        flow.setLanguageRequests(["French", "french", "", "German"])
        XCTAssertEqual(flow.languageRequests, ["French", "German"], "as kept, tidied the same way")
        XCTAssertEqual(Copy.languageNote, "We'll add it soon. Fovea listens in English or Chinese for now.")
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
        XCTAssertEqual(keys.keys(for: flow.waitingFor!.first!), ["⌥"], "then ⌥ for the numbers")
        flow.record(.numbers)
        XCTAssertEqual(keys.keys(for: flow.waitingFor!.first!), ["⌥"], "then ⌥ once in the GitHub tab")
        flow.record(.prs)
        XCTAssertEqual(keys.keys(for: flow.waitingFor!.first!), ["fn", "⌃"], "fn ⌃ again to finish")
        XCTAssertEqual(keys.keys(for: .send), ["return"])
        XCTAssertEqual(keys.keys(for: .passage), [], "words need no key (Oct 17, Ryan)")
        XCTAssertEqual(keys.keys(for: .feedbackKey), ["fn"])
        XCTAssertTrue(Step.weeklyUpdate.showsKeyboard && Step.dictation.showsKeyboard)
        XCTAssertFalse(Step.permissions.showsKeyboard || Step.makeItYours.showsKeyboard || Step.home.showsKeyboard,
                       "no keyboard where no keys are taught")
    }

    func testInstructionsFollowTheStepTheTabAndWhetherAKeyIsArmed() {
        XCTAssertEqual(Copy.instruction(.prs, step: .weeklyUpdate, tab: .analytics), "Now click the GitHub tab.")
        XCTAssertEqual(Copy.instruction(.prs, step: .weeklyUpdate, tab: .github), "Press ⌥ once, then drag over the merged pull requests.")
        XCTAssertEqual(Copy.instruction(.prs, step: .weeklyUpdate, armed: true, tab: .github), "Drag over the merged pull requests.")
        XCTAssertEqual(Copy.instruction(.numbers, step: .weeklyUpdate, tab: .github), "Now click the Analytics tab.")
        XCTAssertEqual(Copy.instruction(.numbers, step: .weeklyUpdate, tab: .analytics), "Press ⌥ once, then drag over this week's numbers.")
        // The weekly update's parts are ⌥ once each (⌥ twice is Claude's; ⌘ twice, the whole screen,
        // is dictation's, Oct 18).
        for beat in Step.weeklyUpdate.beats.flatMap({ $0 }) {
            XCTAssertFalse(Copy.instruction(beat, step: .weeklyUpdate)?.contains("twice") ?? false, "nothing twice: \(beat)")
        }
        for beat in Beat.allCases {
            XCTAssertFalse(Copy.instruction(beat, step: .dictation)?.contains("⌥ twice") ?? false, "no ⌥ twice: \(beat)")
        }
        XCTAssertEqual(Copy.instruction(.send, step: .packList, agent: "Claude Code"), "Press return to send it to Claude Code.")
        XCTAssertNil(Copy.instruction(.allowedAccessibility, step: .permissions), "the lists say enough by their names")
        XCTAssertNil(Copy.instruction(.heard, step: .microphone), "the line says enough")
        let swapped = KeyMap(screenshot: ["right ⌘"])
        XCTAssertTrue(Copy.instruction(.prs, step: .weeklyUpdate, tab: .github, keys: swapped)!.contains("Press right ⌘ once"), "key names come from the map")
        // Oct 17, Ryan: words and files are taken with no key.
        XCTAssertEqual(Copy.instruction(.passage, step: .packList), "Select the line about the snow: drag across it.")
        XCTAssertEqual(Copy.instruction(.file, step: .packList), "Drag Packing list.txt onto the notch.", "round 2: a file is dragged onto the notch")
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
        XCTAssertEqual(Copy.step(.hello).body, "Talk to your agents from the notch.", "and then the one line")
        XCTAssertEqual(Copy.step(.permissions).title, "Grant Fovea Access")
        XCTAssertEqual(Copy.step(.permissions).body, "")
        XCTAssertEqual(Copy.step(.weeklyUpdate).caption, "Dispatch from anywhere.")
        for step in Step.allCases where !step.isReading {
            XCTAssertEqual(Copy.step(step).body, "", "\(step): a doing step has one caption, no paragraph")
        }
        XCTAssertEqual(Copy.step(.home).body, "", "the end is two short parts")
    }

    // MARK: Back (Oct 15 review, OB-01.7 and FR-05)

    /// Oct 17, Ryan: "a back button for every stage".
    func testBackIsOnEveryStepButTheFirst() {
        for step in Step.allCases {
            XCTAssertEqual(step.hasBack, step != .name, "\(step)")
        }
        XCTAssertFalse(Flow().canGoBack, "nothing before the first page")
        XCTAssertEqual(Flow(start: .weeklyUpdate).backTarget, .agents, "a practice task goes back to the step before it")
        XCTAssertEqual(Flow(start: .home).backTarget, .memory, "the end too")
        XCTAssertEqual(Flow(start: .microphone).backTarget, .permissions, "the microphone's test too")
    }

    func testBackReturnsToThePageAsItWasLeft() {
        var flow = Flow()
        flow.name = "Ryan"
        flow.record(.named)
        XCTAssertEqual(flow.advance(), .signIn)
        XCTAssertEqual(flow.backTarget, .name)
        XCTAssertEqual(flow.back(), .name)
        XCTAssertTrue(flow.isComplete, "the name was given: Continue goes on")
        XCTAssertTrue(flow.revisited)
        XCTAssertEqual(flow.name, "Ryan", "what was entered stays")
        XCTAssertEqual(flow.advance(), .signIn)
        XCTAssertFalse(flow.revisited)

        flow.account = .apple
        flow.record(.signedIn)
        XCTAssertEqual(flow.advance(), .hello)
        XCTAssertEqual(flow.back(), .signIn)
        XCTAssertTrue(flow.isComplete, "signed in already")
        XCTAssertEqual(flow.back(), .name, "and back again")
        XCTAssertNil(flow.back(), "nothing before the name")
    }

    func testBackLandsOnTheMicrophoneHeard() {
        var flow = Flow(start: .permissions)
        flow.allow(.accessibility)
        flow.allow(.screenRecording)
        XCTAssertEqual(flow.advance(), .microphone)
        flow.allow(.microphone)
        flow.record(.heard)
        XCTAssertEqual(flow.advance(), .agents)
        XCTAssertEqual(flow.back(), .microphone, "every stage has Back, the test too")
        XCTAssertTrue(flow.isComplete, "heard already: Continue goes on")
        XCTAssertEqual(flow.back(), .permissions)
        XCTAssertTrue(flow.isComplete)
        XCTAssertEqual(flow.advance(), .agents, "on again, over the test that's done")
    }

    func testBackWithoutAPageSeenBefore() {
        var flow = Flow()
        flow.jump(to: .agents)
        XCTAssertEqual(flow.backTarget, .microphone, "a run picked up part way: the step before in order")
        XCTAssertEqual(flow.back(), .microphone)
        XCTAssertTrue(flow.isComplete, "what's allowed and heard counts")
        var resumed = Flow()
        resumed.jump(to: .dictationIntro)
        XCTAssertEqual(resumed.backTarget, .packList, "asking more starts again from the packing list that makes its session")
    }

    func testAPracticeTaskGoneBackToStartsOver() {
        var flow = Flow()
        flow.jump(to: .weeklyUpdate)
        for beat in [Beat.requestKey, .numbers, .prs, .finish, .review, .send] { flow.record(beat) }
        XCTAssertEqual(flow.advance(), .hover)
        XCTAssertEqual(flow.backTarget, .weeklyUpdate, "watching it goes back to the task that sent it")
        XCTAssertEqual(flow.back(), .weeklyUpdate)
        XCTAssertEqual(flow.done, [], "from its beginning")
        XCTAssertFalse(flow.revisited)
        XCTAssertTrue(Step.weeklyUpdate.restartsOnBack && Step.dictation.restartsOnBack)
        XCTAssertFalse(Step.hello.restartsOnBack || Step.microphone.restartsOnBack)

        var later = Flow()
        later.jump(to: .packList)
        for beat in [Beat.requestKey, .passage, .file, .finish, .review, .send, .answer] { later.record(beat) }
        XCTAssertEqual(later.advance(), .followUp)
        later.record(.followKey)
        later.record(.followAnswer)
        XCTAssertEqual(later.advance(), .dictationIntro)
        XCTAssertEqual(later.back(), .packList, "asking more needs its session: the packing list starts over")
        XCTAssertEqual(later.done, [])
    }

    func testDictationGoneBackToStartsOver() {
        var flow = Flow()
        flow.jump(to: .dictation)
        for beat in [Beat.feedbackKey, .feedbackTaken, .feedbackLanded, .replyKey, .replyLanded] { flow.record(beat) }
        XCTAssertEqual(flow.advance(), .dictionary)
        XCTAssertEqual(flow.back(), .dictation)
        XCTAssertEqual(flow.done, [], "both windows again")
        XCTAssertEqual(flow.back(), .dictationIntro)
    }

    // MARK: Input Monitoring (Oct 15 review, OB-01.5 and FR-09)

    func testInputMonitoringIsAskedForAndNeverWaitedOn() {
        XCTAssertEqual(Permission.page, [.accessibility, .screenRecording, .inputMonitoring])
        XCTAssertFalse(Permission.required.contains(.inputMonitoring))
        XCTAssertEqual(Permission.inputMonitoring.paneName, "Input Monitoring")
        XCTAssertEqual(Permission.inputMonitoring.purpose, "So your shortcuts work in every app.")
        var flow = Flow(start: .permissions)
        flow.allow(.inputMonitoring)
        XCTAssertFalse(flow.isComplete, "it's not one of the two")
        flow.allow(.accessibility)
        flow.allow(.screenRecording)
        XCTAssertTrue(flow.isComplete)
        var without = Flow(start: .permissions)
        without.allow(.accessibility)
        without.allow(.screenRecording)
        XCTAssertEqual(without.advance(), .microphone, "the two are enough")
    }

    // MARK: What Fovea remembers (Oct 15 review, OB-01.6)

    func testWhatFoveaRemembersComesBeforeTheEnd() {
        XCTAssertEqual(Array(Step.allCases.suffix(3)), [.dictionary, .memory, .home])
        XCTAssertTrue(Step.memory.isReading)
        XCTAssertEqual(Step.memory.beats, [])
        XCTAssertEqual(Step.memory.skip, .never)
        XCTAssertEqual(Step.memory.stage, .home)
        XCTAssertEqual(Copy.step(.memory).title, "What Fovea remembers")
        let points = Copy.memoryPoints
        XCTAssertEqual(points.map(\.title), ["What's kept", "Where", "Who reads it", "It's yours"])
        XCTAssertTrue(points[1].detail.contains("this Mac"))
        XCTAssertTrue(points[2].detail.contains("Settings › Connectors"))
        XCTAssertTrue(points[3].detail.contains("Settings › Memory"))
        var flow = Flow(start: .memory)
        XCTAssertTrue(flow.isComplete, "read, and Continue")
        XCTAssertEqual(flow.advance(), .home)
    }

    // MARK: Practice again (Oct 15 review, OB-03.1)

    func testAPracticeAgainWalksOnlyItsSteps() {
        XCTAssertEqual(PracticeAgain.allCases.map(\.rawValue), ["weeklyUpdate", "packingList", "followUp", "dictation"])
        XCTAssertEqual(PracticeAgain.followUp.steps.first, .packList, "asking more needs a session to ask in")

        var weekly = Flow(start: .weeklyUpdate, only: PracticeAgain.weeklyUpdate.steps)
        weekly.jump(to: .weeklyUpdate)
        XCTAssertEqual(weekly.fraction, 0)
        for beat in [Beat.requestKey, .numbers, .prs, .finish, .review, .send] { weekly.record(beat) }
        XCTAssertEqual(weekly.advance(), .hover)
        XCTAssertEqual(weekly.fraction, 0.5, accuracy: 0.001, "its own steps only")
        XCTAssertEqual(weekly.backTarget, .weeklyUpdate, "Back within the practice (Oct 17, Ryan)")
        weekly.record(.hoverNotch)
        weekly.record(.answer)
        XCTAssertNil(weekly.advance(), "past its last step")
        XCTAssertTrue(weekly.finished, "Home again")

        var dictation = Flow(start: .dictationIntro, only: PracticeAgain.dictation.steps)
        dictation.jump(to: .dictationIntro)
        XCTAssertFalse(dictation.canGoBack, "nothing before a practice's first step")
        XCTAssertEqual(dictation.advance(), .dictation)
        XCTAssertNil(dictation.skip(), "Skip dictation ends it, not the words and the end")
        XCTAssertTrue(dictation.finished)

        var packing = Flow(start: .packList, only: PracticeAgain.packingList.steps)
        packing.jump(to: .packList)
        for beat in [Beat.requestKey, .passage, .file, .finish, .review, .send, .answer] { packing.record(beat) }
        XCTAssertNil(packing.advance())
        XCTAssertTrue(packing.finished)
    }

    func testTheTourFillsTheProgressLineByTheEnd() {
        XCTAssertEqual(Flow().fraction, 0)
        XCTAssertEqual(Flow(start: .home).fraction, 1)
        XCTAssertLessThan(Flow(start: .memory).fraction, 1)
    }

    // MARK: The keys as recorded (Oct 15 review, ST-03.1)

    func testTheCopyNamesThePersonsOwnKeys() {
        XCTAssertEqual(KeyMap(prefs: FoveaPrefs()), KeyMap.current, "the defaults, left ⌥ drawn as ⌥")
        var prefs = FoveaPrefs()
        prefs.shortcutChords[FoveaKeys.dispatch.id] = KeyChord(modifiers: ["right ⌥"])
        prefs.shortcutChords[FoveaKeys.voiceflow.id] = KeyChord(modifiers: ["⌃"], keyCode: 49, keyCap: "Space")
        let keys = KeyMap(prefs: prefs)
        XCTAssertEqual(Copy.instruction(.requestKey, step: .weeklyUpdate, keys: keys), "Press right ⌥ to start.")
        XCTAssertEqual(Copy.instruction(.finish, step: .packList, keys: keys), "Say the line, then press right ⌥.")
        XCTAssertTrue(Copy.step(.dictationIntro, keys: keys).body.contains("Press ⌃ Space, talk"))
        XCTAssertEqual(Copy.instruction(.feedbackKey, step: .dictation, keys: keys), "Point at the feedback window and press ⌃ Space.")
        XCTAssertEqual(Copy.feedbackPlaceholder(keys: keys), "Point here, press ⌃ Space, and talk.")
        XCTAssertEqual(keys.keys(for: .requestKey), ["right ⌥"])
        XCTAssertFalse(keys.usesFn)
        XCTAssertFalse(Copy.step(.weeklyUpdate, keys: keys).help!.contains("🌐"), "the 🌐 key's setting only when fn is used")
        XCTAssertTrue(Copy.step(.weeklyUpdate).help!.contains("🌐"))

        prefs.shortcutChords[FoveaKeys.dispatch.id] = KeyChord(modifiers: [])
        XCTAssertEqual(Copy.instruction(.requestKey, step: .weeklyUpdate, keys: KeyMap(prefs: prefs)),
                       "Press your Dispatch shortcut to start.", "a cleared shortcut is named, never blank")
    }

    // MARK: Signing up (Oct 15 review, FR-03, FR-04, AC-01.1, AC-01.2)

    func testSigningUpSaysWhereItIs() {
        XCTAssertEqual(Copy.continueWith(.apple), "Continue with Apple")
        XCTAssertEqual(Copy.continueWith(.google), "Continue with Google")
        XCTAssertEqual(Copy.signInWaiting(.apple), "Waiting for Apple…")
        XCTAssertEqual(Copy.signInFailed, "Couldn't sign in. Check your connection and try again.")
        XCTAssertEqual(Copy.signInTryAgain, "Try Again")
        XCTAssertEqual(Copy.signIn(.choosing).title, "Sign up")
        XCTAssertEqual(Copy.step(.signIn), Copy.signIn(.choosing))
        let check = Copy.signIn(.checkEmail("ryan@example.com"))
        XCTAssertEqual(check.title, "Check your email")
        XCTAssertTrue(check.body.contains("We sent a link to ryan@example.com."))
        XCTAssertEqual(ResendCountdown.label(secondsLeft: 24), "Resend in 0:24")
        XCTAssertEqual(ResendCountdown.label(secondsLeft: 75), "Resend in 1:15")
        XCTAssertEqual(ResendCountdown.label(secondsLeft: 0), "Resend Email")
        XCTAssertEqual(Copy.signInDifferentEmail, "Use a Different Email")
        XCTAssertEqual(Copy.signedIn(.apple, email: nil), "Signed in with Apple.")
        XCTAssertEqual(Copy.signedIn(.email, email: "ryan@example.com"), "Signed in as ryan@example.com.")
        XCTAssertTrue(SignInPhase.choosing.showsChoices)
        XCTAssertTrue(SignInPhase.canceled(.google).showsChoices, "canceled: the choices again")
        XCTAssertFalse(SignInPhase.waiting(.apple).showsChoices)
        XCTAssertFalse(SignInPhase.checkEmail("a@b.co").showsChoices)
        XCTAssertTrue(SignInPhase.signedIn(.apple).isSignedIn)
        for line in [Copy.signInCanceled, Copy.signInFailed, Copy.signInResent, Copy.signInKept, check.body] {
            XCTAssertFalse(line.contains("!"), line)
        }
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
        XCTAssertTrue(DictationApp.wisprFlow.connects, "it keeps its words on this Mac")
        XCTAssertFalse(DictationApp.allCases.map(\.name).contains("VoiceOS"), "Oct 18, Ryan: no VoiceOS")
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

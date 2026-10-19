import SwiftUI
import AppKit
import Carbon.HIToolbox
import OnboardingCore
import FoveaIsland

/// `Fovea --smoke-first-run`: the first run on the real island, its stage invisible, the practice
/// agent answering, nothing about the Mac changed (no Dock, no login item, no apps hidden). It
/// walks the teaching steps the way a person would (the permissions and the microphone, which need
/// the person, aside) and checks what the person would see: every word on the bar, never under the
/// notch; the notch only once it's taught; the board, the sessions, asking more, as on any day.
@MainActor
package enum OnboardingSmoke {
    private static var failures: [String] = []

    package static func run(_ run: OnboardingCoordinator) async -> Bool {
        let model = run.model
        let island = run.island
        await settle(1)
        // Oct 18, Ryan: `FOVEA_SMOKE_LANGUAGE=chinese` walks it all in Chinese (the checks compare
        // the same localized words); `FOVEA_SMOKE_SHOTS=<dir>` keeps a picture of the stage at each
        // beat, to look for words left in English.
        let env = ProcessInfo.processInfo.environment
        let chinese = env["FOVEA_SMOKE_LANGUAGE"] == "chinese"
        let shots = env["FOVEA_SMOKE_SHOTS"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        if let shots { try? FileManager.default.createDirectory(at: shots, withIntermediateDirectories: true) }
        var shotCount = 0
        func shot(_ name: String) async {
            guard let shots else { return }
            await settle(0.5)
            shotCount += 1
            run.renderStage(to: shots.appendingPathComponent(String(format: "%02d-", shotCount) + name + ".png"))
        }
        if chinese {
            model.toggleLanguage(.chinese)
            model.choosePrimaryLanguage(.chinese)
            await settle(1.5)
        }

        // Oct 15 review: the pages before the teaching. Back (OB-01.7), signing up with Apple and
        // its states (AC-01.1, FR-03, FR-04), the email's link (AC-01.2).
        model.jump(to: .name); await settle(0.3)
        check("the first page has no Back", !model.canGoBack)
        model.typedName = "Ryan"
        model.continueTapped()
        _ = await until(2) { model.step == .signIn }
        check("the name goes on to signing up, which has Back", model.step == .signIn && model.canGoBack, "\(model.step)")
        let rig = model.makeRig()
        let back = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: 0,
                                    context: nil, characters: "[", charactersIgnoringModifiers: "[", isARepeat: false,
                                    keyCode: UInt16(kVK_ANSI_LeftBracket))
        let tookBack = back.map { rig.handleKey($0) } ?? false
        await settle(0.2)
        check("⌘[ goes Back to the name, as it was entered", tookBack && model.step == .name && model.typedName == "Ryan" && model.flow.isComplete,
              "\(model.step) \(model.typedName)")
        model.continueTapped()
        _ = await until(2) { model.step == .signIn }
        model.signUp(with: .apple)
        check("Continue with Apple waits for Apple, with Cancel", model.signInPhase == .waiting(.apple) && !model.guideButtonShown)
        await shot("signin-waiting")
        model.cancelSignIn()
        check("…Cancel: the choices again, with a quiet line", model.signInPhase == .canceled(.apple) && model.guideButtonShown)
        await shot("signin-canceled")
        model.signUp(with: .apple)
        _ = await until(5) { model.step == .hello }
        check("Apple answers: signed in, and on to hello by itself", model.step == .hello && run.prefs.accountProvider == .apple,
              "\(model.step) \(run.prefs.accountProvider)")
        model.goBack(); await settle(0.2)
        check("Back to signing up shows it signed in, Continue on it", model.step == .signIn && model.signInPhase == .signedIn(.apple)
              && model.guideButtonShown, "\(model.step) \(model.signInPhase)")
        model.continueTapped()
        _ = await until(2) { model.step == .hello }
        check("…and Continue goes on", model.step == .hello, "\(model.step)")
        model.jump(to: .signIn); await settle(0.2)
        model.stageSignIn(.failed(.google))
        check("couldn't sign in: Try Again, no Continue", model.signInPhase == .failed(.google) && !model.guideButtonShown)
        await shot("signin-failed")
        model.jump(to: .signIn); await settle(0.2)
        model.typedEmail = "ryan@example.com"
        model.continueTapped()
        check("an email: a link sent, Resend held back", model.signInPhase == .checkEmail("ryan@example.com") && model.resendLeft > 0
              && model.copy.title == L("Check your email"), "\(model.signInPhase) \(model.resendLeft)")
        await shot("signin-check-email")
        _ = await until(10) { model.step == .hello }
        check("…the link opened: signed in as the email, and on", model.step == .hello && run.prefs.accountProvider == .email
              && run.prefs.accountEmail == "ryan@example.com", "\(model.step) \(run.prefs.accountEmail)")

        // Oct 17, Ryan (round 2): Grant Fovea Access never moves on by itself, even with
        // everything allowed already: each row shows Allowed, and the person presses Continue.
        model.jump(to: .makeItYours); await settle(0.3)
        model.flow.allow(.accessibility)
        model.flow.allow(.screenRecording)
        model.continueTapped()
        _ = await until(2) { model.step != .makeItYours }
        check("with both lists allowed already, the permissions page still shows", model.step == .permissions, "\(model.step)")
        check("the permissions page has Back", model.canGoBack)
        model.grant(.accessibility)
        model.grant(.screenRecording)
        await settle(2.0)
        check("…and stays, both allowed, Continue on it (Input Monitoring never waited on)",
              model.step == .permissions && model.flow.isComplete && model.guideButtonShown, "\(model.step)")
        await shot("permissions")
        model.continueTapped()
        _ = await until(2) { model.step != .permissions }
        check("…Continue goes on, to the microphone", model.step == .microphone, "\(model.step)")
        // The microphone's test, heard, waits for Continue too (stood in for: the line heard).
        model.flow.allow(.microphone)
        model.heard()
        await settle(2.0)
        check("the line heard: the microphone stays, Continue on it", model.step == .microphone && model.micPhase == .heard
              && model.guideButtonShown, "\(model.step) \(model.micPhase)")
        await shot("microphone-heard")
        model.continueTapped()
        _ = await until(2) { model.step != .microphone }
        check("…Continue goes on", model.step == .agents, "\(model.step)")

        // Oct 18, Ryan: "Choose your languages", and a primary when both are on: the interface's.
        model.jump(to: .hello); await settle(0.3)
        await shot("hello")
        if !chinese {
        model.toggleLanguage(.chinese)
        check("both languages on: a primary is asked for", model.languageChoice.on == [.english, .chinese] && model.languageChoice.asksPrimary
              && run.prefs.languages == [.english, .chinese], "\(model.languageChoice)")
        model.choosePrimaryLanguage(.chinese)
        check("…Chinese primary: the interface switches to it at once", FoveaLocale.shared.language == .chinese
              && run.prefs.language == .chinese && model.flow.language == .chinese)
        model.toggleLanguage(.english)
        model.toggleLanguage(.chinese)
        check("…the last one stays on", model.languageChoice.on == [.chinese], "\(model.languageChoice.on)")
        model.toggleLanguage(.english)
        model.choosePrimaryLanguage(.english)
        model.toggleLanguage(.chinese)
        check("…back to English alone", model.languageChoice == LanguageChoice(on: [.english], primary: .english)
              && FoveaLocale.shared.language == .english && run.prefs.language == .english, "\(model.languageChoice)")
        await settle(1.0)
        }

        // Oct 17, Ryan (FR-06): more than one language under More…, each removable.
        model.jump(to: .hello); await settle(0.3)
        model.openLanguageMore()
        let japanese = model.addLanguageRequest("Japanese")
        let korean = model.addLanguageRequest("Korean")
        let twice = model.addLanguageRequest("japanese")
        model.removeLanguageRequest("Japanese")
        check("More… takes several languages, not twice, each removable", japanese && korean && !twice
              && run.prefs.requestedLanguages == ["Korean"], "\(run.prefs.requestedLanguages)")
        model.removeLanguageRequest("Korean")

        // Oct 17, Ryan: Back on every step. The microphone's test, come back to, shows it heard.
        model.jump(to: .agents); await settle(0.3)
        model.goBack(); await settle(0.3)
        check("Back from the agents is the microphone, heard, Continue on it",
              model.step == .microphone && model.micPhase == .heard && model.guideButtonShown, "\(model.step) \(model.micPhase)")
        model.continueTapped()
        _ = await until(2) { model.step == .agents }
        check("…and Continue goes on", model.step == .agents, "\(model.step)")

        // Oct 15 review, OB-01.6: what Fovea remembers, before the end.
        model.jump(to: .memory); await settle(0.3)
        check("what Fovea remembers has Back, to your words", model.flow.backTarget == .dictionary)
        model.continueTapped()
        _ = await until(2) { model.step == .home }
        check("…Continue marks it read, and the end", model.step == .home && run.prefs.memoryDisclosureSeen, "\(model.step)")

        // Before the teaching: nothing at the notch.
        model.jump(to: .makeItYours); await settle(0.4)
        check("Make it yours opens with nothing at the notch", island.probeState == "silent", island.probeState)
        check("…and the board doesn't open from the notch yet", !model.allowsBoard())
        model.setAura(.ocean); await settle(0.4)
        check("touching a light pulls the notch down, glowing", island.probeState == "v2Voice", island.probeState)
        model.setAuraHue(0.3); await settle(2.0)
        check("…and it keeps glowing while the light is picked", island.probeState == "v2Voice", island.probeState)
        // Oct 18, Ryan: the eight palettes are fixed; only Customize has a hue and a drift.
        model.setAuraHue(120)
        check("a palette keeps its own colors whatever the hue says", model.personal.drawnHue == 0 && run.prefs.drawnGlowHue == 0)
        model.setAura(.custom)
        check("…Customize, the ninth, is drawn at the hue set", Personalization.tiles.count == 9 && model.personal.drawnHue == 120
              && run.prefs.drawnGlowHue == 120, "\(model.personal.drawnHue)")
        await shot("make-it-yours-customize")
        model.jump(to: .agents); await settle(0.4)
        check("leaving Make it yours puts the notch back", island.probeState == "silent", island.probeState)

        // The weekly update: Do it for me stages the request on Choose chat; Return sends it.
        model.jump(to: .weeklyUpdate); await settle(1.5)
        check("in the teaching, the board may open from the notch", model.allowsBoard())
        check("no line is ever put under the notch", !island.probeCaptionUnderNotch)
        island.probe(.fn); await settle(0.3)
        check("fn where it isn't taught says so on the bar", model.hintText != nil, model.hintText ?? "nil")
        // Oct 17, Ryan (round 2): ⌥ once each; no whole screen, no ×2. Oct 18: two parts.
        model.islandDidEmit(.voiceOpened(dispatch: true))
        check("the first part is this week's numbers: ⌥ once, no ×2", model.waitingBeat == .numbers
              && model.keyboardTargets == ["⌥"] && model.keyboardBadges.isEmpty
              && Copy.instruction(.numbers, step: .weeklyUpdate, tab: .analytics, keys: model.keys) == L("Press \(model.keys.spoken(.screenshot)) once, then drag over \(L("this week's numbers"))."),
              "\(String(describing: model.waitingBeat)) \(model.keyboardTargets)")
        await shot("weekly-update-numbers")
        check("two parts to take, the numbers and the pull requests (Oct 18, Ryan)",
              model.step.beats.filter { group in group.contains { model.keys.keys(for: $0) == ["⌥"] } }.count == 2
              && model.openTabs == [.analytics, .github], "\(model.openTabs)")
        model.doItForMe(); await settle(1.5)
        check("Do it for me puts the request together at the notch, on Choose chat", island.probeState == "v2Send", island.probeState)
        check("…with the two parts", model.request?.referents.count == 2, "\(model.request?.referents.count ?? 0)")
        island.probe(.enter); await settle(0.6)
        check("Return sends it: the session on the board, working", island.probeSessions.count == 1, "\(island.probeSessions.count)")
        var weekly = island.probeSessions.first?.id
        _ = await until(5) { model.step == .hover }
        check("…and the run moves on to watching it", model.step == .hover, "\(model.step)")
        await shot("hover")

        // Oct 17, Ryan: Back from watching it starts the weekly update over, cleanly.
        model.goBack(); await settle(0.6)
        check("Back from watching it: the weekly update from its beginning, the board and the update gone",
              model.step == .weeklyUpdate && model.flow.done.isEmpty && island.probeSessions.isEmpty
              && !model.practice.exists(PracticeFiles.update) && model.sessions.isEmpty,
              "\(model.step) \(model.flow.done.map(\.rawValue)) \(island.probeSessions.count)")
        check("…and it has Back too, to the step before", model.canGoBack && model.flow.backTarget == .agents,
              "\(String(describing: model.flow.backTarget))")
        model.doItForMe(); await settle(1.5)
        island.probe(.enter); await settle(0.6)
        weekly = island.probeSessions.first?.id
        _ = await until(5) { model.step == .hover }
        check("…sent again, watched again", model.step == .hover && island.probeSessions.count == 1,
              "\(model.step) \(island.probeSessions.count)")

        // Hover: the board from the notch, as any day; the answer there when it's back.
        island.probePointer(onNotch: false); await settle(0.2)
        let opened = await until(4) { island.probePointer(onNotch: true); return island.probeState == "v2Board" }
        check("the pointer at the notch opens the board", opened, island.probeState)
        let done = await until(15) { island.probeSessions.first { $0.id == weekly }?.state == "complete" }
        check("the practice agent's update comes back", done)
        if let s = island.probeSessions.first(where: { $0.id == weekly }) {
            // In Chinese the island can't yet tell the agent's lines apart (it reads English verbs), so
            // its fold has one step (Oct 18: said to the lead).
            check("…with what it did (its steps) folded under the answer", chinese ? s.steps >= 1 : s.steps >= 3, "\(s.steps)")
            check("…and the file it wrote to open", s.files.contains(PracticeFiles.update), "\(s.files)")
        }
        let complete = await until(4) { model.flow.isComplete }
        check("seen and back, the step is done, waiting for Continue on the bar", complete && model.guideButtonShown,
              "done \(model.flow.done.map(\.rawValue)) waiting \(String(describing: model.flow.waitingFor)) answered \(model.answered.map(\.rawValue))")
        await shot("hover-answer")
        model.continueTapped()
        _ = await until(4) { model.step == .packList }
        check("Continue goes on to the packing list", model.step == .packList, "\(model.step)")
        island.probePointer(onNotch: false)
        _ = await until(4) { island.probeState == "silent" }

        // The packing list, then asking more by voice in its session.
        await settle(1)
        // Oct 17, Ryan (round 2): words selected, the file dragged onto the notch; the island says
        // each was taken (stood in for here, as the island would say it).
        model.islandDidEmit(.voiceOpened(dispatch: true))
        model.islandDidEmit(.referentTaken(kind: .passage, rect: model.paragraphFrames[OT.Practice.snowParagraph] ?? .zero))
        check("the packing list asks for the file dragged onto the notch", model.instruction == L("Drag Packing list.txt onto the notch.")
              && model.keyboardTargets.isEmpty, model.instruction ?? "nil")
        await shot("pack-list-file")
        model.islandDidEmit(.referentTaken(kind: .file, rect: model.fileFrames[PracticeFiles.list] ?? .zero))
        check("…dropped there, it's taken", model.flow.done.contains(.file) && model.flow.done.contains(.passage),
              "\(model.flow.done.map(\.rawValue))")
        model.doItForMe(); await settle(1.5)
        island.probe(.enter); await settle(0.6)
        let packing = island.probeSessions.first { $0.id != weekly }?.id
        check("the packing list goes", packing != nil)
        _ = await until(12) { model.flow.isComplete }
        check("its answer back, the step is done", model.flow.isComplete)
        await shot("pack-list-answer")
        // The practice agent is quick (a few seconds): as on any day, a quick answer opens by
        // itself (Claude Code, slower, waits on the board).
        check("…a quick answer opens by itself, as any day", island.probeState == "v2Chat", island.probeState)
        model.continueTapped()
        _ = await until(4) { model.step == .followUp }
        check("Continue asks for more", model.step == .followUp, "\(model.step)")
        await shot("follow-up")
        if let packing {
            if island.probeState != "v2Chat" { island.probeOpen(packing); await settle(0.4) }
            check("the packing session opens at the notch", island.probeState == "v2Chat" && island.probeFocus == packing,
                  "\(island.probeState) \(island.probeFocus ?? "nil")")
            island.probeWords(["now sort it into clothes and gear"])
            island.probe(.fn); await settle(0.4)
            check("fn on it listens there, the session still on screen", island.probeAsksOver, island.probeState)
            try? await Task.sleep(for: .seconds(0.8))
            island.probe(.fn)
            let stayed = await until(6) { island.probeState == "v2Chat" }
            check("…sent, the session stays open, the question in it", stayed, island.probeState)
            let sorted = await until(12) { model.flow.isComplete }
            check("the practice agent sorts the list: the step is done", sorted, "\(model.step)")
            await shot("follow-up-answer")
            if let s = island.probeSessions.first(where: { $0.id == packing }) {
                check("…the earlier answer kept in the session", s.history == 1, "\(s.history)")
            }
        }

        // Oct 17, Ryan: dictation takes things while you talk. The intro lists the keys; in the
        // feedback, something taken (⌥ and a drag, stood in for as the island would say it) lands
        // after the words; words first is missed, said, and tried again.
        model.jump(to: .dictationIntro); await settle(0.4)
        check("dictation's intro lists ⌥, ⌘ twice, and words or a file dragged onto the notch with no key",
              Copy.whileDictating(keys: model.keys).map(\.caps) == [["⌥"], ["⌘"], []] && model.step.keys.contains(.screenshot))
        model.jump(to: .dictation); await settle(0.6)
        model.pointerOver = .feedback
        model.islandDidEmit(.voiceOpened(dispatch: false))
        check("fn at the feedback, then the keyboard asks for ⌥, or ⌘ ×2", model.waitingBeat == .feedbackTaken
              && model.keyboardTargets == ["⌥", "⌘"] && model.keyboardBadges == ["⌘": "×2"],
              "\(String(describing: model.waitingBeat)) \(model.keyboardTargets)")
        await shot("dictation-take")
        _ = model.paste("Too quick.")
        check("…words before anything's taken: said, and tried again", model.flow.done.isEmpty
              && model.hintText == Copy.dictationMissed(keys: model.keys), model.hintText ?? "nil")
        await shot("dictation-missed")
        model.pointerOver = .feedback
        model.islandDidEmit(.voiceOpened(dispatch: false))
        model.islandDidEmit(.referentTaken(kind: .region, rect: OT.Layout.messagesFrame.insetBy(dx: 40, dy: 80)))
        check("⌥ and a drag while talking: taken, a picture of it", model.flow.done == [.feedbackKey, .feedbackTaken]
              && model.dictationTaken.count == 1 && model.dictationTaken.first?.image != nil, "\(model.flow.done.map(\.rawValue))")
        _ = model.paste("This part was clear.")
        check("…it lands after the words", model.feedbackTaken.count == 1 && model.feedbackText.hasSuffix("This part was clear.")
              && model.dictationTaken.isEmpty, model.feedbackText)
        await shot("dictation-feedback")
        // Oct 18, Ryan: a picture can be taken off again before Send.
        if let taken = model.feedbackTaken.first { model.removeTaken(taken.id, from: .feedback) }
        check("…and taken off again", model.feedbackTaken.isEmpty)
        // Oct 18, Ryan: the words land under the pointer as they land, not where listening began.
        model.pointerOver = .messages
        model.islandDidEmit(.voiceOpened(dispatch: false))
        model.pointerOver = .feedback
        _ = model.paste("Moved.")
        check("words land in the window under the pointer when they land", model.feedbackText.hasSuffix("Moved.")
              && model.replyText.isEmpty, model.feedbackText)
        model.pointerOver = .messages
        model.islandDidEmit(.voiceOpened(dispatch: false))
        _ = model.paste("Friday at three works for me.")
        check("…then the reply to Lin: dictation done", model.flow.isComplete, "\(model.flow.done.map(\.rawValue))")
        check("…the reply in Messages' box, the person's to change until it's sent", model.replyText == "Friday at three works for me."
              && model.sentReply == nil, model.replyText)
        await shot("dictation-reply")
        model.sendReply()
        check("…Return sends it", model.sentReply == "Friday at three works for me." && model.replyText.isEmpty)
        await shot("dictation-sent")

        // Reading pages after the teaching: the notch rests, says nothing.
        model.jump(to: .dictationIntro); await settle(0.6)
        check("a page to read after the teaching rests the notch", island.probeState == "silent", island.probeState)
        check("…and the board doesn't open from it", !model.allowsBoard())
        model.jump(to: .home); await settle(0.6)
        check("You're all set: nothing at the notch", island.probeState == "silent", island.probeState)
        check("…and Back, to what Fovea remembers (Oct 17)", model.flow.backTarget == .memory)

        // Exit tour, at any step: the place kept, the stage away, the notch at rest.
        model.jump(to: .followUp); await settle(0.6)
        var left = false
        run.onExit = { left = true }
        model.exitTour(); await settle(0.4)
        let kept = run.savedResumeStep
        check("Exit tour puts the run away and opens Home", left)
        check("…keeping its place (asking more goes back to the task that makes the session)", kept == .packList, "\(String(describing: kept))")
        check("…and marks the tour as put away, not done", run.tourPaused && !run.tourComplete)
        check("…the notch at rest", island.probeState == "silent", island.probeState)

        // Oct 15 review, OB-03.1: one practice again from Home, the tour left as it was put away.
        var home = false
        let again = run.makeRun(.practice(.weeklyUpdate)) { home = true }
        again.start()
        let practice = again.model
        _ = await until(6) { practice.pageReady }
        await settle(1)
        check("a practice again starts at its task, Back nowhere", practice.step == .weeklyUpdate && !practice.canGoBack,
              "\(practice.step)")
        practice.doItForMe(); await settle(1.5)
        island.probe(.enter); await settle(0.6)
        _ = await until(5) { practice.step == .hover }
        island.probePointer(onNotch: false); await settle(0.2)
        _ = await until(4) { island.probePointer(onNotch: true); return island.probeState == "v2Board" }
        let practised = await until(15) { practice.flow.isComplete }
        check("…its update comes back", practised, "\(practice.step) \(practice.flow.done.map(\.rawValue))")
        practice.continueTapped()
        _ = await until(3) { home }
        check("…Continue past its last step: Home again", home)
        check("…the tour still put away where it was", run.tourPaused && !run.tourComplete && run.savedResumeStep == .packList,
              "\(String(describing: run.savedResumeStep))")
        island.probePointer(onNotch: false)

        // Oct 18, Ryan: a first run from the beginning keeps nothing of the last one.
        run.prefs.requestedLanguages = ["Korean"]
        run.prefs.glowPalette = .ocean
        let hadName = !run.prefs.accountName.isEmpty
        let fresh = run.makeRun(.replay) {}
        check("a run from the beginning starts blank: no name, email, languages or choices of the last one",
              hadName && run.prefs.accountName.isEmpty && run.prefs.accountEmail.isEmpty && run.prefs.requestedLanguages.isEmpty
              && run.prefs.glowPalette == FoveaPrefs().glowPalette && fresh.model.typedName.isEmpty && fresh.model.typedEmail.isEmpty
              && fresh.model.flow.languageRequests.isEmpty && fresh.model.flow.personal == Personalization() && fresh.model.step == .name,
              "\(run.prefs.accountName) \(run.prefs.requestedLanguages)")

        print(failures.isEmpty ? "SMOKE PASS" : "SMOKE FAIL: \(failures.count) check(s)")
        for name in failures { print("  failed: \(name)") }
        return failures.isEmpty
    }

    private static func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
        if !ok { failures.append(name) }
        let more = detail()
        print("\(ok ? "ok  " : "FAIL") \(name)\(more.isEmpty ? "" : "  (\(more))")")
    }

    private static func settle(_ seconds: Double = 0.3) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    private static func until(_ timeout: Double, _ condition: () -> Bool) async -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }
}

import SwiftUI
import AppKit
import Carbon.HIToolbox
import OnboardingCore
import FoveaIsland
import FoveaPlatform

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
            // The real windows too (Fovea's own, as the window server composites them): the notch
            // as it's drawn, which the stage's picture doesn't have.
            if let screen = Screens.island, let png = RealScreenShot.ownWindowsPNG(of: screen) {
                try? png.write(to: shots.appendingPathComponent(String(format: "%02d-", shotCount) + name + ".screen.png"))
            }
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
        await shot("make-it-yours-ocean")
        // Oct 23, Ryan: a look pulls the board down; after it the light picked came back never, and
        // every light touched after that showed nothing.
        model.setNotchPanels(.floating); await settle(0.4)
        check("a look chosen pulls the board down, in that look", island.probeState == "v2Board" && run.prefs.panels == .floating,
              island.probeState)
        await shot("make-it-yours-floating")
        _ = await until(OT.Motion.lookShown + 1) { island.probeState == "v2Voice" }
        check("…then the light picked comes back", island.probeState == "v2Voice", island.probeState)
        model.setAura(.sunset); await settle(0.4)
        check("…and the next light shows at once, in its colors", island.probeState == "v2Voice" && run.prefs.glowPalette == .sunset,
              island.probeState)
        await shot("make-it-yours-sunset")
        model.setNotchAppearance(.light); await settle(0.4)
        check("the glass chosen pulls the board down", island.probeState == "v2Board", island.probeState)
        await shot("make-it-yours-light")
        model.setNotchDensity(.compact); await settle(0.4)
        await shot("make-it-yours-compact")
        model.setAccent(.orange); await settle(0.4)
        check("the accent too: the board, its buttons in it (Oct 23, Ryan)", island.probeState == "v2Board" && run.prefs.accent == .orange,
              island.probeState)
        model.setNotchAppearance(.dark); model.setNotchPanels(.attached); model.setNotchDensity(.spacious); model.setAccent(.multicolor)
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
        // Come back to, a light shows again.
        model.jump(to: .permissions); await settle(0.3)
        model.goBack(); await settle(0.4)
        model.setAura(.ice); await settle(0.4)
        check("Make it yours come back to with Back: a light shows again", model.step == .makeItYours && island.probeState == "v2Voice",
              "\(model.step) \(island.probeState)")
        model.jump(to: .agents); await settle(0.4)

        // The weekly update: Do it for me stages the request on Choose chat; Return sends it.
        model.jump(to: .weeklyUpdate); await settle(1.5)
        check("in the teaching, the board may open from the notch", model.allowsBoard())
        check("no line is ever put under the notch", !island.probeCaptionUnderNotch)
        island.probe(.fn); await settle(0.3)
        check("fn where it isn't taught says so on the bar", model.hintText != nil, model.hintText ?? "nil")
        // Oct 19, Ryan: ⌘ once each, no ×2. Oct 18: two parts.
        model.islandDidEmit(.voiceOpened(dispatch: true))
        check("the first part is this week's numbers: ⌘ once, no ×2", model.waitingBeat == .numbers
              && model.keyboardTargets == ["⌘"] && model.keyboardBadges.isEmpty
              && Copy.instruction(.numbers, step: .weeklyUpdate, tab: .analytics, keys: model.keys) == L("Press \(model.keys.spoken(.screenshot)) once, then drag over \(L("this week's numbers"))."),
              "\(String(describing: model.waitingBeat)) \(model.keyboardTargets)")
        await shot("weekly-update-numbers")
        check("two parts to take, the numbers and the pull requests (Oct 18, Ryan)",
              model.step.beats.filter { group in group.contains { model.keys.keys(for: $0) == ["⌘"] } }.count == 2
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

        // Hover: the board from the notch, as any day; the answer there when it's back. Oct 23,
        // Ryan: the update opened, pulled out of the notch, tucked at the side, brought back.
        island.probePointer(onNotch: false); await settle(0.2)
        let opened = await until(4) { island.probePointer(onNotch: true); return island.probeState == "v2Board" }
        check("the pointer at the notch opens the board", opened, island.probeState)
        check("…and the bar asks to open the update", model.instruction == L("Click the update to open it."), model.instruction ?? "nil")
        if let weekly { island.probeOpen(weekly) }
        await settle(0.4)
        check("opened: the bar asks to drag it out of the notch", model.waitingBeat == .pulledOut
              && model.instruction == L("Drag it down, out of the notch.") && model.skipLabel == Copy.doItForMe,
              "\(String(describing: model.waitingBeat)) \(model.instruction ?? "nil")")
        if let weekly { island.pullOut(weekly) }
        await settle(0.5)
        check("…pulled out, a window; the bar asks to drop it at the side", weekly.flatMap(island.detachedState) == "out"
              && model.waitingBeat == .tucked, "\(weekly.flatMap(island.detachedState) ?? "nil") \(String(describing: model.waitingBeat))")
        await shot("hover-pulled-out")
        if let weekly { island.tuck(weekly) }
        await settle(0.6)
        check("…dropped at the side, a tab; the bar asks to bring it back", weekly.flatMap(island.detachedState) == "tucked"
              && model.waitingBeat == .broughtBack, "\(weekly.flatMap(island.detachedState) ?? "nil") \(String(describing: model.waitingBeat))")
        let done = await until(15) { island.probeSessions.first { $0.id == weekly }?.state == "complete" }
        check("the practice agent's update comes back", done)
        if let s = island.probeSessions.first(where: { $0.id == weekly }) {
            // In Chinese the island can't yet tell the agent's lines apart (it reads English verbs), so
            // its fold has one step (Oct 18: said to the lead).
            check("…with what it did (its steps) folded under the answer", chinese ? s.steps >= 1 : s.steps >= 3, "\(s.steps)")
            check("…and the file it wrote to open", s.files.contains(PracticeFiles.update), "\(s.files)")
        }
        check("…the tab has its check: the bar says click it", model.instruction == L("Click the tab to bring the update back."),
              model.instruction ?? "nil")
        check("…and the update's preview waits, off the tab", model.previewFile == nil, model.previewFile ?? "nil")
        await shot("hover-tucked")
        if let weekly { island.bringBack(weekly) }
        await settle(0.4)
        check("the tab clicked: the update is back out", weekly.flatMap(island.detachedState) == "out")
        let complete = await until(4) { model.flow.isComplete }
        check("seen and back, the step is done, waiting for Continue on the bar", complete && model.guideButtonShown,
              "done \(model.flow.done.map(\.rawValue)) waiting \(String(describing: model.flow.waitingFor)) answered \(model.answered.map(\.rawValue))")
        check("…and the update opens now, as Quick Look would", model.previewFile == PracticeFiles.update, model.previewFile ?? "nil")
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
        // Oct 23, Ryan: two chats, a new one picked, and the weekly update's.
        check("Choose chat offers a new chat, picked, and the weekly update's", island.probeSuggestions.count == 2
              && island.probeSuggestions.first == L("New chat") && model.instruction == L("Fovea picked the chat. \(model.keys.spoken(.expand)) shows all your chats; return sends it here."),
              "\(island.probeSuggestions) \(model.instruction ?? "nil")")
        island.probe(.enter); await settle(0.6)
        let packing = island.probeSessions.first { $0.id != weekly }?.id
        check("the packing list goes, to a new chat", packing != nil)
        // Oct 23, Ryan: the agent asks before it edits the list.
        let asked = await until(6) { island.probeSessions.first { $0.id == packing }?.state == "needsYou" }
        check("its agent asks to edit the list: the session needs you, and the menu bar says so", asked && island.activity == .needsYou
              && model.waitingBeat == .approved, "\(island.probeSessions.first { $0.id == packing }?.state ?? "nil") \(island.activity)")
        check("…the bar says to allow it at the notch, and names the menu bar's icon",
              model.instruction?.contains(chinese ? "菜单栏" : "menu bar") == true, model.instruction ?? "nil")
        await shot("pack-list-approval")
        if let packing { island.probeDeny(packing) }
        await settle(0.3)
        check("Deny: in practice it asks again, and the bar says why", model.hintText == L("In practice, Allow it so the list gets made.")
              && island.probeSessions.first { $0.id == packing }?.state == "needsYou", model.hintText ?? "nil")
        if let packing { island.probeAllow(packing) }
        _ = await until(12) { model.flow.isComplete }
        check("Allow: it goes on, and with its answer back the step is done", model.flow.isComplete,
              "\(model.flow.done.map(\.rawValue))")
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
            let sorted = await until(12) { model.waitingBeat == .expanded }
            check("the practice agent sorts the list", sorted, "\(model.step) \(String(describing: model.waitingBeat))")
            await shot("follow-up-answer")
            if let s = island.probeSessions.first(where: { $0.id == packing }) {
                check("…the earlier answer kept in the session", s.history == 1, "\(s.history)")
            }
            // Oct 23, Ryan: then the whole session, with ⌃.
            check("…then the bar asks for the whole session, ⌃ lit", model.instruction == L("Press \(model.keys.spoken(.expand)) to see the whole session.")
                  && model.keyboardTargets == ["⌃"], "\(model.instruction ?? "nil") \(model.keyboardTargets)")
            if island.probeState != "v2Chat" { island.probeOpen(packing); await settle(0.4) }
            island.probe(.control); await settle(0.5)
            check("⌃: the whole session; the step is done, Esc to step back", island.probeExpanded && model.flow.isComplete
                  && model.instruction == L("\(model.keys.spoken(.cancel).capitalized) steps back."), "\(island.probeExpanded) \(model.instruction ?? "nil")")
            await shot("follow-up-whole-session")
        }

        // Oct 23, Ryan: the packing list sent to the weekly update's chat goes into that session.
        if let weekly {
            model.jump(to: .packList); await settle(1.0)
            model.doItForMe(); await settle(1.5)
            island.probePickNext(); await settle(0.2)
            let before = island.probeSessions.count
            island.probe(.enter); await settle(0.6)
            check("the weekly update's chat picked: the request goes into its session, no new one",
                  island.probeSessions.count == before && model.packSession?.islandID == weekly,
                  "\(island.probeSessions.count) vs \(before) \(model.packSession?.islandID ?? "nil")")
            _ = await until(6) { island.probeSessions.first { $0.id == weekly }?.state == "needsYou" }
            island.probeAllow(weekly)
            let went = await until(12) { model.flow.isComplete }
            check("…allowed, answered there", went, "\(model.flow.done.map(\.rawValue))")
            island.probePointer(onNotch: false)
        }

        // Oct 17, Ryan: dictation takes things while you talk. The intro lists the keys; in the
        // feedback, something taken (⌘ and a drag, stood in for as the island would say it) lands
        // after the words; words first is missed, said, and tried again.
        model.jump(to: .dictationIntro); await settle(0.4)
        check("dictation's intro lists ⌘, ⌘ twice, and words or a file dragged onto the notch with no key",
              Copy.whileDictating(keys: model.keys).map(\.caps) == [["⌘"], ["⌘"], []] && model.step.keys.contains(.screenshot))
        model.jump(to: .dictation); await settle(0.6)
        model.pointerOver = .feedback
        model.islandDidEmit(.voiceOpened(dispatch: false))
        check("fn at the feedback, then the keyboard asks for ⌘ (once a part, twice all of it)", model.waitingBeat == .feedbackTaken
              && model.keyboardTargets == ["⌘"] && model.keyboardBadges.isEmpty,
              "\(String(describing: model.waitingBeat)) \(model.keyboardTargets)")
        await shot("dictation-take")
        _ = model.paste("Too quick.")
        check("…words before anything's taken: said, and tried again", model.flow.done.isEmpty
              && model.hintText == Copy.dictationMissed(keys: model.keys), model.hintText ?? "nil")
        await shot("dictation-missed")
        model.pointerOver = .feedback
        model.islandDidEmit(.voiceOpened(dispatch: false))
        model.islandDidEmit(.referentTaken(kind: .region, rect: OT.Layout.messagesFrame.insetBy(dx: 40, dy: 80)))
        check("⌘ and a drag while talking: taken, a picture of it", model.flow.done == [.feedbackKey, .feedbackTaken]
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
        // Oct 23, Ryan: in Messages, esc throws the words away and ⌘Z brings them back first.
        model.pointerOver = .messages
        model.islandDidEmit(.voiceOpened(dispatch: false))
        _ = model.paste("Too soon.")
        check("words landed in Messages before esc: said, Messages' try again", model.waitingBeat == .replyKey
              && model.hintText == L("Landed. This time, press \(model.keys.spoken(.cancel)) before you finish, then \(model.keys.spoken(.undo))."),
              "\(String(describing: model.waitingBeat)) \(model.hintText ?? "nil")")
        model.replyText = ""
        model.pointerOver = .messages
        // The notch at rest first, as when the person turns to Messages (the board was left open).
        island.probePointer(onNotch: false)
        island.rest(); await settle(0.4)
        island.probe(.fn); await settle(0.3)
        check("fn at Messages: the keyboard asks for esc", model.waitingBeat == .replyCancelled && model.keyboardTargets == ["esc"],
              "\(String(describing: model.waitingBeat)) \(model.keyboardTargets)")
        island.probe(.escape); await settle(0.3)
        check("…esc throws it away; now ⌘Z, lit", island.probeState == "cancelled" && model.waitingBeat == .replyRestored
              && model.keyboardTargets == ["⌘", "Z"]
              && Copy.instruction(.replyRestored, step: .dictation, keys: model.keys) == L("Changed your mind? Press \(model.keys.spoken(.undo)) to bring it back."),
              "\(island.probeState) \(String(describing: model.waitingBeat)) \(model.keyboardTargets)")
        await shot("dictation-undo")
        island.probe(.undo); await settle(0.3)
        check("…⌘Z brings it back, listening", island.probeState == "voiceFlow" && model.waitingBeat == .replyLanded,
              "\(island.probeState) \(String(describing: model.waitingBeat))")
        island.rest(); await settle(0.2)
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
        check("…and the menu bar's icon named with its line (Oct 23)", Closing.menuBarIcon != nil && !Copy.homeMenuBar.isEmpty)
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
        // Oct 23, Ryan: opened, pulled out, tucked and brought back, by "Do it for me" this time.
        let practised = await until(20) {
            if practice.flow.isComplete { return true }
            if practice.waitingBeat != .answer { practice.hoverForYou() }
            return false
        }
        check("…its update comes back, pulled out, tucked and brought back for you", practised,
              "\(practice.step) \(practice.flow.done.map(\.rawValue))")
        practice.continueTapped()
        _ = await until(3) { home }
        check("…Continue past its last step: Home again", home)
        check("…the tour still put away where it was", run.tourPaused && !run.tourComplete && run.savedResumeStep == .packList,
              "\(String(describing: run.savedResumeStep))")
        island.probePointer(onNotch: false)

        // Oct 23, Ryan: More to try, from Getting Started, each on its own and Home again after.
        await moreToTry(run, island)

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

    /// Set when a practice run is over.
    private final class Over { var on = false }

    /// A practice from Getting Started, started on the same Mac and stores, its pages loaded.
    private static func practice(_ kind: PracticeAgain, after run: OnboardingCoordinator) async -> (OnboardingCoordinator, Over) {
        let over = Over()
        let again = run.makeRun(.practice(kind)) { over.on = true }
        again.start()
        _ = await until(6) { again.model.pageReady }
        await settle(1)
        return (again, over)
    }

    /// A picture for the stack, as ⌘ and a drag would take it.
    private static var swatch: NSImage {
        let image = NSImage(size: NSSize(width: 160, height: 100))
        image.lockFocus()
        NSColor.systemTeal.setFill()
        NSRect(x: 0, y: 0, width: 160, height: 100).fill()
        image.unlockFocus()
        return image
    }

    /// Oct 23, Ryan: More to try, walked as a person would.
    private static func moreToTry(_ run: OnboardingCoordinator, _ island: IslandController) async {
        // Take a few things: two parts with ⌘ held, opened, one looked at, one taken out, sent.
        let (few, fewOver) = await practice(.takeFew, after: run)
        let m = few.model
        check("More to try: Take a few things, outside the tour, Back nowhere", m.step == .takeFew && !m.canGoBack
              && !Step.run.contains(.takeFew), "\(m.step)")
        island.probe(.fnControl); await settle(0.4)
        check("…fn ⌃ listens; the bar asks for two parts with ⌘ held, ⌘ lit", m.waitingBeat == .twoTaken && m.keyboardTargets == ["⌘"]
              && m.instruction == L("Hold \(m.keys.spoken(.screenshot)) and drag over one part of the page, then another."),
              "\(String(describing: m.waitingBeat)) \(m.keyboardTargets) \(m.instruction ?? "nil")")
        for i in 0..<2 {
            island.probeTake(swatch)
            m.islandDidEmit(.referentTaken(kind: .region, rect: m.part(i == 0 ? "numbers" : "prs", in: .analytics)))
            if i == 0 {
                check("…one taken: keep holding ⌘ for another", m.instruction == L("Keep holding \(m.keys.spoken(.screenshot)) and drag over another part."),
                      m.instruction ?? "nil")
            }
        }
        check("…two taken: open them at the notch", m.waitingBeat == .stackOpened && island.probeStackCount == 2,
              "\(String(describing: m.waitingBeat)) \(island.probeStackCount)")
        island.probeOpenStack(); await settle(0.3)
        check("…opened: look at one", m.waitingBeat == .referentInspected, "\(String(describing: m.waitingBeat))")
        island.probeInspect(0); await settle(0.3)
        check("…looked at: take one out", m.waitingBeat == .referentRemoved, "\(String(describing: m.waitingBeat))")
        island.probeRemove(1); await settle(0.7)
        check("…taken out: one left at the notch and in what goes", island.probeStackCount == 1 && m.referents.count == 1
              && m.waitingBeat == .finish, "\(island.probeStackCount) \(m.referents.count) \(String(describing: m.waitingBeat))")
        island.probeWords(["compare these two"])
        island.probe(.fnControl)
        _ = await until(6) { island.probeState == "v2Send" }
        check("…fn ⌃: Choose chat, waiting for return", island.probeState == "v2Send" && m.waitingBeat == .send,
              "\(island.probeState) \(String(describing: m.waitingBeat))")
        island.probe(.enter)
        let fewDone = await until(10) { m.flow.isComplete }
        check("…sent with its one picture, and answered: done", fewDone && m.request?.referents.count == 1,
              "\(m.flow.done.map(\.rawValue)) \(m.request?.referents.count ?? -1)")
        m.continueTapped()
        _ = await until(3) { fewOver.on }
        check("…Continue: Home again", fewOver.on)

        // While it works: a message typed while it works waits its turn; then Answer again, stopped.
        let (working, workingOver) = await practice(.whileWorking, after: run)
        let w = working.model
        island.probe(.fnControl); await settle(0.4)
        island.probeWords(["plan a route for saturday from this trail report"])
        island.probe(.fnControl)
        _ = await until(6) { island.probeState == "v2Send" }
        island.probe(.enter); await settle(0.6)
        let id = island.probeSessions.last?.id
        check("While it works: sent, working; the bar asks for a message typed while it works",
              w.waitingBeat == .queued && island.probeSessions.last?.state == "working",
              "\(String(describing: w.waitingBeat)) \(island.probeSessions.last?.state ?? "nil")")
        if let id { island.probeType(id, "Start early, please.") }
        await settle(0.3)
        check("…typed while it works: it waits its turn", island.probeQueued == 1 && w.waitingBeat == .answer
              && w.instruction == L("Your message waits until this answer is done."),
              "\(island.probeQueued) \(String(describing: w.waitingBeat))")
        let both = await until(20) { w.waitingBeat == .answeredAgain }
        check("…the answer, then the waiting message goes, and is answered", both && island.probeQueued == 0,
              "\(String(describing: w.waitingBeat)) \(island.probeQueued)")
        if let id { island.probeAnswerAgain(id, model: "opus-5.5") }
        await settle(0.5)
        check("…Answer again with another model: working again; the bar asks to stop it", w.waitingBeat == .stopped
              && island.probeSessions.last?.state == "working", "\(String(describing: w.waitingBeat)) \(island.probeSessions.last?.state ?? "nil")")
        if let id { island.probeStop(id) }
        await settle(0.4)
        check("…Stop: stopped, and the step is done", w.flow.isComplete && island.probeSessions.last?.state == "failed"
              && w.instruction == L("Stopped. Only Stop stops an agent; closing it never does."),
              "\(w.flow.done.map(\.rawValue)) \(island.probeSessions.last?.state ?? "nil")")
        w.continueTapped()
        _ = await until(3) { workingOver.on }
        check("…Continue: Home again", workingOver.on)

        // Nowhere to type: fn with the pointer on the desktop; the words held at the notch; Copy,
        // then (again) Paste into the feedback window clicked into.
        for paste in [false, true] {
            let (nowhere, nowhereOver) = await practice(.nowhereToType, after: run)
            let n = nowhere.model
            n.pointerOver = nil
            check("Nowhere to type\(paste ? ", again" : ""): the bar asks for fn on the desktop, fn lit", n.waitingBeat == .heldShown
                  && n.keyboardTargets == Set(n.keys.caps(.dictation).map(OnboardingModel.keyboardLabel)),
                  "\(String(describing: n.waitingBeat)) \(n.keyboardTargets)")
            island.probe(.fn); await settle(0.3)
            check("…fn on the desktop listens", island.probeState == "voiceFlow", island.probeState)
            island.probeHold("Let's meet at noon.")
            await settle(0.3)
            check("…nowhere to type: the words held at the notch, and the bar says Copy or Paste",
                  island.probeState == "pasteNotFound" && n.waitingBeat == .heldTaken
                  && n.instruction == L("Nowhere to type, so the notch holds your words. Click Copy, or click into the feedback window and then Paste."),
                  "\(island.probeState) \(String(describing: n.waitingBeat))")
            check("…the feedback window takes no paste until it's clicked into", !n.pasteTarget())
            if paste {
                n.typingInto = .feedback
                check("…clicked into, it does", n.pasteTarget())
                _ = n.paste("Let's meet at noon.")
                check("…Paste: the words in the feedback window, done", n.flow.isComplete && n.feedbackText == "Let's meet at noon.",
                      n.feedbackText)
            } else {
                island.probeCopyHeld(); await settle(0.3)
                check("…Copy: done", n.flow.isComplete
                      && n.instruction == L("Whenever there's nowhere to type, your words wait at the notch."), "\(n.flow.done.map(\.rawValue))")
            }
            n.continueTapped()
            _ = await until(3) { nowhereOver.on }
            check("…Continue: Home again", nowhereOver.on)
        }
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

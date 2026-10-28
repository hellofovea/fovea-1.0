import SwiftUI
import AppKit
import OnboardingCore
import FoveaIsland
import FoveaPlatform

/// `Fovea --design-shots first-run <dir>` (FoveaV1/README.md): every page of the first run and
/// its moments as pictures of the real screen, for the dev team's design document. The run as
/// `--smoke-first-run` walks it (the practice agent answering, nothing about the Mac changed), but
/// with the stage and the notch on screen over a clean desktop (`RealScreenShot`). The pages
/// before the teaching are staged directly.
@MainActor
package enum OnboardingShots {
    package static func run(_ run: OnboardingCoordinator, to dir: URL) async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let model = run.model
        let island = run.island
        let screen = Screens.island ?? NSScreen.screens[0]
        guard RealScreenShot.allowed else {
            print("design-shots: Screen Recording is off for Fovea (System Settings › Privacy & Security)")
            return
        }
        RealScreenShot.showBackdrop(on: screen, picture: DesktopCover.tahoeDay())
        // As the real tour: Fovea in front (its menu bar), no Dock.
        NSApp.activate(ignoringOtherApps: true)
        NSApp.presentationOptions = [.hideDock]
        defer {
            NSApp.presentationOptions = []
            RealScreenShot.hideBackdrop()
        }
        for _ in 0..<60 where !model.pageReady { await settle(0.1) }
        await settle(1)

        // `--only a,b`: just the pictures whose names contain any of them (the run still walks it all).
        let only = CommandLine.arguments.firstIndex(of: "--only").flatMap {
            $0 + 1 < CommandLine.arguments.count ? CommandLine.arguments[$0 + 1].split(separator: ",").map(String.init) : nil
        }
        func shoot(_ name: String, after seconds: Double = 0.9) async {
            await settle(seconds)
            if let only, !only.contains(where: { name.contains($0) }) { return }
            // Only the clean desktop with the stage on it is ever pictured: never another Space the
            // person went to, nor the backdrop without the stage (it's on every Space; the stage isn't).
            if let backdrop = RealScreenShot.backdropWindow, !(RealScreenShot.onCleanDesktop(backdrop) && run.stageInFront) {
                let end = Date().addingTimeInterval(45)
                print("design-shots: waiting for the first run's Space")
                while !(RealScreenShot.onCleanDesktop(backdrop) && run.stageInFront), Date() < end {
                    NSApp.activate(ignoringOtherApps: true)
                    await settle(1)
                }
                guard RealScreenShot.onCleanDesktop(backdrop), run.stageInFront else { print("skipped fr-\(name)"); return }
                await settle(0.8)
            }
            guard let png = RealScreenShot.png(of: screen) else { print("failed \(name)"); return }
            try? png.write(to: dir.appendingPathComponent("fr-\(name).png"))
            print("wrote fr-\(name).png")
        }
        func page(_ step: Step, _ setup: (OnboardingModel) -> Void = { _ in }) {
            model.alert = nil
            model.previewFile = nil
            model.jump(to: step)
            setup(model)
            model.cancelWaits()
        }

        // Arrive: the name, the email, hello, make it yours.
        page(.name) { $0.typedName = "" }
        await shoot("01-name")
        page(.name) { $0.typedName = "Ryan" }
        await shoot("02-name-typed")
        model.continueTapped()
        page(.signIn) { $0.typedEmail = "" }
        await shoot("03-sign-up")
        page(.signIn) { $0.typedEmail = "ryan@example.com" }
        await shoot("04-sign-up-typed")
        // Oct 15 review: signing up as it goes (FR-03, FR-04, AC-01.2).
        page(.signIn) { $0.stageSignIn(.waiting(.apple)) }
        await shoot("04a-sign-up-waiting")
        page(.signIn) { $0.stageSignIn(.failed(.apple)) }
        await shoot("04b-sign-up-failed")
        page(.signIn) { $0.stageSignIn(.checkEmail("ryan@example.com")) }
        await shoot("04c-sign-up-check-email")
        page(.hello)
        await shoot("05-hello")
        page(.hello) { m in
            m.languageMoreOpen = true
            m.flow.setLanguageRequests(["Japanese", "Korean"])
        }
        await shoot("06-hello-languages")
        page(.makeItYours)
        await shoot("07-make-it-yours")
        model.setAccent(.purple)
        await shoot("08-make-it-yours-accent", after: 1.6)

        // Turn on: the permissions, the microphone; the agents.
        page(.permissions)
        await shoot("09-permissions", after: 1.2)
        page(.microphone)
        await shoot("10-microphone")
        page(.microphone) { m in
            m.flow.allow(.microphone)
            m.micPhase = .listening
            m.micLevel = 0.62
            m.micVoiced = 0.45
            m.host?.listening(true)
            m.host?.listeningLevel(0.62)
        }
        await shoot("11-microphone-listening", after: 1.2)
        model.host?.listening(false)
        page(.agents) { $0.flow.agentWishes = ["Cursor"] }
        await shoot("12-agents", after: 1.2)

        // Point and say: the weekly update, watched from the notch.
        page(.weeklyUpdate)
        await shoot("13-weekly-update", after: 1.5)
        model.doItForMe()
        await shoot("14-weekly-update-choose-chat", after: 1.6)
        island.probe(.enter)
        await shoot("15-weekly-update-sent", after: 0.7)
        let weekly = island.probeSessions.first?.id
        _ = await until(6) { model.step == .hover }
        island.probePointer(onNotch: false)
        await settle(0.4)
        _ = await until(4) { island.probePointer(onNotch: true); return island.probeState == "v2Board" }
        await shoot("16-hover-board-working", after: 0.8)
        _ = await until(20) { island.probeSessions.first { $0.id == weekly }?.state == "complete" }
        await shoot("17-hover-answer-back", after: 1.2)
        if let weekly {
            island.probeOpen(weekly)
            await shoot("18-hover-session-open", after: 1.2)
        }
        _ = await until(4) { model.flow.isComplete }
        model.continueTapped()
        _ = await until(4) { model.step == .packList }
        island.probePointer(onNotch: false)
        _ = await until(4) { island.probeState == "silent" }

        // The packing list, then asking more by voice in its session.
        await shoot("19-pack-list", after: 1.2)
        model.doItForMe()
        await shoot("20-pack-list-choose-chat", after: 1.6)
        island.probe(.enter)
        let packing = island.probeSessions.first { $0.id != weekly }?.id
        _ = await until(15) { island.probeState == "v2Chat" }
        await shoot("21-pack-list-answer", after: 1.2)
        _ = await until(6) { model.flow.isComplete }
        model.continueTapped()
        _ = await until(4) { model.step == .followUp }
        await shoot("22-follow-up", after: 1.0)
        if let packing {
            if island.probeState != "v2Chat" { island.probeOpen(packing); await settle(0.5) }
            island.probeWords(["now sort it into clothes and gear"])
            island.probe(.fn)
            await shoot("23-follow-up-listening", after: 1.0)
            island.probe(.fn)
            _ = await until(6) { island.probeState == "v2Chat" }
            await shoot("24-follow-up-working", after: 0.6)
            _ = await until(15) { model.flow.isComplete }
            await shoot("25-follow-up-answer", after: 1.2)
        }

        // Dictation, staged: the feedback window, then Messages.
        island.probePointer(onNotch: false)
        page(.dictationIntro)
        await shoot("26-dictation-intro", after: 1.2)
        page(.dictation) { m in
            m.pointerOver = .feedback
            m.dictationTarget = .feedback
            m.flow.record(.feedbackKey)
            m.host?.listening(true)
            m.host?.listeningLevel(0.5)
        }
        await shoot("27-dictation-feedback", after: 1.2)
        // Oct 17, Ryan: something taken while talking (⌘ and a drag), waiting to land after the words.
        model.islandDidEmit(.referentTaken(kind: .region, rect: OT.Layout.messagesFrame.insetBy(dx: 40, dy: 80)))
        await shoot("27a-dictation-taken", after: 0.8)
        page(.dictation) { m in
            m.feedbackText = OT.Dictation.sampleFeedback
            m.feedbackTaken = m.dictationTaken
            m.pointerOver = .messages
            m.dictationTarget = .messages
            for beat in [Beat.feedbackKey, .feedbackTaken, .feedbackLanded, .replyKey] { m.flow.record(beat) }
            m.host?.listening(true)
            m.host?.listeningLevel(0.5)
        }
        await shoot("28-dictation-reply", after: 1.2)
        model.host?.listening(false)
        page(.dictation) { m in
            m.feedbackText = OT.Dictation.sampleFeedback
            m.replyText = OT.Dictation.sampleReply
            m.feedbackSent = true
            for beat in [Beat.feedbackKey, .feedbackTaken, .feedbackLanded, .replyKey, .replyLanded] { m.flow.record(beat) }
        }
        await shoot("29-dictation-done", after: 1.2)

        // Home: your words (sample words, never this Mac's other apps), then the end.
        page(.dictionary) { m in
            m.importCandidates = DictionaryImport.parse(pasted: OT.Dictation.sampleWords)
            m.importChosen = Set(m.importCandidates.map(\.word))
        }
        await shoot("30-your-words", after: 1.0)
        // Oct 15 review, OB-01.6.
        page(.memory)
        await shoot("30a-what-fovea-remembers", after: 1.2)
        page(.home)
        await shoot("31-all-set", after: 1.2)
    }

    private static func settle(_ seconds: Double) async {
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

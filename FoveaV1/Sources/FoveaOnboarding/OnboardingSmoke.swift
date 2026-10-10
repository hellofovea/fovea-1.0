import SwiftUI
import AppKit
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

        // Before the teaching: nothing at the notch.
        model.jump(to: .makeItYours); await settle(0.4)
        check("Make it yours opens with nothing at the notch", island.probeState == "silent", island.probeState)
        check("…and the board doesn't open from the notch yet", !model.allowsBoard())
        model.setAura(.ocean); await settle(0.4)
        check("touching a light pulls the notch down, glowing", island.probeState == "v2Voice", island.probeState)
        model.setAuraHue(0.3); await settle(2.0)
        check("…and it keeps glowing while the light is picked", island.probeState == "v2Voice", island.probeState)
        model.jump(to: .agents); await settle(0.4)
        check("leaving Make it yours puts the notch back", island.probeState == "silent", island.probeState)

        // The weekly update: Do it for me stages the request on Choose chat; Return sends it.
        model.jump(to: .weeklyUpdate); await settle(1.5)
        check("in the teaching, the board may open from the notch", model.allowsBoard())
        check("no line is ever put under the notch", !island.probeCaptionUnderNotch)
        island.probe(.fn); await settle(0.3)
        check("fn where it isn't taught says so on the bar", model.hintText != nil, model.hintText ?? "nil")
        model.doItForMe(); await settle(1.5)
        check("Do it for me puts the request together at the notch, on Choose chat", island.probeState == "v2Send", island.probeState)
        island.probe(.enter); await settle(0.6)
        check("Return sends it: the session on the board, working", island.probeSessions.count == 1, "\(island.probeSessions.count)")
        let weekly = island.probeSessions.first?.id
        _ = await until(5) { model.step == .hover }
        check("…and the run moves on to watching it", model.step == .hover, "\(model.step)")

        // Hover: the board from the notch, as any day; the answer there when it's back.
        island.probePointer(onNotch: false); await settle(0.2)
        let opened = await until(4) { island.probePointer(onNotch: true); return island.probeState == "v2Board" }
        check("the pointer at the notch opens the board", opened, island.probeState)
        let done = await until(15) { island.probeSessions.first { $0.id == weekly }?.state == "complete" }
        check("the practice agent's update comes back", done)
        if let s = island.probeSessions.first(where: { $0.id == weekly }) {
            check("…with what it did (its steps) folded under the answer", s.steps >= 3, "\(s.steps)")
            check("…and the file it wrote to open", s.files.contains(PracticeFiles.update), "\(s.files)")
        }
        let complete = await until(4) { model.flow.isComplete }
        check("seen and back, the step is done, waiting for Continue on the bar", complete && model.guideButtonShown,
              "done \(model.flow.done.map(\.rawValue)) waiting \(String(describing: model.flow.waitingFor)) answered \(model.answered.map(\.rawValue))")
        model.continueTapped()
        _ = await until(4) { model.step == .packList }
        check("Continue goes on to the packing list", model.step == .packList, "\(model.step)")
        island.probePointer(onNotch: false)
        _ = await until(4) { island.probeState == "silent" }

        // The packing list, then asking more by voice in its session.
        await settle(1)
        model.doItForMe(); await settle(1.5)
        island.probe(.enter); await settle(0.6)
        let packing = island.probeSessions.first { $0.id != weekly }?.id
        check("the packing list goes", packing != nil)
        _ = await until(12) { model.flow.isComplete }
        check("its answer back, the step is done", model.flow.isComplete)
        // The practice agent is quick (a few seconds): as on any day, a quick answer opens by
        // itself (Claude Code, slower, waits on the board).
        check("…a quick answer opens by itself, as any day", island.probeState == "v2Chat", island.probeState)
        model.continueTapped()
        _ = await until(4) { model.step == .followUp }
        check("Continue asks for more", model.step == .followUp, "\(model.step)")
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
            if let s = island.probeSessions.first(where: { $0.id == packing }) {
                check("…the earlier answer kept in the session", s.history == 1, "\(s.history)")
            }
        }

        // Reading pages after the teaching: the notch rests, says nothing.
        model.jump(to: .dictationIntro); await settle(0.6)
        check("a page to read after the teaching rests the notch", island.probeState == "silent", island.probeState)
        check("…and the board doesn't open from it", !model.allowsBoard())
        model.jump(to: .home); await settle(0.6)
        check("You're all set: nothing at the notch", island.probeState == "silent", island.probeState)

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

import SwiftUI
import AppKit
import FoveaCore

// `--record-creatures <file.mp4>`: the creatures board in motion, cropped to the board, into a
// movie, then quit (docs/island/CREATURES.md). A scripted pointer and a scripted afternoon: the
// board opens and they look up; the pointer passes along the wings; a session gets through its
// plan and finishes, hopping to the person's side; a new request comes out of the notch; one is
// read and goes home.

extension WorkbenchModel {
    func recordCreatures(to url: URL) async {
        var waited = 0
        while stageProbe?.window == nil, waited < 50 {
            try? await Task.sleep(for: .milliseconds(100))
            waited += 1
        }
        guard let window = stageProbe?.window else { print("no window to record"); exit(1) }
        window.setContentSize(WorkbenchTokens.Snapshot.size)
        columnVisibility = .detailOnly
        pointerScripted = true
        boardStyle = .creatures
        try? await Task.sleep(for: .milliseconds(900))
        // The board's room on the display, and around it.
        let width = WorkbenchTokens.Creatures.width
        let region = CGRect(x: (display.frame.width - width) / 2 - 50, y: 0, width: width + 100, height: 262)
        guard let crop = windowRect(forDisplay: region),
              let recorder = WorkbenchRecorder(url: url, window: window, maxWidth: 1600, crop: crop, captionHeight: 64)
        else { print("cannot record to \(url.path)"); exit(1) }
        stageFeedback(.progress)
        // The script drives the sent session's plan itself, below.
        if let sent = v2Session { v2Runs[sent]?.cancel(); v2Runs[sent] = nil }
        notchState = .silent
        try? await Task.sleep(for: .milliseconds(500))
        recorder.start()

        func caption(_ text: String) { recorder.caption = text }
        func pause(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }
        func slots() -> CreatureSlots {
            CreatureSlots.make(model: self, width: width, notch: NotchGeometry.notchRect(metrics: metrics, spec: WorkbenchTokens.Island.spec))
        }
        /// The pointer glides to a point on the board; the creature it reaches comes on the stage.
        func glide(to target: CGPoint, seconds: Double) async {
            let from = v2BoardPointer ?? CGPoint(x: width / 2, y: 120)
            let steps = max(1, Int(seconds * 60))
            for i in 1...steps {
                let k = Double(i) / Double(steps)
                let e = k < 0.5 ? 2 * k * k : 1 - pow(-2 * k + 2, 2) / 2
                v2BoardPointer = CGPoint(x: from.x + (target.x - from.x) * e, y: from.y + (target.y - from.y) * e)
                if let near = slots().places.min(by: { abs($0.point.x - v2BoardPointer!.x) < abs($1.point.x - v2BoardPointer!.x) }),
                   abs(near.point.x - v2BoardPointer!.x) < 14, v2BoardPointer!.y < 40 {
                    v2Focus = near.task.id
                }
                try? await Task.sleep(for: .seconds(seconds / Double(steps)))
            }
        }

        caption("The board opens: a small hop each; the one waiting on you calls")
        await pause(0.6)
        v2BoardPointer = CGPoint(x: width / 2, y: 18)
        showAgentPanel(pinned: true)
        await pause(1.8)

        caption("Waiting on you: amber and larger, still, the only one watching the pointer")
        if let waiting = slots().places.first(where: { $0.task.state == .needsYou }) {
            await glide(to: CGPoint(x: waiting.point.x + 40, y: 70), seconds: 1.2)
            await glide(to: CGPoint(x: waiting.point.x - 60, y: 110), seconds: 1.2)
            await glide(to: CGPoint(x: waiting.point.x, y: waiting.point.y), seconds: 0.8)
        }
        await pause(0.8)

        caption("At work: hollow, filling with its plan; each new step one gesture; it grows under the pointer")
        let right = slots().places.filter { $0.side > 0 }.sorted { $0.point.x < $1.point.x }
        if let first = right.first, let last = right.last {
            await glide(to: first.point, seconds: 0.7)
            await glide(to: last.point, seconds: 2.4)
            await glide(to: first.point, seconds: 1.2)
        }
        await pause(0.6)

        caption("Finished: it fills up and hops over to your side, holding its page")
        if let sent = v2Session, v2Task(sent)?.state == .working {
            v2Focus = sent
            // The rest of its plan, then done.
            for _ in 0..<3 {
                if let i = agentTasks.firstIndex(where: { $0.id == sent }), agentTasks[i].planDone < agentTasks[i].plan.count {
                    withAnimation(WorkbenchTokens.Creatures.fillChange) { agentTasks[i].planDone += 1 }
                }
                await pause(0.7)
            }
            v2Scripts[sent] = nil
            if let i = agentTasks.firstIndex(where: { $0.id == sent }) {
                withAnimation(WorkbenchTokens.Creatures.move) {
                    agentTasks[i].state = .complete
                    agentTasks[i].answer = v2Request.answer(followUp: false)
                    v2FinishedAt[sent] = Date()
                }
            }
        }
        await pause(2.4)

        caption("Sent: a new one comes out of the notch")
        withAnimation(WorkbenchTokens.Creatures.move) {
            let fresh = makeV2Session(V2Request.formula.suggestions[0], at: 0)
            v2Focus = fresh
        }
        await pause(2.6)

        caption("Read: it goes back into the notch")
        if let done = slots().places.first(where: { $0.task.state == .complete }) {
            await glide(to: done.point, seconds: 0.9)
            await pause(0.6)
            withAnimation(WorkbenchTokens.Creatures.move) { _ = v2Checked.insert(done.task.id) }
        }
        await pause(2.2)
        caption("")
        await pause(0.4)
        await recorder.finish()
        print("wrote \(url.path) (\(recorder.frames) frames)")
        exit(0)
    }
}

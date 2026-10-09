import SwiftUI
import AppKit
import FoveaCore

// `--record-pets <file.mp4>`: the same pet through the board's designs, in motion, cropped to the
// notch and the board, into a movie, then quit (docs/island/CREATURES.md). A scripted afternoon: at
// rest, the pet of the session waiting on the person beside the notch; the board opens on Lanes
// and the pets walk on as their plans get done; one reaches the finish; the person allows a
// command and that one goes back to work; Desk, List and Capsules show the same pets; closed, the
// most pressing one rests beside the notch again.

extension WorkbenchModel {
    func recordPets(to url: URL) async {
        var waited = 0
        while stageProbe?.window == nil, waited < 50 {
            try? await Task.sleep(for: .milliseconds(100))
            waited += 1
        }
        guard let window = stageProbe?.window else { print("no window to record"); exit(1) }
        window.setContentSize(WorkbenchTokens.Snapshot.size)
        columnVisibility = .detailOnly
        pointerScripted = true
        boardStyle = .petLanes
        try? await Task.sleep(for: .milliseconds(900))
        // The widest design's room on the display, and around it.
        let width = WorkbenchTokens.Pets.deskWidth + 80
        let region = CGRect(x: (display.frame.width - width) / 2, y: 0, width: width, height: 610)
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
        /// One more step of a session's plan done.
        func advance(_ id: String) {
            guard let i = agentTasks.firstIndex(where: { $0.id == id }), agentTasks[i].planDone < agentTasks[i].plan.count else { return }
            withAnimation(WorkbenchTokens.Pets.laneMove) { agentTasks[i].planDone += 1 }
        }

        caption("At rest: beside the notch, the pet of the session most in need (waiting on you: amber)")
        await pause(2.6)

        caption("The board opens on Lanes: each pet as far along as its agent's plan has got")
        showAgentPanel(pinned: true)
        await pause(2.8)

        caption("A step of its plan done: it walks on")
        advance("t-shortcuts")
        await pause(1.4)
        advance("t-launch")
        await pause(1.4)
        if let sent = v2Session { advance(sent) }
        await pause(1.4)

        caption("Finished: at the finish its loop closes, and it joins Done")
        if let sent = v2Session, v2Task(sent)?.state == .working {
            v2Scripts[sent] = nil
            if let i = agentTasks.firstIndex(where: { $0.id == sent }) {
                withAnimation(WorkbenchTokens.Board.move) {
                    agentTasks[i].planDone = agentTasks[i].plan.count
                    agentTasks[i].state = .complete
                    agentTasks[i].answer = v2Request.answer(followUp: false)
                    v2FinishedAt[sent] = Date()
                }
            }
        }
        await pause(2.6)

        caption("Desk: the same pets as a team, four to a row, each with its agent and what it is doing")
        withAnimation(WorkbenchTokens.Board.move) { boardStyle = .petDesk }
        await pause(2.6)
        caption("Allowed in place: it calls no more and goes back to work")
        allowTask("t-paste")
        await pause(3.0)

        caption("List: the board's rows, each led by its pet; the agent's icon by the title")
        withAnimation(WorkbenchTokens.Board.move) { boardStyle = .petList }
        await pause(2.8)

        caption("Capsules: each session its own small island, its pet at the front")
        withAnimation(WorkbenchTokens.Board.move) { boardStyle = .petCapsules }
        await pause(3.0)

        caption("Closed: the most pressing one rests beside the notch")
        closeAgentPanel()
        await pause(2.6)
        caption("")
        await pause(0.4)
        await recorder.finish()
        print("wrote \(url.path) (\(recorder.frames) frames)")
        exit(0)
    }
}

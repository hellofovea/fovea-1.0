import SwiftUI
import AppKit
import OnboardingCore
import FoveaIsland

// The scripted parts of the first run: the permissions as macOS asks for them, connecting the
// agents, the sends, the follow-up, the real Home. The keys, the pages, the files and the agent's
// work are real. There's no demo before the tasks (Oct 9, round two): you learn by doing.

extension OnboardingModel {
    // MARK: Permissions, as macOS asks

    /// The one button before the system's own prompt (Apple HIG: a plain verb, then macOS asks).
    func askMicrophone() {
        guard let host else {
            animate(OT.Motion.content) { alert = .microphone }
            return
        }
        // macOS's own prompts: the microphone, then speech recognition (1.0 turns words into text
        // on this Mac).
        host.askMicrophoneAndSpeech { [weak self] allowed in
            guard let self else { return }
            guard allowed else {
                self.say(L("Fovea needs the microphone to hear you. Allow it in System Settings, or skip for now."), hold: true)
                return
            }
            self.grant(.microphone)
        }
    }

    func grant(_ permission: Permission) {
        flow.allow(permission)
        animate(OT.Motion.content) { _ = switchedOn.insert(permission) }
        // Allowed isn't the end of the microphone step: it has to hear the line (Oct 8).
        if permission == .microphone, step == .microphone, !flow.isComplete {
            startMicTest()
            return
        }
        // Oct 17, Ryan (round 2): "the user should manually give access to each one … right now it
        // just jumps over". Allowed shows on its row, with the check, and the page waits for the
        // person's Continue: it never moves on by itself, not after the last Allow, nor with
        // everything allowed at launch. (Input Monitoring, OB-01.5, is never waited on either.)
        sound.cue(.allow)
        if step == .permissions, permission == .accessibility, !flow.isComplete {
            // The first list done: System Settings turns to the second (Fovea opens it by its link).
            after(OT.Timing.nextList, "nextList") { [weak self] in
                guard let self else { return }
                self.animate(OT.Motion.content) { self.settingsPane = .screenRecording }
            }
        }
    }

    /// Input Monitoring allowed, seen live on the permissions page (Oct 15 review, OB-01.5).
    func inputMonitoringAllowed() {
        guard !flow.allowed.contains(.inputMonitoring) else { return }
        grant(.inputMonitoring)
    }

    // MARK: Your agents

    func toggleAgent(_ agent: Agent) {
        animate(OT.Motion.select) {
            if agentsOn.contains(agent) { agentsOn.remove(agent) } else { agentsOn.insert(agent) }
        }
        sound.cue(.tick)
    }

    /// One of the agents to come, asked for (Oct 9: to help choose what's built next).
    func toggleWish(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        animate(OT.Motion.select) {
            if let i = flow.agentWishes.firstIndex(of: trimmed) { flow.agentWishes.remove(at: i) } else { flow.agentWishes.append(trimmed) }
        }
        sound.cue(.tick)
    }

    /// Connect: the agents left on answer the tasks. Connected is connected (Oct 9): when Claude
    /// Code can't answer here (its command-line tool isn't signed in), the practice agent makes the
    /// same edits, quietly.
    func connectAgents() {
        sound.cue(.tick)
        let real = connectedAgents.contains(.claudeCode) && agentSignedIn != false
        // Connected again after Back (Oct 15 review, OB-01.7): as the agents are switched now.
        useRealAgent = real && !options.harness && !options.practiceAgent
        say(connectedAgents.isEmpty ? L("The practice agent will answer for now.")
            : L("\(connectedAgents.map(\.name).joined(separator: L(" and "))) connected."), hold: false)
        beat(.agentsConnected)
    }

    // MARK: Sending

    /// The way past a task: Fovea puts it together (the two parts, or the line and
    /// the list) with the words, and it waits on the review card for return.
    func doItForMe() {
        cancelWaits(except: ["skip"])
        flow.retry()
        referents = []
        marks = []
        switch step {
        case .weeklyUpdate:
            // Oct 17, Ryan (round 2): parts, one from each tab (no whole screen any more). Oct 18,
            // Ryan: two of them, the numbers and the pull requests.
            let parts = Self.weeklyParts.compactMap { beat -> (CGRect, PracticeTab)? in
                guard let name = beat.part, let tab = beat.tab else { return nil }
                return (part(name, in: tab), tab)
            }
            referents = parts.map { TakenReferent(kind: .region($0.0), tab: $0.1) }
            for (i, item) in parts.enumerated() { capture(referents[i].id, region: item.0, tab: item.1, name: "part-\(i + 1).png") }
            for beat in [Beat.requestKey] + Self.weeklyParts + [.finish] { flow.record(beat) }
        case .packList:
            let lines = paragraphLines[OT.Practice.snowParagraph] ?? []
            marks = lines.isEmpty ? [] : [HighlightMark(rects: lines)]
            if let frame = fileFrames[PracticeFiles.list] {
                marks.append(HighlightMark(rects: [frame.insetBy(dx: OT.Marks.fileInset.width, dy: OT.Marks.fileInset.height)], file: true))
            }
            referents = [TakenReferent(kind: .passage(OT.Practice.snowParagraph), tab: .trail),
                         TakenReferent(kind: .file(.list), path: practice.url(PracticeFiles.list))]
            for beat in [Beat.requestKey, .passage, .file, .finish] { flow.record(beat) }
        default:
            return
        }
        // The pictures now, for the stack at the notch and the agent's files.
        var items: [StagedReferent] = []
        for i in referents.indices {
            switch referents[i].kind {
            case .wholeScreen, .region:
                let shot: ScreenCapture.Shot?
                if case .region(let r) = referents[i].kind {
                    shot = ScreenCapture.region(r, model: self, tab: referents[i].tab, name: "part-\(i + 1).png")
                } else {
                    shot = ScreenCapture.whole(model: self, tab: .analytics, name: "screen-\(i + 1).png")
                }
                if let shot {
                    referents[i].image = shot.image
                    referents[i].path = shot.path
                    items.append(.picture(shot.image, source: "\(referents[i].tab?.title ?? L("Desktop")) · Fovea"))
                }
            case .passage(let p):
                items.append(.passage(paragraphTexts[p] ?? PracticePage.paragraphs[min(p, PracticePage.paragraphs.count - 1)],
                                      source: "\(L("Trail report")) · Fovea"))
            case .file(let file):
                items.append(.file(practice.url(file.name)))
            }
        }
        request = PracticeRequest(words: copy.script ?? "", referents: referents, step: step)
        beat(.review)
        island = .review
        host?.stageRequest(words: copy.script ?? "", items: items)
    }

    /// A tab's part, in display points, with a little room around it.
    func part(_ name: String, in tab: PracticeTab) -> CGRect {
        let origin = pageOrigin
        let r = pageLayouts[tab]?.parts[name] ?? CGRect(x: 28, y: 60, width: 600, height: 200)
        return r.offsetBy(dx: origin.x, dy: origin.y).insetBy(dx: -8, dy: -8)
    }

    func theme(of request: PracticeRequest) -> String {
        switch request.step {
        case .weeklyUpdate: L("This week's update")
        case .packList: L("Packing for the snow")
        default: L("What's on the page")
        }
    }

    func record(_ referent: TakenReferent) -> PracticeRecord.Referent {
        switch referent.kind {
        case .region: .region(source: "\(referent.tab?.title ?? L("Desktop")) · Safari")
        case .wholeScreen: .wholeScreen
        case .passage(let i): .passage(text: paragraphTexts[i] ?? PracticePage.paragraphs[min(i, PracticePage.paragraphs.count - 1)],
                                       source: "\(L("Trail report")) · Safari")
        case .file(let file): .file(name: file.name, type: file.type, folder: L("Desktop"))
        }
    }

    // MARK: Home

    /// The real Home, with what was made here on top: the App opens it (`onFinished`), in the
    /// accent and the aura chosen at the start, with the words brought in.
    func openHome() {
        homeOpened = true
        guard !options.smoke else { return }
        onFinished?(PracticeCaptures.captures(flow.records))
    }

    /// Eye tracking's beta, asked for (Oct 9, round two: a request, not feedback).
    func askEyeTracking() {
        guard !eyeTrackingAsked else { return }
        if !options.harness { FeedbackStore.append("Eye tracking: asked to join the beta") }
        sound.cue(.allow)
        animate(OT.Motion.select) { eyeTrackingAsked = true }
    }
}

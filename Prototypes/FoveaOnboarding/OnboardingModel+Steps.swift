import SwiftUI
import AppKit
import OnboardingCore

// The scripted parts of the first run: the permissions as macOS asks for them, connecting the
// agents, the sends, the follow-up, the real Home. The keys, the pages, the files and the agent's
// work are real. There's no demo before the tasks (Oct 9, round two): you learn by doing.

extension OnboardingModel {
    // MARK: Permissions, as macOS asks

    /// The line from the notch, dropped: on the list, Fovea joins it already on (macOS 27 adds a
    /// dropped app switched on; REAL_MAC.md). Then the other list.
    func tileDropped(at point: CGPoint) {
        tileDrag = nil
        guard let pane = settingsPane, settingsListFrame.insetBy(dx: -20, dy: -20).contains(point) else { return }
        animate(OT.Motion.content) { _ = inList.insert(pane) }
        sound.cue(.tick)
        if pane == .screenRecording {
            animate(OT.Motion.content) { _ = switchedOn.insert(pane) }
            after(OT.Timing.reopenAlert, "reopen") { [weak self] in self?.animate(OT.Motion.calm) { self?.alert = .reopen } }
        } else {
            grant(pane)
        }
    }

    /// The help's way: Fovea already in the list, its switch flipped on.
    func toggleSwitch(_ permission: Permission) {
        guard inList.contains(permission), !switchedOn.contains(permission) else { return }
        animate(OT.Motion.content) { _ = switchedOn.insert(permission) }
        if permission == .screenRecording {
            after(OT.Timing.reopenAlert, "reopen") { [weak self] in self?.animate(OT.Motion.calm) { self?.alert = .reopen } }
        } else {
            grant(permission)
        }
    }

    /// The one button before the system's own prompt (Apple HIG: a plain verb, then macOS asks).
    func askMicrophone() {
        animate(OT.Motion.calm) { alert = .microphone }
    }

    func alertAnswered(_ allow: Bool) {
        guard let shown = alert else { return }
        animate(OT.Motion.calm) { alert = nil }
        switch shown {
        case .microphone:
            guard allow else {
                say("Fovea needs the microphone to hear you. Allow it in System Settings, or skip for now.", hold: true)
                return
            }
            grant(.microphone)
        case .reopen:
            reopen(now: allow)
        }
    }

    /// macOS wants Fovea to reopen before Screen Recording takes: it does, and comes back here.
    private func reopen(now: Bool) {
        if now {
            animate(OT.Motion.calm) { flash = true }
            after(OT.Timing.reopenPause, "reopened") { [weak self] in
                guard let self else { return }
                self.animate(OT.Motion.slow) { self.flash = false }
                self.grant(.screenRecording)
            }
        } else {
            grant(.screenRecording)
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
        if step == .permissions {
            if flow.isComplete {
                animate(OT.Motion.content) { captionText = Copy.permissionCaptions[2] }
                sound.cue(.allow)
                after(OT.Timing.autoAdvance, "advance") { [weak self] in
                    guard let self else { return }
                    self.animate(OT.Motion.calm) { self.settingsPane = nil }
                    if let next = self.flow.advance() { self.enter(next) }
                }
            } else if permission == .accessibility {
                // The first list done: System Settings turns to the second (Fovea opens it by its
                // link), and the notch asks for one more drag.
                sound.cue(.allow)
                after(OT.Timing.nextList, "nextList") { [weak self] in
                    guard let self else { return }
                    self.animate(OT.Motion.calm) { self.settingsPane = .screenRecording }
                    self.animate(OT.Motion.content) { self.captionText = Copy.permissionCaptions[1] }
                    self.dragTried = false
                }
            }
            return
        }
        if flow.isComplete {
            sound.cue(.allow)
            after(OT.Timing.autoAdvance, "advance") { [weak self] in
                guard let self else { return }
                if let next = self.flow.advance() { self.enter(next) }
            }
        }
    }

    // MARK: Your agents

    func toggleAgent(_ agent: Agent) {
        animate(OT.Motion.content) {
            if agentsOn.contains(agent) { agentsOn.remove(agent) } else { agentsOn.insert(agent) }
        }
        sound.cue(.tick)
    }

    /// One of the agents to come, asked for (Oct 9: to help choose what's built next).
    func toggleWish(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        animate(OT.Motion.content) {
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
        if !real { useRealAgent = false }
        say(connectedAgents.isEmpty ? "The practice agent will answer for now."
            : "\(connectedAgents.map(\.name).joined(separator: " and ")) connected.", hold: false)
        beat(.agentsConnected)
    }

    // MARK: Sending

    /// The way past a task: Fovea puts it together (the screen and the two parts, or the line and
    /// the list) with the words, and it waits on the review card for return.
    func doItForMe() {
        cancelWaits(except: ["skip"])
        flow.retry()
        referents = []
        marks = []
        switch step {
        case .weeklyUpdate:
            let screen = TakenReferent(kind: .wholeScreen, tab: .analytics)
            let prs = part("prs", in: .github)
            let tickets = part("tickets", in: .support)
            referents = [screen, TakenReferent(kind: .region(prs), tab: .github), TakenReferent(kind: .region(tickets), tab: .support)]
            capture(referents[0].id, tab: .analytics, name: "screen-1.png")
            capture(referents[1].id, region: prs, tab: .github, name: "part-2.png")
            capture(referents[2].id, region: tickets, tab: .support, name: "part-3.png")
            for beat in [Beat.requestKey, .wholeScreen, .prs, .tickets, .finish] { flow.record(beat) }
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
        request = PracticeRequest(words: copy.script ?? "", referents: referents, step: step)
        beat(.review)
        showIsland(.review, OT.Motion.open)
    }

    /// A tab's part, in display points, with a little room around it.
    func part(_ name: String, in tab: PracticeTab) -> CGRect {
        let origin = pageOrigin
        let r = pageLayouts[tab]?.parts[name] ?? CGRect(x: 28, y: 60, width: 600, height: 200)
        return r.offsetBy(dx: origin.x, dy: origin.y).insetBy(dx: -8, dy: -8)
    }

    /// Return on the review card. The agent runs as a process of Fovea's, so there's no Automation
    /// prompt (that's only for handing words to Terminal).
    func send() {
        guard readyToSend, let request else { return }
        sound.cue(.step)
        let session = PracticeSession(task: step, title: theme(of: request), agent: agentName,
                                      turns: [.init(ask: request.words, answer: nil)])
        sessions.append(session)
        openSessionID = session.id
        flow.add(PracticeRecord(kind: .dispatch, words: request.words, referents: request.referents.map(record),
                                agent: agentName, chat: OT.Practice.chat, theme: theme(of: request),
                                secondsBeforeEnd: request.step == .weeklyUpdate ? 300 : 200))
        // The update goes on being written while the next step shows where to watch it; the
        // packing list's row shows on the board at once.
        if step == .packList { showIsland(.board, OT.Motion.open) }
        dispatch(request, session: session.id, turn: 0)
        beat(.send)
    }

    /// Jumped straight to the follow-up: a finished packing session to ask more in.
    func prepareFollowUpSession() {
        practice.write(PracticeFiles.list, PracticeFiles.listStart + OT.Send.practiceAdded)
        let session = PracticeSession(task: .packList, title: "Packing for the snow", agent: agentName,
                                      turns: [.init(ask: Copy.step(.packList).script ?? "", answer: OT.Send.practiceReply)])
        sessions.append(session)
        answered.insert(.packList)
        openSessionID = session.id
        showIsland(.session, OT.Motion.open)
    }

    /// fn in the open session, then fn again: the follow-up joins the packing session.
    func askMore() {
        guard let index = sessions.lastIndex(where: { $0.task == .packList }) else { return }
        let ask = Copy.step(.followUp).script ?? ""
        sessions[index].turns.append(.init(ask: ask, answer: nil))
        openSessionID = sessions[index].id
        flow.add(PracticeRecord(kind: .dispatch, words: ask, agent: agentName, chat: OT.Practice.chat,
                                theme: "Sorting the packing list", secondsBeforeEnd: 150))
        showIsland(.session, OT.Motion.open)
        dispatch(PracticeRequest(words: ask, referents: [], step: .followUp), session: sessions[index].id,
                 turn: sessions[index].turns.count - 1)
    }

    func theme(of request: PracticeRequest) -> String {
        switch request.step {
        case .weeklyUpdate: "This week's update"
        case .packList: "Packing for the snow"
        default: "What's on the page"
        }
    }

    func record(_ referent: TakenReferent) -> PracticeRecord.Referent {
        switch referent.kind {
        case .region: .region(source: "\(referent.tab?.title ?? "Desktop") · Safari")
        case .wholeScreen: .wholeScreen
        case .passage(let i): .passage(text: paragraphTexts[i] ?? PracticePage.paragraphs[min(i, PracticePage.paragraphs.count - 1)],
                                       source: "Trail report · Safari")
        case .file(let file): .file(name: file.name, type: file.type, folder: "Desktop")
        }
    }

    // MARK: Home

    /// The real Home, from Fovea Captures, with what was made here on top, in the accent and the
    /// aura chosen at the start, and the words brought in.
    func openHome() {
        homeOpened = true
        guard !options.smoke else { return }
        let handle = CapturesHomeHandle(records: flow.records, personal: personal, words: importedWords)
        home = handle
        after(options.harness ? 0 : OT.Timing.homeOpen, "home") { [weak self] in
            guard let self else { return }
            handle.show(over: self.windowFrame)
        }
    }

    /// The onboarding window's frame on screen, for placing Home over it.
    var windowFrame: NSRect? {
        NSApp.windows.first { $0.identifier?.rawValue.hasPrefix("onboarding") == true || $0.title == "Fovea Onboarding" }?.frame
    }

    /// Eye tracking's beta, asked for (Oct 9, round two: a request, not feedback).
    func askEyeTracking() {
        guard !eyeTrackingAsked else { return }
        if !options.harness { FeedbackStore.append("Eye tracking: asked to join the beta") }
        sound.cue(.allow)
        animate(OT.Motion.content) { eyeTrackingAsked = true }
    }
}

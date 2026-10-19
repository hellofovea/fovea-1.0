import SwiftUI
import AppKit
import OnboardingCore
import FoveaIsland

// What makes the first run real: the microphone test listens for the line, the tasks go to the
// agent on this Mac (Claude Code) with the practice site and files, the blog reloads with its edit,
// dictation writes your own words, the feedback is kept when you send it, and your words come in
// from another dictation app. Each has a backup when something fails.

enum MicPhase: Equatable {
    /// Before the microphone is allowed.
    case waiting
    /// Listening for the line.
    case listening
    case heard
    /// No microphone, or not allowed: hold space while talking instead.
    case unavailable
}

extension OnboardingModel {
    // MARK: The microphone test

    /// Allowed: now say the line. The bar listens to the real microphone; with none, space stands in.
    func startMicTest() {
        micVoiced = 0
        micLevel = 0
        animate(OT.Motion.content) { micPhase = .listening }
        showIsland(.voice(.dictation), OT.Motion.barOpen)
        guard !options.harness else { return }
        mic.onLevel = { [weak self] level in
            self?.heardLevel(level)
            self?.host?.listeningLevel(level)
        }
        lastMicSample = Date()
        mic.start { [weak self] ok in
            guard let self, self.micPhase == .listening, !ok else { return }
            self.animate(OT.Motion.content) { self.micPhase = .unavailable }
        }
    }

    func stopMicTest() {
        mic.stop()
        mic.onLevel = nil
        host?.listening(false)
        spaceTalk?.invalidate()
        spaceTalk = nil
    }

    /// One reading of the input. Enough voice, and the test is passed.
    func heardLevel(_ level: Double) {
        let now = Date()
        let dt = min(0.2, now.timeIntervalSince(lastMicSample))
        lastMicSample = now
        micLevel = micLevel * OT.Mic.smoothing + level * (1 - OT.Mic.smoothing)
        guard step == .microphone, micPhase == .listening || micPhase == .unavailable else { return }
        if level > OT.Mic.voiced { micVoiced += dt }
        if micVoiced >= OT.Mic.heardSeconds { heard() }
    }

    func heard() {
        guard micPhase != .heard else { return }
        stopMicTest()
        animate(OT.Motion.content) { micPhase = .heard }
        micLevel = 0
        say(Copy.micHeard, hold: false)
        beat(.heard)
    }

    /// Space, held, talks for a Mac with no microphone (and for the smoke run).
    func spaceKey(_ down: Bool) -> Bool {
        guard step == .microphone, micPhase == .unavailable || micPhase == .listening else { return false }
        spaceTalk?.invalidate()
        spaceTalk = nil
        if down {
            lastMicSample = Date()
            spaceTalk = Timer.scheduledTimer(withTimeInterval: OT.Mic.spaceTick, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.heardLevel(OT.Mic.spaceLevel) }
            }
        } else {
            micLevel = 0
        }
        return true
    }

    // MARK: The agent

    var agentExecutable: URL? { AgentDetector.executable(.claudeCode) }

    /// The send goes to Claude Code on this Mac when it's connected, signed in, and the panel
    /// allows it.
    var sendsToRealAgent: Bool {
        useRealAgent && !options.harness && connectedAgents.contains(.claudeCode) && agentExecutable != nil && agentSignedIn != false
    }

    /// Checks, once, whether the agent is signed in, so the step can say so before anything is sent.
    func checkAgentSignIn() {
        guard agentSignedIn == nil, !options.harness, let executable = agentExecutable else { return }
        Task { @MainActor [weak self] in
            let signedIn = await AgentDetector.signedIn(.claudeCode, at: executable)
            self?.animate(OT.Motion.content) { self?.agentSignedIn = signedIn }
        }
    }

    var agentName: String { sendsToRealAgent ? "Claude Code" : (connectedAgents.first?.name ?? "Fovea") }

    /// What the agent is handed: the words, then what was pointed at (the pictures as files it can
    /// open, each said where it's from), and where it may work.
    func prompt(for request: PracticeRequest) -> String {
        let folder = practice.folder.path
        var lines = [request.words, "", "What I pointed at, in order:"]
        for (index, referent) in request.referents.enumerated() {
            let n = index + 1
            let path = referent.path?.path ?? ""
            switch referent.kind {
            case .wholeScreen:
                lines.append("\(n). A picture of my whole screen: \"\(path)\". Maya's request is in the team chat; this week's analytics are in the browser.")
            case .region:
                switch referent.tab {
                case .analytics: lines.append("\(n). A picture from the Analytics tab: \"\(path)\". This week's signups, activation and churn.")
                case .github: lines.append("\(n). A picture from the GitHub tab: \"\(path)\". The pull requests merged this week.")
                default: lines.append("\(n). A picture of part of my screen: \"\(path)\".")
                }
            case .passage(let i):
                lines.append("\(n). These words from the trail report: \"\(paragraphTexts[i] ?? PracticePage.paragraphs[min(i, 2)])\"")
            case .file(let file):
                lines.append("\(n). The file \"\(practice.url(file.name).path)\"")
            }
        }
        lines.append("")
        switch request.step {
        case .weeklyUpdate:
            // Oct 18, Ryan: two parts taken, so two parts written.
            lines += ["Maya asked in the team chat for this week's update: signups and what shipped."]
            lines += ["Look at the pictures. Write the update to \"\(practice.url(PracticeFiles.update).path)\": a title, then two short parts (Growth, Shipped), a line or two each, with the numbers from the pictures."]
        default:
            lines += ["Keep the packing list as it is laid out: a title, then one \"- item\" per line."]
        }
        // Oct 18, Ryan: the agent answers, and writes, in the person's primary language.
        if let language = Self.answerLanguage { lines += ["Write the file and your reply in \(language)."] }
        lines += ["This is someone's first try of Fovea, which hands you what they point at and what they say.",
                  "Work only in \"\(folder)\". When you're done, reply in two or three short sentences: what you did, and anything worth checking."]
        return lines.joined(separator: "\n")
    }

    /// The language the agent's answer should be in, when it isn't English (Oct 18, Ryan).
    static var answerLanguage: String? { FoveaLocale.shared.language == .chinese ? "Simplified Chinese" : nil }

    /// Sends a request: to Claude Code for real, or to the practice agent.
    func dispatch(_ request: PracticeRequest, session id: UUID, turn: Int) {
        agentNote = nil
        agentActivity = L("Starting")
        if sendsToRealAgent, let executable = agentExecutable {
            let text = turn == 0 ? prompt(for: request)
                : "\(request.words) Keep the same layout, with a heading for each group. Reply in a sentence or two."
                    + (Self.answerLanguage.map { " Write it in \($0)." } ?? "")
            runner.run(executable: executable, prompt: text, folder: practice.folder,
                       resume: turn == 0 ? nil : agentSession) { [weak self] event in
                self?.agentEvent(event, session: id, turn: turn, task: request.step)
            }
        } else {
            practiceAgent(session: id, turn: turn, task: request.step)
        }
    }

    func agentEvent(_ event: AgentRunner.Event, session id: UUID, turn: Int, task: Step) {
        switch event {
        case .activity(let line):
            animate(OT.Motion.content) { agentActivity = line }
            if let islandID = sessions.first(where: { $0.id == id })?.islandID { host?.sessionActivity(islandID, line) }
        case .done(let reply, let session):
            // Signed out, the tool still "answers": with a sign-in line. That's a failure here.
            if reply.localizedCaseInsensitiveContains("not logged in") || reply.contains("/login") {
                agentSignedIn = false
                agentNote = L("Claude Code isn't signed in on this Mac, so the practice agent answered. Run claude in Terminal once to sign in.")
                practiceAgent(session: id, turn: turn, task: task)
                return
            }
            agentSession = session ?? agentSession
            answered(session: id, turn: turn, task: task, reply: Self.trimmed(reply))
        case .failed(let why):
            agentNote = L("Claude Code didn't finish (\(why)) The practice agent answered instead.")
            practiceAgent(session: id, turn: turn, task: task)
        }
    }

    /// The practice agent: the same files, the same edits, made here.
    func practiceAgent(session id: UUID, turn: Int, task: Step) {
        let steps: [String]
        switch task {
        case .weeklyUpdate:
            // Oct 18, Ryan: the agent's lines in the primary language.
            steps = [L("Looking at \("part-1.png")"), L("Looking at \("part-2.png")"), L("Writing \(PracticeFiles.update)")]
        case .followUp:
            steps = [L("Looking at \(PracticeFiles.list)"), L("Editing \(PracticeFiles.list)")]
        default:
            steps = [L("Reading your words"), L("Looking at \(PracticeFiles.list)"), L("Editing \(PracticeFiles.list)")]
        }
        let wait = Self.agentWait + id.uuidString
        for (index, line) in steps.enumerated() {
            after(OT.Send.practiceBeat * Double(index), "\(wait):\(index)") { [weak self] in
                self?.animate(OT.Motion.content) { self?.agentActivity = line }
                if let islandID = self?.sessions.first(where: { $0.id == id })?.islandID { self?.host?.sessionActivity(islandID, line) }
            }
        }
        after(OT.Send.practiceBeat * Double(steps.count), "\(wait):done") { [weak self] in
            guard let self else { return }
            switch task {
            case .weeklyUpdate:
                self.practice.write(PracticeFiles.update, OT.Send.practiceUpdate)
                self.answered(session: id, turn: turn, task: task, reply: OT.Send.practiceUpdateReply)
            case .followUp:
                self.practice.write(PracticeFiles.list, OT.Send.practiceSorted)
                self.answered(session: id, turn: turn, task: task, reply: OT.Send.practiceSortedReply)
            default:
                self.practice.write(PracticeFiles.list, PracticeFiles.listStart + OT.Send.practiceAdded)
                self.answered(session: id, turn: turn, task: task, reply: OT.Send.practiceReply)
            }
        }
    }

    /// The backup when the agent is slow: stop it and let the practice agent answer.
    func usePracticeAnswer() {
        runner.cancel()
        guard let index = sessions.lastIndex(where: { $0.running }) else { return }
        agentNote = L("The practice agent answered this one.")
        let session = sessions[index]
        let task = session.turns.count > 1 ? Step.followUp : session.task
        practiceAgent(session: session.id, turn: session.turns.count - 1, task: task)
    }

    /// The answer is back: in the session, on the page or in the file, and the step hears it.
    func answered(session id: UUID, turn: Int, task: Step, reply: String) {
        guard let index = sessions.firstIndex(where: { $0.id == id }), sessions[index].turns.indices.contains(turn) else { return }
        sessions[index].turns[turn].answer = reply
        agentActivity = ""
        let changed = task == .weeklyUpdate ? [PracticeFiles.update] : [PracticeFiles.list]
        if let islandID = sessions[index].islandID {
            host?.sessionAnswered(islandID, reply, files: changed.filter { practice.exists($0) })
        }
        answered.insert(task)
        sound.cue(.allow)
        switch task {
        case .weeklyUpdate:
            // The update is on the desktop now, and opens, as Quick Look would.
            animate(OT.Motion.calm) { updateWritten = practice.exists(PracticeFiles.update) || updateWritten }
            if practice.exists(PracticeFiles.update) {
                editedFiles.insert(PracticeFiles.update)
                showPreview(PracticeFiles.update)
            }
            // As in real use (Oct 9, evening): a slow answer waits on the board, Done; a quick one
            // opens by itself. Nothing is opened for the person.
            if step == .hover {
                if !flow.done.contains(.hoverNotch) { say(L("Done. Move your pointer to the notch to see it."), hold: false) }
                beat(.answer)
            }
        case .followUp:
            // The session is open where it was asked; the answer comes into it.
            editedFiles.insert(PracticeFiles.list)
            showPreview(PracticeFiles.list)
            if step == .followUp { beat(.followAnswer) }
        default:
            editedFiles.insert(PracticeFiles.list)
            showPreview(PracticeFiles.list)
            if step == .packList { beat(.answer) }
        }
    }

    /// A tab's page has loaded (or reloaded): its picture and where its parts are.
    func pageLoaded(_ tab: PracticeTab, _ layout: PageLayout, _ image: NSImage?) {
        pageLayouts[tab] = layout
        if let image { pageImages[tab] = image }
        if tab == currentTab { placePage() }
    }

    /// Where the page sits on the screen: under the browser's toolbar and its tabs.
    var pageOrigin: CGPoint {
        CGPoint(x: OT.Layout.practiceFrame.minX, y: OT.Layout.practiceFrame.minY + OT.Layout.practiceToolbar + OT.Layout.tabBar + 1)
    }

    /// The showing tab's parts, from page points to display points.
    func placePage() {
        let origin = pageOrigin
        pageFrame = CGRect(origin: origin, size: OT.Site.size)
        let layout = pageLayouts[currentTab] ?? PageLayout()
        func place(_ r: CGRect) -> CGRect { r.offsetBy(dx: origin.x, dy: origin.y) }
        var frames: [Int: CGRect] = [:], lines: [Int: [CGRect]] = [:], texts: [Int: String] = [:]
        for (i, paragraph) in layout.paragraphs.enumerated() {
            frames[i] = place(paragraph.rect)
            lines[i] = paragraph.lines.map(place)
            texts[i] = paragraph.text
        }
        paragraphFrames = frames
        paragraphLines = lines
        paragraphTexts = texts
        partFrames = layout.parts.mapValues(place)
    }

    func showPreview(_ name: String) {
        previewText = practice.text(name) ?? ""
        animate(OT.Motion.calm) { previewFile = name }
    }

    func hidePreview() {
        animate(OT.Motion.calm) { previewFile = nil }
    }

    /// The reply as the agent wrote it (Oct 9, evening: the whole of it, in the session), only
    /// not endless.
    static func trimmed(_ reply: String) -> String {
        let text = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.count > 900 ? String(text.prefix(897)) + "…" : text
    }

    // MARK: Dictation (Oct 9): two windows, your own words

    func land(_ words: String, in target: DictationWindow) {
        // Oct 17, Ryan: what was taken while talking lands after the words, in the same window.
        let taken = dictationTaken
        dictationTaken = []
        animate(OT.Motion.content) {
            switch target {
            case .feedback:
                feedbackText = feedbackText.isEmpty ? words : feedbackText + " " + words
                feedbackTaken += taken
            case .messages:
                // Into the box, after what's there (Oct 18, Ryan: the person's to change).
                replyText = replyText.isEmpty ? words : replyText + " " + words
                replyTaken += taken
            }
        }
        flow.add(PracticeRecord(kind: .dictation, words: words, theme: target == .feedback ? L("Feedback on the first run") : L("Moving the call"),
                                secondsBeforeEnd: target == .feedback ? 90 : 60))
        dictationTarget = nil
        heardSoFar = ""
        let owed = flow.waitingFor
        // In the feedback, landed while still owing what's taken, it's missed (said, tried again).
        if target == .feedback, flow.done.contains(.feedbackKey), flow.remaining.contains(where: { $0.contains(.feedbackLanded) }) {
            beat(.feedbackLanded)
        }
        if target == .messages, owed?.contains(.replyLanded) == true { beat(.replyLanded) }
    }

    /// Something taken while dictating (Oct 17, Ryan): a picture of it, drawn from Fovea's own
    /// windows as the island's own picture is without Screen Recording, to land after the words.
    /// Taken into the feedback, it's the beat the step waits for.
    func takenWhileDictating(_ kind: IslandEvent.TakenKind, rect: CGRect) {
        let shot = kind == .wholeScreen ? ScreenCapture.whole(model: self, name: nil)
                                        : ScreenCapture.region(rect, model: self, name: nil)
        var referent = TakenReferent(kind: kind == .wholeScreen ? .wholeScreen : .region(rect))
        referent.image = shot?.image
        dictationTaken.append(referent)
        sound.cue(.capture)
        if (dictationTarget ?? pointerOver) == .feedback { beat(.feedbackTaken) }
    }

    /// Light clean-up, as Voiceflow does: no ums, a capital, a full stop.
    static func cleaned(_ text: String) -> String {
        var words = text.split(separator: " ").map(String.init)
        words.removeAll { ["um", "uh", "erm", "um,", "uh,"].contains($0.lowercased()) }
        var out = words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = out.first else { return out }
        out = first.uppercased() + out.dropFirst()
        if let last = out.last, !".?!…".contains(last) { out += "." }
        return out
    }

    /// Send: the feedback is kept on this Mac, and only now (the shipping app would post it to
    /// Fovea). Nothing goes before the click.
    func sendFeedback() {
        let text = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !feedbackSent else { return }
        // What was taken with it is said in the entry (the shipping app would post the pictures).
        let pictures = feedbackTaken.count
        let entry = pictures == 0 ? text : text + "\n[\(pictures) picture\(pictures == 1 ? "" : "s") of the screen]"
        if !options.harness { FeedbackStore.append(entry) }
        sound.cue(.allow)
        animate(OT.Motion.content) { feedbackSent = true }
    }

    // MARK: Bringing your words (Oct 9)

    /// A file dropped or chosen: its words, to look over before they're added.
    func importFile(_ url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        guard let words = DictionaryImport.parse(data, filename: url.lastPathComponent) else {
            animate(OT.Motion.content) { importMessage = L("Fovea reads .csv, .txt, .json and .plist files.") }
            return
        }
        offer(words, from: url.lastPathComponent)
    }

    /// Connect: the words straight from the app's own store on this Mac (Wispr Flow), read
    /// now and not before. The smoke run and the snapshots read a stand-in, never yours.
    func connect(_ app: DictationApp) {
        let rows: [(word: String, replacement: String?)]?
        if options.harness {
            rows = OT.Dictation.sampleRows
        } else {
            rows = DictationAppReader.read(app)
        }
        guard let rows else {
            animate(OT.Motion.content) { importMessage = Copy.importCantRead }
            return
        }
        offer(DictionaryImport.rows(rows), from: app.name)
    }

    /// Words pasted from another app (most have no export).
    func importPasted(_ text: String) {
        offer(DictionaryImport.parse(pasted: text), from: L("what you pasted"))
    }

    private func offer(_ words: [ImportedWord], from source: String) {
        animate(OT.Motion.content) {
            let known = Set(importCandidates.map { $0.word.lowercased() })
            let fresh = words.filter { !known.contains($0.word.lowercased()) }
            importCandidates += fresh
            importChosen.formUnion(fresh.map(\.word))
            importMessage = words.isEmpty ? Copy.importNone : L("\(words.count) from \(source)")
        }
        sound.cue(.tick)
    }

    func toggleImport(_ word: String) {
        if importChosen.contains(word) { importChosen.remove(word) } else { importChosen.insert(word) }
    }

    /// Add: the chosen words go to Fovea's dictionary (Home shows them), and on to the end.
    func importChosenWords() {
        let chosen = importCandidates.filter { importChosen.contains($0.word) }
        guard !chosen.isEmpty else { return }
        // Come back to with Back (Oct 15 review, OB-01.7), the words already added aren't added twice.
        let added = Set(importedWords.map { $0.word.lowercased() })
        let fresh = chosen.filter { !added.contains($0.word.lowercased()) }
        importedWords += fresh
        flow.importWords(fresh.count)
        sound.cue(.allow)
        say(chosen.count == 1 ? L("1 word added.") : L("\(chosen.count) words added."), hold: false)
        moveOn(flow.advance())
    }

    // MARK: The end

    /// The practice files go at the end of the run, from the desktop and from disk.
    func clearPracticeFiles() {
        hidePreview()
        animate(OT.Motion.slow) { filesCleared = true }
        if !options.harness { practice.remove() }
    }
}

/// The feedback, kept on this Mac when Send is clicked: one entry after another, dated.
enum FeedbackStore {
    static var file: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Fovea Onboarding", isDirectory: true).appendingPathComponent("feedback.txt")
    }

    static func append(_ text: String) {
        let folder = file.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date())
        let entry = "--- \(stamp)\n\(text)\n\n"
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile()
            handle.write(Data(entry.utf8))
            try? handle.close()
        } else {
            try? entry.write(to: file, atomically: true, encoding: .utf8)
        }
    }
}

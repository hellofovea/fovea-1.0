import SwiftUI
import AppKit
import OnboardingCore

// The whole first run, played by itself (`--play`, or Play it all in the panel): a pointer moves to
// what a person would click and drags what they'd drag, the keys light as they'd be pressed, and
// every step waits long enough to read. It calls the same model methods the keys and the clicks
// call, so what it shows is what the run does.

/// A control the play clicks, found by where its view says it is.
enum PlayTarget: Hashable {
    case guideButton
    case accent(AccentName)
    case aura(AuraPalette)
    case languageMore
    case tile
    case toggle
    case alertPrimary
    case sessionRow
    case drift
    case skip
    case feedbackSend
    case sendArrow
    case agentWish
    case connectApp
    case eyeTracking
}

extension View {
    /// Reports this control's frame on the screen, in display points, for the play's pointer.
    func playTarget(_ target: PlayTarget?, _ model: OnboardingModel) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .named(ScreenSpace.name)) } action: { frame in
            if let target { model.targets[target] = frame }
            if let target, PlayDebug.on { print("target \(target) \(frame)"); fflush(stdout) }
        }
    }
}

enum PlayDebug {
    static let on = ProcessInfo.processInfo.environment["ONB_DEBUG"] == "1"
}

extension OnboardingModel {
    /// A fresh first run: nothing allowed or signed in, nothing made yet, Home put away, the
    /// practice files and the blog new. Started at a later step, the ones before it count as done
    /// (the permissions allowed, the agents connected, sign-in done).
    func restart(at step: Step = .hello) {
        home?.window.orderOut(nil)
        home = nil
        runner.cancel()
        cancelWaits()
        var fresh = Flow(start: .hello)
        fresh.found(flow.agents)
        fresh.language = flow.language
        if step != .hello { fresh.jump(to: step) }
        flow = fresh
        inList = []
        switchedOn = []
        finished = false
        homeOpened = false
        filesCleared = false
        editedFiles = []
        previewFile = nil
        sessions = []
        openSessionID = nil
        answered = []
        agentSession = nil
        agentNote = nil
        agentActivity = ""
        feedbackText = ""
        replyText = ""
        feedbackSent = false
        updateWritten = false
        eyeTrackingAsked = false
        importCandidates = []
        importChosen = []
        importMessage = nil
        importedWords = []
        languageMoreOpen = false
        micPhase = .waiting
        practice.create()
        for site in sites.values { site.reload() }
        if !options.harness { sound.startAmbient() }
        enter(step)
    }

    // MARK: Bookmarks (Oct 8): any stage, to compare and to prototype from

    static func firstStep(of stage: Stage) -> Step {
        Step.allCases.first { $0.stage == stage } ?? .hello
    }

    /// Goes to a stage as things are now, to compare the designs there.
    func goTo(_ stage: Stage) {
        stopPlaying()
        jump(to: Self.firstStep(of: stage))
    }

    /// A fresh run from a stage, as if the ones before it were done.
    func startFrom(_ stage: Stage) {
        stopPlaying()
        restart(at: Self.firstStep(of: stage))
    }

    /// The step before or after this one, as things are.
    func stepBy(_ offset: Int) {
        let all = Step.allCases
        guard let i = all.firstIndex(of: step), all.indices.contains(i + offset) else { return }
        stopPlaying()
        jump(to: all[i + offset])
    }

    /// Plays the run by itself, fresh, from a stage (the start, unless one is given).
    func play(from stage: Stage = .arrive) {
        stopPlaying()
        restart(at: Self.firstStep(of: stage))
        playing = true
        let player = OnboardingPlayer(model: self, from: stage)
        playTask = Task { await player.run() }
    }

    func stopPlaying() {
        guard playing || playTask != nil else { return }
        playTask?.cancel()
        playTask = nil
        playing = false
        animate(OT.Motion.calm) {
            ghost = nil
            keysDown = []
        }
    }
}

@MainActor
final class OnboardingPlayer {
    private let m: OnboardingModel
    /// The stage the play starts at.
    private let from: Stage
    /// Where the pointer is, for when it has to appear again.
    private var at: CGPoint

    init(model: OnboardingModel, from: Stage = .arrive) {
        m = model
        self.from = from
        at = CGPoint(x: OT.Display.size.width * OT.Play.start.x, y: OT.Display.size.height * OT.Play.start.y)
    }

    /// Whether the play covers a stage: the one it started at, and every one after.
    private func plays(_ stage: Stage) -> Bool { stage.rawValue >= from.rawValue }

    func run() async {
        // A presentation: not napped in the background, and the display stays awake for it.
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleDisplaySleepDisabled],
                                                             reason: "Playing the first run")
        defer { ProcessInfo.processInfo.endActivity(activity) }
        do {
            try await playAll()
            note("done")
        } catch {
            note("stopped")
            return // stopPlaying() has put the pointer away
        }
        m.playing = false
        m.playTask = nil
        m.animate(OT.Motion.calm) {
            m.ghost = nil
            m.keysDown = []
        }
    }

    // MARK: The run

    private func playAll() async throws {
        try await until("the page", timeout: 6) { m.pageReady }
        try await pause(1.2)

        if plays(.arrive) {
        // Hello, then make it yours: an accent, a light tried, a light kept, live at the notch.
        note("hello")
        try await read()
        try await click(.guideButton) { m.continueTapped() }
        note("make it yours")
        try await pause(OT.Play.pageIn)
        try await read()
        try await click(.accent(OT.Play.accent)) { m.setAccent(OT.Play.accent) }
        try await pause(0.8)
        try await click(.aura(OT.Play.auraTried)) { m.setAura(OT.Play.auraTried) }
        try await pause(OT.Play.look)
        try await click(.aura(OT.Play.aura)) { m.setAura(OT.Play.aura) }
        try await pause(1.2)
        if let dial = m.targets[.drift] {
            // Drift is a dial: drag it toward lively.
            let from = CGPoint(x: dial.minX + 40 + dial.width * 0.25, y: dial.midY)
            let to = CGPoint(x: dial.minX + 40 + dial.width * 0.55, y: dial.midY)
            try await drag(from: from, to: to, seconds: 0.8) { point in
                m.setAuraDrift(0.5 + 0.25 * Double(min(1, max(0, (point.x - from.x) / max(1, to.x - from.x)))))
            }
            m.setAuraDrift(0.75)
        }
        try await pause(OT.Play.look)
        try await click(.guideButton) { m.continueTapped() }
        }

        if plays(.turnOn) {
        // Turn things on: Fovea dragged into both lists, then the microphone hears the line.
        note("permissions")
        try await until("System Settings", timeout: 6) { m.settingsPane == .accessibility }
        try await pause(OT.Play.watchHint)
        try await dragTile()
        try await until("the second list") { m.settingsPane == .screenRecording && !m.inList.contains(.screenRecording) }
        try await pause(1.4)
        try await dragTile()
        try await until("the reopen question") { m.alert == .reopen }
        try await pause(1.4)
        try await click(.alertPrimary) { m.alertAnswered(true) }
        try await until("the microphone step", timeout: 15) { m.step == .microphone }

        note("microphone")
        try await read()
        try await click(.guideButton) { m.continueTapped() }
        try await until("macOS's question") { m.alert == .microphone }
        try await pause(1.2)
        try await click(.alertPrimary) { m.alertAnswered(true) }
        // The mic test: it has to hear the line. The play says it.
        try await until("the mic test") { m.micPhase == .listening || m.micPhase == .unavailable || m.micPhase == .heard }
        try await pause(0.8)
        let wobble: [Double] = [0.35, 0.6, 0.72, 0.5, 0.66, 0.8, 0.58, 0.7, 0.45, 0.62]
        var tick = 0
        while m.micPhase != .heard, tick < 60 {
            m.heardLevel(wobble[tick % wobble.count])
            tick += 1
            try await Task.sleep(for: .seconds(0.06 * m.pace))
        }
        try await until("the agents", timeout: 15) { m.step == .agents }
        }

        if plays(.agents) {
        // Your agents: one asked for next, then Connect.
        note("agents")
        try await until("the agents", timeout: 6) { m.step == .agents }
        try await pause(OT.Play.pageIn)
        try await read()
        try await click(.agentWish) { m.toggleWish(Agent.comingNext[0]) }
        try await pause(0.8)
        try await click(.guideButton) { m.continueTapped() }
        try await until("the weekly update", timeout: 15) { m.step == .weeklyUpdate }
        }

        if plays(.pointAndSay) {
        // Point and send: the weekly update, gathered from the chat and three tabs.
        note("the weekly update: the whole screen, then a part from two tabs")
        try await until("the weekly update", timeout: 6) { m.step == .weeklyUpdate }
        try await read()
        try await press(["fn", "⌃"]) { m.requestKey() }
        try await pause(1.4)
        // ⌘ twice: the whole screen (Maya's ask and the chart).
        try await press(["⌘"], hold: OT.Play.tap) {
            m.commandDown()
            m.commandUp(tap: true)
        }
        try await press(["⌘"], hold: OT.Play.tap) {
            m.commandDown()
            m.commandUp(tap: true)
            m.commandDouble()
        }
        try await pause(1.6)
        for (tab, part) in [(PracticeTab.github, "prs"), (.support, "tickets")] {
            // The tab, then ⌘ once and a drag over its part.
            if let frame = m.tabFrames[tab] {
                try await click(at: CGPoint(x: frame.midX, y: frame.midY)) { m.selectTab(tab) }
            } else {
                m.selectTab(tab)
            }
            try await pause(1.0)
            try await press(["⌘"]) {
                m.commandDown()
                m.commandUp(tap: true)
            }
            let r = m.partFrames[part] ?? m.part(part, in: tab)
            let a = CGPoint(x: r.minX - 6, y: r.minY - 6)
            let b = CGPoint(x: r.maxX + 6, y: r.maxY + 6)
            try await drag(from: a, to: b, seconds: 1.0) { m.dragChanged(from: a, to: $0) }
            m.dragEnded(from: a, to: b)
            try await pause(1.0)
        }
        try await sayAndFinish()
        note("send")
        try await press(["return"]) { _ = m.returnKey() }
        try await until("watch it work") { m.step == .hover }

        note("the board, from the notch, while it works")
        try await read()
        let notch = CGPoint(x: OT.Display.size.width / 2, y: OT.Display.notchHeight / 2 + 2)
        try await move(to: notch, seconds: 0.9)
        m.pointerMoved(notch)
        try await until("the board") { m.island == .board || m.island == .session }
        try await until("the update", timeout: m.sendsToRealAgent ? OT.Send.timeout : 20) { m.answered.contains(.weeklyUpdate) }
        try await pause(OT.Play.look)
        let away = CGPoint(x: OT.Display.size.width * 0.4, y: OT.Display.size.height * 0.45)
        try await move(to: away, seconds: 0.8)
        m.pointerMoved(away)
        try await pause(OT.Play.look)
        try await until("the hover step's end") { m.flow.isComplete }
        try await click(.guideButton) { m.continueTapped() }

        note("pack for the snow: words, then a file")
        try await read()
        try await press(["fn", "⌃"]) { m.requestKey() }
        try await pause(1.2)
        // Held while dragging across the line about the snow.
        let lines = m.paragraphLines[OT.Practice.snowParagraph] ?? []
        if let first = lines.first, let last = lines.last {
            let h0 = CGPoint(x: first.minX + 2, y: first.midY)
            let h1 = CGPoint(x: last.maxX - 4, y: last.midY)
            try await move(to: h0)
            hold(["⌥"])
            m.optionDown()
            try await pause(OT.Play.keyHold)
            try await drag(from: h0, to: h1, seconds: 1.4) { m.dragChanged(from: h0, to: $0) }
            m.dragEnded(from: h0, to: h1)
            m.optionUp(tap: false)
            hold([])
        }
        try await pause(1.2)
        if let list = m.fileFrames[PracticeFiles.list] {
            try await press(["⌥"]) {
                m.optionDown()
                m.optionUp(tap: true)
            }
            let center = CGPoint(x: list.midX, y: list.midY)
            try await click(at: center) { m.dragEnded(from: center, to: center) }
        }
        try await sayAndFinish()
        // The arrow this time: a click sends as return does.
        try await click(.sendArrow) { m.send() }
        try await until("the list's answer", timeout: m.sendsToRealAgent ? OT.Send.timeout : 20) { m.flow.isComplete }
        try await pause(OT.Play.look + 0.6)
        try await click(.guideButton) { m.continueTapped() }

        note("a follow-up")
        try await read()
        try await press(["fn"]) { m.dictationKey() }
        try await pause(OT.Play.speak)
        try await press(["fn"]) { m.dictationKey() }
        try await until("the second answer", timeout: m.sendsToRealAgent ? OT.Send.timeout : 15) { m.flow.isComplete }
        try await pause(OT.Play.look + 0.6)
        try await click(.guideButton) { m.continueTapped() }
        }

        if plays(.dictation) {
        // Dictation, tried rather than skipped: the feedback window, then Messages.
        note("dictation")
        try await until("dictation's start", timeout: 6) { m.step == .dictationIntro }
        try await pause(OT.Play.pageIn)
        try await read()
        try await click(.guideButton) { m.continueTapped() }
        try await until("the two windows") { m.step == .dictation }
        try await read()
        for (window, frame) in [(DictationWindow.feedback, OT.Layout.feedbackFrame), (.messages, OT.Layout.messagesFrame)] {
            let inside = CGPoint(x: frame.midX, y: frame.minY + frame.height * 0.4)
            try await move(to: inside, seconds: 0.9)
            m.pointerMoved(inside)
            try await pause(0.6)
            try await press(["fn"]) { m.dictationKey() }
            try await pause(OT.Play.speak + 0.8)
            try await press(["fn"]) { m.dictationKey() }
            try await until("the words in \(window)") { window == .feedback ? !m.feedbackText.isEmpty : !m.replyText.isEmpty }
            try await pause(OT.Play.look)
        }
        try await click(.feedbackSend) { m.sendFeedback() }
        try await pause(OT.Play.look)
        try await click(.guideButton) { m.continueTapped() }
        }

        // Bring your words: passed by, this time. Then You're set, and Home.
        note("your words")
        try await until("the dictionary", timeout: 8) { m.step == .dictionary }
        try await pause(OT.Play.pageIn)
        try await read()
        try await click(.skip) { m.skipTapped() }
        note("home")
        try await until("Home") { m.step == .home }
        try await pause(OT.Play.pageIn)
        try await read(min: 2.5)
        try await click(.eyeTracking) { m.askEyeTracking() }
        try await pause(1.2)
        try await click(.guideButton) { m.continueTapped() }
        try await pause(2)
    }

    /// Saying the line, then fn ⌃: written up, and the review card to read.
    private func sayAndFinish() async throws {
        try await pause(OT.Play.speak)
        try await press(["fn", "⌃"]) { m.requestKey() }
        try await until("the review card") { m.island == .review }
        try await pause(OT.Play.look)
    }

    /// The line from the notch into System Settings' list.
    private func dragTile() async throws {
        try await until("the line to drag", timeout: 4) { m.targets[.tile] != nil && m.settingsListFrame != .zero }
        let list = m.settingsListFrame
        let to = CGPoint(x: list.midX, y: list.maxY - OT.Layout.dropZoneHeight / 2 - 6)
        if let tile = m.targets[.tile] {
            m.dragTried = true
            try await drag(from: CGPoint(x: tile.midX, y: tile.midY), to: to, seconds: 1.2) { m.tileDrag = $0 }
        }
        m.tileDropped(at: to)
        try await pause(0.6)
    }

    // MARK: Time

    /// Seconds, at the run's pace (the panel's Pace, or --pace).
    private func pause(_ seconds: Double) async throws {
        try await Task.sleep(for: .seconds(seconds * m.pace))
    }

    /// Long enough to read the guide card.
    private func read(min: Double = OT.Play.readMin) async throws {
        let words = (m.copy.title + " " + m.copy.body).split(separator: " ").count
        try await pause(Swift.max(min, Swift.min(OT.Play.readMax, Double(words) * OT.Play.readPerWord)))
    }

    /// Waits for the run to get somewhere; past the timeout it says so and goes on.
    private func until(_ what: String, timeout: Double = 12, _ condition: () -> Bool) async throws {
        let limit = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < limit else {
                note("waited too long for \(what)")
                return
            }
            try await Task.sleep(for: .milliseconds(80))
        }
    }

    private func note(_ what: String) {
        print("play: \(what)")
        fflush(stdout)
    }

    // MARK: The pointer

    private func appear() {
        if let ghost = m.ghost {
            at = ghost.position
        } else {
            m.animate(OT.Motion.calm) { m.ghost = Ghost(position: at) }
        }
    }

    private func move(to point: CGPoint, seconds: Double = OT.Play.move) async throws {
        appear()
        m.animate(.easeInOut(duration: seconds * m.pace)) { m.ghost?.position = point }
        at = point
        try await pause(seconds + 0.08)
    }

    private func tap() async throws {
        m.animate(nil) { m.ghost?.pressing = true }
        try await pause(OT.Play.press)
        m.animate(nil) { m.ghost?.pressing = false }
    }

    /// To a control and a click on it; the click does what the control does.
    private func click(_ target: PlayTarget, _ action: () -> Void) async throws {
        try await until("\(target)", timeout: 4) { m.targets[target] != nil }
        if let frame = m.targets[target] {
            try await move(to: CGPoint(x: frame.midX, y: frame.midY))
            try await tap()
        }
        action()
    }

    private func click(at point: CGPoint, _ action: () -> Void) async throws {
        try await move(to: point)
        try await tap()
        action()
    }

    /// Pressed from one point to the other, eased; `step` hears each point on the way.
    private func drag(from a: CGPoint, to b: CGPoint, seconds: Double = OT.Play.drag,
                      step: (CGPoint) -> Void) async throws {
        try await move(to: a)
        m.animate(nil) { m.ghost?.pressing = true }
        let frames = Swift.max(6, Int(seconds * m.pace * OT.Play.dragFrames))
        for i in 1...frames {
            let t = Double(i) / Double(frames)
            let e = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            let p = CGPoint(x: a.x + (b.x - a.x) * e, y: a.y + (b.y - a.y) * e)
            m.ghost?.position = p
            at = p
            step(p)
            try await Task.sleep(for: .seconds(seconds * m.pace / Double(frames)))
        }
        m.animate(nil) { m.ghost?.pressing = false }
    }

    // MARK: The keys

    /// Keys held: lit on the guide card and beside the pointer.
    private func hold(_ labels: [String]) {
        appear()
        m.animate(nil) {
            m.keysDown = Set(labels)
            m.ghost?.keys = labels
        }
    }

    /// Keys pressed and let go; the action is what the press does.
    private func press(_ labels: [String], hold seconds: Double = OT.Play.keyHold, _ action: () -> Void) async throws {
        hold(labels)
        try await pause(seconds)
        action()
        try await pause(OT.Play.keyAfter)
        hold([])
    }
}

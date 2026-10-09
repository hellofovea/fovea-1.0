import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OnboardingCore
import FoveaCore
import CapturesCore

/// What the Island shows. The first run keeps its own state and never borrows the Workbench's.
enum IslandPhase: Equatable {
    case rest
    /// One line under the notch.
    case caption
    /// Make it yours: the Dispatch bar listening, in the chosen aura.
    case auraPreview
    /// The permissions: one line under the notch that is itself the tile to drag (Oct 9).
    case dragCaption
    case voice(VoiceKind)
    case transcribing(VoiceKind)
    /// The request on the review card (Choose chat).
    case review
    case board
    case session
}

enum VoiceKind: Equatable {
    /// fn ⌃: a request for an agent, in the aura.
    case request
    /// fn in an open session: asking more, in the aura too.
    case followUp
    /// fn: dictation, the waveform bar.
    case dictation
}

/// Something taken off the practice screen, in the order taken. Pictures carry the real image Fovea
/// made of the screen, the tab they were taken from, and the file the agent is handed.
struct TakenReferent: Identifiable, Equatable {
    enum Kind: Equatable {
        case region(CGRect)
        case wholeScreen
        case passage(Int)
        case file(DesktopFile)
    }
    let id = UUID()
    let kind: Kind
    var tab: PracticeTab?
    var image: NSImage?
    var path: URL?

    static func == (a: TakenReferent, b: TakenReferent) -> Bool { a.id == b.id && a.kind == b.kind && a.path == b.path }
}

/// A file on the practice desktop.
struct DesktopFile: Identifiable, Equatable, Hashable {
    let name: String
    let type: String
    var id: String { name }

    /// The packing task's files; the weekly update joins once it's written.
    static let all = [
        DesktopFile(name: PracticeFiles.list, type: "txt"),
        DesktopFile(name: PracticeFiles.map, type: "pdf"),
    ]
    static let update = DesktopFile(name: PracticeFiles.update, type: "md")

    static var list: DesktopFile { all.first { $0.name == PracticeFiles.list }! }

    var icon: NSImage {
        if let type = UTType(filenameExtension: self.type) { return NSWorkspace.shared.icon(for: type) }
        return NSWorkspace.shared.icon(for: .data)
    }
}

/// The request as the review card shows it, and as it's sent.
struct PracticeRequest: Equatable {
    var words: String
    var referents: [TakenReferent]
    var step: Step
}

/// One request sent to an agent, and the follow-ups asked in it: a row on the board, a session
/// when opened. The two tasks are two sessions.
struct PracticeSession: Equatable, Identifiable {
    struct Turn: Equatable {
        var ask: String
        var answer: String?
    }
    let id = UUID()
    /// The task that sent it.
    var task: Step
    var title: String
    var agent: String
    var turns: [Turn]
    var running: Bool { turns.last?.answer == nil }
}

/// The windows on the desktop: none until a step uses one (Oct 9, round two: at the start, only
/// the notch and the bar), then the browser and the team chat for the tasks, or dictation's two.
enum PracticeScreen: Equatable {
    case empty, page, dictation

    static func `for`(_ step: Step) -> PracticeScreen {
        switch step {
        case .weeklyUpdate, .hover, .packList, .followUp: .page
        case .dictation: .dictation
        default: .empty
        }
    }
}

/// The app in front, named in the menu bar with its menus: the one whose window the step has open.
enum FrontApp: Equatable {
    case finder, systemSettings, safari, fovea

    var name: String {
        switch self {
        case .finder: "Finder"
        case .systemSettings: "System Settings"
        case .safari: "Safari"
        case .fovea: "Fovea"
        }
    }

    var menus: [String] {
        switch self {
        case .finder: ["File", "Edit", "View", "Go", "Window", "Help"]
        case .systemSettings: ["Edit", "View", "Window", "Help"]
        case .safari: ["File", "Edit", "View", "History", "Bookmarks", "Window", "Help"]
        case .fovea: ["File", "Edit", "View", "Window", "Help"]
        }
    }
}

/// Dictation's two windows (Oct 9): the words go to the one under the pointer.
enum DictationWindow: Equatable { case feedback, messages }

enum MockAlert: Equatable { case microphone, reopen }

/// One highlighter mark, in display points: a marker's strokes over words, or a ring round a file.
/// Marks stay on the screen while the request lasts.
struct HighlightMark: Equatable, Identifiable {
    let id = UUID()
    var rects: [CGRect]
    var file = false
}

/// The play's pointer and the keys it presses.
struct Ghost: Equatable {
    var position: CGPoint
    var keys: [String] = []
    var pressing = false
}

@MainActor
@Observable
final class OnboardingModel {
    // MARK: Run

    let options: Options
    /// Every wait is multiplied by this: the smoke run sets it near zero.
    var pace: Double
    var reduceMotion = false
    /// Lines typed out letter by letter (Oct 9); off shows them whole, for comparison.
    var typing = true
    var flow: Flow
    var keys = KeyMap.current
    var stepStarted = Date()
    var skipShown = false

    // MARK: The Island

    var island: IslandPhase = .rest
    var captionText = ""
    /// A word on the board mid-task ("That missed the pull requests."), in place of the instruction
    /// for a moment: the Island keeps the voice bar open meanwhile.
    var hintText: String?
    /// While transcribing: 0…1 along the aura's edge.
    var transcribeProgress: Double = 0

    // MARK: Hello

    /// More… is open: a box to type a language into.
    var languageMoreOpen = false

    // MARK: Practice

    var practiceScreen: PracticeScreen = .empty
    var referents: [TakenReferent] = []
    var screenshotArmed = false
    var highlighterOn = false
    /// A screenshot's drag in progress, in display points.
    var selection: CGRect?
    /// The highlighter's marks, and the strokes being drawn.
    var marks: [HighlightMark] = []
    var markDraft: [CGRect]?
    var flash = false
    var request: PracticeRequest?
    /// Everything sent so far, newest last; the board lists them.
    var sessions: [PracticeSession] = []
    var openSessionID: UUID?
    /// Tasks whose answer has come back: lasting, so a step that starts after the answer still
    /// sees it.
    var answered: Set<Step> = []
    /// The play's pointer.
    var ghost: Ghost?
    /// The keys held, as their labels, for the keyboard.
    var keysDown: Set<String> = []
    /// The team chat beside the browser, for the weekly update.
    var chatShown = true

    // MARK: The browser's tabs (real local pages: PracticeSite.swift)

    var currentTab: PracticeTab = .analytics
    /// Each tab's page as the browser shows it, retaken after every load.
    var pageImages: [PracticeTab: NSImage] = [:]
    var pageLayouts: [PracticeTab: PageLayout] = [:]
    /// Where the showing tab's parts are, in display points.
    var pageFrame: CGRect = .zero
    var paragraphFrames: [Int: CGRect] = [:]
    var paragraphLines: [Int: [CGRect]] = [:]
    var paragraphTexts: [Int: String] = [:]
    var partFrames: [String: CGRect] = [:]
    var fileFrames: [String: CGRect] = [:]
    var tabFrames: [PracticeTab: CGRect] = [:]
    var settingsListFrame: CGRect = .zero

    /// Every tab's page has loaded once.
    var pageReady: Bool { PracticeTab.allCases.allSatisfy { pageLayouts[$0] != nil } }

    // MARK: Permissions, as macOS would show them

    var settingsPane: Permission?
    var inList: Set<Permission> = []
    var switchedOn: Set<Permission> = []
    var alert: MockAlert?
    /// The tile being dragged from the notch toward the list, in display points.
    var tileDrag: CGPoint?
    /// The drag has been tried once: the ghost stops showing how.
    var dragTried = false

    // MARK: Agents

    /// Agents switched on in the agents step (all found, by default).
    var agentsOn: Set<Agent> = []

    // MARK: Dictation (Oct 9: two windows, real words)

    /// The window under the pointer now, and the one the words are going to.
    var pointerOver: DictationWindow?
    var dictationTarget: DictationWindow?
    var feedbackText = ""
    var replyText = ""
    /// Words as they're heard, before they land.
    var heardSoFar = ""
    var feedbackSent = false
    var speechNote: String?
    @ObservationIgnored let speech = SpeechInput()

    // MARK: Bringing your words (Oct 9)

    var importCandidates: [ImportedWord] = []
    var importChosen: Set<String> = []
    var importMessage: String?
    var importedWords: [ImportedWord] = []
    var dictationApps: [DictationApp] = []

    // MARK: The end

    /// The run is over: the practice captures for Home. Set by the App.
    @ObservationIgnored var onFinished: (([CapturesCore.Capture]) -> Void)?
    /// The last card's Done was pressed.
    var finished = false
    /// Home was asked for (the harness never opens a window for it).
    var homeOpened = false
    /// Asked for eye tracking's beta (Oct 9, round two).
    var eyeTrackingAsked = false

    // MARK: The keyboard, the mic test, the real send

    /// The whole keyboard while keys are taught (the panel can hide it).
    var keyboardOn = true
    var micPhase: MicPhase = .waiting
    /// The input's loudness, 0…1, while the mic test listens.
    var micLevel: Double = 0
    /// Seconds of voice heard so far.
    var micVoiced: Double = 0
    @ObservationIgnored let mic = MicMeter()
    @ObservationIgnored var lastMicSample = Date()
    @ObservationIgnored var spaceTalk: Timer?
    /// Send to the agent on this Mac (Claude Code), not the practice agent. Off in the harness.
    var useRealAgent = true
    /// Whether the agent's command-line tool is signed in (`claude auth status`): it decides who
    /// answers, quietly (Oct 9: connected is connected, nothing to sign in to). Nil until checked.
    var agentSignedIn: Bool?
    /// The one line of what the agent is doing (the Island's one line of activity).
    var agentActivity = ""
    var agentSession: String?
    /// Said when the real agent was asked and couldn't answer, and the practice one did.
    var agentNote: String?
    @ObservationIgnored let runner = AgentRunner()
    @ObservationIgnored let practice: PracticeFiles
    @ObservationIgnored var sites: [PracticeTab: PracticeSite] = [:]
    /// Files the agent changed or wrote: marked on the desktop.
    var editedFiles: Set<String> = []
    /// The weekly update is written: it's on the desktop.
    var updateWritten = false
    /// A file shown open on the desktop, as Quick Look would.
    var previewFile: String?
    var previewText = ""
    /// The practice files are gone (the end of the run).
    var filesCleared = false

    // MARK: The play (Play.swift)

    /// The whole run is playing by itself: the real pointer's hover is ignored.
    var playing = false
    var playTask: Task<Void, Never>?
    /// Where the controls the play clicks are, in display points, reported by their views.
    var targets: [PlayTarget: CGRect] = [:]

    let sound: AmbientSound
    private var tasks: [String: Task<Void, Never>] = [:]
    private(set) var monitors: KeyRig?

    init(options: Options) {
        self.options = options
        pace = options.smoke ? 0.02 : (options.pace ?? 1)
        typing = !options.noTyping
        var flow = Flow(start: options.step ?? .hello)
        if let step = options.step { flow.jump(to: step) }
        flow.language = Language.preferred(Locale.preferredLanguages)
        self.flow = flow
        sound = AmbientSound(enabled: !options.harness && !options.mute)
        practice = PracticeFiles(separate: options.harness || options.play)
    }

    var copy: StepCopy { Copy.step(flow.step, keys: keys, agents: connectedAgents) }
    var step: Step { flow.step }
    var personal: Personalization { flow.personal }

    /// The agents that will answer: the ones found and left on.
    var connectedAgents: [Agent] { flow.agents.filter { agentsOn.contains($0) } }

    /// The browser's tabs for this step.
    var openTabs: [PracticeTab] { PracticeTab.open(for: step) }

    /// What's on the desktop now: a file shows from the task that uses it (Oct 9, round two), the
    /// update once the agent has written it, the trip's two for the packing list, and none once
    /// the tasks are done. The update keeps the first place, so nothing moves when the others come.
    var desktopFiles: [DesktopFile] {
        guard step.stage == .pointAndSay else { return [] }
        return (updateWritten ? [.update] : []) + (step == .packList || step == .followUp ? DesktopFile.all : [])
    }

    /// The app in front, for the menu bar.
    var frontApp: FrontApp {
        if settingsPane != nil { return .systemSettings }
        switch practiceScreen {
        case .page: return .safari
        case .dictation: return .fovea
        case .empty: return .finder
        }
    }

    // MARK: Start

    func start() {
        flow.found(AgentDetector.detect())
        agentsOn = Set(flow.agents)
        dictationApps = DictationAppDetector.installed()
        practice.create()
        for tab in PracticeTab.allCases {
            let site = PracticeSite(tab: tab)
            site.onLayout = { [weak self] tab, layout, image in self?.pageLoaded(tab, layout, image) }
            site.load(practice)
            sites[tab] = site
        }
        if options.harness || options.practiceAgent { useRealAgent = false }
        if !options.harness { sound.startAmbient() }
        if !options.harness { startKeys() }
        // No opening moment (Oct 9): the run opens on hello.
        enter(flow.step)
    }

    func startKeys() {
        guard monitors == nil else { return }
        let rig = makeRig()
        rig.start()
        monitors = rig
    }

    /// The key rig, its closures pointed at this model. The smoke run feeds its monitors
    /// synthetic edges without installing any event monitor.
    func makeRig() -> KeyRig {
        let rig = KeyRig()
        rig.onRequest = { [weak self] in self?.requestKey() }
        rig.onDictation = { [weak self] in self?.dictationKey() }
        rig.onCommandDown = { [weak self] in self?.commandDown() }
        rig.onCommandUp = { [weak self] tap in self?.commandUp(tap: tap) }
        rig.onCommandDouble = { [weak self] in self?.commandDouble() }
        rig.onOptionDown = { [weak self] in self?.optionDown() }
        rig.onOptionUp = { [weak self] tap in self?.optionUp(tap: tap) }
        rig.onFlags = { [weak self] down in self?.keysDown = down }
        rig.onReturn = { [weak self] in self?.returnKey() ?? false }
        rig.onEscape = { [weak self] in self?.escapeKey() ?? false }
        rig.onSpace = { [weak self] down in self?.spaceKey(down) ?? false }
        rig.wire()
        return rig
    }

    // MARK: Waiting, at the run's pace

    /// Runs `body` after `seconds` (scaled by the pace), replacing anything waiting under `key`.
    func after(_ seconds: Double, _ key: String, _ body: @escaping @MainActor () -> Void) {
        tasks[key]?.cancel()
        let delay = max(0, seconds * pace)
        tasks[key] = Task { @MainActor [weak self] in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            guard !Task.isCancelled, self != nil else { return }
            body()
        }
    }

    func cancelWait(_ key: String) {
        tasks[key]?.cancel()
        tasks[key] = nil
    }

    /// Cancels what's waiting, but not the agent's own work: an answer on its way outlives the
    /// step that sent it.
    func cancelWaits(except keep: Set<String> = []) {
        for (key, task) in tasks where !keep.contains(key) && !key.hasPrefix(Self.agentWait) { task.cancel() }
        tasks = tasks.filter { keep.contains($0.key) || $0.key.hasPrefix(Self.agentWait) }
    }

    /// Waits named with this survive a step change (the practice agent's lines and its answer).
    static let agentWait = "agent:"

    func animate(_ animation: Animation?, _ body: () -> Void) {
        if options.harness || reduceMotion {
            withAnimation(reduceMotion && !options.harness ? OT.Motion.reduceMotion : nil, body)
        } else {
            withAnimation(animation, body)
        }
    }

    // MARK: Steps

    func continueTapped() {
        switch step {
        case .agents where !flow.isComplete:
            connectAgents()
            return
        case .microphone where micPhase == .waiting && alert == nil:
            askMicrophone()
            return
        case .dictionary:
            importChosenWords()
            return
        case .home:
            finish()
            return
        default:
            break
        }
        guard flow.isComplete else { return }
        sound.cue(.step)
        if let next = flow.advance() { enter(next) }
    }

    /// The way past a step (Oct 8: every step has a backup). Where there's a better backup than
    /// moving on, it's taken: the request put together for you, the practice answer for a slow
    /// agent, the session opened for you.
    func skipTapped() {
        guard step.skip.allowed, skipShown || step.skip == .now else { return }
        switch step {
        case .weeklyUpdate, .packList:
            doItForMe()
            return
        case .hover:
            // As if the notch were hovered; the practice answer stands in if the agent is slow.
            beat(.hoverNotch)
            if answered.contains(.weeklyUpdate) {
                openSession(for: .weeklyUpdate)
            } else {
                usePracticeAnswer()
                showIsland(.board, OT.Motion.open)
            }
            return
        case .agents:
            // No agents: the practice agent answers the tasks.
            useRealAgent = false
            agentsOn = []
        default:
            break
        }
        if let next = flow.skip() { enter(next) }
    }

    func jump(to step: Step) {
        finished = false
        flow.jump(to: step)
        enter(step)
    }

    /// Sets the stage for a step: the Island, the windows, what the practice screen holds.
    func enter(_ step: Step) {
        cancelWaits()
        stopMicTest()
        stepStarted = Date()
        skipShown = step.skip == .now
        if case .after(let seconds) = step.skip {
            after(seconds, "skip") { [weak self] in self?.animate(OT.Motion.calm) { self?.skipShown = true } }
        }
        resetPractice()
        animate(OT.Motion.calm) {
            if step != .permissions { settingsPane = nil }
            alert = nil
            practiceScreen = .for(step)
            chatShown = step == .weeklyUpdate || step == .hover
            // A file opened stays open only for the follow-up on it.
            if step != .followUp { previewFile = nil }
            switch step {
            case .packList, .followUp: currentTab = .trail
            case .weeklyUpdate: currentTab = .analytics
            default: if !openTabs.contains(currentTab) { currentTab = .analytics }
            }
        }
        placePage()
        switch step {
        case .hello:
            say(copy.caption, hold: false)
        case .makeItYours:
            showIsland(.auraPreview, OT.Motion.barOpen)
        case .permissions:
            dragTried = false
            showIsland(.dragCaption, OT.Motion.open)
            captionText = Copy.permissionCaptions[flow.allowed.contains(.accessibility) ? 1 : 0]
            animate(OT.Motion.calm) {
                settingsPane = flow.allowed.contains(.accessibility) ? .screenRecording : .accessibility
            }
        case .microphone:
            micPhase = .waiting
            say(copy.caption, hold: false)
        case .agents:
            say(copy.caption, hold: false)
            checkAgentSignIn()
        case .weeklyUpdate, .packList:
            say(copy.caption, hold: false)
        case .hover:
            // The agent is at work on the update: its row is on the board. Its answer may already
            // be back (a fast agent): that counts.
            say(copy.caption, hold: false)
            if answered.contains(.weeklyUpdate) { beat(.answer) }
        case .followUp:
            if let session = sessions.last(where: { $0.task == .packList }) {
                openSessionID = session.id
                showIsland(.session, OT.Motion.open)
            } else {
                prepareFollowUpSession()
            }
        case .dictationIntro, .dictation, .dictionary, .home:
            if step == .home { clearPracticeFiles() }
            say(copy.caption, hold: false)
        }
    }

    private func resetPractice() {
        hintText = nil
        referents = []
        screenshotArmed = false
        highlighterOn = false
        selection = nil
        marks = []
        markDraft = nil
        transcribeProgress = 0
        if !playing { ghost = nil }
        tileDrag = nil
        request = nil
        if step.stage != .pointAndSay {
            openSessionID = nil
        }
        if step != .dictation {
            dictationTarget = nil
            heardSoFar = ""
            speech.cancel()
        }
    }

    /// A beat the person made: counted, sounded, and the step moved on if it's done.
    func beat(_ beat: Beat) {
        guard flow.record(beat) else {
            if flow.missedBeat != nil { missed() }
            return
        }
        if flow.isComplete { completed() }
    }

    /// A try went wrong (finished before taking what it needs): say so, and start it over.
    private func missed() {
        guard isPracticeTry else { flow.retry(); return }
        say(step == .packList
            ? "Not quite. Take the line and the packing list, then press \(keys.spoken(.request))."
            : "Not quite. Take the screen and the two parts, then press \(keys.spoken(.request)).", hold: true)
        flow.retry()
        referents = []
        marks = []
    }

    /// The step's beats are met. Permissions, the agents and sending the update move on by
    /// themselves; the rest wait for Continue, so the result can be read.
    private func completed() {
        switch step {
        case .permissions, .microphone, .agents:
            sound.cue(.allow)
            after(OT.Timing.autoAdvance, "advance") { [weak self] in
                guard let self else { return }
                if let next = self.flow.advance() { self.enter(next) }
            }
        case .weeklyUpdate:
            // Sent: the agent works while the next step shows where to watch it.
            if let next = flow.advance() { enter(next) }
        default:
            sound.cue(.step)
        }
    }

    /// Done: "You're set" goes, and Home opens (Oct 9: no closing animation). Home stays open to look
    /// around; quit from the menu, as Fovea itself quits only from the menu bar.
    func finish() {
        sound.stopAmbient()
        animate(OT.Motion.slow) { finished = true }
        rest()
        if !flow.agentWishes.isEmpty, !options.harness {
            FeedbackStore.append("Agents wanted next: \(flow.agentWishes.joined(separator: ", "))")
        }
        openHome()
        after(OT.Timing.homeCaption, "homeCaption") { [weak self] in
            self?.say(Copy.homeNotch, hold: false)
            self?.after(OT.Timing.restAfterFinish, "rest") { [weak self] in self?.rest() }
        }
    }

    // MARK: The keyboard (Oct 9: only while keys are taught; a key pressed elsewhere brings nothing)

    var keyboardWanted: Bool { keyboardOn && !finished && step.showsKeyboard }
    var keyboardVisible: Bool { keyboardWanted }

    /// The beat to light keys for: the first owed, in the step's order (the whole screen before
    /// the parts, the words before the file).
    var waitingBeat: Beat? {
        guard let group = flow.waitingFor else { return nil }
        if group.count == 1 { return group.first }
        return Beat.allCases.first { group.contains($0) }
    }

    /// The keys to press now, lit on the keyboard, in turn (Oct 9): fn and ⌃ to start, ⌘ twice for
    /// the whole screen, ⌘ once for each part (once its tab is showing), nothing while you drag or
    /// click a tab, fn ⌃ to finish, return to send.
    var keyboardTargets: Set<String> {
        switch step {
        case .dictationIntro:
            return Set(keys.caps(.dictation))
        default:
            guard let beat = waitingBeat else { return [] }
            if let tab = beat.tab, tab != currentTab { return [] }
            // Armed: what's left is a drag or a click. (The whole screen's first ⌘ arms too, but
            // it takes a second.)
            if beat.tab != nil, screenshotArmed { return [] }
            if beat == .file, highlighterOn { return [] }
            return Set(keys.keys(for: beat))
        }
    }

    /// A badge on a lit key: "×2" on ⌘ while the whole screen is owed (Oct 9).
    var keyboardBadges: [String: String] {
        guard step == .weeklyUpdate, let beat = waitingBeat else { return [:] }
        let presses = keys.presses(for: beat)
        guard presses > 1 else { return [:] }
        return Dictionary(uniqueKeysWithValues: keys.keys(for: beat).map { ($0, "×\(presses)") })
    }

    /// The tab to click now, lit in the browser.
    var tabToClick: PracticeTab? {
        guard requestBarOpen, let tab = waitingBeat?.tab, tab != currentTab else { return nil }
        return tab
    }

    /// What to do now, typed out on the board.
    var instruction: String? {
        if let hintText { return hintText }
        if step == .microphone, micPhase == .unavailable { return Copy.micUnavailable }
        if step == .dictation, flow.isComplete, feedbackSent { return Copy.feedbackSent }
        if step == .dictation, let note = speechNote,
           flow.waitingFor?.contains(.feedbackLanded) == true || flow.waitingFor?.contains(.replyLanded) == true {
            return note
        }
        let armed = (waitingBeat?.tab != nil && screenshotArmed) || (waitingBeat == .file && highlighterOn)
        return Copy.instruction(waitingBeat, step: step, armed: armed, tab: currentTab, keys: keys,
                                agent: connectedAgents.first?.name)
    }

    // MARK: The Island

    func showIsland(_ phase: IslandPhase, _ animation: Animation) {
        animate(animation) { island = phase }
    }

    /// One line in the Island, typed out. Held lines go back to what the step showed once read.
    func say(_ text: String, hold: Bool) {
        animate(OT.Motion.content) { captionText = text }
        if island != .caption { showIsland(.caption, OT.Motion.barOpen) }
        if hold { scheduleCaptionReturn(for: text) }
    }

    /// How long a line stays: long enough to be typed, then read (Oct 9).
    func holdTime(for text: String) -> Double {
        (typing ? Typewriter.duration(of: text) : 0) + OT.Typing.readAfter
    }

    /// A held line goes back to the step's own after a moment.
    private func scheduleCaptionReturn(for text: String) {
        after(holdTime(for: text), "caption") { [weak self] in
            guard let self, self.island == .caption else { return }
            self.animate(OT.Motion.content) { self.captionText = self.copy.caption }
        }
    }

    /// Said on the board while a request is open, so the voice bar stays as it is.
    func hint(_ text: String) {
        animate(OT.Motion.content) { hintText = text }
        after(holdTime(for: text), "hint") { [weak self] in self?.animate(OT.Motion.content) { self?.hintText = nil } }
    }

    func rest() {
        showIsland(.rest, OT.Motion.close)
    }

    // MARK: Make it yours

    func setAccent(_ accent: AccentName) { animate(OT.Motion.calm) { flow.personal.accent = accent }; sound.cue(.tick) }
    func setAura(_ aura: AuraPalette) { animate(OT.Motion.calm) { flow.personal.aura = aura }; sound.cue(.tick) }
    func setAuraHue(_ hue: Double) { flow.personal.auraHue = hue }
    func setAuraDrift(_ drift: Double) { flow.personal.auraDrift = drift }

    /// The accent as a color: Multicolor is the Mac's own accent.
    var accentColor: Color { AccentPalette.color(personal.accent) }

    var auraLook: VoiceGlowLook {
        (GlowChoice(rawValue: personal.aura.rawValue) ?? .colorful).look(hue: personal.auraHue, spread: 120, driftAmount: personal.auraDrift)
    }

    // MARK: Hello

    func chooseLanguage(_ language: Language) {
        animate(OT.Motion.calm) {
            flow.language = language
            languageMoreOpen = false
        }
        sound.cue(.tick)
    }

    func openLanguageMore() {
        animate(OT.Motion.calm) { languageMoreOpen = true }
    }

    func requestLanguage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        flow.languageRequest = trimmed.isEmpty ? nil : trimmed
    }
}

/// The accent's colors: Fovea Captures' `AccentChoice`, Multicolor as the system's own.
enum AccentPalette {
    static func color(_ accent: AccentName) -> Color { Color(nsColor: nsColor(accent)) }

    static func nsColor(_ accent: AccentName) -> NSColor {
        switch accent {
        case .multicolor: .controlAccentColor
        case .blue: .systemBlue
        case .purple: .systemPurple
        case .pink: .systemPink
        case .red: .systemRed
        case .orange: .systemOrange
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .graphite: .systemGray
        }
    }
}

/// Agents on this Mac, by whether their command-line tool exists: a file's presence, nothing read
/// (as FoveaWindowBench's AgentDetector).
enum AgentDetector {
    /// The places a command-line agent lives: the app's PATH, then the usual installs (an app
    /// opened from the Dock may not have the shell's PATH; REAL_MAC.md).
    static var places: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
            + ["/usr/local/bin", "/opt/homebrew/bin", "\(home)/.local/bin", "\(home)/.claude/local",
               "\(home)/.npm-global/bin", "\(home)/bin"]
    }

    static func detect() -> [Agent] {
        Agent.allCases.filter { agent in
            if agent == .cursor, FileManager.default.fileExists(atPath: "/Applications/Cursor.app") { return true }
            return executable(agent) != nil
        }
    }

    /// Asks the agent's own tool whether it's signed in, without spending a request (Claude Code:
    /// `claude auth status --json`). Nil when it can't say.
    static func signedIn(_ agent: Agent, at executable: URL) async -> Bool? {
        guard agent == .claudeCode else { return nil }
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = ["auth", "status", "--json"]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            process.standardInput = FileHandle.nullDevice
            process.terminationHandler = { _ in
                let data = output.fileHandleForReading.readDataToEndOfFile()
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                continuation.resume(returning: json?["loggedIn"] as? Bool)
            }
            do { try process.run() } catch { continuation.resume(returning: nil) }
        }
    }

    /// The agent's command-line tool, if it's installed.
    static func executable(_ agent: Agent) -> URL? {
        places.lazy.map { URL(fileURLWithPath: $0).appendingPathComponent(agent.command) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}

/// Dictation apps on this Mac (Oct 9), by bundle ID or name in /Applications: their presence. Their
/// words are read only when Connect is clicked (DictationAppReader).
enum DictationAppDetector {
    static func installed() -> [DictationApp] {
        DictationApp.allCases.filter { app in
            if app.isSystem { return true }
            if app.bundleIDs.contains(where: { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }) { return true }
            return app.appNames.contains { FileManager.default.fileExists(atPath: "/Applications/\($0)") }
        }
    }

    /// The app's icon, for its Connect button.
    static func icon(_ app: DictationApp) -> NSImage? {
        for id in app.bundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) { return NSWorkspace.shared.icon(forFile: url.path) }
        }
        for name in app.appNames where FileManager.default.fileExists(atPath: "/Applications/\(name)") {
            return NSWorkspace.shared.icon(forFile: "/Applications/\(name)")
        }
        return nil
    }
}

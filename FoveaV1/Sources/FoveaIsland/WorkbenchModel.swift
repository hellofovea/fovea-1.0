import SwiftUI
import AppKit
import FoveaCore
import FoveaKit

/// Command-line options. `--snapshot <dir>` renders the window to PNGs and exits; `--smoke`
/// checks the live window and exits; `--play-demo` plays the screenshot walkthrough once
/// launched; `--record <file.mp4>` plays it into a movie and exits.
struct WorkbenchOptions {
    var snapshotDirectory: URL?
    /// `--only <text>`: just the snapshots whose names contain it.
    var snapshotFilter: String?
    var smoke = false
    var playDemo = false
    var recording: URL?
    /// `--density=compact|spacious`: the open panels' room for this run (not remembered).
    var density: PanelDensity?
    /// `--design=original|native`: the notch's design for this run (not remembered).
    var design: NotchDesign?
    /// `--native-panels=attached|floating`: how Native's panels meet the notch for this run.
    var nativePanels: NativePanels?

    static func parse(_ args: [String] = CommandLine.arguments) -> WorkbenchOptions {
        var options = WorkbenchOptions()
        if let i = args.firstIndex(of: "--snapshot"), args.count > i + 1 {
            options.snapshotDirectory = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        }
        if let i = args.firstIndex(of: "--only"), args.count > i + 1 {
            options.snapshotFilter = args[i + 1]
        }
        options.smoke = args.contains("--smoke")
        options.playDemo = args.contains("--play-demo")
        if let i = args.firstIndex(of: "--record"), args.count > i + 1 {
            options.recording = URL(fileURLWithPath: args[i + 1])
        }
        if let flag = args.first(where: { $0.hasPrefix("--density=") }) {
            options.density = PanelDensity(rawValue: String(flag.dropFirst("--density=".count)))
        }
        if let flag = args.first(where: { $0.hasPrefix("--design=") }) {
            options.design = NotchDesign(rawValue: String(flag.dropFirst("--design=".count)))
        }
        if let flag = args.first(where: { $0.hasPrefix("--native-panels=") }) {
            options.nativePanels = NativePanels(rawValue: String(flag.dropFirst("--native-panels=".count)))
        }
        return options
    }
}

/// The mock display's appearance: the system's, or one to test against. The workbench
/// window itself always follows the system.
enum MockAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// The notch design's state on the mock display. Silent is the notch at rest: the physical
/// cutout and nothing else. Voice flow is the Listening Flowing Bar. Transcribing is the same
/// bar turning the voice into words; Cancelled is the same bar offering to undo a cancel,
/// with the time left (PRD §10: every voice state keeps the Listening size). Paste not found
/// is the one that grows: the words had nowhere to go, so the island holds them to copy.
/// Dispatch and Quick actions have their own voice bars, and Quick actions its Thinking, the
/// agent at work (docs/island/AGENT_VOICE_AND_THINKING.md). Dispatch's Choose chat shows the
/// request, its referents and the chat Fovea picked, and opens to the chats by agent
/// (docs/island/CHOOSE_CHAT.md).
enum NotchState: String, CaseIterable, Identifiable {
    case silent, voiceFlow, transcribing, cancelled, noSpeech, pasteNotFound
    /// A notice in place of the bar (feedback #2): what went wrong, in English, and the one way on.
    case voiceError
    case dispatchVoice, chooseChat, chatsExpanded, chatsAll, agentPanel, quickVoice, quickThinking
    /// Dispatch Version 2 (WorkbenchModel+DispatchV2.swift): its voice bar (Voiceflow's); Choose
    /// chat; the control board; a session's expanded chat.
    case v2Voice, v2Transcribing, v2Send, v2Board, v2Chat
    var id: String { rawValue }
    var title: String {
        switch self {
        case .silent: return "Silent notch"
        case .voiceFlow: return "Voice flow"
        case .transcribing: return "Transcribing"
        case .cancelled: return "Cancelled"
        case .noSpeech: return "No speech detected"
        case .pasteNotFound: return "Paste not found"
        case .voiceError: return "Error"
        case .dispatchVoice, .quickVoice, .v2Voice: return "Voice input"
        case .chooseChat: return "Choose chat"
        case .chatsExpanded: return "Expanded view of chats"
        case .chatsAll: return "Chats in a project"
        case .agentPanel: return "Agent panel"
        case .quickThinking: return "Thinking"
        case .v2Transcribing: return "Transcribing"
        case .v2Send: return "Choose chat"
        case .v2Chat: return "Expanded chat"
        case .v2Board: return "Control board"
        }
    }
    /// The island's geometry for the state: Core lays out each density, corners included,
    /// so every state meets the Mac the same way.
    var density: NotchGeometry.Density {
        self == .silent ? .resting : .voice
    }
    /// The flow the state belongs to; the notch at rest belongs to none.
    var flow: NotchFlow? {
        switch self {
        case .silent: return nil
        case .voiceFlow, .transcribing, .cancelled, .noSpeech, .pasteNotFound, .voiceError: return .voiceflow
        case .dispatchVoice, .chooseChat, .chatsExpanded, .chatsAll, .agentPanel: return .dispatch
        case .quickVoice, .quickThinking: return .quickActions
        case .v2Voice, .v2Transcribing, .v2Send, .v2Board, .v2Chat: return .dispatchV2
        }
    }
    /// The microphone is open.
    var listening: Bool { self == .voiceFlow || self == .dispatchVoice || self == .quickVoice || self == .v2Voice }
    /// Dispatch Version 2's own states.
    var dispatchV2: Bool { flow == .dispatchV2 }
    /// The bar that collects referents (the waveform, the stack, capture mode): Voiceflow's, and
    /// Dispatch Version 2's voice input, which is the same bar.
    var collects: Bool { self == .voiceFlow || self == .v2Voice }
    /// States that keep the request's referents: Choose chat's, and Dispatch Version 2's voice
    /// input and suggested chats.
    var keepsReferents: Bool { choosingChat || self == .v2Voice || self == .v2Transcribing || self == .v2Send }
    /// Choose chat, closed or opened to the chats.
    var choosingChat: Bool { self == .chooseChat || self == .chatsExpanded || self == .chatsAll }
    /// How far Choose chat is opened, to order its springs.
    var chatDepth: Int { self == .chatsAll ? 2 : self == .chatsExpanded ? 1 : 0 }
}

/// The panel's flows under Notch, each a disclosure group of its states.
enum NotchFlow {
    case voiceflow, dispatch, quickActions, dispatchV2
}

/// The Notch list in the panel: the notch at rest, the voice bar, or the voice bar with capture
/// mode on (left Option held), then the states after it. No speech detected and Paste not found
/// are fallbacks: nothing was said, or the words had nowhere to go.
enum NotchMode: String, CaseIterable, Identifiable {
    case silent, voiceFlow, addScreenshot, transcribing, cancelled, noSpeech, pasteNotFound
    var id: String { rawValue }
    var title: String {
        switch self {
        case .silent: return "Silent notch"
        case .voiceFlow: return "Voice flow"
        case .addScreenshot: return "Add screenshot"
        case .transcribing: return "Transcribing"
        case .cancelled: return "Cancelled"
        case .noSpeech: return "No speech detected"
        case .pasteNotFound: return "Paste not found"
        }
    }
}

/// The Notch list's Dispatch section: the states of dispatching a request to an Agent. The notch
/// at rest (the same Silent notch as Voiceflow's), its voice bar, and Choose chat: closed, opened
/// to the rail of agents and their projects (left ⌃ opens and closes it too), and opened to one
/// project's chats.
enum DispatchMode: String, CaseIterable, Identifiable {
    case silent, voice, choose, chats, all, panel
    var id: String { rawValue }
    var title: String {
        switch self {
        case .silent: return "Silent notch"
        case .voice: return "Voice input"
        case .choose: return "Choose chat"
        case .chats: return "Expanded view of chats"
        case .all: return "Chats in a project"
        case .panel: return "Agent panel"
        }
    }
}

/// The Notch list's Quick actions section: the notch at rest, its voice bar, and Thinking, the
/// agent at work on the Mac.
enum QuickActionMode: String, CaseIterable, Identifiable {
    case silent, voice, thinking
    var id: String { rawValue }
    var title: String {
        switch self {
        case .silent: return "Silent notch"
        case .voice: return "Voice input"
        case .thinking: return "Thinking"
        }
    }
}

/// What the mock display shows: the desktop, or an app taken full screen, where the menu bar
/// and the Dock are gone and the band beside the notch is black.
enum MockScreenContent: String, CaseIterable, Identifiable {
    case desktop, fullScreenApp
    /// Two apps side by side in Split View (feedback #6): the words go to the one under the pointer.
    case splitView
    var id: String { rawValue }
    var title: String {
        switch self {
        case .desktop: return "Desktop"
        case .fullScreenApp: return "Full-Screen App"
        case .splitView: return "Split View"
        }
    }
    /// Full screen and Split View hide the menu bar: the band beside the notch is black.
    var fullScreen: Bool { self != .desktop }
}

/// The workbench's state: the panel's visibility, the mock display's size, and what the
/// desktop shows. One per window.
@MainActor @Observable
final class WorkbenchModel {
    static let sidebarKey = "workbench.sidebarVisible"
    static let appearanceKey = "workbench.appearance"
    static let wallpaperKey = "workbench.wallpaper"
    static let screenKey = "workbench.screen"
    static let referentShapeKey = "workbench.referentShape"
    static let cardMotionKey = "workbench.cardMotion"

    let options: WorkbenchOptions
    /// Snapshots fix the clock, the background and the appearance, so a PNG is reproducible.
    var snapshotMode: Bool { options.snapshotDirectory != nil }

    /// `.detailOnly` hides the panel. Never test for `.all`: for a two-column split SwiftUI
    /// may hand `.doubleColumn` back, and both mean "shown".
    var columnVisibility: NavigationSplitViewVisibility

    /// The display: a MacBook's points in the Workbench; the real screen's in Fovea (IslandLive).
    var display = WorkbenchTokens.Layout.display
    /// The real Mac (Fovea 1.0): set by IslandController; nil in the Workbench's own runs.
    @ObservationIgnored var live: IslandLive?
    /// Fovea: the glass's light or dark, the person's choice.
    var liveScheme: ColorScheme = .dark
    /// Fovea: the board opens on the hover only when the person lets it, after their wait.
    @ObservationIgnored var hoverOpens = true
    /// The name the board greets the person by when nothing is running (prefs' account name).
    var greetingName = ""
    /// Settings › Notch › "Show an answer as soon as it's back": a quick answer opens by itself.
    @ObservationIgnored var showAnswers = true
    @ObservationIgnored var hoverDwell: (start: Double, cap: Double) = (WorkbenchTokens.Panel.dwell, WorkbenchTokens.Panel.dwellCap)
    /// Fovea: the words the person said for the Dispatch request now (the script plays the work).
    var v2Words: String?
    /// Fovea: a choice shown at the notch a moment (Settings, the first run), no microphone.
    var previewing = false
    /// Fovea's `--demo`: the Workbench's sample sessions on the board, and no microphone.
    @ObservationIgnored var demoSamples = false
    /// How much the glow's colors wander, still (0) to lively (1).
    var glowDriftAmount: Double = 0.5
    /// When Accessibility was last asked for the words under the highlighter.
    @ObservationIgnored var highlightAsked: Date?
    /// The first run: the line under the notch; the sessions its agent runs, and their answers;
    /// the microphone test's level; the chats it offers in Choose chat.
    var directorSessions: Set<String> = []
    var directorAnswers: [String: String] = [:]
    /// What the director's agent did for the exchange now (its steps as it reported them), and
    /// the files it changed, for the fold under its answer and the buttons under that.
    var directorSteps: [String: [AgentLiveStep]] = [:]
    var directorFiles: [String: [String]] = [:]
    var previewLevel: Float = 0 { didSet { if previewing { audioLevel = previewLevel } } }
    var directorSuggestions: [V2Suggestion]?
    var metrics: ScreenMetrics { display }
    /// The detail column's size, reported by the stage.
    var columnSize: CGSize = .zero
    /// How the display is drawn: the largest fit of the lid in the column, never above 1:1.
    var scale: CGFloat {
        let lid = WorkbenchTokens.Layout.lid
        guard columnSize.width > 0, columnSize.height > 0 else { return 1 }
        return min(1, columnSize.width / lid.width, columnSize.height / lid.height)
    }
    /// The screen's size on the window, in points.
    var screenSize: CGSize {
        CGSize(width: display.frame.width * scale, height: display.frame.height * scale)
    }

    /// The notch design's state: a session, not a preference, so it starts Silent. Setting it
    /// starts or stops the microphone; the view moves the surface on the Island's springs.
    var notchState: NotchState {
        get { notchStateStorage }
        set { setNotchState(newValue) }
    }
    private var notchStateStorage: NotchState = .silent
    /// The flow whose list shows the notch at rest: the last one the notch was in, or the one
    /// whose Silent notch was chosen. Every flow's Silent notch rests the notch the same way.
    var restingFlow: NotchFlow = .voiceflow
    /// The microphone level while listening, 0…1. Simulated: Core's meter, the product's own.
    var audioLevel: Float = 0
    @ObservationIgnored private let meter = SimulatedAudioMeter()
    @ObservationIgnored private var metering: Task<Void, Never>?
    /// fn, press-to-toggle (Voiceflow), and fn⌃ (Dispatch Version 2). Started by the app once
    /// launching is done.
    @ObservationIgnored let functionKey = ModifierPressMonitor.function()
    /// Left Control, press-to-toggle: Choose chat opens to every chat, and folds again.
    @ObservationIgnored let leftControlKey = ModifierPressMonitor.leftControl()
    /// Left Option on either voice bar: a click turns capture mode on (a region, a passage's text,
    /// a file) and another turns it off; held, it is on while held; clicked twice, the whole screen
    /// is attached.
    @ObservationIgnored let leftOptionKey = ModifierHoldMonitor.leftOption()
    /// The press of left Option under way turned capture mode on (nil: no press, or not on a bar).
    @ObservationIgnored var optionTurnedOn: Bool?
    /// A passage just taken in capture mode, flashing.
    var capturedFlash: CGRect?
    /// Fovea's own surfaces (the island, its pulled-out chats, capture mode's marks) are hidden
    /// for a moment while the whole screen is taken, so nothing of Fovea covers it.
    var hidingOwnSurfaces = false
    /// Esc and the tab keys, in the workbench window.
    @ObservationIgnored let keys = WorkbenchKeyMonitor()
    /// The pointer, wherever the workbench is among the apps: the hover over the notch.
    @ObservationIgnored let pointer = PointerMonitor()

    // MARK: Capture (WorkbenchModel+Capture.swift)

    /// Capture mode: a drag draws a region and captures it; everything else reaches the page.
    var capturing: Bool {
        get { capturingStorage }
        set { setCapturing(newValue) }
    }
    var capturingStorage = false
    /// The region being drawn, in display points.
    var selection: CGRect?
    /// The captures, in the order they were taken. A session's: cleared when the bar closes.
    var referents: [CapturedReferent] = []
    /// Captures still flying into the stack, and the cards waiting for them.
    var flights: [ReferentFlight] = []
    var landing: Set<UUID> = []
    var referentShape: ReferentShape {
        didSet {
            islandAnimation = WorkbenchTokens.Referents.settle
            cardChange = .settle
        }
    }
    var cardMotion: WorkbenchTokens.CardMotion
    /// Every capture laid out in the island.
    var stackExpanded = false
    /// The capture being looked at closely, in the opened stack.
    var inspectedId: UUID?
    /// The capture under the pointer in the opened stack: it grows a little and shows its ✕.
    var hoveredReferent: UUID?
    /// Removed captures, fading where they were while the rest close the gap.
    var removing: Set<UUID> = []
    /// The card growing for a close look, or going back from one: it moves on the fan.
    @ObservationIgnored var inspectTransitionId: UUID?
    /// The pointer on the collapsed stack: it fans to the right.
    var stackHovered = false
    /// How the island and the cards move for the change being made; set with the change.
    @ObservationIgnored var islandAnimation: Animation = WorkbenchTokens.Motion.open
    @ObservationIgnored var cardChange: CardChange = .settle
    /// The stage's probe: where the display sits in the window, for real captures.
    @ObservationIgnored weak var stageProbe: NSView?

    // MARK: Transcribing and cancelling (WorkbenchModel+Voice.swift)

    /// The words so far, revealed as the transcription runs.
    var transcript = ""
    /// When the transcription started; its progress is the time since, over its length.
    var transcribeStart: Date?
    /// When the cancel happened; the time left to undo counts down from here.
    var undoStart: Date?
    /// Set while the pointer rests on the bar: the time left to undo holds still.
    var undoPausedAt: Date?
    /// What Undo returns to: the state the cancel came from, capture mode included.
    @ObservationIgnored var undoMode: NotchMode = .voiceFlow
    @ObservationIgnored var transcribeTask: Task<Void, Never>?
    @ObservationIgnored var undoTask: Task<Void, Never>?
    /// When listening began: a session too short to have said anything transcribes to nothing.
    @ObservationIgnored var listenStart: Date?
    @ObservationIgnored var noSpeechTask: Task<Void, Never>?

    // MARK: Paste not found (WorkbenchModel+Paste.swift)

    /// The transcript opened to its full length.
    var pasteExpanded = false
    /// Copy was pressed: the button says so, then the island rests.
    var pasteCopied = false
    /// When the countdown to rest started.
    var pasteStart: Date?
    /// Where Copy stopped the countdown: the ring holds there until the island rests.
    var pastePausedAt: Date?
    @ObservationIgnored var pasteTask: Task<Void, Never>?
    /// The transcript's height at the island's text width, whole and as the lines it shows
    /// closed; measured by the view, which draws it.
    var pasteTextHeight: CGFloat = 0
    var pasteLinesHeight: CGFloat = 0
    /// Where Copy writes: the general pasteboard; the checks use their own.
    @ObservationIgnored var pasteboard: NSPasteboard = .general
    /// What was pasted into the notes' comment box, the one input box on the mock pages.
    var pastedNote: String?

    // MARK: Agents (WorkbenchModel+Agent.swift)

    static let agentPreviewKey = "workbench.agentPreview"
    static let activityKey = "workbench.activityLayout"
    /// Thinking's layout and what the agent does (the full run, or one action on a loop),
    /// chosen in the panel and remembered.
    var agentPreview: AgentAction? {
        didSet {
            rememberAgentStyles()
            // A new choice plays at once when Thinking is showing.
            if notchState == .quickThinking, oldValue != agentPreview { showThinking() }
        }
    }
    var activityLayout: ActivityLayout {
        didSet {
            islandAnimation = WorkbenchTokens.Referents.settle
            rememberAgentStyles()
        }
    }
    /// What the agent is doing while Thinking; nil otherwise.
    var agentAction: AgentAction?
    /// The person answered Needs you.
    @ObservationIgnored var agentAllowed = false
    /// The agent's pointer on the page, drawn only, and the rings its clicks leave.
    var agentPointer: DemoPointer?
    var agentRipples: [AgentRipple] = []
    @ObservationIgnored var agentTask: Task<Void, Never>?
    /// The agent voice bars' glow (libraries.dev/voice): its driver keeps the envelope across
    /// frames.
    @ObservationIgnored let voiceGlow = VoiceGlowEngine()
    static let glowPaletteKey = "workbench.glowPalette"
    static let glowHueKey = "workbench.glowHue"
    static let glowSpreadKey = "workbench.glowSpread"
    static let glowDriftKey = "workbench.glowDrift"
    /// The glow's colors, chosen in the panel's Voice glow section and remembered. Touching any of
    /// them shows the glow, so the change can be seen.
    var glowPalette: GlowPalette { didSet { glowChanged() } }
    /// A palette's turn around the wheel, or Custom's base hue, in degrees.
    var glowHue: Double { didSet { glowChanged() } }
    /// How far Custom's seven hues fan across the wheel, in degrees.
    var glowSpread: Double { didSet { glowChanged() } }
    var glowDrift: Bool { didSet { glowChanged() } }
    /// The colors as chosen, for the renderer and the panel's swatches.
    var glowLook: VoiceGlowLook {
        var look = VoiceGlowLook.make(palette: glowPalette, hue: glowHue, spread: glowSpread, drift: glowDrift)
        look.driftAmount = glowDriftAmount * 2
        return look
    }
    /// How fast the agent's script runs: 1 in person; the checks run it faster.
    @ObservationIgnored var agentPace: Double = 1
    /// Where named parts of the mock pages are on the display ("article.headline",
    /// "notes.comment", "safari.address"…), reported by the pages, for the agent's pointer.
    @ObservationIgnored var agentAnchors: [String: CGRect] = [:]
    /// What the agent shows on the mock screen besides its pointer: a key it pressed, text it
    /// selected, a context menu, a screenshot's flash, a region it zoomed into, something it
    /// drags, what it types into the address field, a toast (a download), and a question for
    /// the person (Needs you).
    var agentKeycap: String?
    /// The element the agent is about to act on, bracketed; and the matches of a find.
    var agentTarget: CGRect?
    var agentFinds: [CGRect] = []
    var agentHighlights: [CGRect] = []
    var agentMenu: AgentMenu?
    var agentFlash = false
    var agentZoom: CGRect?
    var agentDrag: CGRect?
    var agentAddress: String?
    var agentToast: AgentToast?
    var agentNeedsYou: String?

    // MARK: Choose chat (WorkbenchModel+Chat.swift)

    static let chatCaseKey = "workbench.chatCase"
    /// The sample chats, as the edge case staged leaves them.
    var chats = ChatBook.chats
    /// The edge case the panel stages; changing it starts Choose chat over.
    var chatCase: ChatCase {
        didSet {
            guard chatCase != oldValue else { return }
            rememberAgentStyles()
            chatCaseChanged()
        }
    }
    /// The chat the request goes to: Fovea's pick, until the person picks another; empty while
    /// routing has failed.
    var chosenChat = ChatBook.predicted
    /// The row under the keyboard's or the pointer's highlight in the opened view: a project's,
    /// a chat's, or the row back.
    var chatHighlight: String?
    /// The agent whose projects show under the rail, and the project open on the chats level.
    var chatAgent = ChatBook.predictedAgent
    var chatProject: String? = ChatBook.project
    /// Routing has answered: the pill shows the chat. Until then it breathes "Choosing chat".
    var chatRouted = true
    /// Routing couldn't answer; or it isn't sure and asks, its guesses under the row.
    var chatRoutingFailed = false
    var chatUnsure = false
    @ObservationIgnored var chatRetried = false
    /// The chat routing picked was closed before the request went.
    var chatRemovedTitle: String?
    /// Where the request is after Send, when it isn't simply gone.
    var chatSend: ChatSendPhase?
    @ObservationIgnored var chatSendRetried = false
    /// Agents whose chats are still being read.
    var chatLoadingAgents: Set<String> = []
    /// "Continue in Terminal" was chosen over a Claude Desktop too old to take the request.
    var chatTerminal = false
    /// A referent that couldn't be read: it shows as missing and doesn't go.
    var chatMissingReferent: UUID?
    /// "Chats change while open" has happened this time.
    @ObservationIgnored var chatChanged = false
    @ObservationIgnored var chatCaseTask: Task<Void, Never>?
    /// Where the pointer was when a row last took the highlight.
    @ObservationIgnored var chatHoverMouse: CGPoint?
    /// The request's height at the island's text width, whole and as its three lines; measured by
    /// the view, which draws it. Longer than three lines, it scrolls in them.
    var chatTextHeight: CGFloat = 0
    var chatLinesHeight: CGFloat = 0
    /// Routing's answer, and a chosen chat's close.
    @ObservationIgnored var chatTask: Task<Void, Never>?
    @ObservationIgnored var chooseTask: Task<Void, Never>?

    // MARK: Agent panel (WorkbenchModel+Panel.swift)

    static let panelStyleKey = "workbench.panelStyle"
    /// The Agent tasks Fovea delivered (a sample, live while the workbench runs).
    var agentTasks = AgentBoard.tasks
    /// How the rows read (the variations to choose from), chosen in the panel and remembered.
    var panelStyle: PanelStyle = .ledger {
        didSet {
            islandAnimation = WorkbenchTokens.Panel.open
            rememberAgentStyles()
        }
    }
    /// The keyboard's or the pointer's row, and the task Send just created (highlighted a while).
    var panelHighlight: String?
    var panelSentTask: String?
    /// Opened from the panel's radio: it stays until Esc or another choice.
    @ObservationIgnored var panelPinned = false
    /// The hover: where the pointer is, whether a rest on the notch may open the panel again, and
    /// the dwell, exit and sent graces.
    @ObservationIgnored var panelZone: PanelZone = .outside
    @ObservationIgnored var panelArmed = true
    @ObservationIgnored var panelDwell: Task<Void, Never>?
    @ObservationIgnored var panelExit: Task<Void, Never>?
    @ObservationIgnored var panelSentGrace: Task<Void, Never>?
    /// The pointer's last moves (for the rest test), when it last left the notch while a dwell
    /// ran (the jitter grace), and when a hover last closed the panel (the reopen window).
    @ObservationIgnored var panelMoves: [(time: Date, point: CGPoint)] = []
    @ObservationIgnored var panelLeftNotch: Date?
    @ObservationIgnored var panelHoverClosed: Date?
    /// When the panel last opened: its controls take no click for a moment after (a click meant
    /// for what was under the pointer never allows a command).
    @ObservationIgnored var panelOpened = Date.distantPast
    /// The agents at work: each task's place in its script, and one-off scripts (a sent request,
    /// an answer).
    @ObservationIgnored var panelSimulation: Task<Void, Never>?
    @ObservationIgnored var panelBeats: [String: Int] = [:]
    @ObservationIgnored var panelScripts: [String: [AgentBeat]] = [:]

    // MARK: Dispatch Version 2 (WorkbenchModel+DispatchV2.swift)

    static let v2RequestKey = "workbench.v2Request"
    /// The sample request the flow plays, chosen in the panel.
    var v2Request: V2Request = .code {
        didSet { rememberAgentStyles() }
    }
    /// The latest request's session; every session this flow sent; the ones the person opened
    /// (no longer Ready for review).
    var v2Session: String?
    var v2Sessions: Set<String> = []
    var v2Checked: Set<String> = []
    /// The session in focus (the board's, the expanded chat's), and the board's row the keys
    /// moved to, to scroll into view.
    var v2Focus: String?
    var v2ScrollTarget: String?
    /// fn on an expanded chat: the voice bar asks it more.
    var v2Continuing: String?
    /// Choose chat: the chat in the pill (nil: the first suggestion); its browser (the agent, the
    /// project opened). Nothing sends until the person does.
    var v2PickStorage: V2Suggestion?
    var v2Browsing = false
    var v2BrowseAgent = ChatBook.predictedAgent
    var v2BrowseProject: String?
    /// The taken thing being looked at closer in Choose chat.
    var v2Inspecting: UUID?
    /// The expanded chat: opened from the board (✕ goes back there); the pointer on it; read.
    var v2ChatFromBoard = false
    var v2ChatHovered = false
    var v2ChatInteracted = false
    var v2Copied = false
    /// When each request went and came back (its status line; whether it pops up).
    var v2Started: [String: Date] = [:]
    var v2FinishedAt: [String: Date] = [:]
    /// What the person did with the suggestions, request by request: routing's labels.
    var v2Labels: [V2RoutingLabel] = []
    /// What was asked more in a session, shown as its request; and each session's exchanges
    /// before the one now (a pulled-out chat lists them all, with a rail to find each).
    var v2Followed: [String: String] = [:]
    var v2History: [String: [V2Turn]] = [:]
    /// Chats pulled out of the notch, and the one being pulled.
    var v2Detached: [V2Detached] = []
    var v2DragOut: V2DragOut?
    @ObservationIgnored var v2Pinned = false
    /// The board a session was opened from was pinned (the panel's radio): back on it, it is again.
    @ObservationIgnored var v2BoardPinned = false
    @ObservationIgnored var v2Scripts: [String: [AgentBeat]] = [:]
    @ObservationIgnored var v2Requests: [String: V2Request] = [:]
    /// What was taken with each request, for the head of an answer about it.
    @ObservationIgnored var v2Attachments: [String: [NSImage]] = [:]
    @ObservationIgnored var v2Runs: [String: Task<Void, Never>] = [:]
    @ObservationIgnored var v2BoardHold: Task<Void, Never>?
    @ObservationIgnored var v2ChatHold: Task<Void, Never>?
    @ObservationIgnored var v2Play: Task<Void, Never>?
    @ObservationIgnored var v2HoverFocus: Task<Void, Never>?
    @ObservationIgnored var v2Transcribe: Task<Void, Never>?
    /// When the transcription began (its progress bar).
    var v2TranscribeStart = Date.distantPast

    // MARK: Feedback, Oct 6 (Feedback/*.swift; docs/island/FEEDBACK_2026-10-06.md)

    /// The panel's Feedback tab on show, and each tab's own choices.
    var feedbackSelection: FeedbackItem?
    var feedbackErrorChoice: VoiceError = .offline
    var feedbackSelectStage: SelectStage = .highlighting
    var feedbackCountdownStage: CountdownStage = .lastMinute
    var feedbackWorkStage: WorkStage = .working
    var feedbackQueueStage: QueueStage = .queued
    /// #2: the notice showing (in place of the bar, or inside it while it listens), its clock.
    var voiceError: VoiceError?
    var barNotice: VoiceError?
    var errorStart: Date?
    var errorPausedAt: Date?
    @ObservationIgnored var errorTask: Task<Void, Never>?
    @ObservationIgnored var barNoticeTask: Task<Void, Never>?
    /// #3/#8: Option on a voice bar is the highlighter (text and files), in the accent color; its
    /// marks stay on the screen while the session lasts. ⌘ takes the screenshots.
    var highlighting: Bool {
        get { highlightingStorage }
        set { setHighlighting(newValue) }
    }
    var highlightingStorage = false
    var highlightDraft: [CGRect]?
    var highlights: [ScreenHighlight] = []
    /// ⌥ on, on the real Mac: the file under the pointer, shaded before it's clicked.
    var hoverMark: CGRect?
    @ObservationIgnored var hoverMarkAsked: Date?
    var accent: FoveaAccent = .blue {
        didSet {
            DesignStore.shared.accent = accent
            if !snapshotMode { UserDefaults.standard.set(accent.rawValue, forKey: Self.accentKey) }
        }
    }
    static let accentKey = "workbench.accent"
    /// The notch's design (docs/island/NATIVE.md): every token that follows it reads it.
    var design: NotchDesign = .original {
        didSet {
            DesignStore.shared.value = design
            if !snapshotMode && !options.smoke && options.design == nil {
                UserDefaults.standard.set(design.rawValue, forKey: Self.designKey)
            }
        }
    }
    static let designKey = "workbench.design"
    /// Native's panels: attached to the notch, or floating under it (docs/island/NATIVE.md).
    var nativePanels: NativePanels = .attached {
        didSet {
            DesignStore.shared.panels = nativePanels
            if !snapshotMode && !options.smoke && options.nativePanels == nil {
                UserDefaults.standard.set(nativePanels.rawValue, forKey: Self.nativePanelsKey)
            }
        }
    }
    static let nativePanelsKey = "workbench.nativePanels"
    /// The open panels' room (docs/island/SPACIOUS.md): every token that follows it reads it.
    var density: PanelDensity = .spacious {
        didSet {
            DensityStore.shared.value = density
            if !snapshotMode && !options.smoke && options.density == nil {
                UserDefaults.standard.set(density.rawValue, forKey: Self.densityKey)
            }
        }
    }
    static let densityKey = "workbench.density"
    /// The press of ⌘ under way turned capture mode on (nil: no press, or not on a bar).
    @ObservationIgnored var commandTurnedOn: Bool?
    @ObservationIgnored let leftCommandKey = ModifierHoldMonitor.leftCommand()
    @ObservationIgnored let rightCommandKey = ModifierHoldMonitor.rightCommand()
    /// #4: how long the session has been listening, as the bar shows it (the panel's stages
    /// start it near the end), and the pulse when the last minute begins.
    var recordingStart: Date?
    var inLastMinute = false
    var lastMinutePulse = 0
    /// The last minute's nudge: the bar a few points taller for a moment, on its own spring.
    var lastMinuteNudge = false
    @ObservationIgnored var recordingLimitTask: Task<Void, Never>?
    /// #6: the pointer on the mock display (Split View's two apps take words from the one under
    /// it), and the demo's hand standing in for it.
    var pointerOnDisplay: CGPoint?
    var splitTargetOverride: SplitSide?
    var splitPasted: [SplitSide: String] = [:]
    @ObservationIgnored var splitDemo: Task<Void, Never>?
    /// #7: the words just landed in a field (it lights up), then the notch leaves.
    var pasteLanding: Date?
    /// #1 and #19: the model and thinking effort chosen for the request (nil: Auto, Fovea picks),
    /// and the sheet that chooses them open (Choose chat's, or the voice bar's).
    var v2Model: String?
    var v2Effort: String?
    var v2ModelSheet = false
    var feedbackModelStage: ModelStage = .closed
    /// #15: names made from a new session's first request, and the ones still being made.
    var v2Titles: [String: String] = [:]
    var v2Naming: Set<String> = []
    /// #24: what waits for a working session, and the sessions whose queue holds.
    var v2Queue: [String: [V2QueuedAsk]] = [:]
    var v2QueuePaused: Set<String> = []
    /// Sessions on a follow-up (their sample answer is the follow-up's).
    @ObservationIgnored var v2FollowUps: Set<String> = []
    /// #19: whether Choose chat shows the words to check (the setting), and the voice bar's sheet
    /// for the chat, model and effort when it doesn't.
    var v2ReviewBeforeSend = true
    var v2RouteOpen = false
    var feedbackRouteOpen = false
    /// What the agent did, folded under each answer, opened: the session's id for the exchange
    /// now, `V2Work.key` for an earlier one.
    var v2StepsOpen: Set<String> = []
    /// The session's size in the notch: usual, or expanded (the whole session). Its expand button
    /// and left ⌃ switch; Esc comes back to the usual size.
    var v2Size: V2SessionSize = .usual
    var v2Expanded: Bool {
        get { v2Size == .expanded }
        set { v2Size = newValue ? .expanded : .usual }
    }
    /// The expanded session opens at its foot, and keeps to it as it grows (an answer coming in);
    /// once the person opens what an agent did, what grows grows downward from where they are.
    var v2HistoryHeld = false
    /// Counts the expansions, so each opens a new scroll at its foot.
    var v2HistoryEpoch = 0
    /// The expanded session staged with many requests (the panel's second entry), and the
    /// outline's card shown open (the shots' stand-in for the pointer).
    var v2StagedLong = false
    var v2OutlineShown = false
    /// The agents' steps move on with this (Feedback/V2Steps.swift).
    var v2LiveTick = 0
    @ObservationIgnored var liveStepClock: Task<Void, Never>?
    /// Drawing off screen (`--render-board`): scroll views, which can't be drawn there, become stacks.
    @ObservationIgnored var offscreenRender = false
    /// #16: the steps watched in the session or on the board.
    var feedbackStepsStage: StepsStage = .session
    /// The control board's design (#9–10, #17, round three).
    var boardStyle: BoardStyle = .sections
    /// The designs with pets: the pet of the session most in need beside the notch at rest.
    var petAtRest = true
    /// Creatures: the pointer over the board, in the board's points (nil: not over it), for the
    /// creatures' eyes and the Dock-like growth under it.
    var v2BoardPointer: CGPoint?
    /// A recording drives the pointer itself (`--record-creatures`); the real one is ignored.
    @ObservationIgnored var pointerScripted = false
    /// #16: the activity line's words (decided: the kind of step only; the board no longer shows one).
    var activityWithObject = false

    // MARK: Safari

    let tabs = SafariTab.all
    var selectedTab = 0
    /// A page to scroll to an anchor, animated; pages act on the one addressed to them.
    var scrollRequest: ScrollRequest?
    /// Every page back to its top, at once.
    var scrollReset = 0
    /// How far each page is scrolled, in points; for the checks.
    @ObservationIgnored var pageOffsets: [Int: CGFloat] = [:]

    // MARK: Demo (WorkbenchDemo.swift)

    /// A drawn pointer, so a recording shows where the hand is.
    var demoPointer: DemoPointer?
    var demoRunning = false
    @ObservationIgnored var demoTask: Task<Void, Never>?

    /// What the display shows, chosen in the panel.
    var screenContent: MockScreenContent
    var wallpaperChoice: WallpaperChoice
    var appearance: MockAppearance
    /// Pictures are read once per choice.
    @ObservationIgnored private var fills: [WallpaperChoice: WallpaperFill] = [:]
    var wallpaperFill: WallpaperFill {
        if let fill = fills[wallpaperChoice] { return fill }
        let fill = Wallpaper.fill(for: wallpaperChoice)
        fills[wallpaperChoice] = fill
        return fill
    }

    let clock: Date
    let dockIcons: DockIcons
    /// The picture on the full-screen page.
    let pageHero: NSImage?

    init(arguments: [String] = CommandLine.arguments) {
        let options = WorkbenchOptions.parse(arguments)
        let snapshot = options.snapshotDirectory != nil
        self.options = options
        let defaults = UserDefaults.standard
        let remembered = defaults.object(forKey: Self.sidebarKey) as? Bool ?? true
        columnVisibility = remembered ? .all : .detailOnly
        // Snapshots do not depend on the Mac they ran on: the desktop, the bundled photo, the
        // system look.
        screenContent = snapshot ? .desktop
            : defaults.string(forKey: Self.screenKey).flatMap(MockScreenContent.init(rawValue:)) ?? .desktop
        wallpaperChoice = snapshot ? .photo(Wallpaper.defaultPhoto)
            : defaults.string(forKey: Self.wallpaperKey).flatMap(WallpaperChoice.init(key:)) ?? .system
        appearance = snapshot ? .system
            : defaults.string(forKey: Self.appearanceKey).flatMap(MockAppearance.init(rawValue:)) ?? .system
        clock = snapshot ? WorkbenchTokens.Snapshot.date : Date()
        dockIcons = DockIcons.load()
        pageHero = Wallpaper.bundled("coast")
        // Decided: rounded rectangles on the reference's motion. The other shapes and the
        // no-bounce motion stay in code for the comparison snapshots; nothing restores them.
        referentShape = .roundedRectangle
        cardMotion = .reference
        // Saved choices from the progress studies, now settled (docs/island/PROGRESS.md).
        for key in ["workbench.transcribeStyle", "workbench.undoStyle", "workbench.thinkingLabel",
                    "workbench.transcribeLine", "workbench.undoLine", "workbench.lineWeight"] {
            defaults.removeObject(forKey: key)
        }
        defaults.removeObject(forKey: Self.referentShapeKey)
        defaults.removeObject(forKey: Self.cardMotionKey)
        // The agent studies' choices; snapshots use the defaults. The voice styles were compared
        // and settled on libraries.dev/voice.
        defaults.removeObject(forKey: "workbench.dispatchVoiceStyle")
        defaults.removeObject(forKey: "workbench.quickVoiceStyle")
        // The orb was settled on the Lasso; the other forms and their tuning are gone.
        defaults.removeObject(forKey: "workbench.orbTuning")
        defaults.removeObject(forKey: "workbench.thinkingStyle")
        // The glow's style was settled on Wide.
        defaults.removeObject(forKey: "workbench.glowVariation")
        glowPalette = snapshot ? .colorful
            : defaults.string(forKey: Self.glowPaletteKey).flatMap(GlowPalette.init(rawValue:)) ?? .colorful
        glowHue = snapshot ? WorkbenchTokens.VoiceGlow.defaultHue
            : (defaults.object(forKey: Self.glowHueKey) as? Double) ?? WorkbenchTokens.VoiceGlow.defaultHue
        glowSpread = snapshot ? WorkbenchTokens.VoiceGlow.defaultSpread
            : (defaults.object(forKey: Self.glowSpreadKey) as? Double) ?? WorkbenchTokens.VoiceGlow.defaultSpread
        glowDrift = snapshot ? true : (defaults.object(forKey: Self.glowDriftKey) as? Bool) ?? true
        agentPreview = snapshot ? nil : defaults.string(forKey: Self.agentPreviewKey).flatMap(AgentAction.init(rawValue:))
        activityLayout = snapshot ? .under
            : defaults.string(forKey: Self.activityKey).flatMap(ActivityLayout.init(rawValue:)) ?? .under
        // Choose chat was settled on the rail.
        defaults.removeObject(forKey: "workbench.chatsStyle")
        chatCase = snapshot ? .usual : defaults.string(forKey: Self.chatCaseKey).flatMap(ChatCase.init(rawValue:)) ?? .usual
        panelStyle = snapshot ? .ledger : defaults.string(forKey: Self.panelStyleKey).flatMap(PanelStyle.init(rawValue:)) ?? .ledger
        v2Request = snapshot ? .code : defaults.string(forKey: Self.v2RequestKey).flatMap(V2Request.init(rawValue:)) ?? .code
        // The workbench's two flows (docs/island/FLOWS.md). fn⌃ is always a new Dispatch Version 2
        // request; fn is that flow's while one of its cards is up, and Voiceflow's everywhere else.
        functionKey.onPress = { [weak self] in
            guard let self else { return }
            if self.v2FunctionKey(control: self.functionKey.heldDuring.contains(.control)) { return }
            self.toggleVoiceFlow()
        }
        // Left Option, on either flow's voice bar: a click, capture on or off; held, capture while
        // held; clicked twice, the whole screen.
        leftOptionKey.onDown = { [weak self] in self?.optionDown() }
        leftOptionKey.onUp = { [weak self] click in self?.optionUp(click: click) }
        // Left ⌃ alone, on Choose chat: every chat, and folded again. (Held with fn it is fn⌃.)
        leftControlKey.onPress = { [weak self] in
            guard let self, !self.leftControlKey.heldDuring.contains(.function) else { return }
            if self.notchState == .v2Send { self.toggleV2Browse() }
            else if self.notchState == .v2Chat { self.toggleV2Expanded() }
        }
        // ⌘ on a voice bar, either side: a screenshot, one region per press; pressed twice, the whole
        // screen. Option is the highlighter (Oct 6 feedback, round two).
        for key in [leftCommandKey, rightCommandKey] {
            key.onDown = { [weak self] in self?.commandDown() }
            key.onUp = { [weak self] click in self?.commandUp(click: click) }
            key.onDoublePress = { [weak self] in self?.captureWholeScreen() }
        }
        accent = snapshot ? .blue : defaults.string(forKey: Self.accentKey).flatMap(FoveaAccent.init(rawValue:)) ?? .blue
        density = options.density ?? (snapshot || options.smoke ? .spacious
            : defaults.string(forKey: Self.densityKey).flatMap(PanelDensity.init(rawValue:)) ?? .spacious)
        DensityStore.shared.value = density
        design = options.design ?? (snapshot || options.smoke ? .original
            : defaults.string(forKey: Self.designKey).flatMap(NotchDesign.init(rawValue:)) ?? .original)
        DesignStore.shared.value = design
        DesignStore.shared.accent = accent
        nativePanels = options.nativePanels ?? (snapshot || options.smoke ? .attached
            : defaults.string(forKey: Self.nativePanelsKey).flatMap(NativePanels.init(rawValue:)) ?? .attached)
        DesignStore.shared.panels = nativePanels
        keys.onChatKey = { [weak self] key in self?.v2Key(key) ?? false }
        pointer.onMove = { [weak self] point in self?.pointerMoved(toScreen: point) }
        keys.onEscape = { [weak self] in self?.escape() ?? false }
        keys.onTabStep = { [weak self] step in self?.stepTab(step) ?? false }
        keys.onUndo = { [weak self] in self?.undoCancel() ?? false }
    }

    /// What the fn key does, as in the product: one press listens, the next turns the voice
    /// into words (Transcribing), which then paste, or wait to be copied. From Cancelled, No
    /// speech detected or Paste not found it starts afresh.
    func toggleVoiceFlow() {
        switch notchState {
        case .silent:
            // The first run: fn works only where it's taught.
            if let director = live?.director, !director.allowsVoice(dispatch: false) { return }
            notchState = .voiceFlow
            live?.director?.islandDidEmit(.voiceOpened(dispatch: false))
        // Dispatch Version 2's own presses are taken first (v2FunctionKey); here fn is dictation.
        case .v2Voice, .v2Transcribing, .v2Send, .v2Board, .v2Chat:
            notchState = .voiceFlow
        case .voiceFlow: startTranscribing()
        case .transcribing: notchState = .silent
        case .cancelled, .noSpeech, .pasteNotFound, .voiceError:
            dropUndo()
            clearReferents()
            notchState = .voiceFlow
        case .dispatchVoice, .quickVoice, .quickThinking:
            notchState = .voiceFlow
        case .agentPanel:
            notchState = .voiceFlow
        case .chooseChat, .chatsExpanded, .chatsAll:
            // Its referents were this request's, not the next one's.
            clearReferents()
            notchState = .voiceFlow
        }
    }

    /// The glow's settings changed: remembered, and the glow shown if no voice bar is, so the
    /// change can be seen (Dispatch Version 2's aura, unless the notch is busy with something else).
    private func glowChanged() {
        // Fovea: the controller shows a change at the notch, without the microphone.
        guard !snapshotMode, live == nil else { return }
        let defaults = UserDefaults.standard
        defaults.set(glowPalette.rawValue, forKey: Self.glowPaletteKey)
        defaults.set(glowHue, forKey: Self.glowHueKey)
        defaults.set(glowSpread, forKey: Self.glowSpreadKey)
        defaults.set(glowDrift, forKey: Self.glowDriftKey)
        if notchState == .silent { startV2Voice() }
    }

    /// Remembers the agent studies' choices. Snapshots leave them alone.
    func rememberAgentStyles() {
        guard !snapshotMode else { return }
        let defaults = UserDefaults.standard
        defaults.set(agentPreview?.rawValue, forKey: Self.agentPreviewKey)
        defaults.set(activityLayout.rawValue, forKey: Self.activityKey)
        defaults.set(chatCase.rawValue, forKey: Self.chatCaseKey)
        defaults.set(panelStyle.rawValue, forKey: Self.panelStyleKey)
        defaults.set(v2Request.rawValue, forKey: Self.v2RequestKey)
    }

    /// The view animates the change (`MockIsland`), so it moves the same way from any caller.
    /// Closing the bar ends the session: capture mode stops and the captures go, once the
    /// island has closed over them.
    private func setNotchState(_ state: NotchState) {
        guard state != notchStateStorage else { return }
        let opening = notchStateStorage == .silent
        let wasCollecting = notchStateStorage.collects
        let paste = state == .pasteNotFound || notchStateStorage == .pasteNotFound
        let thinking = state == .quickThinking || notchStateStorage == .quickThinking
        let chat = state.choosingChat || notchStateStorage.choosingChat
        let C = WorkbenchTokens.Chat.self
        let panel = state == .agentPanel || notchStateStorage == .agentPanel
        let v2 = state.dispatchV2 || notchStateStorage.dispatchV2
        islandAnimation = reduceMotion ? .easeOut(duration: WorkbenchTokens.Motion.reduceMotionFade)
            // Dispatch Version 2: each of its moves on its own spring (WorkbenchTokens.V2).
            : v2 && !panel ? WorkbenchTokens.V2.spring(from: notchStateStorage, to: state)
            // The Agent panel opens on its own quick spring (from Choose chat, after Send, it
            // settles from that shape), and closes quicker.
            : panel ? (state == .agentPanel ? WorkbenchTokens.Panel.open : WorkbenchTokens.Panel.close)
            // Choose chat opens and closes as Paste not found does; its list grows and folds.
            : chat ? (state.choosingChat && notchStateStorage.choosingChat
                      ? (state.chatDepth > notchStateStorage.chatDepth ? C.expand : C.collapse)
                      : (state.choosingChat ? C.open : C.close))
            : paste ? (state == .pasteNotFound ? WorkbenchTokens.Paste.open : WorkbenchTokens.Paste.close)
            : thinking ? (state == .quickThinking ? WorkbenchTokens.Thinking.open : WorkbenchTokens.Thinking.close)
            : (state == .silent ? WorkbenchTokens.Motion.close : (opening ? WorkbenchTokens.Motion.open : WorkbenchTokens.Referents.settle))
        cardChange = .state
        if state != .transcribing { stopTranscribing() }
        if state != .cancelled { undoTask?.cancel(); undoTask = nil }
        if state != .noSpeech { noSpeechTask?.cancel(); noSpeechTask = nil }
        if state != .pasteNotFound { dropPaste() }
        if state != .voiceError { dropVoiceError() }
        if state != .quickThinking { stopAgent() }
        if !state.choosingChat, notchStateStorage.choosingChat { stopChat() }
        let hoverPanel: (NotchState) -> Bool = { $0 == .agentPanel || $0 == .v2Board }
        if !hoverPanel(state), hoverPanel(notchStateStorage) { stopPanel() }
        // Coming to rest with the pointer already away, a hover may open the panel again (the
        // app's reducer re-arms in `rest()` the same way); with it on the notch, it must leave first.
        if state == .silent, panelZone == .outside { panelArmed = true }
        if state != .v2Chat { v2ChatHold?.cancel(); v2ChatHovered = false }
        // Play carries on through Transcribing and Choose chat, where it sends.
        if state != .v2Voice, state != .v2Transcribing, state != .v2Send { v2Play?.cancel() }
        if state != .v2Transcribing { v2Transcribe?.cancel() }
        if !state.collects { optionTurnedOn = nil }
        if state != .v2Board { v2BoardHold?.cancel() }
        // Another flow's bar does not carry Voiceflow's captures; they would come back later.
        // Choose chat does: they are the request's referents, to check before it goes.
        if let flow = state.flow, flow != .voiceflow, !state.keepsReferents, !referents.isEmpty {
            referents.removeAll()
            flights.removeAll()
            landing.removeAll()
            removing.removeAll()
        }
        // The glow starts from silence each time an agent voice bar opens.
        let glowing: (NotchState) -> Bool = { $0 == .dispatchVoice || $0 == .quickVoice || $0 == .v2Voice }
        if glowing(state), !glowing(notchStateStorage) { voiceGlow.reset() }
        notchStateStorage = state
        if let flow = state.flow { restingFlow = flow }
        if state.collects, !wasCollecting {
            listenStart = Date()
            startRecordingClock()
        }
        if !state.collects, wasCollecting { stopRecordingClock() }
        if state.listening { startMetering() } else { stopMetering() }
        if state == .silent {
            live?.sessionEnded()
            live?.director?.islandDidEmit(.rested)
        }
        if !state.collects {
            capturingStorage = false
            highlightingStorage = false
            highlightDraft = nil
            barNotice = nil
            selection = nil
            stackExpanded = false
            stackHovered = false
            inspectedId = nil
            hoveredReferent = nil
            if state == .silent { endSession() }
        }
    }

    var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Starts the meter once, on the edge into listening: a voice bar handing over to another
    /// keeps it running (starting the meter twice would leave its first sampler running).
    private func startMetering() {
        if snapshotMode {
            audioLevel = WorkbenchTokens.Island.snapshotLevel
            return
        }
        if let live, !previewing, !demoSamples {
            guard metering == nil else { return }
            metering = Task { [weak self] in
                let failure = await live.startListening { level in self?.audioLevel = level }
                guard let self, let failure else { return }
                self.voiceFailed(failure)
            }
            return
        }
        // The first run's microphone test feeds the level itself.
        if live?.director != nil, previewing, notchState == .voiceFlow { return }
        guard metering == nil else { return }
        metering = Task { [weak self] in
            guard let self, let levels = try? await self.meter.start() else { return }
            for await level in levels {
                if Task.isCancelled { break }
                self.audioLevel = level
            }
        }
    }

    private func stopMetering() {
        metering?.cancel()
        metering = nil
        meter.stop()
        audioLevel = 0
        // Fovea: into Transcribing the words are waited for (finishWords); anywhere else they go.
        if let live, notchState != .transcribing, notchState != .v2Transcribing {
            live.cancelListening()
        }
    }

    /// What View › Hide/Show Sidebar does.
    func toggleSidebar() {
        columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
    }

    /// Remembers the panel's visibility across launches. UserDefaults keys off the process
    /// name here: a bare SwiftPM executable has no bundle id.
    func rememberSidebar() {
        UserDefaults.standard.set(columnVisibility != .detailOnly, forKey: Self.sidebarKey)
    }

    /// Remembers what the display shows. Snapshots leave the choices alone.
    func rememberDisplay() {
        guard !snapshotMode else { return }
        let defaults = UserDefaults.standard
        defaults.set(appearance.rawValue, forKey: Self.appearanceKey)
        defaults.set(wallpaperChoice.key, forKey: Self.wallpaperKey)
        defaults.set(screenContent.rawValue, forKey: Self.screenKey)
    }

    /// Choose Image…: any picture on disk becomes the background.
    func chooseWallpaperFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a picture for the mock display."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        wallpaperChoice = .file(url)
    }
}

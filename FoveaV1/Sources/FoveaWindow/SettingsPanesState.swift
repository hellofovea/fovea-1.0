import AppKit
import AVFoundation
import SwiftUI
import CapturesCore
import FoveaKit
import FoveaPlatform

// Oct 15 review: the state of the Settings panes this pass rebuilt (Voice & Capture, Dictionary,
// Memory, Shortcuts, Connectors, Appearance's Motion, Eye Tracking), held apart from the window's
// model so each pane's file keeps its own. The model holds one (`CapturesModel.panes`). What's real
// is read from this Mac (microphones, displays, the agents' CLIs, Node, the space captures use,
// permissions); what 1.0 has no server for (memory, eye tracking) is simulated, and says so here.

@MainActor @Observable
final class PanesState {
    // MARK: Memory (ME-01, ME-02, ST-07, NH-03)

    /// Narrowed within what the browser shows: a source, a tag, an entity (ME-01.3).
    var memoryRefine = MemoryRefine()
    var memorySearch = ""
    /// Meaning search can answer (simulated: it's getting ready while new captures are organised,
    /// and search falls back to word matches, saying so: ME-01.2).
    var meaningSearchReady = true
    /// New captures being organised into memories, how many (simulated work: ME-01.4).
    var organising: Int?
    /// Captures up to here are organised; the ones the island adds after it are new.
    var organisedThrough = Date()
    @ObservationIgnored var organiseTask: Task<Void, Never>?
    /// The notch's notice named a memory that isn't there any more (NH-03): Recent, with a line.
    var memoryMissing = false
    /// A tag asked to be deleted, waiting for the person's yes (ME-01.5).
    var tagToDelete: String?
    /// The memory the list scrolls to.
    var memoryScrollTarget: String?
    /// Access Log (ST-07.3): what agents read, which kind is shown, when it was last read.
    var accessEvents: [AccessEvent] = AccessEvent.samples()
    var accessKind: AccessEvent.Kind?
    var accessChecked = Date()
    var accessRefreshing = false

    // MARK: Dictionary (DI-01, FR-30)

    /// Each word's other spellings and whether it's on, by the word's id (kept beside the
    /// dictionary until `DictionaryWord` holds them: see `WordExtrasFile`).
    var wordExtras: [String: WordExtras] = [:]
    @ObservationIgnored var extrasFile: URL?
    var dictionarySearch = ""
    var editingWord: WordDraft?
    var importing = false

    // MARK: Voice & Capture (ST-04, HI-01.5, ST-07.2, ST-07.4)

    /// The microphones on this Mac, read from the system (ST-04.1).
    var microphones: [Microphone] = []
    var systemMicrophone: String?
    /// The one chosen, by its id and name; nil is the system default.
    var microphoneID: String?
    var microphoneName: String?
    /// What captures take on this Mac: captures.json and their pictures (HI-01.5).
    var captureBytes: Int64?
    var choosingApp = false
    var confirmClear = false

    // MARK: Shortcuts (ST-03)

    /// The shortcut being recorded, the keys held so far, and a chord waiting on a clash.
    var recording: String?
    var heldCaps: [String] = []
    var recordingHint: String?
    var pending: PendingChord?
    var confirmResetAll = false
    @ObservationIgnored let listener = ChordListener()

    // MARK: Permissions (ST-07.4): a stage shows one missing.

    var stagedMissing: Set<Permission> = []

    // MARK: Connectors (ST-05.2, ST-06)

    var agents: [AgentCLI: AgentCheckResult] = [:]
    var checkingAgents = false
    var agentsChecked: Date?
    /// A review stage set the agents' states: a check doesn't overwrite them until Check Again.
    var agentsStaged = false
    var node: NodeInstall?
    var nodeChecked = false
    var serverSetUp: Set<AgentCLI> = []
    var mcpStage: MemoryServerState?
    var setupDetailsOpen = false
    var copied: String?

    // MARK: Eye tracking (ST-08): simulated, after the person's own session.

    var eyeTrackingOn = true
    var cameraName: String?
    var cameraChecked = false
    var stagedNoCamera = false
    var pasteWhereYouLook = true
    var showGaze = false
    var gazeDisplay = ""
    var calibrating = false
    var testing = false
    var calibratedAt: Date?

    // MARK: Connectors: checks

    /// Checks both agents, Node and the memory server, off the main thread (`AgentCheck`).
    func checkAgents(force: Bool = false) async {
        guard !checkingAgents else { return }
        if agentsStaged && !force { return }
        agentsStaged = false
        checkingAgents = true
        async let claude = AgentCheck.check(.claude)
        async let codex = AgentCheck.check(.codex)
        async let node = AgentCheck.node()
        let results = await [claude, codex]
        let found = await node
        let setUp = await Task.detached { AgentCheck.memoryServerSetUp() }.value
        guard !agentsStaged else { checkingAgents = false; return }
        for r in results { agents[r.agent] = r }
        self.node = found
        nodeChecked = true
        serverSetUp = setUp
        agentsChecked = Date()
        checkingAgents = false
    }

    /// A command on the clipboard, and the button that copied it says so a moment.
    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = text
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            if self.copied == text { self.copied = nil }
        }
    }

    // MARK: Microphones

    func readMicrophones() {
        microphones = Microphone.all()
        systemMicrophone = AVCaptureDevice.default(for: .audio)?.localizedName
    }

    // MARK: Eye tracking

    func readCamera() {
        let video = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
                                                     mediaType: .video, position: .unspecified)
        cameraName = video.devices.first?.localizedName
        cameraChecked = true
        if gazeDisplay.isEmpty { gazeDisplay = NSScreen.screens.first?.localizedName ?? "" }
    }
}

/// A microphone on this Mac.
struct Microphone: Identifiable, Hashable {
    let id: String
    let name: String

    /// Every audio input macOS lists: the built-in one, a USB or Bluetooth one, an iPhone.
    static func all() -> [Microphone] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone, .external], mediaType: .audio, position: .unspecified)
            .devices.map { Microphone(id: $0.uniqueID, name: $0.localizedName) }
    }
}

/// The memory server's state, as a stage shows it (ST-06.1).
enum MemoryServerState: Equatable { case notSetUp, setUp, unavailable }

// MARK: - The model's

extension CapturesModel {
    /// Fovea's folder on this Mac (`--data-dir` or Application Support): where captures.json,
    /// media/ and dictionary.json are.
    var foveaFolder: URL? { dataFolder ?? media?.directory.deletingLastPathComponent() }

    /// Whether the person's motion choice reduces it, the Mac's setting counted where it's asked
    /// to be (IS02).
    static func reduces(_ preference: MotionPreference, harness: Bool) -> Bool {
        switch preference {
        case .reduce: return true
        case .full: return harness
        case .system: return harness || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }
    }
}

// MARK: - Review stages

extension HomeWindowController {
    /// Oct 15 review: every state of Voice & Capture, Dictionary, Memory, Shortcuts, Connectors,
    /// Appearance and Eye Tracking that using the app wouldn't show on demand, on the Review menu
    /// (FoveaKit/Review.swift). Call once from `init`, after the model is made:
    /// `Self.registerSettingsPaneStages(model: model) { [weak self] in self?.show() }`.
    /// `show` brings the window forward; without it, the window titled Fovea is.
    static func registerSettingsPaneStages(model: CapturesModel, show: (@MainActor () -> Void)? = nil) {
        func open(_ category: String, part: String? = nil) {
            if let show { show() } else {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first { $0.title == "Fovea" && $0.contentViewController != nil }?.makeKeyAndOrderFront(nil)
            }
            model.browsingMemories = false
            model.accessLogShown = false
            model.panes.editingWord = nil
            model.panes.importing = false
            model.panes.choosingApp = false
            model.panes.calibrating = false
            model.panes.testing = false
            model.show(.settings)
            if let c = SettingsCategory(rawValue: category) ?? (category == "dictionary" ? .memory : nil) {
                model.openSettings(c)
            }
            if let part {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.5))
                    model.scrollTarget = nil
                    model.scrollTarget = part
                }
            }
        }
        func later(_ seconds: Double = 0.45, _ body: @escaping @MainActor () -> Void) {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(seconds))
                body()
            }
        }
        let p = model.panes

        // Memory.
        Review.stage("ME-01.1", "Memory browser: one source", area: .settings) {
            open("memory")
            later {
                p.memoryRefine = MemoryRefine(); p.memorySearch = ""
                let source = MemoryOrigins.sources(model.library.memories).first?.name ?? "Mail"
                model.memoryFilter = .source(source)
                model.memorySelection = []
                model.browsingMemories = true
            }
        }
        Review.stage("ME-01.2", "Memory search: word matches while meaning search gets ready", area: .settings) {
            open("memory")
            later {
                model.memoryFilter = .recent; p.memoryRefine = MemoryRefine()
                p.meaningSearchReady = false
                p.memorySearch = "notch"
                model.browsingMemories = true
            }
        }
        Review.stage("ME-01.3", "Memory browser: filtered by an entity", area: .settings) {
            open("memory")
            later {
                model.memoryFilter = .recent; p.memorySearch = ""
                p.memoryRefine = MemoryRefine(entity: "Lin")
                model.memorySelection = ["m-lin"]
                model.browsingMemories = true
            }
        }
        Review.stage("ME-01.4", "Memory: organising new captures", area: .settings) {
            open("memory", part: "memory-all")
            later { model.organise(12) }
        }
        Review.stage("ME-01.5", "Memory browser: several selected", area: .settings) {
            open("memory")
            later {
                model.memoryFilter = .recent; p.memoryRefine = MemoryRefine(); p.memorySearch = ""
                let ids = model.library.memories.filter { $0.deleted == nil }.sorted { $0.date > $1.date }.prefix(3).map(\.id)
                model.memorySelection = Set(ids)
                model.browsingMemories = true
            }
        }
        Review.stage("ME-01.5", "Memory browser: Recently Deleted", area: .settings) {
            open("memory")
            later {
                model.memoryFilter = .deleted; p.memoryRefine = MemoryRefine(); p.memorySearch = ""
                model.memorySelection = Set(model.library.memories.filter { $0.deleted != nil }.prefix(1).map(\.id))
                model.browsingMemories = true
            }
        }
        Review.stage("ME-01.5", "Memory browser: deleting a tag asks first", area: .settings) {
            open("memory")
            later {
                model.memoryFilter = .tag("Dinner"); p.memoryRefine = MemoryRefine(); p.memorySearch = ""
                model.browsingMemories = true
                later(0.6) { p.tagToDelete = "Dinner" }
            }
        }
        Review.stage("ME-02", "Memory detail: where it came from", area: .settings) {
            open("memory")
            later { model.openMemory("m-hero") }
        }
        Review.stage("NH-03", "A memory the notch named, gone: back to Recent", area: .settings) {
            open("memory")
            later { model.openMemory("m-not-here") }
        }
        Review.stage("ST-07.1", "Memory: Memory Link off (paused)", area: .settings) {
            open("memory", part: "memory-about")
            later { model.animate(.swap) { model.prefs.memoryLink = false } }
        }
        Review.stage("ST-07.3", "Access Log", area: .settings) {
            open("memory")
            later {
                if p.accessEvents.isEmpty { p.accessEvents = AccessEvent.samples() }
                p.accessKind = nil
                model.accessLogShown = true
            }
        }
        Review.stage("ST-07.3", "Access Log: nothing read yet", area: .settings) {
            open("memory")
            later { p.accessEvents = []; p.accessKind = nil; model.accessLogShown = true }
        }

        // Dictionary.
        Review.stage("DI-01.2", "Dictionary: editing a word", area: .settings) {
            open("dictionary")
            later {
                model.signedOut = false
                let word = model.library.dictionary.first { $0.heardAs != nil } ?? model.library.dictionary.first
                p.editingWord = word.map { WordDraft($0, extras: p.wordExtras[$0.id]) } ?? WordDraft.new()
            }
        }
        Review.stage("DI-01.3", "Dictionary: signed out (read-only)", area: .settings) {
            open("dictionary")
            later { model.signedOut = true }
        }
        Review.stage("DI-01.3", "Dictionary: signed in again", area: .settings) {
            open("dictionary")
            later { model.signedOut = false }
        }
        Review.stage("FR-30", "Dictionary: Import words", area: .settings) {
            open("dictionary")
            later { model.signedOut = false; p.importing = true }
        }

        // Voice & Capture.
        Review.stage("ST-04.1", "Voice: the chosen microphone isn't connected", area: .settings) {
            open("voice")
            later { p.microphoneID = "staged-missing"; p.microphoneName = "AirPods Pro" }
        }
        Review.stage("ST-07.2", "Never capture in: choosing an app", area: .settings) {
            open("voice", part: "capture")
            later(0.8) { p.choosingApp = true }
        }
        Review.stage("HI-01.5", "Voice: Clear History asks first", area: .settings) {
            open("voice", part: "history")
            later(0.8) { p.confirmClear = true }
        }
        Review.stage("ST-07.4", "Permissions: Microphone and Screen Recording not allowed", area: .settings) {
            open("voice", part: "permissions")
            later { p.stagedMissing = [.microphone, .screenRecording] }
        }
        Review.stage("ST-07.4", "Permissions: as this Mac has them", area: .settings) {
            open("voice", part: "permissions")
            later { p.stagedMissing = [] }
        }

        // Shortcuts.
        Review.stage("ST-03.1", "Shortcuts: recording Dispatch", area: .settings) {
            open("shortcuts")
            later { model.startRecording(FoveaKeys.dispatch.id) }
        }
        Review.stage("ST-03.2", "Shortcuts: a clash with Spotlight", area: .settings) {
            open("shortcuts")
            later { model.offer(KeyChord(modifiers: ["⌘"], keyCode: 49, keyCap: "Space"), for: FoveaKeys.dispatch.id) }
        }
        Review.stage("ST-03.2", "Shortcuts: a clash with another shortcut", area: .settings) {
            open("shortcuts")
            later { model.offer(KeyChord(modifiers: ["fn", "⌃"]), for: FoveaKeys.voiceflow.id) }
        }
        Review.stage("ST-03.2", "Shortcuts: one changed, Reset to Default", area: .settings) {
            open("shortcuts")
            later { model.save(KeyChord(modifiers: ["right ⌥"]), for: FoveaKeys.voiceflow.id) }
        }
        Review.stage("ST-03.1", "Shortcuts: Accessibility not allowed", area: .settings) {
            open("shortcuts")
            later { p.stagedMissing = [.accessibility] }
        }

        // Connectors.
        func agents(_ claude: AgentCheckResult.State, _ codex: AgentCheckResult.State = .ready) {
            open("connectors")
            later {
                p.agentsStaged = true
                p.agents[.claude] = AgentCheckResult(agent: .claude, state: claude,
                                                     path: claude == .notInstalled ? nil : "/Users/you/.local/bin/claude",
                                                     version: claude == .notInstalled ? nil : "2.1.92",
                                                     account: claude == .ready ? "you@example.com" : nil)
                p.agents[.codex] = AgentCheckResult(agent: .codex, state: codex,
                                                    path: codex == .notInstalled ? nil : "/opt/homebrew/bin/codex",
                                                    version: codex == .notInstalled ? nil : "0.47.0",
                                                    account: codex == .ready ? "ChatGPT" : nil)
                p.agentsChecked = Date()
            }
        }
        Review.stage("ST-05.2", "Agents: both ready", area: .settings) { agents(.ready) }
        Review.stage("ST-05.2", "Agents: Claude Code not installed", area: .settings) { agents(.notInstalled) }
        Review.stage("ST-05.2", "Agents: Claude Code not signed in", area: .settings) { agents(.notSignedIn) }
        Review.stage("ST-05.2", "Agents: Claude Code's sign-in expired", area: .settings) { agents(.signInExpired) }
        Review.stage("ST-05.2", "Agents: couldn't check Codex", area: .settings) {
            let codex = "Codex", seconds = 6  // Oct 18, Ryan: in the primary language, as AgentCheck writes it.
            agents(.ready, .couldntCheck(L("\(codex) didn't answer within \(seconds) seconds.")))
        }
        Review.stage("ST-05.2", "Agents: as this Mac has them", area: .settings) {
            open("connectors")
            later { Task { await p.checkAgents(force: true) } }
        }
        Review.stage("ST-06.1", "Memory for your agents: not set up", area: .settings) {
            open("connectors", part: "memory-agents")
            later { p.mcpStage = .notSetUp }
        }
        Review.stage("ST-06.1", "Memory for your agents: set up", area: .settings) {
            open("connectors", part: "memory-agents")
            later { p.mcpStage = .setUp }
        }
        Review.stage("ST-06.1", "Memory for your agents: unavailable (no Node)", area: .settings) {
            open("connectors", part: "memory-agents")
            later { p.mcpStage = .unavailable }
        }
        Review.stage("ST-06.2", "Memory for your agents: setup details", area: .settings) {
            open("connectors", part: "memory-agents")
            later { p.mcpStage = .notSetUp; p.setupDetailsOpen = true }
        }

        // Appearance.
        Review.stage("IS02", "Appearance: Motion set to Reduce", area: .settings) {
            open("appearance")
            later { model.animate(.swap) { model.prefs.motion = .reduce } }
        }

        // Eye tracking.
        Review.stage("ST-08.1", "Eye tracking: following the dots", area: .settings) {
            open("eyeTracking", part: "eye-beta")
            later { model.prefs.gaze = .downloaded; model.openCollector() }
        }
        Review.stage("ST-08.1", "Eye tracking: review, then send", area: .settings) {
            open("eyeTracking", part: "eye-beta")
            later { model.play?.cancel(); model.animate(.swap) { model.prefs.gaze = .reviewing } }
        }
        Review.stage("ST-08.1", "Eye tracking: after your session", area: .settings) {
            open("eyeTracking", part: "eye-controls")
            later { p.stagedNoCamera = false; model.play?.cancel(); model.animate(.swap) { model.prefs.gaze = .collected } }
        }
        Review.stage("ST-08.1", "Eye tracking: no camera (not connected)", area: .settings) {
            open("eyeTracking", part: "eye-controls")
            later { p.stagedNoCamera = true; model.play?.cancel(); model.animate(.swap) { model.prefs.gaze = .collected } }
        }
        Review.stage("ST-08.2", "Eye tracking: Calibrate…", area: .settings) {
            open("eyeTracking")
            later { model.play?.cancel(); model.prefs.gaze = .collected; p.calibrating = true }
        }
        Review.stage("ST-08.2", "Eye tracking: Test…", area: .settings) {
            open("eyeTracking")
            later { model.play?.cancel(); model.prefs.gaze = .collected; p.testing = true }
        }
        Review.stage("ST-08.1", "Eye tracking: before your session", area: .settings) {
            open("eyeTracking")
            later { model.play?.cancel(); model.animate(.swap) { model.prefs.gaze = .idle } }
        }
    }
}

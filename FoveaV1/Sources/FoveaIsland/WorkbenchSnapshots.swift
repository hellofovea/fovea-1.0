import SwiftUI
import FoveaCore
import AppKit
import FoveaKit

/// `FoveaWorkbench --snapshot <dir>` captures the live window as composited on screen, chrome
/// and materials included, in both appearances and with the panel collapsed, then exits.
@MainActor
enum WorkbenchSnapshots {
    struct Shot {
        var name: String
        var dark: Bool
        let sidebar: Bool
        /// The notch's design (docs/island/NATIVE.md), and in Native, whether what drops below
        /// hangs from the top edge with the island or floats under the notch.
        var design: NotchDesign = .original
        var panels: NativePanels = .attached
        var appearance: MockAppearance = .system
        var screen: MockScreenContent = .desktop
        var notch: NotchState = .silent
        /// Captures taken from Safari's tabs before the shot, and how the stack shows them.
        var referents = 0
        var shape: ReferentShape = .roundedRectangle
        var expanded = false
        var peek = false
        var capturing = false
        var selection: CGRect? = nil
        /// A capture looked at closely, and one under the pointer (its ✕ showing), by index.
        var inspect: Int? = nil
        var hover: Int? = nil
        /// Transcribing, or the undo window after a cancel.
        var transcribing = false
        var cancelled = false
        var noSpeech = false
        /// Paste not found, closed to its first lines or opened to the whole transcript.
        var paste = false
        var pasteExpanded = false
        /// An agent voice bar (Dispatch's or Quick actions'), or Thinking in a layout.
        var agentVoice: NotchState? = nil
        var thinking = false
        var activity: ActivityLayout = .under
        /// The agent's action, staged mid-way with what it draws on the screen.
        var action: AgentAction? = nil
        /// The glow's colors.
        var palette: GlowPalette = .colorful
        var hue: Double = 0
        var spread: Double = WorkbenchTokens.VoiceGlow.defaultSpread
        /// Dispatch's Choose chat at a level, the agent the rail shows, the project open, and the
        /// edge case staged.
        var chats: ChatLevel? = nil
        var chatAgent: String? = nil
        var chatProject: String? = nil
        var chatCase: ChatCase = .usual
        /// Send pressed, for the sending cases.
        var chatSend = false
        /// Dispatch's Agent panel: on its own, or just after Send from Choose chat.
        var panel = false
        var panelSent = false
        /// The rows' style.
        var panelStyle: PanelStyle = .ledger
        /// Leave out this project's tasks, to show the rows under it.
        var panelSkip: String? = nil
        /// Dispatch Version 2: a state, for a request.
        var v2: V2Mode? = nil
        var v2Request: V2Request = .code
        /// Choose chat with a passage and a file taken too; with every chat open.
        var v2Mixed = false
        var v2Browse = false
        /// The cards' fan runs 0.65 s with its stagger.
        var settle: TimeInterval = WorkbenchTokens.Snapshot.settle
        /// A Feedback tab (Oct 6), its choices set before it is staged, and a touch after.
        var feedback: FeedbackItem? = nil
        var prepare: ((WorkbenchModel) -> Void)? = nil
        var after: ((WorkbenchModel) -> Void)? = nil
    }

    /// Regions captured from each tab, in display points.
    static let captureRegions: [CGRect] = [
        CGRect(x: 430, y: 225, width: 610, height: 320),   // the article's photograph
        CGRect(x: 770, y: 300, width: 425, height: 262),   // a photograph in the gallery
        CGRect(x: 372, y: 160, width: 726, height: 190),   // the notes' heading and intro
        CGRect(x: 300, y: 200, width: 710, height: 260),   // lines of code
    ]

    static let baseShots: [Shot] = [
        Shot(name: "workbench-light", dark: false, sidebar: true),
        Shot(name: "workbench-dark", dark: true, sidebar: true),
        Shot(name: "workbench-collapsed", dark: false, sidebar: false),
        // The panel's appearance choice: a dark display in a light window.
        Shot(name: "workbench-stage-dark", dark: false, sidebar: true, appearance: .dark),
        // An app full screen: no menu bar, no Dock, the black band beside the notch.
        Shot(name: "workbench-fullscreen", dark: false, sidebar: true, screen: .fullScreenApp),
        // Voice flow: the Listening Flowing Bar under the notch, one fixed frame of the waveform.
        Shot(name: "workbench-voice", dark: false, sidebar: true, notch: .voiceFlow),
        // Capture mode: a region being drawn over the page, the bar open with three captures.
        Shot(name: "workbench-capture", dark: false, sidebar: true, screen: .fullScreenApp, notch: .voiceFlow,
             referents: 3, capturing: true, selection: CGRect(x: 430, y: 225, width: 610, height: 320)),
    ]
    static let shapeShots: [Shot] = ReferentShape.allCases.flatMap { shape in [
        // Each shape, collapsed in the bar and opened.
        Shot(name: "workbench-stack-\(shape.rawValue)", dark: false, sidebar: true, screen: .fullScreenApp,
             notch: .voiceFlow, referents: 3, shape: shape),
        Shot(name: "workbench-stack-\(shape.rawValue)-open", dark: false, sidebar: true, screen: .fullScreenApp,
             notch: .voiceFlow, referents: 5, shape: shape, expanded: true, settle: 1.1),
    ] }
    static let stackShots: [Shot] = [
        // The pointer on the stack: it fans to the right.
        Shot(name: "workbench-stack-peek", dark: false, sidebar: true, screen: .fullScreenApp, notch: .voiceFlow,
             referents: 3, peek: true, settle: 1.0),
        // Opened, the pointer on the second capture: it grows a little and shows its ✕.
        Shot(name: "workbench-stack-hover", dark: false, sidebar: true, screen: .fullScreenApp, notch: .voiceFlow,
             referents: 5, expanded: true, hover: 1, settle: 1.1),
        // A close look at the first capture.
        Shot(name: "workbench-stack-inspect", dark: false, sidebar: true, screen: .fullScreenApp, notch: .voiceFlow,
             referents: 5, expanded: true, inspect: 0, settle: 1.1),
    ]
    static let voiceShots: [Shot] = [
        // "Thinking" and its ellipsis over the 4 pt line filling; the undo window's line draining.
        Shot(name: "workbench-transcribing", dark: false, sidebar: true, screen: .fullScreenApp, transcribing: true),
        Shot(name: "workbench-cancelled", dark: false, sidebar: true, screen: .fullScreenApp, cancelled: true),
        Shot(name: "workbench-no-speech", dark: false, sidebar: true, screen: .fullScreenApp, noSpeech: true),
        // Nowhere to paste: the transcript's first lines, ✕, the chevron, Copy, the line draining.
        Shot(name: "workbench-paste-not-found", dark: false, sidebar: true, screen: .fullScreenApp, paste: true),
        Shot(name: "workbench-paste-expanded", dark: false, sidebar: true, screen: .fullScreenApp, paste: true,
             pasteExpanded: true, settle: 0.9),
        Shot(name: "workbench-paste-desktop", dark: false, sidebar: true, paste: true),
    ]

    /// Dispatch Version 2's aura alone (no referents), full screen and on the desktop, and its
    /// colors from the Voice glow section.
    static let glowShots: [Shot] = [
        Shot(name: "workbench-glow", dark: false, sidebar: true, screen: .fullScreenApp, agentVoice: .v2Voice),
        Shot(name: "workbench-glow-desktop", dark: false, sidebar: true, agentVoice: .v2Voice),
        Shot(name: "workbench-glow-ocean", dark: false, sidebar: true, screen: .fullScreenApp, agentVoice: .v2Voice,
             palette: .ocean),
        Shot(name: "workbench-glow-custom", dark: false, sidebar: true, screen: .fullScreenApp, agentVoice: .v2Voice,
             palette: .custom, hue: 150, spread: 60),
    ]
    /// Dispatch Version 2: each state; Choose chat with every kind of taken thing and with
    /// every chat open; the result in each of its shapes.
    static let v2Shots: [Shot] = [
        Shot(name: "workbench-v2-voice", dark: false, sidebar: true, screen: .fullScreenApp, v2: .voice),
        Shot(name: "workbench-v2-transcribe", dark: false, sidebar: true, screen: .fullScreenApp, v2: .transcribe),
        Shot(name: "workbench-v2-send", dark: false, sidebar: true, screen: .fullScreenApp, v2: .send, v2Mixed: true),
        Shot(name: "workbench-v2-send-browse", dark: false, sidebar: true, screen: .fullScreenApp, v2: .send, v2Browse: true),
        Shot(name: "workbench-v2-board", dark: false, sidebar: true, screen: .fullScreenApp, v2: .board),
        Shot(name: "workbench-v2-chat-formula", dark: false, sidebar: true, screen: .fullScreenApp, v2: .chat, v2Request: .formula),
        Shot(name: "workbench-v2-chat-calendar", dark: false, sidebar: true, screen: .fullScreenApp, v2: .chat, v2Request: .calendar),
        Shot(name: "workbench-v2-chat-draft", dark: false, sidebar: true, screen: .fullScreenApp, v2: .chat, v2Request: .draft),
        Shot(name: "workbench-v2-chat-code", dark: false, sidebar: true, screen: .fullScreenApp, v2: .chat),
        Shot(name: "workbench-v2-pulled", dark: false, sidebar: true, v2: .pulled, v2Request: .calendar),
        // Oct 7 (docs/island/WHOLE_SESSION.md): the session expanded, the whole session in the
        // centred column. One exchange (as tall as it is); four, with the outline of the requests;
        // what the agent did, opened; many requests; the outline's card open.
        Shot(name: "workbench-v2-expanded", dark: false, sidebar: true, screen: .fullScreenApp, v2: .chat,
             after: { $0.v2Size = .expanded }),
        Shot(name: "workbench-v2-expanded-session", dark: false, sidebar: true, screen: .fullScreenApp, v2: .whole),
        Shot(name: "workbench-v2-expanded-work", dark: false, sidebar: true, screen: .fullScreenApp, v2: .whole,
             after: { m in if let id = m.v2Focus { m.v2StepsOpen.insert(id) } }),
        Shot(name: "workbench-v2-expanded-long", dark: false, sidebar: true, screen: .fullScreenApp, v2: .wholeLong),
        Shot(name: "workbench-v2-expanded-outline", dark: false, sidebar: true, screen: .fullScreenApp, v2: .wholeLong,
             after: { $0.v2OutlineShown = true }),
        // Its ‹, pressed: the control board.
        Shot(name: "workbench-v2-expanded-exit", dark: false, sidebar: true, screen: .fullScreenApp, v2: .wholeLong,
             after: { $0.exitV2ToBoard() }),
    ]

    /// The Feedback tabs (Oct 6): each item, and each of its variations.
    static let feedbackShots: [Shot] = {
        func shot(_ name: String, _ item: FeedbackItem, screen: MockScreenContent = .fullScreenApp, settle: TimeInterval = 0.9,
                  expanded: Bool = false,
                  prepare: ((WorkbenchModel) -> Void)? = nil, after: ((WorkbenchModel) -> Void)? = nil) -> Shot {
            Shot(name: "fb-\(name)", dark: false, sidebar: true, screen: screen, expanded: expanded, settle: settle, feedback: item,
                 prepare: prepare, after: after)
        }
        var shots: [Shot] = [
            shot("01-choose-chat", .modelEffort),
            shot("01-model-open", .modelEffort, prepare: { $0.feedbackModelStage = .open }),
            shot("03-highlight-text", .textFiles, prepare: { $0.feedbackSelectStage = .highlighting }),
            shot("03-highlight-file", .textFiles, screen: .desktop, prepare: { $0.feedbackSelectStage = .file }),
            shot("03-stack", .textFiles, prepare: { $0.feedbackSelectStage = .stack }),
            shot("03-opened", .textFiles, settle: 1.4, expanded: true, prepare: { $0.feedbackSelectStage = .opened }),
            shot("04-last-minute", .countdown, prepare: { $0.feedbackCountdownStage = .lastMinute }),
            shot("04-last-seconds", .countdown, prepare: { $0.feedbackCountdownStage = .lastSeconds }),
            shot("06-split-view", .splitView, screen: .splitView, after: { $0.splitTargetOverride = .right }),
            shot("06-split-landed", .splitView, screen: .splitView, after: {
                $0.splitPasted[.right] = WorkbenchModel.sampleTranscript
                $0.pasteLanding = Date()
                $0.notchState = .silent
            }),
            shot("07-landing", .landing),
            shot("15-titles", .titles),
            shot("19-review-off", .skipReview, prepare: { $0.v2Request = .code }),
            shot("19-route-open", .skipReview, prepare: { $0.v2Request = .code; $0.feedbackRouteOpen = true }),
            shot("09-board", .progress),
            shot("09-board-opened", .progress, after: { $0.openV2("t-snapshots") }),
            shot("16-steps-session", .steps, prepare: { $0.feedbackStepsStage = .session }),
            shot("16-steps-board", .steps, prepare: { $0.feedbackStepsStage = .board }),
            shot("09-board-end", .progress, after: { $0.v2ScrollTarget = "t-docs" }),
            shot("09-chat-working", .answer, prepare: { $0.v2Request = .code; $0.feedbackWorkStage = .working }),
            shot("23-working", .reanswer, prepare: { $0.v2Request = .code; $0.feedbackWorkStage = .working }),
            shot("23-done", .reanswer, prepare: { $0.v2Request = .code; $0.feedbackWorkStage = .done }),
            shot("24-queued", .queue, prepare: { $0.feedbackQueueStage = .queued }),
            shot("24-paused", .queue, prepare: { $0.feedbackQueueStage = .paused }),
        ]
        for error in VoiceError.allCases {
            shots.append(shot("02-\(error.rawValue)", .errors, prepare: { $0.feedbackErrorChoice = error }))
        }
        for request in V2Request.allCases {
            shots.append(shot("11-\(request.rawValue)", .answer, prepare: {
                $0.v2Request = request
                $0.feedbackWorkStage = .done
            }))
        }
        shots.append(shot("11-expanded", .answer, prepare: {
            $0.v2Request = .code
            $0.feedbackWorkStage = .done
        }, after: { m in
            if let id = m.v2Focus { m.v2StepsOpen.insert(id) }
            m.v2Expanded = true
        }))
        shots.append(shot("11-steps-open", .answer, prepare: {
            $0.v2Request = .code
            $0.feedbackWorkStage = .done
        }, after: { m in if let id = m.v2Focus { m.v2StepsOpen.insert(id) } }))
        return shots
    }()

    static var shots: [Shot] {
        // The workbench's two flows: Voiceflow, and Dispatch Version 2 with its aura; the feedback;
        // and all of it again in the Native design, Light and Dark.
        baseShots + shapeShots + stackShots + voiceShots + glowShots + v2Shots + feedbackShots + nativeShots
    }

    /// The Native design (docs/island/NATIVE.md): every Voiceflow and Dispatch shot again, the mock
    /// display Light and then Dark, named `native-light-…` and `native-dark-…`, the panels attached;
    /// then the states with a panel again with the panels floating, `native-floating-light-…`.
    /// Glass is drawn only when the window is captured (not with `FOVEA_OFFSCREEN`), so these need
    /// the screen unlocked.
    static var nativeShots: [Shot] {
        let flows = baseShots.filter { ["workbench-voice", "workbench-capture"].contains($0.name) }
            + stackShots + voiceShots + Array(glowShots.prefix(1)) + v2Shots + feedbackShots
        // The states whose content drops below the notch, where the two kinds of panel differ.
        let floating = ["paste-not-found", "stack-inspect", "v2-send", "v2-board", "v2-chat-code", "v2-expanded",
                        "fb-02-offline", "fb-09-board-wings", "fb-09-board-pet-desk", "fb-19-route-open"]
        func bare(_ name: String) -> String {
            name.hasPrefix("workbench-") ? String(name.dropFirst("workbench-".count)) : name
        }
        // And on the desktop, under the menu bar, where an attached panel's ears meet it.
        let desktop = ["v2-voice", "v2-send", "v2-board", "v2-chat-code", "fb-02-offline"]
        func native(_ original: Shot, _ appearance: MockAppearance, _ panels: NativePanels, onDesktop: Bool = false) -> Shot {
            var shot = original
            let bare = bare(original.name)
            shot.name = "native-\(panels == .floating ? "floating-" : "")\(onDesktop ? "desktop-" : "")\(appearance.rawValue)-\(bare)"
            if onDesktop { shot.screen = .desktop }
            shot.design = .native
            shot.panels = panels
            shot.appearance = appearance
            shot.dark = appearance == .dark
            return shot
        }
        return [MockAppearance.light, .dark].flatMap { appearance in flows.map { native($0, appearance, .attached) } }
            + [MockAppearance.light, .dark].flatMap { appearance in
                flows.filter { floating.contains(bare($0.name)) }.map { native($0, appearance, .floating) }
            }
            + [NativePanels.attached, .floating].flatMap { panels in
                [MockAppearance.light, .dark].flatMap { appearance in
                    flows.filter { desktop.contains(bare($0.name)) }.map { native($0, appearance, panels, onDesktop: true) }
                }
            }
    }

    static func runIfRequested(model: WorkbenchModel) {
        guard let dir = model.options.snapshotDirectory else { return }
        Task { @MainActor in
            // The scene's window appears once launching has settled.
            var waited = 0
            while sceneWindow == nil, waited < 30 {
                try? await Task.sleep(for: .milliseconds(100))
                waited += 1
            }
            run(dir: dir, model: model)
            NSApp.terminate(nil)
        }
    }

    private static var sceneWindow: NSWindow? {
        NSApp.windows.first { $0.styleMask.contains(.titled) }
    }

    private static func run(dir: URL, model: WorkbenchModel) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let window = sceneWindow else { print("no window to snapshot"); return }
        window.setContentSize(WorkbenchTokens.Snapshot.size)
        let filter = model.options.snapshotFilter
        if filter == nil { writeSheet(LassoSheet(), named: "workbench-lasso", to: dir) }
        // `--only a,b`: the shots whose names contain any of them.
        let parts = filter.map { $0.split(separator: ",").map(String.init) }
        for shot in shots where parts.map({ $0.contains { shot.name.contains($0) } }) ?? true {
            // SwiftUI owns the window's appearance; the app-wide one is what it follows.
            let appearance = NSAppearance(named: shot.dark ? .darkAqua : .aqua)
            NSApp.appearance = appearance
            window.appearance = appearance
            model.columnVisibility = shot.sidebar ? .all : .detailOnly
            model.design = shot.design
            model.nativePanels = shot.panels
            // Every shot starts from the board's scroll at the top, and Choose chat's browser closed
            // with nothing picked.
            model.v2ScrollTarget = V2BoardList.topID
            model.v2Browsing = false
            model.v2BrowseAgent = ChatBook.predictedAgent
            model.v2PickStorage = nil
            model.appearance = shot.appearance
            model.screenContent = shot.screen
            model.notchState = shot.notch
            model.setExpanded(false)
            model.setStackHovered(false)
            model.hoveredReferent = nil
            model.capturing = false
            model.selection = nil
            if shot.referents > 0, model.referents.count != shot.referents {
                takeReferents(shot.referents, model: model, window: window)
            }
            model.referentShape = shot.shape
            model.capturing = shot.capturing
            model.selection = shot.selection
            if shot.transcribing { model.startTranscribing() }
            if shot.cancelled { model.playCancelled() }
            if shot.noSpeech { model.showNoSpeech() }
            if shot.paste { model.showPasteNotFound() }
            model.glowPalette = shot.palette
            model.glowHue = shot.hue
            model.glowSpread = shot.spread
            if let voice = shot.agentVoice { model.notchState = voice }
            if let level = shot.chats {
                model.clearReferents()
                model.chatCase = shot.chatCase
                model.showChooseChat(level)
                if let agent = shot.chatAgent { model.setChatAgent(agent) }
                if let project = shot.chatProject { model.openProject(project) }
                if shot.chatSend { model.sendChat() }
            }
            if let mode = shot.v2 {
                model.agentTasks = AgentBoard.tasks
                model.v2Request = shot.v2Request
                model.v2Selection = mode
                if shot.v2Mixed {
                    let rect = CGRect(x: 600, y: 400, width: 200, height: 60)
                    model.attachText(ArticlePage.opening[0], from: rect, animated: false)
                    if let file = DesktopFile.all.first { model.attachFile(file, from: rect, animated: false) }
                    model.capturedFlash = nil
                }
                if shot.v2Browse {
                    model.toggleV2Browse()
                }
                // A touch after (a session's size, the outline open).
                if shot.feedback == nil { shot.after?(model) }
            }
            if let item = shot.feedback {
                model.resetFeedback()
                shot.prepare?(model)
                model.stageFeedback(item)
                settle(window)
                shot.after?(model)
            }
            if shot.panel {
                model.agentTasks = AgentBoard.tasks.filter { $0.project != shot.panelSkip }
                model.panelStyle = shot.panelStyle
                if shot.panelSent {
                    model.clearReferents()
                    model.chatCase = .usual
                    model.showChooseChat(.closed)
                    model.sendChat()
                } else {
                    model.showAgentPanel(pinned: true)
                }
            }
            model.activityLayout = shot.activity
            if shot.thinking {
                if let action = shot.action {
                    model.selectTab(WorkbenchModel.tab(for: action))
                    model.scrollReset += 1
                }
                model.showThinking()
                if let action = shot.action {
                    settle(window)
                    model.stageForSnapshot(action)
                }
            }
            settle(window)
            model.setStackHovered(shot.peek)
            model.setExpanded(shot.expanded)
            model.setPasteExpanded(shot.pasteExpanded)
            settle(window, shot.settle)
            if let i = shot.inspect, model.referents.indices.contains(i) {
                model.inspect(model.referents[i].id)
                settle(window, 0.9)
            }
            if let i = shot.hover, model.referents.indices.contains(i) {
                model.hoveredReferent = model.referents[i].id
                settle(window, 0.8)
            }
            guard let rep = composited(window), let data = rep.representation(using: .png, properties: [:]) else {
                print("failed \(shot.name)"); continue
            }
            let url = dir.appendingPathComponent("\(shot.name).png")
            try? data.write(to: url)
            print("wrote \(url.lastPathComponent)")
        }
    }

    /// The window as the window server composites it: materials, vibrancy and the toolbar
    /// included, which `cacheDisplay` leaves out. An app may always capture its own windows.
    /// (ScreenCaptureKit, the replacement, asks for Screen Recording even for those, hence the
    /// deprecation warning here.)
    static func composited(_ window: NSWindow) -> NSBitmapImageRep? {
        // `FOVEA_OFFSCREEN=1`: the window's views drawn inside the process instead, for when the
        // screen is locked (the window server then hands back a blank image); materials draw flat.
        if ProcessInfo.processInfo.environment["FOVEA_OFFSCREEN"] == "1",
           let view = window.contentView?.superview ?? window.contentView,
           let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: rep)
            return rep
        }
        let id = CGWindowID(window.windowNumber)
        guard let image = CGWindowListCreateImage(.null, .optionIncludingWindow, id, [.boundsIgnoreFraming, .bestResolution]) else {
            return nil
        }
        return NSBitmapImageRep(cgImage: image)
    }

    /// Real captures from Safari's tabs, one region per tab in turn.
    private static func takeReferents(_ count: Int, model: WorkbenchModel, window: NSWindow) {
        model.clearReferents()
        model.screenContent = .fullScreenApp
        model.notchState = .voiceFlow
        for i in 0..<count {
            model.selectTab(i % model.tabs.count)
            settle(window)
            model.captureNow(captureRegions[i % captureRegions.count])
        }
        model.selectTab(0)
    }

    /// Real display cycles, so the split view finishes its collapse and the images decode.
    private static func settle(_ window: NSWindow, _ seconds: TimeInterval = WorkbenchTokens.Snapshot.settle) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            window.layoutIfNeeded()
            window.displayIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
    }

    /// A contact sheet of marks over time, enlarged on black, so the motion can be read from a
    /// still.
    private static func writeSheet<V: View>(_ view: V, named name: String, to dir: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else { print("failed \(name)"); return }
        let url = dir.appendingPathComponent("\(name).png")
        try? data.write(to: url)
        print("wrote \(url.lastPathComponent)")
    }
}

/// The Lasso over one loop: eight moments, each at 3× on the island's black, and, set apart, the
/// loop it holds when still.
private struct LassoSheet: View {
    private let columns = 8

    var body: some View {
        let T = WorkbenchTokens.Thinking.self
        let period = WorkbenchTokens.Lasso.period
        HStack(spacing: 18) {
            ForEach(0..<columns + 1, id: \.self) { i in
                let t = i == columns ? LassoRenderer.rest : period * (1 + (Double(i) + 0.25) / Double(columns))
                Canvas { ctx, size in
                    var c = ctx
                    c.scaleBy(x: 3, y: 3)
                    LassoRenderer.draw(in: &c, size: CGSize(width: size.width / 3, height: size.height / 3), time: t)
                }
                .frame(width: T.markSize * 3, height: T.markSize * 3)
                .overlay(alignment: .leading) {
                    if i == columns { Rectangle().fill(.white.opacity(0.14)).frame(width: 1).offset(x: -9) }
                }
            }
        }
        .padding(24)
        .background(Color.black)
    }
}

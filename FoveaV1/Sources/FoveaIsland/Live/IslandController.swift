import SwiftUI
import AppKit
import Observation
import FoveaCore
import FoveaKit
import FoveaStore
import FoveaPlatform
import FoveaLook

// The island's window and its life: one full-screen transparent panel on the screen with the
// notch, the Workbench's island in it in the Native design (Liquid Glass, only the notch black)
// with the Badges board, at Spacious density. The person's choices (prefs.json) set its glass,
// light or dark, its panels, attached or floating, its accent and its glow, and it changes the
// moment they do. Clicks go through it everywhere but where it draws.

@MainActor
package final class IslandController {
    let model: WorkbenchModel
    let live: IslandLive
    private let prefs: PrefsStore
    private var panel: NotchPanel?
    private var hosting: PassthroughHostingView<AnyView>?
    /// The pulled-out chats' own layer (Oct 11): just under the island's, on the display in use.
    private var detachedPanel: NotchPanel?
    private var detachedHosting: PassthroughHostingView<AnyView>?
    private var detachedScreen: NSScreen?
    private var followCandidate: CGDirectDisplayID?
    private var followTask: Task<Void, Never>?
    private let keyTap = KeyboardTap()
    private let watcher = PermissionWatcher()
    private var screenObserver: Any?
    private var spaceObservers: [Any] = []
    private var screenContentCheck: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var lastPrefs: FoveaPrefs
    /// A choice made in Settings shows at the notch a moment. The first run turns this off: it
    /// shows its choices itself, for as long as they're being made.
    package var autoPreview = true

    package init(prefs: PrefsStore, captures: CaptureLibrary, dictionary: DictionaryStore) {
        self.prefs = prefs
        let screen = Screens.island ?? NSScreen.screens[0]
        live = IslandLive(prefs: prefs, captures: captures, dictionary: dictionary, screen: screen)
        // No Workbench flags: the island's own run (a snapshot or smoke run is the App's to ask for).
        model = WorkbenchModel(arguments: ["Fovea"])
        lastPrefs = prefs.prefs
        model.live = live
        model.voiceGlow.liveLevel = { [weak live] in live?.level ?? 0 }
        // The decided design: Native, Spacious, the Badges board, the desktop as it is.
        model.screenContent = .desktop
        model.design = .native
        model.boardStyle = .badges
        model.petAtRest = false
        model.display = Screens.metrics(for: screen)
        apply(prefs.prefs, preview: false)
        // Oct 15 review, ST-03.1: the shortcuts as recorded drive the island (IslandInput.swift).
        installShortcuts()
    }

    /// The first run's hold on the island.
    package var director: IslandDirector? {
        get { live.director }
        set { live.director = newValue }
    }

    /// `smoke` (LiveSmoke): the island's window invisible, the person's keys and pointer never
    /// watched, the stand-ins at its edges; the model and its states as they always are.
    /// `smoke`: scripted words, no keys or pointer watched, nothing reaching another app; the panel
    /// invisible unless `visible` (`--design-shots`, pictures of the real screen).
    package func start(smoke: Bool = false, visible: Bool = false) {
        if smoke {
            live.smoke = IslandLive.Smoke()
            build()
            panel?.alphaValue = visible ? 1 : 0
            detachedPanel?.alphaValue = visible ? 1 : 0
            model.startLiveSteps()
            observePrefs()
            observeModel()
            // Oct 17, Ryan: taken words' marks end with the session in the smoke too.
            observeInput()
            return
        }
        build()
        startKeys()
        // Oct 15 review (IslandInput.swift): the session's display (IS05), capture on the other
        // displays (VF05), the opened row's swipe (VF04), the review's stages.
        observeInput()
        startStackScroll()
        // Oct 17, Ryan: words selected and files clicked while Fovea listens are taken, no key.
        startSelectionWatch()
        // Oct 18, Ryan: their marks over the window they're in, and only there (IslandMarks.swift).
        startMarks()
        registerInputReviewStages()
        // Oct 15 review (IslandController+Cases.swift): Dispatch's sessions' stages.
        registerCaseStages()
        model.pointer.onMove = { [weak self] point in
            self?.pointerMoved(point)
            self?.model.pointerMoved(toScreen: point)
            ScreenPointer.reassert()
        }
        model.pointer.start()
        model.startLiveSteps()
        observePrefs()
        observeModel()
        // A grant seen live (Accessibility, in the first run): the keys start working at once.
        watcher.onChange = { [weak self] permission, granted in
            guard let self, granted, permission == .accessibility else { return }
            self.restartKeys()
        }
        // Oct 21, perf: Accessibility only, the one this acts on (KeyboardTap.swift, PermissionWatcher).
        watcher.start(interval: 1, watching: [.accessibility])
        // An app taken full screen: the band beside the notch black, as on the Mac (Oct 11; the
        // Workbench's full-screen shots, real).
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            spaceObservers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateScreenContent() }
            })
        }
        updateScreenContent()
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                                object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        }
    }

    // MARK: The panel

    private func build() {
        let screen = live.screen
        let panel = NotchPanel(frame: screen.frame)
        let root = AnyView(IslandLayerView(model: model, prefs: prefs))
        let hosting = PassthroughHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: screen.frame.size)
        hosting.autoresizingMask = [.width, .height]
        hosting.interactive = { [weak self] in self?.interactiveRects() ?? [] }
        hosting.takesAll = { [weak self] in self?.takesAll ?? false }
        panel.contentView = hosting
        panel.appearance = prefs.prefs.notchAppearance.nsAppearance
        panel.setFrame(screen.frame, display: true)
        panel.orderFrontRegardless()
        self.panel = panel
        self.hosting = hosting
        live.panel = panel
        if detachedPanel == nil { buildDetached() }
        // Off screen until the island has something to show.
        updatePresence()
    }

    /// The pulled-out chats' layer: a clear panel the size of a display, just under the island's,
    /// on every Space; it follows the pointer to the display in use (`followPointer`).
    private func buildDetached() {
        let screen = live.screen
        let panel = NotchPanel(frame: screen.frame)
        let hosting = PassthroughHostingView(rootView: AnyView(DetachedLayerView(model: model)))
        hosting.frame = NSRect(origin: .zero, size: screen.frame.size)
        hosting.autoresizingMask = [.width, .height]
        hosting.interactive = { [weak self] in self?.detachedRects() ?? [] }
        panel.contentView = hosting
        panel.appearance = prefs.prefs.notchAppearance.nsAppearance
        panel.setFrame(screen.frame, display: true)
        panel.level = Self.detachedLevel
        detachedPanel = panel
        detachedHosting = hosting
        detachedScreen = screen
    }

    private static let detachedLevel = NSWindow.Level(rawValue: NotchPanel.islandLevel.rawValue - 1)

    /// Where the pulled-out chats take clicks, in their display's top-down points.
    private func detachedRects() -> [CGRect] {
        let w = model.detachedArea.width
        return model.v2Detached.map { item in
            if let side = item.docked {
                return CGRect(x: side == .left ? 0 : w - 64, y: item.dockY - 40, width: 64, height: 120)
            }
            return CGRect(origin: item.origin, size: item.size).insetBy(dx: -12, dy: -12)
        }
    }

    /// The pointer on another display for a moment (not mid-drag, not pulling one out): the
    /// pulled-out chats go there, each at the same place on it (Oct 11, Yulun: "it follows me
    /// between displays"). Back on the notch's display once none is left out.
    private func followPointer(_ appKitPoint: CGPoint) {
        guard !model.v2Detached.isEmpty, !model.v2DetachedMoving, model.v2DragOut == nil,
              let screen = NSScreen.screens.first(where: { NSMouseInRect(appKitPoint, $0.frame, false) }),
              let id = Screens.displayID(screen) else {
            followTask?.cancel(); followCandidate = nil
            return
        }
        if let current = detachedScreen, Screens.displayID(current) == id {
            followTask?.cancel(); followCandidate = nil
            return
        }
        guard followCandidate != id else { return }
        followCandidate = id
        followTask?.cancel()
        followTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(WorkbenchTokens.V2.followDwell))
            guard let self, !Task.isCancelled, self.followCandidate == id, !self.model.v2DetachedMoving else { return }
            self.moveDetached(to: screen)
        }
    }

    /// The pulled-out chats' layer onto `screen`, each chat at the same place on it.
    package func moveDetached(to screen: NSScreen) {
        followCandidate = nil
        guard let panel = detachedPanel else { return }
        let area = screen.frame.size
        if Screens.displayID(screen) == Screens.displayID(live.screen), area == model.display.frame.size {
            model.moveDetachedArea(to: area)
            model.liveDetachedArea = nil
        } else {
            model.moveDetachedArea(to: area)
        }
        panel.setFrame(screen.frame, display: true)
        detachedHosting?.frame = NSRect(origin: .zero, size: area)
        panel.level = Self.detachedLevel
        detachedScreen = screen
    }

    /// The display the pulled-out chats are on (the smoke run reads it).
    package var detachedDisplay: CGDirectDisplayID? { detachedScreen.flatMap(Screens.displayID) }

    private func rebuild() {
        guard let screen = Screens.island else { return }
        live.screen = screen
        model.display = Screens.metrics(for: screen)
        panel?.reassert()
        panel?.setFrame(screen.frame, display: true)
        hosting?.frame = NSRect(origin: .zero, size: screen.frame.size)
        // Displays changed: the pulled-out chats come back to the notch's.
        moveDetached(to: screen)
    }

    /// Desktop or an app full screen, asked a moment after the switch (the window list settles).
    private func updateScreenContent() {
        screenContentCheck?.cancel()
        screenContentCheck = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.35))
            guard let self, !Task.isCancelled, !self.model.demoSamples else { return }
            let content: MockScreenContent = Screens.frontAppFillsScreen(self.live.screen) ? .fullScreenApp : .desktop
            if self.model.screenContent != content { self.model.screenContent = content }
        }
    }

    /// Where the island draws and takes clicks, in the screen's top-down points.
    private func interactiveRects() -> [CGRect] {
        var rects: [CGRect] = []
        let w = model.display.frame.width
        if model.notchState != .silent {
            let size = (model.notchState == .v2Board ? model.v2BoardLayout.hoverSize : nil) ?? model.stackLayout.outline.size
            rects.append(CGRect(x: (w - size.width) / 2 - 8, y: 0, width: size.width + 16, height: size.height + 8))
        }
        return rects
    }

    /// Capture mode, the highlighter, a chat being pulled out: every click is the island's.
    private var takesAll: Bool {
        model.capturing || model.highlighting || model.v2DragOut != nil
    }

    /// The panel lets clicks through where it doesn't draw: decided as the pointer moves.
    private func pointerMoved(_ appKitPoint: CGPoint) {
        updateClickThrough(at: appKitPoint)
        followPointer(appKitPoint)
    }

    private func updateClickThrough(at appKitPoint: CGPoint = NSEvent.mouseLocation) {
        guard let panel else { return }
        let inside: Bool
        if takesAll {
            inside = true
        } else if let p = live.layerPoint(fromScreen: appKitPoint) {
            inside = interactiveRects().contains { $0.contains(p) }
        } else {
            inside = false
        }
        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }
        // The pulled-out chats' layer takes clicks only on them (none while one is pulled out).
        if let detached = detachedPanel, let screen = detachedScreen {
            let onIt = !takesAll && NSMouseInRect(appKitPoint, screen.frame, false)
                && detachedRects().contains { $0.contains(Screens.local(appKit: appKitPoint, on: screen)) }
            if detached.ignoresMouseEvents == onIt { detached.ignoresMouseEvents = !onIt }
        }
    }

    /// The island's window is the size of the screen and on every Space; up while it has nothing to
    /// show, it covered the full-screen apps' Spaces in Mission Control (Oct 10: they showed black).
    /// So it's on screen only while the island is: open, previewing, capturing, a chat pulled out, a
    /// mark fading. At rest it shows nothing the hardware's notch doesn't (a moment after the
    /// island closes, so its spring finishes).
    private func updatePresence() {
        updateDetachedPresence()
        guard let panel, live.smoke == nil else { return }
        let needed = model.notchState != .silent || model.previewing || model.capturing || model.highlighting
            || model.v2DragOut != nil || !model.highlights.isEmpty || !model.flights.isEmpty
        if needed {
            hideTask?.cancel()
            hideTask = nil
            if !panel.isVisible {
                panel.reassert()
                panel.orderFrontRegardless()
            }
            noteOffScreen()
            return
        }
        guard panel.isVisible, hideTask == nil else { return }
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard let self, !Task.isCancelled else { return }
            self.hideTask = nil
            let still = self.model.notchState == .silent && !self.model.previewing && !self.model.capturing
                && !self.model.highlighting && self.model.v2DragOut == nil
            if still { self.panel?.orderOut(nil) }
            self.noteOffScreen()
        }
    }

    /// Oct 21, perf: whether anything of the island is on the screen, for the model's simulated
    /// work to animate only when it can be seen (`WorkbenchModel.islandOffScreen`).
    private func noteOffScreen() {
        let off = live.smoke == nil && panel?.isVisible != true && detachedPanel?.isVisible != true
        if model.islandOffScreen != off { model.islandOffScreen = off }
    }

    /// The pulled-out chats' layer is up while any is out. One being pulled out of the notch lands
    /// on the notch's display, so the layer comes back there first; with none left, it rests there.
    private func updateDetachedPresence() {
        defer { noteOffScreen() }
        guard let detached = detachedPanel else { return }
        if model.v2DragOut != nil || model.v2Detached.isEmpty, let screen = detachedScreen,
           Screens.displayID(screen) != Screens.displayID(live.screen) {
            moveDetached(to: live.screen)
        }
        if model.v2Detached.isEmpty {
            if detached.isVisible { detached.orderOut(nil) }
        } else if !detached.isVisible {
            detached.level = Self.detachedLevel
            detached.orderFrontRegardless()
            panel?.orderFrontRegardless()
        }
    }

    /// ⌘'s crosshair and ⌥'s accent arrow, over any app; the app's own pointer otherwise.
    private var pointerStyle: ScreenPointer.Style = .system
    private func updatePointer() {
        guard live.smoke == nil else { return }
        let style: ScreenPointer.Style = model.capturing ? .crosshair
            : model.highlighting ? .custom(AccentArrow.cursor(model.accent)) : .system
        let changed: Bool
        switch (style, pointerStyle) {
        case (.system, .system), (.crosshair, .crosshair): changed = false
        case (.custom, .custom): changed = !model.highlighting
        default: changed = true
        }
        guard changed else { return }
        pointerStyle = style
        ScreenPointer.set(style)
    }

    // MARK: Keys

    private func startKeys() {
        // Oct 15 review, ST-03.1: fn, fn ⌃, ⌘ and left ⌥ as Settings › Shortcuts records them
        // (IslandInput.swift); left ⌃ alone stays Choose chat's.
        live.shortcuts.start()
        model.leftControlKey.start()
        // A recorded chord's key (⌥ Space), from any app, kept only when the press is the island's.
        keyTap.shortcutHandler = { [weak self] event in self?.live.shortcuts.handleKey(event) ?? false }
        // Esc, the arrows, Return and ⌘Z, while the island is open: taken from the app in front
        // only when the island used them.
        keyTap.handler = { [weak self] event in
            guard let self, self.model.notchState != .silent else { return false }
            return self.model.keys.handle(event)
        }
        keyTap.start()
    }

    private func restartKeys() {
        // Monitors made before the grant see nothing from other apps: made again.
        live.shortcuts.stop(); live.shortcuts.start()
        model.leftControlKey.stop(); model.leftControlKey.start()
        keyTap.start()
    }

    // MARK: The person's choices

    private func observePrefs() {
        withObservationTracking { _ = prefs.prefs } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.apply(self.prefs.prefs, preview: true)
                self.observePrefs()
            }
        }
    }

    private func observeModel() {
        withObservationTracking {
            _ = model.notchState; _ = model.capturing; _ = model.highlighting; _ = model.v2DragOut; _ = model.v2Detached
            _ = model.previewing; _ = model.highlights; _ = model.flights
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateClickThrough()
                self?.updatePointer()
                self?.updatePresence()
                self?.observeModel()
            }
        }
    }

    /// The prefs, onto the island: glass, panels, accent, glow, the board's hover. A change made
    /// while the person is choosing (Settings, the first run) shows at the notch a moment.
    private func apply(_ p: FoveaPrefs, preview: Bool) {
        let before = lastPrefs
        lastPrefs = p
        model.liveScheme = p.notchAppearance.colorScheme
        panel?.appearance = p.notchAppearance.nsAppearance
        model.nativePanels = p.panels
        model.density = PanelDensity(rawValue: p.density.rawValue) ?? .spacious
        model.accent = p.accent
        model.glowPalette = p.glowPalette
        // Oct 18, Ryan: "changing the hue should not change the color scheme provided": a palette
        // is drawn as it is; only Custom takes the hue, the spread and the drift.
        model.glowHue = p.drawnGlowHue
        model.glowSpread = p.drawnGlowSpread
        model.glowDriftAmount = p.drawnGlowDrift
        model.glowDrift = p.drawnGlowDrift > 0.001
        model.v2ReviewBeforeSend = p.reviewFirst
        model.hoverOpens = p.hoverOpens
        model.showAnswers = p.showAnswers
        if model.greetingName != p.accountName { model.greetingName = p.accountName }
        model.hoverDwell = p.hoverWait.dwell
        // Oct 15 review, ST-03.1: a shortcut recorded (or cleared) works at once.
        updateShortcuts(p)
        guard preview, autoPreview, model.notchState == .silent || model.previewing else { return }
        // A change that draws no differently (the hue under a palette) shows nothing.
        let glowChanged = before.glowPalette != p.glowPalette || before.drawnGlowHue != p.drawnGlowHue
            || before.drawnGlowSpread != p.drawnGlowSpread || before.drawnGlowDrift != p.drawnGlowDrift
        let lookChanged = before.notchAppearance != p.notchAppearance || before.panels != p.panels
            || before.density != p.density || before.accent != p.accent
        if glowChanged { showPreview(.aura) } else if lookChanged { showPreview(.panel) }
    }

    /// The smoke run changes the prefs as Settings would.
    var prefsForSmoke: FoveaPrefs {
        get { prefs.prefs }
        set { prefs.prefs = newValue }
    }

    package enum Preview { case aura, panel }

    /// The notch shows the choice a moment: the Dispatch bar with its glow, or a sample of the
    /// board (so Attached and Floating can be seen), then rests. No microphone.
    package func showPreview(_ kind: Preview, seconds: Double = 4) {
        previewTask?.cancel()
        model.showPreview(kind == .aura ? .aura : .panel)
        previewTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, !Task.isCancelled else { return }
            self.model.endPreview()
        }
    }

    /// `--demo <state>`: a state staged at the real notch, with the Workbench's samples and no
    /// microphone, to look at. Every state the Workbench shows (Oct 11): `stageNames` lists them,
    /// e.g. voiceFlow, stack:3:open, highlight:text, countdown:lastMinute, error:offline,
    /// v2Send:model, v2Chat:calendar, whole:outline, queue:paused, fullScreen:v2Board.
    package func stage(_ name: String) {
        // A staged state replaces a setting's preview, as a real press does, and starts from rest:
        // the last one's sessions, marks and choices gone, the person's prefs back on.
        endPreview()
        model.notchState = .silent
        model.resetFeedback()
        // Oct 15 review: Dispatch's cases from rest too (IslandController+Cases.swift).
        model.cases.reset()
        model.clearReferents()
        model.highlights = []
        model.v2Size = .usual
        apply(prefs.prefs, preview: false)
        model.demoSamples = true
        let parts = name.split(separator: ":").map(String.init)
        let option = parts.count > 1 ? parts[1] : nil
        let detail = parts.count > 2 ? parts[2] : nil
        let scene = shotScene ?? ShotScene.standard(on: live.screen)
        var screen = MockScreenContent.desktop
        switch parts[0] {
        case "voiceFlow": model.notchMode = .voiceFlow
        case "transcribing":
            model.notchMode = .voiceFlow
            // Long enough to have said something: the sample's words arrive.
            model.listenStart = Date().addingTimeInterval(-6)
            model.notchMode = .transcribing
        case "cancelled": model.notchMode = .cancelled
        case "noSpeech": model.notchMode = .noSpeech
        case "pasteNotFound":
            model.transcript = WorkbenchModel.sampleTranscript
            model.notchMode = .pasteNotFound
            if option == "expanded" { model.setPasteExpanded(true) }
        case "error":
            if let e = option.flatMap(VoiceError.init(rawValue:)) { model.stageError(e) }
        // ⌘: a part of the screen being taken.
        case "capture":
            model.notchMode = .voiceFlow
            model.capturing = true
            model.selection = scene.regions[0]
        // What was taken, in the bar: closed, opened, the pointer on it, one looked at closely.
        case "stack":
            model.notchMode = .voiceFlow
            let count = Int(option ?? "3") ?? 3
            Task { @MainActor in
                for rect in scene.regions.prefix(count) { await self.model.capture(rect, animated: false) }
                switch detail {
                case "open": self.model.setExpanded(true)
                case "peek": self.model.setStackHovered(true)
                case "hover":
                    self.model.setExpanded(true)
                    if self.model.referents.count > 1 { self.model.hoveredReferent = self.model.referents[1].id }
                case "inspect":
                    self.model.setExpanded(true)
                    try? await Task.sleep(for: .seconds(0.6))
                    self.model.inspect(self.model.referents.first?.id)
                default: break
                }
            }
        // ⌥: words and a file taken with the highlighter (#3, #8).
        case "highlight":
            model.notchMode = .voiceFlow
            switch option {
            case "file":
                model.markFile(DesktopFile(name: scene.fileURL.lastPathComponent, size: "4 KB"), rect: scene.fileRect)
            case "stack", "opened":
                model.stageMixedReferents()
                if option == "opened" { model.setExpanded(true) }
            default:
                // Oct 17, Ryan: words taken with no key (no highlighter any more): the mark of what
                // was taken, and its card.
                model.markText(scene.text, rects: scene.lines)
            }
        // The Dispatch bar's glow alone, in a palette (Settings › Notch).
        case "glow":
            if let palette = option.flatMap(GlowPalette.init(rawValue:)) {
                // Oct 18, Ryan: a palette as it is, whatever hue the person's Custom has.
                var staged = prefs.prefs
                staged.glowPalette = palette
                model.glowPalette = palette
                model.glowHue = staged.drawnGlowHue
                model.glowSpread = staged.drawnGlowSpread
                model.glowDriftAmount = staged.drawnGlowDrift
                model.glowDrift = staged.drawnGlowDrift > 0.001
            }
            if palette(option) == .custom { model.glowHue = 150; model.glowSpread = 60 }
            // A steady voice, as Settings' preview draws it: no microphone runs in a staged state.
            showPreview(.aura, seconds: 3600)
        // #4: the last minute of a ten-minute bar, and its last seconds.
        case "countdown":
            model.stageCountdown(option == "lastSeconds" ? .lastSeconds : .lastMinute)
        case "v2Voice": model.stageV2(.voice)
        case "v2Transcribing": model.stageV2(.transcribe)
        case "v2Send":
            switch option {
            case "mixed": model.stageModelEffort()
            case "model": model.feedbackModelStage = .open; model.stageModelEffort()
            case "browse":
                model.stageV2(.send)
                model.toggleV2Browse()
                if let row = model.v2BrowseRows.first { model.pickV2Browse(row) }
            default: model.stageV2(.send)
            }
        // #19: the review off, the chat, model and effort a click away.
        case "route":
            model.feedbackRouteOpen = option == "open"
            model.stageSkipReview()
        case "v2Board":
            model.stageV2(.board)
            if option == "end" { model.v2ScrollTarget = "t-docs" }
            if option == "open" { model.openV2("t-snapshots") }
        case "v2Chat":
            if let request = option.flatMap(V2Request.init(rawValue:)) { model.v2Request = request }
            switch option {
            case "working": model.v2Request = .code; model.feedbackWorkStage = .working; model.stageAnswer()
            case "steps": model.stageV2(.chat); if let id = model.v2Focus { model.v2StepsOpen.insert(id) }
            case "expanded": model.stageV2(.chat); model.setV2Size(.expanded)
            default: model.stageV2(.chat)
            }
        case "whole":
            switch option {
            case "long": model.stageV2(.wholeLong)
            case "outline": model.stageV2(.wholeLong); model.v2OutlineShown = true
            case "work": model.stageV2(.whole); if let id = model.v2Focus { model.v2StepsOpen.insert(id) }
            case "exit": model.stageV2(.wholeLong); model.exitV2ToBoard()
            default: model.stageV2(.whole)
            }
        case "pulled":
            model.stageV2(.pulled)
            for i in model.v2Detached.indices where model.v2Detached[i].docked == nil {
                switch option {
                // Let go at the screen's side: both chats tucked into tabs, one each side (Oct 11).
                case "tucked":
                    model.v2Detached[i].docked = .right
                    model.v2Detached[i].dockY = 300
                // Its corner pulled: a bigger window, the words their size, more of them in view.
                case "resized":
                    let base = V2DetachedLayout.size
                    model.v2Detached[i].origin.x -= base.width * 0.4
                    model.resizeDetachedV2(model.v2Detached[i].id, to: CGSize(width: base.width * 1.4, height: base.height * 1.3))
                default: break
                }
            }
        case "titles": model.stageTitles()
        case "steps":
            model.feedbackStepsStage = option == "board" ? .board : .session
            model.stageSteps()
        case "reanswer":
            model.v2Request = .code
            model.feedbackWorkStage = option == "done" ? .done : .working
            model.stageReanswer()
        case "queue":
            model.feedbackQueueStage = option == "paused" ? .paused : .queued
            model.stageQueue()
        // As Settings shows it: the preview's own three sessions, not the samples beside them.
        case "preview":
            model.demoSamples = false
            showPreview(option == "panel" ? .panel : .aura, seconds: 3600)
        // The board with nothing running: "Hello, (Name). Start building here." (Oct 9, late).
        case "hello":
            model.agentTasks = []
            model.v2Sessions = []
            model.showAgentPanel(pinned: true)
        // Asking more by voice: the band under the notch, the session below it (Oct 9, late).
        case "asksOver":
            model.stageV2(.chat)
            model.startV2Voice(continuing: model.v2Focus)
        // Any state over an app taken full screen: the band beside the notch black, no menu bar.
        case "fullScreen":
            stage(parts.dropFirst().joined(separator: ":"))
            screen = .fullScreenApp
        // Oct 15 review, VF04/VF05/QA02: sample referents, `referents:<n>[:open|:other|:send]`.
        case "referents":
            stageReferents(Int(option ?? "5") ?? 5, detail)
        // Oct 15 review, Dispatch's sessions: `qa:<case>` (Feedback/V2CaseStages.swift).
        case "qa": model.stageCase(name)
        default: break
        }
        // The staging above assumes the Workbench's full-screen Safari in places; the real Mac's
        // screen is what it is.
        model.screenContent = screen
        updateClickThrough()
    }

    private func palette(_ option: String?) -> GlowPalette? { option.flatMap(GlowPalette.init(rawValue:)) }

    /// Every state `stage` knows, in the order a design review reads them.
    package static var stageNames: [String] {
        var names = ["voiceFlow", "capture", "stack:1", "stack:3", "stack:5:open", "stack:3:peek", "stack:5:hover",
                     "stack:5:inspect", "highlight:text", "highlight:file", "highlight:stack", "highlight:opened",
                     "countdown:lastMinute", "countdown:lastSeconds", "transcribing", "cancelled", "noSpeech",
                     "pasteNotFound", "pasteNotFound:expanded"]
        names += VoiceError.allCases.map { "error:\($0.rawValue)" }
        names += GlowPalette.allCases.map { "glow:\($0.rawValue)" }
        names += ["v2Voice", "v2Transcribing", "v2Send", "v2Send:mixed", "v2Send:model", "v2Send:browse", "route",
                  "route:open", "titles", "v2Board", "v2Board:end", "v2Board:open", "hello", "steps:board"]
        names += ["v2Chat"] + V2Request.allCases.map { "v2Chat:\($0.rawValue)" }
        names += ["v2Chat:working", "v2Chat:steps", "v2Chat:expanded", "steps:session", "reanswer:working",
                  "reanswer:done", "queue:queued", "queue:paused", "asksOver", "whole", "whole:work", "whole:long",
                  "whole:outline", "whole:exit", "pulled", "pulled:tucked", "pulled:resized", "preview:aura", "preview:panel",
                  "fullScreen:voiceFlow", "fullScreen:v2Board", "fullScreen:v2Chat"]
        // Oct 15 review, VF04/VF05/QA02.
        names += ["referents:5", "referents:12:open", "referents:4:other", "referents:5:send"]
        // Oct 15 review, Dispatch's sessions.
        names += caseStageNames
        return names
    }

    /// `--design-shots`: what's on the screen under the island to take (a document's lines, a file,
    /// parts to capture), in the screen's top-down points. Without one, places on the bare desktop.
    package var shotScene: ShotScene?

    package func endPreview() {
        previewTask?.cancel()
        model.endPreview()
    }
}

/// The island's whole layer, the size of the screen: capture mode's surface (clear, there only
/// while it's on), the chats pulled out of the notch, the island at the top, and the marks and
/// flights over everything.
struct IslandLayerView: View {
    let model: WorkbenchModel
    let prefs: PrefsStore

    var body: some View {
        let scheme = model.liveScheme
        ZStack(alignment: .top) {
            Color.clear
                .contentShape(Rectangle())
                .allowsHitTesting(model.capturing || model.highlighting)
                .modifier(CaptureSurface(model: model))
            Group {
                // The one being pulled out; once out, the chats are drawn in their own layer.
                V2DetachedLayer(model: model, chats: false)
                MockIsland(model: model)
                CaptureOverlay(model: model)
            }
            .opacity(model.hidingOwnSurfaces ? 0 : 1)
            .animation(nil, value: model.hidingOwnSurfaces)
            .environment(\.displayScheme, scheme)
            // The real Mac's glass: a blur of what's behind the window (NativeGlass.swift).
            .environment(\.behindWindowGlass, true)
        }
        .frame(width: model.display.frame.width, height: model.display.frame.height, alignment: .top)
        .coordinateSpace(name: ScreenSpace.name)
        .environment(\.colorScheme, scheme)
        // Oct 15 review, IS02: Fovea's own Motion over the Mac's Reduce Motion.
        .modifier(IslandMotion(model: model))
        // Oct 18, Ryan: the notch's words in the primary language, live.
        .foveaLanguage()
        .ignoresSafeArea()
        // The panel is never the key window: without this, SwiftUI took a click on it as the one
        // that brings it forward, and dropped it (⌥ and a click on a file took nothing: Oct 9).
        .answersActivatingClick()
    }
}

/// The pulled-out chats' layer, the size of the display they're on (it follows the pointer's).
struct DetachedLayerView: View {
    let model: WorkbenchModel

    var body: some View {
        let scheme = model.liveScheme
        let area = model.detachedArea
        V2DetachedLayer(model: model, pulling: false)
            .environment(\.displayScheme, scheme)
            .environment(\.behindWindowGlass, true)
            .frame(width: area.width, height: area.height, alignment: .topLeading)
            .coordinateSpace(name: ScreenSpace.name)
            .environment(\.colorScheme, scheme)
            .modifier(IslandMotion(model: model))
            .foveaLanguage()
            .ignoresSafeArea()
            .answersActivatingClick()
    }
}

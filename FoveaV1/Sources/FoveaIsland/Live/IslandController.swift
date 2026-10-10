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
    private let keyTap = KeyboardTap()
    private let watcher = PermissionWatcher()
    private var screenObserver: Any?
    private var previewTask: Task<Void, Never>?
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
    }

    /// The first run's hold on the island.
    package var director: IslandDirector? {
        get { live.director }
        set { live.director = newValue }
    }

    package func start() {
        build()
        startKeys()
        model.pointer.onMove = { [weak self] point in
            self?.pointerMoved(point)
            self?.model.pointerMoved(toScreen: point)
            ScreenPointer.reassert()
            if let self, self.model.highlighting { self.model.updateHoverMark(self.live, at: self.live.layerPoint(fromScreen: point)) }
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
        watcher.start(interval: 1)
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
    }

    private func rebuild() {
        guard let screen = Screens.island else { return }
        live.screen = screen
        model.display = Screens.metrics(for: screen)
        panel?.reassert()
        panel?.setFrame(screen.frame, display: true)
        hosting?.frame = NSRect(origin: .zero, size: screen.frame.size)
    }

    /// Where the island draws and takes clicks, in the screen's top-down points.
    private func interactiveRects() -> [CGRect] {
        var rects: [CGRect] = []
        let w = model.display.frame.width
        if model.notchState != .silent {
            let size = (model.notchState == .v2Board ? model.v2BoardLayout.hoverSize : nil) ?? model.stackLayout.outline.size
            rects.append(CGRect(x: (w - size.width) / 2 - 8, y: 0, width: size.width + 16, height: size.height + 8))
        }
        if model.guideCaption != nil, model.notchState == .silent, let frame = model.captionFrame {
            rects.append(frame.insetBy(dx: -4, dy: -4))
        }
        for item in model.v2Detached {
            if let side = item.docked {
                let x: CGFloat = side == .left ? 0 : w - 64
                rects.append(CGRect(x: x, y: item.dockY - 40, width: 64, height: 120))
            } else {
                rects.append(CGRect(origin: item.origin, size: item.size).insetBy(dx: -12, dy: -12))
            }
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
    }

    /// ⌘'s crosshair and ⌥'s accent arrow, over any app; the app's own pointer otherwise.
    private var pointerStyle: ScreenPointer.Style = .system
    private func updatePointer() {
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
        model.functionKey.start()
        model.leftControlKey.start()
        model.leftOptionKey.start()
        model.leftCommandKey.start()
        model.rightCommandKey.start()
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
        for monitor in [model.functionKey, model.leftControlKey] { monitor.stop(); monitor.start() }
        for monitor in [model.leftOptionKey, model.leftCommandKey, model.rightCommandKey] { monitor.stop(); monitor.start() }
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
            _ = model.guideCaption; _ = model.captionFrame
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateClickThrough()
                self?.updatePointer()
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
        model.glowHue = p.glowHue
        model.glowSpread = p.glowSpread
        model.glowDriftAmount = p.glowDrift
        model.glowDrift = p.glowDrift > 0.001
        model.v2ReviewBeforeSend = p.reviewFirst
        model.hoverOpens = p.hoverOpens
        model.hoverDwell = p.hoverWait.dwell
        guard preview, autoPreview, model.notchState == .silent || model.previewing else { return }
        let glowChanged = before.glowPalette != p.glowPalette || before.glowHue != p.glowHue
            || before.glowSpread != p.glowSpread || before.glowDrift != p.glowDrift
        let lookChanged = before.notchAppearance != p.notchAppearance || before.panels != p.panels
            || before.density != p.density || before.accent != p.accent
        if glowChanged { showPreview(.aura) } else if lookChanged { showPreview(.panel) }
    }

    package enum Preview { case aura, panel }

    /// The notch shows the choice a moment: the Dispatch bar with its glow, or a sample of the
    /// board (so Attached and Floating can be seen), then rests. No microphone.
    package func showPreview(_ kind: Preview, seconds: Double = 2.6) {
        previewTask?.cancel()
        model.showPreview(kind == .aura ? .aura : .panel)
        previewTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, !Task.isCancelled else { return }
            self.model.endPreview()
        }
    }

    /// `--demo <state>`: a state staged at the real notch, with the Workbench's samples and no
    /// microphone, to look at: voiceFlow, transcribing, cancelled, noSpeech, pasteNotFound,
    /// error:<name>, v2Voice, v2Transcribing, v2Send, v2Board, v2Chat, whole, pulled,
    /// preview:aura, preview:panel.
    package func stage(_ name: String) {
        model.demoSamples = true
        let parts = name.split(separator: ":").map(String.init)
        switch parts[0] {
        case "voiceFlow": model.notchMode = .voiceFlow
        case "transcribing": model.notchMode = .voiceFlow; model.notchMode = .transcribing
        case "cancelled": model.notchMode = .cancelled
        case "noSpeech": model.notchMode = .noSpeech
        case "pasteNotFound": model.notchMode = .pasteNotFound
        case "error":
            if let e = parts.dropFirst().first.flatMap(VoiceError.init(rawValue:)) { model.showVoiceError(e) }
        case "v2Voice": model.stageV2(.voice)
        case "v2Transcribing": model.stageV2(.transcribe)
        case "v2Send": model.stageV2(.send)
        case "v2Board": model.stageV2(.board)
        case "v2Chat": model.stageV2(.chat)
        case "whole": model.stageV2(.whole)
        case "pulled": model.stageV2(.pulled)
        case "preview": showPreview(parts.dropFirst().first == "panel" ? .panel : .aura, seconds: 3600)
        default: break
        }
        updateClickThrough()
    }

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
                V2DetachedLayer(model: model)
                MockIsland(model: model)
                if let caption = model.guideCaption, model.notchState == .silent {
                    GuideCaptionView(model: model, caption: caption)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(ScreenSpace.name)) } action: { model.captionFrame = $0 }
                }
                CaptureOverlay(model: model)
            }
            .opacity(model.hidingOwnSurfaces ? 0 : 1)
            .animation(nil, value: model.hidingOwnSurfaces)
            .environment(\.displayScheme, scheme)
        }
        .frame(width: model.display.frame.width, height: model.display.frame.height, alignment: .top)
        .coordinateSpace(name: ScreenSpace.name)
        .environment(\.colorScheme, scheme)
        .ignoresSafeArea()
        // The panel is never the key window: without this, SwiftUI took a click on it as the one
        // that brings it forward, and dropped it (⌥ and a click on a file took nothing: Oct 9).
        .answersActivatingClick()
    }
}

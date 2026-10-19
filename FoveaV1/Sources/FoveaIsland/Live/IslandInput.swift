import SwiftUI
import AppKit
import FoveaKit
import FoveaStore
import FoveaPlatform
import FoveaLook

// The notch's input side, as the dev team's review of Oct 15 changed it (docs/v1/REVIEW_2026-10-15.md),
// wired onto the real island once (IslandController calls in here):
//  • ST-03.1: the shortcuts Settings › Shortcuts records drive Voiceflow, Dispatch, the region and
//    the highlighter (`ShortcutMonitor`, KeyMonitors.swift), re-read whenever the prefs change.
//  • IS05 ("where you're working"): a press opens the island on the display with the pointer, a
//    software island at its top centre where there's no notch; it stays there until the session is
//    done, then goes home to the notch.
//  • VF04: a swipe or the wheel over the opened stack scrolls its one row sideways.
//  • VF05: capture mode reaches the other displays, and what's taken there says so.
//  • NH-04: the notices' Settings buttons open Fovea's Settings (`onOpenSettings`).
//  • The review's stages for the states using the app won't show on demand.

extension IslandController {
    // MARK: ST-03.1 The shortcuts

    /// The shortcuts' actions, as fn, fn ⌃ and ⌘ had them (WorkbenchModel.init), now whatever keys
    /// they're recorded as. Oct 17, Ryan: the highlighter has no key: words and files are taken as
    /// they're selected (`startSelectionWatch`). Oct 19, Ryan: the region is ⌘ by default again
    /// (it was ⌥ from Oct 17), and ⌥ does nothing.
    func installShortcuts() {
        let model = self.model
        let shortcuts = live.shortcuts
        shortcuts.paused = { ShortcutRecording.active }
        let onBar: () -> Bool = { [weak model] in model?.notchState.collects ?? false }
        shortcuts.actions = [
            FoveaKeys.voiceflow.id: .init(kind: .toggle, toggle: { [weak self] in self?.shortcutPressed(dispatch: false) ?? false }),
            FoveaKeys.dispatch.id: .init(kind: .toggle, toggle: { [weak self] in self?.shortcutPressed(dispatch: true) ?? false }),
            // A part of the screen: pressed once, capture for one region (a drag takes it, and
            // capture ends); held, capture while held; a second press turns it off. Used with
            // another key (⌘C, ⌘V), never a press: capture it turned on goes off at once.
            // Oct 19, Ryan: "pressing ⌘ once take a screenshot of the selected area, ⌘ twice the
            // entire screen": ⌘ (either side) by default again, as before Oct 17; ⌥ does nothing.
            // Twice, the two presses turn capture on and off, and the whole screen's double press
            // (below) takes the screen: nothing else is taken.
            FoveaKeys.region.id: .init(kind: .hold, active: onBar,
                                       down: { [weak model] in model?.regionDown() },
                                       up: { [weak model] tap in model?.regionUp(click: tap) },
                                       interrupted: { [weak model] in model?.regionInterrupted() }),
            // Oct 18, Ryan: "double clicking command for full-screen screenshot". ⌘ (either side)
            // pressed twice quickly, nothing between, takes the whole screen the pointer is on, and
            // ⌘ with a key (⌘C, ⌘V) is never a press. Fixed, not recorded: with the region recorded
            // on another key, ⌘ twice still takes the whole screen (and ⌘ once nothing).
            FoveaKeys.wholeScreen.id: .init(kind: .hold, active: onBar,
                                            doublePress: { [weak model] in model?.captureWholeScreen() }),
        ]
        // The Workbench's fixed keys stand down on the real Mac: fn and the region are chords now,
        // ⌘ does nothing special, and the left-⌥ highlighter is gone (Oct 17).
        model.functionKey.onPress = {}
        for key in [model.leftOptionKey, model.leftCommandKey, model.rightCommandKey] {
            key.onDown = {}
            key.onUp = { _ in }
            key.onDoublePress = {}
        }
        // Left ⌃ alone, in Choose chat and a session: alone means alone (with fn it's fn ⌃; with any
        // other key it's a recorded chord's), and never when a shortcut is left ⌃ by itself.
        model.leftControlKey.onPress = { [weak self] in
            guard let self, self.model.leftControlKey.heldDuring.isEmpty,
                  !self.live.shortcuts.claims(.leftControl) else { return }
            if self.model.notchState == .v2Send { self.model.toggleV2Browse() }
            else if self.model.notchState == .v2Chat { self.model.toggleV2Expanded() }
        }
        updateShortcuts(live.prefs.prefs)
    }

    /// The recorded chords (or the defaults), in Settings' order.
    func updateShortcuts(_ prefs: FoveaPrefs) {
        // Oct 18, Ryan: ⌘ twice for the whole screen, after the recorded ones (they win a clash).
        live.shortcuts.set(FoveaKeys.changeable.map { (id: $0.id, chord: FoveaKeys.chord($0.id, prefs)) }
                           + [(id: FoveaKeys.wholeScreen.id, chord: KeyChord(modifiers: ["⌘"]))])
    }

    /// Voiceflow's or Dispatch's shortcut pressed, as fn and fn ⌃ always were: Dispatch's flow takes
    /// its own presses first, fn is dictation everywhere else. Whether the press was the island's
    /// (at rest with nothing opened, as in the first run before fn is taught, it was the app's).
    func shortcutPressed(dispatch: Bool) -> Bool {
        // A press during a setting's preview at the notch is the real thing: the preview goes first.
        if model.previewing { endPreview() }
        let resting = model.notchState == .silent
        if resting { openOnPointerDisplay() }
        if dispatch {
            _ = model.v2FunctionKey(control: true)
        } else if !model.v2FunctionKey(control: false) {
            model.toggleVoiceFlow()
        }
        return !(resting && model.notchState == .silent)
    }

    // MARK: Oct 17, Ryan: words and files with no key

    /// While Fovea listens, the mouse is watched, never taken over: a global monitor (and a local
    /// one for the first run's practice windows) sees where each press begins and ends; the press
    /// itself reaches the app as always. A moment after it's let go, what it selected or clicked is
    /// taken (`autoTake`). Fovea's own surfaces are never what's taken.
    func startSelectionWatch() {
        guard live.mouseMonitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.watchMouse(event, own: false)
        }) {
            live.mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.watchMouse(event, own: true)
            return event
        }) {
            live.mouseMonitors.append(local)
        }
    }

    private func watchMouse(_ event: NSEvent, own: Bool) {
        // Oct 17, Ryan: a file dragged from Finder, the desktop (or the first run's own windows).
        if !(own && event.window is NotchPanel) { watchFileDrag(event) }
        // Fovea's own windows: only the first run's practice windows, never the island's.
        if own, event.window is NotchPanel || live.director == nil { return }
        let p = NSEvent.mouseLocation
        let point = CGPoint(x: p.x, y: Screens.primaryHeight - p.y)
        switch event.type {
        case .leftMouseDown:
            live.pressAt = model.notchState.collects && !model.capturing ? point : nil
            live.draftMark = nil
            live.pressText = nil
            live.pressWindow = nil
            // Oct 18, Ryan: what was selected where the press began, and the window it began in, so
            // only the selection this press makes is drawn and taken.
            if live.pressAt != nil, !live.readsSelectionAtOnce {
                live.pressWindow = WindowList.window(at: point)?.id
                live.selectionReader.text(at: point) { [weak live] text in live?.pressText = text }
            }
            // The marks' windows back above theirs (a click raises the window it lands on).
            followMarks()
        case .leftMouseDragged:
            // Oct 18, Ryan: the highlight grows and shrinks with the cursor.
            guard let start = live.pressAt, hypot(start.x - point.x, start.y - point.y) > WorkbenchTokens.Capture.dragThreshold else { return }
            model.draftSelection(live, from: start, to: point)
        case .leftMouseUp:
            guard let start = live.pressAt else { followMarks(); return }
            live.pressAt = nil
            if model.highlightDraft != nil { model.highlightDraft = nil }
            let clicks = event.clickCount, before = live.pressText
            Task { [weak self] in
                try? await Task.sleep(for: WorkbenchTokens.Capture.selectionSettle)
                guard let self else { return }
                self.model.autoTake(self.live, from: start, to: point, clicks: clicks, before: before)
                self.followMarks()
            }
        default:
            break
        }
    }

    // MARK: Oct 17, Ryan: files dragged onto the notch

    /// Whether the island takes a file dropped on it now: either voice bar listening, or Choose
    /// chat (adding to the request).
    var acceptsFileDrop: Bool { model.notchState.collects || model.notchState == .v2Send }

    /// A drag that put files on the drag pasteboard (as Finder's and the desktop's do) while the
    /// island takes them: a drop target goes up over the island, a little past it, until the drag
    /// is let go. Only then, so no other drag, and no click, ever lands on it.
    private func watchFileDrag(_ event: NSEvent) {
        guard live.smoke == nil else { return }
        switch event.type {
        case .leftMouseDown:
            live.dragBoardCount = NSPasteboard(name: .drag).changeCount
        case .leftMouseDragged:
            if live.fileDragging { placeDropPanel(); return }
            guard acceptsFileDrop, !model.capturing else { return }
            let board = NSPasteboard(name: .drag)
            guard board.changeCount != live.dragBoardCount else { return }
            live.dragBoardCount = board.changeCount
            guard board.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) else { return }
            live.fileDragging = true
            showDropPanel()
        case .leftMouseUp:
            guard live.fileDragging else { return }
            live.fileDragging = false
            // The drop lands a moment after the mouse is let go: the target stays for it.
            Task { [weak self] in
                try? await Task.sleep(for: WorkbenchTokens.Capture.dropLinger)
                guard let self, !self.live.fileDragging else { return }
                self.hideDropPanel()
            }
        default:
            break
        }
    }

    /// While the island takes drops, the drag pasteboard is also asked a few times a second: a drag
    /// from Fovea's own window (the first run's practice files) reaches no event monitor.
    private func updateDragPoll() {
        let wanted = acceptsFileDrop && live.smoke == nil
        if !wanted {
            live.dragPoll?.invalidate()
            live.dragPoll = nil
            return
        }
        guard live.dragPoll == nil else { return }
        live.dragBoardCount = NSPasteboard(name: .drag).changeCount
        live.dragPoll = Timer.scheduledTimer(withTimeInterval: WorkbenchTokens.Capture.dragPollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollDrag() }
        }
    }

    private func pollDrag() {
        let board = NSPasteboard(name: .drag)
        guard NSEvent.pressedMouseButtons & 1 != 0 else {
            // Let go: a drag under way is over (its drop lands a moment after).
            if live.fileDragging {
                live.fileDragging = false
                Task { [weak self] in
                    try? await Task.sleep(for: WorkbenchTokens.Capture.dropLinger)
                    guard let self, !self.live.fileDragging else { return }
                    self.hideDropPanel()
                }
            }
            live.dragBoardCount = board.changeCount
            return
        }
        if live.fileDragging { placeDropPanel(); return }
        guard acceptsFileDrop, !model.capturing, board.changeCount != live.dragBoardCount else { return }
        live.dragBoardCount = board.changeCount
        guard board.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) else { return }
        live.fileDragging = true
        showDropPanel()
    }

    /// Where the drop target is: the island as drawn now, and a little past it, in AppKit's points.
    private var dropZone: NSRect {
        let size = model.stackLayout.outline.size
        let slack = WorkbenchTokens.Capture.dropSlack
        let frame = live.screen.frame
        let local = CGRect(x: (model.display.frame.width - size.width) / 2 - slack, y: 0,
                           width: size.width + 2 * slack, height: size.height + slack)
        return NSRect(x: frame.minX + local.minX, y: frame.maxY - local.maxY, width: local.width, height: local.height)
    }

    private func showDropPanel() {
        if live.dropPanel == nil {
            let zone = dropZone
            let panel = NotchPanel(frame: zone)
            let view = FileDropView(frame: NSRect(origin: .zero, size: zone.size))
            view.autoresizingMask = [.width, .height]
            view.onTargeted = { [weak self] on in
                guard let self, self.model.fileDropTargeted != on else { return }
                self.model.fileDropTargeted = on && self.acceptsFileDrop
            }
            view.onDrop = { [weak self] urls, point in
                guard let self else { return false }
                return self.model.dropFiles(urls, at: Screens.local(appKit: point, on: self.live.screen))
            }
            panel.contentView = view
            panel.ignoresMouseEvents = false
            live.dropPanel = panel
        }
        placeDropPanel()
        live.dropPanel?.level = NSWindow.Level(rawValue: NotchPanel.islandLevel.rawValue + 1)
        live.dropPanel?.orderFrontRegardless()
    }

    private func placeDropPanel() {
        guard let panel = live.dropPanel, panel.frame != dropZone else { return }
        panel.setFrame(dropZone, display: false)
    }

    private func hideDropPanel() {
        live.dropPanel?.orderOut(nil)
        if model.fileDropTargeted { model.fileDropTargeted = false }
    }

    // MARK: IS05 Where you're working

    /// A press from rest opens the island on the display with the pointer. Not in the first run,
    /// whose stage is the notch's display, nor in the smoke.
    func openOnPointerDisplay() {
        guard live.smoke == nil, live.director == nil, let screen = Screens.forPress() else { return }
        moveIsland(to: screen)
    }

    /// The island's window onto `screen`: the model's display is that screen's (a software island at
    /// its top centre where there's no notch). The pulled-out chats keep their own display.
    func moveIsland(to screen: NSScreen) {
        guard !Screens.same(screen, live.screen), let panel = live.panel else { return }
        if model.liveDetachedArea == nil, !model.v2Detached.isEmpty { model.liveDetachedArea = model.display.frame.size }
        live.screen = screen
        model.display = Screens.metrics(for: screen)
        panel.reassert()
        panel.setFrame(screen.frame, display: true)
        panel.contentView?.frame = NSRect(origin: .zero, size: screen.frame.size)
        model.screenContent = Screens.frontAppFillsScreen(screen) ? .fullScreenApp : .desktop
    }

    /// The display a press would open the island on (the smoke reads it).
    package var pressDisplay: CGDirectDisplayID? { Screens.forPress().flatMap(Screens.displayID) }

    /// Watches the session: done (the island at rest, its spring finished), the island goes home to
    /// the notch's display; capture mode on, its surfaces on the other displays (VF05).
    func observeInput() {
        withObservationTracking {
            _ = model.notchState; _ = model.capturing
            // Oct 18, Ryan: the marks over other apps' windows follow the model's.
            _ = model.highlights; _ = model.accent
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.inputChanged()
                self.observeInput()
            }
        }
    }

    private func inputChanged() {
        updateOtherDisplayCapture()
        syncMarks()
        // Oct 17, Ryan: the session done (landed, sent, cancelled, or at rest), the words it took are
        // no longer marked; and nothing is dropped where nothing takes it.
        let request: Set<NotchState> = [.voiceFlow, .transcribing, .v2Voice, .v2Transcribing, .v2Send]
        if !request.contains(model.notchState) { model.clearTakenMarks() }
        if !acceptsFileDrop, live.dropPanel?.isVisible == true || model.fileDropTargeted { hideDropPanel() }
        updateDragPoll()
        guard model.notchState == .silent, live.smoke == nil, let home = Screens.island, !Screens.same(home, live.screen) else { return }
        Task { [weak self] in
            try? await Task.sleep(for: WorkbenchTokens.Motion.homeAfterRest)
            guard let self, self.model.notchState == .silent, !self.model.previewing, !self.model.capturing else { return }
            self.moveIsland(to: home)
        }
    }

    // MARK: VF05 The other displays

    /// Capture mode reaches every display: on the others, a clear panel takes the drag, shaded as
    /// on the island's, and what it takes is marked as from the other display.
    func updateOtherDisplayCapture() {
        let on = model.capturing && live.smoke == nil && live.director == nil
        let others = on ? NSScreen.screens.filter { !Screens.same($0, live.screen) } : []
        let have = live.otherCapture.compactMap { $0.screen.flatMap(Screens.displayID) }
        let want = others.compactMap(Screens.displayID)
        guard Set(have) != Set(want) || live.otherCapture.count != others.count else { return }
        live.otherCapture.forEach { $0.orderOut(nil) }
        live.otherCapture = others.map { screen in
            let panel = NotchPanel(frame: screen.frame)
            let hosting = NSHostingView(rootView: OtherDisplayCapture(model: model, screen: screen))
            hosting.frame = NSRect(origin: .zero, size: screen.frame.size)
            hosting.autoresizingMask = [.width, .height]
            panel.contentView = hosting
            panel.ignoresMouseEvents = false
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            return panel
        }
    }

    // MARK: VF04 The row, swiped

    /// A swipe (or the wheel) over the opened stack scrolls its one row sideways; elsewhere the
    /// wheel is the app's.
    func startStackScroll() {
        guard live.scrollMonitor == nil else { return }
        live.scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.scrollStack(event) else { return event }
            return nil
        }
    }

    private func scrollStack(_ event: NSEvent) -> Bool {
        guard model.stackExpanded, model.inspectedId == nil, model.notchState.collects else { return false }
        let layout = model.stackLayout
        guard layout.scrollMax > 0.5, let p = live.layerPoint(fromScreen: NSEvent.mouseLocation) else { return false }
        let size = layout.outline.size
        let island = CGRect(x: (model.display.frame.width - size.width) / 2, y: 0, width: size.width, height: size.height)
        guard island.contains(p) else { return false }
        let line = event.hasPreciseScrollingDeltas ? 1 : WorkbenchTokens.Referents.scrollLine
        let dx = event.scrollingDeltaX * line, dy = event.scrollingDeltaY * line
        // Sideways on a trackpad; a mouse's wheel turns the row too.
        let delta = abs(dx) >= abs(dy) ? dx : dy
        if delta != 0 { model.scrollStack(by: -delta) }
        return true
    }

    // MARK: NH-04 Settings from the notch

    /// Opens a page of Fovea's Settings ("voice", "account"…) from the notch's notices: the app
    /// sets it (it owns the window).
    package var onOpenSettings: ((String) -> Void)? {
        get { live.openSettings }
        set { live.openSettings = newValue }
    }

    // MARK: The review's stages

    /// The Review menu's notch states for this side of the review, staged on the real island with
    /// sample referents (no Screen Recording needed).
    func registerInputReviewStages() {
        Review.stage("VF04", "Five referents: +2 on the stack", area: .notch) { [weak self] in self?.stage("referents:5") }
        Review.stage("VF04", "Twelve referents opened: one row, swipe sideways", area: .notch) { [weak self] in
            self?.stage("referents:12:open")
        }
        Review.stage("VF05", "A referent from your other display", area: .notch) { [weak self] in self?.stage("referents:4:other") }
        Review.stage("QA02", "Choose chat with five referents", area: .notch) { [weak self] in self?.stage("referents:5:send") }
        Review.stage("VF09", "Held words: hover holds them, Paste beside Copy", area: .notch) { [weak self] in
            self?.stage("pasteNotFound")
        }
        Review.stage("NH-04", "Microphone unavailable: Choose Microphone…", area: .notch) { [weak self] in
            self?.stage("error:micUnavailable")
        }
        Review.stage("NH-04", "Session expired: Sign in opens Account", area: .notch) { [weak self] in self?.stage("error:sessionExpired") }
    }

    /// `referents:<n>[:open|:other|:send]`: the voice bar with `n` sample referents, collapsed (+N
    /// past three), opened to its row, opened with the second from the other display, or Choose chat
    /// with them.
    func stageReferents(_ count: Int, _ option: String?) {
        if option == "send" {
            model.stageV2(.send)
        } else {
            model.notchMode = .voiceFlow
        }
        let samples = model.sampleReferents(count, otherDisplay: option == "other" ? 1 : nil)
        if option == "send" {
            model.referents = samples
        } else {
            model.referents.append(contentsOf: samples)
        }
        if option == "open" || option == "other" { model.setExpanded(true) }
    }
}

/// Oct 15 review, VF05: capture mode on another display than the island's: the drag shaded as
/// macOS shades ⌘⇧4's, taken on release.
struct OtherDisplayCapture: View {
    let model: WorkbenchModel
    let screen: NSScreen
    @State private var selection: CGRect?

    var body: some View {
        let T = WorkbenchTokens.Capture.self
        ZStack(alignment: .topLeading) {
            Color.clear.contentShape(Rectangle())
            if let selection { SelectionView(rect: selection) }
        }
        .gesture(
            DragGesture(minimumDistance: T.dragThreshold, coordinateSpace: .local)
                .onChanged { selection = CGRect(from: $0.startLocation, to: $0.location) }
                .onEnded { value in
                    selection = nil
                    model.finishSelection(CGRect(from: value.startLocation, to: value.location), on: screen)
                })
        .frame(width: screen.frame.width, height: screen.frame.height, alignment: .topLeading)
        .ignoresSafeArea()
        .answersActivatingClick()
    }
}

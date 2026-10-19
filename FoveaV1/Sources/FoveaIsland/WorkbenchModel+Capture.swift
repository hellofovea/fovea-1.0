import SwiftUI
import AppKit
import FoveaCore
import FoveaKit

/// What the island and its cards are doing, so each change moves on its own curve.
enum CardChange {
    /// The bar opening or closing.
    case state
    /// The stack opening into its row, or folding back.
    case expand, collapse
    /// The pointer fanning the collapsed stack, or leaving it.
    case peek(Bool)
    /// One capture grown for a close look, or put back.
    case inspect(Bool)
    /// A capture removed: it fades, the rest close the gap.
    case remove
    /// A capture joining, or the shape changing.
    case settle
    /// Oct 15 review, VF04: the opened row scrolled sideways under the fingers.
    case scroll
}

/// A capture on its way from the region it was taken from into its place in the stack.
struct ReferentFlight: Identifiable {
    let id: UUID
    let image: NSImage
    /// Top-leading placements in display points.
    let from: CardVector
    let to: CardVector
    var landed = false
}

struct ScrollRequest: Equatable {
    let tab: Int
    let anchor: String
    let token = UUID()
}

extension WorkbenchModel {
    /// The captures still in the session: not the ones fading out.
    var liveReferents: [CapturedReferent] {
        removing.isEmpty ? referents : referents.filter { !removing.contains($0.id) }
    }

    /// Where everything in the island goes now, for the live captures in order.
    var stackLayout: StackLayout {
        let live = liveReferents
        var layout = StackLayout.make(state: notchState, aspects: live.map(\.aspect), shape: referentShape,
                                      expanded: stackExpanded, peek: stackHovered && !stackExpanded,
                                      inspecting: inspectedId.flatMap { id in live.firstIndex { $0.id == id } },
                                      scroll: stackScroll, metrics: metrics)
        // Paste not found and Thinking are the island's own shapes.
        if notchState == .pasteNotFound { layout.outline = pasteLayout.outline }
        if notchState == .quickThinking { layout.outline = agentLayout.outline }
        if notchState.choosingChat { layout.outline = chatLayout.outline }
        if notchState == .agentPanel { layout.outline = panelLayout.outline }
        if let v2 = v2Outline { layout.outline = v2 }
        // Asking more over an open session: the session's outline, the bar's band on top of it.
        if v2AsksOver, !stackExpanded {
            var chat = v2ChatLayout.outline
            chat.size.height += WorkbenchTokens.Island.spec.voiceBelow
            layout.outline = chat
        }
        // Feedback #2: the notice in place of the bar, or inside it (the bar wider, its stack and
        // waveform stepping back); #4: the waveform moves left for the countdown at the right.
        if notchState == .voiceError, let error = voiceError {
            layout.outline = VoiceErrorLayout.outline(error, metrics: metrics)
        }
        // Feedback #19: with the words' review off, the voice bar keeps the notch's width and one
        // icon (the chosen chat's agent) opens the chat, model and effort under it, at Dispatch's width.
        if notchState == .v2Voice, !v2ReviewBeforeSend, !stackExpanded, v2RouteOpen {
            let spec = WorkbenchTokens.Island.spec
            // Open, the band is Dispatch's width: the stack goes to its left edge (it would sit
            // stranded in the middle), the icon to its right.
            let half = NotchGeometry.notchRect(metrics: metrics, spec: spec).width / 2
            let delta = (-WorkbenchTokens.V2.width / 2 + V2Geometry.contentX) - (-half + WorkbenchTokens.Referents.inset)
            for i in layout.cards.indices { layout.cards[i].cx += delta }
            layout.stackHit = layout.stackHit?.offsetBy(dx: delta, dy: 0)
            layout.outline.size.width = WorkbenchTokens.V2.width
            layout.outline.size.height += WorkbenchTokens.V2.gap + V2RouteSheet.height(model: self) + WorkbenchTokens.V2.margin
                + WorkbenchTokens.Native.panelGap
            layout.outline.topRadius = spec.expandedTopRadius
            layout.outline.bottomRadius = WorkbenchTokens.V2.bottomRadius
        }
        if notchState.collects, !stackExpanded {
            if barNotice != nil {
                layout.outline = VoiceErrorLayout.barOutline(metrics: metrics)
            } else if inLastMinute {
                let F = WorkbenchTokens.Feedback.self
                let T = WorkbenchTokens.Referents.self
                let half = NotchGeometry.notchRect(metrics: metrics, spec: WorkbenchTokens.Island.spec).width / 2
                // Oct 15 review, VF04: the "+N" chip is part of the stack.
                let stackRight = (layout.cards.filter { $0.opacity > 0.01 }.map { $0.cx + $0.width / 2 }
                    + [layout.more?.maxX].compactMap { $0 }).max()
                let left = stackRight.map { $0 + T.waveformGap } ?? (-half + T.inset)
                let right = half - F.countdownInset - F.countdownWidth - T.waveformGap / 2
                layout.waveform.x = (left + right) / 2
                if lastMinuteNudge { layout.outline.size.height += F.nudgeGrowth }
            }
        }
        return layout
    }

    /// The layout with the fading captures still in it: where they were, for their exit.
    var departingLayout: StackLayout {
        StackLayout.make(state: notchState, aspects: referents.map(\.aspect), shape: referentShape,
                         expanded: stackExpanded, peek: false, scroll: stackScroll, metrics: metrics)
    }

    /// The Notch list: silent, the voice bar, or the voice bar capturing.
    var notchMode: NotchMode {
        get {
            switch notchState {
            case .silent: return .silent
            case .voiceFlow: return capturing ? .addScreenshot : .voiceFlow
            case .transcribing: return .transcribing
            case .cancelled: return .cancelled
            case .noSpeech: return .noSpeech
            case .pasteNotFound: return .pasteNotFound
            case .voiceError: return .silent
            // The other flows' states are no row of Voiceflow's.
            case .dispatchVoice, .chooseChat, .chatsExpanded, .chatsAll, .agentPanel, .quickVoice, .quickThinking,
                 .v2Voice, .v2Transcribing, .v2Send, .v2Board, .v2Chat: return .silent
            }
        }
        set {
            switch newValue {
            case .silent:
                dropUndo()
                notchState = .silent
            case .voiceFlow:
                dropUndo()
                notchState = .voiceFlow
                capturing = false
            case .addScreenshot:
                dropUndo()
                capturing = true
            case .transcribing: playTranscribing()
            case .cancelled: playCancelled()
            case .noSpeech: showNoSpeech()
            case .pasteNotFound: playPasteNotFound()
            }
        }
    }

    /// The flow whose list shows the choice: the state's own, or, at rest, the last one.
    var currentFlow: NotchFlow {
        return notchState.flow ?? restingFlow
    }

    /// The panel's Voiceflow list: its state, or none while another flow's is the one chosen.
    var voiceflowSelection: NotchMode? {
        get { currentFlow == .voiceflow ? notchMode : nil }
        set {
            guard let newValue else { return }
            leaveFeedback()
            restingFlow = .voiceflow
            notchMode = newValue
        }
    }

    /// The panel's Dispatch list: Silent notch rests the notch, as Voiceflow's does; Voice
    /// input is Dispatch's voice bar; Choose chat shows the request and the chat Fovea picked,
    /// and its expanded view the chats by agent.
    var dispatchSelection: DispatchMode? {
        get {
            guard currentFlow == .dispatch else { return nil }
            switch notchState {
            case .dispatchVoice: return .voice
            case .chooseChat: return .choose
            case .chatsExpanded: return .chats
            case .chatsAll: return .all
            case .agentPanel: return .panel
            default: return .silent
            }
        }
        set {
            guard let newValue else { return }
            restingFlow = .dispatch
            dropUndo()
            switch newValue {
            case .silent: notchState = .silent
            case .voice: notchState = .dispatchVoice
            case .choose: showChooseChat(.closed)
            case .chats: showChooseChat(.projects)
            case .all: showChooseChat(.chats)
            case .panel: showAgentPanel(pinned: true)
            }
        }
    }

    /// The panel's Quick actions list: the notch at rest, the voice bar, and Thinking.
    var quickSelection: QuickActionMode? {
        get {
            guard currentFlow == .quickActions else { return nil }
            switch notchState {
            case .quickVoice: return .voice
            case .quickThinking: return .thinking
            default: return .silent
            }
        }
        set {
            guard let newValue else { return }
            restingFlow = .quickActions
            dropUndo()
            switch newValue {
            case .silent: notchState = .silent
            case .voice: notchState = .quickVoice
            case .thinking: showThinking()
            }
        }
    }

    // MARK: Capture mode

    /// Capturing needs the bar, where the captures go: starting it opens the bar. Stopping
    /// leaves the bar and the captures as they are.
    func setCapturing(_ on: Bool) {
        guard on != capturingStorage else { return }
        if on, !notchState.collects { notchState = restingFlow == .dispatchV2 ? .v2Voice : .voiceFlow }
        capturingStorage = on
        if !on { selection = nil }
    }

    /// Esc closes the innermost thing: the close look, then the opened stack, then capture mode
    /// (as Esc ends ⌘⇧4's: the bar and the captures stay), then the opened transcript. On the
    /// bar itself (Voice flow, Transcribing) it cancels the request, which can be undone for a
    /// moment; on that undo offer it lets the request go at once, and on Paste not found it lets
    /// the transcript go, as ✕ does.
    func escape() -> Bool {
        if inspectedId != nil { inspect(nil); return true }
        if stackExpanded { setExpanded(false); return true }
        if capturing { capturing = false; return true }
        if highlighting { highlighting = false; return true }
        if barNotice != nil { dismissBarNotice(); return true }
        switch notchState {
        case .voiceFlow, .transcribing: return cancel()
        case .cancelled:
            dropUndo()
            notchState = .silent
            return true
        case .noSpeech:
            notchState = .silent
            return true
        case .voiceError:
            dismissVoiceError()
            return true
        case .pasteNotFound:
            if pasteExpanded { setPasteExpanded(false) } else { dismissPaste() }
            return true
        case .dispatchVoice, .quickVoice, .quickThinking:
            notchState = .silent
            return true
        // Esc steps out one level: a project's chats, then the projects, then the request goes.
        case .chatsAll:
            setChatLevel(.projects)
            return true
        case .chatsExpanded:
            setChatLevel(.closed)
            return true
        case .chooseChat:
            notchState = .silent
            return true
        case .agentPanel:
            closeAgentPanel()
            return true
        // Dispatch Version 2: Esc while listening drops the request; on Choose chat it folds
        // the browser (a project's chats, then the projects), then drops the request; on the
        // board or a result it closes it; beside the notch it rests the island.
        case .v2Voice, .v2Transcribing:
            if v2RouteOpen { withAnimation(WorkbenchTokens.V2.resize) { v2RouteOpen = false }; return true }
            // Asking more over a session: back to it as it was.
            if v2AsksOver, let id = v2Continuing {
                if live != nil { live?.cancelListening() }
                returnToV2Chat(id)
                return true
            }
            notchState = .silent
            return true
        case .v2Send:
            if v2Inspecting != nil { withAnimation(cardMotion.fan) { v2Inspecting = nil } }
            else if v2ModelSheet { withAnimation(WorkbenchTokens.V2.resize) { v2ModelSheet = false } }
            else if v2Browsing, v2BrowseProject != nil { v2BrowseProject = nil }
            else if v2Browsing { v2Browsing = false }
            else { notchState = .silent }
            return true
        case .v2Chat:
            // Expanded, Esc comes back to the usual size first, then closes.
            if v2Expanded { setV2Size(.usual) } else { closeV2Chat() }
            return true
        case .v2Board:
            closeAgentPanel()
            return true
        case .silent: return false
        }
    }

    /// A drag ended: big enough, it is a capture, and capture mode ends with it: one press of
    /// Option, one screenshot (feedback #3, decided Oct 6). A click without a drag was the page's;
    /// text and files are ⌘'s now.
    func finishSelection(_ rect: CGRect) {
        let T = WorkbenchTokens.Capture.self
        guard capturing, rect.width >= T.minimumSide, rect.height >= T.minimumSide else {
            selection = nil
            return
        }
        Task {
            await capture(rect)
            // Oct 19, Ryan: "Hold ⌘ to take more than one": while the key is held, capture stays.
            if commandTurnedOn == nil { capturing = false }
        }
    }

    /// Captures a region of the display as it is on screen: the selection is cleared, the
    /// window draws without it, and the region's pixels are taken from the window.
    func capture(_ rect: CGRect, animated: Bool = true) async {
        if let live {
            await liveCapture(live, rect, animated: animated)
            return
        }
        selection = nil
        try? await Task.sleep(for: WorkbenchTokens.Capture.clearDelay)
        guard let image = windowImage(displayRect: rect) else { return }
        add(image: image, from: rect, animated: animated)
    }

    /// The same, at once, for snapshots: the selection must already be off the window.
    @discardableResult
    func captureNow(_ rect: CGRect) -> Bool {
        guard let image = windowImage(displayRect: rect) else { return false }
        add(image: image, from: rect, animated: false)
        return true
    }

    func add(image: NSImage, from rect: CGRect, animated: Bool, kind: ReferentKind = .screenshot, source given: String? = nil,
             otherDisplay: Bool = false, fileURL: URL? = nil) {
        let source = given ?? (screenContent == .fullScreenApp ? tabs[selectedTab].title : L("Desktop"))
        // Oct 15 review, VF05: taken on another display than the island's. Oct 17: a file's URL.
        let referent = CapturedReferent(id: UUID(), image: image, aspect: image.size.width / max(1, image.size.height),
                                        source: source, kind: kind, otherDisplay: otherDisplay, fileURL: fileURL)
        islandAnimation = WorkbenchTokens.Referents.settle
        cardChange = .settle
        referents.append(referent)
        guard animated, !reduceMotion, let card = stackLayout.cards.last else { return }
        // The capture flies from where it was taken to its card, which waits hidden.
        let to = CardVector(x: Double(display.frame.width / 2 + card.cx - card.width / 2), y: Double(card.top),
                            w: Double(card.width), h: Double(card.height), r: Double(card.radius),
                            rot: card.rotation, o: card.opacity)
        let from = CardVector(x: Double(rect.minX), y: Double(rect.minY), w: Double(rect.width), h: Double(rect.height),
                              r: Double(WorkbenchTokens.Capture.flightStartRadius), rot: 0, o: 1)
        landing.insert(referent.id)
        flights.append(ReferentFlight(id: referent.id, image: image, from: from, to: to))
        let id = referent.id
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(20))
            guard let self, let i = self.flights.firstIndex(where: { $0.id == id }) else { return }
            self.flights[i].landed = true
            try? await Task.sleep(for: WorkbenchTokens.Capture.flightDuration)
            self.landing.remove(id)
            self.flights.removeAll { $0.id == id }
        }
    }

    /// Clears the captures once the island has closed over them, unless it reopened.
    func endSession() {
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard let self, self.notchState == .silent else { return }
            self.referents.removeAll()
            self.highlights.removeAll()
            self.flights.removeAll()
            self.landing.removeAll()
            self.removing.removeAll()
            self.inspectedId = nil
            self.hoveredReferent = nil
        }
    }

    func clearReferents() {
        islandAnimation = WorkbenchTokens.Referents.settle
        cardChange = .settle
        stackExpanded = false
        stackScroll = 0
        stackHovered = false
        inspectedId = nil
        hoveredReferent = nil
        removing.removeAll()
        referents.removeAll()
        highlights.removeAll()
    }

    /// Removes one capture: it fades where it is while the rest close the gap and the island
    /// fits them, then it leaves the list. Removing the last one folds the stack away.
    func removeReferent(_ id: UUID) {
        guard referents.contains(where: { $0.id == id }), !removing.contains(id) else { return }
        islandAnimation = reduceMotion ? .easeOut(duration: WorkbenchTokens.Motion.reduceMotionFade) : WorkbenchTokens.Referents.settle
        cardChange = .remove
        if hoveredReferent == id { hoveredReferent = nil }
        if inspectedId == id { inspectedId = nil }
        removing.insert(id)
        highlights.removeAll { $0.referent == id }
        if liveReferents.isEmpty {
            stackExpanded = false
            stackHovered = false
        }
        Task { [weak self] in
            try? await Task.sleep(for: WorkbenchTokens.Referents.departDelay)
            guard let self else { return }
            self.referents.removeAll { $0.id == id }
            self.removing.remove(id)
        }
    }

    /// A close look at one capture in the opened stack, or back to all of them.
    func inspect(_ id: UUID?) {
        guard stackExpanded, id != inspectedId else { return }
        islandAnimation = reduceMotion ? .easeOut(duration: WorkbenchTokens.Motion.reduceMotionFade) : WorkbenchTokens.Referents.inspect
        cardChange = .inspect(id != nil)
        inspectTransitionId = id ?? inspectedId
        hoveredReferent = nil
        inspectedId = id
    }

    // MARK: The stack

    func setExpanded(_ open: Bool) {
        guard open != stackExpanded, !open || !referents.isEmpty else { return }
        let T = WorkbenchTokens.Referents.self
        islandAnimation = reduceMotion ? .easeOut(duration: WorkbenchTokens.Motion.reduceMotionFade)
            : (open ? T.expand : T.collapse)
        cardChange = open ? .expand : .collapse
        stackHovered = false
        hoveredReferent = nil
        inspectedId = nil
        // Oct 15 review, VF04: the row opens at its first referent.
        stackScroll = 0
        stackExpanded = open
    }

    /// Oct 15 review, VF04: the opened row, scrolled sideways by `delta` points (a swipe right
    /// brings the first ones back), within its ends. Returns whether it could move.
    @discardableResult
    func scrollStack(by delta: CGFloat) -> Bool {
        guard stackExpanded, inspectedId == nil else { return false }
        let layout = stackLayout
        guard layout.scrollMax > 0.5 else { return false }
        let next = min(max(0, layout.scroll + delta), layout.scrollMax)
        guard abs(next - layout.scroll) > 0.01 else { return false }
        islandAnimation = reduceMotion ? .easeOut(duration: WorkbenchTokens.Motion.reduceMotionFade) : WorkbenchTokens.Referents.scrollFollow
        cardChange = .scroll
        hoveredReferent = nil
        stackScroll = next
        return true
    }

    func setStackHovered(_ inside: Bool) {
        guard inside != stackHovered, !stackExpanded else { return }
        cardChange = .peek(inside)
        stackHovered = inside
    }

    /// How card `index` of `count` moves for the change being made: the reference's fan
    /// opening, front first, 30 ms apart; its fold closing, last first.
    func cardAnimation(index: Int, count: Int, departing: Bool = false, inspected: Bool = false) -> Animation {
        if reduceMotion { return .easeOut(duration: WorkbenchTokens.Motion.reduceMotionFade) }
        let T = WorkbenchTokens.Referents.self
        switch cardChange {
        case .remove:
            return departing ? T.departFade : T.settle
        case .inspect(let opening):
            // The looked-at card grows (or goes back) on the reference's fan; the rest step
            // back quickly, and come back a beat after it has left.
            if inspected { return cardMotion.fan }
            return opening ? T.othersFade : T.othersFade.delay(0.08)
        case .state:
            return notchState.collects ? WorkbenchTokens.Motion.open : WorkbenchTokens.Motion.close
        case .expand:
            return cardMotion.fan.delay(T.cardDelay + Double(min(index, T.staggerCap)) * T.stagger)
        case .collapse:
            return cardMotion.fold.delay(Double(min(count - 1 - index, T.staggerCap)) * T.stagger)
        case .peek(let inside):
            return inside ? cardMotion.fan : cardMotion.fold
        case .settle:
            return T.settle
        case .scroll:
            return T.scrollFollow
        }
    }

    // MARK: Safari tabs

    func selectTab(_ index: Int) {
        guard tabs.indices.contains(index) else { return }
        selectedTab = index
    }

    /// ⌃Tab and its friends, while Safari is on screen.
    func stepTab(_ step: Int) -> Bool {
        guard screenContent == .fullScreenApp else { return false }
        selectedTab = (selectedTab + step + tabs.count) % tabs.count
        return true
    }

    func scroll(tab: Int, to anchor: String) {
        scrollRequest = ScrollRequest(tab: tab, anchor: anchor)
    }

    // MARK: The display in the window

    /// A region of the display, in the window's coordinates (AppKit: origin bottom left).
    /// The stage centers the scaled display in its column, so this is arithmetic on the probe.
    func windowRect(forDisplay r: CGRect) -> CGRect? {
        guard let probe = stageProbe, probe.window != nil else { return nil }
        let column = probe.convert(probe.bounds, to: nil)
        let s = scale
        let size = display.frame.size
        let left = column.minX + (column.width - size.width * s) / 2
        let top = column.maxY - (column.height - size.height * s) / 2
        return CGRect(x: left + r.minX * s, y: top - r.maxY * s, width: r.width * s, height: r.height * s)
    }

    func windowPoint(forDisplay p: CGPoint) -> CGPoint? {
        windowRect(forDisplay: CGRect(origin: p, size: .zero)).map { CGPoint(x: $0.minX, y: $0.minY) }
    }

    /// The pixels of a region of the display, taken from the window as it is composited on
    /// screen, at the display's own size in points. An app may always read its own windows.
    func windowImage(displayRect r: CGRect) -> NSImage? {
        guard let window = stageProbe?.window, let rect = windowRect(forDisplay: r),
              let full = WorkbenchSnapshots.composited(window)?.cgImage else { return nil }
        let k = CGFloat(full.width) / window.frame.width
        let crop = CGRect(x: rect.minX * k, y: (window.frame.height - rect.maxY) * k,
                          width: rect.width * k, height: rect.height * k).integral
        guard let cg = full.cropping(to: crop) else { return nil }
        return NSImage(cgImage: cg, size: r.size)
    }
}

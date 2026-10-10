import SwiftUI
import AppKit
import FoveaCore

// Dispatch's Agent panel: the Agent tasks Fovea delivered, as the hover list shows them, each
// readable at a glance (what it is doing, on what, how far, what changed) and controllable in
// place (allow, answer, stop, retry, open). It opens when the pointer rests on the notch, and
// after Send with the new task highlighted. docs/island/AGENT_PANEL.md has the reasons.

/// Where the pointer is, for the hover: on the notch itself (it can open the panel), on or near
/// the open panel (it keeps it open), or elsewhere.
enum PanelZone: Equatable {
    case inside, near, outside
}

extension WorkbenchModel {
    /// The Agent panel, or Dispatch Version 2's control board in its place: what the hover opens.
    var panelOpen: Bool { notchState == .agentPanel || notchState == .v2Board }

    /// The tasks by project, in the panel's order.
    var panelGroups: [AgentProjectGroup] { AgentBoard.grouped(agentTasks) }

    /// The tasks in the panel's order, top to bottom.
    var panelTasks: [AgentTaskItem] { panelGroups.flatMap(\.tasks) }

    var panelLayout: PanelLayout {
        PanelLayout.make(groups: panelGroups, style: panelStyle, metrics: metrics)
    }

    private var panelAnimated: Bool { !snapshotMode && !reduceMotion }

    // MARK: Opening and closing

    /// Opens Dispatch Version 2's control board (the hover's panel): from the radio (it stays
    /// until Esc or another choice), from the hover (it closes when the pointer leaves), or after
    /// Send (the new session in focus a while). Never opens empty (PRD §8); on the real Mac, with
    /// nothing running, it greets the person instead ("Hello, Ryan. Start building here.", Oct 9).
    func showAgentPanel(pinned: Bool, sent: String? = nil) {
        guard !v2BoardOrder.isEmpty || live != nil else { return }
        if !panelOpen { panelOpened = Date() }
        if v2Focus == nil || !v2BoardOrder.contains(where: { $0.id == v2Focus }) {
            v2Focus = v2BoardOrder.first?.id
        }
        panelPinned = pinned
        panelArmed = false
        panelSentTask = sent
        panelHighlight = sent
        if notchState != .v2Board { notchState = .v2Board }
        startPanelSimulation()
        panelSentGrace?.cancel()
        if sent != nil, panelAnimated {
            panelSentGrace = Task { [weak self] in
                try? await Task.sleep(for: .seconds(WorkbenchTokens.Panel.sentGrace))
                guard let self, !Task.isCancelled, self.panelOpen else { return }
                self.panelSentTask = nil
                // Longer while the pointer is on it; then it closes as a hover does.
                if self.panelZone == .outside, !self.panelPinned { self.closeAgentPanel() }
            }
        }
    }

    func closeAgentPanel() {
        guard panelOpen else { return }
        panelDwell?.cancel()
        panelExit?.cancel()
        panelSentGrace?.cancel()
        notchState = .silent
    }

    /// Leaving the panel's state: its timers stop; the simulation keeps the agents working.
    func stopPanel() {
        panelDwell?.cancel()
        panelDwell = nil
        panelExit?.cancel()
        panelExit = nil
        panelSentGrace?.cancel()
        panelSentGrace = nil
        panelSentTask = nil
        panelHighlight = nil
        panelPinned = false
    }

    // MARK: Hover

    /// The pointer moved over the display (nil: it left). Opening needs the pointer to come to
    /// rest on the notch itself: a dwell, then the first moment it is still (or a cap, so a
    /// fidgeting hand still gets it); brushing across, sweeping along the menu bar, or approaching
    /// from below doesn't open it, and a wobble off the notch's edge doesn't restart it. The open
    /// panel stays while the pointer is on it or near it, and closes a beat after it leaves; back
    /// on the notch just after, it opens at once. After a close, the pointer must leave the notch
    /// before it can open again (AMENDMENTS).
    func panelPointer(_ point: CGPoint?) {
        let now = Date()
        // Creatures look at the pointer and grow under it: where it is over the board.
        if notchState == .v2Board, boardStyle == .creatures, let point {
            let width = v2BoardLayout.outline.size.width
            v2BoardPointer = CGPoint(x: point.x - (display.frame.width - width) / 2, y: point.y)
        } else if v2BoardPointer != nil {
            v2BoardPointer = nil
        }
        if let point {
            panelMoves.append((now, point))
            panelMoves.removeAll { now.timeIntervalSince($0.time) > WorkbenchTokens.Panel.moveMemory }
        } else {
            panelMoves.removeAll()
        }
        let zone = zone(of: point)
        guard zone != panelZone else { return }
        let was = panelZone
        panelZone = zone
        let P = WorkbenchTokens.Panel.self
        switch zone {
        case .inside:
            panelExit?.cancel()
            panelExit = nil
            panelLeftNotch = nil
            // The board already up (just sent) and the pointer comes to the notch: it's been
            // hovered all the same (the first run counts it).
            if notchState == .v2Board { live?.director?.islandDidEmit(.boardOpened(byHover: true)) }
            guard hoverOpens, notchState == .silent, panelArmed, !v2BoardOrder.isEmpty || live != nil, panelDwell == nil,
                  live?.director?.allowsBoard() ?? true else { return }
            // Back just after a hover closed it: the person meant it; no second dwell.
            if let closed = panelHoverClosed, now.timeIntervalSince(closed) < P.reopenWindow {
                showAgentPanel(pinned: false)
                live?.director?.islandDidEmit(.boardOpened(byHover: true))
                return
            }
            panelDwell = Task { [weak self] in
                let start = Date()
                try? await Task.sleep(for: .seconds(self?.live != nil ? (self?.hoverDwell.start ?? P.dwell) : P.dwell))
                while true {
                    guard let self, !Task.isCancelled else { return }
                    if self.panelZone != .inside {
                        // Off the notch a moment: a wobble at its edge keeps the dwell; longer ends it.
                        if let left = self.panelLeftNotch, Date().timeIntervalSince(left) >= P.dwellJitter {
                            self.panelDwell = nil
                            return
                        }
                    } else if self.panelAtRest || Date().timeIntervalSince(start) >= (self.live != nil ? self.hoverDwell.cap : P.dwellCap) {
                        self.panelDwell = nil
                        guard self.notchState == .silent else { return }
                        self.showAgentPanel(pinned: false)
                        self.live?.director?.islandDidEmit(.boardOpened(byHover: true))
                        return
                    }
                    try? await Task.sleep(for: .seconds(P.dwellCheck))
                }
            }
        case .near, .outside:
            if was == .inside, panelDwell != nil { panelLeftNotch = now }
            if zone == .outside, notchState == .silent { panelArmed = true }
            if zone == .near {
                if panelOpen || notchState == .v2Chat {
                    panelExit?.cancel()
                    panelExit = nil
                }
                return
            }
            guard hoverHolds else { return }
            panelExit?.cancel()
            panelExit = Task { [weak self] in
                try? await Task.sleep(for: .seconds(P.exitGrace))
                guard let self, !Task.isCancelled, self.panelZone == .outside, self.hoverHolds else { return }
                if self.notchState == .v2Chat { self.notchState = .silent } else { self.closeAgentPanel() }
                self.panelArmed = true
                self.panelHoverClosed = Date()
            }
        }
    }

    /// What the hover holds open, and so closes when the pointer leaves: the board (unless the
    /// panel's radio pinned it, or Send is showing its new session), and a session opened from it
    /// (unless it is being pulled out of the notch).
    var hoverHolds: Bool {
        if panelOpen { return !panelPinned && panelSentTask == nil }
        return notchState == .v2Chat && v2ChatFromBoard && !v2BoardPinned && v2DragOut == nil
    }

    /// The real pointer moved (`PointerMonitor`): over the mock display, where it is in its points.
    /// A smoke run drives the pointer itself, and snapshots hold still.
    func pointerMoved(toScreen point: CGPoint) {
        guard !options.smoke, !snapshotMode, !pointerScripted else { return }
        let onDisplay = displayPoint(fromScreen: point)
        // Split View sends the words to the app under the pointer (feedback #6); ⌘ outlines what a
        // click would take (#3).
        if screenContent == .splitView { pointerOnDisplay = onDisplay }
        panelPointer(onDisplay)
    }

    /// A point on the screen in the mock display's points; nil when the display isn't what is
    /// under it (another window in front of the workbench, or the bezel, or past the window).
    func displayPoint(fromScreen p: CGPoint) -> CGPoint? {
        if let live { return live.layerPoint(fromScreen: p) }
        guard let probe = stageProbe, let window = probe.window, window.isVisible,
              NSWindow.windowNumber(at: p, belowWindowWithWindowNumber: 0) == window.windowNumber else { return nil }
        let w = window.convertPoint(fromScreen: p)
        let column = probe.convert(probe.bounds, to: nil)
        let s = scale
        let size = display.frame.size
        let left = column.minX + (column.width - size.width * s) / 2
        let top = column.maxY - (column.height - size.height * s) / 2
        let d = CGPoint(x: (w.x - left) / s, y: (top - w.y) / s)
        return CGRect(origin: .zero, size: size).contains(d) ? d : nil
    }

    /// Still: it has moved less than a few points over the last moment (or not at all).
    private var panelAtRest: Bool {
        let P = WorkbenchTokens.Panel.self
        guard let last = panelMoves.last else { return true }
        let now = Date()
        let then = panelMoves.last { now.timeIntervalSince($0.time) >= P.restWindow } ?? panelMoves[0]
        return hypot(last.point.x - then.point.x, last.point.y - then.point.y) < P.restDistance
    }

    /// Whether a row's controls take a click: not in the first moment after the panel opens.
    var panelControlsLive: Bool {
        Date().timeIntervalSince(panelOpened) >= WorkbenchTokens.Panel.controlsGuard
    }

    /// The notch, and a little round it, is where the board opens from; the open board (or a
    /// session opened from it), with a little slack, is where it stays.
    private func zone(of point: CGPoint?) -> PanelZone {
        guard let point else { return .outside }
        let P = WorkbenchTokens.Panel.self
        let notch = NotchGeometry.notchRect(metrics: metrics, spec: WorkbenchTokens.Island.spec)
        let mid = display.frame.width / 2
        let notchRect = CGRect(x: mid - notch.width / 2 - P.hoverReach, y: 0,
                               width: notch.width + 2 * P.hoverReach, height: notch.height + P.hoverReach)
        if notchRect.contains(point) { return .inside }
        if petAtRestShown, petAtRestRect.insetBy(dx: -P.hoverReach / 2, dy: -P.hoverReach / 2).contains(point) { return .inside }
        if panelOpen || notchState == .v2Chat {
            // Capsules: the island stays the notch; the capsules under it are the board's room.
            let size = (notchState == .v2Board ? v2BoardLayout.hoverSize : nil) ?? stackLayout.outline.size
            let panel = CGRect(x: mid - size.width / 2, y: 0, width: size.width, height: size.height)
                .insetBy(dx: -P.exitSlack, dy: 0)
            if panel.contains(point) || panel.offsetBy(dx: 0, dy: P.exitSlack).contains(point) { return .near }
        }
        return .outside
    }

    // MARK: The agents at work

    /// The working tasks move on every few seconds, each through its script, so the panel shows
    /// live work. Snapshots and Reduce Motion hold them still.
    func startPanelSimulation() {
        guard panelAnimated, panelSimulation == nil else { return }
        panelSimulation = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(WorkbenchTokens.Panel.beat))
                guard let self, !Task.isCancelled else { return }
                self.advancePanel()
            }
        }
    }

    private func advancePanel() {
        for i in agentTasks.indices {
            agentTasks[i].age += WorkbenchTokens.Panel.beat
            agentTasks[i].inState += WorkbenchTokens.Panel.beat
            let task = agentTasks[i]
            guard task.state == .working, let script = panelScripts[task.id] ?? AgentBoard.scripts[task.id] else { continue }
            let next = ((panelBeats[task.id] ?? 0) + 1)
            // A one-off script (a sent request, an answer) ends; the sample ones loop.
            if panelScripts[task.id] != nil, next >= script.count { continue }
            let beat = script[next % script.count]
            panelBeats[task.id] = next
            withAnimation(WorkbenchTokens.Panel.change) {
                apply(beat, to: i)
            }
        }
    }

    func apply(_ beat: AgentBeat, to i: Int) {
        agentTasks[i].activity = beat.activity
        agentTasks[i].work = beat.work
        agentTasks[i].object = beat.object
        agentTasks[i].preview = beat.preview
        if beat.reply != nil { agentTasks[i].reply = beat.reply }
        if beat.draft != nil { agentTasks[i].draft = beat.draft }
        if !beat.artifacts.isEmpty { agentTasks[i].artifacts = beat.artifacts }
        if beat.screen != nil { agentTasks[i].screen = beat.screen }
        if beat.result != nil { agentTasks[i].result = beat.result }
        // Feedback, Oct 6: each working beat is a step it took (folded under the answer).
        if beat.state == .working, beat.work != .done, agentTasks[i].steps.last?.activity != beat.activity {
            agentTasks[i].steps.append(AgentStep(id: agentTasks[i].steps.count, work: beat.work, object: beat.object,
                                                 activity: beat.activity))
        }
        if agentTasks[i].state != beat.state { agentTasks[i].inState = 0 }
        agentTasks[i].state = beat.state
        agentTasks[i].ask = beat.ask
        agentTasks[i].age = 0
    }

    /// Runs a one-off script on a task from its first beat.
    private func run(_ script: [AgentBeat], on id: String) {
        guard let i = agentTasks.firstIndex(where: { $0.id == id }), let first = script.first else { return }
        panelScripts[id] = script
        panelBeats[id] = 0
        withAnimation(WorkbenchTokens.Panel.change) { apply(first, to: i) }
        startPanelSimulation()
    }

    /// Send, from Choose chat: the request becomes a task in the chosen chat, and the panel
    /// opens with it highlighted (AMENDMENTS: about 3.5 s, longer while the pointer is on it).
    func deliverToPanel(chat: AgentChat, request: String) {
        let id = "t-sent-\(UUID().uuidString.prefix(6))"
        let script = AgentBoard.sentScript()
        agentTasks.append(AgentTaskItem(id: id, agent: chat.agent, session: chat.isNew ? "New chat" : chat.title,
                                        project: chat.folder, request: request, state: .working,
                                        activity: script[0].activity, work: script[0].work, object: script[0].object,
                                        preview: script[0].preview, ask: nil, age: 0, inState: 0))
        run(script, on: id)
        showAgentPanel(pinned: false, sent: id)
    }

    // MARK: Control

    /// Allow what a task asked for: it goes on.
    func allowTask(_ id: String) {
        guard let task = agentTasks.first(where: { $0.id == id }), task.state == .needsYou else { return }
        let command = task.object ?? "swift test"
        run([
            AgentBeat(activity: "Running \(command)", work: .running, object: command,
                      preview: "✓ PasteNotFoundTests.pausesUnderThePointer"),
            AgentBeat(activity: "Running \(command)", work: .running, object: command,
                      preview: "✓ PasteNotFoundTests.resumesWhenThePointerLeaves"),
            AgentBeat(activity: "The countdown pauses under the pointer", work: .done, object: "PasteNotFound.swift",
                      state: .complete),
        ], on: id)
    }

    /// Deny it: the agent goes on without it.
    func denyTask(_ id: String) {
        guard let task = agentTasks.first(where: { $0.id == id }), task.state == .needsYou else { return }
        run([
            AgentBeat(activity: "Going on without running it", work: .thinking, object: task.object),
            AgentBeat(activity: "Done, without the tests", work: .done, object: task.object, state: .complete),
        ], on: id)
    }

    /// Answer what a task asked: it goes on with that.
    func answerTask(_ id: String, _ answer: String) {
        guard agentTasks.contains(where: { $0.id == id && $0.state == .needsYou }) else { return }
        let keep = answer == "Keep"
        run([
            AgentBeat(activity: keep ? "Adding the flag to CaptureSettings.swift" : "Removing LegacyCapture.swift",
                      work: .editing, object: keep ? "CaptureSettings.swift" : "LegacyCapture.swift",
                      preview: keep ? "@AppStorage(\"useLegacyCapture\") var useLegacyCapture = false" : "- final class LegacyCapture {"),
            AgentBeat(activity: keep ? "Moved to ScreenCaptureKit, the old path behind a flag" : "Moved to ScreenCaptureKit",
                      work: .done, object: "Capture.swift", state: .complete),
        ], on: id)
    }

    /// Stop a working task where it is.
    func stopTask(_ id: String) {
        guard let i = agentTasks.firstIndex(where: { $0.id == id }), agentTasks[i].state == .working else { return }
        panelScripts[id] = []
        withAnimation(WorkbenchTokens.Panel.change) {
            agentTasks[i].state = .failed
            agentTasks[i].stopped = true
            agentTasks[i].activity = "Stopped"
            agentTasks[i].preview = nil
            agentTasks[i].age = 0
            agentTasks[i].inState = 0
        }
    }

    /// Try a failed (or stopped) task again.
    func retryTask(_ id: String) {
        guard let task = agentTasks.first(where: { $0.id == id }), task.state == .failed else { return }
        if let i = agentTasks.firstIndex(where: { $0.id == id }) { agentTasks[i].stopped = false }
        let file = task.object.map { String($0.split(separator: ":")[0]) } ?? "the build"
        run([
            AgentBeat(activity: "Editing \(file)", work: .editing, object: file,
                      preview: "override func flagsChanged(with event: NSEvent)"),
            AgentBeat(activity: "Running swift build", work: .running, object: "swift build",
                      preview: "Compiling \(file)"),
            AgentBeat(activity: "Builds again; fn toggles", work: .done, object: file, state: .complete),
        ], on: id)
    }

    /// Take me there: the task's chat, in its own app. The island rests.
    func openTask(_ id: String) {
        guard agentTasks.contains(where: { $0.id == id }) else { return }
        closeAgentPanel()
    }

    // MARK: Keys

    /// ↑↓ move the highlight (never animated), Return takes the highlighted task there, Esc
    /// closes. Returns whether the key was used.
    func panelKey(_ key: ChatKey) -> Bool {
        guard notchState == .agentPanel else { return false }
        let ids = panelTasks.map(\.id)
        switch key {
        case .up, .down:
            guard let current = panelHighlight, let i = ids.firstIndex(of: current) else {
                panelHighlight = ids.first
                return true
            }
            panelHighlight = ids[key == .up ? max(0, i - 1) : min(ids.count - 1, i + 1)]
        case .enter, .send:
            if let id = panelHighlight { openTask(id) }
        case .left, .right:
            return false
        }
        return true
    }
}

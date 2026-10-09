import SwiftUI
import AppKit
import OnboardingCore

// The keys and the pointer: what a press, a drag, a click or a hover does on each step. The keys
// are the Workbench's after the Oct 6 decisions (round two): fn ⌃ starts and finishes a request,
// ⌘ takes a screenshot (twice, the whole screen), left ⌥ is the highlighter, fn dictates or, in
// an open session, asks more. Pressing ⌘ or ⌥ only arms what comes next; what's taken is the beat.

extension OnboardingModel {
    /// The two tasks (Oct 9): the weekly update, and the packing list.
    var isPracticeTry: Bool { [.weeklyUpdate, .packList].contains(step) }

    var barOpen: Bool {
        if case .voice = island { return true }
        return false
    }

    var requestBarOpen: Bool { island == .voice(.request) || island == .voice(.followUp) }

    /// The task is put together and waits for return: its request is on the review card, not yet
    /// sent. (It reads the card, not the step's beats, so the card's send arrow is never a beat
    /// behind.)
    var readyToSend: Bool { isPracticeTry && island == .review && request != nil && !flow.done.contains(.send) }

    // MARK: fn ⌃

    func requestKey() {
        sound.cue(.tick)
        switch island {
        case .voice(.request), .voice(.followUp):
            finishVoice()
        case .review where readyToSend:
            send()
        case .transcribing:
            break
        default:
            guard isPracticeTry else { return }
            // Sent already: this task is the agent's now.
            guard !flow.done.contains(.send) else { return }
            startRequest()
        }
    }

    func startRequest() {
        flow.retry()
        referents = []
        marks = []
        request = nil
        showIsland(.voice(.request), OT.Motion.barOpen)
        beat(.requestKey)
    }

    /// The second press: the bar closes and the words are written up.
    func finishVoice() {
        guard case .voice(let kind) = island else { return }
        screenshotArmed = false
        highlighterOn = false
        selection = nil
        if kind == .request, isPracticeTry {
            guard flow.waitingFor?.contains(.finish) == true else {
                // Finished before taking both things: the try starts over, and the Island says why.
                flow.retry()
                referents = []
                marks = []
                say(step == .packList
                    ? "Not quite. Take the line and the packing list, then press \(keys.spoken(.request))."
                    : "Not quite. Take the screen and the two parts, then press \(keys.spoken(.request)).", hold: true)
                return
            }
            beat(.finish)
        }
        transcribe(kind)
    }

    func transcribe(_ kind: VoiceKind) {
        let duration = kind == .dictation ? OT.Timing.dictationTranscribing : OT.Timing.transcribing
        transcribeProgress = 0
        showIsland(.transcribing(kind), OT.Motion.barOpen)
        animate(.linear(duration: duration * pace)) { transcribeProgress = 1 }
        after(duration, "transcribe") { [weak self] in
            guard let self else { return }
            switch kind {
            case .request:
                // Ready first, then the card: it's drawn as it will stay.
                self.request = PracticeRequest(words: self.copy.script ?? "", referents: self.referents, step: self.step)
                self.beat(.review)
                self.showIsland(.review, OT.Motion.open)
            case .followUp:
                self.askMore()
            case .dictation:
                self.dictationWritten()
            }
        }
    }

    // MARK: fn

    func dictationKey() {
        sound.cue(.tick)
        switch island {
        case .voice(.dictation):
            finishDictation()
        case .voice(.followUp):
            finishVoice()
        case .session where step == .followUp:
            beat(.followKey)
            showIsland(.voice(.followUp), OT.Motion.barOpen)
        case .transcribing:
            break
        default:
            guard step == .dictation else { return }
            startDictation()
        }
    }

    // MARK: ⌘ and left ⌥, on a voice bar

    /// ⌘ down on a request bar arms a screenshot: tapped, for the next drag; held, while held.
    /// Twice is the whole screen (`commandDouble`). Arming isn't a beat: the first ⌘ of a double
    /// press would otherwise count early.
    func commandDown() {
        guard requestBarOpen else { return }
        animate(nil) { screenshotArmed = true }
        sound.cue(.tick)
    }

    func commandUp(tap: Bool) {
        guard requestBarOpen, !tap else { return }
        animate(nil) { screenshotArmed = false }
    }

    func commandDouble() {
        guard requestBarOpen else { return }
        takeWholeScreen()
    }

    func optionDown() {
        guard requestBarOpen else { return }
        animate(nil) { highlighterOn = true }
    }

    /// Tapped, the highlighter stays on for one mark; held, it's on while held.
    func optionUp(tap: Bool) {
        guard !tap else { return }
        animate(nil) { highlighterOn = false }
    }

    // MARK: The pointer, in display points

    /// A drag: ⌘'s rectangle, or the highlighter's strokes as they will be.
    func dragChanged(from start: CGPoint, to end: CGPoint) {
        if highlighterOn {
            markDraft = hypot(start.x - end.x, start.y - end.y) > 3 ? markRuns(from: start, to: end).rects : nil
            return
        }
        guard screenshotArmed else { return }
        selection = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                           width: abs(end.x - start.x), height: abs(end.y - start.y))
    }

    func dragEnded(from start: CGPoint, to end: CGPoint) {
        let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                          width: abs(end.x - start.x), height: abs(end.y - start.y))
        defer { selection = nil; markDraft = nil }
        if rect.width < 6 && rect.height < 6 {
            clicked(at: end)
            return
        }
        if screenshotArmed {
            takeRegion(rect)
        } else if highlighterOn {
            highlight(from: start, to: end)
        }
    }

    /// The marker's strokes from one point to another, through the page's real lines (the page
    /// reports where each line of each paragraph is), as a text selection runs; and the paragraphs
    /// crossed.
    func markRuns(from a: CGPoint, to b: CGPoint) -> (rects: [CGRect], paragraphs: [Int]) {
        let (start, end) = a.y < b.y || (abs(a.y - b.y) < 4 && a.x <= b.x) ? (a, b) : (b, a)
        var lines: [(paragraph: Int, rect: CGRect)] = []
        for index in paragraphLines.keys.sorted() {
            for rect in paragraphLines[index] ?? [] { lines.append((index, rect)) }
        }
        // The lines the drag spans, top to bottom.
        let spanned = lines.filter { $0.rect.maxY >= start.y && $0.rect.minY <= end.y }
        guard let first = spanned.first, let last = spanned.last else { return ([], []) }
        var rects: [CGRect] = []
        var crossed: [Int] = []
        for line in spanned {
            let r = line.rect
            let x0 = line.rect == first.rect && start.y >= r.minY ? min(max(start.x, r.minX), r.maxX) : r.minX
            let x1 = line.rect == last.rect && end.y <= r.maxY ? min(max(end.x, r.minX), r.maxX) : r.maxX
            guard x1 - x0 > 2 else { continue }
            rects.append(CGRect(x: x0, y: r.minY - 1, width: x1 - x0, height: r.height + 2))
            if !crossed.contains(line.paragraph) { crossed.append(line.paragraph) }
        }
        return (rects, crossed)
    }

    func clicked(at point: CGPoint) {
        guard highlighterOn else { return }
        if let file = desktopFiles.first(where: { fileFrames[$0.name]?.insetBy(dx: -6, dy: -6).contains(point) == true }) {
            takeFile(file)
            return
        }
        if let hit = paragraphFrames.first(where: { $0.value.insetBy(dx: -4, dy: -3).contains(point) }) {
            // A click marks the whole paragraph.
            let lines = paragraphLines[hit.key] ?? [hit.value]
            take(paragraph: hit.key, strokes: lines.map { $0.insetBy(dx: 0, dy: -1) })
        }
    }

    /// ⌘ and a drag. In the weekly update, a part taken in the GitHub tab is the merged pull
    /// requests, in the Support tab the open tickets; a drag that misses them there says so.
    /// Anywhere else it's simply one more referent.
    func takeRegion(_ rect: CGRect) {
        guard rect.width > 8, rect.height > 8 else { return }
        screenshotArmed = false
        var counts: Beat?
        if step == .weeklyUpdate, let beat = [Beat.prs, .tickets].first(where: { $0.tab == currentTab }), pageFrame.contains(rect.center) {
            let part = partFrames[beat == .prs ? "prs" : "tickets"] ?? .zero
            let overlap = part.intersection(rect)
            guard !overlap.isNull, overlap.width * overlap.height > rect.width * rect.height * OT.Practice.partCover else {
                hint(beat == .prs ? "That missed the pull requests. Press \(keys.spoken(.screenshot)) and drag over the list."
                                  : "That missed the tickets. Press \(keys.spoken(.screenshot)) and drag over them.")
                return
            }
            counts = beat
        }
        let referent = TakenReferent(kind: .region(rect), tab: pageFrame.contains(rect.center) ? currentTab : nil)
        animate(OT.Motion.referentIn) { referents.append(referent) }
        capture(referent.id, region: rect, name: "part-\(referents.count).png")
        sound.cue(.capture)
        if let counts { beat(counts) }
    }

    func takeWholeScreen() {
        screenshotArmed = false
        let referent = TakenReferent(kind: .wholeScreen, tab: currentTab)
        capture(referent.id, name: "screen-\(referents.count + 1).png")
        animate(nil) { flash = true }
        after(OT.Timing.flash, "flash") { [weak self] in self?.animate(OT.Motion.calm) { self?.flash = false } }
        animate(OT.Motion.referentIn) { referents.append(referent) }
        sound.cue(.capture)
        beat(.wholeScreen)
    }

    /// A drag with the highlighter marks the words it crossed; the first paragraph crossed joins
    /// the stack.
    func highlight(from start: CGPoint, to end: CGPoint) {
        let runs = markRuns(from: start, to: end)
        guard let first = runs.paragraphs.first, !runs.rects.isEmpty else { return }
        take(paragraph: first, strokes: runs.rects)
    }

    func take(paragraph: Int, strokes: [CGRect]) {
        animate(OT.Motion.markFade) { marks.append(HighlightMark(rects: strokes)) }
        animate(OT.Motion.referentIn) { referents.append(TakenReferent(kind: .passage(paragraph), tab: currentTab)) }
        highlighterOn = false
        sound.cue(.capture)
        beat(.passage)
    }

    /// ⌥ and a click on a file. The packing task wants the packing list: another file says so.
    func takeFile(_ file: DesktopFile) {
        highlighterOn = false
        if step == .packList, file != .list {
            hint("For this one, take \(PracticeFiles.list).")
            return
        }
        if let frame = fileFrames[file.name] {
            let ring = frame.insetBy(dx: OT.Marks.fileInset.width, dy: OT.Marks.fileInset.height)
            animate(OT.Motion.markFade) { marks.append(HighlightMark(rects: [ring], file: true)) }
        }
        animate(OT.Motion.referentIn) { referents.append(TakenReferent(kind: .file(file), path: practice.url(file.name))) }
        sound.cue(.capture)
        beat(.file)
    }

    /// The pointer anywhere on the practice screen: near the notch, the board opens (never empty:
    /// only once something was sent); off it, the board closes. In dictation, the window under it
    /// is where the words will go.
    func pointerMoved(_ point: CGPoint) {
        if step == .dictation {
            let over: DictationWindow? = OT.Layout.feedbackFrame.contains(point) ? .feedback
                : OT.Layout.messagesFrame.contains(point) ? .messages : nil
            if over != pointerOver { animate(OT.Motion.content) { pointerOver = over } }
        }
        let size = OT.Display.size
        let reach = OT.Island.hoverReach
        let notch = CGRect(x: (size.width - OT.Display.notchWidth) / 2 - reach, y: 0,
                           width: OT.Display.notchWidth + 2 * reach, height: OT.Display.notchHeight + reach)
        if notch.contains(point) {
            guard !sessions.isEmpty, island == .rest || island == .caption else { return }
            guard [.hover, .packList, .followUp, .home].contains(step) else { return }
            after(OT.Timing.hoverDwell, "hover") { [weak self] in
                guard let self else { return }
                self.showIsland(.board, OT.Motion.open)
                if self.step == .hover { self.beat(.hoverNotch) }
            }
        } else if island == .board {
            let board = CGRect(x: (size.width - OT.Island.boardWidth) / 2 - 8, y: 0,
                               width: OT.Island.boardWidth + 16, height: IslandMetrics.height(.board, model: self) + 8)
            if !board.contains(point) {
                after(OT.Timing.hoverClose, "hover") { [weak self] in
                    guard let self, self.island == .board else { return }
                    self.rest()
                }
            }
        } else {
            // Leaving the notch before the dwell ends: nothing opens.
            after(0, "hover") {}
        }
    }

    /// A row on the board: its session opens.
    func openSessionRow(_ id: UUID) {
        guard sessions.contains(where: { $0.id == id }) else { return }
        openSessionID = id
        showIsland(.session, OT.Motion.open)
    }

    func openSession(for task: Step) {
        guard let session = sessions.last(where: { $0.task == task }) else { return }
        openSessionRow(session.id)
    }

    var openSession: PracticeSession? {
        sessions.first { $0.id == openSessionID } ?? sessions.last
    }

    /// A tab clicked in the browser: its page shows. The voice bar stays open meanwhile, so what's
    /// taken from one tab and the next goes in the same request (Oct 9: gathering from tabs).
    func selectTab(_ tab: PracticeTab) {
        guard openTabs.contains(tab), tab != currentTab else { return }
        animate(nil) { currentTab = tab }
        placePage()
        sound.cue(.tick)
    }

    // MARK: Return and Esc, in the window

    func returnKey() -> Bool {
        if readyToSend {
            send()
            return true
        }
        if flow.isComplete, guideButtonShown {
            continueTapped()
            return true
        }
        return false
    }

    /// Esc steps out one level, as in the Workbench: the capture key first (⌘ or the highlighter),
    /// then the request.
    func escapeKey() -> Bool {
        switch island {
        case .voice where screenshotArmed || highlighterOn:
            screenshotArmed = false
            highlighterOn = false
            selection = nil
            markDraft = nil
            return true
        case .voice(.dictation):
            cancelDictation()
            return true
        case .voice, .transcribing:
            cancelWaits(except: ["skip"])
            flow.retry()
            referents = []
            marks = []
            markDraft = nil
            screenshotArmed = false
            highlighterOn = false
            rest()
            return true
        case .review where !readyToSend:
            rest()
            return true
        case .board, .session:
            rest()
            return true
        default:
            return false
        }
    }

    /// Whether the board shows its main button now (the tasks wait for their beats; the
    /// permissions and sign-in move on by themselves).
    var guideButtonShown: Bool {
        switch step {
        case .permissions, .weeklyUpdate: false
        case .microphone: micPhase == .waiting && alert == nil
        case .packList, .hover, .followUp, .dictation: flow.isComplete
        default: true
        }
    }
}

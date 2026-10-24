import SwiftUI
import AppKit
import OnboardingCore

// The pointer and Return in Fovea's own windows. The keys themselves (fn ⌃, ⌘, left ⌥, fn) are the
// real island's now (FoveaIsland); what they did is heard as the island's events
// (OnboardingModel+Island.swift).

extension OnboardingModel {
    /// The two tasks (Oct 9): the weekly update, and the packing list. Oct 23, Ryan: and More to
    /// try's two that send.
    var isPracticeTry: Bool { [.weeklyUpdate, .packList, .takeFew, .whileWorking].contains(step) }

    var barOpen: Bool {
        if case .voice = island { return true }
        return false
    }

    var requestBarOpen: Bool { island == .voice(.request) || island == .voice(.followUp) }

    /// The task is put together and waits for return: its request is on the review card, not yet
    /// sent. (It reads the card, not the step's beats, so the card's send arrow is never a beat
    /// behind.)
    var readyToSend: Bool { isPracticeTry && island == .review && request != nil && !flow.done.contains(.send) }

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

    /// The pointer on the practice screen: in dictation, the window under it is where the words
    /// will go. (The board at the notch is the real island's hover.)
    func pointerMoved(_ point: CGPoint) {
        guard step == .dictation || step == .nowhereToType else { return }
        let over: DictationWindow? = OT.Layout.feedbackFrame.contains(point) ? .feedback
            : OT.Layout.messagesFrame.contains(point) ? .messages : nil
        if over != pointerOver { animate(OT.Motion.hover) { pointerOver = over } }
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

    /// Return in Fovea's window: Continue, once the step is done. (Return on Choose chat is the
    /// island's.)
    func returnKey() -> Bool {
        if flow.isComplete, guideButtonShown {
            continueTapped()
            return true
        }
        return false
    }

    /// Esc is the island's (it steps out one level there).
    func escapeKey() -> Bool { false }

    /// Whether the board shows its main button now (the tasks wait for their beats; sign-in moves
    /// on by itself).
    var guideButtonShown: Bool {
        switch step {
        // Oct 17, Ryan (round 2): the permissions page always has Continue, dim until both lists
        // are allowed; it never moves on by itself.
        case .permissions: true
        // Signing up: Continue with the choices (an email typed), or on a page come back to.
        case .signIn:
            signInPhase.showsChoices || (flow.revisited && signInPhase.isSignedIn)
        case .weeklyUpdate: false
        // Heard (Oct 17, Ryan, round 2: it waits for Continue), or come back to with Back.
        case .microphone: (micPhase == .waiting && alert == nil) || micPhase == .heard
        case .packList, .hover, .followUp, .dictation, .takeFew, .whileWorking, .nowhereToType: flow.isComplete
        default: true
        }
    }
}

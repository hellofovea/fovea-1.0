import SwiftUI
import AppKit
import FoveaCore

// Paste not found: the transcription finished with no input box on the page to paste into, so
// the island holds the words: a few lines of them, ✕, the countdown to rest, the chevron that
// opens the whole transcript, and Copy (docs/island/PASTE_NOT_FOUND.md).

extension WorkbenchModel {
    /// The page on screen has an input box to paste into: of the mock pages, only the design
    /// notes' comment box. The desktop has none.
    var inputBoxOnScreen: Bool {
        if let live, !demoSamples { return live.canPaste }
        return screenContent == .splitView || (screenContent == .fullScreenApp && tabs[selectedTab].page == .notes)
    }

    /// Where the island's parts go for Paste not found, opened or not.
    var pasteLayout: PasteLayout {
        PasteLayout.make(expanded: pasteExpanded, textHeight: pasteTextHeight, linesHeight: pasteLinesHeight, metrics: metrics)
    }

    /// The transcription is done: into the input box, and the bar closes; with none on the
    /// page, the island keeps the words to copy.
    func deliverTranscript() {
        if inputBoxOnScreen {
            // Feedback #7: the words land in the field, it lights up, then the notch leaves.
            landTranscript()
        } else {
            showPasteNotFound()
        }
    }

    /// The island opens to the transcript, closed to its first lines, and the countdown starts.
    func showPasteNotFound() {
        stopTranscribing()
        dropUndo()
        if transcript.isEmpty, live == nil { transcript = Self.sampleTranscript }
        // Fovea: the words had nowhere to go; Home keeps them all the same.
        if let live, !transcript.isEmpty { live.logDictation(text: transcript, referents: liveReferents) }
        pasteExpanded = false
        pasteCopied = false
        notchState = .pasteNotFound
        startPasteClock()
    }

    /// The panel's Paste not found: the last transcript, or the sample, from whatever is showing.
    func playPasteNotFound() {
        if notchState == .pasteNotFound { notchState = .silent }
        showPasteNotFound()
    }

    /// The chevron: the whole transcript, or back to its first lines. The countdown carries on
    /// either way: the island rests about 5 s after it appeared, opened or not.
    func setPasteExpanded(_ open: Bool) {
        guard notchState == .pasteNotFound, open != pasteExpanded, !pasteCopied else { return }
        islandAnimation = reduceMotion ? WorkbenchTokens.Spring.fade
            : (open ? WorkbenchTokens.Paste.expand : WorkbenchTokens.Paste.collapse)
        pasteExpanded = open
    }

    /// Copy: the transcript onto the pasteboard, the button says so, and the island rests.
    func copyTranscript() {
        guard notchState == .pasteNotFound, !pasteCopied else { return }
        pasteboard.clearContents()
        pasteboard.setString(transcript, forType: .string)
        pasteCopied = true
        // The line stops where it was; the island rests once the button has said so.
        pasteTask?.cancel()
        if pasteStart != nil, pastePausedAt == nil { pastePausedAt = Date() }
        pasteTask = Task { [weak self] in
            try? await Task.sleep(for: WorkbenchTokens.Paste.copiedHold)
            guard let self, !Task.isCancelled, self.notchState == .pasteNotFound else { return }
            self.notchState = .silent
        }
    }

    /// Oct 15 review, VF10: Paste beside Copy: the words into the field that's focused now (the path
    /// dictation takes), then the island rests as it does after a dictation lands. False when no
    /// field takes them (the button says so, and the words stay).
    @discardableResult
    func pasteHeldWords() -> Bool {
        guard notchState == .pasteNotFound, !pasteCopied else { return false }
        if let live {
            guard livePasteHeld(live) else { return false }
        } else {
            // The Workbench: the notes' comment box, the one input box on the mock pages.
            guard inputBoxOnScreen else { return false }
            pastedNote = transcript
        }
        pasteTask?.cancel()
        if pasteStart != nil, pastePausedAt == nil { pastePausedAt = Date() }
        pasteLanding = Date()
        pasteTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(WorkbenchTokens.Feedback.landHold))
            guard let self, !Task.isCancelled, self.notchState == .pasteNotFound else { return }
            self.notchState = .silent
        }
        return true
    }

    /// Oct 15 review, VF09 ("Hover keeps the held text open"): the pointer on the held words holds
    /// the 5 s close, the ring still; leaving starts the 5 s again. Copy's own stop isn't undone.
    func setPasteHover(_ inside: Bool) {
        guard notchState == .pasteNotFound, !pasteCopied, pasteStart != nil, !snapshotMode else { return }
        if inside {
            guard pastePausedAt == nil else { return }
            pastePausedAt = Date()
            pasteTask?.cancel()
            pasteTask = nil
        } else if pastePausedAt != nil {
            pastePausedAt = nil
            pasteStart = Date()
            schedulePasteEnd()
        }
    }

    /// ✕ (or esc): the transcript goes, and the island rests.
    func dismissPaste() {
        guard notchState == .pasteNotFound else { return }
        notchState = .silent
    }

    /// The time left before the island rests, 1 → 0: 5 s from appearing, however far the transcript
    /// is opened; it stops where Copy was pressed, and while the pointer is on the words (Oct 15
    /// review, VF09), starting again once it leaves.
    func pasteRemaining(at date: Date) -> Double {
        guard let start = pasteStart else { return snapshotMode ? WorkbenchTokens.Paste.still : 1 }
        let now = pastePausedAt ?? date
        return max(0, min(1, 1 - now.timeIntervalSince(start) / WorkbenchTokens.Paste.duration.seconds))
    }

    func dropPaste() {
        pasteTask?.cancel()
        pasteTask = nil
        pasteStart = nil
        pastePausedAt = nil
        pasteExpanded = false
        pasteCopied = false
    }

    private func startPasteClock() {
        pasteTask?.cancel()
        pasteTask = nil
        pastePausedAt = nil
        pasteStart = snapshotMode ? nil : Date()
        guard !snapshotMode else { return }
        schedulePasteEnd()
    }

    /// Rests the island when the time runs out, unless Copy stopped it or it was restarted.
    private func schedulePasteEnd() {
        pasteTask?.cancel()
        let started = pasteStart
        let left = pasteRemaining(at: Date()) * WorkbenchTokens.Paste.duration.seconds
        pasteTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(left))
            guard let self, !Task.isCancelled, self.notchState == .pasteNotFound, self.pasteStart == started,
                  self.pastePausedAt == nil else { return }
            self.notchState = .silent
        }
    }
}

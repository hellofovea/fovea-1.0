import SwiftUI
import FoveaCore

extension WorkbenchModel {
    /// What the voice said while the bar listened: a request of a few sentences, the length a
    /// spoken one runs to, longer than the lines Paste not found shows closed.
    static let sampleTranscript = "Move this photo above the heading and make the caption a little smaller. "
        + "Then tighten the space between the paragraphs so the article reads as one column, "
        + "and keep the byline where it is."

    // MARK: Transcribing

    /// fn's second press: the words arrive while the progress runs, then they are pasted into
    /// the page's input box and the bar closes, or, with no input box on the page, the island
    /// holds them to copy (Paste not found). A listening session too short to have said
    /// anything transcribes to nothing, and the bar says so. Snapshots hold a frame.
    func startTranscribing() {
        let P = WorkbenchTokens.Progress.self
        let heard = notchState != .voiceFlow || listenStart.map { Date().timeIntervalSince($0) >= P.minimumSpeech.seconds } ?? true
        notchState = .transcribing
        transcribeStart = Date()
        transcript = ""
        guard !snapshotMode else {
            transcript = Self.sampleTranscript
            return
        }
        guard heard else {
            transcribeTask?.cancel()
            transcribeTask = Task { [weak self] in
                try? await Task.sleep(for: P.emptyTranscribe)
                guard let self, !Task.isCancelled, self.notchState == .transcribing else { return }
                self.showNoSpeech()
            }
            return
        }
        if let live, !demoSamples {
            liveTranscribe(live)
            return
        }
        let words = Self.sampleTranscript.split(separator: " ").map(String.init)
        // The words arrive across the transcription's length, however many there are, each on
        // the clock, so the length does not drift with the number of words.
        let interval = min(P.wordInterval, P.transcribeDuration / max(1, words.count))
        let clock = ContinuousClock()
        let start = clock.now
        transcribeTask?.cancel()
        transcribeTask = Task { [weak self] in
            for (i, word) in words.enumerated() {
                guard let self, !Task.isCancelled else { return }
                self.transcript = i == 0 ? word : self.transcript + " " + word
                try? await Task.sleep(until: start + interval * (i + 1), clock: clock)
            }
            try? await Task.sleep(until: start + P.transcribeDuration + P.transcribeHold, clock: clock)
            guard let self, !Task.isCancelled, self.notchState == .transcribing else { return }
            self.deliverTranscript()
        }
    }

    func stopTranscribing() {
        transcribeTask?.cancel()
        transcribeTask = nil
    }

    /// The panel's Transcribing: plays it from the start, from whatever is showing.
    func playTranscribing() {
        dropUndo()
        stopTranscribing()
        startTranscribing()
    }

    // MARK: No speech detected

    /// The transcription found no speech: the bar says so for a moment, then rests, and the
    /// request goes with it (amendment §10: the island rests when the moment runs out).
    func showNoSpeech() {
        stopTranscribing()
        dropUndo()
        notchState = .noSpeech
        noSpeechTask?.cancel()
        guard !snapshotMode else { return }
        noSpeechTask = Task { [weak self] in
            try? await Task.sleep(for: WorkbenchTokens.Progress.noSpeechDuration)
            guard let self, !Task.isCancelled, self.notchState == .noSpeech else { return }
            self.notchState = .silent
        }
    }

    // MARK: Cancel and undo

    /// Esc while listening, capturing or transcribing: the request is cancelled, and for a
    /// moment the bar offers to undo that. Its captures wait with it.
    @discardableResult
    func cancel() -> Bool {
        switch notchState {
        case .voiceFlow: undoMode = capturing ? .addScreenshot : .voiceFlow
        case .transcribing: undoMode = .transcribing
        default: return false
        }
        stopTranscribing()
        notchState = .cancelled
        startUndoClock()
        return true
    }

    /// Undo (the pill or ⌘Z): back to what was cancelled, captures and all.
    @discardableResult
    func undoCancel() -> Bool {
        guard notchState == .cancelled else { return false }
        dropUndo()
        switch undoMode {
        case .transcribing: startTranscribing()
        case .addScreenshot:
            notchState = .voiceFlow
            capturing = true
        default:
            notchState = .voiceFlow
        }
        return true
    }

    /// The panel's Cancelled: cancels what is showing, or shows the undo window for an empty
    /// request when nothing is.
    func playCancelled() {
        if notchState == .voiceFlow || notchState == .transcribing {
            cancel()
            return
        }
        dropUndo()
        undoMode = .voiceFlow
        notchState = .cancelled
        startUndoClock()
    }

    /// The time left to undo, 1 → 0; it holds while the pointer rests on the bar.
    func undoRemaining(at date: Date) -> Double {
        guard let start = undoStart else { return WorkbenchTokens.Progress.stillUndo }
        let now = undoPausedAt ?? date
        let length = WorkbenchTokens.Progress.undoDuration.seconds
        return max(0, min(1, 1 - now.timeIntervalSince(start) / length))
    }

    /// The pointer on the bar pauses the countdown; leaving resumes it where it was. Nobody
    /// loses the request while reaching for Undo (toast libraries pause on hover; WCAG 2.2.1
    /// counts an expiring undo window as a time limit).
    func setUndoHover(_ inside: Bool) {
        guard notchState == .cancelled, let start = undoStart else { return }
        if inside, undoPausedAt == nil {
            undoPausedAt = Date()
            undoTask?.cancel()
            undoTask = nil
        } else if !inside, let paused = undoPausedAt {
            undoStart = start.addingTimeInterval(Date().timeIntervalSince(paused))
            undoPausedAt = nil
            scheduleUndoEnd()
        }
    }

    /// How far the transcription is, 0 → 1.
    func transcribeProgress(at date: Date) -> Double {
        guard let start = transcribeStart, !snapshotMode else { return WorkbenchTokens.Progress.stillTranscribe }
        return max(0, min(1, date.timeIntervalSince(start) / WorkbenchTokens.Progress.transcribeDuration.seconds))
    }

    func dropUndo() {
        undoTask?.cancel()
        undoTask = nil
        undoStart = nil
        undoPausedAt = nil
    }

    private func startUndoClock() {
        undoStart = snapshotMode ? nil : Date()
        undoPausedAt = nil
        guard !snapshotMode else { return }
        scheduleUndoEnd()
    }

    /// Lets the request go when the time left runs out, unless undone, paused or restarted.
    private func scheduleUndoEnd() {
        undoTask?.cancel()
        let started = undoStart
        let left = undoRemaining(at: Date()) * WorkbenchTokens.Progress.undoDuration.seconds
        undoTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(left))
            guard let self, !Task.isCancelled, self.notchState == .cancelled, self.undoStart == started,
                  self.undoPausedAt == nil else { return }
            self.notchState = .silent
        }
    }
}

extension Duration {
    var seconds: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}

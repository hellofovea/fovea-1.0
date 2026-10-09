import SwiftUI
import AppKit
import FoveaKit
import FoveaPlatform
import CapturesCore

// The Workbench model's steps that the real Mac does differently (IslandLive): the words come
// from the microphone, they paste into the app in front, the pictures come from the screen, the
// highlighter reads the app under it, and each finished capture goes to Home.

extension WorkbenchModel {
    // MARK: Words

    /// The microphone couldn't start, or speech recognition can't run: said on the island.
    func voiceFailed(_ failure: VoiceFailure) {
        switch failure {
        case .microphoneDenied: showVoiceError(.micPermission)
        case .microphoneUnavailable: showVoiceError(.micUnavailable)
        // The bar listens on; it says why there'll be no words once it stops.
        case .speechDenied, .speechUnavailable, .recognitionFailed: break
        }
    }

    /// Voiceflow's Transcribing on the real Mac: the last words, then the paste.
    func liveTranscribe(_ live: IslandLive) {
        let P = WorkbenchTokens.Progress.self
        transcribeTask?.cancel()
        transcribeTask = Task { [weak self] in
            let result = await live.finishWords()
            guard let self, !Task.isCancelled, self.notchState == .transcribing else { return }
            guard !result.text.isEmpty else {
                if result.failure == .speechDenied { self.showVoiceError(.speechPermission) } else { self.showNoSpeech() }
                return
            }
            self.transcript = result.text
            // The line runs at least a moment, so the words are seen arriving.
            let shown = Date().timeIntervalSince(self.transcribeStart ?? Date())
            let rest = P.minimumLiveTranscribe - shown
            if rest > 0 { try? await Task.sleep(for: .seconds(rest)) }
            guard !Task.isCancelled, self.notchState == .transcribing else { return }
            self.deliverTranscript()
        }
    }

    /// Dispatch's Transcribing on the real Mac: the words, the script that fits them, then Choose
    /// chat (or straight on, as the Workbench does).
    func liveFinishV2(_ live: IslandLive) {
        v2Transcribe?.cancel()
        v2Transcribe = Task { [weak self] in
            let result = await live.finishWords()
            guard let self, !Task.isCancelled, self.notchState == .v2Transcribing else { return }
            guard !result.text.isEmpty else {
                if result.failure == .speechDenied { self.showVoiceError(.speechPermission) } else { self.showNoSpeech() }
                return
            }
            self.v2Words = result.text
            let matched = RequestMatcher.match(result.text, tookSomething: !self.liveReferents.isEmpty)
            self.v2Request = V2Request(rawValue: matched.rawValue) ?? .code
            let shown = Date().timeIntervalSince(self.v2TranscribeStart)
            let rest = WorkbenchTokens.V2.transcribeTime - shown
            if rest > 0 { try? await Task.sleep(for: .seconds(rest)) }
            guard !Task.isCancelled, self.notchState == .v2Transcribing else { return }
            live.director?.islandDidEmit(.transcribing(dispatch: true))
            if let id = self.v2Continuing, self.v2Task(id) != nil {
                self.askMoreV2(id, text: result.text)
            } else if !self.v2ReviewBeforeSend {
                self.sendWithoutReview()
            } else {
                self.showV2Send()
                live.director?.islandDidEmit(.chooseChatShown)
            }
        }
    }

    /// The request's words as said (or the script's, in the Workbench).
    var v2Spoken: String { v2Words ?? v2Request.spoken }

    // MARK: Pasting

    /// The words into the field the person is typing in, and Home keeps them.
    func liveLand(_ live: IslandLive) {
        live.paste(transcript)
        live.logDictation(text: transcript, referents: liveReferents)
        live.director?.islandDidEmit(.dictationLanded)
        pasteLanding = Date()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(WorkbenchTokens.Feedback.landHold))
            guard let self, self.notchState == .transcribing else { return }
            self.notchState = .silent
        }
    }

    // MARK: Pictures

    /// A part of the real screen, Fovea's own marks left out.
    func liveCapture(_ live: IslandLive, _ rect: CGRect, animated: Bool) async {
        selection = nil
        try? await Task.sleep(for: WorkbenchTokens.Capture.clearDelay)
        guard ScreenCapturer.allowed || live.director != nil else {
            showBarNotice(.screenRecording)
            return
        }
        guard let image = await live.image(of: rect) else {
            showBarNotice(.screenRecording)
            return
        }
        add(image: image, from: rect, animated: animated, source: live.source(of: rect))
        live.director?.islandDidEmit(.referentTaken(kind: .region, rect: rect))
    }

    /// ⌘ twice: the whole screen, Fovea's own surfaces left out.
    func liveWholeScreen(_ live: IslandLive) async {
        guard ScreenCapturer.allowed || live.director != nil else {
            showBarNotice(.screenRecording)
            return
        }
        guard let image = await live.image(of: display.frame), notchState.collects else {
            showBarNotice(.screenRecording)
            return
        }
        add(image: image, from: display.frame.insetBy(dx: 40, dy: 40), animated: !reduceMotion, kind: .screenshot,
            source: "The whole screen")
        live.director?.islandDidEmit(.referentTaken(kind: .wholeScreen, rect: display.frame))
    }

    // MARK: The highlighter

    /// Let go on the real screen: a click takes the Finder file or the paragraph under it; a drag
    /// takes the words it crossed, as text with a picture of them.
    func finishLiveHighlight(_ live: IslandLive, from a: CGPoint, to b: CGPoint) {
        if hypot(a.x - b.x, a.y - b.y) <= 3 {
            if let found = live.file(at: b) {
                markFile(url: found.url, rect: found.rect)
                live.director?.islandDidEmit(.referentTaken(kind: .file, rect: found.rect))
                highlighting = false
            } else if let para = live.paragraph(at: b) {
                markLiveText(live, para.text, rects: para.rects)
                highlighting = false
            }
            return
        }
        let runs = highlightRuns(from: a, to: b)
        guard !runs.rects.isEmpty else { return }
        markLiveText(live, runs.text, rects: runs.rects)
        highlighting = false
    }

    /// Words taken: their card (or, where the app gave no words, a picture of the marked lines),
    /// the marks left on the screen.
    func markLiveText(_ live: IslandLive, _ text: String, rects: [CGRect]) {
        let union = rects.dropFirst().reduce(rects.first ?? .zero) { $0.union($1) }
        highlights.append(ScreenHighlight(rects: rects, file: false, referent: nil))
        let source = live.source(of: union)
        Task { [weak self] in
            guard let self else { return }
            if text.isEmpty {
                // Nothing the app would say: the marked lines, as a picture.
                guard let image = await live.image(of: union.insetBy(dx: -4, dy: -4)) else { return }
                self.add(image: image, from: union, animated: !self.reduceMotion, kind: .screenshot, source: source)
            } else if let card = AttachmentCards.text(text) {
                self.add(image: card, from: union, animated: !self.reduceMotion, kind: .text(text), source: source)
            }
            if let last = self.highlights.indices.last { self.highlights[last].referent = self.referents.last?.id }
            live.director?.islandDidEmit(.referentTaken(kind: .passage, rect: union))
        }
    }

    /// A file on this Mac, taken: its card, its mark round the icon.
    func markFile(url: URL, rect: CGRect) {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map {
            ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file)
        } ?? ""
        let file = DesktopFile(name: url.lastPathComponent, size: size)
        guard let card = AttachmentCards.file(file) else { return }
        add(image: card, from: rect, animated: !reduceMotion, kind: .file(name: file.name, size: file.size),
            source: url.deletingLastPathComponent().lastPathComponent)
        highlights.append(ScreenHighlight(rects: [rect.insetBy(dx: -6, dy: -5)], file: true, referent: referents.last?.id))
    }

    // MARK: Previews

    enum PreviewKind { case aura, panel }

    /// A choice shown at the notch: Dispatch's bar with its glow (no microphone), or the board
    /// with a sample session (so Attached and Floating can be seen).
    func showPreview(_ kind: PreviewKind) {
        previewing = true
        switch kind {
        case .aura:
            restingFlow = .dispatchV2
            if notchState != .v2Voice { notchState = .v2Voice }
        case .panel:
            if notchState == .v2Voice { notchState = .silent }
            stagePreviewBoard()
        }
    }

    func endPreview() {
        guard previewing else { return }
        previewing = false
        if notchState == .v2Voice || notchState == .v2Board { notchState = .silent }
        removePreviewBoard()
    }

    /// One sample session on the board, for a look at it.
    private func stagePreviewBoard() {
        if v2Sessions.isEmpty {
            v2Sessions.insert(Self.previewSessionID)
            if !agentTasks.contains(where: { $0.id == Self.previewSessionID }),
               let sample = agentTasks.first(where: { DispatchV2.sampleIds.contains($0.id) && $0.state == .working }) {
                agentTasks.append(sample.renamed(Self.previewSessionID))
            }
        }
        showAgentPanel(pinned: true)
    }

    private func removePreviewBoard() {
        guard v2Sessions.contains(Self.previewSessionID) else { return }
        v2Sessions.remove(Self.previewSessionID)
        agentTasks.removeAll { $0.id == Self.previewSessionID }
    }

    static let previewSessionID = "t-preview"
}

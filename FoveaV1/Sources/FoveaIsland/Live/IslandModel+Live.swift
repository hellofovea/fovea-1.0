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

    /// Recognition that broke, rather than heard nothing: "Something went wrong" (feedback #2, Oct 11).
    static func unexpected(_ failure: VoiceFailure) -> Bool {
        failure == .recognitionFailed || failure == .speechUnavailable
    }

    /// Voiceflow's Transcribing on the real Mac: the last words, then the paste.
    func liveTranscribe(_ live: IslandLive) {
        let P = WorkbenchTokens.Progress.self
        transcribeTask?.cancel()
        transcribeTask = Task { [weak self] in
            let result = await live.finishWords()
            guard let self, !Task.isCancelled, self.notchState == .transcribing else { return }
            guard !result.text.isEmpty else {
                if result.failure == .speechDenied { self.showVoiceError(.speechPermission) }
                else if result.failure.map(Self.unexpected) == true { self.showVoiceError(.unexpected) }
                else { self.showNoSpeech() }
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
            let continuing = self.v2Continuing.flatMap { self.v2Task($0) != nil ? $0 : nil }
            guard !result.text.isEmpty else {
                if result.failure == .speechDenied { self.showVoiceError(.speechPermission) }
                else if continuing == nil, result.failure.map(Self.unexpected) == true { self.showVoiceError(.unexpected) }
                // Asking more and nothing heard: back to the session as it was.
                else if let id = continuing { self.returnToV2Chat(id) }
                else { self.showNoSpeech() }
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
            if let id = continuing {
                // The new question goes into the session, which stays on screen, working.
                self.askMoreV2(id, text: result.text, inWindow: true)
                self.returnToV2Chat(id)
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

    /// #7: where the words went, lit a moment, as the Workbench's field does (Oct 11).
    private func markLanding(_ live: IslandLive) {
        // Oct 18, Ryan: the field the words go to now (under the pointer, or the focused one).
        guard live.smoke == nil, let frame = live.landingFrame, frame.width > 0 else { return }
        let rect = Screens.local(frame, on: live.screen).insetBy(dx: -4, dy: -3)
        let mark = ScreenHighlight(rects: [rect], file: true, referent: nil)
        highlights.append(mark)
        fadeLiveMark(mark.id)
    }

    /// The words into the field the person is typing in, then what was taken (Oct 17, Ryan), and
    /// Home keeps them.
    func liveLand(_ live: IslandLive) {
        // Oct 17, Ryan: landed, the words it took are no longer marked.
        clearTakenMarks()
        markLanding(live)
        live.paste(Self.pastePieces(words: transcript, referents: liveReferents))
        live.logDictation(text: transcript, referents: liveReferents)
        live.director?.islandDidEmit(.dictationLanded)
        pasteLanding = Date()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(WorkbenchTokens.Feedback.landHold))
            guard let self, self.notchState == .transcribing else { return }
            self.notchState = .silent
        }
    }

    /// Oct 15 review, VF10: Paste beside Copy on the held words: into the field focused now, by the
    /// path dictation takes (Home already keeps them). False when nothing takes a paste.
    func livePasteHeld(_ live: IslandLive) -> Bool {
        guard live.canPaste else { return false }
        markLanding(live)
        live.paste(Self.pastePieces(words: transcript, referents: liveReferents))
        return true
    }

    /// Oct 17, Ryan ("paste them after the words"): what a dictation pastes, in turn into the same
    /// field: the words first, then each referent in the order taken: words taken, in quotes on
    /// lines of their own; a screenshot, as a picture; a file, as the file. Each picture or file
    /// starts on a line of its own. The words go first, so a field that takes text only still
    /// gets them.
    static func pastePieces(words: String, referents: [CapturedReferent]) -> [Paster.Piece] {
        var pieces: [Paster.Piece] = [.text(words)]
        func text(_ more: String) {
            if case .text(let last)? = pieces.last { pieces[pieces.count - 1] = .text(last + more) }
            else { pieces.append(.text(more)) }
        }
        for referent in referents {
            switch referent.kind {
            case .text(let taken):
                text("\n“\(taken)”")
            case .screenshot:
                guard let png = referent.image.pngData else { continue }
                text("\n")
                pieces.append(.image(png))
            case .file:
                guard let url = referent.fileURL else { continue }
                text("\n")
                pieces.append(.file(url))
            }
        }
        return pieces
    }

    // MARK: Pictures

    /// A part of the real screen, Fovea's own marks left out.
    func liveCapture(_ live: IslandLive, _ rect: CGRect, animated: Bool) async {
        selection = nil
        try? await Task.sleep(for: WorkbenchTokens.Capture.clearDelay)
        guard ScreenCapturer.allowed || live.director != nil || live.smoke != nil else {
            showBarNotice(.screenRecording)
            return
        }
        // The first run: a drag that misses what the task asks for is said, not taken.
        if let director = live.director, !director.acceptRegion(rect) { return }
        guard let image = await live.image(of: rect) else {
            showBarNotice(.screenRecording)
            return
        }
        if Self.tooLarge(image) { showBarNotice(.imageTooLarge); return }
        add(image: image, from: rect, animated: animated, source: live.source(of: rect))
        live.director?.islandDidEmit(.referentTaken(kind: .region, rect: rect))
    }

    /// A screenshot past the 20 MB a request may carry, as the PNG it would be sent as.
    static func tooLarge(_ image: NSImage) -> Bool {
        guard let tiff = image.tiffRepresentation, tiff.count > WorkbenchTokens.Feedback.imageLimit / 4,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return false }
        return png.count > WorkbenchTokens.Feedback.imageLimit
    }

    /// Oct 15 review, VF05: a region taken in capture mode on another display than the island's.
    func liveCaptureOther(_ live: IslandLive, _ rect: CGRect, on screen: NSScreen) async {
        try? await Task.sleep(for: WorkbenchTokens.Capture.clearDelay)
        guard ScreenCapturer.allowed, let image = await live.image(of: rect, on: screen) else {
            showBarNotice(.screenRecording)
            return
        }
        guard notchState.collects else { return }
        if Self.tooLarge(image) { showBarNotice(.imageTooLarge); return }
        add(image: image, from: rect, animated: false, source: live.source(of: rect, on: screen), otherDisplay: true)
    }

    /// ⌘ twice: the whole screen, Fovea's own surfaces left out. Over another display than the
    /// island's, that display (Oct 15 review, VF05).
    func liveWholeScreen(_ live: IslandLive) async {
        guard ScreenCapturer.allowed || live.director != nil || live.smoke != nil else {
            showBarNotice(.screenRecording)
            return
        }
        if live.smoke == nil, live.director == nil, let other = Screens.underPointer, !Screens.same(other, live.screen) {
            guard let image = await live.image(of: CGRect(origin: .zero, size: other.frame.size), on: other), notchState.collects else {
                showBarNotice(.screenRecording)
                return
            }
            if Self.tooLarge(image) { showBarNotice(.imageTooLarge); return }
            add(image: image, from: display.frame.insetBy(dx: 40, dy: 40), animated: false, kind: .screenshot,
                source: L("The whole screen"), otherDisplay: true)
            return
        }
        guard let image = await live.image(of: display.frame), notchState.collects else {
            showBarNotice(.screenRecording)
            return
        }
        if Self.tooLarge(image) { showBarNotice(.imageTooLarge); return }
        add(image: image, from: display.frame.insetBy(dx: 40, dy: 40), animated: !reduceMotion, kind: .screenshot,
            source: L("The whole screen"))
        live.director?.islandDidEmit(.referentTaken(kind: .wholeScreen, rect: display.frame))
    }

    // MARK: Oct 17, Ryan: words and files with no key

    /// While Fovea listens (Voiceflow and Dispatch), a press in another app that selected words (a
    /// drag across them, a double or a triple click) takes them, marked where they are; a click on
    /// a file in Finder or on the desktop takes the file. A plain click that selects nothing takes
    /// nothing; nothing is ever done to the press itself (the app gets it as always). In Voiceflow,
    /// words selected in a field that takes text stay there: that's where the dictation will paste.
    /// `a` and `b` are where the press began and ended, in global top-left points.
    func autoTake(_ live: IslandLive, from a: CGPoint, to b: CGPoint, clicks: Int, before: String? = nil) {
        guard notchState.collects, !capturing, !highlighting else { return }
        let dragged = hypot(a.x - b.x, a.y - b.y) > WorkbenchTokens.Capture.dragThreshold
        // Oct 17, Ryan: a click is never a file taken (it may be opening it): files are dragged
        // onto the notch (`dropFiles`). A plain click takes nothing.
        guard dragged || clicks >= 2 else { return }
        if live.readsSelectionAtOnce {
            guard let found = live.selectionMade(from: a, to: b, clicks: clicks), !found.text.isEmpty else { return }
            let la = live.localPoint(a), lb = live.localPoint(b)
            take(live, text: found.text, rects: found.rects, editable: found.editable, span: CGRect(from: la, to: lb),
                 at: lb, dragged: dragged, window: nil)
            return
        }
        // Oct 18, Ryan: another app's selection, read off the main thread as the app made it.
        live.selectionReader.read(at: b) { [weak self] read in
            guard let self else { return }
            live.draftMark = nil
            defer { live.syncMarks?() }
            guard let read, read.text != before else { return }
            let span = CGRect(from: a, to: b)
            self.take(live, text: read.text, rects: read.rects.map(live.local), editable: read.editable,
                      span: live.local(span), at: live.localPoint(b), dragged: dragged, window: read)
        }
    }

    /// Words found selected: taken, unless they're in the field the words will paste into
    /// (Voiceflow), or aren't where the press was (a selection left from before), or were just taken.
    /// `rects` and `span` in the island's points; `window`, the other app's window they're in.
    private func take(_ live: IslandLive, text: String, rects found: [CGRect], editable: Bool, span: CGRect,
                      at lb: CGPoint, dragged: Bool, window: SelectionRead?) {
        guard notchState.collects, !capturing else { return }
        // In the field the words will paste into, a selection is for them to replace.
        if notchState == .voiceFlow, editable { return }
        let slack = WorkbenchTokens.Capture.selectionSlack
        if !found.isEmpty, !found.contains(where: { $0.intersects(span.insetBy(dx: -slack, dy: -slack)) }) { return }
        // Taken already, just now.
        if case .text(let last)? = liveReferents.last?.kind, last == text { return }
        // Oct 17, Ryan: where the app gives no lines, what can be marked: the drag's span (or,
        // after a double or triple click, the line under it).
        let rects = found.isEmpty
            ? [dragged ? span.insetBy(dx: 0, dy: min(0, (span.height - 20) / 2))
                       : CGRect(x: lb.x - 60, y: lb.y - 11, width: 120, height: 22)]
            : found
        markLiveText(live, text, rects: rects, otherDisplay: !rects.contains(where: live.onIslandDisplay), window: window)
    }

    /// Oct 18, Ryan: the words being selected, drawn as they'll be taken while the cursor moves:
    /// read off the main thread, the newest point winning; nothing for a drag over no words (a
    /// window moved), or for a selection that was there before the press.
    func draftSelection(_ live: IslandLive, from a: CGPoint, to b: CGPoint) {
        guard notchState.collects, !capturing, !highlighting else { return }
        if live.readsSelectionAtOnce {
            // The first run's practice windows answer at once, in the island's points.
            if live.director != nil, let run = live.director?.textRun(from: live.localPoint(a), to: live.localPoint(b)) {
                if highlightDraft != run.rects { highlightDraft = run.rects }
            }
            return
        }
        let now = Date()
        guard now.timeIntervalSince(live.lastDragRead) >= WorkbenchTokens.Capture.dragReadInterval else { return }
        live.lastDragRead = now
        let before = live.pressText, pressed = live.pressWindow
        live.selectionReader.readLatest(at: b) { [weak self] read in
            guard let self, live.pressAt != nil else { return }
            var draft: (window: CGWindowID, bounds: CGRect, rects: [CGRect])?
            let span = CGRect(from: a, to: b).insetBy(dx: -WorkbenchTokens.Capture.selectionSlack, dy: -WorkbenchTokens.Capture.selectionSlack)
            if let read, read.text != before, read.window == pressed, !(self.notchState == .voiceFlow && read.editable),
               read.rects.contains(where: { $0.intersects(span) }) {
                draft = (read.window, read.windowBounds, read.rects.map { MarkGeometry.local($0, in: read.windowBounds) })
            }
            if live.draftMark?.rects != draft?.rects || live.draftMark?.window != draft?.window {
                live.draftMark = draft
                live.syncMarks?()
            }
        }
    }

    /// Oct 17, Ryan: files dragged onto the notch while it listens (or onto Choose chat, adding to
    /// the request): each a file referent with its card, flying in from where it was let go
    /// (`at`, the island's points). A picture over the limit isn't added, and the bar says so.
    @discardableResult
    func dropFiles(_ urls: [URL], at point: CGPoint) -> Bool {
        guard notchState.collects || notchState == .v2Send else { return false }
        var took = false
        for url in urls where url.isFileURL && !liveReferents.contains(where: { $0.fileURL == url }) {
            // The first run as the old click had it: asked first (a no refuses the drop), then told
            // what was taken and where it was let go (its packing list counts on that event).
            if let director = live?.director, !director.acceptFile(url) { continue }
            let rect = CGRect(x: point.x - 24, y: point.y - 24, width: 48, height: 48)
            if takeFile(url: url, from: rect) {
                took = true
                live?.director?.islandDidEmit(.referentTaken(kind: .file, rect: rect))
            }
        }
        return took
    }

    /// Words taken: their card (or, where the app gave no words, a picture of the marked lines),
    /// the marks left on the screen. On another display than the island's (Oct 15 review, VF05),
    /// no flight; the referent says where it came from. Oct 18, Ryan: taken from another app's
    /// window (`window`), the mark is drawn over that window, wherever it is, and only there.
    func markLiveText(_ live: IslandLive, _ text: String, rects: [CGRect], otherDisplay: Bool = false,
                      window: SelectionRead? = nil) {
        let union = rects.dropFirst().reduce(rects.first ?? .zero) { $0.union($1) }
        // Oct 17, Ryan: the accent highlighter's mark, kept for the session (`clearTakenMarks`).
        var mark = ScreenHighlight(rects: rects, file: false, referent: nil, taken: true)
        if let window {
            mark.window = window.window
            mark.windowBounds = window.windowBounds
            mark.windowRects = (window.rects.isEmpty ? rects.map(live.global) : window.rects)
                .map { MarkGeometry.local($0, in: window.windowBounds) }
        }
        if !otherDisplay || window != nil { highlights.append(mark) }
        let source = otherDisplay ? live.source(atGlobal: live.global(CGPoint(x: union.midX, y: union.midY))) : live.source(of: union)
        Task { [weak self] in
            guard let self else { return }
            let animated = !self.reduceMotion && !otherDisplay
            if text.isEmpty {
                // Nothing the app would say: the marked lines, as a picture.
                guard !otherDisplay, let image = await live.image(of: union.insetBy(dx: -4, dy: -4)) else { return }
                self.add(image: image, from: union, animated: animated, kind: .screenshot, source: source)
            } else if let card = AttachmentCards.text(text) {
                self.add(image: card, from: union, animated: animated, kind: .text(text), source: source, otherDisplay: otherDisplay)
            }
            if let i = self.highlights.firstIndex(where: { $0.id == mark.id }) { self.highlights[i].referent = self.referents.last?.id }
            live.director?.islandDidEmit(.referentTaken(kind: .passage, rect: union))
        }
    }

    /// Oct 17, Ryan: the session is done (landed, sent, cancelled…): the marks of the words it took go.
    func clearTakenMarks() {
        if highlights.contains(where: \.taken) { highlights.removeAll { $0.taken } }
    }

    /// A file dropped on the notch: its card, flying in from where it was let go. False when it
    /// isn't added (a picture over the limit: the bar says so).
    func takeFile(url: URL, from rect: CGRect) -> Bool {
        if let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey]),
           values.contentType?.conforms(to: .image) == true,
           (values.fileSize ?? 0) > WorkbenchTokens.Feedback.imageLimit {
            showBarNotice(.imageTooLarge)
            return false
        }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map {
            ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file)
        } ?? ""
        let file = DesktopFile(name: url.lastPathComponent, size: size)
        guard let card = AttachmentCards.file(file) else { return false }
        add(image: card, from: rect, animated: !reduceMotion && notchState.collects, kind: .file(name: file.name, size: file.size),
            source: url.deletingLastPathComponent().lastPathComponent, fileURL: url)
        return true
    }

    /// A file on this Mac, taken: its card, its mark round the icon (on the island's display).
    func markFile(url: URL, rect: CGRect, otherDisplay: Bool = false) {
        // A picture over the limit isn't added, and the bar says so (feedback #2, Oct 11).
        if let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey]),
           values.contentType?.conforms(to: .image) == true,
           (values.fileSize ?? 0) > WorkbenchTokens.Feedback.imageLimit {
            showBarNotice(.imageTooLarge)
            return
        }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map {
            ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file)
        } ?? ""
        let file = DesktopFile(name: url.lastPathComponent, size: size)
        guard let card = AttachmentCards.file(file) else { return }
        add(image: card, from: rect, animated: !reduceMotion && !otherDisplay, kind: .file(name: file.name, size: file.size),
            source: url.deletingLastPathComponent().lastPathComponent, otherDisplay: otherDisplay, fileURL: url)
        hoverMark = nil
        guard !otherDisplay else { return }
        let mark = ScreenHighlight(rects: [rect.insetBy(dx: -6, dy: -5)], file: true, referent: referents.last?.id)
        highlights.append(mark)
        fadeLiveMark(mark.id)
    }

    /// A mark says what was taken, then goes once it has flown into the stack (Oct 9, evening:
    /// it stayed on, and over the next app too, since the island is on every Space).
    private func fadeLiveMark(_ id: UUID) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(WorkbenchTokens.Feedback.liveMarkHold))
            self?.highlights.removeAll { $0.id == id }
        }
    }

    // MARK: Previews

    enum PreviewKind { case aura, panel }

    /// A choice shown at the notch: Dispatch's bar with its glow (no microphone), or the board
    /// with a sample session (so Attached and Floating can be seen).
    func showPreview(_ kind: PreviewKind) {
        previewing = true
        // A voice that never falls quiet, so the glow shows the whole time it's being chosen.
        voiceGlow.liveLevel = { 0.62 + 0.22 * sin(Date().timeIntervalSinceReferenceDate * 2.3) }
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
        voiceGlow.liveLevel = { [weak live] in live?.level ?? 0 }
        if notchState == .v2Voice || notchState == .v2Board { notchState = .silent }
        removePreviewBoard()
    }

    /// Three sample sessions on the board (one waiting on you, one done, one at work), for a look
    /// at it: one row didn't show a change of size (Oct 10).
    private func stagePreviewBoard() {
        if v2Sessions.isEmpty {
            let wanted: [AgentTaskState] = [.needsYou, .complete, .working]
            for (i, state) in wanted.enumerated() {
                let id = Self.previewSessionID + "-\(i)"
                guard !agentTasks.contains(where: { $0.id == id }),
                      let sample = agentTasks.first(where: { DispatchV2.sampleIds.contains($0.id) && $0.state == state }) else { continue }
                agentTasks.append(sample.renamed(id))
                v2Sessions.insert(id)
            }
        }
        showAgentPanel(pinned: true)
    }

    private func removePreviewBoard() {
        let ids = (0..<3).map { Self.previewSessionID + "-\($0)" }
        guard ids.contains(where: v2Sessions.contains) else { return }
        for id in ids { v2Sessions.remove(id) }
        agentTasks.removeAll { ids.contains($0.id) }
    }

    static let previewSessionID = "t-preview"
}

import SwiftUI
import AppKit
import FoveaCore
import FoveaKit
import FoveaLook
import FoveaPlatform

/// Oct 18, Ryan: a word whose English means two things in the app ("Done" the first run's button
/// and a state here, "Running" a board section and a step's verb, "Thinking" the agent at work
/// and the model sheet's row), looked up by a key of its own so Chinese can say each: the English
/// as given, the Chinese under `key` in Localization/zh-Hans/island.strings.
func L(_ key: StaticString, english: String.LocalizationValue) -> String {
    // Oct 21, perf: remembered (FoveaKit's `LookupMemo`); the lookup itself is as it was.
    LookupMemo.shared.value(language: FoveaLocale.shared.language, key: key, english: english) {
        String(localized: LocalizedStringResource(key, defaultValue: english, locale: FoveaLocale.shared.locale, bundle: .main))
    }
}

// The dev team's notch feedback of Oct 6 and Yulun's answers, one panel tab per item
// (docs/island/FEEDBACK_2026-10-06.md has every decision and why). Items 5, 18, 20, 21 and 22
// were set aside; 8, 14 and 17 are research, written up, not drawn.

/// A tab under Feedback in the panel: what it stages on the mock display.
enum FeedbackItem: String, CaseIterable, Identifiable {
    case modelEffort, errors, textFiles, countdown, splitView, landing, progress, answer, titles,
         steps, skipReview, reanswer, queue

    var id: String { rawValue }
    var title: String {
        switch self {
        case .modelEffort: return "1 · One stack, model and effort"
        case .errors: return "2 · Errors on the island"
        case .textFiles: return "3, 8 · Highlighter and screenshots"
        case .countdown: return "4 · The last minute"
        case .splitView: return "6 · Split View follows the pointer"
        case .landing: return "7 · Words land, the notch leaves"
        case .progress: return "9–10, 17 · The control board"
        case .answer: return "11–13 · The answer"
        case .titles: return "15 · Titles named from the request"
        case .steps: return "16 · One step at a time"
        case .skipReview: return "19 · Skip reviewing the words"
        case .reanswer: return "23 · Answer again, stop"
        case .queue: return "24 · Queue"
        }
    }
}

/// #3's stages: picking with ⌘, the stack holding all three kinds, and the stack opened.
enum SelectStage: String, CaseIterable, Identifiable {
    case highlighting, file, stack, opened
    var id: String { rawValue }
    var title: String {
        switch self {
        case .highlighting: return "Text"
        case .file: return "File"
        case .stack: return "Stack"
        case .opened: return "Opened"
        }
    }
}

/// A mark the highlighter left on the screen: the strokes over the words (or round a file), and
/// the referent it made. It stays while the session lasts.
struct ScreenHighlight: Identifiable, Equatable {
    let id = UUID()
    var rects: [CGRect]
    var file: Bool
    var referent: UUID?
    /// Oct 17, Ryan: words taken while Fovea listens: a highlighter's mark in the accent over
    /// exactly their lines, kept until the session is done or the referent leaves the stack.
    var taken = false
    /// Oct 18, Ryan: taken from another app's window: drawn over that window (`MarkWindow`), on its
    /// display and its Space only, not in the island's layer. Its rects there, in that window's own
    /// top-left points.
    var window: CGWindowID? = nil
    var windowRects: [CGRect] = []
    var windowBounds: CGRect = .zero
}

/// Fovea's accent (FoveaKit's `FoveaAccent`), in the system's own colors (FoveaLook): the
/// highlighter's ink, the insertion caret, Native's primary actions.
extension FoveaAccent {
    var system: Color { color }
}

/// #4's stages: the last minute begins, and its last seconds run out.
enum CountdownStage: String, CaseIterable, Identifiable {
    case lastMinute, lastSeconds
    var id: String { rawValue }
    var title: String {
        switch self {
        case .lastMinute: return "One minute left"
        case .lastSeconds: return "Ten seconds left"
        }
    }
}

/// A session at work, or done: the stages #9–#13 and #23 show.
enum WorkStage: String, CaseIterable, Identifiable {
    case working, done
    var id: String { rawValue }
    var title: String { self == .working ? "Working" : "Done" }
}

/// A part of the board, in the hover list's order (PRD §8): what waits on the person, what came
/// back, what runs, what can't be read.
enum BoardSection: Int, CaseIterable, Identifiable {
    case needsYou, done, running, unknown
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .needsYou: return L("Needs you")
        case .running: return L("Running")
        case .done: return L("island.done", english: "Done")
        case .unknown: return L("Status unavailable")
        }
    }
}

/// #16, Oct 7: where the agent's steps are watched.
enum StepsStage: String, CaseIterable, Identifiable {
    case session, board
    var id: String { rawValue }
    var title: String { self == .session ? "Session" : "Board" }
}

/// #24's stages.
enum QueueStage: String, CaseIterable, Identifiable {
    case queued, paused
    var id: String { rawValue }
    var title: String { self == .queued ? "Two waiting" : "Paused" }
}

/// Split View's two apps.
enum SplitSide: Hashable {
    case left, right
}

// MARK: - #2 The errors

/// Everything that can go wrong around a voice session, in the product's own English
/// (fovea-mac's `UserFacingError` and `Loc`), shaped for the notch: a title, one line, at most one
/// action. "No speech detected" keeps its own band (it already shipped in the design).
enum VoiceError: String, CaseIterable, Identifiable {
    case noSpeech, tooShort, micPermission, micUnavailable, speechPermission, screenRecording, imageTooLarge,
         offline, timeout, serverUnavailable, sessionExpired, quotaUsed, trialEnded, proExpired,
         rateLimited, tooLarge, unexpected

    var id: String { rawValue }

    /// When it shows: as the bar opens (the microphone can't start), inside the listening bar
    /// (the session goes on), or after the words went to the server.
    enum Moment { case start, inBar, afterStop }

    /// Its tone, as Choose chat's notices have it: information in white, the person's turn in
    /// Needs you amber, a failure in Failed red.
    enum Tone { case info, yours, failure }

    enum Action: String {
        case retry = "Retry", openSettings = "Open Settings", signIn = "Sign in", upgrade = "Upgrade", renew = "Renew"
        /// Oct 15 review, NH-04: the microphone is chosen in Fovea's Settings › Voice.
        case chooseMicrophone = "Choose Microphone…"

        /// A label longer than Open Settings: its notice is a little wider.
        var isLong: Bool { self == .chooseMicrophone }

        /// Oct 18, Ryan: the button's words, in the primary language.
        var label: String {
            switch self {
            case .retry: return L("Retry")
            case .openSettings: return L("Open Settings")
            case .signIn: return L("Sign in")
            case .upgrade: return L("Upgrade")
            case .renew: return L("Renew")
            case .chooseMicrophone: return L("Choose Microphone…")
            }
        }
    }

    var moment: Moment {
        switch self {
        case .micPermission, .micUnavailable, .speechPermission: return .start
        case .screenRecording, .imageTooLarge: return .inBar
        default: return .afterStop
        }
    }

    var tone: Tone {
        switch self {
        case .noSpeech, .tooShort, .rateLimited, .imageTooLarge: return .info
        case .micPermission, .speechPermission, .screenRecording, .sessionExpired, .quotaUsed, .trialEnded, .proExpired: return .yours
        case .micUnavailable, .offline, .timeout, .serverUnavailable, .tooLarge, .unexpected: return .failure
        }
    }

    /// The panel's name for it.
    var menuTitle: String {
        switch self {
        case .noSpeech: return "No speech detected"
        case .tooShort: return "Recording too short"
        case .micPermission: return "Microphone access off"
        case .micUnavailable: return "Microphone unavailable"
        case .speechPermission: return "Speech Recognition off"
        case .screenRecording: return "Screen Recording off (screenshot)"
        case .imageTooLarge: return "Image over 20 MB (screenshot)"
        case .offline: return "Offline"
        case .timeout: return "Request timed out"
        case .serverUnavailable: return "Service unavailable"
        case .sessionExpired: return "Session expired"
        case .quotaUsed: return "Usage limit reached"
        case .trialEnded: return "Trial ended"
        case .proExpired: return "Pro expired"
        case .rateLimited: return "Too many requests"
        case .tooLarge: return "Recording too large"
        case .unexpected: return "Something went wrong"
        }
    }

    var title: String {
        switch self {
        case .noSpeech: return L("No speech detected")
        case .tooShort: return L("Recording too short")
        case .micPermission: return L("Microphone access is off")
        case .micUnavailable: return L("Microphone unavailable")
        case .speechPermission: return L("Speech Recognition is off")
        case .screenRecording: return L("Screen Recording is off")
        case .imageTooLarge: return L("Image over 20 MB, not added")
        case .offline: return L("You're offline")
        case .timeout: return L("Request timed out")
        case .serverUnavailable: return L("Service temporarily unavailable")
        case .sessionExpired: return L("Session expired")
        case .quotaUsed: return L("Usage limit reached")
        case .trialEnded: return L("Trial ended")
        case .proExpired: return L("Pro subscription expired")
        case .rateLimited: return L("Too many requests")
        case .tooLarge: return L("Recording too large")
        case .unexpected: return L("Something went wrong")
        }
    }

    /// One line under the title; nil when the title says it all.
    var message: String? {
        switch self {
        case .noSpeech, .imageTooLarge, .screenRecording: return nil
        case .tooShort: return L("Say a little more, then try again.")
        case .micPermission, .speechPermission: return L("Allow it in System Settings, then try again.")
        // Oct 15 review, NH-04: Choose Microphone… beside it.
        case .micUnavailable: return L("Choose another, or restart Fovea.")
        case .offline: return L("Your recording is saved. Check your connection.")
        case .timeout: return L("Your recording is saved. The server took too long.")
        case .serverUnavailable: return L("Your recording is saved. Try again soon.")
        case .sessionExpired: return L("Sign in again to keep using Fovea.")
        case .quotaUsed: return L("This week's quota is used up. Resets Mon, Oct 12.")
        case .trialEnded: return L("Upgrade to Pro to keep using Fovea.")
        case .proExpired: return L("Renew it to keep using Fovea.")
        case .rateLimited: return L("Try again in a few seconds.")
        case .tooLarge: return L("Your recording is saved in History. Try a shorter one.")
        // Real in 1.0 (recognition that broke), which keeps no recording: no "saved", no made-up ID.
        case .unexpected: return L("Speech recognition stopped. Try again.")
        }
    }

    var action: Action? {
        switch self {
        case .micPermission, .speechPermission, .screenRecording: return .openSettings
        // Oct 15 review, NH-04: every notice whose fix is in Settings or System Settings has its button.
        case .micUnavailable: return .chooseMicrophone
        case .offline, .timeout, .serverUnavailable, .unexpected: return .retry
        case .sessionExpired: return .signIn
        case .quotaUsed, .trialEnded: return .upgrade
        case .proExpired: return .renew
        default: return nil
        }
    }

    /// Oct 15 review, NH-04: the page of Fovea's own Settings where the fix is (the microphone in
    /// Voice, signing in again in Account); nil when it's System Settings, the website, or nowhere.
    var settingsPage: String? {
        switch action {
        case .chooseMicrophone: return "voice"
        case .signIn: return "account"
        default: return nil
        }
    }

    var symbol: String {
        switch self {
        case .noSpeech, .tooShort: return "waveform"
        case .micPermission, .micUnavailable: return "mic.slash.fill"
        case .speechPermission: return "waveform.badge.exclamationmark"
        case .screenRecording: return "rectangle.dashed.badge.record"
        case .imageTooLarge: return "photo"
        case .offline: return "wifi.slash"
        case .timeout: return "clock.fill"
        case .serverUnavailable: return "exclamationmark.icloud.fill"
        case .sessionExpired: return "person.crop.circle.badge.exclamationmark"
        case .quotaUsed, .trialEnded, .proExpired: return "gauge.with.dots.needle.100percent"
        case .rateLimited: return "hourglass"
        case .tooLarge: return "waveform.badge.exclamationmark"
        case .unexpected: return "exclamationmark.triangle.fill"
        }
    }

    /// How long it stays (paused while the pointer is on it): fovea-mac's 2 s for information and
    /// 4 s for a warning; a notice with something to do stays long enough to do it.
    var duration: Double {
        let F = WorkbenchTokens.Feedback.self
        if moment == .inBar { return F.barNoticeTime }
        if action != nil { return F.errorActionTime }
        return tone == .info ? F.errorInfoTime : F.errorWarningTime
    }
}

extension WorkbenchModel {
    // MARK: The panel's Feedback tabs

    /// A tab chosen: the mock display set up for it, live from there.
    func stageFeedback(_ item: FeedbackItem) {
        clearFeedbackSessions()
        feedbackSelection = item
        dropUndo()
        splitDemo?.cancel()
        splitTargetOverride = nil
        demoPointer = nil
        switch item {
        case .modelEffort: stageModelEffort()
        case .errors: stageError(feedbackErrorChoice)
        case .textFiles: stageTextFiles(feedbackSelectStage)
        case .countdown: stageCountdown(feedbackCountdownStage)
        case .splitView: stageSplitView()
        case .landing: stageLanding()
        case .progress: stageProgress()
        case .answer: stageAnswer()
        case .titles: stageTitles()
        case .steps: stageSteps()
        case .skipReview: stageSkipReview()
        case .reanswer: stageReanswer()
        case .queue: stageQueue()
        }
    }

    /// A staging step a moment later, live; at once in a snapshot run, which holds the main actor
    /// while it renders (a task would never get its turn).
    func later(_ milliseconds: Int, _ body: @escaping @MainActor (WorkbenchModel) -> Void) {
        if snapshotMode { body(self); return }
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(milliseconds))
            guard let self else { return }
            body(self)
        }
    }

    /// The tab's own choice changed: stage it again.
    func restageFeedback() {
        if let item = feedbackSelection { stageFeedback(item) }
    }

    /// The other lists take over from the Feedback tabs.
    func leaveFeedback() {
        feedbackSelection = nil
    }

    /// What a tab leaves behind (its sessions, its queue, its pasted words), cleared before the
    /// next is staged; the panel's choices stay.
    func clearFeedbackSessions() {
        v2Runs.values.forEach { $0.cancel() }
        v2Runs = [:]
        notchState = .silent
        clearReferents()
        agentTasks = AgentBoard.tasks
        v2Sessions = []
        v2Checked = []
        v2Detached = []
        v2Queue = [:]
        v2QueuePaused = []
        v2FollowUps = []
        v2History = V2SampleHistory.sessions
        v2Followed = [:]
        v2Titles = [:]
        v2StepsOpen = []
        v2RouteOpen = false
        v2ModelSheet = false
        splitPasted = [:]
        splitTargetOverride = nil
        pastedNote = nil
        pasteLanding = nil
        barNotice = nil
        highlighting = false
        highlights = []
        highlightDraft = nil
    }

    /// Everything, the panel's choices included (the snapshots stage each from scratch).
    func resetFeedback() {
        clearFeedbackSessions()
        v2ReviewBeforeSend = true
        v2Model = nil
        v2Effort = nil
        feedbackModelStage = .closed
        feedbackWorkStage = .working
        feedbackQueueStage = .queued
        feedbackRouteOpen = false
    }

    private func freshVoiceBar(screen: MockScreenContent? = nil) {
        notchState = .silent
        clearReferents()
        if let screen { screenContent = screen }
        restingFlow = .voiceflow
        notchState = .voiceFlow
    }

    // MARK: #2

    func stageError(_ error: VoiceError) {
        restingFlow = .voiceflow
        switch error {
        case .noSpeech:
            notchState = .silent
            showNoSpeech()
        case _ where error.moment == .inBar:
            freshVoiceBar()
            showBarNotice(error)
        default:
            notchState = .silent
            showVoiceError(error)
        }
    }

    /// The island in place of the bar: what went wrong and the one way on, for a while.
    func showVoiceError(_ error: VoiceError) {
        stopTranscribing()
        voiceError = error
        notchState = .voiceError
        startErrorClock()
    }

    /// Inside the listening bar, which goes on listening: it widens to say so, then goes back.
    func showBarNotice(_ error: VoiceError) {
        guard notchState.collects else { return }
        islandAnimation = WorkbenchTokens.Feedback.noticeSpring
        barNotice = error
        barNoticeTask?.cancel()
        guard !snapshotMode else { return }
        barNoticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(error.duration))
            guard let self, !Task.isCancelled, self.barNotice == error else { return }
            self.dismissBarNotice()
        }
    }

    func dismissBarNotice() {
        barNoticeTask?.cancel()
        // Oct 21, Ryan: back to the bar without a bounce.
        islandAnimation = WorkbenchTokens.Feedback.noticeAway
        barNotice = nil
    }

    func dismissVoiceError() {
        guard notchState == .voiceError else { return }
        notchState = .silent
    }

    /// Its one action. Retry sends the saved recording again (here it goes through); the others
    /// open where the fix is (System Settings, the sign-in page, pricing), and the island rests.
    func performErrorAction(_ error: VoiceError) {
        if barNotice == error {
            // Inside the bar (Screen Recording off): its button opens System Settings too, and the
            // bar goes on listening (it only closed the notice before, Oct 11).
            if live != nil, error == .screenRecording { Permission.screenRecording.openSettings() }
            dismissBarNotice()
            return
        }
        // Oct 15 review, NH-04: where the fix is, in Fovea's own Settings (the app opens the window).
        if let live, let page = error.settingsPage {
            live.openSettings?(page)
            notchState = .silent
            return
        }
        // Fovea: where the fix is, in System Settings.
        if live != nil, error.action == .openSettings {
            switch error {
            case .micPermission: Permission.microphone.openSettings()
            case .speechPermission: Permission.speechRecognition.openSettings()
            case .screenRecording: Permission.screenRecording.openSettings()
            default: break
            }
            notchState = .silent
            return
        }
        // Keeping or renewing the plan is the website's (Oct 13): Renew opens the subscription,
        // Upgrade the plans.
        if live != nil, error.action == .renew || error.action == .upgrade {
            NSWorkspace.shared.open(error.action == .renew ? FoveaSite.account : FoveaSite.pricing)
            notchState = .silent
            return
        }
        switch error.action {
        case .retry:
            // 1.0 keeps no recording to send again: Retry listens again (Oct 11).
            // In the flow that failed: Dispatch's bar again after a Dispatch error (Oct 11).
            if live != nil, !demoSamples {
                notchState = .silent
                if restingFlow == .dispatchV2 { startV2Voice() } else { toggleVoiceFlow() }
                return
            }
            if transcript.isEmpty { transcript = Self.sampleTranscript }
            startTranscribing()
        default:
            notchState = .silent
        }
    }

    /// The time left, 1 → 0; it holds while the pointer is on the notice.
    func errorRemaining(at date: Date) -> Double {
        guard let error = voiceError, let start = errorStart else { return snapshotMode ? 0.6 : 1 }
        let now = errorPausedAt ?? date
        return max(0, min(1, 1 - now.timeIntervalSince(start) / error.duration))
    }

    func setErrorHover(_ inside: Bool) {
        guard notchState == .voiceError, let start = errorStart else { return }
        if inside, errorPausedAt == nil {
            errorPausedAt = Date()
            errorTask?.cancel()
        } else if !inside, let paused = errorPausedAt {
            errorStart = start.addingTimeInterval(Date().timeIntervalSince(paused))
            errorPausedAt = nil
            scheduleErrorEnd()
        }
    }

    func dropVoiceError() {
        errorTask?.cancel()
        errorTask = nil
        errorStart = nil
        errorPausedAt = nil
    }

    private func startErrorClock() {
        errorPausedAt = nil
        errorStart = snapshotMode ? nil : Date()
        guard !snapshotMode else { return }
        scheduleErrorEnd()
    }

    private func scheduleErrorEnd() {
        errorTask?.cancel()
        guard let error = voiceError else { return }
        let started = errorStart
        let left = errorRemaining(at: Date()) * error.duration
        errorTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(left))
            guard let self, !Task.isCancelled, self.notchState == .voiceError, self.errorStart == started,
                  self.errorPausedAt == nil else { return }
            self.notchState = .silent
        }
    }

    // MARK: #3 and #8 The highlighter (Option) and screenshots (⌘)

    /// Option on a voice bar: the highlighter. Pressed (or held), the pointer becomes a highlighter
    /// in the accent color; a drag across text marks it, a click marks a whole passage or a file.
    /// One press, one highlight: it puts itself down after. The marks stay on the screen while the
    /// session lasts. Elsewhere Option is the app's.
    func optionDown() {
        guard notchState.collects else { optionTurnedOn = nil; return }
        if capturing { capturing = false }
        optionTurnedOn = !highlighting
        highlighting = true
    }

    /// Option let go: a click leaves the highlighter on if it turned it on, and off if it was on;
    /// held, it was on only while held.
    func optionUp(click: Bool) {
        guard let turnedOn = optionTurnedOn else { return }
        optionTurnedOn = nil
        guard notchState.collects else { return }
        if click ? !turnedOn : turnedOn { highlighting = false }
    }

    /// The region's key on a voice bar: a screenshot, one region per press (decided Oct 6, round
    /// two). Held, capture is on while held. ⌘ until Oct 17, then ⌥ (Ryan: ⌘ clashed with Codex),
    /// and ⌘ again from Oct 19 (Ryan: "⌘ once the selected area, ⌘ twice the entire screen"), or
    /// whatever Settings › Shortcuts records.
    func regionDown() {
        guard notchState.collects else { commandTurnedOn = nil; return }
        if highlighting { highlighting = false }
        commandTurnedOn = !capturing
        capturing = true
    }

    func regionUp(click: Bool) {
        guard let turnedOn = commandTurnedOn else { return }
        commandTurnedOn = nil
        guard notchState.collects else { return }
        // Oct 19, Ryan: a tap leaves capture on if it turned it on (one region), off if it was on;
        // a hold was capture while held, so its release ends it.
        if click ? !turnedOn : true { capturing = false }
    }

    /// Oct 19, Ryan: the region's key used with another (⌘C, ⌘V) was never a press: capture it
    /// turned on goes off at once, and its release does nothing.
    func regionInterrupted() {
        guard let turnedOn = commandTurnedOn else { return }
        commandTurnedOn = nil
        if turnedOn, notchState.collects { capturing = false }
    }

    func setHighlighting(_ on: Bool) {
        guard on != highlightingStorage else { return }
        if on, !notchState.collects { notchState = restingFlow == .dispatchV2 ? .v2Voice : .voiceFlow }
        if on { capturing = false }
        highlightingStorage = on
        highlightDraft = nil
        hoverMark = nil
    }

    /// The article's lines: the body face's line and its spacing (the page's own numbers).
    var articleLine: CGFloat {
        let font = NSFont.systemFont(ofSize: 18)
        return ceil(font.ascender - font.descender + font.leading) + WorkbenchTokens.Safari.bodyLineSpacing
    }

    /// The passages on show, top to bottom, with where they are.
    var visiblePassages: [(name: String, text: String, rect: CGRect)] {
        guard screenContent == .fullScreenApp, tabs[selectedTab].page == .article else { return [] }
        return ArticlePage.passages.compactMap { name, text in
            agentAnchors["article.\(name)"].map { (name, text, $0) }
        }
        .filter { $0.name != "headline" }
        .sorted { $0.rect.minY < $1.rect.minY }
    }

    /// The marker's strokes from one point to another, line by line through the passages between
    /// them, as a text selection runs; and the words they cover.
    func highlightRuns(from a: CGPoint, to b: CGPoint) -> (rects: [CGRect], text: String) {
        // Fovea: the words the app under the drag says are there (Accessibility), or, where it
        // says nothing (a picture, a canvas), bands of the drag's lines to take as a picture.
        if let live {
            if let run = live.textRun(from: a, to: b) { return run }
            return (Self.bands(from: a, to: b), "")
        }
        let (start, end) = a.y < b.y || (abs(a.y - b.y) < 4 && a.x <= b.x) ? (a, b) : (b, a)
        let lh = articleLine
        var rects: [CGRect] = []
        var words: [String] = []
        for passage in visiblePassages where passage.rect.maxY >= start.y && passage.rect.minY <= end.y {
            let r = passage.rect
            let lines = max(1, Int((r.height + WorkbenchTokens.Safari.bodyLineSpacing) / lh))
            func line(_ y: CGFloat) -> Int { min(lines - 1, max(0, Int((y - r.minY) / lh))) }
            let first = start.y < r.minY ? 0 : line(start.y)
            let last = end.y > r.maxY ? lines - 1 : line(end.y)
            guard first <= last else { continue }
            let firstX = start.y < r.minY ? r.minX : min(max(start.x, r.minX), r.maxX)
            let lastX = end.y > r.maxY ? r.maxX : min(max(end.x, r.minX), r.maxX)
            for i in first...last {
                let x0 = i == first ? firstX : r.minX
                let x1 = i == last ? lastX : r.maxX
                guard x1 - x0 > 2 else { continue }
                rects.append(CGRect(x: x0, y: r.minY + CGFloat(i) * lh - 1, width: x1 - x0, height: lh - WorkbenchTokens.Safari.bodyLineSpacing + 3))
            }
            // The words under the strokes, by their place along the passage's lines.
            let chars = Array(passage.text)
            func index(_ i: Int, _ x: CGFloat) -> Int {
                let along = (CGFloat(i) + (x - r.minX) / max(1, r.width)) / CGFloat(lines)
                return min(chars.count, max(0, Int(along * CGFloat(chars.count))))
            }
            var from = index(first, firstX), to = index(last, lastX)
            while from > 0, chars[from - 1] != " " { from -= 1 }
            while to < chars.count, chars[to] != " " { to += 1 }
            if from < to { words.append(String(chars[from..<to]).trimmingCharacters(in: .whitespaces)) }
        }
        return (rects, words.joined(separator: " "))
    }

    /// The highlighter dragging: the marks as they will be.
    func highlightDrag(from a: CGPoint, to b: CGPoint) {
        guard highlighting, hypot(a.x - b.x, a.y - b.y) > 3 else { return }
        // Fovea: Accessibility is asked a few times a second, not on every point of the drag.
        if live != nil {
            let now = Date()
            if let last = highlightAsked, now.timeIntervalSince(last) < 0.05 { return }
            highlightAsked = now
        }
        highlightDraft = highlightRuns(from: a, to: b).rects
    }

    /// Where the app under the drag says nothing: the drag's lines as bands, a line's height each.
    static func bands(from a: CGPoint, to b: CGPoint) -> [CGRect] {
        let (start, end) = a.y < b.y ? (a, b) : (b, a)
        let line: CGFloat = 22
        let rows = max(1, Int(ceil((end.y - start.y + 1) / line)))
        let left = min(a.x, b.x), right = max(a.x, b.x)
        if rows == 1 { return [CGRect(x: left, y: start.y - line / 2, width: max(8, right - left), height: line)] }
        return (0..<rows).map { i in
            let y = start.y - line / 2 + CGFloat(i) * line
            let x0 = i == 0 ? start.x : left
            let x1 = i == rows - 1 ? end.x : right
            return CGRect(x: min(x0, x1), y: y, width: max(8, abs(x1 - x0)), height: line)
        }
    }

    /// Let go: a drag marks the words it crossed; a click marks the passage or the file under it.
    /// The mark stays, the thing joins the stack, and the highlighter is put down.
    func finishHighlight(from a: CGPoint, to b: CGPoint) {
        guard highlighting else { return }
        highlightDraft = nil
        // Oct 17, Ryan: the real Mac has no highlighter; words and files are taken with no key
        // (`autoTake`, IslandModel+Live.swift). This is the Workbench's.
        guard live == nil else { highlighting = false; return }
        if hypot(a.x - b.x, a.y - b.y) <= 3 {
            for file in DesktopFile.all {
                if screenContent == .desktop, let rect = agentAnchors["desktop.\(file.name)"], rect.contains(b) {
                    markFile(file, rect: rect)
                    highlighting = false
                    return
                }
            }
            if let passage = visiblePassages.first(where: { $0.rect.contains(b) }) {
                let runs = highlightRuns(from: CGPoint(x: passage.rect.minX, y: passage.rect.minY + 1),
                                         to: CGPoint(x: passage.rect.maxX, y: passage.rect.maxY - 1))
                markText(passage.text, rects: runs.rects)
                highlighting = false
            }
            return
        }
        let runs = highlightRuns(from: a, to: b)
        guard !runs.rects.isEmpty, !runs.text.isEmpty else { return }
        markText(runs.text, rects: runs.rects)
        highlighting = false
    }

    func markText(_ text: String, rects: [CGRect]) {
        guard let card = AttachmentCards.text(text) else { return }
        let union = rects.dropFirst().reduce(rects.first ?? .zero) { $0.union($1) }
        add(image: card, from: union, animated: !snapshotMode, kind: .text(text))
        highlights.append(ScreenHighlight(rects: rects, file: false, referent: referents.last?.id))
    }

    func markFile(_ file: DesktopFile, rect: CGRect) {
        guard let card = AttachmentCards.file(file) else { return }
        add(image: card, from: rect, animated: !snapshotMode, kind: .file(name: file.name, size: file.size))
        highlights.append(ScreenHighlight(rects: [rect.insetBy(dx: -6, dy: -5)], file: true, referent: referents.last?.id))
    }

    func stageTextFiles(_ stage: SelectStage) {
        switch stage {
        case .highlighting:
            freshVoiceBar(screen: .fullScreenApp)
            selectTab(0)
            scrollReset += 1
            highlighting = true
            later(700) { model in
                // A passage already marked, the highlighter up again for the next.
                guard let p = model.visiblePassages.first else { return }
                let runs = model.highlightRuns(from: CGPoint(x: p.rect.minX + 120, y: p.rect.minY + 4),
                                               to: CGPoint(x: p.rect.maxX - 160, y: p.rect.minY + model.articleLine + 4))
                model.markText(runs.text, rects: runs.rects)
                model.highlighting = true
            }
        case .file:
            freshVoiceBar(screen: .desktop)
            later(600) { model in
                guard let file = DesktopFile.all.dropFirst().first,
                      let rect = model.agentAnchors["desktop.\(file.name)"] else { return }
                model.markFile(file, rect: rect)
            }
        case .stack, .opened:
            freshVoiceBar(screen: .fullScreenApp)
            selectTab(0)
            scrollReset += 1
            stageMixedReferents()
            if stage == .opened { later(450) { $0.setExpanded(true) } }
        }
    }

    /// A screenshot, a passage and a file, as if taken while speaking.
    func stageMixedReferents() {
        if let image = V2Referents.image(.screen("Screens/fovea-home.png", "Fovea — Home")) {
            referents.append(CapturedReferent(id: UUID(), image: image.image, aspect: image.image.size.width / max(1, image.image.size.height),
                                              source: image.source))
        }
        let passage = ArticlePage.pass[0]
        if let card = AttachmentCards.text(passage) {
            referents.append(CapturedReferent(id: UUID(), image: card, aspect: card.size.width / max(1, card.size.height),
                                              source: SafariTab.all[0].title, kind: .text(passage)))
        }
        let file = DesktopFile.all[1]
        if let card = AttachmentCards.file(file) {
            referents.append(CapturedReferent(id: UUID(), image: card, aspect: card.size.width / max(1, card.size.height),
                                              source: "Desktop", kind: .file(name: file.name, size: file.size)))
        }
    }

    // MARK: #4 The last minute

    /// A session listens for ten minutes at most; the last minute counts down at the bar's right.
    func recordingRemaining(at date: Date) -> Double? {
        guard let start = recordingStart, notchState.collects else { return nil }
        if snapshotMode, feedbackSelection == .countdown {
            return feedbackCountdownStage == .lastMinute ? 42 : 7
        }
        return max(0, WorkbenchTokens.Feedback.recordingLimit - date.timeIntervalSince(start))
    }

    /// Whether the bar counts down now: in the last minute.
    func countingDown(at date: Date) -> Bool {
        guard let left = recordingRemaining(at: date) else { return false }
        return left <= WorkbenchTokens.Feedback.countdownFrom
    }

    func startRecordingClock(elapsed: Double = 0) {
        recordingStart = Date().addingTimeInterval(-elapsed)
        recordingLimitTask?.cancel()
        let F = WorkbenchTokens.Feedback.self
        inLastMinute = elapsed >= F.recordingLimit - F.countdownFrom
        guard !snapshotMode else { return }
        var pulsed = inLastMinute
        recordingLimitTask = Task { [weak self] in
            while let self, !Task.isCancelled, self.notchState.collects, let start = self.recordingStart {
                let used = Date().timeIntervalSince(start)
                if !pulsed, used >= F.recordingLimit - F.countdownFrom {
                    pulsed = true
                    // Oct 21, Ryan ("simpler is better"): the countdown fades in, and that's all; the
                    // bar no longer grows a few points and settles back as it does.
                    withAnimation(F.countdownIn) { self.inLastMinute = true }
                }
                if used >= F.recordingLimit {
                    // Time's up: it stops as fn would, and what was said goes on.
                    if self.notchState == .voiceFlow { self.startTranscribing() }
                    else if self.notchState == .v2Voice { self.finishV2Voice() }
                    return
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    func stopRecordingClock() {
        recordingLimitTask?.cancel()
        recordingLimitTask = nil
        inLastMinute = false
    }

    func stageCountdown(_ stage: CountdownStage) {
        freshVoiceBar(screen: .fullScreenApp)
        selectTab(2)
        let F = WorkbenchTokens.Feedback.self
        // Live, it starts a breath before the last minute, so the countdown's arrival shows.
        let elapsed = stage == .lastMinute ? F.recordingLimit - F.countdownFrom - (snapshotMode ? -18 : 0.6) : F.recordingLimit - 10
        listenStart = Date().addingTimeInterval(-elapsed)
        startRecordingClock(elapsed: elapsed)
    }

    // MARK: #6 Split View

    /// Dictation is under way (Voiceflow listening or transcribing): its words will go into a field,
    /// which shows the caret. Dispatch's words go to an agent, not a field.
    var dictating: Bool { notchState == .voiceFlow || notchState == .transcribing }

    /// The app the words go to: the one under the pointer (the demo's hand, while it plays).
    var splitTarget: SplitSide {
        if let override = splitTargetOverride { return override }
        guard let p = pointerOnDisplay else { return .left }
        return p.x < display.frame.width / 2 ? .left : .right
    }

    func stageSplitView() {
        splitPasted = [:]
        pastedNote = nil
        freshVoiceBar(screen: .splitView)
    }

    /// Play: the hand starts on Mail, speaks, crosses to Messages mid-sentence (the focus follows
    /// it), and fn lands the words there; the notch leaves.
    func playSplitDemo() {
        stageSplitView()
        guard !snapshotMode else { splitTargetOverride = .right; return }
        splitDemo?.cancel()
        let w = display.frame.width, h = display.frame.height
        splitDemo = Task { [weak self] in
            guard let self else { return }
            self.demoPointer = DemoPointer(location: CGPoint(x: w * 0.27, y: h * 0.55), style: .arrow)
            self.splitTargetOverride = .left
            try? await Task.sleep(for: .seconds(1.4))
            for step in 1...24 {
                guard !Task.isCancelled else { return }
                let t = Double(step) / 24
                let x = w * (0.27 + 0.46 * t)
                self.demoPointer = DemoPointer(location: CGPoint(x: x, y: h * (0.55 + 0.12 * sin(t * .pi))), style: .arrow)
                self.splitTargetOverride = x < w / 2 ? .left : .right
                try? await Task.sleep(for: .milliseconds(30))
            }
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled, self.notchState == .voiceFlow else { return }
            self.startTranscribing()
            try? await Task.sleep(for: .seconds(4.6))
            guard !Task.isCancelled else { return }
            self.demoPointer = nil
            self.splitTargetOverride = nil
        }
    }

    // MARK: #7 The words land

    func stageLanding() {
        pastedNote = nil
        freshVoiceBar(screen: .fullScreenApp)
        selectTab(2)
        scroll(tab: 2, to: "comment")
        guard !snapshotMode else {
            pastedNote = Self.sampleTranscript
            pasteLanding = Date()
            return
        }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard let self, self.notchState == .voiceFlow, self.feedbackSelection == .landing else { return }
            self.startTranscribing()
        }
    }

    /// The words go into the field under them, it lights up as they land, and a beat later the
    /// notch leaves (no "Delivered": the words in the field are the confirmation).
    func landTranscript() {
        if let live, !demoSamples {
            liveLand(live)
            return
        }
        if screenContent == .splitView {
            splitPasted[splitTarget] = transcript
        } else {
            pastedNote = transcript
        }
        pasteLanding = Date()
        guard !snapshotMode else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(WorkbenchTokens.Feedback.landHold))
            guard let self, self.notchState == .transcribing else { return }
            self.notchState = .silent
        }
    }
}

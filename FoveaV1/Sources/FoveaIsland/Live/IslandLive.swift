import SwiftUI
import AppKit
import FoveaKit
import FoveaStore
import FoveaPlatform
import FoveaLook
import CapturesCore

// The island on the real Mac (Fovea 1.0). The Workbench's model and views, unchanged where they
// can be: its "display" is the real screen (in that screen's own top-down points), its pictures
// come from ScreenCaptureKit, its words from the microphone and on-device speech, its pastes go to
// the app in front, and what it makes goes to Home. Dispatch's agents stay the Workbench's
// simulation (the words are real; the work and the answers are scripted).

/// What the island does on the real Mac, for the model to call.
@MainActor
final class IslandLive {
    let prefs: PrefsStore
    let captures: CaptureLibrary
    let dictionary: DictionaryStore
    let voice = VoiceInput()
    /// The screen the island is on, and the panel it draws in.
    var screen: NSScreen
    weak var panel: NotchPanel?
    /// The first run's hooks (FoveaOnboarding), nil the rest of the time.
    weak var director: IslandDirector?
    /// The app in front when the session began: what the words were said into.
    var sessionApp: (name: String, bundleID: String)?
    var sessionStart = Date()
    /// Set by the model while it listens: the level for the waveform and the glow.
    var level: Double = 0
    /// Oct 15 review, ST-03.1: the shortcuts Settings › Shortcuts records (KeyMonitors.swift),
    /// wired by the controller (IslandInput.swift).
    let shortcuts = ShortcutMonitor()
    /// Oct 15 review, NH-04: a Settings page opened from the notch ("voice", "account"…), set by
    /// the app (`IslandController.onOpenSettings`).
    var openSettings: ((String) -> Void)?
    /// Oct 15 review, VF05: capture mode's surfaces on the other displays (IslandInput.swift).
    var otherCapture: [NotchPanel] = []
    /// Oct 15 review, VF04: the wheel over the opened stack (IslandInput.swift).
    var scrollMonitor: Any?
    /// Oct 17, Ryan: the mouse, watched while Fovea listens (never taken over), and where the
    /// press under way began, in global top-left points (IslandInput.swift).
    var mouseMonitors: [Any] = []
    var pressAt: CGPoint?
    /// Oct 17, Ryan: files dragged onto the notch. The drag pasteboard as the press began (a file
    /// drag changes it), whether one is under way, and the drop target over the island meanwhile.
    var dragBoardCount = 0
    var fileDragging = false
    var dropPanel: NotchPanel?
    /// The drag pasteboard, asked a few times a second while the island takes drops: a drag Fovea's
    /// own window starts (the first run's practice files) is seen by no event monitor.
    var dragPoll: Timer?
    /// Oct 18, Ryan: selections read off the main thread, as the cursor moves; the words already
    /// selected where the press began, and the window it began in; the selection being made, drawn
    /// over its window as it grows; and the windows drawing the marks, by the window they're over.
    let selectionReader = SelectionReader()
    var pressText: String?
    var pressWindow: CGWindowID?
    var lastDragRead = Date.distantPast
    var draftMark: (window: CGWindowID, bounds: CGRect, rects: [CGRect])?
    var markWindows: [CGWindowID: MarkWindow] = [:]
    var markFollow: Timer?
    var markObservers: [Any] = []
    /// The controller's: the mark windows brought up to date (IslandMarks.swift).
    var syncMarks: (() -> Void)?

    /// `--smoke` (LiveSmoke.swift): the real island with stand-ins at its edges, so nothing reaches
    /// the microphone, the app in front, the screen or Accessibility. Off otherwise.
    struct Smoke {
        /// The words each listening hears, in turn ("" for silence).
        var words: [String] = []
        /// A text field to paste into, or none (Paste not found).
        var canPaste = false
        /// Oct 18, Ryan: a field under the pointer when the words land, and where each paste went
        /// ("pointer", "focused").
        var fieldUnderPointer = false
        var landedOn: [String] = []
        var pasted: [String] = []
        /// What a click finds there (a Finder file).
        var file: (url: URL, rect: CGRect)?
        var run: (rects: [CGRect], text: String)?
        /// Oct 17, Ryan: what the app says the person selected (after a drag, a double or a triple
        /// click), in the island's points, and whether it sits in the field the words paste into.
        var selection: (text: String, rects: [CGRect], editable: Bool)?
        /// What the last dictation would have pasted, piece by piece (the words, then what was taken).
        var pastedPieces: [Paster.Piece] = []
        /// Real pictures of the screen for what's taken (`--design-shots`), not stand-ins.
        var realImages = false
        /// What a picture taken is said to come from (`--design-shots`: its scene's document).
        var source: String?
    }
    var smoke: Smoke?

    init(prefs: PrefsStore, captures: CaptureLibrary, dictionary: DictionaryStore, screen: NSScreen) {
        self.prefs = prefs; self.captures = captures; self.dictionary = dictionary; self.screen = screen
    }

    // MARK: Points

    /// The pointer (AppKit's bottom-up screen point) on the island's screen, in its top-down points.
    func layerPoint(fromScreen p: CGPoint) -> CGPoint? {
        guard NSMouseInRect(p, screen.frame, false) else { return nil }
        return Screens.local(appKit: p, on: screen)
    }

    func global(_ p: CGPoint) -> CGPoint { Screens.global(p, on: screen) }
    func global(_ r: CGRect) -> CGRect { Screens.global(r, on: screen) }
    func local(_ r: CGRect) -> CGRect { Screens.local(r, on: screen) }

    // MARK: Listening

    func startListening(level: @escaping (Float) -> Void) async -> VoiceFailure? {
        if smoke != nil { sessionStart = Date(); return nil }
        voice.onLevel = { [weak self] l in
            self?.level = Double(l)
            level(l)
        }
        sessionStart = Date()
        if sessionApp == nil { sessionApp = AXReader.frontmostApp }
        do {
            // Oct 15 review, ST-04.2/3: with Tidy my words off, speech recognition adds no punctuation.
            // Oct 23, Ryan: in every language the person speaks (English and Chinese both on: both
            // listen, and the surer words are kept; the primary language's on a tie).
            try await voice.start(locales: prefs.prefs.chosenLanguages.map(\.speechLocale), contextual: dictionary.contextualStrings,
                                  punctuates: tidiesWords)
            return nil
        } catch let failure as VoiceFailure {
            return failure
        } catch {
            return .microphoneUnavailable
        }
    }

    /// Oct 15 review, ST-04.2/3: Voice & Capture's "Tidy my words". On, Fovea takes the ums out and
    /// adds a capital and a full stop; off, the words go exactly as they were said.
    var tidiesWords: Bool { prefs.prefs.tidyWords }

    /// The words as they'll go: tidied, or (Tidy my words off) exactly as said.
    func written(_ said: String) -> String {
        guard !said.isEmpty else { return "" }
        return tidiesWords ? TranscriptCleaner.clean(said) : said.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The words, once the person stops: the dictionary's corrections made, tidied unless the
    /// person said not to.
    func finishWords() async -> VoiceResult {
        if smoke != nil {
            let said = smoke?.words.isEmpty == false ? smoke!.words.removeFirst() : ""
            return VoiceResult(text: written(said), failure: nil, seconds: 1)
        }
        var result = await voice.finish()
        level = 0
        // Oct 23: every spelling of the words that are on, made whole-word (it was any match,
        // inside longer words too, and Off words were made as well).
        result.text = written(dictionary.written(result.text))
        return result
    }

    func cancelListening() {
        if smoke != nil { level = 0; return }
        voice.cancel()
        level = 0
    }

    func sessionEnded() { sessionApp = nil }

    // MARK: Pasting

    /// Somewhere to paste: the onboarding's own windows, or a text field in the app in front.
    var canPaste: Bool {
        landing = findLanding()
        return landing != nil
    }

    /// Oct 18, Ryan: where the words land, found the moment they're pasted ("where the user's mouse
    /// is hovering at the very last moment before sending, not the last moment before the
    /// transcription starts"): the first run's practice window under the pointer; a field under
    /// the pointer (brought forward and focused); else the focused field; else nowhere (Paste not
    /// found).
    enum Landing {
        case practice, focused
        case pointer(AXReader.TextField?)
    }

    /// What the last `canPaste` found, for the paste right after it.
    var landing: Landing?

    func findLanding() -> Landing? {
        if let smoke { return smoke.fieldUnderPointer ? .pointer(nil) : (smoke.canPaste ? .focused : nil) }
        if director?.pasteTarget() == true { return .practice }
        guard !Paster.secureInput else { return nil }
        let p = NSEvent.mouseLocation
        if let field = AXReader.textField(at: CGPoint(x: p.x, y: Screens.primaryHeight - p.y)) {
            return field.focused ? .focused : .pointer(field)
        }
        return AXReader.focusedTextInput() != nil ? .focused : nil
    }

    /// Where the words are about to land, global top-left points (to light it a moment).
    var landingFrame: CGRect? {
        if case .pointer(let field?)? = landing { return field.frame }
        return AXReader.focusedTextInput()?.frame
    }

    func paste(_ text: String) {
        if smoke != nil { smoke?.pasted.append(text); return }
        if director?.paste(text) == true { return }
        Paster.paste(text)
    }

    /// Oct 17, Ryan ("paste them after the words"): the words, then what was taken, in turn into the
    /// same field (`Paster`). The first run's practice windows take the words alone.
    func paste(_ pieces: [Paster.Piece]) {
        let words = pieces.compactMap { piece -> String? in
            if case .text(let text) = piece { return text } else { return nil }
        }.joined()
        let landing = self.landing ?? findLanding()
        self.landing = nil
        if smoke != nil {
            smoke?.pastedPieces = pieces
            smoke?.pasted.append(words)
            if case .pointer? = landing { smoke?.landedOn.append("pointer") } else { smoke?.landedOn.append("focused") }
            return
        }
        if director?.paste(words) == true { return }
        // Oct 18, Ryan: a field under the pointer that isn't the focused one: brought forward and
        // focused (never a click), then the paste once it has the keyboard.
        if case .pointer(let field?)? = landing {
            AXReader.focus(field)
            Task {
                try? await Task.sleep(for: Self.focusSettle)
                await Paster.paste(pieces)
            }
            return
        }
        Task { await Paster.paste(pieces) }
    }

    /// How long a field brought forward gets to take the keyboard before the paste.
    static let focusSettle: Duration = .milliseconds(180)
    // MARK: Pictures

    /// A part of the screen, as it is under Fovea's own marks. `on`: another display than the
    /// island's (Oct 15 review, VF05), in that display's own top-down points.
    func image(of rect: CGRect, on other: NSScreen? = nil) async -> NSImage? {
        if let smoke, !smoke.realImages {
            return NSImage(size: NSSize(width: max(rect.width, 1), height: max(rect.height, 1)), flipped: false) { r in
                NSColor.systemTeal.setFill(); r.fill(); return true
            }
        }
        let windows = ([panel].compactMap { $0 } + otherCapture).map(\.windowNumber)
        guard let cg = try? await ScreenCapturer.capture(rect, on: other ?? screen, excluding: windows) else {
            return other == nil ? director?.image(of: rect) : nil
        }
        return NSImage(cgImage: cg, size: rect.size)
    }

    /// Where something at a global point was taken from: the window there, by app and title.
    func source(atGlobal p: CGPoint) -> String {
        if let name = smoke?.source { return name }
        guard let w = WindowList.window(at: p) else { return L("Desktop") }
        if let title = w.title, !title.isEmpty { return "\(title) · \(w.owner)" }
        return w.owner
    }

    /// Where a part of the screen was taken from: the window under it, by app and title.
    func source(of rect: CGRect, on other: NSScreen? = nil) -> String {
        // `--design-shots`: its own scene, never a window of the person's behind it.
        if let name = smoke?.source { return name }
        let center = Screens.global(CGPoint(x: rect.midX, y: rect.midY), on: other ?? screen)
        if let w = WindowList.window(at: center) {
            if let title = w.title, !title.isEmpty { return "\(title) · \(w.owner)" }
            return w.owner
        }
        // Fovea's own windows (the first run's practice windows).
        if let name = director?.source(of: rect) { return name }
        return L("Desktop")
    }

    // MARK: Oct 17, Ryan: words and files with no key

    /// A global top-left point in the island's own points.
    func localPoint(_ p: CGPoint) -> CGPoint { local(CGRect(origin: p, size: .zero)).origin }

    /// Whether a rect in the island's points is on the island's display.
    func onIslandDisplay(_ r: CGRect) -> Bool { CGRect(origin: .zero, size: screen.frame.size).intersects(r) }

    /// What the person selected with a press from `a` to `b` (global top-left points), where it's
    /// known at once: the smoke's stand-in, or the first run's practice windows; its lines in the
    /// island's points. Another app's selection is read off the main thread (`selectionReader`).
    func selectionMade(from a: CGPoint, to b: CGPoint, clicks: Int) -> (text: String, rects: [CGRect], editable: Bool)? {
        if let smoke { return smoke.selection }
        if let director {
            let own = clicks >= 2 ? director.paragraph(at: localPoint(b)) : director.textRun(from: localPoint(a), to: localPoint(b))
            if let own { return (own.text, own.rects, director.pasteTarget()) }
        }
        return nil
    }

    /// The smoke and the first run answer at once; everywhere else, Accessibility off the main thread.
    var readsSelectionAtOnce: Bool { smoke != nil || director != nil }

    // MARK: The highlighter (the Workbench's; the real Mac's has no key since Oct 17)

    /// The words between two points of a drag, line by line, in the island's points.
    func textRun(from a: CGPoint, to b: CGPoint) -> (rects: [CGRect], text: String)? {
        if let smoke { return smoke.run }
        if let own = director?.textRun(from: a, to: b) { return own }
        guard let run = AXReader.textRun(from: global(a), to: global(b)) else { return nil }
        return (run.lines.map(local), run.text)
    }

    func paragraph(at p: CGPoint) -> (rects: [CGRect], text: String)? {
        if let smoke { return smoke.run }
        if let own = director?.paragraph(at: p) { return own }
        guard let para = AXReader.paragraph(at: global(p)) else { return nil }
        return (para.lines.map(local), para.text)
    }

    func file(at p: CGPoint) -> (url: URL, rect: CGRect)? {
        if let smoke { return smoke.file.flatMap { $0.rect.contains(p) ? $0 : nil } }
        if let own = director?.file(at: p) { return own }
        guard let found = AXReader.file(at: global(p)) else { return nil }
        return (found.url, found.frame.map(local) ?? CGRect(x: p.x - 24, y: p.y - 24, width: 48, height: 48))
    }

    // MARK: Home

    /// A Dispatch, for Home: what was asked, what was taken, and the agent and chat it went to.
    func logDispatch(text: String, referents: [CapturedReferent], agent: String, chat: String) {
        log(kind: .dispatch, text: text, referents: referents, destination: Destination(agent, chat: chat))
    }

    /// A dictation, for Home.
    func logDictation(text: String, referents: [CapturedReferent]) {
        log(kind: .dictation, text: text, referents: referents)
    }

    /// What was said and taken, for Home.
    func log(kind: CaptureKind, text: String, referents: [CapturedReferent], destination: Destination? = nil,
             title: String? = nil) {
        let id = "\(kind == .dictation ? "d" : "x")-\(UUID().uuidString.prefix(8).lowercased())"
        let anchor = (text as NSString).length
        var attachments: [Attachment] = []
        for (i, r) in referents.enumerated() {
            let index = i + 1
            switch r.kind {
            case .screenshot:
                let art = r.image.pngData.flatMap { png in captures.media?.save(png: png, capture: id, index: index) }
                attachments.append(Attachment(index, .region, anchor: anchor, art: art, text: "", source: r.source))
            case .text(let words):
                let art = r.image.pngData.flatMap { png in captures.media?.save(png: png, capture: id, index: index) }
                attachments.append(Attachment(index, .passage, anchor: anchor, art: art, text: words, source: r.source))
            case .file(let name, _):
                attachments.append(Attachment(index, .file, anchor: anchor, text: name,
                                              fileType: (name as NSString).pathExtension.lowercased(), source: r.source))
            }
        }
        let app = sessionApp ?? AXReader.frontmostApp ?? (L("Desktop"), "com.apple.finder")
        var capture = Capture(id: id, kind: kind, time: Date(), app: AppRef(app.name, app.bundleID), text: text,
                              attachments: attachments, destination: destination,
                              theme: title ?? TitleNamer.title(for: text, maxWords: 4),
                              seconds: max(1, Date().timeIntervalSince(sessionStart)))
        if let director { capture = director.decorate(capture) }
        captures.add(capture)
        director?.islandDidEmit(.logged(kind))
    }
}

extension NSImage {
    var pngData: Data? {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

/// What the island tells the first run (FoveaOnboarding maps them to its beats).
package enum IslandEvent: Equatable {
    case voiceOpened(dispatch: Bool)
    case referentTaken(kind: TakenKind, rect: CGRect)
    case transcribing(dispatch: Bool)
    case chooseChatShown
    case sent
    case sessionAnswered
    case boardOpened(byHover: Bool)
    case followUpStarted
    case followUpAnswered
    case dictationLanded
    case logged(CaptureKind)
    case rested
    /// Oct 23, Ryan (the first run teaches the rest): a session opened from the board; a chat
    /// pulled out of the notch, tucked at a side as a tab, and brought back; a session expanded.
    case sessionOpened, chatPulledOut, chatTucked, chatBroughtBack, sessionExpanded
    /// The first run's agent asked to edit a file; the person allowed it, or denied it.
    case approvalAnswered(allowed: Bool)
    /// Esc on a voice bar, and ⌘Z (or Undo) bringing it back.
    case cancelled, restored
    /// The stack opened, one of it looked at closely, one taken out (its place in the stack).
    case stackOpened, referentInspected, referentRemoved(index: Int)
    /// A message typed while the agent works, waiting its turn; a session stopped; answered again.
    case queued, stopped(String), answeredAgain(String)
    /// Words held at the notch with nowhere to paste them, and copied from there.
    case heldWords, heldCopied
    /// Oct 27, Ryan: the board's search opened, and a past chat opened from it.
    case chatSearchOpened, pastChatOpened

    package enum TakenKind: Equatable { case region, wholeScreen, passage, file }
}

/// The first run's hold on the island: what it may do in each step, and Fovea's own practice
/// windows as places to point at and paste into. Every method has a "nothing to say" answer.
@MainActor
package protocol IslandDirector: AnyObject {
    /// The island happened; the first run moves on when it's what the step waits for.
    func islandDidEmit(_ event: IslandEvent)
    /// fn and fn ⌃ work now (the keyboard only where keys are taught).
    func allowsVoice(dispatch: Bool) -> Bool
    /// The pointer at the notch opens the board now (not before the notch is taught).
    func allowsBoard() -> Bool
    /// A practice window under the pointer takes the words.
    func pasteTarget() -> Bool
    func paste(_ text: String) -> Bool
    /// Pictures of Fovea's own windows when Screen Recording isn't allowed.
    func image(of rect: CGRect) -> NSImage?
    func source(of rect: CGRect) -> String?
    func textRun(from a: CGPoint, to b: CGPoint) -> (rects: [CGRect], text: String)?
    func paragraph(at p: CGPoint) -> (rects: [CGRect], text: String)?
    func file(at p: CGPoint) -> (url: URL, rect: CGRect)?
    func decorate(_ capture: Capture) -> Capture
    /// fn ⌃ again: the request may go on (the task's things are taken), else the director says why.
    func allowsFinish(continuing: Bool) -> Bool
    /// A part of the screen dragged over: taken, or missed (the director says so).
    func acceptRegion(_ rect: CGRect) -> Bool
    func acceptFile(_ url: URL) -> Bool
    /// Its agent works the session (returns false to leave it to the script).
    func runSession(_ id: String, words: String, referents: [IslandReferent], followUp: Bool) -> Bool
    /// Oct 23, Ryan: Answer again on one of its sessions: its agent answers the last request again
    /// (returns false to leave it to the script).
    func rerunSession(_ id: String) -> Bool
    /// The board shows its search (and the pinned chats) now.
    func allowsSearch() -> Bool
}

package extension IslandDirector {
    func rerunSession(_ id: String) -> Bool { false }
    /// Oct 27, Ryan: the board's search and its chats, from the step that teaches them on.
    func allowsSearch() -> Bool { false }
}

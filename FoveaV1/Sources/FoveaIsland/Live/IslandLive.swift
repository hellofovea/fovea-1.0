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
        voice.onLevel = { [weak self] l in
            self?.level = Double(l)
            level(l)
        }
        sessionStart = Date()
        if sessionApp == nil { sessionApp = AXReader.frontmostApp }
        do {
            try await voice.start(locale: prefs.prefs.language.speechLocale, contextual: dictionary.contextualStrings)
            return nil
        } catch let failure as VoiceFailure {
            return failure
        } catch {
            return .microphoneUnavailable
        }
    }

    /// The words, once the person stops: cleaned, the dictionary's corrections made.
    func finishWords() async -> VoiceResult {
        var result = await voice.finish()
        level = 0
        var text = result.text
        for (heard, word) in dictionary.replacements where !heard.isEmpty {
            text = text.replacingOccurrences(of: heard, with: word, options: [.caseInsensitive])
        }
        result.text = text.isEmpty ? "" : TranscriptCleaner.clean(text)
        return result
    }

    func cancelListening() {
        voice.cancel()
        level = 0
    }

    func sessionEnded() { sessionApp = nil }

    // MARK: Pasting

    /// Somewhere to paste: the onboarding's own windows, or a text field in the app in front.
    var canPaste: Bool {
        if director?.pasteTarget() == true { return true }
        guard !Paster.secureInput else { return false }
        return AXReader.focusedTextInput() != nil
    }

    func paste(_ text: String) {
        if director?.paste(text) == true { return }
        Paster.paste(text)
    }

    // MARK: Pictures

    /// A part of the screen, as it is under Fovea's own marks.
    func image(of rect: CGRect) async -> NSImage? {
        let windows = [panel?.windowNumber].compactMap { $0 }
        guard let cg = try? await ScreenCapturer.capture(rect, on: screen, excluding: windows) else {
            return director?.image(of: rect)
        }
        return NSImage(cgImage: cg, size: rect.size)
    }

    /// Where a part of the screen was taken from: the window under it, by app and title.
    func source(of rect: CGRect) -> String {
        let center = global(CGPoint(x: rect.midX, y: rect.midY))
        if let w = WindowList.window(at: center) {
            if let title = w.title, !title.isEmpty { return "\(title) · \(w.owner)" }
            return w.owner
        }
        // Fovea's own windows (the first run's practice windows).
        if let name = director?.source(of: rect) { return name }
        return "Desktop"
    }

    // MARK: The highlighter

    /// The words between two points of a drag, line by line, in the island's points.
    func textRun(from a: CGPoint, to b: CGPoint) -> (rects: [CGRect], text: String)? {
        if let own = director?.textRun(from: a, to: b) { return own }
        guard let run = AXReader.textRun(from: global(a), to: global(b)) else { return nil }
        return (run.lines.map(local), run.text)
    }

    func paragraph(at p: CGPoint) -> (rects: [CGRect], text: String)? {
        if let own = director?.paragraph(at: p) { return own }
        guard let para = AXReader.paragraph(at: global(p)) else { return nil }
        return (para.lines.map(local), para.text)
    }

    func file(at p: CGPoint) -> (url: URL, rect: CGRect)? {
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
        let app = sessionApp ?? AXReader.frontmostApp ?? ("Desktop", "com.apple.finder")
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
}

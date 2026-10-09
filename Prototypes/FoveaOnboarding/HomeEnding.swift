import AppKit
import CapturesCore
import CapturesUI
import OnboardingCore

/// The end of the first run: the real Home (Fovea Captures, through CapturesUI's `CapturesHome`)
/// with what was made in practice on top, in the accent and the aura chosen at the start, and the
/// words brought in from another dictation app in its dictionary (Oct 9).
@MainActor
final class CapturesHomeHandle {
    let home: CapturesHome

    init(records: [PracticeRecord], personal: Personalization, words: [ImportedWord] = []) {
        let captures = Self.captures(records)
        home = CapturesHome(adding: captures, accent: personal.accent.rawValue, glow: personal.aura.rawValue,
                            glowHue: personal.auraHue, glowDrift: personal.auraDrift > 0.05,
                            words: words.map { (word: $0.word, heardAs: $0.heardAs) })
    }

    /// Over the onboarding window's middle, or centered on the screen.
    func show(over frame: NSRect?) {
        guard let frame else { home.show(); return }
        let size = CapturesHome.size
        let origin = CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2 - 14)
        home.show(contentOrigin: origin)
    }

    var window: NSWindow { home.window }

    /// Practice records as Home's captures: newest first, dated just before the sample library's
    /// clock so they head today.
    static func captures(_ records: [PracticeRecord]) -> [CapturesCore.Capture] {
        let now = CapturesHome.now
        var turns: [String: Int] = [:]
        return records.enumerated().reversed().map { index, record in
            let text = record.words
            let anchor = text.utf16.count
            let attachments = record.referents.enumerated().map { i, referent in
                attachment(referent, index: i + 1, anchor: anchor)
            }
            var destination: Destination?
            if record.kind == .dispatch, let agent = record.agent {
                let chat = record.chat ?? OT.Practice.chat
                turns[chat, default: 0] += 1
                destination = Destination(agent, chat: chat, turn: turns[chat] ?? 1)
            }
            let app = record.kind == .dictation
                ? (record.theme.hasPrefix("Feedback") ? AppRef("Fovea", "com.fovea.app") : AppRef("Messages", "com.apple.MobileSMS"))
                : AppRef("Safari", "com.apple.Safari")
            return CapturesCore.Capture(
                id: "onboarding-\(index)",
                kind: record.kind == .dictation ? .dictation : .dispatch,
                time: now.addingTimeInterval(-record.secondsBeforeEnd),
                app: app,
                text: text,
                attachments: attachments,
                destination: destination,
                theme: record.theme,
                seconds: max(2, Double(text.split(separator: " ").count) * 0.4),
                site: record.kind == .dictation ? nil : (record.theme.contains("Pack") ? PracticeTab.trail.address : PracticeTab.analytics.address),
                tags: ["First run"])
        }
    }

    private static func attachment(_ referent: PracticeRecord.Referent, index: Int, anchor: Int) -> Attachment {
        switch referent {
        case .region(let source):
            return Attachment(index, .region, anchor: anchor, art: OT.Practice.photoArt, text: "", source: source)
        case .wholeScreen:
            return Attachment(index, .region, anchor: anchor, art: OT.Practice.photoArt, text: "The whole screen", source: "Desktop")
        case .passage(let text, let source):
            return Attachment(index, .passage, anchor: anchor, text: text, source: source)
        case .file(let name, let type, let folder):
            return Attachment(index, .file, anchor: anchor, text: name, fileType: type, source: folder)
        }
    }
}

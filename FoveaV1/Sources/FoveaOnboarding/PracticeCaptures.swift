import AppKit
import CapturesCore
import OnboardingCore

/// The end of the first run: what was made in practice, as Home's captures, tagged "First run".
/// The App puts them in the library and opens the real Home (the onboarding never sees the window).
enum PracticeCaptures {
    /// Practice records as Home's captures: newest first, dated as they were made, so they head
    /// today.
    static func captures(_ records: [PracticeRecord], now: Date = Date()) -> [CapturesCore.Capture] {
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

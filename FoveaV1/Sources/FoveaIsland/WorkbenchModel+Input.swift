import SwiftUI
import AppKit
import FoveaKit

// The model's side of the Oct 15 review's input changes (docs/v1/REVIEW_2026-10-15.md): Motion
// (IS02), the sample referents its stages use (VF04, VF05, QA02), and a region taken on the other
// display (VF05; IslandModel+Live.swift takes the picture).

extension WorkbenchModel {
    // MARK: IS02 Motion

    /// Oct 15 review, IS02: Settings › Appearance › Motion. Match the Mac follows the Mac's Reduce
    /// Motion; Reduce and Full hold whatever the Mac says. Every spring that already asks
    /// `reduceMotion` (and every view reading the environment's, through `IslandMotion`) follows it.
    var motionReduced: Bool {
        switch live?.prefs.prefs.motion ?? .system {
        case .system: return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        case .reduce: return true
        case .full: return false
        }
    }

    // MARK: VF04, VF05, QA02 Sample referents

    /// `count` referents to stage without Screen Recording: Fovea's own Home and Settings, a
    /// passage and a file, round again; `otherDisplay` marks the one at that index as taken there.
    func sampleReferents(_ count: Int, otherDisplay: Int? = nil) -> [CapturedReferent] {
        var pool: [CapturedReferent] = []
        for name in [("Screens/fovea-home.png", "Fovea — Home"), ("Screens/fovea-settings.png", "Fovea — Settings")] {
            if let (image, source) = V2Referents.image(.screen(name.0, name.1)) {
                pool.append(CapturedReferent(id: UUID(), image: image, aspect: image.size.width / max(1, image.size.height), source: source))
            }
        }
        let passage = ArticlePage.pass[0]
        if let card = AttachmentCards.text(passage) {
            pool.append(CapturedReferent(id: UUID(), image: card, aspect: card.size.width / max(1, card.size.height),
                                         source: SafariTab.all[0].title, kind: .text(passage)))
        }
        let file = DesktopFile.all[1]
        if let card = AttachmentCards.file(file) {
            pool.append(CapturedReferent(id: UUID(), image: card, aspect: card.size.width / max(1, card.size.height),
                                         source: "Desktop", kind: .file(name: file.name, size: file.size)))
        }
        guard !pool.isEmpty else { return [] }
        return (0..<count).map { i in
            let sample = pool[i % pool.count]
            return CapturedReferent(id: UUID(), image: sample.image, aspect: sample.aspect, source: sample.source,
                                    kind: sample.kind, otherDisplay: i == otherDisplay)
        }
    }

    // MARK: VF05 The other display

    /// A region dragged in capture mode on another display than the island's: taken, as on the
    /// island's (big enough, then capture mode ends), and marked as from the other display.
    func finishSelection(_ rect: CGRect, on screen: NSScreen) {
        let T = WorkbenchTokens.Capture.self
        guard capturing, let live, rect.width >= T.minimumSide, rect.height >= T.minimumSide else { return }
        Task {
            await liveCaptureOther(live, rect, on: screen)
            // Oct 19, Ryan: held, capture stays for the next (`finishSelection(_:)`).
            if commandTurnedOn == nil { capturing = false }
        }
    }
}

/// Oct 15 review, IS02: the island's views read `accessibilityReduceMotion`; Fovea's own Motion
/// overrides it (Reduce, Full) or leaves the Mac's (Match the Mac).
struct IslandMotion: ViewModifier {
    let model: WorkbenchModel

    func body(content: Content) -> some View {
        switch model.live?.prefs.prefs.motion ?? .system {
        case .system: content
        case .reduce: content.environment(\._accessibilityReduceMotion, true)
        case .full: content.environment(\._accessibilityReduceMotion, false)
        }
    }
}

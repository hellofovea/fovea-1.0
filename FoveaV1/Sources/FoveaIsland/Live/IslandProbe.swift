import SwiftUI
import AppKit

// What the first run's smoke (FoveaOnboarding/OnboardingSmoke.swift) may do to and read from the
// real island, which it can't reach into: keys as macOS sends them, the pointer, the words heard,
// and what the island shows. For `--smoke-first-run` only.

extension IslandController {
    /// Oct 23, Ryan: ⌘Z and left ⌃ too (cancelled words back; the whole session).
    package enum ProbeKey { case fn, fnControl, escape, enter, undo, control }

    package func probe(_ key: ProbeKey) {
        switch key {
        case .fn: LiveSmoke.fn(model)
        case .fnControl: LiveSmoke.fnControl(model)
        case .escape: _ = model.escape()
        case .enter: _ = model.v2Key(.enter)
        case .undo: _ = model.undoCancel()
        case .control: model.toggleV2Expanded()
        }
    }

    // Oct 23, Ryan: what the first run now teaches, done as the person would.

    /// A picture put on the stack, as ⌘ and a drag would.
    package func probeTake(_ image: NSImage) {
        let from = CGRect(x: model.display.frame.midX - 40, y: 200, width: 80, height: 60)
        model.add(image: image, from: from, animated: false, kind: .screenshot, source: "Smoke")
    }
    package var probeStackCount: Int { model.liveReferents.count }
    package func probeOpenStack() { model.setExpanded(true) }
    package func probeInspect(_ index: Int) {
        guard model.liveReferents.indices.contains(index) else { return }
        model.inspect(model.liveReferents[index].id)
    }
    package func probeRemove(_ index: Int) {
        guard model.liveReferents.indices.contains(index) else { return }
        model.inspect(nil)
        model.removeReferent(model.liveReferents[index].id)
    }
    package func probeAllow(_ id: String) { model.allowTask(id) }
    package func probeDeny(_ id: String) { model.denyTask(id) }
    package func probeStop(_ id: String) { model.stopTask(id) }
    package func probeAnswerAgain(_ id: String, model name: String? = nil) { model.reanswerV2(id, model: name) }
    /// Words typed in the session's box, and Return.
    package func probeType(_ id: String, _ text: String) { model.askMoreV2(id, text: text) }
    package var probeQueued: Int { model.v2Queue.values.reduce(0) { $0 + $1.count } }
    /// Words held at the notch, as when there's nowhere to paste them; Copy.
    package func probeHold(_ words: String) {
        model.transcript = words
        model.showPasteNotFound()
    }
    package func probeCopyHeld() { model.copyTranscript() }
    package var probeExpanded: Bool { model.v2Size == .expanded }
    /// Choose chat's suggestions, by name; ↓ to the next.
    package var probeSuggestions: [String] { model.v2Suggestions.map(\.title) }
    package func probePickNext() { model.stepV2Pick(1) }

    /// The words the next listening hears.
    package func probeWords(_ words: [String]) { live.smoke?.words = words }

    /// The pointer on the notch, or away from it.
    package func probePointer(onNotch: Bool) {
        model.panelPointer(onNotch ? LiveSmoke.notchPoint(model) : LiveSmoke.away(model))
    }

    package var probeState: String { "\(model.notchState)" }
    package var probeAsksOver: Bool { model.v2AsksOver }
    package var probeCaptionUnderNotch: Bool { false }
    package var probeBoardEmpty: Bool { model.v2BoardOrder.isEmpty }

    /// The island's sessions: their id, state, the steps of the exchange now, and the files.
    package var probeSessions: [(id: String, state: String, steps: Int, files: [String], history: Int)] {
        model.v2BoardOrder.map { task in
            (task.id, "\(task.state)", model.v2Work(task).entries.count, model.v2Artifacts(task).map(\.title),
             (model.v2History[task.id] ?? []).count)
        } + model.agentTasks.filter { t in model.v2Sessions.contains(t.id) && !model.v2BoardOrder.contains { $0.id == t.id } }.map { task in
            (task.id, "\(task.state)", model.v2Work(task).entries.count, model.v2Artifacts(task).map(\.title),
             (model.v2History[task.id] ?? []).count)
        }
    }

    package func probeOpen(_ id: String) { model.openV2(id) }
    package var probeFocus: String? { model.v2Focus }
}

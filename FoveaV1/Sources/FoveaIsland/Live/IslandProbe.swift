import SwiftUI
import AppKit

// What the first run's smoke (FoveaOnboarding/OnboardingSmoke.swift) may do to and read from the
// real island, which it can't reach into: keys as macOS sends them, the pointer, the words heard,
// and what the island shows. For `--smoke-first-run` only.

extension IslandController {
    package enum ProbeKey { case fn, fnControl, escape, enter }

    package func probe(_ key: ProbeKey) {
        switch key {
        case .fn: LiveSmoke.fn(model)
        case .fnControl: LiveSmoke.fnControl(model)
        case .escape: _ = model.escape()
        case .enter: _ = model.v2Key(.enter)
        }
    }

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

import Foundation
import Observation
import FoveaKit

// What the notch is doing, in one word, for the menu bar's icon (Oct 15 review, NH-01): resting,
// listening (a press under way: listening, transcribing, thinking), an agent at work, or an agent
// that needs you. Read from the model, never written.

package enum IslandActivity: Equatable, Sendable {
    case idle, listening, working, needsYou
}

extension IslandController {
    package var activity: IslandActivity {
        switch model.notchState {
        case .voiceFlow, .transcribing, .dispatchVoice, .quickVoice, .quickThinking, .v2Voice, .v2Transcribing:
            return .listening
        default:
            break
        }
        if model.agentTasks.contains(where: { $0.state == .needsYou }) { return .needsYou }
        if model.agentTasks.contains(where: { $0.state == .working }) { return .working }
        return .idle
    }

    /// Oct 23, Ryan: the menu bar's menu says what the notch is doing now, in words: listening,
    /// writing the words down, which agent is at work or needs you (and how many), or ready.
    package var activityLine: String {
        switch model.notchState {
        case .voiceFlow, .dispatchVoice, .quickVoice, .v2Voice:
            return L("Listening")
        case .transcribing, .v2Transcribing, .quickThinking:
            return L("Writing down your words")
        default:
            break
        }
        func line(_ state: AgentTaskState, one: (String) -> String, many: (Int) -> String) -> String? {
            let tasks = model.agentTasks.filter { $0.state == state }
            guard let first = tasks.first else { return nil }
            return tasks.count == 1 ? one(ChatAgent.named(first.agent).name) : many(tasks.count)
        }
        return line(.needsYou, one: { L("\($0) needs you") }, many: { L("\($0) agents need you") })
            ?? line(.working, one: { L("\($0) is working") }, many: { L("\($0) agents are working") })
            ?? L("Fovea is ready")
    }

    /// Calls `onChange` with the activity now, and again each time it changes.
    package func observeActivity(_ onChange: @escaping @MainActor (IslandActivity) -> Void) {
        let now = withObservationTracking { activity } onChange: { [weak self] in
            Task { @MainActor in self?.observeActivity(onChange) }
        }
        onChange(now)
    }
}

extension IslandController {
    /// The Review menu's "Notch: back to rest" (Oct 15 review): what a staged state left on the
    /// board — its sample sessions, cases, referents — gone, the notch at rest with the person's
    /// own sessions and prefs.
    package func backToRest() {
        endPreview()
        model.notchState = .silent
        model.resetFeedback()
        model.cases.reset()
        model.clearReferents()
        model.highlights = []
        model.v2Size = .usual
        model.demoSamples = false
    }
}

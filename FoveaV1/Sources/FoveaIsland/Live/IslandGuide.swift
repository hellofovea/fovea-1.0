import SwiftUI
import AppKit
import UniformTypeIdentifiers
import FoveaKit
import FoveaPlatform

// What the first run asks of the real island (FoveaOnboarding drives it; the island never knows
// the first run's steps): a line under the notch, typed out ("Hi. I live up here."), one that is
// itself the tile to drag into System Settings' list, the microphone test's bar, and sessions run
// by the agent on this Mac instead of the Workbench's script.

/// A line under the notch.
struct GuideCaption: Equatable {
    var text: String
    /// The line is Fovea's app, to drag into a System Settings list.
    var draggable: Bool
}

/// Something taken off the screen, as the first run hands it to the agent.
package struct IslandReferent: Sendable {
    package enum Kind: Sendable, Equatable {
        case region, passage(String), file(name: String)
    }
    package var kind: Kind
    package var png: Data?
    package var source: String
}

/// Something put on the stack for the person ("Do it for me").
package enum StagedReferent {
    case picture(NSImage, source: String)
    case passage(String, source: String)
    case file(URL)
}

/// A session the director runs, by its id on the island.
package struct IslandChat: Sendable, Equatable {
    package var agent: String
    package var chat: String
    package var project: String?
    package init(agent: String, chat: String, project: String? = nil) {
        self.agent = agent; self.chat = chat; self.project = project
    }
}

extension WorkbenchModel {
    // MARK: Sessions the director runs

    /// A send in the first run: the director's agent works it, not the script. The session is
    /// on the board at once, working.
    func directorSend(_ director: IslandDirector, id: String, followUp: Bool, text: String) -> Bool {
        let referents = liveReferents.map { r -> IslandReferent in
            let png = r.image.pngData
            switch r.kind {
            case .screenshot: return IslandReferent(kind: .region, png: png, source: r.source)
            case .text(let words): return IslandReferent(kind: .passage(words), png: png, source: r.source)
            case .file(let name, _): return IslandReferent(kind: .file(name: name), png: nil, source: r.source)
            }
        }
        guard director.runSession(id, words: text, referents: referents, followUp: followUp) else { return false }
        directorSessions.insert(id)
        return true
    }

    /// The director's agent, at work: one line of what it does.
    func updateDirectorSession(_ id: String, activity: String) {
        guard let i = agentTasks.firstIndex(where: { $0.id == id }) else { return }
        let lower = activity.lowercased()
        let work: AgentWork = lower.hasPrefix("editing") || lower.hasPrefix("writing") ? .editing
            : lower.hasPrefix("looking") || lower.hasPrefix("reading") ? .reading : .thinking
        withAnimation(WorkbenchTokens.Panel.change) {
            apply(AgentBeat(activity: activity, work: work, object: nil), to: i)
        }
    }

    /// The director's agent answered.
    func finishDirectorSession(_ id: String, answer: String, failed: Bool = false) {
        guard let i = agentTasks.firstIndex(where: { $0.id == id }) else { return }
        directorAnswers[id] = answer
        withAnimation(WorkbenchTokens.Panel.change) {
            apply(AgentBeat(activity: failed ? "Didn't finish" : "Done", work: failed ? .failed : .done,
                            state: failed ? .failed : .complete,
                            result: AgentResult(outcome: answer)), to: i)
            agentTasks[i].answer = answer
            agentTasks[i].plan = []
            agentTasks[i].changes = []
        }
        v2FinishedAt[id] = Date()
        v2Runs[id] = nil
        live?.director?.islandDidEmit(.sessionAnswered)
        // A quick answer opens by itself, as the Workbench's do.
        if notchState == .silent, v2Quick(id) { showV2Chat(id, popped: true) }
    }
}

extension IslandController {
    /// A line under the notch (nil: none). Draggable, it is Fovea itself, to drop into a list.
    package func setCaption(_ text: String?, draggable: Bool = false) {
        withAnimation(WorkbenchTokens.Motion.open) {
            model.guideCaption = text.map { GuideCaption(text: $0, draggable: draggable) }
        }
    }

    /// The microphone test: the voice bar listening (the first run's own meter feeds it).
    package func showListening(_ on: Bool) {
        if on {
            model.previewing = true
            model.restingFlow = .voiceflow
            if model.notchState != .voiceFlow { model.notchState = .voiceFlow }
        } else if model.previewing, model.notchState == .voiceFlow {
            model.notchState = .silent
            model.previewing = false
        }
    }

    package func setListeningLevel(_ level: Double) {
        model.previewLevel = Float(level)
    }

    /// The island at rest, whatever it was doing.
    package func rest() {
        model.previewing = false
        if model.notchState != .silent { model.notchState = .silent }
    }

    /// The director's agent at work, and done.
    package func updateSession(_ id: String, activity: String) { model.updateDirectorSession(id, activity: activity) }
    package func finishSession(_ id: String, answer: String) { model.finishDirectorSession(id, answer: answer) }
    package func failSession(_ id: String, why: String) { model.finishDirectorSession(id, answer: why, failed: true) }

    /// Opens a session's chat at the notch.
    package func openSession(_ id: String) { model.openV2(id) }

    /// The chats Choose chat offers (the first run's practice chat); nil, the request's own.
    package func setChats(_ chats: [IslandChat]?) {
        model.directorSuggestions = chats?.map {
            V2Suggestion(agent: $0.agent, chat: $0.chat, project: $0.project, reason: "Your first run")
        }
    }

    /// A request put together for the person ("Do it for me"): the Dispatch bar's request on
    /// Choose chat, with its pictures and words, waiting for Return.
    package func stageRequest(words: String, items: [StagedReferent]) {
        model.previewing = false
        model.restingFlow = .dispatchV2
        model.v2Continuing = nil
        model.clearReferents()
        let from = CGRect(x: model.display.frame.midX - 40, y: 200, width: 80, height: 60)
        for item in items {
            switch item {
            case .picture(let image, let source):
                model.add(image: image, from: from, animated: false, kind: .screenshot, source: source)
            case .passage(let text, let source):
                if let card = AttachmentCards.text(text) { model.add(image: card, from: from, animated: false, kind: .text(text), source: source) }
            case .file(let url):
                let file = DesktopFile(name: url.lastPathComponent, size: "")
                if let card = AttachmentCards.file(file) {
                    model.add(image: card, from: from, animated: false, kind: .file(name: file.name, size: ""),
                              source: url.deletingLastPathComponent().lastPathComponent)
                }
            }
        }
        model.v2Words = words
        model.v2Request = .code
        model.showV2Send()
        model.live?.director?.islandDidEmit(.chooseChatShown)
    }

    /// Opens the board, as the hover would.
    package func openBoard() { model.showAgentPanel(pinned: false) }

    /// The first run is over: its sessions leave the board.
    package func clearSessions() {
        let ids = model.directorSessions
        model.v2Sessions.subtract(ids)
        model.agentTasks.removeAll { ids.contains($0.id) }
        model.directorSessions.removeAll()
        rest()
    }
}

/// The line under the notch: a glass capsule just below it, in the notch's look, typed out as it
/// comes. It never covers or redraws the notch itself (the hardware's is the notch). Draggable, it
/// carries Fovea.app, as a Finder icon would.
struct GuideCaptionView: View {
    let model: WorkbenchModel
    let caption: GuideCaption

    var body: some View {
        let label = HStack(spacing: 8) {
            if caption.draggable {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 20, height: 20)
            }
            Text(caption.text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(WorkbenchTokens.ink(0.9))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            if #available(macOS 26.0, *) {
                Color.clear.glassEffect(.regular, in: Capsule())
            } else {
                Capsule().fill(.regularMaterial)
            }
        }
        .contentShape(Capsule())
        .padding(.top, model.metrics.safeAreaTop + 8)
        Group {
            if caption.draggable {
                label.onDrag {
                    NSItemProvider(contentsOf: Bundle.main.bundleURL) ?? NSItemProvider()
                }
                .help("Drag Fovea into the list")
            } else {
                label
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

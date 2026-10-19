import SwiftUI
import AppKit
import UniformTypeIdentifiers
import FoveaKit
import FoveaPlatform

// What the first run asks of the real island (FoveaOnboarding drives it; the island never knows
// the first run's steps): the microphone test's bar, and sessions run by the agent on this Mac
// instead of the Workbench's script. The first run says nothing at the notch (Oct 9, evening:
// every word of it is on its bar); the island shows only its own states.

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
        directorSteps[id] = []
        directorFiles[id] = []
        return true
    }

    /// The director's agent, at work: one line of what it does.
    func updateDirectorSession(_ id: String, activity: String) {
        guard let i = agentTasks.firstIndex(where: { $0.id == id }) else { return }
        let (work, object) = Self.directorStep(activity)
        // Kept as a step, for the fold under the answer: what it did, on what.
        let kind: StepKind = work == .editing ? .edit : work == .reading ? (object == nil ? .list : .read) : .think
        if directorSteps[id]?.last?.object != object || directorSteps[id]?.last?.kind != kind {
            directorSteps[id, default: []].append(AgentLiveStep(kind: kind, object: object))
        }
        withAnimation(WorkbenchTokens.Panel.change) {
            apply(AgentBeat(activity: activity, work: work, object: nil), to: i)
        }
    }

    /// What a line of the director's agent says it does, and on what. Oct 18, Ryan: the first run
    /// sends its lines in the primary language, so they're read in either: English as before
    /// ("Looking at …", "Editing …", "Writing …", "Reading …"), or the Chinese it sends
    /// ("正在查看 …", "正在编辑 …", "正在写入 …", "正在读取 …").
    static func directorStep(_ activity: String) -> (work: AgentWork, object: String?) {
        let lower = activity.lowercased()
        if lower.hasPrefix("editing") || lower.hasPrefix("writing") || lower.hasPrefix("looking") || lower.hasPrefix("reading") {
            let work: AgentWork = lower.hasPrefix("editing") || lower.hasPrefix("writing") ? .editing : .reading
            let object = ["looking at ", "editing ", "writing ", "reading "].first { lower.hasPrefix($0) }
                .map { String(activity.dropFirst($0.count)) }
            return (work, object)
        }
        let chinese: [(String, AgentWork)] = [("正在编辑", .editing), ("正在写入", .editing), ("正在整理", .editing),
                                              ("正在写", .editing), ("正在查看", .reading), ("正在读取", .reading),
                                              ("正在阅读", .reading), ("正在读", .reading), ("正在看", .reading)]
        guard let (prefix, work) = chinese.first(where: { activity.hasPrefix($0.0) }) else { return (.thinking, nil) }
        let rest = activity.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        let object = rest.trimmingCharacters(in: CharacterSet(charactersIn: "。…．.")).isEmpty ? nil : rest
        return (work, object)
    }

    /// The director's agent answered, with the files it changed.
    func finishDirectorSession(_ id: String, answer: String, files: [String] = [], failed: Bool = false) {
        guard let i = agentTasks.firstIndex(where: { $0.id == id }) else { return }
        directorAnswers[id] = answer
        directorFiles[id] = files
        withAnimation(WorkbenchTokens.Panel.change) {
            apply(AgentBeat(activity: failed ? L("Didn't finish") : L("island.done", english: "Done"), work: failed ? .failed : .done,
                            state: failed ? .failed : .complete,
                            result: AgentResult(outcome: answer)), to: i)
            agentTasks[i].answer = answer
            agentTasks[i].plan = []
            agentTasks[i].changes = []
        }
        v2FinishedAt[id] = Date()
        v2Runs[id] = nil
        live?.director?.islandDidEmit(.sessionAnswered)
        // A quick answer opens by itself, as the Workbench's do (and as Settings › Notch asks).
        if notchState == .silent, showAnswers, v2Quick(id) { showV2Chat(id, popped: true) }
    }
}

extension IslandController {
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
    package func finishSession(_ id: String, answer: String, files: [String] = []) {
        model.finishDirectorSession(id, answer: answer, files: files)
    }
    package func failSession(_ id: String, why: String) { model.finishDirectorSession(id, answer: why, failed: true) }

    /// Opens a session's chat at the notch.
    package func openSession(_ id: String) { model.openV2(id) }

    /// The chats Choose chat offers (the first run's practice chat); nil, the request's own.
    package func setChats(_ chats: [IslandChat]?) {
        model.directorSuggestions = chats?.map {
            V2Suggestion(agent: $0.agent, chat: $0.chat, project: $0.project, reason: L("Your first run"))
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

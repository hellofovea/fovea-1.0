import SwiftUI
import AppKit
import FoveaKit

// The Oct 15 review's Dispatch states on the real notch (Feedback/V2Cases.swift): the Review
// menu's stages, Home's Open in Notch, and the hooks the app wires (FoveaApp).

extension IslandController {
    /// Registers a Review stage for each of Dispatch's states the app doesn't reach by being used
    /// (Review › Notch). Each stages the live island through `stage(_:)`, from rest. Safe to repeat.
    package func registerCaseStages() {
        for item in WorkbenchModel.caseStages {
            Review.stage(item.id, item.title, area: .notch) { [weak self] in self?.stage(item.name) }
        }
    }

    /// The stage names of the review's states (`--demo qa:<case>` reaches each).
    package static var caseStageNames: [String] { WorkbenchModel.caseStages.map(\.name) }

    /// Home's Open in Notch (QA25): the session of a capture opens at the notch: "Reopening…", then
    /// the session; read only if it's from before this launch; gone, with Ask in a New Chat, if its
    /// agent isn't here any more. `agent` is the capture's agent, as Home names it ("Claude Code").
    package func reopen(captureID: String, title: String, agent: String) {
        endPreview()
        model.demoSamples = false
        model.reopenV2(captureID: captureID, title: title, agent: agent)
    }

    /// NH-03: "Remembered: …" Open; the id of the memory, for Settings › Memory to show.
    package var onOpenMemory: ((String) -> Void)? {
        get { model.cases.onOpenMemory }
        set { model.cases.onOpenMemory = newValue }
    }

    /// NH-03: Settings' "Tell me when a memory updates". Off, nothing says so.
    package var tellsMemoryUpdates: Bool {
        get { model.cases.memoryNotices }
        set { model.cases.memoryNotices = newValue }
    }

    /// QA20: folders where an answer's files may be, besides each project's own (the first run's
    /// practice folder), for Show in Finder and Save a Copy….
    package var answerFileFolders: [URL] {
        get { model.cases.fileRoots }
        set { model.cases.fileRoots = newValue }
    }
}

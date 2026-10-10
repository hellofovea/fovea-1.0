import SwiftUI
import AppKit
import OnboardingCore

// Where the first run's controls are on the screen (each view reports its frame), and starting the
// run over from a step. (The prototype's self-playing run, `--play`, stays in Prototypes/: on the
// real Mac the person drives.)

/// A control the play clicks, found by where its view says it is.
enum PlayTarget: Hashable {
    /// The glass bar while you do: where the stage takes clicks.
    case board
    case guideButton
    case accent(AccentName)
    case aura(AuraPalette)
    case languageMore
    case tile
    case toggle
    case alertPrimary
    case sessionRow
    case drift
    case skip
    case feedbackSend
    case sendArrow
    case agentWish
    case connectApp
    case eyeTracking
}

extension View {
    /// Reports this control's frame on the screen, in display points, for the play's pointer.
    func playTarget(_ target: PlayTarget?, _ model: OnboardingModel) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .named(ScreenSpace.name)) } action: { frame in
            if let target { model.targets[target] = frame }
            if let target, PlayDebug.on { print("target \(target) \(frame)"); fflush(stdout) }
        }
    }
}

enum PlayDebug {
    static let on = ProcessInfo.processInfo.environment["ONB_DEBUG"] == "1"
}

extension OnboardingModel {
    /// A fresh first run: nothing allowed or signed in, nothing made yet, Home put away, the
    /// practice files and the blog new. Started at a later step, the ones before it count as done
    /// (the permissions allowed, the agents connected, sign-in done).
    func restart(at step: Step = .signIn) {
        runner.cancel()
        cancelWaits()
        var fresh = Flow(start: .signIn)
        fresh.found(flow.agents)
        fresh.language = flow.language
        fresh.email = flow.email
        fresh.name = flow.name
        if step != .signIn { fresh.jump(to: step) }
        flow = fresh
        inList = []
        switchedOn = []
        finished = false
        homeOpened = false
        filesCleared = false
        editedFiles = []
        previewFile = nil
        sessions = []
        openSessionID = nil
        answered = []
        agentSession = nil
        agentNote = nil
        agentActivity = ""
        feedbackText = ""
        replyText = ""
        feedbackSent = false
        updateWritten = false
        eyeTrackingAsked = false
        importCandidates = []
        importChosen = []
        importMessage = nil
        importedWords = []
        languageMoreOpen = false
        micPhase = .waiting
        practice.create()
        for site in sites.values { site.reload() }
        if !options.harness { sound.startAmbient() }
        enter(step)
    }

    // MARK: Bookmarks (Oct 8): any stage, to compare and to prototype from

}

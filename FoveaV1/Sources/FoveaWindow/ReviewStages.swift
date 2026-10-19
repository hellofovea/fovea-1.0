import AppKit
import SwiftUI
import CapturesCore
import FoveaKit

// Oct 15 review: the Review menu's stages for Home and Settings (FoveaKit/Review.swift). Every
// state the review added that can't be reached just by using the app, shown on the real window.
// Each starts from Home as it is (`resetReview`), so stages don't pile up, and can run again; the
// two "back to normal" stages put everything back. A stage's captures are shown, never kept.

extension HomeWindowController {
    func registerReviewStages() {
        // MARK: Home
        home("MW-02a", "Restoring your session") { m in m.session = .restoring }
        home("MW-02a", "Couldn't restore your session") { m in m.session = .failed }
        for error in WindowError.allCases {
            home("MW-02b", error.title) { m in m.windowError = error }
        }
        home("HI-01.6", "Loading your captures") { m in m.capturesLoad = .loading }
        home("HI-01.6", "Couldn't load your captures") { m in m.capturesLoad = .failed }
        home("MW-05.1", "Empty Home: both daily keys") { m in m.stagedEmpty = true }
        home("MW-05.3", "A Dispatch session with four requests") { m in m.stage(Self.session(m.now)) }
        home("HI-01.3", "A Dispatch opened: Open in Notch") { m in
            m.stage(Self.session(m.now))
            Self.open("review-session-4", m)
        }
        home("QA25", "A Dispatch that wasn't sent: Send Again") { m in
            m.stage([Self.notSent(m.now)])
            Self.open("review-not-sent", m)
        }
        home("VF13", "A recording not transcribed yet") { m in
            m.holdRetries = true
            m.stage([Self.notTranscribed(m.now)])
        }
        home("VF13", "Trying again, then its words come back") { m in
            m.stage([Self.notTranscribed(m.now)])
            Self.open("review-failed-notes", m)
        }
        home("RC-01", "Earlier data: Home's line") { m in m.earlierData = CapturesModel.sampleEarlierData(now: m.now) }
        home("OB-02", "What Fovea remembers (once)") { m in m.memoryDisclosureShown = true }
        home("IS04", "A save that failed") { m in
            m.saveFailure = SaveFailure(title: L("Couldn't Save “\("Notch ears height")”"),  // Oct 18, Ryan: in the primary language.
                                        message: L("You don't have permission to save the file “Notch ears height” in the folder “Shared”."))
        }
        home("Reset", "Home: back to normal") { _ in }

        // MARK: Settings
        settings("MW-04", "Settings: the new sidebar", .gettingStarted) { _ in }
        settings("OB-03.1", "Getting Started", .gettingStarted) { _ in }
        settings("ST-10.1", "About: checking for updates", .about) { m in m.update = .checking }
        settings("ST-10.2", "About: an update to install", .about) { m in m.update = .available("1.0.1") }
        settings("ST-10.2", "About: couldn't check for updates", .about) { m in m.update = .failed }
        settings("ST-10.3", "About: Leave the Beta?", .about) { m in
            m.prefs.betaUpdates = true
            Self.later(m) { m.leavingBeta = true }
        }
        settings("MW-04c", "Report a Problem: couldn't send", .about) { m in
            m.reportFails = true
            Self.later(m) { m.reporting = true }
        }
        settings("RC-02.1", "Earlier data: bringing in", .account) { m in
            m.earlierData = CapturesModel.sampleEarlierData(now: m.now)
            Self.later(m) { m.scrollTarget = "earlier-data"; m.bringIn("earlier-0.9") }
        }
        settings("RC-02.2", "Earlier data: couldn't bring in", .account) { m in
            var data = CapturesModel.sampleEarlierData(now: m.now)
            data[0].state = .failed("Fovea couldn't read the old history. Quit Fovea 0.9 if it's open, then try again.")
            m.earlierData = data
            Self.later(m) { m.scrollTarget = "earlier-data" }
        }
        settings("MW-05.4", "Earlier data: brought in, the originals kept", .account) { m in
            var data = CapturesModel.sampleEarlierData(now: m.now)
            data[0].state = .broughtIn
            m.earlierData = data
            Self.later(m) { m.scrollTarget = "earlier-data" }
        }
        settings("AC-01.4", "Account: signed out", .account) { m in m.signedOut = true }
        settings("AC-01.5", "Sign in: waiting for Apple", .account) { m in
            m.signedOut = true
            m.signIn = SignInFlow(stage: .waiting(.apple))
        }
        settings("AC-01.5", "Sign in: couldn't sign in", .account) { m in
            m.signedOut = true
            m.signIn = SignInFlow(stage: .failed(.google, L("Google didn't answer. Check your connection, then try again.")))
        }
        settings("AC-01.5", "Sign in: check your email", .account) { m in
            m.signedOut = true
            m.signIn = SignInFlow(stage: .emailSent("sam@northwind.studio", Date()), email: "sam@northwind.studio")
        }
        settings("ST-02.4", "Account: couldn't save your name", .account) { m in m.nameSaveFailed = true }
        settings("AC-02.1", "Plan: Pro trial, 5 days left", .plan) { m in m.stagePlan(.trial) }
        settings("AC-02.1", "Plan: trial ended", .plan) { m in m.stagePlan(.trialEnded) }
        settings("AC-02.2", "Plan: usage limit reached", .plan) { m in m.stagePlan(.usedUp) }
        settings("MW-04d", "Plan: subscription ending", .plan) { m in m.stagePlan(.subscriptionEnding) }
        settings("MW-04d", "Plan: subscription expired", .plan) { m in m.stagePlan(.expired) }
        settings("MW-04d", "Plan: payment processing", .plan) { m in m.stagePlan(.paymentProcessing) }
        settings("MW-04d", "Plan: payment failed", .plan) { m in m.stagePlan(.paymentFailed) }
        settings("MW-04d", "Plan: couldn't open the billing page", .plan) { m in m.stagePlan(.billingUnavailable) }
        settings("Reset", "Settings: back to normal", .account) { _ in }
    }

    /// Every staged state off: Home and Settings as they are.
    func resetReview() {
        let m = model
        m.closeDetail()
        m.closeViewer()
        m.unstage()
        // A scroll asked for again must read as a change.
        m.scrollTarget = nil
        m.session = .ready
        m.capturesLoad = .loaded
        m.windowError = nil
        m.stagedEmpty = false
        m.holdRetries = false
        m.earlierData = []
        m.signIn = nil
        m.signedOut = false
        m.nameSaveFailed = false
        m.saveFailure = nil
        m.memoryDisclosureShown = false
        m.reporting = false
        m.reportFails = false
        m.leavingBeta = false
        m.update = .upToDate
        m.planAlert = nil
        m.plan = .pro
        m.nextPlan = nil
    }

    // MARK: Staging

    private func home(_ id: String, _ title: String, _ run: @escaping @MainActor (CapturesModel) -> Void) {
        Review.stage(id, title, area: .home) { [weak self] in
            guard let self else { return }
            self.resetReview()
            self.show()
            if self.model.page != .captures { self.model.show(.captures) }
            run(self.model)
        }
    }

    private func settings(_ id: String, _ title: String, _ category: SettingsCategory,
                          _ run: @escaping @MainActor (CapturesModel) -> Void) {
        Review.stage(id, title, area: .settings) { [weak self] in
            guard let self else { return }
            self.resetReview()
            self.showSettings(section: category.rawValue)
            run(self.model)
        }
    }

    /// After the page has drawn (a sheet, a scroll, an expanded card wait on it).
    static func later(_ m: CapturesModel, _ body: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.6))
            body()
        }
    }

    static func open(_ id: String, _ m: CapturesModel) {
        later(m) { m.open(id) }
    }

    // MARK: The stages' captures (never kept)

    /// MW-05.3, HI-01.3: one Dispatch session, four requests to the same chat.
    static func session(_ now: Date) -> [Capture] {
        let requests: [(minutes: Double, text: String, theme: String)] = [
            (190, "Make the notch's ears exactly as tall as the menu bar, and keep their curve the same at both sizes.", "Notch ears height"),
            (172, "Now the same on an external display, where there's no notch: the island should sit at the top center.", "Ears on other displays"),
            (150, "Run the tests for NotchGeometry and tell me what fails, before you change anything else.", "NotchGeometry tests"),
            (124, "Good. Write a short line for the changelog about the ears, in the voice of the last three entries.", "Changelog line"),
        ]
        return requests.enumerated().map { i, r in
            Capture(id: "review-session-\(i + 1)", kind: .dispatch, time: now.addingTimeInterval(-r.minutes * 60),
                    app: Fixtures.Apps.xcode, text: r.text,
                    destination: Destination(Fixtures.Agents.claudeCode, chat: "Notch ears", turn: i + 1),
                    theme: r.theme, seconds: 9 + Double(i) * 2, tags: ["Notch"])
        }
    }

    /// QA25: a Dispatch that didn't reach its agent.
    static func notSent(_ now: Date) -> Capture {
        Capture(id: "review-not-sent", kind: .dispatch, time: now.addingTimeInterval(-6 * 60), app: Fixtures.Apps.chrome,
                text: "Add rate limiting to the login endpoint: five tries a minute per IP, and a 429 with a Retry-After header once someone goes over.",
                destination: Destination(Fixtures.Agents.codex, chat: "auth middleware"), theme: "Login rate limiting", seconds: 14,
                tags: ["API"], sendFailure: "Codex didn't answer. It may have been closed, or its session ended.")
    }

    /// VF13: a recording whose words haven't come back (its words are in `recovered`).
    static func notTranscribed(_ now: Date) -> Capture {
        Fixtures.failed("review-failed-notes", now.addingTimeInterval(-3 * 60), Fixtures.Apps.notes,
                        because: "The network dropped while your words were on their way.", seconds: 18.4)
    }
}

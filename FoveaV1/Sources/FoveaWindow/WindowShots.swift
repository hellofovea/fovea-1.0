import SwiftUI
import AppKit
import CapturesCore
import FoveaKit

// `Fovea --design-shots window <dir>` (FoveaV1/README.md): Home and every Settings pane as
// pictures, for the dev team's design document. The window as the window server composites it
// (an app may always capture its own windows), with the sheet over it when one is up. Oct 15
// review: every state the review added, staged as the Review menu stages it (ReviewStages.swift),
// pictured as `review-<id>-<state>.png`.

extension HomeWindowController {
    package func designShots(to dir: URL) async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // The sheet that shows once (OB-02) is pictured on purpose below, not over everything.
        offersDisclosure = false
        // Oct 18, Ryan: `--language zh` pictures the window in Chinese, as the primary language.
        if let language = Self.shotsLanguage {
            model.prefs.languages = Array(Set(model.prefs.languages + [language])).sorted { $0 == .english && $1 != .english }
            model.prefs.appLanguage = language
            FoveaLocale.shared.language = language
        }
        show()
        await settle(1.6)
        // Oct 24: `--fixture` pictures the sample year (the fixture's captures, moved up to today)
        // in place of what the data dir holds, so no picture shows anyone's own captures. Only into
        // a `--data-dir` of its own: the samples are written to its store.
        if CommandLine.arguments.contains("--fixture"), CommandLine.arguments.contains(where: { $0.hasPrefix("--data-dir=") }) {
            let shift = Date().timeIntervalSince(Fixtures.now)
            model.library.captures = Fixtures.library(.typical).captures.map { c in
                var c = c
                c.time = c.time.addingTimeInterval(shift)
                return c
            }
            model.calendarYear = Lines.calendar.component(.year, from: Date())
            await settle(0.8)
        }
        // Oct 21, Ryan: `--smoke-detail` checks the expanded card's Copy, Save and Delete by doing
        // them (DetailSmoke.swift); it needs a `--data-dir` of its own.
        if CommandLine.arguments.contains("--smoke-detail") {
            await detailSmoke(dir)
            NSApp.terminate(nil)
            return
        }
        for dark in [false, true] {
            let suffix = dark ? "-dark" : ""
            let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            NSApp.appearance = appearance
            window.appearance = appearance
            model.show(.captures)
            await settle(1.0)
            shoot("home\(suffix)", dir)
            if dark { continue }
            model.tourUnfinished = true
            await settle(0.6)
            shoot("home-finish-tour", dir)
            model.tourUnfinished = false
            if let first = model.visible.first?.capture.id {
                model.open(first)
                await settle(1.2)
                shoot("home-capture-open", dir)
                model.closeDetail()
                await settle(0.8)
            }
            model.usageShown = true
            await settle(0.8)
            shoot("home-usage", dir)
            model.usageShown = false
            await settle(0.4)
        }
        for dark in [false, true] {
            let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            NSApp.appearance = appearance
            window.appearance = appearance
            for category in SettingsCategory.allCases where !dark || ["account", "notch", "about"].contains(category.rawValue) {
                model.show(.settings)
                openSettings(category.rawValue)
                await settle(1.0)
                shoot("settings-\(category.rawValue)\(dark ? "-dark" : "")", dir)
            }
        }
        NSApp.appearance = NSAppearance(named: .aqua)
        window.appearance = NSAppearance(named: .aqua)
        // Oct 24: `--no-review` stops at Home and the panes (the review's states take minutes).
        if !CommandLine.arguments.contains("--no-review") { await reviewShots(dir) }
    }

    /// Oct 15 review: each state the review added, as its stage shows it.
    private func reviewShots(_ dir: URL) async {
        let m = model
        func home(_ name: String, wait: Double = 1.0, _ set: @MainActor () -> Void) async {
            resetReview()
            model.show(.captures)
            await settle(0.5)
            set()
            await settle(wait)
            shoot("review-\(name)", dir)
        }
        func settings(_ name: String, _ category: SettingsCategory, scroll: String? = nil, wait: Double = 1.0,
                      _ set: @MainActor () -> Void) async {
            resetReview()
            openSettings(category.rawValue)
            await settle(0.6)
            set()
            if let scroll { await settle(0.3); m.scrollTarget = scroll }
            await settle(wait)
            shoot("review-\(name)", dir)
        }

        // Home
        await home("MW-02a-restoring") { m.session = .restoring }
        await home("MW-02a-restore-failed") { m.session = .failed }
        for error in WindowError.allCases {
            await home("MW-02b-\(error.rawValue)") { m.windowError = error }
        }
        await home("HI-01.6-loading") { m.capturesLoad = .loading }
        await home("HI-01.6-load-failed") { m.capturesLoad = .failed }
        await home("MW-05.1-empty") { m.stagedEmpty = true }
        await home("MW-05.3-requests") { m.stage(Self.session(m.now)) }
        await home("HI-01.3-open-in-notch", wait: 1.8) {
            m.stage(Self.session(m.now))
            Self.open("review-session-4", m)
        }
        await home("QA25-not-sent", wait: 1.8) {
            m.stage([Self.notSent(m.now)])
            Self.open("review-not-sent", m)
        }
        await home("VF13-card") {
            m.holdRetries = true
            m.stage([Self.notTranscribed(m.now)])
        }
        await home("VF11-expanded", wait: 1.8) {
            m.holdRetries = true
            m.stage([Self.notTranscribed(m.now)])
            Self.open("review-failed-notes", m)
        }
        await home("VF13-trying-again", wait: 1.8) {
            m.holdRetries = true
            m.stage([Self.notTranscribed(m.now)])
            m.transcribing.insert("review-failed-notes")
            Self.open("review-failed-notes", m)
        }
        await home("RC-01-banner") { m.earlierData = CapturesModel.sampleEarlierData(now: m.now) }
        await home("OB-02-memory", wait: 1.4) { m.memoryDisclosureShown = true }
        await home("IS04-save-failed", wait: 1.4) {
            m.saveFailure = SaveFailure(title: L("Couldn't Save “\("Notch ears height")”"),  // Oct 18, Ryan: in the primary language.
                                        message: L("You don't have permission to save the file “Notch ears height” in the folder “Shared”."))
        }

        // Settings
        await settings("ST-10.2-update", .about) { m.update = .available("1.0.1") }
        await settings("ST-10.2-installing", .about) { m.update = .installing("1.0.1", 0.42) }
        await settings("ST-10.1-checking", .about) { m.update = .checking }
        await settings("ST-10.2-check-failed", .about) { m.update = .failed }
        await settings("ST-10.3-leave-beta", .about, wait: 1.4) { m.leavingBeta = true }
        await settings("MW-04c-report-failed", .about, wait: 1.4) { m.reportFails = true; m.reporting = true }
        await settings("AC-01.4-signed-out", .account) { m.signedOut = true }
        await settings("AC-01.5-choose", .account, wait: 1.4) { m.signedOut = true; m.signIn = SignInFlow() }
        await settings("AC-01.5-waiting", .account, wait: 1.4) { m.signedOut = true; m.signIn = SignInFlow(stage: .waiting(.apple)) }
        await settings("AC-01.5-failed", .account, wait: 1.4) {
            m.signedOut = true
            m.signIn = SignInFlow(stage: .failed(.google, L("Google didn't answer. Check your connection, then try again.")))
        }
        await settings("AC-01.5-email-sent", .account, wait: 1.4) {
            m.signedOut = true
            m.signIn = SignInFlow(stage: .emailSent("sam@northwind.studio", Date()), email: "sam@northwind.studio")
        }
        await settings("ST-02.4-name-failed", .account) { m.nameSaveFailed = true }
        await settings("RC-02.1-earlier-data", .account, scroll: "earlier-data") {
            m.earlierData = CapturesModel.sampleEarlierData(now: m.now)
        }
        await settings("RC-02.1-bringing-in", .account, scroll: "earlier-data") {
            var data = CapturesModel.sampleEarlierData(now: m.now)
            data[0].state = .bringingIn(0.4)
            data[1].state = .failed("Fovea couldn't read the old history. Quit Fovea 0.9 if it's open, then try again.")
            m.earlierData = data
        }
        await settings("MW-05.4-brought-in", .account, scroll: "earlier-data") {
            var data = CapturesModel.sampleEarlierData(now: m.now)
            data[0].state = .broughtIn
            m.earlierData = data
        }
        for alert in [PlanAlert.trial, .trialEnded, .usedUp, .subscriptionEnding, .expired, .paymentProcessing, .paymentFailed, .billingUnavailable] {
            await settings("plan-\(alert.rawValue)", .plan) { m.stagePlan(alert) }
        }
        resetReview()
        model.show(.captures)
        await settle(0.4)
    }

    /// `--language zh` (or `--language=zh`, `en`): the language the pictures are in.
    static var shotsLanguage: FoveaLanguage? {
        let args = CommandLine.arguments
        let value = args.firstIndex(of: "--language").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
            ?? args.first { $0.hasPrefix("--language=") }.map { String($0.dropFirst("--language=".count)) }
        switch value?.lowercased() {
        case "zh", "zh-hans", "chinese": return .chinese
        case "en", "english": return .english
        default: return nil
        }
    }

    private func settle(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    /// The window, and the sheet over it when there is one.
    func shoot(_ name: String, _ dir: URL) {
        // Front to back: the sheet, then the window under it.
        var ids = [CGWindowID(window.windowNumber)]
        if let sheet = window.attachedSheet { ids.insert(CGWindowID(sheet.windowNumber), at: 0) }
        var pointers = ids.map { UnsafeRawPointer(bitPattern: UInt($0)) }
        guard let array = CFArrayCreate(nil, &pointers, pointers.count, nil),
              let image = CGImage(windowListFromArrayScreenBounds: .null, windowArray: array, imageOption: [.boundsIgnoreFraming, .bestResolution]),
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            print("failed \(name)"); return
        }
        try? png.write(to: dir.appendingPathComponent("\(name).png"))
        print("wrote \(name).png")
    }
}

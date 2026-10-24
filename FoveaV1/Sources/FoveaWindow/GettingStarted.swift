import AppKit
import AVFoundation
import Combine
import Speech
import SwiftUI
import CapturesCore
import FoveaKit
import FoveaLook
import FoveaPlatform

// Oct 15 review, OB-03.1 and OB-03.2: Settings › Getting Started, a section of its own. The tour
// again; one of its tasks to practise again; whether Fovea has what it needs (the five
// permissions, read live, each with Allow or Open Settings); and the keys as you have them. The
// tour and the tasks are the first run's (`onReplayTour`, `onPractice`: the app opens it).

extension CapturesModel {
    func replayTour() {
        if let replay = onReplayTour { replay() } else { say(L("Would start the tour again")) }
    }

    func practise(_ step: String, _ title: String) {
        if let practise = onPractice { practise(step) } else { say(L("Would open the tour at \(L(key: title).lowercased())")) }
    }
}

struct GettingStartedPane: View {
    @Environment(CapturesModel.self) private var model

    /// The first run's tasks, by its step (OnboardingCore's `Step` raw values).
    static let tasks: [(step: String, title: String, detail: String)] = [
        ("weeklyUpdate", "The weekly update", "A Dispatch from a chat and three tabs."),
        ("packList", "The packing list", "A Dispatch with a passage and a file."),
        ("followUp", "A follow-up", "Asking more in a session that's under way."),
        ("dictation", "Dictation", "Your words typed into two windows."),
    ]

    /// Oct 23, Ryan: what the tour doesn't cover, by its practice (OnboardingCore's `PracticeAgain`
    /// raw values).
    static let moreToTry: [(step: String, title: String, detail: String)] = [
        ("takeFew", "Take a few things", "Several screenshots in one request; look at one, take one out."),
        ("whileWorking", "While it works", "Type while the agent works, answer again with another model, and stop it."),
        ("nowhereToType", "Nowhere to type", "Where your words wait when there's no box to type in."),
    ]

    var body: some View {
        SettingsSection("The tour") {
            SettingsCard {
                SettingsRow("Take the tour again", detail: "The first run, from the start. Your captures and settings stay as they are.") {
                    PaneButton("Replay the Tour") { model.replayTour() }
                }
            }
        }

        SettingsSection("Practise again", note: "One task from the tour, with the practice agent. Nothing is sent anywhere else.") {
            SettingsCard {
                ForEach(Array(Self.tasks.enumerated()), id: \.element.step) { i, task in
                    if i > 0 { RowDivider() }
                    SettingsRow(task.title, detail: task.detail) {
                        PaneButton("Practise") { model.practise(task.step, task.title) }
                    }
                }
            }
        }

        SettingsSection("More to try", note: "What the tour doesn't cover, a minute each, with the practice agent.") {
            SettingsCard {
                ForEach(Array(Self.moreToTry.enumerated()), id: \.element.step) { i, task in
                    if i > 0 { RowDivider() }
                    SettingsRow(task.title, detail: task.detail) {
                        PaneButton("Try It") { model.practise(task.step, task.title) }
                    }
                }
            }
        }

        PermissionCheck()

        SettingsSection("Your keys", note: "Press once to start, again to stop.") {
            SettingsCard {
                ForEach(Array(FoveaKeys.changeable.enumerated()), id: \.element.id) { i, shortcut in
                    if i > 0 { RowDivider() }
                    SettingsRow(shortcut.title, detail: shortcut.detail) {
                        HStack(spacing: 4) {
                            ForEach(Array(model.keys(shortcut).enumerated()), id: \.offset) { _, key in KeyCap(key) }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } footer: {
                Text("Yours to change in Shortcuts.")
                Spacer()
                PaneButton("Open Shortcuts") { model.openSettings(.shortcuts) }
            }
        }
    }
}

/// The five things Fovea asks for, each read live: when the pane shows, every second it's open,
/// and when the window comes back to the front (after System Settings). Allow asks macOS where it
/// still can; Open Settings goes to the list where the person switches Fovea on.
private struct PermissionCheck: View {
    @Environment(CapturesModel.self) private var model
    @State private var states: [Permission: (granted: Bool, denied: Bool)] = [:]
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        // Oct 21, perf: what's known (`Permission.known`), not two reads of macOS per row per draw.
        let missing = Permission.allCases.filter { !(states[$0]?.granted ?? Permission.known($0).granted) }.count
        SettingsSection("What Fovea needs", note: missing == 0 ? "Everything is on." : L("\(missing) of 5 still off. Fovea works without them, but less.")) {
            SettingsCard {
                ForEach(Array(Permission.allCases.enumerated()), id: \.element) { i, permission in
                    if i > 0 { RowDivider() }
                    let state = states[permission] ?? Self.pair(Permission.known(permission))
                    SettingsRow(permission.paneName, detail: Self.why(permission)) {
                        if state.granted {
                            StatusLabel(word: "Allowed")
                        } else if state.denied {
                            // "Off" is also a shortcut not set (app.strings): a key of its own here.
                            StatusLabel(word: L("Off (permission)", english: "Off"), ok: false, fix: ("Open Settings", { permission.openSettings() }))
                        } else {
                            StatusLabel(word: "Not asked yet", ok: false, fix: ("Allow", { allow(permission) }))
                        }
                    }
                }
            }
        }
        .onAppear { refresh() }
        // Oct 21, perf: the poll, and a window coming forward, read macOS off the main thread.
        .onReceive(tick) { _ in refreshInBackground() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in refreshInBackground() }
        .onChange(of: model.permissionsChecked) { refresh() }
    }

    private func refresh() {
        // Oct 21, perf: one read of each (`Permission.standing`), not two.
        apply(Permission.read(Permission.allCases))
    }

    private func refreshInBackground() {
        Permission.readInBackground(Permission.allCases) { read in apply(read) }
    }

    private func apply(_ read: [Permission: PermissionStanding]) {
        for (p, standing) in read {
            let now = Self.pair(standing)
            if states[p]?.granted != now.0 || states[p]?.denied != now.1 { states[p] = now }
        }
    }

    private static func pair(_ s: PermissionStanding) -> (granted: Bool, denied: Bool) { (s.granted, s.denied) }

    /// macOS's own prompt, where it still asks (the microphone, speech, input monitoring); the
    /// list in System Settings everywhere else.
    private func allow(_ p: Permission) {
        switch p {
        case .microphone:
            AVCaptureDevice.requestAccess(for: .audio) { _ in Task { @MainActor in refresh() } }
        case .speechRecognition:
            SFSpeechRecognizer.requestAuthorization { _ in Task { @MainActor in refresh() } }
        case .inputMonitoring:
            Permission.requestInputMonitoring()
            refresh()
        case .accessibility, .screenRecording:
            p.openSettings()
        }
    }

    static func why(_ p: Permission) -> String {
        switch p {
        case .accessibility: return "Your keys in any app, and your words typed where you are."
        case .screenRecording: return "To take what you point at on the screen."
        case .microphone: return "To hear you."
        case .speechRecognition: return "To turn what you say into words, on this Mac."
        case .inputMonitoring: return "So your shortcuts are heard in every app."
        }
    }
}

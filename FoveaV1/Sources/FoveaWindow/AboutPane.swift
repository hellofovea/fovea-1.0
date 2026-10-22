import AppKit
import SwiftUI
import CapturesCore
import FoveaKit
import FoveaLook

// Oct 15 review, ST-10.1, ST-10.2, ST-10.3 and MW-04c: Settings › About, out of Account. The
// version with its build and a Beta badge; Check for Updates with its four states (checking, up to
// date, an update to Install and Relaunch, a check that failed with Try Again); Get Beta Updates,
// which asks before you leave; the help (Help Center, What's New, Report a Problem…, Send
// Feedback); the small print. Updates are simulated: 1.0 has no update server.

extension CapturesModel {
    /// Install and Relaunch: the download, then Fovea opens again on the new version. Simulated:
    /// there's no new version to download, so it says what it would do and stays on this one.
    func installUpdate(_ version: String) {
        animate(.layout) { update = .installing(version, 0) }
        Task { @MainActor in
            let steps = 26
            for step in 1...steps {
                try? await Task.sleep(for: .seconds(self.motion.seconds(T.Simulated.updateDownload / Double(steps))))
                guard case .installing = self.update else { return }
                self.update = .installing(version, Double(step) / Double(steps))
            }
            self.animate(.layout) { self.update = .upToDate }
            self.say(L("Would relaunch into Fovea \(version) (simulated)"))
        }
    }

    /// The menu's Check for Updates…: About, checking.
    func checkForUpdatesFromMenu() {
        openSettings(.about)
        if update != .checking { checkForUpdates() }
    }
}

struct AboutPane: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var model = model
        SettingsSection(nil) {
            SettingsCard {
                AboutVersion()
            }
        }

        SettingsSection("Updates") {
            SettingsCard {
                AboutUpdateRow()
                RowDivider()
                SettingsRow("Get beta updates", detail: "New features a few weeks early. They may have rough edges.") {
                    // ST-10.3: turning it off asks first; on is at once.
                    InkToggle(title: "Get beta updates", isOn: Binding(get: { model.prefs.betaUpdates }, set: { on in
                        if on { model.prefs.betaUpdates = true } else { model.leavingBeta = true }
                    }))
                }
            }
        }
        .alert("Leave the Beta?", isPresented: $model.leavingBeta) {
            Button("Leave the Beta") { model.animate(.layout) { model.prefs.betaUpdates = false } }
            Button("Stay in the Beta", role: .cancel) {}
        } message: {
            Text("You'll keep this beta until the next release of Fovea, then get release updates only.")
        }

        SettingsSection("Help") {
            SettingsCard {
                SettingsRow("Help Center", detail: "How Fovea works, and answers to what people ask most.") {
                    Link("Open ↗", destination: FoveaSite.helpCenter)
                }
                RowDivider()
                SettingsRow("What's New", detail: "What changed in each version.") {
                    Link("Open ↗", destination: FoveaSite.whatsNew)
                }
                RowDivider()
                SettingsRow("Something not working?", detail: "Tell us what went wrong. Diagnostics can go with it, if you agree.") {
                    Button("Report a Problem…") { model.reporting = true }
                }
                RowDivider()
                // Feedback goes to the website (Oct 13).
                SettingsRow("Something to tell us?", detail: "Ideas, what you like, what you'd change: on hellofovea.com.") {
                    Link("Send Feedback ↗", destination: FoveaSite.feedback)
                }
            } footer: {
                AboutLinks()
            }
        }
    }
}

/// Fovea's icon, its name, the version with its build, and Beta while on beta updates.
private struct AboutVersion: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let v = Diagnostics.version
        HStack(spacing: 14) {
            if let icon = Art.resource("AppIcon.png") {
                Image(nsImage: icon).resizable().interpolation(.high).frame(width: 56, height: 56)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("Fovea").font(.system(size: 15, weight: .semibold)).foregroundStyle(palette.text)
                    if model.prefs.betaUpdates { SoonPill(text: "Beta") }
                }
                Text("Version \(v.short) (\(v.build ?? L("development build")))")
                    .font(.system(size: 12)).foregroundStyle(palette.secondary)
                    .textSelection(.enabled)
                    .monospacedDigit()
            }
            Spacer()
        }
        .cardPadding()
    }
}

/// Check for Updates, in its four states: checking, up to date, an update to install, failed.
struct AboutUpdateRow: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13)).foregroundStyle(palette.text)
                detail
            }
            Spacer()
            control
        }
        .cardPadding()
        .animation(model.motion.animation(.layout), value: model.update)
    }

    // Oct 18, Ryan: in the primary language.
    private var title: String {
        switch model.update {
        case .available, .installing: return L("An update is ready")
        default: return L("Software update")
        }
    }

    @ViewBuilder private var detail: some View {
        switch model.update {
        case .upToDate:
            Text("Fovea is up to date.").font(.system(size: 11.5)).foregroundStyle(palette.secondary)
        case .checking:
            Text("Checking for updates…").font(.system(size: 11.5)).foregroundStyle(palette.secondary)
        case .failed:
            Text("Couldn't check for updates. Check your connection, then try again.")
                .font(.system(size: 11.5)).foregroundStyle(palette.danger)
        case .available(let version):
            Text("Fovea \(version) fixes the notch on external displays and makes dictation faster. Fovea relaunches to install it.")
                .font(.system(size: 11.5)).foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .installing(let version, let p):
            Text(p < 1 ? "Downloading Fovea \(version)… \(Int((p * 100).rounded()))%" : "Relaunching…")
                .font(.system(size: 11.5)).foregroundStyle(palette.secondary).monospacedDigit()
        }
    }

    @ViewBuilder private var control: some View {
        switch model.update {
        case .upToDate: Button("Check for Updates") { model.checkForUpdates() }
        case .checking: ProgressView().controlSize(.small)
        case .failed: Button("Try Again") { model.checkForUpdates() }
        case .available(let version):
            Button("Install and Relaunch") { model.installUpdate(version) }
                .buttonStyle(.borderedProminent)
        case .installing(_, let p):
            ProgressView(value: p).frame(width: 120)
        }
    }
}

/// Website · What leaves your Mac · Privacy Policy · Terms of Service, as the Mac app links them.
struct AboutLinks: View {
    var body: some View {
        HStack(spacing: 6) {
            Link("Website", destination: FoveaSite.home)
            Text(verbatim: "·")
            Link("What leaves your Mac", destination: FoveaSite.whatLeavesYourMac)
            Text(verbatim: "·")
            Link("Privacy Policy", destination: URL(string: "https://www.hellofovea.com/privacy")!)
            Text(verbatim: "·")
            Link("Terms of Service", destination: URL(string: "https://www.hellofovea.com/terms")!)
        }
    }
}

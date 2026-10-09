import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CapturesCore

// Settings from the App UI review (Oct 6), built on the panes as they were: the Language tab
// (row 6), your photo and name (row 8), Report a Problem (row 9), the links and the privacy the
// Mac app has (row 10), the plan's and the updates' states (row 13), how Fovea writes up what you
// said (row 15), the dictionary at its real size (rows 18–19), the questions' model and what they
// may include (rows 21–22), Memory as areas of your life over a searchable record (row 24), and
// places Fovea takes nothing from (row 25). The copy follows the Mac app's where it has one.

// MARK: - Values

enum AppLanguage: String, CaseIterable, Hashable {
    case english, chinese
    var title: String { self == .english ? "English" : "简体中文" }
}

enum NotchLanguage: String, CaseIterable, Hashable {
    case sameAsApp, english, chinese
    var title: String {
        switch self {
        case .sameAsApp: return "Same as Fovea"
        case .english: return "English"
        case .chinese: return "简体中文"
        }
    }
}

enum UpdateState: Equatable, Hashable {
    case upToDate, checking, failed, available(String)
    var title: String {
        switch self {
        case .upToDate: return "Up to Date"
        case .checking: return "Checking"
        case .failed: return "Check Failed"
        case .available: return "Update Available"
        }
    }
}

enum PlanAlert: String, CaseIterable, Hashable {
    case almostOut, usedUp, paymentProcessing
    var title: String {
        switch self {
        case .almostOut: return "Almost Out (93%)"
        case .usedUp: return "Used Up"
        case .paymentProcessing: return "Payment Processing"
        }
    }
}

/// The three ways the window can't open its data (row 13, 1–3): the Mac app's words.
enum WindowError: String, CaseIterable, Hashable {
    case storage, diskFull, preparing
    var menuTitle: String {
        switch self {
        case .storage: return "Storage Error"
        case .diskFull: return "Disk Full"
        case .preparing: return "Couldn't Prepare Data"
        }
    }
    var title: String {
        switch self {
        case .storage: return "Fovea hit a local storage error"
        case .diskFull: return "Local storage is full"
        case .preparing: return "Fovea couldn't finish preparing local data"
        }
    }
    var message: String {
        switch self {
        case .storage: return "Relaunch Fovea. If you keep seeing this, check that there's free disk space and that Fovea can write to its folder."
        case .diskFull: return "Free up some disk space, then relaunch Fovea. Nothing has been lost."
        case .preparing: return "Relaunch Fovea. If it keeps happening, keep your old history folder and write to us: Report a Problem in the Help menu."
        }
    }
}

enum LoadState: String, CaseIterable, Hashable { case loaded, loading, failed }

enum MemoryFilter: String, CaseIterable, Hashable {
    case all, hidden, deleted
    var title: String {
        switch self {
        case .all: return "All"
        case .hidden: return "Hidden from Agents"
        case .deleted: return "Recently Deleted"
        }
    }
}

enum Effort: String, CaseIterable, Hashable {
    case auto, low, medium, high, max
    var title: String { self == .auto ? "Auto" : rawValue.capitalized }
}

/// One place Fovea takes nothing from: an app, a website, or any text with certain words in it.
struct PrivacyRule: Identifiable, Hashable {
    enum Kind: String, CaseIterable, Hashable { case app, website, words }
    var id: String
    var kind: Kind
    var value: String
    var on = true

    var label: String {
        switch kind {
        case .app: return value
        case .website: return "Websites with “\(value)”"
        case .words: return "Anything with “\(value)”"
        }
    }

    static let defaults: [PrivacyRule] = [
        PrivacyRule(id: "r-1password", kind: .app, value: "1Password"),
        PrivacyRule(id: "r-keychain", kind: .app, value: "Keychain Access"),
        PrivacyRule(id: "r-bank", kind: .website, value: "bank"),
        PrivacyRule(id: "r-code", kind: .words, value: "验证码"),
    ]
}

/// The models a question can go to, for each agent (row 21): Auto first.
enum QuestionModels {
    static func options(for agent: String) -> [String] {
        switch agent {
        case "Claude Code": return ["Auto", "Opus 5.5", "Sonnet 5.5", "Haiku 4.5"]
        case "Codex": return ["Auto", "GPT-5 Codex", "GPT-5", "GPT-5 mini"]
        default: return ["Auto"]
        }
    }
}

// MARK: - Actions

extension CapturesModel {
    /// Your photo (row 8): JPG, PNG, GIF or WebP, up to 2 MB, as the Mac app takes it.
    func choosePhoto() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Profile Photo"
        panel.allowedContentTypes = [.jpeg, .png, .gif, .webP]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if size > 2 * 1024 * 1024 {
            showPhotoTooLarge()
        } else if let image = NSImage(contentsOf: url) {
            animate(.swap) { profilePhoto = image; photoTooLarge = false }
            say("Photo changed")
        }
    }

    func showPhotoTooLarge() {
        animate(.swap) { photoTooLarge = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            self.animate(.swap) { self.photoTooLarge = false }
        }
    }

    /// Check for Updates (row 13, 8–9): checking, then up to date.
    func checkForUpdates() {
        animate(.swap) { update = .checking }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            if self.update == .checking { self.animate(.swap) { self.update = .upToDate } }
        }
    }

    // Memory (row 24).

    func deleteMemories(_ ids: Set<String>) {
        guard !ids.isEmpty else { return }
        animate(.swap) {
            for i in library.memories.indices where ids.contains(library.memories[i].id) { library.memories[i].deleted = now }
            memorySelection = []
        }
        lastDeletedMemories = Array(ids)
        say("Deleted \(ids.count == 1 ? "a memory" : "\(ids.count) memories")", undo: true)
    }

    func restoreMemories(_ ids: Set<String>) {
        animate(.swap) {
            for i in library.memories.indices where ids.contains(library.memories[i].id) { library.memories[i].deleted = nil }
            memorySelection = []
        }
        say("Restored \(ids.count == 1 ? "a memory" : "\(ids.count) memories")")
    }

    func setHidden(_ ids: Set<String>, _ hidden: Bool) {
        animate(.swap) {
            for i in library.memories.indices where ids.contains(library.memories[i].id) { library.memories[i].hidden = hidden }
        }
        say(hidden ? "Hidden from agents" : "Agents can see it again")
    }

    func undoMemoryDelete() {
        let ids = Set(lastDeletedMemories)
        lastDeletedMemories = []
        animate(.swap) {
            for i in library.memories.indices where ids.contains(library.memories[i].id) { library.memories[i].deleted = nil }
        }
        withAnimation(motion.animation(.content)) { toast = nil }
    }

    func forgetArea(_ id: String) {
        guard let area = library.areas.first(where: { $0.id == id }) else { return }
        animate(.swap) { library.areas.removeAll { $0.id == id } }
        say("Forgot “\(area.title)”. What it came from stays in your memories.")
    }

    func updateArea(_ id: String, summary: String) {
        guard let i = library.areas.firstIndex(where: { $0.id == id }) else { return }
        animate(.swap) { library.areas[i].summary = summary; library.areas[i].updated = now }
        say("Saved. Fovea writes from your version now.")
    }

    /// Opens the capture a memory came from.
    func openCapture(_ id: String) {
        browsingMemories = false
        show(.captures)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.35))
            self.open(id)
        }
    }

    /// Settings, on one section (the usage popover's Upgrade, the Help menu).
    func openSettings(_ category: SettingsCategory) {
        show(.settings, pane: category.pane)
        pickSettings(category)
    }

    /// Your initial, where there's no photo.
    var initial: String {
        let name = profileName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "R" : String(name.prefix(1)).uppercased()
    }

    /// A sheet is over the window: its toast shows in the sheet instead, where it can be clicked.
    var sheetUp: Bool { browsingMemories || accessLogShown || reporting }
}

// MARK: - Language (row 6)

/// Fovea's words and the notch's, each its own; and the language you speak, which Fovea hears on
/// its own (moved here from Voice & Capture, so all of language is in one place).
struct LanguagePane: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var model = model
        SettingsSection(nil) {
            SettingsCard {
                SettingsRow("Fovea", detail: "Its menus, Settings and this window.") {
                    InlinePicker(options: AppLanguage.allCases, selection: $model.prefs.appLanguage, label: \.title)
                }
                RowDivider()
                SettingsRow("The notch", detail: "What the notch says while you work: Listening, the chats, the answers.") {
                    InlinePicker(options: NotchLanguage.allCases, selection: $model.prefs.notchLanguage, label: \.title)
                }
            } footer: {
                Text("The first time, Fovea follows your Mac's language. This prototype stays in English.")
            }
        }
        SettingsSection("Speech") {
            SettingsCard {
                SettingsRow("The language you speak", detail: "Fovea hears it on its own, even two in one sentence.") {
                    InlinePicker(options: ["Automatic", "English", "中文"], selection: $model.prefs.speechLanguage, label: { $0 })
                }
            }
        }
    }
}

// MARK: - Account (rows 8, 9, 10, 13)

/// You, in a circle: your photo, or your name's first letter.
struct ProfileImage: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            if let photo = model.profilePhoto {
                Image(nsImage: photo).resizable().aspectRatio(contentMode: .fill)
            } else {
                Circle().fill(palette.text)
                Text(verbatim: model.initial)
                    .font(.system(size: size * 0.4, weight: .semibold)).foregroundStyle(palette.card)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

/// Your photo and name, yours to change (row 8); the email, from how you signed in. Sign Out
/// stays in the header, where it was.
struct ProfileSection: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var confirmSignOut = false
    @State private var hoverPhoto = false

    var body: some View {
        @Bindable var model = model
        SettingsSection("Profile") {
            SettingsCard {
                HStack(spacing: 14) {
                    // Click your photo to change it; Edit shows under the pointer, as on System
                    // Settings' account picture.
                    Button { model.choosePhoto() } label: {
                        ProfileImage(size: 56)
                            .overlay {
                                Text("Edit").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                                    .frame(width: 56, height: 22)
                                    .background(Color.black.opacity(0.55))
                                    .frame(width: 56, height: 56, alignment: .bottom)
                                    .clipShape(Circle())
                                    .opacity(hoverPhoto ? 1 : 0)
                            }
                    }
                    .buttonStyle(.plain)
                    .onHover { hoverPhoto = $0 }
                    .help("Change Photo")
                    .accessibilityLabel("Change photo")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.profileName.isEmpty ? "Your name" : model.profileName)
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(palette.text)
                        Text(verbatim: "ryan@example.com").font(.system(size: 12)).foregroundStyle(palette.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    TextButton("Sign Out", role: .destructive) { confirmSignOut = true }
                }
                .cardPadding()
                RowDivider()
                SettingsRow("Name", detail: "How Fovea and your agents greet you.") {
                    TextField("Name", text: $model.profileName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
                RowDivider()
                PhotoRow()
            } footer: {
                Text("Your email comes from how you signed in, so it can't be changed here.")
            }
        }
        .confirmationDialog("Sign out of Fovea?", isPresented: $confirmSignOut) {
            Button("Sign Out") { model.say("Would sign out (simulated)") }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your captures stay on this Mac. You'll sign in again to dispatch.")
        }
    }
}

/// Your photo: what it can be, Choose and Remove; a photo over 2 MB says so here, in red, for a
/// moment (row 13 #7).
private struct PhotoRow: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Photo").font(.system(size: 13)).foregroundStyle(palette.text)
                if model.photoTooLarge {
                    Text("That photo is over 2 MB. Choose one under 2 MB.")
                        .font(.system(size: 11.5)).foregroundStyle(palette.danger)
                        .transition(.opacity)
                } else {
                    Text("JPG, PNG, GIF or WebP, up to 2 MB.")
                        .font(.system(size: 11.5)).foregroundStyle(palette.secondary)
                }
            }
            Spacer()
            if model.profilePhoto != nil {
                TextButton("Remove") { model.animate(.swap) { model.profilePhoto = nil } }
            }
            TextButton("Choose…") { model.choosePhoto() }
        }
        .cardPadding()
    }
}

/// Report a Problem (row 9): one button; diagnostics go with it if you agree.
struct SupportSection: View {
    @Environment(CapturesModel.self) private var model

    var body: some View {
        SettingsSection("Help") {
            SettingsCard {
                SettingsRow("Something not working?", detail: "Tell us what went wrong. Diagnostics can go with it, if you agree.") {
                    Button("Report a Problem…") { model.reporting = true }
                }
            }
        }
    }
}

/// The version and its updates (row 13, 8–9), beta updates, and the links (row 10).
struct UpdateRow: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Version 0.5 beta 7").font(.system(size: 13)).foregroundStyle(palette.text)
                switch model.update {
                case .upToDate:
                    Text("Fovea is up to date.").font(.system(size: 11.5)).foregroundStyle(palette.secondary)
                case .checking:
                    Text("Checking…").font(.system(size: 11.5)).foregroundStyle(palette.secondary)
                case .failed:
                    Text("Couldn't check for updates. Check your connection, then try again.")
                        .font(.system(size: 11.5)).foregroundStyle(palette.danger)
                case .available(let version):
                    Text("Version \(version) is available.").font(.system(size: 11.5)).foregroundStyle(palette.text)
                }
            }
            Spacer()
            switch model.update {
            case .upToDate: Button("Check for Updates") { model.checkForUpdates() }
            case .checking: ProgressView().controlSize(.small)
            case .failed: Button("Try Again") { model.checkForUpdates() }
            case .available(let version):
                Button("Update…") { model.say("Would download and install \(version) (simulated)") }
                    .buttonStyle(.borderedProminent)
            }
        }
        .cardPadding()
    }
}

/// Website · Privacy Policy · Terms of Service, as the Mac app links them.
struct LegalLinks: View {
    var body: some View {
        HStack(spacing: 6) {
            Link("Website", destination: URL(string: "https://www.hellofovea.com/")!)
            Text("·")
            Link("Privacy Policy", destination: URL(string: "https://www.hellofovea.com/privacy")!)
            Text("·")
            Link("Terms of Service", destination: URL(string: "https://www.hellofovea.com/terms")!)
        }
    }
}

/// Report a Problem, as a Mac sheet: what happened, and whether diagnostics go with it. Sending
/// them asks first, listing what goes and what never does (the Mac app's consent, kept).
struct ReportProblemSheet: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var text = ""
    @State private var diagnostics = true
    @State private var showIncluded = false
    @State private var confirm = false
    @State private var stage: Stage = .writing
    enum Stage: Equatable { case writing, sending, sent(String) }

    static let included = [
        "App logs from the last 3 days (up to 8 MB, events only)",
        "Your Mac's model, macOS version and Fovea's permissions",
        "Fovea's version and an anonymous account ID",
    ]
    static let never = [
        "No recordings, transcripts or requests",
        "No clipboard, files or selected text",
        "Never your email, tokens or user name",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch stage {
            case .writing, .sending:
                Text("Report a Problem").font(.system(size: 15, weight: .semibold))
                Text("What happened, and what did you expect instead?")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .font(.system(size: 13))
                    .frame(height: 130)
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.35), lineWidth: 0.5))
                Toggle("Include diagnostic information", isOn: $diagnostics)
                    .toggleStyle(.checkbox)
                DisclosureGroup("What's included", isExpanded: $showIncluded) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Self.included, id: \.self) { Label($0, systemImage: "checkmark").foregroundStyle(.secondary) }
                        ForEach(Self.never, id: \.self) { Label($0, systemImage: "xmark").foregroundStyle(.secondary) }
                    }
                    .font(.system(size: 11.5))
                    .padding(.top, 4)
                }
                .font(.system(size: 12))
                HStack {
                    if stage == .sending {
                        ProgressView().controlSize(.small)
                        Text(diagnostics ? "Packaging diagnostics…" : "Sending…").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Cancel") { model.reporting = false }
                        .keyboardShortcut(.cancelAction)
                    Button("Send Report") { diagnostics ? (confirm = true) : send() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || stage == .sending)
                }
            case .sent(let id):
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 26)).foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Thanks, your report is on its way").font(.system(size: 15, weight: .semibold))
                        Text("If you write to us about it, include its ID: \(id).")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                HStack {
                    Spacer()
                    Button("Copy ID") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(id, forType: .string)
                    }
                    Button("Done") { model.reporting = false }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 460)
        .alert("Send diagnostic information?", isPresented: $confirm) {
            Button("Agree & Send") { send() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It helps us find what went wrong on your Mac. It includes:\n"
                 + Self.included.map { "✓ \($0)" }.joined(separator: "\n") + "\n\n"
                 + Self.never.map { "✗ \($0)" }.joined(separator: "\n"))
        }
    }

    private func send() {
        stage = .sending
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(diagnostics ? 1.6 : 0.8))
            stage = .sent("FV-8C2D41A9")
        }
    }
}

// MARK: - Plan (row 13, 4–6)

/// This month's credits, as System Settings shows a capacity (its Storage, its iCloud): what's
/// left, and what's used of the total, at the left; the Mac's own capacity indicator, short, at
/// the right. Under them, what credits are for; used up, what waits and Upgrade; a payment in
/// flight says Pro is on its way.
struct PlanUsageCard: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let usage = model.usage
        let f = usage.fraction
        let usedUp = usage.left == 0
        SettingsCard {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(usedUp ? "No credits left" : "\(usage.left.formatted()) credits left")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(usedUp ? palette.danger : palette.text)
                    Text("\(usage.used.formatted()) of \(usage.total.formatted()) used · resets \(Lines.day(usage.resets))")
                        .font(.system(size: 11.5)).foregroundStyle(palette.secondary)
                }
                .monospacedDigit()
                Spacer(minLength: 16)
                CreditsLevel(used: usage.used, total: usage.total)
                    .frame(width: 180)
            }
            .cardPadding()
            if model.planAlert == .paymentProcessing {
                RowDivider()
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Your payment is processing. Pro unlocks on its own.")
                        .font(.system(size: 12.5)).foregroundStyle(palette.text)
                    Spacer()
                    Button("Refresh") { model.say("Still processing (simulated)") }
                }
                .cardPadding()
            }
        } footer: {
            if usedUp {
                Text("Taking things and dispatching wait until \(Lines.day(usage.resets)). Dictation stays free.")
                Spacer()
                // Not while a payment is on its way: that is the upgrade.
                if model.planAlert != .paymentProcessing {
                    Button("Upgrade…") { model.scrollTarget = "plans" }
                        .buttonStyle(.borderedProminent)
                }
            } else if f >= 0.9 {
                Text("Almost out: \(Int(((1 - f) * 100).rounded()))% left until \(Lines.day(usage.resets)).")
                    .foregroundStyle(palette.danger)
            } else {
                Text("Dictation is free. Taking things off the screen and dispatching use credits.")
            }
        }
    }
}

/// Credits used, drawn as the Mac draws a capacity (HIG › Gauges › macOS): its level indicator in
/// the continuous capacity style, a translucent track filling with a solid bar. Green, the Mac's
/// own fill; yellow past 70 % and red past 90 % (the Mac app's thresholds, set as the indicator's
/// warning and critical values), so the colors are the system's, not ours. Not a progress bar:
/// those are for work under way.
struct CreditsLevel: NSViewRepresentable {
    let used: Int
    let total: Int

    func makeNSView(context: Context) -> NSLevelIndicator {
        let level = NSLevelIndicator()
        level.levelIndicatorStyle = .continuousCapacity
        level.isEditable = false
        level.minValue = 0
        level.setContentHuggingPriority(.defaultLow, for: .horizontal)
        level.setAccessibilityLabel("Credits used")
        return level
    }

    func updateNSView(_ level: NSLevelIndicator, context: Context) {
        let max = Double(Swift.max(total, 1))
        level.maxValue = max
        level.warningValue = max * 0.7
        level.criticalValue = max * 0.9
        level.doubleValue = Double(Swift.min(used, total))
        level.setAccessibilityValueDescription("\(used.formatted()) of \(total.formatted()) credits used")
    }

    /// As wide as it's given, as tall as the Mac makes it.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSLevelIndicator, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 180, height: nsView.intrinsicContentSize.height)
    }
}

// MARK: - Voice & Capture (row 25)

/// Places Fovea takes nothing from (row 25): apps and websites (nothing taken, nothing heard while
/// they're in front) and words (anything containing them stays out of your history and memory).
/// Each can be paused; the Mac app's private sources, by app, site and content.
struct PrivacyRulesCard: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var adding: PrivacyRule.Kind?
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 8) {
            Text("Never capture in").font(.system(size: 13, weight: .medium)).foregroundStyle(palette.text)
            Text("Fovea takes nothing, and doesn't listen, while one of these is in front. Anything with one of these words stays out of your history and memory.")
                .font(.system(size: 11.5)).foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                // By id, not by index: a rule can be removed while its switch is on screen.
                ForEach(model.prefs.privacyRules) { rule in
                    HStack(spacing: 10) {
                        icon(rule)
                        Text(rule.label).font(.system(size: 12.5)).foregroundStyle(rule.on ? palette.text : palette.tertiary)
                        Spacer()
                        Toggle(rule.label, isOn: isOn(rule.id)).toggleStyle(.switch).controlSize(.mini).labelsHidden()
                        Button {
                            model.animate(.swap) { model.prefs.privacyRules.removeAll { $0.id == rule.id } }
                        } label: {
                            Image(systemName: "minus.circle").foregroundStyle(palette.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Remove")
                        .accessibilityLabel("Remove \(rule.label)")
                    }
                    .padding(.vertical, 6)
                }
                if let kind = adding {
                    HStack(spacing: 8) {
                        TextField(kind == .app ? "App name" : kind == .website ? "Part of a web address, e.g. bank" : "Words, e.g. 验证码",
                                  text: $text)
                            .textFieldStyle(.roundedBorder)
                            .focused($focused)
                            .onSubmit { commit(kind) }
                            .onAppear { focused = true }
                        Button("Add") { commit(kind) }.disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                        Button("Cancel") { adding = nil; text = "" }
                    }
                    .padding(.vertical, 6)
                }
            }
            Menu("Add") {
                Button("App…") { adding = .app }
                Button("Website…") { adding = .website }
                Button("Words…") { adding = .words }
            }
            .fixedSize()
        }
        .cardPadding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func icon(_ rule: PrivacyRule) -> some View {
        switch rule.kind {
        case .app:
            Image(nsImage: VoicePane.icon(rule.value) ?? NSWorkspace.shared.icon(for: .application))
                .resizable().frame(width: 18, height: 18)
        case .website:
            Image(systemName: "globe").frame(width: 18).foregroundStyle(palette.secondary)
        case .words:
            Image(systemName: "text.quote").frame(width: 18).foregroundStyle(palette.secondary)
        }
    }

    private func isOn(_ id: String) -> Binding<Bool> {
        Binding(get: { model.prefs.privacyRules.first { $0.id == id }?.on ?? false },
                set: { on in
                    if let i = model.prefs.privacyRules.firstIndex(where: { $0.id == id }) { model.prefs.privacyRules[i].on = on }
                })
    }

    private func commit(_ kind: PrivacyRule.Kind) {
        let value = text.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        model.animate(.swap) {
            model.prefs.privacyRules.append(PrivacyRule(id: "r-\(UUID().uuidString.prefix(6))", kind: kind, value: value))
        }
        adding = nil
        text = ""
    }
}

// MARK: - Dictionary (rows 13·15, 18, 19)

/// The words Fovea writes your way, at their real number (row 18): searched, filtered, A to Z in a
/// list that scrolls in place, the learned ones marked ✦ with what Fovea heard first (row 19).
struct DictionarySection: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.settingsNative) private var native
    @State private var search = ""
    @State private var newWord = ""

    var body: some View {
        let all = model.library.dictionary
        let tab = model.dictionaryTab
        let tokens = search.lowercased().split(separator: " ").map(String.init)
        let words = all.filter { w in
            (tab == .all || (tab == .learned ? w.source == .learned : w.source == .added))
                && tokens.allSatisfy { t in w.word.lowercased().contains(t) || (w.heardAs?.lowercased().contains(t) ?? false) }
        }
        .sorted { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }
        let groups = Dictionary(grouping: words) { Self.letter($0.word) }
        let letters = groups.keys.sorted { a, b in a == "#" ? false : (b == "#" ? true : a < b) }

        SettingsSection("Dictionary") {
            if !model.signedOut && !all.isEmpty {
                SettingsSegments(segments: DictionaryTab.allCases.map { t in
                    let n = t == .all ? all.count : all.filter { $0.source == (t == .learned ? .learned : .added) }.count
                    return (t, "\(t == .added ? "Added" : t.title) \(n)")
                }, selection: tab, inset: 3, padding: 8) { t in
                    model.animate(.swap) { model.dictionaryTab = t }
                }
            }
        } content: {
            SettingsCard {
                if model.signedOut {
                    VStack(spacing: 8) {
                        Image(systemName: "lock").font(.system(size: 20)).foregroundStyle(palette.tertiary)
                        Text("Sign in to use your dictionary.").font(.system(size: 13)).foregroundStyle(palette.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    HStack(spacing: 8) {
                        if !all.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass").foregroundStyle(palette.tertiary)
                                TextField("Search \(all.count) words", text: $search).textFieldStyle(.plain)
                                if !search.isEmpty {
                                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(palette.tertiary) }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Clear search")
                                }
                            }
                            .font(.system(size: 12.5))
                            .padding(.horizontal, 8)
                            .frame(height: 26)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(palette.fill))
                        }
                        TextField(all.isEmpty ? "Add a name, a term or an acronym" : "Add a word", text: $newWord)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: all.isEmpty ? .infinity : 150)
                            .onSubmit { add() }
                        Button("Add") { add() }.disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .cardPadding()
                    RowDivider()
                    if all.isEmpty {
                        Text("No words yet. Add one above, and Fovea writes it your way.")
                            .font(.system(size: 12.5)).foregroundStyle(palette.secondary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else if words.isEmpty {
                        Text("No matching words.").font(.system(size: 12.5)).foregroundStyle(palette.secondary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                                ForEach(letters, id: \.self) { letter in
                                    Section {
                                        ForEach(groups[letter] ?? []) { w in WordRow(word: w) }
                                    } header: {
                                        Text(letter)
                                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(palette.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 3)
                                            .background(native ? palette.nativeGroup : palette.card)
                                    }
                                }
                            }
                        }
                        .frame(height: 300)
                    }
                }
            } footer: {
                if !model.signedOut {
                    Text("✦ Learned: Fovea adds a word when you correct what it typed. The rest you added.")
                }
            }
        }
    }

    /// The section a word sorts under: its first letter, or # for the rest (numbers, 中文).
    static func letter(_ word: String) -> String {
        guard let c = word.first, c.isLetter, c.isASCII else { return "#" }
        return String(c).uppercased()
    }

    private func add() {
        model.addWord(newWord)
        newWord = ""
    }
}

/// One word: as Fovea writes it; for a learned one, what it heard first and where; when; ✕ on hover.
private struct WordRow: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let word: DictionaryWord
    @State private var hover = false

    var body: some View {
        HStack(spacing: 8) {
            Text(word.source == .learned ? "✦" : " ")
                .font(.system(size: 10)).foregroundStyle(palette.accent).frame(width: 12)
            Text(word.word).font(.system(size: 13)).foregroundStyle(palette.text)
            if let heard = word.heardAs {
                Text("heard as “\(heard)”\(word.learnedIn.map { " in \($0)" } ?? "")")
                    .font(.system(size: 11.5)).foregroundStyle(palette.tertiary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(Lines.day(word.date)).font(.system(size: 11)).foregroundStyle(palette.tertiary).monospacedDigit()
            Button {
                model.removeWord(word.id)
                model.say("Removed “\(word.word)”")
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(palette.tertiary)
            }
            .buttonStyle(.plain)
            .opacity(hover ? 1 : 0)
            .help("Remove")
            .accessibilityLabel("Remove \(word.word)")
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(hover ? palette.ink(0.04) : .clear)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }
}

// MARK: - Memory (rows 13·12–14, 24, 25)

/// Memory, as people think of it (row 24, after Claude's memory topics): the areas of your life
/// Fovea has come to know, each a short summary in its words, read from the tags that keep coming
/// up; under them, every memory, raw, with the words and the capture each came from, one button
/// away and searchable. Then what it may remember.
struct MemorySection: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var model = model
        let active = model.library.memories.filter { $0.deleted == nil }
        Group {
            switch model.memoryState {
            case .loading:
                SettingsSection("About you") {
                    SettingsCard {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text("Loading your memories…").font(.system(size: 12.5)).foregroundStyle(palette.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                    }
                }
                .id("memory-about")
            case .failed:
                SettingsSection("About you") {
                    SettingsCard {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle").font(.system(size: 18)).foregroundStyle(palette.warning)
                            Text("Couldn't load your memories: the memory file is in use.")
                                .font(.system(size: 12.5)).foregroundStyle(palette.text)
                            Button("Try Again") { model.animate(.swap) { model.memoryState = .loaded } }
                        }
                        .frame(maxWidth: .infinity, minHeight: 140)
                    }
                }
                .id("memory-about")
            case .loaded where active.isEmpty && model.library.areas.isEmpty:
                SettingsSection("About you") {
                    SettingsCard {
                        VStack(spacing: 6) {
                            Image(systemName: "brain.head.profile").font(.system(size: 20)).foregroundStyle(palette.tertiary)
                            Text("No memories yet").font(.system(size: 13, weight: .medium)).foregroundStyle(palette.secondary)
                            Text("Send something to an agent, or say “remember that …”, and it shows up here.")
                                .font(.system(size: 12)).foregroundStyle(palette.tertiary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 140)
                    }
                }
                .id("memory-about")
            case .loaded:
                SettingsSection("About you", note: "What Fovea has come to know from what you send your agents, in its own words. Correct it, or forget a part.") {
                    if !model.prefs.memoryLink {
                        HStack(spacing: 8) {
                            Image(systemName: "pause.circle").foregroundStyle(palette.secondary)
                            Text("Memory Link is off: what you send now isn't remembered.")
                                .font(.system(size: 12)).foregroundStyle(palette.text)
                            Spacer()
                            Button("Turn On") { model.animate(.swap) { model.prefs.memoryLink = true } }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(palette.fill))
                    }
                    VStack(spacing: 10) {
                        ForEach(model.library.areas) { area in AreaCard(area: area) }
                    }
                }
                .id("memory-about")
                SettingsSection("All memories") {
                    SettingsCard {
                        SettingsRow("\(active.count.formatted()) memories",
                                    detail: "Everything the summaries come from: each with the words it came from, and its capture.") {
                            Button("Search Memories…") { model.browsingMemories = true }
                        }
                    }
                }
            }
        }
        SettingsSection("Remembering") {
            SettingsCard {
                SettingsRow("Memory Link", detail: "Remember what you send your agents, not only what you ask Fovea to remember. Off pauses it.") {
                    InkToggle(title: "Memory Link", isOn: $model.prefs.memoryLink)
                }
                RowDivider()
                SettingsRow("Remember things when you ask", detail: "Press fn and say “remember that …”.") {
                    InkToggle(title: "Remember things when you ask", isOn: $model.prefs.remember)
                }
                RowDivider()
                SettingsRow("Show when Fovea remembers something") {
                    InkToggle(title: "Show when Fovea remembers something", isOn: $model.prefs.rememberNotice)
                }
                RowDivider()
                SettingsRow("Agents' reading", detail: "Which agents read your memory, and when.") {
                    Button("Access Log…") { model.accessLogShown = true }
                }
            }
        }
        .id("memory-remembering")
    }
}

/// One area of your life: its summary (yours to correct), the tags it reads from with how often
/// each came up (each shows its captures), and when it last changed. Forget it from its menu.
private struct AreaCard: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let area: MemoryArea
    @State private var editing = false
    @State private var draft = ""
    @State private var confirmForget = false

    var body: some View {
        let counts = Dictionary(uniqueKeysWithValues: CaptureSearch.tags(in: model.library.captures).map { ($0.tag, $0.count) })
        SettingsCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: area.symbol)
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(palette.accent))
                    Text(area.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.text)
                    Spacer()
                    Text("Updated \(Lines.relative(area.updated, now: model.now))")
                        .font(.system(size: 11)).foregroundStyle(palette.tertiary)
                    Menu {
                        Button("Edit Summary…") { draft = area.summary; editing = true }
                        Divider()
                        Button("Forget “\(area.title)”…", role: .destructive) { confirmForget = true }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundStyle(palette.secondary)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Edit or forget")
                }
                if editing {
                    TextEditor(text: $draft)
                        .font(.system(size: 13))
                        .frame(height: 96)
                        .padding(4)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(palette.accent, lineWidth: 1))
                    HStack {
                        Spacer()
                        Button("Cancel") { editing = false }
                        Button("Save") { model.updateArea(area.id, summary: draft); editing = false }
                            .keyboardShortcut(.defaultAction)
                    }
                } else {
                    Text(area.summary)
                        .font(.system(size: 13)).foregroundStyle(palette.text)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                FlowLayout(spacing: 6) {
                    ForEach(area.tags.filter { counts[$0] != nil }, id: \.self) { tag in
                        Button { model.show(tag: tag) } label: {
                            HStack(spacing: 4) {
                                Text(tag).foregroundStyle(palette.text)
                                Text("\(counts[tag] ?? 0)").foregroundStyle(palette.tertiary).monospacedDigit()
                            }
                            .font(.system(size: 11.5))
                            .padding(.horizontal, 9)
                            .frame(height: 22)
                            .background(Capsule().fill(palette.fill))
                        }
                        .buttonStyle(.plain)
                        .help("Show the \(counts[tag] ?? 0) captures tagged “\(tag)”")
                    }
                }
            }
            .cardPadding()
        }
        .confirmationDialog("Forget “\(area.title)”?", isPresented: $confirmForget) {
            Button("Forget", role: .destructive) { model.forgetArea(area.id) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Fovea stops using this summary. The memories it came from stay, searchable, until you delete them.")
        }
    }
}

/// Every memory, raw (row 24): search them, see only those hidden from agents or recently
/// deleted, select several (⌘ and ⇧ as any Mac list), delete with Undo, hide from agents,
/// restore; the one selected shows its words, where it came from, and its capture.
struct MemoryBrowser: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var search = ""

    var body: some View {
        @Bindable var model = model
        let tokens = search.lowercased().split(separator: " ").map(String.init)
        let shown = model.library.memories.filter { m in
            switch model.memoryFilter {
            case .all: guard m.deleted == nil else { return false }
            case .hidden: guard m.deleted == nil, m.hidden else { return false }
            case .deleted: guard m.deleted != nil else { return false }
            }
            let hay = ([m.text, m.quote] + m.tags).joined(separator: " ").lowercased()
            return tokens.allSatisfy { hay.contains($0) }
        }
        .sorted { $0.date > $1.date }
        let selected = model.memorySelection
        let one = selected.count == 1 ? model.library.memories.first { selected.contains($0.id) } : nil

        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text("Memories").font(.system(size: 15, weight: .semibold))
                Spacer()
                Picker("Show", selection: $model.memoryFilter) {
                    ForEach(MemoryFilter.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search by words or tags", text: $search)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.secondary.opacity(0.12)))
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            Divider()
            HStack(spacing: 0) {
                if shown.isEmpty {
                    Text(model.memoryFilter == .deleted ? "No recently deleted memories." :
                            model.memoryFilter == .hidden ? "No memories hidden from agents." : "No matching memories.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $model.memorySelection) {
                        ForEach(shown) { m in MemoryListRow(memory: m).tag(m.id) }
                    }
                    .listStyle(.inset)
                    .onDeleteCommand { delete(selected) }
                    .frame(minWidth: 380)
                }
                Divider()
                MemoryDetail(memory: one, count: selected.count)
                    .frame(width: 280)
            }
            Divider()
            HStack(spacing: 8) {
                if let message = model.toast {
                    // The window's toast, here, where it can be clicked while the sheet is up.
                    Text(message).font(.system(size: 12, weight: .medium))
                    if !model.lastDeletedMemories.isEmpty {
                        Button("Undo") { model.undoMemoryDelete() }
                            .keyboardShortcut("z", modifiers: .command)
                    }
                } else {
                    Text(selected.isEmpty ? "\(shown.count.formatted()) \(shown.count == 1 ? "memory" : "memories")" : "\(selected.count) selected")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Text(model.memoryFilter == .deleted ? "Gone for good 30 days after they're deleted."
                                                        : "⇧- or ⌘-click selects several, ⌘A all · ⌘⌫ deletes")
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                Spacer()
                if model.memoryFilter == .deleted {
                    Button("Restore") { model.restoreMemories(selected) }.disabled(selected.isEmpty)
                } else {
                    let allHidden = !selected.isEmpty && model.library.memories.filter { selected.contains($0.id) }.allSatisfy(\.hidden)
                    Button(allHidden ? "Show to Agents" : "Hide from Agents") { model.setHidden(selected, !allHidden) }
                        .disabled(selected.isEmpty)
                    Button("Delete", role: .destructive) { delete(selected) }
                        .keyboardShortcut(.delete, modifiers: .command)
                        .disabled(selected.isEmpty)
                }
                Button("Done") { model.browsingMemories = false }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 760, height: 540)
        .onChange(of: model.memoryFilter) { model.memorySelection = [] }
    }

    private func delete(_ ids: Set<String>) {
        guard model.memoryFilter != .deleted else { return }
        model.deleteMemories(ids)
    }
}

/// A memory in the list: its words, then when, its area and tags; marked when hidden from agents,
/// and, deleted, how long until it's gone for good.
private struct MemoryListRow: View {
    @Environment(CapturesModel.self) private var model
    let memory: Memory

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                if memory.hidden { Image(systemName: "eye.slash").font(.system(size: 10)).foregroundStyle(.secondary) }
                Text(memory.text).font(.system(size: 13)).lineLimit(1)
            }
            Text(line).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private var line: String {
        var parts = [Lines.day(memory.date)]
        if let a = memory.area, let area = model.library.areas.first(where: { $0.id == a }) { parts.append(area.title) }
        if !memory.tags.isEmpty { parts.append(memory.tags.joined(separator: ", ")) }
        if let d = memory.deleted {
            let left = max(0, 30 - (Lines.calendar.dateComponents([.day], from: d, to: model.now).day ?? 0))
            parts.append(left == 0 ? "Gone soon" : "Gone for good in \(left) days")
        }
        return parts.joined(separator: " · ")
    }
}

/// The memory selected: its words, the words it came from, where, its tags, and its capture.
private struct MemoryDetail: View {
    @Environment(CapturesModel.self) private var model
    let memory: Memory?
    let count: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let m = memory {
                    Text(m.text).font(.system(size: 14, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(m.stated ? "You asked Fovea to remember" : "From what you said").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        Text("“\(m.quote)”").font(.system(size: 12.5)).fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("When").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        Text("\(Lines.day(m.date))\(m.scope.map { " · \($0)" } ?? "")").font(.system(size: 12.5))
                    }
                    if !m.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tags").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                            FlowLayout(spacing: 5) {
                                ForEach(m.tags, id: \.self) { t in
                                    Text(t).font(.system(size: 11.5)).padding(.horizontal, 8).frame(height: 20)
                                        .background(Capsule().fill(Color.secondary.opacity(0.14)))
                                }
                            }
                        }
                    }
                    if m.hidden {
                        Label("Hidden from agents: Fovea still uses it.", systemImage: "eye.slash")
                            .font(.system(size: 11.5)).foregroundStyle(.secondary)
                    }
                    if let id = m.captureID, model.library.captures.contains(where: { $0.id == id }) {
                        Button("Show Capture") { model.openCapture(id) }
                    }
                } else {
                    Text(count > 1 ? "\(count) memories selected" : "Select a memory to see where it came from.")
                        .font(.system(size: 12.5)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// When agents read your memory, which, and what they asked (the Mac app's external AI access
/// log): read-only.
struct AccessLogSheet: View {
    @Environment(CapturesModel.self) private var model
    @State private var filter = "All"
    static let events: [(agent: String, kind: String, what: String, results: Int, when: String)] = [
        ("Claude Code", "Search", "“ears”", 2, "Today, 13:38"),
        ("Claude Code", "Recall", "recent memories", 5, "Today, 11:02"),
        ("Codex", "Search", "“第二屏”", 1, "Yesterday, 16:40"),
        ("Claude Code", "List", "work", 12, "Sep 24, 10:15"),
        ("Codex", "Search", "“rate limits”", 3, "Sep 23, 09:51"),
    ]

    var body: some View {
        let kinds = ["All", "Search", "Recall", "List"]
        let shown = Self.events.filter { filter == "All" || $0.kind == filter }
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Agents' reading").font(.system(size: 15, weight: .semibold))
                Spacer()
                Picker("Show", selection: $filter) { ForEach(kinds, id: \.self) { Text($0).tag($0) } }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
            }
            Text("When an agent read your memory through Fovea, and what it asked. Read-only.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            List(shown, id: \.when) { e in
                HStack {
                    Image(nsImage: Art.agentIcon(e.agent)).resizable().frame(width: 20, height: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(e.agent) · \(e.kind) \(e.what)").font(.system(size: 12.5))
                        Text("\(e.results) \(e.results == 1 ? "result" : "results") · \(e.when)").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.inset)
            .frame(height: 220)
            HStack { Spacer(); Button("Done") { model.accessLogShown = false }.keyboardShortcut(.defaultAction) }
        }
        .padding(20)
        .frame(width: 480)
    }
}

// MARK: - Connectors (rows 21, 22)

/// Who answers a question, with which model and how much thinking, for new chats (row 21), and how
/// many rounds an answer shows; then what a question may include from your screen, each yours to
/// allow (row 22).
struct QuestionsSections: View {
    @Environment(CapturesModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let agent = model.prefs.answerWith
        SettingsSection("Questions") {
            SettingsCard {
                SettingsRow("Answer with", detail: "Who answers a question you dispatch.") {
                    InlinePicker(options: ["Fovea", "Claude Code", "Codex"], selection: $model.prefs.answerWith, label: { $0 },
                                 icon: { $0 == "Fovea" ? Art.resource("AppIcon.png") : Art.agentIcon($0) })
                }
                if agent == "Fovea" {
                    RowDivider()
                    SettingsRow("Model", detail: "Fovea's own answers use the model your plan includes.")
                } else {
                    RowDivider()
                    SettingsRow("Model for new questions", detail: "A chat keeps the model it started with.") {
                        InlinePicker(options: QuestionModels.options(for: agent),
                                     selection: Binding(get: { QuestionModels.options(for: agent).contains(model.prefs.questionModel) ? model.prefs.questionModel : "Auto" },
                                                        set: { model.prefs.questionModel = $0 }),
                                     label: { $0 })
                    }
                    RowDivider()
                    SettingsRow("Thinking", detail: "More thinking answers harder questions, more slowly.") {
                        InlinePicker(options: Effort.allCases, selection: $model.prefs.questionEffort, label: \.title)
                    }
                }
                RowDivider()
                SettingsRow("Rounds an answer shows", detail: "Earlier rounds stay; scroll up to see them.") {
                    InlinePicker(options: [1, 3, 5, 10], selection: $model.prefs.rounds, label: { "\($0)" })
                }
            }
        }
        SettingsSection("What a question can include", note: "What you pick always goes with your question. The rest is yours to allow.") {
            SettingsCard {
                SettingsRow("What you pick", detail: "Text you select, the regions and files you take.") {
                    StatusLabel(word: "Always")
                }
                RowDivider()
                SettingsRow("The window you're in", detail: "Its title, its web address, or the file it shows.") {
                    InkToggle(title: "The window you're in", isOn: $model.prefs.includeWindow.animation(model.motion.animation(.swap)))
                }
                if model.prefs.includeWindow {
                    VStack(spacing: 0) {
                        RowDivider()
                        SettingsRow("A picture of that window", detail: "Only when you haven't taken one yourself.") {
                            InkToggle(title: "A picture of that window", isOn: $model.prefs.includeWindowPicture)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}

// MARK: - The window's errors (row 13, 1–3)

/// When the window can't open its data: what happened, what to do, Open Diagnostics and Relaunch
/// Fovea, in the middle of the window and nothing else (the Mac app's, kept).
struct WindowErrorView: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let error: WindowError

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30)).foregroundStyle(palette.warning)
            Text(error.title).font(.system(size: 17, weight: .semibold)).foregroundStyle(palette.text)
            Text(error.message)
                .font(.system(size: 13)).foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Open Diagnostics") { model.say("Would open the diagnostics folder (simulated)") }
                Button("Relaunch Fovea") { model.say("Would relaunch Fovea (simulated)") }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }
}

// MARK: - The States menu (row 13)

/// What History, Memory and the Dictionary show, picked on the States menu so each of the review's
/// fifteen states can be seen without staging it.
enum HistoryDemo: String, CaseIterable, Hashable {
    case typical, empty, noResults
    var title: String {
        switch self {
        case .typical: return "A Year of Use"
        case .empty: return "No Captures Yet"
        case .noResults: return "A Search with No Results"
        }
    }
    /// A search nothing in the fixtures matches.
    static let noMatch = "zeppelin"
}

enum MemoryDemo: String, CaseIterable, Hashable {
    case loaded, loading, failed, empty
    var title: String {
        switch self {
        case .loaded: return "Loaded"
        case .loading: return "Loading"
        case .failed: return "Couldn't Load"
        case .empty: return "No Memories Yet"
        }
    }
}

enum DictionaryDemo: String, CaseIterable, Hashable {
    case words, empty, signedOut
    var title: String {
        switch self {
        case .words: return "Words"
        case .empty: return "No Words Yet"
        case .signedOut: return "Signed Out"
        }
    }
}

/// What the States menu cleared, to put back.
@MainActor final class DemoStash {
    static var memories: (memories: [Memory], areas: [MemoryArea])?
    static var dictionary: [DictionaryWord]?
}

extension CapturesModel {
    var historyDemo: HistoryDemo {
        if library.captures.isEmpty { return .empty }
        return query.text == HistoryDemo.noMatch ? .noResults : .typical
    }

    func setHistory(_ demo: HistoryDemo) {
        windowError = nil
        show(.captures)
        switch demo {
        case .typical:
            if library.captures.isEmpty { load(.typical) }
            query.text = ""
        case .empty:
            load(.empty)
            query.text = ""
        case .noResults:
            if library.captures.isEmpty { load(.typical) }
            query.text = HistoryDemo.noMatch
        }
    }

    var memoryDemo: MemoryDemo {
        if DemoStash.memories != nil { return .empty }
        switch memoryState {
        case .loaded: return .loaded
        case .loading: return .loading
        case .failed: return .failed
        }
    }

    func setMemory(_ demo: MemoryDemo) {
        windowError = nil
        if let stash = DemoStash.memories, demo != .empty {
            library.memories = stash.memories
            library.areas = stash.areas
            DemoStash.memories = nil
        }
        switch demo {
        case .loaded: memoryState = .loaded
        case .loading: memoryState = .loading
        case .failed: memoryState = .failed
        case .empty:
            memoryState = .loaded
            if DemoStash.memories == nil { DemoStash.memories = (library.memories, library.areas) }
            library.memories = []
            library.areas = []
        }
        openSettings(.memory)
    }

    var dictionaryDemo: DictionaryDemo {
        if signedOut { return .signedOut }
        return DemoStash.dictionary != nil ? .empty : .words
    }

    func setDictionary(_ demo: DictionaryDemo) {
        windowError = nil
        if let stash = DemoStash.dictionary, demo != .empty {
            library.dictionary = stash
            DemoStash.dictionary = nil
        }
        signedOut = demo == .signedOut
        if demo == .empty {
            if DemoStash.dictionary == nil { DemoStash.dictionary = library.dictionary }
            library.dictionary = []
        }
        openSettings(.memory)
    }

    func setPlanAlert(_ alert: PlanAlert?) {
        windowError = nil
        animate(.swap) {
            planAlert = alert
            // A payment in flight is for Pro, from Free.
            if alert == .paymentProcessing { plan = .free; nextPlan = nil }
        }
        openSettings(.plan)
    }

    func setUpdate(_ state: UpdateState) {
        windowError = nil
        animate(.swap) { update = state }
        openSettings(.account)
    }

    func setWindowError(_ error: WindowError?) {
        animate(.swap) { windowError = error }
    }

    /// The photo-too-large line, where it shows: under your name in Account.
    func demoPhotoTooLarge() {
        windowError = nil
        openSettings(.account)
        showPhotoTooLarge()
    }
}

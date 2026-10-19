import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CapturesCore
import FoveaKit

// Settings from the App UI review (Oct 6), built on the panes as they were: the Language tab
// (row 6), your photo and name (row 8), Report a Problem (row 9), the links and the privacy the
// Mac app has (row 10), the plan's and the updates' states (row 13), how Fovea writes up what you
// said (row 15), the dictionary at its real size (rows 18–19), the questions' model and what they
// may include (rows 21–22), Memory as areas of your life over a searchable record (row 24), and
// places Fovea takes nothing from (row 25). The copy follows the Mac app's where it has one.

// MARK: - Values

typealias AppLanguage = FoveaLanguage

enum UpdateState: Equatable, Hashable {
    case upToDate, checking, failed, available(String)
    /// Oct 15 review, ST-10.2: Install and Relaunch, downloading the version, 0…1.
    case installing(String, Double)
    var title: String {
        switch self {
        case .upToDate: return "Up to Date"
        case .checking: return "Checking"
        case .failed: return "Check Failed"
        case .available: return "Update Available"
        case .installing: return "Installing"
        }
    }
}

enum PlanAlert: String, CaseIterable, Hashable {
    case almostOut, usedUp, paymentProcessing
    // Oct 15 review, AC-02.1, AC-02.2 and MW-04d: the trial, its end, a subscription ending or
    // expired, a payment that failed, and the billing page that wouldn't open (all simulated).
    case trial, trialEnded, subscriptionEnding, expired, paymentFailed, billingUnavailable
    var title: String {
        switch self {
        case .almostOut: return "Almost Out (93%)"
        case .usedUp: return "Used Up"
        case .paymentProcessing: return "Payment Processing"
        case .trial: return "Pro Trial"
        case .trialEnded: return "Trial Ended"
        case .subscriptionEnding: return "Subscription Ending"
        case .expired: return "Subscription Expired"
        case .paymentFailed: return "Payment Failed"
        case .billingUnavailable: return "Billing Page Didn't Open"
        }
    }
}

/// When the window can't open its data (row 13, 1–3). Oct 15 review, MW-02b: the four kinds the
/// dev team found, each saying what it means; Open Diagnostics and Relaunch Fovea are real, and
/// Try Again is offered where trying again can help (`LocalDataErrorView`, HomeStates.swift).
enum WindowError: String, CaseIterable, Hashable {
    case uncleanQuit, slowClose, migration, diskFull
    var menuTitle: String {
        switch self {
        case .uncleanQuit: return "Didn't Quit Properly"
        case .slowClose: return "Took Too Long to Close"
        case .migration: return "Couldn't Update Data"
        case .diskFull: return "Disk Full"
        }
    }
    /// Oct 18, Ryan: the window's error page, in the primary language.
    var title: String {
        switch self {
        case .uncleanQuit: return L("Fovea didn't quit properly last time")
        case .slowClose: return L("Fovea took too long to close")
        case .migration: return L("Couldn't update your data")
        case .diskFull: return L("Your Mac's disk is full")
        }
    }
    var message: String {
        switch self {
        case .uncleanQuit:
            return L("It stopped before it could finish saving. Your captures up to then are safe. Relaunch Fovea to check them and carry on.")
        case .slowClose:
            return L("macOS stopped it while it was still saving, so the last few seconds before you quit may be missing. Relaunch Fovea to open your captures.")
        case .migration:
            return L("This version keeps your captures in a new way, and moving them over stopped part way. Your old history hasn't been touched.")
        case .diskFull:
            return L("Fovea needs a little free space to open your captures. Free up some space, then try again. Nothing has been lost.")
        }
    }
    /// Trying again can help: the move can run again, and space may have been freed.
    var canRetry: Bool { self == .migration || self == .diskFull }
    /// The SF Symbol over the title.
    var symbol: String {
        switch self {
        case .uncleanQuit, .slowClose: return "exclamationmark.triangle.fill"
        case .migration: return "arrow.triangle.2.circlepath"
        case .diskFull: return "internaldrive.fill"
        }
    }
}

enum LoadState: String, CaseIterable, Hashable { case loaded, loading, failed }

enum Effort: String, CaseIterable, Hashable {
    case auto, low, medium, high, max
    /// Oct 18, Ryan: in the primary language. "Max" is also a plan's name, so its own key here.
    var title: String {
        switch self {
        case .auto: return L("Auto")
        case .low: return L("Low")
        case .medium: return L("Medium")
        case .high: return L("High")
        case .max: return L("Max (thinking)", english: "Max")
        }
    }
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
        panel.title = L("Choose a Profile Photo")
        panel.allowedContentTypes = [.jpeg, .png, .gif, .webP]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if size > 2 * 1024 * 1024 {
            showPhotoTooLarge()
        } else if let image = NSImage(contentsOf: url) {
            animate(.swap) { profilePhoto = image; photoTooLarge = false }
            say(L("Photo changed"))
        }
    }

    func showPhotoTooLarge() {
        animate(.swap) { photoTooLarge = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            self.animate(.swap) { self.photoTooLarge = false }
        }
    }

    /// Check for Updates (row 13, 8–9; Oct 15 review, ST-10.1): checking, then up to date.
    /// Simulated: 1.0 has no update server, so it's always the newest; a review stage shows an
    /// update to install, and a check that failed.
    func checkForUpdates() {
        animate(.swap) { update = .checking }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(self.motion.seconds(T.Simulated.updateCheck)))
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
        // Oct 18, Ryan: in the primary language, one sentence for one and for several.
        say(ids.count == 1 ? L("Deleted a memory") : L("Deleted \(ids.count) memories"), undo: true)
    }

    func restoreMemories(_ ids: Set<String>) {
        animate(.swap) {
            for i in library.memories.indices where ids.contains(library.memories[i].id) { library.memories[i].deleted = nil }
            memorySelection = []
        }
        say(ids.count == 1 ? L("Restored a memory") : L("Restored \(ids.count) memories"))
    }

    func setHidden(_ ids: Set<String>, _ hidden: Bool) {
        animate(.swap) {
            for i in library.memories.indices where ids.contains(library.memories[i].id) { library.memories[i].hidden = hidden }
        }
        say(hidden ? L("Hidden from agents") : L("Agents can see it again"))
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
        say(L("Forgot “\(area.title)”. What it came from stays in your memories."))
    }

    func updateArea(_ id: String, summary: String) {
        guard let i = library.areas.firstIndex(where: { $0.id == id }) else { return }
        animate(.swap) { library.areas[i].summary = summary; library.areas[i].updated = now }
        say(L("Saved. Fovea writes from your version now."))
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
        return name.isEmpty ? "F" : String(name.prefix(1)).uppercased()
    }

    /// A sheet is over the window: its toast shows in the sheet instead, where it can be clicked.
    var sheetUp: Bool { browsingMemories || accessLogShown || reporting }
}

// MARK: - Language (row 6; Oct 18)

/// Oct 18, Ryan: "Choose your languages", as the first run asks it: English and Chinese, each on or
/// off (one at least), and any other asked for; with both on, the primary one. The primary is the
/// language of Fovea's menus, Settings, Home and the notch, and the one speech recognition starts
/// in ("If they choose Chinese as primary, the entire interface will be in Chinese"). One choice,
/// so the separate pickers for Fovea's words, the notch's and the speech are gone.
struct LanguagePane: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let chosen = model.prefs.languages
        SettingsSection("Your languages", note: "Fovea listens in the languages you choose.") {
            SettingsCard {
                ForEach(Array(FoveaLanguage.featured.enumerated()), id: \.element) { i, language in
                    if i > 0 { RowDivider() }
                    // A language in its own name, always (English stays English in Chinese).
                    SettingsRow(verbatim: language.nativeName, detail: Self.otherName(language)) {
                        InkToggle(title: language.nativeName, isOn: Binding(get: { chosen.contains(language) },
                                                                             set: { model.setLanguage(language, on: $0) }))
                            // One language at least: the last one on can't be turned off.
                            .disabled(chosen == [language])
                    }
                }
                RowDivider()
                RequestedLanguagesRow()
            }
        }
        .id("language-chosen")

        if chosen.count > 1 {
            SettingsSection("Primary language") {
                SettingsCard {
                    SettingsRow("Primary language",
                                detail: "Fovea's menus, Settings and the notch use it, and speech recognition starts in it.") {
                        SettingsSegments(segments: chosen.map { ($0, $0.nativeName) }, selection: model.prefs.appLanguage) { language in
                            model.setPrimaryLanguage(language)
                        }
                    }
                }
            }
            .id("language-primary")
            .transition(.opacity)
        }
    }

    /// A language's name in the interface's own language, under its own: "Chinese" under 简体中文
    /// in English, “英语” under English in Chinese; nothing when they're the same.
    static func otherName(_ language: FoveaLanguage) -> String? {
        switch (language, FoveaLocale.shared.language) {
        case (.english, .chinese): return L("English (the language)")
        case (.chinese, .english): return L("Simplified Chinese")
        default: return nil
        }
    }
}

extension CapturesModel {
    /// A language on or off (Oct 18): one stays on at least; the primary moves to the one that's
    /// left when it's turned off.
    func setLanguage(_ language: FoveaLanguage, on: Bool) {
        var chosen = prefs.languages
        if on, !chosen.contains(language) { chosen.append(language) }
        if !on { chosen.removeAll { $0 == language } }
        guard !chosen.isEmpty else { return }
        let order = FoveaLanguage.featured
        chosen.sort { (order.firstIndex(of: $0) ?? 9) < (order.firstIndex(of: $1) ?? 9) }
        animate(.swap) {
            prefs.languages = chosen
            if !chosen.contains(prefs.appLanguage) { prefs.appLanguage = chosen[0] }
        }
    }

    /// The primary language: the interface follows it at once (the App sets FoveaLocale from it).
    func setPrimaryLanguage(_ language: FoveaLanguage) {
        guard prefs.languages.contains(language) else { return }
        prefs.appLanguage = language
    }
}

/// Oct 17, Ryan (FR-06): the languages asked for, as the first run's More… keeps them
/// (FoveaPrefs.requestedLanguages): more than one. Return adds the language typed as a chip and
/// clears the box for another; a chip's ✕ takes it off; empty, repeated ones and the two Fovea
/// listens in already are passed over (OnboardingCore's LanguageRequests, which this module can't
/// see, keeps the same rule).
private struct RequestedLanguagesRow: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.settingsNative) private var native
    @State private var draft = ""

    var body: some View {
        let requested = model.prefs.requestedLanguages
        VStack(alignment: .leading, spacing: 0) {
            SettingsRow("Other languages", detail: "We'll add it soon. Fovea listens in English or Chinese for now.") {
                TextField("Type a language, then press Return", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
                    .onSubmit(add)
            }
            if !requested.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(requested, id: \.self) { language in chip(language) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, native ? T.Native.rowInset : 16)
                .padding(.bottom, 12)
                .transition(.opacity)
            }
        }
    }

    private func add() {
        let name = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        let lower = name.lowercased()
        let offered = FoveaLanguage.featured.flatMap { [$0.title.lowercased(), $0.nativeName.lowercased()] }
        guard !name.isEmpty, !offered.contains(lower),
              !model.prefs.requestedLanguages.contains(where: { $0.lowercased() == lower }) else { return }
        model.animate(.swap) { model.prefs.requestedLanguages.append(name) }
    }

    private func chip(_ language: String) -> some View {
        HStack(spacing: 5) {
            Text(language).font(.system(size: 12.5)).foregroundStyle(palette.text)
            Button {
                model.animate(.swap) { model.prefs.requestedLanguages.removeAll { $0 == language } }
            } label: {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(palette.secondary)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(palette.fill))
            }
            .buttonStyle(.plain)
            .help("Remove \(language)")
            .accessibilityLabel("Remove \(language)")
        }
        .padding(.leading, 10).padding(.trailing, 5)
        .frame(height: 24)
        .background(Capsule().fill(palette.ink(T.Shade.fill)))
        .overlay(Capsule().strokeBorder(palette.ink(T.Shade.line), lineWidth: 0.5))
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
/// stays in the header, where it was. Oct 15 review, AC-01.4: signed out, Sign In… takes its
/// place; ST-02.4: a name that couldn't be saved says so under it, with Try Again.
struct ProfileSection: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.settingsNative) private var native
    @State private var confirmSignOut = false
    @State private var hoverPhoto = false

    var body: some View {
        @Bindable var model = model
        SettingsSection("Profile") {
            SettingsCard {
                if model.signedOut {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 46, weight: .ultraLight)).foregroundStyle(palette.tertiary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Not signed in").font(.system(size: 15, weight: .semibold)).foregroundStyle(palette.text)
                            Text("Your captures stay on this Mac. Sign in to dispatch, and to keep your plan.")
                                .font(.system(size: 12)).foregroundStyle(palette.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button("Sign In…") { model.startSignIn() }
                            .buttonStyle(.borderedProminent)
                    }
                    .cardPadding()
                } else {
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
                            Text(model.profileName.isEmpty ? L("Your name") : model.profileName)
                                .font(.system(size: 15, weight: .semibold)).foregroundStyle(palette.text)
                            Text(verbatim: model.profileEmail.isEmpty ? L("Signed in on this Mac") : model.profileEmail).font(.system(size: 12)).foregroundStyle(palette.secondary)
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
                    if model.nameSaveFailed {
                        // Oct 15 review, ST-02.4: inline, where the name is, until it's saved.
                        HStack(spacing: 8) {
                            Circle().fill(palette.danger).frame(width: 6, height: 6)
                            Text("Couldn't save your name.").font(.system(size: 11.5)).foregroundStyle(palette.danger)
                            Spacer()
                            TextButton("Try Again") { model.retrySaveName() }
                        }
                        .padding(.horizontal, native ? T.Native.rowInset : 16)
                        .padding(.bottom, 10)
                        .transition(.opacity)
                    }
                    RowDivider()
                    PhotoRow()
                }
            } footer: {
                if !model.signedOut {
                    Text("Your email comes from how you signed in, so it can't be changed here.")
                }
            }
        }
        .confirmationDialog("Sign out of Fovea?", isPresented: $confirmSignOut) {
            Button("Sign Out", role: .destructive) { model.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your captures stay on this Mac. You'll sign in again to dispatch.")
        }
    }
}

extension CapturesModel {
    /// Signed out: kept in the prefs (FoveaPrefs.signedOut), the email stays on this Mac for
    /// signing in again; Account shows Sign In… until you do.
    func signOut() {
        animate(.swap) { signedOut = true }
        onSignedOut?()
        say(L("Signed out. Your captures stay on this Mac."))
    }

    /// ST-02.4: the name written again.
    func retrySaveName() {
        animate(.swap) { nameSaveFailed = false }
        onPrefsEdited?()
        say(L("Saved your name"))
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

// Oct 15 review, MW-04c and ST-10: Help, the version and its updates, beta updates and the links
// moved to Settings › About (AboutPane.swift).

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
    /// Oct 15 review, MW-04c: sending can fail; the report can then be saved to send later.
    enum Stage: Equatable { case writing, sending, sent(String), failed }

    // Oct 18, Ryan: in the primary language (read each time, so they follow a change of it).
    static var included: [String] { [
        L("App logs from the last 3 days (up to 8 MB, events only)"),
        L("Your Mac's model, macOS version and Fovea's permissions"),
        L("Fovea's version and an anonymous account ID"),
    ] }
    static var never: [String] { [
        L("No recordings, transcripts or requests"),
        L("No clipboard, files or selected text"),
        L("Never your email, tokens or user name"),
    ] }

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
            case .failed:
                // Oct 15 review, MW-04c: nothing is lost; it can go again, or be saved as a file.
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 24)).foregroundStyle(palette.warning)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Couldn't send your report").font(.system(size: 15, weight: .semibold))
                        Text("Check your connection and try again. Or save it, and send it later from hellofovea.com/feedback.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack {
                    Button("Save Report…") { saveReport() }
                    Spacer()
                    Button("Cancel") { model.reporting = false }
                        .keyboardShortcut(.cancelAction)
                    Button("Try Again") { model.reportFails = false; send() }
                        .keyboardShortcut(.defaultAction)
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
        .onAppear {
            if model.reportFails, text.isEmpty { text = Self.sample; stage = .failed }
        }
        .alert("Send diagnostic information?", isPresented: $confirm) {
            Button("Agree & Send") { send() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(L("It helps us find what went wrong on your Mac. It includes:") + "\n"
                 + Self.included.map { "✓ \($0)" }.joined(separator: "\n") + "\n\n"
                 + Self.never.map { "✗ \($0)" }.joined(separator: "\n"))
        }
    }

    private func send() {
        stage = .sending
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(model.motion.seconds(diagnostics ? T.Simulated.report : T.Simulated.report / 2)))
            // Simulated: 1.0 has no server; a review stage makes the send fail.
            stage = model.reportFails ? .failed : .sent("FV-8C2D41A9")
        }
    }

    /// Oct 15 review, MW-04c: the report as a text file, where the person chooses, with the
    /// diagnostics when they agreed to include them.
    private func saveReport() {
        let panel = NSSavePanel()
        panel.title = L("Save Report")
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = L("Fovea Problem Report") + ".txt"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var report = "Fovea problem report\n\nWhat happened:\n\(text.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        if diagnostics {
            report += "\n" + Diagnostics.text(problem: nil, captures: model.library.captures.count, data: model.dataFolder)
        }
        do {
            try report.write(to: url, atomically: true, encoding: .utf8)
            model.reporting = false
            model.say(L("Saved the report to \(url.deletingLastPathComponent().lastPathComponent)"))
        } catch {
            model.reporting = false
            model.saveFailure = SaveFailure(title: L("Couldn't Save the Report"), message: error.localizedDescription)
        }
    }

    /// A report already written, for the review stage that shows a send failing.
    static let sample = "I pressed fn ⌃ in Xcode and the notch didn't open. It worked again after I clicked the menu bar."
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
                    // Oct 15 review, MW-04d: Refresh asks again (simulated: it went through).
                    Button(model.refreshingPayment ? "Checking…" : "Refresh") { model.refreshPayment() }
                        .disabled(model.refreshingPayment)
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
        level.setAccessibilityLabel(L("Credits used"))
        return level
    }

    func updateNSView(_ level: NSLevelIndicator, context: Context) {
        let max = Double(Swift.max(total, 1))
        level.maxValue = max
        level.warningValue = max * 0.7
        level.criticalValue = max * 0.9
        level.doubleValue = Double(Swift.min(used, total))
        level.setAccessibilityValueDescription(L("\(used.formatted()) of \(total.formatted()) credits used"))
    }

    /// As wide as it's given, as tall as the Mac makes it.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSLevelIndicator, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 180, height: nsView.intrinsicContentSize.height)
    }
}

// Oct 15 review: the privacy rules (VoiceCaptureSettings.swift), the dictionary (DictionaryPane.swift),
// Memory, its browser and the access log (MemoryBrowser.swift) are in their own files now.

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

// Oct 15 review, MW-02b: drawn by `LocalDataErrorView` (HomeStates.swift), with the four kinds.

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
        // Oct 15 review, ST-10: updates live in About now.
        openSettings(.about)
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

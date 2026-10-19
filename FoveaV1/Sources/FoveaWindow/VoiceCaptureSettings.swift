import AppKit
import AVFoundation
import Combine
import Speech
import SwiftUI
import CapturesCore
import FoveaKit
import FoveaLook
import FoveaPlatform
import FoveaStore

// Settings › Voice & Capture (Oct 15 review: ST-04.1–ST-04.3, HI-01.5, ST-07.2, ST-07.4). The
// microphones on this Mac, read from the system, "System default" first; "Tidy my words" (on,
// fillers out, capitals and punctuation; off, exactly what you said), kept in the prefs the
// transcriber reads; how long captures stay and how much space they take on this Mac (the real
// size of Fovea's folder); Clear History, after asking, for real; "Never capture in" with apps
// chosen from those open and those installed, websites and words; and the five permissions as this
// Mac has them.

struct VoicePane: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var model = model
        @Bindable var panes = model.panes
        SettingsSection("Voice") {
            SettingsCard {
                MicrophoneRow()
                RowDivider()
                SettingsRow("Play sounds when listening starts and stops") {
                    InkToggle(title: "Play sounds", isOn: $model.prefs.sounds)
                }
            } footer: {
                // The language you speak moved to Language, with Fovea's and the notch's (row 6).
                Text("The language you speak is in Language.")
            }
        }

        // Oct 15 review, ST-04.2/ST-04.3: the transcriber writes up what you said, or leaves it as
        // you said it (FoveaPrefs.tidyWords).
        SettingsSection("Your words") {
            SettingsCard {
                SettingsRow("Tidy my words", detail: model.prefs.tidyWords
                            ? "Fillers out, capitals and punctuation in."
                            : "Exactly what you said, word for word.") {
                    InkToggle(title: "Tidy my words", isOn: $model.prefs.tidyWords.animation(model.motion.animation(.swap)))
                }
                RowDivider()
                TidyExample(tidy: model.prefs.tidyWords)
            }
        }
        .id("words")

        // Screen awareness (Yulun, Oct 7): you choose, and can see, what dictation reads from your
        // screen. Item by item, as What a question can include (row 22).
        SettingsSection("Screen awareness", note: "What Fovea reads from your screen while you dictate. Never the whole screen, unless you take it.") {
            SettingsCard {
                SettingsRow("What you pick", detail: "Text you select, the regions and files you take.") {
                    StatusLabel(word: "Always")
                }
                RowDivider()
                SettingsRow("The window you're speaking into", detail: "Its app, its title, its web address, or the file it shows.") {
                    InkToggle(title: "The window you're speaking into", isOn: $model.prefs.dictationWindow.animation(model.motion.animation(.swap)))
                }
                if model.prefs.dictationWindow {
                    VStack(spacing: 0) {
                        RowDivider()
                        SettingsRow("The text in that window", detail: "A picture of the window, read on this Mac. Only its text goes with your words, to spell names and terms right.") {
                            InkToggle(title: "The text in that window", isOn: $model.prefs.dictationWindowText)
                        }
                    }
                    .transition(.opacity)
                }
            } footer: {
                HStack(spacing: 4) {
                    Text("What a question can include is in Connectors.")
                    Link("What leaves your Mac ↗", destination: FoveaSite.whatLeavesYourMac)
                }
            }
        }
        .id("screen")

        SettingsSection("Capture") {
            SettingsCard {
                SettingsRow("Read the text in what you take", detail: "So you can search the words in a region you took.") {
                    InkToggle(title: "Read the text in what you take", isOn: $model.prefs.readText)
                }
                RowDivider()
                PrivacyRulesCard()
            }
        }
        .id("capture")
        .sheet(isPresented: $panes.choosingApp) {
            AppChooserSheet()
                .environment(model)
                .environment(\.palette, palette)
                .foveaLanguage()
        }

        SettingsSection("History") {
            SettingsCard {
                SettingsRow("Keep captures") {
                    InlinePicker(options: ["24 hours", "1 week", "1 month", "Forever"], selection: $model.prefs.keepCaptures, label: { $0 })
                }
                RowDivider()
                SettingsRow("Keep screenshots", detail: "When a screenshot goes, your words and the text read off it stay.") {
                    InlinePicker(options: ["30 days", "90 days", "180 days", "Forever"], selection: $model.prefs.keepScreenshots, label: { $0 })
                }
                RowDivider()
                StorageRow()
            } footer: {
                Text("Your captures, recordings and screenshots stay on this Mac.")
            }
        }
        .id("history")

        // Oct 15 review, ST-07.4: the five permissions as this Mac has them, read again each second.
        SettingsSection("Permissions", note: "What Fovea needs, and whether this Mac allows it.") {
            SettingsCard {
                PermissionRows(permissions: [.microphone, .speechRecognition, .screenRecording, .accessibility, .inputMonitoring]) { p in
                    switch p {
                    case .microphone: return "To hear you."
                    case .speechRecognition: return "To turn what you say into words, on this Mac."
                    case .screenRecording:
                        return model.prefs.dictationWindow && model.prefs.dictationWindowText
                            ? "To take regions and the whole screen, and to read the window you're speaking into."
                            : "To take regions and the whole screen."
                    case .accessibility: return "Fovea's keys in any app, typing your words where you are, reading what you highlight."
                    case .inputMonitoring: return "The shortcuts, heard in every app."
                    }
                }
            }
        }
        .id("permissions")

        let n = model.library.captures.count
        DangerCard(title: "Clear history",
                   consequence: n == 0 ? L("There are no captures on this Mac.")
                                       : L("Deletes all \(n.formatted()) captures and their screenshots from this Mac. This can't be undone."),
                   button: "Clear History…") { panes.confirmClear = true }
            .disabled(n == 0)
            // The Mac's own alert, as the window's other confirmations (Saving.swift).
            .alert("Delete all \(n.formatted()) captures?", isPresented: $panes.confirmClear) {
                Button("Delete \(n.formatted()) Captures", role: .destructive) { model.clearHistory() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Every capture, its screenshots and its words leave this Mac. This can't be undone.")
            }
    }

    /// An app's icon by its name, for the few the rules start with (and any rule kept without its
    /// bundle id).
    static func icon(_ name: String) -> NSImage? {
        let ids = ["1Password": "com.1password.1password", "Keychain Access": "com.apple.keychainaccess",
                   "Messages": "com.apple.MobileSMS", "Mail": "com.apple.mail"]
        guard let id = ids[name] else { return NSWorkspace.shared.icon(for: .application) }
        return Art.icon(AppRef(name, id))
    }
}

/// The microphone: a small level meter and the devices on this Mac, the system's default first.
/// A chosen one that's gone says so and the default stands in.
private struct MicrophoneRow: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let p = model.panes
        let missing = p.microphoneID != nil && !p.microphones.contains { $0.id == p.microphoneID }
        let options = [""] + p.microphones.map(\.id)
        let name = p.microphoneName ?? L("That microphone")
        SettingsRow("Microphone", detail: missing ? L("\(name) isn't connected. Fovea uses the system default until it is.") : nil) {
            HStack(spacing: 10) {
                LevelMeter()
                InlinePicker(options: options,
                             selection: Binding(get: { missing ? "" : (p.microphoneID ?? "") },
                                                set: { id in
                                                    p.microphoneID = id.isEmpty ? nil : id
                                                    p.microphoneName = p.microphones.first { $0.id == id }?.name
                                                }),
                             label: { id in
                                 id.isEmpty ? (p.systemMicrophone.map { L("System default (\($0))") } ?? L("System default"))
                                            : (p.microphones.first { $0.id == id }?.name ?? L("Microphone"))
                             })
            }
        }
        .onAppear { p.readMicrophones() }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasConnectedNotification)) { _ in p.readMicrophones() }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasDisconnectedNotification)) { _ in p.readMicrophones() }
    }
}

/// A small input meter, moving as a microphone would (simulated; still under Reduce Motion).
private struct LevelMeter: View {
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08, paused: motion.reduce)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    let v = motion.reduce ? 0.3 : 0.25 + 0.75 * abs(sin(t * (2.1 + Double(i) * 0.7) + Double(i)))
                    Capsule().fill(palette.text.opacity(0.55)).frame(width: 2.5, height: 4 + 10 * v)
                }
            }
            .frame(height: 14)
        }
        .accessibilityHidden(true)
    }
}

/// What you'd say, and what Fovea types, with Tidy my words as it's set: the transcriber's own
/// cleaning (FoveaKit's `TranscriptCleaner`) on an example.
private struct TidyExample: View {
    @Environment(\.palette) private var palette
    let tidy: Bool
    private let said = "um so the build is failing on main again, uh, can you look"

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Oct 18, Ryan: the example in the primary language (the cleaning's English, written
            // out in Chinese as it would come out).
            line("You say", L(key: said), muted: true)
            line("Fovea types", L(key: tidy ? TranscriptCleaner.clean(said) : said), muted: false)
        }
        .cardPadding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(nil, value: tidy)
    }

    private func line(_ label: String, _ text: String, muted: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(L(key: label)).font(.system(size: 11)).foregroundStyle(palette.secondary).frame(width: 72, alignment: .leading)
            Text(text).font(.system(size: 12.5)).foregroundStyle(muted ? palette.secondary : palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// What captures take on this Mac: Fovea's captures file and the pictures kept with them, measured,
/// with the folder one click away (HI-01.5).
private struct StorageRow: View {
    @Environment(CapturesModel.self) private var model

    var body: some View {
        let p = model.panes
        let n = model.library.captures.count
        let size = p.captureBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
        let count = n.formatted()
        SettingsRow("On this Mac", detail: size.map { n == 1 ? L("\($0) for 1 capture and its pictures.") : L("\($0) for \(count) captures and their pictures.") }
                                       ?? L("Measuring…")) {
            if let folder = model.foveaFolder {
                TextButton("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([folder]) }
            }
        }
        .task(id: n) { p.captureBytes = await CaptureStorage.size(folder: model.foveaFolder, media: model.media) }
    }
}

/// Fovea's folder and what captures take in it.
enum CaptureStorage {
    /// The captures file and the pictures, as the disk counts them, off the main thread.
    static func size(folder: URL?, media: MediaStore?) async -> Int64 {
        guard let folder else { return 0 }
        let urls = [folder.appendingPathComponent("captures.json"), media?.directory ?? folder.appendingPathComponent("media")]
        return await Task.detached(priority: .utility) {
            var total: Int64 = 0
            let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]
            func add(_ url: URL) {
                if let v = try? url.resourceValues(forKeys: Set(keys)), v.isRegularFile == true {
                    total += Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
                }
            }
            for url in urls {
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
                if isDir.boolValue {
                    let items = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys)
                    while let item = items?.nextObject() as? URL { add(item) }
                } else {
                    add(url)
                }
            }
            return total
        }.value
    }
}

extension CapturesModel {
    /// Clear History, for real: every capture and the pictures kept with it leave this Mac (the
    /// controller writes the empty history to the store).
    func clearHistory() {
        let n = library.captures.count
        if let media {
            for capture in library.captures {
                for a in capture.attachments {
                    if let url = media.url(for: a.art) { try? FileManager.default.removeItem(at: url) }
                }
            }
        }
        if detailID != nil { closeDetail() }
        animate(.swap) { library.captures = [] }
        say(n == 1 ? L("Deleted 1 capture") : L("Deleted \(n.formatted()) captures"))
    }
}

// MARK: - Permissions (ST-07.4)

/// Permissions as this Mac has them, read again each second while shown (a grant in System Settings
/// shows at once): Allowed; Not asked yet, with Allow…; Not allowed, with the way to System Settings.
struct PermissionRows: View {
    @Environment(CapturesModel.self) private var model
    let permissions: [Permission]
    var detail: (Permission) -> String? = { _ in nil }
    @State private var state: [Permission: Standing] = [:]
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum Standing { case allowed, notAsked, denied }

    var body: some View {
        ForEach(Array(permissions.enumerated()), id: \.element) { i, permission in
            if i > 0 { RowDivider() }
            SettingsRow(permission.paneName, detail: detail(permission)) {
                switch model.panes.stagedMissing.contains(permission) ? .denied : (state[permission] ?? Self.standing(permission)) {
                case .allowed:
                    StatusLabel(word: "Allowed")
                case .notAsked:
                    StatusLabel(word: "Not asked yet", ok: false, fix: ("Allow…", { ask(permission) }))
                case .denied:
                    StatusLabel(word: "Not allowed", ok: false, fix: ("Open Privacy Settings…", { permission.openSettings() }))
                }
            }
        }
        .onAppear { refresh() }
        .onReceive(tick) { _ in refresh() }
    }

    private func refresh() {
        for p in permissions { state[p] = Self.standing(p) }
    }

    static func standing(_ p: Permission) -> Standing {
        if p.granted { return .allowed }
        return p.denied ? .denied : .notAsked
    }

    /// macOS's own prompt, where there is one.
    private func ask(_ p: Permission) {
        switch p {
        case .microphone: AVCaptureDevice.requestAccess(for: .audio) { _ in }
        case .speechRecognition: SFSpeechRecognizer.requestAuthorization { _ in }
        case .inputMonitoring: if !Permission.requestInputMonitoring() { p.openSettings() }
        case .accessibility, .screenRecording: p.openSettings()
        }
    }
}

// MARK: - Never capture in (ST-07.2)

/// One place Fovea takes nothing from: an app, a website, or any text with certain words in it.
struct PrivacyRule: Identifiable, Hashable {
    enum Kind: String, CaseIterable, Hashable { case app, website, words }
    var id: String
    var kind: Kind
    var value: String
    var on = true
    /// An app's bundle id, for its icon and to know it when it's in front.
    var bundleID: String?

    var label: String {
        switch kind {
        case .app: return value
        case .website: return L("Websites with “\(value)”")
        case .words: return L("Anything with “\(value)”")
        }
    }

    static let defaults: [PrivacyRule] = [
        PrivacyRule(id: "r-1password", kind: .app, value: "1Password", bundleID: "com.1password.1password"),
        PrivacyRule(id: "r-keychain", kind: .app, value: "Keychain Access", bundleID: "com.apple.keychainaccess"),
        PrivacyRule(id: "r-bank", kind: .website, value: "bank"),
        PrivacyRule(id: "r-code", kind: .words, value: "验证码"),
    ]
}

/// Places Fovea takes nothing from (row 25): apps (chosen from this Mac's, Oct 15) and websites
/// (nothing taken, nothing heard while they're in front), and words (anything containing them
/// stays out of your history and memory). Each can be paused.
struct PrivacyRulesCard: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var adding: PrivacyRule.Kind?
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
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
                        TextField(kind == .website ? L("Part of a web address, e.g. bank") : L("Words, e.g. 验证码"), text: $text)
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
                Button("App…") { model.panes.choosingApp = true }
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
            let image = rule.bundleID.map { Art.icon(AppRef(rule.value, $0)) } ?? VoicePane.icon(rule.value) ?? NSWorkspace.shared.icon(for: .application)
            Image(nsImage: image).resizable().frame(width: 18, height: 18)
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

/// An app on this Mac, to choose for "Never capture in".
struct AppChoice: Identifiable, Hashable {
    var id: String { bundleID }
    let bundleID: String
    let name: String
    let url: URL
}

enum AppCatalog {
    /// The apps open now, by name.
    @MainActor static func running() -> [AppChoice] {
        let me = Bundle.main.bundleIdentifier
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications.compactMap { app -> AppChoice? in
            guard app.activationPolicy == .regular, let id = app.bundleIdentifier, id != me, let url = app.bundleURL,
                  seen.insert(id).inserted else { return nil }
            return AppChoice(bundleID: id, name: app.localizedName ?? url.deletingPathExtension().lastPathComponent, url: url)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// The apps in the Applications folders, read off the main thread.
    static func installed() async -> [AppChoice] {
        await Task.detached(priority: .userInitiated) {
            let files = FileManager.default
            let home = files.homeDirectoryForCurrentUser.path
            let dirs = ["/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities", "\(home)/Applications"]
            var seen = Set<String>()
            var out: [AppChoice] = []
            for dir in dirs {
                for item in (try? files.contentsOfDirectory(atPath: dir)) ?? [] where item.hasSuffix(".app") {
                    let url = URL(fileURLWithPath: dir).appendingPathComponent(item)
                    guard let id = Bundle(url: url)?.bundleIdentifier, seen.insert(id).inserted else { continue }
                    out.append(AppChoice(bundleID: id, name: files.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""), url: url))
                }
            }
            return out.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }.value
    }
}

/// Choose an app: the ones open now first, then every one on this Mac, searched by name; Other…
/// for one somewhere else (ST-07.2).
struct AppChooserSheet: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var search = ""
    @State private var running: [AppChoice] = []
    @State private var installed: [AppChoice] = []
    @State private var selection: AppChoice.ID?

    var body: some View {
        let taken = Set(model.prefs.privacyRules.compactMap(\.bundleID))
        let q = search.lowercased()
        let open = running.filter { !taken.contains($0.bundleID) && (q.isEmpty || $0.name.lowercased().contains(q)) }
        let openIDs = Set(open.map(\.bundleID))
        let rest = installed.filter { !taken.contains($0.bundleID) && !openIDs.contains($0.bundleID) && (q.isEmpty || $0.name.lowercased().contains(q)) }
        VStack(alignment: .leading, spacing: 12) {
            Text("Never Capture In an App").font(.system(size: 15, weight: .semibold))
            Text("Fovea takes nothing, and doesn't listen, while it's in front.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            SearchField(prompt: "Search apps", text: $search)
            List(selection: $selection) {
                if !open.isEmpty {
                    Section("Open now") { ForEach(open) { row($0) } }
                }
                Section("On this Mac") {
                    if installed.isEmpty {
                        HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Looking…").foregroundStyle(.secondary) }
                    } else {
                        ForEach(rest) { row($0) }
                    }
                }
            }
            .listStyle(.inset)
            .contextMenu(forSelectionType: AppChoice.ID.self, menu: { _ in }) { ids in
                if let id = ids.first, let app = (running + installed).first(where: { $0.id == id }) { add(app) }
            }
            .frame(height: 300)
            HStack {
                Button("Other…", action: other)
                Spacer()
                Button("Cancel") { model.panes.choosingApp = false }.keyboardShortcut(.cancelAction)
                Button("Add") {
                    if let app = (running + installed).first(where: { $0.id == selection }) { add(app) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selection == nil)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear { running = AppCatalog.running() }
        .task { installed = await AppCatalog.installed() }
    }

    private func row(_ app: AppChoice) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path)).resizable().frame(width: 20, height: 20)
            Text(app.name)
        }
        .tag(app.id)
    }

    private func add(_ app: AppChoice) {
        model.animate(.swap) {
            model.prefs.privacyRules.append(PrivacyRule(id: "r-\(UUID().uuidString.prefix(6))", kind: .app, value: app.name, bundleID: app.bundleID))
        }
        model.panes.choosingApp = false
    }

    private func other() {
        let panel = NSOpenPanel()
        panel.title = "Choose an App"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier else { return }
        add(AppChoice(bundleID: id, name: FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""), url: url))
    }
}

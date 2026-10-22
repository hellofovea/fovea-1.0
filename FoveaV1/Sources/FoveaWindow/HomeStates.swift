import AppKit
import SwiftUI
import CapturesCore
import FoveaKit
import FoveaLook
import FoveaPlatform

// Oct 15 review: what Home shows besides its cards. A session being restored (MW-02a), the four
// ways the window can't open its data (MW-02b), the captures loading or failing to (HI-01.6), the
// empty Home with your two keys (MW-05.1), and "What Fovea remembers", once (OB-02). Each is a
// review stage (ReviewStages.swift).

// MARK: - Actions

extension CapturesModel {
    /// Oct 15 review, HI-01.3: the session, reopened at the notch (the notch builds it, with its
    /// restoring, unavailable and read-only states).
    func openInNotch(_ id: String) {
        // Oct 18, Ryan: the toasts in the primary language.
        if let open = onOpenInNotch { open(id) } else { say(L("Would open this session at the notch")) }
    }

    /// Oct 15 review, QA25: a Dispatch that didn't go, sent again by the notch. A review stage's
    /// capture isn't the notch's to send: it goes here, simulated.
    func sendAgain(_ id: String) {
        guard let i = library.captures.firstIndex(where: { $0.id == id }) else { return }
        if stagedIDs.contains(id) || onSendAgain == nil {
            let agent = library.captures[i].destination?.agent ?? L("your agent")
            animate(.layout) { library.captures[i].sendFailure = nil }
            say(L("Sent again to \(agent)"))
        } else {
            onSendAgain?(id)
        }
    }

    /// Oct 15 review, MW-02a: the session restored, then Home (simulated: 1.0 keeps the account on
    /// this Mac, so it's always there; a stage shows the wait and the failure).
    func restoreSession() {
        animate(.fadeIn) { session = .restoring }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(self.motion.seconds(T.Simulated.restore)))
            guard self.session == .restoring else { return }
            self.animate(.fadeIn) { self.session = .ready }
        }
    }

    /// Oct 15 review, HI-01.6: the captures read again (they're already in memory: simulated wait).
    func loadCaptures() {
        animate(.fadeIn) { capturesLoad = .loading }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(self.motion.seconds(T.Simulated.loadCaptures)))
            guard self.capturesLoad == .loading else { return }
            self.animate(.fadeIn) { self.capturesLoad = .loaded }
        }
    }

    /// Oct 15 review, MW-02b: a diagnostics file written for real, in ~/Library/Logs/Fovea, and
    /// shown in Finder. What's in it is listed at its top; never your words or what you took.
    func openDiagnostics(_ problem: WindowError?) {
        do {
            let url = try Diagnostics.write(problem: problem?.title, captures: library.captures.count, data: dataFolder)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            saveFailure = SaveFailure(title: L("Couldn't Write the Diagnostics"), message: error.localizedDescription)
        }
    }

    /// Oct 15 review, MW-02b: Try Again. The disk is asked for real how much room it has; the move
    /// to the new format runs again (simulated).
    func retry(_ problem: WindowError) {
        switch problem {
        case .diskFull:
            let free = Diagnostics.freeSpace() ?? 0
            if free >= Diagnostics.neededSpace {
                animate(.fadeIn) { windowError = nil }
            } else {
                say(L("Still not enough room: \(ByteCountFormatter.string(fromByteCount: free, countStyle: .file)) free"))
            }
        case .migration:
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(self.motion.seconds(T.Simulated.migrationRetry)))
                self.animate(.fadeIn) { self.windowError = nil }
            }
        case .uncleanQuit, .slowClose:
            animate(.fadeIn) { windowError = nil }
        }
    }

    /// A review stage's captures: shown in Home like any other, never written to the store.
    func stage(_ captures: [Capture]) {
        stagedIDs.formUnion(captures.map(\.id))
        let ids = Set(captures.map(\.id))
        var all = library.captures.filter { !ids.contains($0.id) }
        all.append(contentsOf: captures)
        library.captures = all.sorted { $0.time > $1.time }
    }

    /// Every review stage's capture gone again.
    func unstage() {
        let ids = stagedIDs
        guard !ids.isEmpty else { return }
        if let d = detailID, ids.contains(d) { closeDetail(animated: false) }
        library.captures.removeAll { ids.contains($0.id) }
        stagedIDs = []
        retryScheduled.subtract(ids)
        transcribing.subtract(ids)
    }

    /// OB-02: read, so it doesn't show again.
    func memoryDisclosureDone() {
        memoryDisclosureShown = false
        onMemoryDisclosureRead?()
    }
}

// MARK: - Diagnostics

/// Oct 15 review, MW-02b: what Open Diagnostics writes. A plain text file a person can read
/// before sending it: Fovea's version, the Mac, the permissions, the free space, how many
/// captures, and the problem. Never words, pictures, files or the email.
enum Diagnostics {
    /// What Fovea needs free to open its captures (the disk-full check).
    static let neededSpace: Int64 = 200 * 1024 * 1024

    static var folder: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Logs/Fovea", isDirectory: true)
    }

    @MainActor static func write(problem: String?, captures: Int, data: URL?) throws -> URL {
        let files = FileManager.default
        try files.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let url = folder.appendingPathComponent("Fovea Diagnostics \(stamp.string(from: Date())).txt")
        try text(problem: problem, captures: captures, data: data).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// The diagnostics, as text (also what a saved report carries, MW-04c).
    @MainActor static func text(problem: String?, captures: Int, data: URL?) -> String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "development"
        var lines = [
            "Fovea diagnostics",
            "Written \(Date().formatted(date: .long, time: .standard))",
            "",
            "This file has no words you said, nothing you took, no files and no email.",
            "",
            "Problem: \(problem ?? "none reported")",
            "Fovea: \(version) (\(build))",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Mac: \(model)",
            "Memory: \(ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory))",
            "Free space: \(freeSpace().map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "unknown")",
            "Captures: \(captures)",
            "Data folder: \(data?.path ?? "~/Library/Application Support/app.fovea")",
            "",
            "Permissions:",
        ]
        for p in Permission.allCases {
            lines.append("  \(p.paneName): \(p.granted ? "allowed" : (p.denied ? "not allowed" : "not asked yet"))")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Fovea's version and build, as About shows them.
    static var version: (short: String, build: String?) {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleShortVersionString"] as? String ?? "1.0", info?["CFBundleVersion"] as? String)
    }

    /// The space free for what matters, on the disk Fovea keeps its data on.
    static func freeSpace() -> Int64? {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    /// The Mac's model identifier ("Mac15,12").
    private static var model: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "unknown" }
        var bytes = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &bytes, &size, nil, 0)
        return String(cString: bytes)
    }
}

// MARK: - Views

/// Oct 15 review, MW-02a: while the session is restored, the page holds only this, never the
/// captures of whoever was signed in before or "No Captures Yet"; if it can't be, it says so.
struct SessionView: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 10) {
            if model.session == .failed {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 30)).foregroundStyle(palette.secondary)
                Text("Couldn't restore your session").font(.system(size: 17, weight: .semibold)).foregroundStyle(palette.text)
                Text("Fovea couldn't tell who's signed in, so your captures stay hidden for now. Try again, or sign in.")
                    .font(.system(size: 13)).foregroundStyle(palette.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button("Sign In…") { model.startSignIn() }
                    Button("Try Again") { model.restoreSession() }
                        .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 8)
            } else {
                ProgressView().controlSize(.regular)
                Text("Restoring your session…").font(.system(size: 13)).foregroundStyle(palette.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }
}

/// Oct 15 review, HI-01.6: the captures loading, or not, in place of the cards.
struct CapturesLoadView: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 8) {
            if model.capturesLoad == .failed {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 20)).foregroundStyle(palette.warning)
                Text("Couldn't load your captures").font(.system(size: 15, weight: .semibold)).foregroundStyle(palette.text)
                Text("Fovea couldn't read your history on this Mac. Nothing has been deleted.")
                    .font(.system(size: 13)).foregroundStyle(palette.secondary)
                Button("Try Again") { model.loadCaptures() }
                    .padding(.top, 6)
            } else {
                ProgressView().controlSize(.small)
                Text("Loading your captures…").font(.system(size: 13)).foregroundStyle(palette.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 140)
    }
}

/// When the window can't open its data (row 13, 1–3; Oct 15 review, MW-02b): what happened, what
/// it means, and what to do, in the middle of the window and nothing else.
struct LocalDataErrorView: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let error: WindowError

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: error.symbol)
                .font(.system(size: 30)).foregroundStyle(palette.warning)
            // Oct 18, Ryan: in the primary language (looked up as written).
            Text(L(key: error.title)).font(.system(size: 17, weight: .semibold)).foregroundStyle(palette.text)
            Text(L(key: error.message))
                .font(.system(size: 13)).foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Open Diagnostics") { model.openDiagnostics(error) }
                    .help("Writes a diagnostics file in ~/Library/Logs/Fovea and shows it in Finder")
                if error.canRetry {
                    Button("Relaunch Fovea") { Relauncher.relaunch() }
                    Button("Try Again") { model.retry(error) }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Relaunch Fovea") { Relauncher.relaunch() }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.top, 8)
            Text("Report a Problem in the Help menu if it keeps happening.")
                .font(.system(size: 11.5)).foregroundStyle(palette.tertiary)
                .padding(.top, 6)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }
}

/// Oct 15 review, MW-05.1: the empty Home names both daily keys, as the person has them now.
struct EmptyKeys: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(FoveaKeys.daily) { shortcut in
                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        ForEach(Array(model.keys(shortcut).enumerated()), id: \.offset) { _, key in KeyCap(key) }
                    }
                    .frame(minWidth: 64, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(shortcut.title).font(.system(size: 13, weight: .medium)).foregroundStyle(palette.secondary)
                        Text(shortcut.id == FoveaKeys.dispatch.id ? "Send what you say and point at to Claude Code or Codex."
                                                                  : "Speak, and Fovea types it where you are.")
                            .font(.system(size: 12)).foregroundStyle(palette.tertiary)
                    }
                }
            }
        }
    }
}

extension CapturesModel {
    /// Home has nothing to show: no captures, or a review stage drawing it empty (MW-05.1).
    var homeEmpty: Bool { library.captures.isEmpty || stagedEmpty }

    /// A shortcut's keys as the person has them now (recorded, or the default).
    func keys(_ shortcut: FoveaShortcut) -> [String] {
        let keys = shortcutKeys[shortcut.id] ?? shortcut.keys
        return keys.isEmpty ? [L("Off")] : keys
    }
}

/// Oct 15 review, OB-02: "What Fovea remembers", once, for someone who finished the tour before
/// the first run said it: what's kept, where, who reads it, and that it's yours. The same four
/// points the first run makes.
struct MemoryDisclosureSheet: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    /// Oct 18, Ryan: in the primary language (made as it's drawn, so a change of language shows).
    static var points: [(symbol: String, title: String, detail: String)] {
        [
            ("brain.head.profile", L("What it keeps"),
             L("Short notes from what you send your agents, and anything you ask it to remember, each with the words it came from.")),
            ("lock.laptopcomputer", L("Where"),
             L("On this Mac, with your captures.")),
            ("person.2", L("Who reads it"),
             L("Fovea, to write your way, and the agents you connect, when they need to know you. Never anyone else.")),
            ("hand.raised", L("It's yours"),
             L("Find, hide from agents or delete any memory in Settings › Memory, or turn remembering off.")),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("What Fovea remembers").font(.system(size: 17, weight: .semibold))
                Text("Fovea now remembers a little about you, so you say less each time. Here's how.")
                    .font(.system(size: 12.5)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Self.points, id: \.title) { point in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: point.symbol)
                            .font(.system(size: 15)).foregroundStyle(palette.accent)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(point.title).font(.system(size: 13, weight: .semibold))
                            Text(point.detail).font(.system(size: 12.5)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            HStack {
                Button("Open Memory Settings") {
                    model.memoryDisclosureDone()
                    model.openSettings(.memory)
                }
                Spacer()
                Button("Done") { model.memoryDisclosureDone() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 440)
    }
}

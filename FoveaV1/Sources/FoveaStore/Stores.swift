import Foundation
import Observation
import FoveaKit
import CapturesCore

// What Fovea keeps on this Mac, in ~/Library/Application Support/app.fovea/ (or `--data-dir=`): JSON
// files written whole and atomically, a moment after the last change. One process holds every
// store, so the island's new capture is Home's at once: they're @Observable, and both surfaces
// read the same instance (the App makes them and hands them out).

/// Where the files live.
public struct DataLocation: Sendable {
    public let root: URL

    public init(root: URL) { self.root = root }

    /// `--data-dir=<path>` for a run of its own (the smoke run, a test), else Application Support.
    public static func resolve(_ args: [String] = CommandLine.arguments) -> DataLocation {
        if let flag = args.first(where: { $0.hasPrefix("--data-dir=") }) {
            let path = (String(flag.dropFirst("--data-dir=".count)) as NSString).expandingTildeInPath
            return DataLocation(root: URL(fileURLWithPath: path, isDirectory: true))
        }
        // A smoke run never touches the person's own data: a folder of its own.
        if args.contains(where: { $0.hasPrefix("--smoke") }) {
            return DataLocation(root: FileManager.default.temporaryDirectory
                .appendingPathComponent("fovea-smoke-\(UUID().uuidString.prefix(8))", isDirectory: true))
        }
        // Its own folder, by bundle id: "Fovea" is another Fovea app's (gaze, logs, namespaces).
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return DataLocation(root: support.appendingPathComponent("app.fovea", isDirectory: true))
    }

    public func file(_ name: String) -> URL { root.appendingPathComponent(name) }
    public var media: URL { root.appendingPathComponent("media", isDirectory: true) }
    public var practice: URL { root.appendingPathComponent("Practice", isDirectory: true) }

    public func prepare() {
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
    }

    /// Everything Fovea kept, gone (`--reset-all`).
    public func eraseAll() {
        try? FileManager.default.removeItem(at: root)
        prepare()
    }
}

/// One JSON file.
public struct FileStore<Value: Codable>: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    public func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Value.self, from: data)
    }

    public func save(_ value: Value) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    public func remove() { try? FileManager.default.removeItem(at: url) }
}

/// Writes a moment after the last change, so a slider's drag is one write.
@MainActor
final class Debouncer {
    private var task: Task<Void, Never>?
    private let delay: Duration

    init(delay: Duration = .milliseconds(300)) { self.delay = delay }

    func schedule(_ work: @escaping @MainActor () -> Void) {
        task?.cancel()
        task = Task { @MainActor [delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            work()
        }
    }

    func flush(_ work: @MainActor () -> Void) {
        task?.cancel()
        task = nil
        work()
    }
}

// MARK: - Prefs

/// What the person chose: the accent, the glow, the notch's glass and panels, the language.
@MainActor
@Observable
public final class PrefsStore {
    public var prefs: FoveaPrefs {
        didSet { if prefs != oldValue { saver.schedule { [weak self] in self?.write() } } }
    }
    @ObservationIgnored private let file: FileStore<FoveaPrefs>?
    @ObservationIgnored private let saver = Debouncer()

    /// `initial` is used when nothing was kept yet (the first run picks the glass from the Mac's
    /// own appearance).
    public init(location: DataLocation?, initial: @autoclosure () -> FoveaPrefs = FoveaPrefs()) {
        file = location.map { FileStore(url: $0.file("prefs.json")) }
        prefs = file?.load() ?? initial()
    }

    /// Writes now (before quitting).
    public func flush() { saver.flush { write() } }

    private func write() { file?.save(prefs) }
}

// MARK: - Captures

/// Every capture you made, newest first, and the pictures you took with them.
@MainActor
@Observable
public final class CaptureLibrary {
    public private(set) var captures: [Capture]
    @ObservationIgnored private let file: FileStore<CaptureFile>?
    @ObservationIgnored public let media: MediaStore?
    @ObservationIgnored private let saver = Debouncer()

    struct CaptureFile: Codable {
        var version = 1
        var captures: [Capture]
    }

    public init(location: DataLocation?) {
        file = location.map { FileStore(url: $0.file("captures.json")) }
        media = location.map { MediaStore(directory: $0.media) }
        captures = (file?.load()?.captures ?? []).sorted { $0.time > $1.time }
    }

    public func add(_ capture: Capture) {
        captures.removeAll { $0.id == capture.id }
        captures.insert(capture, at: 0)
        captures.sort { $0.time > $1.time }
        persist()
    }

    public func update(_ id: String, _ change: (inout Capture) -> Void) {
        guard let i = captures.firstIndex(where: { $0.id == id }) else { return }
        change(&captures[i])
        persist()
    }

    public func remove(_ ids: Set<String>) {
        let gone = captures.filter { ids.contains($0.id) }
        captures.removeAll { ids.contains($0.id) }
        for capture in gone { media?.removeAll(for: capture) }
        persist()
    }

    /// Replaces the whole history (the window's own edits: tags, a deletion, Transcribe Again).
    public func replaceAll(_ captures: [Capture]) {
        self.captures = captures.sorted { $0.time > $1.time }
        persist()
    }

    public func flush() { saver.flush { write() } }

    private func persist() { saver.schedule { [weak self] in self?.write() } }
    private func write() { file?.save(CaptureFile(captures: captures)) }
}

/// The pictures taken with captures, one PNG each, named by their capture. An attachment points at
/// one as `art = "media:<file>"`.
public struct MediaStore: Sendable {
    public let directory: URL
    public static let scheme = "media:"

    public init(directory: URL) { self.directory = directory }

    /// Keeps a picture and returns the attachment's `art` for it.
    public func save(png: Data, capture: String, index: Int) -> String {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "\(capture)-\(index).png"
        try? png.write(to: directory.appendingPathComponent(name), options: .atomic)
        return Self.scheme + name
    }

    /// The file an attachment's `art` names, if it's one of these.
    public func url(for art: String?) -> URL? {
        guard let art, art.hasPrefix(Self.scheme) else { return nil }
        return directory.appendingPathComponent(String(art.dropFirst(Self.scheme.count)))
    }

    func removeAll(for capture: Capture) {
        for a in capture.attachments { if let url = url(for: a.art) { try? FileManager.default.removeItem(at: url) } }
    }
}

// MARK: - The dictionary

/// Your words: the ones you added (or brought in from another dictation app) and the ones Fovea
/// learned. Speech recognition is given them as context.
@MainActor
@Observable
public final class DictionaryStore {
    public private(set) var words: [DictionaryWord]
    @ObservationIgnored private let file: FileStore<[DictionaryWord]>?
    @ObservationIgnored private let saver = Debouncer()

    public init(location: DataLocation?) {
        file = location.map { FileStore(url: $0.file("dictionary.json")) }
        words = file?.load() ?? []
    }

    /// Adds words not already there (by spelling, case aside). Returns how many were new.
    @discardableResult
    public func add(_ new: [(word: String, heardAs: String?)], source: DictionaryWord.Source = .added, date: Date = Date()) -> Int {
        var known = Set(words.map { $0.word.lowercased() })
        var added: [DictionaryWord] = []
        for item in new {
            let w = item.word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !w.isEmpty, !known.contains(w.lowercased()) else { continue }
            known.insert(w.lowercased())
            added.append(DictionaryWord(id: "w-\(UUID().uuidString.prefix(8))", word: w, heardAs: item.heardAs, source: source, date: date))
        }
        guard !added.isEmpty else { return 0 }
        words = added + words
        persist()
        return added.count
    }

    public func replaceAll(_ words: [DictionaryWord]) {
        self.words = words
        persist()
    }

    /// The words speech recognition should listen for.
    public var contextualStrings: [String] { words.map(\.word) }

    /// "heard as" → the word, for the words Fovea mishears.
    public var replacements: [(heard: String, word: String)] {
        words.compactMap { w in w.heardAs.map { ($0, w.word) } }
    }

    public func flush() { saver.flush { write() } }
    private func persist() { saver.schedule { [weak self] in self?.write() } }
    private func write() { file?.save(words) }
}

// MARK: - The first run

/// An app the onboarding hid while it ran ("Clear my screen"), to bring back at the end.
public struct HiddenApp: Codable, Hashable, Sendable {
    public var bundleID: String
    public var pid: Int32
    public init(bundleID: String, pid: Int32) { self.bundleID = bundleID; self.pid = pid }
}

/// Whether the first run is done, and where to pick it up after Screen Recording's Quit & Reopen.
public struct OnboardingState: Codable, Equatable, Sendable {
    public var complete = false
    public var completedAt: Date?
    /// The onboarding's own resume point, as it encodes it (FoveaOnboarding).
    public var resume: Data?
    public var hiddenApps: [HiddenApp] = []

    public init() {}
}

@MainActor
public final class OnboardingStateStore {
    public private(set) var state: OnboardingState
    private let file: FileStore<OnboardingState>?

    public init(location: DataLocation?) {
        file = location.map { FileStore(url: $0.file("onboarding.json")) }
        state = file?.load() ?? OnboardingState()
    }

    public func update(_ change: (inout OnboardingState) -> Void) {
        change(&state)
        file?.save(state)
    }

    public func reset() {
        state = OnboardingState()
        file?.remove()
    }
}

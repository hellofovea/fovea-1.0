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

    /// Everything Fovea kept, gone (`--reset-all`), but the first run's desktop picture
    /// (`Wallpapers/`, put there by hand: Tahoe Day).
    public func eraseAll() {
        let files = FileManager.default
        let keep: Set<String> = ["Wallpapers"]
        for item in (try? files.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        where !keep.contains(item.lastPathComponent) {
            try? files.removeItem(at: item)
        }
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

    /// Settings › Dictionary's On/Off and other spellings, by word (`dictionary-extras.json`, the
    /// window's to write). Oct 23: read here, so they reach speech recognition.
    @ObservationIgnored private let extrasURL: URL?
    @ObservationIgnored private var extrasRead: (date: Date, value: [String: WordSpellings])?

    public init(location: DataLocation?) {
        file = location.map { FileStore(url: $0.file("dictionary.json")) }
        extrasURL = location.map { $0.file("dictionary-extras.json") }
        words = file?.load() ?? []
    }

    /// The extras as the window last wrote them (read again when the file has changed).
    private var extras: [String: WordSpellings] {
        guard let url = extrasURL,
              let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else { return [:] }
        if let read = extrasRead, read.date == date { return read.value }
        let value = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([String: WordSpellings].self, from: $0) } ?? [:]
        extrasRead = (date, value)
        return value
    }

    /// Oct 23, Ryan: a correction the person made to what Fovea heard (a request edited in the
    /// notch) teaches the words put right, as Learned, with what was heard as "Also heard as".
    /// A word already in the dictionary isn't added again. Returns how many were learned.
    @discardableResult
    public func learn(heard: String, corrected: String, in place: String? = nil, date: Date = Date()) -> Int {
        var known = Set(words.map { $0.word.lowercased() })
        var learned: [DictionaryWord] = []
        for item in DictionaryRules.learned(heard: heard, corrected: corrected) where !known.contains(item.word.lowercased()) {
            known.insert(item.word.lowercased())
            learned.append(DictionaryWord(id: "w-\(UUID().uuidString.prefix(8))", word: item.word, heardAs: item.heardAs,
                                          source: .learned, date: date, learnedIn: place))
        }
        guard !learned.isEmpty else { return 0 }
        words = learned + words
        persist()
        return learned.count
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

    /// The words speech recognition should listen for: the ones that are on (Oct 23).
    public var contextualStrings: [String] { DictionaryRules.contextual(words, extras: extras) }

    /// "heard as" → the word, for the words Fovea mishears: every spelling of the words that are
    /// on (Oct 23: the extra spellings and Off, from Settings › Dictionary).
    public var replacements: [(heard: String, word: String)] { DictionaryRules.replacements(words, extras: extras) }

    /// The words as the dictionary writes them (whole words, case aside; Chinese anywhere).
    public func written(_ text: String) -> String { DictionaryRules.apply(text, replacements) }

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
    /// Left part way with "Exit tour" (Oct 10): Fovea opens to Home, and the tour picks up from
    /// there when asked (Home's link, or Fovea › Resume the Tour), at `resume`.
    public var paused = false

    public init() {}

    // Decoding tolerates a file written before a field existed.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        complete = (try? c.decode(Bool.self, forKey: .complete)) ?? false
        completedAt = try? c.decode(Date.self, forKey: .completedAt)
        resume = try? c.decode(Data.self, forKey: .resume)
        hiddenApps = (try? c.decode([HiddenApp].self, forKey: .hiddenApps)) ?? []
        paused = (try? c.decode(Bool.self, forKey: .paused)) ?? false
    }
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

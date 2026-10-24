import AppKit
import SwiftUI
import CapturesCore
import FoveaKit
import FoveaLook

// Memory, all of it (Oct 15 review: ME-01.1–ME-01.5, ME-02, ST-07.1, ST-07.3, NH-03). Ryan approved
// a full Memory browser: a recorded departure from AGENTS.md's "no UI for curating stored facts".
// Settings › Memory keeps the areas Fovea has come to know; under them every memory, browsed by
// Recent, by the app it came from, by tag, Hidden and Recently Deleted; searched, falling back to
// word matches (and saying so) while meaning search gets ready; narrowed by a source, a tag or an
// entity; how many there are and what they take; select one or many to Hide, Show, Delete (with
// Undo) or Restore; a memory's detail with where it came from and what backs it. 1.0 has no memory
// server: the memories and where they came from are simulated (Fixtures), and the access log too.

// MARK: - Values

/// Where the browser is (ME-01.1): Recent, one app, one tag, Hidden or Recently Deleted.
enum MemoryFilter: Hashable {
    case recent, source(String), tag(String), hidden, deleted

    var title: String {
        switch self {
        case .recent: return L("Recent")
        case .source(let s): return s
        case .tag(let t): return t
        case .hidden: return L("Hidden")
        case .deleted: return L("Recently Deleted")
        }
    }
}

/// What the list is narrowed to, within where it is (ME-01.3): one source, one tag, one entity.
struct MemoryRefine: Equatable {
    var source: String?
    var tag: String?
    var entity: String?
    var isEmpty: Bool { source == nil && tag == nil && entity == nil }
}

/// Where a memory came from and what backs it (ME-02): the app and its window, what you said, the
/// answer in brief, the text on screen, and the evidence (the picture, the words you selected, where
/// you looked). Simulated: read from the capture each memory came from in the sample history
/// (Fixtures), or written here for the few said straight to Fovea.
struct MemoryOrigin {
    var app: AppRef
    var window: String?
    var said: String
    var answer: String?
    var seen: String?
    var picture: Attachment?
    var selected: String?
    var file: String?
    /// Where the eyes were on the picture, in unit coordinates (simulated).
    var gaze: CGPoint?
    /// The capture, when it's in the sample history or this Mac's.
    var captureID: String?
    var sentTo: String?
}

@MainActor
enum MemoryOrigins {
    /// The sample history the simulated memories point into.
    private static let sample: [String: Capture] = Dictionary(Fixtures.library(.typical).captures.map { ($0.id, $0) },
                                                             uniquingKeysWith: { a, _ in a })
    private static var origins: [String: MemoryOrigin] = [:]
    private static var entityCache: [String: [String]] = [:]

    /// The few memories said straight to Fovea or in an app with no capture kept (simulated).
    private static let written: [String: (app: AppRef, window: String?, answer: String?)] = [
        "m-main": (AppRef("Terminal", "com.apple.Terminal"), "api-server — zsh", "Claude Code pushed the change to api-server."),
        "m-second": (AppRef("Google Chrome", "com.google.Chrome"), "fovea-site — localhost:3000", "Claude Code changed the Features section's button to “开始”."),
        "m-claude": (AppRef("Fovea", "app.fovea"), nil, nil),
        "m-ears": (AppRef("Xcode", "com.apple.dt.Xcode"), "NotchShape.swift — Fovea", "Claude Code matched the ears' radius to the menu bar's."),
        "m-signoff": (AppRef("Mail", "com.apple.mail"), "Re: Interview recordings", nil),
    ]

    /// The answer, in brief, for the sample dispatches that have one (simulated).
    private static let answers: [String: String] = [
        "x-ship": "Wrote the weekly update as five short lines.",
        "x-downloads": "Moved six invoices into Finance, each dated.",
        "x-hero-photo": "Cropped the hero to 16:9 around the ridge line, with a WebP and a JPEG.",
        "x-ears": "Matched the ears to the menu bar.",
        "x-mcp": "An MCP tool is called when needed; a resource is attached up front.",
    ]

    static func origin(_ m: Memory, captures: [Capture]) -> MemoryOrigin {
        let cacheKey = "\(m.id)|\(FoveaLocale.shared.language.rawValue)"
        if let hit = origins[cacheKey] { return hit }
        let capture = m.captureID.flatMap { id in captures.first { $0.id == id } ?? sample[id] }
        var o: MemoryOrigin
        if let c = capture {
            let region = c.attachments.first { $0.kind == .region }
            let passage = c.attachments.first { $0.kind == .passage }
            let file = c.attachments.first { $0.kind == .file }
            o = MemoryOrigin(app: c.app,
                             window: c.attachments.first?.source ?? c.site,
                             said: c.text.isEmpty ? m.quote : c.text,
                             answer: c.kind == .dispatch ? (answers[c.id] ?? c.destination.map { L("Answered in “\($0.chat)”.") }) : nil,
                             seen: region?.text,
                             picture: region,
                             selected: passage?.text,
                             file: file?.text,
                             gaze: region == nil ? nil : gazePoint(m.id),
                             captureID: c.id,
                             sentTo: c.kind == .dispatch ? c.destination?.agent : nil)
        } else if let w = written[m.id] {
            o = MemoryOrigin(app: w.app, window: w.window, said: m.quote, answer: w.answer)
        } else {
            let app = m.scope.map { AppRef($0, "") } ?? AppRef("Fovea", "app.fovea")
            o = MemoryOrigin(app: app, said: m.quote)
        }
        origins[cacheKey] = o
        return o
    }

    /// A point on the picture where the eyes rested, the same every time for a memory (simulated).
    private static func gazePoint(_ id: String) -> CGPoint {
        let n = id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return CGPoint(x: 0.3 + Double(n % 40) / 100, y: 0.3 + Double((n / 40) % 40) / 100)
    }

    /// The people, places and things a memory names (simulated: quoted terms, then names written
    /// with capitals, and the app or project it applies to).
    static func entities(_ m: Memory) -> [String] {
        if let hit = entityCache[m.id] { return hit }
        var out: [String] = []
        func add(_ s: String) {
            let t = s.trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.whitespaces))
            if t.count > 1, !out.contains(t) { out.append(t) }
        }
        if let regex = try? NSRegularExpression(pattern: "“([^”]+)”") {
            let ns = m.text as NSString
            for match in regex.matches(in: m.text, range: NSRange(location: 0, length: ns.length)) {
                add(ns.substring(with: match.range(at: 1)))
            }
        }
        let words = m.text.replacingOccurrences(of: "“", with: " ").replacingOccurrences(of: "”", with: " ")
            .split(separator: " ").map(String.init)
        var run: [String] = []
        for (i, word) in words.enumerated() {
            let clean = word.trimmingCharacters(in: .punctuationCharacters)
            let capital = clean.first.map { $0.isUppercase && $0.isASCII } ?? false
            if i > 0, capital, !stop.contains(clean) {
                run.append(clean)
            } else {
                if !run.isEmpty { add(run.joined(separator: " ")) }
                run = []
            }
            if word.hasSuffix(",") || word.hasSuffix(";") || word.hasSuffix(".") {
                if !run.isEmpty { add(run.joined(separator: " ")) }
                run = []
            }
        }
        if !run.isEmpty { add(run.joined(separator: " ")) }
        if let scope = m.scope { add(scope) }
        let result = Array(out.prefix(5))
        entityCache[m.id] = result
        return result
    }

    private static let stop: Set<String> = ["The", "A", "An", "In", "On", "Of", "And", "Or", "To", "For", "With", "Not", "Then", "I"]

    /// The apps memories came from, the most first.
    static func sources(_ memories: [Memory], captures: [Capture] = []) -> [(name: String, app: AppRef, count: Int)] {
        var counts: [String: (AppRef, Int)] = [:]
        for m in memories where m.deleted == nil {
            let app = origin(m, captures: captures).app
            counts[app.name] = (app, (counts[app.name]?.1 ?? 0) + 1)
        }
        return counts.map { (name: $0.key, app: $0.value.0, count: $0.value.1) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }

    /// The names memories carry, the most used first (the Filter menu's Entity).
    static func entityCounts(_ memories: [Memory], limit: Int = 24) -> [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for m in memories where m.deleted == nil { for e in entities(m) { counts[e, default: 0] += 1 } }
        let sorted: [(name: String, count: Int)] = counts.map { (name: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
        return Array(sorted.prefix(limit))
    }

    /// Tags on memories, the most used first.
    static func tags(_ memories: [Memory]) -> [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for m in memories where m.deleted == nil { for t in m.tags { counts[t, default: 0] += 1 } }
        return counts.map { (tag: $0.key, count: $0.value) }.sorted { $0.count != $1.count ? $0.count > $1.count : $0.tag < $1.tag }
    }
}

/// One time an agent read Fovea's memory (ST-07.3): when, with which tool, which client, what it
/// asked or read, and how many memories came back. Simulated: 1.0 has no memory server.
struct AccessEvent: Identifiable, Hashable {
    enum Kind: String, CaseIterable, Hashable {
        case search, recall, list
        var title: String {
            switch self {
            case .search: return L("Search")
            case .recall: return L("Recall")
            case .list: return L("List")
            }
        }
        /// The memory server's tool, as the agent called it.
        var tool: String {
            switch self {
            case .search: return "search_memories"
            case .recall: return "recall_memory"
            case .list: return "list_memories"
            }
        }
    }

    let id: String
    var time: Date
    var kind: Kind
    var client: String
    var memory: String
    var count: Int

    static func samples(now: Date = Date()) -> [AccessEvent] {
        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        return [
            AccessEvent(id: "a1", time: ago(22), kind: .search, client: "Claude Code", memory: "“ears”", count: 2),
            AccessEvent(id: "a2", time: ago(184), kind: .recall, client: "Claude Code", memory: "“主仓” means api-server", count: 1),
            AccessEvent(id: "a3", time: ago(60 * 26), kind: .search, client: "Codex", memory: "“第二屏”", count: 1),
            AccessEvent(id: "a4", time: ago(60 * 50), kind: .list, client: "Claude Code", memory: "Work", count: 12),
            AccessEvent(id: "a5", time: ago(60 * 75), kind: .search, client: "Codex", memory: "“rate limits”", count: 3),
            AccessEvent(id: "a6", time: ago(60 * 140), kind: .recall, client: "Claude Code", memory: "Send motion work to Claude Code", count: 1),
        ]
    }
}

// MARK: - Actions

extension CapturesModel {
    /// The browser's list: where it is, narrowed, searched; newest first (ME-01.1–ME-01.3).
    func memoriesShown() -> [Memory] {
        let p = panes
        let tokens = p.memorySearch.lowercased().split(separator: " ").map(String.init)
        let captures = library.captures
        return library.memories.filter { m in
            switch memoryFilter {
            case .recent: if m.deleted != nil { return false }
            case .source(let s): if m.deleted != nil || MemoryOrigins.origin(m, captures: captures).app.name != s { return false }
            case .tag(let t): if m.deleted != nil || !m.tags.contains(t) { return false }
            case .hidden: if m.deleted != nil || !m.hidden { return false }
            case .deleted: if m.deleted == nil { return false }
            }
            if let s = p.memoryRefine.source, MemoryOrigins.origin(m, captures: captures).app.name != s { return false }
            if let t = p.memoryRefine.tag, !m.tags.contains(t) { return false }
            if let e = p.memoryRefine.entity, !MemoryOrigins.entities(m).contains(e) { return false }
            guard !tokens.isEmpty else { return true }
            // Meaning search reads everything a memory carries (simulated: its words, where it
            // came from, its tags and names, its area); until it's ready, the memory's own words.
            let hay: String
            if p.meaningSearchReady {
                let o = MemoryOrigins.origin(m, captures: captures)
                let area = m.area.flatMap { a in library.areas.first { $0.id == a }?.title } ?? ""
                hay = ([m.text, m.quote, o.app.name, o.window ?? "", o.said, area] + m.tags + MemoryOrigins.entities(m))
                    .joined(separator: " ").lowercased()
            } else {
                hay = (m.text + " " + m.quote).lowercased()
            }
            return tokens.allSatisfy { hay.contains($0) }
        }
        .sorted { $0.date > $1.date }
    }

    /// "2,340 memories · 38 MB" (ME-01.4). The size is simulated: about 16 KB a memory, its words
    /// and a picture's thumbnail.
    var memoryCapacity: String {
        let n = library.memories.filter { $0.deleted == nil }.count
        let size = ByteCountFormatter.string(fromByteCount: Int64(n) * 16_600, countStyle: .file)
        return n == 1 ? L("1 memory · \(size)") : L("\(n.formatted()) memories · \(size)")
    }

    /// New captures organised into memories, one at a time (simulated work, ME-01.4): meaning search
    /// waits for it.
    func organise(_ count: Int) {
        guard count > 0 else { return }
        let p = panes
        withAnimation(motion.animation(.layout)) {
            p.organising = (p.organising ?? 0) + count
            p.meaningSearchReady = false
        }
        guard p.organiseTask == nil else { return }
        p.organiseTask = Task { @MainActor in
            while let left = p.organising, left > 0 {
                try? await Task.sleep(for: .seconds(0.7))
                guard !Task.isCancelled else { break }
                p.organising = left > 1 ? left - 1 : nil
            }
            withAnimation(self.motion.animation(.layout)) {
                p.organising = nil
                p.meaningSearchReady = true
            }
            p.organisedThrough = Date()
            p.organiseTask = nil
        }
    }

    /// Captures the island added since the last were organised start organising (simulated work
    /// on real captures).
    func organiseNewCaptures() {
        let new = library.captures.filter { $0.time > panes.organisedThrough }.count
        if new > 0 {
            panes.organisedThrough = Date()
            organise(new)
        }
    }

    /// Opens the browser on one memory (NH-03, the notch's "memory updated"): in Recently Deleted
    /// if it's there; gone, Recent, with a quiet line.
    func openMemory(_ id: String) {
        openSettings(.memory)
        panes.memoryRefine = MemoryRefine()
        panes.memorySearch = ""
        if let m = library.memories.first(where: { $0.id == id }) {
            memoryFilter = m.deleted != nil ? .deleted : .recent
            memorySelection = [id]
            panes.memoryMissing = false
            panes.memoryScrollTarget = nil
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.35))
                self.panes.memoryScrollTarget = id
            }
        } else {
            memoryFilter = .recent
            memorySelection = []
            panes.memoryMissing = true
        }
        browsingMemories = true
    }

    /// Takes a tag off every memory, once the person has said yes (ME-01.5). The memories stay.
    func deleteTag(_ tag: String) {
        let n = library.memories.filter { $0.tags.contains(tag) }.count
        animate(.layout) {
            for i in library.memories.indices where library.memories[i].tags.contains(tag) {
                library.memories[i].tags.removeAll { $0 == tag }
            }
            if memoryFilter == .tag(tag) { memoryFilter = .recent }
            if panes.memoryRefine.tag == tag { panes.memoryRefine.tag = nil }
        }
        say(n == 1 ? L("Deleted the tag “\(tag)” from 1 memory") : L("Deleted the tag “\(tag)” from \(n) memories"))
    }

    /// Opens what a memory came from: its capture in Home when it's there, otherwise the app.
    func openSource(_ origin: MemoryOrigin) {
        if let id = origin.captureID, library.captures.contains(where: { $0.id == id }) {
            openCapture(id)
            return
        }
        guard !origin.app.bundleID.isEmpty,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: origin.app.bundleID) else {
            say(L("\(origin.app.name) isn't on this Mac"))
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Reads the access log again (simulated: nothing new arrives).
    func refreshAccessLog() {
        let p = panes
        p.accessRefreshing = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.8))
            p.accessRefreshing = false
            p.accessChecked = Date()
        }
    }
}

extension HomeWindowController {
    /// Oct 15 review, NH-03: the notch's "memory updated" notice opens the memory it names here
    /// (`IslandController` → App → this). A memory that's gone opens Recent, with a quiet line.
    package func openMemory(_ id: String) {
        show()
        model.openMemory(id)
    }
}

// MARK: - Settings › Memory

/// Memory, as people think of it (row 24, after Claude's memory topics): the areas of your life
/// Fovea has come to know, each a short summary in its words, read from the tags that keep coming
/// up; under them, every memory, how many and what they take, one button away (Oct 15: the
/// browser). Then what it may remember, when it says so, and who read it.
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
                            Button("Try Again") { model.animate(.layout) { model.memoryState = .loaded } }
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
                        // Oct 15 review, ST-07.1: Memory off says so where the memories are, with the
                        // way back on.
                        PausedBanner()
                    }
                    VStack(spacing: 10) {
                        ForEach(model.library.areas) { area in AreaCard(area: area) }
                    }
                }
                .id("memory-about")
                AllMemoriesSection(count: active.count)
                    .id("memory-all")
            }
        }
        SettingsSection("Remembering") {
            SettingsCard {
                SettingsRow("Memory Link", detail: "Remember what you send your agents, not only what you ask Fovea to remember. Off pauses it.") {
                    InkToggle(title: "Memory Link", isOn: $model.prefs.memoryLink.animation(model.motion.animation(.layout)))
                }
                RowDivider()
                SettingsRow("Remember things when you ask", detail: "Press fn and say “remember that …”.") {
                    InkToggle(title: "Remember things when you ask", isOn: $model.prefs.remember)
                }
                RowDivider()
                // Oct 15 review, NH-03: the notch says when a memory updates, and its notice opens
                // the memory (`HomeWindowController.openMemory`).
                SettingsRow("Tell me when a memory updates", detail: "A short note at the notch. Click it to see the memory.") {
                    InkToggle(title: "Tell me when a memory updates", isOn: $model.prefs.rememberNotice)
                }
                RowDivider()
                SettingsRow("Agents' reading", detail: "Which agents read your memory, when, and what they asked.") {
                    TextButton("Access Log…") { model.accessLogShown = true }
                }
            }
        }
        .id("memory-remembering")
        .onAppear { model.organiseNewCaptures() }
    }
}

/// "Memory is paused", over the memories, with the way back on (ST-07.1).
private struct PausedBanner: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "pause.circle").foregroundStyle(palette.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Memory is paused").font(.system(size: 12, weight: .medium)).foregroundStyle(palette.text)
                Text("What you send now isn't remembered. Your memories stay, and agents can still read them.")
                    .font(.system(size: 11)).foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Turn On") { model.animate(.layout) { model.prefs.memoryLink = true } }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(palette.fill))
    }
}

/// How many memories, what they take, whether new captures are being organised, and the way in
/// (ME-01.4).
private struct AllMemoriesSection: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let count: Int

    var body: some View {
        SettingsSection("All memories") {
            SettingsCard {
                SettingsRow(model.memoryCapacity,
                            detail: "Everything the summaries come from: each with what you said, where, and what backs it.") {
                    TextButton("Search Memories…") { model.browsingMemories = true }
                }
                if let n = model.panes.organising {
                    RowDivider()
                    OrganisingLine(count: n)
                        .cardPadding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.arrive)
                }
            }
        }
    }
}

/// "Organising 12 new captures…" with the system's spinner.
private struct OrganisingLine: View {
    @Environment(\.palette) private var palette
    let count: Int
    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(count == 1 ? L("Organising 1 new capture…") : L("Organising \(count) new captures…"))
                .font(.system(size: 12)).foregroundStyle(palette.secondary)
                .monospacedDigit()
        }
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
                    if WindowLook.isAligned {
                        // Aligned: the symbol alone, in ink, as the sidebar draws its own.
                        Image(systemName: area.symbol)
                            .font(.system(size: T.Aligned.sidebarSymbol)).foregroundStyle(palette.secondary)
                            .frame(width: 22, height: 22)
                    } else {
                        Image(systemName: area.symbol)
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(palette.accent))
                    }
                    // Oct 18, Ryan: the sample areas in the primary language (a summary the person
                    // rewrote isn't a key, and shows as written).
                    Text(L(key: area.title)).font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.text)
                    Spacer()
                    Text("Updated \(Lines.relative(area.updated, now: model.now))")
                        .font(.system(size: 11)).foregroundStyle(palette.tertiary)
                    Menu {
                        Button("Edit Summary…") { draft = area.summary; editing = true }
                        Divider()
                        Button("Forget “\(L(key: area.title))”…", role: .destructive) { confirmForget = true }
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
                    Text(L(key: area.summary))
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
        .alert("Forget “\(L(key: area.title))”?", isPresented: $confirmForget) {
            Button("Forget", role: .destructive) { model.forgetArea(area.id) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Fovea stops using this summary. The memories it came from stay, searchable, until you delete them.")
        }
    }
}

// MARK: - The browser

/// Every memory (Oct 15 review, ME-01.1–ME-01.5, ME-02): where to look at the left (Recent, Hidden,
/// Recently Deleted, then by app and by tag), the list in the middle with search and what it's
/// narrowed to, the one selected at the right; several selected, Hide, Show or Delete them at once.
struct MemoryBrowser: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var model = model
        @Bindable var panes = model.panes
        let shown = model.memoriesShown()
        let selected = model.memorySelection
        let one = selected.count == 1 ? model.library.memories.first { selected.contains($0.id) } : nil

        VStack(spacing: 0) {
            BrowserHeader()
            Divider()
            HStack(spacing: 0) {
                MemorySidebar()
                    .frame(width: 196)
                Divider()
                VStack(spacing: 0) {
                    ListNotes()
                    MemoryList(shown: shown)
                }
                .frame(minWidth: 330, maxWidth: .infinity)
                Divider()
                MemoryDetail(memory: one, count: selected.count)
                    .frame(width: 300)
            }
            Divider()
            BrowserFooter(shown: shown)
        }
        .frame(width: 900, height: 580)
        .onChange(of: model.memoryFilter) {
            model.memorySelection = []
            panes.memoryMissing = false
        }
        .alert("Delete the tag “\(panes.tagToDelete ?? "")”?",
                            isPresented: Binding(get: { panes.tagToDelete != nil }, set: { if !$0 { panes.tagToDelete = nil } })) {
            Button("Delete Tag", role: .destructive) {
                if let tag = panes.tagToDelete { model.deleteTag(tag) }
                panes.tagToDelete = nil
            }
            Button("Cancel", role: .cancel) { panes.tagToDelete = nil }
        } message: {
            let tag = panes.tagToDelete ?? ""
            let n = model.library.memories.filter { $0.tags.contains(tag) }.count
            Text(n == 1 ? L("It comes off 1 memory. The memory stays.") : L("It comes off \(n) memories. The memories stay."))
        }
    }
}

/// The title, how many and what they take, organising, and search.
private struct BrowserHeader: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var panes = model.panes
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Memories").font(.system(size: 15, weight: .semibold))
                HStack(spacing: 8) {
                    Text(model.memoryCapacity).monospacedDigit()
                    if let n = panes.organising {
                        Text("·")
                        OrganisingLine(count: n)
                    }
                }
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search memories", text: $panes.memorySearch)
                    .textFieldStyle(.plain)
                if !panes.memorySearch.isEmpty {
                    Button { panes.memorySearch = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .frame(width: 260, height: 28)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(palette.ink(T.Shade.fill)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// Where to look: Recent, Hidden, Recently Deleted; then each app memories came from, and each
/// tag (a tag's menu deletes it, after asking).
private struct MemorySidebar: View {
    @Environment(CapturesModel.self) private var model

    var body: some View {
        let memories = model.library.memories
        let live = memories.filter { $0.deleted == nil }
        let sources = MemoryOrigins.sources(memories, captures: model.library.captures)
        let tags = MemoryOrigins.tags(memories)
        List(selection: Binding<MemoryFilter?>(get: { model.memoryFilter }, set: { if let f = $0 { model.memoryFilter = f } })) {
            Section {
                Label("Recent", systemImage: "clock").badge(live.count).tag(MemoryFilter.recent)
                Label("Hidden", systemImage: "eye.slash").badge(live.filter(\.hidden).count).tag(MemoryFilter.hidden)
                    .help("Hidden from agents. Fovea still uses them.")
                Label("Recently Deleted", systemImage: "trash").badge(memories.count - live.count).tag(MemoryFilter.deleted)
            }
            Section("Sources") {
                ForEach(sources, id: \.name) { s in
                    Label { Text(s.name) } icon: { Image(nsImage: Art.small(Art.icon(s.app))) }
                        .badge(s.count)
                        .tag(MemoryFilter.source(s.name))
                }
            }
            Section("Tags") {
                ForEach(tags, id: \.tag) { t in
                    Label(t.tag, systemImage: "tag")
                        .badge(t.count)
                        .tag(MemoryFilter.tag(t.tag))
                        .contextMenu {
                            Button("Delete Tag “\(t.tag)”…", role: .destructive) { model.panes.tagToDelete = t.tag }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .environment(\.defaultMinListRowHeight, 26)
    }
}

/// Above the list: what it's narrowed to (each token removable, and a Filter menu for more), why
/// search shows word matches, and a memory asked for that's gone.
private struct ListNotes: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var panes = model.panes
        let r = panes.memoryRefine
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let s = r.source { Token(kind: "Source", value: s) { panes.memoryRefine.source = nil } }
                if let t = r.tag { Token(kind: "Tag", value: t) { panes.memoryRefine.tag = nil } }
                if let e = r.entity { Token(kind: "Entity", value: e) { panes.memoryRefine.entity = nil } }
                Spacer(minLength: 0)
                FilterMenu()
            }
            if !panes.meaningSearchReady && !panes.memorySearch.isEmpty {
                Label("Showing word matches: meaning search is still getting ready.", systemImage: "info.circle")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
                    .transition(.arrive)
            }
            if panes.memoryMissing {
                HStack(spacing: 6) {
                    Text("That memory isn't here any more. These are your recent ones.")
                    Button { panes.memoryMissing = false } label: { Image(systemName: "xmark").font(.system(size: 9, weight: .bold)) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss")
                }
                .font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

/// "Source: Xcode ✕".
private struct Token: View {
    @Environment(\.palette) private var palette
    let kind: String
    let value: String
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(L(key: kind)).foregroundStyle(.secondary)
            Text(value).lineLimit(1)
            Button(action: remove) { Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary) }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Remove \(L(key: kind)) \(value)"))
        }
        .font(.system(size: 11.5))
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Capsule().fill(palette.ink(T.Shade.fill)))
        .overlay(Capsule().strokeBorder(palette.ink(T.Shade.line), lineWidth: 0.5))
    }
}

/// Narrow by source, tag or entity.
private struct FilterMenu: View {
    @Environment(CapturesModel.self) private var model

    var body: some View {
        let memories = model.library.memories
        let entities = MemoryOrigins.entityCounts(memories)
        Menu {
            Menu("Source") {
                ForEach(MemoryOrigins.sources(memories, captures: model.library.captures), id: \.name) { s in
                    Button("\(s.name) (\(s.count))") { model.panes.memoryRefine.source = s.name }
                }
            }
            Menu("Tag") {
                ForEach(MemoryOrigins.tags(memories), id: \.tag) { t in
                    Button("\(t.tag) (\(t.count))") { model.panes.memoryRefine.tag = t.tag }
                }
            }
            Menu("Entity") {
                ForEach(entities, id: \.name) { e in
                    Button("\(e.name) (\(e.count))") { model.panes.memoryRefine.entity = e.name }
                }
            }
            if !model.panes.memoryRefine.isEmpty {
                Divider()
                Button("Clear Filters") { model.panes.memoryRefine = MemoryRefine() }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .font(.system(size: 12))
    }
}

/// The memories, several selectable (⌘ and ⇧ as any Mac list), ⌘⌫ deletes.
private struct MemoryList: View {
    @Environment(CapturesModel.self) private var model
    let shown: [Memory]

    var body: some View {
        @Bindable var model = model
        if shown.isEmpty {
            VStack(spacing: 6) {
                Text(emptyLine).foregroundStyle(.secondary)
                if !model.panes.memoryRefine.isEmpty || !model.panes.memorySearch.isEmpty {
                    Button("Clear Search and Filters") {
                        model.panes.memoryRefine = MemoryRefine()
                        model.panes.memorySearch = ""
                    }
                }
            }
            .font(.system(size: 12.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                List(selection: $model.memorySelection) {
                    ForEach(shown) { m in MemoryListRow(memory: m).tag(m.id).id(m.id) }
                }
                .listStyle(.inset)
                .onDeleteCommand { if model.memoryFilter != .deleted { model.deleteMemories(model.memorySelection) } }
                .onChange(of: model.panes.memoryScrollTarget) {
                    if let id = model.panes.memoryScrollTarget { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
    }

    private var emptyLine: String {
        if !model.panes.memorySearch.isEmpty || !model.panes.memoryRefine.isEmpty { return L("No matching memories.") }
        switch model.memoryFilter {
        case .deleted: return L("No recently deleted memories.")
        case .hidden: return L("No memories hidden from agents.")
        default: return L("No memories here.")
        }
    }
}

/// A memory in the list: its words, then the app it came from, when, its tags; marked when hidden
/// from agents, and, deleted, how long until it's gone for good.
private struct MemoryListRow: View {
    @Environment(CapturesModel.self) private var model
    let memory: Memory

    var body: some View {
        let origin = MemoryOrigins.origin(memory, captures: model.library.captures)
        HStack(alignment: .top, spacing: 8) {
            Image(nsImage: Art.icon(origin.app)).resizable().frame(width: 18, height: 18).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    if memory.hidden { Image(systemName: "eye.slash").font(.system(size: 10)).foregroundStyle(.secondary) }
                    Text(memory.text).font(.system(size: 13)).lineLimit(1)
                }
                Text(line(origin)).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private func line(_ origin: MemoryOrigin) -> String {
        var parts = [origin.app.name, Lines.day(memory.date)]
        if !memory.tags.isEmpty { parts.append(memory.tags.joined(separator: L(", "))) }
        if let d = memory.deleted {
            let left = max(0, 30 - (Lines.calendar.dateComponents([.day], from: d, to: model.now).day ?? 0))
            parts.append(left == 0 ? L("Gone soon") : L("Gone for good in \(left) days"))
        }
        return parts.joined(separator: " · ")
    }
}

/// The memory selected: where it came from, what you said, the answer in brief, the text on screen,
/// its tags and the names in it (each narrows the list), and what backs it; Open Source, Hide or
/// Show, Delete or Restore.
private struct MemoryDetail: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let memory: Memory?
    let count: Int

    var body: some View {
        if let m = memory {
            let o = MemoryOrigins.origin(m, captures: model.library.captures)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(m.text).font(.system(size: 14, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                        from(m, o)
                        part(m.stated ? "You asked Fovea to remember" : "What you said") {
                            Text(o.said).font(.system(size: 12.5)).lineLimit(8).fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                        if let answer = o.answer {
                            part("The answer, in brief") {
                                Text(L(key: answer)).font(.system(size: 12.5)).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if let seen = o.seen, !seen.isEmpty {
                            part("Text on screen") {
                                Text(seen).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(5)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if !m.tags.isEmpty {
                            part("Tags") { chips(m.tags) { model.panes.memoryRefine.tag = $0 } }
                        }
                        let entities = MemoryOrigins.entities(m)
                        if !entities.isEmpty {
                            part("Names in it") { chips(entities) { model.panes.memoryRefine.entity = $0 } }
                                .help("Click a name to see every memory with it.")
                        }
                        evidence(o)
                        if m.hidden {
                            Label("Hidden from agents: Fovea still uses it.", systemImage: "eye.slash")
                                .font(.system(size: 11.5)).foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                actions(m, o)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        } else {
            Text(count > 1 ? L("\(count) memories selected") : L("Select a memory to see where it came from."))
                .font(.system(size: 12.5)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func from(_ m: Memory, _ o: MemoryOrigin) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: Art.icon(o.app)).resizable().frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(o.window.map { "\(o.app.name) · \($0)" } ?? o.app.name).font(.system(size: 12)).lineLimit(2)
                Text(Lines.day(m.date) + (o.sentTo.map { " · " + L("sent to \($0)") } ?? ""))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func part<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L(key: title)).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func chips(_ values: [String], pick: @escaping (String) -> Void) -> some View {
        FlowLayout(spacing: 5) {
            ForEach(values, id: \.self) { v in
                Button { pick(v) } label: {
                    Text(v).font(.system(size: 11.5)).padding(.horizontal, 8).frame(height: 20)
                        .background(Capsule().fill(palette.ink(T.Shade.fill)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The evidence: the picture taken, with where you looked on it; the words you selected; a file.
    @ViewBuilder private func evidence(_ o: MemoryOrigin) -> some View {
        if o.picture != nil || o.selected != nil || o.file != nil {
            part("Evidence") {
                VStack(alignment: .leading, spacing: 8) {
                    if let a = o.picture, let image = Art.region(a) {
                        Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                            .overlay {
                                GeometryReader { geo in
                                    if let g = o.gaze {
                                        Circle().strokeBorder(palette.accent, lineWidth: 2)
                                            .background(Circle().fill(palette.accent.opacity(0.18)))
                                            .frame(width: 22, height: 22)
                                            .position(x: geo.size.width * g.x, y: geo.size.height * g.y)
                                    }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(palette.ink(T.Shade.line), lineWidth: 0.5))
                            .frame(maxHeight: 150)
                        if o.gaze != nil {
                            Label("Where you looked", systemImage: "circle.circle")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    if let words = o.selected {
                        Text("Selected: “\(words)”").font(.system(size: 12)).lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let file = o.file {
                        Label(file, systemImage: "doc").font(.system(size: 12))
                    }
                }
            }
        }
    }

    private func actions(_ m: Memory, _ o: MemoryOrigin) -> some View {
        HStack(spacing: 8) {
            Button("Open Source") { model.openSource(o) }
                .help("The capture it came from in Home, or the app")
            Spacer()
            if m.deleted != nil {
                Button("Restore") { model.restoreMemories([m.id]) }
            } else {
                Button(m.hidden ? L("Show") : L("Hide")) { model.setHidden([m.id], !m.hidden) }
                    .help(m.hidden ? L("Agents can see it again") : L("Agents won't see it. Fovea still uses it."))
                Button("Delete", role: .destructive) { model.deleteMemories([m.id]) }
            }
        }
        .controlSize(.small)
    }
}

/// How many are shown or selected, the window's toast with Undo while the sheet is up, and what
/// the selection can do.
private struct BrowserFooter: View {
    @Environment(CapturesModel.self) private var model
    let shown: [Memory]

    var body: some View {
        let selected = model.memorySelection
        HStack(spacing: 8) {
            if let message = model.toast {
                Text(message).font(.system(size: 12, weight: .medium))
                if !model.lastDeletedMemories.isEmpty {
                    Button("Undo") { model.undoMemoryDelete() }
                        .keyboardShortcut("z", modifiers: .command)
                }
            } else {
                Text(selected.isEmpty ? (shown.count == 1 ? L("1 memory") : L("\(shown.count.formatted()) memories")) : L("\(selected.count) selected"))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Text(model.memoryFilter == .deleted ? L("Gone for good 30 days after they're deleted.")
                                                    : L("⇧- or ⌘-click selects several · ⌘⌫ deletes"))
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            Spacer()
            // One selected: its own Hide and Delete are in the detail. Several: here, for all of them.
            if selected.count > 1 {
                if model.memoryFilter == .deleted {
                    Button("Restore \(selected.count)") { model.restoreMemories(selected) }
                } else {
                    let allHidden = model.library.memories.filter { selected.contains($0.id) }.allSatisfy(\.hidden)
                    Button(allHidden ? L("Show \(selected.count)") : L("Hide \(selected.count)")) { model.setHidden(selected, !allHidden) }
                        .help(allHidden ? L("Agents can see them again") : L("Agents won't see them. Fovea still uses them."))
                    Button("Delete \(selected.count)", role: .destructive) { model.deleteMemories(selected) }
                }
            }
            Button("Done") { model.browsingMemories = false }
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Access Log (ST-07.3)

/// When agents read your memory through Fovea: each read's time, the tool it called, the client,
/// what it asked or read, and how many memories came back; by kind; read again with Refresh; and,
/// before any agent has read it, a line that says so. Read-only.
struct AccessLogSheet: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var panes = model.panes
        let shown = panes.accessEvents.filter { panes.accessKind == nil || $0.kind == panes.accessKind }.sorted { $0.time > $1.time }
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Agents' reading").font(.system(size: 15, weight: .semibold))
                Spacer()
                Picker("Show", selection: $panes.accessKind) {
                    Text("All").tag(AccessEvent.Kind?.none)
                    ForEach(AccessEvent.Kind.allCases, id: \.self) { Text($0.title).tag(AccessEvent.Kind?.some($0)) }
                }
                .pickerStyle(.segmented).labelsHidden().fixedSize()
                Button { model.refreshAccessLog() } label: {
                    if panes.accessRefreshing { ProgressView().controlSize(.small) } else { Label("Refresh", systemImage: "arrow.clockwise") }
                }
                .disabled(panes.accessRefreshing)
            }
            Text("When an agent read your memory through Fovea, and what it asked. Read-only.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Group {
                if panes.accessEvents.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "tray").font(.system(size: 22)).foregroundStyle(.tertiary)
                        Text("No agent has read your memory yet").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                        Text("When Claude Code or Codex reads it through Fovea, it shows here.")
                            .font(.system(size: 12)).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if shown.isEmpty {
                    Text(panes.accessKind == .search ? L("No searches yet.") : (panes.accessKind == .recall ? L("No recalls yet.") : L("No lists yet.")))
                        .font(.system(size: 12.5)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Table(shown) {
                        TableColumn("Time") { e in Text(Lines.relative(e.time, now: Date())).foregroundStyle(.secondary) }
                            .width(104)
                        TableColumn("Tool") { e in Text(e.kind.tool).font(.system(size: 11.5, design: .monospaced)) }
                            .width(122)
                        TableColumn("Client") { e in
                            HStack(spacing: 5) {
                                Image(nsImage: Art.agentIcon(e.client)).resizable().frame(width: 16, height: 16)
                                Text(e.client)
                            }
                        }
                        .width(116)
                        TableColumn("Memory") { e in Text(L(key: e.memory)).lineLimit(1).help(L(key: e.memory)) }
                            .width(min: 180, ideal: 260)
                        TableColumn("Count") { e in Text("\(e.count)").monospacedDigit().frame(maxWidth: .infinity, alignment: .trailing) }
                            .width(48)
                    }
                }
            }
            .frame(height: 250)
            HStack {
                Text("Checked \(Lines.relative(panes.accessChecked, now: Date()))").font(.system(size: 11)).foregroundStyle(.tertiary)
                Spacer()
                Button("Done") { model.accessLogShown = false }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 700)
    }
}

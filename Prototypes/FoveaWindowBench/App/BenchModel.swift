import SwiftUI
import AppKit
import WindowBenchCore

/// How a level change moves, decided when it starts so both ends draw the same motion.
struct LevelTransition: Equatable {
    enum Direction { case into, outOf }
    var id = UUID()
    var direction: Direction
    var style: DrillStyle
    /// The row the level opens from or closes onto.
    var sourceKey: String?
    var depth: Int
}

struct Highlight: Equatable {
    var key: String
    var token = UUID()
}

enum BriefPhase: Equatable {
    case writing, written
}

/// The search field's live state. Nothing here is saved: no recent searches are kept.
struct SearchUI: Equatable {
    var expanded = false
    var query = SearchQuery()
    /// Results shown (in place or in the dropdown).
    var presented = false
}

/// The onboarding scan as it counts up.
struct ScanCounts: Equatable {
    var sessions = 0
    var agents = 0
    var projects = 0
    var progress: Double = 0
    /// Sessions read so far per agent; `sessions` is their sum and `agents` how many have any.
    var perAgent: [AgentKind: Int] = [:]
}

@MainActor @Observable
final class BenchModel {
    var state: BenchState { didSet { if state != oldValue { persistSoon() } } }
    var library: Library { didSet { index = LibraryIndex(library) } }
    private(set) var index: LibraryIndex
    let options: BenchOptions
    @ObservationIgnored private let store: BenchStore
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored var currentPlay: Task<Void, Never>?

    // Session state, never saved.
    var transition: LevelTransition?
    var highlight: Highlight?
    var openFold: String?
    var search = SearchUI()
    var correction: String?
    var briefs: [String: BriefPhase] = [:]
    var scan = ScanCounts()
    /// How many projects have arrived in the reveal; `Int.max` when the list is whole.
    var revealed = Int.max
    var revealToken = UUID()
    var mergeIndex = 0
    var dismissedMerges: Set<String> = []
    /// Runs that just arrived in Needs you: their glyph plays the arrival once.
    var arrivals: Set<String> = []
    /// Answers given to waiting runs, actions taken (the verdict log, Stop), by run id.
    var verdicts: [String: String] = [:]
    var handoffTip = false
    /// The hand-off glyph has flown into the notch.
    var handoffFlown = false
    /// Where probed views are in the window, for flights (never drawn from).
    @ObservationIgnored var probes: [String: CGRect] = [:]
    /// The run page's receipt hides while the notch's card flies onto it.
    var receiptHidden = false
    /// The project whose name is travelling between its row and its page's title (Zoom).
    var morphingTitle: String?
    /// A level arriving from outside the window (the notch) enters with the content entrance.
    var arrivalFade = false
    /// A section switch under way: the one in view is fading out.
    var sectionLeaving = false
    @ObservationIgnored var sectionSwitch: Task<Void, Never>?
    var lastMerge: MergeRecord?
    /// The memory item just forgotten, and where it was, so Undo puts it back in place.
    var lastForgotten: (item: MemoryItem, index: Int)?
    /// Diff files the user folded; every file starts open.
    var collapsedFiles: Set<String> = []
    /// The capture stream's type filter (nil: all).
    var captureFilter: CaptureKind?
    /// A capture shown as a Quick Look card over the stream.
    var quickLook: String?
    /// What the notch's Today view shows (Settings › Notch).
    var today = TodaySettings() {
        didSet { if today != oldValue { syncTodayPreview() } }
    }
    /// What the Today preview draws: `today`, a beat later and on the swap spring, so a change
    /// that reorders Settings' rows at once still animates in the preview.
    var previewToday = TodaySettings()
    /// Snapshots draw this row as if the pointer were on it (hover stills).
    var hoverKey: String?
    /// Each agent's hooks (simulated: the bench never writes an agent's file).
    var hooks = BenchModel.defaultHooks
    static let defaultHooks: [AgentKind: HookState] = [
        .claudeCode: .installed(BenchFixtures.now.addingTimeInterval(-2 * 86_400 - 4 * 3600)),
        .codex: .installed(BenchFixtures.now.addingTimeInterval(-86_400 - 5 * 3600)),
    ]
    /// The Settings section a snapshot (or a Go to) scrolls to.
    var settingsScrollTarget: String?
    /// Simulates the keyboard's fn key set to start Dictation (General's conflict check).
    var simulateFnConflict = false
    /// Screen Recording granted (simulated): a result in another app shows a live thumbnail.
    var simulateScreenRecording = false
    /// A block of the run page to bring into view (the harness's stills): `result/<run>`, `captures/<run>`.
    var runScrollTarget: String?
    var settings: BenchSettings {
        get { state.settings }
        set { state.settings = newValue }
    }
    var reduceMotionSystem = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    /// The notch's receipt card is down (the lab notch).
    var notchCard: String?
    /// Something the bench says about itself in the panel (the last Play action, a save).
    var status = ""
    /// Real-scan results, when the source is This Mac.
    var scanSummary: HistorySummary?

    // Hooks the app delegate fills in: the windows live in AppKit.
    @ObservationIgnored var openSettingsHandler: (SettingsTab) -> Void = { _ in }
    @ObservationIgnored var showWindowHandler: () -> Void = {}
    @ObservationIgnored var flightHandler: (String) async -> Void = { _ in }
    @ObservationIgnored var handoffFlightHandler: () async -> Void = {}
    @ObservationIgnored var recordHandler: (String) -> Void = { _ in }
    /// The panel's switch: each Play is also recorded as a GIF.
    var recordPlays = false
    @ObservationIgnored var snapshotHandler: () -> Void = {}
    /// Lays the window out now, so a page a Go to just opened exists before anything else changes.
    @ObservationIgnored var commitHandler: () -> Void = {}
    /// What each fold row last drew, by title: the smoke run checks the screen against the model.
    @ObservationIgnored var drawnFolds: [String: Bool] = [:]
    /// The onboarding step the content area last drew (nil: the levels).
    @ObservationIgnored var drawnOnboarding: OnboardingStep?
    /// Whether the content area last drew search results in place of the page.
    @ObservationIgnored var drawnSearchResults = false
    /// The queries "No results" was drawn for (the smoke run's check on jumps).
    @ObservationIgnored var drawnNoResults: [String] = []
    @ObservationIgnored var scanHandler: () async -> HistorySummary? = { nil }
    var settingsTab: SettingsTab = .general

    init(options: BenchOptions, store: BenchStore) {
        self.options = options
        self.store = store
        var initial = (options.fresh || options.isAutomated) ? BenchState() : (store.load() ?? BenchState())
        if let fixture = options.fixture { initial.fixture = fixture }
        if let source = options.source { initial.source = source }
        if options.isAutomated { initial.onboarding = nil }
        for (id, option) in options.variants { initial.variants[id] = option }
        if let speed = options.speed { initial.speed = speed }
        if let appearance = options.appearance { initial.appearance = appearance }
        if CommandLine.arguments.contains("--reduce-motion") { initial.reduceMotion = true }
        state = initial
        let library = BenchFixtures.library(initial.fixture)
        self.library = library
        index = LibraryIndex(library)
        if let route = options.route { apply(route: route) }
    }

    // MARK: Persistence

    private func persistSoon() {
        saveTask?.cancel()
        let snapshot = state
        saveTask = Task { [store] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            store.save(snapshot)
        }
    }

    // MARK: Variants and motion

    func v<V: Variant>(_ type: V.Type) -> V { state.variants.get(type) }

    func set<V: Variant>(_ value: V) { state.variants.set(value) }

    func setVariant(id: String, option: String) { state.variants[id] = option }

    var motion: MotionSpec {
        MotionSpec(system: v(MotionSystem.self), speed: state.speed,
                   reduce: state.reduceMotion || reduceMotionSystem, arrival: v(WaitingArrival.self))
    }

    func animate(_ role: MotionSpec.Role, _ body: () -> Void) {
        withAnimation(motion.animation(role), body)
    }

    func withoutAnimation(_ body: () -> Void) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t, body)
    }

    private func syncTodayPreview() {
        Task { @MainActor [weak self] in
            guard let self, self.previewToday != self.today else { return }
            self.animate(.swap) { self.previewToday = self.today }
        }
    }

    var verbs: (followUp: String, takeMeThere: String, pass: String) {
        v(VerbLabels.self) == .chinese ? ("接着改", "带我去", "过") : ("Follow up", "Take me there", "Pass")
    }

    // MARK: Data

    func loadFixture(_ set: FixtureSet) {
        state.fixture = set
        library = BenchFixtures.library(set)
        dismissedMerges = []
        mergeIndex = 0
        arrivals = []
        verdicts = [:]
        briefs = [:]
        // Paths that point at things the new library doesn't have go back to the top.
        state.projectPath = state.projectPath.filter(exists)
        if state.projectPath.isEmpty { state.projectPath = [PathEntry(level: .projects)] }
        state.capturePath = state.capturePath.filter(exists)
        if state.capturePath.isEmpty { state.capturePath = [PathEntry(level: .captures)] }
    }

    private func exists(_ entry: PathEntry) -> Bool {
        switch entry.level {
        case .projects, .captures: return true
        case .project(let id): return index.projectByID[id] != nil
        case .run(let id): return index.runByID[id] != nil
        case .capture(let id): return index.captureByID[id] != nil
        }
    }

    // MARK: Navigation

    var path: [PathEntry] {
        get { state.section == .project ? state.projectPath : state.capturePath }
        set {
            if state.section == .project { state.projectPath = newValue } else { state.capturePath = newValue }
        }
    }

    var currentLevel: Level { path.last?.level ?? .projects }

    /// Where the window is going: during a ghost pop the path changes only when the motion ends,
    /// but the crumbs and the toolbar change when it starts, as they do on the way in.
    var destinationPath: [PathEntry] { pendingPop ?? path }
    var destinationLevel: Level { destinationPath.last?.level ?? .projects }

    func selectSection(_ section: WindowSection) {
        guard section != state.section else { return }
        closeSearchResults()
        switchSection(to: section)
    }

    /// Changes section: the one in view fades out on the content curve, then the other fades in,
    /// so two pages are never drawn over each other. `then` runs once the new one is in view.
    func switchSection(to section: WindowSection, then: (() -> Void)? = nil) {
        guard section != state.section else { then?(); return }
        sectionSwitch?.cancel()
        // The pages' own fades (ContentArea) carry the timing: out now, in once it has gone.
        sectionLeaving = true
        sectionSwitch = Task { @MainActor [weak self] in
            guard let self else { return }
            // The page in view starts leaving now; the next one's fade-in carries its own short
            // delay (ContentArea), so no wait here beyond the frame below.
            guard !Task.isCancelled else { return }
            self.batch { self.state.section = section }
            // A frame later: in the batch's own update the fade-in would be dropped (a cut).
            try? await Task.sleep(for: .milliseconds(20))
            guard !Task.isCancelled else { return }
            self.sectionLeaving = false
            then?()
        }
    }

    /// Shows a path in a section: in place when it's the one in view, else through the switch.
    private func go(_ entries: [PathEntry], section: WindowSection, then: @escaping () -> Void) {
        if section == state.section {
            show(entries, section: section)
            then()
        } else {
            batch {
                transition = nil
                pendingPop = nil
                if section == .project { state.projectPath = entries } else { state.capturePath = entries }
            }
            switchSection(to: section, then: then)
        }
    }

    /// Opens a level in place, from the row the click landed on.
    func drill(into level: Level, from sourceKey: String?) {
        closeSearchResults()
        let style = v(DrillStyle.self)
        transition = LevelTransition(direction: .into, style: style, sourceKey: sourceKey, depth: path.count)
        if motion.reduce || style == .crossFade || style == .push {
            animate(.open) { path.append(PathEntry(level: level, sourceKey: sourceKey)) }
        } else {
            path.append(PathEntry(level: level, sourceKey: sourceKey))
        }
    }

    /// Goes back up to `depth` (0 is the top level), the crumbs' and the back button's action.
    func pop(to depth: Int) {
        closeSearchResults()
        guard depth < path.count - 1, depth >= 0 else { return }
        let style = v(DrillStyle.self)
        // One level at a time animates; jumping several levels lands on the target directly.
        let landing = path[depth + 1].sourceKey
        transition = LevelTransition(direction: .outOf, style: style, sourceKey: landing, depth: depth + 1)
        let target = Array(path.prefix(depth + 1))
        if motion.reduce || style == .crossFade || style == .push {
            animate(.close) { path = target }
        } else {
            pendingPop = target
        }
    }

    /// For ghost-driven drills the level is removed when the ghost lands.
    var pendingPop: [PathEntry]?

    func finishPop() {
        if let target = pendingPop {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { path = target }
        }
        pendingPop = nil
    }

    func back() { pop(to: path.count - 2) }

    /// Puts a level on screen directly (the panel's Go to, a restore, a jump).
    func show(_ entries: [PathEntry], section: WindowSection) {
        sectionSwitch?.cancel()
        batch {
            transition = nil
            pendingPop = nil
            sectionLeaving = false
            state.section = section
            if section == .project { state.projectPath = entries } else { state.capturePath = entries }
        }
    }

    /// Changes made from outside the window's own events (the panel, Play, the harness) reach
    /// SwiftUI one by one, and it brings the window up to date inside a change's willSet whenever
    /// an earlier change is pending (even within one transaction): a view rebuilt then reads the
    /// old value and never hears the new one. A batch makes its changes without animation, then
    /// heals: every value is announced again once all are final, so whatever SwiftUI rebuilds
    /// from then on reads final values, and a view that missed a change hears it.
    func batch(_ body: () -> Void) {
        commitHandler()
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t, body)
        heal()
    }

    /// Announces every observed value again (none changes), so a view that missed a change hears
    /// it. Called where the panel and the harness hand control back to the window.
    func heal() {
        commitHandler()
        withMutation(keyPath: \.state) {}
        withMutation(keyPath: \.library) {}
        withMutation(keyPath: \.index) {}
        withMutation(keyPath: \.transition) {}
        withMutation(keyPath: \.highlight) {}
        withMutation(keyPath: \.openFold) {}
        withMutation(keyPath: \.search) {}
        withMutation(keyPath: \.correction) {}
        withMutation(keyPath: \.briefs) {}
        withMutation(keyPath: \.scan) {}
        withMutation(keyPath: \.revealed) {}
        withMutation(keyPath: \.revealToken) {}
        withMutation(keyPath: \.mergeIndex) {}
        withMutation(keyPath: \.dismissedMerges) {}
        withMutation(keyPath: \.arrivals) {}
        withMutation(keyPath: \.verdicts) {}
        withMutation(keyPath: \.handoffTip) {}
        withMutation(keyPath: \.handoffFlown) {}
        withMutation(keyPath: \.receiptHidden) {}
        withMutation(keyPath: \.morphingTitle) {}
        withMutation(keyPath: \.lastMerge) {}
        withMutation(keyPath: \.lastForgotten) {}
        withMutation(keyPath: \.collapsedFiles) {}
        withMutation(keyPath: \.captureFilter) {}
        withMutation(keyPath: \.quickLook) {}
        withMutation(keyPath: \.today) {}
        withMutation(keyPath: \.previewToday) {}
        withMutation(keyPath: \.hoverKey) {}
        withMutation(keyPath: \.hooks) {}
        withMutation(keyPath: \.settingsScrollTarget) {}
        withMutation(keyPath: \.simulateFnConflict) {}
        withMutation(keyPath: \.simulateScreenRecording) {}
        withMutation(keyPath: \.runScrollTarget) {}
        withMutation(keyPath: \.notchCard) {}
        withMutation(keyPath: \.scanSummary) {}
        withMutation(keyPath: \.settingsTab) {}
        withMutation(keyPath: \.pendingPop) {}
        withMutation(keyPath: \.arrivalFade) {}
        withMutation(keyPath: \.sectionLeaving) {}
        commitHandler()
    }

    /// The run arrives in the window from outside it (带我去 from the notch): its page comes in on
    /// the open spring with the notch's content entrance, whatever the drill style.
    func arrive(atRun id: String) {
        guard let run = index.runByID[id], let project = index.project(of: run), let thread = index.thread(of: run) else { return }
        // The page in view leaves on the content curve, then the run's page comes in: the same
        // out-then-in as a section switch, so the two pages are never read together and there
        // is no blank beat between them.
        sectionSwitch?.cancel()
        commitHandler()
        sectionLeaving = true
        sectionSwitch = Task { @MainActor [weak self] in
            guard let self else { return }
            // The page in view starts leaving now; the next one's fade-in carries its own short
            // delay (ContentArea), so no wait here beyond the frame below.
            guard !Task.isCancelled else { return }
            self.batch {
                self.transition = nil
                self.pendingPop = nil
                self.correction = nil
                self.state.onboarding = nil
                self.state.section = .project
                self.state.projectPath = [PathEntry(level: .projects),
                                          PathEntry(level: .project(project.id), sourceKey: "project/\(project.id)"),
                                          PathEntry(level: .run(id), sourceKey: "run/\(thread.id)/\(id)")]
            }
            try? await Task.sleep(for: .milliseconds(20))
            guard !Task.isCancelled else { return }
            self.sectionLeaving = false
        }
    }

    /// Opens where something lives: a project, a thread's project, a run, a capture.
    func jump(toRun id: String, highlight: Bool = true) {
        guard let run = index.runByID[id], let project = index.project(of: run) else { return }
        go([PathEntry(level: .projects), PathEntry(level: .project(project.id), sourceKey: "project/\(project.id)")], section: .project) {
            if highlight { self.flash("run/\(run.threadID)/\(id)") }
        }
    }

    func jump(toProject id: String) {
        go([PathEntry(level: .projects)], section: .project) { self.flash("project/\(id)") }
    }

    func jump(toThread id: String) {
        guard let thread = index.threadByID[id] else { return }
        go([PathEntry(level: .projects), PathEntry(level: .project(thread.projectID), sourceKey: "project/\(thread.projectID)")], section: .project) {
            self.flash("thread/\(id)")
        }
    }

    func jump(toCapture id: String) {
        go([PathEntry(level: .captures)], section: .capture) { self.flash("capture/\(id)") }
    }

    func flash(_ key: String) {
        highlight = Highlight(key: key)
    }

    /// `--route projects/p-site`, `run/r-bullets`, `captures`, `capture/c-site-shot`
    func apply(route: String) {
        let parts = route.split(separator: "/", maxSplits: 1).map(String.init)
        switch (parts.first, parts.count > 1 ? parts[1] : nil) {
        case ("projects", let id?):
            show([PathEntry(level: .projects), PathEntry(level: .project(id), sourceKey: "project/\(id)")], section: .project)
        case ("projects", nil): show([PathEntry(level: .projects)], section: .project)
        case ("run", let id?):
            if let run = index.runByID[id], let project = index.project(of: run) {
                show([PathEntry(level: .projects), PathEntry(level: .project(project.id), sourceKey: "project/\(project.id)"),
                      PathEntry(level: .run(id), sourceKey: "run/\(run.threadID)/\(id)")], section: .project)
            }
        case ("captures", nil): show([PathEntry(level: .captures)], section: .capture)
        case ("capture", let id?):
            show([PathEntry(level: .captures), PathEntry(level: .capture(id), sourceKey: "capture/\(id)")], section: .capture)
        case ("onboarding", let step?):
            state.onboarding = OnboardingStep(rawValue: step)
        default: break
        }
    }

    // MARK: Folds (one open at a time)

    func toggleFold(_ key: String) {
        let opening = openFold != key
        if opening, openFold != nil, v(InlineSequence.self) == .sequence {
            animate(.collapse) { openFold = nil }
            Task { @MainActor in
                await motion.sleep(BenchTokens.MotionValues.collapse)
                animate(.expand) { openFold = key }
            }
        } else {
            animate(opening ? .expand : .collapse) { openFold = opening ? key : nil }
        }
    }

    // MARK: Search

    func closeSearchResults() {
        guard search.presented else { return }
        animate(.close) { search.presented = false }
    }

    var searchHits: [SearchHit] { SearchEngine.search(search.query, in: index) }

    func open(_ hit: SearchHit) {
        // The field closes and forgets the query: no recent searches are kept. The results fade
        // out showing what they showed (they hold their own query). Under Reduce Motion: a cut.
        if motion.reduce {
            batch { search = SearchUI() }
        } else {
            animate(.close) { search = SearchUI() }
        }
        switch hit.scope {
        case .projects: jump(toProject: hit.targetID)
        case .threads: jump(toThread: hit.targetID)
        case .runs: jump(toRun: hit.targetID)
        case .captures: jump(toCapture: hit.targetID)
        }
    }

    // MARK: Settings

    func openSettings(_ tab: SettingsTab) {
        settingsTab = tab
        openSettingsHandler(tab)
    }
}

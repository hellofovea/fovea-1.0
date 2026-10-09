import SwiftUI
import WindowBenchCore

/// A merge, kept so Undo can put things back exactly.
struct MergeRecord: Equatable {
    var suggestion: MergeSuggestion
    var removed: Project
    var keptName: String
    var movedThreads: [String]
}

struct RunStateItem: Identifiable {
    let id: String
    let title: String
}

/// The panel's Go to and Play. Go to puts a state on screen without motion; Play sets the
/// state before a change without motion, then makes the change through the Motion layer, so
/// every replay starts from the same place.
extension BenchModel {
    static let runStates: [RunStateItem] = [
        RunStateItem(id: "r-bullets", title: "Code · 2nd attempt · ▲"),
        RunStateItem(id: "r-ears", title: "Code · two ▲"),
        RunStateItem(id: "r-notes", title: "Text"),
        RunStateItem(id: "r-photo", title: "Image"),
        RunStateItem(id: "r-review", title: "Result in Calendar"),
        RunStateItem(id: "r-hero", title: "Running"),
        RunStateItem(id: "r-deploy", title: "Waiting · a permission"),
        RunStateItem(id: "r-email", title: "Waiting · a question"),
        RunStateItem(id: "r-rate", title: "Failed"),
        RunStateItem(id: "r-dark", title: "Unobserved"),
    ]

    // MARK: Go to

    func goTo(onboarding step: OnboardingStep) {
        batch {
            playTask(nil)
            show([PathEntry(level: .projects)], section: .project)
            search = SearchUI()
            mergeIndex = 0
            dismissedMerges = []
            lastMerge = nil
            handoffTip = false
            state.onboarding = step
            switch step {
            case .consent, .nothingFound:
                scan = ScanCounts()
                revealed = 0
            case .scanning:
                revealed = 0
                scan = scanCounts(at: 0.58)
            case .reveal, .merge, .handoff:
                scan = scanTargets
                revealed = Int.max
                if step == .handoff { showHandoffTip() }
            }
        }
    }

    func finishOnboarding() {
        playTask(nil)
        animate(.close) { state.onboarding = nil }
        revealed = Int.max
        handoffTip = false
        notchCard = nil
    }

    func goToProject(_ id: String) {
        batch {
            state.onboarding = nil
            revealed = Int.max
            show([PathEntry(level: .projects), PathEntry(level: .project(id), sourceKey: "project/\(id)")], section: .project)
        }
    }

    func goToRun(_ id: String) {
        batch {
            state.onboarding = nil
            revealed = Int.max
            apply(route: "run/\(id)")
        }
    }

    func goToOlderOpen() {
        batch {
            state.onboarding = nil
            show([PathEntry(level: .projects)], section: .project)
            openFold = "older"
        }
    }

    func goToSearch(_ text: String?) {
        batch {
            state.onboarding = nil
            search.expanded = true
            if let text {
                search.query.text = text
                search.presented = true
            }
        }
    }

    func goToCapture(_ id: String) {
        batch {
            state.onboarding = nil
            show([PathEntry(level: .captures), PathEntry(level: .capture(id), sourceKey: "capture/\(id)")], section: .capture)
        }
    }

    // MARK: Onboarding flow

    /// A history folder the scan couldn't list, and why (the real scan's, or the fixture's).
    func readError(folder: String, of agent: AgentKind) -> FolderReadError? {
        if state.source == .thisMac { return scanSummary?.readErrors[folder] }
        return library.agents.first { $0.kind == agent }?.historyReadErrors[folder]
    }

    /// Every folder the scan couldn't list, in the agents' order.
    var readErrors: [(folder: String, error: FolderReadError)] {
        let agents = library.agents.isEmpty ? BenchFixtures.agents() : library.agents
        return agents.flatMap { agent in
            agent.historyFolders.compactMap { folder in readError(folder: folder, of: agent.kind).map { (folder, $0) } }
        }
    }

    /// What the scan ends on, from the library (or the real scan).
    var scanTargets: ScanCounts {
        if state.source == .thisMac, let summary = scanSummary {
            return ScanCounts(sessions: summary.sessions, agents: summary.agents.count, projects: summary.projects.count,
                              progress: 1, perAgent: summary.perAgent)
        }
        // Fixtures: sessions per agent in proportion to its runs, three sessions a run.
        var perAgent: [AgentKind: Int] = [:]
        for run in library.runs { if let agent = index.thread(of: run)?.agent { perAgent[agent, default: 0] += 3 } }
        return ScanCounts(sessions: perAgent.values.reduce(0, +), agents: perAgent.count, projects: library.projects.count,
                          progress: 1, perAgent: perAgent)
    }

    /// The counts at `p` (0…1) of the way through the scan: each agent's rows fill in, the line
    /// adds them up, so the two never disagree.
    func scanCounts(at p: Double) -> ScanCounts {
        let target = scanTargets
        let eased = 1 - pow(1 - p, 2)
        var perAgent: [AgentKind: Int] = [:]
        for (agent, n) in target.perAgent { perAgent[agent] = Int((Double(n) * eased).rounded(.down)) }
        if p >= 1 { perAgent = target.perAgent }
        return ScanCounts(sessions: perAgent.values.reduce(0, +), agents: perAgent.values.filter { $0 > 0 }.count,
                          projects: p >= 1 ? target.projects : Int(Double(target.projects) * pow(p, 1.4)),
                          progress: p, perAgent: perAgent)
    }

    /// Read my history: scan, reveal, then the merge suggestions one at a time, then the hand-off.
    func startScan(after delay: Double = 0) {
        playTask { [weak self] in
            guard let self else { return }
            if delay > 0 { await self.motion.sleep(delay) }
            if Task.isCancelled { return }
            self.batch {
                self.scan = ScanCounts()
                self.revealed = 0
            }
            // The consent becomes the scan in place: its buttons fade, the counts come in.
            self.animate(.open) { self.state.onboarding = .scanning }
            if self.state.source == .thisMac { self.scanSummary = await self.scanHandler() }
            let V = BenchTokens.MotionValues.self
            let steps = Int(V.scanDuration / V.scanTick)
            for i in 1...steps {
                if Task.isCancelled { return }
                let p = Double(i) / Double(steps)
                withAnimation(self.motion.animation(.swap)) { self.scan = self.scanCounts(at: p) }
                await self.motion.sleep(V.scanTick)
            }
            await self.reveal()
        }
    }

    /// Projects arrive one by one into the list.
    func reveal() async {
        batch {
            revealed = 0
            revealToken = UUID()
        }
        // The panel leaves, then the list's head comes in (both carry their own animation).
        animate(.content) { state.onboarding = .reveal }
        // The counts line settles at the list's head before any row moves.
        await motion.sleep(0.3)
        let count = library.projects.count
        let interval = state.revealStaggerMS / 1000
        if v(RevealStyle.self) == .allAtOnce || motion.reduce {
            animate(.content) { revealed = Int.max }
        } else {
            for i in 1...max(1, count) {
                if Task.isCancelled { return }
                animate(.open) { revealed = i }
                await motion.sleep(interval)
            }
            revealed = Int.max
        }
        await motion.sleep(0.6)
        if !pendingMerges.isEmpty {
            animate(.open) { state.onboarding = .merge }
        } else {
            animate(.open) { state.onboarding = .handoff }
            showHandoffTip()
        }
    }

    var pendingMerges: [MergeSuggestion] {
        library.merges.filter { !dismissedMerges.contains($0.id) && index.projectByID[$0.first] != nil && index.projectByID[$0.second] != nil }
    }

    var inlineMerge: MergeSuggestion? {
        state.onboarding == .merge && v(MergeStyle.self) == .inline ? pendingMerges.first : nil
    }

    var bannerMerge: MergeSuggestion? {
        state.onboarding == .merge && v(MergeStyle.self) == .banner ? pendingMerges.first : nil
    }

    func merge(_ suggestion: MergeSuggestion) {
        guard let removed = index.projectByID[suggestion.second] else { return }
        let moved = library.threads.filter { $0.projectID == suggestion.second }.map(\.id)
        animate(.collapse) {
            for i in library.threads.indices where library.threads[i].projectID == suggestion.second {
                library.threads[i].projectID = suggestion.first
            }
            library.projects.removeAll { $0.id == suggestion.second }
            dismissedMerges.insert(suggestion.id)
            lastMerge = MergeRecord(suggestion: suggestion, removed: removed,
                                    keptName: index.projectByID[suggestion.first]?.name ?? "", movedThreads: moved)
        }
        afterMerge()
    }

    /// Puts a merged project back exactly as it was.
    func undoMerge() {
        guard let record = lastMerge else { return }
        animate(.expand) {
            if let at = library.projects.firstIndex(where: { $0.id == record.suggestion.first }) {
                library.projects.insert(record.removed, at: at + 1)
            } else {
                library.projects.append(record.removed)
            }
            for i in library.threads.indices where record.movedThreads.contains(library.threads[i].id) {
                library.threads[i].projectID = record.removed.id
            }
            lastMerge = nil
        }
    }

    func keepSeparate(_ suggestion: MergeSuggestion) {
        animate(.collapse) { dismissedMerges.insert(suggestion.id) }
        afterMerge()
    }

    private func afterMerge() {
        guard pendingMerges.isEmpty else { return }
        playTask { [weak self] in
            guard let self else { return }
            await self.motion.sleep(0.35)
            self.animate(.open) { self.state.onboarding = .handoff }
            self.showHandoffTip()
        }
    }

    func skipOnboarding() {
        animate(.swap) { state.onboarding = .nothingFound }
    }

    func showHandoffTip() {
        handoffTip = v(HandoffCue.self) == .notchTip && state.labNotch
        handoffFlown = false
    }

    /// The hand-off line is on screen: the notch answers per the Hand-off switch.
    func handoffCueAppeared() {
        switch v(HandoffCue.self) {
        case .arrow: break
        case .notchTip: handoffTip = state.labNotch
        case .fly:
            guard state.labNotch else { return }
            playTask { [weak self] in
                guard let self else { return }
                await self.motion.sleep(0.5)
                await self.handoffFlightHandler()
                self.handoffFlown = true
            }
        }
    }

    // MARK: Play

    /// A Play from the panel: recorded as a GIF too when the panel's switch says so.
    func runPlay(_ name: String) {
        if recordPlays {
            recordHandler(name)
        } else if let scenario = BenchRecorder.scenarios.first(where: { $0.name == name }) {
            guard let prepare = scenario.prepare else { scenario.run(self); return }
            // The before-state draws first, so the change is seen as a change.
            prepare(self)
            heal()
            playTask { [weak self] in
                try? await Task.sleep(for: .seconds(0.35))
                guard let self, !Task.isCancelled else { return }
                scenario.run(self)
            }
        }
    }

    /// The whole flow from the consent: Read my history, the scan, the reveal.
    func playReveal() {
        if state.fixture == .empty { loadFixture(.typical) }
        goTo(onboarding: .consent)
        startScan(after: 0.6)
    }

    func playDrill() {
        playTask { [weak self] in
            guard let self else { return }
            self.state.onboarding = nil
            self.revealed = Int.max
            self.show([PathEntry(level: .projects)], section: .project)
            await self.motion.sleep(0.35)
            self.drill(into: .project("p-site"), from: "project/p-site")
            await self.motion.sleep(1.5)
            self.back()
        }
    }

    func playCounts() {
        if state.onboarding == .scanning || state.onboarding == .reveal {
            startScan()
            return
        }
        playTask { [weak self] in
            guard let self else { return }
            let run = Run(id: "r-roll", threadID: "t-copy", words: "Roll the counts", state: .seen,
                          evidence: [.edit(FileChange(path: "src/new-file.ts", kind: .added, added: 3, removed: 0))],
                          agentLine: "Done.", started: self.library.now.addingTimeInterval(-60), finished: self.library.now, result: .code)
            self.animate(.swap) { self.library.runs.append(run) }
            await self.motion.sleep(1.4)
            self.animate(.swap) { self.library.runs.removeAll { $0.id == "r-roll" } }
        }
    }

    /// `change` gets the run alone: it must not read the model (the library is being written).
    private func setRun(_ id: String, role: MotionSpec.Role = .swap, _ change: (inout Run) -> Void, arrival: Bool = false) {
        guard let i = library.runs.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(arrival ? motion.arrivalAnimation : motion.animation(role)) {
            change(&library.runs[i])
            if arrival { arrivals.insert(id) } else { arrivals.remove(id) }
        }
    }

    /// r-progress (fovea-mac) asks a question; its project moves to Stuck with the arrival.
    func playArrival() {
        guard let run = index.runByID["r-progress"] else { return }
        if run.state == .waiting {
            setRun("r-progress") { $0.state = .finished; $0.stuck = nil }
            status = "fovea-mac back to To look at"
        } else {
            setRun("r-progress", { $0.state = .waiting; $0.stuck = .question("Use 0.85 for the fill in Dark too?", options: ["Yes", "Use 0.9"]) }, arrival: true)
            status = "fovea-mac arrived in Stuck: waiting for you"
        }
    }

    func playFinish() {
        guard let run = index.runByID["r-hero"] else { return }
        let now = library.now
        if run.state == .running {
            setRun("r-hero", role: .expand) {
                $0.state = .finished
                $0.finished = now
                $0.evidence.append(.command(CommandResult("npm run test:visual")))
                $0.agentLine = "Slowed the hero to 0.6 s and removed the overshoot."
                $0.result = .code
            }
            status = "hero 动效 finished: ○"
        } else {
            setRun("r-hero") { $0.state = .running; $0.finished = nil; $0.agentLine = nil }
            status = "hero 动效 running again"
        }
    }

    func playFail() {
        guard let run = index.runByID["r-rail"] else { return }
        let now = library.now
        if run.state == .running {
            setRun("r-rail", role: .expand) {
                $0.state = .failed
                $0.finished = now
                $0.failure = Failure(command: "swift build", exitCode: 1,
                                     tail: "ChooseChat.swift:331:9: error: cannot find 'chosenDotGap' in scope")
                $0.evidence.append(.command(CommandResult("swift build", exit: 1)))
                $0.result = .code
                $0.output = "swift build\nCompiling FoveaWorkbench ChooseChat.swift\nChooseChat.swift:331:9: error: cannot find 'chosenDotGap' in scope\nerror: build had 1 command failure"
            }
            status = "Choose chat rail failed: !"
        } else {
            setRun("r-rail") { $0.state = .running; $0.failure = nil; $0.finished = nil; $0.result = .none; $0.output = nil }
            status = "Choose chat rail running again"
        }
    }

    /// design-tokens walks through every group.
    func playMove() {
        guard let run = index.runByID["r-dark"] else { return }
        let next: RunState
        switch run.state {
        case .unobserved: next = .running
        case .running: next = .finished
        case .finished: next = .waiting
        case .waiting: next = .failed
        case .failed: next = .seen
        case .seen: next = .unobserved
        }
        state.onboarding = nil
        if path.count > 1 || state.section != .project { show([PathEntry(level: .projects)], section: .project) }
        setRun("r-dark", { $0.state = next }, arrival: next == .waiting)
        status = "design-tokens: \(next.accessibilityLabel)"
    }

    func playFold() {
        if currentLevel != .project("p-site") { goToProject("p-site") }
        toggleFold("earlier/t-copy")
    }

    func playJump() {
        playTask { [weak self] in
            guard let self else { return }
            self.state.onboarding = nil
            self.show([PathEntry(level: .projects)], section: .project)
            // The field opens, then the query is typed into it, then the results come.
            self.animate(.open) { self.search.expanded = true }
            await self.motion.sleep(BenchTokens.MotionValues.open + 0.15)
            self.search.query = SearchQuery(text: "bullets")
            self.animate(.open) { self.search.presented = true }
            await self.motion.sleep(1.1)
            if let hit = self.searchHits.first(where: { $0.targetID == "r-bullets" }) { self.open(hit) }
        }
    }

    /// The guess opens, an alternative is picked, and the line says so in place.
    func playCorrection() {
        if currentLevel != .project("p-site") { goToProject("p-site") }
        playTask { [weak self] in
            guard let self else { return }
            await self.motion.sleep(0.25)
            self.animate(.open) { self.correction = "thread/t-copy" }
            await self.motion.sleep(1.5)
            if let choice = self.index.threadByID["t-copy"]?.routing.alternatives.first {
                self.applyCorrection("thread/t-copy", choice: choice)
            }
        }
    }

    func playTakeMeThere() {
        playTask { [weak self] in
            guard let self else { return }
            self.state.onboarding = nil
            self.show([PathEntry(level: .projects)], section: .project)
            self.notchCard = "r-bullets"
            await self.motion.sleep(1.3)
            await self.flightHandler("r-bullets")
        }
    }

    /// View in Project from a capture's detail; then, from the project, the run's captures link
    /// back to the stream.
    func playCaptureJumps() {
        playTask { [weak self] in
            guard let self else { return }
            self.viewInProject("c-site-shot")
            await self.motion.sleep(1.8)
            self.showCaptures(of: "r-bullets")
        }
    }

    func playCaptureOpen() {
        playTask { [weak self] in
            guard let self else { return }
            self.openCapture("c-site-shot")
            await self.motion.sleep(1.5)
            if self.quickLook != nil {
                self.animate(.close) { self.quickLook = nil }
            } else {
                self.back()
            }
        }
    }

    /// Earlier runs open in one thread, then in another (the first closes as the second opens),
    /// then close.
    func playAccordion() {
        playTask { [weak self] in
            guard let self else { return }
            self.toggleFold("earlier/t-copy")
            await self.motion.sleep(1.1)
            self.toggleFold("earlier/t-hero")
            await self.motion.sleep(1.1)
            self.toggleFold("earlier/t-hero")
        }
    }

    /// A drill turned back halfway: the motion reverses from where it is.
    func playDrillInterrupt() {
        playTask { [weak self] in
            guard let self else { return }
            self.drill(into: .project("p-site"), from: "project/p-site")
            await self.motion.sleep(0.12)
            self.back()
        }
    }

    /// Forget, then Undo, in place.
    func playForget() {
        playTask { [weak self] in
            guard let self else { return }
            self.forget("m-second")
            await self.motion.sleep(1.4)
            self.undoForget()
        }
    }

    /// The capture filters, one after another: the stream cross-fades, nothing slides.
    func playFilters() {
        playTask { [weak self] in
            guard let self else { return }
            for filter in [CaptureKind.screenshot, .voice] {
                self.animate(.swap) { self.captureFilter = filter }
                await self.motion.sleep(1.0)
            }
            self.animate(.swap) { self.captureFilter = nil }
        }
    }

    func playToday() {
        playTask { [weak self] in
            guard let self else { return }
            self.animate(.swap) { self.today.apply(.agents) }
            await self.motion.sleep(1.2)
            self.animate(.swap) { self.today.apply(.meetings) }
        }
    }

    func playBrief() {
        if currentLevel != .project("p-site") { goToProject("p-site") }
        requestBrief("p-site")
    }

    func requestBrief(_ projectID: String) {
        playTask { [weak self] in
            guard let self else { return }
            self.animate(.open) { self.briefs[projectID] = .writing }
            await self.motion.sleep(1.8)
            self.animate(.open) { self.briefs[projectID] = .written }
        }
    }

    // MARK: Data source

    func setSource(_ source: DataSource) {
        state.source = source
        if source == .fixtures {
            scanSummary = nil
            loadFixture(state.fixture)
            return
        }
        playTask { [weak self] in
            guard let self else { return }
            self.status = "Listing history folders…"
            guard let summary = await self.scanHandler() else {
                self.status = "No agent history folders on this Mac"
                return
            }
            self.scanSummary = summary
            self.library = Library(now: Date(), projects: HistoryAggregate.projects(from: summary),
                                   agents: await AgentDetector.detect())
            self.show([PathEntry(level: .projects)], section: .project)
            self.status = "This Mac: \(Lines.scanCounts(sessions: summary.sessions, agents: summary.agents.count, projects: summary.projects.count))"
        }
    }

    // MARK: One scenario at a time

    /// Runs `work` as the only scenario: starting another one cancels it.
    func playTask(_ work: (@MainActor () async -> Void)?) {
        currentPlay?.cancel()
        guard let work else { currentPlay = nil; return }
        currentPlay = Task { @MainActor in await work() }
    }
}

extension BenchModel {
    /// 带我去 in the window: opens the run's session in its agent's app (simulated here).
    func takeMeThere(_ runID: String) {
        guard let run = index.runByID[runID], let thread = index.thread(of: run) else { return }
        status = "Would open \(thread.agent.name) on \(thread.title)"
    }
}

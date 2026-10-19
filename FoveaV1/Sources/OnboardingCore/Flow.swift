import Foundation

/// Something made during practice, kept so the real Home can show it at the end.
public struct PracticeRecord: Equatable, Sendable {
    public enum Kind: String, Sendable { case capture, dispatch, dictation }

    public enum Referent: Equatable, Sendable {
        /// A region dragged over: what it was taken from.
        case region(source: String)
        case wholeScreen
        case passage(text: String, source: String)
        case file(name: String, type: String, folder: String)
    }

    public var kind: Kind
    public var words: String
    public var referents: [Referent]
    /// Dispatch: the agent and the chat it went to.
    public var agent: String?
    public var chat: String?
    public var theme: String
    /// How long before the end of the first run it was made, so the cards read in order.
    public var secondsBeforeEnd: TimeInterval

    public init(kind: Kind, words: String, referents: [Referent] = [], agent: String? = nil, chat: String? = nil,
                theme: String, secondsBeforeEnd: TimeInterval) {
        self.kind = kind; self.words = words; self.referents = referents; self.agent = agent; self.chat = chat
        self.theme = theme; self.secondsBeforeEnd = secondsBeforeEnd
    }
}

/// Oct 18, Ryan: "Choose your languages." English and Chinese, each on or off (one stays on); with
/// both on, one is the primary: Fovea's interface is in it, and it listens in it first. With one
/// on, that one is the primary.
public struct LanguageChoice: Equatable, Sendable {
    /// The ones on, in the hello page's order.
    public private(set) var on: [FoveaLanguage]
    public private(set) var primary: FoveaLanguage

    public init(on: [FoveaLanguage], primary: FoveaLanguage) {
        let chosen = Set(on + [primary])
        self.on = FoveaLanguage.featured.filter(chosen.contains)
        self.primary = primary
    }

    /// As the prefs keep it: the languages (empty means just the primary) and the primary.
    public init(prefs: FoveaPrefs) {
        self.init(on: prefs.languages, primary: prefs.language)
    }

    /// Asks which is primary: only with more than one on.
    public var asksPrimary: Bool { on.count > 1 }

    /// One on or off. The last one stays on; turning off the primary makes the other primary.
    public mutating func toggle(_ language: FoveaLanguage) {
        if on.contains(language) {
            guard on.count > 1 else { return }
            on.removeAll { $0 == language }
            if primary == language, let other = on.first { primary = other }
        } else {
            on = FoveaLanguage.featured.filter { on.contains($0) || $0 == language }
        }
    }

    /// The primary, among the ones on.
    public mutating func setPrimary(_ language: FoveaLanguage) {
        guard on.contains(language) else { return }
        primary = language
    }
}

/// Languages asked for under More… (Oct 17, Ryan, FR-06: more than one). Settings › Language keeps
/// the same rule (FoveaWindow can't see this module; its pane says so where it repeats it).
public enum LanguageRequests {
    /// The list with `typed` added: trimmed, never empty, never twice in any case, never English or
    /// Chinese (Fovea listens in those already).
    public static func adding(_ typed: String, to list: [String]) -> [String] {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return list }
        let lower = name.lowercased()
        let offered = Language.featured.flatMap { [$0.title.lowercased(), $0.nativeName.lowercased()] }
        guard !offered.contains(lower), !list.contains(where: { $0.lowercased() == lower }) else { return list }
        return list + [name]
    }

    public static func removing(_ language: String, from list: [String]) -> [String] {
        list.filter { $0.lowercased() != language.lowercased() }
    }
}

/// The first run's progress: the step, what it has seen in it, and what carries across steps
/// (the keys learned, what's allowed, the agents found, the practice made). Beats count only in
/// order, so a try finished before its picture was taken doesn't pass; the app sees that as
/// `missedBeat` and offers the try again.
public struct Flow: Equatable, Sendable {
    public private(set) var step: Step
    public private(set) var done: [Beat] = []
    /// A beat that came early: the step's try went wrong and should start over.
    public private(set) var missedBeat: Beat?
    public private(set) var learned: Set<KeyName> = []
    public private(set) var allowed: Set<Permission> = []
    public var language: Language = .english
    /// The email signed in with, and the name to be called by (the first two steps).
    public var email: String?
    public var name: String?
    /// How the person signed up: Apple, Google or an email (Oct 15 review, AC-01.1). Nil until done.
    public var account: AccountProvider?
    /// Languages typed under More… (Oct 9): kept as requests, not listened in yet. Oct 17, Ryan
    /// (FR-06): as many as the person types, one at a time, each removable; kept in
    /// `FoveaPrefs.requestedLanguages`, which Settings › Language shows too.
    public private(set) var languageRequests: [String] = []

    /// A language typed under More… and Return pressed: added, unless it's empty, already asked for
    /// (in any case) or one Fovea already listens in. Returns whether it was added.
    @discardableResult
    public mutating func requestLanguage(_ typed: String) -> Bool {
        let next = LanguageRequests.adding(typed, to: languageRequests)
        guard next != languageRequests else { return false }
        languageRequests = next
        return true
    }

    public mutating func dropLanguageRequest(_ language: String) {
        languageRequests = LanguageRequests.removing(language, from: languageRequests)
    }

    /// The requests as kept (the prefs, at the start), tidied the same way.
    public mutating func setLanguageRequests(_ list: [String]) {
        languageRequests = list.reduce([]) { LanguageRequests.adding($1, to: $0) }
    }
    /// The accent and the aura, chosen in `makeItYours`.
    public var personal = Personalization()
    public private(set) var agents: [Agent] = []
    /// The coding agents were connected (Oct 9: right after the permissions).
    public private(set) var agentsConnected = false
    /// The agents asked for next (Oct 9: to help choose what to build).
    public var agentWishes: [String] = []
    /// The microphone test has heard a voice.
    public private(set) var heardOnce = false
    public private(set) var dictationSkipped = false
    /// Words brought in from another dictation app, at the end.
    public private(set) var imported = 0
    public private(set) var records: [PracticeRecord] = []
    public private(set) var finished = false

    /// Oct 15 review, OB-01.7: a page seen in this run, and what it had seen when it was left, so
    /// Back returns to it as it was.
    public struct Visit: Equatable, Sendable {
        public var step: Step
        public var done: [Beat]
    }
    /// The pages seen before this one, oldest first (Back's way).
    public private(set) var history: [Visit] = []
    /// This page was come back to with Back: it's done already, and goes on with Continue.
    public private(set) var revisited = false
    /// Oct 15 review, OB-03.1: one practice run again from Home, these steps only; past the last, the
    /// run is over.
    public private(set) var only: [Step]?

    public init(start: Step = .name, only: [Step]? = nil) {
        step = start
        self.only = only
    }

    // MARK: What the step has seen

    /// The beat groups not yet met, in order.
    public var remaining: [Set<Beat>] {
        Array(step.beats.dropFirst(metCount))
    }

    /// The group the step is waiting on now: the guide lights it.
    public var waitingFor: Set<Beat>? { remaining.first }

    public var isComplete: Bool { metCount == step.beats.count }

    /// Done and total, for a step's own checklist.
    public var progress: (done: Int, total: Int) { (metCount, step.beats.count) }

    private var metCount: Int {
        var count = 0
        for group in step.beats {
            guard done.contains(where: { group.contains($0) }) else { break }
            count += 1
        }
        return count
    }

    /// The person did something. It counts if it meets the group the step is waiting on (or, for a
    /// step's any-order beats, any group still owed); a beat from a later group, arriving early,
    /// marks the try as missed.
    @discardableResult
    public mutating func record(_ beat: Beat) -> Bool {
        switch beat {
        case .allowedAccessibility: allowed.insert(.accessibility)
        case .allowedMicrophone: allowed.insert(.microphone)
        case .allowedScreenRecording: allowed.insert(.screenRecording)
        case .heard: heardOnce = true
        case .agentsConnected: agentsConnected = true
        default: break
        }
        guard let waiting = waitingFor else { return false }
        // An any-order beat already made, made again (the button dragged twice): nothing new, and
        // nothing wrong either.
        if step.anyOrder.contains(beat), done.contains(beat) { return false }
        if waiting.contains(beat) {
            done.append(beat)
            missedBeat = nil
            return true
        }
        // Beats the step takes in any order count when they come, as long as one is still owed.
        if step.anyOrder.contains(beat), !done.contains(beat), remaining.contains(where: { $0.contains(beat) }) {
            done.append(beat)
            missedBeat = nil
            return true
        }
        if remaining.dropFirst().contains(where: { $0.contains(beat) }) {
            missedBeat = beat
        }
        return false
    }

    /// Starts the step's try over: the bar was closed, or a beat came early.
    public mutating func retry() {
        done.removeAll()
        missedBeat = nil
    }

    public mutating func allow(_ permission: Permission) {
        allowed.insert(permission)
        switch permission {
        case .accessibility: record(.allowedAccessibility)
        case .microphone: record(.allowedMicrophone)
        case .screenRecording: record(.allowedScreenRecording)
        // Oct 15 review, OB-01.5: asked for, never waited on.
        case .automation, .inputMonitoring: break
        }
    }

    public mutating func found(_ agents: [Agent]) {
        self.agents = agents
    }

    public mutating func add(_ record: PracticeRecord) {
        records.append(record)
    }

    /// Words imported at the end, from another dictation app.
    public mutating func importWords(_ count: Int) {
        imported += max(0, count)
    }

    // MARK: Moving on

    /// Moves to the next step once this one is met (or waits for nothing). Returns the new step,
    /// or nil when the first run is over.
    @discardableResult
    public mutating func advance() -> Step? {
        guard isComplete else { return nil }
        learned.formUnion(step.keys)
        return move(to: following(step))
    }

    /// Passes over a step that allows it. Skipping dictation skips all of it, on to the end
    /// (which starts with bringing your words).
    @discardableResult
    public mutating func skip() -> Step? {
        guard step.skip.allowed else { return nil }
        if step.stage == .dictation {
            dictationSkipped = true
            return move(to: .dictionary)
        }
        return move(to: following(step))
    }

    // MARK: Going back (Oct 15 review, OB-01.7 and FR-05)

    /// Where Back goes from here, if anywhere: the step seen before this one, or, in a run picked up
    /// part way, the step before it in order; a step that waits on an earlier one's session lands on
    /// the step that makes it (`Step.backLanding`). In a practice run again from Home, only within
    /// its own steps: nothing before its first (Oct 17, Ryan).
    public var backTarget: Step? {
        guard step.hasBack else { return nil }
        let target: Step?
        if let visit = history.last {
            target = visit.step.backLanding
        } else if only == nil {
            target = step.previous?.backLanding
        } else {
            target = nil
        }
        guard let target, target != step, only?.contains(target) ?? true else { return nil }
        return target
    }

    public var canGoBack: Bool { backTarget != nil }

    /// Back to the step before. A page to read (or the permissions, the microphone) as it was left:
    /// what was entered stays, and a page that was done is done, so Continue goes on from it. A
    /// practice task, or dictation, starts again from its beginning (Oct 17, Ryan): the app puts
    /// back what it made (OnboardingModel.startOver).
    @discardableResult
    public mutating func back() -> Step? {
        guard let target = backTarget else { return nil }
        var restored: [Beat] = []
        if let i = history.lastIndex(where: { $0.step == target }) {
            restored = history[i].done
            history.removeSubrange(i...)
        }
        step = target
        missedBeat = nil
        finished = false
        if target.restartsOnBack {
            done = []
            revisited = false
            if target.stage == .dictation { dictationSkipped = false }
            return target
        }
        // What carries across steps says it's done too (a permission allowed since, the agents).
        for beat in settledBeats(target) where !restored.contains(beat) { restored.append(beat) }
        done = restored
        revisited = true
        return target
    }

    /// The beats a step has met by what's kept across steps.
    private func settledBeats(_ step: Step) -> [Beat] {
        switch step {
        case .name: name == nil ? [] : [.named]
        case .signIn: account == nil ? [] : [.signedIn]
        case .permissions:
            (allowed.contains(.accessibility) ? [.allowedAccessibility] : [])
                + (allowed.contains(.screenRecording) ? [.allowedScreenRecording] : [])
        case .microphone: allowed.contains(.microphone) && heardOnce ? [.allowedMicrophone, .heard] : []
        case .agents: agentsConnected ? [.agentsConnected] : []
        default: []
        }
    }

    /// How far the run is, 0 to 1: the steps done, and the part of this one. A practice run again
    /// counts only its own steps.
    public var fraction: Double {
        let within = step.beats.isEmpty ? 0 : min(0.99, Double(metCount) / Double(step.beats.count))
        if let only {
            guard let i = only.firstIndex(of: step) else { return 0 }
            return min(1, (Double(i) + within) / Double(only.count))
        }
        let all = Step.allCases
        guard let i = all.firstIndex(of: step), all.count > 1 else { return 0 }
        return min(1, (Double(i) + within) / Double(all.count - 1))
    }

    /// The control panel's jump: any step, its beats cleared. Earlier steps' permissions count as
    /// allowed (and the agents connected), so a jump past them doesn't ask again.
    public mutating func jump(to target: Step) {
        let order = Step.allCases
        if let i = order.firstIndex(of: target) {
            for earlier in order[..<i] {
                switch earlier {
                case .permissions: allowed.formUnion([.accessibility, .screenRecording])
                case .microphone: allowed.insert(.microphone); heardOnce = true
                case .agents: agentsConnected = true
                default: break
                }
            }
        }
        finished = false
        step = target
        history = []
        revisited = false
        retry()
        showAllowed()
    }

    /// The step after `step`, past what's already been settled: a permission already allowed, the
    /// agents already connected.
    private func following(_ step: Step) -> Step? {
        var next = step.next
        while let candidate = next, settled(candidate) { next = candidate.next }
        return next
    }

    private func settled(_ step: Step) -> Bool {
        switch step {
        // Oct 17, Ryan (round 2): the permissions page is never passed over, even with everything
        // allowed already: the person sees each one and goes on with Continue.
        case .permissions: false
        // The microphone step is also its test: it's settled only once it has heard you.
        case .microphone: allowed.contains(.microphone) && heardOnce
        case .agents: agentsConnected
        default: false
        }
    }

    private mutating func move(to next: Step?) -> Step? {
        // A practice run again ends past its own steps (Oct 15 review, OB-03.1).
        guard let next, only?.contains(next) ?? true else {
            finished = true
            return nil
        }
        history.append(Visit(step: step, done: done))
        revisited = false
        step = next
        retry()
        showAllowed()
        return next
    }

    /// Oct 17, Ryan (round 2): the permissions page shows what's allowed already as allowed (and
    /// so is done, for Continue), never passing over itself.
    private mutating func showAllowed() {
        guard step == .permissions else { return }
        for beat in settledBeats(.permissions) where !done.contains(beat) { done.append(beat) }
    }
}

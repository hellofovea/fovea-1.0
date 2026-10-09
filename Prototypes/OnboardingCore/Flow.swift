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
    /// A language typed under More… (Oct 9): kept as a request, not listened in yet.
    public var languageRequest: String?
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

    public init(start: Step = .hello) {
        step = start
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
        case .automation: break
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
        retry()
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
        case .permissions: allowed.isSuperset(of: [.accessibility, .screenRecording])
        // The microphone step is also its test: it's settled only once it has heard you.
        case .microphone: allowed.contains(.microphone) && heardOnce
        case .agents: agentsConnected
        default: false
        }
    }

    private mutating func move(to next: Step?) -> Step? {
        guard let next else {
            finished = true
            return nil
        }
        step = next
        retry()
        return next
    }
}

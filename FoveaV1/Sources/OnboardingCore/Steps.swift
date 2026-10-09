import Foundation

// Fovea's first run, as data: the stages, the steps in each, and what every step waits for.
// Pure, so the order and the rules can be tested without a screen (Tests/OnboardingCoreTests).
// docs/onboarding/ONBOARDING.md is the design this follows.

/// The six stages (Oct 9): hello, the permissions, the agents, two real tasks, dictation, and the
/// end. Dictation can be skipped whole.
public enum Stage: Int, CaseIterable, Sendable {
    case arrive, turnOn, agents, pointAndSay, dictation, home

    public var title: String {
        switch self {
        case .arrive: "Hello"
        case .turnOn: "Turn things on"
        case .agents: "Your agents"
        case .pointAndSay: "Point and send"
        case .dictation: "Dictation"
        case .home: "Finish"
        }
    }
}

/// One screen's worth of the first run. Oct 9 merged Accessibility and Screen Recording into one
/// step, put connecting the coding agents right after the permissions (the tasks send to them for
/// real), and gave the practice two tasks that do something: the weekly update at work, gathered
/// from three tabs and a chat, and your packing list. No sign-in after the agents, and no demo
/// before the tasks: you learn by doing (Oct 9, round two).
public enum Step: String, CaseIterable, Sendable, Codable {
    case hello, makeItYours
    case permissions, microphone
    case agents
    case weeklyUpdate, hover, packList, followUp
    case dictationIntro, dictation
    case dictionary, home

    public var stage: Stage {
        switch self {
        case .hello, .makeItYours: .arrive
        case .permissions, .microphone: .turnOn
        case .agents: .agents
        case .weeklyUpdate, .hover, .packList, .followUp: .pointAndSay
        case .dictationIntro, .dictation: .dictation
        case .dictionary, .home: .home
        }
    }

    /// What the step waits for, in order. Each entry is a set of alternatives: any one of them
    /// does. Steps that wait for none move on with Continue.
    public var beats: [Set<Beat>] {
        switch self {
        case .hello, .makeItYours, .dictationIntro, .dictionary, .home: []
        // Two lists, one drag each (Oct 9: granted together).
        case .permissions: [[.allowedAccessibility], [.allowedScreenRecording]]
        // Allowed, then heard: the person has to say the line before it counts (Oct 8).
        case .microphone: [[.allowedMicrophone], [.heard]]
        case .agents: [[.agentsConnected]]
        // The weekly update: the whole screen (the ask and the chart), the merged pull requests from
        // one tab and the open tickets from another, then the words, then return.
        case .weeklyUpdate: [[.requestKey], [.wholeScreen], [.prs], [.tickets], [.finish], [.review], [.send]]
        // While the agent works: the notch, and its answer, in either order.
        case .hover: [[.hoverNotch], [.answer]]
        // The everyday task: the line about the snow and the packing list.
        case .packList: [[.requestKey], [.passage], [.file], [.finish], [.review], [.send], [.answer]]
        case .followUp: [[.followKey], [.followAnswer]]
        // Two windows: the feedback first, then Messages (Oct 9).
        case .dictation: [[.feedbackKey], [.feedbackLanded], [.replyKey], [.replyLanded]]
        }
    }

    /// Beats a step takes in any order (they still all have to happen). The keyboard teaches them
    /// in the order of `beats`: the whole screen (⌘ twice) before each part (⌘ once).
    public var anyOrder: Set<Beat> {
        switch self {
        // The lists are shown in turn, but either allowed first counts.
        case .permissions: [.allowedAccessibility, .allowedScreenRecording]
        case .weeklyUpdate: [.wholeScreen, .prs, .tickets]
        case .hover: [.hoverNotch, .answer]
        case .packList: [.passage, .file]
        default: []
        }
    }

    /// Every step has a way past it, in case something fails (Oct 8): Skip appears after a while,
    /// or at once where there's nothing to fail. Hello, Make it yours and Home always go on.
    public var skip: Skip {
        switch self {
        case .hello, .makeItYours, .home: .never
        case .dictationIntro, .dictation, .dictionary: .now
        case .permissions, .agents: .after(8)
        case .microphone, .hover: .after(10)
        case .followUp: .after(12)
        case .weeklyUpdate, .packList: .after(15)
        }
    }

    /// The keys a step teaches.
    public var keys: [KeyName] {
        switch self {
        case .weeklyUpdate: [.request, .screenshot, .send]
        case .packList: [.request, .highlighter, .send]
        case .followUp, .dictationIntro, .dictation: [.dictation]
        default: []
        }
    }

    /// The whole keyboard is up while keys are taught (Oct 9: "at all times" there, and only there:
    /// pressing a key elsewhere doesn't bring it up): the tasks and dictation.
    public var showsKeyboard: Bool {
        switch stage {
        case .pointAndSay, .dictation: true
        default: false
        }
    }

    /// Steps for reading, where the board holds the eye; the rest are for doing, and the screen is
    /// the person's.
    public var isReading: Bool { [.hello, .makeItYours, .agents, .dictationIntro, .dictionary, .home].contains(self) }

    /// The step after this one, before any skipping.
    public var next: Step? {
        let all = Step.allCases
        guard let i = all.firstIndex(of: self), i + 1 < all.count else { return nil }
        return all[i + 1]
    }
}

public enum Skip: Equatable, Sendable {
    case never
    case now
    case after(TimeInterval)

    public var allowed: Bool { self != .never }
}

/// Something the person did that a step can be waiting for. Pressing a capture key isn't one:
/// ⌘ and ⌥ only arm what comes next (the first ⌘ of a double press would otherwise count early).
public enum Beat: String, CaseIterable, Sendable, Codable {
    case allowedAccessibility, allowedMicrophone, allowedScreenRecording
    /// The microphone test heard a voice.
    case heard
    /// The coding agents on this Mac are connected.
    case agentsConnected
    /// fn ⌃ opened the voice bar.
    case requestKey
    /// ⌘ twice: the whole screen.
    case wholeScreen
    /// ⌘ once and a drag, in the GitHub tab: the pull requests merged this week.
    case prs
    /// ⌘ once and a drag, in the Support tab: the open tickets.
    case tickets
    /// Left ⌥ and a drag across words.
    case passage
    /// Left ⌥ and a click on a file.
    case file
    /// fn ⌃ pressed again: the words are being transcribed.
    case finish
    /// The request shows on the review card.
    case review
    case send
    case answer
    case hoverNotch
    case followKey
    case followAnswer
    /// Dictation into the feedback window, then into Messages: fn, then the words landing.
    case feedbackKey, feedbackLanded
    case replyKey, replyLanded

    /// The tab a part of the screen is taken from (Oct 9: gathering from different tabs).
    public var tab: PracticeTab? {
        switch self {
        case .prs: .github
        case .tickets: .support
        default: nil
        }
    }
}

/// The browser's tabs in practice: the weekly update's three, and the trail report for the trip.
public enum PracticeTab: String, CaseIterable, Sendable, Codable {
    case analytics, github, support, trail

    public var title: String {
        switch self {
        case .analytics: "Analytics"
        case .github: "GitHub"
        case .support: "Support"
        case .trail: "Trail report"
        }
    }

    /// The page's address, as the browser shows it.
    public var address: String {
        switch self {
        case .analytics: "insights.northwind.app"
        case .github: "github.com/northwind/app/pulls"
        case .support: "support.northwind.app"
        case .trail: "trailreport.example/high-valleys"
        }
    }

    /// The tabs open for a step: the work tabs, then the trip's added beside them.
    public static func open(for step: Step) -> [PracticeTab] {
        switch step {
        case .packList, .followUp: [.analytics, .github, .support, .trail]
        default: [.analytics, .github, .support]
        }
    }
}

/// The keys the first run teaches. Their labels come from `KeyMap`, so a change of keys changes
/// the copy in one place.
public enum KeyName: String, CaseIterable, Sendable, Codable {
    case request, screenshot, highlighter, send, dictation
}

/// The keys as the Notch Workbench has them after the Oct 6 decisions (round two): ⌘ takes a
/// screenshot (twice, the whole screen), left ⌥ is the highlighter. Settings › Shortcuts in Fovea
/// Captures and AMENDMENTS.md:75-77 still show round one; this table is the one place to change.
public struct KeyMap: Equatable, Sendable {
    public var request: [String]
    public var screenshot: [String]
    public var highlighter: [String]
    public var send: [String]
    public var dictation: [String]

    public init(request: [String] = ["fn", "⌃"], screenshot: [String] = ["⌘"], highlighter: [String] = ["⌥"],
                send: [String] = ["return"], dictation: [String] = ["fn"]) {
        self.request = request; self.screenshot = screenshot; self.highlighter = highlighter
        self.send = send; self.dictation = dictation
    }

    public static let current = KeyMap()

    public func caps(_ key: KeyName) -> [String] {
        switch key {
        case .request: request
        case .screenshot: screenshot
        case .highlighter: highlighter
        case .send: send
        case .dictation: dictation
        }
    }

    /// The key's name in a sentence: "fn ⌃", "⌘".
    public func spoken(_ key: KeyName) -> String { caps(key).joined(separator: " ") }

    /// The keys to press for what a step waits on now, as the keyboard labels them: only these
    /// light, in turn (Oct 9). A capture key already armed is the app's to clear (then it's a drag
    /// or a click, and nothing lights).
    public func keys(for beat: Beat) -> [String] {
        switch beat {
        case .requestKey, .finish: request
        case .wholeScreen, .prs, .tickets: screenshot
        case .passage, .file: highlighter
        case .send: send
        case .followKey, .followAnswer, .feedbackKey, .feedbackLanded, .replyKey, .replyLanded: dictation
        default: []
        }
    }

    /// How many presses it takes: the whole screen is ⌘ twice, shown as "×2" on the key (Oct 9).
    public func presses(for beat: Beat) -> Int {
        beat == .wholeScreen ? 2 : 1
    }
}

/// The permissions the first run asks for. Speech Recognition is gone and Automation joins
/// (docs/window/FEEDBACK_2026-10-06.md, rows 3–5); Automation is only for handing words to Terminal.
public enum Permission: String, CaseIterable, Sendable, Codable {
    case accessibility, microphone, screenRecording, automation

    /// The pane's name as macOS 27 writes it.
    public var paneName: String {
        switch self {
        case .accessibility: "Device Control and Data Access"
        case .microphone: "Microphone"
        case .screenRecording: "Screen & System Audio Recording"
        case .automation: "Automation"
        }
    }

    /// What it's for, in a few words (Oct 9: "shorter terms").
    public var purpose: String {
        switch self {
        case .accessibility: "Your hotkeys, in any app."
        case .microphone: "So Fovea hears you."
        case .screenRecording: "Only what you point at."
        case .automation: "So Fovea can hand your words to Terminal."
        }
    }
}

/// The language Fovea listens in. Oct 9: English and Chinese only; any other is typed under More…
/// and kept as a request, for the languages to add next.
public enum Language: String, CaseIterable, Sendable, Codable {
    case english, chinese

    public var title: String { rawValue.capitalized }

    /// On the hello board's row, before More….
    public static let featured: [Language] = [.english, .chinese]

    /// What to start on: Chinese for a Mac that reads Chinese first, English otherwise.
    public static func preferred(_ identifiers: [String]) -> Language {
        identifiers.first?.lowercased().hasPrefix("zh") == true ? .chinese : .english
    }
}

/// The coding agents Fovea sends to (Oct 9: Claude Code and Codex, and more to come).
public enum Agent: String, CaseIterable, Sendable, Codable {
    case claudeCode, codex, cursor

    public var name: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        case .cursor: "Cursor"
        }
    }

    /// The command-line tool whose presence says it's installed.
    public var command: String {
        switch self {
        case .claudeCode: "claude"
        case .codex: "codex"
        case .cursor: "cursor-agent"
        }
    }

    /// The ones Fovea connects to today; the rest are among what's next.
    public static let supported: [Agent] = [.claudeCode, .codex]

    /// What people can ask for next (Oct 9: "note which agent you want next").
    public static let comingNext = ["Cursor", "Gemini CLI", "GitHub Copilot", "Windsurf", "Amp", "OpenCode"]
}

/// The dictation apps a dictionary can come from (Oct 9). Found by bundle ID or by name in
/// /Applications. Wispr Flow and VoiceOS keep their words on this Mac, so Connect reads them
/// straight from there, when it's clicked and not before (as VoiceOS itself imports from Wispr
/// Flow); Typeless keeps them online, so for it, and the rest, it's a paste or a file.
public enum DictationApp: String, CaseIterable, Sendable {
    case wisprFlow, typeless, voiceOS, superwhisper, macWhisper, textReplacements

    public var name: String {
        switch self {
        case .wisprFlow: "Wispr Flow"
        case .typeless: "Typeless"
        case .voiceOS: "VoiceOS"
        case .superwhisper: "Superwhisper"
        case .macWhisper: "MacWhisper"
        case .textReplacements: "Text Replacements"
        }
    }

    public var bundleIDs: [String] {
        switch self {
        case .wisprFlow: ["com.electron.wispr-flow"]
        case .typeless: ["now.typeless.desktop"]
        case .voiceOS: ["com.voiceos.app"]
        case .superwhisper: ["com.superduper.superwhisper"]
        case .macWhisper: ["com.goodsnooze.MacWhisper"]
        case .textReplacements: []
        }
    }

    /// The app's name in /Applications.
    public var appNames: [String] {
        switch self {
        case .wisprFlow: ["Wispr Flow.app"]
        case .typeless: ["Typeless.app"]
        case .voiceOS: ["VoiceOS.app"]
        case .superwhisper: ["superwhisper.app", "Superwhisper.app"]
        case .macWhisper: ["MacWhisper.app"]
        case .textReplacements: []
        }
    }

    /// One line on getting the words out, where Connect can't.
    public var howTo: String {
        switch self {
        case .wisprFlow, .voiceOS:
            "Connect reads your words from it."
        case .typeless:
            "Typeless keeps your words online. Copy them there, then paste."
        case .superwhisper:
            "Copy your vocabulary from Superwhisper's settings, then paste."
        case .macWhisper:
            "Export your replacement list, then drop the file here."
        case .textReplacements:
            "Drag entries out of Keyboard › Text Replacements, then drop the file here."
        }
    }

    /// Where the app keeps its words on this Mac (under Application Support), and how to read them:
    /// the word, and what it replaces if anything, leaving out deleted entries and snippets. Nil
    /// where they aren't on this Mac.
    public var localStore: (path: String, query: String)? {
        switch self {
        case .wisprFlow:
            ("Wispr Flow/flow.sqlite",
             "SELECT phrase, replacement FROM Dictionary WHERE isDeleted = 0 AND isSnippet = 0")
        case .voiceOS:
            ("VoiceOS/voiceos.db", "SELECT text, NULL FROM dictionary WHERE deleted_at IS NULL")
        default:
            nil
        }
    }

    /// One click brings the words in (the app keeps them on this Mac).
    public var connects: Bool { localStore != nil }

    /// Text Replacements is the Mac's own, so it's always there.
    public var isSystem: Bool { self == .textReplacements }
}

/// The accent, as macOS offers it (Fovea Captures' `AccentChoice`): Multicolor follows the Mac's
/// own accent; the eight colors put one accent through Fovea. Chosen at the start.
public enum AccentName: String, CaseIterable, Sendable, Codable {
    case multicolor, blue, purple, pink, red, orange, yellow, green, graphite
    public var title: String { rawValue.capitalized }
}

/// The glow in the Dispatch voice bar, Fovea's aura (Settings › Notch, `GlowChoice`): a palette
/// to start from, turned round the color wheel, wandering as much as you like. Custom's spread
/// stays in Settings; the first run offers the templates.
public enum AuraPalette: String, CaseIterable, Sendable, Codable {
    case colorful, ocean, sunset, forest, candy, ice, gold, mono
    public var title: String { rawValue.capitalized }
    /// Mono is gray: there's no hue to turn and nothing to drift.
    public var turns: Bool { self != .mono }
}

/// What the person made theirs at the start, carried to the real Home at the end.
public struct Personalization: Equatable, Sendable, Codable {
    public var accent: AccentName = .multicolor
    public var aura: AuraPalette = .colorful
    /// Degrees the palette is turned, 0–360.
    public var auraHue: Double = 0
    /// How much the colors wander, from still (0) to lively (1): a spectrum, not a switch (Oct 8).
    public var auraDrift: Double = 0.5

    public init(accent: AccentName = .multicolor, aura: AuraPalette = .colorful, auraHue: Double = 0, auraDrift: Double = 0.5) {
        self.accent = accent; self.aura = aura; self.auraHue = auraHue; self.auraDrift = auraDrift
    }

    /// Settings › Notch's defaults.
    public var isDefault: Bool { self == Personalization() }
}

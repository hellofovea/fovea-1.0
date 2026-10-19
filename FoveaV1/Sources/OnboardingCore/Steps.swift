import Foundation
@_exported import FoveaKit

// Fovea's first run, as data: the stages, the steps in each, and what every step waits for.
// Pure, so the order and the rules can be tested without a screen (Tests/OnboardingCoreTests).
// docs/onboarding/ONBOARDING.md is the design this follows.

/// The six stages (Oct 9): hello, the permissions, the agents, two real tasks, dictation, and the
/// end. Dictation can be skipped whole.
public enum Stage: Int, CaseIterable, Sendable {
    case arrive, turnOn, agents, pointAndSay, dictation, home

    public var title: String {
        switch self {
        case .arrive: L("Hello")
        case .turnOn: L("Turn things on")
        case .agents: L("Your agents")
        case .pointAndSay: L("Point and send")
        case .dictation: L("Dictation")
        case .home: L("Finish")
        }
    }
}

/// One screen's worth of the first run. Oct 9 merged Accessibility and Screen Recording into one
/// step, put connecting the coding agents right after the permissions (the tasks send to them for
/// real), and gave the practice two tasks that do something: the weekly update at work, gathered
/// from two tabs and a chat (Oct 18, Ryan: two parts), and your packing list. No sign-in after the agents, and no demo
/// before the tasks: you learn by doing (Oct 9, round two).
public enum Step: String, CaseIterable, Sendable, Codable {
    /// Oct 9 (Fovea 1.0): the run starts with the name to be called by, then the email to sign up
    /// with; hello greets you by the name.
    case name, signIn
    case hello, makeItYours
    case permissions, microphone
    case agents
    case weeklyUpdate, hover, packList, followUp
    case dictationIntro, dictation
    /// Oct 15 review, OB-01.6: what Fovea remembers, read before the closing page.
    case dictionary, memory, home

    public var stage: Stage {
        switch self {
        case .name, .signIn, .hello, .makeItYours: .arrive
        case .permissions, .microphone: .turnOn
        case .agents: .agents
        case .weeklyUpdate, .hover, .packList, .followUp: .pointAndSay
        case .dictationIntro, .dictation: .dictation
        case .dictionary, .memory, .home: .home
        }
    }

    /// What the step waits for, in order. Each entry is a set of alternatives: any one of them
    /// does. Steps that wait for none move on with Continue.
    public var beats: [Set<Beat>] {
        switch self {
        case .hello, .makeItYours, .dictationIntro, .dictionary, .memory, .home: []
        case .signIn: [[.signedIn]]
        case .name: [[.named]]
        // Two lists, one drag each (Oct 9: granted together).
        case .permissions: [[.allowedAccessibility], [.allowedScreenRecording]]
        // Allowed, then heard: the person has to say the line before it counts (Oct 8).
        case .microphone: [[.allowedMicrophone], [.heard]]
        case .agents: [[.agentsConnected]]
        // The weekly update: this week's numbers from one tab and the merged pull requests from
        // another, then the words, then return (Oct 19, Ryan: ⌘ once each). Oct 17, round 2:
        // so no whole screen. Oct 18, Ryan: "only have two screenshot tasks": the tickets went.
        case .weeklyUpdate: [[.requestKey], [.numbers], [.prs], [.finish], [.review], [.send]]
        // While the agent works: the notch, and its answer, in either order.
        case .hover: [[.hoverNotch], [.answer]]
        // The everyday task: the line about the snow and the packing list.
        case .packList: [[.requestKey], [.passage], [.file], [.finish], [.review], [.send], [.answer]]
        case .followUp: [[.followKey], [.followAnswer]]
        // Two windows: the feedback first, then Messages (Oct 9). Oct 17, Ryan: in the feedback,
        // something taken while talking (⌘ and a drag, Oct 19), which lands after the words.
        case .dictation: [[.feedbackKey], [.feedbackTaken], [.feedbackLanded], [.replyKey], [.replyLanded]]
        }
    }

    /// Beats a step takes in any order (they still all have to happen). The keyboard teaches them
    /// in the order of `beats`: the numbers, then the pull requests.
    public var anyOrder: Set<Beat> {
        switch self {
        // The lists are shown in turn, but either allowed first counts.
        case .permissions: [.allowedAccessibility, .allowedScreenRecording]
        case .weeklyUpdate: [.numbers, .prs]
        case .hover: [.hoverNotch, .answer]
        case .packList: [.passage, .file]
        default: []
        }
    }

    /// Every step has a way past it, in case something fails (Oct 8): Skip appears after a while,
    /// or at once where there's nothing to fail. Hello, Make it yours and Home always go on.
    public var skip: Skip {
        switch self {
        case .signIn, .name, .hello, .makeItYours, .memory, .home: .never
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
        // Oct 17, Ryan: words and files need no key; dictation takes pictures too, with ⌘ (Oct 19).
        case .packList: [.request, .send]
        case .followUp: [.dictation]
        // Oct 18, Ryan: and ⌘ twice for the whole screen.
        case .dictationIntro, .dictation: [.dictation, .screenshot, .wholeScreen]
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
    public var isReading: Bool { [.signIn, .name, .hello, .makeItYours, .agents, .dictationIntro, .dictionary, .memory, .home].contains(self) }

    /// Oct 15 review, OB-01.7 and FR-05: a quiet Back beside the progress line. Oct 17, Ryan: "a
    /// back button for every stage": on every step after the first (the name has nothing before it),
    /// the microphone's test, the practice tasks and the end included.
    public var hasBack: Bool { self != Step.allCases.first }

    /// Oct 17, Ryan: where Back lands for this step. A step that waits on an earlier one's session
    /// starts again from the step that makes it, as Exit tour does: watching the update is the
    /// weekly update, asking more is the packing list.
    public var backLanding: Step {
        switch self {
        case .hover: .weeklyUpdate
        case .followUp: .packList
        default: self
        }
    }

    /// Oct 17, Ryan: gone back to, it starts again from its beginning, cleanly (a practice task,
    /// dictation's two windows), not as it was left.
    public var restartsOnBack: Bool { stage == .pointAndSay || self == .dictation }

    /// The step before this one in order: Back's way in a run picked up part way (after Exit tour,
    /// or Screen Recording's Quit & Reopen), with no page seen before it in this run.
    public var previous: Step? {
        let all = Step.allCases
        guard let i = all.firstIndex(of: self), i > 0 else { return nil }
        return all[i - 1]
    }

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

/// Something the person did that a step can be waiting for. Pressing a capture key isn't one: ⌘
/// only arms what comes next, a drag.
public enum Beat: String, CaseIterable, Sendable, Codable {
    /// An email to sign in with, and a name to be called by.
    case signedIn, named
    case allowedAccessibility, allowedMicrophone, allowedScreenRecording
    /// The microphone test heard a voice.
    case heard
    /// The coding agents on this Mac are connected.
    case agentsConnected
    /// fn ⌃ opened the voice bar.
    case requestKey
    /// ⌘ once and a drag, in the Analytics tab: this week's numbers (Oct 19, Ryan: ⌘ once a part,
    /// twice the whole screen).
    case numbers
    /// ⌘ once and a drag, in the GitHub tab: the pull requests merged this week.
    case prs
    /// Words selected while Fovea listens (Oct 17, Ryan: no key).
    case passage
    /// A file dragged onto the notch while Fovea listens (Oct 17, Ryan, round 2: no key; a click
    /// may mean opening it).
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
    /// Dictation into the feedback window, then into Messages: fn, then the words landing. Oct 17,
    /// Ryan: between them, something taken while talking into the feedback (`feedbackTaken`).
    case feedbackKey, feedbackTaken, feedbackLanded
    case replyKey, replyLanded

    /// The tab a part of the screen is taken from (Oct 9: gathering from different tabs).
    public var tab: PracticeTab? {
        switch self {
        case .numbers: .analytics
        case .prs: .github
        default: nil
        }
    }

    /// The part of its tab's page it takes (the page marks it `data-fovea`).
    public var part: String? {
        switch self {
        case .numbers: "numbers"
        case .prs: "prs"
        default: nil
        }
    }
}

/// The browser's tabs in practice: the weekly update's three, and the trail report for the trip.
public enum PracticeTab: String, CaseIterable, Sendable, Codable {
    /// Oct 18, Ryan: two parts for the weekly update, so two work tabs (the Support tab went).
    case analytics, github, trail

    public var title: String {
        switch self {
        case .analytics: L("Analytics")
        case .github: L("GitHub")
        case .trail: L("Trail report")
        }
    }

    /// The page's address, as the browser shows it.
    public var address: String {
        switch self {
        case .analytics: "insights.northwind.app"
        case .github: "github.com/northwind/app/pulls"
        case .trail: "trailreport.example/high-valleys"
        }
    }

    /// The tabs open for a step: the work tabs, then the trip's added beside them.
    public static func open(for step: Step) -> [PracticeTab] {
        switch step {
        case .packList, .followUp: [.analytics, .github, .trail]
        default: [.analytics, .github]
        }
    }
}

/// The keys the first run teaches. Their labels come from `KeyMap`, so a change of keys changes
/// the copy in one place.
/// Oct 17, Ryan: the highlighter key is gone. While Fovea listens, words you select and a file you
/// click are taken, with no key.
public enum KeyName: String, CaseIterable, Sendable, Codable {
    /// Oct 18, Ryan: ⌘ twice takes the whole screen again (fixed: it isn't recorded).
    case request, screenshot, wholeScreen, send, dictation

    /// Said for a shortcut cleared in Settings › Shortcuts (Oct 15 review, ST-03.1).
    public var unset: String {
        switch self {
        case .request: L("your Dispatch shortcut")
        case .screenshot: L("your screenshot key")
        case .wholeScreen: "⌘"
        case .send: "return"
        case .dictation: L("your Voice Flow shortcut")
        }
    }
}

/// The keys as FoveaKit's `FoveaKeys` has them. Oct 19, Ryan: "pressing ⌘ once take a screenshot
/// of the selected area, ⌘ twice the entire screen" (⌥ does nothing any more); words are selected
/// and files dragged onto the notch, no key; fn is Voice Flow, fn ⌃ Dispatch. This table is the one
/// place in the first run to change.
public struct KeyMap: Equatable, Sendable {
    public var request: [String]
    public var screenshot: [String]
    /// Oct 18, Ryan: "double clicking command for full-screen screenshot": ⌘ twice, FoveaKeys' own.
    public var wholeScreen: [String]
    public var send: [String]
    public var dictation: [String]

    public init(request: [String] = ["fn", "⌃"], screenshot: [String] = ["⌘"], wholeScreen: [String] = FoveaKeys.wholeScreen.keys,
                send: [String] = ["return"], dictation: [String] = ["fn"]) {
        self.request = request; self.screenshot = screenshot; self.wholeScreen = wholeScreen
        self.send = send; self.dictation = dictation
    }

    public static let current = KeyMap()

    /// Oct 15 review, ST-03.1: the keys as the person recorded them in Settings › Shortcuts (the
    /// defaults until they do), so every line in the first run that names a key names theirs. A
    /// left-hand key is drawn as the keyboard labels it ("left ⌥" is ⌥); a cleared shortcut has no
    /// caps, and is named instead (`spoken`).
    public init(prefs: FoveaPrefs) {
        func caps(_ id: String) -> [String] {
            (FoveaKeys.chord(id, prefs)?.caps ?? []).map { $0.hasPrefix("left ") ? String($0.dropFirst("left ".count)) : $0 }
        }
        self.init(request: caps(FoveaKeys.dispatch.id), screenshot: caps(FoveaKeys.region.id),
                  dictation: caps(FoveaKeys.voiceflow.id))
    }

    /// Some key in the map is fn (the 🌐 key's setting matters then).
    public var usesFn: Bool { [request, screenshot, wholeScreen, dictation].contains { $0.contains("fn") } }

    public func caps(_ key: KeyName) -> [String] {
        switch key {
        case .request: request
        case .screenshot: screenshot
        case .wholeScreen: wholeScreen
        case .send: send
        case .dictation: dictation
        }
    }

    /// The key's name in a sentence: "fn ⌃", "⌘". A shortcut cleared in Settings is named
    /// ("your Dispatch shortcut"), never left blank (Oct 15 review, ST-03.1).
    public func spoken(_ key: KeyName) -> String {
        let caps = caps(key)
        return caps.isEmpty ? key.unset : caps.joined(separator: " ")
    }

    /// The keys to press for what a step waits on now, as the keyboard labels them: only these
    /// light, in turn (Oct 9). A capture key already armed is the app's to clear (then it's a drag
    /// or a click, and nothing lights).
    public func keys(for beat: Beat) -> [String] {
        switch beat {
        case .requestKey, .finish: request
        // Oct 19, Ryan: ⌘ for pictures (once, a part; twice, the whole screen), in dictation too;
        // words and files light nothing (no key).
        case .numbers, .prs: screenshot
        case .feedbackTaken: screenshot + wholeScreen.filter { !screenshot.contains($0) }
        case .send: send
        case .followKey, .followAnswer, .feedbackKey, .feedbackLanded, .replyKey, .replyLanded: dictation
        default: []
        }
    }

    /// How many presses a beat takes: one (the weekly update's parts are ⌘ once each).
    public func presses(for beat: Beat) -> Int { 1 }

    /// How many presses a key takes: the whole screen is ⌘ twice (Oct 18, Ryan), the rest once.
    public func presses(_ key: KeyName) -> Int { key == .wholeScreen ? FoveaKeys.wholeScreen.presses : 1 }

    /// The "×2" on the keyboard for what a beat waits on: the whole screen's key where the whole
    /// screen is named. Oct 19, Ryan: when it's the screenshot key too (⌘ once, ⌘ twice), the key
    /// lights plain, for once; twice is in the words.
    public func badges(for beat: Beat) -> [String: String] {
        guard beat == .feedbackTaken, !wholeScreen.contains(where: screenshot.contains) else { return [:] }
        return Dictionary(wholeScreen.map { ($0, "×\(presses(.wholeScreen))") }, uniquingKeysWith: { a, _ in a })
    }
}

/// The permissions the first run asks for. Speech Recognition is gone and Automation joins
/// (docs/window/FEEDBACK_2026-10-06.md, rows 3–5); Automation is only for handing words to Terminal.
public enum Permission: String, CaseIterable, Sendable, Codable {
    /// Oct 15 review, OB-01.5 and FR-09: Input Monitoring, asked for on the permissions page. 1.0's
    /// own key engine doesn't need it, so the page never waits on it.
    case accessibility, microphone, screenRecording, automation, inputMonitoring

    /// The ones the permissions page waits on (Input Monitoring is asked for, never waited on).
    public static let required: [Permission] = [.accessibility, .screenRecording]
    /// The rows on the permissions page, in order.
    public static let page: [Permission] = [.accessibility, .screenRecording, .inputMonitoring]

    /// The pane's name as macOS 27 writes it.
    public var paneName: String {
        switch self {
        case .accessibility: L("Device Control and Data Access")
        case .microphone: L("Microphone")
        case .screenRecording: L("Screen & System Audio Recording")
        case .automation: L("Automation")
        case .inputMonitoring: L("Input Monitoring")
        }
    }

    /// What it's for, in a few words (Oct 9: "shorter terms").
    public var purpose: String {
        switch self {
        case .accessibility: L("Your hotkeys, in any app.")
        case .microphone: L("So Fovea hears you.")
        case .screenRecording: L("Only what you point at.")
        case .automation: L("So Fovea can hand your words to Terminal.")
        case .inputMonitoring: L("So your shortcuts work in every app.")
        }
    }
}

/// Oct 15 review, OB-03.1: one practice again, from Home's Getting Started, the rest of the first
/// run left as it is; Home again at its end.
public enum PracticeAgain: String, CaseIterable, Sendable, Codable {
    case weeklyUpdate, packingList, followUp, dictation

    public var title: String {
        switch self {
        case .weeklyUpdate: L("The weekly update")
        case .packingList: L("The packing list")
        case .followUp: L("Asking more")
        case .dictation: L("Dictation")
        }
    }

    /// The steps it walks. Asking more needs a session to ask in, so the packing list goes first.
    public var steps: [Step] {
        switch self {
        case .weeklyUpdate: [.weeklyUpdate, .hover]
        case .packingList: [.packList]
        case .followUp: [.packList, .followUp]
        case .dictation: [.dictationIntro, .dictation]
        }
    }
}

/// The language Fovea listens in. Oct 9: English and Chinese only; any other is typed under More…
/// and kept as a request, for the languages to add next. FoveaKit's, shared with Settings.
public typealias Language = FoveaLanguage

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
/// /Applications. Wispr Flow keeps its words on this Mac, so Connect reads them straight from
/// there, when it's clicked and not before; Typeless keeps them online, so for it, and the rest,
/// it's a paste or a file. Oct 18, Ryan: no VoiceOS in the list.
public enum DictationApp: String, CaseIterable, Sendable {
    case wisprFlow, typeless, superwhisper, macWhisper, textReplacements

    public var name: String {
        switch self {
        case .wisprFlow: "Wispr Flow"
        case .typeless: "Typeless"
        case .superwhisper: "Superwhisper"
        case .macWhisper: "MacWhisper"
        case .textReplacements: L("Text Replacements")
        }
    }

    public var bundleIDs: [String] {
        switch self {
        case .wisprFlow: ["com.electron.wispr-flow"]
        case .typeless: ["now.typeless.desktop"]
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
        case .superwhisper: ["superwhisper.app", "Superwhisper.app"]
        case .macWhisper: ["MacWhisper.app"]
        case .textReplacements: []
        }
    }

    /// One line on getting the words out, where Connect can't.
    public var howTo: String {
        switch self {
        case .wisprFlow:
            L("Connect reads your words from it.")
        case .typeless:
            L("Typeless keeps your words online. Copy them there, then paste.")
        case .superwhisper:
            L("Copy your vocabulary from Superwhisper's settings, then paste.")
        case .macWhisper:
            L("Export your replacement list, then drop the file here.")
        case .textReplacements:
            L("Drag entries out of Keyboard › Text Replacements, then drop the file here.")
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
        default:
            nil
        }
    }

    /// One click brings the words in (the app keeps them on this Mac).
    public var connects: Bool { localStore != nil }

    /// Text Replacements is the Mac's own, so it's always there.
    public var isSystem: Bool { self == .textReplacements }
}

/// The accent, as macOS offers it: Multicolor follows the Mac's own accent; the eight colors put
/// one accent through Fovea. Chosen at the start. FoveaKit's, shared with Settings and the notch.
public typealias AccentName = FoveaAccent

/// The glow in the Dispatch voice bar, Fovea's aura (Settings › Notch). Oct 18, Ryan: the eight
/// palettes are fixed (their hue and drift never change); Customize (`.custom`) is the ninth, and
/// only it has a hue and a drift to set. FoveaKit's.
public typealias AuraPalette = GlowPalette

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

    /// Oct 18, Ryan: "changing the hue should not change the color scheme provided". The glow as
    /// drawn: a palette at its own colors and the default drift; Customize at the person's hue and
    /// drift. FoveaPrefs' `drawnGlowHue` and `drawnGlowDrift` keep the same rule (a test holds them).
    public var drawnHue: Double { aura == .custom ? auraHue : 0 }
    public var drawnDrift: Double { aura == .custom ? auraDrift : Personalization().auraDrift }

    /// Make it yours' tiles: the eight palettes, then Customize.
    public static let tiles: [AuraPalette] = GlowPalette.templates + [.custom]
}

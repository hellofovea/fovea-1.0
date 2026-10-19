import Foundation

/// The words for one step: the line the Island says; on a reading step, the title and why; on a
/// doing step, the title is the one caption on the board (Oct 9: one line saying where you are,
/// then what to do, then what to say). Plain and calm: no exclamation marks, no speed claims,
/// nothing Fovea can't show (AGENTS.md: no efficiency metrics).
public struct StepCopy: Equatable, Sendable {
    /// One line in the Island.
    public var caption: String
    public var title: String
    /// Why the step is here, in a sentence (reading steps; empty where the title says it all).
    public var body: String
    /// The line to say.
    public var script: String?
    /// What to try when it doesn't work, behind "Not working?".
    public var help: String?
    public var button: String
    /// The way past the step (every step has one, Oct 8), and what taking it costs.
    public var skipLabel: String
    public var skipNote: String?

    public init(caption: String, title: String, body: String = "", script: String? = nil, help: String? = nil,
                button: String = L("Continue"), skipLabel: String = L("Skip"), skipNote: String? = nil) {
        self.caption = caption; self.title = title; self.body = body; self.script = script
        self.help = help; self.button = button; self.skipLabel = skipLabel; self.skipNote = skipNote
    }
}

public enum Copy {
    public static func step(_ step: Step, keys: KeyMap = .current, agents: [Agent] = [], name: String? = nil) -> StepCopy {
        let agent = agents.first?.name
        let dictation = keys.spoken(.dictation)
        // Oct 15 review, ST-03.1: the 🌐 key's setting only matters when a shortcut uses fn.
        let keysHelp = keys.usesFn
            ? L("Keys not lighting up? Allow Device Control and Data Access, and set Keyboard › Press 🌐 key to Do Nothing.")
            : L("Keys not lighting up? Allow Device Control and Data Access, then check your keys in Settings › Shortcuts.")
        switch step {
        case .name:
            return StepCopy(
                caption: "",
                title: L("What should we call you?"),
                button: L("Continue"))
        case .signIn:
            return signIn(.choosing)
        case .hello:
            // Greeted by name (Oct 9), then the one line (Oct 8).
            let who = name.map { $0.trimmingCharacters(in: .whitespaces) }.flatMap { $0.isEmpty ? nil : $0 }
            return StepCopy(
                caption: who.map { L("Hi, \($0). I live up here.") } ?? L("Hi. I live up here."),
                title: who.map { L("Hello, \($0).") } ?? L("Hello."),
                body: L("Talk to your agents from the notch."),
                button: L("Begin"))
        case .makeItYours:
            return StepCopy(
                caption: L("This is how I glow when you talk to an agent."),
                title: L("Make it yours"),
                body: L("Your accent, the light the notch makes while it listens, and the notch itself. All of it stays in Settings."),
                button: L("Looks good"))
        case .permissions:
            // Both lists in one step, named and nothing more (Oct 9, round two).
            return StepCopy(
                caption: permissionCaptions[0],
                title: L("Grant Fovea Access"),
                help: L("Click Allow, then turn Fovea's switch on in the list System Settings opens. Not in the list? Click + under it and choose Fovea from Applications."),
                skipLabel: L("Skip for now"),
                skipNote: L("Fovea's keys and pictures won't work until you allow both."))
        case .microphone:
            // A line to say, and nothing else to read (Oct 9).
            return StepCopy(
                caption: L("Let me hear you."),
                title: L("Say this out loud"),
                script: micLine,
                help: L("Nothing moving? Check the input in System Settings › Sound, or come a little closer."),
                button: L("Allow the microphone"),
                skipLabel: L("Skip for now"),
                skipNote: L("You can test the microphone later in Settings › Voice & Capture."))
        case .agents:
            // Right after the permissions (Oct 9): the tasks send to them for real. Connected is
            // connected: nothing to sign in to.
            return StepCopy(
                caption: L("Now, your coding agents."),
                title: L("Connect your coding agents"),
                button: agent != nil ? L("Connect") : L("Use the practice agent"),
                skipLabel: L("Skip for now"),
                skipNote: L("The practice agent answers the tasks. Connect agents later in Settings › Connectors."))
        case .weeklyUpdate:
            // The work task (Oct 9, round two): gathering from different tabs into one request.
            return StepCopy(
                caption: L("Dispatch from anywhere."),
                // Oct 18, Ryan: two parts, from two tabs.
                title: L("Maya needs this week's update. The numbers are in two tabs."),
                script: L("Draft this week's update from these."),
                help: keysHelp,
                skipLabel: L("Do it for me"),
                skipNote: L("Fovea takes the two parts for you, with the line."))
        case .hover:
            return StepCopy(
                caption: L("\(agent ?? L("Your agent")) is on it."),
                title: L("Your agent is writing the update."),
                skipLabel: L("Open it for me"))
        case .packList:
            // The everyday task: a line from the trail report, and your packing list.
            return StepCopy(
                caption: L("Now something for you."),
                title: L("You're hiking this weekend, and there's snow up top."),
                script: L("Add what I'll need for this to my packing list."),
                help: keysHelp,
                skipLabel: L("Put it together for me"),
                skipNote: L("Fovea takes the line and the list for you, with the words."))
        case .followUp:
            return StepCopy(
                caption: L("Ask more, the same way."),
                title: L("Your list is ready. Ask for more by voice."),
                script: L("Now sort it into clothes and gear."),
                skipLabel: L("Skip the follow-up"))
        case .dictationIntro:
            return StepCopy(
                caption: L("One more, if you want it."),
                title: L("Dictation"),
                // Oct 17, Ryan: what you take while you talk lands after your words; the keys for it
                // are listed under this (`whileDictating`).
                body: L("Press \(dictation), talk, and press \(dictation) again. Your words land in the window under your pointer, and what you take lands after them."),
                button: L("Try it"),
                skipLabel: L("Skip dictation"))
        case .dictation:
            // Two windows, real words (Oct 9); feedback first.
            return StepCopy(
                caption: L("Point, then talk."),
                title: L("Start with your feedback for Fovea, then answer Lin."),
                skipLabel: L("Skip dictation"))
        case .dictionary:
            return StepCopy(
                caption: L("One last thing."),
                title: L("Bring your words"),
                body: L("From the dictation app you use now."),
                button: L("Add words"),
                skipLabel: L("Not now"),
                skipNote: L("You can add words to Fovea's dictionary any time."))
        case .memory:
            // Oct 15 review, OB-01.6: four short points on how Memory works, before the end.
            return StepCopy(
                caption: L("What I keep, and where."),
                title: L("What Fovea remembers"),
                button: L("Continue"))
        case .home:
            return StepCopy(
                caption: L("That's everything."),
                title: L("You're all set"),
                button: L("Done"))
        }
    }

    // MARK: Signing up (Oct 15 review, FR-03, FR-04, AC-01.1, AC-01.2)

    /// The sign-up page's words as it goes: the choices, then a link to check for.
    public static func signIn(_ phase: SignInPhase) -> StepCopy {
        if case .checkEmail(let email) = phase {
            return StepCopy(
                caption: "",
                title: L("Check your email"),
                body: L("We sent a link to \(email). Open it on this Mac to go on."),
                button: L("Continue"))
        }
        return StepCopy(
            caption: "",
            title: L("Sign up"),
            body: L("So your settings and history stay yours."),
            button: L("Continue"))
    }

    public static func continueWith(_ provider: AccountProvider) -> String { L("Continue with \(provider.title)") }
    public static func signInWaiting(_ provider: AccountProvider) -> String { L("Waiting for \(provider.title)…") }
    public static var signInCanceled: String { L("Sign-in canceled.") }
    public static var signInFailed: String { L("Couldn't sign in. Check your connection and try again.") }
    public static var signInTryAgain: String { L("Try Again") }
    public static var signInCancel: String { L("Cancel") }
    public static var signInResend: String { L("Resend Email") }
    public static var signInResent: String { L("Sent again.") }
    public static var signInDifferentEmail: String { L("Use a Different Email") }
    public static var signInDifferentAccount: String { L("Use a Different Account") }
    public static var signInKept: String { L("Whichever you choose is kept on this Mac for now.") }
    public static func signedIn(_ provider: AccountProvider, email: String?) -> String {
        if provider == .email, let email, !email.isEmpty { return L("Signed in as \(email).") }
        return L("Signed in with \(provider.title).")
    }

    // MARK: What Fovea remembers (Oct 15 review, OB-01.6)

    public struct MemoryPoint: Equatable, Sendable {
        public let title: String
        public let detail: String
    }

    /// What's kept, where, who reads it, and that it's yours.
    public static var memoryPoints: [MemoryPoint] { [
        MemoryPoint(title: L("What's kept"), detail: L("What you say and what you take, and the app it came from.")),
        MemoryPoint(title: L("Where"), detail: L("On this Mac.")),
        MemoryPoint(title: L("Who reads it"), detail: L("Your agents, only if you allow it in Settings › Connectors.")),
        MemoryPoint(title: L("It's yours"), detail: L("Find, hide or delete any memory in Settings › Memory, or turn Memory Link off.")),
    ] }

    // MARK: The way back, and the way out (Oct 15 review, OB-01.7, OB-03.1)

    public static var back: String { L("Back") }
    public static var exitTour: String { L("Exit tour") }
    public static var exitPractice: String { L("Exit practice") }

    /// What to do now, typed out on the board as the step goes (Oct 9: letter by letter, as if
    /// Fovea were talking). `armed`: ⌥ is already pressed, so what's left is a drag.
    /// `tab`: the browser tab showing, for a part to take from a tab.
    public static func instruction(_ beat: Beat?, step: Step, armed: Bool = false, tab: PracticeTab? = nil,
                                   keys: KeyMap = .current, agent: String? = nil) -> String? {
        let request = keys.spoken(.request)
        let shot = keys.spoken(.screenshot)
        let dictation = keys.spoken(.dictation)
        guard let beat else {
            switch step {
            case .dictation: return L("Read it over. Your feedback goes only when you click Send.")
            case .weeklyUpdate, .packList, .followUp, .hover: return L("Done.")
            default: return nil
            }
        }
        switch (step, beat) {
        // The permissions and the microphone say nothing more than their names and their line.
        case (.permissions, _), (.microphone, _):
            return nil
        case (_, .requestKey):
            return L("Press \(request) to start.")
        // Oct 17, Ryan (round 2): ⌥ once each; no whole screen. Oct 18: two parts.
        case (_, .numbers), (_, .prs):
            let wanted = beat.tab ?? .github
            let what = beat == .numbers ? L("this week's numbers") : L("the merged pull requests")
            if tab != wanted { return L("Now click the \(wanted.title) tab.") }
            return armed ? L("Drag over \(what).") : L("Press \(shot) once, then drag over \(what).")
        // Oct 17, Ryan: words and files need no key while Fovea listens.
        case (_, .passage):
            return L("Select the line about the snow: drag across it.")
        // Oct 17, Ryan (round 2): a file is taken by dragging it onto the notch.
        case (_, .file):
            return L("Drag Packing list.txt onto the notch.")
        case (_, .finish):
            return L("Say the line, then press \(request).")
        case (_, .review):
            return L("Writing it up.")
        case (_, .send):
            return L("Press return to send it to \(agent ?? L("your agent")).")
        case (.hover, .hoverNotch):
            return L("Move your pointer to the notch.")
        case (_, .answer):
            return step == .hover ? L("Still writing. It opens when it's done.") : L("Your agent is on it.")
        case (_, .followKey):
            return L("Open the packing list from the notch, then press \(dictation) to ask more.")
        case (_, .followAnswer):
            return L("Say the line, then press \(dictation).")
        case (_, .feedbackKey):
            return L("Point at the feedback window and press \(dictation).")
        // Oct 17, Ryan: one thing taken while talking, which lands after the words.
        case (_, .feedbackTaken):
            // Oct 18, Ryan: or the whole screen, ⌘ twice.
            return L("Tell us what you think, and show us what you mean: press \(shot), then drag over any part of the screen, or press \(keys.spoken(.wholeScreen)) twice for all of it.")
        case (_, .feedbackLanded):
            return L("Press \(dictation) when you're done. What you took lands after your words.")
        case (_, .replyKey):
            return L("Now point at Messages and press \(dictation).")
        case (_, .replyLanded):
            return L("Answer Lin, then press \(dictation).")
        default:
            return nil
        }
    }

    // MARK: While you talk (Oct 17, Ryan: "a part that tells the user all of the hotkeys")

    /// One way to take something while dictating: its keys (none for words and files), how many
    /// presses, what it is (Oct 18, Ryan: "Screenshot", "Selected text and files") and, quieter,
    /// how.
    public struct TakeLine: Equatable, Sendable {
        public let caps: [String]
        public let presses: Int
        public let title: String
        public let detail: String
    }

    public static var whileDictatingLead: String { L("While you talk") }

    /// What works while dictating, with the person's own keys: ⌥ for part of the screen, ⌘ twice for
    /// the whole screen (Oct 18), and words or a file with no key. All of it lands after the words.
    public static func whileDictating(keys: KeyMap = .current) -> [TakeLine] {
        // Oct 17, Ryan (round 2): ⌥ once only (twice is Claude's); a file is dragged onto the notch.
        // Oct 18, Ryan: named for what they take, how in a quiet second line.
        // Oct 18, Ryan: ⌘ twice for the whole screen joins them.
        [TakeLine(caps: keys.caps(.screenshot), presses: 1, title: L("Screenshot"),
                  detail: L("Press \(keys.spoken(.screenshot)), then drag over it.")),
         TakeLine(caps: keys.caps(.wholeScreen), presses: keys.presses(.wholeScreen), title: L("Whole screen"),
                  detail: L("Press \(keys.spoken(.wholeScreen)) twice.")),
         TakeLine(caps: [], presses: 1, title: L("Selected text and files"), detail: L("Select words, or drag a file onto the notch."))]
    }

    /// Words landed in the feedback before anything was taken (Oct 17, Ryan): the try again.
    public static func dictationMissed(keys: KeyMap = .current) -> String {
        L("Not quite. While you talk, press \(keys.spoken(.screenshot)) and drag over part of the screen, then press \(keys.spoken(.dictation)).")
    }

    /// The notch's line while Fovea is dragged into the lists: the first, the second, both done.
    public static var permissionCaptions: [String] { [L("Drag me into the list."), L("Now this list."), L("Allowed. Thank you.")] }

    /// The microphone test's line, and what the notch says once it hears it (Oct 9).
    public static var micLine: String { L("Hey Fovea, can you hear me?") }
    public static var micHeard: String { L("Loud and clear.") }
    public static var micUnavailable: String { L("No microphone here. Hold space while you say it, or skip.") }

    /// Hello's languages (Oct 9): More… opens a box to type one in.
    // Oct 18, Ryan: "Change 'I'll listen in' to 'Choose your languages'", and a primary.
    public static var languageLead: String { L("Choose your languages") }
    public static var primaryLanguage: String { L("Primary language") }
    public static var primaryNote: String { L("Fovea's words appear in your primary language.") }
    /// Each language in its own name, as macOS lists them.
    public static func languageName(_ language: FoveaLanguage) -> String { language == .english ? "English" : "中文" }
    public static var languageMore: String { L("More…") }
    /// Oct 17, Ryan (FR-06): one at a time, Return adds it, as many as wanted.
    public static var languagePlaceholder: String { L("Type a language, then press Return") }
    public static var languageNote: String { L("We'll add it soon. Fovea listens in English or Chinese for now.") }

    /// Make it yours' two choices, kept well apart (Oct 9).
    public static var accentLabel: String { L("Accent") }
    public static var auraLabel: String { L("The light when you talk to an agent") }
    /// The ninth light, the one whose hue and drift are set (Oct 18, Ryan).
    public static var customizeAura: String { L("Customize") }

    /// The agents (Oct 9, round two): the ones Fovea connects, and a say in what comes next.
    public static var agentNotInstalled: String { L("Not on this Mac. Install it, and Fovea connects it.") }
    public static var agentOnThisMac: String { L("On this Mac") }
    public static var agentsNext: String { L("More are coming. Which do you want next?") }
    public static var agentsOther: String { L("Another…") }

    /// Dictation's two windows. The feedback window suggests what to talk about (Oct 9, round two).
    public static var feedbackTitle: String { L("How was your first run?") }
    public static var feedbackLead: String { L("Talk about any of these:") }
    public static var feedbackTopics: [String] { [L("The flow, start to finish"), L("How it looks"), L("The hotkeys"), L("Settings and making it yours")] }
    /// Names the person's own Voice Flow key (Oct 15 review, ST-03.1).
    public static func feedbackPlaceholder(keys: KeyMap = .current) -> String {
        L("Point here, press \(keys.spoken(.dictation)), and talk.")
    }
    public static var feedbackNote: String { L("Only sent when you click Send.") }
    public static var feedbackSent: String { L("Sent. Thank you.") }
    public static var replyPlaceholder: String { L("iMessage") }
    public static var linMessages: [String] { [L("Morning. Can we move our call this week?"), L("Tuesday is packed for me.")] }

    /// Bringing your words (Oct 9, round two): one click for the apps that keep them on this Mac.
    public static func importConnect(_ app: DictationApp) -> String { L("Connect \(app.name)") }
    public static var importOther: String { L("Another app? Paste your words, or drop a file.") }
    public static var importChoose: String { L("Choose File…") }
    public static var importPaste: String { L("Paste") }
    public static var importNone: String { L("No words there yet.") }
    public static var importCantRead: String { L("Couldn't read its words. Paste them instead.") }

    /// The end (Oct 9, round two): two things, spread out.
    public static var homeNotch: String { L("Next time, start from the notch.") }
    public static var eyeTrackingTitle: String { L("Eye tracking is in beta.") }
    public static var eyeTrackingAsk: String { L("Request access") }
    public static var eyeTrackingAsked: String { L("Requested. We'll let you know.") }
}

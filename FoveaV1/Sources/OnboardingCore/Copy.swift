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
                button: String = "Continue", skipLabel: String = "Skip", skipNote: String? = nil) {
        self.caption = caption; self.title = title; self.body = body; self.script = script
        self.help = help; self.button = button; self.skipLabel = skipLabel; self.skipNote = skipNote
    }
}

public enum Copy {
    public static func step(_ step: Step, keys: KeyMap = .current, agents: [Agent] = [], name: String? = nil) -> StepCopy {
        let agent = agents.first?.name
        let dictation = keys.spoken(.dictation)
        let keysHelp = "Keys not lighting up? Allow Device Control and Data Access, and set Keyboard › Press 🌐 key to Do Nothing."
        switch step {
        case .name:
            return StepCopy(
                caption: "",
                title: "What should we call you?",
                button: "Continue")
        case .signIn:
            return StepCopy(
                caption: "",
                title: "Sign up",
                body: "So your settings and history stay yours.",
                button: "Continue")
        case .hello:
            // Greeted by name (Oct 9), then the one line (Oct 8).
            let who = name.map { $0.trimmingCharacters(in: .whitespaces) }.flatMap { $0.isEmpty ? nil : $0 }
            return StepCopy(
                caption: who.map { "Hi, \($0). I live up here." } ?? "Hi. I live up here.",
                title: who.map { "Hello, \($0)." } ?? "Hello.",
                body: "Talk to any agent from the notch.",
                button: "Begin")
        case .makeItYours:
            return StepCopy(
                caption: "This is how I glow when you talk to an agent.",
                title: "Make it yours",
                body: "Your accent, the light the notch makes while it listens, and the notch itself. All of it stays in Settings.",
                button: "Looks good")
        case .permissions:
            // Both lists in one step, named and nothing more (Oct 9, round two).
            return StepCopy(
                caption: permissionCaptions[0],
                title: "Grant Fovea Access",
                help: "Click Allow, then turn Fovea's switch on in the list System Settings opens. Not in the list? Click + under it and choose Fovea from Applications.",
                skipLabel: "Skip for now",
                skipNote: "Fovea's keys and pictures won't work until you allow both.")
        case .microphone:
            // A line to say, and nothing else to read (Oct 9).
            return StepCopy(
                caption: "Let me hear you.",
                title: "Say this out loud",
                script: micLine,
                help: "Nothing moving? Check the input in System Settings › Sound, or come a little closer.",
                button: "Allow the microphone",
                skipLabel: "Skip for now",
                skipNote: "You can test the microphone later in Settings › Voice & Capture.")
        case .agents:
            // Right after the permissions (Oct 9): the tasks send to them for real. Connected is
            // connected: nothing to sign in to.
            return StepCopy(
                caption: "Now, your coding agents.",
                title: "Connect your coding agents",
                button: agent != nil ? "Connect" : "Use the practice agent",
                skipLabel: "Skip for now",
                skipNote: "The practice agent answers the tasks. Connect agents later in Settings › Connectors.")
        case .weeklyUpdate:
            // The work task (Oct 9, round two): gathering from different tabs into one request.
            return StepCopy(
                caption: "Dispatch from anywhere.",
                title: "Maya needs this week's update. The numbers are in three tabs.",
                script: "Draft this week's update from these.",
                help: keysHelp,
                skipLabel: "Do it for me",
                skipNote: "Fovea takes the screen and the two parts for you, with the line.")
        case .hover:
            return StepCopy(
                caption: "\(agent ?? "Your agent") is on it.",
                title: "Your agent is writing the update.",
                skipLabel: "Open it for me")
        case .packList:
            // The everyday task: a line from the trail report, and your packing list.
            return StepCopy(
                caption: "Now something for you.",
                title: "You're hiking this weekend, and there's snow up top.",
                script: "Add what I'll need for this to my packing list.",
                help: keysHelp,
                skipLabel: "Put it together for me",
                skipNote: "Fovea takes the line and the list for you, with the words.")
        case .followUp:
            return StepCopy(
                caption: "Ask more, the same way.",
                title: "Your list is ready. Ask for more by voice.",
                script: "Now sort it into clothes and gear.",
                skipLabel: "Skip the follow-up")
        case .dictationIntro:
            return StepCopy(
                caption: "One more, if you want it.",
                title: "Dictation",
                body: "Press \(dictation), talk, and press \(dictation) again. Your words land in the window under your pointer.",
                button: "Try it",
                skipLabel: "Skip dictation")
        case .dictation:
            // Two windows, real words (Oct 9); feedback first.
            return StepCopy(
                caption: "Point, then talk.",
                title: "Start with your feedback for Fovea, then answer Lin.",
                skipLabel: "Skip dictation")
        case .dictionary:
            return StepCopy(
                caption: "One last thing.",
                title: "Bring your words",
                body: "From the dictation app you use now.",
                button: "Add words",
                skipLabel: "Not now",
                skipNote: "You can add words to Fovea's dictionary any time.")
        case .home:
            return StepCopy(
                caption: "That's everything.",
                title: "You're all set",
                button: "Done")
        }
    }

    /// What to do now, typed out on the board as the step goes (Oct 9: letter by letter, as if
    /// Fovea were talking). `armed`: ⌘ or ⌥ is already pressed, so what's left is a drag or a click.
    /// `tab`: the browser tab showing, for a part to take from a tab.
    public static func instruction(_ beat: Beat?, step: Step, armed: Bool = false, tab: PracticeTab? = nil,
                                   keys: KeyMap = .current, agent: String? = nil) -> String? {
        let request = keys.spoken(.request)
        let shot = keys.spoken(.screenshot)
        let highlighter = keys.spoken(.highlighter)
        let dictation = keys.spoken(.dictation)
        guard let beat else {
            switch step {
            case .dictation: return "Read it over. Your feedback goes only when you click Send."
            case .weeklyUpdate, .packList, .followUp, .hover: return "Done."
            default: return nil
            }
        }
        switch (step, beat) {
        // The permissions and the microphone say nothing more than their names and their line.
        case (.permissions, _), (.microphone, _):
            return nil
        case (_, .requestKey):
            return "Press \(request) to start."
        case (_, .wholeScreen):
            return "First the whole screen: Maya's ask and the chart. Press \(shot) twice."
        case (_, .prs), (_, .tickets):
            let wanted = beat.tab ?? .github
            let what = beat == .prs ? "the merged pull requests" : "the open tickets"
            if tab != wanted { return "Now click the \(wanted.title) tab." }
            return armed ? "Drag over \(what)." : "Press \(shot) once, then drag over \(what)."
        case (_, .passage):
            return "Hold \(highlighter) and drag across the line about the snow."
        case (_, .file):
            return armed ? "Click Packing list.txt on the desktop." : "Tap \(highlighter), then click Packing list.txt on the desktop."
        case (_, .finish):
            return "Say the line, then press \(request)."
        case (_, .review):
            return "Writing it up."
        case (_, .send):
            return "Press return to send it to \(agent ?? "your agent")."
        case (.hover, .hoverNotch):
            return "Move your pointer to the notch."
        case (_, .answer):
            return step == .hover ? "Still writing. It opens when it's done." : "Your agent is on it."
        case (_, .followKey):
            return "Open the packing list from the notch, then press \(dictation) to ask more."
        case (_, .followAnswer):
            return "Say the line, then press \(dictation)."
        case (_, .feedbackKey):
            return "Point at the feedback window and press \(dictation)."
        case (_, .feedbackLanded):
            return "Tell us what you thought. Press \(dictation) when you're done."
        case (_, .replyKey):
            return "Now point at Messages and press \(dictation)."
        case (_, .replyLanded):
            return "Answer Lin, then press \(dictation)."
        default:
            return nil
        }
    }

    /// The notch's line while Fovea is dragged into the lists: the first, the second, both done.
    public static let permissionCaptions = ["Drag me into the list.", "Now this list.", "Allowed. Thank you."]

    /// The microphone test's line, and what the notch says once it hears it (Oct 9).
    public static let micLine = "Hey Fovea, can you hear me?"
    public static let micHeard = "Loud and clear."
    public static let micUnavailable = "No microphone here. Hold space while you say it, or skip."

    /// Hello's languages (Oct 9): More… opens a box to type one in.
    public static let languageLead = "I'll listen in"
    public static let languageMore = "More…"
    public static let languagePlaceholder = "Type your language"
    public static let languageNote = "We'll add it soon. Fovea listens in English or Chinese for now."

    /// Make it yours' two choices, kept well apart (Oct 9).
    public static let accentLabel = "Accent"
    public static let auraLabel = "The light when you talk to an agent"

    /// The agents (Oct 9, round two): the ones Fovea connects, and a say in what comes next.
    public static let agentNotInstalled = "Not on this Mac. Install it, and Fovea connects it."
    public static let agentOnThisMac = "On this Mac"
    public static let agentsNext = "More are coming. Which do you want next?"
    public static let agentsOther = "Another…"

    /// Dictation's two windows. The feedback window suggests what to talk about (Oct 9, round two).
    public static let feedbackTitle = "How was your first run?"
    public static let feedbackLead = "Talk about any of these:"
    public static let feedbackTopics = ["The flow, start to finish", "How it looks", "The hotkeys", "Settings and making it yours"]
    public static let feedbackPlaceholder = "Point here, press fn, and talk."
    public static let feedbackNote = "Only sent when you click Send."
    public static let feedbackSent = "Sent. Thank you."
    public static let replyPlaceholder = "iMessage"
    public static let linMessages = ["Morning. Can we move our call this week?", "Tuesday is packed for me."]

    /// Bringing your words (Oct 9, round two): one click for the apps that keep them on this Mac.
    public static func importConnect(_ app: DictationApp) -> String { "Connect \(app.name)" }
    public static let importOther = "Another app? Paste your words, or drop a file."
    public static let importChoose = "Choose File…"
    public static let importPaste = "Paste"
    public static let importNone = "No words there yet."
    public static let importCantRead = "Couldn't read its words. Paste them instead."

    /// The end (Oct 9, round two): two things, spread out.
    public static let homeNotch = "Next time, start from the notch."
    public static let eyeTrackingTitle = "Eye tracking is in beta."
    public static let eyeTrackingAsk = "Request access"
    public static let eyeTrackingAsked = "Requested. We'll let you know."
}

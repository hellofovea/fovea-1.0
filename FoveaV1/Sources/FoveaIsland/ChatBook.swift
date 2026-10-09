import Foundation

// Choose chat's sample chats: twenty per agent, as a working week leaves them, in projects (the
// folder each runs in): this one (app-ui-v1, where the request's referents come from) and
// others. Claude Code's include the edge cases of choosing a session (docs/island/CHOOSE_CHAT.md):
// one working mid-turn, one waiting on a permission prompt, one in a worktree since removed, one
// that runs on the web, one Fovea can't continue (open in Claude instead), an untitled one, two
// with the same title in this project, and two with the same title in different projects.

/// An agent a chat lives in.
struct ChatAgent: Identifiable, Equatable {
    let id: String
    let name: String
    /// When its icon is missing.
    let symbol: String

    static let claudeCode = ChatAgent(id: "claude-code", name: "Claude Code", symbol: "terminal")
    static let codex = ChatAgent(id: "codex", name: "Codex", symbol: "chevron.left.forwardslash.chevron.right")
    static let cursor = ChatAgent(id: "cursor", name: "Cursor", symbol: "cursorarrow")
    static let grokBot = ChatAgent(id: "grok-bot", name: "Grok Bot", symbol: "face.smiling")
    static let all = [claudeCode, codex, cursor, grokBot]
    /// The default agent, for a request with no project: Quick answers. Never a provider's icon
    /// there (AGENTS.md), so Fovea's own; it has no chats to choose from, so not in `all`.
    static let fovea = ChatAgent(id: "fovea", name: "Fovea", symbol: "sparkle")

    static func named(_ id: String) -> ChatAgent { (all + [fovea]).first { $0.id == id } ?? claudeCode }
}

/// Where a chat is, for sending to it.
enum ChatState: Equatable {
    /// Open and idle: the request goes in at once.
    case open
    /// Answering now: the request runs after this turn.
    case working
    /// Closed: it resumes when the request is sent.
    case ready
    /// Waiting on the person (a permission prompt, a question, a plan to approve): the request
    /// would sit behind it, so it can't be chosen until that is answered where it is.
    case needsYou
    /// Fovea can't send to it from here, and why.
    case unavailable(String)
    /// Fovea can't confirm it may write to it (it lives in another app's window): it can be
    /// opened there instead.
    case elsewhere(app: String)

    var choosable: Bool {
        switch self {
        case .open, .working, .ready: return true
        case .needsYou, .unavailable, .elsewhere: return false
        }
    }
}

/// One chat: a conversation inside an agent, run in a project's folder.
struct AgentChat: Identifiable, Equatable {
    let id: String
    let agent: String
    /// The agent's own title; an untitled chat shows its first words.
    let title: String
    let untitled: Bool
    /// The project: its working directory's name.
    let folder: String
    /// Its git branch, when it is not the project's main one.
    let branch: String?
    let minutesAgo: Int
    var state: ChatState
    /// A chat that doesn't exist yet: a New chat in the project.
    var isNew = false

    /// "4m", "2h", "3d".
    var age: String {
        minutesAgo < 60 ? "\(minutesAgo)m" : minutesAgo < 1440 ? "\(minutesAgo / 60)h" : "\(minutesAgo / 1440)d"
    }
    var inProject: Bool { folder == ChatBook.project }
}

/// One project of an agent: the folder its chats run in.
struct ChatProject: Identifiable, Equatable {
    let agent: String
    let folder: String
    /// Most recent first.
    let chats: [AgentChat]
    var id: String { "\(agent)/\(folder)" }
    var path: String { ChatBook.paths[folder] ?? "~/\(folder)" }
    var latest: AgentChat? { chats.first }
    var needsYou: Bool { chats.contains { $0.state == .needsYou } }
}

/// The edge cases the panel can stage: fovea-mac's workbench scenarios that touch choosing a
/// chat and sending to it (docs/island/CHOOSE_CHAT.md maps all of them), and the PRD's routing.
enum ChatCase: String, CaseIterable, Identifiable {
    // Routing.
    case usual, unsure, routingFailed
    // The chosen chat.
    case busy, needsApproval, askedQuestion, removed, desktopTooOld
    // The lists.
    case loading, changing, notSetUp
    // The request.
    case longRequest, manyReferents, imagesOnly
    // Sending.
    case sendFails, unconfirmed

    var id: String { rawValue }
    var title: String {
        switch self {
        case .usual: return "Usual"
        case .unsure: return "Fovea isn't sure"
        case .routingFailed: return "Routing failed"
        case .busy: return "The chat is answering (queues)"
        case .needsApproval: return "The chat waits for approval"
        case .askedQuestion: return "The chat asked you a question"
        case .removed: return "The chat was closed"
        case .desktopTooOld: return "Claude Desktop too old"
        case .loading: return "Chats still loading"
        case .changing: return "Chats change while open"
        case .notSetUp: return "An agent isn't set up"
        case .longRequest: return "Long request"
        case .manyReferents: return "Many screenshots, one missing"
        case .imagesOnly: return "Screenshots, no words"
        case .sendFails: return "Sending fails"
        case .unconfirmed: return "Sent, not confirmed"
        }
    }
    /// The panel's sections.
    static let groups: [(title: String, cases: [ChatCase])] = [
        ("Routing", [.usual, .unsure, .routingFailed]),
        ("The chosen chat", [.busy, .needsApproval, .askedQuestion, .removed, .desktopTooOld]),
        ("The chats", [.loading, .changing, .notSetUp]),
        ("The request", [.longRequest, .manyReferents, .imagesOnly]),
        ("Sending", [.sendFails, .unconfirmed]),
    ]
}

enum ChatBook {
    /// The project the request's referents come from.
    static let project = "app-ui-v1"
    /// Routing's pick for the request: the chat about the ears, in this project, open, 4m ago.
    static let predicted = "cc-notch-ears"
    static let predictedAgent = "claude-code"
    /// When routing isn't sure: its best guesses (the same title in two projects, and Codex's
    /// geometry tests), then a New chat here.
    static let guesses = ["cc-notch-ears", "cc-notch-ears-mac", "cx-geometry"]
    /// The agent the "isn't set up" case leaves out: Cursor, which this Mac doesn't have.
    static let notSetUp = "cursor"
    /// A chat that arrives while the list is open, in the "chats change" case.
    static let arriving = AgentChat(id: "cc-ear-spacing", agent: "claude-code", title: "Ear spacing follow-up", untitled: false,
                                    folder: "app-ui-v1", branch: nil, minutesAgo: 0, state: .working)
    /// The request when it runs long, for the "long request" case.
    static let longRequest = "Make the ears on this one match the menu bar's height, and use the spacing from the second one. "
        + "Keep the corner radius the same as the voice bar's, but check it against the full-screen band too, where the ears "
        + "hang from the black strip instead of the screen's edge. If the second one's spacing doesn't fit at 2x, round to "
        + "the nearest half point and tell me what you changed."
    /// Each project's folder.
    static let paths = [
        "app-ui-v1": "~/Desktop/things/fovea/app-ui-v1",
        "fovea-mac": "~/Desktop/things/fovea/fovea-mac",
        "hellofovea": "~/Desktop/things/fovea/fovea-app-ui-v1-hellofovea",
        "FoveaGaze": "~/Desktop/things/FoveaGaze",
        "Futuro": "~/Desktop/things/Futuro",
    ]

    static let chats: [AgentChat] = claudeCode + codex + cursor + grokBot

    /// A New chat for an agent in a project, as a chat that doesn't exist yet.
    static func newChat(agent: String, folder: String) -> AgentChat {
        AgentChat(id: "new|\(agent)|\(folder)", agent: agent, title: "New chat", untitled: false, folder: folder,
                  branch: nil, minutesAgo: 0, state: .open, isNew: true)
    }

    static func chat(_ id: String, in chats: [AgentChat]) -> AgentChat? {
        if id.hasPrefix("new|") {
            let parts = id.split(separator: "|").map(String.init)
            return parts.count == 3 ? newChat(agent: parts[1], folder: parts[2]) : nil
        }
        return chats.first { $0.id == id }
    }

    /// An agent's projects: this one first, then by their latest chat; each one's chats most
    /// recent first.
    static func projects(of agent: String, in chats: [AgentChat]) -> [ChatProject] {
        let mine = chats.filter { $0.agent == agent }
        let folders = Dictionary(grouping: mine, by: \.folder)
        return folders.map { folder, chats in
            ChatProject(agent: agent, folder: folder, chats: chats.sorted { $0.minutesAgo < $1.minutesAgo })
        }.sorted { a, b in
            if (a.folder == project) != (b.folder == project) { return a.folder == project }
            return (a.latest?.minutesAgo ?? .max) < (b.latest?.minutesAgo ?? .max)
        }
    }

    private static func make(_ agent: String, _ rows: [(String, String, String, String?, Int, ChatState)],
                             untitled: Set<String> = []) -> [AgentChat] {
        rows.map { id, title, folder, branch, minutes, state in
            AgentChat(id: id, agent: agent, title: title, untitled: untitled.contains(id), folder: folder,
                      branch: branch, minutesAgo: minutes, state: state)
        }
    }

    static let claudeCode = make("claude-code", [
        ("cc-notch-ears", "Notch ears match the menu bar", "app-ui-v1", nil, 4, .open),
        ("cc-choose-chat", "Choose chat rail", "app-ui-v1", nil, 9, .working),
        ("cc-paste-countdown", "Paste not found countdown", "app-ui-v1", nil, 21, .needsYou),
        ("cc-island-springs", "Island motion springs", "app-ui-v1", "feat/motion", 48, .ready),
        ("cc-referent-stack", "Referent stack expansion", "app-ui-v1", nil, 75, .ready),
        ("cc-notch-ears-mac", "Notch ears match the menu bar", "fovea-mac", nil, 130, .ready),
        ("cc-voice-glow", "Voice glow port", "app-ui-v1", nil, 160, .ready),
        ("cc-agent-rows", "Agent list rows", "app-ui-v1", "ears-fix", 200, .unavailable("Worktree removed")),
        ("cc-fn-key", "fn key press-to-toggle", "fovea-mac", nil, 240, .ready),
        ("cc-gaze-drift", "Gaze calibration drift", "FoveaGaze", nil, 330, .ready),
        ("cc-snapshot-flake", "Flaky snapshot tests", "app-ui-v1", nil, 420, .ready),
        ("cc-ear-clip", "why does the ear clip at 2x", "app-ui-v1", nil, 510, .ready),
        ("cc-settings-spacing", "Settings sidebar spacing", "app-ui-v1", nil, 690, .ready),
        ("cc-ci-cloud", "Move CI to cloud runners", "fovea-mac", nil, 900, .unavailable("Runs on the web")),
        ("cc-quick-answer", "Quick Answer layout", "app-ui-v1", nil, 1500, .elsewhere(app: "Claude")),
        ("cc-release-notes", "Release notes draft", "Futuro", nil, 1900, .unavailable("Read only")),
        ("cc-referent-stack-2", "Referent stack expansion", "app-ui-v1", "feat/stack", 2900, .ready),
        ("cc-onboarding", "Onboarding empty state", "hellofovea", nil, 3400, .ready),
        ("cc-payload", "Payload compiler", "fovea-mac", nil, 4600, .ready),
        ("cc-binding", "Binding first-try rate", "app-ui-v1", nil, 8600, .ready),
    ], untitled: ["cc-ear-clip"])

    static let codex = make("codex", [
        ("cx-agent-routing", "Agent routing", "app-ui-v1", nil, 12, .working),
        ("cx-hotkey", "Hotkey monitor", "fovea-mac", nil, 35, .ready),
        ("cx-snapshots", "Snapshot tests", "app-ui-v1", nil, 52, .ready),
        ("cx-delivery", "Delivery channel adapters", "fovea-mac", nil, 80, .open),
        ("cx-capture", "ScreenCaptureKit capture", "fovea-mac", nil, 110, .needsYou),
        ("cx-tokens", "Tokens audit", "app-ui-v1", nil, 140, .ready),
        ("cx-geometry", "Island geometry tests", "app-ui-v1", nil, 190, .ready),
        ("cx-gaze-model", "Gaze model export", "FoveaGaze", nil, 250, .ready),
        ("cx-review", "Transcript review", "app-ui-v1", nil, 320, .ready),
        ("cx-locale", "Speech locale fallback", "fovea-mac", nil, 400, .ready),
        ("cx-ledger", "Home ledger rows", "app-ui-v1", nil, 520, .ready),
        ("cx-ci-cache", "CI cache keys", "fovea-mac", nil, 700, .unavailable("In use in another window")),
        ("cx-landing", "Landing page copy", "Futuro", nil, 900, .ready),
        ("cx-icons", "Icon pipeline", "app-ui-v1", nil, 1300, .ready),
        ("cx-usage-arc", "Usage arc popover", "app-ui-v1", nil, 1700, .ready),
        ("cx-export", "Data export", "hellofovea", nil, 2400, .ready),
        ("cx-a11y", "Accessibility labels", "app-ui-v1", nil, 3000, .ready),
        ("cx-benchmarks", "Model routing benchmarks", "Futuro", nil, 4200, .ready),
        ("cx-intent", "Routing intent tests", "fovea-mac", nil, 6000, .ready),
        ("cx-menu-bar", "Menu bar icon states", "app-ui-v1", nil, 9000, .ready),
    ])

    static let cursor = make("cursor", [
        ("cu-settings", "Settings polish", "app-ui-v1", nil, 38, .ready),
        ("cu-dictionary", "Dictionary page", "app-ui-v1", nil, 66, .open),
        ("cu-connectors", "Connectors page", "app-ui-v1", nil, 95, .ready),
        ("cu-shortcuts", "Shortcuts recorder", "app-ui-v1", nil, 140, .working),
        ("cu-plan", "Usage & Plan page", "app-ui-v1", nil, 180, .ready),
        ("cu-marketing", "Marketing site hero", "Futuro", nil, 230, .ready),
        ("cu-capture-detail", "Capture detail card", "app-ui-v1", nil, 300, .ready),
        ("cu-eye-tracking", "Eye tracking page", "FoveaGaze", nil, 380, .ready),
        ("cu-search", "Home search", "app-ui-v1", nil, 460, .ready),
        ("cu-account", "Account page", "app-ui-v1", nil, 600, .ready),
        ("cu-empty", "Empty states", "hellofovea", nil, 820, .ready),
        ("cu-pricing", "Pricing table", "Futuro", nil, 1000, .ready),
        ("cu-avatar", "Avatar usage arc", "app-ui-v1", nil, 1400, .ready),
        ("cu-toasts", "Overlay toasts", "fovea-mac", nil, 1900, .ready),
        ("cu-docs", "Docs site nav", "Futuro", nil, 2500, .ready),
        ("cu-chrome", "Window chrome", "app-ui-v1", nil, 3100, .ready),
        ("cu-hover", "Ledger hover states", "app-ui-v1", nil, 3900, .ready),
        ("cu-colors", "Color tokens", "app-ui-v1", nil, 5000, .ready),
        ("cu-blog", "Blog layout", "Futuro", nil, 7000, .ready),
        ("cu-press", "Press kit page", "Futuro", nil, 9800, .ready),
    ])

    static let grokBot = make("grok-bot", [
        ("gk-launch", "Launch copy", "Futuro", nil, 55, .ready),
        ("gk-naming", "Product naming", "Futuro", nil, 80, .ready),
        ("gk-models", "Model notes", "Futuro", nil, 120, .open),
        ("gk-competitors", "Competitor scan", "Futuro", nil, 170, .ready),
        ("gk-gaze-papers", "Gaze tracking papers", "FoveaGaze", nil, 240, .working),
        ("gk-pricing", "Pricing research", "Futuro", nil, 300, .ready),
        ("gk-thread", "Launch thread", "Futuro", nil, 420, .ready),
        ("gk-investors", "Investor update", "Futuro", nil, 560, .ready),
        ("gk-onboarding", "Onboarding copy", "hellofovea", nil, 700, .ready),
        ("gk-faq", "FAQ answers", "Futuro", nil, 900, .ready),
        ("gk-demo", "Demo video script", "Futuro", nil, 1200, .ready),
        ("gk-hiring", "Hiring post", "Futuro", nil, 1600, .ready),
        ("gk-privacy", "Privacy page", "app-ui-v1", nil, 2000, .ready),
        ("gk-ui-copy", "Island UI copy", "app-ui-v1", nil, 2500, .ready),
        ("gk-roadmap", "Roadmap notes", "Futuro", nil, 3200, .ready),
        ("gk-survey", "User survey", "Futuro", nil, 4000, .ready),
        ("gk-press", "Press pitch", "Futuro", nil, 5200, .ready),
        ("gk-glossary", "Glossary", "app-ui-v1", nil, 6400, .ready),
        ("gk-app-store", "App Store listing", "Futuro", nil, 8000, .ready),
        ("gk-talk", "Conference talk", "Futuro", nil, 9900, .ready),
    ])
}

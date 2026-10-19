import Foundation
import FoveaKit

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
    /// Claude Code and Codex, as the site names them (Oct 13: Cursor is among what comes next, not
    /// in the list).
    // Oct 18, Ryan: only Codex and Claude Code (Grok Bot is gone from the notch).
    static let all = [claudeCode, codex]
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
        // Oct 18, Ryan: in the primary language, as an age ("4 分钟前"; the board's "4m" is a duration).
        minutesAgo < 60 ? L("island.age.minutes", english: "\(minutesAgo)m")
            : minutesAgo < 1440 ? L("island.age.hours", english: "\(minutesAgo / 60)h")
            : L("island.age.days", english: "\(minutesAgo / 1440)d")
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
    /// The agent the "isn't set up" case leaves out (Cursor until Oct 13, when it left the list).
    // Oct 18, Ryan: only Codex and Claude Code, so the case leaves out Codex.
    static let notSetUp = "codex"
    /// A chat that arrives while the list is open, in the "chats change" case.
    static var arriving: AgentChat { AgentChat(id: "cc-ear-spacing", agent: "claude-code", title: L("Ear spacing follow-up"), untitled: false,
                                    folder: "app-ui-v1", branch: nil, minutesAgo: 0, state: .working) }
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

    // Oct 18, Ryan: the sample chats' titles in the primary language, made as they are read.
    // Oct 18, Ryan: only Codex and Claude Code.
    static var chats: [AgentChat] { claudeCode + codex }

    /// A New chat for an agent in a project, as a chat that doesn't exist yet.
    static func newChat(agent: String, folder: String) -> AgentChat {
        AgentChat(id: "new|\(agent)|\(folder)", agent: agent, title: L("New chat"), untitled: false, folder: folder,
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

    static var claudeCode: [AgentChat] { make("claude-code", [
        ("cc-notch-ears", L("Notch ears match the menu bar"), "app-ui-v1", nil, 4, .open),
        ("cc-choose-chat", L("Choose chat rail"), "app-ui-v1", nil, 9, .working),
        ("cc-paste-countdown", L("Paste not found countdown"), "app-ui-v1", nil, 21, .needsYou),
        ("cc-island-springs", L("Island motion springs"), "app-ui-v1", "feat/motion", 48, .ready),
        ("cc-referent-stack", L("Referent stack expansion"), "app-ui-v1", nil, 75, .ready),
        ("cc-notch-ears-mac", L("Notch ears match the menu bar"), "fovea-mac", nil, 130, .ready),
        ("cc-voice-glow", L("Voice glow port"), "app-ui-v1", nil, 160, .ready),
        // Oct 15 review, QA05: the four reasons a chat can't take a request (ChatBlock): its
        // worktree removed (the folder), a chat on the web, one being sent to, one read only.
        ("cc-agent-rows", L("Agent list rows"), "app-ui-v1", "ears-fix", 200, .unavailable(ChatBlock.cantWrite)),
        ("cc-fn-key", L("fn key press-to-toggle"), "fovea-mac", nil, 240, .ready),
        // Oct 18, Ryan: only Codex and Claude Code: the papers and the launch thread came from Grok Bot.
        ("cc-gaze-papers", L("Gaze tracking papers"), "FoveaGaze", nil, 240, .ready),
        ("cc-gaze-drift", L("Gaze calibration drift"), "FoveaGaze", nil, 330, .ready),
        ("cc-thread", L("Launch thread"), "Futuro", nil, 420, .ready),
        ("cc-snapshot-flake", L("Flaky snapshot tests"), "app-ui-v1", nil, 420, .ready),
        ("cc-ear-clip", L("why does the ear clip at 2x"), "app-ui-v1", nil, 510, .ready),
        ("cc-settings-spacing", L("Settings sidebar spacing"), "app-ui-v1", nil, 690, .ready),
        ("cc-ci-cloud", L("Move CI to cloud runners"), "fovea-mac", nil, 900, .unavailable(ChatBlock.agentUnavailable)),
        ("cc-quick-answer", L("Quick Answer layout"), "app-ui-v1", nil, 1500, .elsewhere(app: "Claude")),
        ("cc-release-notes", L("Release notes draft"), "Futuro", nil, 1900, .unavailable(ChatBlock.readOnly)),
        ("cc-referent-stack-2", L("Referent stack expansion"), "app-ui-v1", "feat/stack", 2900, .ready),
        ("cc-onboarding", L("Onboarding empty state"), "hellofovea", nil, 3400, .ready),
        ("cc-payload", L("Payload compiler"), "fovea-mac", nil, 4600, .ready),
        ("cc-binding", L("Binding first-try rate"), "app-ui-v1", nil, 8600, .ready),
    ], untitled: ["cc-ear-clip"]) }

    static var codex: [AgentChat] { make("codex", [
        ("cx-agent-routing", L("Agent routing"), "app-ui-v1", nil, 12, .working),
        ("cx-hotkey", L("Hotkey monitor"), "fovea-mac", nil, 35, .ready),
        ("cx-snapshots", L("Snapshot tests"), "app-ui-v1", nil, 52, .ready),
        ("cx-delivery", L("Delivery channel adapters"), "fovea-mac", nil, 80, .open),
        ("cx-capture", L("ScreenCaptureKit capture"), "fovea-mac", nil, 110, .needsYou),
        ("cx-tokens", L("Tokens audit"), "app-ui-v1", nil, 140, .ready),
        ("cx-geometry", L("Island geometry tests"), "app-ui-v1", nil, 190, .ready),
        ("cx-gaze-model", L("Gaze model export"), "FoveaGaze", nil, 250, .ready),
        // Oct 18, Ryan: only Codex and Claude Code: the investor update came from Grok Bot.
        ("cx-investors", L("Investor update"), "Futuro", nil, 560, .ready),
        ("cx-review", L("Transcript review"), "app-ui-v1", nil, 320, .ready),
        ("cx-locale", L("Speech locale fallback"), "fovea-mac", nil, 400, .ready),
        ("cx-ledger", L("Home ledger rows"), "app-ui-v1", nil, 520, .ready),
        ("cx-ci-cache", L("CI cache keys"), "fovea-mac", nil, 700, .unavailable(ChatBlock.inUse)),
        ("cx-landing", L("Landing page copy"), "Futuro", nil, 900, .ready),
        ("cx-icons", L("Icon pipeline"), "app-ui-v1", nil, 1300, .ready),
        ("cx-usage-arc", L("Usage arc popover"), "app-ui-v1", nil, 1700, .ready),
        ("cx-export", L("Data export"), "hellofovea", nil, 2400, .ready),
        ("cx-a11y", L("Accessibility labels"), "app-ui-v1", nil, 3000, .ready),
        ("cx-benchmarks", L("Model routing benchmarks"), "Futuro", nil, 4200, .ready),
        ("cx-intent", L("Routing intent tests"), "fovea-mac", nil, 6000, .ready),
        ("cx-menu-bar", L("Menu bar icon states"), "app-ui-v1", nil, 9000, .ready),
    ]) }

    static var cursor: [AgentChat] { make("cursor", [
        ("cu-settings", L("Settings polish"), "app-ui-v1", nil, 38, .ready),
        ("cu-dictionary", L("Dictionary page"), "app-ui-v1", nil, 66, .open),
        ("cu-connectors", L("Connectors page"), "app-ui-v1", nil, 95, .ready),
        ("cu-shortcuts", L("Shortcuts recorder"), "app-ui-v1", nil, 140, .working),
        ("cu-plan", L("Usage & Plan page"), "app-ui-v1", nil, 180, .ready),
        ("cu-marketing", L("Marketing site hero"), "Futuro", nil, 230, .ready),
        ("cu-capture-detail", L("Capture detail card"), "app-ui-v1", nil, 300, .ready),
        ("cu-eye-tracking", L("Eye tracking page"), "FoveaGaze", nil, 380, .ready),
        ("cu-search", L("Home search"), "app-ui-v1", nil, 460, .ready),
        ("cu-account", L("Account page"), "app-ui-v1", nil, 600, .ready),
        ("cu-empty", L("Empty states"), "hellofovea", nil, 820, .ready),
        ("cu-pricing", L("Pricing table"), "Futuro", nil, 1000, .ready),
        ("cu-avatar", L("Avatar usage arc"), "app-ui-v1", nil, 1400, .ready),
        ("cu-toasts", L("Overlay toasts"), "fovea-mac", nil, 1900, .ready),
        ("cu-docs", L("Docs site nav"), "Futuro", nil, 2500, .ready),
        ("cu-chrome", L("Window chrome"), "app-ui-v1", nil, 3100, .ready),
        ("cu-hover", L("Ledger hover states"), "app-ui-v1", nil, 3900, .ready),
        ("cu-colors", L("Color tokens"), "app-ui-v1", nil, 5000, .ready),
        ("cu-blog", L("Blog layout"), "Futuro", nil, 7000, .ready),
        ("cu-press", L("Press kit page"), "Futuro", nil, 9800, .ready),
    ]) }
}

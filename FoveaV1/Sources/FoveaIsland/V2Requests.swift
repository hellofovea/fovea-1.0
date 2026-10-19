import SwiftUI
import AppKit
import FoveaCore
import FoveaKit

// Dispatch Version 2's sample requests (the flow is in WorkbenchModel+DispatchV2.swift): what is
// said, what is taken, where it could go, and what the agent does, beat by beat, with its screen.
// Dispatch Version 2: Dispatch and Quick actions as one flow, every stage leading to the next.
//
// fn⌃ opens the voice bar (the aura and the referent stack). Left Option held turns on capture: a
// drag takes a region, a click takes a passage's text or a file; twice, the whole screen. fn⌃
// again transcribes it and forwards it all to Choose chat: three suggested chats, the first in
// the pill, or ⌃ to browse every chat by agent and project, as Dispatch's expanded view does;
// it waits until the person sends. Sent, the control board shows a moment, then the island rests. A quick
// answer opens by itself: the agent's screen or what it made, and the outcome. fn on a result
// asks more there; fn⌃ is always new.
// docs/island/DISPATCH_V2.md has the reasons.

/// The sample requests: one per kind of result.
enum V2Request: String, CaseIterable, Identifiable {
    case formula, calendar, draft, code

    var id: String { rawValue }
    var title: String {
        switch self {
        case .formula: return "A formula in a paper"
        case .calendar: return "Pull up my calendar"
        case .draft: return "Draft an email"
        case .code: return "A code change"
        }
    }

    /// What the person says.
    var spoken: String {
        switch self {
        case .formula: return "What does this formula mean?"
        case .calendar: return "Pull up my calendar for this afternoon."
        case .draft: return "Draft a reply to Sam saying Thursday at three works."
        case .code: return "Make the ears on this one match the menu bar's height, and use the spacing from the second one."
        }
    }

    /// What Play and the panel's states take as if circled: the formula, Sam's email, two screens.
    var referents: [V2Referent] {
        switch self {
        case .formula: return [.formula]
        case .calendar: return []
        case .draft: return [.email]
        case .code: return [.screen("Screens/fovea-home.png", "Fovea — Home"), .screen("Screens/fovea-settings.png", "Fovea — Settings")]
        }
    }

    /// Where it could go, best first, with the plain reason. Until routing exists these come
    /// from simple signals: what is open, where the last request went, what is active.
    var suggestions: [V2Suggestion] {
        let newHere = V2Suggestion(agent: "claude-code", chat: nil, project: "app-ui-v1", reason: L("Open in your editor"))
        // Oct 18, Ryan: only Codex and Claude Code (the second suggestion was Grok Bot's).
        switch self {
        case .formula:
            return [V2Suggestion(agent: ChatAgent.fovea.id, chat: nil, project: nil, reason: L("Nothing open to work in")),
                    V2Suggestion(agent: "claude-code", chat: L("Gaze tracking papers"), project: "FoveaGaze", reason: L("Papers, last week")), newHere]
        case .calendar:
            return [V2Suggestion(agent: ChatAgent.fovea.id, chat: nil, project: nil, reason: L("A question about your day")),
                    V2Suggestion(agent: "codex", chat: L("Investor update"), project: "Futuro", reason: L("Active today")), newHere]
        case .draft:
            return [V2Suggestion(agent: ChatAgent.fovea.id, chat: nil, project: nil, reason: L("A draft to take")),
                    V2Suggestion(agent: "claude-code", chat: L("Launch thread"), project: "Futuro", reason: L("Writing, yesterday")), newHere]
        case .code:
            return [V2Suggestion(agent: "claude-code", chat: L("Notch ears match the menu bar"), project: "app-ui-v1", reason: L("Last sent here, 4m ago")),
                    V2Suggestion(agent: "codex", chat: L("Island geometry tests"), project: "app-ui-v1", reason: L("Same files")),
                    V2Suggestion(agent: "claude-code", chat: nil, project: "app-ui-v1", reason: L("Open in your editor"))]
        }
    }

    /// How often the agent moves on: a question in about a second, the change in a couple.
    var pace: Double { self == .code ? WorkbenchTokens.V2.taskPace : WorkbenchTokens.V2.answerPace }

    static let paper = "Attention Is All You Need"
    static let calendarDay = "Thursday, Oct 8"
    static let events = [
        ScreenEvent(start: 14, end: 14.75, title: "Design review with Mia", place: "Zoom"),
        ScreenEvent(start: 16.5, end: 17.5, title: "Dentist", place: "18 Grove St"),
    ]
    // Oct 18, Ryan: the scripted agent writes in the primary language too.
    static var draftText: String { L("Hi Sam,\n\nThursday at 3 works for me. I'll send an invite this afternoon.\n\nBest,") }

    /// What the agent does, beat by beat, each with its screen; the last beat is its result.
    var script: [AgentBeat] {
        switch self {
        case .formula:
            return [
                AgentBeat(activity: L("Reading the formula"), work: .reading, object: L("the formula"),
                          screen: .paper(title: Self.paper, note: nil)),
                AgentBeat(activity: L("Working out each term"), work: .thinking, screen: .paper(title: Self.paper, note: nil)),
                AgentBeat(activity: L("Explained the formula"), work: .done, state: .complete,
                          screen: .paper(title: Self.paper, note: L("Each word becomes a weighted mix of the other words' values.")),
                          result: AgentResult(
                    outcome: L("Each word becomes a weighted mix of the other words' values."),
                    terms: [
                        AgentResultTerm(term: "Q, K, V", meaning: L("Queries, keys, values")),
                        AgentResultTerm(term: "QKᵀ", meaning: L("How well they match")),
                        AgentResultTerm(term: "√dₖ", meaning: L("Keeps the scores small")),
                        AgentResultTerm(term: "softmax", meaning: L("Scores into weights")),
                    ],
                    anchored: true)),
            ]
        case .calendar:
            return [
                AgentBeat(activity: L("Checking your calendar"), work: .reading, object: L("Calendar"),
                          screen: .calendar(day: Self.calendarDay, events: [])),
                AgentBeat(activity: L("Two things this afternoon"), work: .done, state: .complete,
                          screen: .calendar(day: Self.calendarDay, events: Self.events), result: AgentResult(
                    outcome: L("Two things this afternoon."),
                    rows: [
                        AgentResultRow(lead: L("2:00 PM"), text: L("Design review with Mia"), detail: "Zoom", action: L("Join")),
                        AgentResultRow(lead: L("4:30 PM"), text: L("Dentist"), detail: "18 Grove St"),
                    ])),
            ]
        case .draft:
            return [
                AgentBeat(activity: L("Reading Sam's email"), work: .reading,
                          screen: .mail(to: "Sam Lee", subject: "Re: Thursday?", body: "")),
                AgentBeat(activity: L("Drafting the reply"), work: .editing,
                          screen: .mail(to: "Sam Lee", subject: "Re: Thursday?", body: "Hi Sam,\n\nThursday at 3 works for me.")),
                AgentBeat(activity: L("Drafted a reply"), work: .done, state: .complete,
                          screen: .mail(to: "Sam Lee", subject: "Re: Thursday?", body: Self.draftText), result: AgentResult(
                    outcome: L("A short yes, with the invite to follow."), draft: Self.draftText)),
            ]
        case .code:
            let shape: [AgentCodeLine] = [
                AgentCodeLine(number: 41, text: "let earWidth = spec.compactTopRadius"),
                AgentCodeLine(number: 42, text: "let earHeight: CGFloat = 22", change: .removed),
                AgentCodeLine(number: 42, text: "let earHeight = metrics.menuBarHeight", change: .typing),
                AgentCodeLine(number: 43, text: "path.addArc(center: ear, radius: earHeight,"),
                AgentCodeLine(number: 44, text: "            startAngle: .zero, endAngle: .degrees(90))"),
            ]
            var done = shape
            done[2] = AgentCodeLine(number: 42, text: "let earHeight = metrics.menuBarHeight", change: .added)
            return [
                AgentBeat(activity: L("Reading your request"), work: .reading, object: L("2 screenshots"), screen: .terminal(
                    title: "app-ui-v1 — Claude Code", lines: [
                        ScreenLine(text: "> Make the ears on this one match the menu bar's height…", tone: .prompt),
                        ScreenLine(text: "⏺ Reading 2 screenshots", tone: .dim),
                    ])),
                AgentBeat(activity: L("Editing IslandShape.swift"), work: .editing, object: "IslandShape.swift",
                          screen: .editor(file: "IslandShape.swift", lines: shape)),
                AgentBeat(activity: L("Editing NotchGeometry.swift"), work: .editing, object: "NotchGeometry.swift",
                          screen: .editor(file: "NotchGeometry.swift", lines: [
                    AgentCodeLine(number: 118, text: "// The spacing from the second screenshot"),
                    AgentCodeLine(number: 119, text: "let spacing: CGFloat = 8", change: .removed),
                    AgentCodeLine(number: 119, text: "let spacing = referents[1].spacing", change: .typing),
                    AgentCodeLine(number: 120, text: "return frames.inset(by: spacing)"),
                ])),
                AgentBeat(activity: L("Running swift build"), work: .running, object: "swift build", screen: .terminal(
                    title: "app-ui-v1 — swift build", lines: [
                        ScreenLine(text: "❯ swift build", tone: .prompt),
                        ScreenLine(text: "Compiling NotchGeometry.swift", tone: .normal),
                    ])),
                // It asks before running the tests, as Claude Code does: the session waits on the
                // person (Needs you), its queue held, until Run Tests or Deny (Oct 11).
                AgentBeat(activity: L("Run swift test --filter NotchGeometry?"), work: .asking,
                          object: "swift test --filter NotchGeometry", state: .needsYou,
                          ask: .approval("swift test --filter NotchGeometry"), screen: .terminal(
                    title: "app-ui-v1 — Claude Code", lines: [
                        ScreenLine(text: "⏺ Run swift test --filter NotchGeometry?", tone: .prompt),
                    ])),
                AgentBeat(activity: L("Running swift test"), work: .running, object: "swift test", screen: .terminal(
                    title: "app-ui-v1 — swift test", lines: [
                        ScreenLine(text: "❯ swift test", tone: .prompt),
                        ScreenLine(text: "✓ NotchGeometryTests.earsMatchTheMenuBar", tone: .ok),
                    ])),
                AgentBeat(activity: L("The ears match the menu bar"), work: .done, state: .complete,
                          screen: .editor(file: "IslandShape.swift", lines: done), result: AgentResult(
                    outcome: L("The ears match the menu bar now."),
                    points: [L("Height follows the menu bar"),
                             L("Spacing from screenshot 2"),
                             L("Full screen keeps the band")],
                    artifacts: ["IslandShape.swift", "NotchGeometry.swift"],
                    attention: [L("Not checked on an external display")])),
            ]
        }
    }

    /// Asking more (fn on its result): what the person says, and what comes back.
    var followUp: (spoken: String, script: [AgentBeat]) {
        switch self {
        case .formula:
            return ("Why divide by the square root?", [
                AgentBeat(activity: L("Thinking it through"), work: .thinking, screen: .paper(title: Self.paper, note: nil)),
                AgentBeat(activity: L("Explained the scaling"), work: .done, state: .complete,
                          screen: .paper(title: Self.paper, note: "Without √dₖ the scores grow with the key size and softmax saturates."),
                          result: AgentResult(
                    outcome: L("Without it, the scores grow with the key size and softmax saturates."),
                    points: [L("A dot product of two d-long vectors grows about as √d."),
                             L("Dividing by √dₖ keeps the scores near 1, so the weights stay soft.")],
                    anchored: true)),
            ])
        case .calendar:
            return ("When am I free tomorrow?", [
                AgentBeat(activity: L("Checking tomorrow"), work: .reading, object: L("Calendar"),
                          screen: .calendar(day: "Friday, Oct 9", events: [])),
                AgentBeat(activity: L("Free after one tomorrow"), work: .done, state: .complete,
                          screen: .calendar(day: "Friday, Oct 9", events: [
                    ScreenEvent(start: 12, end: 12.5, title: L("Lunch with Ana"), place: "Tartine"),
                ]), result: AgentResult(
                    outcome: L("Free from 1:00 tomorrow."),
                    rows: [AgentResultRow(lead: L("12:00 PM"), text: L("Lunch with Ana"), detail: "Tartine"),
                           AgentResultRow(lead: L("1:00 PM"), text: L("Free until 6:00"))])),
            ])
        case .draft:
            let warmer = L("Hi Sam,\n\nThursday at 3 is perfect, looking forward to it. I'll send an invite this afternoon.\n\nBest,")
            return ("Make it a little warmer.", [
                AgentBeat(activity: L("Rewriting the draft"), work: .editing,
                          screen: .mail(to: "Sam Lee", subject: "Re: Thursday?", body: "Hi Sam,\n\nThursday at 3 is perfect,")),
                AgentBeat(activity: L("Rewrote the draft"), work: .done, state: .complete,
                          screen: .mail(to: "Sam Lee", subject: "Re: Thursday?", body: warmer), result: AgentResult(
                    outcome: L("The same yes, a little warmer."), draft: warmer)),
            ])
        case .code:
            return ("Check it on an external display too.", [
                AgentBeat(activity: L("Running swift test"), work: .running, object: "swift test", screen: .terminal(
                    title: "app-ui-v1 — swift test", lines: [
                        ScreenLine(text: "❯ swift test --filter External", tone: .prompt),
                        ScreenLine(text: "✓ NotchGeometryTests.softwareIslandEars", tone: .ok),
                    ])),
                AgentBeat(activity: L("It holds on an external display"), work: .done, state: .complete, screen: .terminal(
                    title: "app-ui-v1 — swift test", lines: [
                        ScreenLine(text: "❯ swift test --filter External", tone: .prompt),
                        ScreenLine(text: "✓ NotchGeometryTests.softwareIslandEars", tone: .ok),
                        ScreenLine(text: "⏺ It holds on an external display too.", tone: .ok),
                    ]), result: AgentResult(
                    outcome: L("It holds on an external display too."),
                    points: [L("The software island takes the same ear height there.")],
                    artifacts: ["NotchGeometryTests.swift"])),
            ])
        }
    }
}

/// A referent a sample request comes with: one the workbench draws (the paper's formula, Sam's
/// email), or one of Core's screens.
enum V2Referent: Equatable {
    case formula, email
    case screen(String, String)
}

/// A place a request can go: a chat (none: the default agent's quick answer, or a new chat in
/// the project) and why it is suggested.
struct V2Suggestion: Equatable, Identifiable {
    let agent: String
    let chat: String?
    let project: String?
    let reason: String
    var id: String { "\(agent)|\(chat ?? "new")|\(project ?? "")" }
    var quick: Bool { agent == ChatAgent.fovea.id }
    // Oct 18, Ryan: in the primary language.
    var title: String { quick ? L("Quick answer") : (chat ?? L("New chat")) }
}

/// What the person did with the suggestions: the data routing learns from.
enum V2RoutingLabel: Equatable {
    /// The first suggestion, sent as it was (the send button, fn⌃ or Return).
    case keptFirst
    /// Another suggestion (1-based).
    case picked(Int)
    /// One they found browsing every chat.
    case browsed
}

/// A session's size in the notch (Oct 7, docs/island/WHOLE_SESSION.md): usual; or expanded, the
/// whole session, every exchange in it in one centred column, as tall as it needs down to the
/// display's foot, with an outline of its requests at the right. The expand button and left ⌃
/// switch between them; Esc comes back to the usual size, then closes.
enum V2SessionSize: Equatable {
    case usual, expanded
}

/// The panel's Dispatch Version 2 list: the states, each leading to the next.
enum V2Mode: String, CaseIterable, Identifiable {
    case silent, voice, transcribe, send, board, chat, whole, wholeLong, pulled

    var id: String { rawValue }
    var title: String {
        switch self {
        case .silent: return "Silent notch"
        case .voice: return "Voice input"
        case .transcribe: return "Transcribing"
        case .send: return "Choose chat"
        case .board: return "Control board"
        case .chat: return "Expanded chat"
        case .whole: return "Session expanded"
        case .wholeLong: return "Session expanded, many requests"
        case .pulled: return "Pulled out"
        }
    }
}

enum DispatchV2 {
    /// The group the default agent's sessions sit under on the board: they have no project.
    static let quickProject = "Quick answers"
    /// The sample sessions the board shows besides the person's own: two to review, one that
    /// needs them, three at work; with the person's request or two, seven or eight in all.
    static let sampleIds: Set<String> = ["t-snapshots", "t-hero", "t-paste", "t-shortcuts", "t-payload", "t-launch",
                                         "t-docs", "t-tokens"]
}

/// A row of the chat browser that isn't a chat (Oct 15 review, QA04): the list on its way, a list
/// that couldn't load, or a search with nothing in it.
enum V2BrowseStatus: Equatable {
    case loading, failed
    case noMatch(String)
}

/// A row of the chat browser.
enum V2BrowseRow: Identifiable, Equatable {
    case project(ChatProject)
    case back(String)
    case chat(AgentChat)
    /// Oct 15 review, QA04: the rest of a long list, this many more.
    case more(Int)
    case status(V2BrowseStatus)

    var id: String {
        switch self {
        case .project(let p): return "p|" + p.id
        case .back(let folder): return "b|" + folder
        case .chat(let c): return "c|" + c.id
        case .more: return "m|more"
        case .status(let s): return "s|\(s)"
        }
    }

    static func == (a: V2BrowseRow, b: V2BrowseRow) -> Bool { a.id == b.id }
}


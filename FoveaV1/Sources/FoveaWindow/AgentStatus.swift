import AppKit
import SwiftUI
import CapturesCore
import FoveaKit
import FoveaLook
import FoveaPlatform

// Settings › Connectors (Oct 15 review, ST-05.2, ST-06.1, ST-06.2). The agents as this Mac has
// them, found for real (FoveaPlatform's `AgentCheck`: the PATH and the places their installers
// use, `--version`, and Claude Code's `auth status --json` and Codex's `login status`), off the main
// thread, each with a time limit: Ready; Not installed, with the command to install it and its
// page; Not signed in or Sign-in expired, with the command that signs in; or Couldn't check, why,
// and Check Again. Then "Memory for your agents": Fovea's memory server (MCP), which runs on Node,
// found the same way, and is set up in an agent with one command. 1.0 has no memory server: its
// package and source link are placeholders, and an agent counts as set up when its settings name it.

/// The memory server's command for an agent, and its source (placeholders until it ships).
enum MemoryServer {
    static let package = "@hellofovea/memory-mcp"
    static let source = URL(string: "https://github.com/hellofovea/memory-mcp")!
    static let node = URL(string: "https://nodejs.org/en/download")!

    static func setupCommand(_ agent: AgentCLI) -> String {
        switch agent {
        case .claude: return "claude mcp add --scope user fovea-memory -- npx -y \(package)"
        case .codex: return "codex mcp add fovea-memory -- npx -y \(package)"
        }
    }
}

struct ConnectorsPane: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let p = model.panes
        SettingsSection("Agents") {
            CheckedLine()
        } content: {
            SettingsCard {
                ForEach(Array(AgentCLI.allCases.enumerated()), id: \.element) { i, agent in
                    if i > 0 { RowDivider(inset: 56) }
                    AgentRow(agent: agent)
                }
            } footer: {
                Text("Dispatches go to these, through the copy already signed in on this Mac.")
            }
        }
        .task { if p.agentsChecked == nil { await p.checkAgents() } }

        // Who answers, with which model; what a question may include (rows 21, 22).
        QuestionsSections()
            .id("questions")

        MemoryForAgents()
            .id("memory-agents")
    }
}

/// "Checked just now ↻", or "Checking…" while it runs.
private struct CheckedLine: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let p = model.panes
        Button { Task { await p.checkAgents(force: true) } } label: {
            HStack(spacing: 5) {
                if p.checkingAgents {
                    ProgressView().controlSize(.mini)
                    Text("Checking…")
                } else {
                    Text(p.agentsChecked.map { L("Checked \(Lines.relative($0, now: Date()))") } ?? L("Not checked yet"))
                    Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .semibold))
                }
            }
            .font(.system(size: 11.5))
            .foregroundStyle(palette.secondary)
        }
        .buttonStyle(.plain)
        .disabled(p.checkingAgents)
        .help("Check again")
    }
}

/// One agent: its icon and name, what was found (the version, who's signed in, or what's missing
/// and the command that fixes it), and the action that fits.
private struct AgentRow: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.settingsNative) private var native
    let agent: AgentCLI

    var body: some View {
        let p = model.panes
        let result = p.agents[agent]
        HStack(alignment: .center, spacing: native ? 10 : 12) {
            Image(nsImage: Art.agentIcon(agent.title)).resizable().interpolation(.high)
                .frame(width: native ? 24 : 28, height: native ? 24 : 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(agent.title).font(.system(size: 13, weight: native ? .regular : .medium)).foregroundStyle(palette.text)
                if let result {
                    Text(line(result)).font(.system(size: native ? 11 : 11.5)).foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let command = command(result) {
                        Text(command)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(palette.text)
                            .textSelection(.enabled)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(palette.ink(T.Shade.fill)))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(p.checkingAgents ? L("Looking for it on this Mac…") : L("Not checked yet."))
                        .font(.system(size: native ? 11 : 11.5)).foregroundStyle(palette.secondary)
                }
            }
            .frame(maxWidth: 380, alignment: .leading)
            Spacer(minLength: 12)
            controls(result)
        }
        .padding(.horizontal, native ? T.Native.rowInset : 16)
        .padding(.vertical, native ? 8 : 10)
        .frame(minHeight: native ? T.Native.rowHeightWithDetail : 56)
        .help(result?.path ?? "")
    }

    private func line(_ r: AgentCheckResult) -> String {
        switch r.state {
        case .ready:
            return [r.version.map { L("Version \($0)") }, r.account.map { L("signed in as \($0)") }].compactMap { $0 }.joined(separator: " · ")
                .nonEmpty ?? L("Installed on this Mac.")
        case .notInstalled: return L("Not on this Mac. To install it, paste this in Terminal:")
        case .notSignedIn:
            return r.version.map { L("Installed (\($0)), not signed in. To sign in, run this in Terminal:") }
                ?? L("Installed, not signed in. To sign in, run this in Terminal:")
        case .signInExpired: return L("Your sign-in has expired. To sign in again, run this in Terminal:")
        case .couldntCheck(let reason): return L("Couldn't check: \(L(key: reason))")
        }
    }

    private func command(_ r: AgentCheckResult) -> String? {
        switch r.state {
        case .notInstalled: return agent.installCommand
        case .notSignedIn, .signInExpired: return agent.signInCommand
        case .ready, .couldntCheck: return nil
        }
    }

    @ViewBuilder private func controls(_ r: AgentCheckResult?) -> some View {
        let p = model.panes
        if let r {
            switch r.state {
            case .ready:
                StatusLabel(word: "Ready")
            case .notInstalled:
                VStack(alignment: .trailing, spacing: 6) {
                    StatusLabel(word: "Not installed", ok: false)
                    HStack(spacing: 8) {
                        Link("Get It ↗", destination: agent.page).font(.system(size: 12))
                        TextButton(p.copied == agent.installCommand ? L("Copied") : L("Copy Install Command")) { p.copy(agent.installCommand) }
                    }
                }
            case .notSignedIn, .signInExpired:
                VStack(alignment: .trailing, spacing: 6) {
                    StatusLabel(word: r.state == .notSignedIn ? L("Not signed in") : L("Sign-in expired"), ok: false)
                    TextButton(p.copied == agent.signInCommand ? L("Copied") : L("Copy Command")) { p.copy(agent.signInCommand) }
                }
            case .couldntCheck:
                VStack(alignment: .trailing, spacing: 6) {
                    StatusLabel(word: "Couldn't check", ok: false)
                    TextButton("Check Again") { Task { await p.checkAgents(force: true) } }
                        .disabled(p.checkingAgents)
                }
            }
        } else if p.checkingAgents {
            ProgressView().controlSize(.small)
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

/// Memory for your agents (ST-06.1, ST-06.2): whether Fovea's memory server can run here (it needs
/// Node), which agents have it, the command that adds it to each, and how it's set up, step by
/// step, with its source. The Access Log is a click away.
private struct MemoryForAgents: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var panes = model.panes
        let state = serverState
        SettingsSection("Memory for your agents",
                        note: "Fovea's memory server lets Claude Code and Codex search what Fovea remembers. It runs on this Mac.") {
            SettingsCard {
                SettingsRow("Memory server", detail: stateLine(state)) {
                    switch state {
                    case .unavailable: StatusLabel(word: "Unavailable", ok: false)
                    case .notSetUp: StatusLabel(word: "Not set up", ok: false)
                    case .setUp: StatusLabel(word: "Set up")
                    }
                }
                RowDivider()
                SettingsRow("Node.js", detail: nodeLine) {
                    if nodeMissing {
                        Link("Get Node ↗", destination: MemoryServer.node).font(.system(size: 12))
                    }
                }
                .help(model.panes.node?.path ?? "")
                ForEach(AgentCLI.allCases) { agent in
                    RowDivider(inset: 56)
                    SettingsRow(agent.title, detail: agentLine(agent), icon: Art.agentIcon(agent.title)) {
                        if isSetUp(agent) {
                            StatusLabel(word: "Set up")
                        } else {
                            let command = MemoryServer.setupCommand(agent)
                            TextButton(panes.copied == command ? L("Copied") : L("Copy Setup Command")) { panes.copy(command) }
                                .disabled(nodeMissing || (model.panes.mcpStage == nil && model.panes.agents[agent]?.state == .notInstalled))
                        }
                    }
                }
                RowDivider()
                DisclosureGroup(isExpanded: $panes.setupDetailsOpen) {
                    SetupDetails()
                        .padding(.top, 8)
                } label: {
                    Text("Setup details").font(.system(size: 13)).foregroundStyle(palette.text)
                }
                .cardPadding()
            } footer: {
                Text("Agents read your memories, except the ones you hide.")
                Spacer()
                TextButton("Access Log…") { model.accessLogShown = true }
            }
        }
    }

    private var nodeMissing: Bool {
        if let stage = model.panes.mcpStage { return stage == .unavailable }
        return model.panes.nodeChecked && model.panes.node == nil
    }

    private var serverState: MemoryServerState {
        if let stage = model.panes.mcpStage { return stage }
        if nodeMissing { return .unavailable }
        return model.panes.serverSetUp.isEmpty ? .notSetUp : .setUp
    }

    private func isSetUp(_ agent: AgentCLI) -> Bool {
        switch model.panes.mcpStage {
        case .setUp?: return agent == .claude
        case .notSetUp?, .unavailable?: return false
        case nil: return model.panes.serverSetUp.contains(agent)
        }
    }

    private func stateLine(_ state: MemoryServerState) -> String {
        switch state {
        case .unavailable: return "It runs on Node.js, which isn't on this Mac."
        case .notSetUp: return "Add it to an agent below, and the agent can search your memories."
        case .setUp:
            let names = AgentCLI.allCases.filter(isSetUp).map(\.title)
            return L("\(names.joined(separator: L(" and "))) can search your memories.")
        }
    }

    private var nodeLine: String {
        if let stage = model.panes.mcpStage {
            return stage == .unavailable ? "Not found. Install Node 18 or later." : "/usr/local/bin/node · v24.15.0"
        }
        guard model.panes.nodeChecked else { return "Looking for it…" }
        guard let node = model.panes.node else { return "Not found. Install Node 18 or later." }
        return [node.path, node.version].compactMap { $0 }.joined(separator: " · ")
    }

    private func agentLine(_ agent: AgentCLI) -> String {
        if isSetUp(agent) { return "Set up: it can search your memories." }
        if model.panes.agents[agent]?.state == .notInstalled && model.panes.mcpStage == nil { return L("Install \(agent.title) first.") }
        return "Not set up."
    }
}

/// How the memory server goes into an agent: the steps, each agent's command, and its source.
private struct SetupDetails: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            step(1, "Copy the command for your agent.")
            step(2, "Paste it in Terminal and press Return. It adds Fovea's memory server to the agent's settings.")
            step(3, "Start a new chat. The agent can now search what Fovea remembers, and each read shows in the Access Log.")
            ForEach(AgentCLI.allCases) { agent in
                VStack(alignment: .leading, spacing: 3) {
                    Text(agent.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(palette.secondary)
                    Text(MemoryServer.setupCommand(agent))
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(palette.ink(T.Shade.fill)))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 4) {
                Text("It runs with npx, on this Mac, and reads only Fovea's memory.").foregroundStyle(palette.secondary)
                Link("Source ↗", destination: MemoryServer.source)
            }
            .font(.system(size: 11.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: "\(n)").font(.system(size: 11, weight: .semibold)).foregroundStyle(palette.secondary).frame(width: 12)
            Text(L(key: text)).font(.system(size: 12)).foregroundStyle(palette.text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

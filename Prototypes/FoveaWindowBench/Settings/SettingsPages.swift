import SwiftUI
import AppKit
import WindowBenchCore

/// A tab of the Settings window: System Settings' grouped inset rows (R03-01).
struct SettingsPage: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    let tab: SettingsTab

    var body: some View {
        let palette = Palette.make(model.v(SurfaceVariant.self), dark: scheme == .dark)
        Group {
            switch tab {
            case .general: GeneralSettings()
            case .notch: NotchSettings()
            case .connections: ConnectionsSettings()
            case .memory: MemorySettings()
            }
        }
        .formStyle(.grouped)
        .environment(\.palette, palette)
        .environment(\.motion, model.motion)
        .frame(width: BenchTokens.Layout.settingsSize.width, height: BenchTokens.Layout.settingsSize.height)
    }
}

// MARK: - General

/// Launch at login, the three gestures as read-only rows with a conflict check, and the two
/// pop-downs' sounds. Nothing else (brief 03).
struct GeneralSettings: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Toggle("Open Fovea at login", isOn: $model.settings.launchAtLogin)
            } footer: {
                Note("Fovea lives in the menu bar and around the notch; closing this window doesn't quit it.")
            }
            Section {
                GestureRow(title: "Transcribe", detail: "Type what you say into the app in front of you", keys: ["fn"],
                           conflict: model.simulateFnConflict ? FnConflict.dictation : FnConflict.current)
                GestureRow(title: "Dispatch", detail: "Send what you say, and what you point at, to an agent", keys: ["fn", "⌃"], conflict: nil)
                GestureRow(title: "Answer now", detail: "Ask a short question and get the answer in the notch", keys: ["fn", "⌥"], conflict: nil)
            } header: {
                Text("Voice gestures")
            } footer: {
                Note("\(model.v(GestureCopy.self).howTo) The gestures belong to the notch; this window binds no keys.")
            }
            Section("Sounds") {
                Toggle("When a run needs you", isOn: $model.settings.soundNeedsYou)
                Toggle("A minute before a meeting", isOn: $model.settings.soundMeeting)
            }
        }
    }
}

/// What macOS does with a press of fn, which Transcribe would fight (R03-05: name the exact
/// system setting). Read from the keyboard's own preference, never written.
enum FnConflict {
    static let dictation = "Keyboard › Press 🌐 key to: Start Dictation"

    static var current: String? {
        let usage = UserDefaults(suiteName: "com.apple.HIToolbox")?.integer(forKey: "AppleFnUsageType") ?? 0
        switch usage {
        case 1: return "Keyboard › Press 🌐 key to: Change Input Source"
        case 2: return "Keyboard › Press 🌐 key to: Show Emoji & Symbols"
        case 3: return "Keyboard › Press 🌐 key to: Start Dictation"
        default: return nil
        }
    }
}

private struct GestureRow: View {
    @Environment(\.palette) private var palette
    let title: String
    let detail: String
    let keys: [String]
    let conflict: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(detail).font(.system(size: 11)).foregroundStyle(palette.secondary)
                }
                Spacer()
                HStack(spacing: 4) { ForEach(keys, id: \.self) { KeyCap($0) } }
            }
            if let conflict {
                HStack(spacing: 6) {
                    Text("!").font(BenchTokens.Glyph.bangFont)
                    Text("Conflicts with \(conflict)")
                        .font(BenchTokens.Type_.mono(11))
                    Spacer()
                    Button("Open Keyboard Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .controlSize(.small)
                }
                .foregroundStyle(palette.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Connections

/// One row per agent, then each agent's hooks block (the exact file, what was added, Install and
/// Remove), history access with its folders, other notch apps, Calendar (brief 03; R03-02,
/// R03-03, R03-04).
struct ConnectionsSettings: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                Section {
                    // Each list keys its rows in its own namespace: the Form flattens them into one.
                    // The glyph column only when some agent draws a glyph: with every agent
                    // connected (no glyph under "● = needs you"), the names sit on the Form's edge.
                    let marked = model.v(ConnectionGlyphs.self) == .brief || model.drawnAgents.contains { $0.state != .connected }
                    ForEach(model.library.agents, id: \.rowKey) { agent in AgentRow(agent: agent, glyphColumn: marked) }
                } header: {
                    Text("Agents")
                } footer: {
                    Note("Fovea hears from an agent through a small hook in the agent's own settings. Everything below says exactly what it changes.")
                }
                .id("agents")
                ForEach(model.library.agents.filter { $0.state != .notFound }, id: \.hooksKey) { agent in
                    HooksBlock(agent: agent)
                        .id("hooks/\(agent.kind.rawValue)")
                }
                Section {
                    ForEach(model.library.agents, id: \.historyKey) { agent in HistoryRow(agent: agent) }
                } header: {
                    Text("History")
                } footer: {
                    Note("Only sessions active in the last 30 days. Fovea lists these folders and reads their dates on this Mac; nothing is uploaded.")
                }
                .id("history")
                if model.state.otherNotchApp {
                    OtherNotchApp()
                        .id("other-notch")
                }
                CalendarSection()
                    .id("calendar")
            }
            .onChange(of: model.settingsScrollTarget, initial: true) { _, target in
                // No target: back to the very top (the first group's bottom edge in view clamps to it).
                // "<id>#bottom" brings a group's last line into view and as much above it as fits.
                if let target, target.hasSuffix("#bottom") {
                    proxy.scrollTo(String(target.dropLast("#bottom".count)), anchor: .bottom)
                } else if let target {
                    proxy.scrollTo(target, anchor: .top)
                } else {
                    proxy.scrollTo("agents", anchor: .bottom)
                }
            }
        }
    }
}

/// glyph · name over `version · path` (mono) · the state word and the last event (mono).
private struct AgentRow: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let agent: AgentConnection
    let glyphColumn: Bool

    var body: some View {
        // A real Form row (label · value), so the grouped Form keeps it in its section's box.
        LabeledContent {
            VStack(alignment: .trailing, spacing: 2) {
                // The word swaps the notch's way (rise and blur), never printed over the old one.
                SwapText(agent.state != .notFound && model.hookState(agent.kind).isUntrusted ? "Not trusted yet" : model.connectionState(agent).title)
                    .foregroundStyle(palette.secondary)
                SwapText(agent.lastEvent.map { "last event \(Lines.age($0, now: model.index.now)) ago" } ?? "no events yet")
                    .font(BenchTokens.Type_.mono(11))
                    .foregroundStyle(palette.tertiary)
            }
        } label: {
            HStack(spacing: 10) {
                if glyphColumn {
                    ConnectionGlyph(state: model.connectionState(agent), size: 9)
                        .frame(width: BenchTokens.Layout.glyphSlot)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.kind.name)
                    Text([agent.version, agent.binaryPath].compactMap { $0 }.joined(separator: " · ").ifEmpty("not found in /opt/homebrew/bin, /usr/local/bin"))
                        .font(BenchTokens.Type_.mono(11))
                        .foregroundStyle(palette.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// One agent's hooks, fully transparent (R03-04 names the file each action writes; R03-03 shows
/// the lines rather than editing silently).
private struct HooksBlock: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let agent: AgentConnection
    @State private var open = false

    var body: some View {
        let state = model.hookState(agent.kind)
        Section {
            LabeledContent("File") {
                Text(agent.hooksFile).font(BenchTokens.Type_.mono(11.5)).textSelection(.enabled)
            }
            if model.v(HooksDetail.self) == .always {
                RawText(text: agent.hooksText)
            } else {
                DisclosureGroup("What Fovea added", isExpanded: $open) {
                    RawText(text: agent.hooksText)
                }
            }
            HStack {
                // The line swaps the notch's way, out then in; the button's title changes at once,
                // as a push button's does.
                SwapText(state.line)
                    .font(BenchTokens.Type_.mono(11))
                    .foregroundStyle(palette.secondary)
                Spacer()
                Button(state.installed ? "Remove hooks" : "Install hooks") {
                    if state.installed { model.removeHooks(agent.kind) } else { model.installHooks(agent.kind) }
                }
                .transaction { $0.animation = nil }
            }
            if agent.kind == .codex && state.isUntrusted {
                HStack(spacing: 8) {
                    StateGlyph(state: .waiting)
                    Note("Installed. Codex asks you to trust this hook in its own /hooks screen the next time it starts; until then Fovea hears from notify.")
                }
            }
            if agent.kind == .cursor {
                Note("Cursor also runs the Claude Code hook (Third-Party Imports is on), so Fovea tells the two apart by the event's source.")
            }
        } header: {
            Text("\(agent.kind.name) hooks")
        }
        .animation(model.motion.animation(.swap), value: state)
    }
}

/// Raw text, as the file holds it: mono, selectable, no syntax color.
private struct RawText: View {
    @Environment(\.palette) private var palette
    let text: String

    var body: some View {
        // Wrapped, never clipped: this is the block that shows exactly what was added.
        Text(text)
            .font(BenchTokens.Type_.mono(11))
            .foregroundStyle(palette.text)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: BenchTokens.Layout.wellRadius, style: .continuous).fill(palette.well))
    }
}

private struct HistoryRow: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let agent: AgentConnection

    var body: some View {
        // An agent that isn't on this Mac has no history to read: off, and not a choice.
        let present = model.connectionState(agent) != .notFound
        Toggle(isOn: Binding(get: { present && agent.historyAccess }, set: { model.setHistoryAccess(agent.kind, $0) })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(present ? agent.kind.name : "\(agent.kind.name) · not on this Mac")
                ForEach(agent.historyFolders, id: \.self) { folder in
                    let error = model.readError(folder: folder, of: agent.kind)
                    HStack(spacing: 6) {
                        Text(folder).foregroundStyle(error == nil ? palette.secondary : palette.tertiary)
                        if let error { ReadErrorMark(error: error) }
                    }
                    .font(BenchTokens.Type_.mono(11))
                }
            }
        }
        .disabled(!present)
    }
}

/// Another app drawing at the notch (brief item 9, simulated from the panel).
private struct OtherNotchApp: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        Section("Other notch apps") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Boring Notch is also using the notch. The two will overlap.")
                Text("It also added a hook to ~/.claude/settings.json")
                    .font(BenchTokens.Type_.mono(11))
                    .foregroundStyle(palette.secondary)
                HStack {
                    Spacer()
                    Button("Keep both") { model.state.otherNotchApp = false; model.status = "Kept both notch apps" }
                    Button("Quit it") { model.state.otherNotchApp = false; model.status = "Asked Boring Notch to quit (simulated)" }
                }
            }
        }
    }
}

private struct CalendarSection: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        Section {
            HStack {
                // The group is "Calendar"; its one row says what Fovea may do with it.
                VStack(alignment: .leading, spacing: 2) {
                    Text("Access")
                    Text(model.state.calendarGranted ? "Full access" : (model.state.calendarDenied ? "Not allowed" : "Not asked yet"))
                        .font(.system(size: 11))
                        .foregroundStyle(palette.secondary)
                }
                Spacer()
                if model.state.calendarDenied {
                    // Once refused, only System Settings can change it.
                    Button("Open Privacy & Security") { model.status = "Would open Privacy & Security › Calendars (simulated)" }
                } else if !model.state.calendarGranted {
                    Button("Allow Calendar Access…") { model.state.calendarGranted = true; model.status = "Calendar access granted (simulated)" }
                        .help("Simulated in the bench: no permission is requested")
                }
            }
        } header: {
            Text("Calendar")
        } footer: {
            Note("The notch's Today view and meeting alerts read your calendar.")
        }
    }
}

/// A grey line of explanation under a group.
struct Note: View {
    @Environment(\.palette) private var palette
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(palette.secondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}

private extension AgentConnection {
    var rowKey: String { "agent/\(kind.rawValue)" }
    var hooksKey: String { "hooks/\(kind.rawValue)" }
    var historyKey: String { "history/\(kind.rawValue)" }
}

// MARK: - Model

/// A hook's state on one agent: simulated, no file is ever written by the bench.
enum HookState: Equatable {
    case installed(Date)
    case untrusted(Date)
    case notInstalled
    case restored(Date)

    var isUntrusted: Bool { if case .untrusted = self { return true } else { return false } }

    var installed: Bool {
        switch self {
        case .installed, .untrusted: return true
        case .notInstalled, .restored: return false
        }
    }

    static func == (a: HookState, b: HookState) -> Bool {
        switch (a, b) {
        case (.installed(let x), .installed(let y)), (.untrusted(let x), .untrusted(let y)), (.restored(let x), .restored(let y)): return x == y
        case (.notInstalled, .notInstalled): return true
        default: return false
        }
    }

    /// `installed 09-28 10:12 · a byte-exact backup kept` and so on.
    var line: String {
        switch self {
        case .installed(let d): return "installed \(Lines.day(d)) \(Lines.clock(d)) · a byte-exact backup is kept"
        case .untrusted(let d): return "installed \(Lines.day(d)) \(Lines.clock(d)) · waiting for Codex's trust"
        case .notInstalled: return "not installed"
        case .restored(let d): return "removed · file restored as it was before install · \(Lines.day(d)) \(Lines.clock(d))"
        }
    }
}

/// The settings the General tab shows. Simulated: none of them reaches the system.
struct BenchSettings: Codable, Hashable {
    var launchAtLogin = true
    var soundNeedsYou = true
    var soundMeeting = false
}

extension BenchModel {
    /// An agent's hooks: what this session did to them, or else what the library says (a
    /// connected agent has its hooks in).
    func hookState(_ kind: AgentKind) -> HookState {
        if let state = hooks[kind] { return state }
        guard let agent = library.agents.first(where: { $0.kind == kind }) else { return .notInstalled }
        return agent.state == .connected ? .installed(agent.lastEvent ?? index.now) : .notInstalled
    }

    /// An agent's connection as every surface draws it, from its hooks: in and trusted is
    /// connected; missing, removed, or not yet trusted by Codex needs you; an agent that isn't on
    /// this Mac stays not found.
    func connectionState(_ agent: AgentConnection) -> ConnectionState {
        if agent.state == .notFound { return .notFound }
        if case .installed = hookState(agent.kind) { return .connected }
        return .hooksMissing
    }

    /// The agents, each in the state it's drawn in.
    var drawnAgents: [AgentConnection] {
        library.agents.map { agent in
            var drawn = agent
            drawn.state = connectionState(agent)
            return drawn
        }
    }

    func installHooks(_ kind: AgentKind) {
        animate(.swap) { hooks[kind] = kind == .codex ? .untrusted(index.now) : .installed(index.now) }
        status = "Installed \(kind.name) hooks (simulated: no file was written)"
    }

    func removeHooks(_ kind: AgentKind) {
        animate(.swap) { hooks[kind] = .restored(index.now) }
        status = "Removed \(kind.name) hooks (simulated: no file was written)"
    }

    func setHistoryAccess(_ kind: AgentKind, _ on: Bool) {
        guard let i = library.agents.firstIndex(where: { $0.kind == kind }) else { return }
        library.agents[i].historyAccess = on
    }
}

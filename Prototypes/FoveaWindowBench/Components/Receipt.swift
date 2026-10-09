import SwiftUI
import WindowBenchCore

/// The receipt the notch and the window share (§8): your words → what the agent did, computed →
/// ▲ what differs from what you asked → the agent's one sentence, signed → actions. ▲ is the
/// only emphasis. Drawn the notch's way on black, or the same card on paper or in system style.
struct ReceiptCard: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var windowPalette
    let run: Run
    var surface: ReceiptSurface? = nil
    var width: CGFloat? = BenchTokens.Notch.slabWidth

    var body: some View {
        let surface = surface ?? model.v(ReceiptSurface.self)
        let palette = surface == .notch ? Palette.notch : windowPalette
        let radius: CGFloat = surface == .system ? 10 : BenchTokens.Notch.slabRadius
        ReceiptContent(run: run)
            .environment(\.palette, palette)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(width: width, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(surface == .notch ? BenchTokens.Notch.surface : (surface == .paper ? windowPalette.raised : Color(nsColor: .controlBackgroundColor)))
            }
            .overlay {
                if surface != .notch {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(windowPalette.hairline)
                }
            }
            .environment(\.colorScheme, surface == .notch ? .dark : (windowPalette.isDark ? .dark : .light))
    }
}

struct ReceiptContent: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let run: Run

    var body: some View {
        let thread = model.index.thread(of: run)
        VStack(alignment: .leading, spacing: 12) {
            // 1 · your words
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                StateGlyph(state: run.state).alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                Text(run.words)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // 2 · what the agent did, computed
            EvidenceLines(run: run)
            // 3 · ▲ what differs from what you asked
            if !run.differences.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(run.differences.prefix(3), id: \.self) { difference in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("▲").font(.system(size: 10, weight: .bold))
                            Text(difference).font(BenchTokens.Type_.difference)
                        }
                        .foregroundStyle(palette.text)
                    }
                }
            }
            // The run's own state, when it needs you or failed.
            StateDetail(run: run)
            // 4 · the agent's sentence, signed
            if let line = run.agentLine {
                (Text(line).foregroundStyle(palette.text) + Text(Lines.signature(thread?.agent.name ?? "")).foregroundStyle(palette.tertiary))
                    .font(.system(size: 13.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            // 5 · actions
            ReceiptActions(run: run)
        }
    }
}

/// The computed lines: each file with its change kind and counts, each command with its result,
/// or, while running, the last three things the agent did.
struct EvidenceLines: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let run: Run

    var body: some View {
        let size: CGFloat = 11.5
        VStack(alignment: .leading, spacing: 3) {
            if run.state == .running {
                ForEach(Array(run.lastActions.suffix(3).enumerated()), id: \.offset) { i, action in
                    Text(action).foregroundStyle(i == min(2, run.lastActions.count - 1) ? palette.text : palette.secondary)
                }
            } else if run.state == .unobserved {
                EmptyView()
            } else {
                ForEach(Array(run.edits.enumerated()), id: \.offset) { _, edit in
                    HStack(spacing: 10) {
                        Text(edit.kind.rawValue).foregroundStyle(palette.tertiary)
                        Text(edit.path).foregroundStyle(palette.secondary).lineLimit(1).truncationMode(.head)
                        Spacer(minLength: 8)
                        if edit.added + edit.removed > 0 {
                            Text("+\(edit.added) −\(edit.removed)").foregroundStyle(palette.secondary)
                        }
                    }
                }
                ForEach(Array(run.commands.enumerated()), id: \.offset) { _, command in
                    HStack(spacing: 10) {
                        Text("$").foregroundStyle(palette.tertiary)
                        Text(command.command).foregroundStyle(palette.secondary).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(command.exitCode == 0 ? "passed" : "exit \(command.exitCode)").foregroundStyle(palette.secondary)
                    }
                }
                if run.edits.isEmpty && run.commands.isEmpty && run.state != .waiting && run.state != .failed {
                    Text(Lines.evidence(run)).foregroundStyle(palette.secondary)
                }
            }
        }
        .font(BenchTokens.Type_.mono(size))
    }
}

/// Waiting or failed: what it waits on, raw, and the choices.
struct StateDetail: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let run: Run

    var body: some View {
        switch (run.state, run.stuck) {
        case (.waiting, .permission(let kind, let raw)?):
            VStack(alignment: .leading, spacing: 8) {
                Text(kind == .command ? "Wants to run" : kind == .diff ? "Wants to change" : "Wants to open")
                    .font(.system(size: 12)).foregroundStyle(palette.secondary)
                Text(raw)
                    .font(BenchTokens.Type_.mono(12))
                    .foregroundStyle(palette.text)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(palette.well))
            }
        case (.waiting, .question(let text, _)?):
            Text(text).font(.system(size: 13.5)).foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
        case (.failed, _):
            if let failure = run.failure {
                FailureLog(failure: failure, key: "failure/\(run.id)")
            }
        case (.unobserved, _):
            Text("Fovea handed this to your open session. It can't see what happens next.")
                .font(.system(size: 13)).foregroundStyle(palette.secondary)
        default:
            EmptyView()
        }
    }
}

/// 接着改 · 带我去 · 过 (only while not reviewed) · Stop (only while running).
struct ReceiptActions: View {
    @Environment(BenchModel.self) private var model
    let run: Run

    var body: some View {
        HStack(spacing: 6) {
            // What the state asks for comes first, on the same row as the run's own actions.
            switch (run.state, run.stuck) {
            case (.waiting, .permission?):
                Pill("Allow", primary: true) { model.answer(run.id, "Allowed") }
                Pill("Always allow") { model.answer(run.id, "Always allowed") }
                Pill("Deny") { model.answer(run.id, "Denied") }
                divider
            case (.waiting, .question(_, let options)?):
                // The agent's options, side by side, none of them put forward.
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Pill(option) { model.answer(run.id, option) }
                }
                divider
            case (.failed, _):
                Pill("Retry", primary: true) { model.retry(run.id) }
                Pill("Try another agent") { model.status = "Would send it to another agent" }
                Pill("Drop it") { model.drop(run.id) }
                divider
            default:
                EmptyView()
            }
            Pill(model.verbs.followUp) { model.followUp(run.id) }
            Pill(model.verbs.takeMeThere) { model.takeMeThere(run.id) }
            if !run.reviewed && (run.state == .finished || run.state == .seen) {
                Pill(model.verbs.pass) { model.pass(run.id) }
            }
            if run.state == .running { Pill("Stop") { model.stop(run.id) } }
        }
    }

    @Environment(\.palette) private var palette

    private var divider: some View {
        Rectangle().fill(palette.hairline).frame(width: 1, height: 14).padding(.horizontal, 4)
    }
}

/// The notch's gray capsule (Allow, Copy): 24 pt, 12 semibold.
struct Pill: View {
    @Environment(\.palette) private var palette
    let title: String
    var primary = false
    let action: () -> Void
    @State private var hover = false

    init(_ title: String, primary: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.primary = primary; self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BenchTokens.Notch.pillFont)
                .foregroundStyle(primary ? palette.prominentText : palette.text)
                .padding(.horizontal, 12)
                .frame(height: 24)
                .background(Capsule().fill(primary ? palette.prominentFill.opacity(hover ? 0.85 : 1)
                                                    : (hover ? palette.pressed.opacity(palette.isDark ? 2.3 : 1.6) : palette.fill.opacity(palette.isDark ? 2.1 : 1.4))))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .fixedSize()
    }
}

/// A failed command's own output, behind a disclosure: the receipt says what failed; the log is
/// there when you want it.
private struct FailureLog: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let failure: Failure
    let key: String

    var body: some View {
        let open = model.openFold == key
        VStack(alignment: .leading, spacing: 6) {
            Button { model.toggleFold(key) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right").font(.system(size: 8, weight: .bold))
                        .rotationEffect(.degrees(open ? 90 : 0))
                    Text("\(failure.command)'s output").font(.system(size: 12))
                }
                .foregroundStyle(palette.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            InlineExpand(open: open) {
                Text(failure.tail)
                    .font(BenchTokens.Type_.mono(11))
                    .foregroundStyle(palette.secondary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(palette.well))
            }
        }
    }
}

extension BenchModel {
    func answer(_ runID: String, _ choice: String) {
        guard let i = library.runs.firstIndex(where: { $0.id == runID }) else { return }
        animate(.swap) {
            library.runs[i].state = .running
            library.runs[i].stuck = nil
            library.runs[i].lastActions.append("You answered: \(choice)")
            arrivals.remove(runID)
        }
        verdicts[runID] = choice
        status = "Answered: \(choice)"
    }

    func retry(_ runID: String) {
        guard let i = library.runs.firstIndex(where: { $0.id == runID }) else { return }
        animate(.swap) {
            let run = library.runs[i]
            library.runs[i].earlierAttempts.insert(Attempt(number: run.attempt, started: run.started, line: Lines.evidence(run)), at: 0)
            library.runs[i].attempt += 1
            library.runs[i].state = .running
            library.runs[i].failure = nil
            library.runs[i].started = library.now
            library.runs[i].finished = nil
            library.runs[i].lastActions = ["Retrying"]
        }
        status = "Retrying"
    }

    func drop(_ runID: String) {
        guard let i = library.runs.firstIndex(where: { $0.id == runID }) else { return }
        animate(.swap) {
            library.runs[i].state = .seen
            library.runs[i].reviewed = true
        }
        status = "Dropped"
    }
}

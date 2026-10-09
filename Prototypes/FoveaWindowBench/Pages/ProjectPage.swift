import SwiftUI
import WindowBenchCore

/// 2b · a project: its name, where it lives and who works in it (mono), what changed since you
/// last looked (mono, left out when nothing did), a Brief if you asked for one, and its threads
/// as sections, the way Things sets headings in one scrolling page (A2).
struct ProjectPage: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let projectID: String

    var body: some View {
        if let project = model.index.projectByID[projectID] {
            let scale = BenchTokens.Type_.scale(model.v(TypeScale.self))
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 5) {
                        if model.v(BreadcrumbStyle.self) != .largeTitle {
                            Text(project.name)
                                .font(BenchTokens.Type_.pageTitle)
                                .foregroundStyle(palette.text)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .rowFrame("header/project/\(project.id)")
                                .opacity(model.morphingTitle == project.id ? 0 : 1)
                        }
                        Text(Lines.projectHeaderMeta(project, index: model.index))
                            .font(BenchTokens.Type_.mono(scale.meta))
                            .foregroundStyle(palette.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let since = Lines.sinceLastVisit(project, index: model.index) {
                            HStack(spacing: 6) {
                                // A label, so sans; the values after it are computed, so mono.
                                Text("Since your last visit")
                                    .font(.system(size: scale.meta + 0.5))
                                    .foregroundStyle(palette.tertiary)
                                Text(since)
                                    .foregroundStyle(palette.text)
                                    .contentTransition(.numericText())
                            }
                            .font(BenchTokens.Type_.mono(scale.meta))
                            .padding(.top, 3)
                        }
                    }
                    .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
                    .padding(.bottom, 18)

                    if let phase = model.briefs[project.id] {
                        // Its slot opens through layout, pushing the threads down; nothing slides
                        // over the header above it.
                        BriefBlock(projectID: project.id, phase: phase)
                            .padding(.bottom, 22)
                            .modifier(GrowIn())
                            .transition(.opacity)
                    }

                    if project.scan != nil {
                        ScanNote(project: project)
                    }

                    ForEach(model.index.threads(in: project.id)) { thread in
                        ThreadSection(thread: thread)
                            .padding(.bottom, BenchTokens.Layout.threadGap)
                            .zIndex(model.correction == "thread/\(thread.id)" ? 1 : 0)
                    }
                }
                .frame(maxWidth: BenchTokens.Layout.column, alignment: .leading)
                .padding(.horizontal, BenchTokens.Layout.sideMargin)
                .padding(.top, BenchTokens.Layout.topMargin)
                .padding(.bottom, BenchTokens.Layout.bottomMargin)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// A project the history scan found: the scan never opens a session, so it can't name threads.
private struct ScanNote: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let project: Project

    var body: some View {
        Text("\(project.scan?.sessions ?? 0) sessions found by date. Their threads and runs appear once Fovea reads them.")
            .font(BenchTokens.Type_.mono(BenchTokens.Type_.scale(model.v(TypeScale.self)).meta))
            .foregroundStyle(palette.tertiary)
            .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
    }
}

/// One thread: its heading (glyph · name · agent) with the routing Fovea inferred, underlined
/// and correctable; the runs still asking for you; the ones you've seen behind a fold; and runs
/// from other projects that belong to this conversation, marked ↗.
struct ThreadSection: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let thread: ProjectThread

    var body: some View {
        let split = ThreadRuns.split(model.index.runs(in: thread.id))
        let foldKey = "earlier/\(thread.id)"
        VStack(alignment: .leading, spacing: 0) {
            ThreadHeader(thread: thread)
                .padding(.bottom, 4)
                .jumpHighlight("thread/\(thread.id)")
                // Its correction card draws over the runs below it, not under them.
                .zIndex(model.correction == "thread/\(thread.id)" ? 1 : 0)
            ForEach(split.visible) { run in
                RunRow(run: run, context: thread.id)
            }
            ForEach(thread.references, id: \.self) { id in
                if let run = model.index.runByID[id] { ReferenceRow(run: run, context: thread.id) }
            }
            if !split.earlier.isEmpty {
                FoldRow(title: ThreadRuns.earlierTitle(split.earlier.count), open: model.openFold == foldKey) {
                    model.toggleFold(foldKey)
                }
                InlineExpand(open: model.openFold == foldKey) {
                    VStack(spacing: 0) {
                        ForEach(split.earlier) { run in RunRow(run: run, context: thread.id) }
                    }
                }
            }
        }
    }
}

struct ThreadHeader: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let thread: ProjectThread

    var body: some View {
        let style = model.v(ThreadHeaderStyle.self)
        let state = model.index.state(ofThread: thread.id)
        let L = BenchTokens.Layout.self
        let scale = BenchTokens.Type_.scale(model.v(TypeScale.self))
        switch style {
        case .things:
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: L.glyphGap) {
                    StateGlyph(state: state)
                    Text(thread.title)
                        .font(.system(size: scale.body, weight: .semibold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                }
                Rectangle().fill(palette.hairline).frame(height: L.hairline)
                InferenceLink(key: "thread/\(thread.id)", inference: thread.routing)
                    .padding(.leading, model.v(StateStyle.self) == .wordTint ? 0 : L.glyphSlot + L.glyphGap)
            }
            .padding(.horizontal, L.rowPaddingH)
        case .codex:
            HStack(spacing: 8) {
                Text(thread.title)
                    .font(.system(size: scale.body - 1, weight: .medium))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                InferenceLink(key: "thread/\(thread.id)", inference: thread.routing)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, L.rowPaddingH)
            .padding(.top, 2)
        case .large:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: L.glyphGap) {
                    StateGlyph(state: state)
                    Text(thread.title)
                        .font(BenchTokens.Type_.threadLarge)
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                }
                InferenceLink(key: "thread/\(thread.id)", inference: thread.routing)
                    .padding(.leading, model.v(StateStyle.self) == .wordTint ? 0 : L.glyphSlot + L.glyphGap)
            }
            .padding(.horizontal, L.rowPaddingH)
            .padding(.bottom, 4)
        }
    }
}

/// glyph · your words · what the agent did, computed, in mono · time. Truncates your words
/// first-last, the evidence before them; never wraps on one line.
struct RunRow: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let run: Run
    let context: String
    @State private var hover = false

    var body: some View {
        let L = BenchTokens.Layout.self
        let scale = BenchTokens.Type_.scale(model.v(TypeScale.self))
        let twoLines = model.v(RunRowStyle.self) == .twoLines
        let compact = model.v(DensityVariant.self) == .compact
        let key = "run/\(context)/\(run.id)"
        let height = twoLines ? (compact ? L.runRowTwoLines.compact : L.runRowTwoLines.regular)
                              : (compact ? L.runRow.compact : L.runRow.regular)
        HStack(spacing: L.glyphGap) {
            StateGlyph(state: run.state, arriving: model.arrivals.contains(run.id))
                .modifier(PulseOnHighlight(key: key))
            if twoLines {
                VStack(alignment: .leading, spacing: 2) {
                    words(scale)
                    HStack(spacing: 8) {
                        evidence(scale)
                        captures(scale)
                    }
                    .layoutPriority(1)
                }
                Spacer(minLength: 8)
            } else {
                words(scale)
                    .frame(maxWidth: L.runWordsMax, alignment: .leading)
                    .layoutPriority(2)
                evidence(scale)
                    .frame(minWidth: L.evidenceMin, alignment: .leading)
                    .layoutPriority(1)
                Spacer(minLength: 8)
            }
            StateWord(state: run.state)
            // The slot is as wide as what it shows, so the evidence gets the rest of the row.
            TrailingSlot(hover: hover || model.hoverKey == key, width: nil, actions: actions) {
                HStack(spacing: 8) {
                    if !twoLines { captures(scale) }
                    AgeText(date: run.lastActivity)
                }
            }
        }
        .padding(.horizontal, L.rowPaddingH)
        .frame(height: height)
        .background(RoundedRectangle(cornerRadius: L.rowRadius, style: .continuous).fill(hover || model.hoverKey == key ? palette.hover : .clear))
        .contentShape(Rectangle())
        .jumpHighlight(key)
        .rowFrame(key)
        .onHover { hover = $0 }
        .onTapGesture { model.drill(into: .run(run.id), from: key) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.drill(into: .run(run.id), from: key) }
        .id(key)
    }

    private func words(_ scale: BenchTokens.Type_.Scale) -> some View {
        Text(run.words)
            .font(.system(size: scale.body))
            .foregroundStyle(run.state == .seen ? palette.secondary : palette.text)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private func evidence(_ scale: BenchTokens.Type_.Scale) -> some View {
        Text(Lines.evidence(run))
            .font(BenchTokens.Type_.mono(scale.meta))
            .foregroundStyle(palette.tertiary)
            .lineLimit(1)
            .truncationMode(.tail)
            .contentTransition(.opacity)
    }

    @ViewBuilder private func captures(_ scale: BenchTokens.Type_.Scale) -> some View {
        if let label = Lines.usedCaptures(run.captureIDs.count) {
            Button(label) { model.showCaptures(of: run.id) }
                .buttonStyle(ChipLinkStyle(size: scale.meta - 0.5))
                .fixedSize()
                .help("Show the captures this run used")
        }
    }

    private var actions: [RowAction] {
        var list = [RowAction(title: model.verbs.followUp) { model.followUp(run.id) },
                    RowAction(title: model.verbs.takeMeThere) { model.takeMeThere(run.id) }]
        if !run.reviewed && (run.state == .finished || run.state == .seen) {
            list.append(RowAction(title: model.verbs.pass) { model.pass(run.id) })
        }
        if run.state == .running { list.append(RowAction(title: "Stop") { model.stop(run.id) }) }
        return list
    }
}

/// A run that lives in another project but belongs here: no actions, a ↗, and a click opens it
/// where it lives.
struct ReferenceRow: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let run: Run
    let context: String
    @State private var hover = false

    var body: some View {
        let L = BenchTokens.Layout.self
        let scale = BenchTokens.Type_.scale(model.v(TypeScale.self))
        let project = model.index.project(of: run)?.name ?? ""
        HStack(spacing: L.glyphGap) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(palette.tertiary)
                .frame(width: model.v(StateStyle.self) == .wordTint ? nil : L.glyphSlot)
            // The words and where they live share the row: each cuts its own end, neither
            // collapses to a sliver.
            Text(run.words)
                .font(.system(size: scale.body))
                .foregroundStyle(palette.secondary)
                .lineLimit(1)
                .frame(minWidth: 120, alignment: .leading)
                .layoutPriority(1)
            Text("in \(project)")
                .font(BenchTokens.Type_.mono(scale.meta))
                .foregroundStyle(palette.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 90, alignment: .leading)
            Spacer(minLength: 8)
            Text(Lines.age(run.lastActivity, now: model.index.now))
                .font(BenchTokens.Type_.mono(scale.meta))
                .foregroundStyle(palette.tertiary)
                .frame(width: L.actionSlot, alignment: .trailing)
        }
        .padding(.horizontal, L.rowPaddingH)
        .frame(height: L.runRow.regular)
        .background(RoundedRectangle(cornerRadius: L.rowRadius, style: .continuous).fill(hover ? palette.hover : .clear))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { model.jump(toRun: run.id) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isLink)
        .accessibilityLabel("\(run.words), in \(project). Open where it lives")
        .help("Open in \(project)")
    }
}

/// A Brief: written by an agent on request, signed and rendered as received (7d).
struct BriefBlock: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let projectID: String
    let phase: BriefPhase
    private static let headerHeight: CGFloat = 22

    var body: some View {
        let brief = model.library.briefs[projectID]
            ?? BriefDoc(agent: model.index.threads(in: projectID).first?.agent ?? .claudeCode, written: model.index.now,
                        markdown: "**No Brief yet.** The agent hasn't written one for this project.")
        let scale = BenchTokens.Type_.scale(model.v(TypeScale.self))
        // The run rows' anatomy: a glyph column, then the text. The glyph shows while the agent
        // writes; its column stays when it goes, so nothing beside it moves.
        HStack(alignment: .top, spacing: BenchTokens.Layout.glyphGap) {
            ZStack {
                if phase == .writing {
                    RunningGlyph(drawing: model.v(GlyphDrawing.self))
                        .transition(.opacity)
                }
            }
            .frame(width: BenchTokens.Layout.glyphSlot, height: Self.headerHeight)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    // Only the word that changes swaps: "writing" becomes the time, out then in.
                    HStack(spacing: 0) {
                        Text("Brief by \(brief.agent.name) · ")
                        SwapText(phase == .writing ? "writing" : Lines.clock(brief.written))
                    }
                    Spacer()
                    if phase == .written {
                        Button("Copy as Markdown") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(brief.markdown, forType: .string)
                            model.status = "Copied the Brief as Markdown"
                        }
                        .font(.system(size: 11))
                        .controlSize(.small)
                        .transition(.opacity)
                    }
                }
                // As tall as the button that joins it, so the line doesn't drop when it does.
                .frame(height: Self.headerHeight)
                .font(BenchTokens.Type_.mono(scale.meta))
                .foregroundStyle(palette.secondary)
                if phase == .written {
                    // The text arrives after the block has room for it, a beat behind (GrowIn).
                    MarkdownText(markdown: brief.markdown)
                        .modifier(GrowIn())
                        .transition(.opacity)
                }
            }
        }
        .clipped()
        .padding(16)
        .background(RoundedRectangle(cornerRadius: BenchTokens.Layout.cardRadius, style: .continuous).fill(palette.well))
        .overlay(RoundedRectangle(cornerRadius: BenchTokens.Layout.cardRadius, style: .continuous).strokeBorder(palette.hairline))
    }
}

/// Markdown rendered as typeset text, block by block, never rewritten.
struct MarkdownText: View {
    @Environment(\.palette) private var palette
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let text):
                    Text(inline(text)).font(.system(size: 15, weight: .semibold)).foregroundStyle(palette.text)
                case .bullet(let text):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(palette.tertiary)
                        Text(inline(text)).foregroundStyle(palette.text)
                    }
                    .font(BenchTokens.Type_.markdownBody)
                case .paragraph(let text):
                    Text(inline(text)).font(BenchTokens.Type_.markdownBody).foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .textSelection(.enabled)
    }

    enum Block { case heading(String), bullet(String), paragraph(String) }

    private var blocks: [Block] {
        markdown.components(separatedBy: "\n").compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { return nil }
            if line.hasPrefix("## ") { return .heading(String(line.dropFirst(3))) }
            if line.hasPrefix("- ") { return .bullet(String(line.dropFirst(2))) }
            return .paragraph(line)
        }
    }

    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }
}

/// A small chip that is plainly a control: mono, a quiet fill, darker on hover.
struct ChipLinkStyle: ButtonStyle {
    @Environment(\.palette) private var palette
    let size: CGFloat
    @State private var hover = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BenchTokens.Type_.mono(size))
            .foregroundStyle(hover ? palette.text : palette.secondary)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(Capsule().fill(configuration.isPressed ? palette.pressed : (hover ? palette.selected : palette.fill)))
            .onHover { hover = $0 }
    }
}

/// A text link in mono: underlined on hover.
struct LinkTextStyle: ButtonStyle {
    @Environment(\.palette) private var palette
    let size: CGFloat
    @State private var hover = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BenchTokens.Type_.mono(size))
            .foregroundStyle(hover ? palette.text : palette.secondary)
            .underline(hover)
            .onHover { hover = $0 }
    }
}

extension BenchModel {
    func followUp(_ runID: String) {
        guard let run = index.runByID[runID], let thread = index.thread(of: run) else { return }
        status = "Follow up: the next fn ⌃ goes to \(thread.title)"
    }

    /// 过: the run has been looked at; recorded in the verdict log.
    func pass(_ runID: String) {
        guard let i = library.runs.firstIndex(where: { $0.id == runID }) else { return }
        animate(.swap) {
            library.runs[i].reviewed = true
            if library.runs[i].state == .finished { library.runs[i].state = .seen }
        }
        verdicts[runID] = "passed \(Lines.clock(Date()))"
        status = "\(verbs.pass): logged"
    }

    func stop(_ runID: String) {
        guard let i = library.runs.firstIndex(where: { $0.id == runID }) else { return }
        animate(.swap) {
            library.runs[i].state = .seen
            library.runs[i].finished = library.now
            library.runs[i].lastActions.append("Stopped by you")
        }
        status = "Stopped"
    }

    /// Used N captures: the Capture view, scrolled to them.
    func showCaptures(of runID: String) {
        guard let run = index.runByID[runID], let first = run.captureIDs.first else { return }
        jump(toCapture: first)
    }
}

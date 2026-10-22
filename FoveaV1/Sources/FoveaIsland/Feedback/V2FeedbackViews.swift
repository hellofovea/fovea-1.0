import SwiftUI
import AppKit
import FoveaCore
import FoveaLook
import FoveaKit

// The Oct 6 feedback's Dispatch Version 2 views (V2Feedback.swift has the flow).
// docs/island/FEEDBACK_2026-10-06.md has the reasons.

// MARK: - Markdown, as the agent wrote it (#11)

/// The blocks an agent's Markdown is made of. Whatever it wrote is shown as it wrote it: no
/// fixed layout is laid over it (the dev team's point on #11, accepted).
enum MarkdownBlock: Equatable {
    case heading(String)
    case paragraph(String)
    case bullets([String])
    case numbered([String])
    case quote(String)
    case code(String)
    case table([[String]])

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = [], bullets: [String] = [], numbered: [String] = [], quote: [String] = []
        var table: [[String]] = [], code: [String]? = nil
        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))); paragraph = [] }
            if !bullets.isEmpty { blocks.append(.bullets(bullets)); bullets = [] }
            if !numbered.isEmpty { blocks.append(.numbered(numbered)); numbered = [] }
            if !quote.isEmpty { blocks.append(.quote(quote.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))); quote = [] }
            if !table.isEmpty { blocks.append(.table(table)); table = [] }
        }
        for raw in markdown.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                if let lines = code { blocks.append(.code(lines.joined(separator: "\n"))); code = nil }
                else { flush(); code = [] }
                continue
            }
            if code != nil { code?.append(raw); continue }
            if line.isEmpty { flush(); continue }
            if line.hasPrefix(">") {
                if quote.isEmpty { flush() }
                quote.append(String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix("|") {
                if table.isEmpty { flush() }
                let cells = line.trimmingCharacters(in: CharacterSet(charactersIn: "|")).components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                if cells.allSatisfy({ $0.allSatisfy { "-: ".contains($0) } }) { continue }
                table.append(cells)
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                if bullets.isEmpty { flush() }
                bullets.append(String(line.dropFirst(2)))
            } else if let dot = line.firstIndex(of: "."), line[..<dot].allSatisfy(\.isNumber), !line[..<dot].isEmpty {
                if numbered.isEmpty { flush() }
                numbered.append(String(line[line.index(after: dot)...]).trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix("#") {
                flush()
                blocks.append(.heading(line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)))
            } else {
                paragraph.append(line)
            }
        }
        if let lines = code { blocks.append(.code(lines.joined(separator: "\n"))) }
        flush()
        return blocks
    }

    /// The words without their marks, for measuring.
    static func plain(_ inline: String) -> String {
        (try? AttributedString(markdown: inline, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            .map { String($0.characters) } ?? inline
    }

    /// How tall the blocks are at a width (the island's outline is laid out before the view).
    static func height(_ markdown: String, width: CGFloat) -> CGFloat {
        let F = WorkbenchTokens.FeedbackV2.self
        let blocks = parse(markdown)
        var h: CGFloat = 0
        for block in blocks {
            switch block {
            case .heading(let t): h += V2Geometry.measure(plain(t), size: F.headingSize, weight: .semibold, width: width)
            case .paragraph(let t): h += V2Geometry.measure(plain(t), size: F.answerSize, width: width, spacing: F.answerSpacing)
            case .bullets(let items), .numbered(let items):
                for item in items {
                    h += V2Geometry.measure(plain(item), size: F.answerSize, width: width - F.bulletMarker - F.bulletGap,
                                            spacing: F.answerSpacing) + F.bulletSpacing
                }
            case .quote(let t):
                h += V2Geometry.measure(plain(t), size: F.answerSize, width: width - 2 * F.quotePaddingH, spacing: F.answerSpacing)
                    + 2 * F.quotePaddingV
            case .code(let t): h += CGFloat(t.components(separatedBy: "\n").count) * F.codeLine + 2 * F.codePadding
            case .table(let rows): h += CGFloat(rows.count) * F.tableRow + 4
            }
        }
        return h + CGFloat(max(0, blocks.count - 1)) * F.blockGap
    }
}

/// The agent's Markdown drawn on the island: white at its opacities, links and code a little
/// brighter, a table as a table, a quote (a draft) on a raised card.
struct MarkdownView: View {
    let markdown: String
    let width: CGFloat

    var body: some View {
        let F = WorkbenchTokens.FeedbackV2.self
        VStack(alignment: .leading, spacing: F.blockGap) {
            ForEach(Array(MarkdownBlock.parse(markdown).enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(width: width, alignment: .topLeading)
        .environment(\.openURL, OpenURLAction { _ in .handled })
    }

    @ViewBuilder private func blockView(_ block: MarkdownBlock) -> some View {
        let F = WorkbenchTokens.FeedbackV2.self
        switch block {
        case .heading(let text):
            Text(Self.inline(text)).font(.system(size: F.headingSize, weight: .semibold)).foregroundStyle(F.answerStrong)
        case .paragraph(let text):
            Text(Self.inline(text)).font(F.answerFont).foregroundStyle(F.answerColor).lineSpacing(F.answerSpacing)
                .fixedSize(horizontal: false, vertical: true)
        case .bullets(let items), .numbered(let items):
            let numbered: Bool = { if case .numbered = block { return true }; return false }()
            VStack(alignment: .leading, spacing: F.bulletSpacing) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .firstTextBaseline, spacing: F.bulletGap) {
                        Text(numbered ? "\(i + 1)." : "•").foregroundStyle(WorkbenchTokens.V2.subColor)
                            .frame(width: F.bulletMarker, alignment: .leading)
                        Text(Self.inline(item)).foregroundStyle(F.answerColor).lineSpacing(F.answerSpacing)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(F.answerFont)
                }
            }
        case .quote(let text):
            Text(Self.inline(text)).font(F.answerFont).foregroundStyle(F.answerStrong).lineSpacing(F.answerSpacing)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, F.quotePaddingH).padding(.vertical, F.quotePaddingV)
                .frame(width: width, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: F.quoteRadius, style: .continuous).fill(F.quoteFill))
        case .code(let text):
            Text(text).font(F.codeFont).foregroundStyle(F.codeColor)
                .padding(F.codePadding)
                .frame(width: width, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: F.codeRadius, style: .continuous).fill(F.quoteFill))
        case .table(let rows):
            Grid(alignment: .leading, horizontalSpacing: F.tableSpacing, verticalSpacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { r, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { c, cell in
                            Text(Self.inline(cell))
                                .font(r == 0 ? F.tableHeader : (c == 0 ? .system(size: F.tableLeadSize, design: .serif).italic() : .system(size: F.tableCellSize)))
                                .foregroundStyle(r == 0 ? WorkbenchTokens.V2.subColor : (c == 0 ? F.answerStrong : F.answerColor))
                                .lineLimit(1)
                                .frame(height: F.tableRow)
                        }
                    }
                    if r == 0 { Rectangle().fill(F.tableRule).frame(height: 1).gridCellColumns(row.count) }
                }
            }
        }
    }

    /// Inline Markdown (bold, italics, code, links), styled for the island.
    static func inline(_ text: String) -> AttributedString {
        var attributed = (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
        for run in attributed.runs {
            if run.link != nil {
                attributed[run.range].foregroundColor = WorkbenchTokens.skin(Color.white.opacity(0.98), WorkbenchTokens.Native.accent)
                attributed[run.range].underlineStyle = Text.LineStyle(pattern: .solid, color: WorkbenchTokens.skin(Color.white.opacity(0.35), WorkbenchTokens.Native.accent.opacity(0.4)))
            }
            if run.inlinePresentationIntent?.contains(.code) == true {
                attributed[run.range].font = .system(size: WorkbenchTokens.FeedbackV2.inlineCodeSize, design: .monospaced)
                attributed[run.range].foregroundColor = WorkbenchTokens.ink(0.95)
                attributed[run.range].backgroundColor = WorkbenchTokens.ink(0.08)
            }
        }
        return attributed
    }
}

// MARK: - The answer: what it did folded, the words, what it made (#11–13)

/// A session's answer: what it did, folded to one line; the answer as written; what to open.
struct V2Answer: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let width: CGFloat

    var body: some View {
        let F = WorkbenchTokens.FeedbackV2.self
        VStack(alignment: .leading, spacing: F.answerGap) {
            if !task.steps.isEmpty {
                V2WorkFold(model: model, work: model.v2Work(task), key: task.id, width: width)
            }
            // The agent's own words: its Markdown answer, else the reply it finished with.
            if let answer = task.answer ?? task.reply {
                MarkdownView(markdown: answer, width: width)
            } else if let result = task.result {
                Text(result.outcome).font(F.answerFont).foregroundStyle(F.answerColor)
            }
            let artifacts = model.v2Artifacts(task)
            if !artifacts.isEmpty, task.state == .complete {
                V2ArtifactsRow(model: model, artifacts: artifacts, taskID: task.id)
            }
        }
        .frame(width: width, alignment: .topLeading)
    }

    /// Its height at a width, for the island's outline.
    static func height(model: WorkbenchModel, task: AgentTaskItem, width: CGFloat) -> CGFloat {
        let F = WorkbenchTokens.FeedbackV2.self
        var h: CGFloat = 0
        var parts = 0
        if !task.steps.isEmpty {
            h += V2WorkFold.height(model.v2Work(task), open: model.v2StepsOpen.contains(task.id), width: width)
            parts += 1
        }
        if let answer = task.answer ?? task.reply { h += MarkdownBlock.height(answer, width: width); parts += 1 }
        else if task.result != nil { h += 20; parts += 1 }
        if task.state == .complete, !model.v2Artifacts(task).isEmpty { h += F.artifactHeight; parts += 1 }
        return h + CGFloat(max(0, parts - 1)) * F.answerGap
    }
}

/// What the agent did for an exchange, folded under its answer (Oct 7, docs/island/WHOLE_SESSION.md):
/// "Worked for 1m 12s · Edited 2 files ›". Opened, in order: each step, the tool, what it acted
/// on and what came of it (an edit's lines, a command passing or failing, a search's matches); and
/// between them what the agent said along the way. All as the agents report them (V2Steps.swift):
/// no command output, no thinking text. Folded until the person opens it.
struct V2WorkFold: View {
    let model: WorkbenchModel
    let work: V2Work
    /// Which fold this is in `v2StepsOpen`: the session's id now, `V2Work.key` for one before.
    let key: String
    let width: CGFloat
    @State private var hovering = false

    var body: some View {
        let F = WorkbenchTokens.FeedbackV2.self
        let open = model.v2StepsOpen.contains(key)
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(WorkbenchTokens.V2.resize) {
                    // In the expanded session, it opens downward from where the person is.
                    model.v2HistoryHeld = true
                    if open { model.v2StepsOpen.remove(key) } else { model.v2StepsOpen.insert(key) }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(work.summary()).lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(F.stepsChevron)
                        .rotationEffect(.degrees(open ? 90 : 0))
                }
                .font(F.stepsFont)
                .foregroundStyle(hovering ? F.stepsHover : F.stepsColor)
                .frame(height: F.stepsRow)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .help(open ? "Fold what it did" : "What it did: the tools it used, the files it edited, what it said along the way")
            if open {
                VStack(alignment: .leading, spacing: F.workGap) {
                    ForEach(Array(work.entries.enumerated()), id: \.offset) { _, entry in
                        switch entry {
                        case .remark(let words):
                            Text(words)
                                .font(F.stepsFont)
                                .foregroundStyle(F.workRemark)
                                .fixedSize(horizontal: false, vertical: true)
                        case .step(let step):
                            V2WorkStepRow(step: step)
                        }
                    }
                }
                .frame(width: width - F.stepsIndent, alignment: .leading)
                .padding(.leading, F.stepsIndent)
                .overlay(alignment: .leading) { Rectangle().fill(F.workRule).frame(width: 1) }
                .padding(.top, F.workTop)
                .padding(.bottom, F.stepsBottom)
                .transition(.opacity)
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// Its height at a width, folded or open, for the island's outline.
    static func height(_ work: V2Work, open: Bool, width: CGFloat) -> CGFloat {
        let F = WorkbenchTokens.FeedbackV2.self
        guard open else { return F.stepsRow }
        var h = F.stepsRow + F.workTop + F.stepsBottom
        for (i, entry) in work.entries.enumerated() {
            if i > 0 { h += F.workGap }
            switch entry {
            case .remark(let words): h += V2Geometry.measure(words, size: F.stepsSize, width: width - F.stepsIndent, spacing: 0)
            case .step: h += F.workRow
            }
        }
        return h
    }
}

/// One step it took, done: its glyph; the tool, as a verb, and what it acted on (a command or a
/// pattern in code); at the right, what came of it.
struct V2WorkStepRow: View {
    let step: AgentLiveStep

    var body: some View {
        let F = WorkbenchTokens.FeedbackV2.self
        let S = WorkbenchTokens.Steps.self
        HStack(spacing: F.workGlyphGap) {
            Image(systemName: step.kind.symbol)
                .font(F.workGlyph)
                .foregroundStyle(S.glyph)
                .frame(width: F.workGlyphWidth)
            line.lineLimit(1).truncationMode(.middle)
            Spacer(minLength: F.workResultGap)
            result
        }
        .frame(height: F.workRow)
        .accessibilityElement(children: .combine)
    }

    private var line: Text {
        let F = WorkbenchTokens.FeedbackV2.self
        let S = WorkbenchTokens.Steps.self
        var line = Text(step.kind.pastVerb).font(F.stepsFont).foregroundColor(S.verb)
        if let object = step.kind == .search ? step.object.map({ "\u{201C}\($0)\u{201D}" }) : step.object {
            line = line + Text(" ") + Text(object)
                .font(step.kind.codeObject ? F.workCode : F.workObject)
                .foregroundColor(S.object)
        }
        return line
    }

    @ViewBuilder private var result: some View {
        let F = WorkbenchTokens.FeedbackV2.self
        let S = WorkbenchTokens.Steps.self
        if let added = step.added, let removed = step.removed, added + removed > 0 {
            // Only what moved: a file only added to shows +N.
            HStack(spacing: 4) {
                if added > 0 { Text("+\(added)").foregroundStyle(S.added) }
                if removed > 0 { Text("\u{2212}\(removed)").foregroundStyle(S.removed) }
            }
            .font(F.workCount)
        } else if let passed = step.passed {
            Text(passed ? "passed" : "failed").font(F.stepsFont)
                .foregroundStyle(passed ? S.verb : WorkbenchTokens.Panel.failedColor)
        } else if let note = step.note {
            Text(note).font(F.stepsFont).foregroundStyle(S.verb)
        }
    }
}

/// What the answer made or points at, each a way to check it first-hand: Open IslandShape.swift
/// (its lines), Open the paper, Open Calendar.
struct V2ArtifactsRow: View {
    let model: WorkbenchModel
    let artifacts: [V2Artifact]
    /// The session they're from (Oct 15 review, QA20: its bar says when a copy can't be saved).
    var taskID: String? = nil

    var body: some View {
        HStack(spacing: WorkbenchTokens.FeedbackV2.artifactGap) {
            ForEach(artifacts) { artifact in
                V2ArtifactButton(model: model, artifact: artifact, taskID: taskID)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Open what the answer made; and, for a file (Oct 15 review, QA20), Show in Finder and Save a
/// Copy… in its menu.
struct V2ArtifactButton: View {
    let model: WorkbenchModel
    let artifact: V2Artifact
    var taskID: String? = nil
    @State private var hovering = false

    var body: some View {
        let F = WorkbenchTokens.FeedbackV2.self
        Group {
            if artifact.path != nil {
                Menu {
                    Button("Open") { model.openArtifactV2(artifact, taskID: taskID) }
                    Button("Show in Finder") { model.showArtifactInFinder(artifact, taskID: taskID) }
                    Divider()
                    Button("Save a Copy…") { model.saveArtifactCopy(artifact, taskID: taskID) }
                } label: {
                    label(F)
                } primaryAction: {
                    model.openArtifactV2(artifact, taskID: taskID)
                }
                .menuStyle(.button)
                .menuIndicator(.visible)
                .buttonStyle(IslandPressStyle())
                .fixedSize()
            } else {
                Button { model.openArtifactV2(artifact, taskID: taskID) } label: { label(F) }
                    .buttonStyle(IslandPressStyle())
            }
        }
        .padding(.trailing, artifact.path != nil ? F.artifactPaddingH * 0.6 : 0)
        .background(Capsule(style: .continuous).fill(hovering ? F.artifactFillHover : F.artifactFill))
        .contentShape(Capsule(style: .continuous))
        .onHover { hovering = $0 }
        .help(artifact.path != nil ? L("Open \(artifact.title), or show it in Finder, or save a copy") : L("\(artifact.openLabel) to check it yourself"))
    }

    private func label(_ F: WorkbenchTokens.FeedbackV2.Type) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.forward.square").font(F.artifactGlyph)
            Text(artifact.openLabel).lineLimit(1)
        }
        .font(F.artifactFont)
        .foregroundStyle(WorkbenchTokens.V2.titleColor)
        .padding(.leading, F.artifactPaddingH)
        .padding(.trailing, artifact.path != nil ? 2 : F.artifactPaddingH)
        .frame(height: F.artifactHeight)
    }
}

// MARK: - Choose chat: one stack, the model (#1)

/// What was taken, as one stack (front card, two peeking behind); under the pointer it opens into a
/// row, each card readable and a click away from a closer look. Oct 21, Ryan ("simpler is better"):
/// the stack lies flat (no tilt) and the row fades in over it (no growing, no spring).
struct V2ReferentPile: View {
    let model: WorkbenchModel
    @State private var fanned = false
    @State private var overPile = false
    @State private var overFan = false
    @State private var closing: Task<Void, Never>?

    var body: some View {
        let F = WorkbenchTokens.FeedbackV2.self
        let T = WorkbenchTokens.Referents.self
        let items = model.liveReferents
        let w = F.pileHeight * F.pileAspect
        let pileWidth = w + 2 * F.pileOffset
        // Oct 15 review, QA02: past three, "+N" on the stack, as the voice bar has it.
        let hidden = max(0, items.count - 3)
        ZStack(alignment: .leading) {
            // The stack's own footprint: it never pushes the pills.
            Color.clear.frame(width: pileWidth + (hidden > 0 ? T.moreGap + StackLayout.moreWidth(hidden) : 0),
                              height: F.pileHeight)
            ForEach(Array(items.prefix(3).enumerated().reversed()), id: \.element.id) { i, referent in
                let s = 1 - CGFloat(i) * F.pileShrink
                Image(nsImage: referent.image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: w * s, height: F.pileHeight * s)
                    .clipShape(RoundedRectangle(cornerRadius: WorkbenchTokens.V2.attachmentRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: WorkbenchTokens.V2.attachmentRadius, style: .continuous)
                        .strokeBorder(WorkbenchTokens.ink(0.2), lineWidth: 0.75))
                    .opacity(fanned ? 0 : (i == 0 ? 1 : F.pileBackOpacity))
                    // Each card behind peeks past the right edge of the one before it.
                    .offset(x: w * (1 - s) + CGFloat(i) * F.pileOffset)
            }
            if hidden > 0 {
                ReferentMoreChip(count: hidden)
                    .offset(x: pileWidth + T.moreGap)
                    .opacity(fanned ? 0 : 1)
            }
        }
        .frame(height: F.pileHeight)
        .contentShape(Rectangle())
        .onHover { overPile = $0; updateFan() }
        // Fanned: every referent in one row over the pills, numbered in the order taken, swiped
        // sideways when it's wider than Choose chat (an overlay, so the pills never move).
        .overlay(alignment: .leading) {
            if fanned {
                fan(items)
                    .offset(x: -F.fanPadding)
                    .onHover { overFan = $0; updateFan() }
                    .transition(.opacity)
            }
        }
        .zIndex(10)
        .help(items.enumerated().map { "\($0.offset + 1) · \($0.element.kind.label) · \($0.element.whereTaken)" }.joined(separator: "\n"))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("What was taken")
    }

    /// The row: each referent's thumb with its number (and the other display's glyph), in one line
    /// that scrolls past Choose chat's width.
    @ViewBuilder
    private func fan(_ items: [CapturedReferent]) -> some View {
        let F = WorkbenchTokens.FeedbackV2.self
        let T = WorkbenchTokens.Referents.self
        let V = WorkbenchTokens.V2.self
        let row = HStack(spacing: F.fanGap) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, referent in
                V2AttachmentThumb(model: model, referent: referent)
                    .overlay(alignment: .topLeading) {
                        ReferentNumberBadge(number: i + 1)
                            .scaleEffect(F.fanBadgeScale, anchor: .topLeading)
                            .padding(F.fanBadgeInset)
                            .allowsHitTesting(false)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if referent.otherDisplay {
                            ReferentOtherDisplayBadge()
                                .scaleEffect(F.fanBadgeScale, anchor: .bottomTrailing)
                                .padding(F.fanBadgeInset)
                        }
                    }
            }
        }
        let natural = items.map { min(V.attachThumb * $0.aspect, V.attachThumb * 2) }.reduce(0, +)
            + CGFloat(max(0, items.count - 1)) * F.fanGap
        let most = V2Geometry.contentWidth - 2 * F.fanPadding
        Group {
            if natural > most {
                ScrollView(.horizontal) { row }
                    .scrollIndicators(.automatic)
                    .frame(width: most)
            } else {
                row
            }
        }
        .padding(F.fanPadding)
        .background(RoundedRectangle(cornerRadius: F.fanRadius, style: .continuous).fill(F.fanFill))
        .overlay(RoundedRectangle(cornerRadius: F.fanRadius, style: .continuous).strokeBorder(WorkbenchTokens.ink(0.1), lineWidth: 0.75))
        .fixedSize()
        .animation(T.numberFade, value: items.count)
    }

    /// Open while the pointer is on the stack or the row; it closes a moment after it leaves both
    /// (moving from one to the other is never a leave).
    private func updateFan() {
        let F = WorkbenchTokens.FeedbackV2.self
        closing?.cancel()
        if overPile || overFan {
            if !fanned { withAnimation(F.fanMotion) { fanned = true } }
            return
        }
        closing = Task { @MainActor in
            try? await Task.sleep(for: F.fanCloseDelay)
            guard !Task.isCancelled, !overPile, !overFan else { return }
            withAnimation(F.fanMotion) { fanned = false }
        }
    }
}

/// The model and thinking effort beside the chat: "Auto", or "Sonnet 5 · High"; a click opens
/// the sheet under the row.
struct V2ModelPill: View {
    let model: WorkbenchModel
    @State private var hovering = false

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let C = WorkbenchTokens.Chat.self
        Button { model.toggleModelSheet() } label: {
            HStack(spacing: 6) {
                Image(systemName: "brain").font(V.pillGlyph).foregroundStyle(V.subColor)
                Text(model.v2ModelLabel(agent: model.v2Pick.agent))
                    .font(V.pillFont)
                    .foregroundStyle(V.titleColor)
                    .lineLimit(1)
                Image(systemName: model.v2ModelSheet ? "chevron.up" : "chevron.down")
                    .font(V.pillChevron).foregroundStyle(V.subColor)
            }
            .padding(.horizontal, V.pillPaddingH)
            .frame(height: V.pillHeight)
            .frame(maxWidth: WorkbenchTokens.FeedbackV2.modelPillMax)
            .fixedSize(horizontal: true, vertical: false)
            .background(Capsule(style: .continuous).fill(hovering ? C.pillFillHover : C.pillFill))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(IslandPressStyle())
        .onHover { hovering = $0 }
        .help("The model and how hard it thinks. Auto lets Fovea pick")
        .accessibilityLabel("Model, \(model.v2ModelLabel(agent: model.v2Pick.agent))")
    }
}

/// The sheet: the chat's agent's models, then how hard it thinks; Auto first in each.
struct V2ModelSheet: View {
    let model: WorkbenchModel
    var showsChats = false

    var body: some View {
        let F = WorkbenchTokens.FeedbackV2.self
        VStack(alignment: .leading, spacing: F.sheetGap) {
            if showsChats {
                row(L("Chat")) {
                    ForEach(model.v2Suggestions) { pick in
                        V2SheetChip(title: pick.title, icon: pick.agent, chosen: model.v2Pick == pick) { model.chooseV2(pick) }
                    }
                }
            }
            row(L("Model")) {
                // Oct 15 review, QA08: the models on their way, or couldn't load (Try Again); one
                // chosen for another agent, or not in the plan, dimmed (the notes say why).
                if model.cases.modelsLoad != .loaded {
                    V2ModelsStatus(model: model)
                } else {
                    if let carried = model.v2CarriedModel {
                        V2SheetChip(title: carried.name, chosen: false, unavailable: carried.reason) {}
                    }
                    V2SheetChip(title: L("Auto"), chosen: model.v2Model == nil || model.v2CarriedModel != nil) { model.chooseModel(nil) }
                    ForEach(model.v2ModelOptions) { option in
                        V2SheetChip(title: option.name, chosen: model.v2Model == option.id,
                                    unavailable: model.v2ModelUnavailable(option)) { model.chooseModel(option.id) }
                    }
                }
            }
            row(L("island.row.thinking", english: "Thinking")) {
                V2SheetChip(title: L("Auto"), chosen: model.v2Effort == nil) { model.chooseEffort(nil) }
                ForEach(model.v2EffortOptions, id: \.self) { effort in
                    V2SheetChip(title: ModelCatalog.effortName(effort), chosen: model.v2Effort == effort) { model.chooseEffort(effort) }
                }
            }
            // Oct 15 review, QA09: how far the session goes without asking; set by the agent's own
            // settings, it can't be changed here (the notes say where).
            row(L("Approvals")) {
                ForEach(V2ApprovalMode.allCases) { mode in
                    V2SheetChip(title: mode.title, chosen: model.cases.approvalMode == mode,
                                unavailable: model.cases.approvalLocked != nil && model.cases.approvalMode != mode
                                    ? model.cases.approvalLocked : nil) { model.chooseApprovalMode(mode) }
                        .help(mode.help)
                }
                if model.cases.approvalLocked != nil {
                    Image(systemName: "lock.fill").font(WorkbenchTokens.Cases.blockedGlyph).foregroundStyle(WorkbenchTokens.V2.subColor)
                }
            }
            let notes = model.v2ModelNotes
            if !notes.isEmpty {
                V2ModelNotesLine(notes: notes)
                    .padding(.leading, WorkbenchTokens.FeedbackV2.sheetLabelWidth + WorkbenchTokens.FeedbackV2.sheetChipGap)
            }
        }
    }

    private func row<C: View>(_ label: String, @ViewBuilder chips: () -> C) -> some View {
        let F = WorkbenchTokens.FeedbackV2.self
        return HStack(spacing: F.sheetChipGap) {
            Text(label).font(WorkbenchTokens.V2.labelFont).foregroundStyle(WorkbenchTokens.V2.labelColor)
                .frame(width: F.sheetLabelWidth, alignment: .leading)
            chips()
            Spacer(minLength: 0)
        }
        .frame(height: F.sheetRow)
    }

    /// Its height, for the outline: the rows (the chats, the model, thinking, approvals) and, when
    /// a model can't be picked or the approvals are set elsewhere, a line of notes (Oct 15 review).
    static func height(chats: Bool, notes: Int = 0) -> CGFloat {
        let F = WorkbenchTokens.FeedbackV2.self
        let rows: CGFloat = chats ? 4 : 3
        return rows * F.sheetRow + (rows - 1) * F.sheetGap + (notes > 0 ? F.sheetGap + CGFloat(notes) * WorkbenchTokens.Cases.detailRow : 0)
    }
}

struct V2SheetChip: View {
    let title: String
    var icon: String? = nil
    let chosen: Bool
    /// Oct 15 review, QA08/QA09: why it can't be picked; dimmed and struck through, the why on hover.
    var unavailable: String? = nil
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let F = WorkbenchTokens.FeedbackV2.self
        let V = WorkbenchTokens.V2.self
        let off = unavailable != nil
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon { ChatAgentIcon(agent: ChatAgent.named(icon), size: F.sheetChipIcon) }
                Text(title).lineLimit(1).strikethrough(off, color: WorkbenchTokens.ink(0.4))
                if chosen { Image(systemName: "checkmark").font(F.sheetCheck) }
            }
            .font(F.sheetChipFont)
            .foregroundStyle(chosen ? V.titleColor : WorkbenchTokens.ink(off ? 0.35 : 0.7))
            .padding(.horizontal, F.sheetChipPaddingH)
            .frame(height: F.sheetChipHeight)
            .background(Capsule(style: .continuous).fill(chosen ? V.chipChosenFill : (hovering && !off ? V.hoverFill : V.chipFill)))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(IslandPressStyle())
        .disabled(off)
        .onHover { hovering = $0 }
        .help(unavailable ?? "")
        .animation(nil, value: chosen)
    }
}

// MARK: - The queue (#24)

/// What waits for a working session: each message (and anything taken with it), Send now to
/// put it into this turn, ✕ to drop it; held while the session waits on the person, Resume.
struct V2QueueSection: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let width: CGFloat

    var body: some View {
        let F = WorkbenchTokens.FeedbackV2.self
        let V = WorkbenchTokens.V2.self
        let items = model.v2Queue[task.id] ?? []
        let paused = model.v2QueuePaused.contains(task.id)
        VStack(alignment: .leading, spacing: F.queueSpacing) {
            ViewThatFits(in: .horizontal) {
                header(paused: paused, note: true)
                header(paused: paused, note: false)
            }
            .frame(height: F.queueHeader)
            ForEach(items) { ask in
                HStack(spacing: 8) {
                    ForEach(Array(ask.images.prefix(2).enumerated()), id: \.offset) { _, image in
                        Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                            .frame(width: F.queueThumb * 1.3, height: F.queueThumb)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    if ask.failed {
                        // Oct 15 review, QA11: it couldn't send; it stays, to try again or remove.
                        Text("Couldn't send").font(F.queueNote.weight(.semibold)).foregroundStyle(WorkbenchTokens.Panel.failedColor)
                            .fixedSize()
                    }
                    Text(ask.text).font(F.queueText).foregroundStyle(ask.failed ? V.subColor : V.bodyColor).lineLimit(1)
                    Spacer(minLength: 6)
                    if ask.failed {
                        AgentPanelButton(title: L("Try Again"), symbol: "arrow.clockwise", primary: false) { model.retryQueued(task.id, ask) }
                        AgentPanelButton(title: L("Remove"), primary: false) { model.cancelQueued(task.id, ask) }
                    } else {
                        AgentPanelButton(title: L("Send now"), symbol: "arrow.turn.down.right", primary: false) { model.sendQueuedNow(task.id, ask) }
                            .help("Put it into this turn now, out of the line")
                        Button { model.cancelQueued(task.id, ask) } label: {
                            Image(systemName: "xmark").font(F.queueCloseGlyph).foregroundStyle(V.subColor)
                                .frame(width: F.queueClose, height: F.queueClose).contentShape(Rectangle())
                        }
                        .buttonStyle(IslandPressStyle()).help("Don't send it")
                    }
                }
                .padding(.horizontal, F.queueRowPaddingH)
                .frame(height: F.queueRow)
                .background(RoundedRectangle(cornerRadius: F.queueRowRadius, style: .continuous).fill(F.queueFill))
            }
        }
        .frame(width: width, alignment: .topLeading)
    }

    /// The queue's header: held, Resume, and (Oct 15 review, QA12) Open in the agent, to manage it
    /// there; narrow, without the note.
    private func header(paused: Bool, note: Bool) -> some View {
        let F = WorkbenchTokens.FeedbackV2.self
        let V = WorkbenchTokens.V2.self
        let why = task.state == .needsYou ? L("until you answer above") : L("after a failure")
        return HStack(spacing: 6) {
            Text(paused ? "WAITING · HELD" : "WAITING").font(V.labelFont).tracking(0.6).foregroundStyle(V.labelColor)
                .help(paused ? "Held \(why)" : "")
            if paused {
                if note { Text(why).font(F.queueNote).foregroundStyle(V.subColor) }
                Spacer(minLength: 4)
                if model.v2OpensInAgent(task) {
                    // Oct 17, Ryan: the same Open in <agent> as the session's bar, one way.
                    V2OpenInAgentChip(model: model, task: task, iconOnly: !note,
                                      note: ("QA12", "A held queue: Resume, or Open in the agent to manage it there"))
                }
                AgentPanelButton(title: L("Resume"), symbol: "play.fill", primary: false) { model.resumeQueue(task.id) }
            } else {
                Spacer(minLength: 4)
            }
        }
    }

    static func height(count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        let F = WorkbenchTokens.FeedbackV2.self
        return F.queueHeader + F.queueSpacing + CGFloat(count) * (F.queueRow + F.queueSpacing) - F.queueSpacing
    }
}

// MARK: - Answer again and stop (#23)

/// A small gray chip with a glyph.
struct V2IconChip: View {
    let symbol: String
    var title: String? = nil
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let F = WorkbenchTokens.FeedbackV2.self
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(F.iconChipGlyph)
                if let title { Text(title) }
            }
            .font(F.iconChipFont)
            .foregroundStyle(WorkbenchTokens.ink(0.8))
            .padding(.horizontal, title == nil ? 0 : F.iconChipPaddingH)
            .frame(minWidth: WorkbenchTokens.FeedbackV2.iconButton, minHeight: WorkbenchTokens.FeedbackV2.iconButton)
            .background(Capsule(style: .continuous).fill(WorkbenchTokens.ink(hovering ? 0.16 : 0.09)))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(IslandPressStyle())
        .onHover { hovering = $0 }
    }
}

/// Answer again: with the model it used, or another (a menu of the agent's models and efforts).
struct V2ReanswerMenu: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    var compact = false
    /// Oct 15 review: where it's narrow (a pulled-out chat), the glyph only.
    var iconOnly = false

    var body: some View {
        let options = ModelCatalog.options(agent: task.agent == ChatAgent.fovea.id ? "claude-code" : task.agent)
        Menu {
            Button("Answer again with \(task.modelLabel ?? L("Auto"))") { model.reanswerV2(task.id) }
            Divider()
            ForEach(options) { option in
                if let why = model.v2ModelUnavailable(option) {
                    // Oct 15 review, QA08: listed, not to pick, and why.
                    Button("\(option.name) (\(why))") {}.disabled(true)
                } else if option.efforts.isEmpty {
                    Button(option.name) { model.reanswerV2(task.id, model: option.id) }
                } else {
                    Menu(option.name) {
                        ForEach(option.efforts, id: \.self) { effort in
                            Button(ModelCatalog.effortName(effort)) { model.reanswerV2(task.id, model: option.id, effort: effort) }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.clockwise").font(WorkbenchTokens.FeedbackV2.iconChipGlyph)
                if !iconOnly { Text(compact ? "Answer again · \(task.modelLabel ?? L("Auto"))" : "Answer again") }
            }
            .font(WorkbenchTokens.FeedbackV2.iconChipFont)
        } primaryAction: {
            model.reanswerV2(task.id)
        }
        .menuStyle(.button)
        .buttonStyle(IslandPressStyle())
        .foregroundStyle(WorkbenchTokens.ink(0.85))
        .padding(.horizontal, iconOnly ? 0 : WorkbenchTokens.FeedbackV2.iconChipPaddingH)
        .frame(minWidth: WorkbenchTokens.FeedbackV2.iconButton)
        .frame(height: WorkbenchTokens.FeedbackV2.iconButton)
        .background(Capsule(style: .continuous).fill(WorkbenchTokens.ink(0.09)))
        .fixedSize()
        .help("Answer again (click), or pick another model to answer with")
    }
}

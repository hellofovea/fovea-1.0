import SwiftUI
import WindowBenchCore

/// 01 · reading your last 30 days. One panel: the consent (Migration Assistant's skeleton,
/// R01-01) counts in place while it scans, then becomes the project list the projects arrive
/// into. Merge suggestions come one at a time; never a modal. The last step points to the notch.
struct OnboardingView: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let step: OnboardingStep
    @Namespace private var space

    var body: some View {
        Group {
            switch step {
            case .consent, .scanning:
                ConsentPanel(step: step, space: space)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(leaving)
            case .nothingFound:
                NothingFound()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(arriving)
            case .reveal, .merge, .handoff:
                RevealList(step: step, space: space)
                    .transition(arriving)
            }
        }
        .overlay(alignment: .top) {
            if step == .scanning && model.v(ScanProgress.self) == .hairline {
                GeometryReader { geo in
                    Rectangle().fill(palette.text.opacity(0.7))
                        .frame(width: geo.size.width * model.scan.progress, height: 2)
                        .animation(.linear(duration: model.motion.seconds(BenchTokens.MotionValues.scanTick)), value: model.scan.progress)
                }
                .frame(height: 2)
            }
        }
        .animation(model.motion.animation(.open), value: step)
    }

    /// The panel leaves on the notch's content exit; what replaces it comes in on the content
    /// entrance once the panel is gone, so the two are never on screen together.
    private var leaving: AnyTransition {
        .asymmetric(insertion: .opacity,
                    removal: .modifier(active: RevealIn(progress: 0), identity: RevealIn(progress: 1))
                        .animation(model.motion.animation(.content)))
    }

    private var arriving: AnyTransition {
        let motion = model.motion
        return .asymmetric(insertion: .modifier(active: RevealIn(progress: 0), identity: RevealIn(progress: 1))
                            .animation(motion.animation(.content).delay(motion.seconds(BenchTokens.MotionValues.contentDuration * 0.6))),
                           removal: .opacity)
    }
}

/// Where each agent's history lives, as the product reads it (fovea-mac's
/// QuickAnswerExternalSessionDirectory), with the session count it fills in as it reads.
private struct FolderRow: Identifiable {
    let agent: AgentKind
    let paths: [String]
    let share: Double
    var id: String { agent.rawValue }
}

private struct ConsentPanel: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let step: OnboardingStep
    let space: Namespace.ID

    private var folders: [FolderRow] {
        let agents = model.library.agents.isEmpty ? BenchFixtures.agents() : model.library.agents
        let shares: [AgentKind: Double] = [.claudeCode: 0.62, .codex: 0.27, .cursor: 0.11]
        return agents.filter { !$0.historyFolders.isEmpty }.map { agent in
            FolderRow(agent: agent.kind, paths: agent.historyFolders, share: shares[agent.kind] ?? 0.1)
        }
    }

    var body: some View {
        let scanning = step == .scanning
        let scale = BenchTokens.Type_.scale(model.v(TypeScale.self))
        VStack(alignment: .leading, spacing: 0) {
            Text("Read your last 30 days")
                .font(BenchTokens.Type_.heroTitle)
                .foregroundStyle(palette.text)
            Text("Fovea reads the session history your agents already keep, and shows you what you worked on, sorted into projects.")
                .font(BenchTokens.Type_.heroBody)
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            VStack(spacing: 0) {
                ForEach(folders) { folder in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(folder.agent.name)
                            .font(.system(size: scale.body))
                            .foregroundStyle(palette.text)
                            .frame(width: 96, alignment: .leading)
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(folder.paths, id: \.self) { path in
                                let error = scanning || model.scan.sessions > 0 ? model.readError(folder: path, of: folder.agent) : nil
                                HStack(spacing: 6) {
                                    Text(path)
                                        .foregroundStyle(error == nil ? palette.secondary : palette.tertiary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    if let error {
                                        ReadErrorMark(error: error)
                                            .transition(.opacity)
                                    }
                                }
                                .font(BenchTokens.Type_.mono(scale.meta + 0.5))
                            }
                        }
                        Spacer(minLength: 8)
                        if scanning || model.scan.sessions > 0 {
                            Ticker(value: count(folder), font: BenchTokens.Type_.mono(scale.meta + 0.5))
                                .foregroundStyle(palette.secondary)
                                .transition(.opacity)
                        }
                    }
                    .padding(.vertical, 8)
                    if folder.id != folders.last?.id {
                        Rectangle().fill(palette.hairline).frame(height: BenchTokens.Layout.hairline)
                    }
                }
            }
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: BenchTokens.Layout.wellRadius, style: .continuous).fill(palette.well))
            .padding(.top, 18)

            Text("Only sessions active in the last 30 days. Fovea lists these folders and reads their dates on this Mac; nothing is uploaded.")
                .font(.system(size: 12))
                .foregroundStyle(palette.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            // One slot at the panel's foot: the buttons, then (once you click) the counts and the
            // progress line in their place. The panel keeps its height, so nothing above moves.
            ZStack(alignment: .topLeading) {
                HStack(spacing: 10) {
                    Spacer()
                    Button("Skip") { model.skipOnboarding() }
                        .controlSize(.large)
                    Button("Read my history") { model.startScan() }
                        .controlSize(.large)
                        .buttonStyle(ProminentButtonStyle())
                }
                .opacity(scanning ? 0 : 1)
                .allowsHitTesting(!scanning)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        SummaryLine()
                            .modifier(SummaryTravel(space: space))
                        if scanning && model.v(ScanProgress.self) == .ring {
                            ProgressRing(progress: model.scan.progress)
                        }
                    }
                    .frame(height: 22)
                    if model.v(ScanProgress.self) == .notchLine {
                        NotchLine(progress: model.scan.progress)
                            .frame(width: BenchTokens.Layout.consentWidth)
                    }
                }
                .opacity(scanning || model.scan.sessions > 0 ? 1 : 0)
            }
            .frame(height: 34, alignment: .top)
            .padding(.top, 22)
        }
        .frame(width: BenchTokens.Layout.consentWidth)
        .padding(.bottom, 40)
    }

    private func count(_ folder: FolderRow) -> Int { model.scan.perAgent[folder.agent] ?? 0 }
}

/// The counts line doesn't travel from the panel to the list: in flight it crossed rows that had
/// landed, and two copies fought over the move. It fades in at the list's head, where it stays.
private struct SummaryTravel: ViewModifier {
    let space: Namespace.ID
    func body(content: Content) -> some View { content }
}

/// A folder the scan couldn't list: the dashed mark (Fovea can't see it) and why, in mono.
struct ReadErrorMark: View {
    @Environment(\.palette) private var palette
    let error: FolderReadError

    var body: some View {
        HStack(spacing: 4) {
            StateGlyph(state: .unobserved)
            Text(error.line)
        }
        .foregroundStyle(palette.tertiary)
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Can't read: \(error.line)")
    }
}

/// `142 sessions · 3 agents · 9 projects found`, in mono, the digits rolling as they count.
/// While it counts, each number has a slot as wide as its final value (right-aligned, as
/// Migration Assistant's counts are) and each noun keeps room for its "s", so nothing after a
/// number moves as the digits grow or the plural flips.
struct SummaryLine: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let font = BenchTokens.Type_.mono(BenchTokens.Type_.scale(model.v(TypeScale.self)).meta + 1)
        let s = model.scan
        let counting = model.state.onboarding == .scanning
        let target = model.scanTargets
        HStack(spacing: 0) {
            CountSlot(value: s.sessions, final: counting ? target.sessions : nil, font: font)
            Self.noun(" session", count: s.sessions, holding: counting) + Text(" · ")
            CountSlot(value: s.agents, final: counting ? target.agents : nil, font: font)
            Self.noun(" agent", count: s.agents, holding: counting) + Text(" · ")
            CountSlot(value: s.projects, final: counting ? target.projects : nil, font: font)
            Self.noun(" project", count: s.projects, holding: counting) + Text(" found")
        }
        .font(font)
        .foregroundStyle(palette.text)
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    /// The noun, its "s" drawn clear (but kept) while a count of one is still counting.
    static func noun(_ word: String, count: Int, holding: Bool) -> Text {
        if count != 1 { return Text(word + "s") }
        return holding ? Text(word) + Text("s").foregroundColor(.clear) : Text(word)
    }
}

/// A count that rolls in a slot sized for the number it will end on.
private struct CountSlot: View {
    let value: Int
    let final: Int?
    let font: Font

    var body: some View {
        ZStack(alignment: .trailing) {
            if let final {
                Text(String(repeating: "0", count: max(String(final).count, String(value).count)))
                    .font(font).monospacedDigit().hidden()
            }
            Ticker(value: value, font: font)
        }
    }
}

/// The notch's Transcribing line: a 4 pt capsule that fills.
struct NotchLine: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.fill)
                Capsule().fill(palette.text.opacity(0.85))
                    .frame(width: max(BenchTokens.Layout.notchLine, geo.size.width * progress))
            }
        }
        .frame(height: BenchTokens.Layout.notchLine)
        .animation(.linear(duration: model.motion.seconds(BenchTokens.MotionValues.scanTick)), value: progress)
        .accessibilityElement()
        .accessibilityLabel("Reading history")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

struct ProgressRing: View {
    @Environment(\.palette) private var palette
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(palette.fill, lineWidth: 2)
            Circle().trim(from: 0, to: progress)
                .stroke(palette.text.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 14, height: 14)
    }
}

/// The list the projects arrive into, the counts line above it where the panel's was.
private struct RevealList: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let step: OnboardingStep
    let space: Namespace.ID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SummaryLine()
                    .modifier(SummaryTravel(space: space))
                    .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
                    .padding(.bottom, model.readErrors.isEmpty ? 10 : 4)
                ForEach(model.readErrors, id: \.folder) { item in
                    HStack(spacing: 6) {
                        Text(item.folder).foregroundStyle(palette.tertiary)
                        ReadErrorMark(error: item.error)
                    }
                    .font(BenchTokens.Type_.mono(BenchTokens.Type_.scale(model.v(TypeScale.self)).meta))
                    .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
                    .padding(.bottom, 10)
                }
                if step == .handoff {
                    HandoffLine()
                        .padding(.bottom, 12)
                        .modifier(GrowIn())
                        .transition(.opacity)
                }
                if let merge = model.bannerMerge {
                    MergeBanner(suggestion: merge)
                        .padding(.bottom, 12)
                        .modifier(GrowIn())
                        .transition(.opacity)
                        .id(merge.id)
                }
                if let undo = model.lastMerge, model.v(MergeStyle.self) == .banner {
                    MergedLine(record: undo).padding(.bottom, 8)
                }
                ProjectListContent(revealCount: model.revealed)
            }
            // The column is at its full width from the first frame, so the counts line lands
            // where it stays (a column as wide as its content moved it once rows arrived).
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxWidth: BenchTokens.Layout.column)
            .padding(.horizontal, BenchTokens.Layout.sideMargin)
            .padding(.top, BenchTokens.Layout.topMargin)
            .padding(.bottom, BenchTokens.Layout.bottomMargin)
            .frame(maxWidth: .infinity)
        }
    }
}

/// The brief's banner: one suggestion at a time, the names, the evidence in mono, two buttons.
private struct MergeBanner: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let suggestion: MergeSuggestion

    var body: some View {
        let scale = BenchTokens.Type_.scale(model.v(TypeScale.self))
        let a = model.index.projectByID[suggestion.first]?.name ?? ""
        let b = model.index.projectByID[suggestion.second]?.name ?? ""
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("These two look like the same thing. Merge?")
                    .font(.system(size: scale.body, weight: .medium))
                    .foregroundStyle(palette.text)
                Text("\(a)  ·  \(b)")
                    .font(.system(size: scale.body))
                    .foregroundStyle(palette.text)
                MergeEvidenceGrid(evidence: suggestion.evidence, size: scale.meta)
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                Button("Keep separate") { model.keepSeparate(suggestion) }
                Button("Merge") { model.merge(suggestion) }
                    .buttonStyle(ProminentButtonStyle())
            }
        }
        // Text on the column's label edge: the card's inset is the rows' inset.
        .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: BenchTokens.Layout.cardRadius, style: .continuous).fill(palette.well))
        .overlay(RoundedRectangle(cornerRadius: BenchTokens.Layout.cardRadius, style: .continuous).strokeBorder(palette.hairline))
    }
}

/// Photos' way (R01-02): the suggestion as a heading line on the two rows themselves.
struct InlineMergeBlock: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let suggestion: MergeSuggestion

    var body: some View {
        let scale = BenchTokens.Type_.scale(model.v(TypeScale.self))
        let summaries = ProjectIndex.summaries(model.index, failed: .withStuck)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("These two look like the same thing")
                    .font(.system(size: scale.section, weight: .semibold))
                    .foregroundStyle(palette.tertiary)
                Spacer()
                Button("Keep separate") { model.keepSeparate(suggestion) }
                    .controlSize(.small)
                Button("Merge") { model.merge(suggestion) }
                    .buttonStyle(ProminentButtonStyle())
                    .controlSize(.small)
            }
            .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
            .frame(height: BenchTokens.Layout.headerHeight)
            ForEach([suggestion.first, suggestion.second], id: \.self) { id in
                if let summary = summaries.first(where: { $0.id == id }) {
                    ProjectRow(summary: summary)
                }
            }
            MergeEvidenceGrid(evidence: suggestion.evidence, size: scale.meta)
                .padding(.leading, BenchTokens.Layout.rowPaddingH + BenchTokens.Layout.glyphSlot + BenchTokens.Layout.glyphGap)
            Rectangle().fill(palette.hairline).frame(height: BenchTokens.Layout.hairline)
                .padding(.top, BenchTokens.Layout.groupGap - BenchTokens.Layout.hairline)
        }
        .padding(.bottom, 2)
    }
}

/// The evidence as two mono columns: what matched, then the value, every value on one edge.
struct MergeEvidenceGrid: View {
    @Environment(\.palette) private var palette
    let evidence: [MergeEvidence]
    let size: CGFloat

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
            ForEach(evidence, id: \.self) { line in
                GridRow {
                    Text(line.label).foregroundStyle(palette.tertiary)
                    Text(line.value).foregroundStyle(palette.secondary)
                }
            }
        }
        .font(BenchTokens.Type_.mono(size))
    }
}

/// After a merge: what happened, with Undo, instead of a confirmation dialog.
private struct MergedLine: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let record: MergeRecord

    var body: some View {
        HStack(spacing: 8) {
            Text("Merged \(record.removed.name) into \(record.keptName)")
                .font(.system(size: 12))
                .foregroundStyle(palette.secondary)
            Button("Undo") { model.undoMerge() }
                .controlSize(.small)
        }
        .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
    }
}

/// The last step: one line pointing up to the notch, Done to finish.
private struct HandoffLine: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var lift: CGFloat = 0

    var body: some View {
        let cue = model.v(HandoffCue.self)
        HStack(spacing: 12) {
            // An arrow in every style: ● means waiting, and this line isn't a state.
            Image(systemName: "arrow.up")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.text)
                .offset(y: cue == .arrow ? lift : 0)
                .probe("handoff-glyph")
                .opacity(cue == .fly && model.handoffFlown ? 0 : 1)
            VStack(alignment: .leading, spacing: 4) {
                Text("Next time, start from the notch.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.text)
                TeachingLine()
                    .font(.system(size: 12.5))
            }
            Spacer()
            Button("Done") { model.finishOnboarding() }
                .buttonStyle(ProminentButtonStyle())
        }
        // Text on the column's label edge: the card's inset is the rows' inset.
        .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: BenchTokens.Layout.cardRadius, style: .continuous).fill(palette.well))
        .onAppear {
            if cue == .arrow && !model.motion.reduce {
                withAnimation(model.motion.animation(.open).delay(model.motion.seconds(0.3))) { lift = -3 }
                Task { @MainActor in
                    await model.motion.sleep(0.6)
                    withAnimation(model.motion.animation(.close)) { lift = 0 }
                }
            }
            model.handoffCueAppeared()
        }
    }
}

/// Skipped, or nothing to read: the product's one gesture, and the way back to reading.
private struct NothingFound: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 18) {
            TeachingLine()
            Button("Read my history") { model.goTo(onboarding: .consent) }
                .controlSize(.regular)
        }
        .padding(.bottom, 60)
    }
}

/// The one filled button a page may have: ink on paper, white on black in Dark Paper, the
/// accent on System (a native default button).
struct ProminentButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var enabled
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        // The system push button's sizes, so an ink button sits level with a bordered one.
        let m = BenchTokens.Layout.prominentButton(controlSize)
        configuration.label
            .font(.system(size: m.font, weight: .medium))
            .foregroundStyle(palette.prominentText)
            .padding(.horizontal, m.padding)
            .frame(minHeight: m.height)
            .background(RoundedRectangle(cornerRadius: m.radius, style: .continuous)
                .fill(palette.prominentFill.opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.35)))
            .contentShape(Rectangle())
    }
}

/// The notch's content entrance as an insertion: opacity, a 4 pt blur, 0.97 from the top.
struct RevealIn: ViewModifier {
    let progress: CGFloat
    func body(content: Content) -> some View { content.contentReveal(progress) }
}

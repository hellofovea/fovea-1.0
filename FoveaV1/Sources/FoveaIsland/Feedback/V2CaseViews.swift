import SwiftUI
import AppKit
import FoveaCore
import FoveaLook
import FoveaKit

// The Oct 15 review's Dispatch views (V2Cases.swift has the flow): drawn in the island's own
// pieces (its chips, capsule buttons, white at an opacity, amber for the person's turn, red for
// what failed), each tagged with the workbook's ID while Review notes are on.

// MARK: - Small shared pieces


/// A status in a line: a glyph (or a spinner), its words, and room for a way on.
struct V2CaseStatus<Trailing: View>: View {
    var symbol: String? = nil
    var spinner = false
    let text: String
    var color: Color = WorkbenchTokens.V2.subColor
    var glyphColor: Color? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        let C = WorkbenchTokens.Cases.self
        HStack(spacing: C.statusGap) {
            if spinner {
                ProgressView().controlSize(.mini)
            } else if let symbol {
                Image(systemName: symbol).font(C.statusGlyph).foregroundStyle(glyphColor ?? color)
            }
            Text(text).font(C.statusFont).foregroundStyle(color).lineLimit(1).truncationMode(.tail)
            trailing()
        }
    }
}

extension V2CaseStatus where Trailing == EmptyView {
    init(symbol: String? = nil, spinner: Bool = false, text: String, color: Color = WorkbenchTokens.V2.subColor, glyphColor: Color? = nil) {
        self.init(symbol: symbol, spinner: spinner, text: text, color: color, glyphColor: glyphColor) { EmptyView() }
    }
}

/// A text field on the island: its fill, a hairline, the accent when focused.
struct V2CaseField: View {
    let prompt: String
    let text: Binding<String>
    var font: Font = WorkbenchTokens.Cases.detailFont
    var lines: Int = 1
    var autofocus = false
    var submit: () -> Void = {}
    @FocusState private var focused: Bool

    var body: some View {
        let C = WorkbenchTokens.Cases.self
        TextField(prompt, text: text, axis: lines > 1 ? .vertical : .horizontal)
            .textFieldStyle(.plain)
            .font(font)
            .foregroundStyle(WorkbenchTokens.V2.titleColor)
            .lineLimit(1...max(1, lines))
            .focused($focused)
            .onSubmit(submit)
            .padding(.horizontal, C.searchPaddingH)
            .padding(.vertical, 3)
            .frame(maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(C.fieldFill))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(focused && WorkbenchTokens.isNative ? WorkbenchTokens.Native.accent : C.fieldBorder, lineWidth: 0.75))
            .onAppear { if autofocus { focused = true } }
    }
}

// MARK: - Every chat: the search, Load More, a list that couldn't load (QA04), why not (QA05)

/// The browser's search: chats by title or project.
struct V2BrowseSearchField: View {
    let model: WorkbenchModel

    var body: some View {
        let C = WorkbenchTokens.Cases.self
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass").font(C.searchGlyph).foregroundStyle(WorkbenchTokens.V2.subColor)
            TextField("Search chats", text: Binding(get: { model.cases.browseQuery }, set: { model.setBrowseQuery($0) }))
                .textFieldStyle(.plain)
                .font(C.searchFont)
                .foregroundStyle(WorkbenchTokens.V2.titleColor)
            if !model.cases.browseQuery.isEmpty {
                Button { model.setBrowseQuery("") } label: {
                    Image(systemName: "xmark.circle.fill").font(C.searchGlyph).foregroundStyle(WorkbenchTokens.V2.subColor)
                }
                .buttonStyle(.plain)
                .help("Clear the search")
            }
        }
        .padding(.horizontal, C.searchPaddingH)
        .frame(width: C.searchWidth, height: C.searchHeight)
        .background(Capsule(style: .continuous).fill(C.searchFill))
        .help("Chats by title or project")
        .accessibilityLabel("Search chats")
    }
}

/// A row that isn't a chat: the list loading, a list that couldn't load (Try Again), a search
/// with nothing in it.
struct V2BrowseStatusRow: View {
    let model: WorkbenchModel
    let status: V2BrowseStatus

    var body: some View {
        let agent = ChatAgent.named(model.v2BrowseAgent).name
        Group {
            switch status {
            case .loading:
                V2CaseStatus(spinner: true, text: L("Loading \(agent)'s chats…"))
            case .failed:
                V2CaseStatus(symbol: "exclamationmark.triangle.fill", text: L("Couldn't load \(agent)'s chats."),
                             glyphColor: WorkbenchTokens.Panel.failedColor) {
                    AgentPanelButton(title: L("Try Again"), symbol: "arrow.clockwise", primary: false) { model.retryBrowseLoad() }
                }
            case .noMatch(let query):
                V2CaseStatus(symbol: "magnifyingglass", text: L("No chats match \u{201C}\(query)\u{201D}"))
            }
        }
        .padding(.horizontal, WorkbenchTokens.V2.browsePaddingH)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var note: String {
        if case .noMatch = status { return L("A search with nothing in it says so") }
        return L("The list on its way, or Try Again when it couldn't load")
    }
}

/// The rest of a long list, a click away.
struct V2BrowseMoreLabel: View {
    let count: Int

    var body: some View {
        let V = WorkbenchTokens.V2.self
        HStack(spacing: 10) {
            Image(systemName: "ellipsis").font(V.browseGlyph).foregroundStyle(V.subColor).frame(width: 14)
            Text("Load More").font(V.browseFont).foregroundStyle(V.titleColor)
            Text("\(count) more").font(V.reasonFont).foregroundStyle(V.subColor).monospacedDigit()
            Spacer()
        }
    }
}

/// Why a chat can't take the request, at its row's right.
struct V2BlockedReason: View {
    let reason: String
    let chat: AgentChat

    var body: some View {
        let C = WorkbenchTokens.Cases.self
        HStack(spacing: 4) {
            Image(systemName: reason == ChatBlock.agentUnavailable ? "bolt.horizontal.circle" : "nosign")
                .font(C.blockedGlyph)
            // Oct 18, Ryan: the reasons are kept in English (they're compared); shown in the primary language.
            Text(L(key: reason)).font(WorkbenchTokens.V2.reasonFont)
        }
        .foregroundStyle(WorkbenchTokens.V2.subColor)
        .help(ChatBlock.help(reason, chat: chat))
    }
}

// MARK: - Sending (QA06, QA10)

/// In place of the suggestions after Send: on its way, the chat locked; not sent (Try Again,
/// Choose Another Chat); declined by the agent, with its reason.
struct V2SendStatusRow: View {
    let model: WorkbenchModel
    let sending: V2Sending

    var body: some View {
        let P = WorkbenchTokens.Panel.self
        HStack(spacing: P.buttonGap) {
            switch sending {
            case .sending(let pick):
                V2CaseStatus(spinner: true, text: L("Sending to \(pick.title)…"), color: WorkbenchTokens.V2.titleColor)
                Spacer(minLength: 0)
            case .notSent(let pick):
                V2CaseStatus(symbol: "exclamationmark.circle.fill",
                             text: L("Not sent: \(ChatAgent.named(pick.agent).name) didn't take it."),
                             color: WorkbenchTokens.V2.titleColor, glyphColor: P.failedColor)
                    .layoutPriority(1)
                Spacer(minLength: 6)
                AgentPanelButton(title: L("Choose Another Chat"), primary: false) { model.chooseAnotherChatV2() }
                AgentPanelButton(title: L("Try Again"), symbol: "arrow.clockwise", primary: true) { model.retrySendV2() }
            case .declined(let pick, let why):
                V2CaseStatus(symbol: "hand.raised.fill",
                             text: L("Declined by \(ChatAgent.named(pick.agent).name): \(why)"),
                             color: WorkbenchTokens.V2.titleColor, glyphColor: P.needsYouColor)
                    .layoutPriority(1)
                    .help(why)
                Spacer(minLength: 6)
                AgentPanelButton(title: L("Choose Another Chat"), primary: false) { model.chooseAnotherChatV2() }
            }
        }
        .transition(.opacity)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Edit (QA07)

/// The request in a session, editable once it has an answer: Edit on the pointer, then the words
/// in place (Return, or Send, sends them again; Esc or Cancel leaves them).
struct V2EditableQuestion<Shown: View>: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    var lines = 2
    @ViewBuilder var shown: () -> Shown
    @State private var hovering = false

    var body: some View {
        if model.cases.editing == task.id {
            V2CaseField(prompt: L("Your request"), text: Binding(get: { model.cases.editText }, set: { model.cases.editText = $0 }),
                        font: .system(size: WorkbenchTokens.V2.questionSize, weight: .semibold), lines: lines, autofocus: true) {
                model.sendEditV2(task.id)
            }
        } else {
            shown()
                .overlay(alignment: .topTrailing) {
                    if model.canEditV2(task), hovering || model.snapshotMode {
                        V2IconChip(symbol: "pencil", title: L("Edit")) { model.startEditV2(task.id) }
                            .help("Edit your request and send it again")
                            .transition(.opacity)
                    }
                }
                .onHover { inside in withAnimation(WorkbenchTokens.Cases.change) { hovering = inside } }
                .accessibilityAction(named: "Edit") { model.startEditV2(task.id) }
        }
    }
}

// MARK: - The model sheet (QA08, QA09)

extension WorkbenchModel {
    /// The sheet's notes under its rows: models that can't be picked and why; approvals set
    /// elsewhere. Empty: no line.
    var v2ModelNotes: [String] {
        var notes: [String] = []
        if cases.modelsLoad == .loaded {
            if let carried = v2CarriedModel { notes.append(L("\(carried.name): \(carried.reason)")) }
            for option in v2ModelOptions { if let why = v2ModelUnavailable(option) { notes.append(L("\(option.name): \(why)")) } }
        }
        if let locked = cases.approvalLocked { notes.append(locked) }
        return notes
    }
}

/// The Model row while the models load, or when they couldn't.
struct V2ModelsStatus: View {
    let model: WorkbenchModel

    var body: some View {
        let agent = ChatAgent.named(model.v2Pick.quick ? "claude-code" : model.v2Pick.agent).name
        if model.cases.modelsLoad == .loading {
            V2CaseStatus(spinner: true, text: L("Loading \(agent)'s models…"))
        } else {
            V2CaseStatus(symbol: "exclamationmark.triangle.fill", text: L("Couldn't load \(agent)'s models."),
                         glyphColor: WorkbenchTokens.Panel.failedColor) {
                AgentPanelButton(title: L("Try Again"), symbol: "arrow.clockwise", primary: false) { model.retryModelsLoad() }
            }
        }
    }
}

/// The notes under the sheet, a line each: why a model can't be picked, who set the approvals.
struct V2ModelNotesLine: View {
    let notes: [String]

    var body: some View {
        let C = WorkbenchTokens.Cases.self
        VStack(alignment: .leading, spacing: 0) {
            ForEach(notes, id: \.self) { note in
                HStack(spacing: 5) {
                    Image(systemName: "info.circle").font(C.blockedGlyph)
                    Text(note).font(C.detailFont).lineLimit(1).truncationMode(.tail)
                }
                .frame(height: C.detailRow)
            }
        }
        .foregroundStyle(WorkbenchTokens.V2.subColor)
        .help(notes.joined(separator: "\n"))
    }
}

// MARK: - Needs you (QA14, QA15)

/// What a session waiting on the person asks, and what answering it does: an approval's command,
/// the files it would change and for how long it's allowed; a question's choices and a field for
/// the person's own answer; a few questions at once as a small form.
struct V2NeedsYouBody: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let width: CGFloat

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let C = WorkbenchTokens.Cases.self
        VStack(alignment: .leading, spacing: C.needsGap) {
            Text(task.activity)
                .font(.system(size: V.outcomeSize, weight: .semibold))
                .foregroundStyle(WorkbenchTokens.Panel.needsYouColor)
                .lineLimit(2)
                .frame(width: width, height: Self.titleHeight(task, width: width), alignment: .topLeading)
            if let fields = model.cases.forms[task.id] {
                VStack(alignment: .leading, spacing: C.needsGap) {
                    ForEach(fields) { field in V2FormRow(model: model, task: task, field: field) }
                }
            } else {
                switch task.ask {
                case .approval?:
                    V2ApprovalDetail(model: model, task: task, width: width)
                case .choice(let options)?:
                    V2QuestionChoices(model: model, task: task, options: options)
                case nil:
                    Text("It is waiting on you.").font(V.responseFont).foregroundStyle(V.subColor)
                        .frame(height: C.detailRow)
                }
            }
        }
        .frame(width: width, alignment: .topLeading)
    }

    static func titleHeight(_ task: AgentTaskItem, width: CGFloat) -> CGFloat {
        V2Geometry.measure(task.activity, size: WorkbenchTokens.V2.outcomeSize, weight: .semibold, width: width, spacing: 0, lines: 2)
    }

    /// Its height at a width, for the island's outline.
    @MainActor
    static func height(model: WorkbenchModel, task: AgentTaskItem, width: CGFloat) -> CGFloat {
        let C = WorkbenchTokens.Cases.self
        var rows: [CGFloat] = [titleHeight(task, width: width)]
        if let fields = model.cases.forms[task.id] {
            rows += fields.map { _ in C.formRow }
        } else {
            switch task.ask {
            case .approval?:
                let detail = model.v2ApprovalDetail(task)
                if detail.command != nil { rows.append(C.detailRow) }
                if detail.files.isEmpty { rows.append(C.detailRow) } else { rows.append(C.detailRow + CGFloat(detail.files.count) * C.fileRow) }
                rows.append(C.choiceRow)
            case .choice?:
                rows += [C.choiceRow, C.answerField]
            case nil:
                rows.append(C.detailRow)
            }
        }
        return rows.reduce(0, +) + CGFloat(rows.count - 1) * C.needsGap
    }
}

/// An approval, in full: the command it runs; the files it would change (or that it changes
/// none); how long the Allow holds. Allow and Deny are in the bar.
struct V2ApprovalDetail: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let width: CGFloat

    var body: some View {
        let C = WorkbenchTokens.Cases.self
        let V = WorkbenchTokens.V2.self
        let detail = model.v2ApprovalDetail(task)
        VStack(alignment: .leading, spacing: C.needsGap) {
            if let command = detail.command {
                HStack(spacing: 8) {
                    label(L("Runs"))
                    Text(command).font(C.codeFont).foregroundStyle(V.titleColor).lineLimit(1).truncationMode(.middle)
                }
                .frame(height: C.detailRow)
            }
            if detail.files.isEmpty {
                HStack(spacing: 8) {
                    label(L("Changes"))
                    Text("No files").font(C.detailFont).foregroundStyle(V.subColor)
                }
                .frame(height: C.detailRow)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    label(L("Would change")).frame(height: C.detailRow)
                    ForEach(detail.files) { file in
                        HStack(spacing: 6) {
                            Image(systemName: file.path.hasSuffix(".swift") ? "swift" : "doc.text").font(C.blockedGlyph)
                                .foregroundStyle(V.subColor)
                            Text(file.name).font(C.detailFont).foregroundStyle(V.titleColor)
                            Text(file.path).font(C.detailFont).foregroundStyle(V.subColor).lineLimit(1).truncationMode(.head)
                            Spacer(minLength: 6)
                            if file.added > 0 { Text("+\(file.added)").font(C.detailFont.monospacedDigit()).foregroundStyle(WorkbenchTokens.Steps.added) }
                            if file.removed > 0 { Text("\u{2212}\(file.removed)").font(C.detailFont.monospacedDigit()).foregroundStyle(WorkbenchTokens.Steps.removed) }
                        }
                        .padding(.leading, C.labelWidth + 8)
                        .frame(height: C.fileRow)
                    }
                }
            }
            HStack(spacing: WorkbenchTokens.FeedbackV2.sheetChipGap) {
                label(L("Allow"))
                ForEach(V2ApprovalScope.allCases) { scope in
                    V2SheetChip(title: scope.title, chosen: model.v2Scope(task.id) == scope) { model.setV2Scope(task.id, scope) }
                }
            }
            .frame(height: C.choiceRow)
        }
        .frame(width: width, alignment: .leading)
    }

    private func label(_ text: String) -> some View {
        Text(text).font(WorkbenchTokens.V2.labelFont).foregroundStyle(WorkbenchTokens.V2.labelColor)
            .frame(width: WorkbenchTokens.Cases.labelWidth, alignment: .leading)
    }
}

/// A question: its choices, and a field for the person's own answer.
struct V2QuestionChoices: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let options: [String]

    var body: some View {
        let C = WorkbenchTokens.Cases.self
        HStack(spacing: WorkbenchTokens.FeedbackV2.sheetChipGap) {
            ForEach(options, id: \.self) { option in
                V2SheetChip(title: option, chosen: false) { model.answerTask(task.id, option) }
            }
        }
        .frame(height: C.choiceRow)
        HStack(spacing: 6) {
            V2CaseField(prompt: L("Or type your answer"),
                        text: Binding(get: { model.cases.ownAnswer[task.id] ?? "" }, set: { model.cases.ownAnswer[task.id] = $0 })) {
                model.answerOwnV2(task.id)
            }
            AgentPanelButton(title: L("Answer"), primary: true) { model.answerOwnV2(task.id) }
                .disabled((model.cases.ownAnswer[task.id] ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .frame(height: C.answerField)
    }
}

/// One question of a few: its choices, or a field.
struct V2FormRow: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let field: V2FormField

    var body: some View {
        let C = WorkbenchTokens.Cases.self
        let answer = model.cases.formAnswers[task.id]?[field.id] ?? ""
        HStack(spacing: WorkbenchTokens.FeedbackV2.sheetChipGap) {
            Text(field.label).font(C.detailFont).foregroundStyle(WorkbenchTokens.V2.bodyColor)
                .lineLimit(1).frame(width: C.formLabelWidth, alignment: .leading)
            if field.choices.isEmpty {
                V2CaseField(prompt: L("Your answer"), text: Binding(get: { answer }, set: { model.cases.formAnswers[task.id, default: [:]][field.id] = $0 }))
            } else {
                ForEach(field.choices, id: \.self) { choice in
                    V2SheetChip(title: choice, chosen: answer == choice) { model.cases.formAnswers[task.id, default: [:]][field.id] = choice }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: C.formRow)
    }
}

// MARK: - A session's body in the review's cases

/// What a session shows in place of its usual body: being reopened; a chat that's gone; a
/// request that may not have arrived; what was just decided.
enum V2CaseBodyKind: Equatable {
    case reopening, gone, unconfirmed, decision(String)
}

extension WorkbenchModel {
    func v2CaseBody(_ task: AgentTaskItem) -> V2CaseBodyKind? {
        if cases.reopening.contains(task.id) { return .reopening }
        if cases.gone.contains(task.id) { return .gone }
        if task.state == .working, cases.unconfirmed[task.id] != nil { return .unconfirmed }
        if task.state == .working, let line = cases.decisions[task.id] { return .decision(line) }
        return nil
    }
}

struct V2CaseBodyView: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let kind: V2CaseBodyKind
    let width: CGFloat

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let C = WorkbenchTokens.Cases.self
        let B = WorkbenchTokens.Board.self
        let agent = ChatAgent.named(task.agent).name
        Group {
            switch kind {
            case .reopening:
                V2CaseStatus(spinner: true, text: L("Reopening…"))
                    .frame(height: B.workingLine)
            case .gone:
                VStack(alignment: .leading, spacing: C.needsGap) {
                    Text("This chat isn't available anymore.")
                        .font(.system(size: V.outcomeSize, weight: .semibold)).foregroundStyle(V.titleColor)
                    Text(Self.goneLine(agent)).font(V.responseFont).foregroundStyle(V.subColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            case .unconfirmed:
                V2Unconfirmed(model: model, task: task)
            case .decision(let line):
                // Oct 18, Ryan: the decision's line is in the primary language; Denied leads it.
                V2CaseStatus(symbol: line.hasPrefix(L("Denied")) ? "xmark.circle.fill" : "checkmark.circle.fill", text: line,
                             color: V.bodyColor, glyphColor: line.hasPrefix(L("Denied")) ? V.subColor : WorkbenchTokens.Panel.completeColor)
                    .frame(height: B.workingLine)
            }
        }
        .frame(width: width, alignment: .topLeading)
    }

    static func goneLine(_ agent: String) -> String {
        L("\(agent) no longer has it. Your request is kept: ask it in a new chat.")
    }

    @MainActor
    static func height(model: WorkbenchModel, task: AgentTaskItem, kind: V2CaseBodyKind, width: CGFloat) -> CGFloat {
        let V = WorkbenchTokens.V2.self
        let C = WorkbenchTokens.Cases.self
        let B = WorkbenchTokens.Board.self
        switch kind {
        case .reopening, .decision: return B.workingLine
        case .gone:
            return V2Geometry.measure(L("This chat isn't available anymore."), size: V.outcomeSize, weight: .semibold, width: width, spacing: 0)
                + C.needsGap + V2Geometry.measure(goneLine(ChatAgent.named(task.agent).name), size: V.outcomeSize - 1.5, width: width, spacing: 0)
        case .unconfirmed:
            let attempts = model.cases.unconfirmed[task.id]?.count ?? 0
            return C.detailRow + C.needsGap + C.choiceRow + (attempts > 0 ? C.needsGap + CGFloat(attempts) * C.attemptRow : 0)
        }
    }
}

/// Not sure the request reached the agent (QA24): check there, or send it again; the earlier
/// tries listed quietly under it.
struct V2Unconfirmed: View {
    let model: WorkbenchModel
    let task: AgentTaskItem

    var body: some View {
        let C = WorkbenchTokens.Cases.self
        let agent = ChatAgent.named(task.agent).name
        let attempts = model.cases.unconfirmed[task.id] ?? []
        VStack(alignment: .leading, spacing: C.needsGap) {
            V2CaseStatus(symbol: "questionmark.circle.fill", text: L("Not sure this reached \(agent)"),
                         color: WorkbenchTokens.V2.titleColor, glyphColor: WorkbenchTokens.Panel.needsYouColor)
                .frame(height: C.detailRow)
            HStack(spacing: WorkbenchTokens.Panel.buttonGap) {
                AgentPanelButton(title: L("Check in \(agent)"), symbol: "arrow.up.forward", primary: false) { model.checkInAgentV2(task.id) }
                AgentPanelButton(title: L("Send Again"), symbol: "arrow.clockwise", primary: true) { model.sendAgainV2(task.id) }
            }
            .frame(height: C.choiceRow)
            if !attempts.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(attempts.enumerated()), id: \.offset) { i, date in
                        // Oct 18, Ryan: in the primary language, the time as it writes it, the last line whole
                        // (" yet" stayed English).
                        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: FoveaLocale.shared.locale))
                        Text(i == attempts.count - 1 ? L("Sent at \(time) · no reply yet") : L("Sent at \(time) · no reply"))
                            .font(C.attemptFont).foregroundStyle(C.attemptColor)
                            .frame(height: C.attemptRow)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Earlier tries")
            }
        }
    }
}

// MARK: - The header: the connection, read only (QA16, QA25)

/// In a session's header, when the connection isn't fine (reconnecting; lost or timed out, with
/// Try Again), or when the session is from an earlier version and read only.
struct V2HeaderPill: View {
    let model: WorkbenchModel
    let task: AgentTaskItem

    static func shown(_ model: WorkbenchModel, _ task: AgentTaskItem) -> Bool {
        model.cases.connection[task.id] != nil || model.cases.readOnly.contains(task.id)
    }

    var body: some View {
        let C = WorkbenchTokens.Cases.self
        let agent = ChatAgent.named(task.agent).name
        HStack(spacing: 5) {
            if model.cases.readOnly.contains(task.id) {
                Image(systemName: "lock.fill").font(C.blockedGlyph)
                Text("From an earlier version · read only").font(C.pillFont)
            } else {
                switch model.cases.connection[task.id] {
                case .reconnecting?:
                    ProgressView().controlSize(.mini)
                    Text("Reconnecting to \(agent)…").font(C.pillFont)
                case .lost?:
                    Image(systemName: "bolt.horizontal.circle").font(C.blockedGlyph).foregroundStyle(WorkbenchTokens.Panel.failedColor)
                    Text("Lost connection").font(C.pillFont)
                    retry
                case .timedOut?:
                    Image(systemName: "clock.badge.exclamationmark").font(C.blockedGlyph).foregroundStyle(WorkbenchTokens.Panel.needsYouColor)
                    Text("Timed out").font(C.pillFont)
                    retry
                case nil:
                    EmptyView()
                }
            }
        }
        .foregroundStyle(WorkbenchTokens.V2.bodyColor)
        .padding(.leading, C.pillPaddingH)
        .padding(.trailing, model.cases.connection[task.id] == .lost || model.cases.connection[task.id] == .timedOut ? 3 : C.pillPaddingH)
        .frame(height: C.pillHeight)
        .background(Capsule(style: .continuous).fill(C.pillFill))
        .fixedSize()
        .transition(.opacity)
    }

    private var retry: some View {
        Button { model.retryConnectionV2(task.id) } label: {
            Text("Try Again").font(WorkbenchTokens.Cases.pillFont).foregroundStyle(WorkbenchTokens.V2.titleColor)
                .padding(.horizontal, 7)
                .frame(height: WorkbenchTokens.Cases.pillHeight - 4)
                .background(Capsule(style: .continuous).fill(WorkbenchTokens.ink(0.12)))
        }
        .buttonStyle(.plain)
    }
}

/// A session that can't be asked more (read only, or gone): a quiet line where the box was.
struct V2ReadOnlyLine: View {
    let model: WorkbenchModel
    let task: AgentTaskItem

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let gone = model.cases.gone.contains(task.id)
        HStack(spacing: 6) {
            Image(systemName: "lock").font(WorkbenchTokens.Cases.blockedGlyph)
            Text(gone ? "This chat can't be asked more." : "Read only. You can read it here, not ask more.")
                .font(V.inputFont)
        }
        .foregroundStyle(V.subColor)
        .padding(.leading, V.inputPaddingLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: V.inputHeight)
        .background(Capsule(style: .continuous).fill(V.inputFill.opacity(0.5)))
    }
}

// MARK: - The bar: Open in the agent, Copy Answer, a line a moment (QA26, DSP-18, QA20)

/// Open in <agent>: the session in its own agent (Claude Code, Codex), one way wherever a session
/// shows (the notch, a pulled-out chat, a held queue). Oct 17, Ryan: "don't have Continue, have
/// Open in agent". Narrow, the glyph only.
struct V2OpenInAgentChip: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    var iconOnly = false
    /// The review's tag where it shows (a held queue's is QA12).
    var note: (id: String, text: String) = ("QA26", "Open in the session's agent, replacing Continue in…")

    var body: some View {
        let name = ChatAgent.named(task.agent).name
        V2IconChip(symbol: "arrow.up.forward", title: iconOnly ? nil : L("Open in \(name)")) { model.openInAgentV2(task.id) }
            .help("Open this session in \(name)")
            .accessibilityLabel("Open in \(name)")
    }
}

/// Copy Answer, and Copied a moment after.
struct V2CopyAnswerChip: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    var iconOnly = false

    var body: some View {
        let copied = model.cases.copied == task.id
        V2IconChip(symbol: copied ? "checkmark" : "doc.on.doc", title: iconOnly ? nil : (copied ? L("Copied") : L("Copy Answer"))) {
            model.copyV2(task.id)
        }
        .help(copied ? "Copied" : "Copy the answer")
        .accessibilityLabel(copied ? "Copied" : "Copy Answer")
    }
}

/// Editing the request: Cancel or Send, where the bar's buttons were.
struct V2EditBar: View {
    let model: WorkbenchModel
    let task: AgentTaskItem

    var body: some View {
        let P = WorkbenchTokens.Panel.self
        let empty = model.cases.editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        HStack(spacing: P.buttonGap) {
            Text("Sent again, it replaces this answer").font(WorkbenchTokens.Cases.detailFont)
                .foregroundStyle(WorkbenchTokens.V2.subColor).lineLimit(1)
            Spacer(minLength: 6)
            AgentPanelButton(title: L("Cancel"), primary: false) { model.cancelEditV2() }
            AgentPanelButton(title: L("Send"), symbol: "arrow.up", primary: true) { model.sendEditV2(task.id) }
                .disabled(empty)
                .opacity(empty ? 0.5 : 1)
        }
    }
}

/// A line in the bar a moment: opened there; a copy saved, or not.
struct V2BarLineView: View {
    let line: V2BarLine

    var body: some View {
        HStack(spacing: WorkbenchTokens.Cases.statusGap) {
            Image(systemName: line.symbol).font(WorkbenchTokens.Cases.statusGlyph)
                .foregroundStyle(line.failed ? WorkbenchTokens.Panel.failedColor : WorkbenchTokens.V2.subColor)
            Text(line.text).font(WorkbenchTokens.Cases.statusFont)
                .foregroundStyle(line.failed ? WorkbenchTokens.V2.titleColor : WorkbenchTokens.V2.bodyColor)
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .help(line.text)
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Remembered (NH-03)

/// On the board, a while after a request comes back: what memory took from it, with Open.
struct V2MemoryRow: View {
    let model: WorkbenchModel
    let notice: V2MemoryNotice

    var body: some View {
        let B = WorkbenchTokens.Board.self
        let C = WorkbenchTokens.Cases.self
        HStack(spacing: B.iconGap) {
            Image(systemName: "brain").font(C.memoryGlyph).foregroundStyle(WorkbenchTokens.V2.subColor)
                .frame(width: B.badgedIcon)
            (Text("Remembered: ").foregroundColor(B.line) + Text(notice.title).foregroundColor(B.title))
                .font(B.lineFont)
                .lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 6)
            AgentPanelButton(title: L("Open"), primary: false) { model.openMemoryNotice() }
            NotchIconButton(symbol: "xmark", glyph: B.chevron, size: B.expandButton - 4, help: L("Dismiss")) { model.dismissMemoryNotice() }
        }
        .padding(.horizontal, B.rowPaddingH)
        .frame(height: C.memoryRow)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Remembered: \(notice.title)")
    }
}

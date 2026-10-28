import SwiftUI
import AppKit
import FoveaCore
import FoveaLook
import FoveaKit

// Dispatch Version 2 in the island (the flow is in WorkbenchModel+DispatchV2.swift): Choose chat
// (the Sentence since Oct 27, ChooseChatSentence.swift; the suggestions and every chat a ⌃ away), the
// control board (the focus's screen beside what is ready for review and what is running), the
// expanded chat (the request, the response beside its screen, the grab bar), and the chats
// pulled out of the notch. One width for every open shape; content kept 16 pt inside the
// island's body, which starts where its ears end. docs/island/DISPATCH_V2.md has the reasons.

// MARK: Geometry

enum V2Geometry {
    /// The island's body: the outline less its ears.
    static var bodyInset: CGFloat { WorkbenchTokens.Island.spec.expandedTopRadius }
    /// Where content starts, and how wide it is: the body less its margin, the same both sides.
    static var contentX: CGFloat { bodyInset + WorkbenchTokens.V2.margin }
    static var contentWidth: CGFloat { WorkbenchTokens.V2.width - 2 * contentX }

    static func top(_ metrics: ScreenMetrics) -> CGFloat {
        NotchGeometry.notchRect(metrics: metrics, spec: WorkbenchTokens.Island.spec).height + WorkbenchTokens.V2.topGap
    }

    /// The open shape for content this tall (and this much below it): the panel's width, the
    /// expanded ears, a rounder bottom.
    static func outline(content: CGFloat, bottom: CGFloat = WorkbenchTokens.V2.margin, width: CGFloat = WorkbenchTokens.V2.width,
                        metrics: ScreenMetrics) -> StackLayout.Outline {
        let V = WorkbenchTokens.V2.self
        let spec = WorkbenchTokens.Island.spec
        return StackLayout.Outline(size: CGSize(width: width, height: top(metrics) + content + bottom),
                                   topRadius: spec.expandedTopRadius, bottomRadius: V.bottomRadius)
    }

    /// The words' height at this width, as SwiftUI sets them.
    static func measure(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, width: CGFloat,
                        spacing: CGFloat = 2, lines: Int? = nil) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = spacing
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        let attributed = NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: style])
        var height = ceil(attributed.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                  options: [.usesLineFragmentOrigin, .usesFontLeading]).height)
        if let lines {
            let line = ceil(font.ascender - font.descender + font.leading) + spacing
            height = min(height, CGFloat(lines) * line - spacing)
        }
        return height + 2
    }

    /// A line of words' width, set on one line.
    static func lineWidth(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular) -> CGFloat {
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        return ceil(NSAttributedString(string: text, attributes: [.font: font]).size().width) + 1
    }
}

/// Choose chat (Oct 27, the Sentence): the request, large; a hairline; the sentence; every chat
/// (the suggestions first), opened; the model's sheet.
struct V2SendLayout: Equatable {
    var outline: StackLayout.Outline
    var text: CGFloat
    var browser: CGFloat

    static func make(request: String, attachments: Int, browsing: Bool, browseRows: Int, sheet: Bool = false,
                     sheetNotes: Int = 0, sending: Bool = false, metrics: ScreenMetrics) -> V2SendLayout {
        let V = WorkbenchTokens.V2.self
        let K = WorkbenchTokens.Composer.self
        // Emptied while being edited: the prompt's one line.
        let text = V2Geometry.measure(request.isEmpty ? " " : request, size: K.sentenceRequestSize, weight: K.sentenceMeasureWeight,
                                      width: V2Geometry.contentWidth, spacing: K.sentenceSpacing, lines: K.sentenceLines)
        // As the browser draws it: its top, its rule, the suggestions, the rail, the rows (Compact
        // measured 1 short).
        let browser = browsing ? V2RouteSheet.browserHeight(rows: browseRows, suggestions: true) : 0
        // Feedback #1: the model and effort's sheet, under the sentence (Oct 15 review, QA08/QA09:
        // with the approvals, and a line of notes when a model can't be picked).
        let modelSheet = sheet ? V.gap + V2ModelSheet.height(chats: false, notes: sheetNotes) : 0
        // After Send, where it's going (or why it didn't go) takes a row.
        let status = sending ? K.statusRow : 0
        let content = text + 2 * K.ruleGap + 1 + K.sentenceRow + status + browser + modelSheet
        return V2SendLayout(outline: V2Geometry.outline(content: content, metrics: metrics), text: text, browser: browser)
    }
}

/// A chat pulled out of the notch.
enum V2DetachedLayout {
    static var size: CGSize { WorkbenchTokens.V2.detachedSize }
    /// Where the pointer holds it: its header.
    static let grip: CGFloat = 18
}

// MARK: Pieces

/// A key, drawn as the keyboard shows it.
struct V2Key: View {
    let text: String

    var body: some View {
        let V = WorkbenchTokens.V2.self
        Text(text)
            .font(V.keyFont)
            .foregroundStyle(V.keyColor)
            .frame(minWidth: V.keySize, minHeight: V.keySize)
            .padding(.horizontal, text.count > 1 ? 4 : 0)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(V.keyFill))
    }
}

/// The keys at the foot of a shape: a key, what it does.
struct V2Hints: View {
    let hints: [(String, String)]

    var body: some View {
        let V = WorkbenchTokens.V2.self
        HStack(spacing: 14) {
            ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
                HStack(spacing: 5) {
                    Text(hint.0).font(V.hintKeyFont)
                    Text(hint.1).font(V.hintFont)
                }
            }
        }
        .foregroundStyle(V.hintColor)
    }
}

/// A small capsule label: a project, or "Quick answer".
struct V2Badge: View {
    let text: String

    var body: some View {
        let V = WorkbenchTokens.V2.self
        Text(text)
            .font(V.badgeFont)
            .foregroundStyle(V.subColor)
            .lineLimit(1)
            .padding(.horizontal, V.badgePaddingH)
            .frame(height: V.badgeHeight)
            .background(Capsule().fill(V.badgeFill))
            .fixedSize()
    }
}

/// A session's state in words: Ready for review (with how long it took), Working with what it
/// is doing, Needs you, Failed.
struct V2StateLine: View {
    let model: WorkbenchModel
    let task: AgentTaskItem

    var body: some View {
        let V = WorkbenchTokens.V2.self
        HStack(spacing: 5) {
            AgentStateGlyph(task: task, size: 9, paused: model.snapshotMode)
            Text(words)
                .font(V.statusFont)
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }

    private var words: String {
        switch task.state {
        // Oct 18, Ryan: in the primary language.
        case .complete: return model.v2Checked.contains(task.id) ? L("Complete") : L("Ready for review")
        case .working: return task.stalled ? task.line : L("Working · \(model.v2Line(task))")
        case .needsYou: return L("Needs you · \(task.line)")
        case .failed: return task.stopped ? L("Stopped") : L("Failed · \(task.line)")
        }
    }

    private var color: Color {
        let V = WorkbenchTokens.V2.self
        switch task.state {
        case .complete: return model.v2Checked.contains(task.id) ? V.subColor : V.readyColor
        case .needsYou: return WorkbenchTokens.Panel.needsYouColor
        case .failed: return task.stopped ? V.subColor : WorkbenchTokens.Panel.failedColor
        case .working: return V.subColor
        }
    }
}

/// A session's agent, its name, its project, and its state.
struct V2SessionHeader: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    var avatar: CGFloat = WorkbenchTokens.V2.avatar

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let quick = task.project == DispatchV2.quickProject
        HStack(spacing: 10) {
            ChatAgentIcon(agent: ChatAgent.named(task.agent), size: avatar)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    // Feedback #15: the name made from the request.
                    Text(model.v2Title(task))
                        .font(V.titleFont)
                        .foregroundStyle(V.titleColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    V2Badge(text: quick ? L("Quick answer") : task.project)
                }
                V2StateLine(model: model, task: task)
            }
        }
    }
}

// MARK: Choose chat

/// Choose chat, the Sentence (Oct 27, ChooseChatSentence.swift): the request; the sentence, what
/// was taken, To the chat, thinking how hard, Send; with ⌃ (or the chat), the suggestions, then
/// every chat below, by agent.
struct V2SendContent: View {
    let model: WorkbenchModel
    let layout: V2SendLayout

    var body: some View {
        let V = WorkbenchTokens.V2.self
        ZStack(alignment: .topLeading) {
            Color.clear
            VStack(alignment: .leading, spacing: 0) {
                ComposerSentence(model: model, layout: layout)
                // Oct 15 review, QA06/QA10: after Send, where it's going (the chat locked), or why it
                // didn't go.
                if let sending = model.cases.sending {
                    V2SendStatusRow(model: model, sending: sending)
                        .frame(height: WorkbenchTokens.Composer.statusRow)
                        .transition(.opacity)
                }
                if model.v2Browsing {
                    V2ChatBrowser(model: model, suggestions: true)
                        .frame(height: layout.browser, alignment: .top)
                        .transition(.opacity)
                }
                if model.v2ModelSheet {
                    V2ModelSheet(model: model)
                        .padding(.top, V.gap)
                        .transition(.opacity)
                }
            }
            .frame(width: V2Geometry.contentWidth, alignment: .topLeading)
            .offset(x: V2Geometry.contentX, y: V2Geometry.top(model.metrics))
            // A taken thing, looked at closer: it fades in over the window (Oct 21, Ryan, "simpler
            // is better": it no longer grows out of its thumbnail).
            if let id = model.v2Inspecting, let referent = model.liveReferents.first(where: { $0.id == id }) {
                V2AttachmentInspect(model: model, referent: referent, layout: layout)
            }
        }
        .frame(width: layout.outline.size.width, height: layout.outline.size.height, alignment: .topLeading)
        // Oct 21, Ryan: opening with a little bounce, folding back without.
        .animation(model.v2Browsing ? WorkbenchTokens.V2.resize : WorkbenchTokens.V2.fold, value: model.v2Browsing)
        .animation(model.v2ModelSheet ? WorkbenchTokens.V2.resize : WorkbenchTokens.V2.fold, value: model.v2ModelSheet)
        .animation(WorkbenchTokens.Cases.change, value: model.cases.sending)
        .panelScheme()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Choose chat")
    }
}

/// A suggested chat as a chip: its agent and name; the one chosen marked.
struct V2SuggestionChip: View {
    let model: WorkbenchModel
    let pick: V2Suggestion
    let chosen: Bool
    /// Oct 27: in every chat's list (the new designs), chosen, the list folds as a chat picked does.
    var folds = false
    @State private var hovering = false

    var body: some View {
        let V = WorkbenchTokens.V2.self
        Button {
            model.chooseV2(pick)
            if folds { model.foldV2Browse() }
        } label: {
            HStack(spacing: 6) {
                ChatAgentIcon(agent: ChatAgent.named(pick.agent), size: V.chipIcon)
                Text(pick.title).font(V.chipFont).foregroundStyle(chosen ? V.titleColor : V.chipText).lineLimit(1)
            }
            .padding(.horizontal, V.chipPaddingH)
            .frame(height: V.chipHeight)
            .background(Capsule(style: .continuous).fill(chosen ? V.chipChosenFill : (hovering ? V.hoverFill : V.chipFill)))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(IslandPressStyle())
        .onHover { hovering = $0 }
        .help("\(ChatAgent.named(pick.agent).name)\(pick.project.map { " · \($0)" } ?? "") · \(pick.reason)")
        .accessibilityLabel("\(pick.title), \(pick.reason)")
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}

/// A taken thing in Choose chat: a screenshot, a passage, a file, as its card; it opens larger on a
/// click.
struct V2AttachmentThumb: View {
    let model: WorkbenchModel
    let referent: CapturedReferent

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let width = min(V.attachThumb * referent.aspect, V.attachThumb * 2)
        Image(nsImage: referent.image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: V.attachThumb)
            .clipShape(RoundedRectangle(cornerRadius: V.attachmentRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: V.attachmentRadius, style: .continuous).strokeBorder(WorkbenchTokens.ink(0.2), lineWidth: 0.75))
            .overlay(alignment: .bottomLeading) { kindBadge.padding(3) }
            .onTapGesture {
                withAnimation(WorkbenchTokens.V2.inspectFade) { model.v2Inspecting = referent.id }
            }
            .help(referent.source)
            .accessibilityLabel("\(referent.kind.label) from \(referent.source)")
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var kindBadge: some View {
        switch referent.kind {
        case .screenshot: EmptyView()
        case .text: badge("text.quote")
        case .file: badge("doc.fill")
        }
    }

    private func badge(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 7.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 15, height: 15)
            .background(Circle().fill(Color.black.opacity(0.6)))
    }
}

/// A taken thing, larger: over the window, its source under it; a click puts it back.
struct V2AttachmentInspect: View {
    let model: WorkbenchModel
    let referent: CapturedReferent
    let layout: V2SendLayout

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let maxH = layout.outline.size.height - V2Geometry.top(model.metrics) - V.margin - 22
        let h = min(maxH, V2Geometry.contentWidth / referent.aspect)
        let w = h * referent.aspect
        ZStack(alignment: .topLeading) {
            WorkbenchTokens.inverseInk(0.78)
                .onTapGesture { close() }
            VStack(spacing: 6) {
                Image(nsImage: referent.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: w, height: h)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onTapGesture { close() }
                Text("\(referent.kind.label) · \(referent.source)")
                    .font(V.hintFont).foregroundStyle(V.subColor)
            }
            .frame(width: V2Geometry.contentWidth)
            .offset(x: V2Geometry.contentX, y: V2Geometry.top(model.metrics))
        }
        .frame(width: layout.outline.size.width, height: layout.outline.size.height, alignment: .topLeading)
        .transition(.opacity)
        .accessibilityAddTraits(.isModal)
    }

    private func close() {
        withAnimation(WorkbenchTokens.V2.inspectFade) { model.v2Inspecting = nil }
    }
}

/// Every chat, as Dispatch's expanded view has them: the agents' icons in a rail (the active one in
/// a pill, its name at the right); under it a New chat and the agent's chats, the latest first, a
/// page at a time (Oct 27: the agents give no folders). A chat goes into the pill.
struct V2ChatBrowser: View {
    let model: WorkbenchModel
    /// Oct 27, Ryan: "the suggested chats can go into the choose chat button": in the new designs,
    /// the list opens on them.
    var suggestions = false

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let active = ChatAgent.named(model.v2BrowseAgent)
        VStack(alignment: .leading, spacing: V.browseSpacing) {
            Rectangle().fill(V.rule).frame(height: 1)
            if suggestions {
                ComposerSuggestedRow(model: model)
            }
            HStack(spacing: V.railGap) {
                ForEach(ChatAgent.all) { agent in
                    Button { model.browseV2Agent(agent.id) } label: {
                        ChatAgentIcon(agent: agent, size: V.railIcon)
                            .opacity(agent.id == active.id ? 1 : WorkbenchTokens.Chat.railIdleOpacity)
                            .frame(width: V.railTab.width, height: V.railTab.height)
                            .background(RoundedRectangle(cornerRadius: V.railTabRadius, style: .continuous)
                                .fill(agent.id == active.id ? V.chosenFill : .clear))
                    }
                    .buttonStyle(.plain)
                    .help(agent.name)
                }
                // Oct 15 review, QA04: the agent's chats by title or project.
                V2BrowseSearchField(model: model)
                    .padding(.leading, V.railGap)
                Spacer()
                Text(active.name).font(V.railName).foregroundStyle(V.titleColor)
                    .padding(.trailing, 10)
            }
            .frame(height: V.railHeight)
            column {
                ForEach(model.v2BrowseRows) { row in
                    V2BrowseRowView(model: model, row: row)
                        .frame(height: V.browseRow)
                }
            }
        }
        .padding(.top, V.gap - V.browseSpacing)
    }

    /// The list, scrolling when it must; drawn off the screen, where a scroll view draws nothing,
    /// its rows clipped.
    @ViewBuilder
    private func column<Rows: View>(@ViewBuilder _ rows: () -> Rows) -> some View {
        let stack = VStack(spacing: 0) { rows() }
        if model.offscreenRender {
            stack.frame(minHeight: 0, maxHeight: .infinity, alignment: .top).clipped()
        } else {
            ScrollView { stack }
                .scrollIndicators(.automatic)
        }
    }
}

struct V2BrowseRowView: View {
    let model: WorkbenchModel
    let row: V2BrowseRow
    @State private var hovering = false

    var body: some View {
        let V = WorkbenchTokens.V2.self
        if case .status(let status) = row {
            // Oct 15 review, QA04: the list on its way, one that couldn't load, nothing matching.
            V2BrowseStatusRow(model: model, status: status)
        } else {
            button(V)
        }
    }

    private func button(_ V: WorkbenchTokens.V2.Type) -> some View {
        Button { model.pickV2Browse(row) } label: {
            HStack(spacing: 10) {
                switch row {
                case .status:
                    EmptyView()
                case .more(let count):
                    V2BrowseMoreLabel(count: count)
                case .chat(let chat):
                    // Oct 15 review, QA05: one that can't take the request is dimmed and says why.
                    let blocked = model.v2ChatBlock(chat)
                    // Oct 27, Ryan: "the icon before the chat should be the icon of the coding agent";
                    // a New chat's carries a plus.
                    ChatAgentIcon(agent: ChatAgent.named(chat.agent), size: V.browseIcon)
                        .overlay(alignment: .bottomTrailing) {
                            if chat.isNew {
                                Image(systemName: "plus.circle.fill").font(V.browseNewGlyph)
                                    .foregroundStyle(V.titleColor).background(Circle().fill(V.browseNewPlate))
                                    .offset(x: V.browseNewOffset, y: V.browseNewOffset)
                            }
                        }
                        .opacity(blocked == nil ? 1 : WorkbenchTokens.Chat.railIdleOpacity)
                    Text(chat.title).font(V.browseFont)
                        .foregroundStyle(blocked == nil ? V.titleColor : WorkbenchTokens.Cases.blockedTitle).lineLimit(1)
                    Spacer(minLength: 6)
                    if let blocked {
                        V2BlockedReason(reason: blocked, chat: chat)
                    } else if !chat.isNew {
                        Text(chat.age).font(V.reasonFont).foregroundStyle(V.subColor).monospacedDigit()
                    }
                }
            }
            .padding(.horizontal, V.browsePaddingH)
            .frame(maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: V.rowRadius, style: .continuous)
                .fill(hovering && !isBlocked ? V.hoverFill : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private var isBlocked: Bool {
        if case .chat(let chat) = row { return model.v2ChatBlock(chat) != nil }
        return false
    }
}

/// The agent's response: the outcome, then what fits it (a formula's terms, rows of data, a few
/// points, a draft, the files it touched, what needs the person's eyes); while it works, what it is
/// doing.
struct V2Response: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let width: CGFloat

    var body: some View {
        let V = WorkbenchTokens.V2.self
        VStack(alignment: .leading, spacing: V.responseGap) {
            if let r = task.result, task.state == .complete || task.state == .failed {
                Text(r.outcome)
                    .font(.system(size: V.outcomeSize, weight: .semibold))
                    .lineSpacing(3)
                    .foregroundStyle(V.outcomeColor)
                    .fixedSize(horizontal: false, vertical: true)
                if !r.terms.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(r.terms) { term in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(term.term).font(.system(size: 14, design: .serif)).italic().foregroundStyle(V.titleColor)
                                    .frame(width: 58, alignment: .leading)
                                Text(term.meaning).font(.system(size: 13)).foregroundStyle(V.bodyColor)
                            }
                            .frame(height: 20)
                        }
                    }
                }
                if !r.rows.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(r.rows) { row in
                            HStack(spacing: 10) {
                                Text(row.lead).font(.system(size: 13, weight: .medium)).monospacedDigit().foregroundStyle(V.titleColor)
                                    .frame(width: 66, alignment: .leading)
                                Text(row.text).font(.system(size: 13)).foregroundStyle(V.bodyColor).lineLimit(1)
                                if let detail = row.detail { Text(detail).font(.system(size: 12)).foregroundStyle(V.subColor).lineLimit(1) }
                            }
                            .frame(height: 22)
                        }
                    }
                }
                if !r.points.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(r.points.enumerated()), id: \.offset) { i, point in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("\(i + 1).").foregroundStyle(V.subColor).frame(width: 14, alignment: .leading)
                                Text(point).foregroundStyle(V.bodyColor).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                            }
                            .font(.system(size: 13))
                        }
                    }
                }
                if let plainly = r.plainly {
                    Text(plainly).font(.system(size: 13)).foregroundStyle(V.subColor).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let draft = r.draft {
                    Text(draft)
                        .font(.system(size: 13)).lineSpacing(3).foregroundStyle(V.titleColor)
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(width: width, alignment: .topLeading)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(WorkbenchTokens.ink(0.06)))
                }
                if !r.artifacts.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(r.artifacts, id: \.self) { name in
                            HStack(spacing: 5) {
                                Image(systemName: name.hasSuffix(".swift") ? "swift" : "doc.text").font(.system(size: 9.5, weight: .semibold))
                                Text(name).lineLimit(1)
                            }
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(V.titleColor)
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(Capsule(style: .continuous).fill(WorkbenchTokens.ink(0.08)))
                        }
                    }
                }
                ForEach(r.attention, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill").font(.system(size: 10))
                        Text(line)
                    }
                    .font(.system(size: 12.5))
                    .foregroundStyle(WorkbenchTokens.Panel.needsYouColor)
                }
            } else if task.state == .needsYou {
                // Oct 15 review, QA14/QA15: what it asks, in full, and how to answer.
                V2NeedsYouBody(model: model, task: task, width: width)
            } else {
                // At work: what it is doing now; it comes back here when it is done.
                Text(task.state == .needsYou ? task.activity : task.line)
                    .font(.system(size: V.outcomeSize, weight: .semibold))
                    .foregroundStyle(task.state == .needsYou ? WorkbenchTokens.Panel.needsYouColor : V.outcomeColor)
                    .fixedSize(horizontal: false, vertical: true)
                Text(task.state == .needsYou ? "It is waiting on you." : "Its screen is live beside this; the answer comes back here.")
                    .font(V.responseFont).foregroundStyle(V.subColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: width, alignment: .topLeading)
    }
}

// MARK: Pulled out of the notch

/// The chats pulled out of the notch: small windows anywhere on the screen, or tabs tucked into
/// its sides; and the one being pulled, following the pointer. On the real Mac the pulled-out
/// chats have a layer of their own, which follows the pointer to the display in use (Oct 11): the
/// island's layer draws only the one being pulled (`chats: false`), theirs only the chats.
struct V2DetachedLayer: View {
    let model: WorkbenchModel
    var chats = true
    var pulling = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let size = V2DetachedLayout.size
        let area = chats ? model.detachedArea : model.display.frame.size
        ZStack(alignment: .topLeading) {
            if chats {
                ForEach(model.v2Detached) { item in
                    if let side = item.docked {
                        // Oct 21, Ryan: tucked in, its tab slides in from that edge (and back out to it).
                        // Oct 21 motion review: under Reduce Motion it only fades, nothing slides.
                        V2DockedTab(model: model, item: item, side: side)
                            .transition(reduceMotion ? .opacity : .tuck(side))
                    } else {
                        // At its own size, its top-left where it is; it goes, and comes back, as a
                        // window does: a little smaller and faded.
                        V2DetachedWindow(model: model, item: item)
                            .frame(width: item.size.width, height: item.size.height)
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: WorkbenchTokens.V2.tuckScale)))
                            .position(x: item.origin.x + item.size.width / 2, y: item.origin.y + item.size.height / 2)
                    }
                }
            }
            if pulling, let drag = model.v2DragOut {
                V2DetachedWindow(model: model, item: V2Detached(id: drag.id, origin: .zero, docked: nil, dockY: 0), ghost: true)
                    .position(x: drag.point.x, y: drag.point.y - V2DetachedLayout.grip + size.height / 2)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: area.width, height: area.height, alignment: .topLeading)
    }
}

/// A chat as a small window: its header (drag it anywhere; to a side, it tucks in; ✕ closes),
/// the conversation (the request, the screen, the response, and every follow-up), the box to ask
/// more; its sides and corners resize it, as a Mac window's (a pinch does too): the window changes,
/// never its words.
struct V2DetachedWindow: View {
    let model: WorkbenchModel
    let item: V2Detached
    var ghost = false
    @State private var dragStart: CGPoint?
    @State private var pinchStart: CGSize?

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let size = ghost ? V2DetachedLayout.size : item.size
        let inner = size.width - 2 * V.detachedPadding
        let shape = RoundedRectangle(cornerRadius: V.detachedRadius, style: .continuous)
        VStack(alignment: .leading, spacing: V.detachedSpacing) {
            if let task = model.v2Task(item.id) {
                HStack(spacing: 8) {
                    ChatAgentIcon(agent: ChatAgent.named(task.agent), size: V.detachedIcon)
                    Text(model.v2Title(task))
                        .font(V.detachedTitle).foregroundStyle(V.titleColor).lineLimit(1)
                    Spacer(minLength: 4)
                    // Oct 15 review, QA16/QA25: the connection, or read only, when it isn't fine.
                    if V2HeaderPill.shown(model, task) { V2HeaderPill(model: model, task: task) }
                    // ✕ only: it closes the chat. Oct 15 review, QA21: a session still at work goes
                    // back on the board and keeps working (only Stop stops).
                    NotchIconButton(symbol: "xmark", glyph: V.detachedCloseGlyph, size: V.detachedClose,
                                    help: task.state == .working ? L("Close (it keeps working, on the board)") : L("Close")) {
                        model.closeDetachedV2(item.id)
                    }
                }
                .frame(height: V.detachedHeader)
                .contentShape(Rectangle())
                .gesture(move)
                V2Conversation(model: model, task: task, width: inner)
                // What waits (#24); Open in its app and Answer again, or Stop (#23); the box to ask more.
                if !(model.v2Queue[item.id] ?? []).isEmpty {
                    V2QueueSection(model: model, task: task, width: inner)
                }
                V2SessionBar(model: model, task: task)
                    .frame(height: WorkbenchTokens.Board.actionRow)
                // Oct 15 review, QA25: read only, or gone: a line where the box was.
                if model.cases.readOnly.contains(item.id) || model.cases.gone.contains(item.id) {
                    V2ReadOnlyLine(model: model, task: task)
                } else {
                    V2FollowUpField(model: model, id: item.id)
                }
            }
        }
        .padding(V.detachedPadding)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        // Native: a glass panel, as macOS's popover dragged off into a panel. Oct 21, Ryan
        // ("simpler is better"): one edge (the glass's own rim in Native, a hairline on the
        // Original's fill) and a lighter, closer shadow; it had a second edge over the glass's
        // and a shadow of 22 pt.
        .surface(shape, original: V.detachedFill)
        .overlay { if !WorkbenchTokens.isNative { shape.strokeBorder(V.detachedBorder, lineWidth: 0.75) } }
        .clipShape(shape)
        .shadow(color: V.detachedShadow, radius: V.detachedShadowRadius, y: V.detachedShadowY)
        // Its four sides and corners resize it, as a Mac window's (Oct 24).
        .overlay { if !ghost { V2WindowEdges(model: model, item: item) } }
        .simultaneousGesture(pinch)
        .opacity(ghost ? 0.92 : 1)
        .panelScheme()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pulled-out chat")
    }

    /// A pinch on the trackpad resizes the window, as its corner does; the words keep their size.
    /// Oct 21, Ryan: past its sizes it gives a little, then springs back on release.
    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = pinchStart ?? item.size
                if pinchStart == nil { pinchStart = item.size }
                model.resizeDetachedV2(item.id, to: CGSize(width: start.width * value.magnification,
                                                           height: start.height * value.magnification), elastic: true)
            }
            .onEnded { _ in
                pinchStart = nil
                model.endResizeDetachedV2(item.id)
            }
    }

    /// Dragging the header moves the window, 1:1 with the pointer; let go with the pointer at a
    /// side, it tucks in. Oct 21, Ryan: let go, it carries the release velocity on into a spring.
    private var move: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(ScreenSpace.name))
            .onChanged { value in
                let start = dragStart ?? item.origin
                if dragStart == nil { dragStart = item.origin }
                model.moveDetachedV2(item.id, to: CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height))
            }
            .onEnded { value in
                dragStart = nil
                model.endMoveDetachedV2(item.id, pointer: value.location, velocity: value.velocity)
            }
    }
}

/// A pulled-out chat's sides, as a Mac window's (Oct 24, Ryan: "by dragging all four sides of that
/// chat. So it behaves like any other Mac OS apps"): each edge and each corner, dragged, moves that
/// side and leaves the one across from it where it is; under the pointer, the pointer shows which
/// way it goes. The bands straddle the window's outline, half outside it, where macOS puts them.
/// The window changes, never its words (Oct 11).
struct V2WindowEdges: View {
    let model: WorkbenchModel
    let item: V2Detached

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let w = item.size.width, h = item.size.height
        ZStack(alignment: .topLeading) {
            ForEach(V2WindowEdge.all, id: \.self) { edge in
                V2WindowEdgeHandle(model: model, item: item, edge: edge)
                    .frame(width: edge.x == 0 ? max(0, w - V.resizeCorner) : (edge.corner ? V.resizeCorner : V.resizeEdge),
                           height: edge.y == 0 ? max(0, h - V.resizeCorner) : (edge.corner ? V.resizeCorner : V.resizeEdge))
                    .position(x: CGFloat(edge.x + 1) / 2 * w, y: CGFloat(edge.y + 1) / 2 * h)
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }
}

/// One side of a pulled-out chat (V2WindowEdges): a band (or a corner's square) that takes the
/// pointer and the drag.
private struct V2WindowEdgeHandle: View {
    let model: WorkbenchModel
    let item: V2Detached
    let edge: V2WindowEdge
    @State private var start: CGRect?

    var body: some View {
        let handle = Color.clear
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active: if model.v2ResizeEdge != edge { model.v2ResizeEdge = edge }
                case .ended: if start == nil, model.v2ResizeEdge == edge { model.v2ResizeEdge = nil }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(ScreenSpace.name))
                    .onChanged { value in
                        let from = start ?? CGRect(origin: item.origin, size: item.size)
                        if start == nil { start = from; model.v2ResizeEdge = edge }
                        model.resizeDetachedV2(item.id, edge: edge, from: from, by: value.translation)
                    }
                    .onEnded { _ in
                        start = nil
                        model.endResizeDetachedV2(item.id, edge: edge)
                        model.v2ResizeEdge = nil
                    }
            )
        if edge == .bottomRight {
            // The window's size for VoiceOver, on one of them: larger or smaller by a step.
            handle
                .accessibilityElement()
                .accessibilityLabel("Size")
                .accessibilityValue("\(Int(item.size.width)) by \(Int(item.size.height)) points")
                .accessibilityAdjustableAction { direction in
                    let step: CGFloat = direction == .increment ? 40 : -40
                    model.resizeDetachedV2(item.id, to: CGSize(width: item.size.width + step, height: item.size.height + step))
                }
        } else {
            handle.accessibilityHidden(true)
        }
    }
}

/// A pulled-out chat's conversation: each exchange as the request in its bubble and what came back
/// (what the agent did folded over it), the one now with the agent's screen. With follow-ups, a
/// rail at the right (after Notion's outline) shows which exchange is in view and, on hover, lists
/// them all to jump to.
struct V2Conversation: View {
    let model: WorkbenchModel
    let task: AgentTaskItem
    let width: CGFloat
    @State private var tops: [Int: CGFloat] = [:]

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let turns = model.v2Turns(task.id)
        let now = turns.count - 1
        let railed = turns.count > 1
        let column = railed ? width - V.railGutter : width
        let space = "v2-turns-\(task.id)"
        let inView = turns.last { (tops[$0.id] ?? .infinity) <= V.railReadLine }?.id ?? 0
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: V.turnGap) {
                    ForEach(turns) { turn in
                        VStack(alignment: .leading, spacing: V.turnSpacing) {
                            // Oct 24, Ryan: each request in its bubble at the right, the answer
                            // open at the left; space between the exchanges, no rules.
                            if turn.id == now {
                                // Oct 15 review, QA07: the last request, editable once answered.
                                V2EditableQuestion(model: model, task: task, lines: 3,
                                                   beside: V2RequestBubble.bubbleWidth(turn.question, width: column)) {
                                    V2RequestBubble(text: turn.question, width: column)
                                }
                                .frame(width: column)
                            } else {
                                V2RequestBubble(text: turn.question, width: column)
                            }
                            if turn.id == now {
                                // At work, one quiet line; done, the answer as written. Oct 15
                                // review: reopening, gone, not sure it arrived, what was decided.
                                if let kind = model.v2CaseBody(task) {
                                    V2CaseBodyView(model: model, task: task, kind: kind, width: column)
                                } else if task.state == .working {
                                    V2WorkingLine(model: model, task: task)
                                } else if task.state == .needsYou {
                                    V2Response(model: model, task: task, width: column)
                                } else {
                                    V2Answer(model: model, task: task, width: column)
                                }
                            } else if let answer = turn.answer {
                                // What the agent did, folded, as in the notch (WHOLE_SESSION.md).
                                VStack(alignment: .leading, spacing: WorkbenchTokens.FeedbackV2.answerGap) {
                                    if let work = turn.work {
                                        V2WorkFold(model: model, work: work, key: V2Work.key(task.id, turn: turn.id), width: column)
                                    }
                                    MarkdownView(markdown: answer, width: column)
                                }
                            } else if let result = turn.result {
                                V2Response(model: model, task: answered(result), width: column)
                            } else {
                                Text(V.movedOn).font(V.movedOnFont).foregroundStyle(V.subColor)
                            }
                        }
                        .id(turn.id)
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: V2TurnTops.self, value: [turn.id: geo.frame(in: .named(space)).minY])
                        })
                    }
                }
                .frame(width: width, alignment: .leading)
            }
            .scrollIndicators(railed ? .never : .automatic)
            .coordinateSpace(name: space)
            .onPreferenceChange(V2TurnTops.self) { tops = $0 }
            .overlay(alignment: .topTrailing) {
                if railed {
                    V2TurnRail(turns: turns, inView: inView) { id in
                        withAnimation(WorkbenchTokens.Spring.rows) { proxy.scrollTo(id, anchor: .top) }
                    }
                }
            }
            // A new question: it comes into view.
            .onChange(of: turns.count) { _, _ in
                withAnimation(WorkbenchTokens.Spring.rows) { proxy.scrollTo(now, anchor: .top) }
            }
        }
    }

    /// An earlier exchange's answer, drawn as a finished one.
    private func answered(_ result: AgentResult) -> AgentTaskItem {
        var past = task
        past.result = result
        past.state = .complete
        return past
    }
}

/// Where each exchange starts in the chat's scroll, to tell which is in view.
struct V2TurnTops: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

/// The rail (Notion's outline, at a chat's right edge): a short line per exchange, longer for a
/// longer question, the one in view bright. Hovered, it opens to the questions; a click goes there.
struct V2TurnRail: View {
    let turns: [V2Turn]
    let inView: Int
    let go: (Int) -> Void
    @State private var open = false
    @State private var hovered: Int?

    var body: some View {
        let V = WorkbenchTokens.V2.self
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .trailing, spacing: V.railLineGap) {
                ForEach(turns) { turn in
                    Capsule()
                        .fill(turn.id == inView ? V.railLineOn : V.railLineOff)
                        .frame(width: lineWidth(turn.question), height: V.railLineHeight)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .opacity(open ? 0 : 1)
            if open {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(turns) { turn in
                        Button { go(turn.id) } label: {
                            Text(turn.question)
                                .font(.system(size: 12, weight: turn.id == inView ? .semibold : .regular))
                                .foregroundStyle(turn.id == inView ? V.titleColor : V.subColor)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .frame(maxWidth: .infinity, minHeight: V.railRow, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(hovered == turn.id ? V.railRowHover : .clear))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { hovered = $0 ? turn.id : (hovered == turn.id ? nil : hovered) }
                    }
                }
                .padding(5)
                .frame(width: V.railCardWidth)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(V.railCardFill))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(V.detachedBorder, lineWidth: 0.75))
                // Oct 21, Ryan ("simpler is better"): a lighter shadow, and it fades (no scale).
                .shadow(color: V.railCardShadow, radius: V.railCardShadowRadius, y: 3)
                .transition(.opacity)
            }
        }
        .onHover { inside in withAnimation(V.railMotion) { open = inside } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Questions in this chat")
    }

    private func lineWidth(_ question: String) -> CGFloat {
        let V = WorkbenchTokens.V2.self
        let t = min(1, CGFloat(question.count) / 60)
        return V.railLineMin + (V.railLineMax - V.railLineMin) * t
    }
}

/// The words said, editable in place. Oct 27, Ryan: "users will also be able to edit the transcribed
/// words here on the notch." A click puts the caret in them (the notch takes the keys without
/// taking the app in front); Return sends, ⌥Return starts a new line, Esc stops editing. Under the
/// pointer and while editing, a field shows round them, outside their box, so they don't move.
struct V2RequestEditor: View {
    let model: WorkbenchModel
    /// Oct 27: the Choose chat designs set the words larger (Sentence) or on more lines (Ticket).
    var size: CGFloat? = nil
    var weight: Font.Weight? = nil
    var spacing: CGFloat? = nil
    var lines = 2
    @FocusState private var focused: Bool
    @State private var hovering = false

    var body: some View {
        let V = WorkbenchTokens.V2.self
        Group {
            if model.offscreenRender {
                Text(model.v2Spoken).lineLimit(lines)
            } else {
                TextField(L("Your request"), text: Binding(get: { model.v2Spoken }, set: { model.editV2Request($0) }), axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...lines)
                    .focused($focused)
                    .onSubmit {
                        focused = false
                        _ = model.v2Key(.enter)
                    }
                    .onKeyPress(.escape) {
                        focused = false
                        return .handled
                    }
            }
        }
        .font(.system(size: size ?? V.requestSize, weight: weight ?? V.requestWeight))
        .lineSpacing(spacing ?? V.requestSpacing)
        .foregroundStyle(V.requestColor)
        .background {
            RoundedRectangle(cornerRadius: V.requestEditRadius, style: .continuous)
                .fill(focused ? V.requestEditFill : (hovering ? V.hoverFill : .clear))
                .overlay(RoundedRectangle(cornerRadius: V.requestEditRadius, style: .continuous)
                    .strokeBorder(focused ? WorkbenchTokens.Native.accent.opacity(V.requestEditRing) : .clear, lineWidth: 1))
                .padding(-V.requestEditInset)
        }
        .onHover { hovering = $0 }
        .animation(WorkbenchTokens.Spring.hover, value: focused)
        .help(L("Click to edit what you said"))
        .accessibilityLabel(L("Your request"))
    }
}

/// A text field drawn off the screen (`offscreenRender`), where one can't be (it comes out a yellow
/// box): its words, or its prompt as the field shows it.
struct FieldStandIn: View {
    let prompt: String
    let text: String

    var body: some View {
        Text(text.isEmpty ? prompt : text)
            .foregroundStyle(text.isEmpty ? WorkbenchTokens.V2.subColor : WorkbenchTokens.V2.titleColor)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A pulled-out chat's box for asking more, whenever: type, Return (or the arrow) sends it to that
/// session, at work or done, and the window shows it at work on it.
struct V2FollowUpField: View {
    let model: WorkbenchModel
    let id: String
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        let V = WorkbenchTokens.V2.self
        HStack(spacing: V.inputSpacing) {
            // Oct 24: a chat opened from the search takes its first words here, the box ready.
            let prompt = model.isOpenedChat(id) ? L("Ask in this chat") : L("Ask a follow-up")
            Group {
                if model.offscreenRender { FieldStandIn(prompt: prompt, text: text) } else { TextField(prompt, text: $text) }
            }
                .textFieldStyle(.plain)
                .font(V.inputFont)
                .foregroundStyle(V.titleColor)
                .focused($focused)
                .onSubmit(send)
                .onAppear { if model.isOpenedChat(id), !model.snapshotMode { focused = true } }
                // Esc with nothing typed steps out, as it does when the box isn't being typed in.
                .onKeyPress(.escape) { text.isEmpty && model.escape() ? .handled : .ignored }
                .background { if model.isOpenedChat(id), !model.offscreenRender { KeyWindowMaker() } }
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(V.inputSendGlyph)
                    .foregroundStyle(WorkbenchTokens.isNative && text.isEmpty ? WorkbenchTokens.ink(0.35) : WorkbenchTokens.Panel.buttonPrimaryText)
                    .frame(width: V.inputSend, height: V.inputSend)
                    .background(Circle().fill(WorkbenchTokens.isNative
                        ? (text.isEmpty ? WorkbenchTokens.ink(0.12) : WorkbenchTokens.Native.accent)
                        : Color.white.opacity(text.isEmpty ? 0.35 : 1)))
            }
            .buttonStyle(IslandPressStyle())
            .disabled(text.isEmpty)
            .help("Send (Return)")
        }
        .padding(.leading, V.inputPaddingLeading)
        .padding(.trailing, V.inputPaddingTrailing)
        .frame(height: V.inputHeight)
        .background(Capsule(style: .continuous).fill(V.inputFill))
        .overlay(Capsule(style: .continuous).strokeBorder(
            WorkbenchTokens.isNative && focused ? WorkbenchTokens.Native.accent : WorkbenchTokens.ink(focused ? 0.25 : 0.1),
            lineWidth: 0.75))
        .accessibilityLabel("Follow-up")
    }

    private func send() {
        let words = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !words.isEmpty else { return }
        model.askMoreV2(id, text: words, inWindow: true)
        text = ""
    }
}

/// A chat tucked into a side of the screen: a tab with its agent and its state; a click or a pull
/// brings the window back out.
/// Oct 21, Ryan: a tucked tab comes in from its own edge of the screen and goes back out to it.
private struct TuckOffset: ViewModifier {
    let x: CGFloat
    func body(content: Content) -> some View { content.offset(x: x) }
}

extension AnyTransition {
    static func tuck(_ side: V2Detached.Side) -> AnyTransition {
        let away = WorkbenchTokens.V2.tabSize.width + 12
        return AnyTransition.modifier(active: TuckOffset(x: side == .left ? -away : away), identity: TuckOffset(x: 0))
            .combined(with: .opacity)
    }
}

/// Oct 21, Ryan ("simpler is better"): it no longer widens under the pointer; one edge, a light
/// shadow.
struct V2DockedTab: View {
    let model: WorkbenchModel
    let item: V2Detached
    let side: V2Detached.Side

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let size = V.tabSize
        let shape = UnevenRoundedRectangle(cornerRadii: side == .left
            ? .init(topLeading: 0, bottomLeading: 0, bottomTrailing: 12, topTrailing: 12)
            : .init(topLeading: 12, bottomLeading: 12, bottomTrailing: 0, topTrailing: 0), style: .continuous)
        VStack(spacing: 8) {
            if let task = model.v2Task(item.id) {
                ChatAgentIcon(agent: ChatAgent.named(task.agent), size: 18)
                AgentStateGlyph(task: task, size: 11, paused: model.snapshotMode)
            }
        }
        .frame(width: size.width, height: size.height)
        .surface(shape, original: V.detachedFill)
        .overlay { if !WorkbenchTokens.isNative { shape.strokeBorder(V.detachedBorder, lineWidth: 0.75) } }
        .shadow(color: V.tabShadow, radius: V.tabShadowRadius)
        .contentShape(shape)
        .onTapGesture { withAnimation(WorkbenchTokens.V2.resize) { model.undockV2(item.id) } }
        .gesture(DragGesture(minimumDistance: 6).onEnded { _ in withAnimation(WorkbenchTokens.V2.resize) { model.undockV2(item.id) } })
        .help("Pull the chat back out")
        .position(x: side == .left ? size.width / 2 : model.detachedArea.width - size.width / 2,
                  y: item.dockY + size.height / 2)
        .accessibilityLabel("Tucked chat")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.undockV2(item.id) }
    }
}

/// Words typed in as they come, a caret after them; whole when still.
struct V2Typed: View {
    let text: String
    let paused: Bool
    var rate: Double = WorkbenchTokens.V2.typeRate
    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Oct 21, perf: its band is showing (MockIsland's `BandShown`); its clock pauses when not.
    @Environment(\.islandBandShown) private var bandShown

    var body: some View {
        let still = paused || reduceMotion
        TimelineView(.animation(minimumInterval: 1 / 30, paused: still || !bandShown)) { context in
            let t = context.date.timeIntervalSince(start)
            let count = still ? text.count : min(text.count, Int(t * rate))
            let caret = !still && (count < text.count || Int(t / (WorkbenchTokens.V2.caretBlink / 2)) % 2 == 0)
            Text(String(text.prefix(count))) + Text(caret ? "▏" : " ").foregroundColor(.white.opacity(0.8))
        }
        .onChange(of: text) { _, _ in start = Date() }
    }
}

// MARK: The referents the workbench draws

/// The sample requests' referents: a formula from a paper and an email, drawn here (as if
/// circled on the screen), or one of Core's screens.
@MainActor
enum V2Referents {
    private static var cache: [String: (image: NSImage, source: String)] = [:]

    static func image(_ referent: V2Referent) -> (image: NSImage, source: String)? {
        let key: String
        switch referent {
        case .formula: key = "formula"
        case .email: key = "email"
        case .screen(let path, _): key = path
        }
        if let hit = cache[key] { return hit }
        var made: (NSImage, String)?
        switch referent {
        case .formula:
            made = render(V2FormulaSnippet(), size: CGSize(width: 330, height: 64)).map { ($0, "Attention Is All You Need — p. 4") }
        case .email:
            made = render(V2EmailSnippet(), size: CGSize(width: 300, height: 96)).map { ($0, "Mail — Sam Lee") }
        case .screen(let path, let source):
            if let url = FoveaFiles.url(path), let image = NSImage(contentsOf: url) { made = (image, source) }
        }
        guard let made else { return nil }
        cache[key] = made
        return made
    }

    private static func render<V: View>(_ view: V, size: CGSize) -> NSImage? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2
        return renderer.nsImage
    }
}

/// A line of a paper: the attention formula, set as a paper sets it.
struct V2FormulaSnippet: View {
    var body: some View {
        let ink = Color(white: 0.1)
        HStack(spacing: 4) {
            Text("Attention(Q, K, V) = softmax")
            HStack(spacing: 1) {
                Text("(")
                VStack(spacing: 1) {
                    Text("QK") + Text("T").font(.system(size: 10, design: .serif)).baselineOffset(7)
                    Rectangle().fill(ink).frame(width: 40, height: 0.8)
                    Text("√d") + Text("k").font(.system(size: 10, design: .serif)).baselineOffset(-3)
                }
                Text(")")
            }
            Text("V")
        }
        .font(.system(size: 17, design: .serif)).italic()
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.99, green: 0.985, blue: 0.97))
    }
}

/// An email, as the person had it open.
struct V2EmailSnippet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(Color(red: 0.36, green: 0.55, blue: 0.86)).frame(width: 18, height: 18)
                    .overlay(Text("S").font(.system(size: 10, weight: .bold)).foregroundStyle(.white))
                Text("Sam Lee").font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("9:41").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Text("Thursday?").font(.system(size: 12, weight: .semibold))
            Text("Could we meet Thursday at 3 to go over the launch plan? Happy to come to you.")
                .font(.system(size: 11)).foregroundStyle(Color(white: 0.3)).lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }
}

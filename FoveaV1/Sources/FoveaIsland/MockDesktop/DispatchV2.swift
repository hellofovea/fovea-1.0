import SwiftUI
import AppKit
import FoveaCore
import FoveaLook
import FoveaKit

// Dispatch Version 2 in the island (the flow is in WorkbenchModel+DispatchV2.swift): Choose chat
// as Dispatch has it (with the suggested chats beside the pill, and every chat a ⌃ away), the
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
}

/// Choose chat: the request; what was taken, the chat in a pill, the send button; the
/// suggestions as chips; every chat, opened.
struct V2SendLayout: Equatable {
    var outline: StackLayout.Outline
    var text: CGFloat
    var browser: CGFloat

    static func make(request: String, attachments: Int, browsing: Bool, browseRows: Int, sheet: Bool = false,
                     sheetNotes: Int = 0, metrics: ScreenMetrics) -> V2SendLayout {
        let V = WorkbenchTokens.V2.self
        let text = V2Geometry.measure(request, size: V.requestSize, weight: V.requestMeasureWeight, width: V2Geometry.contentWidth,
                                      spacing: V.requestSpacing, lines: 2)
        // As the browser draws it: its top, its rule, the rail, the rows (Compact measured 1 short).
        let browser = browsing ? V2RouteSheet.browserHeight(rows: browseRows) : 0
        // Feedback #1: the model and effort's sheet, under the suggestions (Oct 15 review, QA08/QA09:
        // with the approvals, and a line of notes when a model can't be picked).
        let modelSheet = sheet ? V.gap + V2ModelSheet.height(chats: false, notes: sheetNotes) : 0
        let content = text + V.gap + V.attachRow + V.attachBottom + V.chipRow + browser + modelSheet
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
                    // Feedback #15: the name made from the request; the request's words while it's made.
                    Text(model.v2Title(task))
                        .font(V.titleFont)
                        .foregroundStyle(model.v2Naming.contains(task.id) ? WorkbenchTokens.FeedbackV2.namingColor : V.titleColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .id(model.v2Title(task))
                        .transition(.opacity)
                    V2Badge(text: quick ? L("Quick answer") : task.project)
                }
                V2StateLine(model: model, task: task)
            }
        }
    }
}

// MARK: Choose chat

/// Choose chat, as Dispatch has it: the request; what was taken; the chat in a pill and the send
/// button, its ring emptying (then it goes); the suggestions as chips under; with ⌃ (or the pill),
/// every chat below, by agent and project.
struct V2SendContent: View {
    let model: WorkbenchModel
    let layout: V2SendLayout
    @Namespace private var space

    var body: some View {
        let V = WorkbenchTokens.V2.self
        ZStack(alignment: .topLeading) {
            Color.clear
            VStack(alignment: .leading, spacing: 0) {
                Text(model.v2Spoken)
                    .font(.system(size: V.requestSize, weight: V.requestWeight))
                    .lineSpacing(V.requestSpacing)
                    .foregroundStyle(V.requestColor)
                    .lineLimit(2)
                    .frame(width: V2Geometry.contentWidth, height: layout.text, alignment: .topLeading)
                    .padding(.bottom, V.gap)
                // What was taken, as one stack (feedback #1); the chat; the model; send.
                HStack(spacing: V.attachmentGap) {
                    if !model.liveReferents.isEmpty {
                        V2ReferentPile(model: model, space: space)
                    }
                    Spacer(minLength: V.attachBottom)
                    V2ChatPill(model: model)
                    V2ModelPill(model: model)
                    V2SendButton(model: model)
                }
                .frame(height: V.attachRow)
                .zIndex(5)
                .padding(.bottom, V.attachBottom)
                // The suggestions: one click puts one in the pill. Oct 15 review, QA06/QA10: after
                // Send, where it's going (the chat locked), or why it didn't go, in their place.
                Group {
                    if let sending = model.cases.sending {
                        V2SendStatusRow(model: model, sending: sending)
                    } else {
                        HStack(spacing: V.chipGap) {
                            Text("Suggested").font(V.labelFont).foregroundStyle(V.labelColor)
                                .padding(.trailing, V.labelTrailing)
                            ForEach(model.v2Suggestions) { pick in
                                V2SuggestionChip(model: model, pick: pick, chosen: model.v2Pick == pick)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(height: V.chipRow)
                .animation(WorkbenchTokens.Cases.change, value: model.cases.sending)
                if model.v2Browsing {
                    V2ChatBrowser(model: model)
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
            // A taken thing, looked at closer: it grows from its thumbnail over the window.
            if let id = model.v2Inspecting, let referent = model.liveReferents.first(where: { $0.id == id }) {
                V2AttachmentInspect(model: model, referent: referent, layout: layout, space: space)
            }
        }
        .frame(width: layout.outline.size.width, height: layout.outline.size.height, alignment: .topLeading)
        .animation(WorkbenchTokens.V2.resize, value: model.v2Browsing)
        .animation(WorkbenchTokens.V2.resize, value: model.v2ModelSheet)
        .panelScheme()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Choose chat")
    }
}

/// The chat the request goes to, as Dispatch's pill: the agent, the chat, a chevron that opens
/// every chat.
struct V2ChatPill: View {
    let model: WorkbenchModel
    @State private var hovering = false

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let C = WorkbenchTokens.Chat.self
        let pick = model.v2Pick
        // Oct 15 review, QA06: while it's sending, the chat is locked.
        let locked = model.cases.sending?.isSending == true
        Button { model.toggleV2Browse() } label: {
            HStack(spacing: 8) {
                ChatAgentIcon(agent: ChatAgent.named(pick.agent), size: V.pillIcon)
                Text(pick.title)
                    .font(V.pillFont)
                    .foregroundStyle(V.titleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: locked ? "lock.fill" : (model.v2Browsing ? "chevron.up" : "chevron.down"))
                    .font(V.pillChevron)
                    .foregroundStyle(V.subColor)
            }
            .padding(.horizontal, V.pillPaddingH)
            .frame(height: V.pillHeight)
            .frame(maxWidth: WorkbenchTokens.FeedbackV2.chatPillMax)
            .fixedSize(horizontal: true, vertical: false)
            .background(Capsule(style: .continuous).fill(hovering ? C.pillFillHover : C.pillFill))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .onHover { hovering = $0 }
        .help(locked ? "Sending to \(pick.title)" : "\(ChatAgent.named(pick.agent).name) · \(pick.project ?? L("Quick answer")). Every chat: ⌃")
        .accessibilityLabel("Sends to \(pick.title)")
        .accessibilityHint("Shows every chat")
    }
}

/// Send: a white disc with an arrow. Nothing sends until it is pressed (or fn⌃, or Return).
struct V2SendButton: View {
    let model: WorkbenchModel
    @State private var hovering = false

    var body: some View {
        let V = WorkbenchTokens.V2.self
        // Oct 15 review, QA06: on its way, the disc turns; not sent or declined, it waits.
        let sending = model.cases.sending
        Button { model.sendV2Now() } label: {
            ZStack {
                Circle().fill(WorkbenchTokens.Panel.buttonPrimary.opacity(sending != nil ? 0.45 : (hovering ? V.sendHoverOpacity : 1)))
                if sending?.isSending == true {
                    ProgressView().controlSize(.small).tint(WorkbenchTokens.Panel.buttonPrimaryText)
                } else {
                    Image(systemName: "arrow.up").font(V.sendGlyph).foregroundStyle(WorkbenchTokens.Panel.buttonPrimaryText)
                }
            }
            .frame(width: V.sendSize, height: V.sendSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(sending != nil)
        .onHover { hovering = $0 }
        .help("Send (fn⌃, Return)")
        .accessibilityLabel("Send")
    }
}

/// A suggested chat as a chip: its agent and name; the one in the pill marked.
struct V2SuggestionChip: View {
    let model: WorkbenchModel
    let pick: V2Suggestion
    let chosen: Bool
    @State private var hovering = false

    var body: some View {
        let V = WorkbenchTokens.V2.self
        Button { model.chooseV2(pick) } label: {
            HStack(spacing: 6) {
                ChatAgentIcon(agent: ChatAgent.named(pick.agent), size: V.chipIcon)
                Text(pick.title).font(V.chipFont).foregroundStyle(chosen ? V.titleColor : V.chipText).lineLimit(1)
            }
            .padding(.horizontal, V.chipPaddingH)
            .frame(height: V.chipHeight)
            .background(Capsule(style: .continuous).fill(chosen ? V.chipChosenFill : (hovering ? V.hoverFill : V.chipFill)))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("\(ChatAgent.named(pick.agent).name)\(pick.project.map { " · \($0)" } ?? "") · \(pick.reason)")
        .accessibilityLabel("\(pick.title), \(pick.reason)")
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}

/// A taken thing in Choose chat: a screenshot, a passage, a file, as its card; it lifts under the
/// pointer and opens larger on a click.
struct V2AttachmentThumb: View {
    let model: WorkbenchModel
    let referent: CapturedReferent
    let space: Namespace.ID
    @State private var hovering = false

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
            .matchedGeometryEffect(id: referent.id, in: space, isSource: model.v2Inspecting != referent.id)
            .opacity(model.v2Inspecting == referent.id ? 0 : 1)
            .scaleEffect(hovering ? WorkbenchTokens.Referents.hoverScale : 1)
            .animation(model.cardMotion.hover, value: hovering)
            .onHover { hovering = $0 }
            .onTapGesture {
                withAnimation(model.cardMotion.fan) { model.v2Inspecting = referent.id }
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
    let space: Namespace.ID

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
                    .matchedGeometryEffect(id: referent.id, in: space, isSource: true)
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
        withAnimation(model.cardMotion.fan) { model.v2Inspecting = nil }
    }
}

/// Every chat, as Dispatch's expanded view has them: the agents' icons in a rail (the active one in
/// a pill, its name at the right), then its projects, then a project's chats (a New chat first).
/// A chat goes into the pill.
struct V2ChatBrowser: View {
    let model: WorkbenchModel

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let active = ChatAgent.named(model.v2BrowseAgent)
        VStack(alignment: .leading, spacing: V.browseSpacing) {
            Rectangle().fill(V.rule).frame(height: 1)
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
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(model.v2BrowseRows) { row in
                        V2BrowseRowView(model: model, row: row)
                            .frame(height: V.browseRow)
                    }
                }
            }
            .scrollIndicators(.automatic)
        }
        .padding(.top, V.gap - V.browseSpacing)
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
                case .project(let project):
                    Text(project.folder).font(V.browseFont).foregroundStyle(V.titleColor)
                    if project.folder == ChatBook.project {
                        Text("this project").font(V.reasonFont).foregroundStyle(V.subColor)
                    }
                    Spacer(minLength: 6)
                    if project.needsYou {
                        Text("Needs you").font(V.reasonFont).foregroundStyle(WorkbenchTokens.Panel.needsYouColor)
                    }
                    Text(project.latest?.age ?? "").font(V.reasonFont).foregroundStyle(V.subColor).monospacedDigit()
                    Image(systemName: "chevron.right").font(V.browseChevron).foregroundStyle(V.subColor)
                case .back(let folder):
                    Image(systemName: "chevron.left").font(V.browseBack).foregroundStyle(V.subColor)
                    Text(folder).font(V.browseFont).foregroundStyle(V.subColor)
                    Spacer()
                case .chat(let chat):
                    // Oct 15 review, QA05: one that can't take the request is dimmed and says why.
                    let blocked = model.v2ChatBlock(chat)
                    Image(systemName: chat.isNew ? "plus" : "bubble.left").font(V.browseGlyph).foregroundStyle(V.subColor).frame(width: 14)
                    Text(chat.title).font(V.browseFont)
                        .foregroundStyle(blocked == nil ? V.titleColor : WorkbenchTokens.Cases.blockedTitle).lineLimit(1)
                    // A search spans projects: each chat says which.
                    if !model.cases.browseQuery.isEmpty {
                        Text(chat.folder).font(V.reasonFont).foregroundStyle(V.subColor).lineLimit(1)
                    }
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

    var body: some View {
        let size = V2DetachedLayout.size
        let area = chats ? model.detachedArea : model.display.frame.size
        ZStack(alignment: .topLeading) {
            if chats {
                ForEach(model.v2Detached) { item in
                    if let side = item.docked {
                        V2DockedTab(model: model, item: item, side: side)
                    } else {
                        // At its own size, its top-left where it is.
                        V2DetachedWindow(model: model, item: item)
                            .frame(width: item.size.width, height: item.size.height)
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
/// more, and a corner that resizes it (a pinch does too): the window changes, never its words.
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
        // Native: a glass panel, as macOS's popover dragged off into a panel.
        .surface(shape, original: V.detachedFill)
        .overlay(shape.strokeBorder(V.detachedBorder, lineWidth: 0.75))
        .overlay(alignment: .bottomTrailing) {
            if !ghost { V2ScaleGrip(model: model, item: item) }
        }
        .clipShape(shape)
        .shadow(color: .black.opacity(0.45), radius: 22, y: 10)
        .simultaneousGesture(pinch)
        .opacity(ghost ? 0.92 : 1)
        .panelScheme()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pulled-out chat")
    }

    /// A pinch on the trackpad resizes the window, as its corner does; the words keep their size.
    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = pinchStart ?? item.size
                if pinchStart == nil { pinchStart = item.size }
                model.resizeDetachedV2(item.id, to: CGSize(width: start.width * value.magnification,
                                                           height: start.height * value.magnification))
            }
            .onEnded { _ in pinchStart = nil }
    }

    /// Dragging the header moves the window; let go with the pointer at a side, it tucks in.
    private var move: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(ScreenSpace.name))
            .onChanged { value in
                let start = dragStart ?? item.origin
                if dragStart == nil { dragStart = item.origin }
                model.moveDetachedV2(item.id, to: CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height))
            }
            .onEnded { value in
                dragStart = nil
                model.endMoveDetachedV2(item.id, pointer: value.location)
            }
    }
}

/// The bottom-right corner of a pulled-out chat: dragged out, the window grows; in, it shrinks.
/// The window resizes, its top-left where it is; its words keep their size and reflow (Oct 11).
struct V2ScaleGrip: View {
    let model: WorkbenchModel
    let item: V2Detached
    @State private var start: CGSize?

    var body: some View {
        let V = WorkbenchTokens.V2.self
        Canvas { context, size in
            var lines = Path()
            for inset in [4.0, 8.5] {
                lines.move(to: CGPoint(x: size.width - 3, y: inset))
                lines.addLine(to: CGPoint(x: inset, y: size.height - 3))
            }
            context.stroke(lines, with: .color(V.scaleGripColor), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
        .frame(width: V.scaleGrip, height: V.scaleGrip)
        .padding(2)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .named(ScreenSpace.name))
                .onChanged { value in
                    // The corner follows the pointer: the window grows by the pointer's travel.
                    let from = start ?? item.size
                    if start == nil { start = item.size }
                    model.resizeDetachedV2(item.id, to: CGSize(width: from.width + value.translation.width,
                                                               height: from.height + value.translation.height))
                }
                .onEnded { _ in start = nil }
        )
        .help("Drag to make it bigger or smaller (or pinch)")
        .accessibilityElement()
        .accessibilityLabel("Size")
        .accessibilityValue("\(Int(item.size.width)) by \(Int(item.size.height)) points")
        .accessibilityAdjustableAction { direction in
            let step: CGFloat = direction == .increment ? 40 : -40
            model.resizeDetachedV2(item.id, to: CGSize(width: item.size.width + step, height: item.size.height + step))
        }
    }
}

/// A pulled-out chat's conversation: each exchange as a question and what came back, the one now
/// with the agent's screen. With follow-ups, a rail at the right (after Notion's outline) shows
/// which exchange is in view and, on hover, lists them all to jump to.
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
                            if turn.id > 0 { Rectangle().fill(V.rule).frame(width: column, height: 0.5) }
                            if turn.id == now {
                                // Oct 15 review, QA07: the last request, editable once answered.
                                V2EditableQuestion(model: model, task: task, lines: 3) {
                                    Text(turn.question)
                                        .font(V.turnQuestion).foregroundStyle(V.bodyColor)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(width: column, alignment: .leading)
                                }
                            } else {
                                Text(turn.question)
                                    .font(V.turnQuestion).foregroundStyle(V.bodyColor)
                                    .fixedSize(horizontal: false, vertical: true)
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
                                MarkdownView(markdown: answer, width: column)
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
                        withAnimation(V.resize) { proxy.scrollTo(id, anchor: .top) }
                    }
                }
            }
            // A new question: it comes into view.
            .onChange(of: turns.count) { _, _ in
                withAnimation(V.resize) { proxy.scrollTo(now, anchor: .top) }
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
                .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topTrailing)))
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
            TextField("Ask a follow-up", text: $text)
                .textFieldStyle(.plain)
                .font(V.inputFont)
                .foregroundStyle(V.titleColor)
                .focused($focused)
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(V.inputSendGlyph)
                    .foregroundStyle(WorkbenchTokens.isNative && text.isEmpty ? WorkbenchTokens.ink(0.35) : WorkbenchTokens.Panel.buttonPrimaryText)
                    .frame(width: V.inputSend, height: V.inputSend)
                    .background(Circle().fill(WorkbenchTokens.isNative
                        ? (text.isEmpty ? WorkbenchTokens.ink(0.12) : WorkbenchTokens.Native.accent)
                        : Color.white.opacity(text.isEmpty ? 0.35 : 1)))
            }
            .buttonStyle(.plain)
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
struct V2DockedTab: View {
    let model: WorkbenchModel
    let item: V2Detached
    let side: V2Detached.Side
    @State private var hovering = false

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
        .frame(width: size.width + (hovering ? 6 : 0), height: size.height)
        .surface(shape, original: V.detachedFill)
        .overlay(shape.strokeBorder(V.detachedBorder, lineWidth: 0.75))
        .shadow(color: .black.opacity(0.35), radius: 10)
        .contentShape(shape)
        .onHover { hovering = $0 }
        .animation(WorkbenchTokens.Chat.hover, value: hovering)
        .onTapGesture { withAnimation(WorkbenchTokens.V2.resize) { model.undockV2(item.id) } }
        .gesture(DragGesture(minimumDistance: 6).onEnded { _ in withAnimation(WorkbenchTokens.V2.resize) { model.undockV2(item.id) } })
        .help("Pull the chat back out")
        .position(x: side == .left ? (size.width + (hovering ? 6 : 0)) / 2
                                   : model.detachedArea.width - (size.width + (hovering ? 6 : 0)) / 2,
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

    var body: some View {
        let still = paused || reduceMotion
        TimelineView(.animation(minimumInterval: 1 / 30, paused: still)) { context in
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

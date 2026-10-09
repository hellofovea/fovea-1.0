import SwiftUI
import AppKit
import FoveaCore
import FoveaKit

// Choose chat in the island (the states are in WorkbenchModel+Chat.swift): the request's words
// and referents, then one row after the PRD, the referents at the left and the chat pill and
// Send at the right; under it, when something stands between the request and its chat, one
// notice line with what can be done (and, when Fovea isn't sure, its guesses). Opened, a
// hairline, a rail of the agents and the active one's projects; a project opens to its chats (a
// New chat first), scrolling, under a row back to the projects. Geometry is pure (`ChatLayout`),
// so the outline, the views and the checks share one answer. docs/island/CHOOSE_CHAT.md has the
// reasons.

/// Where Choose chat's parts go. Coordinates are from the island's top-left corner.
struct ChatLayout: Equatable {
    /// A row: a project, the row back, a note, or one of Fovea's guesses.
    struct Row: Equatable {
        let id: String
        let frame: CGRect
    }

    /// An agent's cell on the rail.
    struct Cell: Equatable {
        let agent: String
        let frame: CGRect
    }

    var outline: StackLayout.Outline
    var level: ChatLevel
    var textRect: CGRect
    var thumbs: [CGRect]
    var pill: CGRect
    var send: CGRect
    /// The notice under the row, its words and its buttons; and Fovea's guesses under it.
    var notice: CGRect?
    var noticeText: CGRect?
    var noticeActions: CGRect?
    var guesses: [Row]
    var hairline: CGRect
    /// The agents' cells, in order, and the room after them, where the active agent's name sits
    /// at the right.
    var cells: [Cell]
    var railName: CGRect
    /// The projects (or the row back, on the chats level); a project's chats scroll in `scroll`.
    var rows: [Row]
    var scroll: CGRect

    /// The note shown for an agent Fovea isn't set up for, and while an agent's chats load.
    nonisolated static let offlineRow = "offline"
    nonisolated static let loadingRow = "loading"

    /// The request and its row, and the list, keep this width.
    static var contentWidth: CGFloat {
        WorkbenchTokens.Chat.width - 2 * WorkbenchTokens.Island.spec.expandedTopRadius - 2 * WorkbenchTokens.Chat.paddingH
    }

    /// The notice's words' width: after its glyph.
    static var noticeTextWidth: CGFloat { contentWidth - WorkbenchTokens.Chat.noticeGlyphWidth }

    /// How tall a notice's words are, at most its lines.
    static func noticeHeight(_ text: String) -> CGFloat {
        let C = WorkbenchTokens.Chat.self
        let style = NSMutableParagraphStyle()
        style.lineSpacing = C.noticeLineSpacing
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: noticeTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: NSFont.systemFont(ofSize: C.noticeFontSize), .paragraphStyle: style])
        return min(ceil(rect.height), C.noticeMaxHeight)
    }

    static func make(level: ChatLevel, textHeight: CGFloat, referents: Int, notice: ChatNotice?, guesses: [String],
                     agents: [ChatAgent], projects: [ChatProject], items: [AgentChat], offline: Bool, loading: Bool,
                     metrics: ScreenMetrics) -> ChatLayout {
        let C = WorkbenchTokens.Chat.self
        let spec = WorkbenchTokens.Island.spec
        let notch = NotchGeometry.notchRect(metrics: metrics, spec: spec)
        let width = C.width
        let contentWidth = Self.contentWidth
        let x0 = (width - contentWidth) / 2
        let text = CGRect(x: x0, y: notch.height + C.paddingTop, width: contentWidth, height: textHeight)
        let rowTop = text.maxY + C.rowGap
        let rowMid = rowTop + C.rowHeight / 2
        let send = CGRect(x: x0 + contentWidth - C.sendSize, y: rowMid - C.sendSize / 2, width: C.sendSize, height: C.sendSize)
        let pill = CGRect(x: send.minX - C.sendGap - C.pillWidth, y: rowMid - C.pillHeight / 2,
                          width: C.pillWidth, height: C.pillHeight)
        // The referents wrap in rows before the pill; never "+N" (AMENDMENTS).
        let room = pill.minX - C.rowGap - x0
        let perRow = max(1, Int((room + C.thumbGap) / (C.thumb.width + C.thumbGap)))
        let thumbs = (0..<referents).map { i in
            CGRect(x: x0 + CGFloat(i % perRow) * (C.thumb.width + C.thumbGap),
                   y: rowMid - C.thumb.height / 2 + CGFloat(i / perRow) * (C.thumb.height + C.thumbGap),
                   width: C.thumb.width, height: C.thumb.height)
        }
        var bottom = max(rowTop + C.rowHeight, thumbs.map(\.maxY).max() ?? 0)
        // The notice: its words (a line or two) after a glyph, its buttons under them at the right.
        var noticeRect: CGRect?, noticeText: CGRect?, noticeActions: CGRect?
        if let notice {
            let top = bottom + C.noticeGap
            let words = CGRect(x: x0 + C.noticeGlyphWidth, y: top, width: Self.noticeTextWidth, height: noticeHeight(notice.text))
            noticeText = words
            var end = words.maxY
            if !notice.actions.isEmpty {
                noticeActions = CGRect(x: x0, y: end + C.noticeActionsGap, width: contentWidth, height: C.noticeButtonHeight)
                end = noticeActions!.maxY
            }
            noticeRect = CGRect(x: x0, y: top, width: contentWidth, height: end - top)
            bottom = end
        }
        // Fovea's guesses, when it isn't sure: one row each.
        var guessRows: [Row] = []
        if !guesses.isEmpty {
            bottom += C.guessGap
            for id in guesses {
                guessRows.append(Row(id: id, frame: CGRect(x: x0, y: bottom, width: contentWidth, height: C.chatRow)))
                bottom += C.chatRow
            }
        }
        // The rail: one cell per agent, the active agent's name after them.
        let hairlineY = bottom + C.listGap
        let railTop = hairlineY + 1 + C.listGap
        let cells = agents.enumerated().map { i, agent in
            Cell(agent: agent.id, frame: CGRect(x: x0 + CGFloat(i) * (C.railCell.width + C.railSpacing),
                                                y: railTop + (C.railHeight - C.railCell.height) / 2,
                                                width: C.railCell.width, height: C.railCell.height))
        }
        let nameLeft = x0 + CGFloat(agents.count) * (C.railCell.width + C.railSpacing) + C.railNameGap
        let railName = CGRect(x: nameLeft, y: railTop, width: x0 + contentWidth - nameLeft, height: C.railHeight)
        // Under it the projects; on the chats level, the row back and the project's chats.
        let listTop = railTop + C.railHeight + C.railGap
        var rows: [Row] = []
        var scroll = CGRect(x: x0, y: listTop, width: contentWidth, height: 0)
        var listBottom = listTop
        func row(_ id: String, height: CGFloat = C.chatRow) {
            rows.append(Row(id: id, frame: CGRect(x: x0, y: listBottom, width: contentWidth, height: height)))
            listBottom += height
        }
        switch level {
        case .closed, .projects:
            if offline {
                row(Self.offlineRow, height: C.offlineHeight)
            } else if loading {
                row(Self.loadingRow)
            } else {
                for project in projects { row(WorkbenchModel.projectPrefix + project.folder) }
            }
        case .chats:
            row(WorkbenchModel.backRow)
            scroll.origin.y = listBottom
            scroll.size.height = CGFloat(min(max(items.count, 1), C.projectRows)) * C.chatRow
            listBottom = scroll.maxY
        }
        let height = level == .closed ? bottom + C.paddingBottom : listBottom + C.paddingBottom
        return ChatLayout(
            outline: StackLayout.Outline(size: CGSize(width: width, height: height),
                                         topRadius: spec.expandedTopRadius, bottomRadius: spec.expandedBottomRadius),
            level: level, textRect: text, thumbs: thumbs, pill: pill, send: send,
            notice: noticeRect, noticeText: noticeText, noticeActions: noticeActions, guesses: guessRows,
            hairline: CGRect(x: x0, y: hairlineY, width: contentWidth, height: 1),
            cells: cells, railName: railName, rows: rows, scroll: scroll)
    }
}

/// Choose chat's content in the island.
struct ChooseChatContent: View {
    let model: WorkbenchModel
    let layout: ChatLayout

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        let open = layout.level != .closed
        ZStack(alignment: .topLeading) {
            Color.clear
            ChatRequestText(model: model)
                .frame(width: layout.textRect.width, height: layout.textRect.height, alignment: .topLeading)
                .position(x: layout.textRect.midX, y: layout.textRect.midY)
            ForEach(Array(zip(model.liveReferents, layout.thumbs)), id: \.0.id) { referent, frame in
                Group {
                    if referent.id == model.chatMissingReferent {
                        ChatMissingThumb()
                    } else {
                        ChatThumb(referent: referent)
                    }
                }
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
            }
            ChatPill(model: model, open: open)
                .frame(width: layout.pill.width, height: layout.pill.height)
                .position(x: layout.pill.midX, y: layout.pill.midY)
            ChatSendButton(enabled: model.canSend, sending: model.chatSend == .sending, reason: model.sendReason) { model.sendChat() }
                .position(x: layout.send.midX, y: layout.send.midY)
            if let notice = model.chatNotice, let words = layout.noticeText {
                ChatNoticeView(model: model, notice: notice, words: words, actions: layout.noticeActions)
                    .transition(.opacity)
            }
            ForEach(Array(layout.guesses.enumerated()), id: \.offset) { _, row in
                if let chat = model.chat(row.id) {
                    ChatGuessRow(model: model, chat: chat, highlighted: model.chatHighlight == row.id)
                        .frame(width: row.frame.width, height: row.frame.height)
                        .position(x: row.frame.midX, y: row.frame.midY)
                }
            }
            Group {
                Rectangle()
                    .fill(C.hairline)
                    .frame(width: layout.hairline.width, height: layout.hairline.height)
                    .position(x: layout.hairline.midX, y: layout.hairline.midY)
                ChatRail(model: model, layout: layout)
            }
            .opacity(open ? 1 : 0)
            .animation(open ? C.listIn : C.listOut, value: open)
            .allowsHitTesting(open)
            .accessibilityHidden(!open)
        }
        .frame(width: layout.outline.size.width, height: layout.outline.size.height, alignment: .topLeading)
        .animation(model.islandAnimation, value: layout)
        .animation(C.nameSwap, value: model.chatNotice)
        // White on black, whatever the display's appearance.
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Choose chat")
    }
}

/// The request's words: three lines at most, scrolling in them when longer (as fovea-mac's
/// question area does), or a quiet line when the screenshots go on their own.
struct ChatRequestText: View {
    let model: WorkbenchModel

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        let text = model.requestText
        if text.isEmpty {
            Text("No words: the screenshots go on their own.")
                .font(C.text)
                .italic()
                .foregroundStyle(C.requestPlaceholder)
                .lineLimit(1)
        } else if model.chatLinesHeight > 0, model.chatTextHeight > model.chatLinesHeight + 0.5 {
            ScrollView {
                styled(Text(text))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.automatic)
        } else {
            styled(Text(text))
                .lineLimit(C.lines)
                .truncationMode(.tail)
        }
    }

    private func styled(_ text: Text) -> some View {
        let C = WorkbenchTokens.Chat.self
        return text.font(C.text).lineSpacing(C.lineSpacing).foregroundStyle(C.textColor)
    }
}

/// A referent, as the review's stack shows one: the capture filling a small rounded card.
struct ChatThumb: View {
    let referent: CapturedReferent

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        let shape = RoundedRectangle(cornerRadius: C.thumbRadius, style: .continuous)
        Image(nsImage: referent.image)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: C.thumb.width, height: C.thumb.height)
            .clipShape(shape)
            .overlay(shape.strokeBorder(C.thumbBorder, lineWidth: C.thumbBorderWidth))
            .help(referent.source)
            .accessibilityLabel("Screenshot from \(referent.source)")
    }
}

/// A referent that couldn't be read (fovea-mac's "attachment unavailable"): its place kept, a
/// glyph instead of the picture; it won't be sent.
struct ChatMissingThumb: View {
    var body: some View {
        let C = WorkbenchTokens.Chat.self
        let shape = RoundedRectangle(cornerRadius: C.thumbRadius, style: .continuous)
        shape.fill(C.missingFill)
            .overlay(shape.strokeBorder(C.thumbBorder, lineWidth: C.thumbBorderWidth))
            .overlay(Image(systemName: "exclamationmark.triangle").font(C.missingGlyph).foregroundStyle(C.missingColor))
            .frame(width: C.thumb.width, height: C.thumb.height)
            .help("This screenshot couldn't be read, so it won't be sent")
            .accessibilityLabel("Screenshot that couldn't be read; it won't be sent")
    }
}

/// An agent's icon: its own app's artwork, as macOS shows it, never tinted (Resources/Agents).
struct ChatAgentIcon: View {
    let agent: ChatAgent
    let size: CGFloat

    var body: some View {
        Group {
            if let image = Self.image(agent.id) {
                Image(nsImage: image).resizable().interpolation(.high)
            } else {
                Image(systemName: agent.symbol).resizable().scaledToFit().foregroundStyle(.white)
                    .padding(size * 0.12)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(agent.name)
    }

    @MainActor private static var cache: [String: NSImage] = [:]

    @MainActor static func image(_ id: String) -> NSImage? {
        if let image = cache[id] { return image }
        guard let url = FoveaFiles.island("Agents/\(id).png"),
              let image = NSImage(contentsOf: url) else { return nil }
        cache[id] = image
        return image
    }
}

/// The chat Fovea picked: its agent's icon, its name (or "New chat · project"), a chevron, at a
/// fixed width. Until routing answers it breathes "Choosing chat" (PRD §11). With no chat (Fovea
/// isn't sure, routing failed, the pick was closed) it says "Choose a chat" with the notice's
/// glyph; a pick waiting on the person says so in amber.
struct ChatPill: View {
    let model: WorkbenchModel
    let open: Bool
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        let chat = model.chosen
        let agent = ChatAgent.named(chat?.agent ?? ChatBook.predictedAgent)
        let routed = model.chatRouted
        let still = routed || model.snapshotMode || reduceMotion
        let shape = RoundedRectangle(cornerRadius: C.pillRadius, style: .continuous)
        Button { model.setChatLevel(open ? .closed : .projects) } label: {
            HStack(spacing: C.pillSpacing) {
                ZStack {
                    TimelineView(.animation(minimumInterval: 1 / 30, paused: still)) { context in
                        Circle()
                            .fill(C.placeholderFill)
                            .opacity(routed ? 0 : breath(context.date))
                    }
                    if routed, chat == nil {
                        ChatNoticeGlyph(tone: model.chatNotice?.tone ?? .info, unsure: model.chatUnsure)
                    } else {
                        ChatAgentIcon(agent: agent, size: C.icon)
                            .opacity(routed ? 1 : 0)
                            .id(agent.id)
                    }
                }
                .frame(width: C.icon, height: C.icon)
                ZStack(alignment: .leading) {
                    TimelineView(.animation(minimumInterval: 1 / 30, paused: still)) { context in
                        Text("Choosing chat")
                            .foregroundStyle(C.pillPlaceholder)
                            .opacity(routed ? 0 : breath(context.date))
                    }
                    Text(title(chat))
                        .foregroundStyle(chat == nil ? C.pillPlaceholderStrong : C.pillText)
                        .opacity(routed ? 1 : 0)
                        .id(chat?.id ?? "none")
                        .transition(.opacity)
                }
                .font(C.pillFont)
                .lineLimit(1)
                .truncationMode(.tail)
                Spacer(minLength: 4)
                if chat?.state == .needsYou {
                    Text("Needs you")
                        .font(C.statusFont)
                        .foregroundStyle(C.needsYouColor)
                        .fixedSize()
                }
                Image(systemName: "chevron.down")
                    .font(C.pillChevron)
                    .foregroundStyle(C.pillChevronColor)
                    .rotationEffect(.degrees(open ? 180 : 0))
                    .animation(reduceMotion ? nil : (open ? C.expand : C.collapse), value: open)
            }
            .padding(.horizontal, C.pillPaddingH)
            .frame(width: C.pillWidth, height: C.pillHeight)
            .background(shape.fill(hovering || open ? C.pillFillHover : C.pillFill))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(C.hover, value: hovering)
        .animation(C.nameSwap, value: routed)
        .animation(C.nameSwap, value: chat?.id)
        .help(help(chat, agent: agent))
        .accessibilityLabel(!routed ? "Choosing chat" : chat == nil ? "Choose a chat" : "Send to \(title(chat)) in \(agent.name)")
        .accessibilityHint("Shows the chats by agent and project")
    }

    private func title(_ chat: AgentChat?) -> String {
        guard let chat else { return "Choose a chat" }
        if chat.isNew { return "New chat · \(chat.folder)" }
        return model.chatTerminal && chat.id == ChatBook.predicted ? "\(chat.title) · Terminal" : chat.title
    }

    private func help(_ chat: AgentChat?, agent: ChatAgent) -> String {
        guard let chat else { return "No chat yet: pick one of Fovea's guesses, or click, ↓ or ⌃ for all the chats." }
        let own = chat.id == model.predictedPick ? "Fovea's pick: " : ""
        if chat.isNew { return "\(own)a New chat in \(agent.name), in \(chat.folder). Click, ↓ or ⌃ for the other chats." }
        return "\(own)\(agent.name), \(ChatRowMeta.detail(chat)). Click, ↓ or ⌃ for the other chats."
    }

    /// The placeholder's breath: full, then down to the PRD's 0.45, every 0.9 s.
    private func breath(_ date: Date) -> Double {
        let C = WorkbenchTokens.Chat.self
        guard !model.snapshotMode, !reduceMotion else { return 1 }
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2 * C.breathe) / C.breathe
        let wave = (1 - cos(phase * .pi)) / 2
        return 1 - (1 - C.breatheLow) * wave
    }
}

/// The notice's glyph, by its tone: a question when Fovea isn't sure, information, the Island's
/// Needs you amber, or its Failed red.
struct ChatNoticeGlyph: View {
    let tone: ChatNotice.Tone
    var unsure = false

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        Image(systemName: unsure ? "questionmark.circle.fill" : tone == .info ? "info.circle.fill" : "exclamationmark.circle.fill")
            .font(C.noticeGlyph)
            .foregroundStyle(tone == .failed ? C.failedColor : tone == .attention ? C.needsYouColor : C.noticeInfoColor)
            .accessibilityHidden(true)
    }
}

/// One line under the row: what stands between the request and its chat, and its buttons at the
/// right under it.
struct ChatNoticeView: View {
    let model: WorkbenchModel
    let notice: ChatNotice
    let words: CGRect
    let actions: CGRect?

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        ZStack(alignment: .topLeading) {
            ChatNoticeGlyph(tone: notice.tone, unsure: model.chatUnsure && model.chosen == nil)
                .frame(width: C.noticeGlyphWidth, height: C.noticeLineHeight, alignment: .leading)
                .position(x: words.minX - C.noticeGlyphWidth / 2, y: words.minY + C.noticeLineHeight / 2)
            Text(notice.text)
                .font(C.noticeFont)
                .lineSpacing(C.noticeLineSpacing)
                .foregroundStyle(C.noticeColor)
                .lineLimit(2)
                .frame(width: words.width, height: words.height, alignment: .topLeading)
                .position(x: words.midX, y: words.midY)
            if let actions, !notice.actions.isEmpty {
                HStack(spacing: C.noticeButtonGap) {
                    Spacer(minLength: 0)
                    ForEach(Array(notice.actions.enumerated()), id: \.offset) { i, action in
                        ChatNoticeButton(title: action.title, primary: i == 0) { model.perform(action) }
                    }
                }
                .frame(width: actions.width, height: actions.height)
                .position(x: actions.midX, y: actions.midY)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(notice.text)
    }
}

/// A notice's button: the island's gray capsule (Copy's), white words; the first a step brighter.
struct ChatNoticeButton: View {
    let title: String
    let primary: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        Button(action: action) {
            Text(title)
                .font(C.noticeButtonFont)
                .foregroundStyle(primary ? C.noticeButtonText : C.noticeButtonTextQuiet)
                .padding(.horizontal, C.noticeButtonPaddingH)
                .frame(height: C.noticeButtonHeight)
                .background(Capsule(style: .continuous).fill(hovering ? C.noticeButtonFillHover : C.noticeButtonFill))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(C.hover, value: hovering)
    }
}

/// One of Fovea's guesses, when it isn't sure: the agent's icon, the chat's title, where it is.
/// A click (or Return on the highlight) chooses it.
struct ChatGuessRow: View {
    let model: WorkbenchModel
    let chat: AgentChat
    let highlighted: Bool

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        let agent = ChatAgent.named(chat.agent)
        HStack(spacing: C.guessSpacing) {
            if chat.isNew {
                Image(systemName: "plus")
                    .font(C.checkGlyph)
                    .foregroundStyle(C.newChatColor)
                    .frame(width: C.icon, height: C.icon)
            } else {
                ChatAgentIcon(agent: agent, size: C.icon)
            }
            Text(chat.isNew ? "New chat" : chat.title)
                .font(C.chatFont)
                .foregroundStyle(chat.isNew ? C.newChatColor : C.chatColor)
                .lineLimit(1)
            Spacer(minLength: C.metaGap)
            Text(chat.isNew ? "\(agent.name) · \(chat.folder)" : "\(chat.folder) · \(chat.age)")
                .font(C.metaFont)
                .foregroundStyle(C.metaColor)
                .fixedSize()
        }
        .padding(.horizontal, C.rowPaddingH)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChatHighlight(on: highlighted))
        .contentShape(Rectangle())
        .onHover { if $0 { model.hoverHighlight(chat.id) } }
        .onTapGesture { model.choose(chat.id) }
        .help(ChatRowMeta.help(chat))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(chat.isNew ? "New chat in \(chat.folder)" : "\(chat.title), \(agent.name), \(chat.folder)")
    }
}

/// Send: a small white disc with a black arrow; dimmed, with its reason, while there is no chat
/// that can take the request; a spinner while it goes.
struct ChatSendButton: View {
    let enabled: Bool
    let sending: Bool
    let reason: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        Button(action: action) {
            ZStack {
                Circle().fill(!enabled ? C.sendDisabledFill : (hovering ? C.sendFillHover : C.sendFill))
                if sending {
                    ProgressView().controlSize(.mini).tint(.white)
                } else {
                    Image(systemName: "arrow.up")
                        .font(C.sendGlyph)
                        .foregroundStyle(enabled ? C.sendGlyphColor : C.sendDisabledGlyph)
                }
            }
            .frame(width: C.sendSize, height: C.sendSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering = $0 }
        .animation(C.hover, value: hovering)
        .animation(C.nameSwap, value: enabled)
        .help(reason)
        .accessibilityLabel(sending ? "Sending" : "Send")
        .accessibilityHint(enabled ? "" : reason)
    }
}

/// The rail and what it opens to: the agents' icons, the active one on a tab that slides between
/// them; under it the active agent's projects, or one project's chats under a row back.
struct ChatRail: View {
    let model: WorkbenchModel
    let layout: ChatLayout
    @State private var hoveredAgent: String?
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        let active = model.chatAgent
        let increased = contrast == .increased
        let tab = RoundedRectangle(cornerRadius: C.tabRadius, style: .continuous)
        let chosenAgent = model.chosen?.agent
        ZStack(alignment: .topLeading) {
            Color.clear
            // A fainter tab under the pointer on another agent.
            if let hovered = hoveredAgent, hovered != active, let cell = layout.cells.first(where: { $0.agent == hovered })?.frame {
                tab.fill(C.tabHoverFill)
                    .frame(width: C.tab.width, height: C.tab.height)
                    .position(x: cell.midX, y: cell.midY)
            }
            // The active agent's tab, sliding to the next on the island's no-bounce spring.
            if let cell = layout.cells.first(where: { $0.agent == active })?.frame {
                tab.fill(increased ? C.contrastFill : C.tabFill)
                    .overlay(tab.strokeBorder(increased ? C.contrastStroke : .clear, lineWidth: 1))
                    .frame(width: C.tab.width, height: C.tab.height)
                    .position(x: cell.midX, y: cell.midY)
                    .animation(model.snapshotMode ? nil : (reduceMotion ? .easeOut(duration: 0.1) : C.agentSwap), value: active)
            }
            // Viewing another agent: a dot under the one whose chat the request goes to.
            if let chosenAgent, chosenAgent != active, let cell = layout.cells.first(where: { $0.agent == chosenAgent })?.frame {
                Circle()
                    .fill(C.chosenDotColor)
                    .frame(width: C.chosenDot, height: C.chosenDot)
                    .position(x: cell.midX, y: cell.midY + C.tab.height / 2 + C.chosenDotGap + C.chosenDot / 2)
            }
            ForEach(layout.cells, id: \.agent) { cell in
                let agent = ChatAgent.named(cell.agent)
                let offline = model.offline(agent.id)
                let idle = offline ? C.offlineOpacity : (increased ? C.contrastIdleOpacity : C.railIdleOpacity)
                Button { model.setChatAgent(agent.id) } label: {
                    ChatAgentIcon(agent: agent, size: C.railIcon)
                        .opacity(agent.id == active ? (offline ? C.offlineActiveOpacity : 1) : (hoveredAgent == agent.id ? C.railHoverOpacity : idle))
                        .frame(width: cell.frame.width, height: cell.frame.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    if inside { hoveredAgent = agent.id } else if hoveredAgent == agent.id { hoveredAgent = nil }
                }
                .help(offline ? "Fovea isn't set up for \(agent.name)" : agent.id == chosenAgent && agent.id != active
                      ? "\(agent.name): the chosen chat is here" : agent.name)
                .position(x: cell.frame.midX, y: cell.frame.midY)
                .accessibilityLabel(agent.name)
                .accessibilityAddTraits(agent.id == active ? [.isButton, .isSelected] : .isButton)
            }
            // The active agent's name at the right, on the rows' right edge (their ages and chevrons).
            Text(ChatAgent.named(active).name)
                .font(C.railNameFont)
                .foregroundStyle(C.railNameColor)
                .lineLimit(1)
                .contentTransition(.opacity)
                .padding(.trailing, C.rowPaddingH)
                .frame(width: layout.railName.width, height: layout.railName.height, alignment: .trailing)
                .position(x: layout.railName.midX, y: layout.railName.midY)
                .animation(C.nameSwap, value: active)
            if layout.level == .chats, let project = model.openProject {
                ChatProjectList(model: model, project: project)
                    .frame(width: layout.scroll.width, height: layout.scroll.height)
                    .position(x: layout.scroll.midX, y: layout.scroll.midY)
            }
            // Rows keep their places: another agent's projects take them over in place.
            ForEach(Array(layout.rows.enumerated()), id: \.offset) { _, row in
                Group {
                    if row.id == ChatLayout.offlineRow {
                        ChatNotSetUpNote(agent: ChatAgent.named(active))
                    } else if row.id == ChatLayout.loadingRow {
                        ChatLoadingRow(agent: ChatAgent.named(active))
                    } else if row.id == WorkbenchModel.backRow, let project = model.openProject {
                        ChatBackRow(model: model, project: project, highlighted: model.chatHighlight == row.id)
                    } else if row.id.hasPrefix(WorkbenchModel.projectPrefix),
                              let project = model.projects(of: active).first(where: { WorkbenchModel.projectPrefix + $0.folder == row.id }) {
                        ChatProjectRow(model: model, project: project, highlighted: model.chatHighlight == row.id)
                    }
                }
                .frame(width: row.frame.width, height: row.frame.height)
                .position(x: row.frame.midX, y: row.frame.midY)
            }
        }
    }
}

/// A project of the active agent: a dot if the chosen chat is in it, its name (and "this
/// project" for the referents'), and on the right whether any chat needs you, how many chats,
/// and how long ago the latest was active. A click opens its chats.
struct ChatProjectRow: View {
    let model: WorkbenchModel
    let project: ChatProject
    let highlighted: Bool

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        let holdsChosen = model.chosen.map { $0.agent == project.agent && $0.folder == project.folder } ?? false
        HStack(spacing: 0) {
            Circle()
                .fill(C.chosenDotColor)
                .frame(width: C.projectDot, height: C.projectDot)
                .opacity(holdsChosen ? 1 : 0)
                .frame(width: C.checkWidth, alignment: .leading)
            Text(project.folder)
                .font(C.chatFont)
                .foregroundStyle(C.chatColor)
                .lineLimit(1)
            if project.folder == ChatBook.project {
                Text("this project")
                    .font(C.metaFont)
                    .foregroundStyle(C.metaColor)
                    .padding(.leading, C.metaSpacing)
                    .fixedSize()
            }
            Spacer(minLength: C.metaGap)
            HStack(spacing: C.metaSpacing) {
                if project.needsYou {
                    Text("Needs you").font(C.statusFont).foregroundStyle(C.needsYouColor)
                }
                Text(project.chats.count == 1 ? "1 chat" : "\(project.chats.count) chats").foregroundStyle(C.metaColor)
                if let latest = project.latest {
                    Text(latest.age).foregroundStyle(C.metaColor).monospacedDigit()
                }
                Image(systemName: "chevron.right")
                    .font(C.pillChevron)
                    .foregroundStyle(C.metaColor)
            }
            .font(C.metaFont)
            .fixedSize()
        }
        .padding(.horizontal, C.rowPaddingH)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChatHighlight(on: highlighted))
        .contentShape(Rectangle())
        .onHover { if $0 { model.hoverHighlight(WorkbenchModel.projectPrefix + project.folder) } }
        .onTapGesture { model.openProject(project.folder) }
        .help(holdsChosen ? "\(project.path): the chosen chat is here" : project.path)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(project.folder), \(project.chats.count == 1 ? "1 chat" : "\(project.chats.count) chats")")
        .accessibilityHint("Shows its chats")
    }
}

/// On the chats level: the project, a step back to the projects.
struct ChatBackRow: View {
    let model: WorkbenchModel
    let project: ChatProject
    let highlighted: Bool

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        HStack(spacing: C.metaSpacing) {
            Image(systemName: "chevron.left")
                .font(C.pillChevron)
                .foregroundStyle(C.backColor)
                .frame(width: C.checkWidth - C.metaSpacing, alignment: .leading)
            Text(project.folder)
                .font(C.backFont)
                .foregroundStyle(C.chatColor)
                .lineLimit(1)
                .fixedSize()
            Text(project.path)
                .font(C.metaFont)
                .foregroundStyle(C.metaColor)
                .lineLimit(1)
                .truncationMode(.head)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, C.rowPaddingH)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChatHighlight(on: highlighted))
        .contentShape(Rectangle())
        .onHover { if $0 { model.hoverHighlight(WorkbenchModel.backRow) } }
        .onTapGesture { model.setChatLevel(.projects) }
        .help("Back to \(ChatAgent.named(project.agent).name)'s projects (esc)")
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Back to projects")
    }
}

/// An agent Fovea isn't set up for (its connector off, or the app not on this Mac): Fovea can't
/// see its chats or send to them, and where to set it up.
struct ChatNotSetUpNote: View {
    let agent: ChatAgent

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        VStack(alignment: .leading, spacing: 2) {
            Text("Fovea isn't set up for \(agent.name)")
                .font(C.chatFont)
                .foregroundStyle(C.chatColor)
            Text("It can't see \(agent.name)'s chats or send to them yet. Set it up in Settings › Connectors.")
                .font(C.metaFont)
                .foregroundStyle(C.metaColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, C.rowPaddingH + C.checkWidth)
        .padding(.trailing, C.rowPaddingH)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// An agent whose chats are still being read (fovea-mac's history loading): a spinner and a line.
struct ChatLoadingRow: View {
    let agent: ChatAgent

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        HStack(spacing: C.metaSpacing) {
            ProgressView().controlSize(.mini).tint(C.metaColor)
                .frame(width: C.checkWidth - C.metaSpacing, alignment: .leading)
            Text("Reading \(agent.name)'s chats…")
                .font(C.chatFont)
                .foregroundStyle(C.loadingColor)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, C.rowPaddingH)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// One project's chats, scrolling: a New chat first, then its chats, most recent first. The
/// keyboard's row is kept in view.
struct ChatProjectList: View {
    let model: WorkbenchModel
    let project: ChatProject

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(model.items(of: project)) { chat in
                        ChatRowView(model: model, chat: chat, highlighted: model.chatHighlight == chat.id)
                            .frame(height: C.chatRow)
                            .id(chat.id)
                    }
                }
            }
            .scrollIndicators(.automatic)
            .onChange(of: model.chatHighlight) { _, id in
                guard let id, id != WorkbenchModel.backRow else { return }
                proxy.scrollTo(id)
            }
            .onAppear {
                if let id = model.chatHighlight, id != WorkbenchModel.backRow { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }
}

/// One chat: a check if it is the one the request goes to, its title, and on the right what
/// matters for sending to it (its branch when not the main one; working, needs you, or why it
/// can't take the request, with a way to open it in its own app; else how long ago).
struct ChatRowView: View {
    let model: WorkbenchModel
    let chat: AgentChat
    let highlighted: Bool

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        let chosen = model.chosenChat == chat.id
        let choosable = chat.state.choosable
        HStack(spacing: 0) {
            Image(systemName: "checkmark")
                .font(C.checkGlyph)
                .foregroundStyle(C.checkColor)
                .opacity(chosen ? 1 : 0)
                .frame(width: C.checkWidth, alignment: .leading)
            if chat.isNew {
                Image(systemName: "plus")
                    .font(C.checkGlyph)
                    .foregroundStyle(C.newChatColor)
                    .padding(.trailing, C.metaSpacing)
            }
            Text(chat.title)
                .font(C.chatFont)
                .italic(chat.untitled)
                .foregroundStyle(chat.isNew ? C.newChatColor : (choosable ? C.chatColor : C.chatDisabledColor))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: C.metaGap)
            ChatRowMeta(model: model, chat: chat,
                        suggested: chat.id == model.predictedPick && !chosen)
        }
        .padding(.horizontal, C.rowPaddingH)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ChatHighlight(on: highlighted))
        .contentShape(Rectangle())
        .onHover { if $0 { model.hoverHighlight(chat.id) } }
        .onTapGesture { model.activateChat(chat.id) }
        .help(ChatRowMeta.help(chat))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel("\(chat.title), \(ChatAgent.named(chat.agent).name)")
        .accessibilityValue(ChatRowMeta.help(chat))
        .accessibilityAction { model.activateChat(chat.id) }
    }
}

/// The right side of a chat's row.
struct ChatRowMeta: View {
    let model: WorkbenchModel
    let chat: AgentChat
    /// Fovea's pick, once the person has chosen another: where it would have gone.
    var suggested = false

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        HStack(spacing: C.metaSpacing) {
            if suggested {
                Text("Suggested").foregroundStyle(C.metaColor)
            }
            if let branch = chat.branch {
                Text(branch).foregroundStyle(C.metaColor).lineLimit(1)
            }
            switch chat.state {
            case .working:
                Circle().fill(C.workingColor).frame(width: C.workingDotSize, height: C.workingDotSize)
                Text("Working").font(C.statusFont).foregroundStyle(C.workingColor)
            case .needsYou:
                Text("Needs you").font(C.statusFont).foregroundStyle(C.needsYouColor)
            case .unavailable(let reason):
                Text(reason).foregroundStyle(C.metaColor)
            case .elsewhere(let app):
                Text("Can't continue here").foregroundStyle(C.metaColor)
                Button { model.openElsewhere(chat.id) } label: {
                    Image(systemName: "arrow.up.forward.square")
                        .font(C.openGlyph)
                        .foregroundStyle(C.openColor)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Open it in \(app)")
                .accessibilityLabel("Open in \(app)")
            case .open, .ready:
                if !chat.isNew {
                    Text(chat.age).foregroundStyle(C.metaColor).monospacedDigit()
                }
            }
        }
        .font(C.metaFont)
        .fixedSize()
    }

    /// What sending to it would do, said plainly.
    static func help(_ chat: AgentChat) -> String {
        if chat.isNew { return "Starts a new chat in \(chat.folder)." }
        switch chat.state {
        case .open: return "Open: takes the request at once. \(detail(chat))."
        case .working: return "Working: the request runs after this turn. \(detail(chat))."
        case .ready: return "Resumes when the request is sent. \(detail(chat))."
        case .needsYou: return "Waiting for your answer where it runs; answer there first. \(detail(chat))."
        case .unavailable(let reason): return "\(reason): Fovea can't send to it from here. \(detail(chat))."
        case .elsewhere(let app): return "Fovea can't confirm it may write to this chat: open it in \(app) instead. \(detail(chat))."
        }
    }

    static func detail(_ chat: AgentChat) -> String {
        var parts = [chat.folder]
        if let branch = chat.branch { parts.append(branch) }
        parts.append("active \(chat.age) ago")
        return parts.joined(separator: " · ")
    }
}

/// The cursor's fill under a row: it moves with the keyboard or the pointer at once, never
/// animating; under Increase Contrast it steps up and takes a keyline.
struct ChatHighlight: View {
    let on: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        let shape = RoundedRectangle(cornerRadius: C.highlightRadius, style: .continuous)
        let increased = contrast == .increased
        shape.fill(on ? (increased ? C.contrastFill : C.highlight) : .clear)
            .overlay(shape.strokeBorder(on && increased ? C.contrastStroke : .clear, lineWidth: 1))
            .transaction { $0.animation = nil }
    }
}

/// Measures the request at the island's text width, whole and as its three lines, for the
/// layout. Drawn hidden, behind the island's content.
struct ChatMeasure: View {
    let model: WorkbenchModel

    var body: some View {
        let C = WorkbenchTokens.Chat.self
        VStack(spacing: 0) {
            Text(model.requestText.isEmpty ? " " : model.requestText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: ChatLayout.contentWidth, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { model.chatTextHeight = $0 }
            Text(" ")
                .lineLimit(C.lines, reservesSpace: true)
                .frame(width: ChatLayout.contentWidth, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { model.chatLinesHeight = $0 }
        }
        .font(C.text)
        .lineSpacing(C.lineSpacing)
        .fixedSize(horizontal: false, vertical: true)
        .hidden()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

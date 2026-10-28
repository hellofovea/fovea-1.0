import SwiftUI
import FoveaCore
import FoveaLook
import FoveaKit

// Oct 27, Ryan, of Choose chat: "the design is just mediocre. not bad, but really boring and not
// innovative at all … creative, artsy, but useful ways of structuring the prompt, attachment, chat
// choosing button, effort choosing button, and send button. i think the suggested chats can go
// into the choose chat button." Three were built after research (Sentence, Dial, Ticket;
// docs/island/CHOOSE_CHAT.md); then "i want sentence. delete others." The Sentence: the request
// large, as said; under a hairline, one line that reads as a sentence, "[what was taken] To [chat]
// · thinking [hard]   Send ↵", its words the controls (Apple Shortcuts' parameter summaries,
// mad-libs forms). The suggestions are in the chat's word (every chat opens on them); ↑↓ still
// step through them and Return still sends.

extension WorkbenchTokens {
    enum Composer {
        /// After Send, where it's going (or why it didn't go), on a row of its own.
        static var statusRow: CGFloat { V2.chipRow }

        // Sentence: the request as said, larger; the hairline; the sentence.
        static var sentenceRequestSize: CGFloat { size(17) }
        static let sentenceRequestWeight: Font.Weight = .regular
        static let sentenceMeasureWeight: NSFont.Weight = .regular
        static var sentenceSpacing: CGFloat { size(3) }
        static let sentenceLines = 3
        static var ruleGap: CGFloat { size(10) }
        static var sentenceRow: CGFloat { size(34) }
        static var wordFont: Font { Font.system(size: typeSize(12.5)) }
        static var tokenFont: Font { Font.system(size: typeSize(12.5), weight: .semibold) }
        static var wordGap: CGFloat { size(5) }
        static var tokenIcon: CGFloat { size(15) }
        static var chatTokenMax: CGFloat { size(236) }
        static var tokenPadding: CGFloat { size(4) }
        static var tokenHeight: CGFloat { size(24) }
        static let tokenRadius: CGFloat = 6
        /// The words that are controls: a dotted rule under them, in the accent.
        static let underline: CGFloat = 1.25
        static let underlineDash: [CGFloat] = [1.25, 2.25]
        static var underlineDrop: CGFloat { size(3) }

        // Send with its key: "Send ↵".
        static var sendHeight: CGFloat { size(28) }
        static var sendPadding: CGFloat { size(12) }
        static var sendFont: Font { Font.system(size: typeSize(12.5), weight: .semibold) }
        static var sendKeyGlyph: Font { Font.system(size: typeSize(10.5), weight: .bold) }
    }
}

extension WorkbenchModel {
    /// How hard it thinks, in a sentence's words ("thinking hard"); on Auto, "default" (Oct 27, Ryan:
    /// "dont have the default named \"as needed\", go with just \"default\"").
    var composerEffortWords: String {
        guard let effort = v2Effort else { return L("default") }
        switch effort {
        case "minimal": return L("barely")
        case "low": return L("briefly")
        case "medium": return L("it through")
        case "high": return L("hard")
        case "xhigh": return L("harder")
        case "max": return L("hardest")
        default: return ModelCatalog.effortName(effort)
        }
    }
}

// MARK: Sentence

/// The request as said, large; a hairline; one line that reads as a sentence, its words the
/// controls: what was taken, To the chat, thinking how hard, and Send with its key.
struct ComposerSentence: View {
    let model: WorkbenchModel
    let layout: V2SendLayout

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let K = WorkbenchTokens.Composer.self
        VStack(alignment: .leading, spacing: 0) {
            V2RequestEditor(model: model, size: K.sentenceRequestSize, weight: K.sentenceRequestWeight,
                            spacing: K.sentenceSpacing, lines: K.sentenceLines)
                .frame(width: V2Geometry.contentWidth, height: layout.text, alignment: .topLeading)
            Rectangle().fill(V.rule).frame(height: 1).padding(.vertical, K.ruleGap)
            HStack(spacing: K.wordGap) {
                if !model.liveReferents.isEmpty {
                    V2ReferentPile(model: model)
                        .padding(.trailing, K.wordGap)
                }
                Text(L("To")).font(K.wordFont).foregroundStyle(V.subColor)
                ComposerChatToken(model: model)
                Text(L("· thinking")).font(K.wordFont).foregroundStyle(V.subColor)
                ComposerToken(text: model.composerEffortWords, help: L("How hard it thinks, the model and the approvals")) {
                    model.toggleModelSheet()
                }
                Spacer(minLength: K.wordGap)
                ComposerSendKey(model: model)
            }
            .frame(height: K.sentenceRow)
            .zIndex(5)
        }
    }
}

/// A word in the sentence that is a control: set bold, a dotted rule under it in the accent, a
/// field round it under the pointer.
struct ComposerToken<Lead: View>: View {
    let text: String
    var help = ""
    var maxWidth: CGFloat? = nil
    @ViewBuilder var lead: () -> Lead
    let action: () -> Void
    @State private var hovering = false

    init(text: String, help: String = "", maxWidth: CGFloat? = nil, @ViewBuilder lead: @escaping () -> Lead,
         action: @escaping () -> Void) {
        self.text = text; self.help = help; self.maxWidth = maxWidth; self.lead = lead; self.action = action
    }

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let K = WorkbenchTokens.Composer.self
        Button(action: action) {
            HStack(spacing: K.wordGap) {
                lead()
                Text(text)
                    .font(K.tokenFont)
                    .foregroundStyle(V.titleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .overlay(alignment: .bottom) {
                        DottedRule()
                            .stroke(WorkbenchTokens.Native.accent, style: StrokeStyle(lineWidth: K.underline, lineCap: .round,
                                                                                      dash: K.underlineDash))
                            .frame(height: K.underline)
                            .offset(y: K.underlineDrop)
                    }
            }
            .padding(.horizontal, K.tokenPadding)
            .frame(height: K.tokenHeight)
            .frame(maxWidth: maxWidth)
            .fixedSize(horizontal: maxWidth == nil, vertical: false)
            .background(RoundedRectangle(cornerRadius: K.tokenRadius, style: .continuous).fill(hovering ? V.hoverFill : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(IslandPressStyle())
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(text)
    }
}

extension ComposerToken where Lead == EmptyView {
    init(text: String, help: String = "", maxWidth: CGFloat? = nil, action: @escaping () -> Void) {
        self.init(text: text, help: help, maxWidth: maxWidth, lead: { EmptyView() }, action: action)
    }
}

/// The chat as a word of the sentence: its agent's icon and its name; a click opens the suggested
/// chats and every other.
struct ComposerChatToken: View {
    let model: WorkbenchModel

    var body: some View {
        let K = WorkbenchTokens.Composer.self
        let pick = model.v2Pick
        let locked = model.cases.sending?.isSending == true
        ComposerToken(text: pick.title, help: locked ? L("Sending to \(pick.title)") : L("Suggested chats, and every chat: ⌃"),
                      maxWidth: K.chatTokenMax) {
            ChatAgentIcon(agent: ChatAgent.named(pick.agent), size: K.tokenIcon)
        } action: {
            model.toggleV2Browse()
        }
        .disabled(locked)
    }
}

/// A line along the middle of its frame, for a dotted rule.
struct DottedRule: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

/// Send with its key, in the accent: "Send ↵". On its way it turns.
struct ComposerSendKey: View {
    let model: WorkbenchModel
    @State private var hovering = false

    var body: some View {
        let V = WorkbenchTokens.V2.self
        let K = WorkbenchTokens.Composer.self
        let sending = model.cases.sending
        Button { model.sendV2Now() } label: {
            HStack(spacing: K.wordGap + 1) {
                if sending?.isSending == true {
                    ProgressView().controlSize(.small).tint(WorkbenchTokens.Panel.buttonPrimaryText)
                } else {
                    Text(L("Send")).font(K.sendFont)
                    Image(systemName: "return").font(K.sendKeyGlyph)
                }
            }
            .foregroundStyle(WorkbenchTokens.Panel.buttonPrimaryText)
            .padding(.horizontal, K.sendPadding)
            .frame(height: K.sendHeight)
            .background(Capsule(style: .continuous)
                .fill(WorkbenchTokens.Panel.buttonPrimary.opacity(sending != nil ? 0.45 : (hovering ? V.sendHoverOpacity : 1))))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(IslandPressStyle())
        .disabled(sending != nil)
        .onHover { hovering = $0 }
        .help(L("Send (fn⌃, Return)"))
        .accessibilityLabel(L("Send"))
    }
}

// MARK: The suggestions, in the chat's button

/// The suggested chats at the top of every chat (Oct 27, Ryan: "the suggested chats can go into the
/// choose chat button"), as chips; the one chosen marked.
struct ComposerSuggestedRow: View {
    let model: WorkbenchModel

    var body: some View {
        let V = WorkbenchTokens.V2.self
        HStack(spacing: V.chipGap) {
            Text(L("Suggested")).font(V.labelFont).foregroundStyle(V.labelColor)
                .padding(.trailing, V.labelTrailing)
            ForEach(model.v2Suggestions) { pick in
                V2SuggestionChip(model: model, pick: pick, chosen: model.v2Pick == pick, folds: true)
            }
            Spacer(minLength: 0)
        }
        .frame(height: V.chipRow)
    }
}

import SwiftUI
import AppKit
import QuartzCore
import FoveaCore
import OnboardingCore
import FoveaLook

// The practice windows (Oct 9). For the tasks: the browser, its tabs real local pages
// (PracticeSite.swift), and the team chat beside it. For dictation: Fovea's own feedback window
// and a Messages thread, side by side; the words go to the one under the pointer.

/// The browser, with the showing tab's page as it last loaded.
struct PracticeWindow: View {
    let model: OnboardingModel

    var body: some View {
        VStack(spacing: 0) {
            BrowserToolbar(address: model.currentTab.address)
            TabBar(model: model)
            Rectangle().fill(OT.Colors.practiceEdge).frame(height: 1)
            PageImage(model: model, tab: model.currentTab)
        }
        .background(OT.Colors.practiceWindow)
        .clipShape(RoundedRectangle(cornerRadius: OT.Layout.practiceRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OT.Layout.practiceRadius, style: .continuous).strokeBorder(OT.Colors.practiceEdge))
        .shadow(color: OT.Colors.practiceShadow, radius: 24, y: 12)
        .environment(\.colorScheme, .light)
    }
}

/// The browser's tabs. Clicking one shows its page; while a request is open, the tab to click
/// next is ringed in the accent (Oct 9: gathering from different tabs; Oct 21, Ryan ("simpler is
/// better"): held still, it breathed).
struct TabBar: View {
    let model: OnboardingModel
    var still = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(model.openTabs, id: \.self) { tab in
                let on = tab == model.currentTab
                let next = !still && model.tabToClick == tab
                Button(action: { model.selectTab(tab) }) {
                    Text(tab.title)
                        .font(.system(size: 12, weight: on ? .semibold : .regular))
                        .foregroundStyle(on ? OT.Colors.pageText : OT.Colors.toolbarGlyph)
                        .frame(maxWidth: .infinity)
                        .frame(height: OT.Layout.tabBar - 8)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(on ? OT.Colors.practiceWindow : .clear))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(next ? model.accentColor : (on ? OT.Colors.practiceEdge : .clear),
                                          lineWidth: next ? 2 : 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(ScreenSpace.name)) } action: { model.tabFrames[tab] = $0 }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: OT.Layout.tabBar)
        .background(OT.Colors.toolbar)
    }
}

/// Safari's toolbar, plainly drawn: the lights, the address, two buttons.
struct BrowserToolbar: View {
    let address: String
    var secure = true

    var body: some View {
        HStack(spacing: 14) {
            TrafficLights()
            Image(systemName: "sidebar.left").foregroundStyle(OT.Colors.toolbarGlyph)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: secure ? "lock.fill" : "globe").font(.system(size: 10))
                Text(address)
            }
            .font(.system(size: 12.5))
            .foregroundStyle(OT.Colors.toolbarGlyph)
            .frame(width: 320, height: 28)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(OT.Colors.addressField))
            Spacer()
            Image(systemName: "square.and.arrow.up").foregroundStyle(OT.Colors.toolbarGlyph)
            Image(systemName: "plus").foregroundStyle(OT.Colors.toolbarGlyph)
        }
        .font(.system(size: 14))
        .padding(.horizontal, 14)
        .frame(height: OT.Layout.practiceToolbar)
        .background(OT.Colors.toolbar)
    }
}

struct TrafficLights: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(OT.Colors.trafficLights.indices, id: \.self) { i in
                Circle().fill(OT.Colors.trafficLights[i]).frame(width: 12, height: 12)
            }
        }
    }
}

/// A tab's page as the browser shows it: the page's own picture, retaken after every load.
struct PageImage: View {
    let model: OnboardingModel
    let tab: PracticeTab

    var body: some View {
        ZStack {
            OT.Colors.practiceWindow
            if let image = model.pageImages[tab] {
                Image(nsImage: image).resizable().interpolation(.high)
            }
        }
        .frame(width: OT.Site.size.width, height: OT.Site.size.height)
    }
}

/// The team chat (Oct 9: the weekly update starts with Maya asking for it), drawn plainly.
struct ChatWindow: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TrafficLights()
                Spacer()
                Text("# team").font(.system(size: 12, weight: .semibold)).foregroundStyle(OT.Colors.toolbarGlyph)
                Spacer()
                Color.clear.frame(width: 52, height: 1)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(OT.Colors.toolbar)
            Rectangle().fill(OT.Colors.practiceEdge).frame(height: 1)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(OT.Practice.teamChat.indices, id: \.self) { i in
                    let message = OT.Practice.teamChat[i]
                    HStack(alignment: .top, spacing: 10) {
                        Text(String(message.name.prefix(1)))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OT.Colors.chatInitial)
                            .frame(width: 28, height: 28)
                            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(message.color))
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(message.name).font(.system(size: 12.5, weight: .bold)).foregroundStyle(OT.Colors.pageText)
                                Text(message.time).font(.system(size: 11)).foregroundStyle(OT.Colors.pageSecondary)
                            }
                            Text(message.text).font(.system(size: 13)).foregroundStyle(OT.Colors.pageText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .background(OT.Colors.practiceWindow)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(OT.Colors.practiceEdge))
        .shadow(color: OT.Colors.practiceShadow, radius: 18, y: 10)
        .environment(\.colorScheme, .light)
    }
}

// MARK: - Dictation's two windows

/// Fovea's own feedback window (Oct 9: start with feedback on this first run): ink on paper, the
/// words land in it when spoken to, and it goes only when Send is clicked.
struct FeedbackWindow: View {
    let model: OnboardingModel
    /// Drawn for a picture of the screen (ImageRenderer can't draw an editable box): the words as
    /// text.
    var picture = false

    /// Oct 18, Ryan: the words go to the window under the pointer when they land.
    private var targeted: Bool { model.dictationLanding == .feedback }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TrafficLights()
                Spacer()
                Text("Fovea · Feedback").font(.system(size: 12, weight: .semibold)).foregroundStyle(OT.Colors.ink(0.6))
                Spacer()
                Color.clear.frame(width: 52, height: 1)
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            VStack(alignment: .leading, spacing: 14) {
                Text(Copy.feedbackTitle).font(.system(size: 22, weight: .semibold)).foregroundStyle(OT.Colors.ink)
                // What to talk about (Oct 9, round two: guidance makes for better feedback).
                VStack(alignment: .leading, spacing: 8) {
                    Text(Copy.feedbackLead).font(.system(size: 12, weight: .medium)).foregroundStyle(OT.Colors.ink(0.5))
                    FlowRow(spacing: 6) {
                        ForEach(Copy.feedbackTopics, id: \.self) { topic in
                            Text(topic).font(.system(size: 12, weight: .medium)).foregroundStyle(OT.Colors.ink(0.75))
                                .padding(.horizontal, 10).frame(height: 26)
                                .background(Capsule().fill(OT.Colors.ink(0.05)))
                        }
                    }
                }
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(OT.Colors.ink(0.03))
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(targeted ? model.accentColor.opacity(0.75) : OT.Colors.ink(0.1), lineWidth: targeted ? 2 : 1)
                    VStack(alignment: .leading, spacing: 10) {
                        if picture {
                            DictatedText(text: model.feedbackText, placeholder: Copy.feedbackPlaceholder(keys: model.keys), caret: targeted,
                                         accent: model.accentColor, ink: OT.Colors.ink, placeholderInk: OT.Colors.ink(0.35))
                        } else {
                            // Oct 18, Ryan: "the users should be able to delete what they have put
                            // here": the words are the person's to change before Send.
                            EditableDictation(text: Binding(get: { model.feedbackText }, set: { model.feedbackText = $0 }),
                                              placeholder: Copy.feedbackPlaceholder(keys: model.keys), caret: targeted,
                                              accent: model.accentColor)
                                .disabled(model.feedbackSent)
                        }
                        // Oct 17, Ryan: what was taken while talking, after the words; Oct 18: each
                        // can be taken off again.
                        if !model.feedbackTaken.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(model.feedbackTaken) { taken in
                                    TakenPicture(referent: taken, height: OT.Layout.takenInFeedback,
                                                 onRemove: picture || model.feedbackSent ? nil : { model.removeTaken(taken.id, from: .feedback) })
                                }
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(14)
                }
                .frame(maxHeight: .infinity)
                HStack {
                    Text(model.feedbackSent ? Copy.feedbackSent : Copy.feedbackNote)
                        .font(.system(size: 12)).foregroundStyle(OT.Colors.ink(0.5))
                    Spacer()
                    Button(action: { model.sendFeedback() }) {
                        Text(model.feedbackSent ? "Sent" : "Send")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OT.Colors.canvas)
                            .padding(.horizontal, 18).frame(height: 32)
                            .background(Capsule().fill(OT.Colors.ink(model.feedbackText.isEmpty || model.feedbackSent ? 0.25 : 1)))
                    }
                    .buttonStyle(.plain)
                    .playTarget(.feedbackSend, model)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
        }
        .background(OT.Colors.canvas)
        .clipShape(RoundedRectangle(cornerRadius: OT.Layout.practiceRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OT.Layout.practiceRadius, style: .continuous).strokeBorder(OT.Colors.practiceEdge))
        .shadow(color: OT.Colors.practiceShadow, radius: 24, y: 12)
        .environment(\.colorScheme, .light)
    }
}

/// Messages, with Lin asking to move the call; the reply box takes the words. Oct 18, Ryan: the box
/// is the person's to change before it's sent (Return, or the arrow); what was taken sits above it,
/// each with ✕, and goes with the words.
struct MessagesWindow: View {
    let model: OnboardingModel
    /// Drawn for a picture of the screen: the box as text (ImageRenderer can't draw a field).
    var picture = false

    /// Oct 18, Ryan: the words go to the window under the pointer when they land.
    private var targeted: Bool { model.dictationLanding == .messages }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TrafficLights()
                Spacer()
                Text("Messages · Lin").font(.system(size: 12, weight: .semibold)).foregroundStyle(OT.Colors.toolbarGlyph)
                Spacer()
                Color.clear.frame(width: 52, height: 1)
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(OT.Colors.toolbar)
            Rectangle().fill(OT.Colors.practiceEdge).frame(height: 1)
            VStack(alignment: .leading, spacing: 10) {
                Text("Today 9:12 AM").font(.system(size: 11)).foregroundStyle(OT.Colors.pageSecondary).frame(maxWidth: .infinity)
                ForEach(Copy.linMessages, id: \.self) { bubble($0, mine: false) }
                if let sent = model.sentReply {
                    bubble(sent, mine: true)
                        .transition(model.sentTransition)
                }
                // Oct 17, Ryan: taken while answering, after the words, as Messages sends a picture.
                ForEach(model.sentReplyTaken) { taken in
                    HStack {
                        Spacer(minLength: 100)
                        TakenPicture(referent: taken, height: OT.Layout.takenInMessages)
                    }
                    .transition(model.sentTransition)
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            // What's taken waits above the box until it's sent, each with ✕ (Oct 18, Ryan).
            if !model.replyTaken.isEmpty {
                HStack(spacing: 8) {
                    Spacer()
                    ForEach(model.replyTaken) { taken in
                        TakenPicture(referent: taken, height: OT.Layout.takenInFeedback,
                                     onRemove: picture ? nil : { model.removeTaken(taken.id, from: .messages) })
                    }
                }
                .padding(.horizontal, 16)
                .transition(.opacity)
            }
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(OT.Colors.messagesGlyph)
                HStack(spacing: 6) {
                    if picture || model.replyText.isEmpty && !targeted {
                        Text(model.replyText.isEmpty ? Copy.replyPlaceholder : model.replyText)
                            .foregroundStyle(model.replyText.isEmpty ? OT.Colors.pageSecondary : OT.Colors.messageText)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    } else {
                        if targeted, model.replyText.isEmpty { Caret(accent: model.accentColor) }
                        TextField("", text: Binding(get: { model.replyText }, set: { model.replyText = $0 }))
                            .textFieldStyle(.plain)
                            .foregroundStyle(OT.Colors.messageText)
                            .onSubmit { model.sendReply() }
                    }
                    if model.canSendReply, !picture {
                        Button(action: { model.sendReply() }) {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 20)).foregroundStyle(OT.Colors.messageMine)
                        }
                        .buttonStyle(.plain)
                        .help("Send")
                        .accessibilityLabel("Send")
                    } else {
                        Image(systemName: "mic").foregroundStyle(OT.Colors.pageSecondary)
                    }
                }
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Capsule().strokeBorder(targeted ? model.accentColor.opacity(0.75) : OT.Colors.replyEdge,
                                                   lineWidth: targeted ? 2 : 1))
            }
            .padding(16)
        }
        .background(OT.Colors.practiceWindow)
        .clipShape(RoundedRectangle(cornerRadius: OT.Layout.practiceRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OT.Layout.practiceRadius, style: .continuous).strokeBorder(OT.Colors.practiceEdge))
        .shadow(color: OT.Colors.practiceShadow, radius: 24, y: 12)
        .environment(\.colorScheme, .light)
    }

    private func bubble(_ text: String, mine: Bool) -> some View {
        HStack {
            if mine { Spacer(minLength: 100) }
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(mine ? OT.Colors.messageMineText : OT.Colors.messageText)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(mine ? OT.Colors.messageMine : OT.Colors.messageBubble))
                .fixedSize(horizontal: false, vertical: true)
            if !mine { Spacer(minLength: 100) }
        }
    }
}

/// A picture taken while dictating, as it lands after the words (Oct 17, Ryan). Oct 18, Ryan: it
/// can be taken off again, with its ✕, or selected and Delete.
struct TakenPicture: View {
    let referent: TakenReferent
    let height: CGFloat
    var onRemove: (() -> Void)? = nil
    @FocusState private var focused: Bool

    var body: some View {
        if let onRemove {
            picture
                .overlay(RoundedRectangle(cornerRadius: OT.Layout.takenRadius, style: .continuous)
                    .strokeBorder(focused ? OT.Colors.ink(0.5) : .clear, lineWidth: 2))
                .overlay(alignment: .topTrailing) {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: OT.Layout.takenRemove))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(OT.Colors.white(0.95), OT.Colors.ink(0.6))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 6, y: -6)
                    .help("Remove")
                    .accessibilityLabel("Remove the picture")
                }
                .focusable()
                .focused($focused)
                .onTapGesture { focused = true }
                .onDeleteCommand(perform: onRemove)
        } else {
            picture
        }
    }

    private var picture: some View {
        Group {
            if let image = referent.image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "photo").font(.system(size: height / 3)).foregroundStyle(OT.Colors.ink(0.3))
                    .frame(width: height * 1.4, height: height)
                    .background(OT.Colors.ink(0.05))
            }
        }
        .frame(maxHeight: height)
        .clipShape(RoundedRectangle(cornerRadius: OT.Layout.takenRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OT.Layout.takenRadius, style: .continuous).strokeBorder(OT.Colors.practiceEdge))
        .accessibilityLabel("A picture of part of the screen")
    }
}

/// The feedback's words, the person's to change (Oct 18, Ryan): a plain text box, the hint and the
/// accent caret where the words will land while it's empty.
struct EditableDictation: View {
    @Binding var text: String
    let placeholder: String
    let caret: Bool
    let accent: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 15))
                .foregroundStyle(OT.Colors.ink)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .lineSpacing(3)
            if text.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    if caret { Caret(accent: accent) }
                    Text(placeholder).foregroundStyle(OT.Colors.ink(0.35))
                }
                .font(.system(size: 15))
                .padding(.leading, 5)
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, minHeight: OT.Layout.feedbackBoxMin, alignment: .topLeading)
    }
}

/// What was said, or the hint, with the accent caret where the words will land.
struct DictatedText: View {
    let text: String
    let placeholder: String
    let caret: Bool
    let accent: Color
    let ink: Color
    let placeholderInk: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            if text.isEmpty {
                if caret { Caret(accent: accent) }
                Text(placeholder).foregroundStyle(placeholderInk)
            } else {
                (Text(text).foregroundStyle(ink))
                if caret { Caret(accent: accent) }
            }
        }
        .font(.system(size: 15))
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// The text caret, in the accent, blinking where the words will go (AMENDMENTS: no badge, a caret).
struct Caret: View {
    let accent: Color
    @State private var on = true
    /// Oct 21, perf: on the live stage it blinks on Core Animation (`BreathingLayer`): the same
    /// curve and length, 1↔0, with no SwiftUI frame for each step (each laid the stage out).
    @Environment(\.firstRunLayerLoops) private var layerLoops
    @State private var since = CACurrentMediaTime()

    var body: some View {
        if layerLoops {
            // The rectangle keeps the caret's place and baseline; its layer draws it.
            Rectangle().fill(Color.clear).frame(width: 2, height: 17)
                .overlay(BreathingLayer(color: accent, cornerRadius: 0, continuous: false, from: 1, to: 0,
                                        seconds: OT.Motion.caretBlinkSeconds, since: since))
                .onAppear { since = CACurrentMediaTime() }
        } else {
            Rectangle().fill(accent).frame(width: 2, height: 17)
                .opacity(on ? 1 : 0)
                .onAppear { withAnimation(OT.Motion.caretBlink) { on = false } }
        }
    }
}

/// Chips laid out in rows, wrapping as they need.
struct FlowRow: Layout {
    var spacing: CGFloat = 6
    /// Each row centered in the width (the agents' wishes, Oct 9), else from the leading edge.
    var centered = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = self.rows(subviews, width: width)
        let widest = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: centered && width.isFinite ? width : min(width, widest), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(subviews, width: bounds.width) {
            var x = centered ? bounds.minX + (bounds.width - row.width) / 2 : bounds.minX
            for i in row.items {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func rows(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].items.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if !rows[rows.count - 1].items.isEmpty, needed > width { rows.append(Row()) }
            var row = rows[rows.count - 1]
            row.width = row.items.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.items.append(i)
            rows[rows.count - 1] = row
        }
        return rows.filter { !$0.items.isEmpty }
    }
}

private extension OnboardingModel {
    /// What's sent in Messages fades in (Oct 21, Ryan ("simpler is better"): it rose from the
    /// window's foot, the whole window's height).
    var sentTransition: AnyTransition {
        if options.harness { return .identity }
        return .asymmetric(insertion: .opacity.animation(motion(OT.Motion.partIn)), removal: .opacity.animation(motion(OT.Motion.contentOut)))
    }
}

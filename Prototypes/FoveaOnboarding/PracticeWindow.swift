import SwiftUI
import AppKit
import FoveaCore
import OnboardingCore

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
/// next breathes in the accent (Oct 9: gathering from different tabs).
struct TabBar: View {
    let model: OnboardingModel
    var still = false
    @State private var breathe = false

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
                            .strokeBorder(next ? model.accentColor.opacity(breathe ? 1 : 0.4) : (on ? OT.Colors.practiceEdge : .clear),
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
        .onAppear { if !model.options.harness { withAnimation(OT.Motion.dropZone) { breathe = true } } }
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

    private var targeted: Bool { model.dictationTarget == .feedback || (model.dictationTarget == nil && model.pointerOver == .feedback) }

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
                    DictatedText(text: model.feedbackText, placeholder: Copy.feedbackPlaceholder, caret: targeted, accent: model.accentColor,
                                 ink: OT.Colors.ink, placeholderInk: OT.Colors.ink(0.35))
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

/// Messages, with Lin asking to move the call; the reply box takes the words.
struct MessagesWindow: View {
    let model: OnboardingModel

    private var targeted: Bool { model.dictationTarget == .messages || (model.dictationTarget == nil && model.pointerOver == .messages) }

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
                if !model.replyText.isEmpty {
                    bubble(model.replyText, mine: true)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                Spacer(minLength: 0)
            }
            .padding(20)
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(OT.Colors.messagesGlyph)
                HStack(spacing: 0) {
                    if targeted { Caret(accent: model.accentColor) }
                    Text(targeted ? "" : Copy.replyPlaceholder).foregroundStyle(OT.Colors.pageSecondary)
                    Spacer()
                    Image(systemName: "mic").foregroundStyle(OT.Colors.pageSecondary)
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

    var body: some View {
        Rectangle().fill(accent).frame(width: 2, height: 17)
            .opacity(on ? 1 : 0)
            .onAppear { withAnimation(OT.Motion.caretBlink) { on = false } }
    }
}

/// Chips laid out in rows, wrapping as they need.
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { x = 0; y += row + spacing; row = 0 }
            x += size.width + spacing
            row = max(row, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(width, widest), height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { x = bounds.minX; y += row + spacing; row = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            row = max(row, size.height)
        }
    }
}

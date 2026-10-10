import SwiftUI
import FoveaCore

/// Fovea's surface at the notch, drawn for the chosen state with Core's geometry, so every
/// state meets the Mac the same way: concave ears fuse the top corners into the menu bar,
/// the sides are straight, the bottom corners convex (docs/island/VOICE_BAR.md).
///
/// Voice flow is the Listening Flowing Bar. Captures stack at its left and the waveform
/// moves right to make room; hovering the stack fans it to the right, clicking it opens the
/// island to lay every capture out in rows, flowing right from the first
/// (docs/island/REFERENT_STACK.md).
///
/// Everything keeps one identity and is placed by `StackLayout`: the waveform, each card,
/// the stack's control and the close pill. Each animatable part carries its own animation,
/// set by the model with the change, so the outline, the waveform and the cards each move on
/// their own curve whoever made the change (a key, the panel, a click, a check).
struct MockIsland: View {
    let model: WorkbenchModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func contentAnimation(for state: NotchState) -> Animation {
        bandAnimation(shown: state.collects)
    }

    /// A band's content coming in a beat behind the shape, or going out on the closing spring.
    private func bandAnimation(shown: Bool) -> Animation {
        if reduceMotion { return .easeOut(duration: WorkbenchTokens.Motion.reduceMotionFade) }
        return shown
            ? WorkbenchTokens.Motion.content.delay(WorkbenchTokens.Motion.contentDelay)
            : WorkbenchTokens.Motion.contentOut
    }

    /// Dispatch Version 2's content: in a beat behind the shape, out on the closing spring.
    private func v2Content(_ shown: Bool) -> Animation {
        if reduceMotion { return .easeOut(duration: WorkbenchTokens.Motion.reduceMotionFade) }
        return shown ? WorkbenchTokens.V2.contentIn : bandAnimation(shown: false)
    }

    /// A live capture's slot, or where a removed one was, fading and shrinking about its center.
    private func placement(for referent: CapturedReferent, fullIndex: Int, liveIndex: [UUID: Int],
                           layout: StackLayout, departing: StackLayout?) -> StackLayout.Card? {
        if let i = liveIndex[referent.id] {
            return layout.cards.indices.contains(i) ? layout.cards[i] : nil
        }
        guard let departing, departing.cards.indices.contains(fullIndex) else { return nil }
        var card = departing.cards[fullIndex]
        let k = WorkbenchTokens.Referents.departShrink
        card.top += card.height * (1 - k) / 2
        card.width *= k
        card.height *= k
        card.radius *= k
        card.opacity = 0
        return card
    }

    var body: some View {
        let state = model.notchState
        // The waveform: Voiceflow's, and on Dispatch's bar too, a new request or asking more in a
        // session (Oct 9, evening: talking to the notch looks the same every time, the bar flowing
        // as you speak; the aura stays Dispatch's).
        let voice = (state == .voiceFlow || state == .v2Voice) && model.barNotice == nil
        let layout = model.stackLayout
        let maxH = WorkbenchTokens.Island.waveformMaxHeight
        let T = WorkbenchTokens.Referents.self
        ZStack(alignment: .top) {
            Color.clear

            VoiceBarView(level: model.audioLevel, still: model.snapshotMode, paused: !voice)
                .frame(width: WorkbenchTokens.Island.waveformSpan, height: maxH)
                .modifier(VoiceContentTransition(progress: voice ? 1 : 0))
                .animation(contentAnimation(for: state), value: state)
                .accessibilityHidden(!voice)
                .offset(x: layout.waveform.x, y: layout.waveform.y - maxH / 2)
                .animation(model.islandAnimation, value: layout.waveform)

            // Transcribing and Cancelled share the bar: each band crossfades in on its own.
            let spec = WorkbenchTokens.Island.spec
            let bandWidth = model.metrics.notchWidth ?? spec.softwareIslandWidth
            let transcribing = state == .transcribing, cancelled = state == .cancelled, noSpeech = state == .noSpeech
            TranscribingBand(model: model)
                .frame(width: bandWidth, height: spec.voiceBelow)
                .modifier(VoiceContentTransition(progress: transcribing ? 1 : 0))
                .animation(bandAnimation(shown: transcribing), value: state)
                .offset(y: model.metrics.safeAreaTop)
                .allowsHitTesting(false)
                .accessibilityHidden(!transcribing)
            CancelledBand(model: model)
                .frame(width: bandWidth, height: spec.voiceBelow)
                .modifier(VoiceContentTransition(progress: cancelled ? 1 : 0))
                .animation(bandAnimation(shown: cancelled), value: state)
                .contentShape(Rectangle())
                .onHover { model.setUndoHover($0) }
                .offset(y: model.metrics.safeAreaTop)
                .allowsHitTesting(cancelled)
                .accessibilityHidden(!cancelled)
            NoSpeechBand()
                .frame(width: bandWidth, height: spec.voiceBelow)
                .modifier(VoiceContentTransition(progress: noSpeech ? 1 : 0))
                .animation(bandAnimation(shown: noSpeech), value: state)
                .offset(y: model.metrics.safeAreaTop)
                .allowsHitTesting(false)
                .accessibilityHidden(!noSpeech)

            // Every capture, the fading ones included, each placed by id: a live one in its
            // slot, a removed one where it was, fading and shrinking while the rest close up.
            let live = model.liveReferents
            let liveIndex = Dictionary(uniqueKeysWithValues: live.enumerated().map { ($0.element.id, $0.offset) })
            let departing = model.removing.isEmpty ? nil : model.departingLayout
            ForEach(Array(model.referents.enumerated()), id: \.element.id) { fullIndex, referent in
                if let card = placement(for: referent, fullIndex: fullIndex, liveIndex: liveIndex, layout: layout, departing: departing) {
                    let isLive = liveIndex[referent.id] != nil
                    let looking = model.inspectedId
                    let reachable = model.stackExpanded && isLive && (looking == nil || looking == referent.id)
                    let hovered = reachable && model.hoveredReferent == referent.id
                    ReferentCard(referent: referent)
                        .modifier(CardPlacement(vector: card.vector,
                                                hoverScale: hovered && looking == nil ? T.hoverScale : 1,
                                                hoverAnimation: model.cardMotion.hover,
                                                remove: reachable ? { model.removeReferent(referent.id) } : nil,
                                                removeVisible: hovered))
                        .animation(model.cardAnimation(index: liveIndex[referent.id] ?? fullIndex, count: live.count,
                                                       departing: !isLive,
                                                       inspected: referent.id == model.inspectTransitionId),
                                   value: card)
                        .opacity(model.landing.contains(referent.id) || (model.barNotice != nil && !model.stackExpanded) ? 0 : 1)
                        .allowsHitTesting(reachable)
                        .onHover { inside in
                            if inside { model.hoveredReferent = referent.id }
                            else if model.hoveredReferent == referent.id { model.hoveredReferent = nil }
                        }
                        // A click looks closer; on the one being looked at, it goes back.
                        .onTapGesture { model.inspect(looking == referent.id ? nil : referent.id) }
                        .help(referent.source)
                        .zIndex(card.z + (hovered ? 100 : 0))
                        .accessibilityLabel("Screenshot from \(referent.source)")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction(named: "Remove") { model.removeReferent(referent.id) }
                }
            }

            if let hit = layout.stackHit {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: hit.width, height: hit.height)
                    .onHover { model.setStackHovered($0) }
                    .onTapGesture { model.setExpanded(true) }
                    .linkCursor()
                    .offset(x: hit.midX, y: hit.minY)
                    .zIndex(200)
                    .accessibilityElement()
                    .accessibilityLabel("\(model.referents.count) screenshots")
                    .accessibilityHint("Shows every screenshot")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { model.setExpanded(true) }
            }

            if let close = layout.close {
                let back = model.inspectedId != nil
                StackCloseButton(back: back) { back ? model.inspect(nil) : model.setExpanded(false) }
                    // Only on the opened stack, a panel in Native: the display's scheme.
                    .panelScheme()
                    .offset(x: close.midX, y: close.minY)
                    .animation(model.islandAnimation, value: close)
                    .zIndex(200)
                    .transition(.asymmetric(insertion: .opacity.animation(T.closeIn),
                                            removal: .opacity.animation(T.closeOut)))
            }

            if let caption = layout.caption, let id = model.inspectedId,
               let referent = model.referents.first(where: { $0.id == id }) {
                Text(referent.source)
                    .font(T.caption)
                    .foregroundStyle(T.captionColor)
                    .panelScheme()
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: caption.width, height: caption.height, alignment: .leading)
                    .offset(x: caption.midX, y: caption.minY)
                    .transition(.asymmetric(insertion: .opacity.animation(T.closeIn),
                                            removal: .opacity.animation(T.closeOut)))
            }
        }
        // Paste not found: the island grows to hold the transcript, its words a beat behind the
        // shape. An overlay, so its height never sizes the island's content: as a child of the
        // stack, it made the stack taller than the bar, and the outline's bottom alignment
        // pushed every state's content up.
        .overlay(alignment: .top) {
            let paste = state == .pasteNotFound
            PasteNotFoundContent(model: model, layout: model.pasteLayout)
                .modifier(VoiceContentTransition(progress: paste ? 1 : 0))
                .animation(paste ? (reduceMotion ? .easeOut(duration: WorkbenchTokens.Motion.reduceMotionFade)
                                                 : WorkbenchTokens.Paste.contentIn)
                                 : bandAnimation(shown: false), value: state)
                .offset(y: model.metrics.safeAreaTop)
                .allowsHitTesting(paste)
                .accessibilityHidden(!paste)
        }
        // Thinking: the agent at work, over the island the same way (an overlay never sizes it).
        // Feedback #2: the notice in place of the bar.
        .overlay(alignment: .top) {
            let shown = state == .voiceError
            VoiceErrorContent(model: model)
                .modifier(VoiceContentTransition(progress: shown ? 1 : 0))
                .animation(shown ? (reduceMotion ? .easeOut(duration: WorkbenchTokens.Motion.reduceMotionFade)
                                                 : WorkbenchTokens.Paste.contentIn)
                                 : bandAnimation(shown: false), value: shown)
                .offset(y: model.metrics.safeAreaTop)
                .allowsHitTesting(shown)
                .accessibilityHidden(!shown)
        }
        // …and inside the listening bar, which listens on (#2), and the last minute at its right (#4).
        .overlay(alignment: .top) {
            let shown = state.collects && model.barNotice != nil && !model.stackExpanded
            BarNoticeBand(model: model)
                .frame(width: WorkbenchTokens.Feedback.barNoticeWidth - 2 * WorkbenchTokens.Island.spec.compactTopRadius,
                       height: WorkbenchTokens.Island.spec.voiceBelow)
                .modifier(VoiceContentTransition(progress: shown ? 1 : 0))
                .animation(bandAnimation(shown: shown), value: shown)
                .offset(y: model.metrics.safeAreaTop)
                .allowsHitTesting(shown)
                .accessibilityHidden(!shown)
        }
        .overlay(alignment: .top) {
            let shown = state.collects && model.inLastMinute && model.barNotice == nil && !model.stackExpanded
            let spec = WorkbenchTokens.Island.spec
            let width = model.metrics.notchWidth ?? spec.softwareIslandWidth
            HStack {
                Spacer()
                RecordingCountdown(model: model)
                    .padding(.trailing, WorkbenchTokens.Feedback.countdownInset)
            }
            .frame(width: width, height: spec.voiceBelow)
            .offset(y: model.metrics.safeAreaTop)
            .opacity(shown ? 1 : 0)
            .animation(WorkbenchTokens.Feedback.countdownIn, value: shown)
            .allowsHitTesting(false)
            .accessibilityHidden(!shown)
        }
        // Feedback #19: with the words' review off, the chosen chat's agent at the bar's right; a
        // click opens where it goes (Dispatch's suggestions and every chat) and the model, under it.
        .overlay(alignment: .top) {
            let shown = state == .v2Voice && !model.v2ReviewBeforeSend && !model.stackExpanded
            let spec = WorkbenchTokens.Island.spec
            let notch = NotchGeometry.notchRect(metrics: model.metrics, spec: spec)
            ZStack(alignment: .top) {
                // Closed, at the bar's right; open, at the right of Dispatch's width (the stack has
                // gone to the left).
                HStack {
                    Spacer()
                    V2RouteButton(model: model)
                }
                .padding(.trailing, model.v2RouteOpen ? 0 : WorkbenchTokens.Board.routeInset)
                .frame(width: model.v2RouteOpen ? V2Geometry.contentWidth : notch.width, height: spec.voiceBelow)
                .offset(y: notch.height)
                .animation(WorkbenchTokens.V2.resize, value: model.v2RouteOpen)
                if model.v2RouteOpen {
                    V2RouteSheet(model: model)
                        .panelScheme()
                        .offset(y: notch.height + spec.voiceBelow + WorkbenchTokens.V2.gap + WorkbenchTokens.Native.panelGap)
                        .transition(.opacity)
                }
            }
            .panelScheme()
            .modifier(VoiceContentTransition(progress: shown ? 1 : 0))
            .animation(v2Content(shown), value: shown)
            .animation(WorkbenchTokens.V2.resize, value: model.v2RouteOpen)
            .allowsHitTesting(shown)
            .accessibilityHidden(!shown)
        }
        .overlay(alignment: .top) {
            let thinking = state == .quickThinking
            AgentActivityContent(model: model, layout: model.agentLayout)
                .modifier(VoiceContentTransition(progress: thinking ? 1 : 0))
                .animation(thinking ? (reduceMotion ? .easeOut(duration: WorkbenchTokens.Motion.reduceMotionFade)
                                                    : WorkbenchTokens.Thinking.contentIn)
                                    : bandAnimation(shown: false), value: state)
                .allowsHitTesting(thinking && model.agentAction == .needsYou)
                .accessibilityHidden(!thinking)
        }
        // Choose chat: the request, its referents and the chat Fovea picked; opened, the chats by
        // agent. An overlay too, for the same reason.
        .overlay(alignment: .top) {
            let choosing = state.choosingChat
            ChooseChatContent(model: model, layout: model.chatLayout)
                .modifier(VoiceContentTransition(progress: choosing ? 1 : 0))
                .animation(choosing ? (reduceMotion ? .easeOut(duration: WorkbenchTokens.Motion.reduceMotionFade)
                                                    : WorkbenchTokens.Chat.contentIn)
                                    : bandAnimation(shown: false), value: choosing)
                .allowsHitTesting(choosing)
                .accessibilityHidden(!choosing)
        }
        // The Agent panel: the Agent tasks, at a glance and in reach. An overlay too.
        .overlay(alignment: .top) {
            let panel = state == .agentPanel
            AgentPanelContent(model: model, layout: model.panelLayout)
                .modifier(VoiceContentTransition(progress: panel ? 1 : 0))
                .animation(panel ? (reduceMotion ? .easeOut(duration: WorkbenchTokens.Motion.reduceMotionFade)
                                                 : WorkbenchTokens.Panel.contentIn)
                                 : bandAnimation(shown: false), value: panel)
                .allowsHitTesting(panel)
                .accessibilityHidden(!panel)
        }
        // Dispatch Version 2: Choose chat, the control board, the expanded chat (its voice input
        // is the aura, drawn by AgentEdgeLayer). Overlays too, each fading in a beat behind the shape.
        // Dispatch Version 2 transcribing: the words, over the aura filling the bar's edge.
        .overlay(alignment: .top) {
            let shown = state == .v2Transcribing
            ThinkingText(still: reduceMotion || model.snapshotMode, label: "Transcribing")
                .frame(width: model.metrics.notchWidth ?? WorkbenchTokens.Island.spec.softwareIslandWidth,
                       height: WorkbenchTokens.Island.spec.voiceBelow)
                .offset(y: model.metrics.safeAreaTop)
                .modifier(VoiceContentTransition(progress: shown ? 1 : 0))
                .animation(v2Content(shown), value: shown)
                .allowsHitTesting(false)
                .accessibilityHidden(!shown)
        }
        .overlay(alignment: .top) {
            let shown = state == .v2Send
            V2SendContent(model: model, layout: model.v2SendLayout)
                .modifier(VoiceContentTransition(progress: shown ? 1 : 0))
                .animation(v2Content(shown), value: shown)
                .allowsHitTesting(shown)
                .accessibilityHidden(!shown)
        }
        .overlay(alignment: .top) {
            let shown = state == .v2Board
            V2BoardContent(model: model, layout: model.v2BoardLayout)
                .modifier(VoiceContentTransition(progress: shown ? 1 : 0))
                .animation(v2Content(shown), value: shown)
                .allowsHitTesting(shown)
                .accessibilityHidden(!shown)
        }
        .overlay(alignment: .top) {
            let shown = state == .v2Chat
            V2ChatContent(model: model, layout: model.v2ChatLayout)
                .modifier(VoiceContentTransition(progress: shown ? 1 : 0))
                .animation(v2Content(shown), value: shown)
                .allowsHitTesting(shown)
                .accessibilityHidden(!shown)
        }
        .background(alignment: .top) {
            PasteMeasure(text: model.transcript.isEmpty ? WorkbenchModel.sampleTranscript : model.transcript,
                         width: model.pasteLayout.textWidth, model: model)
            ChatMeasure(model: model)
        }
        // The outline (Original), or the black island and the glass panel under it (Native,
        // docs/island/NATIVE.md).
        .modifier(IslandSurface(model: model, layout: layout))
    }
}

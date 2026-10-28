import SwiftUI
import FoveaCore
import FoveaLook
import FoveaKit

/// Fovea's surface at the notch, drawn for the chosen state with Core's geometry, so every
/// state meets the Mac the same way: concave ears fuse the top corners into the menu bar,
/// the sides are straight, the bottom corners convex (docs/island/VOICE_BAR.md).
///
/// Voice flow is the Listening Flowing Bar. Captures stack at its left and the waveform
/// moves right to make room; hovering the stack fans it to the right, clicking it opens the
/// island to lay every capture out in one row, flowing right from the first, numbered, swiped
/// sideways past the island's width (docs/island/REFERENT_STACK.md; Oct 15 review, VF04).
///
/// Everything keeps one identity and is placed by `StackLayout`: the waveform, each card,
/// the stack's control and the close pill. Each animatable part carries its own animation,
/// set by the model with the change, so the outline, the waveform and the cards each move on
/// their own curve whoever made the change (a key, the panel, a click, a check).
struct MockIsland: View {
    let model: WorkbenchModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    private func contentAnimation(for state: NotchState) -> Animation {
        bandAnimation(shown: state.collects)
    }

    /// A band's content coming in with the shape (Oct 21, Ryan, "simpler is better": no beat
    /// behind it), or going out quicker. Under Reduce Motion, `Spring.fade` (the strong ease-out).
    private func bandAnimation(shown: Bool) -> Animation {
        if reduceMotion { return WorkbenchTokens.Spring.fade }
        return shown ? WorkbenchTokens.Motion.content : WorkbenchTokens.Motion.contentOut
    }

    /// Dispatch Version 2's content: in with the shape, out quicker.
    private func v2Content(_ shown: Bool) -> Animation {
        if reduceMotion { return WorkbenchTokens.Spring.fade }
        return shown ? WorkbenchTokens.V2.contentIn : bandAnimation(shown: false)
    }

    /// A live capture's slot, or where a removed one was, fading where it was (Oct 21, Ryan,
    /// "simpler is better": it no longer shrinks as it goes).
    private func placement(for referent: CapturedReferent, fullIndex: Int, liveIndex: [UUID: Int],
                           layout: StackLayout, departing: StackLayout?) -> StackLayout.Card? {
        if let i = liveIndex[referent.id] {
            return layout.cards.indices.contains(i) ? layout.cards[i] : nil
        }
        guard let departing, departing.cards.indices.contains(fullIndex) else { return nil }
        var card = departing.cards[fullIndex]
        card.opacity = 0
        return card
    }

    var body: some View {
        let state = model.notchState
        // The waveform: Voiceflow's, and on Dispatch's bar too, a new request or asking more in a
        // session (Oct 9, evening: talking to the notch looks the same every time, the bar flowing
        // as you speak; Oct 27: Dispatch's aura is gone, the waveform is all there is).
        // Oct 17, Ryan: a file dragged over the bar: its drop state in place of the waveform.
        let dropping = model.fileDropTargeted && !model.stackExpanded
        let voice = (state == .voiceFlow || state == .v2Voice) && model.barNotice == nil && !dropping
        let layout = model.stackLayout
        let maxH = WorkbenchTokens.Island.waveformMaxHeight
        let T = WorkbenchTokens.Referents.self
        ZStack(alignment: .top) {
            Color.clear

            // Oct 21, perf: the level read in a view of its own (`VoiceBarLevel`). Oct 27: Wings draws
            // every state of the bar (Wings.swift); today's bands are left for the Workbench's Original.
            let designed = layout.wings != nil
            VoiceBarLevel(model: model, paused: !voice || designed)
                .frame(width: WorkbenchTokens.Island.waveformSpan, height: maxH)
                .modifier(VoiceContentTransition(progress: voice && !designed ? 1 : 0))
                .animation(contentAnimation(for: state), value: state)
                .accessibilityHidden(!voice || designed)
                .offset(x: layout.waveform.x, y: layout.waveform.y - maxH / 2)
                .animation(model.islandAnimation, value: layout.waveform)

            // Wings over a panel, attached: the bar black on the glass, from the top edge, as the
            // notch is drawn on it (floating, and the strip, the surface draws it as its island).
            if let bar = layout.wingsBar, WorkbenchTokens.panelsHangFromTop, !layout.floats {
                WingsBarOnGlass(bar: bar)
                    .transition(.opacity)
            }

            if layout.wings != nil, model.dropZoneOpen {
                DropZoneCard(model: model, layout: layout)
                    .transition(.opacity)
            }

            // Oct 28, Ryan: a little aurora in the accent in the bar's bottom-right corner while it
            // listens, Voiceflow and Dispatch alike, under the waveform (Wings.swift).
            if layout.wings != nil {
                let A = WorkbenchTokens.Aurora.self
                let listening = model.auroraShows
                let bar = layout.wingsBar ?? layout.outline
                let room = CGSize(width: A.width, height: bar.size.height)
                WingsAurora(model: model, height: room.height, paused: !listening)
                    .modifier(BarSlot(at: CGPoint(x: bar.size.width / 2 - bar.topRadius - room.width / 2, y: room.height / 2),
                                      size: room, half: layout.outline.size.width / 2, fromEdge: true))
                    .opacity(listening ? 1 : 0)
                    .animation(.easeInOut(duration: A.fade), value: listening)
                    .transition(.opacity)
            }

            // Oct 27, Ryan: Wings' two sides, each placed from the wing's own edge, which moves frame
            // by frame, so they come out from under the notch with it and never get ahead of it.
            if let pose = layout.wings, let left = layout.wingsLeft, let right = layout.wingsRight {
                let half = layout.outline.size.width / 2
                WingsLeftView(model: model, pose: pose, size: left.size)
                    .modifier(BarSlot(at: CGPoint(x: left.midX, y: left.midY), size: left.size, half: half, fromEdge: true))
                    .transition(.opacity)
                WingsRightView(model: model, pose: pose, size: right.size, shown: true)
                    .modifier(BarSlot(at: CGPoint(x: right.midX, y: right.midY), size: right.size, half: half, fromEdge: true))
                    .transition(.opacity)
            }

            // Transcribing and Cancelled share the bar: each band crossfades in on its own.
            let spec = WorkbenchTokens.Island.spec
            let bandWidth = model.metrics.notchWidth ?? spec.softwareIslandWidth
            let transcribing = state == .transcribing, cancelled = state == .cancelled, noSpeech = state == .noSpeech
            TranscribingBand(model: model)
                .frame(width: bandWidth, height: spec.voiceBelow)
                .modifier(VoiceContentTransition(progress: transcribing && !designed ? 1 : 0))
                .animation(bandAnimation(shown: transcribing), value: state)
                .offset(y: model.metrics.safeAreaTop)
                .allowsHitTesting(false)
                .accessibilityHidden(!transcribing)
            CancelledBand(model: model)
                .frame(width: bandWidth, height: spec.voiceBelow)
                .modifier(VoiceContentTransition(progress: cancelled && !designed ? 1 : 0))
                .animation(bandAnimation(shown: cancelled), value: state)
                .contentShape(Rectangle())
                .onHover { model.setUndoHover($0) }
                .offset(y: model.metrics.safeAreaTop)
                .allowsHitTesting(cancelled && !designed)
                .accessibilityHidden(!cancelled || designed)
            NoSpeechBand()
                .frame(width: bandWidth, height: spec.voiceBelow)
                .modifier(VoiceContentTransition(progress: noSpeech && !designed ? 1 : 0))
                .animation(bandAnimation(shown: noSpeech), value: state)
                .offset(y: model.metrics.safeAreaTop)
                .allowsHitTesting(false)
                .accessibilityHidden(!noSpeech)

            // Every capture, the fading ones included, each placed by id: a live one in its
            // slot, a removed one where it was, fading while the rest close up.
            let live = model.liveReferents
            let liveIndex = Dictionary(uniqueKeysWithValues: live.enumerated().map { ($0.element.id, $0.offset) })
            let departing = model.removing.isEmpty ? nil : model.departingLayout
            ForEach(Array(model.referents.enumerated()), id: \.element.id) { fullIndex, referent in
                if let card = placement(for: referent, fullIndex: fullIndex, liveIndex: liveIndex, layout: layout, departing: departing) {
                    let isLive = liveIndex[referent.id] != nil
                    let looking = model.inspectedId
                    let reachable = model.stackExpanded && isLive && (looking == nil || looking == referent.id)
                    let hovered = reachable && model.hoveredReferent == referent.id
                    // Oct 15 review, VF04/QA02: its number in the order taken (what "the second one" binds to).
                    let number = (liveIndex[referent.id] ?? fullIndex) + 1
                    ReferentCard(referent: referent)
                        .modifier(CardPlacement(vector: card.vector,
                                                remove: reachable ? { model.removeReferent(referent.id) } : nil,
                                                removeVisible: hovered,
                                                number: number, otherDisplay: referent.otherDisplay,
                                                badgesVisible: model.stackExpanded && isLive))
                        .animation(model.cardAnimation(index: liveIndex[referent.id] ?? fullIndex, count: live.count,
                                                       departing: !isLive,
                                                       inspected: referent.id == model.inspectTransitionId),
                                   value: card)
                        .opacity(model.landing.contains(referent.id) || ((model.barNotice != nil || dropping) && !model.stackExpanded) ? 0 : 1)
                        .allowsHitTesting(reachable)
                        .onHover { inside in
                            if inside { model.hoveredReferent = referent.id }
                            else if model.hoveredReferent == referent.id { model.hoveredReferent = nil }
                        }
                        // A click looks closer; on the one being looked at, it goes back.
                        .onTapGesture { model.inspect(looking == referent.id ? nil : referent.id) }
                        .help(referent.whereTaken)
                        .zIndex(card.z + (hovered ? 100 : 0))
                        .accessibilityLabel("\(referent.kind.label) \(number), from \(referent.whereTaken)")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction(named: "Remove") { model.removeReferent(referent.id) }
                }
            }

            if let hit = layout.stackHit {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: hit.width, height: hit.height)
                    .onHover { model.setStackHovered($0) }
                    // Oct 27: opened, the bar's left puts the strip away again.
                    .onTapGesture { model.setExpanded(!model.stackExpanded) }
                    .linkCursor()
                    .offset(x: hit.midX, y: hit.minY)
                    .zIndex(200)
                    .accessibilityElement()
                    .accessibilityLabel("\(model.referents.count) screenshots")
                    .accessibilityHint(model.stackExpanded ? "Puts the screenshots away" : "Shows every screenshot")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { model.setExpanded(!model.stackExpanded) }
            }

            // Oct 15 review, VF04: "+N" on the stack, the referents hidden behind the three that show.
            if let more = layout.more {
                ReferentMoreChip(count: layout.moreCount)
                    // Oct 26: on a listening bar design's black, as on the black island.
                    .environment(\.colorScheme, layout.wings != nil ? .dark : scheme)
                    .offset(x: more.midX, y: more.minY)
                    .animation(model.cardAnimation(index: T.maxLayers - 1, count: T.maxLayers), value: more)
                    .opacity(model.barNotice == nil && !dropping ? 1 : 0)
                    .allowsHitTesting(false)
                    .transition(.opacity.animation(T.numberFade))
            }

            // Oct 15 review, VF04: the opened row scrolls sideways; its thumb says where it is.
            if let thumb = layout.scrollThumb {
                ReferentScrollThumb()
                    .frame(width: thumb.width, height: thumb.height)
                    .panelScheme()
                    .offset(x: thumb.midX, y: thumb.minY)
                    .animation(model.islandAnimation, value: thumb)
                    .allowsHitTesting(false)
                    .transition(.asymmetric(insertion: .opacity.animation(T.closeIn),
                                            removal: .opacity.animation(T.closeOut)))
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
                // Oct 15 review, VF04/VF05: the close look names its number, and the other display.
                let number = (model.liveReferents.firstIndex { $0.id == id } ?? 0) + 1
                Text("\(number) · \(referent.whereTaken)")
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
        // Oct 26: a listening bar design shorter than today's bands (Wings, Droplets: the notch's
        // height) keeps them from making the content taller than the bar, which the surface's
        // bottom alignment would push up.
        .frame(height: layout.wings != nil ? layout.outline.size.height : nil, alignment: .top)
        .animation(bandAnimation(shown: layout.wings != nil), value: layout.wings)
        // Paste not found: the island grows to hold the transcript, its words a beat behind the
        // shape. An overlay, so its height never sizes the island's content: as a child of the
        // stack, it made the stack taller than the bar, and the outline's bottom alignment
        // pushed every state's content up.
        .overlay(alignment: .top) {
            let paste = state == .pasteNotFound && layout.wings == nil
            PasteNotFoundContent(model: model, layout: model.pasteLayout)
                .bandShown(paste) // Oct 21, perf
                .modifier(VoiceContentTransition(progress: paste ? 1 : 0))
                .animation(paste ? (reduceMotion ? WorkbenchTokens.Spring.fade
                                                 : WorkbenchTokens.Paste.contentIn)
                                 : bandAnimation(shown: false), value: state)
                .offset(y: model.metrics.safeAreaTop)
                .allowsHitTesting(paste)
                .accessibilityHidden(!paste)
        }
        // Thinking: the agent at work, over the island the same way (an overlay never sizes it).
        // Feedback #2: the notice in place of the bar.
        .overlay(alignment: .top) {
            let shown = state == .voiceError && layout.wings == nil
            VoiceErrorContent(model: model)
                .bandShown(shown) // Oct 21, perf
                .modifier(VoiceContentTransition(progress: shown ? 1 : 0))
                .animation(shown ? (reduceMotion ? WorkbenchTokens.Spring.fade
                                                 : WorkbenchTokens.Paste.contentIn)
                                 : bandAnimation(shown: false), value: shown)
                .offset(y: model.metrics.safeAreaTop)
                .allowsHitTesting(shown)
                .accessibilityHidden(!shown)
        }
        // …and inside the listening bar, which listens on (#2), and the last minute at its right (#4).
        .overlay(alignment: .top) {
            let shown = state.collects && model.barNotice != nil && !model.stackExpanded && layout.wings == nil
            BarNoticeBand(model: model)
                .bandShown(shown) // Oct 21, perf
                .frame(width: WorkbenchTokens.Feedback.barNoticeWidth - 2 * WorkbenchTokens.Island.spec.compactTopRadius,
                       height: WorkbenchTokens.Island.spec.voiceBelow)
                .modifier(VoiceContentTransition(progress: shown ? 1 : 0))
                .animation(bandAnimation(shown: shown), value: shown)
                .offset(y: model.metrics.safeAreaTop)
                .allowsHitTesting(shown)
                .accessibilityHidden(!shown)
        }
        .overlay(alignment: .top) {
            let shown = state.collects && model.inLastMinute && model.barNotice == nil && !model.stackExpanded && layout.wings == nil
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
            // Oct 27: in Wings the agent is at the bar's right (Wings.swift) and only the sheet is here.
            let wings = layout.wings != nil
            let shown = state == .v2Voice && !model.v2ReviewBeforeSend && !model.stackExpanded && !model.v2AsksOver
                && (!wings || model.v2RouteOpen)
            let spec = WorkbenchTokens.Island.spec
            let notch = NotchGeometry.notchRect(metrics: model.metrics, spec: spec)
            ZStack(alignment: .top) {
                // Closed, at the bar's right; open, at the right of Dispatch's width (the stack has
                // gone to the left).
                if !wings {
                    HStack {
                        Spacer()
                        V2RouteButton(model: model)
                    }
                    .padding(.trailing, model.v2RouteOpen ? 0 : WorkbenchTokens.Board.routeInset)
                    .frame(width: model.v2RouteOpen ? V2Geometry.contentWidth : notch.width, height: spec.voiceBelow)
                    .offset(y: notch.height)
                    .animation(model.v2RouteOpen ? WorkbenchTokens.V2.resize : WorkbenchTokens.V2.fold, value: model.v2RouteOpen)
                }
                if model.v2RouteOpen {
                    V2RouteSheet(model: model)
                        .panelScheme()
                        .offset(y: notch.height + (wings ? 0 : spec.voiceBelow) + WorkbenchTokens.V2.gap + WorkbenchTokens.Native.contentDrop)
                        .transition(.opacity)
                }
            }
            .panelScheme()
            .bandShown(shown) // Oct 21, perf
            .modifier(VoiceContentTransition(progress: shown ? 1 : 0))
            .animation(v2Content(shown), value: shown)
            .animation(model.v2RouteOpen ? WorkbenchTokens.V2.resize : WorkbenchTokens.V2.fold, value: model.v2RouteOpen)
            .allowsHitTesting(shown)
            .accessibilityHidden(!shown)
        }
        .overlay(alignment: .top) {
            let thinking = state == .quickThinking
            AgentActivityContent(model: model, layout: model.agentLayout)
                .bandShown(thinking) // Oct 21, perf
                .modifier(VoiceContentTransition(progress: thinking ? 1 : 0))
                .animation(thinking ? (reduceMotion ? WorkbenchTokens.Spring.fade
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
                .bandShown(choosing) // Oct 21, perf: "Choosing chat" breathes only while it shows
                .modifier(VoiceContentTransition(progress: choosing ? 1 : 0))
                .animation(choosing ? (reduceMotion ? WorkbenchTokens.Spring.fade
                                                    : WorkbenchTokens.Chat.contentIn)
                                    : bandAnimation(shown: false), value: choosing)
                .allowsHitTesting(choosing)
                .accessibilityHidden(!choosing)
        }
        // The Agent panel: the Agent tasks, at a glance and in reach. An overlay too.
        .overlay(alignment: .top) {
            let panel = state == .agentPanel
            AgentPanelContent(model: model, layout: model.panelLayout)
                .bandShown(panel) // Oct 21, perf: the working rows' rings and typing
                .modifier(VoiceContentTransition(progress: panel ? 1 : 0))
                .animation(panel ? (reduceMotion ? WorkbenchTokens.Spring.fade
                                                 : WorkbenchTokens.Panel.contentIn)
                                 : bandAnimation(shown: false), value: panel)
                .allowsHitTesting(panel)
                .accessibilityHidden(!panel)
        }
        // Dispatch Version 2: Choose chat, the control board, the expanded chat. Overlays too, each
        // fading in with the shape.
        // Dispatch Version 2 transcribing: the words (Oct 27: the aura that filled the bar's edge
        // under them is gone).
        .overlay(alignment: .top) {
            let shown = state == .v2Transcribing && layout.wings == nil
            ThinkingText(label: L("Transcribing"))
                .frame(width: model.metrics.notchWidth ?? WorkbenchTokens.Island.spec.softwareIslandWidth,
                       height: WorkbenchTokens.Island.spec.voiceBelow)
                .offset(y: model.metrics.safeAreaTop)
                .modifier(VoiceContentTransition(progress: shown ? 1 : 0))
                .animation(v2Content(shown), value: shown)
                .allowsHitTesting(false)
                .accessibilityHidden(!shown)
        }
        .overlay(alignment: .top) {
            // Oct 17, Ryan: a file dragged over Choose chat: its drop state in place of the request.
            let shown = state == .v2Send && !model.fileDropTargeted
            V2SendContent(model: model, layout: model.v2SendLayout)
                .bandShown(shown) // Oct 21, perf
                .modifier(VoiceContentTransition(progress: shown ? 1 : 0))
                .animation(v2Content(shown), value: shown)
                .allowsHitTesting(shown)
                .accessibilityHidden(!shown)
        }
        .overlay(alignment: .top) {
            let shown = state == .v2Board
            V2BoardContent(model: model, layout: model.v2BoardLayout)
                .bandShown(shown) // Oct 21, perf: the sessions' rings and clocks while it's open
                .modifier(VoiceContentTransition(progress: shown ? 1 : 0))
                .animation(v2Content(shown), value: shown)
                .allowsHitTesting(shown)
                .accessibilityHidden(!shown)
        }
        .overlay(alignment: .top) {
            // Asking more by voice, the session stays, under the bar's band (Oct 9, evening).
            let over = model.v2AsksOver && !model.stackExpanded
            let shown = state == .v2Chat || over
            V2ChatContent(model: model, layout: model.v2ChatLayout)
                .bandShown(shown) // Oct 21, perf
                .offset(y: over && layout.wings == nil ? WorkbenchTokens.Island.spec.voiceBelow : 0)
                .animation(model.islandAnimation, value: over)
                .modifier(VoiceContentTransition(progress: shown ? 1 : 0))
                .animation(v2Content(shown), value: shown)
                .allowsHitTesting(shown)
                .accessibilityHidden(!shown)
        }
        // Oct 26, Ryan: a session popping up by itself, needing you or done (Feedback/V2Alert.swift).
        .overlay(alignment: .top) {
            let shown = state == .v2Alert
            V2AlertContent(model: model)
                .bandShown(shown)
                .modifier(VoiceContentTransition(progress: shown ? 1 : 0))
                .animation(v2Content(shown), value: shown)
                .allowsHitTesting(shown)
                .accessibilityHidden(!shown)
        }
        // Oct 17, Ryan: a file dragged over the notch, listening or on Choose chat: the bar (or the
        // panel) lights as a well and says what letting go does.
        .overlay(alignment: .top) {
            let shown = model.fileDropTargeted && (state.collects || state == .v2Send) && layout.wings == nil
            let F = WorkbenchTokens.Feedback.self
            let outline = layout.outline
            let notch = NotchGeometry.notchRect(metrics: model.metrics, spec: WorkbenchTokens.Island.spec)
            let gap = model.notchSurface == .panel ? WorkbenchTokens.Native.panelGap : 0
            FileDropWell(model: model)
                .frame(width: max(0, outline.size.width - 2 * outline.topRadius - 2 * F.dropWellInset),
                       height: max(0, outline.size.height - notch.height - gap - 2 * F.dropWellInset))
                .offset(y: notch.height + gap + F.dropWellInset)
                .opacity(shown ? 1 : 0)
                .animation(F.dropIn, value: shown)
                .allowsHitTesting(false)
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

/// Oct 26: a listening bar design's orb or waveform at its place (x from the island's center, y
/// from its top): beside the notch, measured from the shape's nearer side, which follows the
/// shape's width as it springs; under the notch, from the center.
/// Oct 27, Ryan: files dragged near the notch while it listens: under the bar, clear of the
/// hardware notch, a well with dashes says where to let go; over it, the well lights in the accent
/// and says how many will join.
private struct DropZoneCard: View {
    let model: WorkbenchModel
    let layout: StackLayout

    var body: some View {
        let C = WorkbenchTokens.Capture.self
        let V = WorkbenchTokens.V2.self
        let notch = NotchGeometry.notchRect(metrics: model.metrics, spec: WorkbenchTokens.Island.spec)
        let over = model.fileDropTargeted
        let accent = model.accent.color
        let well = RoundedRectangle(cornerRadius: C.dropWellRadius, style: .continuous)
        HStack(spacing: 8) {
            Image(systemName: model.fileDropCount > 1 ? "doc.on.doc" : "tray.and.arrow.down")
                .font(.system(size: C.dropGlyph, weight: .medium))
            Text(over ? (model.fileDropCount > 1 ? L("Let go to add all \(model.fileDropCount)") : L("Let go to add it"))
                      : L("Drop files here"))
                .font(V.browseFont)
        }
        .foregroundStyle(over ? accent : V.subColor)
        .frame(width: C.dropZoneWidth - 2 * C.dropZonePadding, height: C.dropZoneHeight)
        .background(well.fill(over ? accent.opacity(C.dropWellFill) : .clear))
        .overlay(well.strokeBorder(over ? accent : C.dropWellIdle,
                                   style: StrokeStyle(lineWidth: C.dropWellStroke, dash: over ? [] : C.dropWellDash)))
        .offset(y: notch.height + WorkbenchTokens.Native.floatGap + C.dropZonePadding)
        .panelScheme()
        .animation(WorkbenchTokens.Spring.hover, value: over)
        .allowsHitTesting(false)
        .accessibilityLabel(over ? L("Let go to add the files") : L("Drop files here"))
    }
}

/// Wings over an attached panel: the bar black on the glass, square at the top edge, its foot
/// rounded as the bar's.
private struct WingsBarOnGlass: View {
    let bar: StackLayout.Outline

    var body: some View {
        IslandShape(topRadius: 0, bottomRadius: bar.bottomRadius, earY: 0)
            .fill(WorkbenchTokens.Island.surface)
            .frame(width: max(0, bar.size.width - 2 * bar.topRadius), height: bar.size.height)
            .allowsHitTesting(false)
    }
}

private struct BarSlot: ViewModifier {
    let at: CGPoint
    let size: CGSize
    /// Half the island's width, at its target.
    let half: CGFloat
    let fromEdge: Bool

    func body(content: Content) -> some View {
        let left = at.x < 0
        if fromEdge {
            content
                .frame(width: size.width, height: size.height)
                .padding(left ? .leading : .trailing, max(0, half - abs(at.x) - size.width / 2))
                .frame(maxWidth: .infinity, alignment: left ? .leading : .trailing)
                .offset(y: at.y - size.height / 2)
        } else {
            content
                .frame(width: size.width, height: size.height)
                .offset(x: at.x, y: at.y - size.height / 2)
        }
    }
}

/// Oct 21, perf: the waveform reading the voice's level itself. Read in MockIsland's body, the
/// level (the meter, many times a second while listening) re-ran the whole island's body on every
/// change: every panel's layout and its words looked up again. While the waveform's own clock
/// runs (40 frames a second) it reads the level on each frame, unobserved, so a new level (30 a
/// second, out of step) no longer lays the screen-sized island out again between them; held still
/// (paused, Reduce Motion, a snapshot) it follows the level as before.
private struct VoiceBarLevel: View {
    let model: WorkbenchModel
    let paused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let ticking = !paused && !model.snapshotMode && !reduceMotion
        VoiceBarView(level: ticking ? model.drawnLevel : model.audioLevel,
                     liveLevel: ticking ? { [model] in model.drawnLevel } : nil,
                     still: model.snapshotMode, paused: paused)
    }
}

// Oct 21, perf: every band above is always there, faded to nothing when it isn't the state's; what
// moves inside one (a TimelineView, a repeating symbol effect) kept the screen-sized layer laying
// itself out on every frame with the island at rest (the panel even ordered out): ~6–12% CPU doing
// nothing. Each band now says whether it's showing, and its moving parts hold still once it has
// faded out (`Motion.bandLinger` after), moving again the moment it shows. Nothing seen changes.
private struct IslandBandShownKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Oct 21, perf: the band this view is in is showing (or still fading out). Moving parts pause
    /// their clocks while it's false.
    var islandBandShown: Bool {
        get { self[IslandBandShownKey.self] }
        set { self[IslandBandShownKey.self] = newValue }
    }
}

/// Oct 21, perf: a band's `islandBandShown`, true while `shown` and for `Motion.bandLinger` after.
struct BandShown: ViewModifier {
    let shown: Bool
    @Environment(\.islandBandShown) private var outer
    @State private var lingering = false

    func body(content: Content) -> some View {
        content
            .environment(\.islandBandShown, outer && (shown || lingering))
            .task(id: shown) {
                if shown { lingering = true; return }
                try? await Task.sleep(for: .seconds(WorkbenchTokens.Motion.bandLinger))
                if !Task.isCancelled { lingering = false }
            }
    }
}

extension View {
    /// Oct 21, perf: this band's moving parts run only while it shows (`BandShown`).
    func bandShown(_ shown: Bool) -> some View { modifier(BandShown(shown: shown)) }
}

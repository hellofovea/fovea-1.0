import SwiftUI
import AppKit
import OnboardingCore
import FoveaCore

/// The Island at the notch: black, white at an opacity, the Workbench's springs. Every key in the
/// first run is answered here, never in a picture of it. Bars have fixed sizes (VOICE_BAR.md);
/// cards are measured, so their outline can spring to their content.
struct IslandView: View {
    let model: OnboardingModel
    @State private var measured: CGFloat = 120

    var body: some View {
        let phase = model.island
        let width = IslandMetrics.width(phase, model: model)
        let fixed = IslandMetrics.fixedHeight(phase, model: model)
        let height = fixed ?? (OT.Display.notchHeight + measured)
        let radii = IslandMetrics.radii(phase)
        // Cards and captions sit inside the body, between the ears (the outline is the body plus
        // an ear each side); the bars place their own content.
        let inset = (fixed == nil || phase == .caption || phase == .dragCaption) ? radii.top : 0
        IslandContent(model: model, phase: phase)
            .padding(.horizontal, inset)
            .frame(width: width, height: max(0, height - OT.Display.notchHeight), alignment: .top)
            .padding(.top, OT.Display.notchHeight)
            .modifier(IslandOutline(width: width, height: height, topRadius: radii.top, bottomRadius: radii.bottom) { edge in
                EdgeLight(model: model, phase: phase, edge: edge)
            })
            .background(alignment: .top) {
                if fixed == nil {
                    IslandContent(model: model, phase: phase)
                        .padding(.horizontal, inset)
                        .frame(width: width)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { new in
                            if abs(new - measured) > 0.5 { model.animate(OT.Motion.open) { measured = new } }
                        }
                }
            }
            .environment(\.colorScheme, .dark)
    }
}

/// Sizes and corners per phase.
@MainActor
enum IslandMetrics {
    /// The voice bar as the shipping geometry has it: the notch's width between its ears, 44 pt
    /// below it.
    static let voice = NotchGeometry.frames(density: .voice, metrics: OT.Display.metrics, spec: OT.Island.spec)

    static func width(_ phase: IslandPhase, model: OnboardingModel) -> CGFloat {
        switch phase {
        case .rest: return OT.Display.notchWidth
        case .caption:
            return captionWidth(model.captionText)
        case .dragCaption:
            // The whole line is the tile: the icon, then the words.
            return captionWidth(model.captionText) + OT.Island.dragIcon + OT.Island.dragIconGap
        case .auraPreview, .voice, .transcribing:
            return voice.width + stackWidth(model)
        case .review: return OT.Island.reviewWidth
        case .board: return OT.Island.boardWidth
        case .session: return OT.Island.sessionWidth
        }
    }

    /// A line's width: measured whole, so the notch doesn't grow letter by letter as it's typed.
    static func captionWidth(_ text: String) -> CGFloat {
        let size = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium)]).size()
        return max(OT.Island.captionWidthMin, ceil(size.width) + 2 * OT.Island.captionPadding + 2 * OT.Island.restTopRadius)
    }

    /// Room at the bar's left for what's been taken.
    static func stackWidth(_ model: OnboardingModel) -> CGFloat {
        model.referents.isEmpty ? 0 : OT.Island.referentHeight * OT.Island.referentAspect + 2 * OT.Island.referentInset + 8
    }

    static func fixedHeight(_ phase: IslandPhase, model: OnboardingModel) -> CGFloat? {
        switch phase {
        case .rest: return OT.Display.notchHeight
        case .caption: return OT.Display.notchHeight + OT.Island.captionHeight
        case .dragCaption: return OT.Display.notchHeight + OT.Island.dragCaptionHeight
        case .auraPreview, .voice, .transcribing: return voice.minHeight
        default: return nil
        }
    }

    /// The measured height for the hover's reach; an estimate before it's measured.
    static func height(_ phase: IslandPhase, model: OnboardingModel) -> CGFloat {
        fixedHeight(phase, model: model) ?? 220
    }

    static func radii(_ phase: IslandPhase) -> (top: CGFloat, bottom: CGFloat) {
        switch phase {
        case .rest: return (OT.Island.restTopRadius, 10)
        case .caption, .dragCaption, .auraPreview, .voice, .transcribing:
            return (voice.topRadius, voice.bottomRadius)
        default: return (OT.Island.openTopRadius, OT.Island.openBottomRadius)
        }
    }
}

/// What the Island holds in each phase, below the notch.
struct IslandContent: View {
    let model: OnboardingModel
    let phase: IslandPhase

    var body: some View {
        Group {
            switch phase {
            case .rest:
                Color.clear.frame(height: 0)
            case .caption:
                TypedText(text: model.captionText, font: OT.Type_.caption, color: OT.Colors.islandText,
                          typing: model.typesLines, alignment: .center)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: OT.Island.captionHeight - 4)
                    .id(model.captionText)
                    .transition(.opacity)
            case .dragCaption:
                DragCaption(model: model)
            case .auraPreview, .voice(.request), .voice(.followUp), .transcribing(.request), .transcribing(.followUp):
                BarBand(model: model, phase: phase)
            case .voice(.dictation), .transcribing(.dictation):
                DictationBand(model: model, phase: phase)
            case .review:
                ReviewCard(model: model)
            case .board:
                BoardCard(model: model)
            case .session:
                SessionCard(model: model)
            }
        }
        .foregroundStyle(OT.Colors.islandText)
    }
}

// MARK: - The bars

/// The Dispatch bar's band: what's been taken at the left; the aura (drawn from the edge) does
/// the rest. Nothing shows which capture key is on: the pointer does (a crosshair for ⌘, the
/// accent arrow for the highlighter), as in the Workbench.
struct BarBand: View {
    let model: OnboardingModel
    let phase: IslandPhase

    var body: some View {
        HStack(spacing: 0) {
            if !model.referents.isEmpty {
                ReferentStack(model: model)
                    .padding(.leading, OT.Island.referentInset + IslandMetrics.voice.topRadius)
            }
            Spacer(minLength: 0)
        }
        .frame(height: OT.Island.voiceBelow)
    }
}

/// Voiceflow's bar: the waveform, white on black; Thinking over a filling line while it writes.
struct DictationBand: View {
    let model: OnboardingModel
    let phase: IslandPhase

    var body: some View {
        Group {
            if case .transcribing = phase {
                VStack(spacing: 6) {
                    Text("Thinking").font(OT.Type_.islandMeta).foregroundStyle(OT.Colors.islandSecondary)
                    GeometryReader { geo in
                        Capsule().fill(OT.Colors.islandFill)
                            .overlay(alignment: .leading) {
                                Capsule().fill(OT.Colors.islandText).frame(width: geo.size.width * model.transcribeProgress)
                            }
                    }
                    .frame(width: 90, height: 3)
                }
            } else {
                Waveform(still: model.options.harness && model.micPhase != .listening,
                         live: (model.step == .microphone && model.micPhase != .heard)
                            || (model.step == .dictation && SpeechInput.available && !model.playing) ? model.micLevel : nil)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: OT.Island.voiceBelow)
    }
}

/// Nine bars that move with a voice (the demo voice: there's no microphone in the prototype).
struct Waveform: View {
    let still: Bool
    /// The microphone's real level, during the mic test; otherwise a voice is played.
    var live: Double? = nil

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 40, paused: still)) { context in
            let t = still ? 2.2 : context.date.timeIntervalSinceReferenceDate
            let level = live ?? DemoVoice.level(t)
            HStack(spacing: OT.Island.waveformBarGap) {
                ForEach(0..<OT.Island.waveformBars, id: \.self) { i in
                    let x = Double(i) / Double(OT.Island.waveformBars - 1) * 2 - 1
                    let bell = exp(-(x * x) / (2 * 0.4 * 0.4))
                    let wobble = 0.75 + 0.25 * sin(t * 11 + Double(i) * 1.7)
                    let h = OT.Island.waveformMinHeight + (OT.Island.waveformMaxHeight - OT.Island.waveformMinHeight) * level * bell * wobble * 1.25
                    Capsule().fill(OT.Colors.islandSolid)
                        .frame(width: OT.Island.waveformBarWidth, height: min(OT.Island.waveformMaxHeight, h))
                }
            }
        }
    }
}

/// The light drawn from the Island's edge: the aura while a request listens or is written up (with
/// the progress filling the edge), nothing otherwise.
struct EdgeLight: View {
    let model: OnboardingModel
    let phase: IslandPhase
    let edge: IslandEdge

    var body: some View {
        switch phase {
        case .auraPreview, .voice(.request), .voice(.followUp):
            AuraLayer(edge: edge, look: model.auraLook, progress: nil, still: model.options.harness)
        case .transcribing(.request), .transcribing(.followUp):
            AuraLayer(edge: edge, look: model.auraLook, progress: model.transcribeProgress, still: model.options.harness)
        default:
            EmptyView()
        }
    }
}

/// The aura: FoveaCaptures' renderer (NotchGlow.swift, copied as AuraGlow.swift), driven by the
/// demo voice, in the look chosen at the start.
struct AuraLayer: View {
    let edge: IslandEdge
    let look: VoiceGlowLook
    let progress: Double?
    let still: Bool
    @State private var engine = VoiceGlowEngine()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / GlowTokens.frameRate, paused: still)) { context in
            Canvas { ctx, _ in
                let frame = still
                    ? engine.still(at: GlowTokens.stillTime, geometry: GlowTokens.wide, reduceMotion: false)
                    : engine.frame(at: context.date, geometry: GlowTokens.wide, reduceMotion: false)
                VoiceGlowRenderer.draw(in: &ctx, edge: edge, frame: frame, look: look)
                if let progress {
                    ctx.stroke(edge.path(inset: 1).trimmedPath(from: 0, to: progress),
                               with: .color(OT.Colors.islandProgress), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
        }
        .frame(width: edge.size.width, height: edge.size.height)
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

/// What's been taken, as a small pile at the bar's left (REFERENT_STACK.md).
struct ReferentStack: View {
    let model: OnboardingModel

    var body: some View {
        let h = OT.Island.referentHeight
        let w = h * OT.Island.referentAspect
        ZStack {
            ForEach(Array(model.referents.suffix(3).reversed().enumerated()), id: \.element.id) { index, referent in
                ReferentThumb(referent: referent, model: model)
                    .frame(width: w, height: h)
                    .clipShape(RoundedRectangle(cornerRadius: OT.Island.referentRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: OT.Island.referentRadius, style: .continuous).strokeBorder(OT.Colors.islandHairline))
                    .scaleEffect(1 - CGFloat(index) * 0.08)
                    .rotationEffect(.degrees(OT.Island.referentRotation[min(index, 2)]))
                    .offset(x: CGFloat(index) * OT.Island.referentLayerOffset)
                    .opacity(index == 0 ? 1 : 0.6)
                    .zIndex(Double(-index))
            }
        }
        .frame(width: w + 8, height: h, alignment: .leading)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }
}

/// One referent's picture: the real picture Fovea took of the screen or part of it, a passage, a
/// file.
struct ReferentThumb: View {
    let referent: TakenReferent
    let model: OnboardingModel
    private static let wallpaper: NSImage? = FoveaResources.url("Photos/coast.jpg").flatMap { NSImage(contentsOf: $0) }

    var body: some View {
        switch referent.kind {
        case .region, .wholeScreen:
            if let image = referent.image {
                Image(nsImage: image).resizable().scaledToFill()
            } else if let wallpaper = Self.wallpaper {
                Image(nsImage: wallpaper).resizable().scaledToFill()
            } else {
                OT.Colors.referentFallback
            }
        case .passage:
            PassageLines(dark: false)
        case .file(let file):
            ZStack {
                OT.Colors.referentFileBack
                Image(nsImage: file.icon).resizable().scaledToFit().padding(3)
            }
        }
    }
}

/// A passage, drawn as a few lines on paper.
struct PassageLines: View {
    let dark: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            (dark ? OT.Colors.passagePaperDark : OT.Colors.passagePaper)
            VStack(alignment: .leading, spacing: 3) {
                ForEach([0.9, 0.7, 0.85, 0.5], id: \.self) { f in
                    Capsule().fill(OT.Colors.passageLine).frame(height: 2).scaleEffect(x: f, anchor: .leading)
                }
            }
            .padding(5)
        }
    }
}

// MARK: - Cards

/// The permissions (Oct 9): only a line under the notch, and the line is the thing to drag: the
/// icon and "Drag me into the list." Picked up, it's Fovea, dragged; dropped on the list, it's in.
struct DragCaption: View {
    let model: OnboardingModel

    var body: some View {
        HStack(spacing: OT.Island.dragIconGap) {
            if let icon = FoveaIcon.image {
                Image(nsImage: icon).resizable().frame(width: OT.Island.dragIcon, height: OT.Island.dragIcon)
                    .opacity(model.tileDrag == nil ? 1 : 0.35)
            }
            TypedText(text: model.captionText, font: OT.Type_.caption, color: OT.Colors.islandText, typing: model.typesLines)
                .lineLimit(1)
                .id(model.captionText)
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: OT.Island.dragCaptionHeight - 4)
        .contentShape(Rectangle())
        .playTarget(.tile, model)
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .named(ScreenSpace.name))
                .onChanged { value in
                    if !model.dragTried { model.dragTried = true }
                    model.tileDrag = value.location
                }
                .onEnded { model.tileDropped(at: $0.location) }
        )
        .onHover { inside in (inside ? NSCursor.openHand : NSCursor.arrow).set() }
        .accessibilityLabel("Fovea. Drag into the list in System Settings.")
    }
}

/// The review card (Choose chat): the request and what it took, the chat Fovea picked, the model,
/// and send. It never sends by itself. The arrow is never disabled by the view: a click always
/// reaches `send()`, which knows whether the task is ready (Oct 9: a card drawn a beat early kept
/// a dim, dead arrow).
struct ReviewCard: View {
    let model: OnboardingModel

    private var sending: Bool { model.readyToSend }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.request?.words ?? "")
                .font(OT.Type_.islandBody)
                .foregroundStyle(OT.Colors.islandText)
                .fixedSize(horizontal: false, vertical: true)
            if let referents = model.request?.referents, !referents.isEmpty {
                HStack(spacing: 6) {
                    ForEach(referents) { referent in
                        ReferentThumb(referent: referent, model: model)
                            .frame(width: OT.Island.thumbSize.width, height: OT.Island.thumbSize.height)
                            .clipShape(RoundedRectangle(cornerRadius: OT.Island.thumbRadius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: OT.Island.thumbRadius, style: .continuous).strokeBorder(OT.Colors.islandHairline))
                    }
                }
            }
            HStack(spacing: 8) {
                Pill(icon: AgentIcon.image(model.agentName), text: OT.Practice.chat, chevron: true)
                Pill(icon: nil, systemIcon: "sparkle", text: "Auto", chevron: true)
                Spacer(minLength: 0)
                Button(action: { model.send() }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(OT.Colors.islandOnSolid)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(OT.Colors.islandSolid))
                }
                .buttonStyle(.plain)
                .opacity(sending ? 1 : 0.3)
                .help("Send (return)")
                .playTarget(.sendArrow, model)
            }
            HStack(spacing: 6) {
                Text("Suggested").font(OT.Type_.islandMeta).foregroundStyle(OT.Colors.islandTertiary)
                Chip(text: OT.Practice.chat, chosen: true)
                Chip(text: "New chat", chosen: false)
            }
        }
        .padding(OT.Island.cardPadding)
    }
}

/// The control board: what was sent, running or done, newest first. It never opens empty.
struct BoardCard: View {
    let model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let running = model.sessions.contains { $0.running }
            Text(running ? "Running" : "Done")
                .font(OT.Type_.islandSection)
                .foregroundStyle(OT.Colors.islandTertiary)
                .padding(.horizontal, 6)
            ForEach(model.sessions.reversed()) { session in
                Button(action: { model.openSessionRow(session.id) }) {
                    HStack(spacing: 10) {
                        AgentMark(name: session.agent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.title).font(OT.Type_.islandTitle).lineLimit(1)
                            Text("\(session.agent) · \(OT.Practice.chat)").font(OT.Type_.islandMeta)
                                .foregroundStyle(OT.Colors.islandSecondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if session.running {
                            Breathing().frame(width: 8, height: 8)
                            Text(model.agentActivity.isEmpty ? "Working" : model.agentActivity)
                                .font(OT.Type_.islandMeta).foregroundStyle(OT.Colors.islandSecondary)
                                .lineLimit(1)
                                .contentTransition(.opacity)
                        } else {
                            Text("now").font(OT.Type_.islandMeta.monospacedDigit()).foregroundStyle(OT.Colors.islandSecondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(height: OT.Island.rowHeight)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(OT.Colors.islandFill.opacity(0.6)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .playTarget(session.id == model.sessions.last?.id ? .sessionRow : nil, model)
            }
        }
        .padding(12)
    }
}

/// A session opened from the board: each ask and its answer, and how to ask more.
struct SessionCard: View {
    let model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let session = model.openSession {
                HStack(spacing: 8) {
                    AgentMark(name: session.agent)
                    Text(session.title).font(OT.Type_.islandTitle).lineLimit(1)
                    Spacer()
                    Button(action: { model.rest() }) {
                        Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(OT.Colors.islandFill))
                    }
                    .buttonStyle(.plain)
                }
                ForEach(Array(session.turns.enumerated()), id: \.offset) { _, turn in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(turn.ask).font(OT.Type_.islandMeta).foregroundStyle(OT.Colors.islandSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let answer = turn.answer {
                            Text(answer).font(OT.Type_.islandBody).foregroundStyle(OT.Colors.islandText)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            HStack(spacing: 6) {
                                Breathing().frame(width: 8, height: 8)
                                Text(model.agentActivity.isEmpty ? "Working" : model.agentActivity).lineLimit(1).font(OT.Type_.islandMeta).foregroundStyle(OT.Colors.islandSecondary)
                            }
                        }
                    }
                }
                if model.step == .followUp, session.task == .packList {
                    HStack(spacing: 6) {
                        ForEach(model.keys.caps(.dictation), id: \.self) { KeyCap(label: $0, lit: model.keysDown.contains($0), accent: model.accentColor, dark: true) }
                        Text("to ask more").font(OT.Type_.islandMeta).foregroundStyle(OT.Colors.islandSecondary)
                    }
                }
            }
        }
        .padding(OT.Island.cardPadding)
    }
}

// MARK: - Small parts

struct Pill: View {
    let icon: NSImage?
    var systemIcon: String? = nil
    let text: String
    var chevron = false

    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(nsImage: icon).resizable().frame(width: 14, height: 14).clipShape(RoundedRectangle(cornerRadius: 3)) }
            if let systemIcon { Image(systemName: systemIcon).font(.system(size: 10, weight: .semibold)) }
            Text(text).font(OT.Type_.islandMeta).lineLimit(1)
            if chevron { Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)).foregroundStyle(OT.Colors.islandTertiary) }
        }
        .padding(.horizontal, 10)
        .frame(height: OT.Island.pillHeight)
        .background(RoundedRectangle(cornerRadius: OT.Island.pillRadius, style: .continuous).fill(OT.Colors.islandFill))
    }
}

struct Chip: View {
    let text: String
    let chosen: Bool

    var body: some View {
        Text(text)
            .font(OT.Type_.islandMeta)
            .foregroundStyle(chosen ? OT.Colors.islandText : OT.Colors.islandSecondary)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Capsule().fill(chosen ? OT.Colors.islandFill : .clear))
            .overlay(Capsule().strokeBorder(OT.Colors.islandHairline))
    }
}

/// Running, never a spinner: a dot that breathes (1 → 0.45).
struct Breathing: View {
    @State private var dim = false

    var body: some View {
        Circle().fill(OT.Colors.islandSolid)
            .opacity(dim ? 0.45 : 1)
            .onAppear { withAnimation(OT.Motion.breathe) { dim = true } }
    }
}

struct AgentMark: View {
    let name: String

    var body: some View {
        Group {
            if let image = AgentIcon.image(name) {
                Image(nsImage: image).resizable()
            } else {
                Image(systemName: "sparkle").resizable().scaledToFit().padding(4)
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

enum AgentIcon {
    static func image(_ name: String) -> NSImage? {
        let file: String
        switch name {
        case "Claude Code": file = "Destinations/claude-code.png"
        case "Codex": file = "Destinations/codex.png"
        case "Cursor": file = "Destinations/cursor.png"
        default: return FoveaIcon.image
        }
        return FoveaResources.url(file).flatMap { NSImage(contentsOf: $0) }
    }
}

struct IslandButtonStyle: ButtonStyle {
    let primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(primary ? OT.Colors.islandOnSolid : OT.Colors.islandText)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: OT.Island.pillRadius, style: .continuous)
                .fill(primary ? OT.Colors.islandSolid : OT.Colors.islandFill))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

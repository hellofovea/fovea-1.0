import SwiftUI
import AppKit
import CoreText
import FoveaCore
import FoveaKit

// The listening bar: Wings (docs/island/BAR_DESIGNS.md). Oct 26, Ryan picked it from four designs:
// at the menu bar's height, all black, growing sideways from the notch; Oct 27: "i want only the
// wing build, dont have the others", every state of the bar in it, and:
// - Voiceflow: what's taken (or "Listening") at the left, the small waveform at the right, no aurora.
// - Dispatch: the same. Oct 27, later: "abandon the orbs and aurora completely, i think these are too
//   flashy. go with the voiceflow bars for both voiceflow and dispatch." (Its orb, after Oasis HQ's,
//   and the VoiceOrbs studies are gone; docs/island/BAR_DESIGNS.md keeps what was tried.)
// - Oct 28, Ryan, of another app's bar: "make an accent color a little aurora in the same fashion as
//   the attachment on the bottom right of the notch": while it listens, Voiceflow and Dispatch alike,
//   a small light in the accent inside the bar's bottom-right corner (`WingsAurora`).
// - Transcribing: a white ring at the right, filling as the words come.
// - The words in the system face, as a notice's title (Oct 27, later: the website's EB Garamond
//   italic was "flashy"); the website's ellipsis after Transcribing.
// - The other states in Wings too: Cancelled with Undo, no speech, the held words with Copy, a
//   notice with its one way on, the last minute's time, a file dragged over.
// Only what opens below the notch (Choose chat, the board, a session, the opened stack, asking more
// over a session, the route's sheet) is a panel. Oct 27, Ryan ("they should also suit the new notch
// design"): while it listens, Wings stays the bar over the panel that opens under it (the opened
// stack, a session asked more of, the route's sheet), as the board hangs from the notch, where the
// old tall glass bar used to be.

/// The bar's words in the system face, as a notice's title is set. Oct 27, Ryan, pointing at "Mic
/// access off": "for the notch, go with this font. dont have the flashy font of the current
/// thinking, transcribing, etc." (The website's EB Garamond italic, tried that day, is gone.)
enum WingsType {
    static func word(_ size: CGFloat = WorkbenchTokens.Bar.wordSize) -> Font {
        .system(size: size, weight: WorkbenchTokens.Bar.wordWeight)
    }

    /// The same face for measuring.
    static func wordFont(_ size: CGFloat = WorkbenchTokens.Bar.wordSize) -> NSFont {
        .systemFont(ofSize: size, weight: .medium)
    }

    static func width(_ text: String, font: NSFont) -> CGFloat {
        ceil(NSAttributedString(string: text, attributes: [.font: font]).size().width) + 1
    }
}

/// What the bar's left shows.
enum WingsLeft: Equatable {
    /// The state's word; `dots`, the website's ellipsis after it.
    case word(String, dots: Bool)
    /// What's been taken: the pile (drawn by the stack's cards).
    case stack
    /// A notice: its symbol and its title, in its tone.
    case notice(symbol: String, title: String, tone: VoiceError.Tone)
    /// The held words, nowhere to paste them: quoted.
    case quote(String)
}

/// What the bar's right shows.
enum WingsRight: Equatable {
    /// The small waveform, Voiceflow's and Dispatch's.
    case waveform
    /// Transcribing: the ring filling.
    case ring
    /// Cancelled: Undo, its time draining round it.
    case undo
    /// Nowhere to paste: Copy, its time draining round it.
    case copy
    /// A notice's one way on.
    case action(String)
    case none
}

/// The bar as Wings draws a state.
struct WingsPose: Equatable {
    var left: WingsLeft
    var right: WingsRight
    /// The last minute: its time before the right side.
    var countdown = false
    /// Review off: the chosen chat's agent before the orb (a click opens where it goes).
    var route = false
}

extension WorkbenchModel {
    /// The bar as Wings draws the state on show; nil for what opens below the notch as a panel.
    var wingsPose: WingsPose? {
        guard WorkbenchTokens.isNative else { return nil }
        switch notchState {
        case .voiceFlow, .v2Voice:
            if let notice = barNotice {
                return WingsPose(left: .notice(symbol: notice.symbol, title: notice.wingsTitle, tone: notice.tone),
                                 right: notice.action.map { .action($0.wingsLabel) } ?? .waveform)
            }
            // The opened stack: what's taken is open below, the bar says it's listening.
            return WingsPose(left: liveReferents.isEmpty || stackExpanded ? .word(L("Listening"), dots: false) : .stack,
                             right: .waveform, countdown: inLastMinute,
                             route: notchState == .v2Voice && !v2ReviewBeforeSend)
        case .transcribing:
            return WingsPose(left: .word(L("island.thinking", english: "Thinking"), dots: true), right: .ring)
        case .v2Transcribing:
            return WingsPose(left: .word(L("Transcribing"), dots: true), right: .ring)
        case .cancelled:
            return WingsPose(left: .word(L("Cancelled"), dots: false), right: .undo)
        case .noSpeech:
            return WingsPose(left: .word(L("No speech"), dots: false), right: .none)
        case .pasteNotFound:
            return pasteExpanded ? nil : WingsPose(left: .quote(transcript.isEmpty ? Self.sampleTranscript : transcript), right: .copy)
        case .voiceError:
            guard let error = voiceError else { return nil }
            return WingsPose(left: .notice(symbol: error.symbol, title: error.wingsTitle, tone: error.tone),
                             right: error.action.map { .action($0.wingsLabel) } ?? .none)
        default:
            return nil
        }
    }
}

extension WorkbenchModel {
    /// Oct 28: the bar's little aurora shows (`WingsAurora`): while it listens, the waveform at the right.
    var auroraShows: Bool {
        (notchState == .voiceFlow || notchState == .v2Voice) && wingsPose?.right == .waveform
    }

    /// Its colors: the accent, one hue; Multicolor, the glow's Colorful palette (Oct 28, Ryan).
    var auroraColors: [Color] {
        guard accent == .multicolor else { return [WorkbenchTokens.Native.accent] }
        let look = VoiceGlowLook.make(palette: .colorful, hue: 0, spread: 0, drift: false)
        return Array(VoiceGlowRenderer.swatches(look: look).prefix(WorkbenchTokens.Aurora.lights.count))
    }

    /// The level the bar draws: the voice's; while a choice is shown at the notch (no microphone),
    /// a voice that never falls quiet, so the waveform and the aurora move as they will.
    func barLevel(at date: Date) -> Double {
        let A = WorkbenchTokens.Aurora.self
        return previewing ? A.previewLevel + A.previewSwing * sin(date.timeIntervalSinceReferenceDate * A.previewPace)
                          : Double(drawnLevel)
    }

    /// Oct 27: files dragged near the notch while it listens (and over it): the drop zone is open.
    var dropZoneOpen: Bool {
        WorkbenchTokens.isNative && notchState.collects && !stackExpanded && (fileDragNear || fileDropTargeted)
    }

    /// Wings over a panel: the opened stack, a session asked more of, the route's sheet open, the
    /// drop zone.
    var wingsOverPanel: Bool {
        guard wingsPose != nil else { return false }
        switch notchState {
        case .voiceFlow, .v2Voice:
            return stackExpanded || v2AsksOver || (notchState == .v2Voice && !v2ReviewBeforeSend && v2RouteOpen) || dropZoneOpen
        case .v2Transcribing:
            return v2AsksOver
        default:
            return false
        }
    }

    /// The bar over its panel: the panel's outline (never narrower than the bar), the bar's own
    /// kept in `wingsBar`; opened, the captures laid out in the panel (`opened`, the stack's own
    /// layout) and the bar's pile put away.
    func wingsOver(_ bar: StackLayout, opened: StackLayout) -> StackLayout {
        var layout = bar
        layout.wingsBar = bar.outline
        if stackExpanded {
            layout.cards = opened.cards
            layout.more = nil
            layout.moreCount = 0
            // Oct 27: the bar's left ("Listening") puts the strip away, as Esc does.
            layout.stackHit = bar.wingsLeft
            layout.floats = opened.floats
            layout.close = opened.close
            layout.caption = opened.caption
            layout.rows = opened.rows
            layout.viewport = opened.viewport
            layout.scrollMax = opened.scrollMax
            layout.scroll = opened.scroll
            layout.scrollThumb = opened.scrollThumb
            layout.outline = opened.outline
        } else if dropZoneOpen {
            // Oct 27: a file drag near: the drop zone floating under the bar, clear of the notch.
            let C = WorkbenchTokens.Capture.self
            let spec = WorkbenchTokens.Island.spec
            let notch = NotchGeometry.notchRect(metrics: metrics, spec: spec)
            layout.outline = StackLayout.Outline(
                size: CGSize(width: C.dropZoneWidth + 2 * spec.expandedTopRadius,
                             height: notch.height + WorkbenchTokens.Native.floatGap + C.dropZoneHeight + 2 * C.dropZonePadding),
                topRadius: spec.expandedTopRadius, bottomRadius: C.dropZoneRadius)
            layout.floats = true
        } else if v2AsksOver {
            // The session where it was, the bar beside the notch over it.
            layout.outline = v2ChatLayout.outline
        } else {
            // The route's sheet, at Dispatch's width, under the bar.
            let V = WorkbenchTokens.V2.self
            let spec = WorkbenchTokens.Island.spec
            let notch = NotchGeometry.notchRect(metrics: metrics, spec: spec)
            let height = notch.height + V.gap + V2RouteSheet.height(model: self) + V.margin + WorkbenchTokens.Native.contentDrop
            layout.outline = StackLayout.Outline(size: CGSize(width: V.width, height: height),
                                                 topRadius: spec.expandedTopRadius, bottomRadius: V.bottomRadius)
        }
        layout.outline.size.width = max(layout.outline.size.width, bar.outline.size.width)
        return layout
    }
}

extension StackLayout {
    /// The bar in Wings for `pose`: the notch's height, each wing as wide as the wider side needs
    /// (the sides balanced, as Apple asks of the Dynamic Island's), what's at the left from the left
    /// wing's outer end, what's at the right to the right wing's. x from the island's center.
    static func wings(_ pose: WingsPose, state: NotchState, aspects: [CGFloat], shape: ReferentShape,
                      pasteCopied: Bool = false, metrics: ScreenMetrics) -> StackLayout {
        let B = WorkbenchTokens.Bar.self
        let spec = WorkbenchTokens.Island.spec
        let notch = NotchGeometry.notchRect(metrics: metrics, spec: spec)
        let W = notch.width, H = notch.height
        let cy = H / 2
        let voice = state.collects
        let left = leftWidth(pose, aspects: aspects, shape: shape)
        let right = rightWidth(pose, pasteCopied: pasteCopied)
        let side = max(B.minSide, B.inset + left + B.notchPad, B.inset + right + B.notchPad)
        let body = W + 2 * side
        let x0 = -body / 2 + B.inset
        var layout = StackLayout(outline: Outline(size: CGSize(width: body + 2 * B.wingsEar, height: H),
                                                  topRadius: B.wingsEar, bottomRadius: B.wingsBottom),
                                 cards: [], waveform: CGPoint(x: body / 2 - B.inset - right / 2, y: cy), stackHit: nil, close: nil)
        layout.wings = pose
        layout.wingsLeft = CGRect(x: x0, y: 0, width: left, height: H)
        layout.wingsRight = CGRect(x: body / 2 - B.inset - right, y: 0, width: right, height: H)
        layout.fill = .black
        // What's taken: shown only while it's the left's; otherwise put away where it would be.
        let pile = pileCards(aspects: aspects, shape: shape, left: x0, cy: cy, h: B.thumb, radius: B.thumbRadius,
                             offset: B.layerOffset, visible: voice && pose.left == .stack)
        layout.cards = pile.cards
        layout.more = pile.more
        layout.moreCount = pile.hidden
        if voice, pose.left == .stack, !aspects.isEmpty {
            layout.stackHit = CGRect(x: x0, y: cy - B.thumb / 2, width: pile.right - x0, height: B.thumb).insetBy(dx: -3, dy: -3)
        }
        return layout
    }

    static func leftWidth(_ pose: WingsPose, aspects: [CGFloat], shape: ReferentShape) -> CGFloat {
        let B = WorkbenchTokens.Bar.self
        var width: CGFloat
        switch pose.left {
        case .word(let text, let dots):
            width = WingsType.width(text, font: WingsType.wordFont()) + (dots ? B.dotsWidth : 0)
        case .stack:
            width = pileWidth(aspects, shape: shape, h: B.thumb, offset: B.layerOffset)
        case .notice(_, let title, _):
            width = B.noticeGlyph + B.noticeGap + WingsType.width(title, font: .systemFont(ofSize: B.noticeSize, weight: .medium))
        case .quote(let text):
            width = min(B.quoteWidth, WingsType.width("“\(text)”", font: WingsType.wordFont()))
        }
        return width
    }

    static func rightWidth(_ pose: WingsPose, pasteCopied: Bool) -> CGFloat {
        let B = WorkbenchTokens.Bar.self
        var width: CGFloat
        switch pose.right {
        case .waveform: width = B.span
        case .ring: width = B.ring
        case .undo: width = B.drain + B.pillGap + pillWidth(L("Undo"))
        case .copy: width = B.drain + B.pillGap + pillWidth(pasteCopied ? L("Copied") : L("Copy"))
        case .action(let title): width = pillWidth(title)
        case .none: width = 0
        }
        if pose.countdown { width += B.countdownWidth + B.countdownGap }
        if pose.route { width += B.route + B.routeGap }
        return width
    }

    static func pillWidth(_ title: String) -> CGFloat {
        let B = WorkbenchTokens.Bar.self
        return WingsType.width(title, font: .systemFont(ofSize: B.pillSize, weight: .semibold)) + 2 * B.pillPadding
    }

    /// How wide the pile is for these captures: the front one, two peeking out behind, "+N".
    static func pileWidth(_ aspects: [CGFloat], shape: ReferentShape, h: CGFloat, offset: CGFloat) -> CGFloat {
        guard let first = aspects.first else { return 0 }
        let T = WorkbenchTokens.Referents.self
        let layers = min(aspects.count, T.maxLayers)
        let hidden = max(0, aspects.count - T.maxLayers)
        let front = shape.width(height: h, aspect: first, stacked: true)
        return front + CGFloat(layers - 1) * offset + (hidden > 0 ? T.moreGap + moreWidth(hidden) : 0)
    }

    /// The pile laid from `left`, centered on `cy`: the first capture in front, two more peeking out
    /// behind it to the right, smaller and dimmer, the rest hidden; "+N" after them.
    static func pileCards(aspects: [CGFloat], shape: ReferentShape, left: CGFloat, cy: CGFloat, h: CGFloat,
                          radius: CGFloat, offset: CGFloat,
                          visible: Bool) -> (cards: [Card], more: CGRect?, hidden: Int, right: CGFloat) {
        let T = WorkbenchTokens.Referents.self
        let n = aspects.count
        guard let first = aspects.first else { return ([], nil, 0, left) }
        let front = shape.width(height: h, aspect: first, stacked: true)
        var cards: [Card] = []
        for i in 0..<n {
            let layer = min(i, T.maxLayers - 1)
            let s = 1 - CGFloat(layer) * T.layerShrink
            let w = front * s, hh = h * s
            let right = left + front + CGFloat(layer) * offset
            let opacity: Double = !visible ? 0 : (i == 0 ? 1 : (i < T.maxLayers ? T.layerOpacity : 0))
            cards.append(Card(cx: right - w / 2, top: cy - hh / 2, width: w, height: hh,
                              radius: shape.radius(height: hh, concentric: radius * s),
                              rotation: 0, opacity: opacity, z: Double(n - i)))
        }
        var end = left + front + CGFloat(min(n, T.maxLayers) - 1) * offset
        let hidden = max(0, n - T.maxLayers)
        var more: CGRect?
        if hidden > 0 {
            more = CGRect(x: end + T.moreGap, y: cy - T.moreHeight / 2, width: moreWidth(hidden), height: T.moreHeight)
            end = more?.maxX ?? end
        }
        return (cards, visible ? more : nil, hidden, end)
    }
}

// MARK: The sides

/// The bar's left: the state's word, a notice, or the held words.
/// What's taken is drawn by the stack's cards.
struct WingsLeftView: View {
    let model: WorkbenchModel
    let pose: WingsPose
    let size: CGSize

    var body: some View {
        let B = WorkbenchTokens.Bar.self
        HStack(spacing: B.noticeGap) {
            switch pose.left {
            case .word(let text, let dots):
                HStack(spacing: 0) {
                    Text(text).font(WingsType.word()).foregroundStyle(B.wordColor).lineLimit(1).fixedSize()
                    if dots { WingsDots(model: model) }
                }
            case .stack:
                Color.clear
            case .notice(let symbol, let title, let tone):
                Image(systemName: symbol).font(.system(size: B.noticeGlyph, weight: .semibold)).foregroundStyle(Self.color(tone))
                Text(title).font(B.noticeFont).foregroundStyle(B.noticeColor).lineLimit(1).fixedSize()
            case .quote(let text):
                Text("“\(text)”").font(WingsType.word()).foregroundStyle(B.wordColor).lineLimit(1).truncationMode(.tail)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    static func color(_ tone: VoiceError.Tone) -> Color {
        switch tone {
        case .info: return Color.white.opacity(0.7)
        case .yours: return WorkbenchTokens.Panel.needsYouColor
        case .failure: return WorkbenchTokens.Panel.failedColor
        }
    }
}

/// The bar's right: the waveform, the orb, the ring, a pill (Undo, Copy, a notice's way on), the
/// last minute's time and the chosen chat's agent before them.
struct WingsRightView: View {
    let model: WorkbenchModel
    let pose: WingsPose
    let size: CGSize
    let shown: Bool

    var body: some View {
        let B = WorkbenchTokens.Bar.self
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            if pose.route {
                // On the bar's black in either look (in Light the panels' ink is dark, and it vanished).
                V2RouteButton(model: model).frame(width: B.route, height: B.route).padding(.trailing, B.routeGap)
                    .environment(\.colorScheme, .dark)
            }
            if pose.countdown {
                WingsTime(model: model).frame(width: B.countdownWidth, alignment: .trailing).padding(.trailing, B.countdownGap)
            }
            switch pose.right {
            case .waveform:
                MiniWaveform(model: model, maxHeight: B.barMax, working: false, paused: !shown)
            case .ring:
                ProgressRing(paused: !shown) { date in
                    model.notchState == .v2Transcribing ? model.v2TranscribeProgress(at: date) : model.transcribeProgress(at: date)
                }
                .frame(width: B.ring, height: B.ring)
            case .undo:
                HStack(spacing: B.pillGap) {
                    ProgressRing(draining: true, paused: !shown) { model.undoRemaining(at: $0) }.frame(width: B.drain, height: B.drain)
                    WingsPill(title: L("Undo")) { _ = model.undoCancel() }
                }
                .onHover { model.setUndoHover($0) }
            case .copy:
                HStack(spacing: B.pillGap) {
                    ProgressRing(draining: true, paused: !shown) { model.pasteRemaining(at: $0) }.frame(width: B.drain, height: B.drain)
                    WingsPill(title: model.pasteCopied ? L("Copied") : L("Copy")) { model.copyTranscript() }
                }
                .onHover { model.setPasteHover($0) }
            case .action(let title):
                WingsPill(title: title) {
                    if let error = model.barNotice ?? model.voiceError { model.performErrorAction(error) }
                }
            case .none:
                EmptyView()
            }
        }
        .frame(width: size.width, height: size.height, alignment: .trailing)
    }
}

/// The website's ellipsis (components/book/film/film.css `.ell`): three dots, one lit at a time.
struct WingsDots: View {
    let model: WorkbenchModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let B = WorkbenchTokens.Bar.self
        let still = model.snapshotMode || reduceMotion
        TimelineView(.periodic(from: .now, by: B.dotStep)) { context in
            let lit = still ? 2 : Int(context.date.timeIntervalSinceReferenceDate / B.dotStep) % 3
            HStack(spacing: B.dotGap) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(B.wordColor).frame(width: B.dot, height: B.dot).opacity(i == lit ? 1 : B.dotDim)
                }
            }
            .padding(.leading, B.dotLead)
            .offset(y: 3)
        }
        .accessibilityHidden(true)
    }
}

/// A pill at the bar's right: white at an opacity on the black, the system face.
struct WingsPill: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let B = WorkbenchTokens.Bar.self
        Button(action: action) {
            Text(title).font(B.pillFont).foregroundStyle(B.pillText).lineLimit(1).fixedSize()
                .padding(.horizontal, B.pillPadding)
                .frame(height: B.pillHeight)
                .background(Capsule(style: .continuous).fill(hovering ? B.pillHover : B.pillFill))
        }
        .buttonStyle(IslandPressStyle())
        .onHover { hovering = $0 }
    }
}

/// A ring in white: filling clockwise from the top (Transcribing), or emptying (a pill's time).
struct ProgressRing: View {
    var draining = false
    let paused: Bool
    let progress: (Date) -> Double

    var body: some View {
        let B = WorkbenchTokens.Bar.self
        TimelineView(.animation(minimumInterval: 1 / 30, paused: paused)) { context in
            let p = min(1, max(0, progress(context.date)))
            ZStack {
                Circle().stroke(B.ringTrack, lineWidth: B.ringLine)
                Circle().trim(from: 0, to: p)
                    .stroke(B.ringFill, style: StrokeStyle(lineWidth: B.ringLine, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(x: draining ? -1 : 1, y: 1)
            }
            .padding(B.ringLine / 2)
        }
        .accessibilityElement()
        .accessibilityLabel(draining ? "Time left" : "Progress")
    }
}

/// The last minute's time, before the right side; the last seconds in amber.
struct WingsTime: View {
    let model: WorkbenchModel

    var body: some View {
        let B = WorkbenchTokens.Bar.self
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let left = Int((model.recordingRemaining(at: context.date) ?? 0).rounded(.up))
            Text(String(format: "%d:%02d", left / 60, left % 60))
                .font(B.countdownFont)
                .foregroundStyle(left <= 10 ? WorkbenchTokens.Panel.needsYouColor : B.countdownColor)
        }
    }
}

/// Voiceflow's small waveform: five short white bars, the voice lifting the middle on a bell.
struct MiniWaveform: View {
    let model: WorkbenchModel
    let maxHeight: CGFloat
    let working: Bool
    let paused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let B = WorkbenchTokens.Bar.self
        let still = model.snapshotMode || reduceMotion
        TimelineView(.animation(minimumInterval: 1 / B.frameRate, paused: paused || still)) { context in
            let t = still ? 1.3 : context.date.timeIntervalSinceReferenceDate
            let level = model.snapshotMode ? 0.6 : model.barLevel(at: context.date)
            let heights = Self.heights(level: level, time: t, maxHeight: maxHeight)
            HStack(spacing: B.barGap) {
                ForEach(heights.indices, id: \.self) { i in
                    Capsule(style: .continuous)
                        .fill(B.barColor)
                        .frame(width: B.barWidth, height: heights[i])
                }
            }
        }
        .frame(width: B.span, height: maxHeight)
        .accessibilityElement()
        .accessibilityLabel(L("Listening"))
    }

    static func heights(level: Double, time: TimeInterval, maxHeight: CGFloat) -> [CGFloat] {
        let B = WorkbenchTokens.Bar.self
        return (0..<B.bars).map { i in
            let x = Double(i) / Double(B.bars - 1) * 2 - 1
            let gain = exp(-(x * x) / (2 * B.barSpread * B.barSpread))
            let flutter = 0.7 + 0.3 * sin(time * 11 + Double(i) * 1.9)
            let amount = min(1, max(0, gain * level * B.barBoost * flutter))
            return B.barMin + (maxHeight - B.barMin) * CGFloat(amount)
        }
    }
}

/// Oct 28, Ryan: "when doing dictation/dispatch. make an accent color a little aurora in the same
/// fashion as the attachment on the bottom right of the notch." A small light in the accent inside
/// the bar's bottom-right corner, under the waveform, while it listens: three soft lights wandering
/// a little, the voice brightening and growing them, the bar's edge lit along the corner. Then: "lets
/// just do one color hue. this should be determined along with accent in the onboarding … if they
/// choose multicolor, the hue in the attachment should be the color": one hue, the accent's; on
/// Multicolor, the glow's Colorful palette (`auroraColors`).
struct WingsAurora: View {
    let model: WorkbenchModel
    let height: CGFloat
    let paused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let A = WorkbenchTokens.Aurora.self
        let still = model.snapshotMode || reduceMotion
        let colors = model.auroraColors
        TimelineView(.animation(minimumInterval: 1 / A.frameRate, paused: paused || still)) { context in
            let t = still ? A.stillTime : context.date.timeIntervalSinceReferenceDate
            let level = still ? A.stillLevel : model.barLevel(at: context.date)
            Canvas { ctx, size in
                Self.draw(in: ctx, size: size, colors: colors, time: t, level: level)
            }
        }
        .frame(width: A.width, height: height)
        .mask(WingsCorner(radius: WorkbenchTokens.Bar.wingsBottom))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    static func draw(in ctx: GraphicsContext, size: CGSize, colors: [Color], time t: Double, level: Double) {
        let A = WorkbenchTokens.Aurora.self
        guard !colors.isEmpty else { return }
        let voice = min(1, max(0, level))
        let alpha = A.strength * (A.quiet + (1 - A.quiet) * voice)
        let grow = A.rest + A.breath * CGFloat(voice)
        let corner = CGPoint(x: size.width, y: size.height)
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: A.blur))
            for (i, light) in A.lights.enumerated() {
                let phase = Double(i) * 2.1
                let x = corner.x - light.x + A.wander * CGFloat(sin(t * A.pace + phase))
                let y = corner.y - light.y + A.wander * CGFloat(cos(t * A.pace * 0.8 + phase))
                let r = light.radius * grow
                layer.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                           with: .color(colors[i % colors.count].opacity(alpha * light.share)))
            }
        }
        // The edge along the corner, in the first light's color, fading away from the corner.
        let B = WorkbenchTokens.Bar.self
        var rim = Path()
        rim.move(to: CGPoint(x: corner.x, y: corner.y - B.wingsBottom - A.rimReach))
        rim.addLine(to: CGPoint(x: corner.x, y: corner.y - B.wingsBottom))
        rim.addQuadCurve(to: CGPoint(x: corner.x - B.wingsBottom, y: corner.y), control: corner)
        rim.addLine(to: CGPoint(x: corner.x - B.wingsBottom - A.rimReach, y: corner.y))
        ctx.drawLayer { layer in
            layer.clipToLayer { mask in
                mask.addFilter(.blur(radius: A.rimFade))
                let r = B.wingsBottom + A.rimReach / 2
                mask.fill(Path(ellipseIn: CGRect(x: corner.x - r, y: corner.y - r, width: 2 * r, height: 2 * r)), with: .color(.white))
            }
            layer.stroke(rim, with: .color(colors[0].opacity(A.rimOpacity * (A.quiet + (1 - A.quiet) * voice))),
                         lineWidth: A.rimWidth)
        }
    }
}

/// The bar's bottom-right corner, as `IslandShape` draws it (the same curve), for the aurora's room.
struct WingsCorner: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.width, rect.height)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// The surface a state's island is drawn with.
enum BarFill: Equatable {
    /// The glass coming in as the island grows past the notch, the notch black on it.
    case native
    /// All black, as the notch is: Wings, a session popping up, a board design.
    case black
}

extension VoiceError {
    /// In Wings, beside the notch: the notice in a few words (its full words are its help).
    var wingsTitle: String {
        switch self {
        case .noSpeech: return L("No speech")
        case .tooShort: return L("Too short")
        case .micPermission: return L("Mic access off")
        case .micUnavailable: return L("No microphone")
        case .speechPermission: return L("Speech access off")
        case .screenRecording: return L("Screen Recording off")
        case .imageTooLarge: return L("Image over 20 MB")
        case .offline: return L("Offline")
        case .timeout: return L("Timed out")
        case .serverUnavailable: return L("Service down")
        case .sessionExpired: return L("Signed out")
        case .quotaUsed: return L("Limit reached")
        case .trialEnded: return L("Trial ended")
        case .proExpired: return L("Pro expired")
        case .rateLimited: return L("Too many requests")
        case .tooLarge: return L("Too long")
        case .unexpected: return L("Something went wrong")
        }
    }
}

extension VoiceError.Action {
    /// In Wings: the way on in a word.
    var wingsLabel: String {
        switch self {
        case .retry: return L("Retry")
        case .openSettings: return L("Settings")
        case .signIn: return L("Sign In")
        case .upgrade: return L("Upgrade")
        case .renew: return L("Renew")
        case .chooseMicrophone: return L("Choose")
        }
    }
}

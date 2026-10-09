import SwiftUI
import WindowBenchCore

// MARK: - Jump highlight (motion shortlist 5)

/// A block that arrives through layout: its slot opens on the open spring, pushing what's below
/// down, and its content comes in a beat later on the notch's content entrance. Nothing shows
/// outside the slot while it opens. `enabled` is read once, when the block appears: a block that
/// is there when its page first draws simply is there.
struct GrowIn: ViewModifier {
    @Environment(BenchModel.self) private var model
    @State private var natural: CGFloat = 0
    @State private var open: Bool
    @State private var shown: Bool
    /// A block that was there when its page first drew isn't clipped at all: clipped to a
    /// height still being measured, it would grow in anyway.
    @State private var grows: Bool

    init(enabled: Bool = true) {
        _open = State(initialValue: !enabled)
        _shown = State(initialValue: !enabled)
        _grows = State(initialValue: enabled)
    }

    func body(content: Content) -> some View {
        if grows { growing(content) } else { content }
    }

    private func growing(_ content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { natural = $0 }
            .contentReveal(shown ? 1 : 0)
            .modifier(RevealHeight(height: open ? natural : 0))
            .onAppear {
                guard !open else { return }
                let motion = model.motion
                // The next turn: the slot's height is measured by then.
                DispatchQueue.main.async {
                    if motion.reduce {
                        // Reduce Motion: the slot is simply there; the block fades in.
                        var t = Transaction()
                        t.disablesAnimations = true
                        withTransaction(t) { open = true }
                        withAnimation(motion.animation(.content)) { shown = true }
                    } else {
                        withAnimation(motion.animation(.open)) { open = true }
                        withAnimation(motion.animation(.content).delay(motion.contentDelay)) { shown = true }
                    }
                }
            }
    }
}

/// The notch's line swap: the old line rises 8 pt out into a 2 pt blur, and only once it is gone
/// does the new one rise in from 8 pt below, so a word that changes is never printed over itself
/// (the two share one progress: out over 0–0.4, in over 0.5–1). Under Reduce Motion the same
/// sequence is opacity alone. Use with `.id(value)` on the swapped view, inside a container that
/// lets the two overlap. Animatable, so the body is drawn at every step of the progress: without
/// it SwiftUI would only interpolate the end values, and the two would cross-fade.
struct LineSwapIn: ViewModifier, Animatable {
    @Environment(\.motion) private var motion
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        let travel = motion.reduce ? 0 : 1 - progress
        content
            .offset(y: travel * BenchTokens.MotionValues.lineRise)
            .blur(radius: travel * BenchTokens.MotionValues.lineBlur)
            .opacity(Double(max(0, (progress - 0.5) / 0.5)))
    }
}

struct LineSwapOut: ViewModifier, Animatable {
    @Environment(\.motion) private var motion
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        let travel = motion.reduce ? 0 : progress
        content
            .offset(y: -travel * BenchTokens.MotionValues.lineRise)
            .blur(radius: travel * BenchTokens.MotionValues.lineBlur)
            .opacity(Double(max(0, 1 - progress / 0.4)))
    }
}

extension AnyTransition {
    static var lineSwap: AnyTransition {
        .asymmetric(insertion: .modifier(active: LineSwapIn(progress: 0), identity: LineSwapIn(progress: 1)),
                    removal: .modifier(active: LineSwapOut(progress: 1), identity: LineSwapOut(progress: 0)))
    }

    /// A block (a list, a grid) replaced in place by another: the line swap's order, out then
    /// in, and no movement (the filters aren't pages).
    static var blockSwap: AnyTransition {
        .asymmetric(insertion: .modifier(active: BlockFade(progress: 0, entering: true), identity: BlockFade(progress: 1, entering: true)),
                    removal: .modifier(active: BlockFade(progress: 1, entering: false), identity: BlockFade(progress: 0, entering: false)))
    }
}

struct BlockFade: ViewModifier, Animatable {
    var progress: CGFloat
    let entering: Bool
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        content.opacity(Double(entering ? max(0, (progress - 0.5) / 0.5) : max(0, 1 - progress / 0.4)))
    }
}

/// A line that swaps the notch's way when its text changes.
struct SwapText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        ZStack(alignment: .leading) {
            Text(text)
                .id(text)
                .transition(.lineSwap)
        }
    }
}

/// Marks the thing a jump landed on, then fades: a wash behind it (shipping highlightFade, B3),
/// a ring that settles onto it, or a single pulse of its glyph (`pulsing` is read by the row).
struct HighlightFade: ViewModifier {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let key: String
    @State private var level: Double = 0
    @State private var ringScale: CGFloat = 1

    func body(content: Content) -> some View {
        let style = model.v(JumpHighlight.self)
        content
            .background {
                if style == .wash {
                    RoundedRectangle(cornerRadius: BenchTokens.Layout.rowRadius, style: .continuous)
                        .fill(palette.wash)
                        .opacity(level)
                }
            }
            .overlay {
                if style == .ring {
                    RoundedRectangle(cornerRadius: BenchTokens.Layout.rowRadius, style: .continuous)
                        .strokeBorder(palette.text.opacity(0.55), lineWidth: 1.5)
                        .scaleEffect(ringScale)
                        .opacity(level)
                }
            }
            .onChange(of: model.highlight) { _, highlight in
                guard let highlight, highlight.key == key else { return }
                play()
            }
            .onAppear {
                if model.highlight?.key == key { play() }
            }
    }

    private func play() {
        let V = BenchTokens.MotionValues.self
        let motion = model.motion
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            level = 0
            ringScale = V.ringScale
        }
        withAnimation(motion.reduce ? motion.animation(.fade) : motion.animation(.open)) {
            level = 1
            ringScale = 1
        }
        let hold = model.state.highlightSeconds
        Task { @MainActor in
            await motion.sleep(V.highlightIn + hold)
            withAnimation(.easeOut(duration: motion.seconds(0.6))) { level = 0 }
        }
    }
}

extension View {
    func jumpHighlight(_ key: String) -> some View { modifier(HighlightFade(key: key)) }
}

/// The glyph's pulse for the Glyph pulse highlight: one swell and back.
struct PulseOnHighlight: ViewModifier {
    @Environment(BenchModel.self) private var model
    let key: String
    @State private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: model.highlight) { _, highlight in
                guard let highlight, highlight.key == key, model.v(JumpHighlight.self) == .pulse, !model.motion.reduce else { return }
                withAnimation(model.motion.animation(.open)) { scale = BenchTokens.MotionValues.pulseScale }
                Task { @MainActor in
                    await model.motion.sleep(BenchTokens.MotionValues.open)
                    withAnimation(model.motion.animation(.close)) { scale = 1 }
                }
            }
    }
}

// MARK: - Inline expand (motion shortlist 4)

/// A fold's rows opening in place, one fold open at a time. Clip reveal grows the block's height
/// on the notch's expand/collapse springs while the rows fade in behind its edge (the notch's
/// Paste chevron); Disclosure slides them down from under the fold row, AppKit's way.
struct InlineExpand<Content: View>: View {
    @Environment(BenchModel.self) private var model
    let open: Bool
    @ViewBuilder let content: Content
    @State private var natural: CGFloat = 0

    var body: some View {
        let style = model.v(InlineExpandStyle.self)
        if style == .clip && !model.motion.reduce {
            content
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { natural = $0 }
                .contentReveal(open ? 1 : 0)
                .modifier(RevealHeight(height: open ? natural : 0))
                .allowsHitTesting(open)
                .accessibilityHidden(!open)
        } else {
            VStack(spacing: 0) {
                if open {
                    content.transition(model.motion.reduce ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .clipped()
        }
    }
}

/// Clips to an animatable height, so the block grows through real layout on every frame.
struct RevealHeight: ViewModifier, Animatable {
    var height: CGFloat
    var animatableData: CGFloat {
        get { height }
        set { height = newValue }
    }
    func body(content: Content) -> some View {
        content.frame(height: max(0, height), alignment: .top).clipped()
    }
}

/// The fold row: a chevron that turns, the count, and nothing else (Kaleidoscope's
/// "12 Unchanged Lines", R02-02). The words stay the same open or closed: the chevron says which.
struct FoldRow: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let title: String
    let open: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        let scale = BenchTokens.Type_.scale(model.v(TypeScale.self))
        Button(action: action) {
            HStack(spacing: BenchTokens.Layout.glyphGap) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .rotationEffect(.degrees(open ? 90 : 0))
                    .frame(width: BenchTokens.Layout.glyphSlot)
                Text(title)
                    .font(.system(size: scale.body - 1))
                Spacer(minLength: 0)
            }
            .foregroundStyle(hover ? palette.text : palette.secondary)
            .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
            .frame(height: BenchTokens.Layout.runRow.regular)
            .background(RoundedRectangle(cornerRadius: BenchTokens.Layout.rowRadius, style: .continuous).fill(hover ? palette.hover : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .accessibilityLabel(open ? "Hide \(title)" : "Show \(title)")
        .onChange(of: open, initial: true) { _, now in model.drawnFolds[title] = now }
    }
}

// MARK: - Counts (motion shortlist 3)

/// A number as the Counts switch says: rolling digits, the course's ticker, or plain.
struct Ticker: View {
    @Environment(BenchModel.self) private var model
    let value: Int
    var font: Font

    var body: some View {
        switch model.v(CountStyle.self) {
        case .rolling:
            Text("\(value)").font(font).monospacedDigit().contentTransition(.numericText(value: Double(value)))
        case .ticker:
            TickerDigits(value: value, font: font)
        case .plain:
            Text("\(value)").font(font).monospacedDigit()
        }
    }
}

/// Each changed digit slides 12 pt with a 2 pt blur, the rest stay put (motion notes).
private struct TickerDigits: View {
    let value: Int
    let font: Font

    var body: some View {
        let digits = Array(String(value))
        HStack(spacing: 0) {
            ForEach(Array(digits.enumerated()), id: \.offset) { i, digit in
                Text(String(digit))
                    .font(font)
                    .monospacedDigit()
                    .id("\(digits.count - i)-\(digit)")
                    .transition(.asymmetric(
                        insertion: .modifier(active: DigitShift(offset: BenchTokens.MotionValues.tickerRise), identity: DigitShift(offset: 0)),
                        removal: .modifier(active: DigitShift(offset: -BenchTokens.MotionValues.tickerRise), identity: DigitShift(offset: 0))))
            }
        }
        .clipped()
    }
}

private struct DigitShift: ViewModifier {
    let offset: CGFloat
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .blur(radius: offset == 0 ? 0 : BenchTokens.MotionValues.tickerBlur)
            .opacity(offset == 0 ? 1 : 0)
    }
}

// MARK: - Hover actions (never reflowing, never the only way)

/// A secondary action on a row.
struct RowAction: Identifiable {
    let title: String
    let action: () -> Void
    var id: String { title }
}

/// A row's trailing slot: what the row says at its end (its age, its captures), and its secondary
/// actions per the Row actions switch. On hover the actions take the same place, so revealing
/// them never moves the row and no width sits empty waiting for them.
struct TrailingSlot<Info: View>: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let hover: Bool
    /// A fixed slot, or nil: the slot is as wide as its info, which stays in view and clickable
    /// (a run's "Used 3 captures"), and the actions, when they show, lie just before it, over the
    /// end of the row's evidence, on the row's own color (the row never reflows).
    let width: CGFloat?
    let actions: [RowAction]
    @ViewBuilder let info: Info

    var body: some View {
        let style = model.v(RowActions.self)
        let buttons = HStack(spacing: 4) {
            ForEach(actions) { action in SlotButton(title: action.title, action: action.action) }
        }
        ZStack(alignment: .trailing) {
            if actions.isEmpty {
                info
            } else {
                switch style {
                case .hoverSlot where width == nil:
                    info
                        .overlay(alignment: .leading) {
                            buttons
                                .fixedSize()
                                .padding(.horizontal, 8)
                                .background(palette.hover.background(palette.background))
                                // Its trailing edge on the info's leading edge: it reaches back
                                // over the evidence, never over the info.
                                .alignmentGuide(.leading) { $0[.trailing] }
                                .opacity(hover ? 1 : 0)
                                .allowsHitTesting(hover)
                        }
                case .hoverSlot:
                    info.opacity(hover ? 0 : 1)
                    buttons.opacity(hover ? 1 : 0).allowsHitTesting(hover)
                case .moreButton:
                    HStack(spacing: 4) {
                        ZStack(alignment: .trailing) {
                            info.opacity(hover ? 0 : 1)
                            buttons.opacity(hover ? 1 : 0).allowsHitTesting(hover)
                        }
                        Menu {
                            ForEach(actions) { action in Button(action.title, action: action.action) }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(palette.secondary)
                                .frame(width: 22, height: 20)
                                .contentShape(Rectangle())
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .help("More")
                    }
                case .always:
                    HStack(spacing: 6) {
                        buttons.opacity(hover ? 1 : 0.55)
                        info
                    }
                }
            }
        }
        .frame(width: width, alignment: .trailing)
        .fixedSize(horizontal: width == nil, vertical: false)
        .animation(model.motion.animation(.hover), value: hover)
    }
}

/// A row's age, in mono, never jittering.
struct AgeText: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let date: Date

    var body: some View {
        Text(Lines.age(date, now: model.index.now))
            .font(BenchTokens.Type_.mono(BenchTokens.Type_.scale(model.v(TypeScale.self)).meta))
            .foregroundStyle(palette.tertiary)
            .lineLimit(1)
            .fixedSize()
    }
}

/// A small text action in a row's trailing slot.
struct SlotButton: View {
    @Environment(\.palette) private var palette
    let title: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(hover ? palette.text : palette.secondary)
                .padding(.horizontal, 7)
                .frame(height: 20)
                .background(Capsule().fill(hover ? palette.pressed : palette.fill))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .fixedSize()
    }
}

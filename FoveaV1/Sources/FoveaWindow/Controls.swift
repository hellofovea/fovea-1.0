import AppKit
import SwiftUI
import CapturesCore
import FoveaKit

/// Fovea's controls, built the way Aside builds its own (heyaside.com's CSS, which rebuilds the
/// app's views at its point sizes, and the app on macOS 27):
/// - words in pills, symbols in circles (Aside 2.0: "text buttons are pills"; one round-button
///   control for every icon);
/// - a choice of a few as a pill that slides along a capsule track;
/// - actions together in one glass capsule, the buttons in it concentric with it;
/// - everything in the ink at an opacity (`T.Shade`); color only for what the keyboard has
///   chosen and for what can't be undone;
/// - each symbol answers the pointer once.

// MARK: - A choice of a few

/// Aside's segmented control: a capsule track, the chosen segment a pill that slides to it,
/// white with an edge and a contact shadow (white at 14 % in dark). Fovea's variant chooses with
/// the Island's black instead. Unchosen segments take a faint fill under the pointer.
///
/// - The track is the ink at 6 % on a page, or Liquid Glass in the toolbar. Either way it holds
///   the pill the same distance in on every side, so the pill's ends are concentric with the
///   track's: a capsule inset evenly in a capsule is rounded by the track's radius less the
///   inset.
/// - Every segment is as wide as the widest, as a segmented control's are (or as wide as its
///   words, where the row has to fit).
/// - The pill answers the press itself (mouse down, as browser tabs do), on its own quick spring
///   (`T.Motion.pill`, 0.12 s). What the choice changes follows once the pill has landed, so a
///   heavy page swapping can't stall it mid-flight; a quicker second press wins.
struct SlidingSegments<Value: Hashable>: View {
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion
    struct Segment {
        let value: Value
        let title: String
        var kind: CaptureKind?
        var symbol: String?
        var help: String?
    }
    enum Pill { case raised, island }

    typealias Track = SegmentTrackStyle

    let segments: [Segment]
    let selection: Value
    var pill: Pill = .raised
    var track: Track = .fill
    var height: CGFloat = 26
    var fontSize: CGFloat = 12.5
    var padding: CGFloat = 12
    /// The track's room around the pill, the same on every side.
    var inset: CGFloat = 3
    var equalWidths = true
    /// Chooses a segment; the caller animates what the choice changes.
    let choose: (Value) -> Void
    @Namespace private var ns
    @State private var hovered: Int?
    /// Where the pill is: the selection, a click ahead of it.
    @State private var shown: Value?

    var body: some View {
        Group {
            if equalWidths {
                EqualWidths { ForEach(segments.indices, id: \.self) { i in segment(i) } }
            } else {
                // Each as wide as its words, the row at its own width (not shared out evenly).
                HStack(spacing: 0) { ForEach(segments.indices, id: \.self) { i in segment(i) } }
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(inset)
        .modifier(SegmentTrack(track: track))
        .onAppear { if shown == nil { shown = selection } }
        // Chosen elsewhere (⌘1–4): the pill slides there too.
        .onChange(of: selection) { _, value in
            guard shown != value else { return }
            withAnimation(pillAnimation) { shown = value }
        }
        .accessibilityElement(children: .contain)
    }

    private var pillAnimation: Animation {
        motion.reduce ? .easeOut(duration: T.Motion.reduced) : .interpolatingSpring(duration: motion.seconds(T.Motion.pill), bounce: 0)
    }

    private func segment(_ i: Int) -> some View {
        let s = segments[i]
        let on = s.value == (shown ?? selection)
        let ink: Color = on ? (pill == .island ? palette.onPill : palette.text) : (hovered == i ? palette.text : palette.secondary)
        return HStack(spacing: 5) {
                if let kind = s.kind { KindMark(kind: kind, size: 8) }
                if let symbol = s.symbol { Image(systemName: symbol).font(.system(size: fontSize - 1, weight: .medium)) }
                Text(s.title).font(.system(size: fontSize, weight: on ? .semibold : .medium))
        }
        .foregroundStyle(ink)
        .padding(.horizontal, padding)
        .frame(maxWidth: equalWidths ? .infinity : nil)
        .frame(height: height)
        .background {
            if on {
                chosen.matchedGeometryEffect(id: "pill", in: ns)
            } else if hovered == i {
                Capsule().fill(palette.ink(0.05))
            }
        }
        .contentShape(Capsule())
        // On the press, not the release.
        .gesture(DragGesture(minimumDistance: 0).onChanged { _ in press(s.value) })
        .onHover { h in
            withAnimation(motion.animation(.hover)) { if h { hovered = i } else if hovered == i { hovered = nil } }
        }
        .help(s.help ?? "")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(s.title)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { press(s.value) }
    }

    /// The pill to the segment pressed, now; the choice itself once it has landed, unless
    /// another press has moved it on since.
    private func press(_ value: Value) {
        guard value != (shown ?? selection) else { return }
        withAnimation(pillAnimation) { shown = value }
        DispatchQueue.main.asyncAfter(deadline: .now() + motion.seconds(T.Motion.pill)) {
            if shown == value { choose(value) }
        }
    }

    @ViewBuilder private var chosen: some View {
        let (contact, _) = T.Shade.layers(.control, dark: palette.isDark)
        switch pill {
        case .raised:
            Capsule()
                .fill(palette.isDark ? Color.white.opacity(0.14) : Color.white)
                .overlay(Capsule().strokeBorder(palette.ink(T.Shade.line), lineWidth: 0.5))
                .shadow(color: .black.opacity(contact.opacity + 0.01), radius: contact.radius, y: contact.y)
        case .island:
            Capsule()
                .fill(palette.pill)
                .overlay(Capsule().strokeBorder(Color.white.opacity(palette.isDark ? 0.14 : 0), lineWidth: 0.5))
                .shadow(color: .black.opacity(contact.opacity + 0.03), radius: contact.radius, y: contact.y)
        }
    }
}

/// The segments' track: the ink at 6 %, or glass (Liquid Glass on macOS 26 and later).
enum SegmentTrackStyle { case fill, glass }

private struct SegmentTrack: ViewModifier {
    @Environment(\.palette) private var palette
    let track: SegmentTrackStyle

    func body(content: Content) -> some View {
        switch track {
        case .fill: content.background(Capsule().fill(palette.ink(T.Shade.track)))
        case .glass: content.glass(Capsule())
        }
    }
}

/// A row whose children are all as wide as the widest (a segmented control's segments).
struct EqualWidths: Layout {
    var spacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let width = sizes.map(\.width).max() ?? 0
        let height = sizes.map(\.height).max() ?? 0
        let n = CGFloat(subviews.count)
        return CGSize(width: width * n + spacing * max(0, n - 1), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        var x = bounds.minX
        for view in subviews {
            view.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                       proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
        }
    }
}

// MARK: - Words in a pill

/// A button with words, as a pill (Aside 2.0). Four kinds:
/// - prominent: the one thing a page is for (Aside's Start recording). The ink, lit from above:
///   a slight fall from top to bottom, a highlight along its top edge, three layered shadows
///   that deepen under the pointer and close up when pressed.
/// - secondary: the ink at 7 % with a 12 % edge (Aside's Join).
/// - plain: no fill until the pointer is on it.
/// - destructive: red words; a pink wash under the pointer (Aside's Delete).
struct PillButton: View {
    enum Kind { case prominent, secondary, plain, destructive }
    let title: String
    var symbol: String?
    var kind: Kind = .secondary
    var large = false
    let action: () -> Void
    @State private var bumps = 0

    init(_ title: String, symbol: String? = nil, kind: Kind = .secondary, large: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.symbol = symbol; self.kind = kind; self.large = large; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: large ? 7 : 5) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: large ? 13 : 11, weight: .semibold))
                        .symbolEffect(.bounce, value: bumps)
                }
                Text(title).font(.system(size: large ? 13.5 : 12.5, weight: kind == .prominent ? .semibold : .medium))
            }
            .padding(.horizontal, large ? 16 : 11)
            .frame(height: large ? 34 : 26)
            .contentShape(Capsule())
        }
        .buttonStyle(PillStyle(kind: kind))
        .onHover { if $0 { bumps += 1 } }
    }
}

struct PillStyle: ButtonStyle {
    var kind: PillButton.Kind = .secondary
    func makeBody(configuration: Configuration) -> some View {
        PillBody(configuration: configuration, kind: kind)
    }
}

private struct PillBody: View {
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion
    @Environment(\.isEnabled) private var enabled
    let configuration: ButtonStyleConfiguration
    let kind: PillButton.Kind
    @State private var hover = false

    var body: some View {
        let pressed = configuration.isPressed
        configuration.label
            .foregroundStyle(label)
            .background { plate(pressed: pressed) }
            .opacity(enabled ? 1 : 0.45)
            .onHover { hover = $0 }
            // Hover eases in; a press shows at once, as AppKit's buttons do.
            .animation(pressed ? nil : motion.animation(.hover), value: hover)
    }

    private var label: Color {
        switch kind {
        case .prominent: return palette.isDark ? .black.opacity(0.88) : .white
        case .destructive: return palette.danger
        case .secondary, .plain: return palette.text
        }
    }

    @ViewBuilder private func plate(pressed: Bool) -> some View {
        let lit = hover && enabled
        switch kind {
        case .prominent:
            ProminentPlate(dark: palette.isDark, hover: lit, pressed: pressed)
        case .secondary:
            Capsule()
                .fill(palette.ink(pressed ? T.Shade.pressed : (lit ? T.Shade.fillHover : T.Shade.fill)))
                .overlay(Capsule().strokeBorder(palette.ink(T.Shade.line), lineWidth: 0.5))
        case .plain:
            Capsule().fill(palette.ink(pressed ? T.Shade.fillHover : (lit ? T.Shade.fill : 0)))
        case .destructive:
            Capsule()
                .fill(lit || pressed ? palette.dangerWash : palette.ink(T.Shade.fill))
                .overlay(Capsule().strokeBorder(lit || pressed ? palette.danger.opacity(0.25) : palette.ink(T.Shade.line), lineWidth: 0.5))
                .brightness(pressed ? -0.04 : 0)
        }
    }
}

/// The prominent pill's body: the ink falling slightly darker toward the bottom, a highlight
/// along the top edge and a shade along the bottom one, three shadows at 1, 2 and 4 pt that
/// double under the pointer and close up to one when pressed (Aside's site button, in ink).
private struct ProminentPlate: View {
    let dark: Bool
    let hover: Bool
    let pressed: Bool

    var body: some View {
        let top = dark ? Color(white: hover ? 1 : 0.96) : Color(white: hover ? 0.27 : 0.21)
        let bottom = dark ? Color(white: hover ? 0.9 : 0.84) : Color(white: hover ? 0.1 : 0.04)
        let k = dark ? 2.6 : 1.0
        let spread: CGFloat = pressed ? 0.5 : (hover ? 2 : 1)
        ZStack {
            Capsule().fill(Color.black).shadow(color: .black.opacity(0.14 * k), radius: 0.5 * spread, y: 0.5 * spread)
            if !pressed {
                Capsule().fill(Color.black).shadow(color: .black.opacity(0.11 * k), radius: 1 * spread, y: 1 * spread)
                Capsule().fill(Color.black).shadow(color: .black.opacity(0.09 * k), radius: 2 * spread, y: 2 * spread)
            }
            Capsule().fill(LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom))
            // Lit from above: a highlight along the top edge, a shade along the bottom.
            Capsule().strokeBorder(
                LinearGradient(colors: [.white.opacity(pressed ? 0.06 : (dark ? 0.9 : 0.26)), .white.opacity(0),
                                        .black.opacity(dark ? 0.12 : 0.3)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 1)
            if pressed {
                // Pressed in: a shade from the top, inside.
                Capsule().fill(LinearGradient(colors: [.black.opacity(dark ? 0.12 : 0.35), .clear], startPoint: .top, endPoint: .center))
            }
        }
    }
}

// MARK: - Symbols in circles

/// An action as a symbol: borderless, a round plate under the pointer (Aside's one round-button
/// control), deeper while pressed; the symbol answers the pointer once. Copy turns into a
/// checkmark for a moment; Delete's plate is a pink wash. 28 pt, so a glass capsule 4 pt larger
/// all round holds it concentrically.
struct IconButton: View {
    let symbol: String
    let help: String
    var confirmed = false
    var role: ButtonRole?
    let action: () -> Void
    @State private var bumps = 0

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: bumps)
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(IconButtonStyle(confirmed: confirmed, destructive: role == .destructive))
        .onHover { if $0 { bumps += 1 } }
        .help(help)
        .accessibilityLabel(help)
    }
}

struct IconButtonStyle: ButtonStyle {
    var confirmed = false
    var destructive = false
    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration, confirmed: confirmed, destructive: destructive)
    }
}

private struct IconButtonBody: View {
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion
    @Environment(\.isEnabled) private var enabled
    let configuration: ButtonStyleConfiguration
    let confirmed: Bool
    let destructive: Bool
    @State private var hover = false

    var body: some View {
        let lit = hover && enabled
        let pressed = configuration.isPressed
        configuration.label
            .foregroundStyle(!enabled ? palette.tertiary
                             : confirmed ? palette.accent
                             : destructive && lit ? palette.danger
                             : (lit ? palette.text : palette.secondary))
            .background(
                Circle().fill(destructive && (lit || pressed) ? palette.dangerWash
                              : palette.ink(pressed ? T.Shade.pressed : (lit ? T.Shade.chosen : 0)))
            )
            .onHover { hover = $0 }
            .animation(pressed ? nil : motion.animation(.hover), value: hover)
    }
}

/// Actions together in one glass capsule (Aside's copy · share · delete): round 28 pt buttons
/// with 4 pt of glass around them, so the capsule's ends are concentric with theirs.
struct GlassBar<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack(spacing: 0) { content() }
            .padding(4)
            .glass(Capsule())
    }
}

/// A short upright hairline between groups in a glass capsule.
struct BarDivider: View {
    @Environment(\.palette) private var palette
    var body: some View {
        Rectangle().fill(palette.ink(T.Shade.line)).frame(width: 0.5, height: 16).padding(.horizontal, 4)
    }
}

// MARK: - A shortcut

/// A shortcut as Aside's recorder shows one: the keys in a pill, a ⓧ to clear it under the
/// pointer. Click (or clear) to record: the pill takes the focus edge (the ink at 25 %) and asks
/// for the keys; Esc cancels. The prototype records nothing.
struct ShortcutRecorder: View {
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion
    let keys: [String]
    @State private var recording = false
    @State private var hover = false

    var body: some View {
        HStack(spacing: 6) {
            Button { record() } label: {
                Group {
                    if recording {
                        Text("Type a shortcut").foregroundStyle(palette.secondary)
                    } else {
                        HStack(spacing: 5) {
                            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                                if key.hasPrefix("~") {
                                    Text(String(key.dropFirst())).foregroundStyle(palette.tertiary)
                                } else {
                                    Text(key).foregroundStyle(palette.text)
                                }
                            }
                        }
                    }
                }
                .font(.system(size: 12.5, weight: .medium))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if hover && !recording {
                Button { record() } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundStyle(palette.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear, and record another")
                .transition(.opacity)
            }
        }
        .padding(.leading, 11)
        .padding(.trailing, hover && !recording ? 6 : 11)
        .frame(height: 26)
        .background(Capsule().fill(palette.ink(recording ? T.Shade.fillHover : (hover ? T.Shade.fillHover : T.Shade.fill))))
        .overlay(Capsule().strokeBorder(palette.ink(recording ? T.Shade.focus : T.Shade.line), lineWidth: recording ? 1 : 0.5))
        .onHover { h in withAnimation(motion.animation(.hover)) { hover = h } }
        .onExitCommand { recording = false }
        .help("Click, then press the new keys")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(keys.map { $0.hasPrefix("~") ? String($0.dropFirst()) : $0 }.joined(separator: " "))
    }

    private func record() {
        withAnimation(motion.animation(.hover)) { recording = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(motion.animation(.hover)) { recording = false }
        }
    }
}

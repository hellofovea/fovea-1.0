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
/// - The pill answers the press itself (mouse down, as browser tabs do), on the selection curve
///   (`T.Motion.select`: ease-in-out cubic, 0.2 s), and the choice is made at once (Oct 21, Ryan,
///   "simpler is better": it waited for the pill to land). Under Reduce Motion the pill doesn't
///   travel: the chosen one fades in where it is.
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
        // Chosen elsewhere (⌘1–4): the pill slides there too. Aligned: it jumps (Emil Kowalski:
        // a keyboard action is never animated; it's done many times a day).
        .onChange(of: selection) { _, value in
            guard shown != value else { return }
            if WindowLook.isAligned { shown = value } else { withAnimation(pillAnimation) { shown = value } }
        }
        .accessibilityElement(children: .contain)
    }

    private var pillAnimation: Animation { motion.animation(.select) }

    private func segment(_ i: Int) -> some View {
        let s = segments[i]
        let on = s.value == (shown ?? selection)
        // Notion White: Arc's segmented control, the chosen one's words in the ink (`chosen`).
        let solid = (pill == .island || WindowLook.isAligned) && !T.Look.floats
        let ink: Color = on ? (solid ? palette.onPill : palette.text) : (hovered == i ? palette.text : palette.secondary)
        return HStack(spacing: 5) {
                // Aligned: the words alone (Oct 24, Ryan: no mark before Dictation and Dispatch).
                if let kind = s.kind, !WindowLook.isAligned { KindMark(kind: kind, size: 8) }
                if let symbol = s.symbol { Image(systemName: symbol).font(.system(size: fontSize - 1, weight: .medium)) }
                Text(L(key: s.title)).font(.system(size: fontSize, weight: on ? .semibold : .medium))
        }
        .foregroundStyle(ink)
        .padding(.horizontal, padding)
        .frame(maxWidth: equalWidths ? .infinity : nil)
        .frame(height: height)
        .background {
            if on {
                // Oct 21, Ryan: Reduce Motion: opacity only, so the pill fades in place.
                if motion.reduce {
                    chosen.transition(.opacity)
                } else {
                    chosen.matchedGeometryEffect(id: "pill", in: ns)
                }
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
        // Oct 18, Ryan: in the primary language (a literal help is looked up as it's drawn).
        .help(L(key: s.help ?? ""))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L(key: s.title))
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { press(s.value) }
    }

    /// The pill to the segment pressed, and the choice, now.
    private func press(_ value: Value) {
        guard value != (shown ?? selection) else { return }
        withAnimation(pillAnimation) { shown = value }
        choose(value)
    }

    @ViewBuilder private var chosen: some View {
        let (contact, _) = T.Shade.layers(.control, dark: palette.isDark)
        if T.Look.floats {
            // Arc UI's segmented control: on a quiet track, the chosen one a white card resting on
            // it; on a white card (the toolbar's), the ground's grey sunk into it.
            if track == .glass {
                Capsule().fill(palette.background)
            } else {
                FloatFill(shape: Capsule(), fill: palette.card)
            }
        } else if WindowLook.isAligned {
            // The first run's (NotchChoiceRow): solid ink, white in dark; no edge, no shadow.
            Capsule().fill(palette.pill)
        } else {
            raisedOrIsland(contact)
        }
    }

    @ViewBuilder private func raisedOrIsland(_ contact: T.Shade.Layer) -> some View {
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
        case .fill:
            let A = T.Aligned.self
            content.background(Capsule().fill(palette.ink(WindowLook.isAligned ? (palette.isDark ? A.trackDark : A.trackLight) : T.Shade.track)))
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
/// - prominent: the one thing a page is for, as the Mac's default button is: the accent, flat
///   (Oct 21, Ryan, "simpler is better": it was the ink lit from above, with a gradient, a
///   highlight and three shadows that deepened under the pointer).
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

    init(_ title: String, symbol: String? = nil, kind: Kind = .secondary, large: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.symbol = symbol; self.kind = kind; self.large = large; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: large ? 7 : 5) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: large ? 13 : 11, weight: .semibold))
                }
                // Oct 18, Ryan: a pill is never cut short ("发送采集" came out "发…").
                Text(L(key: title)).font(.system(size: large ? 13.5 : 12.5, weight: kind == .prominent ? .semibold : .medium))
                    .lineLimit(1).fixedSize()
            }
            .padding(.horizontal, WindowLook.isAligned ? (large ? 16 : 12) : (large ? 16 : 11))
            .frame(height: WindowLook.isAligned ? (large ? T.Aligned.buttonHeightLarge : T.Aligned.buttonHeight) : (large ? 34 : 26))
            .contentShape(Capsule())
        }
        .buttonStyle(PillStyle(kind: kind))
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
        let aligned = WindowLook.isAligned
        configuration.label
            .foregroundStyle(label)
            .background { if aligned { alignedPlate(pressed: pressed) } else { plate(pressed: pressed) } }
            .opacity(enabled ? 1 : (aligned ? 0.5 : 0.45))
            // Aligned: the button gives to the press, as the notch's and the first run's do.
            .scaleEffect(aligned && pressed && !motion.reduce ? T.Aligned.pressScale : 1)
            .animation(aligned ? motion.animation(.press) : nil, value: pressed)
            .onHover { hover = $0 }
            // Hover eases in; a press shows at once, as AppKit's buttons do.
            .animation(pressed ? nil : motion.animation(.hover), value: hover)
    }

    /// Aligned: the notch's buttons. The accent lighter under the pointer and lighter again
    /// pressed; the rest a fill with no edge.
    @ViewBuilder private func alignedPlate(pressed: Bool) -> some View {
        let A = T.Aligned.self
        let lit = hover && enabled
        switch kind {
        case .prominent:
            Capsule().fill(palette.accent.opacity(pressed ? A.primaryPressed : (lit ? A.primaryHover : 1)))
        case .secondary where T.Look.floats:
            // Notion White: a white card resting on the grey, a hairline round it on a white group.
            FloatFill(shape: Capsule(), fill: pressed ? palette.background : palette.card)
                .overlay(Capsule().strokeBorder(palette.hairline, lineWidth: 0.5))
                .opacity(lit && !pressed ? 0.94 : 1)
        case .secondary:
            Capsule().fill(palette.ink(pressed ? A.secondaryPressed : (lit ? A.secondaryHover : A.secondaryFill)))
        case .plain:
            Capsule().fill(palette.ink(pressed ? A.secondaryHover : (lit ? A.secondaryFill : 0)))
        case .destructive:
            Capsule().fill(lit || pressed ? palette.dangerWash : palette.ink(A.secondaryFill))
        }
    }

    private var label: Color {
        switch kind {
        case .prominent: return palette.onAccent
        case .destructive: return palette.danger
        case .secondary, .plain: return palette.text
        }
    }

    @ViewBuilder private func plate(pressed: Bool) -> some View {
        let lit = hover && enabled
        switch kind {
        case .prominent:
            // The accent, flat; a little darker under the pointer, darker again pressed.
            Capsule().fill(palette.accent).brightness(pressed ? -0.1 : (lit ? -0.04 : 0))
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

// MARK: - Symbols in circles

/// An action as a symbol: borderless, a round plate under the pointer (Aside's one round-button
/// control), deeper while pressed. Copy, Save and Delete turn into a checkmark for a moment, at
/// once; Delete's plate is a pink wash. 28 pt, so a glass capsule 4 pt larger
/// all round holds it concentrically.
struct IconButton: View {
    let symbol: String
    let help: String
    var confirmed = false
    var role: ButtonRole?
    /// What VoiceOver says, when it isn't the tooltip (which may name a shortcut).
    var label: String?
    let action: () -> Void

    init(symbol: String, help: String, confirmed: Bool = false, role: ButtonRole? = nil, label: String? = nil,
         action: @escaping () -> Void) {
        self.symbol = symbol; self.help = help; self.confirmed = confirmed; self.role = role; self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            // Oct 21, Ryan ("simpler is better"): a new symbol (Copy's checkmark) replaces the
            // old one at once; it bounced under the pointer and swapped out of a blur. Oct 27,
            // Notion White: Arc UI's copy button (MIT), quick and quiet: the new symbol fades in
            // from 85 % in 0.16 s, the old one fades out in 0.1 s; no blur, no bounce.
            ZStack {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .id(symbol)
                    .transition(T.Look.floats
                        ? .asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.85)).animation(T.Look.swapIn),
                                      removal: .opacity.animation(T.Look.swapOut))
                        : .identity)
            }
            .frame(width: 28, height: 28)
            .contentShape(Circle())
        }
        .buttonStyle(IconButtonStyle(confirmed: confirmed, destructive: role == .destructive))
        // Oct 18, Ryan: in the primary language (a literal help is looked up as it's drawn).
        .help(L(key: help))
        .accessibilityLabel(L(key: label ?? help))
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

    @Environment(\.iconPlates) private var plates

    var body: some View {
        let lit = hover && enabled
        let pressed = configuration.isPressed
        let aligned = WindowLook.isAligned
        // Aligned: the notch's round buttons, a plate at rest (none inside a glass capsule, which
        // is the plate there), deeper under the pointer.
        let rest = aligned && plates ? T.Aligned.iconPlate : 0
        let hovered = aligned ? (plates ? T.Aligned.iconPlateHover : T.Shade.chosen) : T.Shade.chosen
        configuration.label
            .foregroundStyle(!enabled ? palette.tertiary
                             : confirmed ? palette.accent
                             : destructive && lit ? palette.danger
                             : (lit ? palette.text : palette.secondary))
            .background(
                Circle().fill(destructive && (lit || pressed) ? palette.dangerWash
                              : palette.ink(pressed ? T.Shade.pressed : (lit ? hovered : rest)))
            )
            .scaleEffect(aligned && pressed && !motion.reduce ? T.Aligned.pressScale : 1)
            .animation(aligned ? motion.animation(.press) : nil, value: pressed)
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
            .environment(\.iconPlates, false)
            .padding(4)
            .glass(Capsule())
    }
}

private struct IconPlatesKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
    /// Aligned: round icon buttons show their plate at rest, except inside a glass capsule.
    var iconPlates: Bool {
        get { self[IconPlatesKey.self] }
        set { self[IconPlatesKey.self] = newValue }
    }
}

/// A short upright hairline between groups in a glass capsule.
struct BarDivider: View {
    @Environment(\.palette) private var palette
    var body: some View {
        Rectangle().fill(palette.ink(T.Shade.line)).frame(width: 0.5, height: 16).padding(.horizontal, 4)
    }
}

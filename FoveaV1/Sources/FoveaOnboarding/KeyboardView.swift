import SwiftUI
import AppKit
import QuartzCore
import FoveaKit

/// The whole keyboard (Oct 8), up the whole time keys are taught (Oct 9), so it's plain where fn,
/// ⌃, ⌥ and ⌘ sit: the keys to press now are ringed in the accent, in turn; the keys held light
/// solid; a key pressed twice says "×2". A MacBook's layout, 15 units wide; every key's width
/// includes its share of the gap, so the rows line up.
struct KeyboardView: View {
    let pressed: Set<String>
    let targets: Set<String>
    let accent: Color
    var dark = false
    var unit: CGFloat = OT.Keyboard.unit
    /// A word on a ringed key ("×2" for a key pressed twice).
    var badges: [String: String] = [:]

    @Environment(\.firstRunReduced) private var reduced

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 0) {
                    ForEach(row) { key in cap(key, short: index == 0) }
                }
            }
        }
        .padding(unit * OT.Keyboard.platePadding)
        .background(RoundedRectangle(cornerRadius: unit * OT.Keyboard.plateRadius, style: .continuous)
            .fill(dark ? OT.Colors.keyboardPlateDark : OT.Colors.keyboardPlate))
        .overlay(RoundedRectangle(cornerRadius: unit * OT.Keyboard.plateRadius, style: .continuous)
            .strokeBorder(dark ? OT.Colors.islandHairline : OT.Colors.ink(0.08)))
        // Oct 21, perf: the keyboard's geometry as one group, so a key lit doesn't redraw all 76
        // labels (each its own text layer). It's a fixed size, so nothing moves differently.
        .geometryGroup()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pressed.isEmpty ? L("Keyboard, no keys held") : L("Keyboard, \(pressed.sorted().joined(separator: " ")) held"))
    }

    private func cap(_ key: Key, short: Bool) -> some View {
        let lit = key.match.map(pressed.contains) ?? false
        let target = !lit && (key.match.map(targets.contains) ?? false)
        let gap = unit * OT.Keyboard.gap
        let height = unit * (short ? OT.Keyboard.shortRow : 1)
        let radius = unit * OT.Keyboard.keyRadius
        // The keys to press now stand out: an accent ring, a wash of accent, the label in the
        // accent (Oct 21, Ryan ("simpler is better"): held still; they breathed); the rest step
        // back a little while there are keys to press.
        let quiet = !targets.isEmpty && !lit && !target
        let ink: Color = lit ? OT.Colors.keyCapLitText
            : target ? accent
            : (dark ? OT.Colors.white(quiet ? 0.45 : 0.7) : OT.Colors.ink(quiet ? 0.4 : 0.62))
        return ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(lit ? accent : target ? accent.opacity(0.16) : (dark ? OT.Colors.white(0.07) : OT.Colors.keyboardKey))
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(target ? accent : (dark ? OT.Colors.white(0.06) : OT.Colors.ink(0.1)),
                              lineWidth: target ? 2 : 0.5)
            VStack(spacing: 0) {
                Text(key.label)
                    .font(.system(size: unit * (key.word == nil ? OT.Keyboard.labelSize : OT.Keyboard.symbolSize),
                                  weight: key.match != nil ? .semibold : .regular))
                if let word = key.word, unit >= OT.Keyboard.wordsFrom {
                    Text(word).font(.system(size: unit * OT.Keyboard.wordSize, weight: .medium))
                }
            }
            .foregroundStyle(ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .frame(width: unit * key.width - gap, height: height - gap)
        .overlay(alignment: .topTrailing) {
            if let match = key.match, let badge = badges[match], Self.firstOf[match] == key.id, target || lit {
                Text(badge)
                    .font(.system(size: max(9, unit * OT.Keyboard.badgeSize), weight: .bold).monospacedDigit())
                    .foregroundStyle(OT.Colors.keyCapLitText)
                    .padding(.horizontal, unit * 0.14)
                    .frame(height: unit * OT.Keyboard.badgeHeight)
                    .background(Capsule().fill(accent))
                    .offset(x: unit * 0.22, y: -unit * 0.3)
                    // Oct 21, Ryan: from 0.6, not from nothing.
                    .transition(reduced ? .opacity : .opacity.combined(with: .scale(scale: OT.Motion.dotFrom)))
            }
        }
        .frame(width: unit * key.width, height: height)
    }

    /// The first key of each label (the left ⌘ of two): where its badge goes.
    private static let firstOf: [String: UUID] = {
        var first: [String: UUID] = [:]
        for key in rows.joined() { if let match = key.match, first[match] == nil { first[match] = key.id } }
        return first
    }()

    // MARK: The layout

    struct Key: Identifiable {
        let id = UUID()
        let label: String
        var word: String?
        var width: CGFloat = 1
        /// The label `keysDown` uses for this key, if it's one Fovea listens to.
        var match: String?
    }

    private static func letters(_ s: String) -> [Key] { s.map { Key(label: String($0).uppercased()) } }

    static let rows: [[Key]] = [
        [Key(label: "esc", width: 1.5, match: "esc")]
            + (1...12).map { Key(label: "F\($0)") } + [Key(label: "⏻", width: 1.5)],
        letters("`1234567890-=") + [Key(label: "delete", width: 2)],
        [Key(label: "tab", width: 1.5)] + letters("qwertyuiop[]") + [Key(label: "\\", width: 1.5)],
        [Key(label: "caps lock", width: 1.75)] + letters("asdfghjkl;'") + [Key(label: "return", width: 2.25, match: "return")],
        [Key(label: "shift", width: 2.25)] + letters("zxcvbnm,./") + [Key(label: "shift", width: 2.75)],
        [Key(label: "fn", word: "🌐", match: "fn"),
         Key(label: "⌃", word: "control", match: "⌃"),
         Key(label: "⌥", word: "option", match: "⌥"),
         Key(label: "⌘", word: "command", width: 1.25, match: "⌘"),
         Key(label: "", width: 5.5, match: "space"),
         Key(label: "⌘", word: "command", width: 1.25, match: "⌘"),
         Key(label: "⌥", word: "option"),
         Key(label: "◀"), Key(label: "▲▼"), Key(label: "▶")],
    ]
}

/// Oct 21, perf: a rounded rectangle (filled, or a ring `border` wide inside its edge) whose opacity
/// breathes from `from` to `to` and back on Core Animation: SwiftUI's `.easeInOut(duration:)
/// .repeatForever(autoreverses: true)` (the same cubic, 0.42 0 0.58 1), run by the render server,
/// so an ambient loop costs the app nothing per frame. The color is resolved as SwiftUI resolves
/// it here; `since` (CACurrentMediaTime) is when the loop began, so loops started together stay in
/// step. It never takes a click.
struct BreathingLayer: NSViewRepresentable {
    var color: Color
    var cornerRadius: CGFloat
    var continuous = true
    var border: CGFloat? = nil
    var from: Double
    var to: Double = 1
    var seconds: Double
    var since: CFTimeInterval

    func makeNSView(context: Context) -> BreathingLayerView { BreathingLayerView() }

    /// The size SwiftUI lays it out at, before AppKit puts the view on whole pixels: the shape is
    /// drawn at exactly this size, as SwiftUI would draw it.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: BreathingLayerView, context: Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height else { return nil }
        nsView.exactSize = CGSize(width: width, height: height)
        return nsView.exactSize
    }

    func updateNSView(_ view: BreathingLayerView, context: Context) {
        view.apply(color: color.resolve(in: context.environment).cgColor, cornerRadius: cornerRadius,
                   continuous: continuous, border: border, from: Float(from), to: Float(to),
                   seconds: seconds, since: since)
    }
}

final class BreathingLayerView: NSView {
    private let shape = CALayer()
    private var loop: (from: Float, to: Float, seconds: Double, since: CFTimeInterval)?
    /// SwiftUI's own size for it (`sizeThatFits`); the view's frame is that on whole pixels.
    var exactSize: CGSize? { didSet { if exactSize != oldValue { needsLayout = true } } }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.addSublayer(shape)
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let size = exactSize, size.width > 0, size.height > 0 {
            shape.frame = CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2,
                                 width: size.width, height: size.height)
        } else {
            shape.frame = bounds
        }
        CATransaction.commit()
    }

    func apply(color: CGColor, cornerRadius: CGFloat, continuous: Bool, border: CGFloat?,
               from: Float, to: Float, seconds: Double, since: CFTimeInterval) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.cornerRadius = cornerRadius
        shape.cornerCurve = continuous ? .continuous : .circular
        if let border {
            shape.backgroundColor = nil
            shape.borderColor = color
            shape.borderWidth = border
        } else {
            shape.backgroundColor = color
            shape.borderWidth = 0
        }
        shape.opacity = from
        CATransaction.commit()
        guard loop == nil || loop! != (from, to, seconds, since) else { return }
        loop = (from, to, seconds, since)
        let breathe = CABasicAnimation(keyPath: "opacity")
        breathe.fromValue = from
        breathe.toValue = to
        breathe.duration = seconds
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        breathe.beginTime = since
        breathe.isRemovedOnCompletion = false
        shape.add(breathe, forKey: "breathe")
    }
}

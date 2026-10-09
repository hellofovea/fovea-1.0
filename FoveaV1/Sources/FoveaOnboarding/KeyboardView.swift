import SwiftUI

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
    /// What to do with the ringed keys, said above them ("Press fn ⌃ to start."). The board's own
    /// keyboard has none: its instruction is typed beside it.
    var caption: String? = nil
    /// A word on a ringed key: "×2" on ⌘ for the whole screen.
    var badges: [String: String] = [:]

    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let caption, !caption.isEmpty {
                HStack(spacing: 6) {
                    if !targets.isEmpty {
                        Circle().fill(accent).frame(width: 6, height: 6).opacity(pulse ? 1 : 0.4)
                    }
                    Text(caption)
                        .font(.system(size: max(10, unit * OT.Keyboard.captionSize), weight: .semibold))
                        .foregroundStyle(dark ? OT.Colors.white(0.88) : OT.Colors.ink(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.opacity)
                }
                .padding(.horizontal, unit * 0.12)
                .padding(.bottom, unit * 0.28)
            }
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
        .onAppear { withAnimation(OT.Motion.keyPulse) { pulse = true } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Keyboard, \(pressed.isEmpty ? "no keys held" : pressed.sorted().joined(separator: " ") + " held")")
    }

    private func cap(_ key: Key, short: Bool) -> some View {
        let lit = key.match.map(pressed.contains) ?? false
        let target = !lit && (key.match.map(targets.contains) ?? false)
        let gap = unit * OT.Keyboard.gap
        let height = unit * (short ? OT.Keyboard.shortRow : 1)
        let radius = unit * OT.Keyboard.keyRadius
        // The keys to press now stand out: an accent ring that breathes, a wash of accent, the label
        // in the accent; the rest step back a little while there are keys to press.
        let quiet = !targets.isEmpty && !lit && !target
        let ink: Color = lit ? OT.Colors.keyCapLitText
            : target ? accent
            : (dark ? OT.Colors.white(quiet ? 0.45 : 0.7) : OT.Colors.ink(quiet ? 0.4 : 0.62))
        return ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(lit ? accent : (dark ? OT.Colors.white(0.07) : OT.Colors.keyboardKey))
            if target {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(accent.opacity(pulse ? 0.22 : 0.1))
            }
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(target ? accent.opacity(pulse ? 1 : 0.45) : (dark ? OT.Colors.white(0.06) : OT.Colors.ink(0.1)),
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
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: unit * key.width, height: height)
        .shadow(color: lit && !dark ? accent.opacity(0.35) : .clear, radius: 4, y: 1)
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

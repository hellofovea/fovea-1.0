import SwiftUI
import WindowBenchCore

/// A value Fovea inferred: computed, so in mono, with a dotted underline that says it can be
/// corrected. A click opens the correction as the Correction switch says: AppKit's popover, a
/// black card in the notch's language scaling from the line, or the choices inline under it.
/// A choice applies at once; the source of the inference shows in mono.
struct InferenceLink: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let key: String
    let inference: Inference
    var size: CGFloat? = nil

    var body: some View {
        let style = model.v(CorrectionStyle.self)
        let open = model.correction == key
        let scale = BenchTokens.Type_.scale(model.v(TypeScale.self))
        VStack(alignment: .leading, spacing: 0) {
            Button {
                model.animate(open ? .close : .open) { model.correction = open ? nil : key }
            } label: {
                // A correction swaps the line the notch's way: the guess out, then your choice in.
                SwapText(inference.text)
                    .font(BenchTokens.Type_.mono(size ?? scale.meta))
                    .foregroundStyle(open ? palette.text : palette.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.bottom, 3)
                    // Round dots, not the text system's dot pattern (short dashes in a mono face):
                    // dashed means "can't see" in the state shapes.
                    .overlay(alignment: .bottom) {
                        DottedRule()
                            .stroke(palette.tertiary, style: StrokeStyle(lineWidth: BenchTokens.Glyph.dotRule,
                                                                         lineCap: .round, dash: BenchTokens.Glyph.dot))
                            .frame(height: BenchTokens.Glyph.dotRule)
                    }
            }
            .buttonStyle(.plain)
            .help("Fovea inferred this. Click to correct it.")
            .popover(isPresented: Binding(get: { open && style == .native },
                                          set: { if !$0, model.correction == key { model.correction = nil } }),
                     arrowEdge: .bottom) {
                CorrectionChoices(key: key, inference: inference)
                    .padding(14)
                    .frame(minWidth: BenchTokens.Layout.popoverWidth)
            }
            .overlay(alignment: .topLeading) {
                if open && style == .notch {
                    NotchCard {
                        CorrectionChoices(key: key, inference: inference)
                            .environment(\.palette, .notch)
                    }
                    .frame(minWidth: BenchTokens.Layout.popoverWidth)
                    .fixedSize()
                    .offset(y: 22)
                    .transition(.modifier(active: NotchPop(progress: 0), identity: NotchPop(progress: 1)))
                    .zIndex(10)
                }
            }
            if open && style == .inline {
                // The choices and their well arrive together, in place: nothing slides over the
                // line above (the notch's content entrance).
                CorrectionChoices(key: key, inference: inference)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: BenchTokens.Layout.wellRadius, style: .continuous).fill(palette.well))
                    .fixedSize()
                    .padding(.top, 6)
                    .transition(.modifier(active: RevealIn(progress: 0), identity: RevealIn(progress: 1)))
            }
        }
    }
}

/// The alternatives, "Not this", a field for anything else, and where the guess came from.
struct CorrectionChoices: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let key: String
    let inference: Inference
    @State private var other = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Instead")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.tertiary)
                .padding(.bottom, 2)
            ForEach(inference.alternatives, id: \.self) { alternative in
                ChoiceRow(title: alternative) { model.applyCorrection(key, choice: alternative) }
            }
            ChoiceRow(title: "Not this", secondary: true) { model.applyCorrection(key, choice: nil) }
            HStack(spacing: 6) {
                TextField("Something else", text: $other)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                Button("Use") { model.applyCorrection(key, choice: other) }
                    .disabled(other.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top, 4)
            Rectangle().fill(palette.hairline).frame(height: BenchTokens.Layout.hairline).padding(.vertical, 6)
            // One line, never broken inside a name: the card takes the width it needs.
            Text(inference.source)
                .font(BenchTokens.Type_.mono(10.5))
                .foregroundStyle(palette.tertiary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

private struct ChoiceRow: View {
    @Environment(\.palette) private var palette
    let title: String
    var secondary = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(secondary ? palette.secondary : palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(RoundedRectangle(cornerRadius: BenchTokens.Notch.rowRadius, style: .continuous).fill(hover ? palette.hover : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// A black card with the notch's expanded corners, for things that come from the notch's
/// language inside the window (the notch popover, the receipt in Notch black).
struct NotchCard<Content: View>: View {
    var radius: CGFloat = BenchTokens.Notch.topRadius
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, BenchTokens.Notch.paddingH)
            .padding(.vertical, BenchTokens.Notch.paddingV)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(BenchTokens.Notch.surface))
            .environment(\.colorScheme, .dark)
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
    }
}

/// A horizontal rule along the bottom of its frame, stroked as dots by the caller.
struct DottedRule: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX + 0.6, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

/// The notch popover's entrance: from the line it came from, a little smaller, a 4 pt blur.
struct NotchPop: ViewModifier {
    let progress: CGFloat
    func body(content: Content) -> some View {
        content
            .scaleEffect(0.92 + 0.08 * progress, anchor: .topLeading)
            .opacity(Double(progress))
            .blur(radius: (1 - progress) * BenchTokens.MotionValues.contentBlur)
    }
}

extension BenchModel {
    /// Applies a correction at once: the new value replaces the inference, which now says it's yours.
    func applyCorrection(_ key: String, choice: String?) {
        let parts = key.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let stamp = Lines.clock(index.now)
        animate(.swap) {
            switch parts[0] {
            case "thread":
                if let i = library.threads.firstIndex(where: { $0.id == parts[1] }) {
                    let old = library.threads[i].routing
                    library.threads[i].routing = corrected(old, choice: choice, stamp: stamp)
                }
            case "capture":
                if let i = library.captures.firstIndex(where: { $0.id == parts[1] }), let old = library.captures[i].reason {
                    library.captures[i].reason = corrected(old, choice: choice, stamp: stamp)
                }
            default: break
            }
            correction = nil
        }
        status = choice.map { "Corrected to \($0)" } ?? "Marked “not this”"
    }

    private func corrected(_ old: Inference, choice: String?, stamp: String) -> Inference {
        guard let choice, !choice.trimmingCharacters(in: .whitespaces).isEmpty else {
            return Inference(text: "not \(old.text.components(separatedBy: " · ").first ?? old.text) · you said so",
                             source: "you said “not this”  \(stamp)  was: \(old.text)", alternatives: old.alternatives)
        }
        return Inference(text: "\(choice) · you chose it", source: "you corrected it  \(stamp)  was: \(old.text)",
                         alternatives: old.alternatives.filter { $0 != choice })
    }
}

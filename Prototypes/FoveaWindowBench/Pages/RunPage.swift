import SwiftUI
import WindowBenchCore

/// 2c / 04 · a run: your words large, the computed meta line, then the receipt the notch shares
/// (its words are the header here, so the card starts at the evidence).
struct RunPage: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let runID: String

    var body: some View {
        if let run = model.index.runByID[runID] {
            let scale = BenchTokens.Type_.scale(model.v(TypeScale.self))
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: BenchTokens.Layout.glyphGap) {
                            StateGlyph(state: run.state, arriving: model.arrivals.contains(run.id))
                                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                            Text(run.words)
                                .font(BenchTokens.Type_.runWords)
                                .foregroundStyle(palette.text)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                                .rowFrame("header/run/\(run.id)")
                        }
                        Text(Lines.runMeta(run, index: model.index))
                            .font(BenchTokens.Type_.mono(scale.meta))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(palette.secondary)
                            .padding(.leading, model.v(StateStyle.self) == .wordTint ? 0 : BenchTokens.Layout.glyphSlot + BenchTokens.Layout.glyphGap)
                    }
                    .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
                    .padding(.vertical, 4)
                    // Where a jump from the notch lands: a wash shows here, on the page, where it
                    // can be seen (on the black receipt it can't).
                    .jumpHighlight("run-header/\(run.id)")
                    .padding(.bottom, 16)
                    VStack(alignment: .leading, spacing: 0) {
                        EarlierAttempts(run: run)
                        RunReceipt(run: run)
                        RunBody(run: run)
                    }
                    .frame(maxWidth: BenchTokens.Layout.runMeasure, alignment: .leading)
                }
                .frame(maxWidth: BenchTokens.Layout.column, alignment: .leading)
                .padding(.horizontal, BenchTokens.Layout.sideMargin)
                .padding(.top, BenchTokens.Layout.topMargin)
                .padding(.bottom, BenchTokens.Layout.bottomMargin)
                .frame(maxWidth: .infinity)
            }
            // Opening the Output brings it into view: it sits under the body.
            .onChange(of: model.openFold, initial: true) { _, key in
                guard key == "output/\(runID)" else { return }
                withAnimation(model.motion.animation(.expand)) { proxy.scrollTo("output/\(runID)", anchor: .top) }
            }
            .onChange(of: model.runScrollTarget, initial: true) { _, target in
                guard let target, target.hasSuffix("/\(runID)") else { return }
                proxy.scrollTo(target, anchor: .bottom)
            }
            }
        }
    }
}

/// The receipt without its words (the page's header carries them).
struct RunReceipt: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var windowPalette
    let run: Run
    /// The copy the 带我去 flight lands as: drawn the same, but not the page's (no probe, no
    /// highlight, never hidden).
    var inFlight = false

    var body: some View {
        let surface = model.v(ReceiptSurface.self)
        let palette = surface == .notch ? Palette.notch : windowPalette
        let radius: CGFloat = surface == .system ? 10 : BenchTokens.Notch.slabRadius
        // The content swaps as one piece when the state changes (the notch's line swap), inside
        // a card that grows to fit: no line or pill is ever drawn over another.
        ZStack(alignment: .topLeading) {
            content(palette: palette)
                .id(run.state)
                .transition(.lineSwap)
        }
        .environment(\.palette, palette)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(surface == .notch ? BenchTokens.Notch.surface : (surface == .paper ? windowPalette.raised : Color(nsColor: .controlBackgroundColor)))
        }
        .overlay {
            if surface != .notch {
                RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(windowPalette.hairline)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .environment(\.colorScheme, surface == .notch ? .dark : (windowPalette.isDark ? .dark : .light))
        .animation(model.motion.animation(.expand), value: run.state)
        .animation(model.motion.animation(.swap), value: run)
        .modifier(PageReceipt(id: run.id, active: !inFlight))
    }

    private func content(palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            EvidenceLines(run: run)
            if !run.differences.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(run.differences.prefix(3), id: \.self) { difference in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("▲").font(.system(size: 10, weight: .bold))
                            Text(difference).font(BenchTokens.Type_.difference)
                        }
                        .foregroundStyle(palette.text)
                    }
                }
            }
            StateDetail(run: run)
            if let line = run.agentLine {
                (Text(line).foregroundStyle(palette.text) + Text(Lines.signature(model.index.thread(of: run)?.agent.name ?? "")).foregroundStyle(palette.tertiary))
                    .font(.system(size: 13.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            ReceiptActions(run: run)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


/// What only the page's own receipt does: it is where a jump lands, the flight's target, and
/// hidden while the flight carries it.
private struct PageReceipt: ViewModifier {
    @Environment(BenchModel.self) private var model
    let id: String
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content
                .jumpHighlight("receipt/\(id)")
                .probe("receipt/\(id)")
                .opacity(model.receiptHidden ? 0 : 1)
        } else {
            content
        }
    }
}

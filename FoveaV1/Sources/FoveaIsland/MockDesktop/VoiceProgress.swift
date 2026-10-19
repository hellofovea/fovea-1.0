import SwiftUI
import FoveaCore
import FoveaKit

// Transcribing and the undo window, drawn in the bar's 44 pt band under the notch. Chosen
// (docs/island/PROGRESS.md): "Thinking" with SF Symbols' ellipsis over a 4 pt line that fills;
// the undo window, a 4 pt line that drains. Progress is read from the clock through a
// TimelineView, so it moves on the display's frames, never through state churn.

/// "Thinking" and Apple's ellipsis lighting its dots in turn: the only words while the voice is
/// turned into words (the transcript is kept, never shown). Still under Reduce Motion.
struct ThinkingText: View {
    let still: Bool
    // Oct 18, Ryan: in the primary language.
    var label = L("island.thinking", english: "Thinking")

    var body: some View {
        let P = WorkbenchTokens.Progress.self
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(label)
            Image(systemName: "ellipsis")
                .symbolEffect(.variableColor.iterative.dimInactiveLayers.nonReversing, options: .repeating, isActive: !still)
        }
        .font(P.text)
        .foregroundStyle(P.labelPeak)
        .lineLimit(1)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

/// Transcribing: "Thinking…" over the line filling leading to trailing.
struct TranscribingBand: View {
    let model: WorkbenchModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let P = WorkbenchTokens.Progress.self
        let running = model.notchState == .transcribing && !model.snapshotMode
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !running)) { context in
            let p = model.transcribeProgress(at: context.date)
            VStack(spacing: P.rowGap) {
                ThinkingText(still: reduceMotion || model.snapshotMode)
                    .frame(height: P.rowHeight)
                ProgressLine(fraction: p)
            }
            .padding(.horizontal, P.paddingH)
            .padding(.top, P.paddingTop)
            .frame(maxHeight: .infinity, alignment: .top)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("island.thinking", english: "Thinking"))
            .accessibilityValue("\(Int(p * 100)) percent")
        }
    }
}

/// Cancelled: what happened, the one way back, and the line draining over the time left.
struct CancelledBand: View {
    let model: WorkbenchModel

    /// The Undo pill's center, in the band (x from the band's center, y from its top).
    static func undoCenter() -> CGPoint {
        let P = WorkbenchTokens.Progress.self
        let half = WorkbenchTokens.Island.spec.softwareIslandWidth / 2
        return CGPoint(x: half - P.paddingH - P.pillWidth / 2, y: P.paddingTop + P.rowHeight / 2)
    }

    var body: some View {
        let P = WorkbenchTokens.Progress.self
        let running = model.notchState == .cancelled && !model.snapshotMode
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !running)) { context in
            let remaining = model.undoRemaining(at: context.date)
            VStack(spacing: P.rowGap) {
                HStack(spacing: 0) {
                    Text("Cancelled").font(P.text).foregroundStyle(P.secondary)
                    Spacer(minLength: 8)
                    UndoPill(remaining: remaining) { model.undoCancel() }
                }
                .frame(height: P.rowHeight)
                ProgressLine(fraction: remaining)
            }
            .padding(.horizontal, P.paddingH)
            .padding(.top, P.paddingTop)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

/// No speech detected: one line of SF Pro, the system's own face, centered in the band.
struct NoSpeechBand: View {
    var body: some View {
        let P = WorkbenchTokens.Progress.self
        Text("No speech detected")
            .font(P.text)
            .foregroundStyle(P.noSpeechColor)
            .lineLimit(1)
            .padding(.horizontal, P.paddingH)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("No speech detected")
    }
}

/// Undo: the stack's pill, a little brighter since it is the one action.
struct UndoPill: View {
    let remaining: Double
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let P = WorkbenchTokens.Progress.self
        let secondsLeft = Int((remaining * P.undoDuration.seconds).rounded(.up))
        Button(action: action) {
            HStack(spacing: P.pillSpacing) {
                Image(systemName: "arrow.uturn.backward").font(P.pillGlyph)
                Text("Undo")
            }
            .font(P.pillFont)
            .foregroundStyle(P.pillText)
            .frame(width: P.pillWidth, height: P.pillHeight)
            .background(Capsule(style: .continuous).fill(hovering ? P.pillFillHover : P.pillFill))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Undo (⌘Z)")
        .accessibilityLabel("Undo")
        .accessibilityValue("\(secondsLeft) seconds left")
    }
}

/// The 4 pt line: the shipping Island's white 85 % over white 14 %, round caps, filled from the
/// leading edge to `fraction` (Transcribing fills it; the undo window drains it).
struct ProgressLine: View {
    let fraction: Double

    var body: some View {
        let P = WorkbenchTokens.Progress.self
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(P.track)
                Capsule().fill(P.fill).frame(width: geo.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: P.lineWeight)
        .accessibilityHidden(true)
    }
}

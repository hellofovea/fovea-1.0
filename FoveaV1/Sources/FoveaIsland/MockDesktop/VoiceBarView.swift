import SwiftUI

/// The Listening Flowing Bar's content: nine short white capsules, centered, following the
/// microphone. No icon, no label, no buttons (PRD §9). Every bar rests at its shortest; the
/// voice moves the middle, on a bell curve, so the edge bars stay short and the middle
/// carries the fluctuation. The outer bounds never move.
struct VoiceBarView: View {
    let level: Float
    /// Oct 21, perf: the level now, read on each of the waveform's frames when its clock runs
    /// (in place of `level`), so the level needn't be observed and draw frames of its own.
    var liveLevel: (() -> Float)? = nil
    /// Snapshots: one fixed frame, so a PNG is the same every time.
    let still: Bool
    /// While hidden the timeline pauses in place. The view keeps its identity either way:
    /// swapping views under an animation throws the container's timing off.
    var paused = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if still {
                waveform(Self.heights(level: Double(level), time: 1.3, frozen: true))
            } else if reduceMotion {
                waveform(Self.heights(level: Double(level), time: 0, frozen: true))
            } else {
                TimelineView(.animation(minimumInterval: 1 / WorkbenchTokens.Island.waveformFrameRate, paused: paused)) { context in
                    waveform(Self.heights(level: Double(liveLevel?() ?? level), time: context.date.timeIntervalSinceReferenceDate))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement()
        .accessibilityLabel("Listening")
    }

    private func waveform(_ heights: [CGFloat]) -> some View {
        HStack(alignment: .center, spacing: WorkbenchTokens.Island.waveformBarGap) {
            ForEach(heights.indices, id: \.self) { i in
                Capsule(style: .continuous)
                    .fill(WorkbenchTokens.Island.waveform)
                    .frame(width: WorkbenchTokens.Island.waveformBarWidth, height: heights[i])
            }
        }
        .frame(height: WorkbenchTokens.Island.waveformMaxHeight)
    }

    /// How much of the level each bar takes: a bell centered on the middle bar, so the edges
    /// take almost none of it.
    static var gain: [Double] {
        let bars = WorkbenchTokens.Island.waveformBars
        let spread = WorkbenchTokens.Island.waveformSpread
        return (0..<bars).map { i in
            let x = Double(i) / Double(bars - 1) * 2 - 1
            return exp(-(x * x) / (2 * spread * spread))
        }
    }

    /// Each bar's height for a level (0…1) at a moment. Pure, so the checks can read it. The voice
    /// flutters each bar a little differently so it reads as a waveform; silence is flat (Oct 21,
    /// Ryan, "simpler is better": the bars no longer wobble on their own with no voice).
    static func heights(level: Double, time: TimeInterval, frozen: Bool = false) -> [CGFloat] {
        let minH = WorkbenchTokens.Island.waveformMinHeight
        let maxH = WorkbenchTokens.Island.waveformMaxHeight
        let boost = WorkbenchTokens.Island.waveformGainBoost
        return gain.enumerated().map { i, g in
            let flutter = frozen ? 1.0 : 0.72 + 0.28 * sin(time * 11 + Double(i) * 1.9)
            let amount = min(1, max(0, g * level * boost * flutter))
            return minH + (maxH - minH) * CGFloat(amount)
        }
    }
}

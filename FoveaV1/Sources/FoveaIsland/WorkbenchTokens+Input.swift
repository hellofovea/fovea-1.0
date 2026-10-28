import SwiftUI

// The Oct 15 review's numbers for the notch's input side (docs/v1/REVIEW_2026-10-15.md): the
// stack's "+N" and its referents' numbers (VF04, VF05, QA02), the opened row's scroll, Paste beside
// Copy (VF09/VF10), the notices' wider capsule (NH-04). Kept apart from WorkbenchTokens.swift so the
// review's additions read as one piece; the same rules hold (ink at an opacity, no colors).

extension WorkbenchTokens.Referents {
    // VF04: "+N" on the collapsed stack, right of the third card, riding its fan.
    static let moreHeight: CGFloat = 16
    static let moreGap: CGFloat = 3
    static let morePaddingH: CGFloat = 5
    /// A character of the chip's label at its size (10 pt semibold, tabular digits).
    static let moreCharWidth: CGFloat = 6.2
    static let moreFont = Font.system(size: 10, weight: .semibold).monospacedDigit()
    static var moreFill: Color { WorkbenchTokens.ink(0.14) }
    static var moreText: Color { WorkbenchTokens.ink(0.85) }

    // VF04/QA02: each referent's number, opened, on the ✕'s dark disc (top left).
    static let numberSize: CGFloat = 16
    static let numberInset: CGFloat = 5
    static let numberWidePadding: CGFloat = 3
    static let numberFont = Font.system(size: 9.5, weight: .bold).monospacedDigit()
    static var numberFade: Animation { WorkbenchTokens.Spring.fadeIn(0.15) }
    /// VF05: the other display's glyph, on the same disc (lower left).
    static let otherDisplayGlyph = Font.system(size: 7.5, weight: .bold)

    // VF04: one row, scrolled sideways; its thumb under it, as an overlay scroller's.
    static let scrollThumbHeight: CGFloat = 3
    static let scrollThumbGap: CGFloat = 5
    static let scrollThumbMin: CGFloat = 24
    static var scrollThumbFill: Color { WorkbenchTokens.ink(0.32) }
    /// A mouse wheel's line, in points (a trackpad's swipe comes in points already).
    static let scrollLine: CGFloat = 12
    /// The row follows the fingers: a spring short enough to feel direct.
    static let scrollFollow: Animation = .interactiveSpring(response: 0.18, dampingFraction: 1)
}

extension WorkbenchTokens.Motion {
    /// IS05: the island goes home to the notch's display once the session is done and its closing
    /// spring has finished (the window is put away after 0.7 s).
    static let homeAfterRest: Duration = .milliseconds(750)
}

extension WorkbenchTokens.Paste {
    // VF09/VF10: Paste beside Copy, quieter (Copy keeps its place and its fill): the chevron's
    // hover fill as its own, the transcript's ink.
    static var pasteFill: Color { WorkbenchTokens.ink(0.1) }
    static var pasteFillHover: Color { WorkbenchTokens.ink(0.16) }
    static var pasteFillPressed: Color { WorkbenchTokens.ink(0.22) }
    static var pasteText: Color { WorkbenchTokens.ink(0.85) }
    static let buttonGap: CGFloat = 6
    /// "No field" stays this long on Paste when nothing takes the words.
    static let missedHold: Duration = .milliseconds(1600)
}

extension WorkbenchTokens.Feedback {
    /// NH-04: a notice whose action is a long label ("Choose Microphone…") is this much wider.
    static var noticeWideExtra: CGFloat { WorkbenchTokens.size(64) }
}

extension WorkbenchTokens.FeedbackV2 {
    // QA02: Choose chat's fanned row, its numbers on the thumbs (a size down), and the bridge
    // between the stack and the row so moving from one to the other never closes it.
    static let fanBadgeScale: CGFloat = 0.85
    static let fanBadgeInset: CGFloat = 3
    static let fanCloseDelay: Duration = .milliseconds(120)
}

extension WorkbenchTokens.Capture {
    // Oct 17, Ryan: words and files with no key. After a press is let go, the app is given this
    // long to make its selection before it's read; a selection counts as the press's when one of
    // its lines comes within this of where the press went.
    static let selectionSettle: Duration = .milliseconds(120)
    static let selectionSlack: CGFloat = 24
    /// Oct 18, Ryan: while a drag goes on, the app's selection is read this often (at most).
    static let dragReadInterval: TimeInterval = 0.03
    /// The mark windows check their window (moved, covered, minimised, another Space) this often.
    static let markFollowInterval: TimeInterval = 0.25
}

extension WorkbenchTokens.Feedback {
    // Oct 17, Ryan: words taken while Fovea listens, marked as a highlighter would: the accent at
    // this opacity, a little proud of the line.
    static let takenMarkOpacity: Double = 0.32
    static let takenMarkOutset: CGFloat = 1.5
}

extension WorkbenchTokens.Capture {
    // Oct 17, Ryan: files dragged onto the notch. The drop target reaches this far past the island
    // (the notch is small to aim at); it stays a moment after the mouse is let go so the drop lands.
    static let dropSlack: CGFloat = 28
    static let dropLinger: Duration = .milliseconds(450)
    // Oct 27, Ryan: "the real notch blocks a part (middle) of the notch, so users cant really see
    // … when notch detects user is dragging a file towards the notch, it opens further down for the
    // user to see. but make sure do not have any design covered up by the real notch." A drag this
    // close to the notch opens the drop zone, floating under it: its size, the room round its
    // well, the well's corner and dashes.
    static let dropApproach: CGFloat = 160
    static let dropZoneWidth: CGFloat = 300
    static let dropZoneHeight: CGFloat = 58
    static let dropZonePadding: CGFloat = 8
    static let dropZoneRadius: CGFloat = 16
    static let dropWellRadius: CGFloat = 9
    static let dropWellStroke: CGFloat = 1.25
    static let dropWellDash: [CGFloat] = [4, 3]
    static let dropGlyph: CGFloat = 15
    static var dropWellIdle: Color { WorkbenchTokens.ink(0.28) }
    static let dropWellFill: Double = 0.14
    static let dragPollInterval: TimeInterval = 0.08
    // Oct 25, Ryan: many files dropped at once. Each card leaves this long after the one before,
    // the last within the spread however many there are; they wait in a pile, each a little
    // down and right of the one before, up to the depth.
    static let dropStagger: Duration = .milliseconds(70)
    static let dropSpread: Duration = .milliseconds(560)
    static let dropPileOffset: CGFloat = 5
    static let dropPileDepth = 3
}

extension WorkbenchTokens.Feedback {
    // Oct 17, Ryan: the drop state when a file is dragged over the notch: a well in the accent,
    // inset in the bar (or Choose chat), its line in the bar notice's face.
    static let dropWellInset: CGFloat = 5
    static let dropWellRadius: CGFloat = 9
    static let dropWellStroke: CGFloat = 1.5
    static let dropWellFill: Double = 0.16
    static var dropIn: Animation { WorkbenchTokens.Spring.fadeIn(0.14) }
}

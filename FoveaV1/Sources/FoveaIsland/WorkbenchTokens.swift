import SwiftUI
import FoveaCore
import FoveaKit

/// Every size, color, material and face the workbench draws with, in one place (root
/// AGENTS.md). The notch's numbers come from Core, `ScreenMetrics.notched` and
/// `IslandLayoutSpec`, so the mock matches what the Island is laid out against.
enum WorkbenchTokens {
    enum Layout {
        /// The desktop's files: a column at its right, under the menu bar.
        static let desktopFilesTop: CGFloat = 22
        static let desktopFilesTrailing: CGFloat = 26
        static let windowDefault = CGSize(width: 1240, height: 820)
        static let windowMin = CGSize(width: 900, height: 600)
        /// The control panel column: an inspector's range, wide enough for a labelled slider.
        static let sidebarMin: CGFloat = 220
        static let sidebarIdeal: CGFloat = 260
        static let sidebarMax: CGFloat = 400

        static let menuBarSidePadding: CGFloat = 16
        static let menuBarItemSpacing: CGFloat = 20
        static let menuBarStatusSpacing: CGFloat = 14
        static let menuBarStatusIconSize: CGFloat = 14

        /// The mock display: a 13-inch MacBook, 1470×956 points with the 200×32 notch (Core's
        /// sample). Scaled to fit the column and never above 1:1, so its proportions are a
        /// MacBook's whatever the window or the panel does.
        static let display = ScreenMetrics.sampleNotched
        /// The lid's bezel around the screen, in display points; the notch is part of it.
        static let bezel: CGFloat = 12
        static let bezelRadius: CGFloat = 22
        /// A notched Mac's screen has rounded top corners and square bottom ones.
        static let screenCornerRadius: CGFloat = 12
        /// The lid's size in display points: the screen plus the bezel.
        static var lid: CGSize {
            CGSize(width: display.frame.width + 2 * bezel, height: display.frame.height + 2 * bezel)
        }

        static let dockIconSize: CGFloat = 40
        static let dockPadding: CGFloat = 6
        static let dockSpacing: CGFloat = 8
        static let dockBottomInset: CGFloat = 8
        static let dockRadius: CGFloat = 16
        static let dockDividerHeight: CGFloat = 28
    }

    /// Fovea's surface at the notch, as the shipping Island draws it: the geometry is Core's
    /// `IslandLayoutSpec` (the production numbers), the waveform `Tokens.Island.Layout`'s.
    /// docs/island/VOICE_BAR.md says why these are the numbers.
    enum Island {
        /// The island's geometry as this workbench draws it, pinned here so it doesn't move when
        /// Core's defaults do: the voice bar 44 pt below the notch (docs/island/VOICE_BAR.md),
        /// open shapes with 19 pt ears and 24 pt bottom corners.
        static let spec: IslandLayoutSpec = {
            var spec = IslandLayoutSpec()
            spec.voiceBelow = 44
            spec.expandedTopRadius = 19
            spec.expandedBottomRadius = 24
            return spec
        }()
        static let surface = Color.black
        /// White, in either design, never the accent or another color (Yulun, Oct 9): on Native's
        /// light glass, the glass's own ink, the one neutral that reads there.
        static var waveform: Color { ink(1) }
        static let waveformBars = 9
        /// 4 pt bars, 4 pt apart: a 1 : 1 bar-to-gap ratio like the reference image and Apple's
        /// regular-weight `waveform` symbol; the width balances the peak's proportion against
        /// the middle bar's travel (docs/island/VOICE_BAR.md, "Bar thickness").
        static let waveformBarWidth: CGFloat = 4
        static let waveformBarGap: CGFloat = 4
        /// A silent bar is a dot a third taller than it is wide, the reference's proportion.
        static let waveformMinHeight: CGFloat = waveformBarWidth * 4 / 3
        static let waveformMaxHeight: CGFloat = 20
        static let waveformFrameRate: Double = 40
        /// Nine bars and the gaps between them.
        static var waveformSpan: CGFloat {
            CGFloat(waveformBars) * waveformBarWidth + CGFloat(waveformBars - 1) * waveformBarGap
        }
        /// Width of the bell that spreads the level across the bars (in the bars' -1…1 span):
        /// the middle bar takes all of it, the edges about 4%.
        static let waveformSpread: Double = 0.4
        /// The level is lifted a little so ordinary speech reaches the middle bar's full height.
        static let waveformGainBoost: Double = 1.25
        /// The level a snapshot shows the bars at: mid speech, so the middle's rise reads.
        static let snapshotLevel: Float = 0.6
    }

    /// Oct 21, Ryan: "research what spring animation is, then apply it to our Dynamic Island as
    /// well as all the other places that need this", and then "don't always use spring
    /// animations; use the correct animations": springs for the island's own morphs, its small
    /// parts and a thrown chat; inside its panels, the curve each thing calls for (content in and
    /// out on the strong ease-out, a move on the strong ease-in-out, hovers on `ease`, press
    /// feedback on ease-out, anything timed linear). The island's motion, one palette
    /// (docs/motion/SPRINGS.md › Island has each one's settling time and overshoot, computed from
    /// SwiftUI's own `Spring`). Interpolating springs, so a morph re-aimed mid-flight keeps its
    /// velocity; a subtle bounce because the island is alive: the most on its smallest, most
    /// frequent move (rest to a voice bar, so the bounce reads), less on the large panels (which
    /// settle longer), and next to none on the way home (exits shorter, simpler). Content only
    /// fades, on the strong ease-out curve. With Reduce Motion each one is a short ease-out with
    /// nothing bouncing (`reduced`, the person's Appearance › Motion or the Mac's).
    enum Spring {
        /// Whether motion is reduced now: the model says (WorkbenchModel.init).
        nonisolated(unsafe) static var reduced: () -> Bool = { false }
        /// With Reduce Motion, a short ease-out instead: nothing moves on a spring or bounces.
        static func or(_ spring: Animation) -> Animation { reduced() ? fade : spring }
        // Oct 21 motion review: the strong ease-out the window and the first run fade on under
        // Reduce Motion, not SwiftUI's weaker built-in `.easeOut`; every Reduce Motion fade in the
        // island (views and model alike) asks for this one.
        static var fade: Animation { fadeIn(Motion.reduceMotionFade) }

        /// Rest → a voice bar (fn, fn ⌃): the smallest growth, seen tens of times a day; at 98% in
        /// 0.12 s. Oct 21, Ryan ("simpler is better"): the one spring left with a little life, a
        /// touch of overshoot (bounce 0.12, under a point); it was 0.3.
        static var barGrow: Animation { or(.interpolatingSpring(duration: 0.24, bounce: 0.12)) }
        /// A bar → rest: quicker than it came, no visible bounce; the outline swallows the content.
        static var barShrink: Animation { or(.interpolatingSpring(duration: 0.18, bounce: 0.06)) }
        /// Rest or a bar → a panel (held words, Choose chat, the board on hover, a session): larger,
        /// so a longer settle. Oct 21, Ryan ("simpler is better"): no bounce on a panel.
        static var panelGrow: Animation { or(.interpolatingSpring(duration: 0.34, bounce: 0)) }
        /// Rest → the board, when the pointer comes to the notch (Oct 21, Ryan: "expand faster when
        /// my mouse hovers"): the same shape as `panelGrow`, shorter: at 98% in about 0.16 s.
        static var boardOpen: Animation { or(.interpolatingSpring(duration: 0.26, bounce: 0)) }
        /// A panel → rest (or a bar): shorter than its entrance, no visible bounce.
        static var panelShrink: Animation { or(.interpolatingSpring(duration: 0.26, bounce: 0.06)) }
        /// The island changing size within a state (the stack opening, a notice, Choose chat's
        /// list, the board to a session), critically damped.
        static var resize: Animation { or(.interpolatingSpring(duration: 0.3, bounce: 0)) }
        /// …and folding back within a state: shorter, no visible bounce.
        static var fold: Animation { or(.interpolatingSpring(duration: 0.24, bounce: 0.06)) }
        /// The island's small parts (cards opening, the +N, chips), critically damped.
        static var part: Animation { or(.interpolatingSpring(duration: 0.28, bounce: 0)) }
        /// …and going back: quick, no visible bounce.
        static var partBack: Animation { or(.interpolatingSpring(duration: 0.22, bounce: 0.08)) }
        /// A capture flying from the screen into the stack: a long way, landing without overshoot.
        static var flight: Animation { or(.interpolatingSpring(duration: 0.42, bounce: 0)) }
        /// A pulled-out chat let go: it carries the pointer's velocity (relative to the distance
        /// left) into a spring with a little bounce, because it was thrown (0.1; it was 0.2).
        static func thrown(_ velocity: Double = 0) -> Animation {
            or(.interpolatingSpring(duration: 0.4, bounce: 0.1, initialVelocity: velocity))
        }
        /// Moved, not thrown (a chat's corner let go past its sizes, back within them): the end
        /// of a gesture, so a spring, critically damped.
        static var reposition: Animation { or(.spring(duration: 0.4, bounce: 0)) }

        // Curves, inside the panels (Oct 21, Ryan: "don't always use spring animations").
        /// Moving on screen, not alive or thrown: the board's rows reordering, a scroll to a
        /// request. The strong ease-in-out (cubic), short.
        static var rows: Animation { or(.timingCurve(0.645, 0.045, 0.355, 1, duration: 0.28)) }
        /// A hover: `ease`, quick (seen dozens of times a day), on a fill or a small lean.
        static var hover: Animation { .timingCurve(0.25, 0.1, 0.25, 1, duration: 0.12) }
        /// Press feedback: a control gives a little and comes back, ease-out (with Reduce Motion
        /// it dims instead).
        static let press: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.14)
        static let pressScale: CGFloat = 0.97
        // Oct 21 motion review: the same dim the window (`T.Motion.pressDim`) and the first run
        // (`OT.Motion.pressDim`) give a press under Reduce Motion, so a press reads alike everywhere.
        static let pressDim: Double = 0.75
        /// Content appearing or going (text, icons, glows, notices' words, the drop well, Copied):
        /// the strong ease-out curve; exits shorter than entrances.
        static func fadeIn(_ duration: Double) -> Animation { .timingCurve(0.23, 1, 0.32, 1, duration: duration) }
        static func fadeOut(_ duration: Double) -> Animation { .timingCurve(0.23, 1, 0.32, 1, duration: duration) }
        /// Its control points, for what AppKit fades (the marks over other apps' windows).
        static let easeOutPoints: (Float, Float, Float, Float) = (0.23, 1, 0.32, 1)
        /// A pulled-out chat's momentum: Apple's projection (Designing Fluid Interfaces), with a
        /// window's quicker deceleration (0.99, not a scroll view's 0.998): a flick of 1000 pt/s
        /// glides about 100 pt on.
        static let deceleration: Double = 0.99
        static func project(_ velocity: Double) -> Double { velocity / 1000 * deceleration / (1 - deceleration) }
        /// Past the screen's edges a dragged chat resists more the further it goes (Apple's
        /// rubber band, 0.55).
        static let rubber: Double = 0.55
        static func rubberBand(_ overshoot: Double, dimension: Double) -> Double {
            guard dimension > 0 else { return 0 }
            return overshoot * dimension * rubber / (dimension + rubber * abs(overshoot))
        }
    }

    /// Island motion: the shape on the palette's springs (`Spring`), the content a short
    /// strong ease-out crossfade with it (docs/island/VOICE_BAR.md). Interpolating springs
    /// on purpose: measured frame by frame, `.smooth` and `.spring(duration:bounce:)` hand the
    /// outline about 85% of a growth on its first frame and then creep; the interpolating spring
    /// moves through the whole range both ways. Oct 21, Ryan: a touch of bounce on the voice bar
    /// alone (`Spring.barGrow`).
    enum Motion {
        static var open: Animation { Spring.barGrow }
        static var close: Animation { Spring.barShrink }
        /// The waveform coming in: a short strong ease-out crossfade, with the shape.
        static var content: Animation { Spring.fadeIn(0.14) }
        /// The waveform (and a panel's content) going out: Oct 21, Ryan: a curve, not the
        /// closing spring: the strong ease-out, shorter than it came in, gone as the outline closes.
        static var contentOut: Animation { Spring.fadeOut(0.1) }
        static let reduceMotionFade: Double = 0.12
        /// Oct 21, perf: how long a band's moving parts keep moving after it stops showing, so
        /// they hold still only once it has faded out (longer than any band's way out).
        static let bandLinger: Double = 1
        /// Oct 21, perf: a once-a-second clock's tick while its band is hidden (in effect, none).
        static let hiddenTick: Double = 3600
    }

    /// The referent stack in the voice bar and its expansion; docs/island/REFERENT_STACK.md
    /// has the reasons. Radii are concentric with the island: inner = outer − inset.
    enum Referents {
        // Collapsed, in the bar's 44 pt band.
        /// From the band's top, bottom and left edges.
        static let inset: CGFloat = 8
        static var thumbHeight: CGFloat { Island.spec.voiceBelow - 2 * inset }
        /// 14 pt bottom corner − 8 pt inset.
        static var radius: CGFloat { Island.spec.compactBottomRadius - inset }
        /// A landscape card in the stack, whatever the capture's own shape.
        static let stackAspect: CGFloat = 1.43
        static let capsuleAspect: CGFloat = 1.6
        /// Captures keep their own shape when laid out, within these bounds.
        static let aspectRange: ClosedRange<CGFloat> = 0.6...2.2
        static let maxLayers = 3
        /// Each card behind peeks out this far to the right…
        static let layerOffset: CGFloat = 5
        /// …is this much smaller…
        static let layerShrink: CGFloat = 0.08
        /// …and dimmer, like the reference's back cards at half opacity (Oct 21, Ryan, "simpler is
        /// better": no tilt, no fan on hover, no growing under the pointer).
        static let layerOpacity: Double = 0.6
        /// Room between the stack and the waveform, which moves right to make it.
        static let waveformGap: CGFloat = 8

        // Expanded: every capture in rows, flowing right from the first.
        static let expandedThumbHeight: CGFloat = 60
        static let expandedMinThumbHeight: CGFloat = 36
        static let expandedMaxRows = 3
        static let expandedSpacing: CGFloat = 10
        static let expandedPadding: CGFloat = 16
        /// 24 pt bottom corner − 16 pt padding.
        static var expandedRadius: CGFloat { Island.spec.expandedBottomRadius - expandedPadding }
        static var expandedMaxWidth: CGFloat { Island.spec.reviewWidth }
        static let footerHeight: CGFloat = 28
        static let footerGap: CGFloat = 12
        static let closeWidth: CGFloat = 54
        static let closeHeight: CGFloat = 22
        static let closePaddingH: CGFloat = 9
        static let closeSpacing: CGFloat = 5
        static let closeGlyph = Font.system(size: 9, weight: .bold)
        static let closeLabel = Font.system(size: 11, weight: .medium)
        static var closeFill: Color { ink(0.12) }
        static var closeFillHover: Color { ink(0.2) }
        static var closeText: Color { ink(0.75) }
        static var border: Color { ink(0.2) }
        static let borderWidth: CGFloat = 0.75
        /// The island opening to show every capture, and closing, both critically damped; the
        /// cards move with it (Oct 21, Ryan, "simpler is better": no beat behind, no stagger).
        static var expand: Animation { Spring.resize }
        static var collapse: Animation { Spring.fold }
        /// A capture joining the stack, and the stack changing shape.
        static var settle: Animation { Spring.resize }
        /// The stack getting smaller (one removed): back without a bounce.
        static var shrink: Animation { Spring.fold }
        /// A card taking its new place (one joined or left): a small part.
        static var cardSettle: Animation { Spring.part }
        static var closeIn: Animation { Spring.fadeIn(0.18) }

        // One capture, looked at closely: the same card, grown inside the island.
        static let inspectMaxHeight: CGFloat = 300
        static let inspectAspectRange: ClosedRange<CGFloat> = 0.4...3.0
        static var inspect: Animation { Spring.resize }
        static let captionGap: CGFloat = 10
        static let caption = Font.system(size: 11.5)
        static var captionColor: Color { ink(0.55) }
        /// The others step back while one is looked at.
        static var othersFade: Animation { Spring.fadeOut(0.15) }

        // Removing one: a small dark disc with a white cross, the island's own black and white,
        // in the card's top-right corner, on hover.
        static let removeSize: CGFloat = 18
        static let removeInset: CGFloat = 5
        static let removeGlyph = Font.system(size: 8, weight: .bold)
        /// The island's raised black (Tokens.Island.Colors.surfaceElevated, #111114).
        static let removeFill = Color(.sRGB, red: 0x11 / 255.0, green: 0x11 / 255.0, blue: 0x14 / 255.0)
        static let removeFillHover = Color(.sRGB, red: 0x2A / 255.0, green: 0x2A / 255.0, blue: 0x2E / 255.0)
        // White on the ✕'s own dark disc in either glass (the glass's ink drew it black on black in
        // Light, Oct 11).
        static let removeGlyphColor = Color.white.opacity(0.9)
        static let removeRing = Color.white.opacity(0.28)
        static var removeAppear: Animation { Spring.fadeIn(0.12) }
        /// A removed card fades as the rest close the gap, then leaves.
        static var departFade: Animation { Spring.fadeOut(0.16) }
        static let departDelay: Duration = .milliseconds(220)
        static var closeOut: Animation { Spring.fadeOut(0.1) }
    }

    /// Transcribing's progress and the undo window's countdown, in the 44 pt band
    /// (docs/island/PROGRESS.md). The line, the track and the fill are the shipping Island's
    /// (2 pt, white 85 % on white 14 %); the rest are the designs to compare.
    enum Progress {
        static var track: Color { ink(0.14) }
        /// The waveform's white too, never a color (Yulun, Oct 9).
        static var fill: Color { ink(0.85) }
        static let paddingH: CGFloat = 16
        static let paddingTop: CGFloat = 6
        static let rowHeight: CGFloat = 24
        static let rowGap: CGFloat = 6
        static let text = Font.system(size: 13.5)
        static var textColor: Color { ink(1) }
        static var secondary: Color { ink(0.55) }
        // "Thinking" and its ellipsis, and the line under it.
        static var labelPeak: Color { ink(0.95) }
        /// Chosen: 4 pt (the shipping Island draws 2 pt; WWDC23 asks for "thicker shapes").
        static let lineWeight: CGFloat = 4
        static let wordInterval: Duration = .milliseconds(150)
        /// A listening session shorter than this said nothing: it transcribes to "No speech detected".
        static let minimumSpeech: Duration = .milliseconds(500)
        /// Fovea: the real words come back as soon as they can; the line runs at least this long.
        static let minimumLiveTranscribe: Double = 0.6
        /// How long an empty transcription thinks before it says so.
        static let emptyTranscribe: Duration = .milliseconds(900)
        /// "No speech detected" (Apple's own wording for the empty recognition) stays this long,
        /// then the bar rests.
        static let noSpeechDuration: Duration = .seconds(2)
        static var noSpeechColor: Color { ink(0.85) }
        static let transcribeDuration: Duration = .milliseconds(2400)
        static let transcribeHold: Duration = .milliseconds(600)
        /// The time to undo a cancel: chosen 2 s (Gmail and toasts use 4–5 s; a cancelled voice
        /// request is quick to redo).
        static let undoDuration: Duration = .seconds(2)
        /// The frame snapshots show.
        static let stillTranscribe = 0.62
        static let stillUndo = 0.58
        // The Undo pill: the stack's esc pill, a little brighter since it is the one action.
        static let pillWidth: CGFloat = 72
        static let pillHeight: CGFloat = 22
        static let pillSpacing: CGFloat = 4
        static let pillFont = Font.system(size: 12, weight: .semibold)
        static let pillGlyph = Font.system(size: 9, weight: .bold)
        static var pillFill: Color { ink(0.14) }
        static var pillFillHover: Color { ink(0.22) }
        static var pillText: Color { ink(0.92) }
    }

    /// Paste not found: the transcript held in the island when the page has no input box, with
    /// ✕ in the countdown's ring, the chevron that opens the whole transcript, and Copy
    /// (docs/island/PASTE_NOT_FOUND.md). Every neutral is white at one of macOS's dark label
    /// opacities; the corners are the Island's expanded ones.
    enum Paste {
        /// The island's width, ears included: 330 pt of text, about 55 characters of 13.5 pt
        /// SF Pro a line, inside a readable measure.
        static var width: CGFloat { pick(368, 400) }
        static var paddingH: CGFloat { pick(14, 16) }
        static var paddingTop: CGFloat { pick(9, 10) + Native.panelGap }
        static var paddingBottom: CGFloat { pick(11, 12) }
        /// The transcript: the Island's body text in the label color, the first two lines
        /// closed, cut at the tail with an ellipsis.
        static var text: Font { pick(Font.system(size: 12.5), .system(size: 13.5)) }
        static var textColor: Color { ink(0.85) }
        static let lineSpacing: CGFloat = 2
        static let lines = 2
        /// Opened, the whole transcript, scrolling past this.
        static let maxTextHeight: CGFloat = 200
        static var rowGap: CGFloat { pick(9, 10) }
        static var rowHeight: CGFloat { pick(21, 24) }
        // ✕: the quietest control, a plain glyph in the secondary label color, in the
        // countdown's ring; a disc lifts inside the ring under the pointer, and the target is
        // larger than the ring.
        static var closeDiscSize: CGFloat { pick(16, 18) }
        static var closeHitSize: CGFloat { pick(26, 30) }
        /// The ring: 24 pt across, 2 pt (a download ring's weight around a control this size;
        /// the lines' 4 pt would crowd the glyph), the lines' white on their track.
        static var ringDiameter: CGFloat { pick(21, 24) }
        static let ringWeight: CGFloat = 2
        static var ringTrack: Color { Progress.track }
        static var ringFill: Color { Progress.fill }
        static var closeGlyph: Font { pick(Font.system(size: 10.5, weight: .semibold), .system(size: 10.5, weight: .semibold)) }
        static var closeFillHover: Color { ink(0.12) }
        static var closeGlyphColor: Color { ink(0.55) }
        static var closeGlyphHover: Color { ink(0.85) }
        // The chevron: a glyph in the secondary label color, a fill only under the pointer.
        static var expandWidth: CGFloat { pick(32, 36) }
        static var expandHeight: CGFloat { pick(19, 22) }
        static var expandGlyph: Font { pick(Font.system(size: 10.5, weight: .semibold), .system(size: 11, weight: .semibold)) }
        static var expandColor: Color { ink(0.55) }
        static var expandColorHover: Color { ink(0.85) }
        static var expandFillHover: Color { ink(0.1) }
        // Copy: a gray capsule, white words. The gray is Apple's dark systemFill as it lands
        // on black (rgba(120,120,128,0.36) ≈ white 0.17); lighter under the pointer, lighter
        // again pressed, as dark controls highlight. The Undo pill's face and weight.
        static var copyHeight: CGFloat { pick(21, 24) }
        static var copyPaddingH: CGFloat { pick(11, 12) }
        static let copySpacing: CGFloat = 4
        static var copyFont: Font { pick(Font.system(size: 11.5, weight: .semibold), .system(size: 12, weight: .semibold)) }
        static var copyGlyph: Font { pick(Font.system(size: 10, weight: .bold), .system(size: 10, weight: .bold)) }
        static var copyFill: Color { skin(Color.white.opacity(0.17), Native.accent) }
        static var copyFillHover: Color { skin(Color.white.opacity(0.23), Native.accent.opacity(Native.accentHover)) }
        static var copyFillPressed: Color { skin(Color.white.opacity(0.29), Native.accent.opacity(Native.accentPressed)) }
        static var copyText: Color { skin(Color.white, Native.onAccent) }
        /// The island rests this long after it appears, opened or not, pointer on it or not.
        static let duration: Duration = .seconds(5)
        /// "Copied" shows this long before the island rests.
        static let copiedHold: Duration = .milliseconds(1000)
        /// The line's frame in snapshots.
        static let still = 0.6
        // Motion (Oct 21, Ryan): a panel's springs, a larger surface than the bar so a little
        // longer and less bouncy; the words a beat behind the shape, the chevron turning on the
        // island's own spring.
        static var open: Animation { Spring.panelGrow }
        static var close: Animation { Spring.panelShrink }
        static var expand: Animation { Spring.resize }
        static var collapse: Animation { Spring.fold }
        /// The last line's ellipsis giving way to the rest of the words, and back.
        static var textSwap: Animation { Spring.fadeIn(0.18) }
        static var copiedSwap: Animation { Spring.fadeIn(0.16) }
        /// The words coming in with the shape (Oct 21, Ryan, "simpler is better": no beat behind).
        static var contentIn: Animation { Spring.fadeIn(0.18) }
        static var hover: Animation { Spring.hover }
        /// The bottom corners: the Island's expanded ones; Spacious, rounder for the larger panel.
        static var bottomRadius: CGFloat { pick(Island.spec.expandedBottomRadius, 28) }
    }

    /// Voice input for agents: libraries.dev/voice (voice-glow, Jakub Antalik, MIT) ported to the
    /// notch, driven by the site's own demo voice, dark theme. Its numbers are the package's own
    /// (src/presets.ts, styles.ts, voiceDriver.ts), resolved per host type and fitted to the notch's
    /// 200 pt band by `scale`. Color and gradients: against PRD §2.7, as the user chose
    /// (docs/island/AGENT_VOICE_AND_THINKING.md).
    enum VoiceGlow {
        /// The style, Wide (chosen 2026-09-30): the package's chat-input tuning (~350 pt host)
        /// fitted to the band at scale 0.57. The glow spans the bar and the colors flow sideways
        /// with the voice (Oct 21, Ryan, "simpler is better": without the package's chromatic
        /// ridge or the distortion under it). Oct 23, Ryan ("see the notch in that color"): the
        /// inner light and its bloom stronger (0.47 and 0.89), so the bar reads in its palette
        /// without the ridge.
        static let wide = VoiceGlowGeometry(
            scale: 0.57, reach: 1.2, spread: 1.05, flow: 48, bend: 60,
            glowWidth: 0.65, glowHeight: 1.25, lobeSpacing: 0.85, rangeWidth: 0.75,
            rangeHeight: 1, softness: 1.07, coreSize: 1, strokeScale: 1, innerScale: 1, innerHeight: 1,
            bloomScale: 1, bloomHeight: 1, glowSize: 1,
            strokeOpacity: 1.16, innerOpacity: 0.8, bloomOpacity: 1.1, brightness: 1.15, saturation: 1.2)
        /// The driver's shape and follow: gate, attack, release; the resting glow (held still).
        static let threshold = 0.015
        static let attack = 0.325
        static let release = 0.86
        static let idle = 0.18
        /// Lobe geometry, px at scale 1 (styles.ts `voiceLobes`): x, width, height, the band each
        /// follows (0 lows, 1 mids, 2 highs).
        static let lobes: [(x: CGFloat, w: CGFloat, h: CGFloat, band: Int)] = [
            (0, 74, 46, 0), (-36, 54, 40, 1), (36, 54, 40, 1), (-72, 48, 32, 2), (72, 48, 32, 2),
            (-108, 42, 26, 1), (108, 42, 26, 1),
        ]
        static let lobeSpan: CGFloat = 36 * 7
        /// The ceilings the layers are masked to, px at multiplier 1.
        static let ceilingHalfWidth: CGFloat = 170
        static let ceilingHeight: CGFloat = 64
        static let bloomCeilingHalfWidth: CGFloat = 200
        static let bloomCeilingHeight: CGFloat = 130
        static let cornerFade: CGFloat = 28
        static let insetBlur: CGFloat = 9
        static let bloomBlur: CGFloat = 10
        static let innerShadow = 0.1
        /// Hue drift: ± this many degrees over this period, cosine ping-pong.
        static let hueRange = 24.0
        static let hueDuration = 12.0
        /// Mono's layers are softened: uniform gray at full opacity reads as a harsh bar.
        static let monoOpacity = 0.6
        /// Native's light glass: the layers this much stronger (docs/island/NATIVE.md).
        static let lightGlassBoost = 1.7
        /// The eight palettes on dark (styles.ts `voicePalettes`), centre lobe first, as r, g, b.
        static let palettes: [GlowPalette: [(Double, Double, Double)]] = [
            .colorful: [(255, 70, 120), (60, 190, 255), (175, 70, 255), (60, 220, 130), (255, 150, 40), (90, 100, 255), (40, 200, 190)],
            .mono: [(215, 215, 215), (180, 180, 180), (190, 190, 190), (160, 160, 160), (170, 170, 170), (150, 150, 150), (155, 155, 155)],
            .ocean: [(80, 140, 255), (40, 200, 230), (120, 90, 255), (30, 170, 210), (160, 80, 240), (60, 110, 255), (40, 190, 180)],
            .sunset: [(255, 110, 60), (255, 180, 40), (255, 60, 90), (255, 210, 80), (240, 70, 140), (255, 140, 50), (230, 50, 110)],
            .forest: [(70, 220, 120), (40, 200, 180), (140, 230, 80), (30, 170, 140), (190, 235, 70), (50, 190, 110), (30, 150, 120)],
            .candy: [(255, 90, 170), (255, 120, 220), (210, 80, 255), (255, 150, 190), (180, 110, 255), (255, 70, 140), (230, 100, 240)],
            .ice: [(150, 230, 255), (90, 200, 255), (190, 240, 255), (120, 190, 255), (160, 220, 250), (80, 170, 255), (200, 235, 255)],
            .gold: [(255, 200, 70), (255, 170, 40), (255, 220, 110), (240, 150, 30), (255, 235, 140), (230, 160, 40), (250, 210, 90)],
        ]
        /// Custom: seven hues fanned across `spread` degrees around the chosen one, centre lobe
        /// first, then the pairs outward; at this saturation and brightness.
        static let customOffsets: [Double] = [0, -1.0 / 6, 1.0 / 6, -2.0 / 6, 2.0 / 6, -3.0 / 6, 3.0 / 6]
        static let customSaturation = 0.72
        static let customBrightness = 1.0
        /// The defaults the panel starts from.
        static let defaultHue = 0.0
        static let defaultSpread = 120.0

        static let frameRate: Double = 60
        /// The frame snapshots show: this far into the demo voice, mid-phrase.
        static let stillTime: Double = 2.2

        // The panel's color controls.
        static let trackHeight: CGFloat = 12
        static let thumbSize: CGFloat = 18
        static let swatchSize: CGFloat = 14
        static let swatchSpacing: CGFloat = 6
    }

    /// Quick actions' Thinking: the agent at work, a mark and one line of what it is doing on the
    /// Mac (the app, the action), never a log (docs/island/AGENT_VOICE_AND_THINKING.md).
    enum Thinking {
        /// Under the notch: one 44 pt band, wider than the voice bar for the line.
        static let underWidth: CGFloat = 360
        /// Beside the notch: a Live Activity's compact wings, the line in a slim band below.
        static let wingWidth: CGFloat = 60
        static let besideBand: CGFloat = 28
        static let paddingH: CGFloat = 14
        static let gap: CGFloat = 10
        static let markSize: CGFloat = 24
        static let line = Font.system(size: 13.5, weight: .medium)
        static var lineColor: Color { ink(0.85) }
        static let appIconSize: CGFloat = 16
        static let appIconOpacity = 0.85
        static let actionGlyph = Font.system(size: 11, weight: .semibold)
        static var actionColor: Color { ink(0.55) }
        static let clusterSpacing: CGFloat = 6
        /// The line swaps as thinking-orbs' status line does: 150 ms, rising 8 pt through a 2 pt blur.
        static let swap: Animation = .easeOut(duration: 0.15)
        static let swapRise: CGFloat = 8
        static let swapBlur: CGFloat = 2
        static let open: Animation = .interpolatingSpring(duration: 0.3, bounce: 0)
        static let close: Animation = .interpolatingSpring(duration: 0.22, bounce: 0)
        static let contentIn: Animation = Motion.content
        static let frameRate: Double = 60
        static let stillTime: TimeInterval = 1.1

        // The mark itself: WorkbenchTokens.Lasso.

        // The agent's pointer on the page: drawn only, never the real one.
        static let pointerMove: Animation = .timingCurve(0.2, 0, 0, 1, duration: 0.5)
        static let rippleSize: CGFloat = 26
        static let rippleDuration: Double = 0.4
        static let typeInterval: Duration = .milliseconds(35)
        /// Something dragged follows the pointer on a slower glide.
        static let dragMove: Animation = .timingCurve(0.2, 0, 0, 1, duration: 0.8)
        /// Needs you: the run waits this long for Allow before carrying on by itself.
        static let needsYouTimeout: Double = 4
        /// The Island's own state tints (Tokens.Island.Colors): Needs you and Failed.
        static var needsYouColor: Color { skin(Color(.sRGB, red: 0xF5 / 255.0, green: 0xB8 / 255.0, blue: 0x4B / 255.0), Native.needsYou) }
        static var failedColor: Color { skin(Color(.sRGB, red: 0xF0 / 255.0, green: 0x6A / 255.0, blue: 0x6A / 255.0), Native.failed) }
        /// Allow: the island's gray capsule (Copy's), white words.
        static let allowFont = Font.system(size: 12, weight: .semibold)
        static let allowHeight: CGFloat = 24
        static let allowPaddingH: CGFloat = 12
        static var allowFill: Color { ink(0.17) }
        static var allowFillHover: Color { ink(0.23) }
    }

    /// The Lasso, Thinking's mark (`LassoRenderer` in MockDesktop/AgentThinking.swift): a
    /// hand-drawn circle in the 24 pt mark, traced and erased behind its bright tip.
    enum Lasso {
        static let radius: CGFloat = 8.6
        static let weight: CGFloat = 1.6
        static let head: CGFloat = 2.4
        static let opacity = 0.9
        /// The hand's waver: the radius's second and third harmonics, as fractions of it; the
        /// second drifts round this many radians a second, so no two loops are quite alike.
        static let waver2 = 0.05
        static let waver3 = 0.03
        static let waverDrift = 0.7
        /// How much the loop closes in as it comes round.
        static let shrink = 0.06
        /// Each new loop starts this far round from the last (radians).
        static let advance: Double = 0.9
        /// A little past one turn, so it overlaps where it closes.
        static let turns: Double = 1.12
        /// A loop every 1.5 s; the trail is three quarters of it.
        static let period: Double = 1.5
        static let length: Double = 0.75
    }

    /// Dispatch's Choose chat (MockDesktop/ChooseChat.swift): the request to check, the chat Fovea
    /// picked, and, opened, a rail of the agents and their chats. docs/island/CHOOSE_CHAT.md has the
    /// reasons. White at the Island's opacities on black; the agents' icons are their own apps'.
    enum Chat {
        // The island: 440 pt, the expanded corners.
        static let width: CGFloat = 440
        static let paddingH: CGFloat = 16
        static let paddingTop: CGFloat = 10
        static let paddingBottom: CGFloat = 10
        // The request, as the Paste not found transcript reads.
        static let text = Font.system(size: 13.5)
        static var textColor: Color { ink(0.85) }
        static let lineSpacing: CGFloat = 2
        static let lines = 3
        static let rowGap: CGFloat = 12
        /// No words (the screenshots go alone): one quiet line in their place.
        static let emptyRequestHeight: CGFloat = 18
        static var requestPlaceholder: Color { ink(0.4) }
        // One row: the referents, the chat, Send.
        static let rowHeight: CGFloat = 32
        /// The review stack's and the Agent list's thumbnail.
        static let thumb = CGSize(width: 44, height: 32)
        static let thumbRadius: CGFloat = 6
        static let thumbGap: CGFloat = 6
        static var thumbBorder: Color { ink(0.2) }
        static let thumbBorderWidth: CGFloat = 0.75
        /// A referent that couldn't be read: its card kept, a glyph instead of the picture.
        static var missingFill: Color { ink(0.06) }
        static let missingGlyph = Font.system(size: 11, weight: .medium)
        static var missingColor: Color { ink(0.4) }
        /// The notice under the row: a glyph, a line or two of words, its buttons under them at
        /// the right (the island's gray capsules, Copy's).
        static let noticeGap: CGFloat = 10
        static let noticeGlyphWidth: CGFloat = 20
        static let noticeGlyph = Font.system(size: 13, weight: .semibold)
        static let noticeFontSize: CGFloat = 12.5
        static let noticeFont = Font.system(size: 12.5)
        static let noticeLineSpacing: CGFloat = 2
        static let noticeLineHeight: CGFloat = 17
        static let noticeMaxHeight: CGFloat = 36
        static var noticeColor: Color { ink(0.85) }
        static var noticeInfoColor: Color { ink(0.62) }
        static let noticeActionsGap: CGFloat = 6
        static let noticeButtonHeight: CGFloat = 24
        static let noticeButtonGap: CGFloat = 6
        static let noticeButtonPaddingH: CGFloat = 12
        static let noticeButtonFont = Font.system(size: 12, weight: .semibold)
        static var noticeButtonText: Color { ink(1) }
        static var noticeButtonTextQuiet: Color { ink(0.85) }
        static var noticeButtonFill: Color { ink(0.17) }
        static var noticeButtonFillHover: Color { ink(0.23) }
        /// Fovea's guesses, when it isn't sure: under the notice, an agent's icon before each.
        static let guessGap: CGFloat = 4
        static let guessSpacing: CGFloat = 8
        /// The chat pill: a fixed width, so routing's answer crossfades in place (PRD §14).
        static let pillWidth: CGFloat = 196
        static let pillHeight: CGFloat = 28
        static let pillRadius: CGFloat = 9
        static let pillPaddingH: CGFloat = 8
        static let pillSpacing: CGFloat = 6
        static var pillFill: Color { ink(0.08) }
        static var pillFillHover: Color { ink(0.12) }
        static let pillFont = Font.system(size: 12, weight: .medium)
        static var pillText: Color { ink(0.85) }
        static var pillPlaceholder: Color { ink(0.4) }
        /// With no chat yet: "Choose a chat", at the secondary opacity.
        static var pillPlaceholderStrong: Color { ink(0.62) }
        static let pillChevron = Font.system(size: 9, weight: .bold)
        static var pillChevronColor: Color { ink(0.55) }
        static let icon: CGFloat = 16
        /// While routing answers: a gray disc where the icon goes, and the words, breathing from
        /// full to 0.45 every 0.9 s (PRD §11, the app's `placeholderPulse`).
        static var placeholderFill: Color { ink(0.14) }
        static let breathe: Double = 0.9
        static let breatheLow = 0.45
        static let routing: Double = 0.6
        /// Routing failed: the pill's mark is the Island's Failed red, its words "Retry routing".
        static let failedGlyph = Font.system(size: 13, weight: .semibold)
        static var failedColor: Color { skin(Color(.sRGB, red: 0xF0 / 255.0, green: 0x6A / 255.0, blue: 0x6A / 255.0), Native.failed) }
        /// Send: the review's small white disc with a black arrow; dimmed while there is no chat
        /// that can take the request.
        static var sendDisabledFill: Color { ink(0.2) }
        static var sendDisabledGlyph: Color { ink(0.45) }
        static let sendSize: CGFloat = 28
        static let sendGap: CGFloat = 8
        static let sendGlyph = Font.system(size: 13, weight: .semibold)
        static var sendFill: Color { skin(Color.white, Native.accent) }
        static var sendFillHover: Color { ink(0.85) }
        static var sendGlyphColor: Color { skin(Color.black, Native.onAccent) }

        // Opened: a hairline, the rail, the rows.
        static let listGap: CGFloat = 10
        static var hairline: Color { ink(0.1) }
        /// The rail: the agents' icons in 34×28 cells; the active one on a tab, the others dimmed
        /// (brighter under the pointer); the active agent's name after them.
        static let railHeight: CGFloat = 28
        static let railCell = CGSize(width: 34, height: 28)
        /// App icons with dark tiles (Codex, Cursor) need the size and the opacity to
        /// stay findable on black when they are not the active one.
        static let railIcon: CGFloat = 18
        static let railSpacing: CGFloat = 2
        static let railIdleOpacity = 0.6
        static let railHoverOpacity = 0.85
        static let railNameGap: CGFloat = 8
        static let railNameFont = Font.system(size: 12, weight: .semibold)
        static var railNameColor: Color { ink(0.85) }
        static let railGap: CGFloat = 6
        /// The active agent's tab: a 30×24 pill behind its icon, as a menu's or a segmented
        /// control's selection; a fainter one under the pointer on the others.
        static let tab = CGSize(width: 30, height: 24)
        static var tabFill: Color { ink(0.12) }
        static var tabHoverFill: Color { ink(0.06) }
        static let tabRadius: CGFloat = 7
        /// Viewing another agent, a dot under the one whose chat is chosen: where the request goes.
        static let chosenDot: CGFloat = 3
        static var chosenDotColor: Color { ink(0.85) }
        static let chosenDotGap: CGFloat = 2
        /// A project's chats scroll in at most this many rows, so it opens on a row's edge.
        static let projectRows = 8
        /// A project row: a dot in the check column when the chosen chat is in it.
        static let projectDot: CGFloat = 5
        /// The row back to the projects: the project's name a step heavier, its path after it.
        static let backFont = Font.system(size: 13, weight: .semibold)
        static var backColor: Color { ink(0.55) }
        /// A New chat, at the top of a project's chats.
        static var newChatColor: Color { ink(0.62) }
        /// A chat Fovea can't continue: a button to open it in its own app.
        static let openGlyph = Font.system(size: 11, weight: .medium)
        static var openColor: Color { ink(0.62) }
        /// An agent that isn't connected: its icon faint on the rail, a note instead of projects.
        static let offlineOpacity = 0.3
        static let offlineActiveOpacity = 0.45
        static let offlineHeight: CGFloat = 48
        /// An agent's chats still being read: a spinner and a line.
        static var loadingColor: Color { ink(0.62) }
        /// The staged cases' timing: chats change (or a pick is closed) this long after opening;
        /// the other agents' chats finish loading; a send takes this long to fail or go.
        static let caseDelay: Double = 1.0
        static let loadingTime: Double = 1.6
        static let sendTime: Double = 0.7
        // A chat's row. Menu grammar: the chosen chat is the one with the checkmark, in a column
        // every row keeps (the current value, HIG Menus); the keyboard's or the pointer's row is
        // the one with the fill (the cursor), which moves at once and never animates. A row never
        // changes weight (it would reflow).
        static let chatRow: CGFloat = 28
        static let rowPaddingH: CGFloat = 8
        static let checkWidth: CGFloat = 14
        static let checkGlyph = Font.system(size: 10, weight: .semibold)
        static var checkColor: Color { ink(0.85) }
        static let chatFont = Font.system(size: 13.5)
        static var chatColor: Color { ink(0.85) }
        /// A chat that can't take the request: its name at the tertiary opacity.
        static var chatDisabledColor: Color { ink(0.4) }
        static var highlight: Color { ink(0.12) }
        static var highlightPressed: Color { ink(0.16) }
        static let highlightRadius: CGFloat = 7
        /// Increase Contrast: the fills step up and take a keyline (3.66:1 on black).
        static var contrastFill: Color { ink(0.2) }
        static var contrastStroke: Color { ink(0.4) }
        static let contrastIdleOpacity = 0.8
        // The right side: project or branch, then the state or the age.
        static let metaFont = Font.system(size: 11.5)
        static let statusFont = Font.system(size: 11.5, weight: .medium)
        static var metaColor: Color { ink(0.4) }
        static let metaGap: CGFloat = 10
        static let metaSpacing: CGFloat = 6
        static var workingColor: Color { ink(0.62) }
        static let workingDotSize: CGFloat = 5
        /// The Island's Needs you amber (Tokens.Island.Colors).
        static var needsYouColor: Color { skin(Color(.sRGB, red: 0xF5 / 255.0, green: 0xB8 / 255.0, blue: 0x4B / 255.0), Native.needsYou) }
        /// A chosen chat's check shows a beat before the island closes with it in the pill (a
        /// menu item's blink, Rauno Freiberg).
        static let chooseHold: Double = 0.25

        // Motion: critically damped, as the island's other growths.
        static let open: Animation = .interpolatingSpring(duration: 0.3, bounce: 0)
        static let close: Animation = .interpolatingSpring(duration: 0.22, bounce: 0)
        static let expand: Animation = .interpolatingSpring(duration: 0.32, bounce: 0)
        static let collapse: Animation = .interpolatingSpring(duration: 0.26, bounce: 0)
        /// The tab sliding to another agent, its chats crossfading in.
        static let agentSwap: Animation = .interpolatingSpring(duration: 0.22, bounce: 0)
        static let contentIn: Animation = Motion.content
        /// The list comes in once the island has room for it, and goes at once.
        static let listIn: Animation = .easeOut(duration: 0.16).delay(0.1)
        static let listOut: Animation = .easeOut(duration: 0.1)
        static let nameSwap: Animation = .easeOut(duration: 0.18)
        // Oct 21 motion review: a hover fill, as every other hover in Fovea (`Spring.hover`: `ease`,
        // 0.12 s); it was SwiftUI's `.easeOut` at 0.1 s, on Dispatch's buttons (AgentPanelButton).
        static var hover: Animation { Spring.hover }
    }

    /// Dispatch's Agent panel (MockDesktop/AgentPanel.swift): the Agent tasks, each readable at a
    /// glance and controllable in place, at Choose chat's width. docs/island/AGENT_PANEL.md has
    /// the reasons. White at the Island's opacities on black; amber and red only for Needs you
    /// and Failed.
    enum Panel {
        // The list: five rows at most, then it scrolls (AMENDMENTS), grouped by project.
        static let rowsVisible = 5
        /// Two lines (the session, then what it is doing), and one line (the Ledger).
        static let rowHeight: CGFloat = 42
        static let lineRowHeight: CGFloat = 30
        /// A Ledger row that needs the person: its line, then its question and answers.
        static let askRowHeight: CGFloat = 52
        /// The list's room, the same in every style: five two-line rows and two projects' names.
        static let listWindow: CGFloat = CGFloat(rowsVisible) * rowHeight + 2 * headerHeight + groupGap
        /// The Ledger's state slot to the icon.
        static let slotGap: CGFloat = 8
        static let listTop: CGFloat = 6
        static let listPadding: CGFloat = 8
        static let rowPaddingH: CGFloat = 10
        static let rowRadius: CGFloat = 8
        static let columnGap: CGFloat = 10
        static let lineGap: CGFloat = 2
        static let icon: CGFloat = 18
        static let lineIcon: CGFloat = 16
        // A project's name over its rows: small and quiet, sticky as the list scrolls; no count.
        static let headerHeight: CGFloat = 22
        static let headerBottom: CGFloat = 4
        static let headerFont = Font.system(size: 11, weight: .semibold)
        static var headerColor: Color { ink(0.4) }
        static let groupGap: CGFloat = 6
        // A row's words: the session, then one line of what it is doing.
        static let nameFont = Font.system(size: 13, weight: .medium)
        static var nameColor: Color { ink(0.92) }
        static let lineFont = Font.system(size: 12)
        static var lineColor: Color { ink(0.5) }
        /// What it asks: brighter, it is the person's turn.
        static var askColor: Color { ink(0.85) }
        /// Gone quiet, or stopped.
        static var quietColor: Color { ink(0.35) }
        // Live: the thing it is on (its kind's glyph, its name), then the line it is producing.
        static let objectGlyph = Font.system(size: 10, weight: .semibold)
        static let objectGlyphWidth: CGFloat = 12
        static var objectColor: Color { ink(0.62) }
        static let glyphGap: CGFloat = 5
        static let codeFont = Font.system(size: 11, design: .monospaced)
        static var codeColor: Color { ink(0.42) }
        static var errorColor: Color { failedColor.opacity(0.85) }
        /// Characters a second the line types in at: quicker than reading, slow enough to see.
        static let typeRate: Double = 60
        // The state: a glyph (Linear's and GitHub's), its word in its color, how long, quietly.
        static let markGlyph: CGFloat = 12
        static let markGap: CGFloat = 5
        static let stateFont = Font.system(size: 11.5, weight: .medium)
        static let timeFont = Font.system(size: 11.5)
        static var timeColor: Color { ink(0.35) }
        static var workingColor: Color { skin(Color.white.opacity(0.7), Native.accent) }
        static var completeColor: Color { skin(Color.white.opacity(0.85), Native.done) }
        static var needsYouColor: Color { skin(Color(.sRGB, red: 0xF5 / 255.0, green: 0xB8 / 255.0, blue: 0x4B / 255.0), Native.needsYou) }
        static var failedColor: Color { skin(Color(.sRGB, red: 0xF0 / 255.0, green: 0x6A / 255.0, blue: 0x6A / 255.0), Native.failed) }
        /// Working's ring: a quarter of it going round; motion is kept for this state alone.
        static let ringWidth: CGFloat = 1.5
        static var ringTrack: Color { ink(0.18) }
        static let spinArc: CGFloat = 0.28
        static let spinPeriod: Double = 1.1
        static let spinStill: Double = 0.15
        static let stallDash: [CGFloat] = [2, 2]
        // Badge: the state on the agent's icon, ringed in the island's black.
        static let badgeIcon: CGFloat = 22
        static let badgeGlyph: CGFloat = 10
        static let badgeRing: CGFloat = 1.5
        static let badgeOffset: CGFloat = 3
        /// A working task quiet this long reads as stalled: its line says so, its ring stops and
        /// goes dashed (a mark that keeps turning on a stall reads as broken).
        static let stallAfter: Double = 300
        // Buttons in a row: the island's gray capsule; the primary (Allow) white with black words.
        static var buttonHeight: CGFloat { pick(18, 20) }
        static var buttonPaddingH: CGFloat { pick(8, 9) }
        static var buttonGap: CGFloat { pick(4.5, 5) }
        static var buttonFont: Font { pick(Font.system(size: 11, weight: .semibold), .system(size: 11.5, weight: .medium)) }
        static var buttonSymbol: Font { pick(Font.system(size: 8.5, weight: .bold), .system(size: 8.5, weight: .semibold)) }
        static var buttonSymbolGap: CGFloat { pick(4, 4) }
        static var buttonFill: Color { ink(0.14) }
        static var buttonFillHover: Color { ink(0.22) }
        static var buttonText: Color { ink(0.9) }
        static var buttonPrimary: Color { skin(Color.white, Native.accent) }
        static var buttonPrimaryHover: Color { skin(Color.white.opacity(0.85), Native.accent.opacity(Native.accentHover)) }
        static var buttonPrimaryText: Color { skin(Color.black, Native.onAccent) }
        // Fills: the pointer's or the keyboard's row, and the task Send just created.
        static var hoverFill: Color { ink(0.07) }
        static var sentFill: Color { ink(0.12) }
        // The hover (AMENDMENTS, the app's IslandReducer): a dwell on the notch itself opens it; the
        // open panel and a little slack round it keep it; a beat after the pointer leaves, it closes.
        /// Opening: at least this long on the notch, then the first moment the pointer is still
        /// (under `restDistance` over `restWindow`), checked every `dwellCheck`; at `dwellCap` it
        /// opens anyway. A deliberate aim lands at about 120–170 ms; a sweep along the menu bar
        /// never rests. Off the notch under `dwellJitter` (a wobble at its edge) keeps the dwell.
        // Oct 21, Ryan ("expand faster when my mouse hovers"): halved from 0.12 / 0.3. The board
        // still waits for the pointer to be still (a sweep along the menu bar never rests), so it
        // opens about 60–160 ms after a deliberate aim instead of 120–300 ms.
        static let dwell: Double = 0.06
        static let dwellCap: Double = 0.16
        static let dwellCheck: Double = 0.02
        static let dwellJitter: Double = 0.08
        static let restWindow: Double = 0.05
        static let restDistance: CGFloat = 6
        static let moveMemory: Double = 0.2
        /// Closing: this long after the pointer leaves the panel and its slack.
        static let exitGrace: Double = 0.1
        static let exitSlack: CGFloat = 8
        /// Near the notch counts as on it: this far beside it and below it (Dispatch Version 2's
        /// hover opens the control board near the notch, not only on it).
        static let hoverReach: CGFloat = 14
        /// Back on the notch this soon after a hover closed it: it opens at once, no dwell.
        static let reopenWindow: Double = 0.3
        /// A row's controls take no click this long after the panel opens.
        static let controlsGuard: Double = 0.5
        /// After Send: the new task highlighted this long, longer while the pointer is on it.
        static let sentGrace: Double = 3.5
        /// The agents at work: a working task moves on this often.
        static let beat: Double = 2.6
        // Motion.
        static let open: Animation = .interpolatingSpring(duration: 0.26, bounce: 0)
        static let close: Animation = .interpolatingSpring(duration: 0.2, bounce: 0)
        /// The rows come in with the shape, a little longer than the voice bar's for the larger
        /// surface (Oct 21, Ryan, "simpler is better": no beat behind it).
        static let contentIn: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.16)
        /// A task changing: its line, its state, its place in the order (Oct 21: list layout,
        /// critically damped, `Spring.rows`).
        static var change: Animation { Spring.rows }
        static var sentFade: Animation { Spring.fadeOut(0.24) }
        static var controlsFade: Animation { Spring.fadeIn(0.12) }
    }

    /// Dispatch Version 2 (WorkbenchModel+DispatchV2.swift, MockDesktop/DispatchV2.swift). Its
    /// open shapes stretch to both sides of the notch: one width for all of them, only the
    /// height changing; content kept the same margin inside the island's body (which starts where
    /// its ears end), so nothing leans. Beside the notch at rest, two equal wings.
    enum V2 {
        // The shape: Compact a little narrower (Oct 9, evening).
        static var width: CGFloat { pick(600, 660) }
        /// Inside the body: the same on every side.
        static var margin: CGFloat { pick(14, 16) }
        /// From the notch's foot to the content; in Native, from the panel's top (the gap under
        /// the island is added: docs/island/NATIVE.md).
        static var topGap: CGFloat { pick(9, 10) + Native.panelGap }
        static var bottomRadius: CGFloat { pick(25, 28) }
        static var gap: CGFloat { pick(11, 12) }
        // Type and ink.
        static var titleFont: Font { pick(Font.system(size: 12.5, weight: .semibold), .system(size: 13.5, weight: .semibold)) }
        static var titleColor: Color { ink(0.94) }
        static var subColor: Color { ink(0.5) }
        static var statusFont: Font { pick(Font.system(size: 11), .system(size: 11.5)) }
        static var badgeFont: Font { pick(Font.system(size: 10.5, weight: .medium), .system(size: 10.5, weight: .medium)) }
        static var badgeFill: Color { ink(0.1) }
        static var bodyColor: Color { ink(0.78) }
        static var detailFont: Font { pick(Font.system(size: 11.5), .system(size: 12)) }
        static let avatar: CGFloat = 26
        // Rows and keys.
        static let rowRadius: CGFloat = 10
        static var chosenFill: Color { ink(0.1) }
        static var hoverFill: Color { ink(0.05) }
        static let keyFont = Font.system(size: 10.5, weight: .semibold)
        static var keyColor: Color { ink(0.42) }
        static var keyFill: Color { ink(0.08) }
        static let keySize: CGFloat = 18
        static var hintFont: Font { pick(Font.system(size: 11), .system(size: 11.5)) }
        static let hintKeyFont = Font.system(size: 11, weight: .semibold)
        static var hintColor: Color { ink(0.38) }
        static let hintHeight: CGFloat = 18
        // Choose chat: the request and what was taken; where it could go; every chat.
        static var requestSize: CGFloat { pick(13, 14) }
        static var requestColor: Color { ink(0.9) }
        static let attachmentHeight: CGFloat = 52
        static var attachmentGap: CGFloat { pick(7, 8) }
        static var attachmentRadius: CGFloat { pick(6, 7) }
        static var labelFont: Font { pick(Font.system(size: 10.5, weight: .semibold), .system(size: 11, weight: .semibold)) }
        static var labelColor: Color { pick(ink(0.4), ink(0.5)) }
        static let labelHeight: CGFloat = 18
        static let suggestionHeight: CGFloat = 36
        static let suggestionIcon: CGFloat = 18
        static let suggestionFont = Font.system(size: 13, weight: .medium)
        static var reasonFont: Font { pick(Font.system(size: 11.5), .system(size: 12)) }
        /// Choose chat, as Dispatch has it: what was taken, the chat in a pill, the send button; the
        /// suggestions as chips under. It waits for the person: nothing sends by itself.
        static var attachRow: CGFloat { pick(39, 44) }
        static var attachThumb: CGFloat { pick(35, 40) }
        static let pillMaxWidth: CGFloat = 250
        static var pillHeight: CGFloat { pick(28, 32) }
        static var sendSize: CGFloat { pick(28, 32) }
        static let sendHoverOpacity: Double = 0.85
        static var chipRow: CGFloat { pick(25, 28) }
        static var chipHeight: CGFloat { pick(23, 26) }
        static var chipFont: Font { pick(Font.system(size: 12, weight: .medium), .system(size: 12.5, weight: .medium)) }
        static var chipFill: Color { ink(0.07) }
        static var chipChosenFill: Color { skin(Color.white.opacity(0.16), Native.accent.opacity(Native.accentWash)) }
        /// Every chat, as Dispatch's expanded view: the agents' rail, then rows.
        static var railHeight: CGFloat { pick(26, 30) }
        static var railIcon: CGFloat { pick(16, 18) }
        static var railTab: CGSize { pick(CGSize(width: 28, height: 23), CGSize(width: 32, height: 26)) }
        static var browseRow: CGFloat { pick(26, 30) }
        static let browseRowsVisible = 6
        // The control board: the focus's screen (16:10) beside every session.
        static let focusWidth: CGFloat = 336
        static let focusHeader: CGFloat = 36
        static let footerHeight: CGFloat = 26
        static let paneGap: CGFloat = 20
        static let listRow: CGFloat = 50
        static let listHeader: CGFloat = 22
        static let listFont = Font.system(size: 12.5, weight: .medium)
        static let thumbWidth: CGFloat = 64
        /// Just sent: the board shows this long (longer while the pointer is on it).
        static let boardHold: Double = 3
        /// The pointer rests this long on a session before it is the focus.
        static let focusDwell: Double = 0.12
        /// The board's two kinds: done and not yet opened (on top), and running.
        static var readyColor: Color { ink(0.9) }
        // The expanded chat: the agent and session; the request; the response beside its screen;
        // its state; what to do; the grab bar that pulls it out.
        static var chatHeader: CGFloat { pick(35, 40) }
        static var questionSize: CGFloat { pick(13.5, 15) }
        static let chatScreen: CGFloat = 268
        static let columnGap: CGFloat = 20
        static let chatBodyMax: CGFloat = 280
        static let statusHeight: CGFloat = 34
        static let barHeight: CGFloat = 36
        static let grabSize = CGSize(width: 40, height: 5)
        static var grabArea: CGFloat { pick(14, 16) }
        static var grabColor: Color { ink(0.32) }
        static var rule: Color { ink(0.08) }
        static var outcomeSize: CGFloat { pick(13.5, 14.5) }
        static var outcomeColor: Color { ink(0.96) }
        /// An answer that came this quickly opens by itself (the person is likely still waiting);
        /// anything slower waits on the board, Ready for review.
        static let quickLimit: Double = 8
        /// Opened by itself, the chat holds this long (longer while the pointer is on it).
        static let chatHold: Double = 12
        /// Pulled this far below the notch, the chat comes out as a window.
        static let pullThreshold: CGFloat = 28
        // A chat pulled out: a small window, anywhere; tucked into a side, a tab.
        static var detachedSize: CGSize { pick(CGSize(width: 313, height: 431), CGSize(width: 340, height: 468)) }
        /// A pulled-out chat's follow-up box.
        static var inputHeight: CGFloat { pick(30, 34) }
        static var inputFill: Color { ink(0.07) }
        static var detachedRadius: CGFloat { pick(14, 16) }
        /// How small and how big a pulled-out chat's window can be made, against its usual size (its
        /// corner or a pinch). The window resizes; its words stay their size and reflow (Oct 11).
        static let detachedResize: ClosedRange<CGFloat> = 0.7...1.6
        static let scaleGrip: CGFloat = 14
        /// How long the pointer stays on another display before the pulled-out chats follow it there
        /// (a pass across it on the way somewhere doesn't move them).
        static let followDwell: Double = 0.6
        static var scaleGripColor: Color { ink(0.32) }
        /// The rail beside a chat with follow-ups (after Notion's outline): a short line per
        /// exchange, the one in view bright; on hover, the questions, each a way back to it.
        static let railGutter: CGFloat = 22
        static let railLineHeight: CGFloat = 2
        static let railLineGap: CGFloat = 7
        static let railLineMin: CGFloat = 9
        static let railLineMax: CGFloat = 17
        static var railLineOn: Color { ink(0.9) }
        static var railLineOff: Color { ink(0.24) }
        static let railCardWidth: CGFloat = 220
        static let railRow: CGFloat = 26
        static var railCardFill: Color { skin(Color(white: 0.11), Native.card) }
        static var railRowHover: Color { ink(0.07) }
        static var railMotion: Animation { Spring.fadeIn(0.14) }
        /// The rail's card: a light shadow, close in (Oct 21, Ryan, "simpler is better"; it was 12 pt at 0.4).
        static let railCardShadow = Color.black.opacity(0.25)
        static let railCardShadowRadius: CGFloat = 8
        /// A turn counts as the one in view once its top is this close to the top of the chat.
        static let railReadLine: CGFloat = 60
        static let turnGap: CGFloat = 18
        // Oct 18, Ryan: in the primary language.
        static var movedOn: String { L("Moved on to your next question.") }
        static let detachedFill = Color(white: 0.06)
        static var detachedBorder: Color { ink(0.12) }
        /// The pulled-out chat's shadow, and its tucked tab's: lighter and closer than a window's
        /// (Oct 21, Ryan, "simpler is better"; they were 22 pt at 0.45 and 10 pt at 0.35).
        static let detachedShadow = Color.black.opacity(0.3)
        static let detachedShadowRadius: CGFloat = 12
        static let detachedShadowY: CGFloat = 6
        static let tabShadow = Color.black.opacity(0.25)
        static let tabShadowRadius: CGFloat = 6
        static let edgeSnap: CGFloat = 12
        static let tabSize = CGSize(width: 34, height: 76)
        // Timing.
        static let listenTime: Double = 2.4
        /// fn⌃ again: what was said is transcribed this long (the aura's progress bar).
        static let transcribeTime: Double = 1.4
        /// Play, on Choose chat: it looks this long, then sends (Choose chat itself never sends).
        static let playChoose: Double = 1.6
        static let answerPace: Double = 1.2
        static let taskPace: Double = 2.2
        static let typeRate: Double = 28
        static let caretBlink: Double = 1.0
        // Motion (Oct 21, Ryan): the palette's springs (`Spring`), each move by its size.
        static var open: Animation { Spring.panelGrow }
        static var resize: Animation { Spring.resize }
        static var fold: Animation { Spring.fold }
        static var close: Animation { Spring.panelShrink }
        static var contentIn: Animation { Spring.fadeIn(0.18) }
        /// A taken thing in Choose chat opening larger over the window, and closing: a fade.
        static var inspectFade: Animation { Spring.fadeIn(0.16) }
        /// A chat tucked into a side, or pulled back out: the tab slides in from that edge.
        static let tuckScale: CGFloat = 0.96

        /// Each move on the spring for its size: from rest, a bar grows on the bar's spring and a
        /// panel on a panel's; a bar becoming a panel grows as a panel; home, each on its own
        /// shrink; a panel becoming a bar folds; the rest resize within the island.
        static func spring(from: NotchState, to: NotchState) -> Animation {
            let bar: (NotchState) -> Bool = { $0 == .v2Voice || $0 == .v2Transcribing || $0 == .voiceFlow }
            switch (from, to) {
            case (_, .silent): return bar(from) ? Spring.barShrink : Spring.panelShrink
            // Oct 21, Ryan: "the island should expand faster when my mouse hovers over it" — the
            // board from rest (the hover's open) on its own quicker spring.
            case (.silent, .v2Board): return Spring.boardOpen
            case (.silent, _): return bar(to) ? Spring.barGrow : Spring.panelGrow
            default:
                if bar(from), !bar(to) { return Spring.panelGrow }
                if !bar(from), bar(to) { return Spring.fold }
                return Spring.resize
            }
        }
        // Values that were written in the views, now here so they follow the density
        // (docs/island/SPACIOUS.md). Compact is each one's value through Oct 6.
        // Choose chat.
        static var requestWeight: Font.Weight { pick(.medium, .regular) }
        static var requestMeasureWeight: NSFont.Weight { pick(.medium, .regular) }
        static var requestSpacing: CGFloat { pick(2, 2) }
        /// Under the row of the stack, the pills and Send.
        static var attachBottom: CGFloat { pick(9, 10) }
        static var chipGap: CGFloat { pick(5.5, 6) }
        static var labelTrailing: CGFloat { pick(4, 4) }
        static var chipPaddingH: CGFloat { pick(9, 10) }
        static var chipIcon: CGFloat { pick(12, 14) }
        static var chipText: Color { ink(0.72) }
        static var pillPaddingH: CGFloat { pick(11, 12) }
        static var pillIcon: CGFloat { pick(16, 18) }
        static var pillFont: Font { pick(Font.system(size: 12, weight: .medium), .system(size: 13, weight: .medium)) }
        static var pillChevron: Font { pick(Font.system(size: 9.5, weight: .semibold), .system(size: 9.5, weight: .semibold)) }
        static var pillGlyph: Font { pick(Font.system(size: 10.5, weight: .semibold), .system(size: 11, weight: .semibold)) }
        static var sendGlyph: Font { pick(Font.system(size: 12, weight: .bold), .system(size: 13, weight: .bold)) }
        // Every chat: the rail, the rows.
        static var browseSpacing: CGFloat { pick(5.5, 6) }
        static var railGap: CGFloat { pick(4, 4) }
        static var railTabRadius: CGFloat { pick(6, 7) }
        static var railName: Font { pick(Font.system(size: 12, weight: .semibold), .system(size: 13, weight: .semibold)) }
        static var browseFont: Font { pick(Font.system(size: 12, weight: .medium), .system(size: 13, weight: .medium)) }
        static var browsePaddingH: CGFloat { pick(9, 10) }
        static var browseChevron: Font { pick(Font.system(size: 9, weight: .semibold), .system(size: 9, weight: .semibold)) }
        static var browseBack: Font { pick(Font.system(size: 10, weight: .semibold), .system(size: 10, weight: .semibold)) }
        static var browseGlyph: Font { pick(Font.system(size: 10), .system(size: 10)) }
        /// The #19 sheet's rule between every chat and the model: this much above and below it.
        static var sheetRuleGap: CGFloat { pick(7, 8) }
        // The session in the notch: its header, the rules, the question.
        static var headerSpacing: CGFloat { pick(9, 10) }
        static var headerIcon: CGFloat { pick(19, 22) }
        static var headerTitle: Font { pick(Font.system(size: 13, weight: .semibold), .system(size: 14, weight: .semibold)) }
        /// The rule under the header; Spacious keeps only this one, finer.
        static var headerRule: CGFloat { pick(1, 1) }
        static var headerRuleColor: Color { pick(rule, ink(0.12)) }
        /// The rule between the question and the answer: Spacious parts them with space.
        static var blockRules: Bool { pick(true, false) }
        static var questionLineSpacing: CGFloat { pick(0, 0) }
        /// The question as measured for the outline (Compact measured it with 2 the view never set).
        static var questionMeasureSpacing: CGFloat { pick(2, 2) }
        static var badgeHeight: CGFloat { pick(14, 16) }
        static var badgePaddingH: CGFloat { pick(5.5, 6) }
        // ✕ and back: a circle, a plate under the pointer (Spacious shows a quiet one at rest).
        static var closeSize: CGFloat { pick(21, 24) }
        static var closeGlyph: Font { pick(Font.system(size: 10.5, weight: .bold), .system(size: 10.5, weight: .semibold)) }
        static var backSize: CGFloat { pick(19, 22) }
        static var backGlyph: Font { pick(Font.system(size: 10.5, weight: .semibold), .system(size: 11, weight: .semibold)) }
        static var iconPlate: Color { pick(Color.clear, ink(0.08)) }
        static var iconPlateHover: Color { pick(Color.clear, ink(0.14)) }
        static var iconGlyphHover: Color { pick(subColor, titleColor) }
        // Expanded (Oct 7, docs/island/WHOLE_SESSION.md): the whole session, every exchange in it,
        // as tall as it needs down to the display's foot, 40 pt from the display's sides and 16
        // above its foot (the shipping app's reading margins). Narrower than the shipping app's 960,
        // the words in one centred column, the room left going to both sides; the header keeps
        // the panel's edges.
        static let readingSideMargin: CGFloat = 40
        static let readingBottomMargin: CGFloat = 16
        static var expandedWidth: CGFloat { pick(840, 880) }
        static var expandGlyph: Font { pick(Font.system(size: 10, weight: .semibold), .system(size: 10, weight: .semibold)) }
        static let grabHitWidth: CGFloat = 120
        /// The column the requests, the answers, the bar and the box keep when expanded: about 90
        /// characters a line at the answer's size (13.5 and 15 pt SF Pro set 6.3 and 6.9 pt a
        /// character), the long end of Practical Typography's 45–90, for answers full of paths and
        /// code. 130 pt each side in Spacious (140 in Compact), the outline in the right one.
        static var readingMeasure: CGFloat { pick(560, 620) }
        /// Every exchange, oldest first, parted by space (no rules).
        static var historyTurnGap: CGFloat { pick(28, 32) }
        static var historyQuestionGap: CGFloat { pick(11, 12) }
        /// The person's words and the agent's, told apart without bubbles (Oct 8): a request on a
        /// quiet band after the prompt's chevron, as Claude Code and Codex print what was typed,
        /// the column's full width; the agent's answer open on the black, its creature in the
        /// margin where it starts.
        static var promptSize: CGFloat { pick(13.5, 14.5) }
        static var promptSpacing: CGFloat { pick(2, 2) }
        static var promptFill: Color { ink(0.075) }
        static var promptColor: Color { ink(0.96) }
        static var promptRadius: CGFloat { pick(9, 10) }
        static var promptPaddingH: CGFloat { pick(11, 12) }
        static var promptPaddingV: CGFloat { pick(8, 9) }
        static var promptGlyph: Font { pick(Font.system(size: 10, weight: .bold), .system(size: 10, weight: .bold)) }
        static var promptGlyphColor: Color { ink(0.4) }
        static var promptGlyphWidth: CGFloat { pick(14, 16) }
        /// The outline at the right (after Notion's page outline): a short line per request, the
        /// one in view bright. Shown from two requests.
        static let outlineTick: CGFloat = 2
        static let outlineTickRequest: CGFloat = 18
        static let outlineGapMax: CGFloat = 8
        static let outlineGapMin: CGFloat = 3
        /// The lines' column, and where it sits: inside the right margin, clear of the words.
        static let outlineWidth: CGFloat = 28
        static let outlineInset: CGFloat = 12
        static var outlineOff: Color { ink(0.22) }
        static var outlineOn: Color { ink(0.92) }
        /// Hovered, the outline opens to a card of the requests, each a way there. Concentric: rows
        /// rounded 8 inside a card rounded 14 with 6 of padding.
        static let outlineCardWidth: CGFloat = 280
        static let outlineCardRadius: CGFloat = 14
        static let outlineCardPadding: CGFloat = 6
        static var outlineRowRequest: CGFloat { pick(25, 28) }
        static var outlineRequestFont: Font { pick(Font.system(size: 12), .system(size: 12.5)) }
        static var outlineRequestFontOn: Font { pick(Font.system(size: 12, weight: .semibold), .system(size: 12.5, weight: .semibold)) }
        static var outlineCardFill: Color { skin(Color(white: 0.12), Native.card) }
        static var outlineCardBorder: Color { ink(0.12) }
        static let outlineCardShadow = Color.black.opacity(0.25)
        static let outlineCardShadowRadius: CGFloat = 8
        static var outlineRowHover: Color { ink(0.08) }
        static var outlineTextOn: Color { ink(0.94) }
        static var outlineTextOff: Color { ink(0.58) }
        static var outlineMotion: Animation { Spring.fadeIn(0.14) }
        /// A request counts as the one in view once its top is this close to the top of the history.
        static let outlineReadLine: CGFloat = 96
        /// Expanded, the history is laid out by this long after it opens; then a request too tall
        /// to fit with its answer is brought to the top.
        static let historySettle: Double = 0.35
        /// Waiting on the person: its question and that it waits.
        static var needsYouBody: CGFloat { pick(53, 60) }
        static var responseGap: CGFloat { pick(9, 10) }
        static var responseFont: Font { pick(Font.system(size: 12), .system(size: 13)) }
        // A chat pulled out.
        static var detachedPadding: CGFloat { pick(11, 12) }
        static var detachedSpacing: CGFloat { pick(9, 10) }
        static var detachedHeader: CGFloat { pick(19, 22) }
        static var detachedIcon: CGFloat { pick(16, 18) }
        static var detachedTitle: Font { pick(Font.system(size: 12, weight: .semibold), .system(size: 13, weight: .semibold)) }
        static var detachedClose: CGFloat { pick(18, 20) }
        static var detachedCloseGlyph: Font { pick(Font.system(size: 9.5, weight: .bold), .system(size: 9.5, weight: .semibold)) }
        static var turnSpacing: CGFloat { pick(9, 10) }
        static var turnQuestion: Font { pick(Font.system(size: 12, weight: .semibold), .system(size: 12.5, weight: .semibold)) }
        static var movedOnFont: Font { pick(Font.system(size: 12), .system(size: 12.5)) }
        // The box to ask more.
        static var inputSpacing: CGFloat { pick(7, 8) }
        static var inputPaddingLeading: CGFloat { pick(11, 12) }
        static var inputPaddingTrailing: CGFloat { pick(4.5, 5) }
        static var inputFont: Font { pick(Font.system(size: 12), .system(size: 13)) }
        static var inputSend: CGFloat { pick(21, 24) }
        static var inputSendGlyph: Font { pick(Font.system(size: 10.5, weight: .bold), .system(size: 11, weight: .bold)) }
    }

    /// What the agent at work shows on the mock screen besides its pointer
    /// (MockDesktop/AgentScreen.swift).
    enum AgentScreen {
        /// Selected text: macOS's light selection blue, over the page.
        static let selection = Color(.sRGB, red: 0.70, green: 0.84, blue: 1.0, opacity: 0.6)
        /// A keystroke display: low in the middle of the screen, white on a dark HUD.
        static let keycapFont = Font.system(size: 22, weight: .medium)
        static let keycapFill = Color.black.opacity(0.72)
        static let keycapHeight: CGFloat = 44
        static let keycapPaddingH: CGFloat = 18
        static let keycapRadius: CGFloat = 12
        static let keycapBottom: CGFloat = 150
        /// A context menu.
        static let menuFont = Font.system(size: 13)
        static let menuWidth: CGFloat = 190
        static let menuRow: CGFloat = 22
        static let menuPadding: CGFloat = 5
        static let menuPaddingH: CGFloat = 9
        static let menuRadius: CGFloat = 8
        static let menuHighlightRadius: CGFloat = 4
        /// A screenshot's flash.
        static let flashOpacity = 0.75
        static let flashFade: Double = 0.35
        /// A zoomed region.
        static let zoomDim = Color.black.opacity(0.18)
        static let zoomStroke: CGFloat = 2
        static let zoomRadius: CGFloat = 6
        /// Something dragged.
        static let dragFill = Color.white.opacity(0.55)
        static let dragStroke = Color.black.opacity(0.25)
        static let dragRadius: CGFloat = 8
        /// A toast by Safari's toolbar.
        static let toastFont = Font.system(size: 12, weight: .medium)
        static let toastHeight: CGFloat = 28
        static let toastPaddingH: CGFloat = 12
        static let toastSpacing: CGFloat = 6
        static let toastInset: CGFloat = 14
        static let toastTop: CGFloat = 60
        static let change: Animation = .easeOut(duration: 0.15)
        /// Corner brackets on the element the agent acts on (after Browser Use's highlight: slide
        /// in 150 ms from 7 pt out to 3 pt out, hold 1 s, fade 300 ms), in the accent color.
        static let bracketLength: CGFloat = 10
        static let bracketWeight: CGFloat = 2.5
        static let bracketOut: CGFloat = 3
        static let bracketIn: Animation = .easeOut(duration: 0.15)
        static let bracketHold: Double = 1.0
        static let bracketFade: Animation = .easeOut(duration: 0.3)
        /// Find on page: matches in the find highlight yellow.
        static let find = Color(.sRGB, red: 1.0, green: 0.86, blue: 0.2, opacity: 0.55)
    }

    /// Capture mode: a drag draws a region; clicks, scrolling and typing reach the page.
    enum Capture {
        /// Left Option: a press this short is a tap; two taps this close are a double press (the
        /// whole screen, attached).
        static let tapLength: Double = 0.3
        static let doubleTapWindow: Double = 0.35
        /// A drag shorter than this is a click.
        static let dragThreshold: CGFloat = 4
        /// Smaller regions are ignored.
        static let minimumSide: CGFloat = 12
        /// The selected area is shaded the way macOS's ⌘⇧4 shades it: a translucent neutral gray
        /// over the region (a white page goes light gray, a dark photo lifts a little), a thin
        /// gray outline, nothing outside it dimmed, and no size readout.
        static let fill = Color(white: 0.5, opacity: 0.32)
        static let stroke = Color(white: 0.4, opacity: 0.75)
        static let strokeWidth: CGFloat = 1
        /// Frames for the selection to leave the window before it is captured.
        static let clearDelay: Duration = .milliseconds(50)
        /// The capture flying into the stack (Oct 21: `Spring.flight`, hardly any overshoot over
        /// its long way); it has landed at about 98% of the way.
        static var flight: Animation { Spring.flight }
        static let flightDuration: Duration = .milliseconds(420)
        static let flightStartRadius: CGFloat = 4
    }

    /// How the cards move. The reference is transitions.dev's card-stack-hover (fan 410 ms on
    /// cubic-bezier(0.31, 1.84, 0.64, 1), fold 360 ms on (0.34, 1.5, 0.64, 1), hover scale
    /// 610 ms on (0.22, 1, 0.36, 1)); its overshoot is capped near 12 pt, about what it reaches
    /// on its own 48 px move, since a 19 % overshoot on a 300 pt move would fling a card out of
    /// the island (16 pt of padding).
    /// No bounce is the Island's own rule (amendment §14), to compare against.
    /// Oct 21, Ryan: springs (`spring`, the default), interruptible; "simpler is better": no
    /// bounce opening or folding, and nothing grows under the pointer.
    enum CardMotion: String, CaseIterable, Identifiable {
        case spring, reference, noBounce
        var id: String { rawValue }
        var title: String { self == .spring ? "Spring" : self == .reference ? "Reference" : "No bounce" }
        var fan: Animation {
            switch self {
            case .spring: return Spring.part
            case .reference: return Animation(CappedOvershoot(x1: 0.31, y1: 1.84, x2: 0.64, y2: 1, duration: 0.41, cap: 12))
            case .noBounce: return .interpolatingSpring(duration: 0.3, bounce: 0)
            }
        }
        var fold: Animation {
            switch self {
            case .spring: return Spring.partBack
            case .reference: return Animation(CappedOvershoot(x1: 0.34, y1: 1.5, x2: 0.64, y2: 1, duration: 0.36, cap: 8))
            case .noBounce: return .interpolatingSpring(duration: 0.24, bounce: 0)
            }
        }
    }

    enum Colors {
        /// The slate the shipping snapshot stage paints when there is no wallpaper.
        static let desktopFallback = Color(.sRGB, red: 0x5B / 255.0, green: 0x64 / 255.0, blue: 0x72 / 255.0)
        static let desktopBlack = Color.black
        static let desktopWhite = Color.white
        static let notch = Color.black
        /// The band beside the notch when an app is full screen: the menu bar is gone, black remains.
        static let notchBand = Color.black
        static let safariField = Color.primary.opacity(0.07)
        /// Web pages keep their own light look.
        static let page = Color.white
        static let bezel = Color.black
        static let dockHairline = Color.white.opacity(0.15)
    }

    /// SwiftUI materials blur what the window draws behind them, so the wallpaper shows through.
    enum Materials {
        static let menuBar: Material = .bar
        static let dock: Material = .regular
    }

    /// The Safari tab shown full screen: its toolbar, then a page column.
    enum Safari {
        static let toolbarHeight: CGFloat = 52
        static let toolbarPadding: CGFloat = 16
        static let toolbarSpacing: CGFloat = 18
        static let toolbarGlyph = Font.system(size: 15, weight: .medium)
        static let addressWidth: CGFloat = 560
        static let addressHeight: CGFloat = 30
        static let addressRadius: CGFloat = 8
        static let addressSpacing: CGFloat = 5
        static let address = Font.system(size: 13)
        static let addressFocusedFill = Color.white
        static let addressGlyph = Font.system(size: 10)
        static let pageTop: CGFloat = 44
        static let pageSpacing: CGFloat = 22
        static let columnWidth: CGFloat = 720
        static let navSpacing: CGFloat = 28
        static let nav = Font.system(size: 14, weight: .medium)
        static let heroHeight: CGFloat = 360
        static let heroRadius: CGFloat = 12
        static let headline = Font.system(size: 40, weight: .bold)
        static let byline = Font.system(size: 13)
        static let body = Font.system(size: 18)
        static let bodyLineSpacing: CGFloat = 6
        // The tab bar (Safari's separate tab layout, under the toolbar).
        static let tabBarHeight: CGFloat = 36
        static let tabBarPadding: CGFloat = 8
        static let tabGap: CGFloat = 6
        static let tabHeight: CGFloat = 28
        static let tabRadius: CGFloat = 7
        static let tabSpacing: CGFloat = 7
        static let tabFont = Font.system(size: 12)
        static let tabFontSelected = Font.system(size: 12, weight: .medium)
        static let tabGlyph = Font.system(size: 11, weight: .semibold)
        static let tabSelected = Color.primary.opacity(0.1)
        static let tabHover = Color.primary.opacity(0.05)
        // Page content.
        static let sectionTitle = Font.system(size: 26, weight: .bold)
        static let caption = Font.system(size: 13)
        static let galleryHeight: CGFloat = 300
        static let gallerySpacing: CGFloat = 16
        static let code = Font.system(size: 14, design: .monospaced)
        static let codeLineHeight: CGFloat = 22
        static let codeFill = Color(.sRGB, red: 0.965, green: 0.965, blue: 0.97)
        static let codeKeyword = Color(.sRGB, red: 0.61, green: 0.14, blue: 0.58)
        static let codeComment = Color(.sRGB, red: 0.42, green: 0.47, blue: 0.5)
        static let swatchSize: CGFloat = 96
        static let pageBottom: CGFloat = 120
        /// Each tab's favicon tint, in tab order.
        static let faviconTints: [Color] = [.blue, .orange, .purple, .gray]
        /// The design notes' palette swatches.
        static let swatches: [(name: String, color: Color)] = [
            ("Island", .black), ("Ink", Color(.sRGB, red: 0.047, green: 0.047, blue: 0.047)),
            ("Canvas", Color(.sRGB, red: 0.984, green: 0.98, blue: 0.969)), ("Waveform", .white),
        ]
        static let swatchBorder = Color.primary.opacity(0.12)
        /// The notes' comment box: the one input box on the mock pages, where a transcript is
        /// pasted.
        static let commentFont = Font.system(size: 15)
        static let commentMinHeight: CGFloat = 64
        static let commentPadding: CGFloat = 12
        static let commentRadius: CGFloat = 8
        static let commentBorder = Color.primary.opacity(0.18)
        static let commentFill = Color.white
        /// Scrolling the demo does: a page length in 0.8 s.
        static let scrollAnimation: Animation = .easeInOut(duration: 0.8)
    }

    enum Type_ {
        static let menuBar = Font.system(size: 13)
        static let menuBarApp = Font.system(size: 13, weight: .semibold)
    }

    enum Snapshot {
        /// A fixed clock, so a PNG does not change with the time of day.
        static let date: Date = {
            var c = DateComponents()
            c.year = 2026; c.month = 9; c.day = 24; c.hour = 9; c.minute = 41
            return Calendar.current.date(from: c) ?? Date(timeIntervalSince1970: 0)
        }()
        static let size = Layout.windowDefault
        /// Real display cycles the window gets after each change before it is captured.
        static let settle: TimeInterval = 0.5
    }

    /// The Oct 6 feedback's Voiceflow pieces (Feedback/*.swift; docs/island/FEEDBACK_2026-10-06.md):
    /// the errors' notice, picking with ⌘, the last minute's countdown, the words landing.
    enum Feedback {
        // #2: the notice in place of the bar: Paste not found's width and corners, its ring and
        // gray capsule; the glyph in the tone's color, everything else white at an opacity.
        static var noticeWidth: CGFloat { pick(368, 400) }
        /// Inside the listening bar: wide enough for the words and one capsule.
        static let barNoticeWidth: CGFloat = 340
        /// The largest picture a request carries (Image over 20 MB, not added).
        static let imageLimit = 20 * 1024 * 1024
        /// Where the words landed, lit a moment (#7, the real field's frame through Accessibility).
        static let landMarkHold: Double = 0.9
        static var noticePaddingH: CGFloat { pick(14, 16) }
        static var noticePaddingTop: CGFloat { pick(8, 9) + Native.panelGap }
        static var noticePaddingBottom: CGFloat { pick(11, 12) }
        static var noticeRow: CGFloat { pick(23, 26) }
        static let noticeMessageGap: CGFloat = 2
        static var noticeMessageHeight: CGFloat { pick(16, 18) }
        static var noticeGlyph: Font { pick(Font.system(size: 12, weight: .semibold), .system(size: 12.5, weight: .semibold)) }
        static var noticeGlyphWidth: CGFloat { pick(16, 18) }
        static var noticeTitle: Font { pick(Font.system(size: 12.5, weight: .semibold), .system(size: 13.5, weight: .semibold)) }
        static var noticeTitleColor: Color { ink(0.94) }
        static var noticeMessage: Font { pick(Font.system(size: 12), .system(size: 12.5)) }
        static var noticeMessageColor: Color { ink(0.55) }
        static var infoColor: Color { ink(0.62) }
        static var yoursColor: Color { Panel.needsYouColor }
        static var failureColor: Color { Panel.failedColor }
        static var actionHeight: CGFloat { pick(21, 24) }
        static var actionPaddingH: CGFloat { pick(11, 12) }
        static var actionFont: Font { pick(Font.system(size: 11.5, weight: .semibold), .system(size: 12, weight: .semibold)) }
        /// How long each kind stays (paused while the pointer is on it).
        static let errorInfoTime: Double = 2.5
        static let errorWarningTime: Double = 4
        static let errorActionTime: Double = 8
        static let barNoticeTime: Double = 3
        static var noticeSpring: Animation { Spring.resize }
        static var noticeAway: Animation { Spring.fold }

        // #3, #8: the highlighter's marks in the accent color: a marker's strokes over words,
        // multiplied into the page; a rounded mark round a file, as Finder marks a selection.
        static let markOpacity: Double = 0.38
        static let markRadius: CGFloat = 3
        static let fileMarkOpacity: Double = 0.28
        static let fileMarkRadius: CGFloat = 8
        static var markFade: Animation { Spring.fadeIn(0.18) }
        /// On the real Mac (Oct 9, evening): never the accent. A very light gray, as macOS shades a
        /// ⌘⇧4 selection, with a thin gray outline round a file; the mark goes a moment after what
        /// it marks has flown into the stack, so nothing stays on the screen (or follows you to
        /// another app). With ⌥ on, the file under the pointer is shaded the same way first.
        static let liveMarkFill = Color(white: 0.5, opacity: 0.2)
        static let liveMarkStroke = Color(white: 0.4, opacity: 0.6)
        static let liveMarkStrokeWidth: CGFloat = 1
        static let liveHoverFill = Color(white: 0.5, opacity: 0.14)
        static let liveMarkHold: Double = 0.9
        static var liveMarkFade: Animation { Spring.fadeOut(0.3) }
        /// Oct 21, Ryan: the marks over other apps' windows follow the pointer 1:1 while drawn,
        /// and fade on the strong ease-out when they go.
        static let liveMarkFadeOut: Double = 0.18

        // #4: ten minutes at most; the last minute counts down at the bar's right.
        static let recordingLimit: Double = 600
        static let countdownFrom: Double = 60
        /// The last seconds turn the digits Needs you amber.
        static let countdownWarn: Double = 10
        static let countdownFont = Font.system(size: 12.5, weight: .semibold).monospacedDigit()
        static var countdownColor: Color { ink(0.85) }
        static var countdownWarnColor: Color { Panel.needsYouColor }
        static let countdownWidth: CGFloat = 32
        static let countdownInset: CGFloat = 10
        static var countdownIn: Animation { Spring.fadeIn(0.2) }

        // #7: the words land in the field, it lights up, and this long after, the notch leaves.
        static let landHold: Double = 0.45
        static let landGlow: Double = 1.2
        static let landHighlight = AgentScreen.selection
        static let landScale: CGFloat = 0.985
        /// #6: the insertion caret in the field the words will go to, in the accent color, blinking
        /// at macOS's rate.
        static let caretBlink: Double = 0.53

        // #6: Split View's two apps, the divider between them.
        static let splitDivider: CGFloat = 6
        static let splitWindowRadius: CGFloat = 10
        // The notice's room that followed the density (docs/island/SPACIOUS.md).
        static var noticeSpacing: CGFloat { pick(7, 8) }
        static var noticeBottomRadius: CGFloat { pick(Island.spec.expandedBottomRadius, 28) }
        // Inside the listening bar, the voice bar's size in both densities.
        static let barNoticeGlyph = Font.system(size: 12.5, weight: .semibold)
        static let barNoticeTitle = Font.system(size: 12.5, weight: .medium)
        static let barNoticeSpacing: CGFloat = 7
        static let barNoticePaddingH: CGFloat = 14
        static let barNoticeTrailing: CGFloat = 6
        static let barActionHeight: CGFloat = 24
        static let barActionPaddingH: CGFloat = 12
        static let barActionFont = Font.system(size: 12, weight: .semibold)
    }

    /// The control board, round two (Feedback/V2Board.swift): a menu from the notch, text first, after
    /// the HIG's menu-bar menus and Claude Code's Agent View. Body 13, secondary 11, a 28 pt row, the
    /// menu's highlight; the running ring is the HIG's small unlabeled spinner.
    enum Board {
        // Round three: two-line rows led by the agent's icon, parted by state. Sections puts the
        // state in a header (a glyph and a word) over its rows; Badges puts it on each icon.
        static var width: CGFloat { pick(368, 400) }
        static var paddingH: CGFloat { pick(5.5, 6) }
        static var paddingBottom: CGFloat { pick(7, 8) }
        /// Nothing running (the real Mac, Oct 9): the board greets the person instead, in two
        /// lines, the title's face over the line's.
        static var helloHeight: CGFloat { pick(50, 56) }
        // Oct 18, Ryan: in the primary language.
        static var helloLead: String { L("Start building here.") }
        static var bottomRadius: CGFloat { pick(19, 22) }
        static var row: CGFloat { pick(40, 46) }
        static let rowsVisible = 6
        static var rowPaddingH: CGFloat { pick(9, 10) }
        static var rowRadius: CGFloat { pick(8, 9) }
        static var lineGap: CGFloat { pick(2, 2) }
        static var groupGap: CGFloat { pick(8, 9) }
        static var hairline: Color { ink(0.08) }
        static var highlight: Color { pick(ink(0.07), ink(0.06)) }
        static var move: Animation { Spring.rows }
        // A section's header: its glyph and its word, quiet; the first sits closer to the notch.
        static var header: CGFloat { pick(23, 26) }
        static var headerFirst: CGFloat { pick(18, 20) }
        static var headerGlyph: CGFloat { pick(10, 11) }
        static let headerGap: CGFloat = 6
        static var headerFont: Font { pick(Font.system(size: 10.5, weight: .semibold), .system(size: 11, weight: .semibold)) }
        static var headerColor: Color { pick(ink(0.45), ink(0.5)) }
        static var headerGlyphColor: Color { ink(0.55) }
        // The agent's icon: 20 pt in Sections; 26 pt with a 12 pt badge in Badges, cut out of
        // the icon by a ring of the island's black.
        static var icon: CGFloat { pick(18, 20) }
        static var badgedIcon: CGFloat { pick(23, 26) }
        static var iconGap: CGFloat { pick(9, 10) }
        static var badge: CGFloat { pick(11, 12) }
        static let badgeRing: CGFloat = 2
        static let badgeOffset: CGFloat = 3
        static var badgeGlyph: Font { pick(Font.system(size: 6.5, weight: .black), .system(size: 6.5, weight: .black)) }
        static let dimSaturation: Double = 0
        static let dimOpacity: Double = 0.4
        // The words: the title over one line in a quieter ink.
        static var titleFont: Font { pick(Font.system(size: 12.5, weight: .semibold), .system(size: 13.5, weight: .semibold)) }
        static var title: Color { ink(0.92) }
        static var dimTitle: Color { ink(0.45) }
        static var lineFont: Font { pick(Font.system(size: lineSize), .system(size: lineSize)) }
        static var lineSize: CGFloat { pick(11, 11.5) }
        static var line: Color { ink(0.6) }
        static var commandFont: Font { pick(Font.system(size: 10.5, design: .monospaced), .system(size: 11, design: .monospaced)) }
        static var wordFont: Font { pick(Font.system(size: 11, weight: .medium), .system(size: 11.5, weight: .medium)) }
        static var done: Color { ink(0.7) }
        static let projectFont = Font.system(size: 11)
        static var project: Color { ink(0.35) }
        // The trailing column: how long, in figures that don't jump; the ring beside it.
        static var timeFont: Font { pick(Font.system(size: 11, weight: .medium), .system(size: 11.5, weight: .medium)) }
        static var time: Color { ink(0.4) }
        static var trailingWidth: CGFloat { pick(39, 44) }
        static var ring: CGFloat { pick(10, 11) }
        static var chevron: Font { pick(Font.system(size: 10, weight: .semibold), .system(size: 10, weight: .semibold)) }
        // The session view, while it works: one quiet line; under it the bar and the box.
        static var workingLine: CGFloat { pick(25, 28) }
        static var workingFont: Font { pick(Font.system(size: 12, weight: .medium), .system(size: 12.5, weight: .medium)) }
        static var workingSize: CGFloat { pick(12, 12.5) }
        static var working: Color { ink(0.6) }
        static var actionRow: CGFloat { pick(26, 30) }
        static var inputGap: CGFloat { pick(7, 8) }
        // #19: the agent's icon at the voice bar's right.
        static let routeIcon: CGFloat = 16
        static let routeInset: CGFloat = 8
        // Values that were written in the views (docs/island/SPACIOUS.md).
        static var headerBottom: CGFloat { pick(4.5, 5) }
        static var trailingGap: CGFloat { pick(5.5, 6) }
        static var workingGap: CGFloat { pick(7, 8) }
        static var workingGlyph: CGFloat { pick(11, 12) }
        static var openInFont: Font { pick(Font.system(size: 12), .system(size: 12.5)) }
        static var openInArrow: Font { pick(Font.system(size: 9, weight: .bold), .system(size: 9, weight: .bold)) }
        static var openInGap: CGFloat { pick(4, 4) }
        static var expandButton: CGFloat { pick(19, 22) }
    }

    /// The agent's steps while it works, one at a time (Feedback/V2Steps.swift): white at the
    /// Island's opacities; red only for a command that failed.
    enum Steps {
        /// How often the line moves on: a step takes two ticks, three with its result.
        static let tick: Double = 0.9
        /// The step's line giving way to the next (a crossfade): content, on the strong ease-out.
        static var change: Animation { Spring.fadeIn(0.2) }
        static var glyph: Color { ink(0.5) }
        static var verb: Color { ink(0.55) }
        static var object: Color { ink(0.92) }
        static var added: Color { ink(0.85) }
        static var removed: Color { ink(0.45) }
    }

    /// The control board's four other designs (Feedback/V2BoardVariants.swift), each from a
    /// different family of notch apps (docs/island/FEEDBACK_2026-10-06.md, "The control board,
    /// round four"). Drawn at the Spacious scale; white at an opacity on black, amber for what
    /// waits on the person, red for a failure.
    enum BoardV {
        // Shared.
        static let titleFont = Font.system(size: 15, weight: .semibold)
        static let subFont = Font.system(size: 12.5)
        static let rowTitleFont = Font.system(size: 13.5, weight: .medium)
        static let timeFont = Font.system(size: 12, weight: .medium)
        static let questionSize: CGFloat = 17
        static let answerSize: CGFloat = 15
        static let bigTime = Font.system(size: 34, weight: .light).monospacedDigit()
        static let bigTimeHeight: CGFloat = 40
        static var sub: Color { ink(0.55) }
        static var answer: Color { ink(0.85) }
        static var question: Color { ink(0.95) }
        static var hairline: Color { ink(0.1) }
        static var selectedFill: Color { ink(0.08) }
        // The big buttons: halves of the row, capsules, the primary one white.
        static let actionHeight: CGFloat = 36
        static let actionGap: CGFloat = 10
        static let actionFont = Font.system(size: 14, weight: .semibold)
        static var actionFill: Color { ink(0.12) }
        static var actionFillHover: Color { ink(0.18) }
        // Focus: the most pressing session as a card, the rest on a shelf under it
        // (Pushary's permission card, Atoll's agents, Crew Tower).
        static let focusWidth: CGFloat = 460
        static let focusMargin: CGFloat = 22
        static let focusHeader: CGFloat = 42
        static let focusIcon: CGFloat = 28
        static let focusGap: CGFloat = 12
        static let focusLines = 3
        static let shelfRule: CGFloat = 28
        static let shelfRow: CGFloat = 36
        static let shelfRowsVisible = 5
        static let shelfIcon: CGFloat = 18
        static let shelfGlyph: CGFloat = 11
        static let bottom: CGFloat = 16
        static let pillFont = Font.system(size: 12, weight: .semibold)
        static let pillHeight: CGFloat = 24
        static var pillFill: Color { WorkbenchTokens.Panel.needsYouColor.opacity(0.16) }
        // Capsules: each session its own small island under the notch (Droppy's bubbles, the
        // Dynamic Island's detached minimal); the island itself stays the notch.
        static let capsuleTop: CGFloat = 8
        static let capsuleGap: CGFloat = 6
        static let capsuleWide: CGFloat = 440
        static let capsuleWidth: CGFloat = 420
        static let capsuleQuiet: CGFloat = 380
        static let capsuleTall: CGFloat = 74
        static let capsuleHeight: CGFloat = 46
        static let capsuleQuietHeight: CGFloat = 40
        static let capsuleRadius: CGFloat = 23
        static let capsuleTallRadius: CGFloat = 26
        static let capsulePadding: CGFloat = 14
        static let capsuleIcon: CGFloat = 24
        static var capsuleStroke: Color { ink(0.1) }
        static let capsuleShadow = Color.black.opacity(0.35)
        static let capsuleStagger: Double = 0.03
        static let capsuleIn: Animation = .interpolatingSpring(duration: 0.32, bounce: 0)
        // Wings: the sessions as tokens in the notch's wings (DynamicLake's and Pushary's wings,
        // the Dynamic Island's minimal); the one in focus on the stage below.
        static let wingsWidth: CGFloat = 540
        static let token: CGFloat = 26
        static let tokenIcon: CGFloat = 18
        static let tokenGap: CGFloat = 8
        static let tokensPerWing = 4
        static let tokenRing: CGFloat = 2
        static let wingInset: CGFloat = 12
        static let stage: CGFloat = 176
        static let stageMargin: CGFloat = 24
        // Split: the sessions at the left, the one in focus at the right (Boring Notch's and
        // Droppy's two panes); Dispatch's width.
        static let splitList: CGFloat = 236
        static let splitGap: CGFloat = 16
        static let splitRow: CGFloat = 40
        static let splitRowsVisible = 6
        static let splitIcon: CGFloat = 20
        static let splitDetailLines = 7
    }

    /// The pet in each of the board's pet designs (Oct 8, docs/island/CREATURES.md): every session
    /// with its agent's icon, its title and its pet at once, so nothing waits for a hover.
    /// The same pet in every design of the board (Oct 8, docs/island/CREATURES.md): where it
    /// stands in each, and how large.
    enum Pets {
        // List: the pet leads each row; the agent's icon sits by the title.
        static var listPet: CGFloat { pick(18, 20) }
        static var listAgentIcon: CGFloat { pick(11, 13) }
        static let agentGap: CGFloat = 6
        // Capsules: the pet at each capsule's front.
        static let capsulePet: CGFloat = 22
        // Desk: the sessions as a team, four to a row: each pet at its desk, its name under it.
        static var deskWidth: CGFloat { pick(534, 580) }
        static let deskMargin: CGFloat = 14
        static let deskColumns = 4
        static var deskCell: CGFloat { pick(114, 124) }
        static let deskGap: CGFloat = 8
        static let deskRowsVisible = 3
        static let deskRadius: CGFloat = 14
        static let deskPadding: CGFloat = 9
        static var deskPet: CGFloat { pick(25, 28) }
        static var deskAgentIcon: CGFloat { pick(12, 14) }
        static var deskFill: Color { ink(0.055) }
        static var deskFillHover: Color { ink(0.09) }
        static var deskWaiting: Color { Panel.needsYouColor.opacity(0.55) }
        static var deskWaitingFill: Color { Panel.needsYouColor.opacity(0.07) }
        static var deskTitle: Font { pick(Font.system(size: 12, weight: .semibold), .system(size: 12.5, weight: .semibold)) }
        static var deskLineSize: CGFloat { pick(10.5, 11) }
        static let deskTime = Font.system(size: 11, weight: .medium)
        // Lanes: a lane each, its pet along a track as far as its plan has got; at the end once done.
        static var lanesWidth: CGFloat { pick(515, 560) }
        static let lanesMargin: CGFloat = 16
        static var lane: CGFloat { pick(49, 56) }
        /// A session whose state can't be read: one quiet line, its pet asleep at the start.
        static var quietLane: CGFloat { pick(28, 32) }
        /// The lanes' room; past it they scroll.
        static var lanesMax: CGFloat { pick(442, 480) }
        static var lanePet: CGFloat { pick(15, 17) }
        static var laneIcon: CGFloat { pick(12, 14) }
        static var laneTrack: Color { ink(0.12) }
        static var laneTravelled: Color { ink(0.42) }
        static var laneFinish: Color { ink(0.45) }
        static let laneLine: CGFloat = 1.5
        /// The track's start, and its end before the finish (of the lane's width): room for the
        /// pet at either end.
        static let laneStart: CGFloat = 14
        static let laneEnd: CGFloat = 16
        static var laneTitle: Font { pick(Font.system(size: 12, weight: .semibold), .system(size: 12.5, weight: .semibold)) }
        static var laneStepSize: CGFloat { pick(11, 11.5) }
        static let laneMove: Animation = .interpolatingSpring(duration: 0.7, bounce: 0.15)
        // At rest: beside the notch, as the Dynamic Island's detached minimal: a black circle with
        // the pet of the session most in need, in Codex Pets' order (waiting, failed, done, running).
        static let restInset: CGFloat = 3
        static let restGap: CGFloat = 6
        static let restPet: CGFloat = 17
        static let restIn: Animation = .interpolatingSpring(duration: 0.4, bounce: 0)
        /// An opened session's header: its pet before its agent's icon.
        static let headerPet: CGFloat = 18
    }

    /// The control board's pet (Oct 8, docs/island/CREATURES.md): the Lasso, alive, Fovea's hand-
    /// drawn circle with two eyes inside, drawn as far as its agent has got through its plan. One pet
    /// in every design (Pets: List, Capsules, Desk, Lanes, Wings; and at rest beside the notch).
    /// White on black as everything on the island; amber when it waits on the person, coral when it
    /// failed. The pen at its tip is its agent: Claude Code's spinner glyph, Codex's bullet.
    enum Creatures {
        // Wings: wider than Wings' 540, so each wing holds four at full spacing and a huddle.
        static let width: CGFloat = 600
        /// A pet in a wing: its loop's height; its place.
        static let size: CGFloat = 18
        static let pitch: CGFloat = 30
        static let huddle: CGFloat = 13
        static let groupGap: CGFloat = 10
        static let wingInset: CGFloat = 16
        /// Its foot this far above the band's foot.
        static let footLift: CGFloat = 4
        /// On the stage: the one in focus, larger, in the card's header.
        static let stageSize: CGFloat = 24
        // The pet: its frame (of its height), the loop (a little wider than tall), the line as the
        // Lasso's, the faint whole loop under the stroke, the pen, the eyes.
        static let frameWidth: CGFloat = 1.5
        static let frameHeight: CGFloat = 1.3
        /// Its footprint's width (of its height), for spacing.
        static let footprint: CGFloat = 1.2
        static let loopWide: CGFloat = 0.56
        static let lineRatio: CGFloat = 0.085
        static let trackOpacity: Double = 0.18
        static let penSize: CGFloat = 0.17
        static let eyeWidth: CGFloat = 0.12
        static let eyeHeight: CGFloat = 0.2
        static let eyeGap: CGFloat = 0.21
        static var body: Color { ink(0.95) }
        static var bodyAsleep: Color { ink(0.32) }
        static var bodyStopped: Color { ink(0.55) }
        static var eyeOnDark: Color { ink(0.95) }
        static var zColor: Color { ink(0.5) }
        /// How far the loop is drawn: a little to start (and when no plan was reported), then its
        /// plan's share; failed with no plan, about half. Whole once done or waiting on the person.
        static let arcStart: Double = 0.18
        static let arcWorking: Double = 0.94
        static let arcUnknown: Double = 0.45
        /// The stroke drawing on to where the work has got.
        static let drawOn: Double = 0.7
        static let fillChange: Animation = .interpolatingSpring(duration: 0.7, bounce: 0)
        // Under the pointer: it grows, the Dock's way, and its neighbours a little.
        static let magnify: CGFloat = 0.32
        static let magnifyReach: CGFloat = 46
        // Motion (a creature's own, outside the island's springs). Calm by default: at rest, a
        // breath of well under a point and the fill's surface, both slower than 2.5 s, and its
        // agent's spinner; each real event, one gesture of half a second (CREATURES.md).
        /// Small figures need no more (notch apps cap theirs at 20); none at all while hidden.
        static let frameRate: Double = 24
        static let breath: Double = 3.0
        static let breathDepth: Double = 0.03
        static let blinkLength: Double = 0.12
        static let gesture: Double = 0.5
        /// Waiting on the person: one call, rising this much larger, then held there, still.
        static let callLength: Double = 0.5
        static let callScale: CGFloat = 1.12
        static let spinnerFrame: Double = 0.12
        /// Arriving, leaving, changing wings: the island's spring, with a hop on the way.
        static let move: Animation = .interpolatingSpring(duration: 0.55, bounce: 0)
        static let hopHeight: CGFloat = 9
        static let hopDuration: Double = 0.42
        /// The board opening: a small hop each, one after another.
        static let noticeStagger: Double = 0.045
        static let noticeLength: Double = 0.36
        static let lift: Animation = .interpolatingSpring(duration: 0.22, bounce: 0)
        /// A failure: one short shake of the head, then still (it doesn't nag).
        static let shake: CGFloat = 3
        static let shakeDuration: Double = 0.28
    }

    /// The Oct 6 feedback's Dispatch Version 2 pieces (Feedback/V2Feedback*.swift): the stack and
    /// the model in Choose chat, progress from what agents report, the answer as written, the
    /// queue, the voice bar's chat and model, answer again and stop. White at an opacity on black.
    enum FeedbackV2 {
        // #1: the referents as one stack, a row under the pointer; the model pill and its sheet.
        static var pileHeight: CGFloat { pick(35, 40) }
        static let pileAspect: CGFloat = 1.3
        static var pileOffset: CGFloat { pick(5.5, 6) }
        static let pileShrink: CGFloat = 0.08
        static let pileBackOpacity: Double = 0.65
        static var fanGap: CGFloat { pick(5.5, 6) }
        static var fanPadding: CGFloat { pick(4.5, 5) }
        static var fanFill: Color { skin(Color(white: 0.08), Native.card) }
        /// The row fading in over the stack, and out (Oct 21, Ryan, "simpler is better": a fade).
        static var fanMotion: Animation { Spring.fadeIn(0.15) }
        static var modelPillMax: CGFloat { pick(156, 170) }
        static var chatPillMax: CGFloat { pick(202, 220) }
        static var sheetRow: CGFloat { pick(26, 30) }
        static var sheetGap: CGFloat { pick(5.5, 6) }
        static var sheetLabelWidth: CGFloat { pick(56, 64) }
        static var sheetChipHeight: CGFloat { pick(21, 24) }
        static var sheetChipFont: Font { pick(Font.system(size: 11.5, weight: .medium), .system(size: 12, weight: .medium)) }

        // #9–10: where the screen was.
        static var cardFill: Color { ink(0.05) }
        static let cardRadius: CGFloat = 12
        static let cardPadding: CGFloat = 12
        static var codeFont: Font { pick(Font.system(size: 11, design: .monospaced), .system(size: 11.5, design: .monospaced)) }
        static var codeColor: Color { ink(0.8) }
        static var codeDim: Color { ink(0.32) }
        static var codeAddedFill: Color { ink(0.07) }
        static var lineNumberColor: Color { ink(0.25) }
        static let kindFont = Font.system(size: 12, weight: .semibold)
        static let objectFont = Font.system(size: 12, weight: .semibold, design: .monospaced)
        static let segmentHeight: CGFloat = 4
        static let segmentGap: CGFloat = 4
        static var segmentDone: Color { ink(0.85) }
        static var segmentTodo: Color { ink(0.14) }
        static let ringWidth: CGFloat = 3
        static let diffBlocks = 5
        static let diffBlock: CGFloat = 6
        static var diffAdded: Color { ink(0.85) }
        static var diffRemoved: Color { ink(0.3) }
        static var diffEmpty: Color { ink(0.1) }
        static let rowVisual: CGFloat = 40
        static let progressHeight: CGFloat = 168

        // #11–13: the answer as written, its steps folded, what it made to open.
        static var answerFont: Font { pick(Font.system(size: answerSize), .system(size: answerSize)) }
        static var answerColor: Color { ink(0.88) }
        static var answerStrong: Color { ink(0.98) }
        static var answerSpacing: CGFloat { pick(3, 3) }
        static var blockGap: CGFloat { pick(8, 9) }
        static var quoteFill: Color { ink(0.06) }
        static var tableRule: Color { ink(0.1) }
        static var tableRow: CGFloat { pick(21, 24) }
        static var stepsRow: CGFloat { pick(19, 22) }
        static let stepLine: CGFloat = 20
        static var stepsFont: Font { pick(Font.system(size: stepsSize), .system(size: stepsSize)) }
        static var stepsColor: Color { ink(0.5) }
        static var artifactHeight: CGFloat { pick(23, 26) }
        static var artifactFont: Font { pick(Font.system(size: 11.5, weight: .medium), .system(size: 12, weight: .medium)) }
        static var artifactFill: Color { ink(0.09) }
        static var artifactFillHover: Color { ink(0.15) }
        static var chatBodyMax: CGFloat { pick(276, 300) }


        // #19: the voice bar's chat, model and effort when the words aren't reviewed.
        static let routeBarWidth: CGFloat = 440
        static let routeBarTwoWidth: CGFloat = 480
        static let wingWidth: CGFloat = 86
        static let routeHeight: CGFloat = 26
        static let routeFont = Font.system(size: 12, weight: .medium)
        static let routeSheetWidth: CGFloat = 520
        static let routeSheetPadding: CGFloat = 12

        // #23: answer again, stop.
        static var iconButton: CGFloat { pick(21, 24) }
        static let inlineRow: CGFloat = 26

        // #24: what waits.
        static var queueHeader: CGFloat { pick(21, 24) }
        static var queueRow: CGFloat { pick(30, 34) }
        static var queueThumb: CGFloat { pick(19, 22) }
        static var queueFill: Color { ink(0.05) }
        // Values that were written in the views (docs/island/SPACIOUS.md). Compact is each one's
        // value through Oct 6.
        // The pile's fan.
        static var fanRadius: CGFloat { pick(11, 12) }
        // The model sheet's chips.
        static var sheetChipGap: CGFloat { pick(5.5, 6) }
        static var sheetChipPaddingH: CGFloat { pick(9, 10) }
        static var sheetChipIcon: CGFloat { pick(11, 13) }
        static var sheetCheck: Font { pick(Font.system(size: 8.5, weight: .bold), .system(size: 8.5, weight: .bold)) }
        // The answer, as written: Captures' expanded card reads at 15 on 5.
        static var answerSize: CGFloat { pick(12.5, 13.5) }
        static var answerGap: CGFloat { pick(9, 10) }
        static var headingSize: CGFloat { pick(13, 14) }
        static var inlineCodeSize: CGFloat { pick(12, 12.5) }
        static var bulletSpacing: CGFloat { pick(3, 3) }
        static var bulletMarker: CGFloat { pick(11, 12) }
        static var bulletGap: CGFloat { pick(5.5, 6) }
        static var quotePaddingH: CGFloat { pick(12, 14) }
        static var quotePaddingV: CGFloat { pick(10, 11) }
        static var quoteRadius: CGFloat { pick(9, 10) }
        static var codePadding: CGFloat { pick(9, 10) }
        static var codeRadius: CGFloat { pick(7, 8) }
        static var codeLine: CGFloat { pick(14, 16) }
        static var tableHeader: Font { pick(Font.system(size: 11.5, weight: .semibold), .system(size: 12, weight: .semibold)) }
        static var tableCellSize: CGFloat { pick(12, 13) }
        static var tableLeadSize: CGFloat { pick(12.5, 13.5) }
        static var tableSpacing: CGFloat { pick(14, 16) }
        // Its work, folded.
        static var stepsSize: CGFloat { pick(11.5, 12) }
        static var stepsChevron: Font { pick(Font.system(size: 8.5, weight: .bold), .system(size: 8.5, weight: .bold)) }
        static var stepsIndent: CGFloat { pick(9, 10) }
        static var stepsLineGap: CGFloat { pick(4, 4) }
        static var stepsBottom: CGFloat { pick(5.5, 6) }
        static var stepsHover: Color { ink(0.8) }
        // Its work, opened (Oct 7, docs/island/WHOLE_SESSION.md): a row per step, the glyph, the
        // tool as a verb and what it acted on, what came of it at the right; the agent's words
        // between them, brighter than the verbs and dimmer than the answer.
        static var workRow: CGFloat { pick(18, 21) }
        static var workGap: CGFloat { pick(2, 2) }
        static var workTop: CGFloat { pick(2, 2) }
        static var workGlyph: Font { pick(Font.system(size: 10.5, weight: .medium), .system(size: 10.5, weight: .medium)) }
        static var workGlyphWidth: CGFloat { pick(12, 14) }
        static var workGlyphGap: CGFloat { pick(5.5, 6) }
        static let workResultGap: CGFloat = 12
        static var workObject: Font { pick(Font.system(size: 11.5, weight: .medium), .system(size: 12, weight: .medium)) }
        static var workCode: Font { pick(Font.system(size: 11, design: .monospaced), .system(size: 11.5, design: .monospaced)) }
        static var workCount: Font { pick(Font.system(size: 12, weight: .medium).monospacedDigit(), .system(size: 13, weight: .medium).monospacedDigit()) }
        static var workRule: Color { ink(0.12) }
        static var workRemark: Color { ink(0.62) }
        // What it made, to open.
        static var artifactGap: CGFloat { pick(5.5, 6) }
        static var artifactPaddingH: CGFloat { pick(9, 10) }
        static var artifactGlyph: Font { pick(Font.system(size: 10.5, weight: .medium), .system(size: 11, weight: .medium)) }
        // Stop, Answer again.
        static var iconChipFont: Font { pick(Font.system(size: 11.5, weight: .medium), .system(size: 12, weight: .medium)) }
        static var iconChipGlyph: Font { pick(Font.system(size: 10, weight: .semibold), .system(size: 10, weight: .semibold)) }
        static var iconChipPaddingH: CGFloat { pick(8, 9) }
        // The queue.
        static var queueSpacing: CGFloat { pick(4, 4) }
        static var queueRowPaddingH: CGFloat { pick(9, 10) }
        static var queueRowRadius: CGFloat { pick(8, 9) }
        static var queueText: Font { pick(Font.system(size: 12), .system(size: 12.5)) }
        static var queueNote: Font { pick(Font.system(size: 10.5), .system(size: 11)) }
        static var queueClose: CGFloat { pick(18, 20) }
        static var queueCloseGlyph: Font { pick(Font.system(size: 9, weight: .bold), .system(size: 9, weight: .bold)) }
    }

    /// The Native design (docs/island/NATIVE.md): the island stays black; what drops below it
    /// floats under the notch as a Liquid Glass panel in the Mac's appearance; the accent and the
    /// system's state colors, as the app (Prototypes/FoveaCaptures) and the onboarding draw them.
    /// Every value here is Original's where Original reads it, so Original doesn't move.
    enum Native {
        /// Between the island's foot and the panel's top, when the panels float. 0 in Original and
        /// with attached panels: their layouts are Original's.
        static var panelGap: CGFloat { floatsPanels ? 8 : 0 }
        /// The island's band over the Wings designs' tokens: the notch's height and a little more,
        /// so the token under the pointer keeps its mark (it sits 2 pt below the notch).
        static let bandExtra: CGFloat = 4
        /// The island's glass comes in over its first points of growth past the notch: at rest
        /// only the black notch shows, without a rim of glass around it.
        static let islandGlassRamp: CGFloat = 12
        /// The island's glass runs this far above what it hangs from, cut off there, so its rim
        /// never draws a top edge; and the cut leaves this much room around its other sides for
        /// the glass's own shadow.
        static let glassLift: CGFloat = 6
        static let glassShadowRoom: CGFloat = 24
        /// The panel's glass, before macOS 26: the system's material and a solid rim (no gradient,
        /// as the Island's rules ask), and a soft shadow.
        static let fallbackRimLight = Color.white.opacity(0.7)
        static let fallbackRimDark = Color.white.opacity(0.18)
        static let fallbackShadowLight = Color.black.opacity(0.12)
        static let fallbackShadowDark = Color.black.opacity(0.4)
        static let fallbackShadowRadius: CGFloat = 12
        static let fallbackShadowY: CGFloat = 4
        static let rimWidth: CGFloat = 0.75
        /// The panel's glass is tinted a little toward its appearance, so a panel full of words
        /// stays legible over a busy photo (HIG, Materials: legibility first).
        static let panelTintLight = Color.white.opacity(0.4)
        static let panelTintDark = Color.black.opacity(0.45)
        /// On the real Mac (Fovea 1.0, Oct 9): Liquid Glass only bends what its own window draws,
        /// and the island's window draws nothing under it, so the glass went flat gray. There the
        /// glass is the system's blur of what's behind the window (the desktop, the apps), a light
        /// tint toward the appearance over it, and the rim. Lighter than the Workbench's tints:
        /// the person wanted to see through it, the light glass above all.
        static let liveMaterialLight: NSVisualEffectView.Material = .popover
        static let liveMaterialDark: NSVisualEffectView.Material = .hudWindow
        static let liveTintLight = Color.white.opacity(0.18)
        static let liveTintDark = Color.black.opacity(0.22)
        static let liveRimLight = Color.white.opacity(0.55)
        static let liveRimDark = Color.white.opacity(0.14)
        /// Off screen, where glass has nothing behind it: a solid of its tone.
        static let offscreenLight = Color(white: 0.96, opacity: 0.94)
        static let offscreenDark = Color(white: 0.17, opacity: 0.94)
        // The states, in the system's colors (the app's warning and danger, done in green).
        static let needsYou = Color(nsColor: .systemOrange)
        static let failed = Color(nsColor: .systemRed)
        static let done = Color(nsColor: .systemGreen)
        /// The accent the person chose (Multicolor follows the Mac), and words on it.
        static var accent: Color { DesignStore.shared.accent.color }
        static let onAccent = Color.white
        /// A primary button under the pointer, and pressed: the accent a little lighter.
        static let accentHover: Double = 0.85
        static let accentPressed: Double = 0.7
        /// Chosen chips and rows: the accent behind them.
        static let accentWash: Double = 0.2
        /// Cards over a panel (the outline's card, the turn rail's, the fanned referents): the
        /// window's own background, opaque, as the app's popovers.
        static let card = Color(nsColor: .windowBackgroundColor)
    }
}

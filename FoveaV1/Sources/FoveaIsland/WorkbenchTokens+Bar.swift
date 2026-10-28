import SwiftUI

// Oct 26, Ryan: "the notch transition from the top menu bar to the notch is too abrupt and the color
// change is too abrupt… like the Voice OS Notch, there's a blue circle on the left, and when
// interacting with the Agent, there's a very small voice waveform bar on the right." The listening
// bar in four designs to compare with today's (BarDesigns.swift); every number they draw with. The
// reasons, and what each is after, are in docs/island/BAR_DESIGNS.md.

extension WorkbenchTokens {
    /// Oct 27, Ryan: "i want only the wing build, dont have the others." The listening bar, Wings: the
    /// menu bar's height, all black, sideways from the notch (Wings.swift, docs/island/BAR_DESIGNS.md).
    enum Bar {
        // The shape: its ears into the menu bar, its foot's corners.
        static let wingsEar: CGFloat = 10
        static let wingsBottom: CGFloat = 12
        /// From the wing's outer end to what's in it; between what's in a wing and the notch; the
        /// least a wing is with nothing in it.
        static let inset: CGFloat = 12
        static let notchPad: CGFloat = 9
        static let minSide: CGFloat = 26

        // The words: the system face, as a notice's title ("Mic access off"), white.
        static let wordSize: CGFloat = 12
        static let wordWeight: Font.Weight = .medium
        static let wordColor = Color.white.opacity(0.88)
        /// The website's ellipsis after Transcribing (components/book/film/film.css `.ell`): three
        /// dots, one lit at a time.
        static let dot: CGFloat = 2.4
        static let dotGap: CGFloat = 2
        static let dotLead: CGFloat = 2.5
        static let dotDim = 0.3
        static let dotStep: Double = 0.36
        static var dotsWidth: CGFloat { dotLead + 3 * dot + 2 * dotGap }
        /// The held words (nowhere to paste), quoted: at most this wide.
        static let quoteWidth: CGFloat = 110
        // A notice's line: the system face, as the website keeps the smallest things in it.
        static let noticeFont = Font.system(size: 12, weight: .medium)
        static let noticeSize: CGFloat = 12
        static let noticeGlyph: CGFloat = 12
        static let noticeGap: CGFloat = 6
        static let noticeColor = Color.white.opacity(0.88)

        // What's taken: 18 pt thumbnails, the two behind peeking out.
        static let thumb: CGFloat = 18
        static let thumbRadius: CGFloat = 4.5
        static let layerOffset: CGFloat = 3.5

        // Voiceflow's small waveform at the right: five bars (VoiceOS's four are 2.5 pt, 8–12 tall).
        static let bars = 5
        static let barWidth: CGFloat = 2.5
        static let barGap: CGFloat = 2
        static let barMin: CGFloat = 3
        static let barMax: CGFloat = 12
        static var span: CGFloat { CGFloat(bars) * barWidth + CGFloat(bars - 1) * barGap }
        static let barColor = Color.white.opacity(0.92)
        static let barSpread: Double = 0.6
        static let barBoost: Double = 1.35
        static let frameRate: Double = 40


        // Transcribing's ring at the right, white, filling clockwise from the top.
        static let ring: CGFloat = 14
        static let ringLine: CGFloat = 2
        static let ringTrack = Color.white.opacity(0.18)
        static let ringFill = Color.white.opacity(0.95)

        // A pill at the right: Undo, Copy, a notice's way on.
        static let pillFont = Font.system(size: 11.5, weight: .semibold)
        static let pillSize: CGFloat = 11.5
        static let pillHeight: CGFloat = 20
        static let pillPadding: CGFloat = 9
        static let pillFill = Color.white.opacity(0.16)
        static let pillHover = Color.white.opacity(0.26)
        static let pillText = Color.white.opacity(0.95)
        /// The time draining round a pill's side: Undo's, Copy's.
        static let drain: CGFloat = 13
        static let pillGap: CGFloat = 6

        // The last minute before the right side: its time.
        static let countdownFont = Font.system(size: 11.5, weight: .semibold).monospacedDigit()
        static let countdownWidth: CGFloat = 30
        static let countdownGap: CGFloat = 7
        static let countdownColor = Color.white.opacity(0.75)
        // The chosen chat's agent before the waveform, review off.
        static let route: CGFloat = 16
        static let routeGap: CGFloat = 7

        /// Under the notch, how much higher the bar's content starts (the stack's cards fly in).
        static let tuck: CGFloat = 6
    }

    /// Oct 28, Ryan, of another app's bar with a green light in its corner: "when doing
    /// dictation/dispatch. make an accent color a little aurora in the same fashion as the
    /// attachment on the bottom right of the notch like this." A small light inside the bar's
    /// bottom-right corner while it listens (Wings.swift's `WingsAurora`), drawn as blurred lights,
    /// not a gradient, as the Halo is.
    enum Aurora {
        /// Its room: this wide at the bar's right end (the body's, inside the ear), the bar's height.
        static let width: CGFloat = 64
        /// Three soft lights in the corner: each one's place from the corner (x to the left, y up),
        /// its radius and its share of the light.
        static let lights: [(x: CGFloat, y: CGFloat, radius: CGFloat, share: Double)] = [
            (12, 4, 15, 1), (28, 9, 11, 0.7), (7, 15, 9, 0.55),
        ]
        static let blur: CGFloat = 8
        static let strength = 0.85
        /// Quiet, this much of the strength shows; the voice brings up the rest, and grows the lights.
        static let quiet = 0.55
        static let rest: CGFloat = 0.85
        static let breath: CGFloat = 0.35
        /// How far each light wanders round its place, and how fast (radians a second).
        static let wander: CGFloat = 3
        static let pace = 0.7
        /// The bar's own edge lit along the corner, fading away from it.
        static let rimWidth: CGFloat = 2
        static let rimOpacity = 0.6
        static let rimReach: CGFloat = 16
        static let rimFade: CGFloat = 6
        static let frameRate: Double = 30
        static let fade: Double = 0.35
        /// Pictures: this far into the wander, at this voice.
        static let stillTime = 1.3
        static let stillLevel = 0.5
        /// A choice shown at the notch (the accent in the first run, Settings): the voice it breathes with.
        static let previewLevel = 0.45
        static let previewSwing = 0.25
        static let previewPace = 2.3
    }

    /// Oct 26, Ryan: a session popping up by itself when it needs you or is done, as Vibe Island's
    /// notch does (Feedback/V2Alert.swift): the board's row on the board's glass (Oct 27; it was
    /// the bar's black).
    enum Alert {
        /// The line over the row ("Claude Code needs you"), in the state's color.
        static let eyebrowHeight: CGFloat = 16
        static let eyebrowGap: CGFloat = 2
        static let eyebrowFont = Font.system(size: 11.5, weight: .semibold)
        static let doneColor = Color(nsColor: .systemGreen)
        /// How long it stays: done; needing you; once answered.
        static let doneHold: Double = 6
        static let needsYouHold: Double = 18
        static let answeredHold: Double = 1.2
    }

}

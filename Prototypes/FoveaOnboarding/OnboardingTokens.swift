import SwiftUI
import CoreText
import FoveaCore
import OnboardingCore

/// Every size, color, face, duration and sound level the onboarding draws or plays with, in one
/// place (AGENTS.md). The Island's numbers follow the Notch Workbench (WorkbenchTokens) so the
/// first run looks like the product it teaches; the guide is the window's ink on paper.
enum OT {
    // MARK: The mock display

    enum Display {
        /// A 13-inch MacBook, 1470×956 points, its 200×32 notch centered (Core's sample).
        static let metrics = ScreenMetrics.sampleNotched
        static var size: CGSize { metrics.frame.size }
        static var notchWidth: CGFloat { metrics.notchWidth ?? 200 }
        static var notchHeight: CGFloat { metrics.safeAreaTop }
        static var menuBarHeight: CGFloat { metrics.menuBarHeight }
        static let bezel: CGFloat = 12
        static let bezelRadius: CGFloat = 22
        static let screenRadius: CGFloat = 12
        static var lid: CGSize { CGSize(width: size.width + 2 * bezel, height: size.height + 2 * bezel) }
    }

    enum Layout {
        static let windowDefault = CGSize(width: 1380, height: 860)
        static let windowMin = CGSize(width: 980, height: 640)
        static let panelWidth: CGFloat = 310

        // The desktop
        static let menuBarSidePadding: CGFloat = 16
        static let menuBarItemSpacing: CGFloat = 20
        static let menuBarStatusSpacing: CGFloat = 14
        static let menuBarStatusIconSize: CGFloat = 14
        static let dockIconSize: CGFloat = 40
        static let dockPadding: CGFloat = 6
        static let dockSpacing: CGFloat = 8
        static let dockBottomInset: CGFloat = 8
        static let dockRadius: CGFloat = 16
        static let dockDividerHeight: CGFloat = 28
        static let filesTop: CGFloat = 26
        static let filesTrailing: CGFloat = 30
        static let fileIconSize: CGFloat = 54
        static let fileSpacing: CGFloat = 18

        // The practice window: the browser and its tabs, left of center, clear of the bar.
        static let practiceFrame = CGRect(x: 120, y: 88, width: 840, height: 566)
        /// The browser's row of tabs.
        static let tabBar: CGFloat = 34
        /// The team chat beside the browser, for the weekly update.
        static let chatFrame = CGRect(x: 990, y: 118, width: 320, height: 300)
        /// Dictation's two windows (Oct 9): Fovea's feedback, then Messages.
        static let feedbackFrame = CGRect(x: 150, y: 96, width: 560, height: 520)
        static let messagesFrame = CGRect(x: 750, y: 96, width: 540, height: 520)
        static let practiceRadius: CGFloat = 12
        static let practiceToolbar: CGFloat = 46
        static let pageWidth: CGFloat = 560
        static let pageLineSpacing: CGFloat = 4
        static let photoHeight: CGFloat = 250

        // System Settings, right of center while it is asked for, near the notch.
        static let settingsFrame = CGRect(x: 790, y: 112, width: 560, height: 420)
        static let settingsSidebar: CGFloat = 180
        static let alertWidth: CGFloat = 260

        // The board's glass bar: near the bottom, above the Dock.
        static let guideBottom: CGFloat = 84
        /// The whole keyboard, when a key is pressed on a step that teaches none: bottom right.
        static let keyboardBottom: CGFloat = 272
        static let guideTrailing: CGFloat = 28
        /// A file opened on the desktop.
        static let previewSize = CGSize(width: 300, height: 250)
        /// System Settings' drop zone at the foot of a list.
        static let dropZoneHeight: CGFloat = 46
        static let keyCapHeight: CGFloat = 30
        static let keyCapMinWidth: CGFloat = 30
        static let keyCapRadius: CGFloat = 7
        static let largeKeyCapHeight: CGFloat = 56
        static let largeKeyCapMinWidth: CGFloat = 56
        static let largeKeyCapRadius: CGFloat = 12

        // The ghost pointer
        static let pointerSize: CGFloat = 22
    }

    // MARK: The Island (after WorkbenchTokens.Island and docs/island/VOICE_BAR.md)

    enum Island {
        static let spec: IslandLayoutSpec = {
            var spec = IslandLayoutSpec()
            spec.voiceBelow = 44
            spec.expandedTopRadius = 19
            spec.expandedBottomRadius = 24
            return spec
        }()
        static let surface = Color.black
        static let restTopRadius: CGFloat = 6
        static let restBottomRadius: CGFloat = 14
        static let openTopRadius: CGFloat = 19
        static let openBottomRadius: CGFloat = 24

        /// A caption: the notch grows a line under itself.
        static let captionWidthMin: CGFloat = 300
        static let captionHeight: CGFloat = 30
        static let captionPadding: CGFloat = 22
        /// The voice bar: 44 pt below the notch (VOICE_BAR.md); wider than the notch for the stack.
        static let voiceWidth: CGFloat = 320
        static var voiceBelow: CGFloat { spec.voiceBelow }
        static let waveformBars = 9
        static let waveformBarWidth: CGFloat = 4
        static let waveformBarGap: CGFloat = 4
        static let waveformMinHeight: CGFloat = 16.0 / 3.0
        static let waveformMaxHeight: CGFloat = 20
        static let referentInset: CGFloat = 8
        static var referentHeight: CGFloat { spec.voiceBelow - 2 * referentInset }
        static let referentAspect: CGFloat = 1.43
        static let referentRadius: CGFloat = 6
        static let referentLayerOffset: CGFloat = 5
        static let referentRotation: [Double] = [0, 4, -3]

        /// The permissions' line under the notch, which is itself the tile to drag (Oct 9).
        static let dragCaptionHeight: CGFloat = 40
        static let dragIcon: CGFloat = 22
        static let dragIconGap: CGFloat = 8
        static let reviewWidth: CGFloat = 560
        static let signInWidth: CGFloat = 430
        static let boardWidth: CGFloat = 520
        static let sessionWidth: CGFloat = 560
        static let cardPadding: CGFloat = 18
        static let rowHeight: CGFloat = 44
        static let thumbSize = CGSize(width: 44, height: 32)
        static let thumbRadius: CGFloat = 6
        static let pillHeight: CGFloat = 28
        static let pillRadius: CGFloat = 9
        /// The hover: the pointer within this of the notch opens the board (Workbench: 14 pt).
        static let hoverReach: CGFloat = 14
    }

    // MARK: Colors

    enum Colors {
        /// Island neutrals: white at an opacity on black.
        static func white(_ opacity: Double) -> Color { Color.white.opacity(opacity) }
        static let islandText = Color.white.opacity(0.85)
        static let islandSecondary = Color.white.opacity(0.55)
        static let islandTertiary = Color.white.opacity(0.4)
        static let islandFill = Color.white.opacity(0.12)
        static let islandHairline = Color.white.opacity(0.1)

        /// The window's ink on paper (Sources/Fovea/Tokens.swift).
        static let ink = Color(.sRGB, red: 12 / 255, green: 12 / 255, blue: 12 / 255)
        static let canvas = Color(.sRGB, red: 251 / 255, green: 250 / 255, blue: 247 / 255)
        static func ink(_ opacity: Double) -> Color { ink.opacity(opacity) }

        /// Fovea's accent (macOS blue): the highlighter, the caret, the aura.
        static let accent = Color(.sRGB, red: 0.0, green: 0.48, blue: 1.0)

        /// Calm: the desktop dims a little behind a guide that wants the eye.
        static let dim = Color.black.opacity(0.22)
        static let bezel = Color(white: 0.06)
        static let stage = Color(white: 0.93)
        static let stageDark = Color(white: 0.12)

        // macOS's own surfaces, drawn as the system draws them.
        static let systemWindow = Color(nsColor: .windowBackgroundColor)
        static let systemText = Color(nsColor: .labelColor)
        static let systemSecondary = Color(nsColor: .secondaryLabelColor)
        static let systemBlue = Color(nsColor: .systemBlue)
        static let systemSeparator = Color(nsColor: .separatorColor)
        static let systemControl = Color(nsColor: .controlBackgroundColor)
        static let systemSidebar = Color(nsColor: .underPageBackgroundColor)
        static let toggleOn = Color(nsColor: .systemBlue)
        static let toggleOff = Color(white: 0.82)
        static let dockHairline = Color.white.opacity(0.25)
        /// The menu bar and the Dock in a picture of the screen, where there's nothing to blur.
        static let menuBarSolid = Color(white: 0.96).opacity(0.94)
        static let dockSolid = Color(white: 0.92).opacity(0.85)
        static let toolbarGlyph = Color(white: 0.45)
        static let trafficLights: [Color] = [Color(nsColor: .systemRed), Color(nsColor: .systemYellow), Color(nsColor: .systemGreen)]
        static let pageText = Color(white: 0.12)
        static let pageSecondary = Color(white: 0.45)
        static let messageBubble = Color(white: 0.91)
        static let messageMine = Color(nsColor: .systemBlue)
        static let messageMineText = Color.white
        static let messageText = Color.black

        /// The Island's solid white (the primary button, the send disc, the waveform, the running
        /// dot) and the black that sits on it.
        static let islandSolid = Color.white
        static let islandOnSolid = Color.black
        static let islandProgress = Color.white.opacity(0.9)
        static let referentFileBack = Color.white.opacity(0.14)
        static let referentFallback = Color.gray
        static let passagePaper = Color.white
        static let passagePaperDark = Color.black
        static let passageLine = Color.gray.opacity(0.55)

        // The guide
        static let guideShadow = Color.black.opacity(0.18)
        static let guideButtonText = Color.white
        static let keyCap = Color.white
        static let keyCapLitText = Color.white
        static let keyCapShadow = Color.black.opacity(0.08)
        static let swatchDot = Color.white
        /// The Multicolor swatch, as System Settings › Appearance draws it.
        static let multicolor: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red]
        static let auraChipBack = Color.black
        static let knobEdge = Color.white
        static let knobShadow = Color.black.opacity(0.3)

        // The stage
        static let flash = Color.black
        /// Clear, but still takes the pointer.
        static let hitLayer = Color.white.opacity(0.001)
        static let ghostArrow = Color.black
        static let ghostArrowEdge = Color.white
        static let fileLabel = Color.white
        static let fileLabelShadow = Color.black.opacity(0.5)
        static let wallpaperFallback = Color(white: 0.4)

        // The practice window: Safari and Messages, as the system draws them
        static let practiceWindow = Color.white
        static let practiceEdge = Color.black.opacity(0.12)
        static let practiceShadow = Color.black.opacity(0.25)
        static let addressField = Color(white: 0.94)
        static let toolbar = Color(white: 0.975)
        static let photoFallback = Color(white: 0.8)
        static let messagesGlyph = Color(white: 0.75)
        static let replyEdge = Color(white: 0.82)

        // System Settings and its alerts
        static let systemEdge = Color.black.opacity(0.15)
        static let systemShadow = Color.black.opacity(0.3)
        static let systemChosenText = Color.white
        static let alertEdge = Color.black.opacity(0.1)
        static let tileLifted = Color.white
        static let tileLiftedText = Color.black
        static let tileShadow = Color.black.opacity(0.3)

        // The whole keyboard (Oct 8)
        static let keyboardPlate = Color(.sRGB, red: 0.93, green: 0.93, blue: 0.92)
        static let keyboardPlateDark = Color(white: 0.09)
        static let keyboardKey = Color.white

        // The board (Oct 9: Stage only): the scrim and the glass
        static let stageScrim = Color.black.opacity(0.58)
        static let stageGlass = Color(white: 0.08).opacity(0.86)
        static let previewPaper = Color.white
        static let chatInitial = Color.white
    }

    enum Materials {
        static let menuBar: Material = .bar
        static let dock: Material = .ultraThinMaterial
        static let alert: Material = .regularMaterial
    }

    // MARK: Type: SF Pro on both surfaces

    enum Type_ {
        static let menuBar = Font.system(size: 13)
        static let menuBarApp = Font.system(size: 13, weight: .bold)
        static let caption = Font.system(size: 13, weight: .medium)
        static let islandTitle = Font.system(size: 13.5, weight: .semibold)
        static let islandBody = Font.system(size: 12.5)
        static let islandMeta = Font.system(size: 11.5)
        static let islandSection = Font.system(size: 11, weight: .semibold)
        static let guideEyebrow = Font.system(size: 11, weight: .semibold)
        static let guideTitle = Font.system(size: 22, weight: .semibold)
        static let guideBody = Font.system(size: 13.5)
        static let guideScript = Font.system(size: 16, weight: .regular)
        static let guideButton = Font.system(size: 13.5, weight: .semibold)
        static let keyCap = Font.system(size: 13, weight: .medium)
        static let largeKeyCap = Font.system(size: 20, weight: .medium)
        static let pageTitle = Font.system(size: 30, weight: .bold)
        static let pageBodySize: CGFloat = 15
        static let pageBody = Font.system(size: pageBodySize)
        static let pageMeta = Font.system(size: 12)
        static let systemTitle = Font.system(size: 13, weight: .semibold)
        static let systemBody = Font.system(size: 12)
        static let systemSmall = Font.system(size: 11)
        static let fileName = Font.system(size: 11, weight: .medium)
        static let panelTitle = Font.system(size: 12, weight: .semibold)
    }

    // MARK: Motion: the Island's own springs; the guide and the stage move slowly

    enum Motion {
        /// The voice bar: its smallest growth, quickest (WorkbenchTokens.Motion).
        static let barOpen: Animation = .interpolatingSpring(duration: 0.18, bounce: 0)
        static let barClose: Animation = .interpolatingSpring(duration: 0.15, bounce: 0)
        /// Larger surfaces: a card, the review, the board.
        static let open: Animation = .interpolatingSpring(duration: 0.3, bounce: 0)
        static let close: Animation = .interpolatingSpring(duration: 0.22, bounce: 0)
        /// Content a beat behind its shape: blur 4→0, scale 0.97→1.
        static let content: Animation = .timingCurve(0.23, 1, 0.32, 1, duration: 0.2)
        static let contentBlur: CGFloat = 4
        static let contentScale: CGFloat = 0.97
        /// Calm: the guide card, the dimming, the ghost pointer.
        static let calm: Animation = .easeInOut(duration: 0.6)
        static let slow: Animation = .easeInOut(duration: 0.9)
        /// Running, never a spinner: the dot breathes.
        static let breathe: Animation = .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
        static let pointer: Animation = .easeInOut(duration: 0.7)
        /// A key the step teaches breathes on the keyboard until it's pressed.
        static let keyPulse: Animation = .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
        /// The boards trade places between steps.
        static let board: Animation = .spring(duration: 0.45, bounce: 0)
        static let keyPress: Animation? = nil
        static let reduceMotion: Animation = .easeOut(duration: 0.12)
        /// The referent's flight into the stack.
        static let referentIn: Animation = .interpolatingSpring(duration: 0.45, bounce: 0)
        /// Reading pages (Oct 9): the page before rises away, and the next rises in a part at a
        /// time, from a little below, clearing a blur.
        static let pageOut: Animation = .easeIn(duration: 0.45)
        static let pageIn: Animation = .timingCurve(0.2, 0.9, 0.3, 1, duration: 0.7)
        static let pageInDelay: Double = 0.35
        static let stagger: Double = 0.1
        static let pageBlur: CGFloat = 6
        static let pageRise: CGFloat = 18
        /// The dark lifting off the desktop after Make it yours: slow (Oct 9: "too fast").
        static let stageLift: Animation = .easeInOut(duration: 1.6)
        /// The glass bar comes up once the dark has mostly gone.
        static let barIn: Animation = .easeOut(duration: 0.7).delay(0.7)
        /// The drop zone breathing in the accent.
        static let dropZone: Animation = .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
        static let caretBlink: Animation = .easeInOut(duration: 0.55).repeatForever(autoreverses: true)
        /// A highlighter mark appearing (WorkbenchTokens.Feedback.markFade).
        static let markFade: Animation = .easeOut(duration: 0.18)
    }

    // MARK: The whole keyboard (Oct 8), in key units

    enum Keyboard {
        static let unit: CGFloat = 26
        static let gap: CGFloat = 0.12
        static let shortRow: CGFloat = 0.62
        static let keyRadius: CGFloat = 0.16
        static let platePadding: CGFloat = 0.32
        static let plateRadius: CGFloat = 0.5
        static let labelSize: CGFloat = 0.36
        static let symbolSize: CGFloat = 0.42
        static let wordSize: CGFloat = 0.24
        /// The line above the keys.
        static let captionSize: CGFloat = 0.5
        /// Words under ⌃ ⌥ ⌘ only when keys are this big.
        static let wordsFrom: CGFloat = 24
        /// It stays up this long after the keys are let go.
        static let linger: Double = 1.4
        /// "×2" on a key pressed twice (Oct 9).
        static let badgeSize: CGFloat = 0.42
        static let badgeHeight: CGFloat = 0.6
    }

    // MARK: Typed out, letter by letter (Oct 9)

    enum Typing {
        static let pace = Typewriter.Pace(perSecond: 45, sentencePause: 0.3, clausePause: 0.1, longest: 2.2)
        /// A line held in the notch stays this long after it's typed.
        static let readAfter: Double = 1.6
    }

    // MARK: The drag, shown (Oct 9)

    enum DragHint {
        /// One glide, then a rest, then again.
        static let loop: Double = 3.4
        static let lifted: Double = 0.3
        static let glide: Double = 1.5
        static let fade: Double = 0.45
        /// How far below the notch the arc's control point sits.
        static let sag: CGFloat = 40
        static let pathOpacity: Double = 0.55
        static let ghostOpacity: Double = 0.9
    }

    // MARK: The blog, a real local site (Oct 9)

    enum Site {
        /// The page's size in the browser: the window less its toolbar and the line under it.
        static var size: CGSize {
            CGSize(width: Layout.practiceFrame.width, height: Layout.practiceFrame.height - Layout.practiceToolbar - Layout.tabBar - 1)
        }
        /// The web view's own window, out of sight.
        static let hiddenOrigin = CGPoint(x: -20000, y: -20000)
        static let snapshotTimeout: Double = 1.5
        /// How often the page looks for the agent's edits while it works.
        static let watchEvery: Double = 0.6
        /// Where the pictures taken go, in the practice folder.
        static let capturesFolder = ".captures"
    }

    // MARK: Dictation's stand-ins, for the play, the smoke run and a Mac without speech

    enum Dictation {
        static let sampleFeedback = "The keyboard made it clear what to press, and the tasks felt like real work. The permissions took me a moment."
        static let sampleReply = "Friday at three works for me."
        static let sampleWords = "favea → Fovea\nCodex\nHeyClicky\nClaude Code\nfovea"
        /// What Connect reads in the smoke run and the snapshots: never anyone's real words.
        static let sampleRows: [(word: String, replacement: String?)] = [
            (word: "favea", replacement: "Fovea"), (word: "Northwind", replacement: nil), (word: "HeyClicky", replacement: nil),
            (word: "Claude Code", replacement: nil), (word: "cloud code", replacement: "Claude Code"), (word: "Maya Chen", replacement: nil),
        ]
    }

    // MARK: The microphone test (Oct 8)

    enum Mic {
        /// The meter's range: −55 dB is silence, −10 dB is loud.
        static let floorDB: Double = -55
        static let rangeDB: Double = 45
        /// Above this, it's a voice.
        static let voiced: Double = 0.32
        /// This much voice passes the test.
        static let heardSeconds: Double = 0.8
        static let smoothing: Double = 0.6
        /// Space, held, talks for a Mac without a microphone.
        static let spaceTick: Double = 0.05
        static let spaceLevel: Double = 0.62
    }

    // MARK: The real send (Oct 8)

    enum Send {
        static let timeout: Double = 150
        /// The practice agent's weekly update, from the numbers in the three tabs.
        static let practiceUpdate = """
        # Weekly update · Oct 9

        **Growth.** 1,284 signups this week, up 18% on last week. Activation held at 41%, and 23 people churned, 4 fewer than last week.

        **Shipped.** Six pull requests merged: faster search on large libraries, a fix for the crash when closing a window, one-step permissions in onboarding, dark mode for Settings, retries for failed uploads, and updated dependencies.

        **Support.** 14 tickets open, 5 fewer than Monday; the oldest is 3 days old. Most are about signing in with SSO (6).
        """
        static let practiceUpdateReply = "Wrote this week's update to weekly-update.md: growth, what shipped, and support."
        /// The practice agent's pace, between its lines.
        static let practiceBeat: Double = 1.1
        static let practiceAdded = "- Insulated jacket\n- Warm gloves\n- Microspikes\n- Sunglasses\n"
        static let practiceReply = "Added an insulated jacket, warm gloves, microspikes and sunglasses for the snow."
        static let practiceSorted = "Packing list\n\nClothes\n- Insulated jacket\n- Warm gloves\n- Sunglasses\n\nGear\n- Tent\n- Sleeping bag\n- Headlamp\n- Stove\n- Microspikes\n"
        static let practiceSortedReply = "Sorted the list into Clothes and Gear."
    }

    // MARK: The board (Oct 9: Stage only)

    enum Board {
        static let stageTitle = Font.system(size: 40, weight: .semibold, design: .serif)
        static let stageBody = Font.system(size: 16)
        static let stageWidth: CGFloat = 660
        /// The space between a reading page's parts.
        static let readingGap: CGFloat = 22
        /// Make it yours: the gap and hairline between the accent and the light (Oct 9).
        static let sectionGap: CGFloat = 56
        static let personalizeWidth: CGFloat = 540
        static let importWidth: CGFloat = 600
        static let extrasWidth: CGFloat = 580
        static let languageField: CGFloat = 260
        /// The words shown to tick before the rest are counted.
        static let importShown = 12
        /// The glass bar, and its width with the keyboard at its right.
        static let stageBarWidth: CGFloat = 760
        static let barWideWidth: CGFloat = 1000
        static let stageBarRadius: CGFloat = 22
        static let barGap: CGFloat = 24
        static let barKeyUnit: CGFloat = 22
        static let instruction = Font.system(size: 15, weight: .medium)
        /// A doing step's one caption, and the line to say, set apart (Oct 9, round two).
        static let caption = Font.system(size: 16, weight: .semibold)
        static let script = Font.system(size: 18, weight: .medium, design: .serif)
        /// The end's two parts, spread out.
        static let closingGap: CGFloat = 34
    }

    // MARK: Marks and the pointer (round three of Oct 6 #3, #8; WorkbenchTokens.Feedback)

    enum Marks {
        /// The highlighter's strokes over words, multiplied into the page as ink is.
        static let opacity: Double = 0.38
        static let radius: CGFloat = 3
        /// The ring round a marked file.
        static let fileOpacity: Double = 0.28
        static let fileRadius: CGFloat = 8
        static let fileEdgeOpacity: Double = 0.9
        static let fileEdgeWidth: CGFloat = 1.5
        static let fileInset = CGSize(width: -6, height: -5)
        /// A screenshot's rectangle while it's dragged.
        static let selectionOpacity: Double = 0.12
        static let selectionEdgeOpacity: Double = 0.9
        static let selectionEdgeWidth: CGFloat = 1.5
        /// The screen's flash: a picture of it taken, or Fovea reopening.
        static let captureFlash: Double = 0.35
        static let reopenFlash: Double = 0.85
    }

    /// The highlighter's pointer: the system's arrow, filled with the accent (AccentArrow).
    enum Pointer {
        static let size = NSSize(width: 24, height: 24)
        static let tip = NSPoint(x: 5, y: 3)
        static let edge = NSColor.white
        static let edgeWidth: CGFloat = 2.6
        static let shadow = NSColor.black.withAlphaComponent(0.35)
        static let shadowBlur: CGFloat = 1.5
        static let shadowOffset = NSSize(width: 0, height: -0.5)
    }

    // MARK: The play: the whole run, played by itself (--play, or Play in the panel)

    enum Play {
        /// The pointer's move to a control, and its press.
        static let move: Double = 0.7
        static let press: Double = 0.14
        /// A drag, the pointer pressed, drawn at this many frames a second.
        static let drag: Double = 0.9
        static let dragFrames: Double = 30
        /// Reading the guide: this long a word, between these.
        static let readPerWord: Double = 0.22
        static let readMin: Double = 2.2
        static let readMax: Double = 5
        /// A key held before its action, and after; a tap, for a double press.
        static let keyHold: Double = 0.3
        static let tap: Double = 0.08
        /// Watching the drag shown before doing it; a reading page rising in.
        static let watchHint: Double = 3.6
        static let pageIn: Double = 1.0
        static let keyAfter: Double = 0.12
        /// Saying the line while the bar listens.
        static let speak: Double = 1.8
        /// Looking at a result before Continue.
        static let look: Double = 2.4
        /// Where the pointer first appears, as a fraction of the display.
        static let start = CGPoint(x: 0.62, y: 0.72)
        /// The accent and the light the play picks (the light it tries first, then keeps).
        static let accent = AccentName.purple
        static let auraTried = AuraPalette.sunset
        static let aura = AuraPalette.candy
    }

    // MARK: Timing (seconds; the smoke run scales them down)

    enum Timing {
        static let transcribing: Double = 1.4
        static let dictationTranscribing: Double = 0.8
        static let boardHold: Double = 3
        static let answerAfter: Double = 2.4
        static let answerHold: Double = 4.5
        static let followAnswerAfter: Double = 1.8
        static let captionHold: Double = 2.4
        static let ghostBeat: Double = 0.9
        static let reopenPause: Double = 1.2
        static let micTest: Double = 2.2
        static let skipAfterDefault: Double = 12
        /// A permission allowed: the step moves on by itself after this.
        static let autoAdvance: Double = 1.1
        /// The end: the notch rests after the last caption.
        static let restAfterFinish: Double = 4
        /// Done: Home opens (no closing animation, Oct 9), then the notch says where to start.
        static let homeOpen: Double = 0.5
        static let homeCaption: Double = 1.2
        /// The first list allowed: System Settings turns to the second.
        static let nextList: Double = 0.9
        /// Screen Recording switched on: macOS asks to reopen after this.
        static let reopenAlert: Double = 0.5
        /// The whole screen taken: the flash.
        static let flash: Double = 0.12
        /// A picture of the screen is drawn this long after it's taken.
        static let captureAfter: Double = 0.03
        static let tapLength: Double = 0.3
        /// Two taps of ⌘ within this are the whole screen (a little longer than the Workbench's
        /// 0.35 s, for a first try).
        static let doubleTapWindow: Double = 0.45
        static let hoverDwell: Double = 0.12
        static let hoverClose: Double = 0.1
    }

    // MARK: Sound: quiet, made on the fly, never louder than a page turning

    enum Sound {
        static let sampleRate: Double = 44_100
        /// The ambient bed: a soft open chord that breathes.
        static let padVolume: Float = 0.032
        static let padNotes: [Double] = [110.0, 164.81, 220.0, 329.63]
        static let padBreath: Double = 0.06
        static let padFadeIn: Double = 3.5
        static let padFadeOut: Double = 1.5
        /// The cues
        static let tickVolume: Float = 0.05
        static let tickPitch: Double = 1760
        static let tickLength: Double = 0.025
        static let captureVolume: Float = 0.06
        static let captureLength: Double = 0.07
        static let chimeVolume: Float = 0.07
        static let chimeNotes: [Double] = [659.25, 987.77]
        static let chimeNoteLength: Double = 0.42
        static let chimeGap: Double = 0.11
        static let allowVolume: Float = 0.06
        static let allowNotes: [Double] = [440.0, 659.25]
    }

    // MARK: Practice content

    enum Practice {
        static let photo = "Photos/mountain.jpg"
        /// The Home card's picture for a region (FoveaCaptures' `CaptureArt`).
        static let photoArt = "mountain-16x9"
        /// The chat the practice sends go to.
        static let chat = "Fovea practice"
        /// The team chat beside the browser: Maya asks for the weekly update.
        static let teamChat: [(name: String, time: String, text: String, color: Color)] = [
            ("Maya Chen", "9:41", "Morning, all. Can someone post this week's update before noon? Signups, what shipped, and support.",
             Color(.sRGB, red: 0.42, green: 0.36, blue: 0.86)),
            ("Jordan", "9:44", "I'm in interviews till two, sorry.", Color(.sRGB, red: 0.22, green: 0.62, blue: 0.52)),
        ]
        /// How much of a drag has to be on the part it's meant to take.
        static let partCover: CGFloat = 0.15
        /// The paragraph with the snow in it, for the packing list.
        static let snowParagraph = 0
    }
}

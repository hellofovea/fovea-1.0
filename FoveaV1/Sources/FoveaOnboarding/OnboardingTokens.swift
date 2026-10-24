import SwiftUI
import CoreText
import FoveaCore
import OnboardingCore
import FoveaKit

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
        /// A picture taken while dictating, where it lands (Oct 17, Ryan).
        static let takenInFeedback: CGFloat = 72
        static let takenInMessages: CGFloat = 110
        static let takenRadius: CGFloat = 8
        /// Its ✕ (Oct 18, Ryan), and the feedback box's least height while it's being changed.
        static let takenRemove: CGFloat = 16
        static let feedbackBoxMin: CGFloat = 60

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
        static let systemChosenText = Color.white
        static let alertEdge = Color.black.opacity(0.1)

        // The whole keyboard (Oct 8)
        static let keyboardPlate = Color(.sRGB, red: 0.93, green: 0.93, blue: 0.92)
        static let keyboardPlateDark = Color(white: 0.09)
        static let keyboardKey = Color.white

        // The board (Oct 9: Stage only): the scrim and the glass
        static let stageScrim = Color.black.opacity(0.58)
        /// Oct 21, Ryan ("simpler is better"): the bar is this one fill (it lay over a material).
        static let stageGlass = Color(white: 0.08).opacity(0.92)
        /// The same, on a light Mac (Oct 9: the pages follow the system, then the person's pick).
        static let stageScrimLight = Color.white.opacity(0.62)
        static let stageGlassLight = Color(white: 0.98).opacity(0.92)
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
        static let guideEyebrow = Font.system(size: 10.5, weight: .semibold)
        static let guideTitle = Font.system(size: 18, weight: .semibold)
        static let guideBody = Font.system(size: 12)
        static let guideScript = Font.system(size: 16, weight: .regular)
        static let guideButton = Font.system(size: 12, weight: .semibold)
        static let keyCap = Font.system(size: 13, weight: .medium)
        static let largeKeyCap = Font.system(size: 16, weight: .medium)
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

    // MARK: Motion (Oct 21, Ryan: the right animation for what it's doing)

    /// Every value the first run moves by, each with why (docs/motion/SPRINGS.md › First run). Ryan,
    /// Oct 21: "don't always use springs". Nothing in the first run is dragged, thrown or alive (the
    /// island it drives is the island's own), so it's all curves: the strong ease-out for what
    /// enters or leaves, the strong ease-in-out for what moves or changes size on screen, `ease`
    /// for a hover or a colour, linear for what keeps time. Nothing eases in, nothing grows from
    /// nothing, every change starts from where things are (so a second click mid-way re-aims it),
    /// and under Reduce Motion (Settings › Motion, or the Mac's) things only fade.
    enum Motion {
        // The curves

        /// Strong ease-out: answers at once, settles softly. For entering and leaving.
        static func easeOut(_ duration: Double) -> Animation { .timingCurve(0.23, 1, 0.32, 1, duration: duration) }
        /// Strong ease-in-out (cubic): for what's on screen already, moving or changing size.
        static func easeInOut(_ duration: Double) -> Animation { .timingCurve(0.645, 0.045, 0.355, 1, duration: duration) }
        /// CSS's `ease`: for a hover, or a colour.
        static func ease(_ duration: Double) -> Animation { .timingCurve(0.25, 0.1, 0.25, 1, duration: duration) }

        // Entering and leaving: strong ease-out, exits shorter

        /// A page fading in, whole (Oct 21, Ryan ("simpler is better"): its parts rose in one by
        /// one, blurred).
        static let pageIn = easeOut(0.25)
        /// The page before leaving: shorter, so the next isn't kept waiting.
        static let pageOut = easeOut(0.15)
        /// The glass bar fading in.
        static let barIn = easeOut(0.2)
        /// A part arriving within a page: a row or section opening, a chip, a file, a sent
        /// bubble, a dot.
        static let partIn = easeOut(0.22)
        /// A practice window opening, or a file opened as Quick Look would.
        static let windowIn = easeOut(0.25)
        /// Content fading in, or replacing what was there a beat behind its new size.
        static let content = easeOut(0.2)
        /// Anything leaving that isn't a page: quicker than it came.
        static let contentOut = easeOut(0.14)
        /// The progress line filling as the run goes on.
        static let progress = easeOut(0.3)
        /// A button held gives to 0.97, and comes back the same way.
        static let press = easeOut(0.14)

        // Moving or changing size on screen: strong ease-in-out

        /// The bar taking its new size between steps or as the keyboard joins; a page settling to
        /// its new height as a section opens; rows and chips making room.
        static let morph = easeInOut(0.3)
        /// A choice taken: a segment's pill sliding over, a switch, a swatch, a palette, a tick.
        /// Oct 23, Ryan ("the buttons feel a little slow"): quick and out at once, on the strong
        /// ease-out; on the ease-in-out's slow start (0.2 s) the button lagged the notch.
        static let select = easeOut(0.12)

        // A hover, a colour: ease

        /// The window under the pointer (dictation) lighting as the pointer comes to it.
        static let hover = ease(0.12)
        /// The board going light or dark, the accent on the line, the line to say brightening.
        static let recolor = ease(0.25)
        /// Make it yours: how long the board shows at the notch for a look just chosen, before the
        /// light picked comes back (Oct 23, Ryan).
        static let lookShown: Double = 3

        // Ambient and rare

        /// The desktop frosting behind a page's words (Oct 21, Ryan ("simpler is better"): it took
        /// 0.6 s).
        static let scrimIn = easeOut(0.3)
        /// The dark lifting off the desktop when the doing starts (Oct 9, Ryan: "too fast" at
        /// less). A reveal no one waits on: the bar fades in while it lifts.
        static let stageLift: Animation = .easeInOut(duration: 1.6)
        /// The desktop's practice files cleared at the end (0.8 s before Oct 21).
        static let filesClear = easeOut(0.3)
        /// The stage going at the end of the run, Home behind it (0.6 s before Oct 21).
        static let end = easeOut(0.3)

        // Keeping time: linear

        /// The microphone's level follows the voice as it is, nothing to lag behind.
        static let meter: Animation = .linear(duration: 0.08)

        /// Reduce Motion: nothing travels or grows; things only cross-fade, quickly.
        static let reduceMotion = easeOut(0.15)

        // How far, how late, how big

        /// A part opening in place (Customize's sliders, the primary language) starts this far
        /// above where it settles: never its whole height.
        static let partTravel: CGFloat = 6
        /// What replaces something in place comes in a beat behind its new size.
        static let contentBehind: Double = 0.06
        /// A dot or a badge this small (a file the agent changed, ×2 on a key, the microphone's
        /// tick) comes in from this size: from 0.97 it wouldn't show, from nothing it pops.
        static let dotFrom: CGFloat = 0.6
        /// Held: the button's size, or under Reduce Motion its strength instead.
        static let pressScale: CGFloat = 0.97
        // Oct 21 motion review: the same dim as the island's controls and the window's (0.75), on
        // the Reduce Motion fade; it was 0.7, at once.
        static let pressDim: Double = 0.75
        /// Disabled, as a plain button is drawn.
        static let disabled: Double = 0.5

        // Loops: ambient, ease-in-out; none under Reduce Motion (they hold still, lit)

        /// Running, never a spinner: the dot breathes.
        static let breathe: Animation = .easeInOut(duration: breatheSeconds).repeatForever(autoreverses: true)
        /// Oct 21, perf: each loop's one way, for the same loop on Core Animation (`BreathingLayer`).
        static let breatheSeconds: Double = 1.1
        /// The caret blinks, Reduce Motion or not, as the Mac's does.
        static let caretBlink: Animation = .easeInOut(duration: caretBlinkSeconds).repeatForever(autoreverses: true)
        static let caretBlinkSeconds: Double = 0.55

        // The island's, as state here: the real island draws and moves itself (FoveaIsland)

        static let barOpen: Animation = .interpolatingSpring(duration: 0.18, bounce: 0)
        static let open: Animation = .interpolatingSpring(duration: 0.3, bounce: 0)
        static let close: Animation = .interpolatingSpring(duration: 0.22, bounce: 0)
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
        /// Words under ⌃ ⌥ ⌘ only when keys are this big.
        static let wordsFrom: CGFloat = 24
        /// It stays up this long after the keys are let go.
        static let linger: Double = 1.4
        /// "×2" on a key pressed twice (Oct 9).
        static let badgeSize: CGFloat = 0.42
        static let badgeHeight: CGFloat = 0.6
    }

    // MARK: Read, not typed (Oct 21, Ryan ("simpler is better"): lines show whole; they were
    // typed out letter by letter, Oct 9)

    enum Reading {
        /// A hint on the bar stays this long, plus its reading time…
        static let base: Double = 1.4
        /// …about 20 letters a second; a Chinese character counts as two…
        static let perCharacter: Double = 0.05
        /// …and never longer than this.
        static let longest: Double = 6

        static func hold(for text: String) -> Double {
            let weight = text.unicodeScalars.reduce(0.0) { $0 + ($1.properties.isIdeographic ? 2 : 1) }
            return min(longest, base + weight * perCharacter)
        }
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
        // Oct 18, Ryan: the practice in the primary language.
        static var sampleFeedback: String { L("The keyboard made it clear what to press, and the tasks felt like real work. The permissions took me a moment.") }
        static var sampleReply: String { L("Friday at three works for me.") }
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
        /// The practice agent's weekly update, from the two parts taken (Oct 18, Ryan: two). Oct 18,
        /// Ryan: the practice agent writes and answers in the primary language.
        static var practiceUpdate: String {
            "# \(L("Weekly update · Oct 9"))\n\n"
                + "**\(L("Growth."))** \(L("1,284 signups this week, up \("18%") on last week. Activation held at \("41%"), and 23 people churned, 4 fewer than last week."))\n\n"
                + "**\(L("Shipped."))** \(L("Six pull requests merged: faster search on large libraries, a fix for the crash when closing a window, one-step permissions in onboarding, dark mode for Settings, retries for failed uploads, and updated dependencies."))\n"
        }
        static var practiceUpdateReply: String {
            L("Wrote this week's update to \(PracticeFiles.update), in two parts: growth, from this week's numbers; and what shipped, the six merged pull requests. Check the numbers before Maya posts it: they're from this morning.")
        }
        /// The practice agent's pace, between its lines.
        static let practiceBeat: Double = 1.1
        static var practiceAdded: String { [L("Insulated jacket"), L("Warm gloves"), L("Microspikes"), L("Sunglasses")].map { "- \($0)\n" }.joined() }
        static var practiceReply: String {
            L("Added an insulated jacket, warm gloves, microspikes and sunglasses to your packing list, for the fresh snow up top. The report says the light goes by four, so the headlamp you already had stays on it.")
        }
        static var practiceSorted: String {
            let clothes = [L("Insulated jacket"), L("Warm gloves"), L("Sunglasses")]
            let gear = [L("Tent"), L("Sleeping bag"), L("Headlamp"), L("Stove"), L("Microspikes")]
            return "\(L("Packing list"))\n\n\(L("Clothes"))\n" + clothes.map { "- \($0)\n" }.joined()
                + "\n\(L("Gear"))\n" + gear.map { "- \($0)\n" }.joined()
        }
        static var practiceSortedReply: String {
            L("Sorted the list into Clothes and Gear, each item kept as it was. The jacket, gloves and sunglasses are under Clothes; the tent, stove and microspikes under Gear.")
        }
        // More to try (Oct 23, Ryan): the practice agent's answers.
        static var practiceCompareReply: String {
            L("The two parts show this week's signups and the pull requests merged. Signups are up on last week; six pull requests went in.")
        }
        static var practiceRouteReply: String {
            L("For Saturday: the lower loop to the lake and back, about nine miles. The pass above it has fresh snow, so it stays off the plan.")
        }
        static var practiceRouteMoreReply: String {
            L("Noted. Start by eight to be back before the light goes at four.")
        }
        /// While it works: how often the held answer looks again, and the longest it's held.
        static let holdCheck: Double = 0.5
        static let holdLongest: Double = 90
    }

    // MARK: The board (Oct 9: Stage only)

    enum Board {
        // Oct 18: the serif is New York's, for Latin; in Chinese it fell back to Songti, its
        // full-width commas gaping ("你好， Ryan"), so Chinese titles take the system's own face.
        static var titleDesign: Font.Design { FoveaLocale.shared.language == .chinese ? .default : .serif }
        static var stageTitle: Font { Font.system(size: 30, weight: .semibold, design: titleDesign) }
        static let stageBody = Font.system(size: 13.5)
        static let stageWidth: CGFloat = 540
        /// The space between a reading page's parts.
        static let readingGap: CGFloat = 16
        /// Make it yours: the gap and hairline between the accent and the light (Oct 9).
        static let sectionGap: CGFloat = 26
        static let personalizeWidth: CGFloat = 440
        /// The lights' tiles a row: nine, the eight and Customize, in three rows (Oct 18, Ryan).
        static let auraColumns = 3
        static let importWidth: CGFloat = 520
        static let extrasWidth: CGFloat = 480
        static let languageField: CGFloat = 260
        /// The languages asked for under More…, as chips (Oct 17, Ryan, FR-06).
        static let languageChips: CGFloat = 420
        static let languageChipHeight: CGFloat = 24
        /// Dictation's intro: what works while talking, the keys in a column of this width.
        static let takeKeysWidth: CGFloat = 92
        static let takeListWidth: CGFloat = 460
        /// The words shown to tick before the rest are counted.
        static let importShown = 12
        /// The glass bar, and its width with the keyboard at its right. A size smaller on Oct 9,
        /// evening: on the real screen it read larger than a coding agent's words.
        static let stageBarWidth: CGFloat = 580
        static let barWideWidth: CGFloat = 760
        static let stageBarRadius: CGFloat = 16
        static let barGap: CGFloat = 14
        static let barKeyUnit: CGFloat = 15
        static let barPadding = CGSize(width: 16, height: 12)
        static let instruction = Font.system(size: 12.5, weight: .medium)
        /// A doing step's one caption, and the line to say, set apart (Oct 9, round two).
        static let caption = Font.system(size: 13, weight: .semibold)
        static var script: Font { Font.system(size: 14, weight: .medium, design: titleDesign) }
        /// The end's three parts, each with room around it.
        static let closingGap: CGFloat = 34
        /// How far the run is: a short thin line at the foot of every page, in the accent.
        static let progressWidth: CGFloat = 160
        static let progressHeight: CGFloat = 3
        static let progressBottom: CGFloat = 34
        /// Oct 23, Ryan: the part still to go, a gray that reads on any wallpaper, light or dark
        /// (the board's hairline went unseen on a bright one), so how far along shows.
        static let progressTrack = Color(white: 0.5).opacity(0.5)
        /// Oct 15 review, OB-01.7: Back, this far to the left of the progress line, and its height.
        static let backGap: CGFloat = 14
        static let backHeight: CGFloat = 24
        /// The room kept each side of the line for it, so the line stays centred.
        static let backSlot: CGFloat = 90
        /// The sign-up page's buttons and its box, one width (Oct 15 review, AC-01.1).
        static let accountWidth: CGFloat = 260
        static let accountHeight: CGFloat = 30
        static let accountGap: CGFloat = 8
        /// The breathing dot while Apple or Google has the person (never a spinner).
        static let waitingDot: CGFloat = 7
        /// What Fovea remembers' four points (Oct 15 review, OB-01.6).
        static let memoryWidth: CGFloat = 430
        static let memoryGap: CGFloat = 18
        static let memoryTitle = Font.system(size: 14, weight: .semibold)
        static let memoryDetail = Font.system(size: 13)
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
        /// A picture of the screen is drawn this long after it's taken.
        static let captureAfter: Double = 0.03
        static let tapLength: Double = 0.3
        /// Two taps of ⌘ within this are the whole screen (a little longer than the Workbench's
        /// 0.35 s, for a first try).
        static let doubleTapWindow: Double = 0.45
        static let hoverDwell: Double = 0.12
        static let hoverClose: Double = 0.1
        /// Oct 15 review, FR-03: Apple's or Google's own window, simulated (1.0 has no account
        /// server): signed in after this.
        static let signInAnswer: Double = 1.8
        /// AC-01.2: the email's link taken as opened after this, so the tour goes on.
        static let emailLinkOpened: Double = 6
        /// A review stage of "Check your email": the countdown as it's staged ("Resend in 0:24").
        static let stagedResendLeft = 24
        /// The countdown's tick: a second.
        static let resendTick: Double = 1
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
        /// One note each (Oct 9, late: two notes read as two sounds at once).
        static let chimeNotes: [Double] = [783.99]
        static let chimeNoteLength: Double = 0.42
        static let chimeGap: Double = 0.11
        static let allowVolume: Float = 0.06
        static let allowNotes: [Double] = [587.33]
    }

    // MARK: The Review menu's stages (Oct 15 review)

    enum Staging {
        /// The address "Check your email" is staged with: never anyone's own.
        static let email = "you@example.com"
    }

    // MARK: Practice content

    enum Practice {
        static let photo = "Photos/mountain.jpg"
        /// The Home card's picture for a region (FoveaCaptures' `CaptureArt`).
        static let photoArt = "mountain-16x9"
        /// The chat the practice sends go to.
        static var chat: String { L("Fovea practice") }
        /// The team chat beside the browser: Maya asks for the weekly update.
        static var teamChat: [(name: String, time: String, text: String, color: Color)] { [
            // Oct 18, Ryan: two parts, so the ask is for two.
            ("Maya Chen", "9:41", L("Morning, all. Can someone post this week's update before noon? Signups and what shipped."),
             Color(.sRGB, red: 0.42, green: 0.36, blue: 0.86)),
            ("Jordan", "9:44", L("I'm in interviews till two, sorry."), Color(.sRGB, red: 0.22, green: 0.62, blue: 0.52)),
        ] }
        /// How much of a drag has to be on the part it's meant to take.
        static let partCover: CGFloat = 0.15
        /// The paragraph with the snow in it, for the packing list.
        static let snowParagraph = 0
    }
}

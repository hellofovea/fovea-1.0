import SwiftUI
import AppKit
import FoveaCore
import FoveaLook
import OnboardingCore

/// The guide, in the one design kept (Oct 9: Stage). Reading steps darken the desktop and set the
/// words large, in serif, centered; doing steps lift the dark and keep a glass bar at the bottom,
/// like a subtitle, and the whole keyboard at its right.
struct BoardView: View {
    let model: OnboardingModel

    var body: some View {
        StageBoard(model: model)
            .frame(width: OT.Display.size.width, height: OT.Display.size.height, alignment: .topLeading)
            .opacity(model.finished ? 0 : 1)
            .allowsHitTesting(!model.finished)
    }
}

struct StageBoard: View {
    let model: OnboardingModel

    var body: some View {
        ZStack(alignment: .bottom) {
            if model.step.isReading {
                // Frosted: the desktop goes soft behind the words, dark or light
                // as the Mac is (then as the person picks). It lifts slowly (Oct 9); it comes in
                // ahead of the words (Oct 21, Ryan ("simpler is better"): quickly, `scrimIn`).
                Rectangle().fill(.ultraThinMaterial)
                    .overlay(model.boardDark ? OT.Colors.stageScrim : OT.Colors.stageScrimLight)
                    .frame(width: OT.Display.size.width, height: OT.Display.size.height)
                    .transition(model.options.harness ? .identity : .asymmetric(insertion: .opacity.animation(OT.Motion.scrimIn),
                                                                                removal: .opacity.animation(OT.Motion.stageLift)))
                // Oct 21, Ryan ("simpler is better"): pages cross-fade, the one before quicker.
                ReadingPage(model: model)
                    .id(model.step)
                    .transition(model.pageLeaving)
            } else {
                GlassBar(model: model)
                    .padding(.bottom, OT.Layout.guideBottom)
                    .frame(width: OT.Display.size.width, height: OT.Display.size.height, alignment: .bottom)
                    .transition(model.barTransition)
            }
        }
        // On every page: how far the run is, in the accent (Oct 10), and the way out. Back sits at
        // the progress line's left on the pages that have it (Oct 15 review, OB-01.7), so the line
        // stays where it was, centred.
        .overlay(alignment: .bottom) {
            // A slot each side of the line, the same width, so the line stays centred; the row as
            // tall as the line, so it stays where it was and Back stands out of it, centred on it.
            HStack(spacing: OT.Board.backGap) {
                ZStack(alignment: .trailing) {
                    if model.canGoBack {
                        BackButton(model: model, onPage: model.step.isReading)
                            .transition(model.fadeTransition)
                    }
                }
                .frame(width: OT.Board.backSlot, alignment: .trailing)
                TourProgress(model: model)
                Color.clear.frame(width: OT.Board.backSlot, height: OT.Board.progressHeight)
            }
            .frame(height: OT.Board.progressHeight)
            .animation(model.motion(OT.Motion.content), value: model.canGoBack)
            .padding(.bottom, OT.Board.progressBottom)
        }
        // The sound at the bottom left; Exit tour at the bottom right (Oct 10).
        .overlay(alignment: .bottomLeading) {
            MuteButton(model: model)
                .padding(.horizontal, 4)
                .background { if !model.step.isReading { Capsule().fill(.ultraThinMaterial) } }
                .playTarget(.mute, model)
                .padding(.leading, 20).padding(.bottom, 20)
        }
        .overlay(alignment: .bottomTrailing) {
            TourCorner(model: model, onPage: model.step.isReading)
                .padding(.trailing, 20).padding(.bottom, 20)
        }
        .environment(\.boardInk, BoardInk(dark: model.boardDark))
        .environment(\.colorScheme, model.boardDark ? .dark : .light)
        .environment(\.firstRunReduced, model.reduceMotion)
        .animation(model.motion(OT.Motion.recolor), value: model.boardDark)
        // Oct 21, Ryan: what a new step resizes or moves (the bar above all) on the strong
        // ease-in-out; it was an ease-in.
        .animation(model.motion(OT.Motion.morph), value: model.step)
    }
}

private extension OnboardingModel {
    /// Oct 21, Ryan ("simpler is better"): a page fades in whole and the page before fades out,
    /// quicker; nothing travels, blurs or comes in part by part.
    var pageLeaving: AnyTransition {
        if options.harness { return .identity }
        return .asymmetric(insertion: .opacity.animation(motion(OT.Motion.pageIn)),
                           removal: .opacity.animation(reduceMotion ? OT.Motion.reduceMotion : OT.Motion.pageOut))
    }

    /// The glass bar fades in and out (Oct 21, Ryan ("simpler is better"): it rose from below
    /// after a delay).
    var barTransition: AnyTransition {
        if options.harness { return .identity }
        return .asymmetric(insertion: .opacity.animation(motion(OT.Motion.barIn)),
                           removal: .opacity.animation(motion(OT.Motion.contentOut)))
    }
}

// MARK: - Reading: the words large

/// One reading step's page (Oct 9: hello to Make it yours wants a transition, not a cut).
struct ReadingPage: View {
    let model: OnboardingModel
    @Environment(\.boardInk) private var ink

    var body: some View {
        VStack(spacing: 0) {
            Text(model.copy.title)
                .font(OT.Board.stageTitle)
                .foregroundStyle(ink.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if !model.copy.body.isEmpty {
                Text(model.copy.body)
                    .font(OT.Board.stageBody)
                    .foregroundStyle(ink.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            BoardExtras(model: model)
                .frame(maxWidth: extrasWidth)
                .padding(.top, OT.Board.readingGap)
            BoardActions(model: model, centered: true, large: true)
                .padding(.top, OT.Board.readingGap + 6)
        }
        .frame(width: OT.Board.stageWidth)
        .frame(width: OT.Display.size.width, height: OT.Display.size.height)
    }

    private var extrasWidth: CGFloat {
        switch model.step {
        case .makeItYours: OT.Board.personalizeWidth
        case .dictionary: OT.Board.importWidth
        default: OT.Board.extrasWidth
        }
    }
}

// MARK: - Doing: the glass bar

/// The bar at the bottom while you do (Ryan liked it, Oct 9). One caption saying where you are,
/// then the instruction for now, then the line to say, set apart from the rest (Oct 9,
/// round two); the way past and the button; the whole keyboard at its right while keys are taught,
/// the keys for now lit in turn.
struct GlassBar: View {
    let model: OnboardingModel
    @Environment(\.boardInk) private var ink

    var body: some View {
        HStack(alignment: .top, spacing: OT.Board.barGap) {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.copy.title)
                    .font(OT.Board.caption)
                    .foregroundStyle(ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                BoardExtras(model: model)
                if let instruction = model.instruction {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle().fill(model.accentColor).frame(width: 7, height: 7).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                        Text(instruction)
                            .font(OT.Board.instruction)
                            .foregroundStyle(ink.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .id(instruction)
                            .transition(model.swapTransition)
                    }
                    // Oct 15 review, ST-03.1: the keys named are the person's own (KeyMap(prefs:)).
                }
                BoardScript(model: model)
                BoardActions(model: model)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Oct 21, Ryan: a new step's words replace the last at once (they sat on each other as
            // both faded) and come in a beat behind the bar's new size.
            .id(model.step)
            .transition(model.swapTransition)
            if model.keyboardWanted {
                KeyboardView(pressed: model.keysDown, targets: model.keyboardTargets, accent: model.accentColor, dark: model.boardDark,
                             unit: OT.Board.barKeyUnit, badges: model.keyboardBadges)
                    .allowsHitTesting(false)
                    .transition(model.fadeTransition)
            }
        }
        .padding(.horizontal, OT.Board.barPadding.width)
        .padding(.vertical, OT.Board.barPadding.height)
        .frame(width: model.keyboardWanted ? OT.Board.barWideWidth : OT.Board.stageBarWidth)
        .background(RoundedRectangle(cornerRadius: OT.Board.stageBarRadius, style: .continuous)
            .fill(model.boardDark ? OT.Colors.stageGlass : OT.Colors.stageGlassLight))
        .overlay(RoundedRectangle(cornerRadius: OT.Board.stageBarRadius, style: .continuous).strokeBorder(ink.hairline))
        .playTarget(.board, model)
        .animation(model.motion(OT.Motion.morph), value: model.keyboardWanted)
    }
}

// MARK: Every page: how far, and the way out (Oct 10)

/// How far the run is: a short thin line at the foot of the screen, filled in the accent (so the
/// accent shows here as it's picked, the notch staying up), with no numbers.
struct TourProgress: View {
    let model: OnboardingModel
    @Environment(\.boardInk) private var ink

    var body: some View {
        let B = OT.Board.self
        Capsule()
            .fill(ink.hairline)
            .frame(width: B.progressWidth, height: B.progressHeight)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(model.accentColor)
                    .frame(width: max(B.progressHeight, B.progressWidth * model.progress), height: B.progressHeight)
            }
            .animation(model.motion(OT.Motion.progress), value: model.progress)
            .animation(model.motion(OT.Motion.recolor), value: model.flow.personal.accent)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel("Tour progress")
            .accessibilityValue(Text("\(Int(model.progress * 100)) percent"))
    }
}

/// Oct 15 review, OB-01.7 and FR-05: a quiet Back beside the progress line. It goes to the page
/// before as it was left: what was entered stays. ⌘[ does the same (KeyRig). Off a page to read, it
/// sits on glass of its own, as Exit tour does. Oct 17, Ryan: on every step after the first, the
/// practice tasks and the end included; a practice task gone back to starts over, cleanly.
struct BackButton: View {
    let model: OnboardingModel
    let onPage: Bool
    @Environment(\.boardInk) private var ink

    var body: some View {
        Button(action: { model.goBack() }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left").font(.system(size: 9.5, weight: .semibold))
                Text(Copy.back).font(.system(size: 11.5, weight: .medium))
            }
            .foregroundStyle(ink.secondary)
            .padding(.horizontal, 8).frame(height: OT.Board.backHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.press)
        .help("Back to the page before (⌘[)")
        .padding(.horizontal, 4)
        .background { if !onPage { Capsule().fill(.ultraThinMaterial) } }
        .fixedSize()
        .playTarget(.back, model)
    }
}

/// Exit tour, in the bottom right of every page (Oct 10). It puts the tour away at once, keeping
/// the place: Home opens, and the tour picks up from there. Off a page to read, it sits on glass of
/// its own, over whatever the desktop shows. In a practice run again from Home (Oct 15 review,
/// OB-03.1) it's Exit practice: Home again, nothing about the first run changed.
struct TourCorner: View {
    let model: OnboardingModel
    let onPage: Bool
    @Environment(\.boardInk) private var ink

    var body: some View {
        let practising = model.practiceRun != nil
        HStack(spacing: 6) {
            Button(action: { model.exitTour() }) {
                Text(practising ? Copy.exitPractice : Copy.exitTour)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(ink.secondary)
                    .padding(.horizontal, 8).frame(height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.press)
            .help(practising ? "Back to Home. The rest of the tour stays as it is."
                  : "Put the tour away. Pick it up from Home whenever you like.")
        }
        .padding(.horizontal, 4)
        .background {
            if !onPage { Capsule().fill(.ultraThinMaterial) }
        }
        .playTarget(.corner, model)
    }
}

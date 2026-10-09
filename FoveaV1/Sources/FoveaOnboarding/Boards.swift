import SwiftUI
import AppKit
import FoveaCore
import OnboardingCore

/// The guide, in the one design kept (Oct 9: Stage). Reading steps darken the desktop and set the
/// words large, in serif, centered, rising in a part at a time; doing steps lift the dark and keep
/// a glass bar at the bottom, like a subtitle, its instruction typed out and the whole keyboard at
/// its right.
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

    /// Snapshots and Reduce Motion: every change at once.
    private var still: Bool { model.options.harness || model.reduceMotion }

    var body: some View {
        ZStack(alignment: .bottom) {
            if model.step.isReading {
                // Frosted and dark, as VoiceOS does it: the desktop goes soft behind the words. It
                // comes in at a calm pace and lifts slowly (Oct 9).
                Rectangle().fill(.ultraThinMaterial)
                    .overlay(OT.Colors.stageScrim)
                    .frame(width: OT.Display.size.width, height: OT.Display.size.height)
                    .transition(still ? .identity : .asymmetric(insertion: .opacity.animation(OT.Motion.slow),
                                                                removal: .opacity.animation(OT.Motion.stageLift)))
                ReadingPage(model: model)
                    .id(model.step)
                    .transition(still ? .identity : .asymmetric(insertion: .identity,
                                                                removal: .opacity.combined(with: .offset(y: -OT.Motion.pageRise)).animation(OT.Motion.pageOut)))
            } else {
                GlassBar(model: model)
                    .padding(.bottom, OT.Layout.guideBottom)
                    .frame(width: OT.Display.size.width, height: OT.Display.size.height, alignment: .bottom)
                    .transition(still ? .identity : .asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)).animation(OT.Motion.barIn),
                                                                removal: .opacity.animation(OT.Motion.content)))
            }
        }
        .environment(\.boardInk, BoardInk(dark: true))
        .environment(\.colorScheme, .dark)
        .animation(still ? nil : OT.Motion.pageOut, value: model.step)
    }
}

// MARK: - Reading: the words large, rising in a part at a time

/// One reading step's page. Each part rises in after the one before (Oct 9: hello to Make it yours
/// wants a transition, not a cut), while the page before rises away.
struct ReadingPage: View {
    let model: OnboardingModel

    var body: some View {
        VStack(spacing: 0) {
            Rises(order: 0, model: model) {
                Text(model.copy.title)
                    .font(OT.Board.stageTitle)
                    .foregroundStyle(OT.Colors.white(0.96))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !model.copy.body.isEmpty {
                Rises(order: 1, model: model) {
                    Text(model.copy.body)
                        .font(OT.Board.stageBody)
                        .foregroundStyle(OT.Colors.white(0.62))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 10)
            }
            Rises(order: 2, model: model) {
                BoardExtras(model: model)
                    .frame(maxWidth: extrasWidth)
            }
            .padding(.top, OT.Board.readingGap)
            Rises(order: 3, model: model) {
                BoardActions(model: model, centered: true, large: true)
            }
            .padding(.top, OT.Board.readingGap + 6)
        }
        .frame(width: OT.Board.stageWidth)
        .frame(width: OT.Display.size.width, height: OT.Display.size.height)
        .overlay(alignment: .bottomLeading) {
            MuteButton(model: model).padding(24)
        }
    }

    private var extrasWidth: CGFloat {
        switch model.step {
        case .makeItYours: OT.Board.personalizeWidth
        case .dictionary: OT.Board.importWidth
        default: OT.Board.extrasWidth
        }
    }
}

/// A part of a reading page, rising into place a beat after the part before it.
struct Rises<Content: View>: View {
    let order: Int
    let model: OnboardingModel
    @ViewBuilder let content: Content
    @State private var shown = false

    var body: some View {
        let still = model.options.harness || model.reduceMotion
        content
            .opacity(shown || still ? 1 : 0)
            .blur(radius: shown || still ? 0 : OT.Motion.pageBlur)
            .offset(y: shown || still ? 0 : OT.Motion.pageRise)
            .onAppear {
                guard !still else { return }
                withAnimation(OT.Motion.pageIn.delay(OT.Motion.pageInDelay + Double(order) * OT.Motion.stagger)) { shown = true }
            }
    }
}

// MARK: - Doing: the glass bar

/// The bar at the bottom while you do (Ryan liked it, Oct 9). One caption saying where you are,
/// then the instruction for now typed out, then the line to say, set apart from the rest (Oct 9,
/// round two); the way past and the button; the whole keyboard at its right while keys are taught,
/// the keys for now lit in turn.
struct GlassBar: View {
    let model: OnboardingModel

    var body: some View {
        HStack(alignment: .top, spacing: OT.Board.barGap) {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.copy.title)
                    .font(OT.Board.caption)
                    .foregroundStyle(OT.Colors.white(0.95))
                    .fixedSize(horizontal: false, vertical: true)
                    .id(model.step)
                    .transition(.opacity)
                BoardExtras(model: model)
                if let instruction = model.instruction {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle().fill(model.accentColor).frame(width: 7, height: 7).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                        TypedText(text: instruction, font: OT.Board.instruction, color: OT.Colors.white(0.94), typing: model.typesLines)
                            .id(instruction)
                    }
                }
                BoardScript(model: model)
                BoardActions(model: model)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if model.keyboardWanted {
                KeyboardView(pressed: model.keysDown, targets: model.keyboardTargets, accent: model.accentColor, dark: true,
                             unit: OT.Board.barKeyUnit, badges: model.keyboardBadges)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .frame(width: model.keyboardWanted ? OT.Board.barWideWidth : OT.Board.stageBarWidth)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: OT.Board.stageBarRadius, style: .continuous))
        .background(RoundedRectangle(cornerRadius: OT.Board.stageBarRadius, style: .continuous).fill(OT.Colors.stageGlass))
        .overlay(RoundedRectangle(cornerRadius: OT.Board.stageBarRadius, style: .continuous).strokeBorder(OT.Colors.white(0.1)))
        .animation(OT.Motion.board, value: model.keyboardWanted)
    }
}

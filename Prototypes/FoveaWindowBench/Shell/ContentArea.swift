import SwiftUI
import WindowBenchCore

/// Under the toolbar: the breadcrumb, then one of onboarding, the section's levels, or search
/// results. Both sections' levels stay mounted, so each keeps its place and scroll.
struct ContentArea: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let onboarding = model.state.section == .project ? model.state.onboarding : nil
        let inPlace = model.search.presented && model.v(SearchResultsStyle.self) == .inPlace
        VStack(spacing: 0) {
            if showsCrumbs(onboarding) {
                // Comes in with the list after onboarding's panel has gone, not before.
                BreadcrumbBar(inSearch: inPlace)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(model.motion.animation(.content)
                            .delay(model.motion.seconds(BenchTokens.MotionValues.contentDuration * 0.6))),
                        removal: .opacity.animation(model.motion.animation(.content))))
            }
            ZStack {
                let leaving = model.sectionLeaving
                let projectShown = model.state.section == .project && onboarding == nil && !inPlace && !leaving
                let captureShown = model.state.section == .capture && !inPlace && !leaving
                // Each section's page fades on the content curve, out at once and in just after
                // (a section switch, a jump, results opening or closing over it): never both read
                // at once, never a blank beat. Under Reduce Motion, and in a Go to, a cut.
                LevelStack(section: .project)
                    .opacity(projectShown ? 1 : 0)
                    .animation(sectionFade(projectShown), value: projectShown)
                    .allowsHitTesting(model.state.section == .project && onboarding == nil && !inPlace)
                LevelStack(section: .capture)
                    .opacity(captureShown ? 1 : 0)
                    .animation(sectionFade(captureShown), value: captureShown)
                    .allowsHitTesting(model.state.section == .capture && !inPlace)
                if let onboarding {
                    OnboardingView(step: onboarding)
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity.animation(model.motion.reduce ? nil : model.motion.animation(.content))))
                }
                if inPlace {
                    // In just after the page under it has gone; out at once before the page is
                    // back. Under Reduce Motion, a cut both ways.
                    SearchResultsView(dropdown: false, query: model.search.query)
                        .background(PageFill())
                        .transition(model.motion.reduce ? .identity : .asymmetric(
                            insertion: .opacity.animation(sectionFade(true)),
                            removal: .opacity.animation(sectionFade(false))))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .onChange(of: onboarding, initial: true) { _, now in model.drawnOnboarding = now }
        .onChange(of: inPlace, initial: true) { _, now in model.drawnSearchResults = now }
        .overlay(alignment: .topTrailing) {
            if model.search.presented && model.v(SearchResultsStyle.self) == .dropdown {
                SearchResultsView(dropdown: true, query: model.search.query)
                    .padding(.top, 6)
                    .padding(.trailing, 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .topTrailing)))
            }
        }
    }

    /// Out: the content curve at once. In: the same, once the other has nearly gone.
    private func sectionFade(_ appearing: Bool) -> Animation? {
        let motion = model.motion
        if motion.reduce { return nil }
        return appearing ? motion.animation(.content).delay(motion.seconds(BenchTokens.MotionValues.contentDuration * 0.6))
                         : motion.animation(.content)
    }

    private func showsCrumbs(_ step: OnboardingStep?) -> Bool {
        switch step {
        case .consent?, .scanning?, .nothingFound?: return false
        default: return true
        }
    }
}

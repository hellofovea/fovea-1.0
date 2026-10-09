import SwiftUI
import WindowBenchCore

/// Every animation in the bench comes from here, so the panel's motion system, speed and
/// simulated Reduce Motion reach all of it: SwiftUI animations, stagger waits and the
/// time-driven drawing (the Lasso, the breath).
struct MotionSpec: Equatable {
    var system: MotionSystem = .notch
    /// 1 is real time; 0.25 plays four times slower.
    var speed: Double = 1
    var reduce: Bool = false
    var arrival: WaitingArrival = .bounce

    enum Role {
        /// A surface opening (a level, a fold, a popover) and closing.
        case open, close, expand, collapse
        /// Something swapping in place (a tab, a name).
        case swap
        /// Content arriving after its container: the notch's short ease-out.
        case content
        case hover, select
        /// The ghost carrying a row into a page, or the notch's card into the window.
        case flight
        /// A long fade: the jump highlight leaving.
        case fade
    }

    private typealias V = BenchTokens.MotionValues

    func animation(_ role: Role) -> Animation {
        if reduce {
            switch role {
            case .hover: return .easeOut(duration: V.hover).speed(speed)
            case .fade: return .easeOut(duration: V.highlightIn).speed(speed)
            default: return .easeOut(duration: V.reduced).speed(speed)
            }
        }
        let base: Animation
        switch system {
        case .notch:
            switch role {
            case .open: base = .interpolatingSpring(duration: V.open, bounce: 0)
            case .close: base = .interpolatingSpring(duration: V.close, bounce: 0)
            case .expand: base = .interpolatingSpring(duration: V.expand, bounce: 0)
            case .collapse: base = .interpolatingSpring(duration: V.collapse, bounce: 0)
            case .swap: base = .interpolatingSpring(duration: V.swap, bounce: 0)
            case .content:
                let c = V.contentCurve
                base = .timingCurve(c.0, c.1, c.2, c.3, duration: V.contentDuration)
            case .hover: base = .easeOut(duration: V.hover)
            case .select: base = .easeOut(duration: V.select)
            case .flight: base = .interpolatingSpring(duration: V.flight, bounce: 0)
            case .fade: base = .easeOut(duration: V.highlightIn * 2)
            }
        case .v1:
            switch role {
            case .open, .close, .expand, .collapse, .flight, .content: base = .smooth(duration: V.v1Transition)
            case .swap, .select: base = .smooth(duration: V.v1Selection)
            case .hover: base = .easeOut(duration: V.hover)
            case .fade: base = .easeInOut(duration: V.highlightIn * 2)
            }
        case .notes:
            switch role {
            case .open: base = .interpolatingSpring(duration: V.notesOpen.0, bounce: V.notesOpen.1)
            case .close, .collapse: base = .interpolatingSpring(duration: V.notesClose.0, bounce: V.notesClose.1)
            case .expand, .flight: base = .interpolatingSpring(duration: V.notesConvert.0, bounce: V.notesConvert.1)
            case .swap, .hover: base = .interpolatingSpring(duration: V.notesHover.0, bounce: V.notesHover.1)
            case .content: base = .easeOut(duration: V.notesContent)
            case .select: base = .easeOut(duration: V.select)
            case .fade: base = .easeOut(duration: V.highlightIn * 2)
            }
        }
        return base.speed(speed)
    }

    /// How long content waits behind its container.
    var contentDelay: Double { reduce ? 0 : seconds(system == .notes ? 0.05 : V.contentDelay) }

    /// The glyph arriving in Needs you: the only bounce the window allows.
    var arrivalAnimation: Animation {
        if reduce { return .easeOut(duration: V.reduced).speed(speed) }
        switch arrival {
        case .bounce:
            return .interpolatingSpring(duration: V.bounce.0, bounce: V.bounce.1).speed(speed)
        case .overshoot:
            let o = V.overshoot
            return Animation(CappedOvershoot(x1: o.x1, y1: o.y1, x2: o.x2, y2: o.y2, duration: o.duration, cap: o.cap)).speed(speed)
        case .none:
            return animation(.open)
        }
    }

    /// Wall-clock seconds for a duration at this speed.
    func seconds(_ s: Double) -> Double { s / max(speed, 0.01) }

    func sleep(_ s: Double) async {
        try? await Task.sleep(for: .milliseconds(Int(seconds(s) * 1000)))
    }

    /// Time for drawing that moves on its own clock (the Lasso, the breath), slowed with the rest.
    func clock(_ date: Date) -> Double { date.timeIntervalSinceReferenceDate * speed }
}

/// Copied from Prototypes/FoveaWorkbench/MockDesktop/ReferentStack.swift (may drift):
/// transitions.dev's card-stack curve with the overshoot capped in points. Not interruptible
/// the way a spring is; the panel says so.
struct CappedOvershoot: CustomAnimation {
    let x1: Double, y1: Double, x2: Double, y2: Double
    let duration: TimeInterval
    let cap: Double

    func animate<V: VectorArithmetic>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        guard time < duration else { return nil }
        return value.scaled(by: progress(for: sqrt(value.magnitudeSquared), at: time / duration))
    }

    func progress(for distance: Double, at x: Double) -> Double {
        let p = Self.curve(x, x1, y1, x2, y2)
        guard p > 1, distance > 0 else { return p }
        let over = (p - 1) * distance
        let limited = over / pow(1 + pow(over / cap, 4), 0.25)
        return 1 + limited / distance
    }

    static func curve(_ x: Double, _ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        func bezier(_ t: Double, _ a: Double, _ b: Double) -> Double {
            let u = 1 - t
            return 3 * u * u * t * a + 3 * u * t * t * b + t * t * t
        }
        var lo = 0.0, hi = 1.0, t = x
        for _ in 0..<24 {
            let xt = bezier(t, x1, x2)
            if abs(xt - x) < 1e-6 { break }
            if xt < x { lo = t } else { hi = t }
            t = (lo + hi) / 2
        }
        return bezier(t, y1, y2)
    }
}

private struct MotionKey: EnvironmentKey {
    static let defaultValue = MotionSpec()
}

extension EnvironmentValues {
    var motion: MotionSpec {
        get { self[MotionKey.self] }
        set { self[MotionKey.self] = newValue }
    }
}

/// The notch's content transition as an animatable modifier: opacity, a 4 pt blur and a 0.97
/// scale from the top, one modifier both ways so the exit is the entrance backwards.
struct ContentReveal: ViewModifier, Animatable {
    @Environment(\.motion) private var motion
    var progress: CGFloat
    var anchor: UnitPoint = .top

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let V = BenchTokens.MotionValues.self
        // Reduce Motion keeps the fade and drops the blur and the scale.
        let travel = motion.reduce ? 0 : 1 - progress
        content
            .opacity(progress)
            .blur(radius: travel * V.contentBlur)
            .scaleEffect(1 - (1 - V.contentScale) * travel, anchor: anchor)
    }
}

extension View {
    func contentReveal(_ progress: CGFloat, anchor: UnitPoint = .top) -> some View {
        modifier(ContentReveal(progress: progress, anchor: anchor))
    }
}

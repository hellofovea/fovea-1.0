import SwiftUI
import AppKit
import FoveaCore

/// Where a surface sits: on the notch (depths are screen depths), or the detached card.
enum IslandMaterialHost: Equatable {
    case attached(notchHeight: CGFloat)
    case detached(notchHeight: CGFloat, dockZone: DockZone)

    var notchHeight: CGFloat {
        switch self {
        case .attached(let h), .detached(let h, _): return h
        }
    }
}

/// The surface under the island's content, for the material picked in the study (A–E).
/// Bottom to top: a behind-window blur (C, D, E), a black floor over the whole shape, and a
/// black ramp: pinned to the top of the screen for D, a share of the height for C. Reduce
/// Transparency and offscreen renders get the solid surface. The caller clips it to the
/// island's shape; that clip reaches the blur too.
struct IslandMaterialBackground: View {
    let material: IslandMaterial
    let host: IslandMaterialHost

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.snapshotMode) private var snapshotMode

    private typealias M = Tokens.Island.Material

    var body: some View {
        if material.isTranslucent && !reduceTransparency && !snapshotMode {
            ZStack {
                BehindWindowBlur()
                Color.black.opacity(floor)
                ramp
            }
        } else {
            solid
        }
    }

    private var solid: Color {
        if case .detached = host { return Tokens.Island.Colors.surfaceElevated }
        return Tokens.Island.Colors.surface
    }

    private var floor: Double {
        switch material {
        case .black, .keyline: return 1
        case .proportionalFade: return M.fadeFloor
        case .graded: return M.gradedFloor
        case .glass: return M.glassFloor
        }
    }

    @ViewBuilder private var ramp: some View {
        switch material {
        case .graded:
            let ramp = IslandMaterialRamp(floor: M.gradedFloor, solidDepth: host.notchHeight + M.gradedHold,
                                          fade: M.gradedFade)
            // An overlay on a clear fill, so a ramp taller than the island never sizes it.
            Color.clear.overlay(alignment: .top) {
                LinearGradient(stops: ramp.rampStops().map { .init(color: .black.opacity($0.opacity), location: $0.location) },
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: ramp.height)
                    .opacity(rampOpacity)
                    .foveaAnimation(.hover, value: rampOpacity, fadeOnly: true)
            }
        case .proportionalFade:
            LinearGradient(stops: [.init(color: .black, location: 0),
                                   .init(color: .black, location: M.fadeSolidFraction),
                                   .init(color: .clear, location: 1)],
                           startPoint: .top, endPoint: .bottom)
        case .black, .keyline, .glass:
            EmptyView()
        }
    }

    /// Attached: the ramp is the notch band. Detached: it returns as the card nears the dock,
    /// so the material itself says the card is about to become part of the notch again.
    private var rampOpacity: Double {
        switch host {
        case .attached: return 1
        case .detached(_, let zone):
            switch zone {
            case .outside: return 0
            case .near: return M.gradedDockNear
            case .ready: return 1
            }
        }
    }
}

/// Keyline (B, D, E) and bright rim (C, E) for the picked material, drawn inside `shape`.
/// Attached, the keyline fades in below the notch band so it never outlines the hardware.
struct IslandMaterialEdge<S: Shape>: View {
    let material: IslandMaterial
    let shape: S
    let host: IslandMaterialHost

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private typealias M = Tokens.Island.Material

    var body: some View {
        ZStack {
            if let keyline {
                line(keyline).mask(alignment: .top) { keylineMask }
            }
            if let rim {
                line(rim).mask {
                    LinearGradient(stops: [.init(color: .clear, location: M.rimStartFraction), .init(color: .black, location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var keyline: Color? {
        switch material {
        case .keyline, .graded, .glass: return contrast == .increased ? M.keylineIncreasedContrast : M.keyline
        case .black, .proportionalFade: return nil
        }
    }

    /// The rim is a glass highlight; with no glass it goes too.
    private var rim: Color? {
        guard !reduceTransparency else { return nil }
        switch material {
        case .proportionalFade: return M.fadeRim
        case .glass: return M.glassRim
        case .black, .keyline, .graded: return nil
        }
    }

    private func line(_ color: Color) -> some View {
        shape.stroke(color, lineWidth: M.edgeStroke).clipShape(shape)
    }

    @ViewBuilder private var keylineMask: some View {
        switch host {
        case .attached(let notchHeight):
            VStack(spacing: 0) {
                Color.clear.frame(height: notchHeight)
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: M.keylineFadeIn)
                Color.black
            }
        case .detached:
            Color.black
        }
    }
}

/// A behind-window blur. The caller's `clipShape` trims it to the island's outline; an
/// NSVisualEffectView `maskImage` must not be used here, because inside SwiftUI's hosting it
/// renders upside down and inset from the sides.
struct BehindWindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = Tokens.Island.Material.blur
        view.blendingMode = .behindWindow
        // The island lives in a non-activating panel that is rarely key; a blur that
        // followed the window's active state would draw flat.
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// Names the material for a moment after it changes, just under the island. Prototype
/// chrome for comparing the study's options; it takes no clicks.
struct MaterialAnnouncement: View {
    let material: IslandMaterial

    private typealias M = Tokens.Island.Material

    var body: some View {
        HStack(spacing: Tokens.Space.s) {
            Text(material.letter)
                .font(Tokens.Island.Type_.status)
                .foregroundStyle(Tokens.Island.Colors.textSecondary)
            Text(material.title)
                .font(Tokens.Island.Type_.pill)
                .foregroundStyle(Tokens.Island.Colors.textPrimary)
            Text("⌃⌥⌘1–5")
                .font(Tokens.Island.Type_.secondary)
                .foregroundStyle(Tokens.Island.Colors.textTertiary)
        }
        .padding(.horizontal, M.announcementPaddingH)
        .frame(height: M.announcementHeight)
        .background(Capsule().fill(M.announcementFill))
        .overlay(Capsule().strokeBorder(Tokens.Island.Colors.hairline, lineWidth: 1))
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Island material \(material.letter), \(material.title)")
    }
}

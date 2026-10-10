import SwiftUI
import AppKit

// Copied from Prototypes/FoveaCaptures/Glass.swift (`GlassSurface`, `.glass`, `\.liquidGlass`);
// may drift. Changed here: the fallback's rim is one solid color, not a gradient (the Island's
// rules), and its colors are Workbench tokens.

extension EnvironmentValues {
    /// Whether surfaces use Liquid Glass where the system has it. Off for drawings made off screen
    /// (`ImageRenderer`), where glass has nothing behind it to take its color from.
    @Entry var liquidGlass = true
    /// The real Mac's glass: the system's blur of what's behind the window, not Liquid Glass,
    /// which bends only what its own window draws (the island's draws nothing under it).
    @Entry var behindWindowGlass = false
    /// The mock display's color scheme, set where the display sets it (MockScreen), so a panel can
    /// take it back inside the island, which is dark (docs/island/NATIVE.md).
    @Entry var displayScheme: ColorScheme = .dark
}

/// A surface's glass: Liquid Glass on macOS 26 and later; before, the system's material with a
/// solid rim and a soft shadow. `tint` colors the glass; `interactive` lets it answer the pointer.
struct GlassSurface<S: Shape>: ViewModifier {
    @Environment(\.liquidGlass) private var liquid
    @Environment(\.behindWindowGlass) private var behindWindow
    @Environment(\.colorScheme) private var scheme
    let shape: S
    var tint: Color?
    var interactive = false

    func body(content: Content) -> some View {
        let N = WorkbenchTokens.Native.self
        if behindWindow, liquid {
            let dark = scheme == .dark
            content
                .background {
                    ZStack {
                        BehindWindowBlur(material: dark ? N.liveMaterialDark : N.liveMaterialLight, dark: dark)
                        Rectangle().fill(dark ? N.liveTintDark : N.liveTintLight)
                    }
                    .clipShape(shape)
                    .overlay(shape.stroke(dark ? N.liveRimDark : N.liveRimLight, lineWidth: N.rimWidth))
                }
        } else if liquid, #available(macOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background {
                    ZStack {
                        if !liquid {
                            // Glass turned off (drawings made off screen, where a material has
                            // nothing to blur): a solid of the glass's tone.
                            shape.fill(scheme == .dark ? N.offscreenDark : N.offscreenLight)
                        } else {
                            shape.fill(.regularMaterial)
                            if let tint { shape.fill(tint) }
                        }
                        shape.stroke(scheme == .dark ? N.fallbackRimDark : N.fallbackRimLight, lineWidth: N.rimWidth)
                    }
                    .shadow(color: scheme == .dark ? N.fallbackShadowDark : N.fallbackShadowLight,
                            radius: N.fallbackShadowRadius, y: N.fallbackShadowY)
                }
        }
    }

    @available(macOS 26.0, *)
    private var glass: Glass {
        var g = Glass.regular
        if let tint { g = g.tint(tint) }
        if interactive { g = g.interactive() }
        return g
    }
}

/// The system's blur of what's behind the window, for the real Mac's glass. The caller's
/// `clipShape` trims it to the shape (an NSVisualEffectView `maskImage` renders upside down and
/// inset inside SwiftUI's hosting: Sources/Fovea/Island/IslandMaterialView.swift). Always active:
/// the island's panel is rarely key, and a blur that followed the window's state would go flat.
struct BehindWindowBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let dark: Bool

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        update(view)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) { update(view) }

    private func update(_ view: NSVisualEffectView) {
        if view.material != material { view.material = material }
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        if view.appearance?.name != appearance?.name { view.appearance = appearance }
    }
}

extension View {
    func glass<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassSurface(shape: shape, tint: tint, interactive: interactive))
    }

    /// A panel's color scheme: in Native, the mock display's (light or dark glass, as the Mac is);
    /// in Original, dark, as every panel has always been drawn. `onBlack`: what sits straight on
    /// the black band beside the notch while an app is full screen, dark in either design.
    func panelScheme(onBlack: Bool = false) -> some View {
        modifier(PanelScheme(onBlack: onBlack))
    }
}

struct PanelScheme: ViewModifier {
    var onBlack = false
    @Environment(\.displayScheme) private var display

    func body(content: Content) -> some View {
        content.environment(\.colorScheme, WorkbenchTokens.isNative && !onBlack ? display : .dark)
    }
}

extension View {
    /// A surface of its own (the pulled-out window, its docked tab, a capsule): its fill in
    /// Original; Liquid Glass in its shape in Native.
    @ViewBuilder
    func surface<S: Shape>(_ shape: S, original: Color, interactive: Bool = false) -> some View {
        if WorkbenchTokens.isNative {
            glass(shape, interactive: interactive)
        } else {
            background(shape.fill(original))
        }
    }
}

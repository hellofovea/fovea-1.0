import AppKit
import SwiftUI
import FoveaKit

/// What the window and its controls are made of. Aside's look, and macOS's own: the window is a
/// translucent material the desktop shows through, the content sits on an opaque page inset in
/// it, and the controls that float over the page are glass. On macOS 26 and later the glass is
/// Liquid Glass; before, the vibrant materials that came before it.

/// The window's own material, behind everything.
enum WindowMaterialStyle: String, CaseIterable {
    /// What a sidebar is made of: vibrant, the desktop's color comes through it (Aside's library).
    case vibrant
    /// Liquid Glass (macOS 26 and later; the vibrant material before).
    case glass
    /// No translucency: the system's under-page color.
    case solid

    var title: String {
        switch self {
        case .vibrant: return "Vibrant (sidebar material)"
        case .glass: return "Liquid Glass"
        case .solid: return "Solid"
        }
    }
}

/// Behind the whole window: the material its sidebar is made of, blended with what's behind the
/// window, and following whether the window is active.
struct WindowMaterial: NSViewRepresentable {
    var style: WindowMaterialStyle

    func makeNSView(context: Context) -> NSView {
        let host = NSView()
        install(in: host)
        return host
    }

    func updateNSView(_ host: NSView, context: Context) {
        if (host.subviews.first?.identifier?.rawValue ?? "") != style.rawValue { install(in: host) }
    }

    private func install(in host: NSView) {
        host.subviews.forEach { $0.removeFromSuperview() }
        let view: NSView
        switch style {
        case .glass:
            if #available(macOS 26.0, *) {
                let glass = NSGlassEffectView()
                glass.cornerRadius = 0
                view = glass
            } else {
                view = Self.vibrant()
            }
        case .vibrant:
            view = Self.vibrant()
        case .solid:
            let v = NSView()
            v.wantsLayer = true
            v.layer?.backgroundColor = NSColor.underPageBackgroundColor.cgColor
            view = v
        }
        view.identifier = NSUserInterfaceItemIdentifier(style.rawValue)
        view.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            view.topAnchor.constraint(equalTo: host.topAnchor),
            view.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
    }

    /// The snapshots are taken with the window in the background: draw the material as an
    /// active window's, as people see it.
    static var alwaysActive = false

    private static func vibrant() -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .sidebar
        v.blendingMode = .behindWindow
        v.state = alwaysActive ? .active : .followsWindowActiveState
        return v
    }
}

private struct LiquidGlassKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
    /// Whether controls use Liquid Glass where the system has it (a comparison shot turns it off to
    /// show what macOS 14 and 15 draw instead).
    var liquidGlass: Bool {
        get { self[LiquidGlassKey.self] }
        set { self[LiquidGlassKey.self] = newValue }
    }
}

/// A surface Aside's way (`T.Shade`): its fill, a 0.5 pt edge just inside it (the ink at 8 %),
/// and one soft shadow. Oct 21, Ryan ("simpler is better"): one shadow, not a tight one under a
/// wide one, and no rim of light along the top in dark.
struct Shading<S: InsettableShape>: ViewModifier {
    @Environment(\.palette) private var palette
    let shape: S
    var level: T.Shade.Level
    var fill: Color?

    func body(content: Content) -> some View {
        let (contact, wide) = T.Shade.layers(level, dark: palette.isDark)
        let shadow = wide.opacity > 0 ? wide : contact
        content
            .background(shape.fill(fill ?? palette.card).shadow(color: .black.opacity(shadow.opacity), radius: shadow.radius, y: shadow.y))
            .overlay(shape.strokeBorder(palette.edge, lineWidth: 0.5))
    }
}

extension View {
    func shading<S: InsettableShape>(_ shape: S, _ level: T.Shade.Level = .resting, fill: Color? = nil) -> some View {
        modifier(Shading(shape: shape, level: level, fill: fill))
    }
}

/// A control's glass: Liquid Glass on macOS 26 and later, a vibrant material with a light rim
/// before. `tint` colors the glass (the Island's black); `interactive` lets it respond to the
/// pointer as system glass buttons do.
struct GlassSurface<S: InsettableShape>: ViewModifier {
    @Environment(\.liquidGlass) private var liquid
    @Environment(\.colorScheme) private var scheme
    let shape: S
    var tint: Color?
    var interactive = false

    func body(content: Content) -> some View {
        if liquid, #available(macOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background {
                    ZStack {
                        if let tint {
                            shape.fill(tint)
                        } else {
                            shape.fill(.regularMaterial)
                        }
                        // The rim light a glass edge catches.
                        shape.strokeBorder(
                            LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.22 : 0.7), .white.opacity(0.04)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 0.75)
                    }
                    .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.1), radius: 6, y: 2)
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

extension View {
    func glass<S: InsettableShape>(_ shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassSurface(shape: shape, tint: tint, interactive: interactive))
    }
}

/// A round glass button with a symbol, as Aside's settings gear and the system's glass buttons:
/// 32 pt, the symbol in the label's color, the glass responding to the pointer.
struct RoundGlassButton: View {
    let symbol: String
    let help: String
    var size: CGFloat = 32
    var tint: Color?
    var foreground: Color?
    let action: () -> Void
    @State private var hover = false
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(foreground ?? (hover ? palette.text : palette.secondary))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glass(Circle(), tint: tint, interactive: true)
        .onHover { hover = $0 }
        // Oct 18, Ryan: in the primary language (a literal help is looked up as it's drawn).
        .help(L(key: help))
        .accessibilityLabel(L(key: help))
    }
}

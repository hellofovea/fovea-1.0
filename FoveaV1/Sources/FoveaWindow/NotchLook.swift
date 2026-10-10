import SwiftUI
import FoveaKit
import FoveaLook
import CapturesCore

// The notch's look, in Settings (Oct 9): the notch is Liquid Glass, light or dark, its panels
// attached to the top edge or floating under it, at Compact or Spacious, in the accent. Settings ›
// Notch shows the choice on a picture of the top of the screen, and the real notch shows it a
// moment as it's made. (Home's switcher stays as Fovea Captures draws it: Oct 9, "keep the
// original design".)

/// The notch's look as the person chose it, read from Settings' prefs.
struct NotchLook: Equatable {
    var appearance: NotchAppearance
    var panels: NativePanels
    var density: NotchDensity
    var accent: Color

    var scheme: ColorScheme { appearance.colorScheme }
    /// Words on the glass: ink on light, white on dark (NATIVE.md, round two).
    func ink(_ opacity: Double) -> Color { (appearance == .dark ? Color.white : Color.black).opacity(opacity) }
}

extension CapturesModel {
    var notchLook: NotchLook {
        NotchLook(appearance: prefs.notchAppearance, panels: prefs.panels, density: prefs.density,
                  accent: accent.color ?? Color(nsColor: .controlAccentColor))
    }
}

/// Liquid Glass in the notch's appearance (the system's material before macOS 26), in a shape.
struct NotchGlass<S: Shape>: View {
    let shape: S
    let look: NotchLook

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                Color.clear.glassEffect(.regular, in: shape)
            } else {
                shape.fill(.regularMaterial)
                    .overlay(shape.stroke(look.ink(0.12), lineWidth: 0.5))
            }
        }
        .environment(\.colorScheme, look.scheme)
    }
}

/// The top of a MacBook's screen, and the notch as chosen: its glass, a panel under it attached
/// or floating, Compact or Spacious, a primary button in the accent.
struct NotchLookPreview: View {
    let look: NotchLook

    var body: some View {
        let screen = RoundedRectangle(cornerRadius: 10, style: .continuous)
        Color.clear
            .overlay { PreviewWallpaper() }
            .overlay(alignment: .top) { PreviewMenuBar() }
            .overlay(alignment: .top) { PanelFigure(look: look) }
            .clipShape(screen)
            .overlay(screen.strokeBorder(.black.opacity(0.12), lineWidth: 0.5))
            .accessibilityElement()
            .accessibilityLabel("Your notch: \(look.appearance.title) glass, panels \(look.panels.title.lowercased()), \(look.density.title)")
    }
}

/// The notch with a board under it, a small sample: two rows, a question and a result.
private struct PanelFigure: View {
    let look: NotchLook

    var body: some View {
        let G = NotchPreviewGeometry.self
        let spacious = look.density == .spacious
        let width: CGFloat = spacious ? 300 : 260
        let rowHeight: CGFloat = spacious ? 34 : 28
        let rows = VStack(alignment: .leading, spacing: spacious ? 8 : 4) {
            row(title: "Notch ears match the menu bar", line: "Run swift test", button: true, height: rowHeight)
            row(title: "Snapshot tests", line: "Both pass on CI now", button: false, height: rowHeight)
        }
        .padding(.horizontal, spacious ? 14 : 10)
        .padding(.vertical, spacious ? 12 : 8)
        let panelHeight = 2 * rowHeight + (spacious ? 8 : 4) + (spacious ? 24 : 16)
        ZStack(alignment: .top) {
            if look.panels == .attached {
                // One glass shape with the island, hanging from the top edge with its ears.
                NotchGlass(shape: IslandShape(topRadius: G.topRadius, bottomRadius: spacious ? 22 : 18), look: look)
                    .frame(width: width, height: G.notch.height + panelHeight)
                rows.frame(width: width, alignment: .leading).padding(.top, G.notch.height)
            } else {
                // A glass panel under the notch, a gap between, as Control Center hangs.
                NotchGlass(shape: RoundedRectangle(cornerRadius: spacious ? 22 : 18, style: .continuous), look: look)
                    .frame(width: width, height: panelHeight)
                    .padding(.top, G.notch.height + 8)
                rows.frame(width: width, alignment: .leading).padding(.top, G.notch.height + 8)
            }
            // The notch itself stays black.
            UnevenRoundedRectangle(bottomLeadingRadius: 8, bottomTrailingRadius: 8)
                .fill(.black)
                .frame(width: G.notch.width, height: G.notch.height)
        }
        .environment(\.colorScheme, look.scheme)
    }

    private func row(title: String, line: String, button: Bool, height: CGFloat) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Color(red: 0.85, green: 0.47, blue: 0.34)).frame(width: 20, height: 20)
                .overlay(alignment: .bottomTrailing) {
                    Circle().fill(button ? Color(nsColor: .systemOrange) : Color(nsColor: .systemGreen))
                        .frame(width: 8, height: 8)
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(look.ink(0.92)).lineLimit(1)
                Text(line).font(.system(size: 10)).foregroundStyle(look.ink(0.55)).lineLimit(1)
            }
            Spacer(minLength: 4)
            if button {
                Text("Run Tests").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 8).frame(height: 20)
                    .background(Capsule().fill(look.accent))
            } else {
                Text("10m").font(.system(size: 10)).foregroundStyle(look.ink(0.45))
            }
        }
        .frame(height: height)
    }
}

/// The menu bar round the notch, as a notched MacBook draws it over the wallpaper.
struct PreviewMenuBar: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "apple.logo").font(.system(size: 13, weight: .medium))
            Text("Finder").font(.system(size: 13, weight: .bold))
            Text("File")
            Text("Edit")
            Spacer(minLength: NotchPreviewGeometry.bar.width + 16)
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Text("9:41")
        }
        .font(.system(size: 13))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 2, y: 0.5)
        .padding(.horizontal, 14)
        .frame(height: NotchPreviewGeometry.notch.height)
        .background(LinearGradient(colors: [.black.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom))
        .accessibilityHidden(true)
    }
}

/// The preview's wallpaper, filling whatever it's given.
struct PreviewWallpaper: View {
    var body: some View {
        if let wallpaper = Art.resource("Photos/coast.jpg") {
            Image(nsImage: wallpaper).resizable().aspectRatio(contentMode: .fill)
        }
    }
}

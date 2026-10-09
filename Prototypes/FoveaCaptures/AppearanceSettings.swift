import AppKit
import SwiftUI
import CapturesCore

/// Settings › Appearance, laid out as System Settings' Appearance pane is, and only what Ryan
/// asked to keep: Light, Dark or Auto as pictures of a window, and the accent from the Mac's own
/// set (Multicolor follows the Mac's). Every choice is a preset: there's no color well. (The
/// themes and the card size, offered here for a day, are gone again.)
struct AppearancePane: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var model = model

        SettingsSection(nil) {
            SettingsCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Appearance").font(.system(size: 13)).foregroundStyle(palette.text)
                    PictureChoices(options: [Appearance.light, .dark, .system], selection: $model.appearance,
                                   title: \.choiceTitle, pictureHeight: 58) { look, _ in
                        WindowThumb(look: look)
                    }
                    .frame(maxWidth: 380, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardPadding()
                RowDivider()
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accent color").font(.system(size: 13)).foregroundStyle(palette.text)
                        Text("What's chosen, what you took, and the words you pointed with.")
                            .font(.system(size: 11)).foregroundStyle(palette.secondary)
                    }
                    AccentDots(selection: $model.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardPadding()
            }
        }
    }
}

extension Appearance {
    /// As System Settings names them: Auto follows the Mac.
    var choiceTitle: String { self == .system ? "Auto" : title }
}

/// A window in miniature: Light, Dark, or Auto (light and dark split across it, as macOS draws
/// its own).
private struct WindowThumb: View {
    let look: Appearance

    var body: some View {
        ZStack {
            Color(white: 0.55)
            switch look {
            case .light: window(dark: false)
            case .dark: window(dark: true)
            case .system:
                ZStack {
                    window(dark: false)
                    window(dark: true).mask(Diagonal())
                }
            }
        }
    }

    private func window(dark: Bool) -> some View {
        let frame = dark ? Color(white: 0.17) : Color(white: 0.98)
        let side = dark ? Color(white: 0.24) : Color(white: 0.9)
        let line = dark ? Color(white: 0.4) : Color(white: 0.78)
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2.5) {
                    Circle().fill(Color(nsColor: .systemRed)).frame(width: 4, height: 4)
                    Circle().fill(Color(nsColor: .systemYellow)).frame(width: 4, height: 4)
                    Circle().fill(Color(nsColor: .systemGreen)).frame(width: 4, height: 4)
                }
                ForEach(0..<3, id: \.self) { _ in Capsule().fill(line).frame(width: 18, height: 3) }
            }
            .padding(6)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(side)
            VStack(alignment: .leading, spacing: 4) {
                Capsule().fill(line).frame(width: 34, height: 4)
                Capsule().fill(line.opacity(0.7)).frame(width: 46, height: 3)
                Capsule().fill(line.opacity(0.7)).frame(width: 40, height: 3)
            }
            .padding(7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(frame)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .padding(.top, 9)
        .padding(.leading, 12)
    }
}

/// The lower-right triangle of a rectangle: where Auto's dark half goes.
private struct Diagonal: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// The accent colors as the Mac shows them: a row of dots, Multicolor first, the chosen one with
/// a white ring inside it; its name under the row.
private struct AccentDots: View {
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion
    @Binding var selection: AccentChoice

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ForEach(AccentChoice.allCases, id: \.self) { choice in
                    let on = choice == selection
                    Button { withAnimation(motion.animation(.swap)) { selection = choice } } label: {
                        ZStack {
                            if let color = choice.color {
                                Circle().fill(color)
                            } else {
                                Circle().fill(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink, .red], center: .center))
                            }
                            Circle().strokeBorder(.black.opacity(0.12), lineWidth: 0.5)
                            if on { Circle().strokeBorder(.white, lineWidth: 2.5).padding(1) }
                        }
                        .frame(width: 20, height: 20)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(choice.title)
                    .accessibilityLabel(choice.title)
                    .accessibilityAddTraits(on ? [.isSelected] : [])
                }
            }
            Text(selection == .multicolor ? "Multicolor: follows your Mac" : selection.title)
                .font(.system(size: 11)).foregroundStyle(palette.secondary)
        }
    }
}

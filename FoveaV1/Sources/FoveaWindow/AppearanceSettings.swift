import AppKit
import SwiftUI
import CapturesCore
import FoveaKit
import FoveaLook

/// Settings › Appearance, laid out as System Settings' Appearance pane is, and only what Ryan
/// asked to keep: Light, Dark or Auto as pictures of a window, and the accent from the Mac's own
/// set (Multicolor follows the Mac's). Every choice is a preset: there's no color well. (The
/// themes and the card size, offered here for a day, are gone again.) Oct 15 review, IS02: Motion,
/// as the Mac's Reduce Motion says, or always reduced, or always full; the window follows it now,
/// and the notch reads the same pref.
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
                    if WindowLook.isAligned {
                        AlignedSwatches(selection: $model.accent)
                    } else {
                        AccentDots(selection: $model.accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardPadding()
                RowDivider()
                SettingsRow("Motion", detail: motionLine) {
                    SettingsSegments(segments: MotionPreference.allCases.map { ($0, $0.title) }, selection: model.prefs.motion) { m in
                        model.animate(.fadeIn) { model.prefs.motion = m }
                    }
                }
            }
        }
    }

    /// What each choice does, and for Match the Mac, how the Mac is set now.
    private var motionLine: String {
        switch model.prefs.motion {
        case .system:
            let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            return reduced ? L("As your Mac's Reduce Motion is set: on, so things fade instead of moving.")
                           : L("As your Mac's Reduce Motion is set: off, so things move.")
        case .reduce: return L("Fades instead of movement, in this window and the notch.")
        case .full: return L("Every movement, whatever your Mac is set to.")
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
                    Button { selection = choice } label: {
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
                    .help(L(key: choice.title))
                    .accessibilityLabel(L(key: choice.title))
                    .accessibilityAddTraits(on ? [.isSelected] : [])
                }
            }
            Text(selection == .multicolor ? L("Multicolor: follows your Mac") : L(key: selection.title))
                .font(.system(size: 11)).foregroundStyle(palette.secondary)
        }
    }
}

/// Aligned (Oct 24): the accent as the first run's Make it yours shows it: 16 pt swatches, a white
/// dot in the chosen one, a hairline round each and the chosen one ringed in the secondary ink,
/// its name at the row's end.
private struct AlignedSwatches: View {
    @Environment(\.palette) private var palette
    @Binding var selection: AccentChoice

    var body: some View {
        let A = T.Aligned.self
        HStack(spacing: A.swatchGap) {
            ForEach(AccentChoice.allCases, id: \.self) { choice in
                let on = choice == selection
                Button { selection = choice } label: {
                    ZStack {
                        if let color = choice.color {
                            Circle().fill(color)
                        } else {
                            Circle().fill(AngularGradient(colors: A.multicolor, center: .center))
                        }
                        if on { Circle().fill(A.swatchDotColor).frame(width: A.swatchDot, height: A.swatchDot) }
                    }
                    .frame(width: A.swatch, height: A.swatch)
                    .overlay(Circle().strokeBorder(palette.hairline))
                    .padding(A.swatchRingGap)
                    .overlay(Circle().strokeBorder(on ? palette.secondary : .clear, lineWidth: A.chosenRing))
                    .contentShape(Circle())
                }
                .buttonStyle(AlignedPress())
                .help(L(key: choice.title))
                .accessibilityLabel(L(key: choice.title))
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
            Text(selection == .multicolor ? L("Multicolor: follows your Mac") : L(key: selection.title))
                .font(.system(size: 12)).foregroundStyle(palette.secondary)
                .padding(.leading, 4)
        }
    }
}

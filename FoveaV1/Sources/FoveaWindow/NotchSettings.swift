import AppKit
import SwiftUI
import CapturesCore
import FoveaKit

/// Settings › Notch: the Island made yours, without a way to break it. The glow's eight palettes
/// are fixed, as they ship; a ninth choice, Customize, is the person's own, and only it shows the
/// Hue, Spread and Drift (Ryan, Oct 18). The real notch shows each change as it's made. A control
/// shows only where it can change something (the sliders for Customize; the wait only while the
/// pointer opens the board): one that can't move looks broken (Ryan, Oct 6). The board can always
/// be reached, and Restore Defaults puts it all back.

/// The glow in the voice bar while Fovea listens for an agent: the Workbench's palettes to start
/// from, and Custom, seven hues fanned round the one picked.
typealias GlowChoice = GlowPalette

extension GlowPalette {
    /// The glow as picked, for the renderer (NotchGlow.swift, the Workbench's own): a template
    /// turned `hue` degrees round the wheel (Mono stays gray), or Custom fanned across `spread`
    /// degrees round `hue`.
    func look(hue: Double, spread: Double, drift: Bool) -> VoiceGlowLook {
        VoiceGlowLook.make(palette: self, hue: hue, spread: spread, drift: drift)
    }

    /// The seven colors as the glow shows them, the drift aside: the Workbench's swatches.
    func colors(hue: Double, spread: Double) -> [Color] {
        VoiceGlowRenderer.swatches(look: look(hue: hue, spread: spread, drift: false))
    }

    /// Copied from Prototypes/FoveaWorkbench/WorkbenchTokens.swift `VoiceGlow.palettes` (may drift),
    /// centre lobe first.
    var rgb: [(Double, Double, Double)] {
        switch self {
        case .colorful: return [(255, 70, 120), (60, 190, 255), (175, 70, 255), (60, 220, 130), (255, 150, 40), (90, 100, 255), (40, 200, 190)]
        case .mono: return [(215, 215, 215), (180, 180, 180), (190, 190, 190), (160, 160, 160), (170, 170, 170), (150, 150, 150), (155, 155, 155)]
        case .ocean: return [(80, 140, 255), (40, 200, 230), (120, 90, 255), (30, 170, 210), (160, 80, 240), (60, 110, 255), (40, 190, 180)]
        case .sunset: return [(255, 110, 60), (255, 180, 40), (255, 60, 90), (255, 210, 80), (240, 70, 140), (255, 140, 50), (230, 50, 110)]
        case .forest: return [(70, 220, 120), (40, 200, 180), (140, 230, 80), (30, 170, 140), (190, 235, 70), (50, 190, 110), (30, 150, 120)]
        case .candy: return [(255, 90, 170), (255, 120, 220), (210, 80, 255), (255, 150, 190), (180, 110, 255), (255, 70, 140), (230, 100, 240)]
        case .ice: return [(150, 230, 255), (90, 200, 255), (190, 240, 255), (120, 190, 255), (160, 220, 250), (80, 170, 255), (200, 235, 255)]
        case .gold: return [(255, 200, 70), (255, 170, 40), (255, 220, 110), (240, 150, 30), (255, 235, 140), (230, 160, 40), (250, 210, 90)]
        case .custom: return []
        }
    }
}


struct NotchPane: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion
    @State private var confirmRestore = false

    var body: some View {
        @Bindable var model = model
        let prefs = model.prefs
        let glow = prefs.glow

        // The glow's color board, as the Notch Workbench has it, under the notch it colors: a
        // palette to start from, the hue turned on a spectrum, Custom's spread, the drift, and the
        // seven colors it makes. The preview sits on the board and is always listening, so every
        // drag shows on the notch the moment it's made.
        // The notch's look (Oct 9): Liquid Glass, light or dark; what opens below attached to the
        // top edge or floating under it; Compact or Spacious. No picture of it here (Oct 10): the
        // real notch shows each choice as it's made.
        SettingsSection("Look", note: "The notch at the top of your screen shows each change as you make it.") {
            SettingsCard {
                SettingsRow("Glass", detail: prefs.notchAppearance == .light ? "Light glass, dark words." : "Dark glass, white words.") {
                    SettingsSegments(segments: NotchAppearance.allCases.map { ($0, $0.title) }, selection: prefs.notchAppearance) { a in
                        model.animate(.fadeIn) { model.prefs.notchAppearance = a }
                    }
                }
                RowDivider()
                SettingsRow("Panels", detail: prefs.panels == .attached
                            ? "What opens below hangs from the top of the screen, one shape with the notch."
                            : "What opens below floats just under the notch.") {
                    SettingsSegments(segments: NativePanels.allCases.map { ($0, $0.title) }, selection: prefs.panels) { p in
                        model.animate(.fadeIn) { model.prefs.panels = p }
                    }
                }
                RowDivider()
                SettingsRow("Size", detail: prefs.density == .spacious
                            ? "Roomy rows and larger words, as the Mac's own panels have."
                            : "Tighter rows: more of the board at once.") {
                    SettingsSegments(segments: NotchDensity.allCases.map { ($0, $0.title) }, selection: prefs.density) { d in
                        model.animate(.fadeIn) { model.prefs.density = d }
                    }
                }
            }
        }
        .id("notch-look")

        // Oct 18, Ryan: "changing the hue should not change the color scheme provided; those should
        // all be fixed. There should be a choice called Customize that shows the hue and drift only
        // when selected." The eight palettes are drawn as they ship (FoveaPrefs.drawnGlow*: no turn
        // of the hue, the default drift and spread); Customize, the ninth tile, is the person's own,
        // and only it shows Hue, Spread and Drift, as the first run shows it.
        SettingsSection("Glow", note: "The light in the voice bar while you talk to an agent. The notch glows with it as you choose.") {
            SettingsCard {
                GlowTiles(selection: $model.prefs.glow.animation(motion.animation(.layout)), prefs: prefs)
                    .cardPadding()
                if glow == .custom {
                    VStack(spacing: 0) {
                        RowDivider()
                        SettingsRow("Hue", detail: "\(Int(prefs.glowHue))°") {
                            SpectrumSlider(value: $model.prefs.glowHue)
                        }
                        .help("The hue your colors fan out from")
                        RowDivider()
                        SettingsRow("Spread", detail: "\(Int(prefs.glowSpread))°") {
                            Slider(value: $model.prefs.glowSpread, in: 0...360)
                                .frame(width: 220)
                        }
                        .help("How far your seven colors fan across the wheel: 0° is one color, 360° a full spectrum")
                        RowDivider()
                        SettingsRow("Drift", detail: "How much the colors wander round the wheel.") {
                            HStack(spacing: 8) {
                                Text("Still").font(.system(size: 11)).foregroundStyle(palette.secondary)
                                Slider(value: $model.prefs.glowDrift, in: 0...1)
                                    .frame(width: 160)
                                Text("Lively").font(.system(size: 11)).foregroundStyle(palette.secondary)
                            }
                        }
                        RowDivider()
                        GlowDots(colors: glow.colors(hue: prefs.drawn().hue, spread: prefs.drawn().spread))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .transition(.arrive)
                }
            }
        }
        .id("notch-glow")

        SettingsSection("Opening the board") {
            SettingsCard {
                SettingsRow("Open when the pointer reaches the notch",
                            detail: "The board shows what your agents are doing; with nothing running, it says hello.") {
                    InkToggle(title: "Open when the pointer reaches the notch", isOn: $model.prefs.hoverOpens.animation(motion.animation(.layout)))
                }
                if prefs.hoverOpens {
                    // Only while the pointer opens it: a wait for nothing would look broken.
                    VStack(spacing: 0) {
                        RowDivider()
                        SettingsRow("Wait before opening", detail: "Relaxed keeps it shut when you only pass by.") {
                            SettingsSegments(segments: HoverWait.allCases.map { ($0, $0.title) }, selection: prefs.hoverWait) { wait in
                                model.prefs.hoverWait = wait
                            }
                        }
                    }
                    .transition(.arrive)
                } else {
                    // Never no way in: with the hover off, the key still opens it.
                    VStack(spacing: 0) {
                        RowDivider()
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle").foregroundStyle(palette.secondary)
                            Text("The board still shows each time you send.")
                                .font(.system(size: 12)).foregroundStyle(palette.text)
                            Spacer()
                        }
                        .cardPadding()
                    }
                    .transition(.arrive)
                }
                RowDivider()
                SettingsRow("Show an answer as soon as it's back",
                            detail: "When an agent answers within a few seconds, the notch opens it for you.") {
                    InkToggle(title: "Show an answer as soon as it's back", isOn: $model.prefs.showAnswers)
                }
            }
        }
        .id("notch-board")

        SettingsSection("Sending to an agent") {
            SettingsCard {
                SettingsRow("Review your words before sending",
                            detail: prefs.reviewFirst
                                ? "Choose chat shows your words and where they'll go. Return sends."
                                : "Fovea sends to the chat it picks. The voice bar says where, and the board shows it on its way.") {
                    InkToggle(title: "Review your words before sending", isOn: $model.prefs.reviewFirst)
                }
            }
        }

        HStack {
            Spacer()
            Button("Restore Defaults") { confirmRestore = true }
                .disabled(prefs.notchIsDefault)
        }
        .alert("Restore the notch's defaults?", isPresented: $confirmRestore) {
            Button("Restore Defaults") { model.animate(.layout) { model.prefs.restoreNotch() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The colorful glow, opening at the notch, and reviewing your words before sending.")
        }
    }

}

/// The hue, picked on the color wheel laid flat: a spectrum track, its thumb filled with the hue
/// it rests on. As the Notch Workbench's (`SpectrumSlider`, WorkbenchView.swift).
struct SpectrumSlider: View {
    @Environment(\.isEnabled) private var isEnabled
    @Binding var value: Double
    private let track: CGFloat = 12
    private let thumb: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let travel = max(1, geo.size.width - thumb)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: stride(from: 0.0, through: 360, by: 30).map { Color(hue: $0 / 360, saturation: 0.8, brightness: 1) },
                                         startPoint: .leading, endPoint: .trailing))
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
                    .frame(height: track)
                    .padding(.horizontal, thumb / 2 - track / 2)
                Circle()
                    .fill(Color(hue: value / 360, saturation: 0.8, brightness: 1))
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
                    .frame(width: thumb, height: thumb)
                    .offset(x: travel * CGFloat(value / 360))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                guard isEnabled else { return }
                value = Double(max(0, min(1, (drag.location.x - thumb / 2) / travel))) * 360
            })
        }
        .frame(width: 220, height: thumb + 4)
        .opacity(isEnabled ? 1 : 0.4)
        .saturation(isEnabled ? 1 : 0.3)
        .accessibilityElement()
        .accessibilityLabel("Hue")
        .accessibilityValue("\(Int(value)) degrees")
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            switch direction {
            case .increment: value = min(360, value + 10)
            case .decrement: value = max(0, value - 10)
            @unknown default: break
            }
        }
    }
}

extension Prefs {
    /// The glow as the notch draws it (Oct 18, the same rule as `FoveaPrefs.drawnGlow*`): a palette
    /// as it ships, Customize as the person set it. `palette` defaults to the one chosen.
    func drawn(_ palette: GlowPalette? = nil) -> (hue: Double, spread: Double, drift: Double) {
        var p = FoveaPrefs()
        p.glowPalette = palette ?? glow
        p.glowHue = glowHue
        p.glowSpread = glowSpread
        p.glowDrift = glowDrift
        return (p.drawnGlowHue, p.drawnGlowSpread, p.drawnGlowDrift)
    }
}

/// The glow's choices as tiles (Oct 18): the eight palettes, fixed, then Customize, which shows the
/// person's own colors. Each is the glow in miniature, on the notch's black; the chosen one ringed in
/// the accent, as System Settings' Appearance tiles are.
private struct GlowTiles: View {
    @Environment(\.palette) private var palette
    @Binding var selection: GlowPalette
    let prefs: Prefs

    var body: some View {
        let options = GlowPalette.templates + [.custom]
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 12) {
            ForEach(options, id: \.self) { option in
                let on = option == selection
                let drawn = prefs.drawn(option)
                Button { selection = option } label: {
                    VStack(spacing: 5) {
                        GlowSwatch(colors: option.colors(hue: drawn.hue, spread: drawn.spread), custom: option == .custom)
                            .frame(height: 38)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .padding(3)
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(on ? palette.accent : .clear, lineWidth: 2.5))
                        Text(option == .custom ? L("Customize") : option.title)
                            .font(.system(size: 11.5, weight: on ? .semibold : .regular))
                            .foregroundStyle(palette.text)
                            .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(option == .custom ? L("Your own colors: Hue, Spread and Drift") : L("\(option.title), as it ships"))
                .accessibilityLabel(option == .custom ? L("Customize") : option.title)
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
    }
}

/// The glow in miniature: its seven colors, soft and overlapping, on the notch's black; Customize
/// marked with the sliders' symbol.
private struct GlowSwatch: View {
    @Environment(\.palette) private var palette
    let colors: [Color]
    var custom = false

    var body: some View {
        let order = [5, 3, 1, 0, 2, 4, 6].filter { $0 < colors.count }
        ZStack {
            palette.pill
            HStack(spacing: -5) {
                ForEach(order, id: \.self) { i in
                    Circle().fill(colors[i]).frame(width: 12, height: 12)
                }
            }
            .blur(radius: 2.5)
            if custom {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(palette.onPill)
                    .padding(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The glow's seven colors as the bar shows them, left to right: the centre lobe in the middle,
/// the pairs outward. As the Workbench's swatches.
struct GlowDots: View {
    let colors: [Color]

    var body: some View {
        let order = [5, 3, 1, 0, 2, 4, 6].filter { $0 < colors.count }
        HStack(spacing: 8) {
            ForEach(order, id: \.self) { i in
                Circle()
                    .fill(colors[i])
                    // Firm enough that Mono's near-white centre still shows on a light page.
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 0.5))
                    .frame(width: 16, height: 16)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("The glow's colors")
    }
}

/// A row of pictures to choose between, each with its name and a line under it; the chosen one
/// ringed in the accent, as System Settings' Appearance tiles are.
struct PictureChoices<Value: Hashable, Picture: View>: View {
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion
    let options: [Value]
    @Binding var selection: Value
    let title: KeyPath<Value, String>
    var detail: KeyPath<Value, String>?
    var pictureHeight: CGFloat = 56
    @ViewBuilder let picture: (Value, Bool) -> Picture

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(options, id: \.self) { option in
                let on = option == selection
                Button { selection = option } label: {
                    VStack(spacing: 6) {
                        picture(option, on)
                            .frame(maxWidth: .infinity)
                            .frame(height: pictureHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.black.opacity(0.12), lineWidth: 0.5))
                            .padding(3)
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(on ? palette.accent : .clear, lineWidth: 2.5))
                        Text(L(key: option[keyPath: title]))
                            .font(.system(size: 11.5, weight: on ? .semibold : .regular))
                            .foregroundStyle(palette.text)
                        if let detail {
                            Text(L(key: option[keyPath: detail]))
                                .font(.system(size: 10.5))
                                .foregroundStyle(palette.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L(key: option[keyPath: title]))
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
    }
}

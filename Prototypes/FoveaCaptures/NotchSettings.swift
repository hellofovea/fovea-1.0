import AppKit
import SwiftUI
import CapturesCore

/// Settings › Notch: the Island made yours, without a way to break it. The glow keeps the Notch
/// Workbench's color board (a palette to start from, the hue turned on a spectrum, Custom's spread,
/// the drift, the seven colors it makes), because people want their own colors, under a live notch
/// that shows each change as it's made. A control shows only where it can change something
/// (Spread for Custom; Hue and the drift not for Mono; the wait only while the pointer opens the
/// board): one that can't move looks broken (Ryan, Oct 6). The board can always be reached, and
/// Restore Defaults puts it all back.

/// The glow in the voice bar while Fovea listens for an agent: the Workbench's palettes to start
/// from, and Custom, seven hues fanned round the one picked.
enum GlowChoice: String, CaseIterable {
    case colorful, ocean, sunset, forest, candy, ice, gold, mono, custom
    var title: String { rawValue.capitalized }
    static let templates: [GlowChoice] = [.colorful, .ocean, .sunset, .forest, .candy, .ice, .gold, .mono]

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

/// How long the pointer rests at the notch before the board opens: named, never in milliseconds.
enum HoverWait: String, CaseIterable {
    case quick, normal, relaxed
    var title: String { rawValue.capitalized }
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
        SettingsSection("Glow", note: "The light in the voice bar while you talk to an agent.") {
            SettingsCard {
                NotchPreview(glow: glow.look(hue: prefs.glowHue, spread: prefs.glowSpread, drift: prefs.glowDrift))
                    .frame(height: 132)
                    .cardPadding()
                RowDivider()
                SettingsRow("Palette", detail: glow == .mono ? "Mono is gray: there's no hue to turn." : nil) {
                    Picker(selection: $model.prefs.glow.animation(motion.animation(.swap))) {
                        ForEach(GlowChoice.templates, id: \.self) { Text($0.title).tag($0) }
                        Divider()
                        Text(GlowChoice.custom.title).tag(GlowChoice.custom)
                    } label: { EmptyView() }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .fixedSize()
                }
                // Only what can change this palette shows: a control that can't move looks broken.
                if glow != .mono {
                    VStack(spacing: 0) {
                        RowDivider()
                        SettingsRow("Hue", detail: glow == .custom ? "\(Int(prefs.glowHue))°" : "+\(Int(prefs.glowHue))°") {
                            SpectrumSlider(value: $model.prefs.glowHue)
                        }
                        .help(glow == .custom ? "The hue the custom colors fan out from" : "Turns the palette round the color wheel")
                    }
                    .transition(.opacity)
                }
                if glow == .custom {
                    VStack(spacing: 0) {
                        RowDivider()
                        SettingsRow("Spread", detail: "\(Int(prefs.glowSpread))°") {
                            Slider(value: $model.prefs.glowSpread, in: 0...360)
                                .frame(width: 220)
                        }
                        .help("How far the seven custom colors fan across the wheel: 0° is one color, 360° a full spectrum")
                    }
                    .transition(.opacity)
                }
                if glow != .mono {
                    VStack(spacing: 0) {
                        RowDivider()
                        SettingsRow("Hue drift", detail: "The colors wander slowly round the wheel.") {
                            InkToggle(title: "Hue drift", isOn: $model.prefs.glowDrift)
                        }
                    }
                    .transition(.opacity)
                }
                RowDivider()
                GlowDots(colors: glow.colors(hue: prefs.glowHue, spread: prefs.glowSpread))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .id("notch-glow")

        SettingsSection("Opening the board") {
            SettingsCard {
                SettingsRow("Open when the pointer reaches the notch",
                            detail: "The board shows what your agents are doing. It never opens empty.") {
                    InkToggle(title: "Open when the pointer reaches the notch", isOn: $model.prefs.hoverOpens.animation(motion.animation(.swap)))
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
                    .transition(.opacity)
                } else {
                    // Never no way in: with the hover off, the key still opens it.
                    VStack(spacing: 0) {
                        RowDivider()
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle").foregroundStyle(palette.secondary)
                            Text("You can still open it: press ⌃ by itself.")
                                .font(.system(size: 12)).foregroundStyle(palette.text)
                            Spacer()
                            Button("Shortcuts…") { model.pickSettings(.shortcuts) }
                        }
                        .cardPadding()
                    }
                    .transition(.opacity)
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
        .confirmationDialog("Restore the notch's defaults?", isPresented: $confirmRestore) {
            Button("Restore Defaults") { model.animate(.swap) { model.prefs.restoreNotch() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The colorful glow, opening at the notch, and reviewing your words before sending.")
        }
    }

}

/// The top of a MacBook's screen at its own size, and Fovea's voice bar listening in it, the glow
/// drawn by the Notch Workbench's renderer from its demo voice. Always live, as the Workbench's
/// notch is, so a change shows as it's made.
struct NotchPreview: View {
    let glow: VoiceGlowLook

    var body: some View {
        let screen = RoundedRectangle(cornerRadius: 10, style: .continuous)
        Color.clear
            .overlay { Wallpaper() }
            .overlay(alignment: .top) { PreviewMenuBar() }
            .overlay(alignment: .top) { VoiceBarFigure(glow: glow) }
            .clipShape(screen)
            .overlay(screen.strokeBorder(.black.opacity(0.12), lineWidth: 0.5))
            .accessibilityElement()
            .accessibilityLabel("Your notch while Fovea listens for an agent")
    }
}

/// The voice bar, black as the shipping Island draws it, listening: the glow rises from its
/// bottom edge, clipped to its outline.
private struct VoiceBarFigure: View {
    @Environment(\.motion) private var motion
    let glow: VoiceGlowLook
    /// The driver keeps the voice's envelope from frame to frame, as the Workbench's does.
    @State private var engine = VoiceGlowEngine()
    /// Snapshots draw one still frame, mid-phrase, as the Workbench's do; `--only glow-live`
    /// keeps it moving.
    private static let snapshot = CommandLine.arguments.contains("--snapshot")
        && !CommandLine.arguments.contains("glow-live")

    var body: some View {
        let G = NotchPreviewGeometry.self
        let edge = IslandEdge(size: G.bar, topRadius: G.topRadius, bottomRadius: G.bottomRadius, earY: 0)
        let still = Self.snapshot || motion.reduce
        TimelineView(.animation(minimumInterval: 1 / GlowTokens.frameRate, paused: still)) { context in
            Canvas { ctx, _ in
                let frame = still
                    ? engine.still(at: GlowTokens.stillTime, geometry: GlowTokens.wide, reduceMotion: motion.reduce)
                    : engine.frame(at: context.date, geometry: GlowTokens.wide, reduceMotion: motion.reduce)
                VoiceGlowRenderer.draw(in: &ctx, edge: edge, frame: frame, look: glow)
            }
        }
        .frame(width: G.bar.width, height: G.bar.height)
        // Flattened into one image before it reaches the screen. Drawn straight to it, most moving
        // frames lost everything under the band line: a black stripe along the bar's foot (14 of
        // 23 frames in `--only glow-live`; flattened, none).
        .drawingGroup()
        .background(.black)
        .clipShape(IslandShape(topRadius: G.topRadius, bottomRadius: G.bottomRadius))
        .allowsHitTesting(false)
    }
}

/// The menu bar round the notch, as a notched MacBook draws it over the wallpaper.
private struct PreviewMenuBar: View {
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
private struct Wallpaper: View {
    var body: some View {
        if let wallpaper = Art.resource("Photos/coast.jpg") {
            Image(nsImage: wallpaper).resizable().aspectRatio(contentMode: .fill)
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
                Button { withAnimation(motion.animation(.swap)) { selection = option } } label: {
                    VStack(spacing: 6) {
                        picture(option, on)
                            .frame(maxWidth: .infinity)
                            .frame(height: pictureHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.black.opacity(0.12), lineWidth: 0.5))
                            .padding(3)
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(on ? palette.accent : .clear, lineWidth: 2.5))
                        Text(option[keyPath: title])
                            .font(.system(size: 11.5, weight: on ? .semibold : .regular))
                            .foregroundStyle(palette.text)
                        if let detail {
                            Text(option[keyPath: detail])
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
                .accessibilityLabel(option[keyPath: title])
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
    }
}

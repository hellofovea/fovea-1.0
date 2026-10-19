import SwiftUI
import AppKit
import UniformTypeIdentifiers
import OnboardingCore
import FoveaLook

// What the board holds besides its words: what each step adds (the languages, the accent and the
// light, the two lists, the microphone's line, the agents, the words to bring), the line to say,
// and the actions (help, the way past the step, the one button). Boards.swift places them.

/// The board's ink: white at an opacity on the dark stage (the Island's rule).
struct BoardInk {
    var dark: Bool
    var primary: Color { dark ? OT.Colors.white(0.94) : OT.Colors.ink }
    var secondary: Color { dark ? OT.Colors.white(0.62) : OT.Colors.ink(0.6) }
    var tertiary: Color { dark ? OT.Colors.white(0.4) : OT.Colors.ink(0.42) }
    var hairline: Color { dark ? OT.Colors.white(0.1) : OT.Colors.ink(0.09) }
    var fill: Color { dark ? OT.Colors.white(0.09) : OT.Colors.ink(0.05) }
    var button: Color { dark ? OT.Colors.islandSolid : OT.Colors.ink }
    var buttonText: Color { dark ? OT.Colors.islandOnSolid : OT.Colors.canvas }
}

private struct BoardInkKey: EnvironmentKey {
    static let defaultValue = BoardInk(dark: true)
}

extension EnvironmentValues {
    var boardInk: BoardInk {
        get { self[BoardInkKey.self] }
        set { self[BoardInkKey.self] = newValue }
    }
}

extension OnboardingModel {
    /// Lines are typed out (Oct 9), unless the panel says not, or it's a snapshot, or Reduce Motion.
    var typesLines: Bool { typing && !options.harness && !reduceMotion }
}

/// The line to say, set apart from everything else on the board (Oct 9, round two: it looked like
/// "Not working?"): Fovea's quote mark in the accent, the words in serif, brighter once the bar
/// listens.
struct BoardScript: View {
    let model: OnboardingModel
    @Environment(\.boardInk) private var ink

    var body: some View {
        if let script = model.copy.script, model.isPracticeTry || model.step == .followUp {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(model.accentColor)
                Text(script)
                    .font(OT.Board.script)
                    .foregroundStyle(model.barOpen ? ink.primary : ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
            .animation(OT.Motion.calm, value: model.barOpen)
        }
    }
}

// MARK: - What a step adds

struct BoardExtras: View {
    let model: OnboardingModel
    @Environment(\.boardInk) private var ink

    var body: some View {
        switch model.step {
        case .signIn:
            SignInView(model: model)
        case .name:
            AccountField(model: model, kind: .name)
        case .hello:
            // Clear my screen set apart from the language (Oct 9), its reason read with it.
            VStack(spacing: 0) {
                LanguagePicker(model: model)
                ClearScreen(model: model)
                    .padding(.top, 30)
            }
        case .makeItYours:
            Personalize(model: model)
        case .permissions:
            PermissionRows(model: model)
        case .microphone:
            MicTestView(model: model)
        case .agents:
            AgentsView(model: model)
        case .hover, .packList, .followUp:
            AgentNote(model: model)
        case .dictationIntro:
            VStack(spacing: OT.Board.readingGap + 6) {
                // Oct 15 review, ST-03.1: the person's own Voice Flow key, as recorded in Settings.
                HStack(spacing: 6) {
                    ForEach(model.keys.caps(.dictation), id: \.self) {
                        KeyCap(label: $0, lit: model.keysDown.contains($0), accent: model.accentColor, dark: model.boardDark, large: true)
                    }
                }
                WhileDictating(model: model)
            }
        case .dictionary:
            DictionaryImportView(model: model)
        case .memory:
            MemoryPoints(model: model)
        case .home:
            Closing(model: model)
        default:
            EmptyView()
        }
    }
}

/// The language Fovea listens in (Oct 9): English and Chinese, and More…, which opens a box to type
/// another in; it's kept as a request, for the languages to add next. Oct 17, Ryan (FR-06): more
/// than one. Return adds the language typed as a chip and clears the box for another; each chip's ✕
/// takes it off; empty and repeated ones are passed over. They're the prefs' requested languages,
/// which Settings › Language lists too.
struct LanguagePicker: View {
    let model: OnboardingModel
    @State private var typed = ""
    @FocusState private var focused: Bool
    @Environment(\.boardInk) private var ink

    var body: some View {
        let choice = model.languageChoice
        let requests = model.flow.languageRequests
        VStack(spacing: 12) {
            // Oct 18, Ryan: "Choose your languages": English and Chinese, each on or off (one
            // stays on), and More… for the rest, kept as requests.
            HStack(spacing: 10) {
                Text(Copy.languageLead).font(OT.Type_.guideBody).foregroundStyle(ink.secondary)
                HStack(spacing: 6) {
                    ForEach(Language.featured, id: \.self) { language in
                        Button(action: { model.toggleLanguage(language) }) {
                            toggle(Copy.languageName(language), on: choice.on.contains(language))
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(choice.on.contains(language) ? L("Switched on") : L("Switched off"))
                    }
                    Button(action: {
                        model.openLanguageMore()
                        focused = true
                    }) {
                        segment(moreTitle(requests), on: model.languageMoreOpen)
                    }
                    .buttonStyle(.plain)
                    .playTarget(.languageMore, model)
                    .padding(2)
                    .background(Capsule().fill(ink.fill))
                }
            }
            // With both on, which is primary: the interface's language (Oct 18, Ryan).
            if choice.asksPrimary {
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        Text(Copy.primaryLanguage).font(OT.Type_.guideBody).foregroundStyle(ink.secondary)
                        HStack(spacing: 2) {
                            ForEach(choice.on, id: \.self) { language in
                                Button(action: { model.choosePrimaryLanguage(language) }) {
                                    segment(Copy.languageName(language), on: choice.primary == language)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(2)
                        .background(Capsule().fill(ink.fill))
                    }
                    Text(Copy.primaryNote).font(.system(size: 12)).foregroundStyle(ink.tertiary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if model.languageMoreOpen {
                VStack(spacing: 8) {
                    TextField(Copy.languagePlaceholder, text: $typed)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(ink.primary)
                        .multilineTextAlignment(.center)
                        .focused($focused)
                        .onSubmit {
                            model.addLanguageRequest(typed)
                            // Cleared for another, whether it was added or passed over.
                            typed = ""
                            focused = true
                        }
                        .padding(.horizontal, 14)
                        .frame(width: OT.Board.languageField, height: 34)
                        .background(Capsule().fill(ink.fill))
                        .overlay(Capsule().strokeBorder(model.accentColor.opacity(focused ? 0.8 : 0.3)))
                    if !requests.isEmpty {
                        FlowRow(spacing: 6, centered: true) {
                            ForEach(requests, id: \.self) { language in
                                chip(language)
                            }
                        }
                        .frame(width: OT.Board.languageChips)
                        .transition(.opacity)
                    }
                    Text(Copy.languageNote).font(.system(size: 12)).foregroundStyle(ink.tertiary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(OT.Motion.calm, value: model.languageMoreOpen)
        .animation(OT.Motion.calm, value: model.languageChoice)
        .animation(OT.Motion.content, value: requests)
    }

    /// A language on or off: a capsule with a check, so several can be on at once.
    private func toggle(_ title: String, on: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(on ? model.accentColor : ink.tertiary)
            Text(title).font(.system(size: 11.5, weight: on ? .semibold : .medium))
                .foregroundStyle(on ? ink.primary : ink.secondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Capsule().fill(ink.fill))
        .overlay(Capsule().strokeBorder(on ? model.accentColor.opacity(0.6) : ink.hairline))
        .contentShape(Capsule())
    }

    /// More…, or what's been asked for once the box is shut ("Japanese", "Japanese +1").
    private func moreTitle(_ requests: [String]) -> String {
        guard let first = requests.first, !model.languageMoreOpen else { return Copy.languageMore }
        return requests.count == 1 ? first : "\(first) +\(requests.count - 1)"
    }

    /// A language asked for, with its ✕.
    private func chip(_ language: String) -> some View {
        HStack(spacing: 5) {
            Text(language).font(.system(size: 12, weight: .medium)).foregroundStyle(ink.primary)
            Button(action: { model.removeLanguageRequest(language) }) {
                Image(systemName: "xmark").font(.system(size: 8.5, weight: .bold)).foregroundStyle(ink.tertiary)
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Remove \(language)")
            .accessibilityLabel("Remove \(language)")
        }
        .padding(.leading, 10).padding(.trailing, 6)
        .frame(height: OT.Board.languageChipHeight)
        .background(Capsule().fill(ink.fill))
        .overlay(Capsule().strokeBorder(ink.hairline))
    }

    private func segment(_ title: String, on: Bool) -> some View {
        Text(title)
            .font(.system(size: 11.5, weight: on ? .semibold : .medium))
            .foregroundStyle(on ? ink.buttonText : ink.secondary)
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(Capsule().fill(on ? ink.button : .clear))
            .contentShape(Capsule())
    }
}

/// Oct 17, Ryan: "there should be a part that tells the user all of the hotkeys". What works while
/// dictating, with the person's own keys: ⌘ for part of the screen (Oct 19), ⌘ twice for the whole screen
/// (Oct 18, Ryan), and words (selected) or a file (dragged onto the notch) with no key. All of it
/// lands after the words.
struct WhileDictating: View {
    let model: OnboardingModel
    @Environment(\.boardInk) private var ink

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Copy.whileDictatingLead).font(OT.Type_.guideEyebrow).foregroundStyle(ink.tertiary)
            ForEach(Array(Copy.whileDictating(keys: model.keys).enumerated()), id: \.offset) { _, line in
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        if line.caps.isEmpty {
                            Image(systemName: "cursorarrow.and.square.on.square.dashed")
                                .font(.system(size: 14)).foregroundStyle(ink.secondary)
                        }
                        ForEach(Array(line.caps.enumerated()), id: \.offset) { _, cap in
                            KeyCap(label: cap, lit: model.keysDown.contains(cap), accent: model.accentColor, dark: model.boardDark)
                        }
                        if line.presses > 1 {
                            Text("×\(line.presses)").font(.system(size: 12, weight: .bold).monospacedDigit())
                                .foregroundStyle(model.accentColor)
                        }
                    }
                    .frame(width: OT.Board.takeKeysWidth, alignment: .trailing)
                    // Oct 18, Ryan: what it takes, and how, quieter, under it.
                    VStack(alignment: .leading, spacing: 1) {
                        Text(line.title).font(.system(size: 13, weight: .medium)).foregroundStyle(ink.primary)
                        Text(line.detail).font(.system(size: 12)).foregroundStyle(ink.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(width: OT.Board.takeListWidth)
    }
}

/// Make it yours: Fovea's accent, then, well apart from it (Oct 9: two choices, a real gap between),
/// the light the notch shows while it listens for an agent: its palette, its hue, and how much it
/// drifts, a dial from still to lively (Oct 8); then the notch itself (Oct 9): its glass light or
/// dark, what opens below attached or floating, and the room it takes. Each shows at the real notch
/// as it's chosen, and Settings › Notch starts with it.
struct Personalize: View {
    let model: OnboardingModel
    @Environment(\.boardInk) private var ink

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                label(Copy.accentLabel)
                HStack(spacing: 10) {
                    ForEach(AccentName.allCases, id: \.self) { accent in
                        Button(action: { model.setAccent(accent) }) {
                            Swatch(accent: accent, chosen: model.personal.accent == accent)
                        }
                        .buttonStyle(.plain)
                        .playTarget(.accent(accent), model)
                        .help(L(key: accent.title))
                    }
                    Text(L(key: model.personal.accent.title))
                        .font(OT.Type_.guideBody).foregroundStyle(ink.secondary)
                        .padding(.leading, 4)
                }
            }
            // Two choices, well apart (Oct 9: a gap, not a line).
            Spacer().frame(height: OT.Board.sectionGap)
            VStack(alignment: .leading, spacing: 10) {
                label(Copy.auraLabel)
                // Oct 18, Ryan: "changing the hue should not change the color scheme provided, those
                // all should be fixed. There should be a choice called Customize". The eight are
                // drawn at their own colors whatever the sliders say; Customize is the ninth, and the
                // hue and the drift show only while it's chosen.
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: OT.Board.auraColumns), spacing: 8) {
                    ForEach(Personalization.tiles, id: \.self) { aura in
                        Button(action: { model.setAura(aura) }) {
                            AuraChip(aura: aura, hue: model.personal.auraHue, chosen: model.personal.aura == aura)
                        }
                        .buttonStyle(.plain)
                        .playTarget(.aura(aura), model)
                    }
                }
                if model.personal.aura == .custom {
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            Text("Hue").font(OT.Type_.guideBody).foregroundStyle(ink.secondary).frame(width: 40, alignment: .leading)
                            HueSlider(value: Binding(get: { model.personal.auraHue }, set: { model.setAuraHue($0) }))
                        }
                        HStack(spacing: 12) {
                            Text("Drift").font(OT.Type_.guideBody).foregroundStyle(ink.secondary).frame(width: 40, alignment: .leading)
                            DriftSlider(value: Binding(get: { model.personal.auraDrift }, set: { model.setAuraDrift($0) }),
                                        accent: model.accentColor)
                                .playTarget(.drift, model)
                        }
                    }
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            Spacer().frame(height: OT.Board.sectionGap)
            VStack(alignment: .leading, spacing: 10) {
                label(L("The notch"))
                NotchChoiceRow(title: L("Glass"), options: NotchAppearance.allCases, chosen: model.notchAppearance,
                               name: \.title) { model.setNotchAppearance($0) }
                NotchChoiceRow(title: L("Panels"), options: NativePanels.allCases, chosen: model.notchPanels,
                               name: \.title) { model.setNotchPanels($0) }
                NotchChoiceRow(title: L("Size"), options: NotchDensity.allCases, chosen: model.notchDensity,
                               name: \.title) { model.setNotchDensity($0) }
            }
        }
        .animation(OT.Motion.calm, value: model.personal.aura)
    }

    private func label(_ text: String) -> some View {
        Text(text).font(OT.Type_.guideEyebrow).foregroundStyle(ink.tertiary)
    }
}

/// One of the notch's choices: its name, and the two ways it can be, as the hello board's
/// language segments are drawn.
struct NotchChoiceRow<Value: Hashable>: View {
    let title: String
    let options: [Value]
    let chosen: Value
    let name: KeyPath<Value, String>
    let choose: (Value) -> Void
    @Environment(\.boardInk) private var ink

    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(OT.Type_.guideBody).foregroundStyle(ink.secondary).frame(width: 44, alignment: .leading)
            HStack(spacing: 2) {
                ForEach(options, id: \.self) { option in
                    let on = option == chosen
                    Button(action: { choose(option) }) {
                        Text(L(key: option[keyPath: name]))
                            .font(.system(size: 11.5, weight: on ? .semibold : .medium))
                            .foregroundStyle(on ? ink.buttonText : ink.secondary)
                            .padding(.horizontal, 10)
                            .frame(height: 22)
                            .background(Capsule().fill(on ? ink.button : .clear))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Capsule().fill(ink.fill))
        }
    }
}

struct Swatch: View {
    let accent: AccentName
    let chosen: Bool
    @Environment(\.boardInk) private var ink

    var body: some View {
        ZStack {
            if accent == .multicolor {
                Circle().fill(AngularGradient(colors: OT.Colors.multicolor, center: .center))
            } else {
                Circle().fill(AccentPalette.color(accent))
            }
            if chosen { Circle().fill(OT.Colors.swatchDot).frame(width: 7, height: 7) }
        }
        .frame(width: 16, height: 16)
        .overlay(Circle().strokeBorder(ink.hairline))
        .padding(2)
        .overlay(Circle().strokeBorder(chosen ? ink.secondary : .clear, lineWidth: 1.5))
    }
}

/// A palette to pick: its seven colors as dots, on black as the notch shows them.
struct AuraChip: View {
    let aura: AuraPalette
    let hue: Double
    let chosen: Bool
    @Environment(\.boardInk) private var ink

    var body: some View {
        // Oct 18, Ryan: a palette at its own colors; Customize at the hue being set.
        let look = (GlowChoice(rawValue: aura.rawValue) ?? .colorful).look(hue: aura == .custom ? hue : 0, spread: 120, drift: false)
        let colors = VoiceGlowRenderer.swatches(look: look)
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(Array([5, 3, 1, 0, 2, 4, 6].filter { $0 < colors.count }.enumerated()), id: \.offset) { _, i in
                    Circle().fill(colors[i]).frame(width: 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(OT.Colors.auraChipBack))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(ink.hairline))
            Text(aura == .custom ? Copy.customizeAura : L(key: aura.title)).font(.system(size: 11, weight: chosen ? .semibold : .regular))
                .foregroundStyle(chosen ? ink.primary : ink.tertiary)
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(chosen ? ink.secondary : .clear, lineWidth: 1.5))
    }
}

/// The hue, on the color wheel laid flat (Settings › Notch's `SpectrumSlider`).
struct HueSlider: View {
    @Binding var value: Double

    var body: some View {
        GeometryReader { geo in
            let thumb: CGFloat = 16
            let travel = max(1, geo.size.width - thumb)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: stride(from: 0.0, through: 360, by: 30).map { Color(hue: $0 / 360, saturation: 0.8, brightness: 1) },
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 10)
                    .padding(.horizontal, thumb / 2 - 5)
                Circle()
                    .fill(Color(hue: value / 360, saturation: 0.8, brightness: 1))
                    .overlay(Circle().strokeBorder(OT.Colors.knobEdge, lineWidth: 2))
                    .shadow(color: OT.Colors.knobShadow, radius: 1, y: 0.5)
                    .frame(width: thumb, height: thumb)
                    .offset(x: travel * CGFloat(value / 360))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                value = Double(max(0, min(1, (drag.location.x - thumb / 2) / travel))) * 360
            })
        }
        .frame(height: 20)
    }
}

/// How much the colors wander: a dial from still to lively, not a switch (Oct 8). The track fills
/// in the accent as far as it's turned.
struct DriftSlider: View {
    @Binding var value: Double
    let accent: Color
    @Environment(\.boardInk) private var ink

    var body: some View {
        HStack(spacing: 8) {
            Text("Still").font(.system(size: 11)).foregroundStyle(ink.tertiary)
            GeometryReader { geo in
                let thumb: CGFloat = 16
                let travel = max(1, geo.size.width - thumb)
                ZStack(alignment: .leading) {
                    Capsule().fill(ink.fill).frame(height: 6)
                    Capsule().fill(accent).frame(width: thumb / 2 + travel * value, height: 6)
                    Circle()
                        .fill(OT.Colors.knobEdge)
                        .overlay(Circle().strokeBorder(ink.hairline))
                        .shadow(color: OT.Colors.knobShadow, radius: 1, y: 0.5)
                        .frame(width: thumb, height: thumb)
                        .offset(x: travel * value)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                    value = Double(max(0, min(1, (drag.location.x - thumb / 2) / travel)))
                })
            }
            .frame(height: 20)
            Text("Lively").font(.system(size: 11)).foregroundStyle(ink.tertiary)
        }
        .accessibilityElement()
        .accessibilityLabel("Drift")
        .accessibilityValue("\(Int(value * 100)) percent")
        .accessibilityAdjustableAction { direction in
            value = max(0, min(1, value + (direction == .increment ? 0.1 : -0.1)))
        }
    }
}

/// The two lists (Oct 9: granted together, named and nothing more), each with its own button:
/// Fovea asks macOS (which adds it to the list), and System Settings opens at that list, where
/// the person turns Fovea's switch on. Ticked the moment it's allowed.
struct PermissionRows: View {
    let model: OnboardingModel
    @Environment(\.boardInk) private var ink

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Oct 15 review, OB-01.5 and FR-09: Input Monitoring is the third row, asked for like the
            // others and shown as it stands, but never waited on: 1.0's own key engine doesn't need
            // it, so Continue works with the first two (OnboardingModel.grant).
            ForEach(Permission.page, id: \.self) { permission in
                let allowed = model.flow.allowed.contains(permission)
                let asked = model.asked.contains(permission)
                HStack(spacing: 10) {
                    Image(systemName: allowed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(allowed ? model.accentColor : ink.tertiary)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(permission.paneName).font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(ink.primary)
                        Text(allowed ? L("Allowed") : (asked ? L("Turn Fovea on in the list") : permission.purpose))
                            .font(.system(size: 11)).foregroundStyle(ink.tertiary)
                    }
                    Spacer(minLength: 12)
                    if !allowed {
                        Button(action: { model.askFor(permission) }) {
                            Text(asked ? "Open Settings" : "Allow")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(ink.buttonText)
                                .padding(.horizontal, 12).frame(height: 24)
                                .background(Capsule().fill(ink.button))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(OT.Motion.content, value: allowed)
            }
            // Screen Recording counts only once Fovea has reopened (macOS's rule); its own
            // Quit & Reopen does it, or this.
            if model.asked.contains(.screenRecording), !model.flow.allowed.contains(.screenRecording) {
                HStack(spacing: 12) {
                    Button(action: { model.host?.reopen() }) {
                        Text("Quit & Reopen")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(ink.primary)
                            .padding(.horizontal, 12).frame(height: 24)
                            .background(Capsule().strokeBorder(ink.hairline))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Once Fovea is switched on in Screen & System Audio Recording")
                    // Still not in the list: + under it, and Fovea, which this shows where it is.
                    Button(action: { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }) {
                        Text("Not in the list? Show Fovea in Finder, then add it with +")
                            .font(.system(size: 11)).foregroundStyle(ink.tertiary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 26)
            }
        }
    }
}

/// The microphone test (Oct 8, Oct 9): a line to say, large, and bars that move with the real input.
struct MicTestView: View {
    let model: OnboardingModel
    @Environment(\.boardInk) private var ink

    var body: some View {
        let phase = model.micPhase
        HStack(spacing: 14) {
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<7, id: \.self) { i in
                    let bell = [0.45, 0.7, 0.9, 1, 0.9, 0.7, 0.45][i]
                    let live = phase == .listening || phase == .unavailable
                    Capsule()
                        .fill(phase == .heard ? model.accentColor : (live ? ink.primary : ink.tertiary))
                        .frame(width: 4, height: 6 + 22 * (phase == .heard ? bell * 0.5 : model.micLevel * bell))
                }
            }
            .frame(height: 30)
            .animation(.linear(duration: 0.08), value: model.micLevel)
            Text("“\(Copy.micLine)”")
                .font(.system(size: 22, weight: .medium, design: OT.Board.titleDesign))
                .foregroundStyle(phase == .listening || phase == .unavailable ? ink.primary : ink.secondary)
            Spacer(minLength: 0)
            if phase == .listening || phase == .unavailable {
                ProgressView(value: min(1, model.micVoiced / OT.Mic.heardSeconds))
                    .progressViewStyle(.linear)
                    .tint(model.accentColor)
                    .frame(width: 90)
            } else if phase == .heard {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(model.accentColor)
            }
        }
    }
}

/// A key, drawn like a Mac's, filled the instant it's pressed (Fovea doesn't animate a highlight).
struct KeyCap: View {
    let label: String
    let lit: Bool
    let accent: Color
    var dark = false
    var large = false

    var body: some View {
        let h = large ? OT.Layout.largeKeyCapHeight : OT.Layout.keyCapHeight
        let w = large ? OT.Layout.largeKeyCapMinWidth : OT.Layout.keyCapMinWidth
        let r = large ? OT.Layout.largeKeyCapRadius : OT.Layout.keyCapRadius
        Text(label)
            .font(large ? OT.Type_.largeKeyCap : OT.Type_.keyCap)
            .foregroundStyle(lit ? (dark ? OT.Colors.islandOnSolid : OT.Colors.keyCapLitText) : (dark ? OT.Colors.islandText : OT.Colors.ink(0.8)))
            .padding(.horizontal, label.count > 2 ? 10 : 0)
            .frame(minWidth: w, minHeight: h)
            .background(RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(lit ? (dark ? OT.Colors.islandSolid : accent) : (dark ? OT.Colors.islandFill : OT.Colors.keyCap)))
            .overlay(RoundedRectangle(cornerRadius: r, style: .continuous)
                .strokeBorder(dark ? OT.Colors.islandHairline : OT.Colors.ink(0.14)))
            .shadow(color: OT.Colors.keyCapShadow.opacity(dark || lit ? 0 : 1), radius: 0, y: 1.5)
    }
}

/// Said when the real agent couldn't do it and the practice one did: never hidden.
struct AgentNote: View {
    let model: OnboardingModel
    @Environment(\.boardInk) private var ink

    var body: some View {
        if let note = model.agentNote {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle").font(.system(size: 12)).foregroundStyle(ink.secondary)
                Text(note).font(.system(size: 12)).foregroundStyle(ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Your coding agents (Oct 9, round two): the ones Fovea connects (Claude Code and Codex), each on
/// when it's on this Mac; nothing to sign in to. Then the ones to come, and a say in which is next.
struct AgentsView: View {
    let model: OnboardingModel
    @State private var other = ""
    @Environment(\.boardInk) private var ink

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 0) {
                ForEach(Agent.supported, id: \.self) { agent in
                    let found = model.flow.agents.contains(agent)
                    row(agent, found: found)
                    if agent != Agent.supported.last { Rectangle().fill(ink.hairline).frame(height: 1).padding(.leading, 54) }
                }
            }
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ink.fill))
            // What comes next, centered under the list (Oct 9).
            VStack(alignment: .center, spacing: 10) {
                Text(Copy.agentsNext).font(.system(size: 13, weight: .medium)).foregroundStyle(ink.secondary)
                    .frame(maxWidth: .infinity)
                FlowRow(spacing: 6, centered: true) {
                    ForEach(Agent.comingNext, id: \.self) { name in
                        wish(name)
                    }
                    ForEach(model.flow.agentWishes.filter { !Agent.comingNext.contains($0) }, id: \.self) { name in
                        wish(name)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold)).foregroundStyle(ink.tertiary)
                        TextField(Copy.agentsOther, text: $other)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(ink.primary)
                            .frame(width: 90)
                            .onSubmit {
                                model.toggleWish(other)
                                other = ""
                            }
                    }
                    .padding(.horizontal, 10).frame(height: 28)
                    .background(Capsule().strokeBorder(ink.hairline))
                }
            }
        }
    }

    private func row(_ agent: Agent, found: Bool) -> some View {
        HStack(spacing: 12) {
            Group {
                if let icon = AgentIcon.image(agent.name) {
                    Image(nsImage: icon).resizable()
                } else {
                    Image(systemName: "sparkles").font(.system(size: 15, weight: .semibold)).foregroundStyle(ink.primary)
                }
            }
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(ink.fill))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .opacity(found ? 1 : 0.5)
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(found ? ink.primary : ink.secondary)
                Text(found ? Copy.agentOnThisMac : Copy.agentNotInstalled).font(.system(size: 12)).foregroundStyle(ink.secondary)
            }
            Spacer()
            if found {
                let on = model.agentsOn.contains(agent)
                Button(action: { model.toggleAgent(agent) }) {
                    Capsule().fill(on ? model.accentColor : ink.fill)
                        .frame(width: 34, height: 20)
                        .overlay(alignment: on ? .trailing : .leading) {
                            Circle().fill(OT.Colors.knobEdge).frame(width: 16, height: 16).padding(2)
                        }
                }
                .buttonStyle(.plain)
                .animation(OT.Motion.content, value: on)
                .accessibilityLabel(agent.name)
                .accessibilityValue(on ? L("Switched on") : L("Switched off"))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
    }

    private func wish(_ name: String) -> some View {
        let on = model.flow.agentWishes.contains(name)
        return Button(action: { model.toggleWish(name) }) {
            HStack(spacing: 5) {
                if on { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
                Text(name).font(.system(size: 12, weight: on ? .semibold : .medium))
            }
            .foregroundStyle(on ? ink.buttonText : ink.secondary)
            .padding(.horizontal, 11).frame(height: 28)
            .background(Capsule().fill(on ? ink.button : ink.fill))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .playTarget(name == Agent.comingNext.first ? .agentWish : nil, model)
    }
}

/// Bringing your words (Oct 9, round two): one click for the dictation apps that keep them on this
/// Mac (Wispr Flow), a paste for the ones that keep them online, and for
/// anything else a paste or a file. The words to look over, each ticked, before they're added.
struct DictionaryImportView: View {
    let model: OnboardingModel
    @State private var targeted = false
    @Environment(\.boardInk) private var ink

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            let apps = model.dictationApps.filter { !$0.isSystem }
            if !apps.isEmpty {
                VStack(spacing: 0) {
                    ForEach(apps, id: \.self) { app in
                        appRow(app)
                        if app != apps.last { Rectangle().fill(ink.hairline).frame(height: 1).padding(.leading, 54) }
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ink.fill))
            }
            if model.importCandidates.isEmpty {
                HStack(spacing: 10) {
                    Text(Copy.importOther).font(.system(size: 12.5)).foregroundStyle(ink.secondary)
                    Spacer(minLength: 0)
                    smallButton(Copy.importPaste) { paste() }
                    smallButton(Copy.importChoose) { choose() }
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(targeted ? model.accentColor : ink.hairline,
                                                                                              style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])))
                .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
                    drop(providers)
                    return true
                }
                if let message = model.importMessage {
                    Text(message).font(.system(size: 11.5)).foregroundStyle(ink.tertiary)
                }
            } else {
                preview
            }
        }
    }

    private func appRow(_ app: DictationApp) -> some View {
        HStack(spacing: 12) {
            Group {
                if let icon = DictationAppDetector.icon(app) {
                    Image(nsImage: icon).resizable()
                } else {
                    Image(systemName: "waveform").font(.system(size: 14, weight: .semibold)).foregroundStyle(ink.primary)
                }
            }
            .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(ink.primary)
                if !app.connects {
                    Text(app.howTo).font(.system(size: 12)).foregroundStyle(ink.secondary)
                }
            }
            Spacer()
            if app.connects {
                Button(action: { model.connect(app) }) {
                    Text(Copy.importConnect(app))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(ink.buttonText)
                        .padding(.horizontal, 14).frame(height: 30)
                        .background(Capsule().fill(ink.button))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .playTarget(app == .wisprFlow ? .connectApp : nil, model)
            } else {
                smallButton(Copy.importPaste) { paste() }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(model.importChosen.count) of \(model.importCandidates.count) words").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ink.primary)
                if let message = model.importMessage {
                    Text("· \(message)").font(.system(size: 12)).foregroundStyle(ink.tertiary)
                }
                Spacer()
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6, alignment: .leading), count: 3), alignment: .leading, spacing: 6) {
                ForEach(model.importCandidates.prefix(OT.Board.importShown), id: \.word) { word in
                    let on = model.importChosen.contains(word.word)
                    Button(action: { model.toggleImport(word.word) }) {
                        HStack(spacing: 6) {
                            Image(systemName: on ? "checkmark.square.fill" : "square")
                                .foregroundStyle(on ? model.accentColor : ink.tertiary)
                            Text(word.word).foregroundStyle(on ? ink.primary : ink.tertiary).lineLimit(1)
                        }
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if model.importCandidates.count > OT.Board.importShown {
                Text("and \(model.importCandidates.count - OT.Board.importShown) more").font(.system(size: 11.5)).foregroundStyle(ink.tertiary)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ink.fill))
    }

    private func smallButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(ink.primary)
                .padding(.horizontal, 12).frame(height: 28)
                .background(Capsule().strokeBorder(ink.hairline))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = ["csv", "txt", "json", "plist", "tsv"].compactMap { UTType(filenameExtension: $0) }
        panel.allowsMultipleSelection = false
        panel.message = L("Choose the words you exported from another dictation app.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.importFile(url)
    }

    private func paste() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            model.importMessage = L("Copy your words first, then paste them here.")
            return
        }
        model.importPasted(text)
    }

    private func drop(_ providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                DispatchQueue.main.async { MainActor.assumeIsolated { model.importFile(url) } }
            }
        }
    }
}

/// The first two steps' one box each: the email to sign in with, then the name to be called by.
/// Return goes on. (1.0 has no account server yet: the email is kept on this Mac, for Settings ›
/// Account.)
struct AccountField: View {
    enum Kind { case email, name }
    let model: OnboardingModel
    let kind: Kind
    @FocusState private var focused: Bool
    @Environment(\.boardInk) private var ink

    var body: some View {
        let binding = kind == .email
            ? Binding(get: { model.typedEmail }, set: { model.typedEmail = $0 })
            : Binding(get: { model.typedName }, set: { model.typedName = $0 })
        VStack(spacing: 8) {
            // Apple, Google and the "or" are the sign-up page's (SignInView, Oct 15 review).
            TextField(kind == .email ? "you@example.com" : "Your name", text: binding)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(ink.primary)
                .multilineTextAlignment(.center)
                .textContentType(kind == .email ? .emailAddress : .name)
                .focused($focused)
                .onSubmit { model.continueTapped() }
                .padding(.horizontal, 14)
                .frame(width: 260, height: 30)
                .background(Capsule().fill(ink.fill))
                .overlay(Capsule().strokeBorder(model.accentColor.opacity(focused ? 0.8 : 0.3)))
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }
}

/// Oct 15 review, FR-03, FR-04, AC-01.1, AC-01.2: signing up, as it goes. Apple, Google or an email;
/// then waiting on Apple or Google (Cancel), canceled (the choices again, a quiet line), failed (Try
/// Again), a link to check for (Resend after a countdown, a different email), and signed in. 1.0 has
/// no account server: Apple, Google and the link are simulated (OnboardingModel.signUp), and what's
/// kept stays on this Mac.
struct SignInView: View {
    let model: OnboardingModel
    @Environment(\.boardInk) private var ink

    var body: some View {
        let B = OT.Board.self
        VStack(spacing: B.accountGap) {
            switch model.signInPhase {
            case .choosing, .canceled:
                choices
            case .waiting(let provider):
                waiting(provider)
            case .failed(let provider):
                failed(provider)
            case .checkEmail:
                checkEmail
            case .signedIn(let provider):
                signedIn(provider)
            }
        }
        .animation(OT.Motion.content, value: model.signInPhase)
    }

    // MARK: The choices

    private var choices: some View {
        VStack(spacing: OT.Board.accountGap) {
            // Oct 15 review, AC-01.1: Apple beside Google, the same size and weight (Apple's rule:
            // no smaller than the other ways in).
            provider(.apple, mark: Image(systemName: "apple.logo").font(.system(size: 13, weight: .semibold)))
            provider(.google, mark: Text("G").font(.system(size: 13, weight: .bold, design: .rounded)))
            HStack(spacing: 10) {
                Rectangle().fill(ink.hairline).frame(height: 1)
                Text("or").font(.system(size: 11.5)).foregroundStyle(ink.tertiary)
                Rectangle().fill(ink.hairline).frame(height: 1)
            }
            .frame(width: OT.Board.accountWidth)
            .padding(.vertical, 4)
            AccountField(model: model, kind: .email)
            if case .canceled = model.signInPhase {
                // FR-03: canceled, said quietly where the choices are.
                Text(Copy.signInCanceled)
                    .font(.system(size: 12)).foregroundStyle(ink.secondary)
                    .transition(.opacity)
            } else {
                Text(Copy.signInKept).font(.system(size: 12)).foregroundStyle(ink.tertiary)
            }
        }
    }

    private func provider(_ provider: AccountProvider, mark: some View) -> some View {
        Button(action: { model.signUp(with: provider) }) {
            HStack(spacing: 7) {
                mark
                Text(Copy.continueWith(provider)).font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(ink.primary)
            .frame(width: OT.Board.accountWidth, height: OT.Board.accountHeight)
            .background(Capsule().fill(ink.fill))
            .overlay(Capsule().strokeBorder(ink.hairline))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: Waiting, failed

    /// FR-03: Apple's or Google's own window has the person; the dot breathes (never a spinner).
    private func waiting(_ provider: AccountProvider) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 9) {
                BreathingDot(color: model.accentColor)
                Text(Copy.signInWaiting(provider)).font(.system(size: 14, weight: .medium)).foregroundStyle(ink.primary)
            }
            quietButton(Copy.signInCancel) { model.cancelSignIn() }
        }
        .frame(minHeight: 120)
    }

    /// FR-04: it didn't work. Say why it might not have, and Try Again.
    private func failed(_ provider: AccountProvider) -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.circle").font(.system(size: 13)).foregroundStyle(ink.secondary)
                Text(Copy.signInFailed).font(.system(size: 13.5)).foregroundStyle(ink.primary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 14) {
                quietButton(Copy.signInCancel) { model.cancelSignIn() }
                solidButton(Copy.signInTryAgain) { model.retrySignIn() }
            }
        }
        .frame(minHeight: 120)
    }

    // MARK: The email's link

    /// AC-01.2: a link sent; Resend held back with a countdown; a different email.
    private var checkEmail: some View {
        VStack(spacing: 14) {
            Image(systemName: "envelope.badge").font(.system(size: 28, weight: .light)).foregroundStyle(model.accentColor)
            HStack(spacing: 14) {
                let ready = model.resendLeft == 0
                Button(action: { model.resendEmail() }) {
                    Text(ResendCountdown.label(secondsLeft: model.resendLeft))
                        .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                        .foregroundStyle(ready ? ink.primary : ink.tertiary)
                        .padding(.horizontal, 14).frame(height: 28)
                        .background(Capsule().strokeBorder(ink.hairline))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!ready)
                .help(ready ? "" : "You can send it again in a moment.")
                quietButton(Copy.signInDifferentEmail) { model.useDifferentEmail() }
            }
            if let note = model.signInNote {
                Text(note).font(.system(size: 12)).foregroundStyle(ink.tertiary).transition(.opacity)
            }
        }
    }

    // MARK: Signed in

    private func signedIn(_ provider: AccountProvider) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundStyle(model.accentColor)
                Text(Copy.signedIn(provider, email: model.flow.email)).font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ink.primary)
            }
            // Come back to with Back (OB-01.7): another way in, if wanted.
            if model.flow.revisited {
                quietButton(Copy.signInDifferentAccount) { model.useDifferentAccount() }
            }
        }
        .frame(minHeight: 60)
    }

    private func quietButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12.5, weight: .medium)).foregroundStyle(ink.secondary)
                .padding(.horizontal, 6).frame(height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func solidButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(ink.buttonText)
                .padding(.horizontal, 16).frame(height: 28)
                .background(Capsule().fill(ink.button))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Running, never a spinner: a dot that breathes (OT.Motion.breathe).
struct BreathingDot: View {
    let color: Color
    @State private var on = false

    var body: some View {
        Circle().fill(color)
            .frame(width: OT.Board.waitingDot, height: OT.Board.waitingDot)
            .opacity(on ? 1 : 0.3)
            .onAppear { withAnimation(OT.Motion.breathe) { on = true } }
    }
}

/// Oct 15 review, OB-01.6: what Fovea remembers, in four short points before the end: what's kept,
/// where, who reads it, and that it's yours. Continue marks it read (`memoryDisclosureSeen`).
struct MemoryPoints: View {
    let model: OnboardingModel
    @Environment(\.boardInk) private var ink

    /// One symbol a point, in the order of `Copy.memoryPoints`.
    private static let symbols = ["text.bubble", "laptopcomputer", "person.2", "hand.raised"]

    var body: some View {
        let B = OT.Board.self
        VStack(alignment: .leading, spacing: B.memoryGap) {
            ForEach(Array(Copy.memoryPoints.enumerated()), id: \.offset) { i, point in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: Self.symbols[min(i, Self.symbols.count - 1)])
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(model.accentColor)
                        .frame(width: B.memoryIcon, height: B.memoryIcon)
                        .background(Circle().fill(ink.fill))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(point.title).font(B.memoryTitle).foregroundStyle(ink.primary)
                        Text(point.detail).font(B.memoryDetail).foregroundStyle(ink.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(width: B.memoryWidth)
    }
}

/// "Clear my screen" (asked, Oct 9): the other apps hide for the tour, so only Fovea's practice
/// windows are on screen, and exactly those apps come back at the end. Never done without asking,
/// so a call or a document isn't hidden by surprise.
struct ClearScreen: View {
    let model: OnboardingModel
    @Environment(\.boardInk) private var ink

    var body: some View {
        // Set apart in a card of its own, the accent on its button (Oct 9, late: it went unseen).
        let accent = model.accentColor
        VStack(spacing: 12) {
            Text(model.screenCleared ? "Your screen is clear" : "Start on a clear screen")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ink.primary)
            Text(model.screenCleared ? "Your apps and the desktop's icons come back when the tour ends."
                 : "For the tour, Fovea shows you around on a clear screen, so your other apps and the desktop's icons hide for now. They'll come back when the tour ends.")
                .font(.system(size: 12)).foregroundStyle(ink.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
                .fixedSize(horizontal: false, vertical: true)
            if !model.screenCleared {
                Button(action: { model.clearScreen() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.dashed").font(.system(size: 11, weight: .bold))
                        Text("Clear my screen")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16).frame(height: 30)
                    .background(Capsule().fill(accent))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 18)
        .frame(maxWidth: 400)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(accent.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(accent.opacity(0.45), lineWidth: 1))
    }
}

/// The last board (Oct 9, round two): three things, each with room around it (Oct 9, evening).
/// Next time, start from the notch; eye tracking is in beta, with a way to request it; and Open at
/// login.
struct Closing: View {
    let model: OnboardingModel
    @Environment(\.boardInk) private var ink

    var body: some View {
        VStack(spacing: 0) {
            part(symbol: "rectangle.topthird.inset.filled", text: Copy.homeNotch)
            VStack(spacing: 10) {
                part(symbol: "eye", text: Copy.eyeTrackingTitle)
                Button(action: { model.askEyeTracking() }) {
                    HStack(spacing: 6) {
                        if model.eyeTrackingAsked { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)) }
                        Text(model.eyeTrackingAsked ? Copy.eyeTrackingAsked : Copy.eyeTrackingAsk)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ink.primary)
                    .padding(.horizontal, 14).frame(height: 26)
                    .background(Capsule().strokeBorder(ink.hairline))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(model.eyeTrackingAsked)
                .playTarget(.eyeTracking, model)
            }
            .padding(.top, OT.Board.closingGap)
            // Open at login: on unless turned off here (or in Settings › Account).
            HStack(spacing: 10) {
                Text("Open Fovea at login").font(.system(size: 12, weight: .medium)).foregroundStyle(ink.primary)
                SmallSwitch(on: model.openAtLogin, accent: model.accentColor) { model.setOpenAtLogin(!model.openAtLogin) }
                    .accessibilityLabel("Open Fovea at login")
            }
            .padding(.top, OT.Board.closingGap)
        }
        .frame(maxWidth: .infinity)
    }

    private func part(symbol: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(model.accentColor)
            Text(text).font(.system(size: 14, weight: .medium)).foregroundStyle(ink.primary)
        }
    }
}

/// A switch drawn by Fovea, a size smaller than the system's, in the accent whether or not the
/// window is the key one (the system's goes gray in a window that isn't, and read as off: Oct 9).
struct SmallSwitch: View {
    let on: Bool
    let accent: Color
    let toggle: () -> Void
    @Environment(\.boardInk) private var ink

    var body: some View {
        Button(action: toggle) {
            Capsule().fill(on ? accent : ink.fill)
                .overlay(Capsule().strokeBorder(on ? Color.clear : ink.hairline))
                .frame(width: 28, height: 16)
                .overlay(alignment: on ? .trailing : .leading) {
                    Circle().fill(OT.Colors.knobEdge).frame(width: 12, height: 12).padding(2)
                        .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(OT.Motion.content, value: on)
        .accessibilityValue(on ? L("Switched on") : L("Switched off"))
        .accessibilityAddTraits(.isButton)
    }
}

struct MuteButton: View {
    let model: OnboardingModel
    @State private var muted = false
    @Environment(\.boardInk) private var ink

    var body: some View {
        Button(action: {
            muted.toggle()
            model.sound.muted = muted
        }) {
            Image(systemName: muted ? "speaker.slash" : "speaker.wave.2")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ink.tertiary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help(muted ? "Sound on" : "Mute")
    }
}

/// Help, the way past the step, and the one button. Every step has a way past (Oct 8). The button
/// dims while the step isn't done but is never disabled by the view: the click reaches the model,
/// which decides (Oct 9).
struct BoardActions: View {
    let model: OnboardingModel
    var centered = false
    var large = false
    var showHelp = true
    @State private var helpOpen = false
    @Environment(\.boardInk) private var ink

    private var title: String {
        switch model.step {
        case .dictionary:
            let n = model.importChosen.count
            return n > 0 ? (n == 1 ? L("Add 1 word") : L("Add \(n) words")) : model.copy.button
        case .agents:
            return model.connectedAgents.isEmpty ? L("Use the practice agent") : model.copy.button
        // Come back to with Back, heard already (Oct 17, Ryan).
        case .microphone where model.micPhase == .heard:
            return L("Continue")
        default:
            return model.copy.button
        }
    }

    private var enabled: Bool {
        switch model.step {
        case .signIn: model.signInPhase.isSignedIn || OnboardingModel.isEmail(model.typedEmail)
        case .name: !model.typedName.trimmingCharacters(in: .whitespaces).isEmpty
        case .agents: true
        case .microphone: model.micPhase == .waiting || (model.micPhase == .heard && model.flow.isComplete)
        case .dictionary: !model.importChosen.isEmpty
        default: model.flow.isComplete
        }
    }

    var body: some View {
        let copy = model.copy
        HStack(spacing: 14) {
            if showHelp, !centered, let help = copy.help {
                // Help, small and plainly a link: nothing like the line to say.
                Button(action: { helpOpen.toggle() }) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Image(systemName: "questionmark.circle").font(.system(size: 11))
                        Text(helpOpen ? help : L("Not working?"))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(ink.tertiary)
                }
                .buttonStyle(.plain)
            }
            if !centered { Spacer(minLength: 0) }
            if model.step.skip.allowed, model.skipShown {
                Button(copy.skipLabel) { model.skipTapped() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ink.secondary)
                    .help(copy.skipNote ?? "")
                    .transition(.opacity)
                    .playTarget(.skip, model)
            }
            if model.guideButtonShown {
                Button(action: { model.continueTapped() }) {
                    Text(title)
                        .font(large ? .system(size: 13, weight: .semibold) : OT.Type_.guideButton)
                        .foregroundStyle(ink.buttonText)
                        .padding(.horizontal, large ? 20 : 14)
                        .frame(height: large ? 32 : 28)
                        .background(Capsule().fill(enabled ? ink.button : ink.button.opacity(0.25)))
                }
                .buttonStyle(.plain)
                .playTarget(.guideButton, model)
                .help(enabled ? "" : "Do the step first")
            }
        }
        .animation(OT.Motion.calm, value: model.skipShown)
        .animation(OT.Motion.calm, value: model.flow.isComplete)
    }
}

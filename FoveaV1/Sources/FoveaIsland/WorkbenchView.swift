import SwiftUI
import AppKit
import FoveaKit

/// The window: the control panel on the left as a real sidebar column, the mock desktop as
/// the detail. The split view supplies the sidebar material, the divider drag, the collapse
/// past the minimum and the toolbar's toggle button; ⌃⌘S comes from `SidebarCommands`.
struct WorkbenchView: View {
    @Bindable var model: WorkbenchModel

    var body: some View {
        NavigationSplitView(columnVisibility: $model.columnVisibility) {
            ControlPanel(model: model)
                // The width trait must be the column root's outermost modifier.
                .navigationSplitViewColumnWidth(min: WorkbenchTokens.Layout.sidebarMin,
                                                ideal: WorkbenchTokens.Layout.sidebarIdeal,
                                                max: WorkbenchTokens.Layout.sidebarMax)
        } detail: {
            MockDesktopView(model: model)
                .toolbar {
                    ToolbarItem(placement: .principal) { DesignSwitch(model: model) }
                    ToolbarItem(placement: .primaryAction) { DensitySwitch(model: model) }
                }
        }
        .frame(minWidth: WorkbenchTokens.Layout.windowMin.width,
               minHeight: WorkbenchTokens.Layout.windowMin.height)
        .onChange(of: model.columnVisibility) { _, _ in model.rememberSidebar() }
        .onChange(of: model.appearance) { _, _ in model.rememberDisplay() }
        .onChange(of: model.wallpaperChoice) { _, _ in model.rememberDisplay() }
        .onChange(of: model.screenContent) { _, _ in model.rememberDisplay() }
        // SwiftUI keeps its windows out of the Window menu; a native window is listed there.
        .background(WindowAccessor { window in
            window.isExcludedFromWindowsMenu = false
            // The hover's pointer moves reach the app while it is in front.
            window.acceptsMouseMovedEvents = true
        })
    }
}

/// The open panels' room, in the window's toolbar so it is always in reach: Compact (the panels
/// as through Oct 6) or Spacious (docs/island/SPACIOUS.md). View › Compact (⌘1) and Spacious (⌘2)
/// switch it too.
struct DensitySwitch: View {
    @Bindable var model: WorkbenchModel

    var body: some View {
        Picker("Density", selection: $model.density) {
            ForEach(PanelDensity.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .help("How much room the notch's open panels take: Compact, as through Oct 6 (⌘1); Spacious, after the Mac's own sizes (⌘2)")
        .accessibilityLabel("Density")
    }
}

/// The notch's design, the window's two tabs (docs/island/NATIVE.md): Original, as drawn through
/// Oct 8; Native, the same states in the app's and the onboarding's language. View › Original
/// Design (⌥⌘1) and Native Design (⌥⌘2) switch it too.
struct DesignSwitch: View {
    @Bindable var model: WorkbenchModel

    var body: some View {
        Picker("Design", selection: $model.design) {
            ForEach(NotchDesign.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .help("The notch's design: Original, as drawn through Oct 8 (⌥⌘1); Native, the same states as the app and the onboarding draw them, a black island with Liquid Glass panels (⌥⌘2)")
        .accessibilityLabel("Design")
    }
}

/// Hands the hosting window to the root, for the AppKit properties SwiftUI does not expose.
struct WindowAccessor: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { if let window = view.window { configure(window) } }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window { configure(window) }
    }
}

/// The panel: a grouped form over the sidebar material, the way System Settings lays out
/// controls. The Notch section holds one disclosure per flow, as an inspector's groups:
/// Voiceflow and Dispatch Version 2 (docs/island/FLOWS.md), each a list of its states; Esc
/// serves both. Voice glow below tunes Dispatch Version 2's aura.
struct ControlPanel: View {
    @Bindable var model: WorkbenchModel
    @State private var voiceflowOpen = true
    @State private var v2Open = true

    var body: some View {
        Form {
            FeedbackSection(model: model)
            Section("Notch") {
                DisclosureGroup("Voiceflow", isExpanded: $voiceflowOpen) {
                    Picker("Voiceflow", selection: $model.voiceflowSelection) {
                        ForEach(NotchMode.allCases) { Text($0.title).tag(Optional($0)) }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
                DisclosureGroup("Dispatch Version 2", isExpanded: $v2Open) {
                    Picker("Dispatch Version 2", selection: $model.v2Selection) {
                        ForEach(V2Mode.allCases) { Text($0.title).tag(Optional($0)) }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                    Picker("Request", selection: $model.v2Request) {
                        ForEach(V2Request.allCases) { Text($0.title).tag($0) }
                    }
                    .help("What is asked: a formula in a paper, the calendar, an email draft, a code change")
                    Button {
                        model.playV2()
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .help("Listens, suggests where it goes, sends, and follows it through. fn⌃ does it by hand")
                }
                Button {
                    _ = model.escape()
                } label: {
                    Label("Esc", systemImage: "escape")
                        .frame(maxWidth: .infinity)
                }
                .disabled(model.notchState == .silent)
                .help("Closes the innermost thing first (a close look, the opened stack, capture mode, the opened transcript, every chat); on Voiceflow's bar it cancels the request; Dispatch Version 2's states it dismisses")
            }
            Section("Voice glow") {
                Picker("Palette", selection: $model.glowPalette) {
                    ForEach(GlowPalette.allCases.filter { $0 != .custom }) { Text($0.title).tag($0) }
                    Divider()
                    Text(GlowPalette.custom.title).tag(GlowPalette.custom)
                }
                LabeledContent {
                    SpectrumSlider(value: $model.glowHue)
                } label: {
                    Text("Hue")
                    Text(model.glowPalette == .custom ? "\(Int(model.glowHue))°" : "+\(Int(model.glowHue))°")
                        .monospacedDigit()
                }
                .help(model.glowPalette == .custom ? "The hue the custom colors fan out from" : "Turns the palette around the color wheel")
                LabeledContent {
                    Slider(value: $model.glowSpread, in: 0...360)
                } label: {
                    Text("Spread")
                    Text("\(Int(model.glowSpread))°").monospacedDigit()
                }
                .disabled(model.glowPalette != .custom)
                .help("How far the seven custom colors fan across the wheel: 0° is one color, 360° a full spectrum")
                Toggle("Hue drift", isOn: $model.glowDrift)
                    .help("The package's slow wander of ±24° over 12 s")
                GlowSwatches(colors: VoiceGlowRenderer.swatches(look: model.glowLook))
            }
            if model.design == .native {
                // Native's panels: hanging from the top edge as Original's island does, or floating
                // a gap under the notch (docs/island/NATIVE.md).
                Section("Native panels") {
                    Picker("Panels", selection: $model.nativePanels) {
                        ForEach(NativePanels.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .help("Attached: one glass shape hanging from the top edge, as Original's island. Floating: a glass panel a gap under the notch, as Control Center")
                }
            }
            Section("Fovea accent") {
                AccentPicker(accent: $model.accent)
            }
            Section("Screen") {
                Picker("Screen", selection: $model.screenContent) {
                    ForEach(MockScreenContent.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Section("Appearance") {
                Picker("Appearance", selection: $model.appearance) {
                    ForEach(MockAppearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            Section("Background") {
                Picker("Background", selection: $model.wallpaperChoice) {
                    Text(WallpaperChoice.system.title).tag(WallpaperChoice.system)
                    Divider()
                    ForEach(Wallpaper.photos, id: \.self) { name in
                        Text(WallpaperChoice.photo(name).title).tag(WallpaperChoice.photo(name))
                    }
                    Divider()
                    ForEach(WallpaperColor.allCases) { color in
                        Text(color.title).tag(WallpaperChoice.color(color))
                    }
                    if case .file(let url) = model.wallpaperChoice {
                        Divider()
                        Text(url.lastPathComponent).tag(WallpaperChoice.file(url))
                    }
                }
                .labelsHidden()
                Button("Choose Image…") { model.chooseWallpaperFile() }
            }
            .disabled(model.screenContent != .desktop)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

/// The dev team's feedback of Oct 6, one tab per item that has something to see; each stages the
/// mock display for it, live from there (docs/island/FEEDBACK_2026-10-06.md).
struct FeedbackSection: View {
    @Bindable var model: WorkbenchModel
    @State private var open = true

    var body: some View {
        Section {
            DisclosureGroup("Feedback · Oct 6", isExpanded: $open) {
                Picker("Feedback", selection: Binding(get: { model.feedbackSelection },
                                                      set: { if let item = $0 { model.stageFeedback(item) } })) {
                    ForEach(FeedbackItem.allCases) { Text($0.title).tag(Optional($0)) }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                if let item = model.feedbackSelection { controls(item) }
                Text("Set aside: 5, 18, 20, 21, 22. #16: the board no longer shows an activity line. Research: 14.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func controls(_ item: FeedbackItem) -> some View {
        switch item {
        case .modelEffort:
            Picker("Stage", selection: $model.feedbackModelStage) {
                ForEach(ModelStage.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: model.feedbackModelStage) { _, _ in model.restageFeedback() }
        case .errors:
            Picker("Error", selection: $model.feedbackErrorChoice) {
                ForEach(VoiceError.allCases) { Text($0.menuTitle).tag($0) }
            }
            .onChange(of: model.feedbackErrorChoice) { _, _ in model.restageFeedback() }
        case .textFiles:
            Picker("Stage", selection: $model.feedbackSelectStage) {
                ForEach(SelectStage.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: model.feedbackSelectStage) { _, _ in model.restageFeedback() }
            Text("On the bar: Option is the highlighter (drag across words, or click a paragraph or a desktop file); ⌘ takes a screenshot, twice the whole screen.")
                .font(.caption).foregroundStyle(.secondary)
        case .countdown:
            Picker("Stage", selection: $model.feedbackCountdownStage) {
                ForEach(CountdownStage.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: model.feedbackCountdownStage) { _, _ in model.restageFeedback() }
        case .splitView:
            playButton("Play", help: "Mail, then Messages under the pointer; the words land there") { model.playSplitDemo() }
            Text("Move the pointer between the two apps while the bar listens; fn lands the words in the one under it.")
                .font(.caption).foregroundStyle(.secondary)
        case .landing:
            playButton("Play again", help: "Transcribe, land the words, the notch leaves") { model.restageFeedback() }
        case .progress:
            Picker("Design", selection: $model.boardStyle) {
                ForEach(BoardStyle.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            Text(model.boardStyle.caption)
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.boardStyle.hasPets {
                Toggle("Pet at rest beside the notch", isOn: $model.petAtRest)
                    .help("While the island rests: the pet of the session most in need in a small black circle at the notch's right; point at it to open the board")
            }
        case .answer:
            Picker("Request", selection: $model.v2Request) {
                ForEach(V2Request.allCases) { Text($0.title).tag($0) }
            }
            .onChange(of: model.v2Request) { _, _ in model.restageFeedback() }
            Picker("Stage", selection: $model.feedbackWorkStage) {
                ForEach(WorkStage.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: model.feedbackWorkStage) { _, _ in model.restageFeedback() }
            Toggle("Session expanded", isOn: Binding(get: { model.v2Expanded }, set: { _ in model.toggleV2Expanded() }))
                .disabled(model.notchState != .v2Chat || model.feedbackWorkStage != .done)
                .help("The whole session, every request in it, with what the agent did folded under each answer: its expand button in the header, or left ⌃; Esc steps back")
        case .titles:
            Picker("Request", selection: $model.v2Request) {
                ForEach(V2Request.allCases) { Text($0.title).tag($0) }
            }
            playButton("Send again", help: "A new chat: its request's words, then its name") { model.restageFeedback() }
        case .steps:
            Picker("Stage", selection: $model.feedbackStepsStage) {
                ForEach(StepsStage.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: model.feedbackStepsStage) { _, _ in model.restageFeedback() }
            Text("While an agent works, one step at a time: what it is doing and to what, as Codex and Claude Code report it; an edit's lines and a command's outcome when the step ends.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .skipReview:
            Toggle("Review the words first", isOn: $model.v2ReviewBeforeSend)
                .help("The setting: on (default), Choose chat shows the words; off, the bar's icon chooses the chat, model and effort")
            Toggle("Chat and model open", isOn: $model.feedbackRouteOpen)
                .disabled(model.v2ReviewBeforeSend)
                .onChange(of: model.feedbackRouteOpen) { _, _ in model.restageFeedback() }
            playButton("Play", help: "Listens, transcribes, sends, the board shows it on its way") { model.playV2() }
        case .reanswer:
            Picker("Stage", selection: $model.feedbackWorkStage) {
                ForEach(WorkStage.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: model.feedbackWorkStage) { _, _ in model.restageFeedback() }
        case .queue:
            Picker("Stage", selection: $model.feedbackQueueStage) {
                ForEach(QueueStage.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: model.feedbackQueueStage) { _, _ in model.restageFeedback() }
        }
    }

    private func playButton(_ title: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "play.fill").frame(maxWidth: .infinity)
        }
        .help(help)
    }
}

/// A hue slider over the color wheel's spectrum, as the system color panel draws one: the track
/// is every hue, the thumb wears the hue it is on. 0–360 degrees.
struct SpectrumSlider: View {
    @Binding var value: Double

    var body: some View {
        let T = WorkbenchTokens.VoiceGlow.self
        GeometryReader { geo in
            let travel = max(1, geo.size.width - T.thumbSize)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: stride(from: 0.0, through: 360, by: 30).map { Color(hue: $0 / 360, saturation: 0.8, brightness: 1) },
                                         startPoint: .leading, endPoint: .trailing))
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
                    .frame(height: T.trackHeight)
                    .padding(.horizontal, T.thumbSize / 2 - T.trackHeight / 2)
                Circle()
                    .fill(Color(hue: value / 360, saturation: 0.8, brightness: 1))
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
                    .frame(width: T.thumbSize, height: T.thumbSize)
                    .offset(x: travel * CGFloat(value / 360))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                value = Double(max(0, min(1, (drag.location.x - T.thumbSize / 2) / travel))) * 360
            })
        }
        .frame(height: T.thumbSize + 4)
        .accessibilityElement()
        .accessibilityLabel("Hue")
        .accessibilityValue("\(Int(value)) degrees")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(360, value + 10)
            case .decrement: value = max(0, value - 10)
            @unknown default: break
            }
        }
    }
}

/// The glow's seven colors as it shows them, left to right across the bar.
struct GlowSwatches: View {
    let colors: [Color]

    var body: some View {
        let T = WorkbenchTokens.VoiceGlow.self
        let order = [5, 3, 1, 0, 2, 4, 6].filter { $0 < colors.count }
        HStack(spacing: T.swatchSpacing) {
            ForEach(order, id: \.self) { i in
                Circle()
                    .fill(colors[i])
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
                    .frame(width: T.swatchSize, height: T.swatchSize)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityLabel("The glow's colors")
    }
}

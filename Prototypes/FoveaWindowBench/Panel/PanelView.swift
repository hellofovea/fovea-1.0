import SwiftUI
import WindowBenchCore

/// The bench's controls, a grouped form like the Notch Workbench's. Design switches come from
/// the variant registry; Play replays a motion from its start; Go to puts a state on screen.
struct PanelView: View {
    @Environment(BenchModel.self) private var model
    @State private var open: Set<String> = ["play", "global", "go.projects"]
    @State private var notes = true

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            if model.state.panelCollapsed {
                collapsedBar
            } else {
                Form {
                    Section {
                        Toggle("Explain each option", isOn: $notes)
                            .help("Shows what the chosen option is and where it comes from")
                    }
                    goTo
                    play
                    design
                    motion
                    data
                    compare
                }
                .formStyle(.grouped)
                .controlSize(.small)
                if !model.status.isEmpty {
                    Text(model.status)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
            }
        }
        .frame(width: BenchTokens.Layout.panelWidth)
    }

    private var collapsedBar: some View {
        HStack {
            Text("Window Bench").font(.system(size: 12, weight: .semibold))
            Spacer()
            Button("Show controls") { model.state.panelCollapsed = false }
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
    }

    private func group<Content: View>(_ id: String, _ title: String, @ViewBuilder _ content: @escaping () -> Content) -> some View {
        DisclosureGroup(title, isExpanded: Binding(get: { open.contains(id) },
                                                   set: { if $0 { open.insert(id) } else { open.remove(id) } })) {
            content()
        }
    }

    // MARK: Go to

    private var goTo: some View {
        Section("Go to") {
            group("go.onboarding", "01 Onboarding") {
                ForEach(OnboardingStep.allCases, id: \.self) { step in
                    RowButton(step.title, current: model.state.onboarding == step) { model.goTo(onboarding: step) }
                }
                RowButton("Done: the project list", current: model.state.onboarding == nil) { model.finishOnboarding() }
            }
            group("go.projects", "02 Projects") {
                RowButton("Project list") { model.show([PathEntry(level: .projects)], section: .project); model.state.onboarding = nil }
                RowButton("Project page · fovea-site") { model.goToProject("p-site") }
                RowButton("Run receipt · bullets") { model.goToRun("r-bullets") }
                RowButton("Older projects open") { model.goToOlderOpen() }
            }
            group("go.settings", "03 Settings") {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    RowButton(tab.title) { model.openSettings(tab) }
                }
            }
            group("go.run", "04 Run detail") {
                ForEach(BenchModel.runStates, id: \.id) { item in
                    RowButton(item.title) { model.goToRun(item.id) }
                }
            }
            group("go.search", "05 Search") {
                RowButton("Field open") { model.goToSearch(nil) }
                RowButton("Results for 第二屏") { model.goToSearch("第二屏") }
                RowButton("Results for Second.tsx") { model.goToSearch("Second.tsx") }
                RowButton("No results") { model.goToSearch("kubernetes") }
            }
            group("go.captures", "06 Captures") {
                RowButton("Stream") { model.show([PathEntry(level: .captures)], section: .capture) }
                RowButton("Screenshot detail") { model.goToCapture("c-site-shot") }
                RowButton("Voice-only detail") { model.goToCapture("c-hero-voice") }
            }
            group("go.polish", "07 Polish") {
                RowButton("Settings › Memory") { model.openSettings(.memory) }
                RowButton("Settings › Notch") { model.openSettings(.notch) }
                RowButton("Correct an inference") { model.playCorrection() }
                RowButton("Brief on fovea-site") { model.playBrief() }
            }
        }
    }

    // MARK: Play

    private var play: some View {
        Section {
            group("play", "Play") {
                PlayButton("Replay the reveal", symbol: "list.bullet.indent") { model.runPlay("reveal") }
                PlayButton("Drill in, then out", symbol: "arrow.down.right.and.arrow.up.left") { model.runPlay("drill") }
                PlayButton("Roll the counts", symbol: "number") { model.runPlay("counts") }
                PlayButton("A run arrives waiting for you", symbol: "circle.fill") { model.runPlay("arrival") }
                PlayButton("A run finishes", symbol: "circle") { model.runPlay("finish") }
                PlayButton("A run fails", symbol: "exclamationmark.circle") { model.runPlay("fail") }
                PlayButton("A project changes group", symbol: "arrow.up.arrow.down") { model.runPlay("move") }
                PlayButton("Open / close earlier runs", symbol: "chevron.down") { model.runPlay("fold") }
                PlayButton("Earlier runs, one thread then another", symbol: "rectangle.stack") { model.runPlay("accordion") }
                PlayButton("Drill in, turned back halfway", symbol: "arrow.uturn.left") { model.runPlay("drillInterrupt") }
                PlayButton("Jump to a search result", symbol: "scope") { model.runPlay("jump") }
                PlayButton("Correct an inference", symbol: "text.cursor") { model.runPlay("correction") }
                PlayButton("\(model.verbs.takeMeThere) from the notch", symbol: "arrow.down.forward.square") { model.runPlay("takeMeThere") }
                PlayButton("Ask for a Brief", symbol: "text.quote") { model.runPlay("brief") }
                PlayButton("Hand-off to the notch", symbol: "arrow.up") { model.runPlay("handoff") }
                PlayButton("Install Cursor's hooks", symbol: "link") { model.runPlay("hooks") }
                PlayButton("A run finishes, on its page", symbol: "doc.text") { model.runPlay("runFinish") }
                PlayButton("A run fails, on its page", symbol: "doc.text.magnifyingglass") { model.runPlay("runFail") }
                PlayButton("Open a capture, then close it", symbol: "photo") { model.runPlay("captureOpen") }
                PlayButton("View in Project, then back to the capture", symbol: "arrow.left.arrow.right") { model.runPlay("captureJumps") }
                PlayButton("Switch the capture filters", symbol: "line.3.horizontal.decrease") { model.runPlay("filters") }
                PlayButton("Today view presets", symbol: "calendar") { model.runPlay("today") }
                PlayButton("Forget a memory, then Undo", symbol: "arrow.uturn.backward") { model.runPlay("forget") }
                Toggle("Record each Play as a GIF", isOn: Binding(get: { model.recordPlays }, set: { model.recordPlays = $0 }))
                    .help("Writes to ~/Desktop/fovea-app-refs/v2/bench-saves")
            }
        }
    }

    // MARK: Design

    private var design: some View {
        Section("Design") {
            group("global", BenchPage.global.title) {
                ForEach(Variants.decisions(on: .global).filter { $0.id != MotionSystem.id }) { decision in
                    DecisionRow(decision: decision, notes: notes)
                }
            }
            ForEach(BenchPage.allCases.filter { $0 != .global && !Variants.decisions(on: $0).isEmpty }, id: \.self) { page in
                group("design.\(page.rawValue)", page.title) {
                    ForEach(Variants.decisions(on: page)) { decision in
                        DecisionRow(decision: decision, notes: notes)
                    }
                }
            }
        }
    }

    // MARK: Motion

    private var motion: some View {
        @Bindable var model = model
        return Section("Motion") {
            DecisionRow(decision: MotionSystem.info, notes: notes)
            Picker("Speed", selection: $model.state.speed) {
                ForEach(BenchTokens.MotionValues.speeds, id: \.self) { speed in
                    Text(speed == 1 ? "1×" : speed == 0.5 ? "½×" : speed == 0.25 ? "¼×" : "⅒×").tag(speed)
                }
            }
            .pickerStyle(.segmented)
            .help("Slows every animation, wait and drawn clock together")
            LabeledContent {
                Slider(value: $model.state.revealStaggerMS, in: BenchTokens.MotionValues.revealRange, step: 10)
            } label: {
                Text("Reveal stagger")
                Text("\(Int(model.state.revealStaggerMS)) ms").monospacedDigit()
            }
            .help("Time between projects arriving in the onboarding reveal. The notch staggers 30 ms, capped at 6.")
            LabeledContent {
                Slider(value: $model.state.highlightSeconds, in: BenchTokens.MotionValues.highlightRange, step: 0.1)
            } label: {
                Text("Highlight holds")
                Text(String(format: "%.1f s", model.state.highlightSeconds)).monospacedDigit()
            }
            Toggle("Reduce Motion", isOn: $model.state.reduceMotion)
                .help("Simulates the accessibility setting: decorative motion stops, meaning-carrying motion becomes a cross-fade")
            if model.reduceMotionSystem {
                Text("Reduce Motion is on in System Settings.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Data

    private var data: some View {
        @Bindable var model = model
        return Section("Data") {
            Picker("Source", selection: Binding(get: { model.state.source }, set: { model.setSource($0) })) {
                ForEach(DataSource.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .help("This Mac lists your agents' history folders and reads file dates only; no session is opened")
            Picker("Fixture", selection: Binding(get: { model.state.fixture }, set: { model.loadFixture($0) })) {
                ForEach(FixtureSet.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .disabled(model.state.source == .thisMac)
            Picker("Appearance", selection: $model.state.appearance) {
                ForEach(BenchAppearance.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Picker("Window", selection: $model.state.windowSize) {
                ForEach(WindowSizePreset.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Toggle("Lab notch", isOn: $model.state.labNotch)
                .help("A black island at the real notch for the hand-off and 带我去. Off removes it.")
            Toggle("Another notch app running", isOn: $model.state.otherNotchApp)
                .help("Simulated: shows Connections' overlap notice")
            Picker("Calendar", selection: Binding(
                get: { model.state.calendarGranted ? 1 : (model.state.calendarDenied ? 2 : 0) },
                set: { v in model.state.calendarGranted = v == 1; model.state.calendarDenied = v == 2 })) {
                Text("Not asked").tag(0)
                Text("Allowed").tag(1)
                Text("Denied").tag(2)
            }
            .help("Simulated: no permission is requested")
            Toggle("fn starts Dictation", isOn: Binding(get: { model.simulateFnConflict }, set: { model.simulateFnConflict = $0 }))
                .help("Simulated: General's fn row shows its conflict")
            Toggle("Screen Recording allowed", isOn: Binding(get: { model.simulateScreenRecording }, set: { model.simulateScreenRecording = $0 }))
                .help("Simulated: a result in another app shows a live thumbnail instead of the dashed outline")
            Button("Start onboarding over") { model.goTo(onboarding: .consent) }
            HStack {
                Button("Show window") { model.showWindowHandler() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
    }

    // MARK: Compare

    private var compare: some View {
        @Bindable var model = model
        return Section("Compare") {
            Toggle("Notch beside the window", isOn: $model.state.compare)
                .help("Shows the notch's own rows (a workbench shot) next to the window, to judge them as one product")
            Button("Save a PNG of this state") { model.snapshotHandler() }
                .help("Writes to ~/Desktop/fovea-app-refs/v2/bench-saves")
            if !model.state.panelCollapsed {
                Button("Collapse this panel") { model.state.panelCollapsed = true }
            }
        }
    }
}

/// One decision: a menu of its options, and what the chosen one is.
struct DecisionRow: View {
    @Environment(BenchModel.self) private var model
    let decision: DecisionInfo
    let notes: Bool

    var body: some View {
        let current = model.state.variants[decision.id] ?? decision.defaultID
        let chosen = decision.options.first { $0.id == current } ?? decision.options[0]
        VStack(alignment: .leading, spacing: 3) {
            Picker(decision.title, selection: Binding(get: { current }, set: { model.setVariant(id: decision.id, option: $0) })) {
                ForEach(decision.options, id: \.id) { option in
                    Text(option.title + (option.id == decision.defaultID ? "" : "")).tag(option.id)
                }
            }
            .help(decision.help)
            if notes {
                Text(chosen.help)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A list-like button for Go to: left-aligned, a dot on the state that's showing.
struct RowButton: View {
    @Environment(BenchModel.self) private var model
    let title: String
    let current: Bool
    let action: () -> Void

    init(_ title: String, current: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.current = current; self.action = action
    }

    var body: some View {
        // The panel's clicks reach the window from outside its events: heal afterwards.
        Button { action(); model.heal() } label: {
            HStack(spacing: 6) {
                Image(systemName: current ? "circle.fill" : "circle")
                    .font(.system(size: 6))
                    .foregroundStyle(current ? .primary : .tertiary)
                Text(title)
                Spacer(minLength: 0)
            }
            .font(.system(size: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct PlayButton: View {
    @Environment(BenchModel.self) private var model
    let title: String
    let symbol: String
    let action: () -> Void

    init(_ title: String, symbol: String, action: @escaping () -> Void) {
        self.title = title; self.symbol = symbol; self.action = action
    }

    var body: some View {
        Button { action(); model.heal() } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

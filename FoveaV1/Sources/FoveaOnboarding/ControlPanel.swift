import SwiftUI
import OnboardingCore

/// The panel at the left: go to any stage or step, press the keys without a keyboard (for a demo on
/// a projector, or a Mac without fn), sound, Reduce Motion, typing, and the run's pace. The first
/// run itself never needs it.
struct ControlPanel: View {
    let model: OnboardingModel
    @State private var holdingOption = false

    var body: some View {
        Form {
            Section {
                ForEach(Stage.allCases, id: \.self) { stage in
                    StageBookmark(model: model, stage: stage)
                }
                HStack(spacing: 6) {
                    Button(action: { model.stepBy(-1) }) { Image(systemName: "chevron.left") }
                        .help("The step before")
                        .disabled(model.step == Step.allCases.first)
                    Text(Copy.step(model.step, agents: model.flow.agents).title)
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.tail)
                        .frame(maxWidth: .infinity)
                    Button(action: { model.stepBy(1) }) { Image(systemName: "chevron.right") }
                        .help("The step after")
                        .disabled(model.step == Step.allCases.last)
                }
                HStack {
                    Button("Start over") { model.startFrom(.arrive) }
                        .help("A fresh run from hello")
                    Spacer()
                    if model.playing {
                        Button("Stop") { model.stopPlaying() }
                    } else {
                        Button("Play it all") { model.play() }
                            .help("The whole first run, played by itself")
                    }
                }
            } header: {
                Text("Stages")
            } footer: {
                Text("Click a stage to go there as things are. Start here begins a fresh run from it; ▶ plays it by itself.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Every step") {
                ForEach(Stage.allCases, id: \.self) { stage in
                    DisclosureGroup(stage.title) {
                        ForEach(Step.allCases.filter { $0.stage == stage }, id: \.self) { step in
                            Button(action: { model.stopPlaying(); model.jump(to: step) }) {
                                HStack {
                                    Text(Copy.step(step).title).lineLimit(1)
                                    Spacer()
                                    if model.step == step { Image(systemName: "circle.fill").font(.system(size: 6)) }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            Section("Keys") {
                HStack {
                    Button("fn ⌃") { model.requestKey() }
                    Button("fn") { model.dictationKey() }
                    Button("return") { _ = model.returnKey() }
                }
                HStack {
                    Button("⌘") { model.commandDown(); model.commandUp(tap: true) }
                    Button("⌘ ⌘") { model.commandDown(); model.commandUp(tap: true); model.commandDouble() }
                    Toggle("⌥", isOn: Binding(get: { holdingOption }, set: { on in
                        holdingOption = on
                        if on { model.optionDown() } else { model.optionUp(tap: false) }
                    }))
                    .toggleStyle(.button)
                }
                Button("Esc") { _ = model.escapeKey() }
                Text("With ⌘ or ⌥ on, drag on the practice page. Real keys work too.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Simulate") {
                Button("Allow both lists") { model.simulateAllow() }
                Button("Say the line (mic test)") { model.simulateVoice() }
                Button("Speak into dictation") { model.simulateDictation() }
                Button("Finish this step") { model.simulateFinishStep() }
                Toggle("Send to the real \(model.agentExecutable == nil ? "agent (none found)" : "Claude Code")",
                       isOn: Binding(get: { model.useRealAgent }, set: { model.useRealAgent = $0 }))
                    .disabled(model.agentExecutable == nil)
                    .help("Off: Fovea's practice agent answers and makes the same edits itself.")
            }
            Section("Feel") {
                Toggle("Letter by letter", isOn: Binding(get: { model.typing }, set: { model.typing = $0 }))
                    .help("The board's instructions and the notch's lines typed out, as if Fovea were talking")
                Toggle("Keyboard while keys are taught", isOn: Binding(get: { model.keyboardOn }, set: { model.keyboardOn = $0 }))
                Toggle("Sound", isOn: Binding(get: { !model.sound.muted }, set: { model.sound.muted = !$0 }))
                Toggle("Ambient bed", isOn: Binding(get: { model.sound.ambientOn }, set: { model.sound.ambientOn = $0 }))
                Toggle("Reduce Motion", isOn: Binding(get: { model.reduceMotion }, set: { model.reduceMotion = $0 }))
                Picker("Pace", selection: Binding(get: { model.pace }, set: { model.pace = $0 })) {
                    Text("1×").tag(1.0)
                    Text("½× (slower)").tag(2.0)
                    Text("2×").tag(0.5)
                }
            }
            Section("Now") {
                LabeledContent("Step", value: model.step.rawValue)
                LabeledContent("Waiting for", value: model.flow.waitingFor.map { $0.map(\.rawValue).sorted().joined(separator: " or ") } ?? "Continue")
                LabeledContent("Agents", value: model.flow.agents.isEmpty ? "none found" : model.flow.agents.map(\.name).joined(separator: ", "))
                LabeledContent("Speech", value: SpeechInput.available ? "real words" : "a stand-in (run the app bundle)")
                LabeledContent("Answers from", value: model.sendsToRealAgent ? "Claude Code" : "the practice agent")
                if let request = model.flow.languageRequest {
                    LabeledContent("Language asked for", value: request)
                }
                if !model.flow.agentWishes.isEmpty {
                    LabeledContent("Agents wanted next", value: model.flow.agentWishes.joined(separator: ", "))
                }
            }
        }
        .formStyle(.grouped)
        .controlSize(.small)
    }
}

extension OnboardingModel {
    /// The panel's shortcut through the permissions: as if dragged into both lists.
    func simulateAllow() {
        switch step {
        case .permissions:
            inList.formUnion([.accessibility, .screenRecording])
            alert = nil
            grant(.accessibility)
            grant(.screenRecording)
        case .microphone: alert = nil; grant(.microphone)
        default: break
        }
    }

    /// The panel's voice for the microphone test: enough to be heard.
    func simulateVoice() {
        guard step == .microphone else { return }
        if micPhase == .waiting { simulateAllow() }
        heard()
    }

    /// The panel's words for dictation: the stand-in lands in the window it's owed to.
    func simulateDictation() {
        guard step == .dictation else { return }
        let owed = flow.waitingFor
        if owed?.contains(.feedbackKey) == true || owed?.contains(.feedbackLanded) == true {
            pointerOver = .feedback
        } else if owed?.contains(.replyKey) == true || owed?.contains(.replyLanded) == true {
            pointerOver = .messages
        } else {
            return
        }
        if dictationTarget == nil { startDictation() }
        if let target = dictationTarget { land(target == .feedback ? OT.Dictation.sampleFeedback : OT.Dictation.sampleReply, in: target) }
    }

    /// The panel's shortcut through any step: its beats, as if done.
    func simulateFinishStep() {
        switch step {
        case .weeklyUpdate, .packList:
            doItForMe()
            return
        case .hover:
            skipTapped()
            return
        default:
            break
        }
        for group in flow.remaining {
            if let beat = group.first { flow.record(beat) }
        }
        if flow.isComplete, [.permissions, .microphone, .agents].contains(step) {
            if let next = flow.advance() { enter(next) }
        }
    }
}

/// One stage in the panel's bookmarks: go there as things are, start a fresh run from it, or play
/// it by itself from there.
struct StageBookmark: View {
    let model: OnboardingModel
    let stage: Stage

    var body: some View {
        let here = model.step.stage == stage
        HStack(spacing: 6) {
            Button(action: { model.goTo(stage) }) {
                HStack(spacing: 8) {
                    Image(systemName: here ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(here ? Color.accentColor : .secondary)
                        .frame(width: 14)
                    Text(stage.title).fontWeight(here ? .semibold : .regular)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Go to \(stage.title), as things are now")
            Button("Start here") { model.startFrom(stage) }
                .help("A fresh run from \(stage.title), as if the stages before were done")
            Button(action: { model.play(from: stage) }) { Image(systemName: "play.fill") }
                .help("Play the run by itself from \(stage.title)")
        }
    }
}

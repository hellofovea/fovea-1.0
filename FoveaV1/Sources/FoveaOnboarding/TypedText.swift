import SwiftUI
import AppKit
import OnboardingCore

/// A line typed out letter by letter, as if Fovea were saying it (Oct 9). The whole line is laid
/// out from the start and the letters not yet typed are clear, so nothing moves as it types. A
/// click shows it all. Shown whole when typing is off (the panel, the harness, Reduce Motion) and
/// when VoiceOver is on; VoiceOver always hears the whole line.
struct TypedText: View {
    let text: String
    var font: Font
    var color: Color
    var typing = true
    var alignment: TextAlignment = .leading

    @State private var shown = Int.max
    @State private var task: Task<Void, Never>?

    private var types: Bool { typing && !NSWorkspace.shared.isVoiceOverEnabled }

    var body: some View {
        let characters = Array(text)
        let count = types ? min(shown, characters.count) : characters.count
        (Text(String(characters.prefix(count))).foregroundStyle(color)
            + Text(String(characters.dropFirst(count))).foregroundStyle(Color.clear))
            .font(font)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(text)
            .contentShape(Rectangle())
            .onTapGesture { finish() }
            .onAppear { type() }
            .onChange(of: text) { type() }
            .onDisappear { task?.cancel() }
    }

    private func type() {
        task?.cancel()
        guard types else { shown = Int.max; return }
        shown = 0
        let delays = Typewriter.delays(for: text, pace: OT.Typing.pace)
        task = Task { @MainActor in
            for (index, delay) in delays.enumerated() {
                if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
                guard !Task.isCancelled else { return }
                shown = index + 1
            }
        }
    }

    private func finish() {
        task?.cancel()
        shown = Int.max
    }
}

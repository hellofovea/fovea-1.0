import SwiftUI
import WindowBenchCore

/// The bottom bar: the agents' connections in mono (a click opens Settings › Connections) and
/// ⚙ at the trailing edge (Settings). Nothing else lives here.
struct StatusBar: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let agents = model.drawnAgents
        let size = BenchTokens.Type_.scale(model.v(TypeScale.self)).meta
        HStack(spacing: 8) {
            Button {
                model.openSettings(.connections)
            } label: {
                HStack(spacing: 7) {
                    switch model.v(StatusBarStyle.self) {
                    case .glyphs:
                        // Only the glyphs that draw something: under "● = needs you" a connected
                        // agent has none, and an empty slot would push the words in for nothing.
                        // A glyph, when there is one, starts where the words do at rest.
                        let marked = agents.filter { model.v(ConnectionGlyphs.self) == .brief || $0.state != .connected }
                        if !marked.isEmpty {
                            HStack(spacing: 3) {
                                ForEach(marked) { agent in ConnectionGlyph(state: agent.state, size: 7) }
                            }
                        }
                        Text(Lines.connected(agents))
                    case .names:
                        ForEach(agents) { agent in
                            HStack(spacing: 4) {
                                ConnectionGlyph(state: agent.state, size: BenchTokens.Notch.workingDot)
                                Text(agent.kind.name)
                            }
                            .opacity(agent.state == .connected ? 1 : 0.55)
                        }
                    case .count:
                        Text(Lines.connected(agents))
                    }
                }
                .font(BenchTokens.Type_.mono(size))
                .foregroundStyle(palette.secondary)
                .padding(.horizontal, 6)
                .frame(height: 20)
                .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())
            .help("Open Settings › Connections")
            .accessibilityLabel("\(Lines.connected(agents)). Open Connections")

            Spacer()

            Button {
                model.openSettings(.general)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .frame(width: 24, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())
            .help("Settings")
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 10)
        .frame(height: BenchTokens.Layout.statusBar)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.hairline).frame(height: BenchTokens.Layout.hairline)
        }
    }
}

/// A connection's state at status-bar size: filled connected, hollow hooks missing, dashed
/// not found. Smaller than a run's glyph, so the two vocabularies don't read as one.
struct ConnectionGlyph: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let state: ConnectionState
    var size: CGFloat = 7

    var body: some View {
        let needsYou = model.v(ConnectionGlyphs.self) == .needsYou
        Group {
            switch (state, needsYou) {
            case (.connected, false): Circle().fill(palette.secondary)
            case (.connected, true): Color.clear
            case (.hooksMissing, false): Circle().strokeBorder(palette.secondary, lineWidth: 1.1)
            case (.hooksMissing, true): Circle().fill(palette.text)
            // Not on this Mac: the list's dashed "can't see" ring, never the dotted running one.
            case (.notFound, _): Image(systemName: "circle.dashed").resizable().fontWeight(.light).foregroundStyle(palette.tertiary)
            }
        }
        // Always its size: a glyph that clears fades where it was, never shrinks (the status
        // bar leaves connected agents out; Settings keeps a column only when one draws).
        .frame(width: size, height: size)
        .accessibilityLabel(state.title)
    }
}

import SwiftUI
import AppKit

// What an agent has in front of it, or what it made, as a picture: the app it works in, drawn at
// a fixed design size and scaled to wherever it shows (the board's focus, a tile, a result).
// While it works the picture is live: a LIVE tag, its pointer moving, the line it types growing.
// Dispatch Version 2 shows these instead of lists: "see the agent's screen and a deliverable".

/// The screen a session shows.
enum AgentScreen: Equatable {
    /// Calendar's day view: the afternoon, its events, the next one emphasised.
    case calendar(day: String, events: [ScreenEvent])
    /// An editor on the file being changed: removed lines struck, the new one typed in.
    case editor(file: String, lines: [AgentCodeLine])
    /// A terminal: the agent's prompt, the command, the lines that matter.
    case terminal(title: String, lines: [ScreenLine])
    /// A page in a browser, the passage being read highlighted.
    case browser(host: String, title: String, lines: [String], highlight: Int?)
    /// Mail's compose window, the draft written in.
    case mail(to: String, subject: String, body: String)
    /// A paper's page, the formula asked about marked, and a note beside it once explained.
    case paper(title: String, note: String?)
}

struct ScreenEvent: Equatable {
    /// Hours, 24-hour: 14.0 is 2:00 PM.
    let start: Double
    let end: Double
    let title: String
    let place: String
}

struct ScreenLine: Equatable {
    enum Tone { case normal, dim, ok, error, ask, prompt }
    let text: String
    var tone: Tone = .normal
}

extension AgentTaskItem {
    /// Its result's first line, for a row, a wing, a result.
    var outcome: String { result?.outcome ?? reply ?? activity }

    /// Its screen: its own, or one made from its line for sessions that came without one.
    var screenView: AgentScreen {
        if let screen { return screen }
        let file = object ?? "Untitled"
        switch work {
        case .editing, .reading:
            if file.contains(".") && !file.contains(" ") && !file.hasPrefix("swift") {
                return .editor(file: file, lines: [
                    AgentCodeLine(number: 11, text: "// \(session)"),
                    AgentCodeLine(number: 12, text: preview ?? activity, change: work == .editing ? .typing : .same),
                    AgentCodeLine(number: 13, text: "}"),
                ])
            }
            return .browser(host: file, title: activity, lines: [preview ?? "", "", ""], highlight: 0)
        case .running:
            return .terminal(title: "\(project) — \(object ?? "zsh")", lines: [
                ScreenLine(text: "❯ \(object ?? "")", tone: .prompt),
                ScreenLine(text: preview ?? activity, tone: (preview ?? "").hasPrefix("✓") ? .ok : .normal),
            ])
        case .browsing:
            return .browser(host: object ?? "", title: preview ?? activity, lines: ["", "", "", ""], highlight: 1)
        case .asking, .thinking:
            return .terminal(title: "\(project) — \(ChatAgent.named(agent).name)", lines: [
                ScreenLine(text: "⏺ \(session)", tone: .dim),
                ScreenLine(text: activity, tone: .ask),
                ScreenLine(text: "  1. Yes   2. No", tone: .dim),
            ])
        case .done:
            if file.hasSuffix(".tsx") || file.hasSuffix(".md") {
                return .browser(host: "localhost:3000", title: outcome, lines: ["", "", ""], highlight: nil)
            }
            return .terminal(title: "\(project) — \(ChatAgent.named(agent).name)", lines: [
                ScreenLine(text: "⏺ \(outcome)", tone: .ok),
                ScreenLine(text: "  \(file)", tone: .dim),
            ])
        case .failed:
            return .terminal(title: "\(project) — swift build", lines: [
                ScreenLine(text: "❯ swift build", tone: .prompt),
                ScreenLine(text: file, tone: .dim),
                ScreenLine(text: preview ?? activity, tone: .error),
            ])
        }
    }
}

/// A screen, scaled to `width`, with its 16:10 frame; LIVE and a moving pointer while it works.
struct AgentScreenView: View {
    let screen: AgentScreen
    let width: CGFloat
    var live = false
    var paused = false

    static let design = CGSize(width: 480, height: 300)

    var body: some View {
        let scale = width / Self.design.width
        let height = Self.design.height * scale
        ZStack(alignment: .topLeading) {
            AgentScreenContent(screen: screen, live: live, paused: paused)
                .frame(width: Self.design.width, height: Self.design.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: width, height: height, alignment: .topLeading)
            if live {
                AgentPointerMark(paused: paused)
                    .frame(width: width, height: height)
                LiveTag()
                    .padding(6)
                    .frame(width: width, height: height, alignment: .topTrailing)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: max(4, 10 * scale + 2), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: max(4, 10 * scale + 2), style: .continuous)
            .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75))
        .accessibilityHidden(true)
    }
}

/// LIVE: the agent is at work on this screen now.
struct LiveTag: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(Color(red: 0.98, green: 0.27, blue: 0.27)).frame(width: 5, height: 5)
            Text("LIVE").font(.system(size: 8.5, weight: .bold)).tracking(0.6)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .frame(height: 15)
        .background(Capsule().fill(Color.black.opacity(0.62)))
    }
}

/// The agent's pointer, moving over its screen in a slow loop.
struct AgentPointerMark: View {
    let paused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1 / 30, paused: paused || reduceMotion)) { context in
                let t = paused || reduceMotion ? 1.2 : context.date.timeIntervalSinceReferenceDate
                let x = proxy.size.width * (0.55 + 0.22 * CGFloat(sin(t * 0.7)))
                let y = proxy.size.height * (0.55 + 0.18 * CGFloat(sin(t * 1.1 + 1)))
                Image(systemName: "cursorarrow")
                    .font(.system(size: max(9, proxy.size.width * 0.035), weight: .regular))
                    .foregroundStyle(.white, .black)
                    .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                    .position(x: x, y: y)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: The apps

/// A screen at its design size (480 × 300): the app's window, its contents.
struct AgentScreenContent: View {
    let screen: AgentScreen
    let live: Bool
    let paused: Bool

    var body: some View {
        switch screen {
        case .calendar(let day, let events):
            ScreenWindow(title: "Calendar", dark: false) { CalendarDay(day: day, events: events) }
        case .editor(let file, let lines):
            ScreenWindow(title: file, dark: true) { EditorScreen(file: file, lines: lines, typing: live && !paused) }
        case .terminal(let title, let lines):
            ScreenWindow(title: title, dark: true) { TerminalScreen(lines: lines, live: live && !paused) }
        case .browser(let host, let title, let lines, let highlight):
            ScreenWindow(title: host, dark: false, address: host) { BrowserPage(title: title, lines: lines, highlight: highlight) }
        case .mail(let to, let subject, let body):
            ScreenWindow(title: "New Message", dark: false) { MailCompose(to: to, subject: subject, text: body, typing: live && !paused) }
        case .paper(let title, let note):
            ScreenWindow(title: "\(title).pdf", dark: false) { PaperPage(title: title, note: note) }
        }
    }
}

/// A Mac window: its title bar (the three lights, the title, an address for a browser).
struct ScreenWindow<Content: View>: View {
    let title: String
    let dark: Bool
    var address: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 6) {
                    Circle().fill(Color(red: 1, green: 0.37, blue: 0.34)).frame(width: 10, height: 10)
                    Circle().fill(Color(red: 1, green: 0.74, blue: 0.18)).frame(width: 10, height: 10)
                    Circle().fill(Color(red: 0.16, green: 0.79, blue: 0.25)).frame(width: 10, height: 10)
                    Spacer()
                }
                if let address {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill").font(.system(size: 8))
                        Text(address).font(.system(size: 11))
                    }
                    .foregroundStyle(Color(white: 0.35))
                    .padding(.horizontal, 14)
                    .frame(height: 20)
                    .background(Capsule().fill(Color(white: 0.86)))
                } else {
                    Text(title).font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(dark ? Color(white: 0.75) : Color(white: 0.3))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(dark ? Color(white: 0.17) : Color(white: 0.93))
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(dark ? Color(white: 0.11) : Color.white)
        }
        .environment(\.colorScheme, dark ? .dark : .light)
    }
}

/// Calendar's afternoon: hours down the side, the events as blocks, the time now as a red line.
struct CalendarDay: View {
    let day: String
    let events: [ScreenEvent]
    private let first = 12.0, last = 18.0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(day).font(.system(size: 20, weight: .bold)).foregroundStyle(Color(white: 0.1))
                .padding(.horizontal, 16).padding(.top, 10)
            GeometryReader { proxy in
                let hour = proxy.size.height / (last - first)
                ZStack(alignment: .topLeading) {
                    ForEach(Array(stride(from: first, to: last, by: 1)), id: \.self) { h in
                        HStack(spacing: 8) {
                            Text(label(h)).font(.system(size: 10)).foregroundStyle(Color(white: 0.55))
                                .frame(width: 40, alignment: .trailing)
                            Rectangle().fill(Color(white: 0.9)).frame(height: 0.5)
                        }
                        .offset(y: (h - first) * hour - 6)
                    }
                    ForEach(Array(events.enumerated()), id: \.offset) { i, e in
                        let tint = i == 0 ? Color(red: 0.2, green: 0.47, blue: 0.95) : Color(red: 0.95, green: 0.45, blue: 0.3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.title).font(.system(size: 12, weight: .semibold))
                            Text("\(label(e.start)) · \(e.place)").font(.system(size: 10))
                        }
                        .foregroundStyle(tint.opacity(0.95))
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .frame(width: proxy.size.width - 72, height: max(36, (e.end - e.start) * hour - 2), alignment: .topLeading)
                        .background(RoundedRectangle(cornerRadius: 5).fill(tint.opacity(0.14)))
                        .overlay(alignment: .leading) { Rectangle().fill(tint).frame(width: 3) }
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .offset(x: 56, y: (e.start - first) * hour)
                    }
                    // Now.
                    HStack(spacing: 0) {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                        Rectangle().fill(Color.red).frame(height: 1)
                    }
                    .offset(x: 50, y: (13.2 - first) * hour - 3)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private func label(_ h: Double) -> String {
        let hour = Int(h) > 12 ? Int(h) - 12 : Int(h)
        let minutes = Int((h - floor(h)) * 60)
        return minutes == 0 ? "\(hour) PM" : String(format: "%d:%02d", hour, minutes)
    }
}

/// An editor on the file: line numbers, the code, the change marked, the typed line growing.
struct EditorScreen: View {
    let file: String
    let lines: [AgentCodeLine]
    let typing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: file.hasSuffix(".swift") ? "swift" : "doc.text").font(.system(size: 10))
                    .foregroundStyle(Color(red: 0.98, green: 0.45, blue: 0.25))
                Text(file).font(.system(size: 11)).foregroundStyle(Color(white: 0.85))
            }
            .padding(.horizontal, 12).frame(height: 26)
            .background(Color(white: 0.14))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(spacing: 10) {
                        Text(line.number > 0 ? "\(line.number)" : "").foregroundStyle(Color(white: 0.4))
                            .frame(width: 26, alignment: .trailing)
                        Text(line.change == .removed ? "−" : (line.change == .same ? " " : "+"))
                            .foregroundStyle(line.change == .removed ? Color(red: 0.95, green: 0.4, blue: 0.4) : Color(red: 0.4, green: 0.85, blue: 0.5))
                        Group {
                            if line.change == .typing, typing {
                                V2Typed(text: line.text, paused: false)
                            } else if line.change == .removed {
                                Text(line.text).strikethrough()
                            } else {
                                Text(line.text)
                            }
                        }
                        .foregroundStyle(line.change == .removed ? Color(white: 0.5) : Color(white: 0.9))
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 13, design: .monospaced))
                    .frame(height: 26)
                    .padding(.horizontal, 8)
                    .background(fill(line.change))
                }
            }
            .padding(.top, 10)
        }
    }

    private func fill(_ change: AgentCodeLine.Change) -> Color {
        switch change {
        case .removed: return Color(red: 0.95, green: 0.3, blue: 0.3).opacity(0.14)
        case .added, .typing: return Color(red: 0.3, green: 0.85, blue: 0.45).opacity(0.13)
        case .same: return .clear
        }
    }
}

/// A terminal: the agent's lines, in their tones.
struct TerminalScreen: View {
    let lines: [ScreenLine]
    let live: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                Group {
                    if live, i == lines.count - 1, line.tone != .ask {
                        V2Typed(text: line.text, paused: false, rate: 40)
                    } else {
                        Text(line.text)
                    }
                }
                .foregroundStyle(color(line.tone))
                .font(.system(size: 13, weight: line.tone == .ask ? .semibold : .regular, design: .monospaced))
                .lineLimit(2)
            }
        }
        .padding(16)
    }

    private func color(_ tone: ScreenLine.Tone) -> Color {
        switch tone {
        case .normal: return Color(white: 0.88)
        case .dim: return Color(white: 0.5)
        case .ok: return Color(red: 0.45, green: 0.86, blue: 0.55)
        case .error: return Color(red: 0.98, green: 0.45, blue: 0.45)
        case .ask: return Color(red: 0.96, green: 0.72, blue: 0.3)
        case .prompt: return Color(red: 0.55, green: 0.7, blue: 1)
        }
    }
}

/// A page: its title, its text, the passage being read highlighted.
struct BrowserPage: View {
    let title: String
    let lines: [String]
    let highlight: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 22, weight: .bold)).foregroundStyle(Color(white: 0.1)).lineLimit(2)
            ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                Group {
                    if line.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.86)).frame(height: 7)
                            RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.86)).frame(width: 300, height: 7)
                        }
                    } else {
                        Text(line).font(.system(size: 13)).foregroundStyle(Color(white: 0.25)).lineLimit(2)
                    }
                }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 4)
                    .fill(i == highlight ? Color(red: 1, green: 0.88, blue: 0.3).opacity(0.55) : .clear))
            }
        }
        .padding(18)
    }
}

/// Mail's compose window: To, Subject, the draft.
struct MailCompose: View {
    let to: String
    let subject: String
    let text: String
    let typing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            field("To:", to)
            field("Subject:", subject)
            Group {
                if typing { V2Typed(text: text, paused: false, rate: 30) } else { Text(text) }
            }
            .font(.system(size: 13.5))
            .foregroundStyle(Color(white: 0.12))
            .lineSpacing(3)
            .padding(16)
        }
    }

    private func field(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label).foregroundStyle(Color(white: 0.5))
            Text(value).foregroundStyle(Color(white: 0.15))
            Spacer()
        }
        .font(.system(size: 12.5))
        .padding(.horizontal, 16)
        .frame(height: 30)
        .overlay(alignment: .bottom) { Rectangle().fill(Color(white: 0.9)).frame(height: 0.5) }
    }
}

/// A paper's page: its title, its text, the attention formula boxed; once explained, a note
/// beside it.
struct PaperPage: View {
    let title: String
    let note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("3.2.1  Scaled Dot-Product Attention").font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundStyle(Color(white: 0.1))
            lines([1.0, 0.94, 0.97, 0.6])
            V2FormulaSnippet()
                .frame(width: 340, height: 58)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color(red: 0.95, green: 0.6, blue: 0.1), lineWidth: 2))
                .frame(maxWidth: .infinity)
            if let note {
                Text(note)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.15))
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(red: 1, green: 0.93, blue: 0.6)))
                    .frame(maxWidth: .infinity)
            } else {
                lines([1.0, 0.9, 0.95])
            }
        }
        .padding(18)
    }

    private func lines(_ widths: [CGFloat]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(widths.enumerated()), id: \.offset) { _, w in
                RoundedRectangle(cornerRadius: 1).fill(Color(white: 0.82)).frame(width: 440 * w, height: 5)
            }
        }
    }
}

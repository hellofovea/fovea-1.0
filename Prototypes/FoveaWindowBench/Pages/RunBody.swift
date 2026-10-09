import SwiftUI
import AppKit
import WindowBenchCore

/// 04 · what a run produced, by where it lives: a diff per file for code, typeset text, an image,
/// or a live thumbnail of the other app (R04-04), each with a way into the original app; then the
/// agent's raw output (collapsed), the captures it used, and earlier attempts folded above.
struct RunBody: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let run: Run
    @State private var appeared = false

    var body: some View {
        // What the run made arrives through layout once the page is showing (a run finishing
        // under your eyes): its slot opens and pushes what's below down, its content a beat
        // behind. Blocks there when the page first draws simply are there.
        VStack(alignment: .leading, spacing: 18) {
            switch run.result {
            case .code where !run.edits.isEmpty:
                VStack(alignment: .leading, spacing: 8) {
                    BodyLabel("Changes", trailing: changesSummary)
                    ForEach(Array(run.edits.enumerated()), id: \.offset) { i, edit in
                        FileDiff(change: edit, key: "\(run.id)/\(i)")
                    }
                }
                .modifier(GrowIn(enabled: appeared))
            case .text(let markdown):
                VStack(alignment: .leading, spacing: 8) {
                    BodyLabel("Document", trailing: run.edits.first?.path)
                    MarkdownText(markdown: markdown)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: BenchTokens.Layout.cardRadius, style: .continuous).fill(palette.raised))
                        .overlay(RoundedRectangle(cornerRadius: BenchTokens.Layout.cardRadius, style: .continuous).strokeBorder(palette.hairline))
                }
                .modifier(GrowIn(enabled: appeared))
            case .image(let path, let caption):
                VStack(alignment: .leading, spacing: 6) {
                    BodyLabel("Image", trailing: nil)
                    if let image = BenchResources.image(path) {
                        // At the measure's width, the caption right under it.
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .clipShape(RoundedRectangle(cornerRadius: BenchTokens.Layout.wellRadius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: BenchTokens.Layout.wellRadius, style: .continuous).strokeBorder(palette.hairline))
                    }
                    Text(caption)
                        .font(BenchTokens.Type_.mono(11))
                        .foregroundStyle(palette.secondary)
                }
                .modifier(GrowIn(enabled: appeared))
                .id("result/\(run.id)")
            case .external(let app, let title, let detail):
                ExternalResult(app: app, title: title, detail: detail)
            default:
                EmptyView()
            }

            if !run.commands.isEmpty, case .code = run.result {
                VStack(alignment: .leading, spacing: 6) {
                    BodyLabel("Commands", trailing: nil)
                    ForEach(Array(run.commands.enumerated()), id: \.offset) { _, command in
                        HStack(spacing: 10) {
                            Text("$").foregroundStyle(palette.tertiary)
                            Text(command.command).foregroundStyle(palette.text)
                            Spacer()
                            Text("exit \(command.exitCode)").foregroundStyle(palette.secondary)
                        }
                        .font(BenchTokens.Type_.mono(11.5))
                    }
                }
                .modifier(GrowIn(enabled: appeared))
            }

            if run.state != .unobserved, !isExternal {
                HStack {
                    Button("Open in \(originalApp)") { model.status = "Would open \(originalApp) on this run" }
                        .help("Anything too big to show here, in the app it came from")
                    Spacer()
                }
            }

            if let output = run.output {
                OutputDisclosure(output: output, key: "output/\(run.id)")
            }

            if !run.captureIDs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    BodyLabel(Lines.usedCaptures(run.captureIDs.count) ?? "Captures", trailing: nil)
                    HStack(spacing: 8) {
                        ForEach(run.captureIDs, id: \.self) { id in
                            if let capture = model.index.captureByID[id] { CaptureChip(capture: capture) }
                        }
                    }
                }
                .id("captures/\(run.id)")
            }
        }
        .padding(.top, 22)
        .onAppear { DispatchQueue.main.async { appeared = true } }
    }

    private var isExternal: Bool { if case .external = run.result { return true } else { return false } }

    private var originalApp: String {
        if case .external(let app, _, _) = run.result { return app }
        return model.index.thread(of: run)?.agent.name ?? "its app"
    }

    private var changesSummary: String {
        let added = run.edits.reduce(0) { $0 + $1.added }, removed = run.edits.reduce(0) { $0 + $1.removed }
        return "\(run.edits.count == 1 ? "1 file" : "\(run.edits.count) files") · +\(added) −\(removed)"
    }
}

/// Earlier attempts, folded above the current one (v0's versions, R04-02).
struct EarlierAttempts: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let run: Run

    var body: some View {
        if !run.earlierAttempts.isEmpty {
            let key = "attempts/\(run.id)"
            VStack(alignment: .leading, spacing: 0) {
                FoldRow(title: run.earlierAttempts.count == 1 ? "1 earlier attempt" : "\(run.earlierAttempts.count) earlier attempts",
                        open: model.openFold == key) { model.toggleFold(key) }
                InlineExpand(open: model.openFold == key) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(run.earlierAttempts, id: \.number) { attempt in
                            HStack(spacing: 10) {
                                Text("Attempt \(attempt.number) · \(Lines.clock(attempt.started))")
                                    .foregroundStyle(palette.text)
                                Text(attempt.line).foregroundStyle(palette.secondary).lineLimit(1)
                            }
                            .font(BenchTokens.Type_.mono(11.5))
                            .padding(.leading, BenchTokens.Layout.rowPaddingH + BenchTokens.Layout.glyphSlot + BenchTokens.Layout.glyphGap)
                            .frame(height: BenchTokens.Layout.runRow.regular)
                        }
                    }
                }
            }
            .padding(.bottom, 8)
        }
    }
}

/// A section label over a body part, a computed fact at its trailing edge.
private struct BodyLabel: View {
    @Environment(\.palette) private var palette
    let title: String
    let trailing: String?
    init(_ title: String, trailing: String?) { self.title = title; self.trailing = trailing }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(palette.tertiary)
            Spacer()
            if let trailing { Text(trailing).font(BenchTokens.Type_.mono(11)).foregroundStyle(palette.tertiary) }
        }
    }
}

// MARK: - Diff

/// One file: a collapsible card, the change kind and counts in mono (Xcode's agent cards, R04-01),
/// its hunks in the Diff switch's treatment. State never by hue, except the Tinted counter-example.
struct FileDiff: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let change: FileChange
    let key: String

    var body: some View {
        let open = !model.collapsedFiles.contains(key)
        // A file without lines (binary, or none recorded) is its header alone: nothing to fold.
        let foldable = !change.hunks.isEmpty
        VStack(alignment: .leading, spacing: 0) {
            Button {
                model.animate(open ? .collapse : .expand) {
                    if open { model.collapsedFiles.insert(key) } else { model.collapsedFiles.remove(key) }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(open ? 90 : 0))
                        .foregroundStyle(palette.tertiary)
                        .opacity(foldable ? 1 : 0)
                    Text(change.kind.rawValue).foregroundStyle(palette.secondary)
                    Text(change.path).foregroundStyle(palette.text).lineLimit(1).truncationMode(.head)
                    Spacer()
                    Text(change.added + change.removed == 0 ? "binary" : "+\(change.added) −\(change.removed)")
                        .foregroundStyle(palette.secondary)
                }
                .font(BenchTokens.Type_.mono(11.5))
                .padding(.horizontal, 12)
                .frame(height: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!foldable)
            if foldable {
                InlineExpand(open: open) {
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle().fill(palette.hairline).frame(height: BenchTokens.Layout.hairline)
                        ForEach(Array(change.hunks.enumerated()), id: \.offset) { _, hunk in
                            HunkView(hunk: hunk)
                        }
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: BenchTokens.Layout.wellRadius, style: .continuous).fill(palette.raised))
        .overlay(RoundedRectangle(cornerRadius: BenchTokens.Layout.wellRadius, style: .continuous).strokeBorder(palette.hairline))
        .clipShape(RoundedRectangle(cornerRadius: BenchTokens.Layout.wellRadius, style: .continuous))
    }
}

private struct HunkView: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let hunk: DiffHunk

    var body: some View {
        let style = model.v(DiffStyle.self)
        VStack(alignment: .leading, spacing: 0) {
            Text(hunk.header)
                .font(BenchTokens.Type_.mono(11))
                .foregroundStyle(palette.tertiary)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 24)
            if style == .split {
                SplitLines(lines: hunk.lines)
            } else {
                ForEach(Array(hunk.lines.enumerated()), id: \.offset) { _, line in
                    UnifiedLine(line: line, tinted: style == .tinted)
                }
            }
        }
        .padding(.bottom, 6)
    }
}

private struct UnifiedLine: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let line: DiffLine
    let tinted: Bool

    var body: some View {
        HStack(spacing: 0) {
            // A hairline bar at the gutter marks a changed line (no hue).
            Rectangle()
                .fill(line.kind == .context || tinted ? .clear : palette.text.opacity(line.kind == .added ? 0.7 : 0.25))
                .frame(width: 2)
            Text(line.oldNumber.map(String.init) ?? "")
                .frame(width: 34, alignment: .trailing)
                .foregroundStyle(palette.tertiary)
            Text(line.newNumber.map(String.init) ?? "")
                .frame(width: 34, alignment: .trailing)
                .foregroundStyle(palette.tertiary)
            Text(line.kind == .added ? "+" : line.kind == .removed ? "−" : " ")
                .frame(width: 22)
                .foregroundStyle(palette.secondary)
            Text(styled)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .font(BenchTokens.Type_.code)
        .frame(height: 19)
        .background(tint)
    }

    private var styled: AttributedString {
        let base: Color = line.kind == .removed ? palette.tertiary : (line.kind == .added ? palette.text : palette.secondary)
        var text = AttributedString(line.text.isEmpty ? " " : line.text)
        text.foregroundColor = base
        if line.kind == .removed && !tinted { text.strikethroughStyle = .init(pattern: .solid, color: palette.quaternary) }
        guard model.v(DiffWords.self) == .on else { return text }
        let ns = line.text as NSString
        // A line that changed throughout says nothing more in bold: emphasis is for spans.
        let changed = line.changed.reduce(0) { $0 + ($1.count == 2 ? $1[1] : 0) }
        let visible = line.text.trimmingCharacters(in: .whitespaces).utf16.count
        guard visible > 0, Double(changed) < Double(visible) * 0.6 else { return text }
        for r in line.changed where r.count == 2 && r[0] + r[1] <= ns.length {
            guard let range = Range(NSRange(location: r[0], length: r[1]), in: line.text),
                  let lo = AttributedString.Index(range.lowerBound, within: text),
                  let hi = AttributedString.Index(range.upperBound, within: text) else { continue }
            text[lo..<hi].font = BenchTokens.Type_.mono(11.5, .medium)
            if tinted {
                text[lo..<hi].backgroundColor = (line.kind == .added ? BenchTokens.DiffTint.added : BenchTokens.DiffTint.removed).opacity(BenchTokens.DiffTint.word)
            }
        }
        return text
    }

    private var tint: Color {
        guard tinted else { return .clear }
        switch line.kind {
        case .added: return BenchTokens.DiffTint.added.opacity(BenchTokens.DiffTint.line)
        case .removed: return BenchTokens.DiffTint.removed.opacity(BenchTokens.DiffTint.line)
        case .context: return .clear
        }
    }
}

/// Before | after, side by side (Kaleidoscope's layout), monochrome.
private struct SplitLines: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let lines: [DiffLine]

    private struct Pair: Identifiable {
        let id: Int
        let left: DiffLine?
        let right: DiffLine?
    }

    private var pairs: [Pair] {
        var out: [Pair] = []
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if line.kind == .context {
                out.append(Pair(id: out.count, left: line, right: line)); i += 1; continue
            }
            var removed: [DiffLine] = [], added: [DiffLine] = []
            while i < lines.count, lines[i].kind == .removed { removed.append(lines[i]); i += 1 }
            while i < lines.count, lines[i].kind == .added { added.append(lines[i]); i += 1 }
            for k in 0..<max(removed.count, added.count) {
                out.append(Pair(id: out.count, left: k < removed.count ? removed[k] : nil, right: k < added.count ? added[k] : nil))
            }
        }
        return out
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(pairs) { pair in
                HStack(spacing: 0) {
                    side(pair.left, number: pair.left?.oldNumber)
                    Rectangle().fill(palette.hairline).frame(width: 1)
                    side(pair.right, number: pair.right?.newNumber)
                }
                .frame(height: 19)
            }
        }
        .font(BenchTokens.Type_.code)
    }

    private func side(_ line: DiffLine?, number: Int?) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(line == nil || line?.kind == .context ? .clear : palette.text.opacity(line?.kind == .added ? 0.7 : 0.25))
                .frame(width: 2)
            Text(number.map(String.init) ?? "")
                .frame(width: 34, alignment: .trailing)
                .foregroundStyle(palette.quaternary)
            Text(" ")
                .frame(width: 10)
            Text(line?.text ?? "")
                .foregroundStyle(line?.kind == .removed ? palette.tertiary : (line?.kind == .added ? palette.text : palette.secondary))
                .fontWeight(line?.kind == .added && model.v(DiffWords.self) == .on && !(line?.changed.isEmpty ?? true) ? .semibold : .regular)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .background(line == nil ? palette.well : .clear)
    }
}

// MARK: - Results that live in another app

/// A live thumbnail of the other app's window with its icon at the corner (Stage Manager, R04-04)
/// and a mono caption; Open brings that window forward, Close dismisses it.
private struct ExternalResult: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let app: String
    let title: String
    let detail: String
    @State private var closed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            BodyLabel("In \(app)", trailing: nil)
            HStack(alignment: .bottom, spacing: 16) {
                // A live thumbnail needs Screen Recording (R04-04). Without it, the window is drawn
                // as what Fovea can't see: the dashed outline, the kind of thing it holds, and why
                // there's no picture. (No app icon: Calendar's would show a date that isn't the event's.)
                Group {
                    if model.simulateScreenRecording, let thumb = BenchResources.image(Self.thumbnail(app)) {
                        Image(nsImage: thumb).resizable()
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(palette.hairline))
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: Self.symbol(app))
                                .font(.system(size: 20, weight: .light))
                            Text("No preview without Screen Recording")
                                .font(.system(size: 11))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(palette.tertiary)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(palette.tertiary, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    }
                }
                .frame(width: 220, height: 138)
                .opacity(closed ? 0.45 : 1)
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(palette.text)
                    Text("\(app) · \(detail)").font(BenchTokens.Type_.mono(11)).foregroundStyle(palette.secondary)
                    HStack(spacing: 8) {
                        Button("Open") { model.status = "Would bring \(app) forward on “\(title)”" }
                        Button(closed ? "Closed" : "Close") { closed = true; model.status = "Would close \(title) in \(app)" }
                            .disabled(closed)
                    }
                }
            }
            .padding(.leading, 10)
            .padding(.bottom, 10)
        }
    }

    /// What the window holds, as a symbol with no date or brand in it.
    private static func symbol(_ app: String) -> String {
        switch app {
        case "Calendar": return "calendar"
        case "Mail": return "envelope"
        case "Safari": return "safari"
        default: return "macwindow"
        }
    }

    /// The window as Screen Recording would show it.
    private static func thumbnail(_ app: String) -> String {
        app == "Calendar" ? "Art/calendar-review" : "Art/\(app.lowercased())"
    }
}

/// The agent's output, as received, collapsed by default.
private struct OutputDisclosure: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let output: String
    let key: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FoldRow(title: "Output", open: model.openFold == key) { model.toggleFold(key) }
            InlineExpand(open: model.openFold == key) {
                VStack(alignment: .trailing, spacing: 6) {
                    Text(output)
                        .font(BenchTokens.Type_.mono(11.5))
                        .foregroundStyle(palette.text)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: BenchTokens.Layout.wellRadius, style: .continuous).fill(palette.well))
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(output, forType: .string)
                        model.status = "Copied the output"
                    }
                    .controlSize(.small)
                }
                // On the measure, as every other block of the body is.
                .padding(.top, 4)
            }
        }
        .id(key)
    }
}

/// A capture the run used: its 44×32 preview (or its kind) and the time, a click opens it.
struct CaptureChip: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let capture: Capture
    @State private var hover = false

    var body: some View {
        let hovered = hover || model.hoverKey == "chip/\(capture.id)"
        Button {
            model.jump(toCapture: capture.id)
        } label: {
            HStack(spacing: 8) {
                CaptureThumb(capture: capture, size: BenchTokens.Layout.captureThumb)
                Text("\(capture.kind.rawValue) · \(Lines.clock(capture.time))")
                    .font(BenchTokens.Type_.mono(11))
                    .foregroundStyle(hovered ? palette.text : palette.secondary)
            }
            .padding(4)
            .padding(.trailing, 6)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(hovered ? palette.hover : palette.fill))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help("Open this capture")
    }
}

/// A capture's small preview: its image, or what kind of capture it is.
struct CaptureThumb: View {
    @Environment(\.palette) private var palette
    let capture: Capture
    let size: CGSize

    var body: some View {
        Group {
            switch capture.preview {
            case .image(let path):
                if let image = BenchResources.image(path) {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                } else { palette.fill }
            case .text(let text):
                Text(text).font(.system(size: 6)).foregroundStyle(palette.secondary).padding(3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(palette.raised)
            case .voice:
                Image(systemName: "waveform").font(.system(size: 12)).foregroundStyle(palette.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(palette.fill)
            case .file:
                Image(systemName: "doc.text").font(.system(size: 12)).foregroundStyle(palette.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(palette.fill)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: BenchTokens.Notch.thumbRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: BenchTokens.Notch.thumbRadius, style: .continuous).strokeBorder(palette.hairline, lineWidth: 0.75))
    }
}

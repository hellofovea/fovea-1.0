import SwiftUI
import WindowBenchCore

/// 06 · the capture stream: chronological, fixed type filters across the top (Photos'
/// collections; they can't be edited), each item a preview and one mono line. Cards or list is
/// undecided (v3.3 §15): List, Cards and Hybrid are on the panel.
struct CaptureStreamPage: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let captures = model.library.captures
            .filter { model.captureFilter == nil || $0.kind == model.captureFilter }
            .sorted { $0.time > $1.time }
        let layout = model.v(CaptureLayout.self)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FilterBar()
                    .padding(.bottom, 14)
                // A filter swaps the whole stream as one layer, out and then in: no row slides
                // through another on its way to a new place (the filters aren't pages).
                ZStack(alignment: .topLeading) {
                    StreamBody(captures: captures, layout: layout, filter: model.captureFilter)
                        .id(StreamKey(filter: model.captureFilter, layout: layout))
                        .transition(.blockSwap)
                }
            }
            .frame(maxWidth: BenchTokens.Layout.column, alignment: .leading)
            .padding(.horizontal, BenchTokens.Layout.sideMargin)
            .padding(.top, BenchTokens.Layout.topMargin)
            .padding(.bottom, BenchTokens.Layout.bottomMargin)
            .frame(maxWidth: .infinity)
        }
        .overlay {
            if let id = model.quickLook, let capture = model.index.captureByID[id] {
                QuickLookCard(capture: capture)
                    .transition(.opacity)
            }
        }
    }

}

private struct StreamKey: Hashable {
    let filter: CaptureKind?
    let layout: CaptureLayout
}

/// The day groups and the cleanup note, for one filter.
private struct StreamBody: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let captures: [Capture]
    let layout: CaptureLayout
    /// The filter this stream was drawn for, handed in: while it fades out after a switch it
    /// stays itself and never redraws as the next filter's layout.
    let filter: CaptureKind?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if captures.isEmpty {
                Text(model.library.captures.isEmpty ? "Captures appear here as you point at things and speak."
                                                      : "No \(filter?.title.lowercased() ?? "captures") yet.")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
            } else {
                ForEach(dayGroups(captures), id: \.day) { group in
                    Text(group.title)
                        .font(.system(size: BenchTokens.Type_.scale(model.v(TypeScale.self)).section, weight: .semibold))
                        .foregroundStyle(palette.tertiary)
                        .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                    switch layout {
                    // Notes list: where every item is a picture (the Screenshots filter), a grid,
                    // as Photos shows its Screenshots collection (R06-03).
                    case .notes where filter == .screenshot, .cards:
                        // Columns fill the width; each tile is its picture (or its words), the
                        // caption under it on the page, as Photos and Finder lay out a grid.
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: BenchTokens.Layout.captureCard.width), spacing: 18, alignment: .top)],
                                  alignment: .leading, spacing: 22) {
                            ForEach(group.captures) { capture in CaptureCard(capture: capture) }
                        }
                        .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
                        .padding(.bottom, 10)
                    case .notes, .list, .hybrid:
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(group.captures) { capture in CaptureRow(capture: capture, layout: layout) }
                        }
                    }
                }
                Text("Captures not used by any run are cleared after 30 days.")
                    .font(BenchTokens.Type_.mono(11))
                    .foregroundStyle(palette.tertiary)
                    .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
                    .padding(.top, 24)
                    .help("Placeholder: the cleanup rule is still open")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct DayGroup { let day: String; let title: String; let captures: [Capture] }

    private func dayGroups(_ captures: [Capture]) -> [DayGroup] {
        let now = model.index.now
        var groups: [DayGroup] = []
        for capture in captures {
            let day = Lines.day(capture.time)
            let title: String
            if Lines.calendar.isDate(capture.time, inSameDayAs: now) { title = "Today" }
            else if let y = Lines.calendar.date(byAdding: .day, value: -1, to: now), Lines.calendar.isDate(capture.time, inSameDayAs: y) { title = "Yesterday" }
            else { title = day }
            if let last = groups.last, last.day == day {
                groups[groups.count - 1] = DayGroup(day: day, title: title, captures: last.captures + [capture])
            } else {
                groups.append(DayGroup(day: day, title: title, captures: [capture]))
            }
        }
        return groups
    }
}

/// All · Screenshots · Selections · Voice · Files: fixed, computed, never edited.
private struct FilterBar: View {
    @Environment(BenchModel.self) private var model

    var body: some View {
        let counts = Dictionary(grouping: model.library.captures, by: \.kind).mapValues(\.count)
        HStack(spacing: 6) {
            Button("All · \(model.library.captures.count)") { model.animate(.swap) { model.captureFilter = nil } }
                .buttonStyle(ToggleChipStyle(on: model.captureFilter == nil))
            ForEach(CaptureKind.allCases, id: \.self) { kind in
                Button("\(kind.title) · \(counts[kind] ?? 0)") { model.animate(.swap) { model.captureFilter = kind } }
                    .buttonStyle(ToggleChipStyle(on: model.captureFilter == kind))
                    .disabled((counts[kind] ?? 0) == 0)
            }
        }
        .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
    }
}

/// List and Hybrid: a row like the notch's (44×32 thumbnail, your words, one mono line); Hybrid
/// gives a capture with something to see a large preview. Notes list: the words always on one
/// edge, the thumbnail at the end only when there is one, never a placeholder (R06-01).
private struct CaptureRow: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let capture: Capture
    let layout: CaptureLayout
    @State private var hover = false

    var body: some View {
        let scale = BenchTokens.Type_.scale(model.v(TypeScale.self))
        let visual = capture.hasVisual
        let hybrid = layout == .hybrid
        let key = "capture/\(capture.id)"
        let hovered = hover || model.hoverKey == key
        HStack(alignment: hybrid && visual ? .top : .center, spacing: 12) {
            if layout == .notes {
                EmptyView()
            } else if hybrid && visual {
                CaptureThumb(capture: capture, size: BenchTokens.Layout.hybridPreview)
            } else {
                CaptureThumb(capture: capture, size: BenchTokens.Layout.captureThumb)
            }
            VStack(alignment: .leading, spacing: 4) {
                // Nothing said: no stand-in sentence in the words' place, only the computed line.
                if !capture.transcript.isEmpty {
                    Text(capture.transcript)
                        .font(.system(size: scale.body))
                        .foregroundStyle(palette.text)
                        .lineLimit(hybrid && visual ? 3 : 1)
                }
                Text((capture.transcript.isEmpty ? "no words · " : "") + Lines.capture(capture, index: model.index))
                    .font(BenchTokens.Type_.mono(scale.meta))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.top, hybrid && visual ? 6 : 0)
            Spacer(minLength: 8)
            if capture.runID != nil {
                SlotButton(title: "View in Project") { model.viewInProject(capture.id) }
                    .opacity(hovered ? 1 : 0)
                    .allowsHitTesting(hovered)
                    .help("Opens the run that used it (also in the capture's detail)")
            }
            if layout == .notes {
                // The thumbnail's place is kept on every row, so View in Project lines up.
                Group {
                    if visual { CaptureThumb(capture: capture, size: BenchTokens.Layout.captureThumb) } else { Color.clear }
                }
                .frame(width: BenchTokens.Layout.captureThumb.width, height: BenchTokens.Layout.captureThumb.height)
            }
        }
        .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
        .padding(.vertical, hybrid && visual ? 10 : 7)
        .background(RoundedRectangle(cornerRadius: BenchTokens.Layout.rowRadius, style: .continuous).fill(hovered ? palette.hover : .clear))
        .contentShape(Rectangle())
        .jumpHighlight(key)
        .rowFrame(key)
        .onHover { hover = $0 }
        .onTapGesture { model.openCapture(capture.id) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .id(key)
    }
}

/// A grid tile: the picture at one shape, cropped to fill (the detail shows it whole), and under
/// it, on the page, your words and the mono line, as Photos and Finder caption a grid. In Cards a
/// capture with nothing to see is its words, large, in a tile of the same shape (mymind, R06-06).
private struct CaptureCard: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let capture: Capture
    @State private var hover = false

    var body: some View {
        let key = "capture/\(capture.id)"
        let hovered = hover || model.hoverKey == key
        let radius = BenchTokens.Layout.cardRadius
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(BenchTokens.Layout.captureTileAspect, contentMode: .fit)
                // Cropped from the top-leading corner, where a screenshot starts to read.
                .overlay(alignment: .topLeading) { tile }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(hovered ? palette.quaternary : palette.hairline))
                .overlay(alignment: .bottomTrailing) {
                    if capture.runID != nil {
                        SlotButton(title: "View in Project") { model.viewInProject(capture.id) }
                            .padding(8)
                            .opacity(hovered ? 1 : 0)
                            .allowsHitTesting(hovered)
                    }
                }
            VStack(alignment: .leading, spacing: 3) {
                if capture.hasVisual && !capture.transcript.isEmpty {
                    Text(capture.transcript)
                        .font(.system(size: 12.5))
                        .foregroundStyle(palette.text)
                        .lineLimit(2)
                }
                // The rows' line in the same order. It may wrap, but only between its parts.
                Text(Lines.unbroken((capture.hasVisual && capture.transcript.isEmpty ? "no words · " : "") + Lines.capture(capture, index: model.index)))
                    .font(BenchTokens.Type_.mono(10.5))
                    .foregroundStyle(palette.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        .jumpHighlight(key)
        .rowFrame(key)
        .onHover { hover = $0 }
        .onTapGesture { model.openCapture(capture.id) }
        .id(key)
    }

    @ViewBuilder private var tile: some View {
        if case .image(let path) = capture.preview, let image = BenchResources.image(path) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
        } else {
            Text(capture.transcript.isEmpty ? "no words" : "“\(capture.transcript)”")
                .font(capture.transcript.isEmpty ? BenchTokens.Type_.mono(11) : .system(size: 15, weight: .medium))
                .foregroundStyle(capture.transcript.isEmpty ? palette.secondary : palette.text)
                .lineLimit(5)
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(palette.raised)
        }
    }
}

/// A capture's detail, a level like any other (in place): the preview large, the words, where it
/// went and why (correctable), and the runs that used it.
struct CapturePage: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let captureID: String

    var body: some View {
        if let capture = model.index.captureByID[captureID] {
            ScrollView {
                CaptureDetail(capture: capture)
                    .frame(maxWidth: BenchTokens.Layout.column, alignment: .leading)
                    .padding(.horizontal, BenchTokens.Layout.sideMargin)
                    .padding(.top, BenchTokens.Layout.topMargin + 4)
                    .padding(.bottom, BenchTokens.Layout.bottomMargin)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct CaptureDetail: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let capture: Capture

    var body: some View {
        let runs = model.index.runs(using: capture.id)
        VStack(alignment: .leading, spacing: 16) {
            Group {
                switch capture.preview {
                case .image(let path):
                    if let image = BenchResources.image(path) {
                        // The whole capture, fitted (never cropped), its border on its own edge.
                        let fit = min(700 / max(1, image.size.width), 380 / max(1, image.size.height), 1)
                        Image(nsImage: image).resizable()
                            .frame(width: image.size.width * fit, height: image.size.height * fit)
                            .clipShape(RoundedRectangle(cornerRadius: BenchTokens.Layout.wellRadius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: BenchTokens.Layout.wellRadius, style: .continuous).strokeBorder(palette.hairline))
                    }
                case .text(let text):
                    Text(text).font(.system(size: 14)).foregroundStyle(palette.text).textSelection(.enabled)
                        .padding(16).frame(maxWidth: 700, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: BenchTokens.Layout.wellRadius, style: .continuous).fill(palette.well))
                case .voice(let seconds):
                    HStack(spacing: 8) {
                        Image(systemName: "waveform").foregroundStyle(palette.secondary)
                        Text(String(format: "voice · %.1f s", seconds)).font(BenchTokens.Type_.mono(11.5)).foregroundStyle(palette.secondary)
                    }
                case .file(let name, let kind):
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text").foregroundStyle(palette.secondary)
                        Text("\(name) · \(kind)").font(BenchTokens.Type_.mono(11.5)).foregroundStyle(palette.secondary)
                    }
                }
            }
            // Everything on the rows' text edge, as the project page's header is.
            .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
            if !capture.transcript.isEmpty {
                Text(capture.transcript)
                    .font(BenchTokens.Type_.runWords)
                    .foregroundStyle(palette.text)
                    .textSelection(.enabled)
                    .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
            }
            Text((capture.transcript.isEmpty ? "no words · " : "") + Lines.capture(capture, index: model.index))
                .font(BenchTokens.Type_.mono(11.5))
                .foregroundStyle(palette.secondary)
                .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
            if let reason = capture.reason {
                InferenceLink(key: "capture/\(capture.id)", inference: reason, size: 11.5)
                    .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
                    .zIndex(model.correction == "capture/\(capture.id)" ? 1 : 0)
            }
            if !runs.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Used by")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.tertiary)
                        .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
                        .padding(.bottom, 4)
                    ForEach(runs) { run in
                        Button { model.viewInProject(capture.id, run: run.id) } label: {
                            HStack(spacing: BenchTokens.Layout.glyphGap) {
                                StateGlyph(state: run.state)
                                Text(run.words).lineLimit(1).foregroundStyle(palette.text)
                                Spacer()
                                Text(model.index.thread(of: run)?.title ?? "")
                                    .font(BenchTokens.Type_.mono(11)).foregroundStyle(palette.tertiary)
                            }
                            .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
                            .frame(height: BenchTokens.Layout.runRow.regular)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    HStack {
                        Button("View in Project") { model.viewInProject(capture.id) }
                        Spacer()
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
                }
            }
        }
    }
}

/// Quick Look style: a card over the stream, which dims and stays where it was.
private struct QuickLookCard: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let capture: Capture

    var body: some View {
        ZStack {
            Color.black.opacity(palette.isDark ? 0.5 : 0.18)
                .onTapGesture { model.animate(.close) { model.quickLook = nil } }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    Button("Close") { model.animate(.close) { model.quickLook = nil } }
                }
                CaptureDetail(capture: capture)
            }
            .padding(20)
            .frame(width: 680)
            .background(RoundedRectangle(cornerRadius: BenchTokens.Layout.cardRadius + 4, style: .continuous).fill(palette.raised))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
            .transition(.modifier(active: NotchPop(progress: 0), identity: NotchPop(progress: 1)))
        }
    }
}

extension Capture {
    var hasVisual: Bool { if case .image = preview { return true } else { return false } }
    var runID: String? { if case .run(let id) = destination { return id } else { return nil } }
}

extension BenchModel {
    /// Opens a capture as the Detail switch says: a level in place, or a Quick Look card.
    func openCapture(_ id: String) {
        if v(CaptureDetailStyle.self) == .quickLook {
            animate(.open) { quickLook = id }
        } else {
            drill(into: .capture(id), from: "capture/\(id)")
        }
    }

    /// View in Project: the run that used the capture, in its project, highlighted.
    func viewInProject(_ captureID: String, run: String? = nil) {
        quickLook = nil
        guard let id = run ?? index.captureByID[captureID]?.runID else { return }
        jump(toRun: id)
    }
}

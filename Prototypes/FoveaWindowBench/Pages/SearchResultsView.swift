import SwiftUI
import WindowBenchCore

/// Search results: glyph · the matched text, the hit shown by weight · where it lives, in
/// mono. A click opens the thing where it lives, with a highlight that fades. In place, the
/// results take the content area; as a dropdown they sit under the field.
struct SearchResultsView: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let dropdown: Bool
    /// The query these results are for, handed in rather than read live: when the results leave
    /// (a jump closes the field and forgets the query), they fade out still showing what they
    /// showed, never "No results".
    let query: SearchQuery

    var body: some View {
        let hits = SearchEngine.search(query, in: model.index)
        let content = VStack(alignment: .leading, spacing: 0) {
            // The scopes, visible and clickable in both field styles (Mail's scope tokens, R05-01).
            ScopeToggles(scopes: query.scopes).padding(.horizontal, BenchTokens.Layout.rowPaddingH).padding(.bottom, 10)
            if hits.isEmpty {
                NoResults(query: query.text)
            } else {
                // What was found, counted (Xcode's line over its results, R05-03).
                Text(Lines.searchCount(hits))
                    .font(BenchTokens.Type_.mono(BenchTokens.Type_.scale(model.v(TypeScale.self)).meta))
                    .foregroundStyle(palette.secondary)
                    .contentTransition(.numericText())
                    .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
                    .padding(.bottom, 2)
                ForEach(SearchScope.allCases.filter { scope in hits.contains { $0.scope == scope } }, id: \.self) { scope in
                    Text(scope.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.tertiary)
                        .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
                        .padding(.top, 10)
                        .padding(.bottom, 2)
                    ForEach(hits.filter { $0.scope == scope }) { hit in
                        HitRow(hit: hit)
                    }
                }
            }
        }
        if dropdown {
            ScrollView {
                content.padding(8)
            }
            .frame(width: BenchTokens.Layout.dropdownWidth)
            .frame(maxHeight: BenchTokens.Layout.dropdownMaxHeight)
            .fixedSize(horizontal: false, vertical: true)
            .background(RoundedRectangle(cornerRadius: BenchTokens.Layout.cardRadius, style: .continuous).fill(palette.raised))
            .overlay(RoundedRectangle(cornerRadius: BenchTokens.Layout.cardRadius, style: .continuous).strokeBorder(palette.hairline))
            .shadow(color: .black.opacity(palette.isDark ? 0.5 : 0.12), radius: 18, y: 8)
        } else {
            ScrollView {
                content
                    .frame(maxWidth: BenchTokens.Layout.column, alignment: .leading)
                    .padding(.horizontal, BenchTokens.Layout.sideMargin)
                    .padding(.top, BenchTokens.Layout.topMargin)
                    .padding(.bottom, BenchTokens.Layout.bottomMargin)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct ScopeToggles: View {
    @Environment(BenchModel.self) private var model
    let scopes: Set<SearchScope>

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SearchScope.allCases, id: \.self) { scope in
                let on = scopes.contains(scope)
                Button(scope.title) {
                    if on { model.search.query.scopes.remove(scope) } else { model.search.query.scopes.insert(scope) }
                }
                .buttonStyle(ToggleChipStyle(on: on))
            }
        }
    }
}

struct ToggleChipStyle: ButtonStyle {
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var enabled
    let on: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(on ? palette.text : (enabled ? palette.secondary : palette.quaternary))
            .padding(.horizontal, 9)
            .frame(height: BenchTokens.Layout.chipHeight)
            .background(Capsule().fill(on ? palette.selected : (configuration.isPressed ? palette.pressed : palette.fill)))
            .overlay(Capsule().strokeBorder(on ? palette.hairline : .clear))
    }
}

private struct HitRow: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let hit: SearchHit
    @State private var hover = false

    var body: some View {
        let scale = BenchTokens.Type_.scale(model.v(TypeScale.self))
        Button {
            model.open(hit)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: BenchTokens.Layout.glyphGap) {
                StateGlyph(state: hit.state).alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                VStack(alignment: .leading, spacing: 2) {
                    if hit.field.isComputed {
                        // A run found by a file or a command: the run's words say which, the match
                        // is set in mono where it was found (a path, a command, a screenshot's text).
                        if let title = hit.title {
                            Text(title)
                                .font(.system(size: scale.body))
                                .foregroundStyle(palette.text)
                                .lineLimit(1)
                        }
                        HStack(spacing: 6) {
                            if hit.field == .screenText {
                                Text("text in screenshot").foregroundStyle(palette.secondary)
                            }
                            Text(Highlighted.text(hit.text, ranges: hit.ranges, color: palette.text, dim: palette.text))
                                .lineLimit(1)
                        }
                        .font(BenchTokens.Type_.mono(scale.meta))
                    } else {
                        Text(Highlighted.text(hit.text, ranges: hit.ranges, color: palette.text, dim: palette.text))
                            .font(.system(size: scale.body))
                            .lineLimit(1)
                    }
                    if !hit.context.isEmpty {
                        Text(hit.context)
                            .font(BenchTokens.Type_.mono(scale.meta))
                            .foregroundStyle(palette.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer(minLength: 8)
                // When it last moved, as every row says it: a quiet project's hits read as old.
                AgeText(date: hit.date)
            }
            .padding(.horizontal, BenchTokens.Layout.rowPaddingH)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: BenchTokens.Layout.rowRadius, style: .continuous)
                .fill(hover || model.hoverKey == "hit/\(hit.id)" ? palette.hover : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// The calm no-results line.
private struct NoResults: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let query: String

    var body: some View {
        VStack(spacing: 6) {
            Text("No results for “\(query)”")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.secondary)
            Text("Fovea searches your words, threads, files, agents, captures and text inside screenshots.")
                .font(.system(size: 12))
                .foregroundStyle(palette.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .onAppear { model.drawnNoResults.append(query) }
    }
}

/// Text with its hits set heavier (search shows a hit by weight, never by color).
enum Highlighted {
    static func text(_ text: String, ranges: [[Int]], color: Color, dim: Color) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = dim
        let ns = text as NSString
        for r in ranges where r.count == 2 && r[0] >= 0 && r[0] + r[1] <= ns.length {
            let nsRange = NSRange(location: r[0], length: r[1])
            guard let range = Range(nsRange, in: text), let lower = AttributedString.Index(range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(range.upperBound, within: attributed) else { continue }
            attributed[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
            attributed[lower..<upper].foregroundColor = color
        }
        return attributed
    }
}

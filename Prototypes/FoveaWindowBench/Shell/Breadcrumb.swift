import SwiftUI
import WindowBenchCore

struct Crumb: Identifiable, Equatable {
    var depth: Int
    var title: String
    var id: Int { depth }
}

extension BenchModel {
    func title(of level: Level) -> String {
        switch level {
        case .projects: return "Projects"
        case .project(let id): return index.projectByID[id]?.name ?? "Project"
        case .run(let id): return index.runByID[id].flatMap { index.thread(of: $0)?.title } ?? "Run"
        case .captures: return "Captures"
        case .capture(let id):
            guard let capture = index.captureByID[id] else { return "Capture" }
            return "\(capture.kind.rawValue) · \(Lines.stamp(capture.time, now: index.now))"
        }
    }

    var crumbs: [Crumb] {
        destinationPath.enumerated().map { Crumb(depth: $0.offset, title: title(of: $0.element.level)) }
    }
}

/// The first line of the content (HIG, path controls): a visible back button and the crumbs,
/// every one but the last clickable. The only way up a level.
struct BreadcrumbBar: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    var inSearch = false

    var body: some View {
        let style = model.v(BreadcrumbStyle.self)
        let crumbs = model.crumbs
        let canGoBack = inSearch || crumbs.count > 1
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                switch style {
                case .chevron, .largeTitle:
                    Button {
                        goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(QuietButtonStyle())
                    .disabled(!canGoBack)
                    .help(canGoBack ? "Back to \(backTitle(crumbs))" : "")
                case .toolbarBack:
                    EmptyView()
                case .pill:
                    if canGoBack {
                        Button {
                            goBack()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                                Text(backTitle(crumbs)).lineLimit(1)
                            }
                            .font(.system(size: BenchTokens.Type_.scale(model.v(TypeScale.self)).crumb))
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(Capsule().fill(palette.fill))
                        }
                        .buttonStyle(.plain)
                        .help("Back to \(backTitle(crumbs))")
                    }
                }
                CrumbTrail(crumbs: crumbs, inSearch: inSearch, small: style == .largeTitle)
                Spacer(minLength: 0)
            }
            // The back button hangs in the margin, so the first crumb lines up with the content.
            .offset(x: style == .pill ? 0 : BenchTokens.Layout.rowPaddingH - 30)
            if style == .largeTitle {
                SwapText(inSearch ? "Search" : (crumbs.last?.title ?? ""))
                    .font(BenchTokens.Type_.largeTitle)
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.leading, BenchTokens.Layout.rowPaddingH)
            }
        }
        .frame(maxWidth: BenchTokens.Layout.column, alignment: .leading)
        .padding(.horizontal, BenchTokens.Layout.sideMargin)
        .frame(maxWidth: .infinity)
        .frame(minHeight: BenchTokens.Layout.crumbBar)
        .padding(.vertical, style == .largeTitle ? 6 : 0)
        .animation(model.motion.animation(.swap), value: crumbs)
    }

    private func backTitle(_ crumbs: [Crumb]) -> String {
        if inSearch { return crumbs.last?.title ?? "" }
        return crumbs.count > 1 ? crumbs[crumbs.count - 2].title : ""
    }

    private func goBack() {
        if inSearch { model.closeSearchResults() } else { model.back() }
    }
}

private struct CrumbTrail: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let crumbs: [Crumb]
    let inSearch: Bool
    let small: Bool

    /// One crumb as the trail draws it: its identity is its place and its name, so a crumb that
    /// stays (Projects, on every drill) is never redrawn, only re-inked.
    private struct Item: Identifiable, Equatable {
        let id: String
        let title: String
        let depth: Int
    }

    var body: some View {
        let size = BenchTokens.Type_.scale(model.v(TypeScale.self)).crumb
        // Search isn't under the page you were on: one crumb, at the root.
        let items = inSearch ? [Item(id: "search", title: "Search", depth: 0)]
                             : crumbs.map { Item(id: "\($0.depth)/\($0.title)", title: $0.title, depth: $0.depth) }
        HStack(spacing: 5) {
            ForEach(items) { item in
                let current = item.id == items.last?.id
                HStack(spacing: 5) {
                    if item.depth > 0 { separator }
                    CrumbLink(title: item.title, current: current) {
                        if inSearch { model.closeSearchResults() }
                        model.pop(to: item.depth)
                    }
                    .layoutPriority(current ? 1 : 0)
                }
                // Only a crumb that arrives or leaves moves: out first, then in (the notch's line swap).
                .transition(.lineSwap)
            }
        }
        .font(.system(size: small ? size - 1 : size))
        .animation(model.motion.animation(.swap), value: items)
    }

    private var separator: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(palette.quaternary)
    }
}

/// A crumb. Every crumb is set alike and only its ink says which is current, so a crumb that
/// becomes (or stops being) the current one changes color in place and never re-lays out.
private struct CrumbLink: View {
    @Environment(\.palette) private var palette
    let title: String
    let current: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .buttonStyle(CrumbButtonStyle(current: current))
        .allowsHitTesting(!current)
        .help(current ? "" : "Back to \(title)")
        .accessibilityAddTraits(current ? .isHeader : .isButton)
    }
}

/// A crumb: secondary text that darkens under the pointer; the current one in the text ink.
struct CrumbButtonStyle: ButtonStyle {
    var current = false
    @Environment(\.palette) private var palette
    @State private var hover = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(current || hover || configuration.isPressed ? palette.text : palette.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(hover && !current ? palette.hover : .clear))
            .onHover { hover = $0 }
    }
}

/// A borderless glyph button with the notch's hover fill.
struct QuietButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var enabled
    @State private var hover = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(enabled ? (hover ? palette.text : palette.secondary) : palette.quaternary)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(configuration.isPressed ? palette.pressed : (hover && enabled ? palette.hover : .clear)))
            .onHover { hover = $0 }
    }
}

import SwiftUI
import AppKit
import WindowBenchCore

/// The toolbar's search, both variants in one item so switching never rebuilds the window.
/// Expanding: a magnifier that grows into a field holding the scope, agent and date chips
/// (Paste's Power Search, B2), on the notch's spring; the item reserves its open width, since
/// the toolbar doesn't animate items that change size. Native: AppKit's search field.
struct SearchItem: View {
    @Environment(BenchModel.self) private var model

    var body: some View {
        if model.v(SearchFieldStyle.self) == .native {
            NativeSearchField()
                .frame(width: BenchTokens.Layout.searchExpanded - 60, height: BenchTokens.Layout.searchHeight)
        } else {
            ExpandingSearch()
                .frame(height: BenchTokens.Layout.searchHeight, alignment: .trailing)
        }
    }
}

private struct ExpandingSearch: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @FocusState private var focused: Bool
    /// The field's contents come in once the capsule has opened, and leave the moment it starts
    /// to close: the text field is AppKit's and isn't clipped by the capsule, so it must never be
    /// in it while it changes size.
    @State private var settled = false

    var body: some View {
        @Bindable var model = model
        let expanded = model.search.expanded
        let fill = Color(nsColor: .labelColor).opacity(0.06)
        HStack(spacing: 4) {
            Button {
                model.animate(.open) { model.search.expanded = true }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: BenchTokens.Layout.searchCollapsed, height: BenchTokens.Layout.searchHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Search")
            .accessibilityLabel("Search")
            if expanded && settled {
                // Leaves at once when the capsule starts to close (the text field isn't clipped).
                Group {
                ChipRow()
                TextField("Search", text: Binding(
                    get: { model.search.query.text },
                    set: { text in
                        // AppKit commits a field's text when it ends editing (as when a jump closes
                        // the field): only real typing may change the query or show results.
                        guard model.search.expanded, text != model.search.query.text else { return }
                        model.search.query.text = text
                        let show = !model.search.query.isEmpty
                        if show != model.search.presented { model.animate(.open) { model.search.presented = show } }
                    }))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($focused)
                    .focusEffectDisabled()
                    .frame(minWidth: 60)
                FilterMenu()
                Button {
                    model.animate(.close) {
                        model.search = SearchUI()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Close search")
                .accessibilityLabel("Close search")
                .padding(.trailing, 4)
                }
                .transition(.asymmetric(insertion: .opacity, removal: .identity))
            }
        }
        .frame(width: expanded ? BenchTokens.Layout.searchExpanded : BenchTokens.Layout.searchCollapsed,
               height: BenchTokens.Layout.searchHeight, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: BenchTokens.Layout.searchHeight / 2, style: .continuous)
                .fill(expanded ? fill : .clear)
                .overlay {
                    RoundedRectangle(cornerRadius: BenchTokens.Layout.searchHeight / 2, style: .continuous)
                        .strokeBorder(Color(nsColor: .keyboardFocusIndicatorColor).opacity(focused && expanded ? 0.8 : 0), lineWidth: 2)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: BenchTokens.Layout.searchHeight / 2, style: .continuous))
        .onChange(of: model.search.expanded, initial: true) { _, now in
            guard now else {
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) { settled = false }
                focused = false
                return
            }
            let motion = model.motion
            Task { @MainActor in
                await motion.sleep(motion.reduce ? 0 : BenchTokens.MotionValues.open * 0.85)
                guard model.search.expanded else { return }
                withAnimation(motion.animation(.content)) { settled = true }
                focused = true
            }
        }
    }
}

/// The chips the query holds: scopes, an agent, a date. Each has a visible ✕.
private struct ChipRow: View {
    @Environment(BenchModel.self) private var model

    var body: some View {
        let q = model.search.query
        HStack(spacing: 3) {
            ForEach(SearchScope.allCases.filter { q.scopes.contains($0) }, id: \.self) { scope in
                Chip(title: scope.title) { model.search.query.scopes.remove(scope) }
            }
            if let agent = q.agent {
                Chip(title: agent.name) { model.search.query.agent = nil }
            }
            if let date = q.date {
                Chip(title: date.title) { model.search.query.date = nil }
            }
        }
        .fixedSize()
    }
}

struct Chip: View {
    let title: String
    let remove: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: remove) {
            HStack(spacing: 3) {
                Text(title).font(.system(size: 11, weight: .medium))
                Image(systemName: "xmark").font(.system(size: 7, weight: .bold)).opacity(hover ? 1 : 0.5)
            }
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(Capsule().fill(Color(nsColor: .labelColor).opacity(hover ? 0.14 : 0.09)))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help("Remove \(title)")
    }
}

/// Scopes, an agent and a date, picked from a menu inside the field (Paste's ≡).
private struct FilterMenu: View {
    @Environment(BenchModel.self) private var model

    var body: some View {
        Menu {
            Section("Search in") {
                ForEach(SearchScope.allCases, id: \.self) { scope in
                    Toggle(scope.title, isOn: Binding(
                        get: { model.search.query.scopes.contains(scope) },
                        set: { on in
                            if on { model.search.query.scopes.insert(scope) } else { model.search.query.scopes.remove(scope) }
                            refresh()
                        }))
                }
            }
            Section("Agent") {
                ForEach([AgentKind.claudeCode, .codex, .cursor], id: \.self) { agent in
                    Toggle(agent.name, isOn: Binding(get: { model.search.query.agent == agent },
                                                     set: { model.search.query.agent = $0 ? agent : nil; refresh() }))
                }
            }
            Section("Date") {
                ForEach(DateChip.allCases, id: \.self) { date in
                    Toggle(date.title, isOn: Binding(get: { model.search.query.date == date },
                                                     set: { model.search.query.date = $0 ? date : nil; refresh() }))
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 11, weight: .medium))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .foregroundStyle(.secondary)
        .help("Search in: projects, threads, runs, captures; an agent; a date")
    }

    private func refresh() {
        let show = !model.search.query.isEmpty
        if show != model.search.presented { model.animate(.open) { model.search.presented = show } }
    }
}

/// AppKit's search field, for the Native variant. Chips live over the results instead.
private struct NativeSearchField: NSViewRepresentable {
    @Environment(BenchModel.self) private var model

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "Search"
        field.sendsSearchStringImmediately = true
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.changed(_:))
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.model = model
        if field.stringValue != model.search.query.text { field.stringValue = model.search.query.text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    @MainActor final class Coordinator: NSObject, NSSearchFieldDelegate {
        var model: BenchModel
        init(model: BenchModel) { self.model = model }

        @objc func changed(_ sender: NSSearchField) {
            // The field also sends its action when it ends editing: only a change counts.
            guard sender.stringValue != model.search.query.text else { return }
            model.search.query.text = sender.stringValue
            model.search.expanded = true
            let show = !model.search.query.isEmpty
            if show != model.search.presented { model.animate(.open) { model.search.presented = show } }
        }

        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSSearchField { changed(field) }
        }
    }
}

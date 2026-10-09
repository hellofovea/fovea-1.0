import SwiftUI
import WindowBenchCore

/// The Fovea window's content: the breadcrumb, the level in view (or onboarding, or search
/// results), and the status bar. The toolbar is SwiftUI's, bridged into the NSWindow.
struct MainView: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette.make(model.v(SurfaceVariant.self), dark: scheme == .dark)
        VStack(spacing: 0) {
            ContentArea()
            StatusBar()
        }
        .background {
            PageFill().ignoresSafeArea()
        }
        .environment(\.palette, palette)
        .environment(\.motion, model.motion)
        .toolbar { WindowToolbar() }
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)) { _ in
            model.reduceMotionSystem = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        }
    }
}

/// The window's own color (the surface, and the warm tint when it has one), opaque. Rows that
/// travel through a list carry it, so they cover what they pass instead of printing over it.
struct PageFill: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            palette.background
            if let tint = palette.tint { tint }
        }
    }
}

/// Traffic lights · the centered Project │ Capture · Brief and 带我去 where they apply · search.
struct WindowToolbar: ToolbarContent {
    @Environment(BenchModel.self) private var model

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            ToolbarBack()
        }
        ToolbarItem(placement: .principal) {
            SectionPicker()
        }
        ToolbarItem(placement: .automatic) {
            // Brief and 带我去 sit with search, at the trailing edge, in one item.
            TrailingTools()
        }
    }
}

struct SectionPicker: View {
    @Environment(BenchModel.self) private var model

    var body: some View {
        Picker("Section", selection: Binding(get: { model.state.section }, set: { model.selectSection($0) })) {
            ForEach(WindowSection.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .help("Project or Capture")
    }
}

/// Brief on a project or a run; 带我去 on a run. Nothing else lives in the toolbar.
struct ContextualButtons: View {
    @Environment(BenchModel.self) private var model

    var body: some View {
        // Gone while a section switch is under way: they belong to the page that is leaving.
        let level = model.state.onboarding == nil && !model.search.presented && !model.sectionLeaving ? model.destinationLevel : .projects
        switch level {
        case .project(let id):
            BriefButton(projectID: id)
        case .run(let id):
            if let run = model.index.runByID[id], let project = model.index.project(of: run) {
                BriefButton(projectID: project.id)
                Button(model.verbs.takeMeThere) { model.takeMeThere(id) }
                    .help("Opens this run's session in \(model.index.thread(of: run)?.agent.name ?? "its agent")")
            }
        default:
            EmptyView()
        }
    }
}

struct BriefButton: View {
    @Environment(BenchModel.self) private var model
    let projectID: String

    var body: some View {
        let threads = model.index.threads(in: projectID)
        let observable = threads.contains(where: \.observable)
        let phase = model.briefs[projectID]
        // The help names who will write it (Copilot's Summary item says what it will write, R07-06).
        let agent = (model.library.briefs[projectID]?.agent ?? threads.first(where: \.observable)?.agent)?.name ?? "An agent"
        Button("Brief") { model.requestBrief(projectID) }
            .disabled(!observable || phase == .writing)
            .help(observable ? (phase == .writing ? "\(agent) is writing the Brief" : "\(agent) writes a Brief of this project")
                             : "Fovea can't see these threads, so no agent can brief them")
    }
}

/// The HIG's circular Back at the toolbar's leading edge (Toolbar back breadcrumb style).
struct ToolbarBack: View {
    @Environment(BenchModel.self) private var model

    var body: some View {
        if model.v(BreadcrumbStyle.self) == .toolbarBack {
            let canGoBack = model.search.presented || model.path.count > 1
            Button {
                if model.search.presented { model.closeSearchResults() } else { model.back() }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!canGoBack || model.state.onboarding != nil)
            .help("Back")
            .accessibilityLabel("Back")
        }
    }
}

/// The trailing item: the contextual buttons, then search. While search is open it takes the
/// whole item; the item keeps one width, since the toolbar doesn't animate items that resize.
struct TrailingTools: View {
    @Environment(BenchModel.self) private var model

    var body: some View {
        HStack(spacing: 6) {
            Spacer(minLength: 0)
            if !model.search.expanded || model.v(SearchFieldStyle.self) == .native {
                // They leave before the capsule opens over them, and come back only once it has
                // closed, so the two never share the space.
                ContextualButtons()
                    .buttonStyle(ToolbarTextButtonStyle())
                    .transition(.asymmetric(
                        insertion: .opacity.animation(model.motion.animation(.content)
                            .delay(model.motion.seconds(BenchTokens.MotionValues.close))),
                        removal: .opacity.animation(model.motion.animation(.content))))
            }
            SearchItem()
                .fixedSize()
        }
        .frame(width: model.v(SearchFieldStyle.self) == .native ? BenchTokens.Layout.searchExpanded + 120 : BenchTokens.Layout.searchExpanded,
               alignment: .trailing)
    }
}

/// A text button that looks like the toolbar's own: no border until the pointer is on it.
struct ToolbarTextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    @State private var hover = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundStyle(enabled ? Color(nsColor: .labelColor) : Color(nsColor: .tertiaryLabelColor))
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .labelColor).opacity(configuration.isPressed ? 0.12 : (hover && enabled ? 0.07 : 0))))
            .onHover { hover = $0 }
    }
}

import AppKit
import SwiftUI
import CapturesCore

/// Settings as System Settings shows its own (Ryan's call, October): a sidebar at the left, on
/// the window's material, each section a tile of color with a white symbol (as System Settings'
/// sidebar draws them, studied from the pane icons on macOS 27), grouped by space; beside it the
/// section picked, alone, opening with its tile, name and what it's for. The page is white, its
/// settings in the Mac's grouped boxes (`T.Native`, measured from SwiftUI's grouped Form). On the
/// Variants menu the sidebar can lead a single scrolling page instead.

/// The sidebar: the sections in System Settings' groups. The section you're in is marked in the
/// accent picked in Appearance, as System Settings marks its own in the Mac's: the List's own
/// highlight knows only the Mac's accent (and greys while the list doesn't have focus), so each
/// row draws its own over it, the accent while the window is in front and grey behind others.
struct SettingsSidebar: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.controlActiveState) private var activeState

    var body: some View {
        let accent = model.accent.color ?? .accentColor
        let front = activeState != .inactive
        List(selection: Binding(get: { model.settingsCategory }, set: { picked in
            if let picked { model.pickSettings(picked) }
        })) {
            ForEach(Array(SettingsCategory.groups.enumerated()), id: \.offset) { _, group in
                Section {
                    ForEach(group) { category in
                        let chosen = category == model.settingsCategory
                        Label {
                            Text(category.title)
                                .foregroundStyle(chosen && front ? Color.white : Color.primary)
                        } icon: {
                            SettingsIcon(category: category, size: 20)
                        }
                        .tag(category)
                        .listRowBackground(chosen ? SidebarMark(color: front ? accent : Color.primary.opacity(0.1)) : nil)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .accessibilityLabel("Settings")
    }
}

/// The chosen row's mark: a rounded bar inset from the sidebar's edges, as macOS draws its own,
/// a point wider on each side than the List's highlight under it, so none of the Mac's color
/// fringes its corners.
private struct SidebarMark: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(color)
            .padding(.horizontal, 9)
    }
}

/// A section's tile, as System Settings draws its own: a rounded square of color, lit a little
/// from the top, with a white symbol filled in it; the notch's drawn.
struct SettingsIcon: View {
    let category: SettingsCategory
    let size: CGFloat

    var body: some View {
        let base = category.tile.nsColor
        let top = base.blended(withFraction: category.tile == .black ? 0.16 : 0.22, of: .white) ?? base
        let shape = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [Color(nsColor: top), Color(nsColor: base)], startPoint: .top, endPoint: .bottom))
            shape.strokeBorder(.black.opacity(0.08), lineWidth: max(0.5, size / 64))
            if let symbol = category.symbol {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.56, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                NotchGlyph().frame(width: size * 0.68, height: size * 0.5)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The notch's symbol: a screen's top edge, the Island hanging from it.
private struct NotchGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: h * 0.18, style: .continuous)
                    .strokeBorder(.white, lineWidth: max(1, h * 0.13))
                IslandShape(topRadius: h * 0.08, bottomRadius: h * 0.16)
                    .fill(.white)
                    .frame(width: w * 0.44, height: h * 0.34)
            }
        }
    }
}

/// The top of a section's page: its tile large, its name, and what it's for, centered in a box,
/// as System Settings opens its panes.
struct PaneHeader: View {
    @Environment(\.palette) private var palette
    let category: SettingsCategory

    var body: some View {
        VStack(spacing: 8) {
            SettingsIcon(category: category, size: 56)
            HStack(spacing: 8) {
                Text(category.title).font(.system(size: 17, weight: .bold)).foregroundStyle(palette.text)
                if category == .eyeTracking { SoonPill(text: "Beta") }
            }
            Text(category.summary)
                .font(.system(size: 12))
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(palette.nativeGroup, in: RoundedRectangle(cornerRadius: T.Native.groupRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The page beside the sidebar: the section picked (or, on the Variants menu, every section in
/// order), in a settings page's column, centered.
struct NativeSettingsPage: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    /// Each section's top, in the scroll view, for the sidebar to follow (one page only).
    @State private var tops: [SettingsCategory: CGFloat] = [:]
    /// While a click's scroll runs, the sidebar keeps the section clicked.
    @State private var settlingUntil = Date.distantPast

    var body: some View {
        GeometryReader { geo in
            let column = min(T.Native.column, geo.size.width - 48)
            ScrollViewReader { proxy in
                ScrollView {
                    Group {
                        if model.settingsLayout == .sidebarPanes {
                            VStack(alignment: .leading, spacing: T.Native.sectionGap) {
                                PaneHeader(category: model.settingsCategory)
                                section(model.settingsCategory)
                            }
                            .id(model.settingsCategory)
                            .transition(.blockSwap)
                        } else {
                            VStack(alignment: .leading, spacing: T.Native.categoryGap) {
                                ForEach(SettingsCategory.allCases) { category in
                                    VStack(alignment: .leading, spacing: T.Native.sectionGap) {
                                        PaneHeader(category: category)
                                        section(category)
                                    }
                                    .id(category)
                                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .scrollView).minY } action: { top in
                                        tops[category] = top
                                        follow()
                                    }
                                }
                            }
                        }
                    }
                    .environment(\.settingsNative, true)
                    .environment(\.settingsArrangement, .column)
                    .frame(width: column, alignment: .leading)
                    // Room under the last section, so it too can reach the top of the page.
                    .padding(.bottom, model.settingsLayout == .sidebarPanes ? 48 : max(48, geo.size.height - 220))
                    .frame(maxWidth: .infinity)
                }
                // A margin the page's top keeps even when a click scrolls a section up to it.
                .contentMargins(.top, 24, for: .scrollContent)
                // One section at a time: each opens at its top, as a pane does.
                .id(model.settingsLayout == .sidebarPanes ? "pane-\(model.settingsCategory.rawValue)" : "page")
                .scrollIndicators(.automatic)
                .background(palette.nativePage, ignoresSafeAreaEdges: [])
                .onAppear { scroll(proxy, animated: false) }
                .onChange(of: model.settingsScroll?.count) { scroll(proxy, animated: true) }
                // The snapshot harness scrolls to a part of a section by its id.
                .onChange(of: model.scrollTarget) { if let target = model.scrollTarget { proxy.scrollTo(target, anchor: .top) } }
            }
        }
    }

    /// The sidebar takes the last section whose top has reached the top of the page.
    private func follow() {
        guard model.settingsLayout == .sidebar, Date() > settlingUntil else { return }
        let current = SettingsCategory.allCases.last { (tops[$0] ?? .infinity) <= 90 } ?? .account
        if current != model.settingsCategory { model.settingsCategory = current }
    }

    private func scroll(_ proxy: ScrollViewProxy, animated: Bool) {
        guard model.settingsLayout == .sidebar, let target = model.settingsScroll?.category else { return }
        settlingUntil = Date().addingTimeInterval(animated ? 0.7 : 0.2)
        if animated {
            withAnimation(model.motion.animation(.page)) { proxy.scrollTo(target, anchor: .top) }
        } else {
            proxy.scrollTo(target, anchor: .top)
        }
    }

    @ViewBuilder private func section(_ category: SettingsCategory) -> some View {
        switch category {
        case .account: AccountPane(dictionary: false, memories: false, language: false)
        case .plan: PlanPane()
        case .appearance: AppearancePane()
        case .notch: NotchPane()
        case .voice: VoicePane()
        case .language: LanguagePane()
        case .memory:
            DictionarySection()
            MemorySection()
        case .shortcuts: ShortcutsPane()
        case .connectors: ConnectorsPane()
        case .eyeTracking: EyeTrackingPane()
        }
    }
}

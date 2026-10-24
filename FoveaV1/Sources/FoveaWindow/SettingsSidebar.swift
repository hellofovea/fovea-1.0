import AppKit
import SwiftUI
import CapturesCore
import FoveaKit
import FoveaLook

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
    @Environment(\.palette) private var palette

    var body: some View {
        if WindowLook.isAligned {
            aligned
        } else {
            current
        }
    }

    private var current: some View {
        let accent = model.accent.color ?? .accentColor
        let front = activeState != .inactive
        return List(selection: Binding(get: { model.settingsCategory }, set: { picked in
            if let picked { model.pickSettings(picked) }
        })) {
            ForEach(Array(SettingsCategory.groups.enumerated()), id: \.offset) { _, group in
                Section {
                    ForEach(group) { category in
                        let chosen = category == model.settingsCategory
                        Label {
                            HStack(spacing: 4) {
                                Text(category.title)
                                    .foregroundStyle(chosen && front ? Color.white : Color.primary)
                                Spacer(minLength: 0)
                            }
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

    /// Aligned: each row drawn here, so the symbol keeps its size (the sidebar list scales a
    /// Label's icon up to the Mac's sidebar icon size) and no system selection shows under the
    /// row's own quiet fill, as the notch's board marks its row. Oct 24, Ryan.
    private var aligned: some View {
        let accent = model.accent.color ?? .accentColor
        let A = T.Aligned.self
        return List {
            ForEach(Array(SettingsCategory.groups.enumerated()), id: \.offset) { _, group in
                Section {
                    ForEach(group) { category in
                        let chosen = category == model.settingsCategory
                        Button { model.pickSettings(category) } label: {
                            HStack(spacing: A.sidebarGap) {
                                AlignedSidebarSymbol(category: category, color: chosen ? accent : palette.secondary)
                                Text(category.title)
                                    .font(.system(size: A.sidebarText, weight: chosen ? .semibold : .regular))
                                    .foregroundStyle(palette.text)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(chosen ? SidebarMark(color: palette.ink(A.sidebarChosen)) : nil)
                        .accessibilityAddTraits(chosen ? .isSelected : [])
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

/// Aligned: a section as the notch and the first run draw a symbol, the outline in ink (the
/// filled one where the Mac has no outline), no tile; the notch drawn.
private struct AlignedSidebarSymbol: View {
    let category: SettingsCategory
    let color: Color

    var body: some View {
        let size = T.Aligned.sidebarSymbol
        Group {
            if let symbol = category.symbol {
                Image(systemName: Self.outline(symbol)).font(.system(size: size, weight: .regular))
            } else {
                // A little under the symbols' box: drawn edge to edge, it read larger than they do.
                NotchGlyph(color: color).frame(width: size * 1.1, height: size * 0.8)
            }
        }
        .foregroundStyle(color)
        .frame(width: T.Aligned.sidebarSymbolColumn)
        .accessibilityHidden(true)
    }

    /// "person.fill" → "person", where the Mac has the outline.
    static func outline(_ symbol: String) -> String {
        guard symbol.hasSuffix(".fill") else { return symbol == "info" ? "info.circle" : symbol }
        let plain = String(symbol.dropLast(5))
        return NSImage(systemSymbolName: plain, accessibilityDescription: nil) != nil ? plain : symbol
    }
}

/// The notch's symbol: a screen's top edge, the Island hanging from it.
private struct NotchGlyph: View {
    var color: Color = .white
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: h * 0.18, style: .continuous)
                    .strokeBorder(color, lineWidth: max(1, h * 0.13))
                IslandShape(topRadius: h * 0.08, bottomRadius: h * 0.16)
                    .fill(color)
                    .frame(width: w * 0.44, height: h * 0.34)
            }
        }
    }
}

/// The top of a section's page: what it's for, in a line, lined up with the sections' headers.
/// Oct 21, Ryan ("simpler is better"): the toolbar and the sidebar already name the pane; it
/// was its tile at 56 pt, its name and this line, centered in a box.
struct PaneHeader: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let category: SettingsCategory

    var body: some View {
        if WindowLook.isAligned {
            titled
        } else {
            // Eye tracking's picture says it in full until your session is in.
            if category != .eyeTracking || model.prefs.gaze == .collected { line }
        }
    }

    /// Aligned: the pane titled as the first run titles a page ("Make it yours" over its line):
    /// its name large in the first run's face, what it's for under it. The toolbar no longer
    /// names it too.
    private var titled: some View {
        let A = T.Aligned.self
        return VStack(alignment: .leading, spacing: A.paneTitleGap) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // The first run's face, set closer in than the window's own design.
                Text(category.title)
                    .alignedDisplay(A.paneTitle)
                    .foregroundStyle(palette.text)
                if category == .eyeTracking { SoonPill(text: "Beta") }
            }
            if category != .eyeTracking || model.prefs.gaze == .collected {
                Text(category.summary)
                    .font(.system(size: A.paneLine))
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, T.Native.rowInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(category.title). \(category.summary)"))
        .accessibilityAddTraits(.isHeader)
    }

    private var line: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if category == .eyeTracking { SoonPill(text: "Beta") }
            Text(category.summary)
                .font(.system(size: 12))
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, T.Native.rowInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(category.title). \(category.summary)"))
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
                .background(WindowLook.isAligned ? palette.background : palette.nativePage, ignoresSafeAreaEdges: [])
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
            withAnimation(model.motion.animation(.layout)) { proxy.scrollTo(target, anchor: .top) }
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
        // Oct 15 review, MW-04: the dictionary is a section of its own again (its page is the
        // other window builder's `DictionaryPane`, DI-01).
        case .dictionary: DictionaryPane()
        case .memory: MemorySection()
        case .shortcuts: ShortcutsPane()
        case .connectors: ConnectorsPane()
        case .eyeTracking: EyeTrackingPane()
        // Oct 15 review: Getting Started (OB-03.1, OB-03.2) and About (ST-10, MW-04c), new.
        case .gettingStarted: GettingStartedPane()
        case .about: AboutPane()
        }
    }
}

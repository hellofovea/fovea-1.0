import AppKit
import SwiftUI
import CapturesCore
import FoveaKit

/// The window, in one of two layouts (the panel's Window › Layout). The library, Aside's: the
/// captures listed in the window's own material, an opaque page inset beside them
/// (`LibraryView.swift`). Or the cards alone: the type filter in the toolbar's center and search
/// toward its end, as Calendar and Mail place theirs; the captures as cards, newest first, by
/// day. In both, the profile icon at the top right is the one way in to Settings (opened on
/// Account, where your credits, your words and your memories are).
struct MainView: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.controlActiveState) private var controlActive

    var body: some View {
        let palette = Palette.make(dark: scheme == .dark, surface: model.surface, accent: model.accent.color)
        Group {
            if model.layout == .library {
                LibraryWindow()
            } else {
                cards(palette)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { model.gridWidth = $0 }
        .fontDesign(model.titleDesign.design)
        // Inside the palette and motion below, so the sheets are given them.
        .modifier(WindowSheets())
        // The system's own controls (switches, segmented controls, the sidebar's selection) take
        // the chosen accent too.
        .tint(model.accent.color)
        // The snapshot harness draws the window as the front one, as it would be in use.
        .environment(\.controlActiveState, WindowMaterial.alwaysActive ? .key : controlActive)
        .environment(\.palette, palette)
        .environment(\.motion, model.motion)
        .environment(\.liquidGlass, model.liquidGlass)
        // The library has no toolbar: its controls live in the sidebar and on the page.
        .toolbar { if model.layout == .cards { Toolbar() } }
    }

    /// The cards under a toolbar, on a page inset in the window (Aside's shading): the window
    /// is the system's material around it, the desktop showing through as through Aside's, and
    /// the page is opaque, 8 pt in from the window's edges, its corners concentric with the
    /// window's (`T.Layout.pageRadius`). Fovea's own schemes frame it in their canvas, or the
    /// Island's ink. On the panel the page can fill the window instead, as before.
    private func cards(_ palette: Palette) -> some View {
        let inset = model.pageStyle == .inset
        // Settings in the Mac's way: its sidebar on the window's material at the left, the page
        // beside it (`SettingsSidebar.swift`).
        let sidebar = model.page == .settings && model.settingsLayout.hasSidebar
        return ZStack {
            if inset || sidebar {
                if palette.surface == .system || !inset {
                    WindowMaterial(style: model.windowMaterial).ignoresSafeArea()
                } else {
                    // The canvas a step darker, so the page's edge shows; or the Island's ink.
                    ZStack {
                        palette.frame
                        if !palette.bandIsDark { palette.ink(palette.isDark ? 0.03 : 0.05) }
                    }
                    .ignoresSafeArea()
                }
            }
            HStack(spacing: 0) {
                if sidebar {
                    SettingsSidebar()
                        .frame(width: T.Native.sidebarWidth)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    if !inset { Rectangle().fill(palette.hairline).frame(width: 0.5).ignoresSafeArea() }
                }
                canvas(palette, inset: inset)
                    .modifier(InsetPage(on: inset))
            }
        }
        .onPreferenceChange(CardFramesKey.self) { frames in model.cardFrames = frames }
    }

    /// The page's content: the captures, a day or Settings; the expanded card over them; the
    /// toast at the foot.
    private func canvas(_ palette: Palette, inset: Bool) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if !inset { palette.background.ignoresSafeArea() }
                // Fovea's schemes draw the toolbar's band themselves (the titlebar is transparent):
                // the canvas color, or the Island's ink across the top; a hairline under it.
                if !inset, let band = palette.band {
                    VStack(spacing: 0) {
                        band.frame(height: geo.safeAreaInsets.top)
                        Rectangle().fill(palette.bandIsDark ? Color.black : palette.hairline).frame(height: 0.5)
                    }
                    .frame(width: geo.size.width)
                    .offset(y: -geo.safeAreaInsets.top)
                    .zIndex(1)
                    .allowsHitTesting(false)
                }
                ZStack(alignment: .top) {
                    switch model.page {
                    case .captures:
                        CapturesPage().transition(.page(forward: model.pageForward))
                            // The notch's panels attached: Home's switcher hangs from the page's top
                            // edge as the notch hangs from the screen's (NotchLook.swift).
                            .overlay(alignment: .top) {
                                if model.prefs.panels == .attached, model.windowError == nil { NotchSwitcher(hanging: true) }
                            }
                    case .day:
                        CapturesPage(day: true).transition(.page(forward: model.pageForward))
                    case .settings:
                        SettingsPage().transition(.page(forward: model.pageForward))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                if model.page != .settings, let capture = model.detail {
                    DetailOverlay(capture: capture, container: geo.size)
                        .zIndex(2)
                }
                // A picture opened large from the expanded card (row 28).
                if let v = model.viewing, let capture = model.library.captures.first(where: { $0.id == v.capture }),
                   let attachment = capture.attachments.first(where: { $0.index == v.index }) {
                    ImageViewer(capture: capture, attachment: attachment)
                        .transition(.opacity)
                        .zIndex(2.5)
                }
                // The window can't open its data (row 13, 1–3): that, and nothing else.
                if let error = model.windowError {
                    WindowErrorView(error: error)
                        .transition(.opacity)
                        .zIndex(2.8)
                }
                Toast()
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                    .zIndex(3)
            }
            .coordinateSpace(name: Space.root)
        }
    }
}

/// The window's sheets (rows 9, 24): Report a Problem, the memories, the agents' reading. Each is a
/// window of its own, so it's given the window's palette and accent.
struct WindowSheets: ViewModifier {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion

    func body(content: Content) -> some View {
        @Bindable var model = model
        content
            .sheet(isPresented: $model.reporting) { themed(ReportProblemSheet()) }
            .background {
                Color.clear.sheet(isPresented: $model.browsingMemories) { themed(MemoryBrowser()) }
            }
            .background {
                Color.clear.sheet(isPresented: $model.accessLogShown) { themed(AccessLogSheet()) }
            }
    }

    private func themed<V: View>(_ view: V) -> some View {
        view
            .environment(model)
            .environment(\.palette, palette)
            .environment(\.motion, motion)
            .tint(model.accent.color)
    }
}

/// The page inset in the window: opaque, clipped to its concentric corners, with Aside's edge
/// and its soft two-layer shadow on the material around it.
private struct InsetPage: ViewModifier {
    @Environment(\.palette) private var palette
    let on: Bool

    func body(content: Content) -> some View {
        if on {
            let shape = RoundedRectangle(cornerRadius: T.Layout.pageRadius, style: .continuous)
            content
                .background(palette.background)
                .clipShape(shape)
                .shading(shape, .page, fill: palette.background)
                .padding(.horizontal, T.Layout.pageInset)
                .padding(.bottom, T.Layout.pageInset)
        } else {
            content
        }
    }
}

// MARK: - Toolbar

/// Three groups, each with room: the app filter at the leading edge, the type at the center,
/// search and you at the trailing edge.
struct Toolbar: ToolbarContent {
    @Environment(CapturesModel.self) private var model
    @Environment(\.colorScheme) private var scheme

    /// Toolbar items don't inherit the window's environment: each gets the scheme's palette
    /// here, the dark one over the Notch scheme's ink band.
    private var palette: Palette {
        let base = Palette.make(dark: scheme == .dark, surface: model.surface, accent: model.accent.color)
        return base.bandIsDark && !base.isDark ? Palette.make(dark: true, surface: model.surface, accent: model.accent.color) : base
    }

    var body: some ToolbarContent {
        let p = palette
        if model.windowError != nil {
            // The window can't open its data (row 13, 1–3): nothing to filter, search or open,
            // so the toolbar keeps only its height.
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
        } else if model.page != .settings {
            if model.page == .day {
                ToolbarItem(placement: .navigation) { BackButton().toolbarScheme(p) }
            } else if #available(macOS 26.0, *) {
                // Its own glass circle, as tall as search's and yours, not a capsule hugging the
                // icon.
                ToolbarItem(placement: .navigation) { AppFilter().toolbarScheme(p) }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .navigation) { AppFilter().toolbarScheme(p) }
            }
            // Its own glass track, so the pill sits the same 4 pt in on every side.
            if #available(macOS 26.0, *) {
                ToolbarItem(placement: .principal) { HomeSwitcherSlot().toolbarScheme(p) }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .principal) { HomeSwitcherSlot().toolbarScheme(p) }
            }
            // Search draws its own glass (a circle, then a capsule as it opens), so the slot it
            // keeps for the open field doesn't show as an empty capsule; you, a circle of glass
            // the same height as the toolbar's (36.5 pt on macOS 27, measured).
            if #available(macOS 26.0, *) {
                ToolbarItem(placement: .primaryAction) { ExpandingSearch().toolbarScheme(p) }
                    .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .primaryAction) { GlassAvatar().toolbarScheme(p) }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .primaryAction) { ExpandingSearch().toolbarScheme(p) }
                ToolbarItem(placement: .primaryAction) { Avatar().toolbarScheme(p) }
            }
        } else if model.settingsLayout.hasSidebar {
            // As System Settings: back in its glass, then the section's name as plain text, at
            // the leading edge; you at the trailing edge (an empty center keeps you there).
            ToolbarItem(placement: .navigation) { BackButton().toolbarScheme(p) }
            if #available(macOS 26.0, *) {
                ToolbarItem(placement: .navigation) { SectionTitle(palette: p) }
                    .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
                    .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .primaryAction) { GlassAvatar().toolbarScheme(p) }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .navigation) { SectionTitle(palette: p) }
                ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
                ToolbarItem(placement: .primaryAction) { Avatar().toolbarScheme(p) }
            }
        } else {
            ToolbarItem(placement: .navigation) { BackButton().toolbarScheme(p) }
            if #available(macOS 26.0, *) {
                ToolbarItem(placement: .principal) {
                    Group { if model.settingsLayout == .tabs { SettingsTabs() } }.toolbarScheme(p)
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .principal) {
                    Group { if model.settingsLayout == .tabs { SettingsTabs() } }.toolbarScheme(p)
                }
            }
            if #available(macOS 26.0, *) {
                ToolbarItem(placement: .primaryAction) { GlassAvatar().toolbarScheme(p) }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .primaryAction) { Avatar().toolbarScheme(p) }
            }
        }
    }
}

/// All · Dictation · Capture · Dispatch: what kind of thing you're looking for, at the center of
/// the toolbar. Aside's segmented control: the chosen one a pill that slides to it, each kind
/// with its mark. The System scheme's pill is white and raised (Aside's); Fovea's own schemes
/// choose with the Island's black (the notch, in the window). The track is glass, as tall as
/// the toolbar's other glass.
struct KindPicker: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let segments = [SlidingSegments<CaptureKind?>.Segment(value: nil, title: "All", help: "Show everything")]
            + CaptureKind.allCases.map { .init(value: $0, title: $0.title, kind: $0, help: "Show only \($0.plural.lowercased())") }
        // A 28 pt pill 4 pt inside a 36 pt glass track: as tall as the toolbar's other glass,
        // and concentric with it at both ends.
        return SlidingSegments(segments: segments, selection: model.query.kind,
                               pill: palette.surface == .system ? .raised : .island, track: .glass,
                               height: T.Layout.toolbarControl - 8, inset: 4) { model.setKind($0) }
            .accessibilityLabel("Show")
    }
}

/// Which app (or, for a dispatch, which agent; in a browser, the website too), which tag, and
/// when: the four squares at the toolbar's leading edge, a pull-down that lists every app with
/// its own icon, the tags most used first, then the times.
struct AppFilter: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let captures = model.library.captures
        let app = model.query.app
        let date = model.query.date
        let tag = model.query.tag
        Menu {
            Picker("App", selection: Binding(get: { app }, set: { v in model.animate(.swap) { model.query.app = v } })) {
                // macOS menus show a label's icon only when asked to (title and icon).
                Label("All Apps", systemImage: "square.grid.2x2")
                    .labelStyle(.titleAndIcon)
                    .tag(String?.none)
                Divider()
                ForEach(CaptureSearch.apps(in: captures), id: \.self) { name in
                    Label { Text(name) } icon: { Image(nsImage: Art.menuIcon(name, in: captures)) }
                        .labelStyle(.titleAndIcon)
                        .tag(String?.some(name))
                }
            }
            .pickerStyle(.inline)
            Divider()
            // The tags (row 25), most used first; the rest under More.
            let tags = CaptureSearch.tags(in: captures)
            Picker("Tag", selection: Binding(get: { tag }, set: { v in model.animate(.swap) { model.query.tag = v } })) {
                Label("All Tags", systemImage: "tag")
                    .labelStyle(.titleAndIcon)
                    .tag(String?.none)
                ForEach(tags.prefix(8), id: \.tag) { t in
                    Text(t.tag).tag(String?.some(t.tag))
                }
            }
            .pickerStyle(.inline)
            if tags.count > 8 {
                Menu("More Tags") {
                    Picker("More Tags", selection: Binding(get: { tag }, set: { v in model.animate(.swap) { model.query.tag = v } })) {
                        ForEach(tags.dropFirst(8), id: \.tag) { t in
                            Text(t.tag).tag(String?.some(t.tag))
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            Divider()
            // The cards' period: the last three days (the default), or today. Any other day is
            // the calendar's, above the cards.
            Picker("Show", selection: Binding(get: { model.scope },
                                              set: { v in model.animate(.swap) { model.query.date = v == .threeDays ? nil : v } })) {
                ForEach([CaptureQuery.DateFilter.threeDays, .today], id: \.self) { d in
                    Text(d.title).tag(d)
                }
            }
            .pickerStyle(.inline)
        } label: {
            // Just the four squares: what it does is found by opening it. Filled while a filter
            // is on (the line above the cards says which).
            Image(systemName: app == nil && date == nil && tag == nil ? "square.grid.2x2" : "square.grid.2x2.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(palette.text)
                // The whole circle opens it, not just the glyph.
                .frame(width: T.Layout.toolbarControl, height: T.Layout.toolbarControl)
                .contentShape(Circle())
        }
        // A plain button's menu: the label's frame is the button, so the whole circle opens it
        // (a pull-down's would shrink to the glyph).
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .modifier(ToolbarCircle())
        .help("Show captures from one app, with one tag, or from one time")
        .accessibilityLabel(app.map { "Filtered by \($0)" } ?? tag.map { "Filtered by \($0)" } ?? "Filter by app, tag or time")
    }
}

/// Search as an icon until you want it, as a toolbar's collapsed search field: a click (or ⌘F)
/// opens it into a field from where the icon was, with the cursor in it; it folds back into the
/// icon when you leave it empty, or press Esc. While it holds a search it stays open.
struct ExpandingSearch: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion
    @FocusState private var focused: Bool
    @State private var open = false
    @State private var hover = false
    @State private var bumps = 0

    var body: some View {
        @Bindable var model = model
        let expanded = open || !model.query.text.isEmpty
        let shape = Capsule()
        let width = model.compactToolbar ? T.Layout.compactSearchWidth : T.Layout.searchWidth
        // The toolbar keeps a slot as wide as the open field, so nothing around it moves; the
        // field grows leftward inside it, out of the icon, its magnifier riding the leading edge.
        ZStack(alignment: .trailing) {
            Color.clear.frame(width: width, height: T.Layout.toolbarControl)
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(expanded ? palette.secondary : (hover ? palette.text : palette.secondary))
                    .symbolEffect(.bounce, value: bumps)
                    .frame(width: 18)
                if expanded {
                    TextField("Search", text: $model.query.text)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($focused)
                        .onSubmit { focused = false }
                        .onExitCommand { close(clear: true) }
                        // AppKit draws the text field at its final size at once, so its text waits
                        // for the field to finish opening, and leaves first when it closes.
                        .transition(.asymmetric(
                            insertion: .opacity.animation(motion.animation(.content).delay(motion.seconds(0.17))),
                            removal: .opacity.animation(.easeOut(duration: motion.seconds(0.05)))))
                    if !model.query.text.isEmpty {
                        Button { model.query.text = "" } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundStyle(palette.tertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear")
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity.animation(.easeOut(duration: motion.seconds(0.05)))))
                    }
                }
            }
            .padding(.horizontal, 9)
            .frame(width: expanded ? width : T.Layout.toolbarControl, height: T.Layout.toolbarControl, alignment: .leading)
            .clipped()
            .modifier(SearchSurface(expanded: expanded, hover: hover, focused: expanded && focused))
            .contentShape(shape)
            .onHover { h in
                hover = h
                if h && !expanded { bumps += 1 }
            }
            .onTapGesture { if !expanded { openSearch() } }
        }
        .onChange(of: focused) { _, now in
            if !now && model.query.text.isEmpty { close(clear: false) }
        }
        .onChange(of: model.searchRequest) { _, n in n < 0 ? close(clear: true) : openSearch() }
        .animation(motion.animation(.hover), value: hover)
        .help("Search your words and what you took (⌘F)")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search")
    }

    private func openSearch() {
        withAnimation(.interpolatingSpring(duration: motion.seconds(0.26), bounce: 0)) { open = true }
        // Focus once the field exists.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(20))
            focused = true
        }
    }

    private func close(clear: Bool) {
        if clear { model.query.text = "" }
        focused = false
        withAnimation(.interpolatingSpring(duration: motion.seconds(0.2), bounce: 0)) { open = false }
    }
}

/// What search is made of. On macOS 26 and later, the toolbar's Liquid Glass: a circle around
/// the magnifier, a capsule once it opens. Before, Aside's field: a capsule of the ink at 7 %
/// with a 12 % edge, 10 % under the pointer. With the keyboard in it, Aside's focus edge (the
/// ink at 25 %), not a blue ring.
private struct SearchSurface: ViewModifier {
    @Environment(\.palette) private var palette
    let expanded: Bool
    let hover: Bool
    let focused: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: Capsule())
                .overlay { if focused { Capsule().strokeBorder(palette.ink(T.Shade.focus), lineWidth: 1) } }
        } else {
            content
                .background(Capsule().fill(palette.ink(expanded ? (hover || focused ? T.Shade.fillHover : T.Shade.fill)
                                                                : (hover ? T.Shade.fill : 0))))
                .overlay {
                    if expanded {
                        Capsule().strokeBorder(palette.ink(focused ? T.Shade.focus : T.Shade.line), lineWidth: focused ? 1 : 0.5)
                    }
                }
        }
    }
}

extension View {
    /// A toolbar item's palette, and the appearance its glass takes: dark over the Notch
    /// scheme's ink band, as the system's own items there are.
    func toolbarScheme(_ palette: Palette) -> some View {
        environment(\.palette, palette).environment(\.colorScheme, palette.isDark ? .dark : .light)
    }
}

/// A toolbar control's own glass circle, on macOS 26 and later (before, the toolbar draws none).
struct ToolbarCircle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Circle())
        } else {
            content
        }
    }
}

/// You, in a glass circle as tall as the toolbar's other glass.
struct GlassAvatar: View {
    var body: some View {
        Avatar()
            .padding((T.Layout.toolbarControl - 28) / 2)
            .glass(Circle(), interactive: true)
    }
}

/// Settings' section, named in the toolbar as System Settings names its pane.
struct SectionTitle: View {
    @Environment(CapturesModel.self) private var model
    let palette: Palette
    var body: some View {
        Text(model.settingsCategory.title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(palette.text)
            .contentTransition(.opacity)
            .padding(.leading, 6)
            .toolbarScheme(palette)
    }
}

/// Back to the captures, at the toolbar's leading edge.
struct BackButton: View {
    @Environment(CapturesModel.self) private var model
    var body: some View {
        Button { model.back() } label: { Label("Back", systemImage: "chevron.left") }
            .help("Back to Captures (⌘[)")
    }
}

/// Your initial in a circle, ringed by an arc of the credits used (an arc only, no track): the
/// one icon at the top right. Hover shows what's left; a click opens Settings on Account, and
/// a second click comes back.
struct Avatar: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var hover = false

    var body: some View {
        let usage = model.usage
        let here = model.page == .settings
        Button { model.profile() } label: {
            ZStack {
                if model.avatarStyle == .eye {
                    // The icon's o: you in its rounded square, the credits used running round it as
                    // a thick ring (an arc only, no track: AGENTS.md).
                    RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                        .fill(here ? palette.pill : palette.text.opacity(0.1))
                        .frame(width: 19, height: 19)
                    face(here: here, size: 19, shape: RoundedRectangle(cornerRadius: 6.5, style: .continuous))
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .trim(from: 0, to: usage.fraction)
                        .stroke(arc(usage.fraction, calm: palette.text), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .frame(width: 25, height: 25)
                } else {
                    Circle()
                        .fill(here ? palette.pill : palette.text.opacity(0.1))
                        .frame(width: 20, height: 20)
                    face(here: here, size: 20, shape: Circle())
                    Circle()
                        .trim(from: 0, to: usage.fraction)
                        .stroke(arc(usage.fraction, calm: palette.secondary), style: StrokeStyle(lineWidth: 1.75, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 25, height: 25)
                }
            }
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(here ? "Back to Captures" : "Account and Settings")
        .accessibilityLabel("Account and Settings. \(Lines.credits(usage))")
        .onHover { h in
            hover = h
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(h ? 400 : 150))
                if hover == h { model.usageShown = h }
            }
        }
        .popover(isPresented: Binding(get: { model.usageShown }, set: { model.usageShown = $0 }), arrowEdge: .bottom) {
            UsagePopover()
        }
    }

    /// Your photo, or your initial (row 8).
    @ViewBuilder private func face<S: Shape>(here: Bool, size: CGFloat, shape: S) -> some View {
        if let photo = model.profilePhoto {
            Image(nsImage: photo).resizable().aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(shape)
        } else {
            Text(verbatim: model.initial)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(here ? palette.onPill : palette.text)
        }
    }

    /// The arc in the bar's colors (row 13): amber past 70 %, red past 90 %.
    private func arc(_ fraction: Double, calm: Color) -> Color {
        fraction >= 0.9 ? palette.danger : (fraction >= 0.7 ? palette.warning : calm)
    }
}

/// What's left of the plan, on hover, with the Mac's capacity indicator. A popover is a window of
/// its own, so it doesn't take the window's accent: it's given it here.
struct UsagePopover: View {
    @Environment(CapturesModel.self) private var model
    var body: some View {
        let usage = model.usage
        let f = usage.fraction
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(usage.plan) plan").font(.headline)
                Spacer()
            }
            // The Mac's capacity indicator, as in Settings › Plan.
            CreditsLevel(used: usage.used, total: usage.total)
            Text(Lines.credits(usage)).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            // What the plan's states say (row 13, 4–6), where you'd see them first.
            if usage.left == 0 {
                Text("Taking things and dispatching wait until \(Lines.day(usage.resets)). Dictation stays free.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Upgrade…") { model.usageShown = false; model.openSettings(.plan) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            } else if f >= 0.9 {
                Text("Almost out.").font(.caption).foregroundStyle(Color(nsColor: .systemRed))
            }
            if model.planAlert == .paymentProcessing {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("Your payment is processing. Pro unlocks on its own.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(width: 260)
        .tint(model.accent.color)
    }
}

// MARK: - Captures page

/// One centered column of cards that takes the keyboard: the first page (this week, then the
/// calendar), search results (every match, whenever it was), or one day's archive.
struct CapturesPage: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @FocusState private var focused: Bool
    /// The day page: one day's cards under its name.
    var day = false

    var body: some View {
        GeometryReader { geo in
            let layout = GridLayout(width: geo.size.width, side: model.cardSize.width, gap: model.cardSpacing.gridGap(model.surface))
            VStack(spacing: 0) {
                if !day && model.historyStyle == .timeline && !model.library.captures.isEmpty {
                    TimelineStrip(width: layout.contentWidth)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                        .frame(maxWidth: .infinity)
                        .background(palette.background)
                        .overlay(alignment: .bottom) { Rectangle().fill(palette.hairline).frame(height: 1) }
                }
                ScrollViewReader { reader in
                    ScrollView {
                        // The grid as one centered block, as wide as its columns: the space left
                        // over goes to both sides equally instead of piling up on the right.
                        VStack(alignment: .leading, spacing: 0) {
                            // The top is above the inset, so scrolling to it shows the inset too; with
                            // the switcher hanging from the page's top, below it.
                            Color.clear.frame(height: model.cardSpacing.metrics.contentInset
                                              + (!day && model.prefs.panels == .attached ? T.Library.islandHeight : 0)).id("top")
                            content(layout)
                        }
                        .frame(width: layout.contentWidth, alignment: .leading)
                        .padding(.bottom, model.cardSpacing.metrics.sectionGap)
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: model.scrollTarget) { _, id in
                        guard let id else { return }
                        // Without motion (a keyboard step, or behind the expanded card so the way
                        // back lands on it).
                        reader.scrollTo(id, anchor: id == "earlier" || id == "top" ? .top : nil)
                        model.scrollTarget = nil
                    }
                    .modifier(GridKeys(focused: $focused))
                }
            }
        }
    }

    @ViewBuilder private func content(_ layout: GridLayout) -> some View {
        if day, let d = model.archiveDay {
            DayHeader(day: d)
                .padding(.bottom, 24)
            ZStack(alignment: .topLeading) {
                CaptureGrid(matches: model.matches(on: d), columns: layout.columns, dayHeaders: false, emptyNote: "")
                    .id(DayKey(day: d, kind: model.query.kind))
                    .transition(.blockSwap)
            }
        } else {
            // A filter or a search swaps the page as one layer: out, then in.
            ZStack(alignment: .topLeading) {
                HomeFeed(layout: layout)
                    .id(GridKey(query: model.query, fixture: model.fixture))
                    .transition(.blockSwap)
            }
        }
    }
}

private struct DayKey: Hashable { let day: Date; let kind: CaptureKind? }

/// The grid takes the keyboard as Finder's icon view does: arrows move the ring, Space or
/// Return opens, Esc lets go. With the expanded card out, ← → step it.
struct GridKeys: ViewModifier {
    @Environment(CapturesModel.self) private var model
    var focused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        content
            .focusable()
            .focused(focused)
            .focusEffectDisabled()
            .onKeyPress(.leftArrow) { key(-1) }
            .onKeyPress(.rightArrow) { key(1) }
            .onKeyPress(.upArrow) { model.detailID == nil ? key(-model.columns) : .ignored }
            .onKeyPress(.downArrow) { model.detailID == nil ? key(model.columns) : .ignored }
            .onKeyPress(.space) { openSelected() }
            .onKeyPress(.return) { openSelected() }
            .onKeyPress(.escape) {
                guard model.detailID == nil, model.selectedID != nil else { return .ignored }
                model.selectedID = nil
                return .handled
            }
            .onChange(of: model.selectedID) { _, id in if id != nil { focused.wrappedValue = true } }
            // In the library the list beside the page holds the keyboard from the start.
            .onAppear { if model.layout == .cards { focused.wrappedValue = true } }
    }

    private func key(_ delta: Int) -> KeyPress.Result {
        if model.detailID != nil {
            model.step(delta > 0 ? 1 : -1)
        } else {
            model.moveSelection(delta)
        }
        return .handled
    }

    private func openSelected() -> KeyPress.Result {
        guard model.detailID == nil, let id = model.selectedID else { return .ignored }
        model.open(id)
        return .handled
    }
}

/// "Filtered by Slack · This week", with Clear, above the grid (Mail's filter line).
struct FilteredLine: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    var body: some View {
        let parts = [model.query.app, model.query.tag.map { "“\($0)”" }, model.query.date?.title].compactMap { $0 }
        HStack(spacing: 8) {
            Text("Filtered by").foregroundStyle(palette.secondary)
            Text(parts.joined(separator: " · ")).foregroundStyle(palette.text).fontWeight(.medium)
            PillButton("Clear", symbol: "xmark", kind: .plain) {
                model.animate(.swap) { model.query.app = nil; model.query.date = nil; model.query.tag = nil }
            }
        }
        .font(.system(size: 12))
    }
}

private struct GridKey: Hashable {
    let kind: CaptureKind?, app: String?, date: CaptureQuery.DateFilter?, tag: String?, empty: Bool, fixture: FixtureSet
    init(query: CaptureQuery, fixture: FixtureSet) {
        kind = query.kind; app = query.app; date = query.date; tag = query.tag; empty = query.tokens.isEmpty; self.fixture = fixture
    }
}

/// How many cards fit a row at a width, and how wide those columns are together.
struct GridLayout {
    let columns: Int
    let contentWidth: CGFloat
    init(width: CGFloat, side: CGFloat, gap: CGFloat) {
        let fit = Int((width - 2 * T.Layout.sideMargin + gap) / (side + gap))
        columns = min(T.Layout.maxColumns, max(1, fit))
        contentWidth = CGFloat(columns) * side + CGFloat(columns - 1) * gap
    }
}

/// The cards by day, newest first.
struct CaptureGrid: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let matches: [CaptureMatch]
    let columns: Int
    /// A title over each day's cards (not on a day's own page, which names it once).
    var dayHeaders = true
    /// What an empty grid says, when it isn't a search with no results.
    var emptyNote: String?

    var body: some View {
        let groups = Self.days(matches, now: model.now)
        let side = model.cardSize.width
        let gap = model.cardSpacing.gridGap(model.surface)
        // A search can reach back a year: its days are built as they scroll into view.
        LazyVStack(alignment: .leading, spacing: model.cardSpacing.metrics.sectionGap) {
            if matches.isEmpty {
                if let emptyNote, !model.library.captures.isEmpty {
                    // An empty note says nothing: the header above already does.
                    if !emptyNote.isEmpty { Text(emptyNote).font(.system(size: 13)).foregroundStyle(palette.tertiary) }
                } else {
                    EmptyState()
                }
            }
            ForEach(groups, id: \.title) { group in
                VStack(alignment: .leading, spacing: model.cardSpacing.metrics.dayLabelGap) {
                    if dayHeaders {
                        DayTitle(title: group.title, count: group.matches.count)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(side), spacing: gap, alignment: .top), count: columns),
                              alignment: .leading, spacing: gap) {
                        ForEach(group.matches, id: \.capture.id) { match in
                            CaptureCard(match: match)
                        }
                    }
                }
            }
        }
    }

    struct Day { let title: String; var matches: [CaptureMatch] }

    static func days(_ matches: [CaptureMatch], now: Date) -> [Day] {
        var out: [Day] = []
        for m in matches {
            let title = Lines.dayGroup(m.capture.time, now: now)
            if out.last?.title == title { out[out.count - 1].matches.append(m) } else { out.append(Day(title: title, matches: [m])) }
        }
        return out
    }
}

/// A day's name as a small tracked label with its count in mono ("TODAY  10"), the way Fovea
/// labels its sections.
struct DayTitle: View {
    @Environment(\.palette) private var palette
    let title: String
    var count: Int?
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.9)
                .foregroundStyle(palette.secondary)
            if let count {
                Text("\(count)").font(.system(size: 11, design: .monospaced)).foregroundStyle(palette.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct EmptyState: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    var body: some View {
        VStack(spacing: 6) {
            if model.library.captures.isEmpty {
                Text("No Captures Yet").font(.system(size: 17, weight: .semibold)).foregroundStyle(palette.secondary)
                HStack(spacing: 4) {
                    Text("Press").foregroundStyle(palette.tertiary)
                    KeyCap("fn")
                    Text("and speak. What you say and take shows up here.").foregroundStyle(palette.tertiary)
                }
                .font(.system(size: 13))
            } else {
                Text("No Results").font(.system(size: 17, weight: .semibold)).foregroundStyle(palette.secondary)
                Text("Fovea searches your words and the text in what you took.")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 120)
        // Texture only where there's nothing else: a faint grid of dots.
        .background(DotGrid().mask(RadialGradient(colors: [.black, .clear], center: .center, startRadius: 40, endRadius: 320)))
        .padding(.top, 30)
    }
}

/// A faint grid of ink dots, for empty places only.
struct DotGrid: View {
    @Environment(\.palette) private var palette
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 14
            var y: CGFloat = step / 2
            while y < size.height {
                var x: CGFloat = step / 2
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x - 0.75, y: y - 0.75, width: 1.5, height: 1.5)), with: .color(palette.text.opacity(0.14)))
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct KeyCap: View {
    let key: String
    init(_ key: String) { self.key = key }
    var body: some View {
        Text(key)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 6)
            .frame(minWidth: 22, minHeight: 20)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color(nsColor: .labelColor).opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color(nsColor: .labelColor).opacity(0.14), lineWidth: 0.5))
    }
}

/// A short notice at the window's foot, with Undo after a delete: it rises 8 pt out of a slight
/// blur and sinks back the same way, quicker.
struct Toast: View {
    @Environment(CapturesModel.self) private var model
    var body: some View {
        ZStack {
            if let message = model.toast, !model.sheetUp {
                HStack(spacing: 12) {
                    Text(message).font(.system(size: 12.5, weight: .medium))
                    if model.lastDeleted != nil || !model.lastDeletedMemories.isEmpty {
                        Button("Undo") { model.undoDelete() }
                            .buttonStyle(.plain)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .keyboardShortcut("z", modifiers: .command)
                    }
                }
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(.horizontal, 16)
                .frame(height: 34)
                .background(Capsule().fill(Color.black.opacity(0.78)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                .transition(.modifier(active: ToastRise(progress: 0), identity: ToastRise(progress: 1)))
            }
        }
        .padding(.bottom, 20)
    }
}

struct ToastRise: ViewModifier, Animatable {
    @Environment(\.motion) private var motion
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        let travel = motion.reduce ? 0 : 1 - progress
        content.opacity(progress).offset(y: 8 * travel).blur(radius: 2 * travel)
    }
}

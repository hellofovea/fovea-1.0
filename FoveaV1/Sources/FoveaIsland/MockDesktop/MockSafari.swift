import SwiftUI
import AppKit
import FoveaCore

/// One open tab: a page to capture from.
struct SafariTab: Identifiable, Hashable {
    enum Page: Hashable { case article, gallery, notes, code }
    let id: Int
    let title: String
    let host: String
    let symbol: String
    let page: Page

    static let all: [SafariTab] = [
        SafariTab(id: 0, title: "Snow returns to the high valleys", host: "alpine.example.com", symbol: "mountain.2.fill", page: .article),
        SafariTab(id: 1, title: "Autumn portfolio — Photographs", host: "photos.example.com", symbol: "photo.fill", page: .gallery),
        SafariTab(id: 2, title: "Island motion — Design notes", host: "notes.example.com", symbol: "doc.text.fill", page: .notes),
        SafariTab(id: 3, title: "IslandShape.swift · fovea", host: "code.example.com", symbol: "chevron.left.forwardslash.chevron.right", page: .code),
    ]
}

/// Safari taken full screen, with several tabs open: the toolbar without traffic lights (full
/// screen hides them), the address of the tab on show, the tab bar in Safari's separate
/// layout, and the pages. Every page stays alive, so each keeps its scroll position. Static
/// content, so a snapshot is the same on every Mac. The caller places it under the black band
/// beside the notch.
struct MockSafari: View {
    let model: WorkbenchModel

    var body: some View {
        content
            .environment(\.agentAnchorReporter, AgentAnchorReporter { name, rect in model.agentAnchors["safari.\(name)"] = rect })
    }

    private var content: some View {
        VStack(spacing: 0) {
            toolbar
            tabBar
                .agentAnchor("tabs")
            Divider()
            ZStack {
                ForEach(model.tabs) { tab in
                    let shown = tab.id == model.selectedTab
                    SafariPage(tab: tab, model: model)
                        .opacity(shown ? 1 : 0)
                        .allowsHitTesting(shown)
                        .accessibilityHidden(!shown)
                }
            }
        }
    }

    /// Where tab `index` sits, in display points: equal widths across the bar.
    static func tabFrame(_ index: Int, count: Int, displayWidth: CGFloat, top: CGFloat) -> CGRect {
        let T = WorkbenchTokens.Safari.self
        let width = (displayWidth - 2 * T.tabBarPadding - CGFloat(count - 1) * T.tabGap) / CGFloat(count)
        return CGRect(x: T.tabBarPadding + CGFloat(index) * (width + T.tabGap),
                      y: top + T.toolbarHeight + (T.tabBarHeight - T.tabHeight) / 2,
                      width: width, height: T.tabHeight)
    }

    private var toolbar: some View {
        HStack(spacing: WorkbenchTokens.Safari.toolbarSpacing) {
            Image(systemName: "sidebar.left")
            Image(systemName: "chevron.left")
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            Spacer(minLength: 0)
            AddressField(host: model.tabs[model.selectedTab].host, typed: model.agentAddress)
                .agentAnchor("address")
            Spacer(minLength: 0)
            Image(systemName: "square.and.arrow.up")
            Image(systemName: "plus")
            Image(systemName: "square.on.square")
        }
        .font(WorkbenchTokens.Safari.toolbarGlyph)
        .foregroundStyle(.secondary)
        .padding(.horizontal, WorkbenchTokens.Safari.toolbarPadding)
        .frame(height: WorkbenchTokens.Safari.toolbarHeight)
        .frame(maxWidth: .infinity)
        .background(WorkbenchTokens.Materials.menuBar)
    }

    private var tabBar: some View {
        let T = WorkbenchTokens.Safari.self
        let width = Self.tabFrame(0, count: model.tabs.count, displayWidth: model.display.frame.width, top: 0).width
        return HStack(spacing: T.tabGap) {
            ForEach(model.tabs) { tab in
                SafariTabButton(tab: tab, selected: tab.id == model.selectedTab) { model.selectTab(tab.id) }
                    .frame(width: width, height: T.tabHeight)
            }
        }
        .padding(.horizontal, T.tabBarPadding)
        .frame(height: T.tabBarHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkbenchTokens.Materials.menuBar)
    }
}

struct SafariTabButton: View {
    let tab: SafariTab
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        let T = WorkbenchTokens.Safari.self
        Button(action: action) {
            HStack(spacing: T.tabSpacing) {
                Image(systemName: tab.symbol)
                    .font(T.tabGlyph)
                    .foregroundStyle(T.faviconTints[tab.id % T.faviconTints.count])
                Text(tab.title)
                    .font(selected ? T.tabFontSelected : T.tabFont)
                    .foregroundStyle(selected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, T.tabSpacing + 3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: T.tabRadius, style: .continuous)
                    .fill(selected ? T.tabSelected : (hovering ? T.tabHover : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Bundled photos, read once.
@MainActor
enum PageImages {
    private static var cache: [String: NSImage] = [:]
    static func named(_ name: String) -> NSImage? {
        if let image = cache[name] { return image }
        let image = Wallpaper.bundled(name)
        cache[name] = image
        return image
    }
}

/// One tab's page: a scroll view that keeps its place, answers the demo's scroll requests,
/// and reports how far it is scrolled. Pages keep their own light look whatever the system
/// appearance, as web pages do.
struct SafariPage: View {
    let tab: SafariTab
    let model: WorkbenchModel
    private var space: String { "page-\(tab.id)" }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // The page's real top, padding included: where a reset lands.
                    Color.clear.frame(height: 0).id("top")
                    content
                        .padding(.top, WorkbenchTokens.Safari.pageTop)
                        .padding(.bottom, WorkbenchTokens.Safari.pageBottom)
                        .frame(maxWidth: .infinity)
                        .screenCursor(capturing: model.capturing, highlighting: model.highlighting, accent: model.accent)
                        .onGeometryChange(for: CGFloat.self) { -$0.frame(in: .named(space)).minY } action: {
                            model.pageOffsets[tab.id] = $0
                        }
                }
            }
            .coordinateSpace(name: space)
            .environment(\.agentAnchorReporter, AgentAnchorReporter { [tab] name, rect in
                model.agentAnchors["\(tab.page).\(name)"] = rect
            })
            .onChange(of: model.scrollRequest) { _, request in
                guard let request, request.tab == tab.id else { return }
                withAnimation(WorkbenchTokens.Safari.scrollAnimation) { proxy.scrollTo(request.anchor, anchor: .top) }
            }
            .onChange(of: model.scrollReset) { _, _ in proxy.scrollTo("top", anchor: .top) }
        }
        .background(WorkbenchTokens.Colors.page)
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder private var content: some View {
        switch tab.page {
        case .article: ArticlePage(hero: model.pageHero)
        case .gallery: GalleryPage()
        case .notes: NotesPage(pasted: model.pastedNote, landedAt: model.pasteLanding,
                               caret: model.dictating ? model.accent.color : nil, steady: model.snapshotMode)
        case .code: CodePage()
        }
    }
}

/// A calm article, long enough to scroll.
struct ArticlePage: View {
    let hero: NSImage?

    static let opening = [
        "The first storm of the season moved through overnight, leaving the upper trails under a hand's depth of fresh snow. Rangers expect the pass to stay open through the weekend, though the forecast holds a second front for early next week.",
        "Below the tree line the change is quieter. Streams that ran clear all summer have turned milky with meltwater, and the last of the lodges have pulled their chairs inside for the year.",
    ]
    static let pass = [
        "At the pass the wind has already carved the new snow into low drifts that run across the trail at an angle. Walkers coming down in the afternoon described the crust as firm enough to hold a boot in the shade and soft wherever the sun had reached it.",
        "The hut wardens have moved the winter shutters up a week. Water is off at the upper hut, and the emergency room is stocked with blankets, a stove and a logbook that already has three entries from this week.",
        "Most of the traffic now comes from day walkers who turn at the lake. The ridge beyond it is still passable with spikes, but the markers are buried in two places and the path is easy to lose when cloud comes down.",
    ]
    static let lodges = [
        "In the valley the lodges are closing in the order they opened: the one by the bridge first, then the farm on the south slope, and last the old inn at the end of the road, which keeps a fire going until the first proper freeze.",
        "Owners say the season was long and uneven, busy in July and then quiet through a wet August. Most will reopen in December if the road crews keep up with the plough schedule.",
        "For now the high valleys belong to the weather again. The next clear morning is due on Thursday, and the photographers are already planning for it.",
    ]

    var body: some View {
        let T = WorkbenchTokens.Safari.self
        VStack(alignment: .leading, spacing: T.pageSpacing) {
            HStack(spacing: T.navSpacing) {
                ForEach(["Weather", "Trails", "Journal", "About"], id: \.self) { Text($0).agentAnchor("nav.\($0)") }
            }
            .font(T.nav)
            .foregroundStyle(.secondary)
            Color.clear
                .overlay {
                    if let hero { Image(nsImage: hero).resizable().scaledToFill() } else { WorkbenchTokens.Colors.desktopFallback }
                }
                .frame(height: T.heroHeight)
                .clipShape(RoundedRectangle(cornerRadius: T.heroRadius, style: .continuous))
                .agentAnchor("hero")
            Text("Snow returns to the high valleys").font(T.headline).agentAnchor("headline")
            Text("September 24, 2026 · 4 min read").font(T.byline).foregroundStyle(.secondary)
            paragraphs(Self.opening, anchor: "opening")
            Text("On the pass").font(T.sectionTitle).id("pass").agentAnchor("passTitle")
            paragraphs(Self.pass, anchor: "pass")
            Color.clear
                .overlay {
                    if let forest = PageImages.named("forest") { Image(nsImage: forest).resizable().scaledToFill() }
                }
                .frame(height: T.galleryHeight)
                .clipShape(RoundedRectangle(cornerRadius: T.heroRadius, style: .continuous))
            Text("The lodges close").font(T.sectionTitle).id("lodges")
            paragraphs(Self.lodges, anchor: "lodges")
        }
        .frame(maxWidth: T.columnWidth, alignment: .leading)
    }

    /// The article's passages by anchor ("opening0" …), for selecting text in capture mode.
    static var passages: [String: String] {
        var out: [String: String] = ["headline": "Snow returns to the high valleys"]
        for (name, texts) in [("opening", opening), ("pass", pass), ("lodges", lodges)] {
            for (i, text) in texts.enumerated() { out["\(name)\(i)"] = text }
        }
        return out
    }

    private func paragraphs(_ texts: [String], anchor: String) -> some View {
        ForEach(Array(texts.enumerated()), id: \.element) { i, text in
            Text(text).font(WorkbenchTokens.Safari.body).lineSpacing(WorkbenchTokens.Safari.bodyLineSpacing)
                .agentAnchor("\(anchor)\(i)")
        }
    }
}

/// Photographs in a two-column grid, with captions.
struct GalleryPage: View {
    private let photos = [("mountain", "Ama Dablam from the lodge"), ("forest", "Larch in the first frost"),
                          ("lion", "Portrait, late light"), ("building", "Station hall, morning"),
                          ("desk", "Contact sheets"), ("coast", "The fjord from the pulpit")]

    var body: some View {
        let T = WorkbenchTokens.Safari.self
        VStack(alignment: .leading, spacing: T.pageSpacing) {
            Text("Autumn portfolio").font(T.headline)
            Text("Six photographs from the last weeks of the season.").font(T.body).foregroundStyle(.secondary)
            Grid(horizontalSpacing: T.gallerySpacing, verticalSpacing: T.gallerySpacing) {
                ForEach(0..<3, id: \.self) { row in
                    GridRow {
                        ForEach(0..<2, id: \.self) { column in
                            let photo = photos[row * 2 + column]
                            VStack(alignment: .leading, spacing: 8) {
                                Color.clear
                                    .overlay {
                                        if let image = PageImages.named(photo.0) { Image(nsImage: image).resizable().scaledToFill() }
                                    }
                                    .frame(height: T.galleryHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: T.heroRadius, style: .continuous))
                                    .agentAnchor("photo\(row * 2 + column)")
                                Text(photo.1).font(T.caption).foregroundStyle(.secondary)
                            }
                            .id("photo\(row * 2 + column)")
                        }
                    }
                }
            }
        }
        .frame(maxWidth: T.columnWidth * 4 / 3, alignment: .leading)
    }
}

/// A design document: prose, a table of numbers, swatches and a small drawing of the notch.
struct NotesPage: View {
    /// What was pasted into the comment box, and when it landed (it lights up, feedback #7).
    let pasted: String?
    var landedAt: Date? = nil
    /// The words will go here: the caret, in the accent color (feedback #6).
    var caret: Color? = nil
    var steady = false
    private let springs = [("Voice bar opens", "0.18 s", "interpolating spring, no bounce"),
                           ("Voice bar closes", "0.15 s", "interpolating spring, no bounce"),
                           ("Waveform in", "0.10 s", "ease-out-quint, 20 ms behind"),
                           ("Stack opens", "0.24 s", "interpolating spring, cards 60 ms behind"),
                           ("Cards fan", "0.41 s", "cubic-bezier(0.31, 1.84, 0.64, 1), capped")]

    var body: some View {
        let T = WorkbenchTokens.Safari.self
        VStack(alignment: .leading, spacing: T.pageSpacing) {
            Text("Island motion").font(T.headline)
            Text("How the surface at the notch moves, and why. The shape leads and the content follows a beat behind; nothing bounces on the island itself, and nothing moves on a keyboard selection.")
                .font(T.body).lineSpacing(T.bodyLineSpacing)
            CommentBox(text: pasted, landedAt: landedAt, caret: caret, steady: steady)
                .agentAnchor("comment")
            Text("Springs").font(T.sectionTitle).id("springs").agentAnchor("springs")
            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 12) {
                ForEach(springs, id: \.0) { row in
                    GridRow {
                        Text(row.0).font(T.nav)
                        Text(row.1).font(T.code)
                        Text(row.2).font(T.caption).foregroundStyle(.secondary)
                    }
                    Divider().gridCellColumns(3)
                }
            }
            Text("Palette").font(T.sectionTitle).id("palette")
            HStack(spacing: T.gallerySpacing) {
                ForEach(T.swatches, id: \.name) { swatch in
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: T.heroRadius, style: .continuous)
                            .fill(swatch.color)
                            .overlay(RoundedRectangle(cornerRadius: T.heroRadius, style: .continuous).strokeBorder(T.swatchBorder))
                            .frame(width: T.swatchSize, height: T.swatchSize)
                        Text(swatch.name).font(T.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Text("The notch at rest").font(T.sectionTitle).id("rest")
            IslandShape(topRadius: 6, bottomRadius: 14)
                .fill(.black)
                .frame(width: 212, height: 32)
            Text("Six-point ears fuse the top corners into the menu bar; fourteen-point corners round the bottom. Every state that follows keeps them, so the island always meets the Mac the same way.")
                .font(T.body).lineSpacing(T.bodyLineSpacing)
            Text("Voice").font(T.sectionTitle).id("voice")
            Text("Listening keeps the notch's width and grows forty-four points down. Nine bars, four points wide and four apart; the edges rest as dots and the middle carries the voice. Captures stack at the left of the bar and the waveform moves right to make room.")
                .font(T.body).lineSpacing(T.bodyLineSpacing)
        }
        .frame(maxWidth: T.columnWidth, alignment: .leading)
    }
}

/// The notes' comment box: the one input box on the mock pages. A transcript finished while
/// this page is on screen is pasted here; anywhere else, there is nowhere to paste.
struct CommentBox: View {
    let text: String?
    var landedAt: Date? = nil
    var caret: Color? = nil
    var steady = false

    var body: some View {
        let T = WorkbenchTokens.Safari.self
        let shape = RoundedRectangle(cornerRadius: T.commentRadius, style: .continuous)
        LandingText(text: text, placeholder: "Add a comment…", landedAt: landedAt, caret: caret, steady: steady)
            .frame(maxWidth: .infinity, minHeight: T.commentMinHeight, alignment: .topLeading)
            .padding(T.commentPadding)
            .background(shape.fill(T.commentFill))
            .overlay(shape.strokeBorder(T.commentBorder))
            .id("comment")
            .accessibilityLabel("Comment")
            .accessibilityValue(text ?? "")
    }
}

/// Source code with line numbers.
struct CodePage: View {
    private static let lines = """
    import SwiftUI

    /// The island outline: concave "ears" at the top that fuse into the menu bar, straight
    /// sides, convex bottom corners. With `topRadius == 0` it is the Quick Answer slab —
    /// straight top and sides, rounded bottom only.
    struct IslandShape: Shape {
        var topRadius: CGFloat
        var bottomRadius: CGFloat

        var animatableData: AnimatablePair<CGFloat, CGFloat> {
            get { AnimatablePair(topRadius, bottomRadius) }
            set { topRadius = newValue.first; bottomRadius = newValue.second }
        }

        func path(in rect: CGRect) -> Path {
            let tr = max(0, min(topRadius, rect.width / 2))
            let br = max(0, min(bottomRadius, rect.height, rect.width / 2 - tr))
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            if tr > 0 {
                p.addQuadCurve(to: CGPoint(x: rect.minX + tr, y: rect.minY + tr),
                               control: CGPoint(x: rect.minX + tr, y: rect.minY))
            }
            p.addLine(to: CGPoint(x: rect.minX + tr, y: rect.maxY - br))
            p.addQuadCurve(to: CGPoint(x: rect.minX + tr + br, y: rect.maxY),
                           control: CGPoint(x: rect.minX + tr, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX - tr - br, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX - tr, y: rect.maxY - br),
                           control: CGPoint(x: rect.maxX - tr, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY + tr))
            if tr > 0 {
                p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                               control: CGPoint(x: rect.maxX - tr, y: rect.minY))
            }
            p.closeSubpath()
            return p
        }
    }

    /// How content enters and leaves the island: opacity with a light blur and a small scale
    /// from the top. One modifier for both directions, so exit is enter played backwards.
    struct IslandContentTransition: ViewModifier, Animatable {
        /// 0 = hidden, 1 = shown.
        var progress: CGFloat

        var animatableData: CGFloat {
            get { progress }
            set { progress = newValue }
        }

        func body(content: Content) -> some View {
            content
                .opacity(progress)
                .blur(radius: (1 - progress) * Tokens.Motion.contentBlur)
                .scaleEffect(Tokens.Motion.contentScale + (1 - Tokens.Motion.contentScale) * progress,
                             anchor: .top)
        }
    }

    extension AnyTransition {
        /// The island's content crossfade, on its own short ease-out.
        static var islandContent: AnyTransition {
            .modifier(active: IslandContentTransition(progress: 0),
                      identity: IslandContentTransition(progress: 1))
                .animation(Tokens.Motion.animation(.islandContent).delay(Tokens.Motion.contentDelay))
        }
    }
    """.components(separatedBy: "\n")

    var body: some View {
        let T = WorkbenchTokens.Safari.self
        VStack(alignment: .leading, spacing: T.pageSpacing) {
            HStack(spacing: 8) {
                Image(systemName: "swift")
                Text("Sources/Fovea/Island/IslandShape.swift").font(T.nav)
                Spacer()
                Text("\(Self.lines.count) lines").font(T.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(Self.lines.enumerated()), id: \.offset) { i, line in
                    HStack(alignment: .firstTextBaseline, spacing: 18) {
                        Text("\(i + 1)").foregroundStyle(.tertiary).frame(width: 28, alignment: .trailing)
                        Text(line.isEmpty ? " " : line)
                            .foregroundStyle(line.trimmingCharacters(in: .whitespaces).hasPrefix("//") ? T.codeComment : .primary)
                    }
                    .font(T.code)
                    .frame(height: T.codeLineHeight, alignment: .leading)
                    .id("l\(i + 1)")
                }
            }
            .agentAnchor("code")
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: T.heroRadius, style: .continuous).fill(T.codeFill))
        }
        .frame(maxWidth: T.columnWidth * 4 / 3, alignment: .leading)
    }
}

/// Safari's address field: the tab's host, or what the agent is typing into it, with the caret
/// and the focus ring a focused field has.
struct AddressField: View {
    let host: String
    let typed: String?

    var body: some View {
        let T = WorkbenchTokens.Safari.self
        let shape = RoundedRectangle(cornerRadius: T.addressRadius, style: .continuous)
        HStack(spacing: T.addressSpacing) {
            if let typed {
                Image(systemName: "magnifyingglass").font(T.addressGlyph).foregroundStyle(.secondary)
                Text(typed.isEmpty ? " " : typed)
                Rectangle().fill(Color.accentColor).frame(width: 1.5, height: 15)
                Spacer(minLength: 0)
            } else {
                Image(systemName: "lock.fill").font(T.addressGlyph)
                Text(host)
            }
        }
        .font(T.address)
        .foregroundStyle(.primary)
        .padding(.horizontal, typed == nil ? 0 : 10)
        .frame(width: T.addressWidth, height: T.addressHeight)
        .background(shape.fill(typed == nil ? WorkbenchTokens.Colors.safariField : T.addressFocusedFill))
        .overlay(shape.strokeBorder(Color.accentColor.opacity(typed == nil ? 0 : 0.6), lineWidth: 3))
    }
}

/// Where a named part of a page is on the display: the agent's script reads it to point at
/// headlines, paragraphs, photos, the comment box and the address field.
struct AgentAnchorReporter {
    let report: (String, CGRect) -> Void
    init(_ report: @escaping (String, CGRect) -> Void) { self.report = report }
}

private struct AgentAnchorReporterKey: EnvironmentKey {
    static let defaultValue = AgentAnchorReporter { _, _ in }
}

extension EnvironmentValues {
    var agentAnchorReporter: AgentAnchorReporter {
        get { self[AgentAnchorReporterKey.self] }
        set { self[AgentAnchorReporterKey.self] = newValue }
    }
}

struct AgentAnchor: ViewModifier {
    let name: String
    @Environment(\.agentAnchorReporter) private var reporter

    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGRect.self) { $0.frame(in: .named(ScreenSpace.name)) } action: { reporter.report(name, $0) }
    }
}

extension View {
    func agentAnchor(_ name: String) -> some View { modifier(AgentAnchor(name: name)) }
}

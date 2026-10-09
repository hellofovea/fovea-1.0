import AppKit
import SwiftUI
import CapturesCore

/// Aside's layout, Fovea's way. The window is the system's own translucent material, the desktop
/// showing through it: at the left it holds search (in the traffic lights' row, as Aside's does),
/// the apps your words went to as chips, the list of everything you said and took, by day, and a
/// month calendar at its foot. At the right an opaque page is inset in it, its corners concentric
/// with the window's, and shows this week's cards, a capture opened as a note, one day, or
/// Settings. From the page's top edge hangs a black island, as the notch hangs from the screen's:
/// the type filter, and, in Settings, the panes.
struct LibraryWindow: View {
    @Environment(CapturesModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            // In Settings with the Mac's sidebar, the window's sidebar becomes Settings' own (as
            // System Settings' is), under the traffic lights' row.
            if model.page == .settings && model.settingsLayout.hasSidebar {
                SettingsSidebar()
                    .padding(.top, T.Library.titlebar)
                    .frame(width: T.Library.sidebarWidth)
                    .transition(.opacity)
            } else {
                LibrarySidebar()
                    .frame(width: T.Library.sidebarWidth)
                    .transition(.opacity)
            }
            LibraryPage()
                .padding(.vertical, T.Library.pageInset)
                .padding(.trailing, T.Library.pageInset)
        }
        .background(WindowMaterial(style: model.windowMaterial).ignoresSafeArea())
        .ignoresSafeArea()
    }
}

/// Where a day starts in the list, for scrolling to it.
enum LibraryIDs {
    static let top = "list-top"
    static func day(_ date: Date) -> String {
        "day-\(Int(Lines.calendar.startOfDay(for: date).timeIntervalSince1970))"
    }
}

// MARK: - The sidebar

struct LibrarySidebar: View {
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            // The traffic lights' row: search beside them.
            HStack(spacing: 0) {
                Color.clear.frame(width: T.Library.trafficLights)
                SidebarSearch()
            }
            .padding(.trailing, 12)
            .frame(height: T.Library.titlebar)
            AppChips()
                .padding(.horizontal, 12)
                .padding(.top, 2)
                .padding(.bottom, 8)
            Rectangle().fill(palette.hairline).frame(height: 0.5).padding(.horizontal, 14)
            CaptureList()
            MiniCalendar()
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 14)
                .overlay(alignment: .top) {
                    Rectangle().fill(palette.hairline).frame(height: 0.5).padding(.horizontal, 14)
                }
        }
    }
}

/// Search, as a sidebar's field: a capsule with the magnifier, ⌘F to reach it, Esc to clear it;
/// the date filter and the rest of the apps in a menu at its end.
struct SidebarSearch: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.secondary)
            TextField("Search", text: $model.query.text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($focused)
                .onExitCommand {
                    model.query.text = ""
                    focused = false
                }
            if !model.query.text.isEmpty {
                Button { model.query.text = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 12)).foregroundStyle(palette.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
            FilterMenuButton()
        }
        .padding(.leading, 10)
        .padding(.trailing, 3)
        .frame(height: 28)
        .background(Capsule().fill(palette.fill))
        .overlay {
            if focused {
                Capsule().strokeBorder(palette.accent.opacity(0.55), lineWidth: 3).padding(-2.5)
            }
        }
        // ⌘F reaches it; a negative request (the harness) lets it go, cleared.
        .onChange(of: model.searchRequest) { _, n in
            if n < 0 { model.query.text = ""; focused = false } else { focused = true }
        }
    }
}

/// The apps your words went to most, as chips under search (Aside's tags): each with its own
/// icon; one picks it, again lets it go. The rest are in the search field's menu.
struct AppChips: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let captures = model.library.captures
        let apps = Array(CaptureSearch.apps(in: captures).prefix(3))
        HStack(spacing: 6) {
            ForEach(apps, id: \.self) { app in
                let on = model.query.app == app
                Button {
                    model.animate(.swap) { model.query.app = on ? nil : app }
                } label: {
                    HStack(spacing: 5) {
                        Image(nsImage: Art.menuIcon(app, in: captures))
                        Text(app).font(.system(size: 11.5, weight: on ? .semibold : .medium)).lineLimit(1)
                    }
                    .foregroundStyle(on ? palette.text : palette.secondary)
                    .padding(.leading, 5)
                    .padding(.trailing, 8)
                    .frame(height: 22)
                    .background(Capsule().fill(on ? palette.fillStrong : palette.fill))
                    .overlay(Capsule().strokeBorder(on ? palette.text.opacity(0.35) : .clear, lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(on ? "Show every app" : "Show only what went to \(app)")
            }
            Spacer(minLength: 0)
        }
    }
}

/// The app it went into (or the agent a dispatch went to) and when, from a menu at the search
/// field's end: each app with its own icon. Filled while a filter is on.
struct FilterMenuButton: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let captures = model.library.captures
        let on = model.query.app != nil || model.query.date != nil || model.query.tag != nil
        Menu {
            Picker("App", selection: Binding(get: { model.query.app }, set: { v in model.animate(.swap) { model.query.app = v } })) {
                Label("All Apps", systemImage: "square.grid.2x2").labelStyle(.titleAndIcon).tag(String?.none)
                Divider()
                ForEach(CaptureSearch.apps(in: captures), id: \.self) { name in
                    Label { Text(name) } icon: { Image(nsImage: Art.menuIcon(name, in: captures)) }
                        .labelStyle(.titleAndIcon)
                        .tag(String?.some(name))
                }
            }
            .pickerStyle(.inline)
            Divider()
            Picker("Date", selection: Binding(get: { model.query.date }, set: { v in model.animate(.swap) { model.query.date = v } })) {
                Text("Any Time").tag(CaptureQuery.DateFilter?.none)
                ForEach(CaptureQuery.DateFilter.allCases, id: \.self) { d in
                    Text(d.title).tag(CaptureQuery.DateFilter?.some(d))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: on ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(on ? palette.accent : palette.secondary)
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(on ? "Filtered: choose an app or a time" : "Filter by app or time")
    }
}

/// Everything you said and took, newest first, by day: what a meeting list is in Aside. One
/// highlight glides from row to row under the pointer instead of each row fading its own (Aside's
/// list hover). ↑ ↓ move through it and the page follows, at once; Esc closes what's open.
struct CaptureList: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @FocusState private var focused: Bool
    @State private var hovered: String?
    @Namespace private var plate

    var body: some View {
        let groups = CaptureGrid.days(model.listed, now: model.now)
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    Color.clear.frame(height: 0).id(LibraryIDs.top)
                    if groups.isEmpty {
                        Text(model.library.captures.isEmpty ? "Nothing yet" : "No results")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                    ForEach(groups, id: \.title) { day in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(day.title)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(palette.secondary)
                            Text("\(day.matches.count)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(palette.tertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 14)
                        .padding(.bottom, 4)
                        .id(LibraryIDs.day(day.matches[0].capture.time))
                        .accessibilityAddTraits(.isHeader)
                        ForEach(day.matches, id: \.capture.id) { m in
                            SidebarRow(match: m, hovered: $hovered, plate: plate).id(m.capture.id)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            }
            .scrollIndicators(.automatic)
            .onChange(of: model.listScrollTarget) { _, id in
                guard let id else { return }
                reader.scrollTo(id, anchor: id.hasPrefix("day-") || id == LibraryIDs.top ? .top : nil)
                model.listScrollTarget = nil
            }
            .onChange(of: model.query) { _, _ in reader.scrollTo(LibraryIDs.top, anchor: .top) }
            .focusable()
            .focused($focused)
            .focusEffectDisabled()
            .onKeyPress(.upArrow) { model.moveNote(-1); return .handled }
            .onKeyPress(.downArrow) { model.moveNote(1); return .handled }
            .onKeyPress(.escape) {
                guard model.noteID != nil else { return .ignored }
                model.closeNote()
                return .handled
            }
            // The list holds the keyboard from the start (not search), so ↑ ↓ work at once.
            .onAppear { focused = true }
        }
    }
}

/// One capture in the list: its type and when, where it went, and the start of its words with
/// each thing you took in place.
struct SidebarRow: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let match: CaptureMatch
    @Binding var hovered: String?
    let plate: Namespace.ID

    var body: some View {
        let c = match.capture
        let selected = model.noteID == c.id
        let when = History.isRecent(c.time, now: model.now, calendar: Lines.calendar)
            ? Lines.compact(c.time, now: model.now) : Lines.time(c.time)
        let shape = RoundedRectangle(cornerRadius: T.Library.rowRadius, style: .continuous)
        Button { model.openNote(c.id) } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    KindMark(kind: c.kind, size: 8)
                    Text(c.kind.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.text)
                    Text(when)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(palette.tertiary)
                    Spacer(minLength: 4)
                    Image(nsImage: Art.cardIcon(c))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 16, height: 16)
                        .help(CardHeader.whereItWent(c))
                }
                InlineText.make(c, hits: match.ranges[.text] ?? [], size: 12, palette: palette, hitStyle: model.hitStyle,
                                color: palette.secondary)
                    .font(.system(size: 12))
                    .lineSpacing(1.5)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                if selected {
                    shape.fill(palette.fillStrong)
                } else if hovered == c.id {
                    // One plate, gliding to the row under the pointer.
                    shape.fill(palette.fill).matchedGeometryEffect(id: "hover", in: plate)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { inside in
            withAnimation(.interpolatingSpring(duration: model.motion.seconds(0.2), bounce: 0)) {
                if inside { hovered = c.id } else if hovered == c.id { hovered = nil }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel("\(c.kind.title), \(when). \(Lines.spoken(c))")
    }
}

/// A month at the foot of the list, as Calendar keeps one at the foot of its sidebar: each day
/// shaded by how much you said that day, today ringed in the accent, the day open ringed in ink.
/// ‹ › walk the months back (never past this one); a day opens its archive in the page.
struct MiniCalendar: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let cal = Lines.calendar
        let month = History.month(model.calendarMonth, calendar: cal)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                Text(Self.title(month.first, now: model.now))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.text)
                Spacer()
                stepButton("chevron.left", help: "Previous month") { model.stepMonth(-1) }
                stepButton("chevron.right", help: "Next month") { model.stepMonth(1) }
                    .disabled(!model.canStepMonthForward)
            }
            HStack(spacing: 2) {
                ForEach(0..<7, id: \.self) { i in
                    Text(cal.veryShortWeekdaySymbols[(cal.firstWeekday - 1 + i) % 7])
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(palette.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            VStack(spacing: 2) {
                ForEach(Array(month.rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { i in
                            if let day = row[i] { DayCellMini(day: day) } else { Color.clear.frame(maxWidth: .infinity).frame(height: 24) }
                        }
                    }
                }
            }
            .id(month.first)
            .transition(.blockSwap)
        }
    }

    private func stepButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    static func title(_ first: Date, now: Date) -> String {
        let cal = Lines.calendar
        let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone; f.locale = cal.locale
        f.dateFormat = "MMMM yyyy"
        return f.string(from: first)
    }
}

private struct DayCellMini: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let day: Date
    @State private var hover = false

    var body: some View {
        let cal = Lines.calendar
        let today = cal.startOfDay(for: model.now)
        let future = day > today
        let n = model.dayCounts[day] ?? 0
        let level = model.levels.level(n)
        let isToday = day == today
        let open = model.archiveDay == day && model.page == .day && model.noteID == nil
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        let line = n == 0 ? "Nothing on \(Lines.longDay(day, now: model.now))" : "\(n) on \(Lines.longDay(day, now: model.now))"
        Text("\(cal.component(.day, from: day))")
            .font(.system(size: 11, weight: isToday || open ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(future ? palette.tertiary.opacity(0.6) : (level >= 3 ? palette.onHeat : palette.text.opacity(0.8)))
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .background(shape.fill(future ? Color.clear : palette.heat[level]))
            .overlay {
                if open {
                    shape.strokeBorder(palette.text, lineWidth: 1.75).padding(-1.5)
                } else if isToday {
                    shape.strokeBorder(palette.accent, lineWidth: 1.25)
                } else if hover && !future {
                    shape.strokeBorder(palette.text.opacity(0.45), lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
            .onHover { hover = $0 }
            .onTapGesture { if !future { model.openDay(day) } }
            .help(future ? "" : line)
            .accessibilityLabel(line)
            .accessibilityAddTraits(open ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - The page

/// The opaque page inset in the window's material: its header (back, the island, you), then what
/// it shows.
struct LibraryPage: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: T.Library.pageRadius, style: .continuous)
        VStack(spacing: 0) {
            PageHeader()
            ZStack(alignment: .top) {
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // A settings page is white to its top, as the Mac's are.
        .background(model.page == .settings && model.settingsLayout.hasSidebar ? palette.nativePage : palette.page)
        .clipShape(shape)
        .overlay(shape.strokeBorder(palette.hairline, lineWidth: 0.5))
        .shadow(color: .black.opacity(palette.isDark ? 0.45 : 0.07), radius: 1.5, y: 0.5)
        .overlay(alignment: .bottom) { Toast() }
    }

    @ViewBuilder private var content: some View {
        if model.page == .settings {
            SettingsPage()
                .transition(.page(forward: model.pageForward))
        } else if let note = model.note {
            CaptureNote(capture: note)
                .id(note.id)
                .transition(.blockSwap)
        } else if model.page == .day {
            CapturesPage(day: true)
                .transition(.page(forward: model.pageForward))
        } else {
            CapturesPage()
                .transition(.page(forward: model.pageForward))
        }
    }
}

/// Back at the left (from a note, a day or Settings), the island hanging at the center, you at
/// the right.
struct PageHeader: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let showsBack = model.noteID != nil || model.page != .captures
        ZStack(alignment: .top) {
            HStack(spacing: 8) {
                if showsBack {
                    RoundGlassButton(symbol: "chevron.left", help: "Back (⌘[)") { model.back() }
                        .transition(.opacity)
                }
                Spacer()
                Avatar()
                    .padding(2)
                    .glass(Circle(), interactive: true)
            }
            .padding(.horizontal, 12)
            .frame(height: T.Library.header)
            PageIsland()
        }
        .frame(height: T.Library.header)
    }
}

/// The black island hanging from the page's top edge, as the notch hangs from the screen's, in
/// the Island's own language: white at opacities on black. It holds the type filter, and in
/// Settings becomes the panes, its width springing from one to the other.
struct PageIsland: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.liquidGlass) private var liquid
    @Namespace private var ns

    var body: some View {
        let settings = model.page == .settings
        Group {
            if settings && model.settingsLayout.hasSidebar {
                // The sidebar picks the section; the island says which one you're in.
                Text(model.settingsCategory.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(glassIsland ? palette.text : Color.white)
                    .padding(.horizontal, T.Library.islandEars + 18)
                    .padding(.bottom, 2)
                    .frame(height: T.Library.islandHeight)
                    .background { island }
                    .contentTransition(.opacity)
            } else if model.pageIsland == .segmented {
                segmented(settings: settings)
                    .frame(height: T.Library.header)
            } else {
                HStack(spacing: 2) {
                    if settings {
                        ForEach(SettingsPane.allCases, id: \.self) { pane in
                            segment(pane.title, kind: nil, on: model.settingsPane == pane) {
                                model.animate(.swap) { model.settingsPane = pane }
                            }
                        }
                    } else {
                        segment("All", kind: nil, on: model.query.kind == nil) { model.setKind(nil) }
                        ForEach(CaptureKind.allCases, id: \.self) { kind in
                            segment(kind.title, kind: kind, on: model.query.kind == kind) { model.setKind(kind) }
                        }
                    }
                }
                .padding(.horizontal, T.Library.islandEars + 6)
                .padding(.bottom, 2)
                .frame(height: T.Library.islandHeight)
                .background { island }
                .animation(model.motion.animation(.open), value: settings)
            }
        }
    }

    /// Liquid Glass for the island: only where the system has it, and only when asked for.
    private var glassIsland: Bool {
        guard model.pageIsland == .glass, liquid else { return false }
        if #available(macOS 26.0, *) { return true }
        return false
    }

    @ViewBuilder private var island: some View {
        let shape = IslandShape(topRadius: T.Library.islandEars, bottomRadius: T.Library.islandFoot)
        if glassIsland, #available(macOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: shape)
        } else {
            // On a dark page the black needs an edge to stand off it: a hairline of white.
            shape.fill(Color.black)
                .overlay(shape.stroke(Color.white.opacity(palette.isDark ? 0.14 : 0), lineWidth: 0.5))
        }
    }

    private func segment(_ title: String, kind: CaptureKind?, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let kind { KindMark(kind: kind, size: 8) }
                Text(title).font(.system(size: 12, weight: on ? .semibold : .medium))
            }
            // On black, white at opacities (the Island's language); on glass, the label's ink.
            .foregroundStyle(glassIsland ? (on ? palette.text : palette.secondary) : Color.white.opacity(on ? 1 : 0.6))
            .padding(.horizontal, 11)
            .frame(height: 24)
            .background {
                if on {
                    Capsule().fill(glassIsland ? palette.fillStrong : Color.white.opacity(0.18))
                        .matchedGeometryEffect(id: "on", in: ns)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    @ViewBuilder private func segmented(settings: Bool) -> some View {
        if settings {
            Picker("Pane", selection: Binding(get: { model.settingsPane }, set: { p in model.animate(.swap) { model.settingsPane = p } })) {
                ForEach(SettingsPane.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        } else {
            Picker("Show", selection: Binding(get: { model.query.kind }, set: { model.setKind($0) })) {
                Text("All").tag(CaptureKind?.none)
                ForEach(CaptureKind.allCases, id: \.self) { Text($0.title).tag(CaptureKind?.some($0)) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }
}

// MARK: - A capture, as a note

/// A capture opened in the page: your words (a dictation's transcription), with each thing you
/// took in place, and what you took, large. No type, no destination, no time: the list beside
/// it says those. Its blocks arrive one after another, 55 ms apart; its actions float in one
/// glass capsule at its foot.
struct CaptureNote: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let capture: Capture
    @State private var shown = false

    var body: some View {
        let match = model.match(for: capture)
        let metrics = DetailMetrics(capture)
        GeometryReader { geo in
            let width = min(geo.size.width - 32, T.Library.noteWidth)
            let inner = width - 2 * metrics.padding
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Group {
                        if capture.failed {
                            FailedNotice(capture: capture)
                        } else {
                            InlineText.make(capture, hits: match.ranges[.text] ?? [], size: T.Text.detailBody, palette: palette,
                                            hitStyle: model.hitStyle, thumbnails: true)
                                .font(.system(size: T.Text.detailBody))
                                .lineSpacing(5)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: min(inner, T.Layout.detailMeasure), alignment: .leading)
                    .modifier(Stagger(index: 1, shown: shown))
                    if !capture.attachments.isEmpty {
                        DetailAttachments(capture: capture, width: inner, lendTiles: false)
                            .modifier(Stagger(index: 2, shown: shown))
                    }
                    CaptureFooter(capture: capture)
                        .frame(width: inner)
                        .modifier(Stagger(index: 3, shown: shown))
                }
                .padding(.horizontal, metrics.padding)
                .padding(.top, 8)
                .padding(.bottom, 80)
                .frame(width: width, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            NoteActions(capture: capture)
                .padding(16)
        }
        .onAppear {
            if model.motion.reduce { shown = true; return }
            withAnimation(model.motion.animation(.open)) { shown = true }
        }
    }
}

/// A note's block arriving: opacity and a few points of rise, each block 55 ms after the one
/// before (Aside's note blocks); Reduce Motion keeps the fade only.
struct Stagger: ViewModifier {
    @Environment(\.motion) private var motion
    let index: Int
    let shown: Bool
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || motion.reduce ? 0 : 6)
            .animation(motion.animation(.open).delay(motion.seconds(0.055 * Double(index))), value: shown)
    }
}

/// The note's actions in one glass capsule (Aside's copy · share · delete): up and down the list,
/// copy, save, delete.
struct NoteActions: View {
    @Environment(CapturesModel.self) private var model
    let capture: Capture

    var body: some View {
        GlassBar {
            IconButton(symbol: "chevron.up", help: "Previous (↑)") { model.moveNote(-1) }
            IconButton(symbol: "chevron.down", help: "Next (↓)") { model.moveNote(1) }
            BarDivider()
            IconButton(symbol: model.copiedID == capture.id ? "checkmark" : "doc.on.doc", help: "Copy",
                       confirmed: model.copiedID == capture.id) { model.copy(capture) }
                .disabled(capture.failed)
            SaveMenu(capture: capture)
            IconButton(symbol: "trash", help: "Delete (⌘⌫)", role: .destructive) { model.delete(capture.id) }
                .keyboardShortcut(.delete, modifiers: .command)
        }
    }
}

import SwiftUI
import AppKit
import WindowBenchCore

// MARK: - 7a · Memory

/// Terms and Memories, each with where it came from (your words, dated, in mono), its scope, and
/// a plain Forget. A field at the bottom takes a correction; the notch takes one too.
struct MemorySettings: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var draft = ""

    var body: some View {
        Form {
            Section {
                ForEach(model.library.memory.filter { $0.kind == .term }) { item in MemoryRow(item: item) }
            } header: {
                Text("Terms")
            } footer: {
                Note("Words you use for things. Fovea routes and briefs with them.")
            }
            Section("Memories") {
                ForEach(model.library.memory.filter { $0.kind == .memory }) { item in MemoryRow(item: item) }
            }
            Section {
                HStack(spacing: 8) {
                    // A placeholder inside the field: a Form would set a TextField's title as a label.
                    TextField("Correction", text: $draft, prompt: Text("“主仓” means api-server, not the app repo"))
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                    Button("Add") {
                        model.addMemory(draft)
                        draft = ""
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Correct or add")
            } footer: {
                HStack(spacing: 4) {
                    Text("Or \(model.v(GestureCopy.self).lead.lowercased())")
                    KeyCap("fn")
                    Text(model.v(GestureCopy.self).short)
                }
                .font(.system(size: 11))
                .foregroundStyle(palette.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .animation(model.motion.animation(.swap), value: model.library.memory.map(\.id))
    }
}

private struct MemoryRow: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    let item: MemoryItem

    var body: some View {
        // Forgotten, the row keeps its place and height and offers Undo where Forget was, so a
        // second click never lands on the next row's Forget.
        let forgotten = model.lastForgotten?.item.id == item.id
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(forgotten ? "Forgot \(item.content)" : item.content)
                    .foregroundStyle(forgotten ? palette.tertiary : palette.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text("\(Lines.day(item.sourceDate)) you said “\(item.sourceQuote)”")
                    .font(BenchTokens.Type_.mono(11))
                    .foregroundStyle(forgotten ? palette.tertiary : palette.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
            Text(item.scope ?? "Global")
                .font(.system(size: 11.5))
                .foregroundStyle(forgotten ? palette.tertiary : palette.secondary)
                .padding(.trailing, 6)
            Group {
                if forgotten {
                    Button("Undo") { model.undoForget() }
                } else {
                    Button("Forget") { model.forget(item.id) }
                        .help("Fovea stops using this; nothing else changes")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(minWidth: 58, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

extension BenchModel {
    /// Forget: the row says so in place, with Undo, until the next change; then it's gone.
    /// The row changes in place at once, as a control's label does: a Form row animated through a
    /// swap stalled half-drawn over itself.
    func forget(_ id: String) {
        guard let i = library.memory.firstIndex(where: { $0.id == id }) else { return }
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            settleForgotten()
            if let j = library.memory.firstIndex(where: { $0.id == id }) { lastForgotten = (library.memory[j], j) }
        }
        _ = i
        status = "Forgotten"
    }

    func undoForget() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { lastForgotten = nil }
    }

    /// The last forgotten item leaves for good (another change came after it).
    func settleForgotten() {
        guard let forgotten = lastForgotten else { return }
        library.memory.removeAll { $0.id == forgotten.item.id }
        lastForgotten = nil
    }

    func addMemory(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        settleForgotten()
        let isTerm = trimmed.contains("“") || trimmed.contains("\"") || trimmed.contains("=")
        animate(.expand) {
            library.memory.append(MemoryItem(id: "m-\(UUID().uuidString.prefix(6))", kind: isTerm ? .term : .memory,
                                             content: trimmed, sourceDate: index.now, sourceQuote: trimmed))
        }
    }
}

// MARK: - 7b · Notch

/// What the notch's Today view shows, with the view itself, live, at the top (System Settings'
/// previews). Rows on the timeline, the time range, what to include, meeting alerts, presets.
/// No free-form layout and no widgets (v3.3 §7).
struct NotchSettings: View {
    @Environment(BenchModel.self) private var model
    @Environment(\.palette) private var palette
    /// The island with all five lanes: the preview row's one height.
    static let lanesHeight: CGFloat = 188

    var body: some View {
        @Bindable var model = model
        ScrollViewReader { proxy in
        Form {
            Section {
                // The island grows and shrinks with its lanes inside a row of one height, so the
                // Form under it never re-lays out mid-change (its rows jumped when it did).
                TodayPreview()
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: model.v(TodayTimelineStyle.self) == .lanes ? Self.lanesHeight : nil, alignment: .top)
                    .padding(.vertical, 6)
            }
            .id("preview")
            Section {
                // One Form row holding the five as a stack with its own separators: a grouped
                // Form animates its rows' moves itself, sliding them (and their separators)
                // through each other. Here a new order is in place at once; the preview above
                // carries the change.
                VStack(spacing: 0) {
                    ForEach(Array(model.today.rows.enumerated()), id: \.element) { i, row in
                        if i > 0 { Divider() }
                        HStack(spacing: 10) {
                            Toggle(isOn: Binding(get: { model.today.shown.contains(row) },
                                                 set: { on in model.animate(.swap) {
                                                     if on { model.today.shown.insert(row) } else { model.today.shown.remove(row) } } })) {
                                Text(row.title)
                            }
                            .toggleStyle(.checkbox)
                            Spacer()
                            Button { model.moveTodayRow(i, by: -1) } label: { Image(systemName: "chevron.up") }
                                .buttonStyle(.borderless).disabled(i == 0)
                                .help("Move up")
                            Button { model.moveTodayRow(i, by: 1) } label: { Image(systemName: "chevron.down") }
                                .buttonStyle(.borderless).disabled(i == model.today.rows.count - 1)
                                .help("Move down")
                        }
                        .frame(minHeight: 30)
                        .contentShape(Rectangle())
                        .onDrag { NSItemProvider(object: row.rawValue as NSString) }
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            providers.first?.loadObject(ofClass: NSString.self) { object, _ in
                                guard let raw = object as? String, let moved = TodayRow(rawValue: raw) else { return }
                                Task { @MainActor in model.moveTodayRow(moved, to: row) }
                            }
                            return true
                        }
                    }
                }
                .transaction { $0.animation = nil }
            } header: {
                Text("On the timeline")
            } footer: {
                Note("Drag a row, or use the arrows, to change the order.")
            }
            Section("Range") {
                Picker("From", selection: $model.today.start) {
                    ForEach([6, 7, 8, 9, 10], id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                }
                Picker("To", selection: $model.today.end) {
                    ForEach([17, 18, 19, 20, 21, 22], id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                }
            }
            .id("range")
            // Which calendars and which projects the timeline shows (the brief's 7b).
            Section {
                Toggle("Work calendar", isOn: $model.today.workCalendar)
                Toggle("Personal calendar", isOn: $model.today.personalCalendar)
                ForEach(model.todayProjects, id: \.id) { project in
                    Toggle(isOn: Binding(get: { !model.today.hiddenProjects.contains(project.id) },
                                         set: { on in model.animate(.swap) {
                                             if on { model.today.hiddenProjects.remove(project.id) } else { model.today.hiddenProjects.insert(project.id) } } })) {
                        Text(project.name)
                    }
                    .toggleStyle(.checkbox)
                }
            } header: {
                Text("Include")
            } footer: {
                Note("Calendars from Calendar; projects with a run today.")
            }
            .id("include")
            Section("Meeting alerts") {
                Toggle("Count down on the left ear", isOn: $model.today.earCountdown)
                Toggle("Drop down a minute before", isOn: $model.today.dropDown)
                Toggle("Play a sound", isOn: $model.settings.soundMeeting)
            }
            .id("alerts")
            Section("Presets") {
                HStack(spacing: 8) {
                    ForEach(TodayPreset.allCases, id: \.self) { preset in
                        // The rows take their order at once; the preview animates on its own.
                        Button(preset.title) { model.withoutAnimation { model.today.apply(preset) } }
                    }
                }
            }
            .id("presets")
        }
        .onChange(of: model.settingsScrollTarget, initial: true) { _, target in
            if let target { proxy.scrollTo(target, anchor: .top) } else { proxy.scrollTo("preview", anchor: .bottom) }
        }
        }
    }
}

enum TodayRow: String, Codable, CaseIterable, Hashable {
    case schedule, agents, notes, dispatches, focus

    var title: String {
        switch self {
        case .schedule: return "Your schedule"
        case .agents: return "Agents"
        case .notes: return "Notes"
        case .dispatches: return "Scheduled dispatches"
        case .focus: return "Focus blocks"
        }
    }

    /// The label on the island's own timeline, where a lane's name has ~70 pt.
    var laneTitle: String {
        switch self {
        case .schedule: return "Schedule"
        case .agents: return "Agents"
        case .notes: return "Notes"
        case .dispatches: return "Dispatches"
        case .focus: return "Focus"
        }
    }
}

enum TodayPreset: String, CaseIterable {
    case meetings, agents, quiet

    var title: String {
        switch self {
        case .meetings: return "Meeting day"
        case .agents: return "Agent day"
        case .quiet: return "Quiet"
        }
    }
}

struct TodaySettings: Equatable {
    var rows: [TodayRow] = TodayRow.allCases
    var shown: Set<TodayRow> = [.schedule, .agents, .dispatches, .focus]
    var start = 8
    var end = 20
    var workCalendar = true
    var personalCalendar = false
    var activeProjectsOnly = true
    /// Projects left off the timeline (Include).
    var hiddenProjects: Set<String> = []
    var earCountdown = true
    var dropDown = true

    mutating func apply(_ preset: TodayPreset) {
        switch preset {
        case .meetings: rows = [.schedule, .focus, .agents, .dispatches, .notes]; shown = [.schedule, .focus, .agents]
        case .agents: rows = [.agents, .dispatches, .schedule, .notes, .focus]; shown = [.agents, .dispatches, .schedule]
        case .quiet: rows = [.schedule, .agents, .notes, .dispatches, .focus]; shown = [.schedule]
        }
    }
}

extension BenchModel {
    func moveTodayRow(_ i: Int, by delta: Int) {
        let j = i + delta
        guard today.rows.indices.contains(i), today.rows.indices.contains(j) else { return }
        withoutAnimation { today.rows.swapAt(i, j) }
    }

    func moveTodayRow(_ moved: TodayRow, to target: TodayRow) {
        guard moved != target, let from = today.rows.firstIndex(of: moved), let to = today.rows.firstIndex(of: target) else { return }
        withoutAnimation {
            today.rows.remove(at: from)
            today.rows.insert(moved, at: to)
        }
    }
}

/// The notch's Today view, live: black, the notch's widths and corners, white at its opacities.
/// Lanes (time across) or Agenda (time down), per the Today switch.
struct TodayPreview: View {
    @Environment(BenchModel.self) private var model

    var body: some View {
        let style = model.v(TodayTimelineStyle.self)
        VStack(spacing: 0) {
            // The notch's own cut-out over the preview, so it reads as the island.
            Capsule().fill(Color.black).frame(width: 180, height: 6).opacity(0)
            Group {
                if style == .lanes { TodayLanes() } else { TodayAgenda() }
            }
            // Inside the island's body: past the flared top corners, then the notch's own padding.
            .padding(.horizontal, BenchTokens.Notch.topRadius + BenchTokens.Notch.paddingH)
            .padding(.top, 34)
            .padding(.bottom, 14)
            .frame(width: BenchTokens.Notch.slabWidth)
            .background(IslandShape(topRadius: BenchTokens.Notch.topRadius, bottomRadius: BenchTokens.Notch.bottomRadius)
                .fill(BenchTokens.Notch.surface))
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.black)
                    .frame(width: 186, height: 28)
                    .overlay(Text("now 14:30").font(BenchTokens.Type_.mono(10)).foregroundStyle(BenchTokens.Notch.tertiary).offset(x: 140))
            }
            .environment(\.colorScheme, .dark)
            .animation(model.motion.animation(.swap), value: model.previewToday)
        }
    }
}

private struct TimelineItem: Identifiable {
    var id: String { "\(row.rawValue)/\(title)" }
    let row: TodayRow
    let title: String
    let start: Double
    let end: Double
    let state: RunState?
}

private extension BenchModel {
    /// The projects the timeline can show: those with a run today.
    var todayProjects: [Project] {
        library.projects.filter { project in
            index.runs(inProject: project.id).contains { Lines.calendar.isDate($0.started, inSameDayAs: index.now) }
        }
    }

    var todayItems: [TimelineItem] {
        var items: [TimelineItem] = []
        if previewToday.shown.contains(.schedule) {
            if previewToday.workCalendar {
                items.append(TimelineItem(row: .schedule, title: "Standup", start: 10, end: 10.25, state: nil))
                items.append(TimelineItem(row: .schedule, title: "Design review with Lin", start: 15, end: 15.75, state: nil))
            }
            if previewToday.personalCalendar { items.append(TimelineItem(row: .schedule, title: "Gym", start: 18.5, end: 19.5, state: nil)) }
        }
        if previewToday.shown.contains(.agents) {
            // Today's runs from the library, the latest in each thread: the same times and
            // states the project pages show.
            let hour = { (d: Date) -> Double in
                let c = Lines.calendar.dateComponents([.hour, .minute], from: d)
                return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
            }
            let today = index.library.runs.filter { Lines.calendar.isDate($0.started, inSameDayAs: index.now) && $0.state != .seen }
            let latest = Dictionary(grouping: today, by: \.threadID).compactMap { $0.value.max { $0.started < $1.started } }
            for run in latest.sorted(by: { $0.started < $1.started }) {
                guard let thread = index.thread(of: run), !previewToday.hiddenProjects.contains(thread.projectID) else { continue }
                items.append(TimelineItem(row: .agents, title: thread.name, start: hour(run.started),
                                          end: hour(run.finished ?? index.now), state: run.state))
            }
        }
        if previewToday.shown.contains(.notes) { items.append(TimelineItem(row: .notes, title: "Call Lin about Room 3", start: 11.5, end: 11.7, state: nil)) }
        if previewToday.shown.contains(.dispatches) { items.append(TimelineItem(row: .dispatches, title: "Nightly tests · Codex", start: 19.5, end: 19.8, state: nil)) }
        if previewToday.shown.contains(.focus) { items.append(TimelineItem(row: .focus, title: "Focus", start: 13, end: 15, state: nil)) }
        return items
    }
}

/// One lane per row kind, time across, now as a line.
private struct TodayLanes: View {
    @Environment(BenchModel.self) private var model

    var body: some View {
        let rows = model.previewToday.rows.filter(model.previewToday.shown.contains)
        let items = model.todayItems
        let start = Double(model.previewToday.start), end = Double(model.previewToday.end)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Color.clear.frame(width: 72)
                GeometryReader { geo in
                    ForEach(Array(stride(from: Int(start), through: Int(end), by: 2)), id: \.self) { hour in
                        Text(String(format: "%02d", hour))
                            .font(BenchTokens.Type_.mono(9.5))
                            .foregroundStyle(BenchTokens.Notch.tertiary)
                            .position(x: geo.size.width * CGFloat((Double(hour) - start) / (end - start)), y: 6)
                    }
                }
                .frame(height: 12)
            }
            // The lanes as one block: a new order fades the old lanes out, then the new ones in,
            // so no lane's name slides over another's.
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(rows, id: \.self) { row in
                        lane(row, items: items.filter { $0.row == row }, start: start, end: end)
                    }
                }
                .id(rows)
                .transition(.blockSwap)
            }
        }
    }

    private func lane(_ row: TodayRow, items laneItems: [TimelineItem], start: Double, end: Double) -> some View {
        HStack(spacing: 0) {
            Text(row.laneTitle)
                .font(.system(size: 11))
                .foregroundStyle(BenchTokens.Notch.secondary)
                .lineLimit(1)
                .frame(width: 72, alignment: .leading)
            GeometryReader { geo in
                let width = geo.size.width
                let xOf = { (t: Double) in width * CGFloat((t - start) / (end - start)) }
                // The next thing after now gets its name; the rest show by shape and place.
                let next = laneItems.filter { $0.start >= 14.5 }.min { $0.start < $1.start }
                // Runs that start close together keep a glyph's width apart, so no two marks overlap.
                let marks = Self.separated(laneItems.filter { $0.state != nil }.sorted { $0.start < $1.start }.map { ($0.id, xOf($0.start)) },
                                           gap: Self.glyphSize + 2)
                ZStack(alignment: .leading) {
                    Capsule().fill(BenchTokens.Notch.fill).frame(height: 2).frame(maxHeight: .infinity)
                    ForEach(laneItems) { item in
                        let x = xOf(item.start)
                        let w = max(6, xOf(item.end) - x)
                        if let state = item.state {
                            // An agent's run: its state by shape (as everywhere), its span a faint bar.
                            Capsule().fill(Color.white.opacity(0.14)).frame(width: w, height: 4)
                                .offset(x: x)
                            Image(systemName: state.symbol)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.9))
                                .frame(width: Self.glyphSize, height: Self.glyphSize)
                                .background(Circle().fill(BenchTokens.Notch.surface))
                                .offset(x: (marks[item.id] ?? x) - Self.glyphSize / 2)
                        } else {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.white.opacity(row == .focus ? 0.1 : 0.3))
                                .frame(width: w, height: 14)
                                .overlay(alignment: .leading) {
                                    if w > 40 {
                                        Text(item.title).font(.system(size: 9.5, weight: .medium))
                                            .foregroundStyle(BenchTokens.Notch.text)
                                            .lineLimit(1).padding(.horizontal, 4)
                                    }
                                }
                                .offset(x: x)
                            if item.id == next?.id && w <= 40 {
                                // Its name after the mark when it fits there, else before it: always
                                // inside the lane.
                                let leftward = x + w + 6 + Self.labelWidth(item.title) > width
                                Text(item.title).font(.system(size: 9.5, weight: .medium))
                                    .foregroundStyle(BenchTokens.Notch.secondary)
                                    .lineLimit(1)
                                    .fixedSize()
                                    .frame(width: leftward ? x - 6 : max(0, width - x - w - 6), alignment: leftward ? .trailing : .leading)
                                    .offset(x: leftward ? 0 : x + w + 6)
                            }
                        }
                    }
                    // Now.
                    Rectangle().fill(Color.white.opacity(0.85)).frame(width: 1, height: 18)
                        .offset(x: xOf(14.5))
                }
            }
            .frame(height: 18)
        }
    }

    static let glyphSize: CGFloat = 12

    /// A lane label's width at its size, for picking its side.
    static func labelWidth(_ title: String) -> CGFloat {
        ceil((title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 9.5, weight: .medium)]).width)
    }

    /// Positions pushed right just enough that each is `gap` past the one before.
    static func separated(_ marks: [(String, CGFloat)], gap: CGFloat) -> [String: CGFloat] {
        var result: [String: CGFloat] = [:]
        var last = -CGFloat.infinity
        for (id, x) in marks {
            let placed = max(x, last + gap)
            result[id] = placed
            last = placed
        }
        return result
    }
}

/// One list down the day, now as a rule.
private struct TodayAgenda: View {
    @Environment(BenchModel.self) private var model

    var body: some View {
        let order = model.previewToday.rows
        let items = model.todayItems.filter { $0.row != .focus || model.previewToday.shown.contains(.focus) }
            .sorted { $0.start == $1.start ? (order.firstIndex(of: $0.row) ?? 0) < (order.firstIndex(of: $1.row) ?? 0) : $0.start < $1.start }
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items) { item in
                HStack(spacing: 10) {
                    Text(String(format: "%02d:%02d", Int(item.start), Int((item.start - floor(item.start)) * 60)))
                        .font(BenchTokens.Type_.mono(11))
                        .foregroundStyle(BenchTokens.Notch.tertiary)
                        .frame(width: 40, alignment: .leading)
                    if let state = item.state {
                        Text(state.word).font(BenchTokens.Notch.statusFont).foregroundStyle(BenchTokens.Notch.secondary).frame(width: 66, alignment: .leading)
                    } else {
                        Text(item.row.laneTitle).font(.system(size: 11)).foregroundStyle(BenchTokens.Notch.tertiary).frame(width: 66, alignment: .leading)
                    }
                    Text(item.title).font(BenchTokens.Notch.rowFont).foregroundStyle(BenchTokens.Notch.text).lineLimit(1)
                    Spacer()
                }
                .frame(height: 24)
                if item.start < 14.5, let next = items.first(where: { $0.start >= 14.5 }), items.firstIndex(where: { $0.id == next.id }) == (items.firstIndex(where: { $0.id == item.id }) ?? 0) + 1 {
                    HStack(spacing: 6) {
                        Text("14:30").font(BenchTokens.Type_.mono(10)).foregroundStyle(Color.white)
                        Rectangle().fill(Color.white.opacity(0.85)).frame(height: 1)
                    }
                    .frame(height: 14)
                }
            }
        }
    }
}

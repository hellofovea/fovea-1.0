import AppKit
import SwiftUI
import CapturesCore
import FoveaKit

/// Settings' own parts, so a pane reads as Fovea and not as a stock grouped form: paper cards
/// with a hairline instead of gray boxes; rows with a title over an optional description and the
/// control at the right; native controls for values, custom ones only where a picture says more
/// (choice tiles), for keys (caps) and for lists of things (chip wells); status as a word, with
/// color only when something needs you. References: Raycast's settings (account header, status
/// words, a red Sign Out row), Linear's preferences (title over description, control right),
/// Vercel's Geist (Choicebox, Kbd, card footers), Bartender 5 (pictures of the choices).

// MARK: - Native

private struct SettingsNativeKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    /// Settings drawn as the Mac draws its own (the sidebar layouts): sections as grouped boxes
    /// under bold headers, the system's switches, menus and buttons (`T.Native`). The same panes
    /// draw Fovea's paper cards everywhere else.
    var settingsNative: Bool {
        get { self[SettingsNativeKey.self] }
        set { self[SettingsNativeKey.self] = newValue }
    }
}

// MARK: - Page, section, card, row

/// The pane, centered, its sections 36 pt apart, in its arrangement: one 560 pt column,
/// a wider one, the titles beside the cards, or two columns. An arrangement the page hasn't room
/// for steps down to one that fits.
struct SettingsColumn<Content: View>: View {
    @Environment(CapturesModel.self) private var model
    @ViewBuilder let content: () -> Content
    var body: some View {
        GeometryReader { geo in
            let arrangement = model.settingsArrangement.fitting(geo.size.width - 48)
            ScrollView {
                Group {
                    if arrangement == .twoColumns {
                        Masonry(columns: 2, spacing: T.Layout.columnGap, rowSpacing: 36) { content() }
                    } else if arrangement == .beside {
                        // A rule across both columns between one titled section and the next
                        // (Apple's spec pages, Tailwind's Catalyst, Shopify's Polaris): 32 pt
                        // either side of it, three times the gaps inside a section.
                        VStack(alignment: .leading, spacing: 2 * T.Layout.besideRuleGap + 1) { content() }
                            .overlayPreferenceValue(SectionFramesKey.self) { sections in
                                GeometryReader { proxy in
                                    let frames = sections.map { (proxy[$0.bounds], $0.titled) }.sorted { $0.0.minY < $1.0.minY }
                                    ForEach(Array(frames.indices.dropFirst()), id: \.self) { i in
                                        if frames[i].1 && frames[i - 1].1 {
                                            SectionRule()
                                                .offset(y: (frames[i - 1].0.maxY + frames[i].0.minY) / 2)
                                        }
                                    }
                                }
                                .allowsHitTesting(false)
                            }
                    } else {
                        VStack(alignment: .leading, spacing: 36) { content() }
                    }
                }
                .environment(\.settingsArrangement, arrangement)
                .frame(width: arrangement.width, alignment: .leading)
                .padding(.top, 28)
                .padding(.bottom, 48)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Where each section is, and whether it has a title, for the rules between them.
struct SectionFramesKey: PreferenceKey {
    struct Section { let bounds: Anchor<CGRect>; let titled: Bool }
    static let defaultValue: [Section] = []
    static func reduce(value: inout [Section], nextValue: () -> [Section]) { value += nextValue() }
}

/// The rule between sections: 1 pt of the separator's ink across both columns (0.5 would read
/// as one more card edge).
private struct SectionRule: View {
    @Environment(\.palette) private var palette
    var body: some View {
        Rectangle().fill(palette.ink(0.1)).frame(height: 1)
    }
}

/// Columns that each take the next view into whichever is shorter, as a masonry wall does.
struct Masonry: Layout {
    var columns = 2
    var spacing: CGFloat = 24
    var rowSpacing: CGFloat = 36

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 2 * T.Layout.halfColumn + spacing
        let placed = place(width: width, subviews: subviews)
        return CGSize(width: width, height: placed.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placed = place(width: bounds.width, subviews: subviews)
        for (view, frame) in zip(subviews, placed.frames) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), anchor: .topLeading,
                       proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }

    private func place(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], height: CGFloat) {
        let n = CGFloat(columns)
        let column = (width - spacing * (n - 1)) / n
        var heights = Array(repeating: CGFloat(0), count: columns)
        var frames: [CGRect] = []
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: column, height: nil))
            let c = heights.indices.min { heights[$0] < heights[$1] } ?? 0
            frames.append(CGRect(x: CGFloat(c) * (column + spacing), y: heights[c], width: column, height: size.height))
            heights[c] += size.height + rowSpacing
        }
        return (frames, max(0, (heights.max() ?? 0) - rowSpacing))
    }
}

/// A sentence-case title 8 pt over its card (closer to what it names than to the card before),
/// with an optional accessory at its end: a filter, a count, a refresh.
struct SettingsSection<Content: View, Accessory: View>: View {
    @Environment(\.palette) private var palette
    let title: String?
    var note: String?
    @ViewBuilder let accessory: () -> Accessory
    @ViewBuilder let content: () -> Content

    init(_ title: String?, note: String? = nil, @ViewBuilder accessory: @escaping () -> Accessory,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.note = note; self.accessory = accessory; self.content = content
    }

    @Environment(\.settingsArrangement) private var arrangement
    @Environment(\.settingsNative) private var native
    @State private var titleHeight: CGFloat = 0

    var body: some View {
        if arrangement == .beside && !native && (title != nil || note != nil) {
            beside
        } else {
            stacked
        }
    }

    /// The title and its note in a column of their own at the left, the card at the right. The
    /// title is the section's heaviest text (Title 3, 15 pt), level with the card's top, and it
    /// stays 16 pt under the top of the page while its section scrolls by, leaving with it
    /// (Linear's changelog, GitLab's settings).
    private var beside: some View {
        // The card at the right; the section at least as tall as its title, which rides over the
        // left of it, in a column as tall as the section so it has room to stay.
        HStack(alignment: .top, spacing: 0) {
            Color.clear.frame(width: T.Layout.besideTitles + T.Layout.besideGap, height: 1)
            VStack(alignment: .leading, spacing: 8) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: titleHeight, alignment: .top)
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 4) {
                if let title {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(palette.text)
                        .accessibilityAddTraits(.isHeader)
                }
                if let note {
                    Text(note).font(.system(size: 12)).foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if Accessory.self != EmptyView.self { accessory().padding(.top, 8) }
            }
            .frame(width: T.Layout.besideTitles, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { titleHeight = $0 }
            .frame(maxHeight: .infinity, alignment: .top)
            .visualEffect { [titleHeight] content, proxy in
                let frame = proxy.frame(in: .scrollView)
                let room = max(0, frame.height - titleHeight)
                return content.offset(y: min(room, max(0, 16 - frame.minY)))
            }
        }
        .anchorPreference(key: SectionFramesKey.self, value: .bounds) { [.init(bounds: $0, titled: true)] }
    }

    /// Untitled sections run across both columns; beside titled ones they count as untitled, so
    /// no rule is drawn through or against them.
    private var stacked: some View {
        stackedBody
            .anchorPreference(key: SectionFramesKey.self, value: .bounds) { [.init(bounds: $0, titled: false)] }
    }

    private var stackedBody: some View {
        // Native: the header in bold over its group, lined up with the rows' text inside it.
        let inset: CGFloat = native ? T.Native.rowInset : 2
        return VStack(alignment: .leading, spacing: native ? T.Native.headerGap : 8) {
            if title != nil || Accessory.self != EmptyView.self {
                HStack(alignment: .firstTextBaseline) {
                    if let title {
                        Text(title).font(.system(size: 13, weight: native ? .bold : .semibold)).foregroundStyle(palette.text)
                            .accessibilityAddTraits(.isHeader)
                    }
                    Spacer(minLength: 8)
                    accessory()
                }
                .padding(.horizontal, inset)
            }
            if let note {
                Text(note).font(.system(size: native ? 11 : 12)).foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, inset)
                    .padding(.bottom, native ? 2 : 4)
            }
            content()
        }
    }
}

extension SettingsSection where Accessory == EmptyView {
    init(_ title: String?, note: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.init(title, note: note, accessory: { EmptyView() }, content: content)
    }
}

/// A card: the page's own surface told from it Aside's way, by an edge just inside it and a soft
/// shadow, never a gray box; an optional footer strip (Vercel's card footer: a sentence on the
/// left, an action on the right).
struct SettingsCard<Content: View, Footer: View>: View {
    @Environment(\.palette) private var palette
    /// 12 (Aside's card); larger where something rounded sits inset in it, so its corners stay
    /// concentric with the card's.
    var radius: CGFloat = 12
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer

    init(radius: CGFloat = 12, @ViewBuilder content: @escaping () -> Content, @ViewBuilder footer: @escaping () -> Footer) {
        self.radius = radius; self.content = content; self.footer = footer
    }

    @Environment(\.settingsNative) private var native

    var body: some View {
        if native {
            // The Mac's grouped box: a step off the page, no edge, no shadow.
            let shape = RoundedRectangle(cornerRadius: T.Native.groupRadius, style: .continuous)
            VStack(spacing: 0) {
                VStack(spacing: 0) { content() }
                if Footer.self != EmptyView.self {
                    RowDivider()
                    HStack(spacing: 12) { footer() }
                        .font(.system(size: 11))
                        .foregroundStyle(palette.secondary)
                        .padding(.horizontal, T.Native.rowInset)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(palette.nativeGroup)
            .clipShape(shape)
        } else {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            VStack(spacing: 0) {
                VStack(spacing: 0) { content() }
                if Footer.self != EmptyView.self {
                    Rectangle().fill(palette.hairline).frame(height: 0.5)
                    HStack(spacing: 12) { footer() }
                        .font(.system(size: 12))
                        .foregroundStyle(palette.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.fill.opacity(0.5))
                }
            }
            .background(palette.card)
            .clipShape(shape)
            // Aside's shading: the edge just inside, a soft two-layer shadow.
            .shading(shape, .resting)
        }
    }
}

extension SettingsCard where Footer == EmptyView {
    init(radius: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
        self.init(radius: radius, content: content, footer: { EmptyView() })
    }
}

/// One setting: its title, a description only when the title doesn't say what it does, and its
/// control at the right, centered on the text.
struct SettingsRow<Control: View>: View {
    @Environment(\.palette) private var palette
    let title: String
    var detail: String?
    var icon: NSImage?
    @ViewBuilder let control: () -> Control

    init(_ title: String, detail: String? = nil, icon: NSImage? = nil, @ViewBuilder control: @escaping () -> Control) {
        self.title = title; self.detail = detail; self.icon = icon; self.control = control
    }

    @Environment(\.settingsNative) private var native

    var body: some View {
        // Native: the Mac's row (13 pt regular over an 11 pt description, 10 pt in from the box).
        HStack(alignment: .center, spacing: native ? 10 : 12) {
            if let icon {
                Image(nsImage: icon).resizable().interpolation(.high).frame(width: native ? 24 : 28, height: native ? 24 : 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: native ? .regular : .medium)).foregroundStyle(palette.text)
                if let detail {
                    Text(detail).font(.system(size: native ? 11 : 11.5)).foregroundStyle(palette.secondary)
                        .frame(maxWidth: 360, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 16)
            control()
        }
        .padding(.horizontal, native ? T.Native.rowInset : 16)
        .padding(.vertical, native ? 7 : 10)
        .frame(minHeight: native ? (detail == nil ? T.Native.rowHeight : T.Native.rowHeightWithDetail) : (detail == nil ? 44 : 56))
        .accessibilityElement(children: .contain)
    }
}

extension SettingsRow where Control == EmptyView {
    init(_ title: String, detail: String? = nil, icon: NSImage? = nil) {
        self.init(title, detail: detail, icon: icon, control: { EmptyView() })
    }
}

/// The hairline between rows, inset to the text (past an icon when rows carry one).
struct RowDivider: View {
    @Environment(\.palette) private var palette
    @Environment(\.settingsNative) private var native
    var inset: CGFloat = 16
    var body: some View {
        if native {
            // The Mac's: 1 pt, in 10 pt from both ends of the box (past an icon when rows carry one).
            Rectangle().fill(palette.nativeSeparator).frame(height: 1)
                .padding(.leading, inset - 16 + T.Native.rowInset)
                .padding(.trailing, T.Native.rowInset)
        } else {
            Rectangle().fill(palette.hairline.opacity(0.7)).frame(height: 0.5).padding(.leading, inset)
        }
    }
}

// MARK: - Controls

/// A native switch, monochrome as Aside's are: on is the ink, not the accent (white at 85 % in
/// dark would hide the knob, so dark's is the label gray). Native settings: the system's own,
/// in the accent you picked for your Mac.
struct InkToggle: View {
    @Environment(\.palette) private var palette
    @Environment(\.settingsNative) private var native
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        if native {
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        } else {
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .tint(palette.isDark ? Color(white: 0.56) : palette.ink(0.85))
        }
    }
}

/// A value and its chevrons in a pill; a menu of the choices with a check on the current one.
struct InlinePicker<Value: Hashable>: View {
    @Environment(\.palette) private var palette
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> String
    var icon: ((Value) -> NSImage?)?
    @State private var hover = false
    @Environment(\.settingsNative) private var native

    var body: some View {
        if native {
            // The system's pop-up menu.
            Picker(selection: $selection) {
                ForEach(options, id: \.self) { option in
                    if let icon, let image = icon(option) {
                        Label { Text(label(option)) } icon: { Image(nsImage: Art.small(image)) }.tag(option)
                    } else {
                        Text(label(option)).tag(option)
                    }
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        } else {
            pill
        }
    }

    private var pill: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    if option == selection {
                        Label(label(option), systemImage: "checkmark").labelStyle(.titleAndIcon)
                    } else {
                        Text(label(option))
                    }
                }
            }
        } label: {
            // One text with its images set in it, so a menu's label keeps their order and size.
            let chevron = Text(Image(systemName: "chevron.up.chevron.down")).font(.system(size: 9, weight: .semibold))
            if let icon, let image = icon(selection) {
                Text("\(Image(nsImage: Art.small(image)))  \(label(selection)) \(chevron)")
            } else {
                Text("\(label(selection)) \(chevron)")
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .font(.system(size: 12.5, weight: .medium))
        .foregroundStyle(palette.text)
        .fixedSize()
        // Aside's style menu: the value in a pill (the ink at 7 %, a 12 % edge), a step darker
        // under the pointer.
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Capsule().fill(palette.ink(hover ? T.Shade.fillHover : T.Shade.fill)))
        .overlay(Capsule().strokeBorder(palette.ink(T.Shade.line), lineWidth: 0.5))
        .contentShape(Capsule())
        .onHover { hover = $0 }
        .animation(.easeOut(duration: T.Motion.hover), value: hover)
    }
}

/// A secondary action: words in a pill, as Aside's are since 2.0 (an arrow when it leaves the
/// app); destructive ones in red, with a pink wash under the pointer. The one prominent pill on a
/// page is `PillButton(kind: .prominent)`.
struct TextButton: View {
    let title: String
    var role: ButtonRole?
    let action: () -> Void

    init(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title; self.role = role; self.action = action
    }

    @Environment(\.settingsNative) private var native

    var body: some View {
        if native {
            // The system's push button.
            Button(title, role: role, action: action)
        } else {
            PillButton(title, kind: role == .destructive ? .destructive : .secondary, action: action)
        }
    }
}

/// A status as a word: quiet when all is well; a warning dot, the word in ink and the fix right
/// beside it when it needs you.
struct StatusLabel: View {
    @Environment(\.palette) private var palette
    let word: String
    var ok = true
    var fix: (title: String, action: () -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            if ok {
                Image(systemName: "checkmark").font(.system(size: 9.5, weight: .bold))
                Text(word)
            } else {
                Circle().fill(palette.warning).frame(width: 6, height: 6)
                Text(word).foregroundStyle(palette.text)
                if let fix {
                    TextButton(fix.title, action: fix.action).padding(.leading, 6)
                }
            }
        }
        .font(.system(size: 12.5))
        .foregroundStyle(palette.secondary)
    }
}

// MARK: - Choice tiles

/// A choice shown, not named (Geist's Choicebox, Bartender's previews): the whole tile is the
/// button, shaded as Aside's cards and lifted a step under the pointer; the chosen one has an
/// ink edge and a check in its corner. Arrow keys move the choice.
struct ChoiceTiles<Value: Hashable, Picture: View>: View {
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion
    struct Option { let value: Value; let title: String; let detail: String }
    let options: [Option]
    @Binding var selection: Value
    @ViewBuilder let picture: (Value, Bool) -> Picture

    @State private var hovered: Value?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(options, id: \.value) { option in
                let on = option.value == selection
                // Concentric: the picture inset 6 pt in a tile rounded 14, so rounded 8.
                let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
                Button { withAnimation(motion.animation(.swap)) { selection = option.value } } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        picture(option.value, on)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(palette.ink(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.text)
                            Text(option.detail).font(.system(size: 11.5)).foregroundStyle(palette.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .settingsSurface(shape, hovered == option.value && !on ? .raised : .resting)
                    // Chosen: the ink, as Aside's active chip is.
                    .overlay(shape.strokeBorder(on ? palette.ink(0.85) : .clear, lineWidth: 1.5))
                    .overlay(alignment: .topTrailing) {
                        if on {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(palette.card)
                                .frame(width: 16, height: 16)
                                .background(Circle().fill(palette.text))
                                .padding(12)
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                    }
                    .contentShape(shape)
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(motion.animation(.hover)) { if h { hovered = option.value } else if hovered == option.value { hovered = nil } }
                }
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onMoveCommand { direction in
            guard let i = options.firstIndex(where: { $0.value == selection }) else { return }
            let j = direction == .left ? i - 1 : (direction == .right ? i + 1 : i)
            if options.indices.contains(j) { withAnimation(motion.animation(.swap)) { selection = options[j].value } }
        }
    }
}

// MARK: - Keys

/// A shortcut as keys: one cap per key, no "+" between, muted words where a key needs saying
/// ("Left", "twice"). Click to record: the caps become a well that says so; Esc cancels.
struct KeyCaps: View {
    @Environment(\.palette) private var palette
    let keys: [String]
    var large = false
    @State private var recording = false

    var body: some View {
        Button {
            recording.toggle()
            if recording {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2.5))
                    recording = false
                }
            }
        } label: {
            Group {
                if recording {
                    Text("Type a shortcut")
                        .font(.system(size: large ? 13 : 12, weight: .medium))
                        .foregroundStyle(palette.secondary)
                        .padding(.horizontal, 10)
                        .frame(height: large ? 32 : 22)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(palette.text.opacity(0.05)))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(palette.text, lineWidth: 1.5))
                } else {
                    HStack(spacing: 4) {
                        ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                            if key.hasPrefix("~") {
                                Text(String(key.dropFirst())).font(.system(size: large ? 13 : 11.5)).foregroundStyle(palette.tertiary)
                            } else {
                                KeyCapView(key: key, large: large)
                            }
                        }
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onExitCommand { recording = false }
        .help("Click, then press the new keys")
        .accessibilityLabel(keys.map { $0.hasPrefix("~") ? String($0.dropFirst()) : $0 }.joined(separator: " "))
    }
}

/// One key: paper with a hairline and a slightly darker bottom edge, the glyph in ink.
struct KeyCapView: View {
    @Environment(\.palette) private var palette
    let key: String
    var large = false
    var body: some View {
        let h: CGFloat = large ? 32 : 22
        let shape = RoundedRectangle(cornerRadius: large ? 7 : 5, style: .continuous)
        Text(key)
            .font(.system(size: large ? 15 : 12, weight: .medium))
            .foregroundStyle(palette.text)
            .padding(.horizontal, large ? 9 : 6)
            .frame(minWidth: h, minHeight: h)
            .overlay(alignment: .bottom) {
                shape.fill(palette.ink(0.08)).frame(height: 1.5).padding(.horizontal, 2).offset(y: -0.25)
                    .mask(shape)
            }
            .shading(shape, .control)
    }
}

// MARK: - Lists of things

/// Things as capsules in lines, ending with a dashed capsule to add one; a hover shows a
/// capsule's ×. Removing is immediate (Undo is in the toast); adding happens in place.
struct ChipWell<Item: Identifiable>: View {
    @Environment(\.palette) private var palette
    let items: [Item]
    let title: (Item) -> String
    var icon: ((Item) -> NSImage?)?
    var marked: ((Item) -> Bool)?
    let addTitle: String
    let onRemove: (Item) -> Void
    let onAdd: ((String) -> Void)?
    var onTap: ((Item) -> Void)?
    @State private var adding = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items) { item in
                Capsule_(text: title(item), icon: icon?(item), marked: marked?(item) ?? false,
                         onRemove: { onRemove(item) }, onTap: onTap.map { tap in { tap(item) } })
            }
            if adding {
                TextField(addTitle, text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .focused($fieldFocused)
                    .onSubmit { commit() }
                    .onExitCommand { adding = false; draft = "" }
                    .padding(.horizontal, 10)
                    .frame(width: 180, height: 24)
                    .background(Capsule().fill(palette.card))
                    .overlay(Capsule().strokeBorder(palette.text, lineWidth: 1))
                    .onAppear { fieldFocused = true }
            } else {
                Button {
                    if onAdd != nil { adding = true } else { onAddApp() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 9.5, weight: .semibold))
                        Text(addTitle)
                    }
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.secondary)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .overlay(Capsule().strokeBorder(palette.tertiary, style: StrokeStyle(lineWidth: 1, dash: [3, 2.5])))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func commit() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty { onAdd?(text) }
        draft = ""
        adding = false
    }

    private func onAddApp() {}
}

private struct Capsule_: View {
    @Environment(\.palette) private var palette
    let text: String
    let icon: NSImage?
    let marked: Bool
    let onRemove: () -> Void
    let onTap: (() -> Void)?
    @State private var hover = false

    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(nsImage: icon).resizable().frame(width: 16, height: 16) }
            if marked {
                Image(systemName: "sparkle").font(.system(size: 9, weight: .semibold)).foregroundStyle(palette.text.opacity(0.4))
            }
            Text(text).font(.system(size: 12.5)).foregroundStyle(palette.text)
            if hover {
                Button(action: onRemove) {
                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(palette.secondary)
                        .frame(width: 14, height: 14)
                        .background(Circle().fill(palette.fill))
                }
                .buttonStyle(.plain)
                .help("Remove \(text)")
                .transition(.opacity)
            }
        }
        .padding(.leading, icon == nil ? 10 : 5)
        .padding(.trailing, hover ? 5 : 10)
        .frame(height: 24)
        .background(Capsule().fill(palette.ink(hover ? T.Shade.fillHover : T.Shade.fill)))
        .overlay(Capsule().strokeBorder(palette.ink(T.Shade.line), lineWidth: 0.5))
        .contentShape(Capsule())
        .onHover { h in withAnimation(.easeOut(duration: T.Motion.hover)) { hover = h } }
        .onTapGesture { onTap?() }
    }
}

// MARK: - The irreversible

/// The last card on a pane, for what can't be undone: what it does, in real numbers, and a
/// button named for the act.
struct DangerCard: View {
    @Environment(\.palette) private var palette
    let title: String
    let consequence: String
    let button: String
    let action: () -> Void
    @Environment(\.settingsNative) private var native

    var body: some View {
        if native {
            SettingsCard {
                SettingsRow(title, detail: consequence) {
                    Button(button, role: .destructive, action: action)
                }
            }
        } else {
            paper
        }
    }

    private var paper: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(palette.text)
                Text(consequence).font(.system(size: 11.5)).foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            PillButton(button, kind: .destructive, action: action)
        }
        .padding(16)
        .shading(shape, .resting)
    }
}

// MARK: - Margins

/// A card's inner margin: 16 pt in Fovea's cards; in native settings the Mac's 10 at the sides
/// (lined up with the rows' text) and 12 at the top and bottom.
private struct CardPadding: ViewModifier {
    @Environment(\.settingsNative) private var native
    let edges: Edge.Set
    func body(content: Content) -> some View {
        if native {
            content
                .padding(edges.intersection(.horizontal), T.Native.rowInset)
                .padding(edges.intersection(.vertical), 12)
        } else {
            content.padding(edges, 16)
        }
    }
}

extension View {
    func cardPadding(_ edges: Edge.Set = .all) -> some View { modifier(CardPadding(edges: edges)) }
}

// MARK: - Tiles

/// A tile's surface: Aside's shading on Fovea's paper; in native settings the Mac's group box,
/// a step off the page with no edge and no shadow.
private struct SettingsSurface<S: InsettableShape>: ViewModifier {
    @Environment(\.settingsNative) private var native
    @Environment(\.palette) private var palette
    let shape: S
    let level: T.Shade.Level
    func body(content: Content) -> some View {
        if native {
            content.background(palette.nativeGroup, in: shape)
        } else {
            content.shading(shape, level)
        }
    }
}

extension View {
    func settingsSurface<S: InsettableShape>(_ shape: S, _ level: T.Shade.Level = .resting) -> some View {
        modifier(SettingsSurface(shape: shape, level: level))
    }
}

/// Two to four choices side by side: the sliding pill on Fovea's paper; the system's segmented
/// control in native settings.
struct SettingsSegments<Value: Hashable>: View {
    @Environment(\.settingsNative) private var native
    let segments: [(value: Value, title: String)]
    let selection: Value
    var inset: CGFloat = 4
    var padding: CGFloat = 10
    let choose: (Value) -> Void

    var body: some View {
        if native {
            Picker("", selection: Binding(get: { selection }, set: { choose($0) })) {
                ForEach(segments, id: \.value) { Text($0.title).tag($0.value) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
        } else {
            SlidingSegments(segments: segments.map { .init(value: $0.value, title: $0.title) },
                            selection: selection, height: 22, fontSize: 11.5, padding: padding, inset: inset, choose: choose)
        }
    }
}

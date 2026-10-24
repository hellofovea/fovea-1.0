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
///
/// Oct 18, Ryan: the interface in the primary language. The parts here take their words as
/// Strings and show them through `L(key:)`, so a literal written at a call site is looked up in
/// Localization/zh-Hans/window.strings as it's drawn; a sentence with a value in it is made with
/// `L("…\(value)…")` where it's written (its key then has %@ or %lld), and passes through unchanged.

/// Oct 18, Ryan: a word whose English means two things in the app ("Max" a plan and a level of
/// thinking, "Off" a shortcut not set and a permission turned off), looked up by a key of its own
/// so Chinese can say each: the English as given, the Chinese under `key` in window.strings.
func L(_ key: StaticString, english: String.LocalizationValue) -> String {
    // Oct 21, perf: remembered (FoveaKit's `LookupMemo`); the lookup itself is as it was.
    LookupMemo.shared.value(language: FoveaLocale.shared.language, key: key, english: english) {
        String(localized: LocalizedStringResource(key, defaultValue: english, locale: FoveaLocale.shared.locale, bundle: .main))
    }
}

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
                    Text(L(key: title)).font(.system(size: 15, weight: .semibold)).foregroundStyle(palette.text)
                        .accessibilityAddTraits(.isHeader)
                }
                if let note {
                    Text(L(key: note)).font(.system(size: 12)).foregroundStyle(palette.secondary)
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
                        Text(L(key: title)).font(WindowLook.isAligned ? T.Aligned.sectionHeader : .system(size: 13, weight: native ? .bold : .semibold))
                            .foregroundStyle(palette.text)
                            .accessibilityAddTraits(.isHeader)
                    }
                    Spacer(minLength: 8)
                    accessory()
                }
                .padding(.horizontal, inset)
            }
            if let note {
                Text(L(key: note)).font(.system(size: WindowLook.isAligned ? T.Aligned.rowDetail : (native ? 11 : 12)))
                    .foregroundStyle(palette.secondary)
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
            // The Mac's grouped box: a step off the page, no edge, no shadow. Aligned: the first
            // run's card, a fill at 14 pt (`T.Aligned`).
            let aligned = WindowLook.isAligned
            let shape = RoundedRectangle(cornerRadius: aligned ? T.Aligned.cardRadius : T.Native.groupRadius, style: .continuous)
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
            .background(aligned ? palette.card : palette.nativeGroup)
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
    /// Oct 18: the title as written, never looked up (a language's own name: "English" stays
    /// English in a Chinese interface, with 英语 under it).
    var verbatim = false
    @ViewBuilder let control: () -> Control

    init(_ title: String, detail: String? = nil, icon: NSImage? = nil, @ViewBuilder control: @escaping () -> Control) {
        self.title = title; self.detail = detail; self.icon = icon; self.control = control
    }

    init(verbatim title: String, detail: String? = nil, @ViewBuilder control: @escaping () -> Control) {
        self.title = title; self.detail = detail; self.verbatim = true; self.control = control
    }

    @Environment(\.settingsNative) private var native

    var body: some View {
        // Native: the Mac's row (13 pt regular over an 11 pt description, 10 pt in from the box).
        HStack(alignment: .center, spacing: native ? 10 : 12) {
            if let icon {
                Image(nsImage: icon).resizable().interpolation(.high).frame(width: native ? 24 : 28, height: native ? 24 : 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim ? title : L(key: title)).font(.system(size: 13, weight: native ? .regular : .medium)).foregroundStyle(palette.text)
                if let detail {
                    Text(L(key: detail)).font(.system(size: native && !WindowLook.isAligned ? 11 : T.Aligned.rowDetail)).foregroundStyle(palette.secondary)
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
            // Aligned: the notch's hairline, 0.5 pt.
            Rectangle().fill(WindowLook.isAligned ? palette.hairline : palette.nativeSeparator).frame(height: WindowLook.isAligned ? 0.5 : 1)
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
            Toggle(L(key: title), isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        } else {
            Toggle(L(key: title), isOn: $isOn)
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
    @Environment(\.motion) private var motion
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> String
    var icon: ((Value) -> NSImage?)?
    @State private var hover = false
    @Environment(\.settingsNative) private var native

    var body: some View {
        // Aligned: the value in a pill, as the notch's model menu shows it, not the system pop-up.
        if native && !WindowLook.isAligned {
            // The system's pop-up menu.
            Picker(selection: $selection) {
                ForEach(options, id: \.self) { option in
                    if let icon, let image = icon(option) {
                        Label { Text(L(key: label(option))) } icon: { Image(nsImage: Art.small(image)) }.tag(option)
                    } else {
                        Text(L(key: label(option))).tag(option)
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
                        Label(L(key: label(option)), systemImage: "checkmark").labelStyle(.titleAndIcon)
                    } else {
                        Text(L(key: label(option)))
                    }
                }
            }
        } label: {
            // One text with its images set in it, so a menu's label keeps their order and size.
            let chevron = Text(Image(systemName: "chevron.up.chevron.down")).font(.system(size: 9, weight: .semibold))
            if let icon, let image = icon(selection) {
                Text("\(Image(nsImage: Art.small(image)))  \(L(key: label(selection))) \(chevron)")
            } else {
                Text("\(L(key: label(selection))) \(chevron)")
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .font(.system(size: 12.5, weight: .medium))
        .foregroundStyle(palette.text)
        .fixedSize()
        // Aside's style menu: the value in a pill (the ink at 7 %, a 12 % edge), a step darker
        // under the pointer.
        .padding(.horizontal, WindowLook.isAligned ? 12 : 10)
        .frame(height: WindowLook.isAligned ? T.Aligned.buttonHeight : 26)
        .background(Capsule().fill(palette.ink(WindowLook.isAligned ? (hover ? T.Aligned.secondaryHover : T.Aligned.secondaryFill)
                                                                    : (hover ? T.Shade.fillHover : T.Shade.fill))))
        .overlay(Capsule().strokeBorder(palette.ink(WindowLook.isAligned ? 0 : T.Shade.line), lineWidth: 0.5))
        .contentShape(Capsule())
        .onHover { hover = $0 }
        .animation(motion.animation(.hover), value: hover)
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
        if WindowLook.isAligned {
            // Aligned: the notch's buttons, a capsule with no edge, its words in sentence case as
            // the notch and the first run write theirs.
            PillButton(AlignedCopy.sentence(title), kind: role == .destructive ? .destructive : .secondary, action: action)
        } else if native {
            // The system's push button.
            Button(L(key: title), role: role, action: action)
        } else {
            PillButton(title, kind: role == .destructive ? .destructive : .secondary, action: action)
        }
    }
}

/// A pane's own button: the system's push button (the prominent one bordered and filled), or in
/// Aligned the notch's capsule, in sentence case (Oct 24). Alerts and sheets keep the system's.
struct PaneButton: View {
    let title: String
    var prominent = false
    var role: ButtonRole?
    let action: () -> Void

    init(_ title: String, prominent: Bool = false, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title; self.prominent = prominent; self.role = role; self.action = action
    }

    var body: some View {
        if WindowLook.isAligned {
            PillButton(AlignedCopy.sentence(title), kind: prominent ? .prominent : (role == .destructive ? .destructive : .secondary),
                       action: action)
        } else if prominent {
            Button(LocalizedStringKey(title), role: role, action: action).buttonStyle(.borderedProminent)
        } else {
            Button(LocalizedStringKey(title), role: role, action: action)
        }
    }
}

/// Oct 24, Aligned: a button's words in sentence case, as the notch ("Answer again", "Send now")
/// and the first run ("Looks good", "Try it") write theirs. Each has its own key (and its Chinese,
/// the same as the Title Case one's, in window.strings); anything not listed is shown as written.
enum AlignedCopy {
    static func sentence(_ title: String) -> String {
        guard WindowLook.isAligned else { return title }
        return table[title] ?? title
    }

    private static let table: [String: String] = [
        "Replay the Tour": "Replay the tour", "Try It": "Try it", "Open Shortcuts": "Open shortcuts",
        "Restore Defaults": "Restore defaults", "Sign In…": "Sign in…", "Sign Out": "Sign out",
        "Check Again": "Check again", "Access Log…": "Access log…", "Add Word…": "Add word…",
        "Watch Recording": "Watch recording", "Delete It": "Delete it", "Collect Again": "Collect again",
        "Try Again": "Try again", "Delete Originals…": "Delete originals…", "Send Session": "Send session",
        "Report a Problem…": "Report a problem…", "Check for Updates": "Check for updates",
        "Install and Relaunch": "Install and relaunch", "Bring In": "Bring in", "Open Settings": "Open settings",
        "Reset All…": "Reset all…", "Choose a Plan…": "Choose a plan…",
        "Update Payment ↗": "Update payment ↗", "Reset to Default": "Reset to default",
    ]
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
                // Aligned: the notch's Complete, a filled check in the system green.
                if WindowLook.isAligned {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: T.Aligned.stateGlyph))
                        .foregroundStyle(palette.done)
                } else {
                    Image(systemName: "checkmark").font(.system(size: 9.5, weight: .bold))
                }
                Text(L(key: word))
            } else {
                Circle().fill(palette.warning).frame(width: 6, height: 6)
                Text(L(key: word)).foregroundStyle(palette.text)
                if let fix {
                    TextButton(fix.title, action: fix.action).padding(.leading, 6)
                }
            }
        }
        .font(.system(size: 12.5))
        .foregroundStyle(palette.secondary)
    }
}

// MARK: - Fields

/// A text field on a pane: the system's bordered field, or in Aligned a fill with no edge, ringed
/// in the accent while it has the keyboard, as the first run's and the notch's fields are.
private struct PaneField: ViewModifier {
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        if WindowLook.isAligned {
            let shape = RoundedRectangle(cornerRadius: T.Aligned.fieldRadius, style: .continuous)
            content
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($focused)
                .padding(.horizontal, 9)
                .frame(height: T.Aligned.buttonHeight)
                .background(shape.fill(palette.ink(T.Aligned.secondaryFill)))
                .overlay(shape.strokeBorder(focused ? palette.accent : .clear, lineWidth: 1))
                .animation(motion.animation(.hover), value: focused)
        } else {
            content.textFieldStyle(.roundedBorder)
        }
    }
}

extension View {
    func paneField() -> some View { modifier(PaneField()) }
}

// MARK: - Keys

/// One key: paper with a hairline, the glyph in ink. Oct 21, Ryan ("simpler is better"): flat,
/// without the darker bottom edge and the shadow that made it a 3D key.
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
            .shading(shape, .flat)
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
                Capsule_(text: title(item), icon: icon?(item),
                         onRemove: { onRemove(item) }, onTap: onTap.map { tap in { tap(item) } })
            }
            if adding {
                TextField(L(key: addTitle), text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .focused($fieldFocused)
                    .onSubmit { commit() }
                    .onExitCommand { adding = false; draft = "" }
                    .padding(.horizontal, 10)
                    .frame(width: 180, height: 24)
                    .background(Capsule().fill(WindowLook.isAligned ? palette.ink(T.Aligned.secondaryFill) : palette.card))
                    // Aligned: a field with the keyboard is ringed in the accent, as the notch's are.
                    .overlay(Capsule().strokeBorder(WindowLook.isAligned ? palette.accent : palette.text, lineWidth: 1))
                    .onAppear { fieldFocused = true }
            } else {
                Button {
                    if onAdd != nil { adding = true } else { onAddApp() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 9.5, weight: .semibold))
                        Text(L(key: addTitle))
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
    @Environment(\.motion) private var motion
    let text: String
    let icon: NSImage?
    let onRemove: () -> Void
    let onTap: (() -> Void)?
    @State private var hover = false

    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(nsImage: icon).resizable().frame(width: 16, height: 16) }
            Text(text).font(.system(size: 12.5)).foregroundStyle(palette.text)
            // Oct 21, Ryan ("simpler is better"): the × has its room all the time and shows under
            // the pointer, so the chip doesn't widen and push the row along.
            Button(action: onRemove) {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(palette.secondary)
                    .frame(width: 14, height: 14)
                    .background(Circle().fill(palette.fill))
            }
            .buttonStyle(.plain)
            .help("Remove \(text)")
            .opacity(hover ? 1 : 0)
            .allowsHitTesting(hover)
            .accessibilityHidden(!hover)
        }
        .padding(.leading, icon == nil ? 10 : 5)
        .padding(.trailing, 5)
        .frame(height: 24)
        .background(Capsule().fill(palette.ink(WindowLook.isAligned ? (hover ? T.Aligned.secondaryHover : T.Aligned.secondaryFill)
                                                                    : (hover ? T.Shade.fillHover : T.Shade.fill))))
        // Aligned: a fill, no edge, as the notch's chips.
        .overlay(Capsule().strokeBorder(palette.ink(WindowLook.isAligned ? 0 : T.Shade.line), lineWidth: 0.5))
        .contentShape(Capsule())
        .onHover { h in withAnimation(motion.animation(.hover)) { hover = h } }
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
                    if WindowLook.isAligned {
                        PillButton(AlignedCopy.sentence(button), kind: .destructive, action: action)
                    } else {
                        Button(L(key: button), role: .destructive, action: action)
                    }
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
                Text(L(key: title)).font(.system(size: 13, weight: .medium)).foregroundStyle(palette.text)
                Text(L(key: consequence)).font(.system(size: 11.5)).foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            PillButton(L(key: button), kind: .destructive, action: action)
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
            content.background(WindowLook.isAligned ? palette.card : palette.nativeGroup, in: shape)
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
        if WindowLook.isAligned {
            // Aligned: the first run's choice row (Make it yours' Glass, Panels, Size): the chosen
            // one solid ink on a quiet track, as wide as its words.
            let A = T.Aligned.self
            SlidingSegments(segments: segments.map { .init(value: $0.value, title: $0.title) },
                            selection: selection, pill: .island, track: .fill, height: A.segmentHeight, fontSize: A.segmentFont,
                            padding: A.segmentPadding, inset: A.segmentInset, equalWidths: false, choose: choose)
        } else if native {
            Picker(selection: Binding(get: { selection }, set: { choose($0) })) {
                ForEach(segments, id: \.value) { Text(L(key: $0.title)).tag($0.value) }
            } label: {
                EmptyView()
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

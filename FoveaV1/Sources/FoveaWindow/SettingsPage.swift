import AppKit
import SwiftUI
import CapturesCore
import FoveaKit
import FoveaPlatform
import Combine

/// Settings, in the window rather than in a window of its own. The profile icon at the top right
/// opens it on Account; the captures give way to it, and the toolbar's leading edge gets a back
/// arrow. The panes are picked from tabs across the top, as a Settings window's toolbar shows
/// them; never from a sidebar (on the panel: one page instead).
///
/// Five panes, each answering one question (built from the shipping Fovea Mac app's settings,
/// regrouped, within AGENTS.md's categories):
/// - Account: who you are, your plan and credits, the words Fovea writes your way, what you
///   asked it to remember, and how it runs on this Mac.
/// - Voice & Capture: the microphone and its sounds, what you take, and how long history stays.
///   (No Island style: Fovea is always the Dynamic Island.)
/// - Shortcuts: the keys, and the permissions they need.
/// - Connectors: the agents dispatches go to, how questions are answered, what agents may read.
/// - Eye Tracking: coming; help collect the data that trains it.
///
/// Built from `SettingsKit`: paper cards, rows with a title over an optional description, native
/// controls for values, pictures for visual choices, keys as caps, status as a word.
struct SettingsPage: View {
    @Environment(CapturesModel.self) private var model

    var body: some View {
        switch model.settingsLayout {
        case .sidebar, .sidebarPanes:
            // The sidebar is the window's (`MainView`); this is the page beside it.
            NativeSettingsPage()
        case .tabs:
            SettingsColumn { pane(model.settingsPane) }
                .id(model.settingsPane)
                .transition(.blockSwap)
        case .onePage:
            SettingsColumn {
                ForEach(SettingsPane.allCases, id: \.self) { p in
                    VStack(alignment: .leading, spacing: 36) {
                        PaneTitle(pane: p)
                        pane(p)
                    }
                }
            }
        }
    }

    @ViewBuilder private func pane(_ pane: SettingsPane) -> some View {
        switch pane {
        case .account: AccountPane()
        case .plan: PlanPane()
        case .voice: VoicePane()
        case .shortcuts: ShortcutsPane()
        case .connectors: ConnectorsPane()
        case .eyeTracking: EyeTrackingPane()
        }
    }
}

/// The panes across the top of the window, never down a sidebar: the same sliding pill as the
/// kinds of capture (Aside's segmented control), so the toolbar's center works one way on every
/// page.
struct SettingsTabs: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    var body: some View {
        // As wide as the widest where the window has room; as wide as their words where it
        // hasn't (the toolbar gives its center about 530 pt in a 980 pt window), and closer
        // still in a narrow one.
        let fit = model.toolbarFit
        return SlidingSegments(segments: SettingsPane.allCases.map { .init(value: $0, title: $0.title) },
                               selection: model.settingsPane,
                               pill: palette.surface == .system ? .raised : .island, track: .glass,
                               height: T.Layout.toolbarControl - 8, fontSize: fit == .tight ? 12 : 12.5,
                               padding: fit == .roomy ? 12 : (fit == .natural ? 9 : 7), inset: 4,
                               equalWidths: fit == .roomy) { pane in
            model.animate(.swap) { model.settingsPane = pane }
        }
        .accessibilityLabel("Settings")
    }
}

private struct PaneTitle: View {
    @Environment(\.palette) private var palette
    let pane: SettingsPane
    var body: some View {
        HStack(spacing: 8) {
            Text(pane.title).font(.system(size: 20, weight: .semibold)).foregroundStyle(palette.text)
            if pane == .eyeTracking { SoonPill(text: "Beta") }
        }
        .padding(.top, 8)
    }
}

/// "Coming soon": a hairline pill in the ink.
struct SoonPill: View {
    @Environment(\.palette) private var palette
    var text = "Soon"
    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(palette.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .overlay(Capsule().strokeBorder(palette.tertiary, lineWidth: 0.5))
    }
}

/// Settings' values for the prototype (in memory; nothing here reaches the system).
struct Prefs {
    enum Gaze: Equatable { case idle, downloading(Double), downloaded }

    var openAtLogin = true
    var showInDock = true
    var betaUpdates = true
    var keepCaptures = "Forever"
    var keepScreenshots = "90 days"
    var remember = true
    var rememberNotice = true
    var microphone = "MacBook Air Microphone"
    var speechLanguage = "Automatic"
    /// Fovea's words, and the notch's (row 6).
    var appLanguage: FoveaLanguage = .english
    var notchLanguage: NotchLanguage = .sameAsApp
    /// Memory Link (row 24, as the Mac app has it): remember what you send, not only what you ask.
    var memoryLink = true
    /// Places Fovea takes nothing from (row 25): apps, websites, and words.
    var privacyRules: [PrivacyRule] = PrivacyRule.defaults
    /// A question's model and effort for new chats (row 21), the rounds an answer shows, and what
    /// it can include from your screen (row 22).
    var questionModel = "Auto"
    var questionEffort: Effort = .auto
    var rounds = 3
    var includeWindow = true
    var includeWindowPicture = true
    /// Screen awareness (Oct 7): what dictation may read from the window you're speaking into. On,
    /// as the Mac app does it today; there it had no setting.
    var dictationWindow = true
    var dictationWindowText = true
    var readText = true
    var sounds = true
    var answerWith = "Fovea"
    var gaze: Gaze = .idle
    // Settings › Notch.
    var glow: GlowChoice = .colorful
    /// Degrees: how far the palette turns round the color wheel; Custom's own hue.
    var glowHue: Double = 0
    /// Degrees Custom's seven colors fan across (0, one color; 360, the whole wheel).
    var glowSpread: Double = 120
    /// How much the colors wander, still (0) to lively (1): a dial, as the first run has it.
    var glowDrift: Double = 0.5
    /// The notch's glass, light or dark, and how what drops below meets it (Oct 9).
    var notchAppearance: NotchAppearance = .dark
    var panels: NativePanels = .attached
    /// How much room what opens below the notch takes (Oct 9).
    var density: NotchDensity = .spacious
    var hoverOpens = true
    var hoverWait: HoverWait = .normal
    var showAnswers = true
    var reviewFirst = true

    /// The notch's settings as they ship.
    var notchIsDefault: Bool {
        glow == .colorful && glowHue == 0 && glowSpread == 120 && glowDrift == 0.5 && panels == .attached && density == .spacious
            && hoverOpens && hoverWait == .normal && showAnswers && reviewFirst
    }
    mutating func restoreNotch() {
        let d = Prefs()
        glow = d.glow; glowHue = d.glowHue; glowSpread = d.glowSpread
        glowDrift = d.glowDrift; panels = d.panels; density = d.density; hoverOpens = d.hoverOpens
        hoverWait = d.hoverWait; showAnswers = d.showAnswers; reviewFirst = d.reviewFirst
    }
}

// MARK: - Account

/// Who you are (your photo and name, yours to change), then the words Fovea writes your way and
/// what it knows of you, and how it runs on this Mac: its version and updates, and help.
struct AccountPane: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.settingsNative) private var native
    /// Dictionary, Memory and Language sit in Account on the tabs; the sidebar gives them their own.
    var dictionary = true
    var memories = true
    var language = true

    var body: some View {
        @Bindable var model = model
        ProfileSection()

        if language { LanguagePane() }
        if dictionary { DictionarySection() }
        if memories { MemorySection() }

        SettingsSection("On this Mac") {
            SettingsCard {
                // Light, Dark, or as the Mac is set: here on the tabs; the sidebar layouts give it
                // Settings › Appearance, with the theme and the accent.
                if !native {
                    SettingsRow("Appearance") {
                        Picker("Appearance", selection: $model.appearance) {
                            ForEach([Appearance.light, .dark, .system], id: \.self) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                    RowDivider()
                }
                SettingsRow("Open at login") { InkToggle(title: "Open at login", isOn: $model.prefs.openAtLogin) }
                RowDivider()
                SettingsRow("Show in Dock", detail: "Off keeps Fovea in the menu bar and around the notch.") {
                    InkToggle(title: "Show in Dock", isOn: $model.prefs.showInDock)
                }
                RowDivider()
                UpdateRow()
                RowDivider()
                SettingsRow("Get beta updates") { InkToggle(title: "Get beta updates", isOn: $model.prefs.betaUpdates) }
            } footer: {
                LegalLinks()
            }
        }
        .id("account-mac")

        SupportSection()
    }
}

/// Your plan: this month's credits, the plans side by side (each with who it's for under its
/// name, its price, what it includes), and when it renews. Up takes effect at once; down, when
/// the credits reset, and can be taken back until then. Everything here is simulated: nothing
/// is charged, and the prices and limits are placeholders.
struct PlanPane: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let usage = model.usage
        SettingsSection("This month") {
            PlanUsageCard()
        }

        SettingsSection("Plans") {
            SettingsSegments(segments: [(false, "Monthly"), (true, "Yearly")], selection: model.yearlyBilling) { yearly in
                model.animate(.swap) { model.yearlyBilling = yearly }
            }
        } content: {
            PlanTiles()
        }
        // The used-up card's Upgrade scrolls here.
        .id("plans")

        SettingsSection("Billing") {
            SettingsCard {
                if model.plan == .free {
                    SettingsRow("Nothing to pay", detail: "Free has no bill. Upgrade any time; you're charged from that day.")
                } else {
                    let price = model.plan.price(yearly: model.yearlyBilling)
                    if let next = model.nextPlan {
                        SettingsRow("\(model.plan.title) ends \(Lines.day(usage.resets))",
                                    detail: "Then \(next.title): \(next.credits.formatted()) credits a month. Until then nothing changes.") {
                            TextButton("Keep \(model.plan.title)") { model.choose(model.plan) }
                        }
                    } else {
                        SettingsRow("Renews \(Lines.day(usage.resets))",
                                    detail: "$\(price) \(model.yearlyBilling ? "a year" : "a month"). Simulated: nothing is charged.")
                    }
                }
            }
        }
    }
}

/// The plans side by side, shaded as every card is: the one you're on ringed in ink, with
/// "Current" in its corner; each with who it's for under its name, its price, what it includes,
/// and the one button that moves you to it (the prominent pill for a move up). Too narrow for
/// three across, they stack.
private struct PlanTiles: View {
    @Environment(CapturesModel.self) private var model

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) { tiles }
            VStack(spacing: 12) { tiles }
        }
    }

    @ViewBuilder private var tiles: some View {
        ForEach(Plan.allCases, id: \.self) { plan in
            PlanTile(plan: plan)
        }
    }
}

private struct PlanTile: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    let plan: Plan
    @State private var confirm = false

    var body: some View {
        let current = model.plan == plan
        let waiting = model.nextPlan == plan
        let yearly = model.yearlyBilling
        let price = plan.price(yearly: yearly)
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(plan.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(palette.text)
                Spacer()
                if current { Badge(text: "Current") } else if waiting { Badge(text: "From \(Lines.day(model.usage.resets))") }
            }
            // Who it's for, under its name.
            Text(plan.line)
                .font(.system(size: 12)).foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(price == 0 ? "$0" : "$\(price)").font(.system(size: 22, weight: .semibold)).foregroundStyle(palette.text)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(price == 0 ? "for good" : (yearly ? "a year" : "a month")).font(.system(size: 12)).foregroundStyle(palette.secondary)
            }
            .padding(.top, 12)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(plan.includes, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(palette.tertiary)
                        Text(item).font(.system(size: 12)).foregroundStyle(palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 12)
            Spacer(minLength: 16)
            action(current: current, waiting: waiting)
        }
        .padding(14)
        // Three across wherever 3 × 160 fits (each then takes its share); stacked where not.
        .frame(minWidth: 150, idealWidth: 160, maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
        .settingsSurface(shape)
        .overlay(shape.strokeBorder(current ? palette.ink(0.85) : .clear, lineWidth: 1.5))
        .confirmationDialog(confirmTitle, isPresented: $confirm) {
            Button(plan > model.plan ? "Upgrade to \(plan.title)" : "Switch on \(Lines.day(model.usage.resets))") { model.choose(plan) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmMessage)
        }
    }

    @ViewBuilder private func action(current: Bool, waiting: Bool) -> some View {
        if current {
            Text(model.nextPlan == nil ? "Your plan" : "Until \(Lines.day(model.usage.resets))")
                .font(.system(size: 12.5, weight: .medium)).foregroundStyle(palette.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
        } else if waiting {
            PillButton("Keep \(model.plan.title) instead", kind: .secondary) { model.choose(model.plan) }
                .frame(maxWidth: .infinity)
        } else if plan > model.plan {
            PillButton("Upgrade to \(plan.title)", kind: .prominent) { confirm = true }
                .frame(maxWidth: .infinity)
        } else {
            PillButton("Switch to \(plan.title)", kind: .secondary) { confirm = true }
                .frame(maxWidth: .infinity)
        }
    }

    private var confirmTitle: String {
        plan > model.plan ? "Upgrade to \(plan.title) now?" : "Switch to \(plan.title) on \(Lines.day(model.usage.resets))?"
    }

    private var confirmMessage: String {
        let price = plan.price(yearly: model.yearlyBilling)
        if plan > model.plan {
            return "\(plan.credits.formatted()) credits a month, from today. $\(price) \(model.yearlyBilling ? "a year" : "a month"). This is a prototype: nothing is charged."
        }
        return "You keep \(model.plan.title) until then. After that, \(plan.credits.formatted()) credits a month. You can change your mind until then."
    }
}

/// A word in a small pill, in the ink: "Current".
private struct Badge: View {
    @Environment(\.palette) private var palette
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(palette.isDark ? Color.black : Color.white)
            .padding(.horizontal, 7)
            .frame(height: 18)
            .background(Capsule().fill(palette.ink(0.85)))
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { y += line + spacing; x = 0; line = 0 }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            line = max(line, size.height)
        }
        return CGSize(width: min(width, widest), height: y + line)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX { y += line + spacing; x = bounds.minX; line = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            line = max(line, size.height)
        }
    }
}


// MARK: - Voice & Capture

struct VoicePane: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var confirmClear = false

    var body: some View {
        @Bindable var model = model
        SettingsSection("Voice") {
            SettingsCard {
                SettingsRow("Microphone") {
                    HStack(spacing: 10) {
                        LevelMeter()
                        InlinePicker(options: ["MacBook Air Microphone", "AirPods Pro", "Studio Display"],
                                     selection: $model.prefs.microphone, label: { $0 })
                    }
                }
                RowDivider()
                SettingsRow("Play sounds when listening starts and stops") {
                    InkToggle(title: "Play sounds", isOn: $model.prefs.sounds)
                }
            } footer: {
                // The language you speak moved to Language, with Fovea's and the notch's (row 6).
                Text("The language you speak is in Language.")
            }
        }

        // Screen awareness (Yulun, Oct 7): you choose, and can see, what dictation reads from your
        // screen. Item by item, as What a question can include (row 22).
        SettingsSection("Screen awareness", note: "What Fovea reads from your screen while you dictate. Never the whole screen, unless you take it.") {
            SettingsCard {
                SettingsRow("What you pick", detail: "Text you select, the regions and files you take.") {
                    StatusLabel(word: "Always")
                }
                RowDivider()
                SettingsRow("The window you're speaking into", detail: "Its app, its title, its web address, or the file it shows.") {
                    InkToggle(title: "The window you're speaking into", isOn: $model.prefs.dictationWindow.animation(model.motion.animation(.swap)))
                }
                if model.prefs.dictationWindow {
                    VStack(spacing: 0) {
                        RowDivider()
                        SettingsRow("The text in that window", detail: "A picture of the window, read on this Mac. Only its text goes with your words, to spell names and terms right.") {
                            InkToggle(title: "The text in that window", isOn: $model.prefs.dictationWindowText)
                        }
                    }
                    .transition(.opacity)
                }
            } footer: {
                Text("What a question can include is in Connectors.")
            }
        }
        .id("screen")

        SettingsSection("Capture") {
            SettingsCard {
                SettingsRow("Read the text in what you take", detail: "So you can search the words in a region you took.") {
                    InkToggle(title: "Read the text in what you take", isOn: $model.prefs.readText)
                }
                RowDivider()
                PrivacyRulesCard()
            }
        }
        .id("capture")

        SettingsSection("History") {
            SettingsCard {
                SettingsRow("Keep captures") {
                    InlinePicker(options: ["24 hours", "1 week", "1 month", "Forever"], selection: $model.prefs.keepCaptures, label: { $0 })
                }
                RowDivider()
                SettingsRow("Keep screenshots", detail: "When a screenshot goes, your words and the text read off it stay.") {
                    InlinePicker(options: ["30 days", "90 days", "180 days", "Forever"], selection: $model.prefs.keepScreenshots, label: { $0 })
                }
            } footer: {
                Text("Your captures, recordings and screenshots stay on this Mac.")
            }
        }

        SettingsSection("Permissions") {
            SettingsCard {
                SettingsRow("Microphone") { StatusLabel(word: "Allowed") }
                RowDivider()
                SettingsRow("Speech Recognition") { StatusLabel(word: "Allowed") }
                RowDivider()
                SettingsRow("Screen Recording", detail: model.prefs.dictationWindow && model.prefs.dictationWindowText
                            ? "To take regions and the whole screen, and to read the window you're speaking into."
                            : "To take regions and the whole screen.") { StatusLabel(word: "Allowed") }
            }
        }

        let n = model.library.captures.count
        DangerCard(title: "Clear history",
                   consequence: "Deletes all \(n.formatted()) captures and their screenshots from this Mac. This can't be undone.",
                   button: "Clear History…") { confirmClear = true }
            .confirmationDialog("Delete all \(n.formatted()) captures?", isPresented: $confirmClear) {
                Button("Delete \(n.formatted()) Captures", role: .destructive) { model.say("Would clear your history (simulated)") }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Every capture, its screenshots and its words leave this Mac. This can't be undone.")
            }
    }

    static func icon(_ name: String) -> NSImage? {
        let ids = ["1Password": "com.1password.1password", "Keychain Access": "com.apple.keychainaccess",
                   "Messages": "com.apple.MobileSMS", "Mail": "com.apple.mail"]
        guard let id = ids[name] else { return NSWorkspace.shared.icon(for: .application) }
        return Art.icon(AppRef(name, id))
    }
}

/// A small input meter, moving as a microphone would (simulated; still under Reduce Motion).
private struct LevelMeter: View {
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08, paused: motion.reduce)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    let v = motion.reduce ? 0.3 : 0.25 + 0.75 * abs(sin(t * (2.1 + Double(i) * 0.7) + Double(i)))
                    Capsule().fill(palette.text.opacity(0.55)).frame(width: 2.5, height: 4 + 10 * v)
                }
            }
            .frame(height: 14)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Shortcuts

struct ShortcutsPane: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    /// Read when the pane shows, and again each second it's open (a grant is seen live).
    @State private var granted: [Permission: Bool] = [:]
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        // Fovea's keys, from the one table every surface reads (FoveaKit's `FoveaKeys`): the
        // round the onboarding teaches and the notch acts on.
        SettingsSection(nil, note: "Press once to start, again to stop.") {
            HStack(alignment: .top, spacing: 12) {
                ForEach(FoveaKeys.daily) { key in
                    MainKey(title: key.title, detail: key.detail, keys: key.keys)
                }
            }
        }

        SettingsSection("While you speak") {
            SettingsCard {
                ForEach(Array(FoveaKeys.whileSpeaking.enumerated()), id: \.element.id) { i, key in
                    if i > 0 { RowDivider() }
                    SettingsRow(key.title, detail: key.detail) { FixedCaps(keys: key.keys, presses: key.presses) }
                }
            }
        }

        SettingsSection("In the notch", note: "The board opens when the pointer rests at the notch (Settings › Notch).") {
            SettingsCard {
                ForEach(Array(FoveaKeys.inTheNotch.enumerated()), id: \.element.id) { i, key in
                    if i > 0 { RowDivider() }
                    SettingsRow(key.title, detail: key.detail) { FixedCaps(keys: key.keys, presses: key.presses) }
                }
            }
        }

        SettingsSection("Permissions", note: "Fovea needs these for its keys in any app, to take what you point at, and to hear you.") {
            SettingsCard {
                let rows: [Permission] = [.accessibility, .screenRecording, .microphone, .speechRecognition]
                ForEach(Array(rows.enumerated()), id: \.element) { i, permission in
                    if i > 0 { RowDivider() }
                    SettingsRow(permission.paneName) {
                        if granted[permission] ?? permission.granted {
                            StatusLabel(word: "Allowed")
                        } else {
                            StatusLabel(word: "Not allowed", ok: false,
                                        fix: ("Open Privacy Settings…", { permission.openSettings() }))
                        }
                    }
                }
            }
        }
        .onAppear { refresh() }
        .onReceive(tick) { _ in refresh() }
    }

    private func refresh() {
        for p in Permission.allCases { granted[p] = p.granted }
    }
}

/// A shortcut's keys, as caps (they aren't changed in 1.0), "×2" for one pressed twice.
private struct FixedCaps: View {
    @Environment(\.palette) private var palette
    let keys: [String]
    var presses = 1

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.text)
                    .frame(minWidth: 22, minHeight: 22)
                    .padding(.horizontal, key.count > 1 ? 6 : 0)
                    .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(palette.ink(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(palette.ink(0.12), lineWidth: 0.5))
            }
            if presses > 1 {
                Text("×\(presses)").font(.system(size: 11, weight: .semibold)).foregroundStyle(palette.secondary)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(keys.joined(separator: " ") + (presses > 1 ? ", twice" : ""))
    }
}

/// One of the two keys you'll use every day, given room: its caps large, its name and a line.
private struct MainKey: View {
    @Environment(\.palette) private var palette
    let title: String
    let detail: String
    let keys: [String]
    var body: some View {
        // Concentric: the well inset 6 pt in a card rounded 14, so rounded 8.
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            KeyCaps(keys: keys, large: true)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(palette.ink(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.text)
                Text(detail).font(.system(size: 11.5)).foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsSurface(shape)
    }
}

// MARK: - Connectors

struct ConnectorsPane: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var checked = "Checked just now"

    var body: some View {
        @Bindable var model = model
        SettingsSection("Agents") {
            Button { model.say("Agents checked (simulated)") } label: {
                HStack(spacing: 4) {
                    Text(checked)
                    Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .semibold))
                }
                .font(.system(size: 12))
                .foregroundStyle(palette.secondary)
            }
            .buttonStyle(.plain)
            .help("Check again")
        } content: {
            SettingsCard {
                SettingsRow("Claude Code", detail: "Ready · 2.1", icon: Art.agentIcon("Claude Code"))
                RowDivider(inset: 56)
                SettingsRow("Codex", detail: "Ready · 0.47", icon: Art.agentIcon("Codex"))
                RowDivider(inset: 56)
                SettingsRow("Cursor", detail: "Not installed", icon: Art.agentIcon("Cursor")) {
                    TextButton("Get Cursor ↗") { model.say("Would open Cursor's site (simulated)") }
                }
            } footer: {
                Text("Dispatches go to these, through the copy already signed in on this Mac.")
            }
        }

        // Who answers, with which model; what a question may include (rows 21, 22).
        QuestionsSections()
            .id("questions")

        SettingsSection("What agents can read") {
            SettingsCard {
                SettingsRow("Claude Code", icon: Art.agentIcon("Claude Code")) { StatusLabel(word: "Can read") }
                RowDivider(inset: 56)
                SettingsRow("Codex", icon: Art.agentIcon("Codex")) {
                    TextButton("Add…") { model.say("Would add Fovea Memory to Codex (simulated)") }
                }
            } footer: {
                Text("Agents read your memories, except the ones you hide from them.")
                Spacer()
                TextButton("Access Log…") { model.accessLogShown = true }
            }
        }
    }
}

// MARK: - Eye Tracking

/// In beta, and honest about it (row 34): there's a model at work already; the way to try it is
/// to help collect the data that fits it to you.
struct EyeTrackingPane: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        SettingsSection(nil) {
            // Concentric: the picture inset 8 pt in a card rounded 20, so rounded 12.
            SettingsCard(radius: 20) {
                VStack(spacing: 14) {
                    GazeHero().frame(height: 196)
                        .padding(.horizontal, -8)
                        .padding(.top, -8)
                    VStack(spacing: 6) {
                        Text("Eye tracking is in beta")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(palette.text)
                        // Row 34: say there's a model at work already, and how to get to try it.
                        Text("Fovea already has a gaze model at work: look at something, say “this,” and it knows what you mean. To try it, spend ten minutes with the Gaze Collector; then it's yours, fitted to your eyes.")
                            .font(.system(size: 13))
                            .foregroundStyle(palette.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 400)
                    }
                }
                .cardPadding()
                .padding(.bottom, 8)
            }
        }

        SettingsSection("Try the beta", note: "The beta is open to people who help collect data. One session with the Gaze Collector fits the model to your eyes, and makes eye tracking better for everyone.") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 14) {
                    Step(number: 1, title: "Download the Gaze Collector", detail: "A small app, separate from Fovea.")
                    Step(number: 2, title: "Follow the dots", detail: "About ten minutes, at your desk, with the camera on.")
                    Step(number: 3, title: "Review, then send", detail: "Watch the recording first. Send it only if you want to.")
                    Step(number: 4, title: "Turn on eye tracking", detail: "Once your session is in, the switch below works, with a model fitted to you.")
                }
                .cardPadding()
                .frame(maxWidth: .infinity, alignment: .leading)
                RowDivider()
                CollectorDownload()
                    .cardPadding()
                    .frame(maxWidth: .infinity)
                RowDivider()
                SettingsRow("Eye tracking", detail: "Available after your first session.") {
                    InkToggle(title: "Eye tracking", isOn: .constant(false)).disabled(true)
                }
            }
        }
        .id("eye-beta")

        SettingsSection("What the Collector records") {
            SettingsCard {
                SettingsRow("Video of your eyes", detail: "Only while you follow the dots. The camera light stays on the whole time.")
                RowDivider()
                SettingsRow("Where each dot was", detail: "Its place on the screen and when it moved.")
                RowDivider()
                SettingsRow("Nothing leaves without you", detail: "Recordings stay on your Mac until you review them and choose to send.")
                RowDivider()
                SettingsRow("Yours to delete", detail: "Remove any recording from the Collector, anytime.")
            } footer: {
                Text("Thank you. Every session helps Fovea see a little better.")
            }
        }
    }
}

private struct Step: View {
    @Environment(\.palette) private var palette
    let number: Int
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(verbatim: "\(number)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.text)
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(palette.tertiary, lineWidth: 0.75))
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 5 }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(palette.text)
                Text(detail).font(.system(size: 11.5)).foregroundStyle(palette.secondary)
            }
        }
    }
}

/// Download, then its progress, then Open, in place (the download is simulated: nothing is
/// fetched).
private struct CollectorDownload: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    var body: some View {
        ZStack {
            switch model.prefs.gaze {
            case .idle:
                VStack(spacing: 6) {
                    PillButton("Download Gaze Collector", symbol: "arrow.down", kind: .prominent, large: true) {
                        model.downloadCollector()
                    }
                    Text("38 MB · macOS 14 or later").font(.system(size: 11.5)).foregroundStyle(palette.secondary)
                }
                .transition(.blockSwap)
            case .downloading(let p):
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(palette.text.opacity(0.08))
                            Capsule().fill(palette.text.opacity(0.85)).frame(width: max(4, geo.size.width * p))
                        }
                    }
                    .frame(width: 240, height: 4)
                    HStack(spacing: 10) {
                        Text("Downloading… \(Int((p * 38).rounded())) of 38 MB").monospacedDigit()
                        TextButton("Cancel") { model.cancelCollector() }
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.secondary)
                }
                .transition(.blockSwap)
            case .downloaded:
                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        PillButton("Open Gaze Collector", symbol: "eye", kind: .prominent, large: true) {
                            model.say("Would open the Gaze Collector (simulated)")
                        }
                        TextButton("Show in Finder") { model.say("Would show it in Downloads (simulated)") }
                    }
                    StatusLabel(word: "In your Downloads folder")
                }
                .transition(.blockSwap)
            }
        }
        .frame(minHeight: 56)
    }
}

private struct GazeHero: View {
    @Environment(CapturesModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.motion) private var motion
    @State private var focus = 1
    @State private var trail: [Int] = []
    @State private var resting = true

    private let screen = CGSize(width: 340, height: 178)
    /// The three windows on the screen, and where on each the eyes land.
    private let windows: [CGRect] = [
        CGRect(x: 14, y: 22, width: 150, height: 82),
        CGRect(x: 176, y: 22, width: 150, height: 82),
        CGRect(x: 14, y: 114, width: 312, height: 50),
    ]
    private let gazes: [CGPoint] = [CGPoint(x: 96, y: 58), CGPoint(x: 236, y: 66), CGPoint(x: 150, y: 140)]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.mark.opacity(palette.isDark ? 0.10 : 0.16))
            screenView
        }
        .task(id: motion.reduce) { await run() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Coming soon: look at something on screen and say “this.”")
    }

    private var screenView: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 9, style: .continuous).fill(palette.card)
            // The menu bar, with the notch where Fovea lives.
            Rectangle().fill(palette.text.opacity(0.04)).frame(height: 12)
            IslandShape(topRadius: 3, bottomRadius: 5)
                .fill(Color.black)
                .frame(width: 52, height: 12)
                .offset(x: (screen.width - 52) / 2)
            chart.frame(width: windows[0].width, height: windows[0].height).offset(x: windows[0].minX, y: windows[0].minY)
            paragraph.frame(width: windows[1].width, height: windows[1].height).offset(x: windows[1].minX, y: windows[1].minY)
            code.frame(width: windows[2].width, height: windows[2].height).offset(x: windows[2].minX, y: windows[2].minY)
            ForEach(Array(windows.enumerated()), id: \.offset) { i, w in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(palette.text, lineWidth: 1.5)
                    .frame(width: w.width + 4, height: w.height + 4)
                    .offset(x: w.minX - 2, y: w.minY - 2)
                    .opacity(focus == i && resting ? 1 : 0)
                    .animation(motion.animation(.hover), value: focus == i && resting)
            }
            ForEach(Array(trail.enumerated()), id: \.offset) { n, i in
                Circle().fill(palette.text)
                    .frame(width: 5, height: 5)
                    .opacity([0.35, 0.18, 0.08][min(n, 2)])
                    .offset(x: gazes[i].x - 2.5, y: gazes[i].y - 2.5)
            }
            gaze.offset(x: gazes[focus].x - 18, y: gazes[focus].y - 18)
            Text("this")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(palette.onMark)
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Capsule().fill(palette.mark))
                .scaleEffect(resting ? 1 : 0.9, anchor: .bottomLeading)
                .opacity(resting ? 1 : 0)
                .offset(x: gazes[focus].x + 12, y: gazes[focus].y - 26)
        }
        .frame(width: screen.width, height: screen.height)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(palette.hairline, lineWidth: 1))
        .shadow(color: .black.opacity(palette.isDark ? 0.4 : 0.1), radius: 8, y: 3)
    }

    private var gaze: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [palette.mark.opacity(0.7), palette.mark.opacity(0)],
                                         center: .center, startRadius: 2, endRadius: 18))
            Circle().fill(palette.text).frame(width: 8, height: 8)
            Circle().strokeBorder(Color.white, lineWidth: 1.5).frame(width: 8, height: 8)
        }
        .frame(width: 36, height: 36)
    }

    private var windowFill: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous).fill(palette.text.opacity(0.035))
    }

    private var chart: some View {
        HStack(alignment: .bottom, spacing: 7) {
            ForEach([0.45, 0.7, 0.55, 0.9, 0.62, 0.8], id: \.self) { h in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(palette.text.opacity(0.28))
                    .frame(width: 14, height: 56 * h)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(12)
        .background(windowFill)
    }

    private var paragraph: some View {
        VStack(alignment: .leading, spacing: 7) {
            Capsule().fill(palette.text.opacity(0.5)).frame(width: 70, height: 6)
            ForEach([118.0, 104, 122, 84], id: \.self) { w in
                Capsule().fill(palette.text.opacity(0.16)).frame(width: w, height: 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(windowFill)
    }

    private var code: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array([[(0.0, 34.0, Color.purple), (40, 56, Color.blue)],
                           [(14, 48, Color.pink), (68, 90, Color.gray)],
                           [(14, 30, Color.orange), (50, 120, Color.gray)]].enumerated()), id: \.offset) { _, line in
                ZStack(alignment: .leading) {
                    ForEach(Array(line.enumerated()), id: \.offset) { _, token in
                        Capsule().fill(token.2.opacity(0.4)).frame(width: token.1, height: 5).offset(x: token.0)
                    }
                }
                .frame(height: 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(windowFill)
    }

    /// A rest of about a second and a half, the "this" fading, a quick jump to the next window,
    /// "this" again: the rhythm of reading a screen.
    private func run() async {
        if motion.reduce {
            focus = 1; resting = true; trail = []
            return
        }
        while !Task.isCancelled {
            withAnimation(motion.animation(.content)) { resting = true }
            try? await Task.sleep(for: .seconds(motion.seconds(1.5)))
            guard !Task.isCancelled else { return }
            withAnimation(motion.animation(.press)) { resting = false }
            try? await Task.sleep(for: .seconds(motion.seconds(0.1)))
            trail = Array(([focus] + trail).prefix(3))
            withAnimation(.spring(duration: motion.seconds(0.32), bounce: 0.06)) { focus = (focus + 1) % gazes.count }
            try? await Task.sleep(for: .seconds(motion.seconds(0.28)))
        }
    }
}


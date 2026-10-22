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
                .transition(.identity)
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
            model.animate(.fadeIn) { model.settingsPane = pane }
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
        Text(L(key: text))
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(palette.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .overlay(Capsule().strokeBorder(palette.tertiary, lineWidth: 0.5))
    }
}

// Oct 15 review: Voice & Capture, Shortcuts, Connectors and Eye Tracking are in their own files now
// (VoiceCaptureSettings.swift, ShortcutRecorder.swift, AgentStatus.swift, EyeTrackingSettings.swift).

/// Settings' values for the prototype (in memory; nothing here reaches the system).
struct Prefs {
    /// The Gaze Collector's steps (Oct 15 review, ST-08: following the dots, reviewing, sending,
    /// then collected, when eye tracking's controls appear). Simulated.
    enum Gaze: Equatable { case idle, downloading(Double), downloaded, collecting(Double), reviewing, sending(Double), collected }

    var openAtLogin = true
    var showInDock = true
    var betaUpdates = true
    var keepCaptures = "Forever"
    var keepScreenshots = "90 days"
    var remember = true
    var rememberNotice = true
    var microphone = "MacBook Air Microphone"
    /// Oct 18, Ryan: the languages the person speaks (FoveaPrefs.languages), and the primary of
    /// them (FoveaPrefs.language): Fovea's interface, the notch and speech recognition use it.
    var languages: [FoveaLanguage] = [.english]
    var appLanguage: FoveaLanguage = .english
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
    // Oct 15 review: Voice & Capture's Tidy my words (ST-04.2), Appearance's Motion (IS02) and the
    // recorded shortcuts (ST-03.1), mirrored to FoveaPrefs by the window's controller.
    var tidyWords = true
    var motion: MotionPreference = .system
    var shortcutChords: [String: KeyChord] = [:]
    /// Oct 17, Ryan (FR-06): the languages asked for under the first run's More…, and here
    /// (FoveaPrefs.requestedLanguages, mirrored by the window's controller).
    var requestedLanguages: [String] = []

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
/// what it knows of you, and how it runs on this Mac. Oct 15 review, MW-04c: the version, updates,
/// beta, help and the links moved to Settings › About; RC-02: earlier data, while there is some.
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

        // Oct 15 review, RC-02.1: captures from an earlier version or account, only while there are.
        EarlierDataSection()

        // "On this Mac" is also the first run's word for an agent already installed: a key of its own.
        SettingsSection(L("On this Mac (settings)", english: "On this Mac")) {
            SettingsCard {
                // Light, Dark, or as the Mac is set: here on the tabs; the sidebar layouts give it
                // Settings › Appearance, with the theme and the accent.
                if !native {
                    SettingsRow("Appearance") {
                        Picker("Appearance", selection: $model.appearance) {
                            ForEach([Appearance.light, .dark, .system], id: \.self) { Text(L(key: $0.title)).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                    RowDivider()
                }
                SettingsRow("Open at login") { InkToggle(title: "Open at login", isOn: $model.prefs.openAtLogin) }
                RowDivider()
                // Oct 15 review, ST-02.5: for real (the app follows prefs.showInDock).
                SettingsRow("Show in Dock", detail: "Off, Fovea stays in the menu bar. Open this window from its icon there.") {
                    InkToggle(title: "Show in Dock", isOn: $model.prefs.showInDock)
                }
            }
        }
        .id("account-mac")
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
        // Oct 15 review, AC-02.1 and MW-04d: the trial, its end, a subscription ending or expired,
        // a payment that failed, the billing page that didn't open.
        PlanStatusSection()

        SettingsSection("This month") {
            PlanUsageCard()
        }

        SettingsSection("Plans") {
            SettingsSegments(segments: [(false, "Monthly"), (true, "Yearly")], selection: model.yearlyBilling) { yearly in
                model.yearlyBilling = yearly
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
                    // Oct 15 review, AC-02.1 and MW-04d: a trial has no bill yet; a cancelled
                    // subscription doesn't renew.
                    // Oct 18, Ryan: in the primary language, a whole sentence for a year and for a month.
                    if model.planAlert == .trial {
                        SettingsRow(L("Trial ends \(Lines.day(model.trialEnds))"),
                                    detail: model.yearlyBilling ? L("Nothing to pay until you choose a plan. Then $\(price) a year.")
                                                                : L("Nothing to pay until you choose a plan. Then $\(price) a month."))
                    } else if model.planAlert == .subscriptionEnding {
                        SettingsRow(L("\(model.plan.title) ends \(Lines.day(usage.resets))"),
                                    detail: "Cancelled: it won't renew. Renew on hellofovea.com to keep it.")
                    } else if let next = model.nextPlan {
                        SettingsRow(L("\(model.plan.title) ends \(Lines.day(usage.resets))"),
                                    detail: L("Then \(next.title): \(next.credits.formatted()) credits a month. Until then nothing changes.")) {
                            TextButton(L("Keep \(model.plan.title)")) { model.choose(model.plan) }
                        }
                    } else {
                        SettingsRow(L("Renews \(Lines.day(usage.resets))"),
                                    detail: model.yearlyBilling ? L("$\(price) a year. Simulated: nothing is charged.")
                                                                : L("$\(price) a month. Simulated: nothing is charged."))
                    }
                }
                RowDivider()
                // Cancelling or keeping the subscription happens on the website (Oct 13).
                SettingsRow("Your subscription", detail: "Cancel it, keep it or change it on hellofovea.com.") {
                    // Oct 15 review, MW-04d: a page that won't open says so (Plan's Try Again).
                    Button("Manage on the Website ↗") { model.openBilling() }
                        .buttonStyle(.link)
                }
            }
        }
    }
}

/// The plans side by side, shaded as every card is: each with who it's for under its name, its
/// price, what it includes, and the one button that moves you to it (the prominent pill for a
/// move up); the one you're on says "Your plan" where its button would be. Oct 21, Ryan ("simpler
/// is better"): said once (it was also ringed in ink, with "Current" in its corner). Too narrow
/// for three across, they stack.
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
                if waiting { Badge(text: L("From \(Lines.day(model.usage.resets))")) }
            }
            // Who it's for, under its name.
            Text(plan.line)
                .font(.system(size: 12)).foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(verbatim: "$\(price)").font(.system(size: 22, weight: .semibold)).foregroundStyle(palette.text)
                    .monospacedDigit()
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
            PillButton(L("Keep \(model.plan.title) instead"), kind: .secondary) { model.choose(model.plan) }
                .frame(maxWidth: .infinity)
        } else if plan > model.plan {
            PillButton(L("Upgrade to \(plan.title)"), kind: .prominent) { confirm = true }
                .frame(maxWidth: .infinity)
        } else {
            PillButton(L("Switch to \(plan.title)"), kind: .secondary) { confirm = true }
                .frame(maxWidth: .infinity)
        }
    }

    // Oct 18, Ryan: in the primary language.
    private var confirmTitle: String {
        plan > model.plan ? L("Upgrade to \(plan.title) now?") : L("Switch to \(plan.title) on \(Lines.day(model.usage.resets))?")
    }

    private var confirmMessage: String {
        let price = plan.price(yearly: model.yearlyBilling)
        let credits = plan.credits.formatted()
        if plan > model.plan {
            return model.yearlyBilling
                ? L("\(credits) credits a month, from today. $\(price) a year. This is a prototype: nothing is charged.")
                : L("\(credits) credits a month, from today. $\(price) a month. This is a prototype: nothing is charged.")
        }
        return L("You keep \(model.plan.title) until then. After that, \(credits) credits a month. You can change your mind until then.")
    }
}

/// A word in a small pill, in the ink: "From Nov 1".
private struct Badge: View {
    @Environment(\.palette) private var palette
    let text: String
    var body: some View {
        Text(L(key: text))
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




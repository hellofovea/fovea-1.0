import AppKit
import SwiftUI
import CapturesCore

/// Renders every state to `window-<name>.png` (2×), Light and Dark where it matters; `frames`
/// records the expanded card opening and closing, slowed tenfold, one PNG every 120 ms.
@MainActor
enum Snapshots {
    struct Shot {
        var name: String
        var dark = false
        /// The window's content size, when the shot checks another width.
        var size: CGSize?
        /// A view id to scroll to before the shot (the calendar under the week).
        var scrollTo: String?
        var setup: (CapturesModel) -> Void = { _ in }
    }

    static func open(_ m: CapturesModel, _ id: String) {
        m.detailID = id; m.detailSourceID = id; m.detailProgress = 1; m.detailClosing = false
    }

    static var shots: [Shot] {
        var list: [Shot] = []
        // The earlier rounds' shots: the cards layout.
        let reset: (CapturesModel) -> Void = { m in
            m.layout = .cards
            m.page = .captures; m.detailID = nil; m.detailSourceID = nil; m.detailProgress = 0; m.query = CaptureQuery(); m.archiveDay = nil
        }
        // The library (Aside's layout), the default.
        let lib: (CapturesModel) -> Void = { m in
            m.layout = .library
            m.page = .captures; m.noteID = nil; m.query = CaptureQuery(); m.archiveDay = nil
        }
        let note = { (m: CapturesModel, id: String) in lib(m); m.noteID = id; m.selectedID = id; m.listScrollTarget = id }
        let day = { (m: CapturesModel, d: Int) in Lines.calendar.date(byAdding: .day, value: -d, to: Lines.calendar.startOfDay(for: m.now))! }
        // The library (the Aside layout study, kept in code).
        list.append(Shot(name: "lib-home", setup: lib))
        list.append(Shot(name: "lib-note") { m in note(m, "x-ears") })
        list.append(Shot(name: "lib-settings-dark", dark: true) { m in lib(m); m.settingsLayout = .tabs; m.page = .settings; m.settingsPane = .account })
        // The page as it was (filling the window), against the inset page now the default.
        for dark in [false, true] {
            let d = dark ? "-dark" : ""
            list.append(Shot(name: "page-full\(d)", dark: dark) { m in reset(m); m.pageStyle = .full })
            list.append(Shot(name: "page-solid\(d)", dark: dark) { m in reset(m); m.windowMaterial = .solid })
        }
        list.append(Shot(name: "page-no-liquid-glass") { m in reset(m); m.liquidGlass = false; open(m, "x-ears") })
        for dark in [false, true] {
            let d = dark ? "-dark" : ""
            list.append(Shot(name: "grid\(d)", dark: dark, setup: reset))
            list.append(Shot(name: "detail-dispatch\(d)", dark: dark) { m in reset(m); open(m, "x-ears") })
            list.append(Shot(name: "detail-dictation\(d)", dark: dark) { m in reset(m); open(m, "d-mail-lin") })
            list.append(Shot(name: "settings-account\(d)", dark: dark) { m in reset(m); m.settingsLayout = .tabs; m.page = .settings; m.settingsPane = .account })
            list.append(Shot(name: "settings-eyeTracking\(d)", dark: dark) { m in reset(m); m.settingsLayout = .tabs; m.page = .settings; m.settingsPane = .eyeTracking })
        }
        // History: the first page's calendar, three ways, and a day's archive.
        list.append(Shot(name: "history-graph", scrollTo: "earlier") { m in reset(m); m.historyStyle = .yearGraph })
        list.append(Shot(name: "history-graph-top") { m in reset(m) })
        list.append(Shot(name: "history-months", scrollTo: "earlier") { m in reset(m); m.historyStyle = .months })
        list.append(Shot(name: "history-timeline") { m in reset(m); m.historyStyle = .timeline })
        list.append(Shot(name: "history-day") { m in reset(m); m.archiveDay = m.busiestDay(daysAgo: 7...30); m.page = .day })
        list.append(Shot(name: "history-day-old") { m in reset(m); m.archiveDay = m.busiestDay(daysAgo: 290...310); m.page = .day })
        list.append(Shot(name: "history-day-empty") { m in reset(m); m.archiveDay = day(m, 175); m.page = .day })
        list.append(Shot(name: "history-inline", scrollTo: "earlier") { m in reset(m); m.archiveStyle = .inline; m.archiveDay = m.busiestDay(daysAgo: 7...30) })
        list.append(Shot(name: "history-graph-dark", dark: true, scrollTo: "earlier") { m in reset(m) })
        list.append(Shot(name: "history-graph-dispatch", scrollTo: "earlier") { m in reset(m); m.query.kind = .dispatch })
        list.append(Shot(name: "detail-capture") { m in reset(m); open(m, "c-review-slot") })
        list.append(Shot(name: "detail-files") { m in reset(m); open(m, "x-downloads") })
        list.append(Shot(name: "detail-passage") { m in reset(m); open(m, "x-crash") })
        list.append(Shot(name: "detail-chinese") { m in reset(m); open(m, "x-why-bullets") })
        list.append(Shot(name: "detail-page") { m in reset(m); m.detailStyle = .page; open(m, "x-ears") })
        list.append(Shot(name: "detail-icon") { m in reset(m); m.detailIcon = true; open(m, "x-ears") })
        list.append(Shot(name: "detail-search") { m in reset(m); m.query.text = "ears"; open(m, "x-ears") })
        // The App UI review (Oct 6): the window's additions.
        list.append(Shot(name: "fb-grid", setup: reset))
        list.append(Shot(name: "fb-detail-dictation") { m in reset(m); open(m, "c-mail-429") })
        list.append(Shot(name: "fb-detail-dispatch") { m in reset(m); open(m, "x-ears") })
        list.append(Shot(name: "fb-detail-failed") { m in reset(m); open(m, "d-failed-notes") })
        list.append(Shot(name: "fb-detail-failed-dark", dark: true) { m in reset(m); open(m, "d-failed-notes") })
        list.append(Shot(name: "fb-tag") { m in reset(m); m.query.tag = "Greek mythology" })
        list.append(Shot(name: "fb-site") { m in reset(m); m.query.app = "Chrome · chatgpt.com" })
        list.append(Shot(name: "fb-viewer") { m in reset(m); open(m, "x-ears"); m.viewing = Viewing(capture: "x-ears", index: 2) })
        // The App UI review's Settings (rows 6–34) and its fifteen states (row 13), in the
        // sidebar's one-section-at-a-time Settings, as they ship.
        let set = { (m: CapturesModel, c: SettingsCategory) in
            reset(m); m.page = .settings; m.settingsLayout = .sidebarPanes; m.settingsCategory = c; m.settingsPane = c.pane
        }
        for dark in [false, true] {
            let d = dark ? "-dark" : ""
            list.append(Shot(name: "fb-set-account\(d)", dark: dark) { m in set(m, .account) })
            list.append(Shot(name: "fb-set-language\(d)", dark: dark) { m in set(m, .language) })
            list.append(Shot(name: "fb-set-memory\(d)", dark: dark, scrollTo: "memory-about") { m in set(m, .memory) })
        }
        list.append(Shot(name: "fb-set-account-mac", scrollTo: "account-mac") { m in set(m, .account) })
        list.append(Shot(name: "fb-set-photo-too-large") { m in set(m, .account); m.photoTooLarge = true })
        list.append(Shot(name: "fb-set-update-checking", scrollTo: "account-mac") { m in set(m, .account); m.update = .checking })
        list.append(Shot(name: "fb-set-update-failed", scrollTo: "account-mac") { m in set(m, .account); m.update = .failed })
        list.append(Shot(name: "fb-set-update-available", scrollTo: "account-mac") { m in set(m, .account); m.update = .available("0.6 beta 1") })
        list.append(Shot(name: "fb-set-plan-almost") { m in set(m, .plan); m.planAlert = .almostOut })
        list.append(Shot(name: "fb-set-plan-used-up") { m in set(m, .plan); m.planAlert = .usedUp })
        list.append(Shot(name: "fb-set-plan-payment") { m in set(m, .plan); m.planAlert = .paymentProcessing; m.plan = .free })
        list.append(Shot(name: "fb-set-voice") { m in set(m, .voice) })
        list.append(Shot(name: "fb-set-voice-privacy", scrollTo: "capture") { m in set(m, .voice) })
        list.append(Shot(name: "fb-set-voice-screen", scrollTo: "screen") { m in set(m, .voice) })
        list.append(Shot(name: "fb-set-voice-screen-off", scrollTo: "screen") { m in set(m, .voice); m.prefs.dictationWindow = false })
        list.append(Shot(name: "fb-set-dictionary") { m in set(m, .memory) })
        list.append(Shot(name: "fb-set-dictionary-learned") { m in set(m, .memory); m.dictionaryTab = .learned })
        list.append(Shot(name: "fb-set-dictionary-empty") { m in set(m, .memory); m.library.dictionary = [] })
        list.append(Shot(name: "fb-set-dictionary-signed-out") { m in set(m, .memory); m.signedOut = true })
        list.append(Shot(name: "fb-set-memory-remembering", scrollTo: "memory-remembering") { m in set(m, .memory) })
        list.append(Shot(name: "fb-set-memory-link-off", scrollTo: "memory-about") { m in set(m, .memory); m.prefs.memoryLink = false })
        list.append(Shot(name: "fb-set-memory-loading", scrollTo: "memory-about") { m in set(m, .memory); m.memoryState = .loading })
        list.append(Shot(name: "fb-set-memory-failed", scrollTo: "memory-about") { m in set(m, .memory); m.memoryState = .failed })
        list.append(Shot(name: "fb-set-memory-empty", scrollTo: "memory-about") { m in set(m, .memory); m.library.memories = []; m.library.areas = [] })
        list.append(Shot(name: "fb-set-connectors", scrollTo: "questions") { m in set(m, .connectors) })
        list.append(Shot(name: "fb-set-connectors-claude", scrollTo: "questions") { m in set(m, .connectors); m.prefs.answerWith = "Claude Code" })
        list.append(Shot(name: "fb-set-eye") { m in set(m, .eyeTracking) })
        list.append(Shot(name: "fb-set-eye-steps", scrollTo: "eye-beta") { m in set(m, .eyeTracking) })
        for error in WindowError.allCases {
            list.append(Shot(name: "fb-window-\(error.rawValue)") { m in reset(m); m.windowError = error })
        }
        list.append(Shot(name: "fb-window-storage-dark", dark: true) { m in reset(m); m.windowError = .storage })
        // Sheets are windows of their own: taken with the window under them.
        list.append(Shot(name: "fb-sheet-report") { m in set(m, .account); m.reporting = true })
        list.append(Shot(name: "fb-sheet-memories") { m in set(m, .memory); m.browsingMemories = true; m.memorySelection = ["m-circe"] })
        list.append(Shot(name: "fb-sheet-memories-dark", dark: true) { m in set(m, .memory); m.browsingMemories = true; m.memorySelection = ["m-circe"] })
        list.append(Shot(name: "fb-sheet-memories-several") { m in set(m, .memory); m.browsingMemories = true; m.memorySelection = ["m-circe", "m-wilson", "m-persephone"] })
        list.append(Shot(name: "fb-sheet-memories-deleted") { m in set(m, .memory); m.browsingMemories = true; m.memoryFilter = .deleted })
        list.append(Shot(name: "fb-sheet-access-log") { m in set(m, .memory); m.accessLogShown = true })
        list.append(Shot(name: "usage-popover-used-up") { m in reset(m); m.planAlert = .usedUp })
        list.append(Shot(name: "usage-popover-almost-out", dark: true) { m in reset(m); m.planAlert = .almostOut })
        list.append(Shot(name: "kind-dictation") { m in reset(m); m.query.kind = .dictation })
        list.append(Shot(name: "kind-dispatch") { m in reset(m); m.query.kind = .dispatch })
        list.append(Shot(name: "search-lin") { m in reset(m); m.query.text = "lin" })
        list.append(Shot(name: "search-took") { m in reset(m); m.query.text = "account" })
        list.append(Shot(name: "search-weight") { m in reset(m); m.hitStyle = .weight; m.query.text = "lin" })
        list.append(Shot(name: "filter") { m in reset(m); m.query = CaptureQuery(app: "Slack", date: .week) })
        list.append(Shot(name: "search-none") { m in reset(m); m.query.text = "kubernetes" })
        list.append(Shot(name: "search-open") { m in reset(m); m.searchRequest += 1 })
        list.append(Shot(name: "filter-claude") { m in reset(m); m.query = CaptureQuery(app: "Claude Code") })
        list.append(Shot(name: "hover") { m in reset(m); m.hoverKey = "x-why-bullets" })
        list.append(Shot(name: "selected") { m in reset(m); m.selectedID = "x-ears" })
        // The cards' period, and the calendar's years.
        list.append(Shot(name: "scope-today") { m in reset(m); m.query.date = .today })
        list.append(Shot(name: "scope-week") { m in reset(m); m.query.date = .week })
        list.append(Shot(name: "calendar-2026", scrollTo: "earlier") { m in reset(m) })
        list.append(Shot(name: "calendar-2025", scrollTo: "earlier") { m in reset(m); m.calendarYear = 2025 })
        list.append(Shot(name: "calendar-2024", scrollTo: "earlier") { m in reset(m); m.calendarYear = 2024 })
        list.append(Shot(name: "calendar-2025-dark", dark: true, scrollTo: "earlier") { m in reset(m); m.calendarYear = 2025 })
        list.append(Shot(name: "calendar-months-2025", scrollTo: "earlier") { m in reset(m); m.historyStyle = .months; m.calendarYear = 2025 })
        list.append(Shot(name: "calendar-search", scrollTo: "earlier") { m in reset(m); m.query.text = "waitlist" })
        // Your plan.
        list.append(Shot(name: "plan") { m in reset(m); m.settingsLayout = .tabs; m.page = .settings; m.settingsPane = .plan })
        list.append(Shot(name: "plan-dark", dark: true) { m in reset(m); m.settingsLayout = .tabs; m.page = .settings; m.settingsPane = .plan })
        list.append(Shot(name: "plan-yearly") { m in reset(m); m.settingsLayout = .tabs; m.page = .settings; m.settingsPane = .plan; m.yearlyBilling = true })
        list.append(Shot(name: "plan-moving-down") { m in reset(m); m.settingsLayout = .tabs; m.page = .settings; m.settingsPane = .plan; m.nextPlan = .free })
        list.append(Shot(name: "plan-max") { m in reset(m); m.settingsLayout = .tabs; m.page = .settings; m.settingsPane = .plan; m.plan = .max })
        list.append(Shot(name: "plan-beside") { m in reset(m); m.settingsLayout = .tabs; m.page = .settings; m.settingsPane = .plan; m.settingsArrangement = .beside })
        // The cards' spacing, against the current, on the week and on a day.
        for spacing in CardSpacing.allCases where spacing != .quiet {
            list.append(Shot(name: "spacing-\(spacing.rawValue)") { m in reset(m); m.cardSpacing = spacing })
            list.append(Shot(name: "spacing-\(spacing.rawValue)-day") { m in
                reset(m); m.cardSpacing = spacing; m.archiveDay = m.busiestDay(daysAgo: 7...30); m.page = .day
            })
        }
        list.append(Shot(name: "spacing-quiet-day") { m in reset(m); m.archiveDay = m.busiestDay(daysAgo: 7...30); m.page = .day })
        list.append(Shot(name: "spacing-little-dark", dark: true) { m in reset(m); m.cardSpacing = .little })
        list.append(Shot(name: "header-type") { m in reset(m); m.headerStyle = .type })
        list.append(Shot(name: "header-theme") { m in reset(m); m.headerStyle = .theme })
        list.append(Shot(name: "header-theme-type") { m in reset(m); m.headerStyle = .themeAndType })
        list.append(Shot(name: "icon-corner") { m in reset(m); m.iconStyle = .corner })
        list.append(Shot(name: "icon-leading") { m in reset(m); m.iconStyle = .leading })
        list.append(Shot(name: "chips-only") { m in reset(m); m.cardAttachments = .inlineOnly })
        list.append(Shot(name: "cards-small") { m in reset(m); m.cardSize = .small })
        list.append(Shot(name: "cards-large") { m in reset(m); m.cardSize = .large })
        list.append(Shot(name: "long-text") { m in reset(m); m.load(.longText) })
        list.append(Shot(name: "empty") { m in reset(m); m.load(.empty) })
        list.append(Shot(name: "toast-deleted") { m in reset(m); m.delete("x-spring") })
        list.append(Shot(name: "account-learned") { m in reset(m); m.settingsLayout = .tabs; m.page = .settings; m.settingsPane = .account; m.dictionaryTab = .learned })
        list.append(Shot(name: "account-forgotten") { m in reset(m); m.settingsLayout = .tabs; m.page = .settings; m.settingsPane = .account; m.forget("m-claude") })
        list.append(Shot(name: "eye-downloading") { m in reset(m); m.settingsLayout = .tabs; m.page = .settings; m.settingsPane = .eyeTracking; m.prefs.gaze = .downloading(0.42) })
        list.append(Shot(name: "eye-downloaded") { m in reset(m); m.settingsLayout = .tabs; m.page = .settings; m.settingsPane = .eyeTracking; m.prefs.gaze = .downloaded })
        for pane in SettingsPane.allCases where pane != .account && pane != .eyeTracking {
            list.append(Shot(name: "settings-\(pane.rawValue)") { m in reset(m); m.settingsLayout = .tabs; m.page = .settings; m.settingsPane = pane })
        }
        list.append(Shot(name: "settings-onepage") { m in reset(m); m.settingsLayout = .onePage; m.page = .settings })
        // Settings' width: the other arrangements, on the panes with the most in them.
        for arrangement in [SettingsArrangement.wide, .beside, .twoColumns] {
            for pane in [SettingsPane.account, .voice, .shortcuts, .connectors] {
                list.append(Shot(name: "arrange-\(arrangement.rawValue)-\(pane.rawValue)") { m in
                    reset(m); m.settingsArrangement = arrangement; m.settingsLayout = .tabs; m.page = .settings; m.settingsPane = pane
                })
            }
        }
        list.append(Shot(name: "arrange-beside-account-dark", dark: true) { m in
            reset(m); m.settingsArrangement = .beside; m.settingsLayout = .tabs; m.page = .settings; m.settingsPane = .account
        })
        // The window has one size now (`T.Layout.window`): no width shots.
        // Settings as the Mac's own: the sidebar, everything on one page (the default now).
        let native = { (m: CapturesModel, c: SettingsCategory) in
            reset(m); m.page = .settings; m.settingsCategory = c; m.settingsScroll = (c, 1)
        }
        for dark in [false, true] {
            let d = dark ? "-dark" : ""
            list.append(Shot(name: "native-account\(d)", dark: dark) { m in native(m, .account) })
            list.append(Shot(name: "native-voice\(d)", dark: dark) { m in native(m, .voice) })
        }
        for c in [SettingsCategory.plan, .memory, .shortcuts, .connectors, .eyeTracking] {
            list.append(Shot(name: "native-\(c.rawValue)") { m in native(m, c) })
        }
        list.append(Shot(name: "native-panes-connectors") { m in native(m, .connectors); m.settingsLayout = .sidebarPanes })
        // October: one section at a time (the default), Appearance and Notch, a chosen accent.
        for dark in [false, true] {
            let d = dark ? "-dark" : ""
            list.append(Shot(name: "native-appearance\(d)", dark: dark) { m in native(m, .appearance) })
            list.append(Shot(name: "native-notch\(d)", dark: dark) { m in native(m, .notch) })
        }
        list.append(Shot(name: "native-notch-hover-off", scrollTo: "notch-board") { m in native(m, .notch); m.prefs.hoverOpens = false; m.prefs.reviewFirst = false })
        // The glow's color board: a template as it comes, turned, Custom, and Mono (what it can't change says why).
        list.append(Shot(name: "native-notch-glow", scrollTo: "notch-glow") { m in native(m, .notch) })
        list.append(Shot(name: "native-notch-glow-turned", scrollTo: "notch-glow") { m in native(m, .notch); m.prefs.glow = .sunset; m.prefs.glowHue = 120 })
        list.append(Shot(name: "native-notch-glow-custom", scrollTo: "notch-glow") { m in native(m, .notch); m.prefs.glow = .custom; m.prefs.glowHue = 200; m.prefs.glowSpread = 90 })
        list.append(Shot(name: "native-notch-glow-custom-dark", dark: true, scrollTo: "notch-glow") { m in native(m, .notch); m.prefs.glow = .custom; m.prefs.glowHue = 200; m.prefs.glowSpread = 90 })
        list.append(Shot(name: "native-notch-glow-mono", scrollTo: "notch-glow") { m in native(m, .notch); m.prefs.glow = .mono })
        list.append(Shot(name: "native-appearance-pink") { m in native(m, .appearance); m.accent = .pink })
        list.append(Shot(name: "usage-popover-pink", dark: true) { m in lib(m); m.accent = .pink })
        list.append(Shot(name: "usage-popover-green") { m in lib(m); m.accent = .green })
        list.append(Shot(name: "native-appearance-pink-focused") { m in native(m, .appearance); m.accent = .pink })
        list.append(Shot(name: "native-notch-green-focused", dark: true) { m in native(m, .notch); m.accent = .green })
        list.append(Shot(name: "native-onepage") { m in native(m, .account); m.settingsLayout = .sidebar })
        list.append(Shot(name: "accent-pink-home") { m in reset(m); m.accent = .pink; m.selectedID = "x-ears" })
        list.append(Shot(name: "native-full-page") { m in native(m, .account); m.pageStyle = .full })
        list.append(Shot(name: "native-library") { m in lib(m); m.page = .settings; m.settingsCategory = .account; m.settingsScroll = (.account, 1) })
        // Fitting the window to the new icon.
        for mark in [FocusMark.dot, .eye] {
            list.append(Shot(name: "focus-\(mark.rawValue)") { m in reset(m); m.focusMark = mark; m.selectedID = "x-ears" })
            list.append(Shot(name: "focus-\(mark.rawValue)-dark", dark: true) { m in reset(m); m.focusMark = mark; m.selectedID = "x-ears" })
        }
        list.append(Shot(name: "avatar-eye") { m in reset(m); m.avatarStyle = .eye })
        list.append(Shot(name: "avatar-eye-settings") { m in native(m, .account); m.avatarStyle = .eye })
        list.append(Shot(name: "type-rounded") { m in reset(m); m.titleDesign = .rounded })
        list.append(Shot(name: "type-rounded-settings") { m in native(m, .account); m.titleDesign = .rounded })
        list.append(Shot(name: "icon-fit-all") { m in
            reset(m); m.focusMark = .eye; m.avatarStyle = .eye; m.titleDesign = .rounded; m.selectedID = "x-ears"
        })
        return list
    }

    /// Back to the defaults, with the window drawn active and nothing moving.
    static func defaults(_ model: CapturesModel) {
        model.load(.typical)
        model.layout = .cards; model.pageStyle = .inset; model.windowMaterial = .vibrant; model.liquidGlass = true; model.pageIsland = .solid
        // The list keeps its place between shots: back to its top.
        model.noteID = nil; model.listScrollTarget = LibraryIDs.top
        model.calendarMonth = Lines.calendar.date(from: Lines.calendar.dateComponents([.year, .month], from: model.now))!
        model.surface = .system; model.headerStyle = .themeAndType; model.cardSize = .medium; model.iconStyle = .small
        model.settingsArrangement = .beside; model.cardSpacing = .quiet
        model.plan = .pro; model.nextPlan = nil; model.yearlyBilling = false
        model.calendarYear = Lines.calendar.component(.year, from: model.now)
        model.cardAttachments = .inlineAndPreview; model.detailStyle = .quickLook; model.attachmentMotion = .fly
        model.detailIcon = false; model.hitStyle = .highlight; model.settingsLayout = .sidebarPanes; model.prefs = Prefs(); model.accent = .multicolor
        model.settingsCategory = .account; model.settingsScroll = nil
        model.focusMark = .ring; model.avatarStyle = .circle; model.titleDesign = .standard; model.iconVariant = .serif
        model.historyStyle = .yearGraphTop; model.archiveStyle = .page; model.archiveDay = nil
        model.hoverKey = nil; model.usageShown = false; model.dictionaryTab = .all; model.lastForgotten = nil
        model.toast = nil; model.copiedID = nil; model.selectedID = nil
        // The App UI review's state.
        model.profileName = "Ryan"; model.profilePhoto = nil; model.photoTooLarge = false
        model.reporting = false; model.update = .upToDate; model.planAlert = nil; model.windowError = nil
        model.memoryState = .loaded; model.signedOut = false
        model.browsingMemories = false; model.memoryFilter = .all; model.memorySelection = []
        model.lastDeletedMemories = []; model.accessLogShown = false; model.viewing = nil
        DemoStash.memories = nil; DemoStash.dictionary = nil
        // Search folds back if a shot opened it (a negative request closes it, cleared).
        model.searchRequest = -1
    }

    static func run(dir: URL, only: String?, app: AppDelegate) async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let model = app.model
        // `--only menus`: the menu bar's menus, with the current choices checked, as text.
        if only == "menus" {
            func dump(_ menu: NSMenu, _ depth: Int) -> [String] {
                menu.delegate?.menuNeedsUpdate?(menu)
                return menu.items.flatMap { item -> [String] in
                    let line = String(repeating: "  ", count: depth) + (item.isSeparatorItem ? "—" : (item.state == .on ? "✓ " : "") + item.title)
                    return [line] + (item.submenu.map { dump($0, depth + 1) } ?? [])
                }
            }
            let text = (NSApp.mainMenu.map { dump($0, 0) } ?? []).joined(separator: "\n")
            try? text.write(to: dir.appendingPathComponent("menus.txt"), atomically: true, encoding: .utf8)
            print(text)
            return
        }
        model.speed = 1
        // `--only glow-live`: Settings › Notch with the glow moving (motion on, unlike the shots),
        // through what a person does there (open it from another section, pick Custom, sweep the
        // hue and the spread, go dark, scroll), a frame after each step, then every half second.
        if only == "glow-live" {
            var n = 0
            func shot(_ label: String) {
                write(app.window, to: dir.appendingPathComponent(String(format: "glow-live-%02d-", n) + label + ".png"))
                n += 1
            }
            await settle(0.8)
            model.cut { defaults(model) }
            model.reduceMotion = false
            model.appearance = .light
            app.applyAppearance()
            app.window.setContentSize(T.Layout.window)
            model.cut { model.page = .settings; model.settingsCategory = .appearance; model.settingsScroll = (.appearance, 1) }
            await settle(1.0)
            withAnimation { model.pickSettings(.notch) }
            await settle(1.5); shot("opened")
            model.prefs.glow = .custom
            await settle(0.8); shot("custom")
            for i in 1...30 { model.prefs.glowHue = 93 * Double(i) / 30; await settle(0.05) }
            await settle(0.5); shot("hue")
            for i in 1...30 { model.prefs.glowSpread = 120 + 240 * Double(i) / 30; await settle(0.05) }
            await settle(0.5); shot("spread")
            model.appearance = .dark
            app.applyAppearance()
            await settle(1.0); shot("dark")
            model.scrollTarget = "notch-glow"
            await settle(1.0); shot("scrolled")
            model.scrollTarget = "top"
            await settle(1.0); shot("top")
            for _ in 0..<16 { await settle(0.5); shot("wait") }
            return
        }
        // The window placed and drawn before the first shot (a first shot could catch it mid-move).
        await settle(0.8)
        for shot in shots where only.map({ shot.name.hasPrefix($0) }) ?? true {
            model.reduceMotion = true
            model.cut { defaults(model) }
            model.appearance = shot.dark ? .dark : .light
            app.applyAppearance()
            app.window.setContentSize(shot.size ?? T.Layout.window)
            model.scrollTarget = "top"
            await settle(0.2)
            model.cut { shot.setup(model) }
            await settle(0.6)
            if let target = shot.scrollTo {
                model.scrollTarget = target
                await settle(0.5)
            }
            // A shot named "…-focused" gives the sidebar's list the keyboard, as a click on it does
            // (the Mac's own highlight is strongest then).
            if shot.name.hasSuffix("-focused") {
                func views(_ v: NSView) -> [NSView] { [v] + v.subviews.flatMap(views) }
                if let list = app.window.contentView.flatMap({ views($0).first { $0 is NSTableView } }) {
                    app.window.makeFirstResponder(list)
                }
                await settle(0.4)
            }
            // A shot named "usage-popover…" opens the avatar's popover and takes it with the window
            // (a popover is a window of its own).
            if shot.name.hasPrefix("usage-popover") || shot.name.hasPrefix("fb-sheet") {
                if shot.name.hasPrefix("usage-popover") { model.usageShown = true }
                await settle(1.0)
                // Front to back: the popover or the sheet over the window it hangs from.
                let others = NSApp.windows.filter { $0.isVisible && $0 !== app.window }
                writeWindows(others + [app.window], to: dir.appendingPathComponent("window-\(shot.name).png"))
                model.usageShown = false
                model.reporting = false; model.browsingMemories = false; model.accessLogShown = false
                await settle(0.8)
                model.reduceMotion = false
                continue
            }
            await settle(0.3)
            write(app.window, to: dir.appendingPathComponent("window-\(shot.name).png"))
            model.reduceMotion = false
        }
        if only.map({ "filter-menu".hasPrefix($0) }) ?? true {
            model.cut { defaults(model) }
            model.appearance = .light
            app.applyAppearance()
            model.cut { model.layout = .cards; model.page = .captures; model.query = CaptureQuery() }
            await settle(0.9)
            writeWithOpenMenu(app.window, item: "All Apps", to: dir.appendingPathComponent("window-filter-menu.png"))
            // A plain button's menu may open on a later turn: wait out the capture.
            await settle(1.2)
        }
    }

    /// Copied from Prototypes/FoveaWindowBench/App/BenchSnapshots.swift (may drift).
    /// Opens the window's own pop-up menu that holds `item` (the real menu, as a click opens
    /// it), draws the menu over the window while it's open, then closes it. Opening a menu runs
    /// its own event loop until it closes, so the capture is scheduled first and closes it.
    static func writeWithOpenMenu(_ window: NSWindow, item: String, to url: URL) {
        func views(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(views) }
        let root = window.contentView?.superview ?? NSView()
        let button = views(root).compactMap({ $0 as? NSControl })
            .first(where: { String(describing: type(of: $0)).contains("PopupButton") })
        // No pop-up button (the filter is a plain button's menu now): click the toolbar's first
        // item, at its middle, as the pointer would.
        let click: NSPoint? = button != nil ? nil : (window.toolbar?.items ?? [])
            .compactMap { $0.view }
            .map { $0.convert($0.bounds, to: nil) }
            .filter { $0.width > 0 }
            .min { $0.minX < $1.minX }
            .map { NSPoint(x: $0.midX, y: $0.midY) }
        guard button != nil || click != nil else {
            print("failed \(url.lastPathComponent): no pop-up button, no toolbar item"); return
        }
        // A timer in the common modes: a menu's own event loop runs in event-tracking mode.
        let timer = Timer(timeInterval: 0.6, repeats: false) { _ in
            let info = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
            let menuLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
            let menus = info.filter { ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == getpid() && ($0[kCGWindowLayer as String] as? NSNumber)?.intValue == menuLevel }
                .compactMap { $0[kCGWindowNumber as String] as? CGWindowID }
            let ids = menus + [CGWindowID(window.windowNumber)]
            let values = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: ids.count)
            defer { values.deallocate() }
            for (i, id) in ids.enumerated() { values[i] = UnsafeRawPointer(bitPattern: UInt(id)) }
            if let array = CFArrayCreate(kCFAllocatorDefault, values, ids.count, nil),
               let image = CGImage(windowListFromArrayScreenBounds: .null, windowArray: array, imageOption: [.boundsIgnoreFraming, .bestResolution]),
               let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                try? data.write(to: url)
                print("wrote \(url.lastPathComponent) (\(menus.count) menu window\(menus.count == 1 ? "" : "s"))")
            } else {
                print("failed \(url.lastPathComponent)")
            }
            if let menu = button?.menu, menu.items.contains(where: { $0.title == item }) {
                menu.cancelTracking()
            } else if let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                                     windowNumber: window.windowNumber, context: nil, characters: "\u{1b}",
                                                     charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53) {
                NSApp.postEvent(escape, atStart: true)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        if let button {
            button.performClick(nil)
        } else if let click {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                if let event = NSEvent.mouseEvent(with: type, location: click, modifierFlags: [],
                                                  timestamp: ProcessInfo.processInfo.systemUptime,
                                                  windowNumber: window.windowNumber, context: nil,
                                                  eventNumber: 0, clickCount: 1, pressure: 1) {
                    window.sendEvent(event)
                }
            }
        }
    }

    /// The expanded card opening, held, then closing; slowed tenfold so each frame is one step.
    static func frames(dir: URL, app: AppDelegate) async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let model = app.model
        model.cut { defaults(model) }
        model.appearance = .light
        app.applyAppearance()
        model.cut { model.page = .captures; model.query = CaptureQuery() }
        await settle(1.0)
        model.speed = 0.1
        var n = 0
        func shoot(_ phase: String) {
            write(app.window, to: dir.appendingPathComponent(String(format: "%@-%03d.png", phase, n)), quiet: true)
            n += 1
        }
        shoot("open")
        model.open("x-ears")
        for _ in 0..<34 { await tick(0.12); shoot("open") }
        await settle(0.5)
        model.closeDetail()
        for _ in 0..<30 { await tick(0.12); shoot("close") }
        model.speed = 1
        print("wrote \(n) frames")
    }

    /// The Eye Tracking pane's gaze moving between windows, at full speed, every 150 ms.
    static func eyeFrames(dir: URL, app: AppDelegate) async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let model = app.model
        model.cut { defaults(model) }
        model.appearance = .light
        app.applyAppearance()
        model.cut { model.page = .settings; model.settingsPane = .eyeTracking }
        await settle(0.6)
        for n in 0..<28 {
            await tick(0.15)
            write(app.window, to: dir.appendingPathComponent(String(format: "eye-%03d.png", n)), quiet: true)
        }
        print("wrote 28 frames")
    }

    /// The search icon opening into the field and folding back, slowed fourfold, every 40 ms.
    static func searchFrames(dir: URL, app: AppDelegate) async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let model = app.model
        model.cut { defaults(model) }
        model.appearance = .light
        app.applyAppearance()
        model.cut { model.page = .captures; model.query = CaptureQuery() }
        await settle(0.8)
        model.speed = 0.25
        var n = 0
        func shoot(_ phase: String) {
            write(app.window, to: dir.appendingPathComponent(String(format: "%@-%03d.png", phase, n)), quiet: true)
            n += 1
        }
        model.searchRequest += 1
        for _ in 0..<30 { await tick(0.04); shoot("open") }
        await settle(0.4)
        // A background window never gets the keyboard, so close it as Esc would.
        model.query.text = ""
        model.searchRequest = -1
        for _ in 0..<26 { await tick(0.04); shoot("close") }
        model.speed = 1
        print("wrote \(n) frames")
    }

    static func tick(_ seconds: Double) async {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end { try? await Task.sleep(for: .milliseconds(10)) }
    }

    static func settle(_ seconds: Double) async {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            for w in NSApp.windows where w.isVisible { w.layoutIfNeeded(); w.displayIfNeeded() }
            try? await Task.sleep(for: .milliseconds(40))
        }
    }

    /// Several of the app's windows, front to back, in the rect that holds them all (nothing of
    /// other apps').
    /// `FOVEA_OFFSCREEN=1`: each window's views drawn into an image inside the process, for when
    /// the screen is locked (the window server then hands back blank captures). The window's
    /// material and glass draw clear; a sheet or popover is written beside its window
    /// (`…-front.png`) instead of over it.
    static let offscreen = ProcessInfo.processInfo.environment["FOVEA_OFFSCREEN"] == "1"

    static func drawn(_ window: NSWindow) -> Data? {
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }

    static func writeWindows(_ windows: [NSWindow], to url: URL) {
        if offscreen {
            if let main = windows.last { write(main, to: url) }
            if windows.count > 1, let data = drawn(windows[0]) {
                let front = url.deletingPathExtension().appendingPathExtension("front.png")
                try? data.write(to: URL(fileURLWithPath: front.path.replacingOccurrences(of: ".front.png", with: "-front.png")))
                print("wrote \(front.lastPathComponent) (offscreen)")
            }
            return
        }
        guard let screen = NSScreen.screens.first, !windows.isEmpty else { return }
        let union = windows.map(\.frame).reduce(CGRect.null) { $0.union($1) }
        // Core Graphics counts from the top of the main screen.
        let rect = CGRect(x: union.minX, y: screen.frame.maxY - union.maxY, width: union.width, height: union.height)
        let ids = windows.map { CGWindowID($0.windowNumber) }
        var pointers = ids.map { UnsafeRawPointer(bitPattern: UInt($0)) }
        guard let array = CFArrayCreate(kCFAllocatorDefault, &pointers, ids.count, nil),
              let image = CGImage(windowListFromArrayScreenBounds: rect, windowArray: array, imageOption: [.bestResolution]),
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            print("failed \(url.lastPathComponent)"); return
        }
        try? data.write(to: url)
        print("wrote \(url.lastPathComponent)")
    }

    static func write(_ window: NSWindow, to url: URL, quiet: Bool = false) {
        if offscreen, let data = drawn(window) {
            try? data.write(to: url)
            if !quiet { print("wrote \(url.lastPathComponent) (offscreen)") }
            return
        }
        guard let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution]),
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            print("failed \(url.lastPathComponent)"); return
        }
        try? data.write(to: url)
        if !quiet { print("wrote \(url.lastPathComponent)") }
    }
}

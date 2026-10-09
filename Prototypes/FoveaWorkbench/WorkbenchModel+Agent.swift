import SwiftUI
import FoveaCore

// Voice input for agents and the agent at work (docs/island/AGENT_VOICE_AND_THINKING.md).
// Dispatch and Quick actions each have a voice bar; Quick actions has Thinking: the Lasso and
// one line of what the agent is doing on the Mac, while a simulated agent drives the mock screen
// with its own drawn pointer.

/// Where Thinking puts the mark, the line and the app: in one band under the notch, or beside
/// it, as a Live Activity's compact wings, with the line in a slim band below.
enum ActivityLayout: String, CaseIterable, Identifiable {
    case under, beside
    var id: String { rawValue }
    var title: String { self == .under ? "Under" : "Beside" }
}

/// How the line reads: as usual, or a moment the person should notice.
enum AgentTone {
    case normal, needsYou, failed
}

/// One thing the agent does on the Mac: the line it shows (a human summary, never a log: the
/// verb in -ing and the thing it acts on, as computer-use agents narrate; the past tense once
/// done), the action's symbol, whether the app it drives shows, the thinking-orbs state that
/// fits it, and how it reads. Each is also performed on the mock screen (`perform`). The set
/// follows the computer-use action vocabularies (Anthropic, OpenAI, Gemini, Browser Use);
/// docs/island/AGENT_VOICE_AND_THINKING.md has the sources.
enum AgentAction: String, CaseIterable, Identifiable {
    case plan, think, openApp, search, openURL, read, find, scroll, click, newTab, doubleClick, selectText, copy,
         switchTab, paste, type, pressKey, rightClick, download, upload, drag, hover, zoom, screenshot, wait,
         goBack, checkCode, runTests, needsYou, complete, failed
    var id: String { rawValue }

    var line: String {
        switch self {
        case .plan: return "Planning the next steps"
        case .think: return "Thinking"
        case .openApp: return "Opening Safari"
        case .search: return "Searching \u{201C}\(Self.query)\u{201D}"
        case .openURL: return "Opening notes.example.com"
        case .read: return "Reading the article"
        case .find: return "Finding \u{201C}pass\u{201D}"
        case .scroll: return "Scrolling to On the pass"
        case .click: return "Clicking \u{201C}Journal\u{201D}"
        case .newTab: return "Opening \u{201C}Journal\u{201D} in a new tab"
        case .doubleClick: return "Selecting \u{201C}Snow\u{201D}"
        case .selectText: return "Selecting the paragraph"
        case .copy: return "Copying the paragraph"
        case .switchTab: return "Switching to Design notes"
        case .paste: return "Pasting into the comment"
        case .type: return "Typing a comment"
        case .pressKey: return "Pressing Return"
        case .rightClick: return "Opening the photo\u{2019}s menu"
        case .download: return "Saving coast.jpg"
        case .upload: return "Attaching mockup.png"
        case .drag: return "Dragging the photo into place"
        case .hover: return "Pointing at \u{201C}Larch in the first frost\u{201D}"
        case .zoom: return "Zooming in on the caption"
        case .screenshot: return "Looking at the screen"
        case .wait: return "Waiting for the page"
        case .goBack: return "Going back to the article"
        case .checkCode: return "Checking line 7"
        case .runTests: return "Running the tests"
        case .needsYou: return "Allow posting the comment?"
        case .complete: return "Posted the comment"
        case .failed: return "Couldn\u{2019}t find \u{201C}Save\u{201D}"
        }
    }

    /// The panel's name for it.
    var title: String {
        switch self {
        case .plan: return "Plan"
        case .think: return "Think"
        case .openApp: return "Open app"
        case .search: return "Search the web"
        case .openURL: return "Open a URL"
        case .read: return "Read"
        case .find: return "Find on page"
        case .scroll: return "Scroll"
        case .click: return "Click"
        case .newTab: return "\u{2318}-click (new tab)"
        case .doubleClick: return "Double-click"
        case .selectText: return "Triple-click (select)"
        case .copy: return "Copy"
        case .switchTab: return "Switch tab"
        case .paste: return "Paste"
        case .type: return "Type"
        case .pressKey: return "Press a key"
        case .rightClick: return "Right-click"
        case .download: return "Download"
        case .upload: return "Upload"
        case .drag: return "Drag"
        case .hover: return "Hover"
        case .zoom: return "Zoom in"
        case .screenshot: return "Screenshot"
        case .wait: return "Wait"
        case .goBack: return "Go back"
        case .checkCode: return "Check code"
        case .runTests: return "Run tests"
        case .needsYou: return "Needs you"
        case .complete: return "Complete"
        case .failed: return "Failed"
        }
    }

    var symbol: String? {
        switch self {
        case .plan: return "checklist"
        case .think: return nil
        case .openApp: return "macwindow"
        case .search: return "magnifyingglass"
        case .openURL: return "globe"
        case .read: return "doc.text.magnifyingglass"
        case .find: return "text.magnifyingglass"
        case .scroll: return "arrow.down"
        case .click: return "cursorarrow.click"
        case .newTab: return "plus.square.on.square"
        case .doubleClick: return "cursorarrow.click.2"
        case .selectText: return "character.cursor.ibeam"
        case .copy: return "doc.on.doc"
        case .switchTab: return "square.on.square"
        case .paste: return "doc.on.clipboard"
        case .type: return "keyboard"
        case .pressKey: return "return"
        case .rightClick: return "contextualmenu.and.cursorarrow"
        case .download: return "square.and.arrow.down"
        case .upload: return "paperclip"
        case .drag: return "hand.draw"
        case .hover: return "cursorarrow.motionlines"
        case .zoom: return "plus.magnifyingglass"
        case .screenshot: return "camera.viewfinder"
        case .wait: return "hourglass"
        case .goBack: return "chevron.backward"
        case .checkCode: return "chevron.left.forwardslash.chevron.right"
        case .runTests: return "terminal"
        case .needsYou: return "hand.raised"
        case .complete: return "checkmark"
        case .failed: return "exclamationmark.triangle"
        }
    }

    /// Safari shows beside the line once the agent is in it.
    var app: Bool { self != .plan && self != .think }

    /// The Lasso holds still: the agent waits on the person, or is done.
    var holdsStill: Bool { self == .needsYou || self == .complete || self == .failed }

    var tone: AgentTone {
        switch self {
        case .needsYou: return .needsYou
        case .failed: return .failed
        default: return .normal
        }
    }

    /// The full run: a research task, from planning to done, with one question on the way.
    static let fullRun: [AgentAction] = [
        .plan, .openApp, .search, .read, .scroll, .selectText, .copy, .switchTab, .paste, .type, .screenshot,
        .needsYou, .pressKey, .complete,
    ]
    /// What the agent searches for, and what it types into the comment box.
    static let query = "snow on the high valleys"
    static let comment = " Match the ears to the menu bar's height."
}

/// A click's ring on the page, where the agent's pointer pressed.
struct AgentRipple: Identifiable, Equatable {
    let id = UUID()
    let location: CGPoint
}

extension WorkbenchModel {
    /// Where Thinking's parts go, for the chosen layout.
    var agentLayout: AgentLayout {
        AgentLayout.make(activityLayout, hasMark: true, metrics: metrics)
    }

    /// Quick actions' Thinking: the island opens to the agent at work and it starts: the full
    /// run, or one action on a loop (the panel's Action). Snapshots hold one action.
    func showThinking() {
        if demoRunning { stopDemo() }
        if notchState == .quickThinking { stopAgent() } else { notchState = .quickThinking }
        guard !snapshotMode else {
            agentAction = agentPreview ?? .scroll
            return
        }
        agentAction = agentPreview ?? AgentAction.fullRun[0]
        agentTask = Task { [weak self] in await self?.runAgent() }
    }

    /// Snapshots: the action as it looks mid-way, on the screen it plays on: the pointer where it
    /// would be and what it drew. Call once the screen has been laid out (the anchors are read).
    func stageForSnapshot(_ action: AgentAction) {
        clearAgentScreen()
        agentAction = action
        let pointer = { (p: CGPoint) in self.agentPointer = DemoPointer(location: p, style: .agent) }
        switch action {
        case .search:
            if let field = anchor("safari.address") { pointer(CGPoint(x: field.minX + 40, y: field.midY)) }
            agentAddress = String(AgentAction.query.prefix(14))
        case .read:
            if let h = anchor("article.headline") { pointer(CGPoint(x: h.midX, y: h.midY)) }
        case .click:
            if let l = anchor("article.nav.Journal") { pointer(CGPoint(x: l.midX, y: l.midY)); agentRipples = [AgentRipple(location: CGPoint(x: l.midX, y: l.midY))] }
        case .doubleClick:
            if let h = anchor("article.headline") {
                let word = CGRect(x: h.minX, y: h.minY, width: h.width * 0.17, height: h.height)
                agentHighlights = [word]
                pointer(CGPoint(x: word.midX, y: word.midY))
            }
        case .selectText, .copy:
            highlight("article.opening0")
            if let p = anchor("article.opening0") { pointer(CGPoint(x: p.minX + 4, y: p.minY + 12)) }
            if action == .copy { agentKeycap = "\u{2318}C" }
        case .pressKey: agentKeycap = "\u{21A9}"
        case .newTab:
            if let l = anchor("article.nav.Journal") {
                agentTarget = l
                agentKeycap = "\u{2318}"
                pointer(CGPoint(x: l.midX, y: l.midY))
            }
        case .openURL:
            if let field = anchor("safari.address") { pointer(CGPoint(x: field.minX + 40, y: field.midY)) }
            agentAddress = "notes.example"
        case .find:
            agentToast = AgentToast(symbol: "magnifyingglass", text: "snow \u{00B7} 1 of 3")
            if let title = anchor("article.headline") {
                agentFinds = [CGRect(x: title.minX, y: title.minY, width: title.width * 0.17, height: title.height)]
            }
        case .upload:
            if let c = anchor("notes.comment") { agentTarget = c; pointer(CGPoint(x: c.minX + 60, y: c.midY)) }
            agentToast = AgentToast(symbol: "paperclip", text: "mockup.png \u{00B7} attached")
        case .runTests:
            if let code = anchor("code.code") {
                agentHighlights = [CGRect(x: code.minX, y: code.minY + WorkbenchTokens.Safari.codeLineHeight * 6,
                                          width: code.width, height: WorkbenchTokens.Safari.codeLineHeight)]
            }
            agentToast = AgentToast(symbol: "checkmark.circle", text: "12 tests passed")
        case .goBack: agentKeycap = "\u{2318}["
        case .rightClick, .download:
            if let hero = anchor("article.hero") {
                let at = CGPoint(x: hero.midX - 80, y: hero.midY - 40)
                agentMenu = AgentMenu(items: ["Open Image in New Tab", "Save Image As\u{2026}", "Copy Image", "Share\u{2026}"],
                                      at: CGPoint(x: at.x + 4, y: at.y + 4), highlighted: action == .download ? 1 : 2)
                let T = WorkbenchTokens.AgentScreen.self
                pointer(CGPoint(x: at.x + 4 + T.menuWidth / 2, y: at.y + 4 + T.menuPadding + T.menuRow * (action == .download ? 1.5 : 2.5)))
            }
            if action == .download { agentToast = AgentToast(symbol: "arrow.down.circle", text: "coast.jpg · 2.4 MB") }
        case .zoom, .drag, .hover:
            if let photo = anchor("gallery.photo0") {
                switch action {
                case .zoom:
                    let caption = CGRect(x: photo.minX - 6, y: photo.maxY + 2, width: photo.width * 0.6, height: 26)
                    agentZoom = caption
                    pointer(CGPoint(x: caption.midX, y: caption.midY))
                case .drag:
                    let size = CGSize(width: photo.width * 0.35, height: photo.height * 0.35)
                    let at = CGPoint(x: photo.maxX + 10, y: photo.midY + 60)
                    agentDrag = CGRect(origin: CGPoint(x: at.x - size.width / 2, y: at.y - size.height / 2), size: size)
                    pointer(at)
                    agentPointer?.pressed = true
                default:
                    pointer(CGPoint(x: photo.midX, y: photo.midY))
                }
            }
        case .checkCode:
            if let code = anchor("code.code") {
                let line = CGRect(x: code.minX, y: code.minY + WorkbenchTokens.Safari.codeLineHeight * 6,
                                  width: code.width, height: WorkbenchTokens.Safari.codeLineHeight)
                agentHighlights = [line]
                pointer(CGPoint(x: line.minX + 120, y: line.midY))
            }
        case .needsYou: agentNeedsYou = action.line
        default:
            pointer(restPoint)
        }
    }

    /// The tab an action plays on.
    static func tab(for action: AgentAction) -> Int {
        switch action {
        case .paste, .type, .switchTab, .upload: return 2
        case .drag, .hover, .zoom: return 1
        case .checkCode, .runTests: return 3
        default: return 0
        }
    }

    /// The agent stops: its script, its pointer and everything it drew go at once.
    func stopAgent() {
        agentTask?.cancel()
        agentTask = nil
        agentAction = nil
        agentPointer = nil
        agentRipples = []
        clearAgentScreen()
    }

    /// The person answers Needs you.
    func allowAgent() {
        guard agentAction == .needsYou else { return }
        agentAllowed = true
    }

    private func clearAgentScreen() {
        agentTarget = nil
        agentFinds = []
        agentKeycap = nil
        agentHighlights = []
        agentMenu = nil
        agentFlash = false
        agentZoom = nil
        agentDrag = nil
        agentAddress = nil
        agentToast = nil
        agentNeedsYou = nil
    }

    // MARK: The run

    private func runAgent() async {
        if let single = agentPreview {
            // One action, again and again, from the screen it needs.
            while !Task.isCancelled, notchState == .quickThinking {
                await prepare(for: single)
                agentAction = single
                guard await perform(single), await agentWait(0.9) else { return }
                clearAgentScreen()
                guard await agentWait(0.4) else { return }
            }
            return
        }
        for action in AgentAction.fullRun {
            agentAction = action
            guard await perform(action) else { return }
        }
        withAnimation(WorkbenchTokens.Motion.contentOut) { agentPointer = nil }
        guard await agentWait(0.4) else { return }
        notchState = .silent
    }

    /// The screen an action starts from when it plays on its own.
    private func prepare(for action: AgentAction) async {
        clearAgentScreen()
        if action.app, screenContent != .fullScreenApp { screenContent = .fullScreenApp }
        let tab = action == .switchTab ? 0 : Self.tab(for: action)
        if action.app {
            selectTab(tab)
            scroll(tab: tab, to: action == .selectText || action == .copy ? "pass" : "top")
            if action == .copy { highlight("article.pass0") }
            if agentPointer == nil { agentPointer = DemoPointer(location: restPoint, style: .agent) }
        }
        _ = await agentWait(0.35)
    }

    /// Does the action on the mock screen; false once the agent was stopped.
    private func perform(_ action: AgentAction) async -> Bool {
        switch action {
        case .plan:
            return await agentWait(2.0)
        case .think:
            return await agentWait(1.6)
        case .wait:
            return await agentWait(1.8)
        case .openApp:
            guard await agentWait(0.5) else { return false }
            if screenContent != .fullScreenApp { screenContent = .fullScreenApp }
            selectTab(0)
            scroll(tab: 0, to: "top")
            agentPointer = DemoPointer(location: restPoint, style: .agent)
            return await agentWait(1.2)
        case .search:
            guard let field = anchor("safari.address"),
                  await agentClick(at: CGPoint(x: field.minX + 40, y: field.midY), target: field,
                                   then: { [weak self] in self?.agentAddress = "" })
            else { return false }
            for character in AgentAction.query {
                guard notchState == .quickThinking, !Task.isCancelled else { return false }
                agentAddress = (agentAddress ?? "") + String(character)
                try? await Task.sleep(for: WorkbenchTokens.Thinking.typeInterval * agentPace)
            }
            guard await keycap("\u{21A9}") else { return false }
            agentAddress = nil
            selectTab(0)
            scroll(tab: 0, to: "top")
            return await agentWait(0.6)
        case .openURL:
            guard let field = anchor("safari.address"),
                  await agentClick(at: CGPoint(x: field.minX + 40, y: field.midY), target: field,
                                   then: { [weak self] in self?.agentAddress = "" })
            else { return false }
            for character in "notes.example.com" {
                guard notchState == .quickThinking, !Task.isCancelled else { return false }
                agentAddress = (agentAddress ?? "") + String(character)
                try? await Task.sleep(for: WorkbenchTokens.Thinking.typeInterval * agentPace)
            }
            guard await keycap("\u{21A9}") else { return false }
            agentAddress = nil
            selectTab(2)
            scroll(tab: 2, to: "top")
            return await agentWait(0.6)
        case .find:
            selectTab(0)
            guard await keycap("\u{2318}F") else { return false }
            agentToast = AgentToast(symbol: "magnifyingglass", text: "pass \u{00B7} 1 of 3")
            scroll(tab: 0, to: "pass")
            guard await agentWait(0.9) else { return false }
            if let title = anchor("article.passTitle") {
                // "pass" in the title: its last word, about a quarter of its width.
                agentFinds = [CGRect(x: title.maxX - title.width * 0.27, y: title.minY, width: title.width * 0.27, height: title.height)]
            }
            return await agentWait(1.2)
        case .newTab:
            guard let link = anchor("article.nav.Journal") else { return await agentWait(1.4) }
            agentKeycap = "\u{2318}"
            guard await agentClick(at: CGPoint(x: link.midX, y: link.midY), target: link, then: {}) else { return false }
            agentKeycap = nil
            agentToast = AgentToast(symbol: "plus.square.on.square", text: "Journal \u{00B7} new tab")
            return await agentWait(1.2)
        case .upload:
            guard await clickComment() else { return false }
            agentToast = AgentToast(symbol: "paperclip", text: "mockup.png \u{00B7} attached")
            return await agentWait(1.4)
        case .runTests:
            guard let code = anchor("code.code") else { return await agentWait(1.6) }
            guard await keycap("\u{2318}U") else { return false }
            let line = CGRect(x: code.minX, y: code.minY + WorkbenchTokens.Safari.codeLineHeight * 6,
                              width: code.width, height: WorkbenchTokens.Safari.codeLineHeight)
            agentHighlights = [line]
            guard await agentWait(0.8) else { return false }
            agentToast = AgentToast(symbol: "checkmark.circle", text: "12 tests passed")
            return await agentWait(1.2)
        case .read:
            guard let headline = anchor("article.headline") else { return await agentWait(2) }
            guard await agentMove(to: CGPoint(x: headline.minX, y: headline.midY)),
                  await agentMove(to: CGPoint(x: headline.maxX, y: headline.midY), duration: 0.9) else { return false }
            if let para = anchor("article.opening0") {
                guard await agentMove(to: CGPoint(x: para.minX, y: para.minY + 14)),
                      await agentMove(to: CGPoint(x: para.maxX - 40, y: para.minY + 14), duration: 0.8) else { return false }
            }
            return await agentWait(0.3)
        case .scroll:
            selectTab(0)
            scroll(tab: 0, to: "pass")
            return await agentWait(1.8)
        case .click:
            guard let link = anchor("article.nav.Journal") else { return await agentWait(1.4) }
            guard await agentClick(at: CGPoint(x: link.midX, y: link.midY), target: link, then: {}) else { return false }
            return await agentWait(0.8)
        case .doubleClick:
            guard let headline = anchor("article.headline") else { return await agentWait(1.4) }
            let word = CGRect(x: headline.minX, y: headline.minY, width: headline.width * 0.17, height: headline.height)
            guard await agentClick(at: CGPoint(x: word.midX, y: word.midY), target: word, then: {}),
                  await agentClick(at: CGPoint(x: word.midX, y: word.midY), then: { [weak self] in self?.agentHighlights = [word] })
            else { return false }
            return await agentWait(1.0)
        case .selectText:
            selectTab(0)
            scroll(tab: 0, to: "pass")
            guard await agentWait(0.9), let para = anchor("article.pass0") else { return false }
            let start = CGPoint(x: para.minX + 4, y: para.minY + 12)
            guard await agentClick(at: start, target: para, then: {}), await agentClick(at: start, then: {}),
                  await agentClick(at: start, then: { [weak self] in self?.highlight("article.pass0") })
            else { return false }
            return await agentWait(0.8)
        case .copy:
            return await keycap("\u{2318}C")
        case .switchTab:
            let tabFrame = MockSafari.tabFrame(2, count: tabs.count, displayWidth: display.frame.width, top: metrics.safeAreaTop)
            guard await agentClick(at: agentTabCenter(2), target: tabFrame, then: { [weak self] in
                self?.agentHighlights = []
                self?.selectTab(2)
                self?.scroll(tab: 2, to: "top")
            }) else { return false }
            return await agentWait(0.8)
        case .paste:
            guard await clickComment() else { return false }
            guard await keycap("\u{2318}V") else { return false }
            pastedNote = "At the pass the wind has already carved the new snow into low drifts."
            return await agentWait(0.6)
        case .type:
            if pastedNote == nil { guard await clickComment() else { return false } ; pastedNote = "" }
            for character in AgentAction.comment {
                guard notchState == .quickThinking, !Task.isCancelled else { return false }
                pastedNote = (pastedNote ?? "") + String(character)
                try? await Task.sleep(for: WorkbenchTokens.Thinking.typeInterval * agentPace)
            }
            return await agentWait(0.5)
        case .pressKey:
            return await keycap("\u{21A9}")
        case .rightClick:
            return await openPhotoMenu(choosing: 2)
        case .download:
            guard await openPhotoMenu(choosing: 1) else { return false }
            agentToast = AgentToast(symbol: "arrow.down.circle", text: "coast.jpg · 2.4 MB")
            return await agentWait(1.4)
        case .drag:
            guard let from = anchor("gallery.photo0"), let to = anchor("gallery.photo3") else { return await agentWait(1.6) }
            let size = CGSize(width: from.width * 0.35, height: from.height * 0.35)
            let start = CGPoint(x: from.midX, y: from.midY)
            guard await agentMove(to: start) else { return false }
            withAnimation(.easeOut(duration: 0.08)) { agentPointer?.pressed = true }
            agentDrag = CGRect(origin: CGPoint(x: start.x - size.width / 2, y: start.y - size.height / 2), size: size)
            let end = CGPoint(x: to.midX, y: to.midY)
            withAnimation(WorkbenchTokens.Thinking.dragMove) {
                agentPointer?.location = end
                agentDrag = CGRect(origin: CGPoint(x: end.x - size.width / 2, y: end.y - size.height / 2), size: size)
            }
            guard await agentWait(0.9) else { return false }
            withAnimation(.easeOut(duration: 0.12)) { agentPointer?.pressed = false }
            agentDrag = nil
            return await agentWait(0.5)
        case .hover:
            guard let photo = anchor("gallery.photo1") else { return await agentWait(1.4) }
            guard await agentMove(to: CGPoint(x: photo.midX, y: photo.midY)) else { return false }
            return await agentWait(1.2)
        case .zoom:
            guard let photo = anchor("gallery.photo0") else { return await agentWait(1.4) }
            let caption = CGRect(x: photo.minX - 6, y: photo.maxY + 2, width: photo.width * 0.6, height: 26)
            guard await agentMove(to: CGPoint(x: caption.midX, y: caption.midY)) else { return false }
            agentZoom = caption
            return await agentWait(1.4)
        case .screenshot:
            agentFlash = true
            guard await agentWait(0.08) else { return false }
            agentFlash = false
            return await agentWait(1.2)
        case .goBack:
            guard await keycap("\u{2318}[") else { return false }
            selectTab(0)
            scroll(tab: 0, to: "top")
            return await agentWait(0.6)
        case .checkCode:
            guard let code = anchor("code.code") else { return await agentWait(1.6) }
            let line = CGRect(x: code.minX, y: code.minY + WorkbenchTokens.Safari.codeLineHeight * 6,
                              width: code.width, height: WorkbenchTokens.Safari.codeLineHeight)
            guard await agentMove(to: CGPoint(x: line.minX + 120, y: line.midY)) else { return false }
            agentHighlights = [line]
            return await agentWait(1.4)
        case .needsYou:
            // One question, one control; the run waits for Allow (or carries on by itself after
            // a while, so an unattended run still finishes).
            agentAllowed = false
            agentNeedsYou = action.line
            let asked = Date()
            while !agentAllowed, Date().timeIntervalSince(asked) < WorkbenchTokens.Thinking.needsYouTimeout * agentPace {
                guard await agentWait(0.05) else { return false }
            }
            agentNeedsYou = nil
            return await agentWait(0.2)
        case .complete:
            agentHighlights = []
            return await agentWait(1.6)
        case .failed:
            // The pointer shakes once where the thing it looked for was not.
            if agentPointer == nil { agentPointer = DemoPointer(location: restPoint, style: .agent) }
            let here = agentPointer?.location ?? restPoint
            for dx in [-7.0, 7.0, -4.0, 0.0] {
                withAnimation(.easeInOut(duration: 0.06)) { agentPointer?.location = CGPoint(x: here.x + dx, y: here.y) }
                guard await agentWait(0.07) else { return false }
            }
            return await agentWait(1.4)
        }
    }

    // MARK: Pieces

    private var restPoint: CGPoint { CGPoint(x: display.frame.width * 0.62, y: display.frame.height * 0.78) }

    private func anchor(_ name: String) -> CGRect? {
        guard let rect = agentAnchors[name], rect.width > 0,
              rect.maxY > 0, rect.minY < display.frame.height else { return nil }
        return rect
    }

    private func highlight(_ name: String) {
        if let rect = agentAnchors[name] { agentHighlights = [rect.insetBy(dx: -2, dy: -1)] }
    }

    private func clickComment() async -> Bool {
        let frame = anchor("notes.comment")
        let box = frame.map { CGPoint(x: $0.minX + 60, y: $0.midY) } ?? CGPoint(x: 460, y: 380)
        return await agentClick(at: box, target: frame, then: {})
    }

    /// A right-click on the article's photo: the menu, the pointer down it to an item, chosen.
    private func openPhotoMenu(choosing item: Int) async -> Bool {
        guard let hero = anchor("article.hero") else { return await agentWait(1.6) }
        let at = CGPoint(x: hero.midX - 80, y: hero.midY - 40)
        guard await agentClick(at: at, target: hero, then: { [weak self] in
            self?.agentMenu = AgentMenu(items: ["Open Image in New Tab", "Save Image As\u{2026}", "Copy Image", "Share\u{2026}"],
                                        at: CGPoint(x: at.x + 4, y: at.y + 4), highlighted: nil)
        }) else { return false }
        let T = WorkbenchTokens.AgentScreen.self
        let row = CGPoint(x: at.x + 4 + T.menuWidth / 2, y: at.y + 4 + T.menuPadding + T.menuRow * (CGFloat(item) + 0.5))
        guard await agentWait(0.4), await agentMove(to: row, duration: 0.4) else { return false }
        agentMenu?.highlighted = item
        guard await agentWait(0.4) else { return false }
        agentMenu = nil
        return await agentWait(0.3)
    }

    /// Corner brackets on the element the agent is about to act on, for a moment.
    private func bracket(_ rect: CGRect) {
        let T = WorkbenchTokens.AgentScreen.self
        withAnimation(T.bracketIn) { agentTarget = rect }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(T.bracketHold))
            guard let self, self.agentTarget == rect else { return }
            withAnimation(T.bracketFade) { self.agentTarget = nil }
        }
    }

    /// Shows a key the agent pressed, a moment.
    private func keycap(_ key: String) async -> Bool {
        agentKeycap = key
        guard await agentWait(0.9) else { return false }
        agentKeycap = nil
        return await agentWait(0.2)
    }

    /// Waits at the run's pace; false once the agent was stopped.
    private func agentWait(_ seconds: Double) async -> Bool {
        if seconds > 0 { try? await Task.sleep(for: .seconds(seconds * agentPace)) }
        return !Task.isCancelled && notchState == .quickThinking
    }

    private func agentMove(to point: CGPoint, duration: Double = 0.5) async -> Bool {
        if agentPointer == nil { agentPointer = DemoPointer(location: restPoint, style: .agent) }
        withAnimation(WorkbenchTokens.Thinking.pointerMove) { agentPointer?.location = point }
        return await agentWait(duration)
    }

    /// Moves to a point (bracketing the element it acts on, if given), presses, leaves a ring,
    /// then does what the click does.
    private func agentClick(at point: CGPoint, target: CGRect? = nil, then action: @escaping () -> Void) async -> Bool {
        if let target { bracket(target) }
        guard await agentMove(to: point) else { return false }
        withAnimation(.easeOut(duration: 0.08)) { agentPointer?.pressed = true }
        let ripple = AgentRipple(location: point)
        agentRipples.append(ripple)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(WorkbenchTokens.Thinking.rippleDuration))
            self?.agentRipples.removeAll { $0.id == ripple.id }
        }
        guard await agentWait(0.12) else { return false }
        withAnimation(.easeOut(duration: 0.12)) { agentPointer?.pressed = false }
        action()
        return true
    }

    private func agentTabCenter(_ index: Int) -> CGPoint {
        let frame = MockSafari.tabFrame(index, count: tabs.count, displayWidth: display.frame.width, top: metrics.safeAreaTop)
        return CGPoint(x: frame.midX, y: frame.midY)
    }
}

import Foundation

/// Which made-up library the bench shows.
public enum FixtureSet: String, CaseIterable, Codable, Hashable, Sendable {
    case typical, heavy, empty, longNames, errors

    public var title: String {
        switch self {
        case .typical: return "Typical"
        case .heavy: return "Heavy"
        case .empty: return "Empty"
        case .longNames: return "Long names"
        case .errors: return "Errors"
        }
    }
}

/// Typed, realistic fixtures: most runs are one sentence and some files; most captures are one
/// sentence and a destination with nothing to look at. Names and words mix Chinese and English
/// the way the brief's examples do.
public enum BenchFixtures {
    /// The bench's clock: Wednesday 2026-09-30 14:30, local time.
    public static var now: Date {
        Lines.calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 14, minute: 30))!
    }

    public static func library(_ set: FixtureSet) -> Library {
        switch set {
        case .typical: return typical()
        case .heavy: return heavy()
        case .empty: return Library(now: now, agents: agents())
        case .longNames: return longNames()
        case .errors: return errors()
        }
    }

    // MARK: Helpers

    static func minutesAgo(_ m: Double) -> Date { now.addingTimeInterval(-m * 60) }
    static func daysAgo(_ d: Int, _ hour: Int, _ minute: Int) -> Date {
        let day = Lines.calendar.date(byAdding: .day, value: -d, to: now)!
        var c = Lines.calendar.dateComponents([.year, .month, .day], from: day)
        c.hour = hour; c.minute = minute
        return Lines.calendar.date(from: c)!
    }

    static func route(_ text: String, _ source: String, _ alternatives: [String]) -> Inference {
        Inference(text: text, source: source, alternatives: alternatives)
    }

    // MARK: Agents

    public static func agents() -> [AgentConnection] {
        [
            AgentConnection(kind: .claudeCode, state: .connected, version: "2.0.14", binaryPath: "/opt/homebrew/bin/claude",
                            lastEvent: minutesAgo(2), hooksFile: "~/.claude/settings.json",
                            hooksText: """
                            "hooks": {
                              "Stop": [
                                { "hooks": [ { "type": "command", "command": "\\"$HOME/Library/Application Support/Fovea/fovea-hook\\" claude-code stop" } ] }
                              ],
                              "Notification": [
                                { "hooks": [ { "type": "command", "command": "\\"$HOME/Library/Application Support/Fovea/fovea-hook\\" claude-code notify" } ] }
                              ]
                            }
                            """,
                            historyFolders: ["~/.claude/projects"]),
            AgentConnection(kind: .codex, state: .connected, version: "0.44.0",
                            binaryPath: "/Applications/Codex.app/Contents/Resources/codex",
                            lastEvent: minutesAgo(14), hooksFile: "~/.codex/config.toml",
                            hooksText: """
                            notify = ["/Users/you/Library/Application Support/Fovea/fovea-hook", "codex"]
                            """,
                            historyFolders: ["~/.codex/sessions"]),
            AgentConnection(kind: .cursor, state: .connected, version: "2025.09.17", binaryPath: "~/.local/bin/cursor-agent",
                            lastEvent: minutesAgo(64), hooksFile: "~/.cursor/hooks.json",
                            hooksText: """
                            {
                              "version": 1,
                              "hooks": {
                                "stop": [ { "command": "~/Library/Application Support/Fovea/fovea-hook cursor stop" } ]
                              }
                            }
                            """,
                            historyFolders: ["~/.cursor/acp-sessions", "~/.cursor/chats"]),
        ]
    }

    // MARK: Typical

    static func typical() -> Library {
        var projects: [Project] = []
        var threads: [ProjectThread] = []
        var runs: [Run] = []

        // fovea-site: the brief's own example.
        projects.append(Project(id: "p-site", name: "fovea-site", paths: ["~/code/fovea-site"], lastVisit: daysAgo(1, 18, 10)))
        threads.append(ProjectThread(id: "t-copy", projectID: "p-site", name: "第二屏文案", agent: .codex,
                                     routing: route("dispatched to Codex · 12 copy tasks here went to it",
                                                    "routing  09-30 14:02  12 of 14 copy tasks in fovea-site → Codex",
                                                    ["Claude Code · hero 动效", "Cursor · a new chat"]),
                                     references: ["r-me"]))
        runs.append(Run(id: "r-deploy", threadID: "t-copy", words: "把第二屏的标题改短一点，副标题保留，按钮文案不用动",
                        state: .waiting, stuck: .permission(.command, raw: "npm run deploy:preview -- --branch second-screen"),
                        evidence: [.edit(FileChange(path: "src/sections/Second.tsx", added: 6, removed: 4)),
                                   .command(CommandResult("npm test"))],
                        started: minutesAgo(28), captureIDs: ["c-voice-title"],
                        lastActions: ["Edited Second.tsx +6 −4", "npm test passed", "Wants to deploy a preview"]))
        runs.append(Run(id: "r-bullets", threadID: "t-copy",
                        words: "Make the second screen's three bullets parallel, start each with a verb",
                        state: .finished,
                        evidence: [.read("src/sections/Second.tsx"),
                                   .edit(FileChange(path: "src/sections/Second.tsx", added: 9, removed: 9, hunks: secondHunks)),
                                   .command(CommandResult("npm test"))],
                        differences: ["Also changed the eyebrow from “Why” to “How”"],
                        agentLine: "Rewrote the three bullets to start with verbs and kept each under eight words.",
                        started: minutesAgo(52), finished: minutesAgo(46), attempt: 2,
                        earlierAttempts: [Attempt(number: 1, started: minutesAgo(70), line: "Edited Second.tsx +9 −9 · npm test · exit 1")],
                        captureIDs: ["c-site-shot", "c-draft", "c-eight"], result: .code,
                        output: """
                        • Read src/sections/Second.tsx
                        • Updated 3 bullet strings and the eyebrow
                        • npm test
                          PASS  src/sections/Second.test.tsx (4 tests)
                        Done. The bullets now start with verbs: Point, Say, Send.
                        """))
        let earlierCopy = [
            "首屏标题去掉“全新”两个字", "Tighten the FAQ answers to two sentences", "把价格页的“免费试用”改成“先试用”",
            "Rewrite the footer tagline, keep it under six words", "第二屏的按钮改成“开始”", "Fix the typo in the third testimonial",
            "Make the pricing toggle say Monthly / Yearly", "把 hero 下面的小字改成灰色", "Shorten the meta description to 150 characters",
            "Use sentence case in every section title", "第三屏配图的说明文字换一下", "Remove the exclamation marks from the CTA",
        ]
        for (i, words) in earlierCopy.enumerated() {
            let started = daysAgo(1 + i / 3, 16 - (i % 3) * 2, 12 + i)
            runs.append(Run(id: "r-copy-\(i)", threadID: "t-copy", words: words, state: .seen,
                            evidence: [.edit(FileChange(path: i % 2 == 0 ? "src/sections/Hero.tsx" : "src/content/copy.ts",
                                                        added: 2 + i % 5, removed: 1 + i % 4)),
                                       .command(CommandResult("npm test"))],
                            agentLine: "Done.", started: started, finished: started.addingTimeInterval(240), result: .code))
        }
        threads.append(ProjectThread(id: "t-hero", projectID: "p-site", name: "hero 动效", agent: .claudeCode,
                                     routing: route("dispatched to Claude Code · you named it last time",
                                                    "routing  09-30 14:21  you said “让 Claude 来” on 09-29",
                                                    ["Codex · 第二屏文案", "Cursor · a new chat"])))
        runs.append(Run(id: "r-hero", threadID: "t-hero", words: "hero 进场的动画太快了，放慢一点并且去掉回弹",
                        state: .running,
                        evidence: [.read("src/hero/Hero.tsx"), .edit(FileChange(path: "src/hero/motion.ts", added: 3, removed: 3, hunks: heroHunks))],
                        started: minutesAgo(9), captureIDs: ["c-hero-voice"],
                        lastActions: ["Read src/hero/Hero.tsx", "Edited motion.ts +3 −3", "Running npm run test:visual"]))
        runs.append(Run(id: "r-hero-0", threadID: "t-hero", words: "Fade the hero in instead of sliding it",
                        state: .seen, evidence: [.edit(FileChange(path: "src/hero/motion.ts", added: 5, removed: 8))],
                        agentLine: "Swapped the slide for a 0.3 s fade.", started: daysAgo(1, 11, 4), finished: daysAgo(1, 11, 9), result: .code))

        // api-server (主仓)
        projects.append(Project(id: "p-api", name: "api-server", paths: ["~/code/api-server"], lastVisit: daysAgo(2, 9, 30)))
        threads.append(ProjectThread(id: "t-auth", projectID: "p-api", name: "auth middleware", agent: .claudeCode,
                                     routing: route("dispatched to Claude Code · 4 auth tasks here went to it",
                                                    "routing  09-30 13:40  4 of 4 tasks touching src/middleware → Claude Code",
                                                    ["Codex · /me endpoint", "Codex · a new chat"])))
        runs.append(Run(id: "r-rate", threadID: "t-auth", words: "Add rate limiting to the login endpoint, 5 tries per minute per IP",
                        state: .failed,
                        failure: Failure(command: "npm test", exitCode: 1, tail: """
                        FAIL  test/auth.test.ts
                          ● login › locks out after 5 tries
                            expect(received).toBe(expected)
                            Expected: 429
                            Received: 200
                        Tests: 1 failed, 41 passed, 42 total
                        """),
                        evidence: [.search("rateLimit"),
                                   .edit(FileChange(path: "src/middleware/rateLimit.ts", kind: .added, added: 48, removed: 0, hunks: rateHunks)),
                                   .edit(FileChange(path: "src/routes/login.ts", added: 6, removed: 1, hunks: loginHunks)),
                                   .command(CommandResult("npm test", exit: 1))],
                        agentLine: "Added a per-IP limiter on /login; one test still sees 200 on the sixth try.",
                        started: minutesAgo(50), finished: minutesAgo(41), captureIDs: ["c-rate"], result: .code,
                        output: "Added express-rate-limit with a memory store.\nnpm test exited 1 (1 failed, 41 passed)."))
        threads.append(ProjectThread(id: "t-me", projectID: "p-api", name: "/me endpoint", agent: .codex,
                                     routing: route("dispatched to Codex · you said 主仓",
                                                    "routing  09-29 17:05  “主仓” = api-server (Memory › Terms)",
                                                    ["Claude Code · auth middleware"])))
        runs.append(Run(id: "r-me", threadID: "t-me", words: "把这个改动推到主仓：/me 里返回套餐名，价格页要用",
                        state: .seen,
                        evidence: [.edit(FileChange(path: "src/routes/me.ts", added: 4, removed: 0)),
                                   .command(CommandResult("npm test"))],
                        agentLine: "Returned plan.name from /me and added a test.", started: daysAgo(1, 17, 5),
                        finished: daysAgo(1, 17, 11), captureIDs: ["c-push"], result: .code))

        // app-ui-v1: the notch's own repo.
        projects.append(Project(id: "p-ui", name: "app-ui-v1", paths: ["~/Desktop/things/fovea/app-ui-v1"], lastVisit: minutesAgo(120)))
        threads.append(ProjectThread(id: "t-ears", projectID: "p-ui", name: "Notch ears", agent: .claudeCode,
                                     routing: route("dispatched to Claude Code · the frontmost window was Xcode",
                                                    "routing  09-30 13:58  Xcode · IslandShape.swift → app-ui-v1",
                                                    ["Codex · Referent stack"])))
        runs.append(Run(id: "r-ears", threadID: "t-ears",
                        words: "Make the ears on this one match the menu bar's height, and use the spacing from the second one.",
                        state: .finished,
                        evidence: [.edit(FileChange(path: "Prototypes/FoveaWorkbench/MockDesktop/IslandShape.swift",
                                                    added: 12, removed: 5, hunks: earHunks)),
                                   .command(CommandResult("swift build"))],
                        differences: ["Changed the bottom radius too, 14 → 12", "Used 10 pt spacing, not the 8 pt in the first capture"],
                        agentLine: "Matched the ear height to the 32 pt menu bar and took the 10 pt spacing from the second capture.",
                        started: minutesAgo(31), finished: minutesAgo(24), captureIDs: ["c-ears-1", "c-ears-2"], result: .code))
        threads.append(ProjectThread(id: "t-rail", projectID: "p-ui", name: "Choose chat rail", agent: .claudeCode,
                                     routing: route("dispatched to Claude Code · same repo as Notch ears",
                                                    "routing  09-30 14:12  cwd ~/Desktop/things/fovea/app-ui-v1",
                                                    ["Codex · Referent stack"])))
        runs.append(Run(id: "r-rail", threadID: "t-rail", words: "The rail's dot should sit 2 pt under the icon, not 4",
                        state: .running,
                        evidence: [.read("ChooseChat.swift"),
                                   .edit(FileChange(path: "WorkbenchTokens.swift", added: 1, removed: 1, hunks: railHunks))],
                        started: minutesAgo(4),
                        lastActions: ["Read ChooseChat.swift", "Edited WorkbenchTokens.swift +1 −1", "Running swift build"]))
        threads.append(ProjectThread(id: "t-stack", projectID: "p-ui", name: "Referent stack", agent: .codex,
                                     routing: route("dispatched to Codex · 6 stack tasks went to it",
                                                    "routing  09-27 10:40  6 of 7 ReferentStack tasks → Codex", ["Claude Code · Notch ears"])))
        runs.append(Run(id: "r-stack", threadID: "t-stack", words: "Cap the fan's overshoot in points, not percent",
                        state: .seen, evidence: [.edit(FileChange(path: "MockDesktop/ReferentStack.swift", added: 34, removed: 6)),
                                                 .command(CommandResult("swift build"))],
                        agentLine: "Added CappedOvershoot with a 12 pt cap.", started: daysAgo(3, 10, 40), finished: daysAgo(3, 10, 52), result: .code))

        // fovea-mac
        projects.append(Project(id: "p-mac", name: "fovea-mac", paths: ["~/Desktop/things/fovea/fovea-mac"], lastVisit: daysAgo(1, 9, 0)))
        threads.append(ProjectThread(id: "t-progress", projectID: "p-mac", name: "VoiceFlow 进度条", agent: .codex,
                                     routing: route("dispatched to Codex · 3 VoiceFlow tasks went to it",
                                                    "routing  09-30 11:20  3 of 3 VoiceFlow tasks → Codex", ["Claude Code · Memory batch 4"])))
        runs.append(Run(id: "r-progress", threadID: "t-progress", words: "进度条的颜色换成白色 0.85，轨道 0.14",
                        state: .finished,
                        evidence: [.edit(FileChange(path: "FoveaMac/Widgets/VoiceProgress.swift", added: 2, removed: 2)),
                                   .command(CommandResult("xcodebuild -scheme FoveaMac build"))],
                        agentLine: "Set the fill to white 0.85 and the track to 0.14.", started: minutesAgo(190), finished: minutesAgo(181),
                        captureIDs: ["c-progress"], result: .code))
        threads.append(ProjectThread(id: "t-memory", projectID: "p-mac", name: "Memory batch 4", agent: .claudeCode,
                                     routing: route("dispatched to Claude Code · the batch's spec named it",
                                                    "routing  09-26 15:00  docs/memory-batch4 → Claude Code", ["Codex · VoiceFlow 进度条"])))
        runs.append(Run(id: "r-memory", threadID: "t-memory", words: "Finish batch 4 and run the whole memory suite",
                        state: .seen, evidence: [.edit(FileChange(path: "FoveaMac/Models/MemoryStore.swift", added: 120, removed: 41)),
                                                 .command(CommandResult("xcodebuild test -scheme FoveaMac"))],
                        agentLine: "Batch 4 is in; 212 tests pass.", started: daysAgo(4, 15, 0), finished: daysAgo(4, 16, 20), result: .code))

        // waitlist: a question, and a result in Mail.
        projects.append(Project(id: "p-wait", name: "waitlist", paths: ["~/code/waitlist"], lastVisit: daysAgo(1, 10, 0)))
        threads.append(ProjectThread(id: "t-email", projectID: "p-wait", name: "Welcome email", agent: .cursor,
                                     routing: route("dispatched to Cursor · the frontmost window was Mail",
                                                    "routing  09-30 13:10  Mail · Draft “Welcome to Fovea” → waitlist",
                                                    ["Claude Code · a new chat"])))
        runs.append(Run(id: "r-email", threadID: "t-email", words: "Draft the welcome email from these notes, short, no exclamation marks",
                        state: .waiting, stuck: .question("Send it when they join, or after they confirm their address?",
                                                          options: ["When they join", "After they confirm"]),
                        evidence: [.read("notes/welcome.md")], started: minutesAgo(80), captureIDs: ["c-mail"],
                        result: .external(app: "Mail", title: "Draft · Welcome to Fovea", detail: "To: new signups · 112 words")))

        // design-tokens: handed off to a session Fovea can't watch.
        projects.append(Project(id: "p-tokens", name: "design-tokens", paths: ["~/code/design-tokens"]))
        threads.append(ProjectThread(id: "t-dark", projectID: "p-tokens", name: "Dark palette", agent: .cursor,
                                     routing: route("handed to your open Cursor window · it was frontmost",
                                                    "routing  09-30 12:02  Cursor · design-tokens (no hooks for this window)",
                                                    ["Claude Code · a new chat"]),
                                     observable: false))
        runs.append(Run(id: "r-dark", threadID: "t-dark", words: "Dark palette: use the notch's ladder for the neutrals",
                        state: .unobserved, started: minutesAgo(148), captureIDs: ["c-dark"]))

        // team-calendar: a result that lives in Calendar.
        projects.append(Project(id: "p-cal", name: "team-calendar", paths: ["~/code/team-calendar"]))
        threads.append(ProjectThread(id: "t-review", projectID: "p-cal", name: "Design review", agent: .claudeCode,
                                     routing: route("dispatched to Claude Code · it has your calendar tools",
                                                    "routing  09-30 10:05  Calendar MCP → Claude Code", ["Codex · a new chat"])))
        runs.append(Run(id: "r-review", threadID: "t-review", words: "Set up a design review with Lin on Thursday morning, 45 minutes",
                        state: .finished, evidence: [.command(CommandResult("calendar.create_event"))],
                        agentLine: "Booked Thursday 10:00–10:45 with Lin and attached the notch notes.",
                        started: minutesAgo(265), finished: minutesAgo(262), captureIDs: ["c-lin"],
                        result: .external(app: "Calendar", title: "Design review · Thu 10:00–10:45", detail: "With Lin · Room 3 · notes attached"),
                        output: "calendar.create_event → created \"Design review with Lin\"\n  Thu 2026-10-02 10:00–10:45 · Room 3\n  attendees: lin@ · attachments: notch-notes.md"))

        // onboarding-research: a document.
        projects.append(Project(id: "p-research", name: "onboarding-research", paths: ["~/Documents/research"]))
        threads.append(ProjectThread(id: "t-notes", projectID: "p-research", name: "Interview notes", agent: .claudeCode,
                                     routing: route("dispatched to Claude Code · you dropped a file on it",
                                                    "routing  09-29 16:40  interview-notes-0926.md → Claude Code", ["Codex · a new chat"])))
        runs.append(Run(id: "r-notes", threadID: "t-notes", words: "把这几份访谈记录整理成要点，按出现次数排",
                        state: .seen, evidence: [.read("interview-notes-0926.md"), .edit(FileChange(path: "summary.md", kind: .added, added: 38, removed: 0))],
                        agentLine: "Grouped 6 interviews into 5 themes, most mentioned first.",
                        started: daysAgo(1, 16, 40), finished: daysAgo(1, 16, 47), captureIDs: ["c-notes-file"],
                        result: .text(notesMarkdown),
                        output: "Read interview-notes-0926.md (6 interviews, 4,212 words)\nWrote summary.md: 5 themes, 38 lines", reviewed: true))

        // landing-images: an image.
        projects.append(Project(id: "p-images", name: "landing-images", paths: ["~/code/fovea-site/public"]))
        threads.append(ProjectThread(id: "t-photo", projectID: "p-images", name: "Hero photo", agent: .codex,
                                     routing: route("dispatched to Codex · it handles images here",
                                                    "routing  09-28 09:12  3 of 3 image tasks → Codex", ["Claude Code · hero 动效"])))
        runs.append(Run(id: "r-photo", threadID: "t-photo", words: "Use this as the hero image, crop it to 16:9",
                        state: .seen, evidence: [.edit(FileChange(path: "public/hero.jpg", kind: .added, added: 0, removed: 0))],
                        agentLine: "Cropped to 1920×1080 and replaced public/hero.jpg.",
                        started: daysAgo(2, 9, 12), finished: daysAgo(2, 9, 14), captureIDs: ["c-photo"],
                        result: .image("Art/mountain-16x9", caption: "public/hero.jpg · 1920×1080"),
                        output: "sips --cropToHeightWidth 1080 1920 hero-source.jpg --out public/hero.jpg\n/Users/…/public/hero.jpg"))

        // Merge candidates: the same work under a second name.
        projects.append(Project(id: "p-site2", name: "fovea-website", paths: ["~/code/fovea-site"]))
        threads.append(ProjectThread(id: "t-site2", projectID: "p-site2", name: "OG image", agent: .claudeCode,
                                     routing: route("dispatched to Claude Code", "routing  09-12 11:00", [])))
        runs.append(Run(id: "r-og", threadID: "t-site2", words: "Make the OG image use the new wordmark", state: .seen,
                        evidence: [.edit(FileChange(path: "public/og.png", added: 0, removed: 0))], agentLine: "Done.",
                        started: daysAgo(18, 11, 0), finished: daysAgo(18, 11, 6), result: .code))
        projects.append(Project(id: "p-api2", name: "api", paths: ["~/code/api-server"]))
        threads.append(ProjectThread(id: "t-api2", projectID: "p-api2", name: "health check", agent: .codex,
                                     routing: route("dispatched to Codex", "routing  09-10 15:00", [])))
        runs.append(Run(id: "r-health", threadID: "t-api2", words: "Add a /healthz route that checks the database", state: .seen,
                        evidence: [.edit(FileChange(path: "src/routes/health.ts", kind: .added, added: 22, removed: 0)),
                                   .command(CommandResult("npm test"))], agentLine: "Added /healthz with a 200 ms DB ping.",
                        started: daysAgo(20, 15, 0), finished: daysAgo(20, 15, 8), result: .code))

        // Twelve projects that sank: quiet for more than a week.
        let older: [(String, String, AgentKind, String, Int)] = [
            ("pricing-page", "定价页 A/B", .codex, "Two pricing layouts behind a flag", 9),
            ("blog-migration", "MDX import", .claudeCode, "Move the old posts to MDX and keep their URLs", 10),
            ("figma-plugin", "Token export", .cursor, "Export the color styles as JSON tokens", 11),
            ("docs-site", "Search", .codex, "Add Algolia search to the docs", 12),
            ("cli-tool", "Release script", .claudeCode, "Write a release script that tags and pushes", 13),
            ("infra", "Staging certs", .codex, "Renew the staging certificates and add a reminder", 15),
            ("invoice-bot", "PDF layout", .cursor, "Make the invoice PDF fit on one page", 16),
            ("resume-site", "部署", .claudeCode, "把简历网站部署到 Vercel", 18),
            ("chrome-extension", "Popup", .codex, "The popup should remember the last tab", 21),
            ("data-cleanup", "Dedupe", .claudeCode, "Find duplicate signups by email, case-insensitive", 23),
            ("translate-strings", "日文", .cursor, "Translate the onboarding strings to Japanese", 25),
            ("ios-companion", "Widget", .codex, "A small widget that shows the last run", 28),
        ]
        for (i, item) in older.enumerated() {
            let pid = "p-old-\(i)", tid = "t-old-\(i)"
            projects.append(Project(id: pid, name: item.0, paths: ["~/code/\(item.0)"]))
            threads.append(ProjectThread(id: tid, projectID: pid, name: item.1, agent: item.2,
                                         routing: route("dispatched to \(item.2.name)", "routing  \(Lines.day(daysAgo(item.4, 10, 0)))", [])))
            let started = daysAgo(item.4, 10 + i % 6, 5 * i % 60)
            runs.append(Run(id: "r-old-\(i)", threadID: tid, words: item.3, state: .seen,
                            evidence: [.edit(FileChange(path: "src/index.ts", added: 10 + i, removed: i)), .command(CommandResult("npm test"))],
                            agentLine: "Done.", started: started, finished: started.addingTimeInterval(600), result: .code))
        }

        return Library(now: now, projects: projects, threads: threads, runs: runs, captures: captures(),
                       agents: agents(), memory: memory(), merges: merges(), briefs: briefs())
    }

    // MARK: Captures

    static func captures() -> [Capture] {
        [
            Capture(id: "c-voice-title", kind: .voice, time: minutesAgo(28), sourceApp: nil,
                    transcript: "把第二屏的标题改短一点，副标题保留，按钮文案不用动", preview: .voice(seconds: 6.2),
                    destination: .run("r-deploy"),
                    reason: route("went to 第二屏文案 because the frontmost window was localhost:3000",
                                  "routing  09-30 14:02  Safari · localhost:3000 → fovea-site › 第二屏文案", ["hero 动效 · Claude Code", "a quick task"])),
            Capture(id: "c-site-shot", kind: .screenshot, time: minutesAgo(53), sourceApp: "Safari", windowTitle: "localhost:3000",
                    transcript: "这一屏的三条 bullet 改成动词开头", preview: .image("Art/localhost-why"), destination: .run("r-bullets"),
                    reason: route("went to 第二屏文案 because the frontmost window was localhost:3000",
                                  "routing  09-30 13:37  Safari · localhost:3000 → fovea-site", ["hero 动效 · Claude Code", "a quick task"]),
                    recognizedText: "Why Fovea\nPoint at anything on your screen and send it to your coding agent.\nFovea sees what you point at\nCircle a region while you talk; its text comes along.\nYou say where it goes\nName the project, or let Fovea pick the chat.\nYour agent gets the context\nYour words, and every region, in the order you made them.\nJoin the waitlist"),
            Capture(id: "c-draft", kind: .selection, time: minutesAgo(53), sourceApp: "Notes", windowTitle: "第二屏文案草稿",
                    transcript: "用这段做参考", preview: .text("Point at anything. Say what you want. Send it to your agent."),
                    destination: .run("r-bullets")),
            Capture(id: "c-eight", kind: .voice, time: minutesAgo(52), sourceApp: nil,
                    transcript: "Keep each of them under eight words", preview: .voice(seconds: 2.4), destination: .run("r-bullets")),
            Capture(id: "c-hero-voice", kind: .voice, time: minutesAgo(9), sourceApp: nil,
                    transcript: "hero 进场的动画太快了，放慢一点并且去掉回弹", preview: .voice(seconds: 4.8), destination: .run("r-hero"),
                    reason: route("went to hero 动效 because you said “让 Claude 来” yesterday",
                                  "routing  09-30 14:21  Memory: you said “让 Claude 来” on 09-29", ["第二屏文案 · Codex", "a quick task"])),
            Capture(id: "c-ears-1", kind: .screenshot, time: minutesAgo(31), sourceApp: "Xcode", windowTitle: "IslandShape.swift",
                    transcript: "Make the ears on this one match the menu bar's height", preview: .image("Art/xcode-islandshape"),
                    destination: .run("r-ears"),
                    reason: route("went to Notch ears because the frontmost window was Xcode · IslandShape.swift",
                                  "routing  09-30 13:59  Xcode · app-ui-v1 → Notch ears", ["Choose chat rail · Claude Code"]),
                    recognizedText: "struct IslandShape: Shape {\nvar topRadius: CGFloat\nvar bottomRadius: CGFloat\nvar animatableData: AnimatablePair<CGFloat, CGFloat> {\nfunc path(in rect: CGRect) -> Path {\np.addQuadCurve(to: CGPoint(x: rect.minX + tr, y: rect.minY + tr),"),
            Capture(id: "c-ears-2", kind: .screenshot, time: minutesAgo(31), sourceApp: "FoveaWorkbench", windowTitle: "Notch Workbench",
                    transcript: "and use the spacing from the second one", preview: .image("Art/workbench-notches"), destination: .run("r-ears")),
            Capture(id: "c-rate", kind: .voice, time: minutesAgo(50), sourceApp: nil,
                    transcript: "Add rate limiting to the login endpoint, 5 tries per minute per IP", preview: .voice(seconds: 4.1),
                    destination: .run("r-rate")),
            Capture(id: "c-quick-spring", kind: .voice, time: minutesAgo(70), sourceApp: nil,
                    transcript: "interpolatingSpring 和 smooth 的区别是什么？", preview: .voice(seconds: 3.0), destination: .quickTask),
            Capture(id: "c-progress", kind: .voice, time: minutesAgo(190), sourceApp: nil,
                    transcript: "进度条的颜色换成白色 0.85，轨道 0.14", preview: .voice(seconds: 3.6), destination: .run("r-progress")),
            Capture(id: "c-mail", kind: .selection, time: minutesAgo(80), sourceApp: "Mail", windowTitle: "Draft · Welcome to Fovea",
                    transcript: "Draft the welcome email from these notes, short, no exclamation marks",
                    preview: .text("Thanks for joining. You'll hear from us when your Mac is in the next batch."),
                    destination: .run("r-email")),
            Capture(id: "c-lin", kind: .voice, time: minutesAgo(265), sourceApp: nil,
                    transcript: "Set up a design review with Lin on Thursday morning, 45 minutes", preview: .voice(seconds: 3.9),
                    destination: .run("r-review")),
            Capture(id: "c-dark", kind: .voice, time: minutesAgo(148), sourceApp: nil,
                    transcript: "Dark palette: use the notch's ladder for the neutrals", preview: .voice(seconds: 3.2),
                    destination: .run("r-dark")),
            Capture(id: "c-quick-index", kind: .voice, time: minutesAgo(300), sourceApp: nil,
                    transcript: "Is the waitlist table indexed on email?", preview: .voice(seconds: 2.2), destination: .quickTask),
            Capture(id: "c-downloads", kind: .screenshot, time: minutesAgo(340), sourceApp: "Finder", windowTitle: "Downloads",
                    transcript: "", preview: .image("Art/finder-downloads"), destination: .notUsed,
                    recognizedText: "Name\nDate Modified\nSize\nfovea-logo-v3.zip\nlin-room-3-map.png\ninterview-notes-0926.md\nScreen Recording 2026-09-30 at 11.12.mov\ninvoice-0930.pdf\nhero-mountain.jpg\nNotch study.key\nwaitlist-export.csv\nSF Mono specimen.pdf\npricing-v2.fig\ndemo-voiceover.m4a\nArchive.zip"),
            Capture(id: "c-stripe", kind: .screenshot, time: daysAgo(1, 15, 22), sourceApp: "Safari", windowTitle: "API reference · Rate limits",
                    transcript: "Remember this limit", preview: .image("Art/docs-rate-limits"), destination: .notUsed,
                    recognizedText: "Authentication\nErrors\nPagination\nRate limits\nVersioning\nWebhooks\nRate limits\nThe API allows up to 100 read requests per second per account and 100 write requests per second per account. Requests over the limit receive a 429 response.\nMode Reads Writes\nLive 100 per second 100 per second\nTest 25 per second 25 per second"),
            Capture(id: "c-push", kind: .voice, time: daysAgo(1, 17, 5), sourceApp: nil,
                    transcript: "把这个改动推到主仓：/me 里返回套餐名，价格页要用", preview: .voice(seconds: 4.4), destination: .run("r-me")),
            Capture(id: "c-notes-file", kind: .file, time: daysAgo(1, 16, 40), sourceApp: "Finder",
                    transcript: "把这几份访谈记录整理成要点，按出现次数排", preview: .file(name: "interview-notes-0926.md", kind: "Markdown"),
                    destination: .run("r-notes")),
            Capture(id: "c-photo", kind: .screenshot, time: daysAgo(2, 9, 12), sourceApp: "Photos", windowTitle: "Library",
                    transcript: "Use this as the hero image, crop it to 16:9", preview: .image("Photos/mountain.jpg"), destination: .run("r-photo")),
            Capture(id: "c-quick-path", kind: .selection, time: daysAgo(2, 11, 30), sourceApp: "Xcode", windowTitle: "IslandShape.swift",
                    transcript: "What does addQuadCurve's control point do here?",
                    preview: .text("p.addQuadCurve(to: CGPoint(x: rect.minX + tr, y: ey + tr), control: CGPoint(x: rect.minX + tr, y: ey))"),
                    destination: .quickTask),
            Capture(id: "c-quick-ship", kind: .voice, time: daysAgo(3, 18, 2), sourceApp: nil,
                    transcript: "What shipped in fovea-mac this week?", preview: .voice(seconds: 2.0), destination: .quickTask),
        ]
    }

    // MARK: Memory, merges, briefs

    static func memory() -> [MemoryItem] {
        [
            MemoryItem(id: "m-main", kind: .term, content: "“主仓” = api-server", sourceDate: daysAgo(12, 10, 2),
                       sourceQuote: "把这个改动推到主仓"),
            MemoryItem(id: "m-second", kind: .term, content: "“第二屏” = the Features section of fovea-site", sourceDate: daysAgo(9, 15, 30),
                       sourceQuote: "第二屏的按钮改成“开始”", scope: "fovea-site"),
            MemoryItem(id: "m-ears", kind: .term, content: "“ears” = the notch's concave top corners", sourceDate: daysAgo(3, 14, 0),
                       sourceQuote: "make the ears match the menu bar", scope: "app-ui-v1"),
            MemoryItem(id: "m-noask", kind: .memory, content: "Prefers agents not to stop to confirm mid-task", sourceDate: daysAgo(12, 18, 40),
                       sourceQuote: "别半路问我"),
            MemoryItem(id: "m-eight", kind: .memory, content: "Keeps bullets under eight words", sourceDate: daysAgo(0, 13, 38),
                       sourceQuote: "Keep each of them under eight words", scope: "fovea-site"),
            MemoryItem(id: "m-claude", kind: .memory, content: "Sends motion work to Claude Code", sourceDate: daysAgo(1, 19, 2),
                       sourceQuote: "动效让 Claude 来"),
        ]
    }

    static func merges() -> [MergeSuggestion] {
        [
            MergeSuggestion(id: "merge-site", first: "p-site", second: "p-site2",
                            evidence: [MergeEvidence("same repo", "~/code/fovea-site"), MergeEvidence("both active", "09-12 → 09-29")]),
            MergeSuggestion(id: "merge-api", first: "p-api", second: "p-api2",
                            evidence: [MergeEvidence("same remote", "github.com/fovea/api-server"),
                                       MergeEvidence("named", "api (Codex) · api-server (Claude Code)")]),
        ]
    }

    static func briefs() -> [String: BriefDoc] {
        [
            "p-site": BriefDoc(agent: .claudeCode, written: minutesAgo(28), markdown: """
            **Where fovea-site stands**

            - The second screen's title change is ready; it waits on your OK to deploy a preview.
            - The bullets now start with verbs. Codex also changed the eyebrow to “How”.
            - Hero motion is being slowed down; the visual tests are running.

            **Open question**

            Keep the fade on the hero, or bring the slide back at the slower speed?
            """),
            "p-api": BriefDoc(agent: .codex, written: minutesAgo(40), markdown: """
            **api-server this week**

            - /me returns the plan name; the pricing page reads it.
            - The login rate limiter is in, but one test still sees 200 on the sixth try: the limiter is keyed on `req.ip`, which is the proxy behind the load balancer.
            """),
        ]
    }

    static let notesMarkdown = """
    ## Onboarding interviews · 6 people

    **1. Setup takes too long** (5 of 6)
    Most stopped at the Accessibility prompt and didn't know why it was needed.

    **2. They want to see their history right away** (4 of 6)
    “Show me what I already did, then I'll trust it.”

    **3. The notch is easy to miss** (3 of 6)
    Two looked for a menu bar icon first.

    **4. Voice in public is awkward** (2 of 6)

    **5. Pricing questions came last** (1 of 6)
    """

    // MARK: Diffs

    static let secondHunks: [DiffHunk] = [
        DiffHunk(header: "@@ -12,9 +12,9 @@ export const second = {", lines: [
            DiffLine(.removed, old: 12, new: nil, "  eyebrow: \"Why\","),
            DiffLine(.added, old: nil, new: 12, "  eyebrow: \"How\","),
            DiffLine(.context, old: 13, new: 13, "  title: \"Point at it. Say it. Done.\","),
            DiffLine(.context, old: 14, new: 14, "  bullets: ["),
            DiffLine(.removed, old: 15, new: nil, "    \"Fovea sees what you point at\","),
            DiffLine(.removed, old: 16, new: nil, "    \"You say where it goes\","),
            DiffLine(.removed, old: 17, new: nil, "    \"Your agent gets the context\","),
            DiffLine(.added, old: nil, new: 15, "    \"Point at anything on screen\","),
            DiffLine(.added, old: nil, new: 16, "    \"Say what you want done\","),
            DiffLine(.added, old: nil, new: 17, "    \"Send it to your agent\","),
            DiffLine(.context, old: 18, new: 18, "  ],"),
            DiffLine(.context, old: 19, new: 19, "};"),
        ]),
    ]

    static let heroHunks: [DiffHunk] = [
        DiffHunk(header: "@@ -4,8 +4,8 @@ export const heroIn = {", lines: [
            DiffLine(.context, old: 4, new: 4, "  opacity: [0, 1],"),
            DiffLine(.removed, old: 5, new: nil, "  duration: 0.4,"),
            DiffLine(.removed, old: 6, new: nil, "  easing: spring(1, 80, 10, 0),"),
            DiffLine(.removed, old: 7, new: nil, "  overshootClamping: false,"),
            DiffLine(.added, old: nil, new: 5, "  duration: 0.6,"),
            DiffLine(.added, old: nil, new: 6, "  easing: spring(1, 80, 16, 0),"),
            DiffLine(.added, old: nil, new: 7, "  overshootClamping: true,"),
            DiffLine(.context, old: 8, new: 8, "  delay: 0.05,"),
            DiffLine(.context, old: 9, new: 9, "};"),
        ]),
    ]

    static let railHunks: [DiffHunk] = [
        DiffHunk(header: "@@ -88,3 +88,3 @@ enum ChooseChat {", lines: [
            DiffLine(.context, old: 88, new: 88, "    static let rowHeight: CGFloat = 28"),
            DiffLine(.removed, old: 89, new: nil, "    static let dotGap: CGFloat = 4"),
            DiffLine(.added, old: nil, new: 89, "    static let chosenDotGap: CGFloat = 2"),
            DiffLine(.context, old: 90, new: 90, "    static let iconSize: CGFloat = 16"),
        ]),
    ]

    static let earHunks: [DiffHunk] = [
        DiffHunk(header: "@@ -20,11 +20,18 @@ struct IslandShape: Shape {", lines: [
            DiffLine(.context, old: 20, new: 20, "    var topRadius: CGFloat"),
            DiffLine(.context, old: 21, new: 21, "    var bottomRadius: CGFloat"),
            DiffLine(.removed, old: 22, new: nil, "    static let earHeight: CGFloat = 28"),
            DiffLine(.added, old: nil, new: 22, "    static let earHeight: CGFloat = 32"),
            DiffLine(.added, old: nil, new: 23, "    /// From the second capture: the ears sit 10 pt from the content."),
            DiffLine(.added, old: nil, new: 24, "    static let earSpacing: CGFloat = 10"),
            DiffLine(.removed, old: 23, new: nil, "    static let bottom: CGFloat = 14"),
            DiffLine(.added, old: nil, new: 25, "    static let bottom: CGFloat = 12"),
            DiffLine(.context, old: 24, new: 26, ""),
            DiffLine(.context, old: 25, new: 27, "    func path(in rect: CGRect) -> Path {"),
        ]),
    ]

    static let rateHunks: [DiffHunk] = [
        DiffHunk(header: "@@ -0,0 +1,14 @@", lines: [
            DiffLine(.added, old: nil, new: 1, "import rateLimit from \"express-rate-limit\";"),
            DiffLine(.added, old: nil, new: 2, ""),
            DiffLine(.added, old: nil, new: 3, "export const loginLimiter = rateLimit({"),
            DiffLine(.added, old: nil, new: 4, "  windowMs: 60 * 1000,"),
            DiffLine(.added, old: nil, new: 5, "  limit: 5,"),
            DiffLine(.added, old: nil, new: 6, "  keyGenerator: (req) => req.ip,"),
            DiffLine(.added, old: nil, new: 7, "  standardHeaders: true,"),
            DiffLine(.added, old: nil, new: 8, "});"),
        ]),
    ]

    static let loginHunks: [DiffHunk] = [
        DiffHunk(header: "@@ -3,7 +3,12 @@ import { Router } from \"express\";", lines: [
            DiffLine(.context, old: 3, new: 3, "import { Router } from \"express\";"),
            DiffLine(.added, old: nil, new: 4, "import { loginLimiter } from \"../middleware/rateLimit\";"),
            DiffLine(.context, old: 4, new: 5, ""),
            DiffLine(.removed, old: 5, new: nil, "router.post(\"/login\", login);"),
            DiffLine(.added, old: nil, new: 6, "router.post(\"/login\", loginLimiter, login);"),
        ]),
    ]

    // MARK: Other sets

    /// Thirty more projects with busy threads: scrolling, folding and moving between groups.
    static func heavy() -> Library {
        var library = typical()
        let words = ["Rename the config flag", "把错误提示写清楚", "Add a test for the empty state", "Cache the avatar images",
                     "去掉没用的依赖", "Make the table sortable", "Log the request id", "Bump the SDK and fix the warnings"]
        let states: [RunState] = [.seen, .seen, .finished, .running, .seen, .failed, .seen, .waiting, .seen, .unobserved]
        for i in 0..<30 {
            let pid = "p-heavy-\(i)"
            library.projects.append(Project(id: pid, name: "service-\(String(format: "%02d", i))", paths: ["~/code/service-\(i)"]))
            for t in 0..<3 {
                let tid = "\(pid)-t\(t)"
                let agent = AgentKind.allCases[(i + t) % 3]
                library.threads.append(ProjectThread(id: tid, projectID: pid, name: ["API", "UI", "Tests"][t], agent: agent,
                                                     routing: route("dispatched to \(agent.name)", "routing", [])))
                for r in 0..<8 {
                    let state = r == 0 ? states[(i + t) % states.count] : .seen
                    let started = minutesAgo(Double(30 + i * 120 + t * 40 + r * 300))
                    library.runs.append(Run(id: "\(tid)-r\(r)", threadID: tid, words: words[(i + t + r) % words.count], state: state,
                                            evidence: [.edit(FileChange(path: "src/\(t)/\(r).ts", added: r + 2, removed: r)),
                                                       .command(CommandResult("npm test", exit: state == .failed ? 1 : 0))],
                                            agentLine: "Done.", started: started,
                                            finished: state == .running || state == .waiting ? nil : started.addingTimeInterval(300),
                                            result: .code, lastActions: ["Running npm test"]))
                }
            }
        }
        return library
    }

    /// Everything too long: where truncation and wrapping show.
    static func longNames() -> Library {
        var library = typical()
        for i in library.projects.indices {
            library.projects[i].name += "-with-a-much-longer-repository-name-than-anyone-would-choose-on-purpose-but-monorepos-do"
            library.projects[i].paths = library.projects[i].paths.map { $0 + "/packages/web/apps/marketing/src/sections/second-screen" }
        }
        for i in library.threads.indices {
            library.threads[i].name += " · 这是一个非常非常长的线程名字，用来测试截断"
        }
        for i in library.runs.indices {
            library.runs[i].words += " — and then a second clause that keeps going well past the width of the window so the row has to cut it somewhere sensible"
            if let line = library.runs[i].agentLine {
                library.runs[i].agentLine = line + " I also checked the other two screens, left the copy there alone, and noted where the spacing still differs."
            }
        }
        for i in library.captures.indices where !library.captures[i].transcript.isEmpty {
            library.captures[i].transcript += ", and then I kept talking for a while about the spacing, the colors and the second screen"
        }
        return library
    }

    /// Agents missing or unhooked, and more runs failing.
    static func errors() -> Library {
        var library = typical()
        if let i = library.agents.firstIndex(where: { $0.kind == .cursor }) {
            library.agents[i].state = .hooksMissing
            library.agents[i].lastEvent = nil
            // One of Cursor's two folders can't be listed; the other still counts.
            library.agents[i].historyReadErrors = ["~/.cursor/chats": .denied]
        }
        if let i = library.agents.firstIndex(where: { $0.kind == .codex }) {
            library.agents[i].state = .notFound
            library.agents[i].version = nil
            library.agents[i].binaryPath = nil
            library.agents[i].lastEvent = nil
        }
        for id in ["r-bullets", "r-ears", "r-progress"] {
            if let i = library.runs.firstIndex(where: { $0.id == id }) {
                library.runs[i].state = .failed
                library.runs[i].failure = Failure(command: "npm test", exitCode: 1, tail: "1 failed, 12 passed")
            }
        }
        return library
    }
}

import Foundation

public enum FixtureSet: String, CaseIterable, Hashable, Sendable {
    case typical, weekOnly, empty, longText

    public var title: String {
        switch self {
        case .typical: return "A year of use"
        case .weekOnly: return "Just this week"
        case .empty: return "First launch"
        case .longText: return "Long text"
        }
    }
}

/// Two weeks of a person using Fovea: dictations into everyday apps, captures that put words and
/// what they took into the app in front, dispatches to coding agents (requests and quick
/// questions). In English and Chinese, as Ryan uses it.
public enum Fixtures {
    /// Friday Oct 3 2026, 14:30 in Cupertino.
    public static let now: Date = {
        var c = DateComponents()
        // Late in a month, a Saturday, so the first page has a month of cards to scroll.
        c.year = 2026; c.month = 9; c.day = 26; c.hour = 14; c.minute = 30
        return Lines.calendar.date(from: c)!
    }()

    static func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
    static func daysAgo(_ d: Int, _ h: Int, _ m: Int) -> Date {
        let day = Lines.calendar.date(byAdding: .day, value: -d, to: Lines.calendar.startOfDay(for: now))!
        return day.addingTimeInterval(Double(h * 3600 + m * 60))
    }

    public enum Apps {
        public static let slack = AppRef("Slack", "com.tinyspeck.slackmacgap")
        public static let notes = AppRef("Notes", "com.apple.Notes")
        public static let mail = AppRef("Mail", "com.apple.mail")
        public static let xcode = AppRef("Xcode", "com.apple.dt.Xcode")
        public static let safari = AppRef("Safari", "com.apple.Safari")
        public static let chrome = AppRef("Chrome", "com.google.Chrome")
        public static let figma = AppRef("Figma", "com.figma.Desktop")
        public static let notion = AppRef("Notion", "notion.id")
        public static let messages = AppRef("Messages", "com.apple.MobileSMS")
        public static let wechat = AppRef("WeChat", "com.tencent.xinWeChat")
        public static let finder = AppRef("Finder", "com.apple.finder")
        public static let calendar = AppRef("Calendar", "com.apple.iCal")
        public static let obsidian = AppRef("Obsidian", "md.obsidian")
        public static let numbers = AppRef("Numbers", "com.apple.iWork.Numbers")
    }

    public enum Agents {
        public static let claudeCode = "Claude Code"
        public static let codex = "Codex"
    }

    public static func library(_ set: FixtureSet) -> Library {
        switch set {
        case .typical:
            return Library(now: now, captures: captures() + history(), dictionary: dictionary(), memories: memories(), usage: usage(),
                           areas: areas())
        case .weekOnly:
            return Library(now: now, captures: captures(), dictionary: dictionary(), memories: memories(includeHistory: false),
                           usage: usage(), areas: areas())
        case .empty:
            return Library(now: now, captures: [], dictionary: [], memories: [],
                           usage: Usage(plan: "Free", used: 0, total: 2_000, resets: daysAgo(-4, 0, 0)))
        case .longText:
            // Appended at the end, so every attachment keeps its place.
            let long = captures().map { c -> Capture in
                if c.failed { return c }
                var c = c
                let more = c.text.unicodeScalars.contains(where: { (0x4E00...0x9FFF).contains($0.value) })
                    ? "，然后我又说了很久关于第二屏的间距、颜色和按钮文案的事情，一直说到最后一个按钮。"
                    : " And then a second paragraph that keeps going well past what any card can show, about the spacing, the colors and the button copy on the second screen, so the card has to cut it somewhere that still reads."
                c.text += more
                return c
            }
            return Library(now: now, captures: long, dictionary: dictionary(), memories: memories(includeHistory: false),
                           usage: usage(), areas: areas())
        }
    }

    /// Thirteen months before this week, the way a year of use looks: busier on weekdays than
    /// at weekends, quieter a year ago than now, two trips with nothing at all, a few heavy days.
    /// Each day's captures reuse this week's words (the archive needs cards, not new prose), at
    /// times spread through the working day. Deterministic: the same every run.
    public static func history(from first: Int = 7, through last: Int = 980) -> [Capture] {
        let base = captures().filter { !$0.failed }
        var rng = Seeded(seed: 0x5EED_F0FE)
        var out: [Capture] = []
        for d in first...last {
            let day = daysAgo(d, 0, 0)
            let weekday = Lines.calendar.component(.weekday, from: day)   // 1 = Sunday
            let weekend = weekday == 1 || weekday == 7
            // Two trips: late July, and early-to-mid April.
            if (62...66).contains(d) || (172...185).contains(d) { continue }
            // The last year ramps up to now; before it, the first months of use, quieter (back
            // to January 2024, so the calendar has three years).
            let growth = d <= 400 ? 0.35 + 0.65 * (1 - Double(d - first) / Double(400 - first)) : 0.3
            var rate = (weekend ? 1.2 : 6.0) * growth
            if rng.next() < 0.05 { rate *= 2.6 }          // a heavy day
            if rng.next() < (weekend ? 0.45 : 0.08) { rate = 0 } // a day off
            let n = Int((rate * (0.55 + 0.9 * rng.next())).rounded())
            guard n > 0 else { continue }
            for i in 0..<n {
                var c = base[(d * 7 + i * 3) % base.count]
                c.id = "h\(d)-\(i)"
                let minutes = 9 * 60 + Int(Double(i) / Double(n) * 11 * 60) + Int(rng.next() * 40)
                c.time = day.addingTimeInterval(Double(minutes * 60))
                out.append(c)
            }
        }
        return out
    }

    /// A small deterministic generator (SplitMix64), so history is the same on every launch.
    struct Seeded {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> Double {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            z ^= z >> 31
            return Double(z >> 11) / Double(1 << 53)
        }
    }

    public static func usage() -> Usage {
        Usage(plan: "Pro", used: 3_160, total: 5_000, resets: daysAgo(-4, 0, 0))
    }

    // MARK: Building blocks

    /// "fix {this}⟨1⟩ and {that one}⟨2⟩": the words without the marks; each attachment anchored
    /// where its ⟨n⟩ was, and bound to the words in braces just before it (the words you pointed
    /// with), so a fixture reads as what was said, where each thing was taken, and what it meant.
    static func anchored(_ marked: String, _ attachments: [Attachment]) -> (String, [Attachment]) {
        var out = ""
        var anchors: [Int: Int] = [:]
        var bounds: [Int: Int] = [:]
        var openBrace: Int?
        var lastBound = 0
        var i = marked.startIndex
        while i < marked.endIndex {
            let c = marked[i]
            if c == "{" { openBrace = out.utf16.count; i = marked.index(after: i); continue }
            if c == "}", let start = openBrace {
                lastBound = out.utf16.count - start
                openBrace = nil
                i = marked.index(after: i)
                continue
            }
            if c == "⟨", let close = marked[i...].firstIndex(of: "⟩"),
               let n = Int(marked[marked.index(after: i)..<close]) {
                anchors[n] = out.utf16.count
                bounds[n] = lastBound
                lastBound = 0
                i = marked.index(after: close)
                continue
            }
            lastBound = 0
            out.append(c)
            i = marked.index(after: i)
        }
        let placed = attachments.map { a -> Attachment in
            var a = a
            a.anchor = anchors[a.index] ?? out.utf16.count
            a.bound = bounds[a.index] ?? 0
            return a
        }
        return (out, placed)
    }

    static func make(_ id: String, _ kind: CaptureKind, _ time: Date, _ app: AppRef, _ marked: String,
                     _ attachments: [Attachment] = [], to destination: Destination? = nil,
                     theme: String, seconds: Double, site: String? = nil, tags: [String] = []) -> Capture {
        let (text, placed) = anchored(marked, attachments)
        return Capture(id: id, kind: kind, time: time, app: app, text: text, attachments: placed,
                       destination: destination, theme: theme, seconds: seconds, site: site, tags: tags)
    }

    /// A recording whose words never came back.
    static func failed(_ id: String, _ time: Date, _ app: AppRef, because reason: String, seconds: Double) -> Capture {
        Capture(id: id, kind: .dictation, time: time, app: app, text: "", theme: "Not transcribed", seconds: seconds, failure: reason)
    }

    /// What each capture is about: the tags Fovea gave it. The filter picks by them; Memory's
    /// areas read from them.
    static let tags: [String: [String]] = [
        "d-slack-standup": ["Notch", "Standup"], "x-why-bullets": ["Fovea site", "Copy"], "x-spring": ["SwiftUI", "Animation"],
        "x-ears": ["Notch", "SwiftUI"], "c-mail-429": ["API", "Rate limits"], "d-mail-lin": ["Design review"],
        "d-wechat": ["Dinner"], "x-rate": ["API", "Rate limits"], "x-index": ["Database", "Invites"],
        "c-notes-quote": ["Fovea site", "Interviews"], "d-notes-ideas": ["Onboarding"], "c-review-slot": ["Design review", "Notch"],
        "d-figma": ["Fovea site"], "x-downloads": ["Files", "Invoices"], "x-ship": ["Weekly update"], "d-messages": ["Dinner"],
        "x-hero-photo": ["Fovea site", "Photography"], "d-obsidian": ["Reference resolution"], "c-notch-spacing": ["Notch"],
        "x-sips": ["Terminal", "Photography"], "x-crash": ["SwiftUI", "Bugs"], "d-slack-review": ["Design review"],
        "x-summarize": ["Interviews"], "x-layout": ["Fovea site"], "x-why-section": ["Fovea site"], "d-notion-spec": ["Fovea spec"],
        "c-csv": ["Waitlist"], "x-mcp": ["MCP", "Memory"],
    ]

    static func region(_ i: Int, _ art: String, _ crop: UnitRect = .full, text: String, from source: String) -> Attachment {
        Attachment(i, .region, anchor: 0, art: art, crop: crop, text: text, source: source)
    }

    static func passage(_ i: Int, _ text: String, from source: String) -> Attachment {
        Attachment(i, .passage, anchor: 0, text: text, source: source)
    }

    static func file(_ i: Int, _ name: String, in folder: String) -> Attachment {
        Attachment(i, .file, anchor: 0, text: name, fileType: (name as NSString).pathExtension.lowercased(), source: folder)
    }

    // MARK: Captures

    /// What people actually say into Fovea: a few sentences to a short paragraph each, with the
    /// place they took something marked ⟨n⟩.
    public static func captures() -> [Capture] {
        typealias A = Apps
        typealias G = Agents
        let why = "localhost:3000"
        let rateText = "Rate limits\nThe API allows up to 100 read requests per second per account and 100 write requests per second per account. Requests over the limit receive a 429 response."
        let list: [Capture] = [
            // Today
            make("d-slack-standup", .dictation, ago(3), A.slack,
                 "Quick update for standup: the island hover panel is done and merged into the prototype branch. Hovering the notch now opens the task list after 120 ms, and it closes 300 ms after you leave, which feels a lot less jumpy than before. I still need someone to review the timing tomorrow morning, ideally before the design sync, because I want to lock the numbers before we touch the voice bar again. Also, the transcribing line now shows the last few words instead of a spinner, so if anything feels off there, tell me today.",
                 theme: "Hover panel review", seconds: 31.4),
            make("x-why-bullets", .dispatch, ago(18), A.safari,
                 "{这一屏}⟨1⟩的三条 bullet 都改成动词开头，读起来要像在说用户能做什么，而不是在介绍功能。第二条太长了，压到一行以内，最好不超过十二个字。第三条里的“context”换成中文，别中英混在一起。改完之后把三条的行高和上面标题的间距也统一一下，现在看起来有点挤。做完先别部署，截个图发给我看看。",
                 [region(1, "localhost-why", UnitRect(0.05, 0.3, 0.75, 0.42),
                         text: "Fovea sees what you point at\nYou say where it goes\nYour agent gets the context", from: why)],
                 to: Destination(G.codex, chat: "第二屏文案"), theme: "第二屏 bullet 文案", seconds: 26.0),
            make("x-spring", .dispatch, ago(41), A.xcode,
                 "interpolatingSpring 和 smooth 到底有什么区别？我在 IslandModel 里两种都用了，展开用的是 interpolatingSpring，收起用的是 smooth，结果中途打断的时候速度感觉不连贯。我想知道它们在被打断时保留速度的方式是不是不一样，还有 duration 和 bounce 这两个参数在两种写法里是不是同一个意思。如果应该统一成一种，告诉我用哪种，以及为什么。",
                 to: Destination(G.claudeCode, chat: "New chat"), theme: "Spring 和 smooth", seconds: 24.5),
            make("x-ears", .dispatch, ago(52), A.xcode,
                 "Make the ears on {this one}⟨1⟩ match the menu bar's height exactly, so the top corners flow into the bar instead of sitting a couple of points below it, and use the spacing from {the second one}⟨2⟩ for the gap between the waveform and the word Listening. Keep the bottom radius as it is. When you're done, run the workbench snapshots for both the notch and the software island and check that nothing else moved, especially the expanded state, because that one shares the same shape.",
                 [region(1, "xcode-islandshape", UnitRect(0, 0, 0.8, 0.55),
                         text: "struct IslandShape: Shape {\nvar topRadius: CGFloat\nvar bottomRadius: CGFloat", from: "IslandShape.swift"),
                  region(2, "workbench-notches", UnitRect(0.5, 0.15, 0.5, 0.7), text: "Listening", from: "Notch Workbench")],
                 to: Destination(G.claudeCode, chat: "Notch ears"), theme: "Notch ears height", seconds: 33.2),
            make("c-mail-429", .dictation, ago(75), A.mail,
                 "Lin, I looked into the errors from yesterday's demo. {The docs}⟨1⟩ say the API allows 100 write requests a second, and we were sending closer to 300 during the sync, so the 429s we saw are ours, not theirs. I'd rather fix it on our side than ask them for a higher limit: batching the writes and adding a short backoff should get us well under the cap. I can have a patch up by Monday if that works for you, and I'll run the demo script again before we show it to anyone.",
                 [region(1, "docs-rate-limits", UnitRect(0.26, 0.05, 0.72, 0.62), text: rateText, from: "API reference · Rate limits")],
                 theme: "The 429s are ours", seconds: 34.8),
            make("d-mail-lin", .dictation, ago(96), A.mail,
                 "Hi Lin,\n\nThanks for the notes on the second screen, they were really helpful. I agree the heading is too long and the second bullet tries to say two things at once. Let's go through them together on Thursday at 10 in Room 3; I'll bring the new version of the notch study and a couple of options for the copy, so we can decide in the room instead of going back and forth over email.\n\nIf Thursday doesn't work, Friday morning is fine too.\n\nRyan",
                 theme: "Thursday with Lin", seconds: 29.6),
            make("d-persephone", .dictation, ago(120), A.chrome,
                 "Why did Persephone eat the pomegranate seeds if she knew it would keep her in the underworld? Some versions say Hades tricked her and others say she chose it, and I'd like to know which version is older. Also explain how the story ties to the seasons, and whether the Eleusinian Mysteries were really about her return. Keep it short and give me the main sources, the Homeric Hymn first, so I can read them myself this weekend.",
                 theme: "Persephone's seeds", seconds: 24.0, site: "chatgpt.com", tags: ["Greek mythology"]),
            failed("d-failed-notes", ago(128), A.notes, because: "The network dropped while your recording was sending.", seconds: 18.4),
            make("d-wechat", .dictation, ago(140), A.wechat,
                 "今晚七点吃饭吗？我订了那家云南菜，就是上次你说想去的那家，在学校东门对面，二楼靠窗的位置。我大概六点四十到，先去点菜，你要是晚一点也没关系。他们家的汽锅鸡要提前点，我先订一份。吃完要不要再去旁边那家咖啡店坐一会儿？",
                 theme: "今晚云南菜", seconds: 21.3),
            make("x-rate", .dispatch, ago(185), A.chrome,
                 "Add rate limiting to the login endpoint, the way the docs describe it {here}⟨1⟩: five tries per minute per IP, and a 429 with a Retry-After header once someone goes over. Put the limiter in the auth middleware, not in the route handler, so the password reset and magic link endpoints get the same protection for free. Use the Redis client we already have rather than adding a new dependency, and write tests for the edge cases, especially the window rolling over and two requests arriving at the same moment.",
                 [region(1, "docs-rate-limits", UnitRect(0.26, 0.05, 0.72, 0.62), text: rateText, from: "API reference · Rate limits")],
                 to: Destination(G.codex, chat: "auth middleware"), theme: "Login rate limiting", seconds: 32.7),
            make("x-index", .dispatch, ago(230), A.notion,
                 "Is the waitlist table indexed on email? I'm writing the spec for the invite flow, and the plan is to look people up by email every time they open an invite link, so if that's a full table scan I want to know now. If there is an index, tell me whether it's unique and which migration added it. If there isn't, tell me what adding one would cost on a table with a few thousand rows, and whether we'd need to take the site down to do it.",
                 to: Destination(G.claudeCode, chat: "New chat"), theme: "Waitlist email index", seconds: 28.9),
            make("c-notes-quote", .dictation, ago(262), A.notes,
                 "Notes for the second screen of the site. I want to open with {this line from the interview}⟨1⟩ instead of our own copy, because it says the whole idea better than anything we've written. Keep the heading short, three or four words at most, and let the quote do the work underneath it. Below that, the three bullets, each starting with a verb. If the quote feels too long on mobile, cut the first sentence rather than rewording it, since it should stay in her words.",
                 [passage(1, "“I don't want to explain my screen to the AI. I just want to point at it.”", from: "interview-notes-0926.md")],
                 theme: "Interview quote opener", seconds: 30.2),

            // Yesterday
            make("d-circe", .dictation, daysAgo(1, 22, 30), A.notes,
                 "Reading list for the next few months, in this order: Circe by Madeline Miller first, then The Song of Achilles, then Stephen Fry's Mythos if I still want more. After that, Emily Wilson's translation of the Odyssey, because everyone says it reads like a novel. Keep a note of which gods show up in more than one of them, and remind me to look up the Fagles translation to compare a few passages. The library has Circe available now; the others are on hold.",
                 theme: "Myth reading list", seconds: 27.5, tags: ["Greek mythology", "Books"]),
            make("d-notes-ideas", .dictation, daysAgo(1, 21, 14), A.notes,
                 "Idea for onboarding: instead of a tour, show the person their own captures from the first five minutes. Most people won't read a tour anyway, but they will recognize something they just did. So the first time they open the window, it should already have two or three cards in it, made from what they actually said and pointed at. Then one line under them explaining that this is where everything lands. No checklist, no progress bar, and no confetti. If the window is empty, that's the moment to teach the hotkey.",
                 theme: "Onboarding without a tour", seconds: 32.0),
            make("c-review-slot", .dictation, daysAgo(1, 16, 40), A.slack,
                 "Lin, does {this slot}⟨1⟩ work for the design review? It's Thursday from 10 to 10:45, right after standup, so nobody has to switch context twice. I'll bring {the notch study}⟨2⟩ and walk through the hover timing, the listening bar and the two island materials we're still deciding between. If you can, look at the second option before we meet, because that's the one I want to argue for. And if 45 minutes feels short, I can book the room until 11.",
                 [region(1, "calendar-review", text: "Design review with Lin\n10:00–10:45", from: "Calendar — Thursday"),
                  file(2, "Notch study.key", in: "Downloads")],
                 theme: "Design review slot", seconds: 30.5),
            make("d-figma", .dictation, daysAgo(1, 15, 2), A.figma,
                 "Make the second screen heading shorter; four words would be ideal. Keep the subheading exactly as it is, since that's the line people actually read. Then tighten the spacing between the heading and the bullets: it's about 40 right now and I think 24 would feel more connected. And can we try the illustration on the left instead of the right? On narrow windows it currently pushes the bullets below the fold, which defeats the whole point of the section.",
                 theme: "Shorter second-screen heading", seconds: 27.1),
            make("x-downloads", .dispatch, daysAgo(1, 11, 20), A.finder,
                 "把{这几份文件}⟨1⟩⟨2⟩⟨3⟩整理一下，按项目放进文件夹：logo 的压缩包放到品牌素材里，访谈记录放进 research 文件夹，发票单独放到财务那个目录，文件名前面加上日期。整理完之后把 Downloads 里一个月以前的截图都挪到一个 archive 文件夹，先别删。最后给我一个清单，告诉我每个文件被放到哪里了。",
                 [file(1, "fovea-logo-v3.zip", in: "Downloads"),
                  file(2, "interview-notes-0926.md", in: "Downloads"),
                  file(3, "invoice-0930.pdf", in: "Downloads")],
                 to: Destination(G.claudeCode, chat: "New chat"), theme: "整理下载文件", seconds: 25.4),
            make("x-ship", .dispatch, daysAgo(1, 9, 45), A.slack,
                 "What shipped in fovea-mac this week? I need a short list for the Friday update: only things people can actually notice, not refactors or test changes. For each one, give me one sentence on what changed and the pull request it came from. If something was merged but is still behind a flag, list it separately at the end so I don't announce it by accident. Keep the whole thing short enough to paste without editing.",
                 to: Destination(G.codex, chat: "New chat"), theme: "This week's ships", seconds: 25.8),

            // Earlier this week
            make("d-budget", .dictation, daysAgo(2, 20, 15), A.numbers,
                 "October budget: rent stays at 2,400, groceries back down to 450 after this month, and set aside 300 for the trip in November. Move the gym to the cheaper plan, which saves about 40 a month, and cancel the second music subscription since nobody uses it. Put whatever is left into the savings column on the first, not the end of the month, so I don't spend it by accident. Add a row for the new laptop fund too, 150 a month until March.",
                 theme: "October budget", seconds: 26.2, tags: ["Budget"]),
            make("d-messages", .dictation, daysAgo(2, 19, 30), A.messages,
                 "Running about 10 minutes late, sorry! The train stopped between stations for a while and just started moving again. Go ahead and order without me if you're hungry, and save me a seat near the window if you can. I'll have whatever you're having, except nothing too spicy tonight. If the place is full, text me and we'll go to the noodle shop next door instead.",
                 theme: "Running late", seconds: 21.9),
            make("x-hero-photo", .dispatch, daysAgo(2, 10, 12), A.safari,
                 "Use {this}⟨1⟩ as the hero image on the landing page, cropped to 16:9 and centered on the ridge line, not the sky. Export it at 2x for Retina and generate a WebP version too, with a JPEG fallback for older browsers. Keep the file under 300 KB if you can without visible banding. Put the photographer's credit in the footer, small, the way the license asks for it, and update the alt text so it describes the mountain rather than just saying hero image.",
                 [region(1, "mountain-16x9", text: "", from: "Unsplash")],
                 to: Destination(G.codex, chat: "Hero photo"), theme: "Hero image crop", seconds: 29.3),
            make("d-obsidian", .dictation, daysAgo(2, 9, 5), A.obsidian,
                 "Reference resolution is the hard part of Fovea, not the transcription. People say \"this one\" and \"that part\" and \"the second one\" while they're still moving the mouse, so the words and the regions arrive out of order. The binding has to use timing, not just order: whatever you circled closest to when you said \"this\" is probably what you meant. When it's ambiguous, ask once, show both options side by side, and remember the answer for next time.",
                 theme: "Reference resolution", seconds: 28.4),
            failed("d-failed-mail", daysAgo(3, 9, 40), A.mail, because: "Fovea's transcription service didn't answer in time.", seconds: 41.0),
            make("c-notch-spacing", .dictation, daysAgo(3, 17, 22), A.slack,
                 "Comparing the two listening bars from today's build. {The first one}⟨1⟩ is too tight: the waveform almost touches the word, and at small sizes it reads as one blob. {The second}⟨2⟩ has the spacing I want, about 8 points between them, and the word sits on the same baseline as the menu bar clock. Let's use the second one for the listening bar too, and for the transcribing line, so the text doesn't jump when one state hands over to the next.",
                 [region(1, "workbench-notches", UnitRect(0, 0.15, 0.5, 0.7), text: "Listening", from: "Notch Workbench"),
                  region(2, "workbench-notches", UnitRect(0.5, 0.15, 0.5, 0.7), text: "Listening", from: "Notch Workbench")],
                 theme: "Listening bar spacing", seconds: 28.0),
            make("x-sips", .dispatch, daysAgo(3, 14, 0), A.finder,
                 "How do I crop an image to 16:9 from the terminal without installing anything? I have about forty screenshots in a folder and I want them all at 1920 by 1080, cropped around the center, with the originals untouched. If sips can do it, give me the exact command and a loop for the whole folder. If it can't do a center crop by itself, tell me the simplest built-in alternative, and whether the output will lose quality compared to the originals.",
                 to: Destination(G.claudeCode, chat: "New chat"), theme: "Crop from the terminal", seconds: 27.5),
            make("x-crash", .dispatch, daysAgo(3, 11, 30), A.xcode,
                 "Why does {this}⟨1⟩ crash when the window closes? It only happens if you close the window while the island is still animating, and the stack trace points at the update method being called on a controller that's already gone. I think the observer is never removed, but I'm not sure where it should be, since the controller is reused when the window opens again. Find the cause, fix it the simplest way you can, and add a test that closes the window mid-animation.",
                 [passage(1, "NotificationCenter.default.addObserver(self, selector: #selector(update), name: NSWindow.didResizeNotification, object: window)",
                          from: "WindowController.swift")],
                 to: Destination(G.claudeCode, chat: "Window lifecycle"), theme: "Crash on close", seconds: 29.0),
            make("d-slack-review", .dictation, daysAgo(4, 12, 10), A.slack,
                 "Can we move the review to Friday? The island timing still needs a pass, and I don't want to show it with numbers I already know are wrong. Specifically, the hover delay feels sticky and the close animation is a bit slower than the open, which should be the other way around. I'll have both fixed by Thursday evening. Friday at 2 works for me, or any time after lunch. If Friday is bad for everyone, let's push to Monday rather than squeeze it in.",
                 theme: "Review to Friday", seconds: 28.6),
            make("x-summarize", .dispatch, daysAgo(4, 10, 0), A.finder,
                 "Summarize {this}⟨1⟩ in three bullets, only the parts about pointing at things on screen. I don't need the background questions or the parts about pricing. For each bullet, include one direct quote with the speaker's name, so I can use it in the deck without going back to the recording. Then, separately, list anything people said that surprised you or contradicted what we assumed, even if it's only one person. Keep the whole summary under 200 words.",
                 [file(1, "interview-notes-0926.md", in: "Downloads")],
                 to: Destination(G.claudeCode, chat: "Interview notes"), theme: "Interview summary", seconds: 26.3),
            make("x-layout", .dispatch, daysAgo(5, 11, 20), A.safari,
                 "This is {the whole screen}⟨1⟩ at the narrowest window we support. The bullets wrap under the illustration and the join button falls off the bottom, so on a 13-inch laptop half the section is invisible until you scroll. Make the layout stack earlier, at around 900 points wide, put the illustration above the bullets, and keep the join button visible without scrolling. Check it at 1280, 1024 and 900, and send me a screenshot of each.",
                 [region(1, "localhost-why", .full,
                         text: "Why Fovea\nFovea sees what you point at\nYou say where it goes\nYour agent gets the context\nJoin the waitlist", from: "Whole screen · Safari")],
                 to: Destination(G.codex, chat: "第二屏文案"), theme: "Narrow window layout", seconds: 27.2),
            make("x-why-section", .dispatch, daysAgo(5, 15, 40), A.safari,
                 "Make {the join button}⟨1⟩ match the one in the nav exactly: same height, same corner radius, same font weight, and the same hover state. Right now it's a few points taller and the text looks heavier. Then put {the section title}⟨2⟩ in sentence case, so it reads Why Fovea, not WHY FOVEA, and check the other section titles on the page for the same thing. Don't change any colors in this pass. Push it to the preview branch so I can check it on my phone.",
                 [region(1, "localhost-why", UnitRect(0, 0.78, 0.4, 0.22), text: "Join the waitlist", from: why),
                  region(2, "localhost-why", UnitRect(0, 0, 0.6, 0.25), text: "Why Fovea", from: why)],
                 to: Destination(G.codex, chat: "第二屏文案"), theme: "Join button height", seconds: 30.1),
            make("d-notion-spec", .dictation, daysAgo(6, 10, 30), A.notion,
                 "The capture is the atomic unit: everything between pressing the hotkey and pressing it again. It holds what you said, what you pointed at, the app you were in, and where it went. Nothing about a capture changes after the fact, except that you can delete it. If you correct something, that's a new capture, not an edit, so the history stays honest. Every screen in the app should be able to explain itself in terms of captures, and if it can't, it probably shouldn't exist.",
                 theme: "The atomic unit", seconds: 30.8),
            make("c-csv", .dictation, daysAgo(6, 18, 2), A.messages,
                 "Here's {the latest waitlist export}⟨1⟩: 214 people so far, up from 160 last week, mostly from the demo video. About a third of them signed up on a Mac with a notch, which is higher than I expected. Can you look through the job titles column when you get a chance and tell me roughly how many are engineers versus designers? I want to decide who gets the first round of invites, and I'd rather start with whoever will actually try the voice features.",
                 [file(1, "waitlist-export.csv", in: "Downloads")],
                 theme: "Waitlist export", seconds: 29.7),

            // Last week
            make("x-mcp", .dispatch, daysAgo(8, 16, 5), A.chrome,
                 "What's the difference between an MCP tool and an MCP resource? I'm deciding how Fovea should expose its memory to agents. If an agent needs to look something up only when the user mentions it, does that make it a tool or a resource? And if the agent should see a few facts at the start of every chat, is that a resource the client attaches automatically? Explain it with a concrete example, and tell me which one Claude Code and Codex actually support today.",
                 to: Destination(G.claudeCode, chat: "New chat"), theme: "MCP tool or resource", seconds: 28.2),
        ]
        var turns: [String: Int] = [:]
        for c in list.sorted(by: { $0.time < $1.time }) {
            guard let d = c.destination, d.chat != "New chat" else { continue }
            turns[c.id] = (turns.filter { k, _ in list.first { $0.id == k }?.destination?.chat == d.chat }.count) + 1
        }
        return list.map { c in
            var c = c
            if c.tags.isEmpty { c.tags = tags[c.id] ?? [] }
            if let turn = turns[c.id] { c.destination?.turn = turn }
            return c
        }
    }

    // MARK: Dictionary and memories

    /// Six weeks of a working dictionary: the words Fovea learned from corrections (what it heard
    /// first, and where), and the ones added by hand. About 120, so the list is drawn for a real
    /// one (row 18), not a dozen.
    public static func dictionary() -> [DictionaryWord] {
        var words = [
            DictionaryWord(id: "w-fovea", word: "Fovea", heardAs: "fovia", source: .learned, date: daysAgo(12, 10, 0), learnedIn: "Slack"),
            DictionaryWord(id: "w-referent", word: "referent", heardAs: "reference", source: .learned, date: daysAgo(9, 15, 0), learnedIn: "Notion"),
            DictionaryWord(id: "w-codex", word: "Codex", source: .added, date: daysAgo(14, 9, 0)),
            DictionaryWord(id: "w-claude-code", word: "Claude Code", source: .added, date: daysAgo(14, 9, 0)),
            DictionaryWord(id: "w-lin", word: "Lin", heardAs: "Lynn", source: .learned, date: daysAgo(3, 11, 0), learnedIn: "Mail"),
            DictionaryWord(id: "w-swiftui", word: "SwiftUI", heardAs: "swift UI", source: .learned, date: daysAgo(6, 14, 0), learnedIn: "Xcode"),
            DictionaryWord(id: "w-island", word: "Island", source: .added, date: daysAgo(11, 9, 30)),
            DictionaryWord(id: "w-second", word: "第二屏", source: .added, date: daysAgo(9, 15, 30)),
            DictionaryWord(id: "w-interp", word: "interpolatingSpring", heardAs: "interpolating spring", source: .learned, date: daysAgo(2, 16, 0), learnedIn: "Xcode"),
            DictionaryWord(id: "w-yunnan", word: "云南菜", source: .added, date: daysAgo(1, 19, 0)),
            DictionaryWord(id: "w-waitlist", word: "waitlist", heardAs: "wait list", source: .learned, date: daysAgo(4, 10, 0), learnedIn: "Notion"),
        ]
        // The rest of six weeks: (word, what Fovea heard first; nil when added by hand).
        let more: [(String, String?)] = [
            ("Persephone", "Persephonie"), ("Circe", "Searcy"), ("Odyssey", nil), ("Eleusinian", "Eleusinian's"), ("Fagles", "fables"),
            ("Madeline Miller", nil), ("Achilles", nil), ("Hades", "hey these"), ("Kubernetes", "communities"), ("PostgreSQL", "post gress"),
            ("GraphQL", "graph cue L"), ("Tailwind", nil), ("Vercel", "versel"), ("Supabase", "super base"), ("Redis", "radish"),
            ("Prisma", nil), ("tRPC", "T RPC"), ("Next.js", "next JS"), ("Vite", "veet"), ("esbuild", "ES build"),
            ("SwiftData", nil), ("AppKit", "app kit"), ("NSPanel", "NS panel"), ("CGWindowListCreateImage", nil), ("actool", "act tool"),
            ("Icon Composer", nil), ("Liquid Glass", nil), ("safeAreaInsets", "safe area insets"), ("MCP", "MCB"), ("Anthropic", nil),
            ("OpenAI", nil), ("Cursor", nil), ("Windsurf", "wind surf"), ("TestFlight", "test flight"), ("notarytool", "notary tool"),
            ("Sparkle", nil), ("Homebrew", nil), ("zsh", "Z shell"), ("tmux", "T mux"), ("ripgrep", "rip grep"),
            ("fzf", "FZF"), ("jq", nil), ("FigJam", "fig jam"), ("Linear", nil), ("Obsidian", nil),
            ("Raycast", "ray cast"), ("Superhuman", nil), ("Granola", nil), ("Wispr", "whisper"), ("Superwhisper", "super whisper"),
            ("Typeless", "type less"), ("VoiceFlow", "voice flow"), ("Quick Answer", nil), ("Gaze Collector", nil), ("Fovea Gaze", nil),
            ("saccade", "sack aid"), ("fixation", nil), ("Tobii", "toby"), ("disambiguation", nil), ("payload", nil),
            ("binding", nil), ("Xudong", "Shoo dong"), ("Mei", "May"), ("Priya", nil), ("Haruto", "Haru toe"),
            ("Søren", "Soren"), ("Okonkwo", nil), ("Zoë", "Zoey"), ("Ngozi", nil), ("Aoife", "Eefa"),
            ("主仓", nil), ("灵动岛", nil), ("转写", "转写的"), ("润色", nil), ("词典", nil),
            ("派发", "排发"), ("眼动", nil), ("注视", "主视"), ("截图", nil), ("录音", nil),
            ("上手练习", nil), ("访谈", "方谈"), ("文案", nil), ("间距", nil), ("行高", nil),
            ("hero image", nil), ("alt text", "all text"), ("Retina", nil), ("WebP", "web P"), ("JPEG", nil),
            ("Room 3", nil), ("standup", "stand up"), ("Thursday sync", nil), ("Friday update", nil), ("design review", nil),
            ("backoff", "back off"), ("429", "four twenty nine"), ("Retry-After", "retry after"), ("rate limiting", nil), ("middleware", "middle wear"),
            ("migration", nil), ("invite flow", nil), ("magic link", nil), ("Homeric Hymn", "homeric him"), ("Mythos", "mythos's"),
            ("Numbers", nil), ("laptop fund", nil), ("savings column", nil), ("invoice", nil), ("Libby", "Libbie"),
        ]
        for (i, (word, heard)) in more.enumerated() {
            let day = 1 + (i * 7) % 41
            words.append(DictionaryWord(id: "w-more-\(i)", word: word, heardAs: heard, source: heard == nil ? .added : .learned,
                                        date: daysAgo(day, 9 + i % 9, (i * 13) % 60),
                                        learnedIn: heard == nil ? nil : ["Slack", "Notes", "Xcode", "Mail", "Notion", "Chrome"][i % 6]))
        }
        return words
    }

    /// The parts of Ryan's life Fovea has read from what they send their agents (row 24): each a
    /// summary they can correct or forget, read from tags that keep coming up.
    public static func areas() -> [MemoryArea] {
        [
            MemoryArea(id: "work", title: "Work", symbol: "briefcase.fill",
                       summary: "Building Fovea, a Mac app that turns pointing and speaking into requests for coding agents. This month: the notch (its hover timing, the listening bar, its ears), the second screen of the site, and inviting the waitlist. Reviews designs with Lin on Thursdays and sends the week's ships on Fridays.",
                       tags: ["Notch", "Fovea site", "Design review", "Waitlist", "Weekly update", "Onboarding"], updated: ago(52)),
            MemoryArea(id: "craft", title: "How you work", symbol: "hammer.fill",
                       summary: "Writes Swift and SwiftUI in Xcode; sends motion work to Claude Code and copy to Codex. Fixes problems on their own side before asking for higher limits, wants tests for the edge cases, and answers short enough to paste. Signs emails “Ryan”.",
                       tags: ["SwiftUI", "API", "Bugs", "Terminal", "Animation"], updated: ago(41)),
            MemoryArea(id: "interests", title: "Interests", symbol: "sparkles",
                       summary: "Greek mythology keeps coming up: why Persephone ate the seeds, Circe and The Song of Achilles, the Odyssey in Emily Wilson's translation. Also photographs landscapes, and cares how a picture is cropped.",
                       tags: ["Greek mythology", "Books", "Photography", "Dinner"], updated: ago(120)),
            MemoryArea(id: "money", title: "Personal finances", symbol: "creditcard.fill",
                       summary: "Keeps a monthly budget in Numbers, files invoices by month, and is putting 150 a month toward a new laptop until March. Fovea never keeps account or card numbers.",
                       tags: ["Budget", "Invoices"], updated: daysAgo(2, 20, 16)),
        ]
    }

    /// Which area a set of tags belongs to: the first area that reads any of them, else work.
    static func area(for tags: [String]) -> String {
        areas().first { !Set($0.tags).isDisjoint(with: tags) }?.id ?? "work"
    }

    /// Everything Fovea keeps, raw (row 24): what Ryan told it to remember, what it read from what
    /// they sent, a few hidden from agents, two recently deleted; and with history, one for every
    /// few captures of the past year, so search has the hundreds a real one has.
    public static func memories(includeHistory: Bool = true) -> [Memory] {
        var out = [
            Memory(id: "m-main", text: "“主仓” means api-server", quote: "把这个改动推到主仓", date: daysAgo(12, 10, 2), area: "work", tags: ["Fovea spec"]),
            Memory(id: "m-second", text: "“第二屏” is the Features section of fovea-site", quote: "第二屏的按钮改成“开始”", date: daysAgo(9, 15, 30), scope: "fovea-site", area: "work", tags: ["Fovea site"]),
            Memory(id: "m-claude", text: "Send motion work to Claude Code", quote: "动效的活都给 Claude Code", date: daysAgo(4, 14, 21), area: "craft", tags: ["Animation"]),
            Memory(id: "m-ears", text: "“ears” are the notch's concave top corners", quote: "make the ears match the menu bar", date: daysAgo(3, 14, 0), scope: "Xcode", area: "work", tags: ["Notch"]),
            Memory(id: "m-signoff", text: "Sign emails “Ryan”, not “Best, Ryan”", quote: "just sign it Ryan", date: daysAgo(6, 9, 40), scope: "Mail", area: "craft"),
            Memory(id: "m-lin", text: "Design reviews with Lin are Thursdays at 10, in Room 3", quote: "Thursday at 10 in Room 3", date: ago(96), captureID: "d-mail-lin", area: "work", tags: ["Design review"], stated: false),
            Memory(id: "m-429", text: "The demo's 429s were Fovea's own writes; batch them and back off", quote: "the 429s we saw are ours, not theirs", date: ago(75), captureID: "c-mail-429", area: "craft", tags: ["API", "Rate limits"], stated: false),
            Memory(id: "m-paste", text: "Wants lists short enough to paste without editing", quote: "short enough to paste without editing", date: daysAgo(1, 9, 45), captureID: "x-ship", area: "craft", tags: ["Weekly update"], stated: false),
            Memory(id: "m-circe", text: "Reading Circe next, then The Song of Achilles, then Mythos", quote: "Circe by Madeline Miller first", date: daysAgo(1, 22, 30), captureID: "d-circe", area: "interests", tags: ["Greek mythology", "Books"], stated: false),
            Memory(id: "m-persephone", text: "Asked why Persephone ate the pomegranate seeds", quote: "Why did Persephone eat the pomegranate seeds", date: ago(120), captureID: "d-persephone", area: "interests", tags: ["Greek mythology"], stated: false),
            Memory(id: "m-wilson", text: "Wants to read the Odyssey in Emily Wilson's translation", quote: "Emily Wilson's translation of the Odyssey", date: daysAgo(1, 22, 30), captureID: "d-circe", area: "interests", tags: ["Greek mythology", "Books"], stated: false),
            Memory(id: "m-budget", text: "October budget: rent 2,400, groceries 450, 300 for the November trip", quote: "rent stays at 2,400", date: daysAgo(2, 20, 15), captureID: "d-budget", area: "money", tags: ["Budget"], stated: false),
            Memory(id: "m-laptop", text: "Saving 150 a month for a new laptop until March", quote: "150 a month until March", date: daysAgo(2, 20, 15), captureID: "d-budget", area: "money", tags: ["Budget"], stated: false),
            Memory(id: "m-invoices", text: "Invoices go in the finance folder, dated", quote: "发票单独放到财务那个目录", date: daysAgo(1, 11, 20), captureID: "x-downloads", area: "money", tags: ["Invoices"], stated: false, hidden: true),
            Memory(id: "m-hero", text: "The site's hero image is cropped to 16:9 around the ridge line", quote: "centered on the ridge line, not the sky", date: daysAgo(2, 10, 12), captureID: "x-hero-photo", area: "work", tags: ["Fovea site", "Photography"], stated: false),
            Memory(id: "m-onboarding", text: "Onboarding should show people their own first captures, not a tour", quote: "show the person their own captures", date: daysAgo(1, 21, 14), captureID: "d-notes-ideas", area: "work", tags: ["Onboarding"], stated: false),
            Memory(id: "m-waitlist", text: "The waitlist reached 214 people on Sep 20", quote: "214 people so far", date: daysAgo(6, 18, 2), captureID: "c-csv", area: "work", tags: ["Waitlist"], stated: false),
            Memory(id: "m-yunnan", text: "Likes the Yunnan place across from the east gate", quote: "那家云南菜", date: ago(140), captureID: "d-wechat", area: "interests", tags: ["Dinner"], stated: false, hidden: true),
            Memory(id: "m-late", text: "Train delays on the way to dinner", quote: "The train stopped between stations", date: daysAgo(2, 19, 30), captureID: "d-messages", area: "interests", tags: ["Dinner"], stated: false, deleted: daysAgo(1, 8, 0)),
            Memory(id: "m-spicy", text: "Nothing too spicy on weeknights", quote: "nothing too spicy tonight", date: daysAgo(2, 19, 30), captureID: "d-messages", area: "interests", tags: ["Dinner"], stated: false, deleted: ago(300)),
        ]
        guard includeHistory else { return out }
        // A year of them: one for every fourth capture in history, in the words a memory keeps.
        for (i, c) in history().enumerated() where i % 4 == 0 {
            let text = c.kind == .dispatch
                ? "Asked \(c.destination?.agent ?? "an agent") about \(c.theme)"
                : "Wrote “\(c.theme)” in \(c.app.name)"
            let quote = String(c.text.prefix(48))
            out.append(Memory(id: "m-h-\(c.id)", text: text, quote: quote, date: c.time, captureID: c.id,
                              area: area(for: c.tags), tags: c.tags, stated: false))
        }
        return out
    }
}

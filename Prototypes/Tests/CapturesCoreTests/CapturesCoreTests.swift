import XCTest
@testable import CapturesCore

final class CaptureSearchTests: XCTestCase {
    /// This week's captures, where every result is known by name.
    let library = Fixtures.library(.weekOnly)

    func testEmptyQueryReturnsEverythingNewestFirst() {
        let hits = CaptureSearch.search(CaptureQuery(), in: library.captures, now: library.now)
        XCTAssertEqual(hits.count, library.captures.count)
        for (a, b) in zip(hits, hits.dropFirst()) { XCTAssertGreaterThanOrEqual(a.capture.time, b.capture.time) }
    }

    func testEveryWordMustMatchSomewhere() {
        let hits = CaptureSearch.search(CaptureQuery(text: "lin thursday"), in: library.captures, now: library.now)
        XCTAssertFalse(hits.isEmpty)
        for hit in hits {
            let c = hit.capture
            let all = [c.text, CaptureSearch.attachmentText(c)].joined(separator: " ").lowercased()
            XCTAssertTrue(all.contains("lin") && all.contains("thursday"), c.id)
        }
        XCTAssertTrue(CaptureSearch.search(CaptureQuery(text: "lin kubernetes"), in: library.captures, now: library.now).isEmpty)
    }

    func testWhatYouTookIsSearched() {
        let hits = CaptureSearch.search(CaptureQuery(text: "account"), in: library.captures, now: library.now)
        XCTAssertEqual(hits.map(\.capture.id), ["c-mail-429", "x-rate"])
        XCTAssertNotNil(hits.first?.ranges[.attachments])
        XCTAssertNil(hits.first?.ranges[.text])
        // A file is found by its name.
        XCTAssertEqual(CaptureSearch.search(CaptureQuery(text: "invoice"), in: library.captures, now: library.now).map(\.capture.id), ["x-downloads"])
    }

    func testWhereADispatchWentIsSearched() {
        let hits = CaptureSearch.search(CaptureQuery(text: "lifecycle"), in: library.captures, now: library.now)
        XCTAssertEqual(hits.map(\.capture.id), ["x-crash"])
        XCTAssertNotNil(hits.first?.ranges[.destination])
        XCTAssertNil(hits.first?.ranges[.text])
    }

    func testDispatchesGoToClaudeCodeOrCodex() {
        for c in library.captures where c.kind == .dispatch {
            XCTAssertTrue([Fixtures.Agents.claudeCode, Fixtures.Agents.codex].contains(c.destination?.agent ?? ""), c.id)
        }
    }

    func testWordsAreAsLongAsPeopleSpeak() {
        for c in library.captures where !c.failed {
            let cjk = c.text.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
            if cjk {
                XCTAssertGreaterThan(c.text.count, 90, c.id)
            } else {
                XCTAssertGreaterThan(c.wordCount, 55, c.id)
            }
        }
    }

    func testChipsFilter() {
        let dictations = CaptureSearch.search(CaptureQuery(kind: .dictation), in: library.captures, now: library.now)
        XCTAssertTrue(dictations.allSatisfy { $0.capture.kind == .dictation })
        let slackToday = CaptureSearch.search(CaptureQuery(app: "Slack", date: .today), in: library.captures, now: library.now)
        XCTAssertEqual(slackToday.map(\.capture.id), ["d-slack-standup"])
    }

    func testRangesPointAtTheMatch() {
        let hit = CaptureSearch.search(CaptureQuery(text: "hover"), in: library.captures, now: library.now).first!
        let r = hit.ranges[.text]!.first!
        XCTAssertEqual((hit.capture.text as NSString).substring(with: NSRange(location: r[0], length: r[1])).lowercased(), "hover")
    }

    func testTheAppFilterPicksWhereItWent() {
        let claude = CaptureSearch.search(CaptureQuery(app: Fixtures.Agents.claudeCode), in: library.captures, now: library.now)
        XCTAssertFalse(claude.isEmpty)
        XCTAssertTrue(claude.allSatisfy { $0.capture.kind == .dispatch && $0.capture.destination?.agent == Fixtures.Agents.claudeCode })
        // A dispatch made in front of Xcode went to an agent, so Xcode doesn't list it.
        let xcode = CaptureSearch.search(CaptureQuery(app: "Xcode"), in: library.captures, now: library.now)
        XCTAssertTrue(xcode.allSatisfy { $0.capture.kind != .dispatch })
        XCTAssertTrue(CaptureSearch.apps(in: library.captures).contains(Fixtures.Agents.codex))
    }

    func testTagsFilterAndRankByUse() {
        let myths = CaptureSearch.search(CaptureQuery(tag: "Greek mythology"), in: library.captures, now: library.now)
        XCTAssertFalse(myths.isEmpty)
        XCTAssertTrue(myths.allSatisfy { $0.capture.tags.contains("Greek mythology") })
        let tags = CaptureSearch.tags(in: library.captures)
        for (a, b) in zip(tags, tags.dropFirst()) { XCTAssertGreaterThanOrEqual(a.count, b.count) }
        // Searching a tag's words finds what carries it.
        XCTAssertTrue(CaptureSearch.search(CaptureQuery(text: "mythology"), in: library.captures, now: library.now)
            .contains { $0.capture.id == "d-circe" })
    }

    func testABrowserNamesItsWebsite() {
        let persephone = library.captures.first { $0.id == "d-persephone" }!
        XCTAssertEqual(persephone.target, "Chrome · chatgpt.com")
        XCTAssertTrue(CaptureSearch.apps(in: library.captures).contains("Chrome · chatgpt.com"))
        XCTAssertEqual(CaptureSearch.search(CaptureQuery(text: "chatgpt"), in: library.captures, now: library.now).first?.capture.id, "d-persephone")
    }

    func testAChatsRequestsKeepTheirPlace() {
        let copy = library.captures.filter { $0.destination?.chat == "第二屏文案" }.sorted { $0.time < $1.time }
        XCTAssertEqual(copy.compactMap { $0.destination?.turn }, Array(1...copy.count))
    }

    func testMemoryAreasReadFromTags() {
        let areas = Fixtures.areas()
        XCTAssertEqual(areas.map(\.id), ["work", "craft", "interests", "money"])
        XCTAssertTrue(areas.first { $0.id == "interests" }!.tags.contains("Greek mythology"))
        let memories = Fixtures.memories()
        XCTAssertGreaterThan(memories.count, 200)
        XCTAssertTrue(memories.allSatisfy { m in m.area.map { id in areas.contains { $0.id == id } } ?? true })
        XCTAssertEqual(memories.filter { $0.deleted != nil }.count, 2)
        XCTAssertFalse(memories.filter(\.hidden).isEmpty)
    }

    func testAppsAreMostUsedFirst() {
        let apps = CaptureSearch.apps(in: library.captures)
        XCTAssertEqual(Set(apps).count, apps.count)
        let counts = Dictionary(grouping: library.captures, by: \.target).mapValues(\.count)
        for (a, b) in zip(apps, apps.dropFirst()) { XCTAssertGreaterThanOrEqual(counts[a]!, counts[b]!) }
    }
}

final class AttachmentPlaceTests: XCTestCase {
    let byID = Dictionary(uniqueKeysWithValues: Fixtures.captures().map { ($0.id, $0) })

    func testMarksBecomeAnchors() {
        let (text, placed) = Fixtures.anchored("fix {this}⟨1⟩ and that⟨2⟩.", [
            Attachment(1, .passage, anchor: 0, text: "a", source: "s"),
            Attachment(2, .passage, anchor: 0, text: "b", source: "s"),
        ])
        XCTAssertEqual(text, "fix this and that.")
        XCTAssertEqual(placed.map(\.anchor), [8, 17])
        XCTAssertEqual(placed.map(\.bound), [4, 0])
    }

    func testEachAttachmentKnowsTheWordsThatPointedAtIt() {
        func bound(_ id: String, _ index: Int) -> String {
            let c = byID[id]!
            let a = c.attachments.first { $0.index == index }!
            return (c.text as NSString).substring(with: NSRange(location: a.anchor - a.bound, length: a.bound))
        }
        XCTAssertEqual(bound("x-ears", 1), "this one")
        XCTAssertEqual(bound("x-ears", 2), "the second one")
        XCTAssertEqual(bound("x-why-bullets", 1), "这一屏")
        XCTAssertEqual(bound("x-downloads", 1), "这几份文件")
        XCTAssertEqual(bound("x-downloads", 2), "")
        XCTAssertEqual(bound("c-notes-quote", 1), "this line from the interview")
        // The braces never reach the words.
        XCTAssertFalse(Fixtures.captures().contains { $0.text.contains("{") || $0.text.contains("}") })
    }

    func testSegmentsPutEachAttachmentWhereItWasTaken() {
        let ears = byID["x-ears"]!
        XCTAssertEqual(ears.segments.count, 5)
        guard case .run(0, let first) = ears.segments[0], case .attachment(let a1) = ears.segments[1],
              case .run(_, let middle) = ears.segments[2], case .attachment(let a2) = ears.segments[3] else {
            return XCTFail("\(ears.segments)")
        }
        // Each chip right after the words that pointed at it.
        XCTAssertTrue(first.hasSuffix("on this one"), first)
        XCTAssertEqual(a1.index, 1)
        XCTAssertTrue(middle.hasSuffix("from the second one"), middle)
        XCTAssertEqual(a2.index, 2)
    }

    func testAttachmentsTakenTogetherSitTogether() {
        let files = byID["x-downloads"]!.segments
        XCTAssertEqual(files.count, 5)
        XCTAssertEqual(files.filter(\.isRun).count, 2)
        guard case .run(_, let after) = files[4] else { return XCTFail("\(files)") }
        XCTAssertTrue(after.hasPrefix("整理一下"), after)
    }

    func testRunsCoverTheTextExactly() {
        for c in Fixtures.captures() {
            let runs = c.segments.compactMap { s -> String? in if case .run(_, let t) = s { return t } else { return nil } }
            XCTAssertEqual(runs.joined(), c.text, c.id)
            XCTAssertEqual(c.segments.filter { !$0.isRun }.count, c.attachments.count, c.id)
        }
    }

    func testSpokenNamesEachAttachmentInPlace() {
        let ears = Lines.spoken(byID["x-ears"]!)
        XCTAssertTrue(ears.contains("on this one (region 1) match"), ears)
        XCTAssertTrue(ears.contains("the second one (region 2) for the gap"), ears)
        XCTAssertTrue(Lines.spoken(byID["c-csv"]!).contains("export (file 1, waitlist-export.csv): 214"))
    }
}

final class LinesTests: XCTestCase {
    let now = Fixtures.now

    func testRelativeTimes() {
        XCTAssertEqual(Lines.relative(now.addingTimeInterval(-20), now: now), "just now")
        XCTAssertEqual(Lines.relative(now.addingTimeInterval(-180), now: now), "3 minutes ago")
        XCTAssertEqual(Lines.relative(now.addingTimeInterval(-7_300), now: now), "2 hours ago")
        XCTAssertEqual(Lines.relative(Fixtures.daysAgo(1, 9, 0), now: now), "Yesterday")
        XCTAssertEqual(Lines.relative(Fixtures.daysAgo(3, 9, 0), now: now), "3 days ago")
        XCTAssertEqual(Lines.relative(Fixtures.daysAgo(9, 9, 0), now: now), "Sep 17")
    }

    func testCompactTimes() {
        XCTAssertEqual(Lines.compact(now.addingTimeInterval(-20), now: now), "now")
        XCTAssertEqual(Lines.compact(now.addingTimeInterval(-180), now: now), "3m")
        XCTAssertEqual(Lines.compact(now.addingTimeInterval(-7_300), now: now), "2h")
        XCTAssertEqual(Lines.compact(Fixtures.daysAgo(1, 9, 0), now: now), "1d")
        XCTAssertEqual(Lines.compact(Fixtures.daysAgo(8, 9, 0), now: now), "1w")
        XCTAssertEqual(Lines.compact(Fixtures.daysAgo(40, 9, 0), now: now), "Aug 17")
    }

    func testDaysAreNamedAsTheArchiveShowsThem() {
        XCTAssertEqual(Lines.longDay(now, now: now), "Today")
        XCTAssertEqual(Lines.longDay(Fixtures.daysAgo(1, 9, 0), now: now), "Yesterday")
        XCTAssertEqual(Lines.longDay(Fixtures.daysAgo(9, 9, 0), now: now), "Thursday, September 17")
        XCTAssertEqual(Lines.longDay(Fixtures.daysAgo(300, 9, 0), now: now), "Sunday, November 30, 2025")
        let week = Fixtures.captures().filter { Lines.calendar.isDate($0.time, inSameDayAs: now) }
        XCTAssertEqual(Lines.breakdown(week), "7 dictations · 5 dispatches")
    }

    func testTheHeaderIsTheTypeOnly() {
        for c in Fixtures.captures() { XCTAssertEqual(Lines.label(c), c.kind.title) }
        XCTAssertEqual(CaptureKind.allCases.map(\.title), ["Dictation", "Dispatch"])
    }

    func testCredits() {
        let u = Usage(plan: "Pro", used: 3_160, total: 5_000, resets: Fixtures.daysAgo(-4, 0, 0))
        XCTAssertEqual(Lines.credits(u), "1,840 of 5,000 credits left · resets Sep 30")
        XCTAssertEqual(u.fraction, 0.632, accuracy: 0.001)
    }

    func testEveryFixtureSetBuilds() {
        for set in FixtureSet.allCases {
            let lib = Fixtures.library(set)
            XCTAssertEqual(Set(lib.captures.map(\.id)).count, lib.captures.count, set.rawValue)
            for c in lib.captures {
                switch c.kind {
                case .dictation:
                    // A dictation may keep what you took; it never goes to an agent.
                    XCTAssertNil(c.destination, c.id)
                case .dispatch:
                    XCTAssertNotNil(c.destination, c.id)
                }
                // Words, unless they never came back; then the recording waits.
                XCTAssertEqual(c.text.isEmpty, c.failed, c.id)
                if c.failed { XCTAssertGreaterThan(c.seconds, 0, c.id) }
                // Numbered in the order taken, and taken in the order said.
                XCTAssertEqual(c.attachments.map(\.index), Array(1...max(1, c.attachments.count)).prefix(c.attachments.count).map { $0 }, c.id)
                XCTAssertEqual(c.attachments.map(\.anchor), c.attachments.map(\.anchor).sorted(), c.id)
                XCTAssertTrue(c.attachments.allSatisfy { $0.anchor <= c.text.utf16.count }, c.id)
                XCTAssertFalse(c.theme.isEmpty, c.id)
            }
        }
    }
}

final class HistoryTests: XCTestCase {
    let cal = Lines.calendar
    let now = Fixtures.now

    func testAYearOfUseIsDeterministicAndShaped() {
        let a = Fixtures.history(), b = Fixtures.history()
        XCTAssertEqual(a.map(\.id), b.map(\.id))
        XCTAssertGreaterThan(a.count, 900)
        // Nothing during the trips.
        let counts = History.dayCounts(a, calendar: cal)
        for d in 172...185 { XCTAssertNil(counts[Fixtures.daysAgo(d, 0, 0)], "\(d)") }
        // Busier lately than a year ago.
        let recent = (7..<67).compactMap { counts[Fixtures.daysAgo($0, 0, 0)] }.reduce(0, +)
        let old = (340..<400).compactMap { counts[Fixtures.daysAgo($0, 0, 0)] }.reduce(0, +)
        XCTAssertGreaterThan(recent, old)
        // History never reaches into the first page's week.
        XCTAssertTrue(a.allSatisfy { !History.isRecent($0.time, now: now, calendar: cal) })
    }

    func testTheFirstPageIsSevenDays() {
        let start = History.recentStart(now: now, calendar: cal)
        XCTAssertEqual(start, Fixtures.daysAgo(6, 0, 0))
        let lib = Fixtures.library(.typical)
        let recent = lib.captures.filter { History.isRecent($0.time, now: now, calendar: cal) }
        XCTAssertEqual(Set(recent.map { cal.startOfDay(for: $0.time) }).count, 7)
    }

    func testDateFiltersAreTheCalendarsOwnPeriods() {
        // Saturday 26 September 2026; weeks start on Sunday here.
        func within(_ f: CaptureQuery.DateFilter, _ d: Int) -> Bool {
            CaptureSearch.within(f, Fixtures.daysAgo(d, 12, 0), now: now, calendar: cal)
        }
        XCTAssertTrue(within(.today, 0)); XCTAssertFalse(within(.today, 1))
        XCTAssertTrue(within(.threeDays, 0)); XCTAssertTrue(within(.threeDays, 2)); XCTAssertFalse(within(.threeDays, 3))
        XCTAssertTrue(within(.week, 6)); XCTAssertFalse(within(.week, 7))
        XCTAssertTrue(within(.month, 25)); XCTAssertFalse(within(.month, 26))
    }

    func testAYearIsItsWeeks() {
        let weeks = History.weeks(year: 2025, calendar: cal)
        let days = weeks.flatMap { $0 }.compactMap { $0 }
        XCTAssertEqual(days.count, 365)
        XCTAssertTrue(days.allSatisfy { cal.component(.year, from: $0) == 2025 })
        XCTAssertTrue(weeks.allSatisfy { $0.count == 7 })
        XCTAssertTrue(weeks.first!.contains(cal.date(from: DateComponents(year: 2025, month: 1, day: 1))!))
        XCTAssertTrue(weeks.last!.contains(cal.date(from: DateComponents(year: 2025, month: 12, day: 31))!))
    }

    func testTheCalendarHasEveryYearOfUse() {
        let lib = Fixtures.library(.typical)
        XCTAssertEqual(History.years(lib.captures, now: now, calendar: cal), [2026, 2025, 2024])
        XCTAssertEqual(History.years([], now: now, calendar: cal), [2026])
        let months = History.months(year: 2026, now: now, calendar: cal)
        XCTAssertEqual(months.count, 9)
        XCTAssertEqual(cal.component(.month, from: months[0].first), 9)
        XCTAssertEqual(History.months(year: 2025, now: now, calendar: cal).count, 12)
    }

    func testLevelsSplitBusyDaysAtTheQuartiles() {
        let levels = History.Levels([0, 1, 2, 3, 4, 5, 6, 7, 8, 20])
        XCTAssertEqual(levels.level(0), 0)
        XCTAssertEqual(levels.level(1), 1)
        XCTAssertEqual(levels.level(20), 4)
        var last = 0
        for n in 0...30 { let l = levels.level(n); XCTAssertGreaterThanOrEqual(l, last); last = l }
    }

    func testWeeksEndWithThisWeek() {
        let weeks = History.weeks(count: 53, now: now, calendar: cal)
        XCTAssertEqual(weeks.count, 53)
        XCTAssertTrue(weeks.allSatisfy { $0.count == 7 })
        let days = weeks.flatMap { $0 }.compactMap { $0 }
        XCTAssertEqual(days.last, cal.startOfDay(for: now))
        for (a, b) in zip(days, days.dropFirst()) { XCTAssertEqual(cal.dateComponents([.day], from: a, to: b).day, 1) }
    }

    func testOneMonthIsTheMonthThatHoldsTheDate() {
        let m = History.month(Fixtures.daysAgo(40, 15, 0), calendar: cal)
        XCTAssertEqual(cal.component(.month, from: m.first), 8)
        XCTAssertEqual(cal.component(.day, from: m.first), 1)
        XCTAssertEqual(m.rows.flatMap { $0 }.compactMap { $0 }.count, 31)
        XCTAssertEqual(History.month(now, calendar: cal), History.months(count: 1, now: now, calendar: cal)[0])
    }

    func testMonthsAreWholeWeeks() {
        let months = History.months(count: 13, now: now, calendar: cal)
        XCTAssertEqual(months.count, 13)
        for m in months {
            XCTAssertTrue(m.rows.allSatisfy { $0.count == 7 })
            let days = m.rows.flatMap { $0 }.compactMap { $0 }
            XCTAssertEqual(days.count, cal.range(of: .day, in: .month, for: m.first)!.count)
        }
    }
}

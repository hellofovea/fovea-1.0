import XCTest
@testable import WindowBenchCore

final class GroupingTests: XCTestCase {
    let index = LibraryIndex(BenchFixtures.library(.typical))

    private func headers(_ items: [ProjectListItem]) -> [ProjectGroup] {
        items.compactMap { if case .header(let g) = $0 { return g } else { return nil } }
    }

    func testGroupsFollowTheBriefsOrder() {
        let groups = headers(ProjectIndex.list(index, failed: .withStuck, olderOpen: false))
        let order: [ProjectGroup] = [.stuck, .toLook, .running, .earlier]
        XCTAssertEqual(groups, order.filter(groups.contains), "stuck → to look at → running → earlier")
        XCTAssertFalse(groups.contains(.failed))
    }

    func testFailedGoesLastInTheNotchsOrder() {
        let items = ProjectIndex.list(index, failed: .last, olderOpen: false)
        let groups = headers(items)
        XCTAssertTrue(groups.contains(.failed))
        if let failed = groups.firstIndex(of: .failed), let earlier = groups.firstIndex(of: .earlier) {
            XCTAssertLessThan(failed, earlier)
        }
        if let failed = groups.firstIndex(of: .failed), let stuck = groups.firstIndex(of: .stuck) {
            XCTAssertGreaterThan(failed, stuck)
        }
    }

    func testEveryProjectAppearsOnceAndThereIsNoCatchAllBucket() {
        let items = ProjectIndex.list(index, failed: .withStuck, olderOpen: true)
        let ids = items.compactMap { if case .project(let s) = $0 { return s.id } else { return nil } }
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(Set(ids), Set(index.library.projects.map(\.id)))
        let titles = ProjectGroup.allCases.map(\.title)
        for forbidden in ["Uncategorized", "Other", "Quick tasks", "Misc"] {
            XCTAssertFalse(titles.contains(forbidden))
        }
    }

    func testQuietProjectsFoldIntoOlder() {
        let closed = ProjectIndex.list(index, failed: .withStuck, olderOpen: false)
        guard case .olderFold(let count)? = closed.last else { return XCTFail("the fold comes last") }
        let quiet = ProjectIndex.summaries(index, failed: .withStuck).filter(\.sunk)
        XCTAssertEqual(count, quiet.count)
        XCTAssertGreaterThanOrEqual(count, 12)
        XCTAssertEqual(ProjectIndex.olderTitle(12), "12 older projects")
        XCTAssertEqual(ProjectIndex.olderTitle(1), "1 older project")
        let open = ProjectIndex.list(index, failed: .withStuck, olderOpen: true)
        XCTAssertEqual(open.count, closed.count + count)
    }

    func testAProjectShowsItsMostUrgentState() {
        let site = ProjectIndex.summaries(index, failed: .withStuck).first { $0.id == "p-site" }
        XCTAssertEqual(site?.state, .waiting)
        XCTAssertEqual(site?.group, .stuck)
        let tokens = ProjectIndex.summaries(index, failed: .withStuck).first { $0.id == "p-tokens" }
        XCTAssertEqual(tokens?.state, .unobserved)
        XCTAssertEqual(tokens?.group, .earlier)
    }

    func testSeenRunsFoldIntoEarlierRuns() {
        let split = ThreadRuns.split(index.runs(in: "t-copy"))
        XCTAssertEqual(split.earlier.count, 12)
        XCTAssertEqual(Set(split.visible.map(\.id)), ["r-deploy", "r-bullets"])
        XCTAssertEqual(ThreadRuns.earlierTitle(12), "12 earlier runs")
        // A thread you've seen all of keeps its latest run in view.
        let me = ThreadRuns.split(index.runs(in: "t-me"))
        XCTAssertEqual(me.visible.map(\.id), ["r-me"])
        XCTAssertTrue(me.earlier.isEmpty)
    }
}

final class LinesTests: XCTestCase {
    let index = LibraryIndex(BenchFixtures.library(.typical))

    func testProjectMeta() {
        let site = index.projectByID["p-site"]!
        XCTAssertEqual(Lines.projectMeta(site, index: index), "2 threads · Codex, Claude Code · 16 runs this week")
        let old = index.projectByID["p-old-0"]!
        XCTAssertEqual(Lines.projectMeta(old, index: index), "1 thread · Codex")
    }

    func testSinceLastVisitCountsOnlyWhatIsNew() {
        let site = index.projectByID["p-site"]!
        XCTAssertEqual(Lines.sinceLastVisit(site, index: index), "3 runs · 2 files changed · 1 waiting for you")
    }

    func testSinceLastVisitIsLeftOutWhenThereIsNothing() {
        var library = BenchFixtures.library(.typical)
        let i = library.projects.firstIndex { $0.id == "p-mac" }!
        library.projects[i].lastVisit = library.now
        let index = LibraryIndex(library)
        XCTAssertNil(Lines.sinceLastVisit(index.projectByID["p-mac"]!, index: index))
        XCTAssertNil(Lines.sinceLastVisit(index.projectByID["p-tokens"]!, index: index), "never visited: nothing to compare")
    }

    func testEvidenceLines() {
        XCTAssertEqual(Lines.evidence(index.runByID["r-bullets"]!), "Edited Second.tsx +4 −4 · npm test passed")
        XCTAssertEqual(Lines.evidence(index.runByID["r-rate"]!), "Edited 2 files +10 −1 · npm test · exit 1")
        XCTAssertEqual(Lines.evidence(index.runByID["r-dark"]!), "Handed to your open session")
        XCTAssertTrue(Lines.evidence(index.runByID["r-deploy"]!).hasPrefix("Asks to run npm run deploy:preview"))
    }

    func testAges() {
        let now = BenchFixtures.now
        XCTAssertEqual(Lines.age(now.addingTimeInterval(-20), now: now), "now")
        XCTAssertEqual(Lines.age(now.addingTimeInterval(-4 * 60), now: now), "4m")
        XCTAssertEqual(Lines.age(now.addingTimeInterval(-3 * 3600), now: now), "3h")
        XCTAssertEqual(Lines.age(now.addingTimeInterval(-2 * 86_400), now: now), "2d")
        XCTAssertEqual(Lines.age(now.addingTimeInterval(-12 * 86_400), now: now), "09-18")
    }

    func testCaptureLine() {
        let line = Lines.capture(index.captureByID["c-site-shot"]!, index: index)
        XCTAssertTrue(line.hasPrefix("screenshot · Safari · "))
        XCTAssertTrue(line.hasSuffix("→ 第二屏文案 · Codex"))
        XCTAssertTrue(Lines.capture(index.captureByID["c-quick-spring"]!, index: index).hasSuffix("→ quick task"))
        XCTAssertTrue(Lines.capture(index.captureByID["c-downloads"]!, index: index).hasSuffix("not used"))
    }

    func testOrdinals() {
        XCTAssertEqual(["1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "21st"],
                       [1, 2, 3, 4, 11, 12, 13, 21].map(Lines.ordinal))
    }
}

final class SearchTests: XCTestCase {
    let index = LibraryIndex(BenchFixtures.library(.typical))

    func testFindsThreadsRunsAndCapturesByYourWords() {
        let hits = SearchEngine.search(SearchQuery(text: "第二屏"), in: index)
        XCTAssertTrue(hits.contains { $0.scope == .threads && $0.targetID == "t-copy" })
        XCTAssertTrue(hits.contains { $0.scope == .runs && $0.targetID == "r-deploy" })
        XCTAssertTrue(hits.contains { $0.scope == .captures })
    }

    func testFindsFilePathsAgentsSunkProjectsAndRecognizedText() {
        XCTAssertTrue(SearchEngine.search(SearchQuery(text: "Second.tsx"), in: index).contains { $0.targetID == "r-bullets" })
        XCTAssertTrue(SearchEngine.search(SearchQuery(text: "codex"), in: index).contains { $0.targetID == "t-copy" })
        XCTAssertTrue(SearchEngine.search(SearchQuery(text: "blog-migration"), in: index).contains { $0.targetID == "p-old-1" })
        let ocr = SearchEngine.search(SearchQuery(text: "100 read requests"), in: index)
        XCTAssertTrue(ocr.contains { $0.targetID == "c-stripe" })
    }

    func testHitRangesPointAtTheMatch() {
        let hit = SearchEngine.search(SearchQuery(text: "bullets verb"), in: index).first { $0.targetID == "r-bullets" }
        XCTAssertNotNil(hit)
        let text = hit!.text as NSString
        let words = hit!.ranges.map { text.substring(with: NSRange(location: $0[0], length: $0[1])).lowercased() }
        XCTAssertEqual(words, ["bullets", "verb"])
    }

    func testScopesAndChipsNarrow() {
        let runsOnly = SearchEngine.search(SearchQuery(text: "第二屏", scopes: [.runs]), in: index)
        XCTAssertTrue(runsOnly.allSatisfy { $0.scope == .runs })
        let cursor = SearchEngine.search(SearchQuery(text: "", agent: .cursor), in: index)
        XCTAssertFalse(cursor.isEmpty)
        XCTAssertFalse(cursor.contains { $0.targetID == "t-copy" })
        XCTAssertTrue(SearchEngine.search(SearchQuery(text: "  "), in: index).isEmpty)
    }
}

final class HistoryTests: XCTestCase {
    func testSummaryCountsOnlyTheLastThirtyDays() {
        let now = BenchFixtures.now
        let records = [
            SessionRecord(agent: .claudeCode, projectPath: "/u/code/a", projectName: "a", modified: now.addingTimeInterval(-3600)),
            SessionRecord(agent: .claudeCode, projectPath: "/u/code/a", projectName: "a", modified: now.addingTimeInterval(-5 * 86_400)),
            SessionRecord(agent: .claudeCode, projectPath: "/u/code/b", projectName: "b", modified: now.addingTimeInterval(-2 * 86_400)),
            SessionRecord(agent: .codex, modified: now.addingTimeInterval(-86_400)),
            SessionRecord(agent: .cursor, modified: now.addingTimeInterval(-40 * 86_400)),
        ]
        let summary = HistoryAggregate.summarize(records, now: now)
        XCTAssertEqual(summary.sessions, 4)
        XCTAssertEqual(summary.agents, [.claudeCode, .codex])
        XCTAssertEqual(summary.projects.map(\.name), ["a", "b"])
        XCTAssertEqual(summary.projects.first?.sessions, 2)
        XCTAssertEqual(summary.unattributed[.codex], 1)
        XCTAssertNil(summary.unattributed[.cursor])
    }

    func testDecodesClaudeProjectFoldersAgainstTheDisk() {
        let dirs: Set<String> = ["/Users", "/Users/me", "/Users/me/code", "/Users/me/code/app-ui-v1",
                                 "/Users/me/things", "/Users/me/things/fovea website"]
        let a = HistoryAggregate.decodeClaudeFolder("-Users-me-code-app-ui-v1", exists: dirs.contains)
        XCTAssertEqual(a.path, "/Users/me/code/app-ui-v1")
        XCTAssertEqual(a.display, "app-ui-v1")
        let b = HistoryAggregate.decodeClaudeFolder("-Users-me-things-fovea-website", exists: dirs.contains)
        XCTAssertEqual(b.display, "fovea website")
        let c = HistoryAggregate.decodeClaudeFolder("-Users-me-gone-project", exists: dirs.contains)
        XCTAssertNil(c.path)
        XCTAssertEqual(c.display, "-Users-me-gone-project")
    }

    func testScannedProjectsCarryTheirCounts() {
        let now = BenchFixtures.now
        let summary = HistoryAggregate.summarize([SessionRecord(agent: .claudeCode, projectPath: "/u/a", projectName: "a", modified: now)], now: now)
        let projects = HistoryAggregate.projects(from: summary)
        XCTAssertEqual(projects.first?.scan?.sessions, 1)
        let index = LibraryIndex(Library(now: now, projects: projects))
        XCTAssertTrue(Lines.projectMeta(projects[0], index: index).hasPrefix("1 session · Claude Code · last active"))
    }
}

final class DiffTests: XCTestCase {
    func testChangedWordsArePaired() {
        let (old, new) = DiffHunk.changedRanges("  eyebrow: \"Why\",", "  eyebrow: \"How\",")
        XCTAssertEqual(old, [12, 3])
        XCTAssertEqual(new, [12, 3])
    }

    func testFixtureHunksAreAnnotated() {
        let run = BenchFixtures.library(.typical).runs.first { $0.id == "r-bullets" }!
        let lines = run.edits[0].hunks[0].lines
        XCTAssertFalse(lines.first { $0.kind == .removed }!.changed.isEmpty)
        XCTAssertTrue(lines.filter { $0.kind == .context }.allSatisfy { $0.changed.isEmpty })
    }
}

final class VariantTests: XCTestCase {
    func testRegistryIsWellFormed() {
        let ids = Variants.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "decision ids are unique")
        for decision in Variants.all {
            XCTAssertGreaterThanOrEqual(decision.options.count, 2, decision.id)
            XCTAssertEqual(Set(decision.options.map(\.id)).count, decision.options.count, decision.id)
        }
        for page in BenchPage.allCases where page != .settings {
            XCTAssertFalse(Variants.decisions(on: page).isEmpty, page.rawValue)
        }
    }

    func testValuesReadDefaultsAndRoundTrip() throws {
        var values = VariantValues()
        XCTAssertEqual(values.get(StateStyle.self), .glyph)
        values.set(DiffStyle.split)
        XCTAssertEqual(values.get(DiffStyle.self), .split)
        values["diff"] = "nonsense"
        XCTAssertEqual(values.get(DiffStyle.self), .monoUnified, "an unknown value reads as the default")
        let data = try JSONEncoder().encode(values)
        XCTAssertEqual(try JSONDecoder().decode(VariantValues.self, from: data), values)
    }

    func testEveryFixtureSetBuilds() {
        for set in FixtureSet.allCases {
            let index = LibraryIndex(BenchFixtures.library(set))
            for run in index.library.runs { XCTAssertNotNil(index.threadByID[run.threadID], "\(set) \(run.id)") }
            for thread in index.library.threads { XCTAssertNotNil(index.projectByID[thread.projectID], "\(set) \(thread.id)") }
        }
    }

    func testSearchRanksByStateThenDateWithinAScope() {
        let index = LibraryIndex(BenchFixtures.typical())
        let hits = SearchEngine.search(SearchQuery(text: "e"), in: index)
        XCTAssertFalse(hits.isEmpty)
        for (a, b) in zip(hits, hits.dropFirst()) where a.scope == b.scope {
            let ua = a.state?.urgency ?? RunState.seen.urgency, ub = b.state?.urgency ?? RunState.seen.urgency
            XCTAssertLessThanOrEqual(ua, ub, "\(a.text) before \(b.text)")
            if ua == ub { XCTAssertGreaterThanOrEqual(a.date, b.date) }
        }
    }

    func testSearchCountLineCountsProjects() {
        let index = LibraryIndex(BenchFixtures.typical())
        let hits = SearchEngine.search(SearchQuery(text: "bullets"), in: index)
        let projects = Set(hits.compactMap(\.projectID)).count
        XCTAssertGreaterThan(projects, 0)
        XCTAssertEqual(Lines.searchCount(hits), "\(hits.count) result\(hits.count == 1 ? "" : "s") in \(projects) project\(projects == 1 ? "" : "s")")
        XCTAssertEqual(Lines.searchCount([]), "0 results")
    }

    func testChangeCountsMatchTheirHunks() {
        for set in FixtureSet.allCases {
            for run in BenchFixtures.library(set).runs {
                for case .edit(let change) in run.evidence where !change.hunks.isEmpty {
                    let lines = change.hunks.flatMap(\.lines)
                    XCTAssertEqual(change.added, lines.filter { $0.kind == .added }.count, "\(run.id) \(change.path)")
                    XCTAssertEqual(change.removed, lines.filter { $0.kind == .removed }.count, "\(run.id) \(change.path)")
                    for hunk in change.hunks {
                        let old = hunk.lines.filter { $0.kind != .added }.count, new = hunk.lines.filter { $0.kind != .removed }.count
                        XCTAssertTrue(hunk.header.contains(",\(old) +") && hunk.header.contains(",\(new) @@"), "\(run.id) \(hunk.header)")
                    }
                }
            }
        }
    }

    func testSnippetStartsAndEndsOnWholeWords() {
        let text = "Rate limits\nThe API allows up to 100 read requests per second per account and 100 write requests per minute for every key"
        let at = (text as NSString).range(of: "write")
        let (snippet, ranges) = SearchEngine.snippet(text, ranges: [[at.location, at.length]], radius: 20)
        XCTAssertTrue(snippet.hasPrefix("…"))
        XCTAssertFalse(snippet.contains("\n"))
        XCTAssertFalse(snippet.contains("  "))
        // The first and last words are whole words of the text.
        let words = Set(text.split(whereSeparator: \.isWhitespace).map(String.init))
        let shown = snippet.trimmingCharacters(in: CharacterSet(charactersIn: "…")).split(separator: " ").map(String.init)
        XCTAssertTrue(words.contains(shown.first ?? ""), snippet)
        XCTAssertTrue(words.contains(shown.last ?? ""), snippet)
        // The hit's range still points at the hit.
        XCTAssertEqual((snippet as NSString).substring(with: NSRange(location: ranges[0][0], length: ranges[0][1])), "write")
    }
}

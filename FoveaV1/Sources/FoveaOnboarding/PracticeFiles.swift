import AppKit
import FoveaCore
import OnboardingCore
import FoveaKit

/// The practice files (Oct 8, Oct 9): the pages open in the browser's tabs (the weekly update's
/// three work pages, and the trail report for the trip), real local pages; your packing list and a
/// trail map on the desktop; and, once the agent writes it, the weekly update. There for the first
/// run, cleared at its end. The shipping app keeps them in Fovea's own practice window
/// (REAL_MAC.md: files on the Desktop make macOS ask for Desktop access); the prototype keeps them
/// in a folder of its own, which the mock desktop shows, and deletes it.
@MainActor
final class PracticeFiles {
    nonisolated static let list = "Packing list.txt"
    nonisolated static let map = "Trail map.pdf"
    /// What the agent writes for the weekly update.
    nonisolated static let update = "weekly-update.md"
    nonisolated static let listStart = "Packing list\n\n- Tent\n- Sleeping bag\n- Headlamp\n- Stove\n"
    /// The tabs' pages, in a folder of their own.
    nonisolated static let pagesFolder = "pages"
    nonisolated static let photo = "valley.jpg"

    let folder: URL

    /// Snapshots, the smoke run and the play keep a folder of their own, so they never touch a run
    /// that's open.
    init(separate: Bool = false) {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(separate ? "Fovea Practice (harness)" : "Fovea Practice", isDirectory: true)
    }

    func url(_ name: String) -> URL { folder.appendingPathComponent(name) }

    var pages: URL { url(Self.pagesFolder) }
    func page(_ tab: PracticeTab) -> URL { pages.appendingPathComponent("\(tab.rawValue).html") }

    func text(_ name: String) -> String? { try? String(contentsOf: url(name), encoding: .utf8) }

    func write(_ name: String, _ text: String) {
        try? text.write(to: url(name), atomically: true, encoding: .utf8)
    }

    func exists(_ name: String) -> Bool { FileManager.default.fileExists(atPath: url(name).path) }

    var exists: Bool { FileManager.default.fileExists(atPath: folder.path) }

    /// Fresh copies, every run.
    func create() {
        remove()
        try? FileManager.default.createDirectory(at: pages, withIntermediateDirectories: true)
        if let source = FoveaFiles.url(OT.Practice.photo) {
            try? FileManager.default.copyItem(at: source, to: pages.appendingPathComponent(Self.photo))
        }
        try? Self.css.write(to: pages.appendingPathComponent("pages.css"), atomically: true, encoding: .utf8)
        for tab in PracticeTab.allCases {
            try? Self.html(tab).write(to: page(tab), atomically: true, encoding: .utf8)
        }
        write(Self.list, Self.listStart)
        makeMap()
    }

    func remove() {
        try? FileManager.default.removeItem(at: folder)
    }

    /// A one-page trail map, drawn here so there's a real PDF to point at.
    private func makeMap() {
        var box = CGRect(x: 0, y: 0, width: 420, height: 300)
        guard let context = CGContext(url(Self.map) as CFURL, mediaBox: &box, nil) else { return }
        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        NSAttributedString(string: "High valley loop", attributes: [.font: NSFont.systemFont(ofSize: 20, weight: .semibold)])
            .draw(at: CGPoint(x: 28, y: 250))
        NSAttributedString(string: "6.2 km · 480 m up · trailhead at the lodges", attributes: [.font: NSFont.systemFont(ofSize: 12)])
            .draw(at: CGPoint(x: 28, y: 228))
        let path = NSBezierPath()
        path.move(to: CGPoint(x: 40, y: 60))
        path.curve(to: CGPoint(x: 380, y: 170), controlPoint1: CGPoint(x: 160, y: 40), controlPoint2: CGPoint(x: 260, y: 200))
        path.lineWidth = 3
        NSColor.systemOrange.setStroke()
        path.stroke()
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()
    }

    // MARK: The pages

    /// Each tab's page. The parts a task takes are marked `data-fovea`, so the page can say where
    /// they are; the trail report's paragraphs are what the highlighter takes.
    nonisolated static func html(_ tab: PracticeTab) -> String {
        let body: String
        switch tab {
        case .analytics:
            let days = [("Mon", 44), ("Tue", 58), ("Wed", 61), ("Thu", 72), ("Fri", 80), ("Sat", 52), ("Sun", 66)]
            let bars = days.map { "<div class=\"day\"><div class=\"bar\" style=\"height:\($0.1)%\"></div><span>\($0.0)</span></div>" }.joined()
            body = """
            <div class="top"><b>Northwind Insights</b><span class="on">Overview</span><span>Funnels</span><span>Retention</span><span class="right">This week ▾</span></div>
            <main>
              <h1>This week</h1>
              <div class="cards" data-fovea="numbers">
                <div class="card"><div class="label">Signups</div><div class="num">1,284</div><div class="up">▲ 18% on last week</div></div>
                <div class="card"><div class="label">Activation</div><div class="num">41%</div><div class="flat">No change</div></div>
                <div class="card"><div class="label">Churned</div><div class="num">23</div><div class="up">▼ 4 on last week</div></div>
              </div>
              <div class="chart" data-fovea="chart"><div class="label">Signups by day</div><div class="bars">\(bars)</div></div>
            </main>
            """
        case .github:
            let prs = [("#423", "Update dependencies", "today"), ("#421", "Retry failed uploads", "Wed"),
                       ("#420", "Dark mode for Settings", "Tue"), ("#418", "Onboarding: permissions in one step", "Tue"),
                       ("#415", "Fix crash when closing a window", "Mon"), ("#412", "Faster search on large libraries", "Mon")]
            let rows = prs.map { "<div class=\"pr\"><span class=\"merged\">⑂</span><b>\($0.1)</b><span class=\"meta\">\($0.0) · merged \($0.2)</span></div>" }.joined(separator: "\n    ")
            body = """
            <div class="top"><b>northwind / app</b><span>Code</span><span class="on">Pull requests</span><span>Issues</span><span>Actions</span></div>
            <main>
              <div class="filter">is:pr is:merged merged:this-week</div>
              <div class="list" data-fovea="prs">
                <div class="head">6 merged this week</div>
                \(rows)
              </div>
            </main>
            """
        case .support:
            let tickets = [("Can't sign in with Okta", "SSO", "3 days"), ("Invoice shows the wrong seat count", "Billing", "1 day"),
                           ("SSO login loops back to the start", "SSO", "1 day"), ("Export to CSV is empty", "Exports", "5 hours")]
            let rows = tickets.map { "<div class=\"ticket\"><b>\($0.0)</b><span class=\"tag\">\($0.1)</span><span class=\"meta\">open \($0.2)</span></div>" }.joined(separator: "\n    ")
            body = """
            <div class="top"><b>Northwind Support</b><span class="on">Inbox</span><span>Customers</span><span>Reports</span></div>
            <main>
              <div class="cards" data-fovea="tickets">
                <div class="card"><div class="label">Open tickets</div><div class="num">14</div><div class="up">▼ 5 since Monday</div></div>
                <div class="card"><div class="label">Oldest open</div><div class="num">3 days</div></div>
                <div class="card"><div class="label">Top topic</div><div class="num small">Signing in with SSO</div><div class="label">6 tickets</div></div>
              </div>
              <div class="list">
                <div class="head">Newest</div>
                \(rows)
              </div>
            </main>
            """
        case .trail:
            let paragraphs = PracticePage.paragraphs.map { "  <p>\($0)</p>" }.joined(separator: "\n")
            body = """
            <div class="top"><b>Trail report</b><span class="on">Conditions</span><span>Huts</span><span>Maps</span></div>
            <main class="article">
              <p class="meta">\(PracticePage.meta)</p>
              <h1 class="title">\(PracticePage.title)</h1>
              <img class="photo" src="\(photo)" alt="Tents in fresh snow below the peaks">
            \(paragraphs)
            </main>
            """
        }
        return """
        <!doctype html>
        <html lang="en">
        <head><meta charset="utf-8"><title>\(tab.title)</title><link rel="stylesheet" href="pages.css"></head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    nonisolated static let css = """
    body { margin: 0; font: 14px/1.5 -apple-system, "SF Pro Text", "Helvetica Neue", sans-serif; color: #1d1d1f; background: #fff; }
    .top { display: flex; align-items: center; gap: 18px; padding: 11px 28px; border-bottom: 1px solid #ececec; font-size: 13px; color: #6e6e73; }
    .top b { color: #1d1d1f; font-size: 14px; margin-right: 6px; }
    .top .on { color: #1d1d1f; font-weight: 600; }
    .top .right { margin-left: auto; }
    main { padding: 18px 28px; }
    h1 { font-size: 20px; margin: 0 0 12px; letter-spacing: -0.01em; }
    .cards { display: flex; gap: 12px; margin-bottom: 14px; }
    .card { flex: 1; border: 1px solid #e8e8ea; border-radius: 10px; padding: 11px 14px; }
    .label { font-size: 12px; color: #6e6e73; }
    .num { font-size: 26px; font-weight: 700; margin-top: 2px; letter-spacing: -0.01em; }
    .num.small { font-size: 16px; margin-top: 6px; }
    .up { color: #1a7f37; font-size: 12px; font-weight: 600; }
    .flat { color: #86868b; font-size: 12px; font-weight: 600; }
    .chart { border: 1px solid #e8e8ea; border-radius: 10px; padding: 11px 14px; }
    .bars { display: flex; align-items: flex-end; gap: 12px; height: 150px; margin-top: 8px; }
    .day { flex: 1; height: 100%; display: flex; flex-direction: column; justify-content: flex-end; align-items: center; gap: 4px; font-size: 11px; color: #86868b; }
    .bar { width: 100%; background: #5b6cf0; border-radius: 5px 5px 0 0; }
    .filter { font: 12px ui-monospace, Menlo, monospace; color: #57606a; border: 1px solid #d0d7de; border-radius: 6px; padding: 6px 10px; margin-bottom: 12px; }
    .list { border: 1px solid #d0d7de; border-radius: 8px; }
    .head { padding: 9px 14px; background: #f6f8fa; border-bottom: 1px solid #d0d7de; font-size: 13px; font-weight: 600; border-radius: 8px 8px 0 0; }
    .pr, .ticket { display: flex; align-items: center; gap: 10px; padding: 9px 14px; border-bottom: 1px solid #eaeef2; font-size: 13.5px; }
    .pr:last-child, .ticket:last-child { border-bottom: 0; }
    .merged { color: #8250df; font-weight: 700; }
    .meta { margin-left: auto; font-size: 12px; color: #6e7781; }
    .tag { font-size: 11px; color: #57606a; background: #eaeef2; border-radius: 10px; padding: 1px 8px; }
    .article { width: 600px; margin: 0 auto; padding-top: 18px; }
    .article .meta { text-transform: uppercase; letter-spacing: 0.06em; font-size: 11px; font-weight: 600; color: #86868b; margin: 0 0 6px; }
    .article .title { font-size: 26px; line-height: 1.15; margin: 0 0 12px; }
    .photo { display: block; width: 600px; height: 150px; object-fit: cover; border-radius: 10px; margin: 0 0 12px; }
    .article p { margin: 0 0 10px; }
    """
}

/// The trail report's words: the passages the highlighter takes (and what it takes when the page
/// hasn't said yet).
enum PracticePage {
    static let title = "Snow comes early to the high valleys"
    static let meta = "October 6 · 3 min read"
    static let paragraphs = [
        "The first storm of the season moved through overnight and left the upper trails under a hand's depth of fresh snow. Rangers expect the pass to stay open through the weekend.",
        "Below the tree line the change is quieter. Streams that ran clear all summer have turned milky with meltwater, and the last of the lodges have pulled their chairs inside for the year.",
        "If you're heading up, start early. The light goes by four, and the wind on the ridge picks up after noon.",
    ]
}

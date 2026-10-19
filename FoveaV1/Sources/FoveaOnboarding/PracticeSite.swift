import AppKit
import WebKit
import OnboardingCore

/// Where a page's parts are, in page points (the page's top-left is 0, 0), as the page itself
/// reports them: each paragraph's box, its lines and its words, and the parts a task takes
/// (`data-fovea`: this week's numbers, the merged pull requests, the chart).
struct PageLayout: Equatable {
    struct Paragraph: Equatable {
        var rect: CGRect
        var lines: [CGRect]
        var text: String
    }
    var paragraphs: [Paragraph] = []
    var parts: [String: CGRect] = [:]
}

/// One tab's page, a real local page loaded in a WKWebView (Oct 9). The browser on the mock screen
/// shows its picture, retaken after every load. The web view lives in a window of its own, out of
/// sight: a web view in no window may never draw, and one inside the scaled mock screen wouldn't
/// scale. One per tab, loaded up front, so switching tabs is instant.
@MainActor
final class PracticeSite: NSObject, WKNavigationDelegate {
    let tab: PracticeTab
    /// After each load: where the parts are, and the page's picture (nil if it didn't come).
    var onLayout: ((PracticeTab, PageLayout, NSImage?) -> Void)?

    private let webView: WKWebView
    private let window: NSWindow
    private var page: URL?
    private var folder: URL?
    private var generation = 0

    init(tab: PracticeTab) {
        self.tab = tab
        let size = OT.Site.size
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: CGRect(origin: .zero, size: size), configuration: configuration)
        window = NSWindow(contentRect: CGRect(origin: OT.Site.hiddenOrigin, size: size), styleMask: [.borderless],
                          backing: .buffered, defer: false)
        super.init()
        webView.navigationDelegate = self
        window.contentView = webView
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.alphaValue = 0
        window.hasShadow = false
        window.collectionBehavior = [.transient, .ignoresCycle]
    }

    func load(_ files: PracticeFiles) {
        page = files.page(tab)
        folder = files.folder
        window.orderBack(nil)
        load()
    }

    /// Load it again, from the files, not the cache (a plain load would keep the old stylesheet).
    /// The run is over: the page and its window go.
    func close() {
        webView.stopLoading()
        window.orderOut(nil)
        window.close()
    }

    func reload() {
        guard page != nil else { return }
        if webView.url == nil { load(); return }
        generation += 1
        webView.reloadFromOrigin()
    }

    private func load() {
        guard let page, let folder else { return }
        generation += 1
        webView.loadFileURL(page, allowingReadAccessTo: folder)
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated { self.measure() }
    }

    /// Where everything is, then the picture. The script returns a string, so an odd page can't
    /// trip the bridge.
    private func measure() {
        let generation = self.generation
        webView.evaluateJavaScript(Self.script) { [weak self] result, _ in
            MainActor.assumeIsolated {
                guard let self, generation == self.generation else { return }
                let layout = (result as? String).flatMap(Self.layout(from:)) ?? PageLayout()
                self.snapshot(layout, generation: generation)
            }
        }
    }

    private func snapshot(_ layout: PageLayout, generation: Int) {
        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(origin: .zero, size: OT.Site.size)
        configuration.afterScreenUpdates = false
        var delivered = false
        let deliver: (NSImage?) -> Void = { [weak self] image in
            guard let self, !delivered, generation == self.generation else { return }
            delivered = true
            self.onLayout?(self.tab, layout, image)
        }
        webView.takeSnapshot(with: configuration) { image, _ in
            MainActor.assumeIsolated { deliver(image) }
        }
        // A snapshot that never comes back still lets the run go on, with the last picture.
        DispatchQueue.main.asyncAfter(deadline: .now() + OT.Site.snapshotTimeout) {
            MainActor.assumeIsolated { deliver(nil) }
        }
    }

    // MARK: Reading the page

    private static let script = """
    (() => {
      const box = e => { const b = e.getBoundingClientRect(); return [b.left, b.top, b.width, b.height]; };
      const out = { paragraphs: [], parts: {} };
      document.querySelectorAll('main.article p:not(.meta)').forEach(p => {
        const range = document.createRange();
        range.selectNodeContents(p);
        const lines = Array.from(range.getClientRects()).map(b => [b.left, b.top, b.width, b.height]);
        out.paragraphs.push({ rect: box(p), lines: lines, text: p.innerText });
      });
      document.querySelectorAll('[data-fovea]').forEach(e => { out.parts[e.dataset.fovea] = box(e); });
      return JSON.stringify(out);
    })()
    """

    /// The script's answer as a layout; a line split into pieces (a word in bold, say) is one line.
    static func layout(from json: String) -> PageLayout? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        func rect(_ value: Any?) -> CGRect? {
            guard let a = value as? [Double], a.count == 4 else { return nil }
            return CGRect(x: a[0], y: a[1], width: a[2], height: a[3])
        }
        var layout = PageLayout()
        for item in object["paragraphs"] as? [[String: Any]] ?? [] {
            guard let box = rect(item["rect"]) else { continue }
            let pieces = (item["lines"] as? [[Double]] ?? []).compactMap { rect($0) }.filter { $0.width > 1 }
            var lines: [CGRect] = []
            for piece in pieces.sorted(by: { ($0.minY, $0.minX) < ($1.minY, $1.minX) }) {
                if let last = lines.last, abs(last.midY - piece.midY) < piece.height / 2 {
                    lines[lines.count - 1] = last.union(piece)
                } else {
                    lines.append(piece)
                }
            }
            layout.paragraphs.append(.init(rect: box, lines: lines.isEmpty ? [box] : lines, text: item["text"] as? String ?? ""))
        }
        for (name, value) in object["parts"] as? [String: Any] ?? [:] {
            if let r = rect(value) { layout.parts[name] = r }
        }
        return layout
    }
}

import AppKit
import SwiftUI
import CapturesCore

/// The referent tab: Fovea's mark for a thing you took, set in your words right after the
/// words that pointed at it. Its number in SF Mono on a small squared tab in the scheme's mark
/// (Macula's highlighter, Blue Pencil's ultramarine), the same tab that numbers the pictures
/// below; with a small picture of the thing beside it when the card shows no pictures.
@MainActor
enum Chips {
    private struct Key: Hashable {
        let art: String, index: Int, height: CGFloat, dark: Bool, surface: Surface, thumb: Bool
        /// The tab's color, so a new accent draws new tabs.
        let mark: Color
    }
    private static var cache: [Key: NSImage] = [:]

    /// The tab's height and how far below the baseline it sits, for text of `size` points: a
    /// little shorter than the line, centered on the lowercase letters.
    static func metrics(for size: CGFloat) -> (height: CGFloat, baseline: CGFloat) {
        let font = NSFont.systemFont(ofSize: size)
        let height = (font.ascender - font.descender - 2).rounded()
        return (height, (font.descender + 1).rounded())
    }

    static func image(_ a: Attachment, height h: CGFloat, palette: Palette, thumbnail: Bool = false) -> NSImage {
        let key = Key(art: "\(a.kind.rawValue):\(a.art ?? a.text):\(a.crop.x),\(a.crop.y)", index: a.index,
                      height: h, dark: palette.isDark, surface: palette.surface, thumb: thumbnail, mark: palette.mark)
        if let hit = cache[key] { return hit }

        let digit = NSAttributedString(string: "\(a.index)", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: (h * 0.68).rounded(), weight: .semibold),
            .foregroundColor: NSColor(palette.onMark),
        ])
        let digitSize = digit.size()
        let tabWidth = max(h, (digitSize.width + 8).rounded(.up))
        let thumbW = thumbnail ? (a.kind == .region ? (h * 1.4).rounded() : h) : 0
        let size = NSSize(width: tabWidth + (thumbnail ? 3 + thumbW : 0), height: h)

        let image = draw(size) { _ in
            let tab = NSRect(x: 0, y: 0, width: tabWidth, height: h)
            let radius = (h * 0.24).rounded()
            NSColor(palette.mark).setFill()
            NSBezierPath(roundedRect: tab, xRadius: radius, yRadius: radius).fill()
            digit.draw(at: NSPoint(x: ((tabWidth - digitSize.width) / 2).rounded(), y: ((h - digitSize.height) / 2).rounded()))
            guard thumbnail else { return }
            let thumb = NSRect(x: tabWidth + 3, y: 0, width: thumbW, height: h)
            let clip = NSBezierPath(roundedRect: thumb, xRadius: radius, yRadius: radius)
            NSGraphicsContext.saveGraphicsState()
            clip.addClip()
            switch a.kind {
            case .region:
                if let region = Art.region(a) {
                    let scale = max(thumb.width / region.size.width, thumb.height / region.size.height)
                    let drawn = NSSize(width: region.size.width * scale, height: region.size.height * scale)
                    region.draw(in: NSRect(x: thumb.minX, y: thumb.maxY - drawn.height, width: drawn.width, height: drawn.height),
                                from: .zero, operation: .sourceOver, fraction: 1)
                }
            case .passage:
                NSColor(palette.fill).setFill(); thumb.fill()
                let config = NSImage.SymbolConfiguration(pointSize: h * 0.55, weight: .semibold)
                    .applying(.init(paletteColors: [NSColor(palette.secondary)]))
                if let symbol = NSImage(systemSymbolName: "text.quote", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                    let s = symbol.size
                    symbol.draw(in: NSRect(x: thumb.midX - s.width / 2, y: thumb.midY - s.height / 2, width: s.width, height: s.height))
                }
            case .file:
                Art.fileIcon(a.fileType).draw(in: thumb, from: .zero, operation: .sourceOver, fraction: 1)
            }
            NSGraphicsContext.restoreGraphicsState()
            NSColor(palette.hairline).setStroke()
            clip.lineWidth = 0.5
            clip.stroke()
        }
        cache[key] = image
        return image
    }

    /// A bitmap at 2× the point size, so the tab is sharp on a Retina display.
    private static func draw(_ size: NSSize, _ body: (NSRect) -> Void) -> NSImage {
        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return NSImage(size: size) }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        body(NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }
}

/// A capture's words, plain, with search's hits marked. What you took follows the words, in the
/// order taken: the words that pointed at each thing aren't marked and no tab sits in the words,
/// until Fovea keeps which words meant which thing (the App UI review, Oct 6, row 32).
@MainActor
enum InlineText {
    static func make(_ capture: Capture, hits: [[Int]], size: CGFloat, palette: Palette, hitStyle: HitStyle,
                     thumbnails: Bool = false, color: Color? = nil) -> Text {
        Text(Highlight.attributed(capture.text, hits: hits, palette: palette, style: hitStyle, color: color))
    }

    /// As it was: each referent tab at the place it was taken, the words that pointed at it
    /// marked. Kept for when the binding is kept; nothing draws it now.
    static func bound(_ capture: Capture, hits: [[Int]], size: CGFloat, palette: Palette, hitStyle: HitStyle,
                      thumbnails: Bool = false, color: Color? = nil) -> Text {
        let (chipHeight, baseline) = Chips.metrics(for: size)
        let segments = capture.segments
        var out = Text(verbatim: "")
        for (i, segment) in segments.enumerated() {
            switch segment {
            case .run(let location, let run):
                let length = (run as NSString).length
                // The words just before the next tab are the ones that pointed at it.
                var bound = 0
                if i + 1 < segments.count, case .attachment(let next) = segments[i + 1] { bound = min(next.bound, length) }
                let plain = (run as NSString).substring(to: length - bound)
                let pointed = (run as NSString).substring(from: length - bound)
                out = out + Text(Highlight.attributed(plain, hits: Highlight.local(hits, location: location, length: length - bound),
                                                      palette: palette, style: hitStyle, color: color))
                if bound > 0 {
                    var mark = Highlight.attributed(pointed, hits: Highlight.local(hits, location: location + length - bound, length: bound),
                                                    palette: palette, style: hitStyle, color: color)
                    switch palette.binding {
                    case .highlighter: mark.backgroundColor = palette.bindingWash
                    case .underline:
                        mark.underlineStyle = .single
                        mark.underlineColor = NSColor(palette.bindingWash)
                    }
                    out = out + Text(mark)
                }
            case .attachment(let a):
                // A hair of space off the word it follows, and off the next word unless
                // punctuation or another tab comes next.
                if i > 0, case .run(_, let before) = segments[i - 1], let last = before.last, !last.isWhitespace {
                    out = out + Text(verbatim: "\u{200A}")
                }
                out = out + Text(Image(nsImage: Chips.image(a, height: chipHeight, palette: palette, thumbnail: thumbnails)))
                    .baselineOffset(baseline)
                if i + 1 < segments.count {
                    switch segments[i + 1] {
                    case .run(_, let after):
                        if let first = after.first, !first.isWhitespace, !first.isPunctuation { out = out + Text(verbatim: "\u{2009}") }
                    case .attachment:
                        out = out + Text(verbatim: "\u{2009}")
                    }
                }
            }
        }
        return out
    }
}

/// Text with search's hits marked: the system's find highlight, or a heavier weight in the same
/// ink (Paper has no highlight color).
enum Highlight {
    static func attributed(_ text: String, hits: [[Int]], palette: Palette, style: HitStyle, color: Color? = nil) -> AttributedString {
        var a = AttributedString(text)
        a.foregroundColor = color ?? palette.text
        for r in hits where r.count == 2 {
            let ns = NSRange(location: r[0], length: r[1])
            guard let range = Range(ns, in: text),
                  let lo = AttributedString.Index(range.lowerBound, within: a),
                  let hi = AttributedString.Index(range.upperBound, within: a) else { continue }
            if style == .highlight, let mark = palette.highlight {
                a[lo..<hi].backgroundColor = mark
                a[lo..<hi].foregroundColor = palette.isDark ? Color.white : palette.text
            } else {
                // A scheme whose highlighter marks the words you pointed with sets a hit heavier
                // and underlines it instead, so the two never read alike.
                a[lo..<hi].inlinePresentationIntent = .stronglyEmphasized
                a[lo..<hi].foregroundColor = palette.text
                if style == .highlight {
                    a[lo..<hi].underlineStyle = .single
                }
            }
        }
        return a
    }

    /// The hits that fall in a run starting at `location`, moved to the run's own offsets.
    static func local(_ hits: [[Int]], location: Int, length: Int) -> [[Int]] {
        hits.compactMap { r in
            guard r.count == 2 else { return nil }
            let lo = max(r[0], location), hi = min(r[0] + r[1], location + length)
            return hi > lo ? [lo - location, hi - lo] : nil
        }
    }
}

/// A few words either side of a hit in what you took, cut on spaces, on one line.
enum Snippet {
    /// Little before the hit and more after, so the hit itself always fits the line.
    static let before = 10, after = 24

    static func bounds(_ text: String, _ hit: [Int]) -> (Int, Int) {
        let ns = text as NSString
        var start = max(0, hit[0] - before)
        while start > 0, start < hit[0], ns.character(at: start - 1) != 32, ns.character(at: start - 1) != 10 { start += 1 }
        let end = min(ns.length, hit[0] + hit[1] + after)
        return (start, end)
    }

    static func around(_ text: String, _ hit: [Int]) -> String {
        let ns = text as NSString
        let (start, end) = bounds(text, hit)
        let body = ns.substring(with: NSRange(location: start, length: end - start)).replacingOccurrences(of: "\n", with: " ")
        return (start > 0 ? "…" : "") + body + (end < ns.length ? "…" : "")
    }

    /// The hit's range inside `around`.
    static func shift(_ text: String, _ hit: [Int]) -> [[Int]] {
        let (start, _) = bounds(text, hit)
        return [[hit[0] - start + (start > 0 ? 1 : 0), hit[1]]]
    }

    /// Which attachment a hit in the joined attachment text falls in.
    static func attachment(of hit: [Int], in capture: Capture) -> Attachment? {
        var offset = 0
        for a in capture.attachments {
            let n = (a.text as NSString).length
            if hit[0] >= offset && hit[0] < offset + n { return a }
            offset += n + 1
        }
        return nil
    }
}

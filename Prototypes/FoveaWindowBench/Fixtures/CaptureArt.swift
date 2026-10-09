import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The fixtures' screenshots, each drawn as what its capture says it holds: a section of the
/// page on localhost:3000, IslandShape.swift in Xcode, two notches in the workbench, Downloads
/// in Finder, a docs page on rate limits, a Calendar event, the hero photo cropped to 16:9.
/// Rendered once, at launch; none is a copy of a real app's window, only the circled region a
/// capture would hold. `Art/<name>` in a fixture's preview path.
@MainActor
enum CaptureArt {
    static func image(_ name: String) -> NSImage? {
        let view: AnyView
        switch name {
        case "localhost-why": view = AnyView(WhySection())
        case "xcode-islandshape": view = AnyView(CodeRegion())
        case "workbench-notches": view = AnyView(NotchPair())
        case "finder-downloads": view = AnyView(DownloadsRegion())
        case "docs-rate-limits": view = AnyView(DocsRegion())
        case "calendar-review": view = AnyView(CalendarRegion())
        case "mountain-16x9": return crop("Photos/mountain.jpg", aspect: 16.0 / 9.0)
        default: return nil
        }
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .light))
        renderer.scale = 2
        return renderer.nsImage
    }

    /// The middle of a photo at `aspect`, as a crop tool leaves it.
    private static func crop(_ path: String, aspect: CGFloat) -> NSImage? {
        guard let source = BenchResources.image(path),
              let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let rect = w / h > aspect
            ? CGRect(x: (w - h * aspect) / 2, y: 0, width: h * aspect, height: h)
            : CGRect(x: 0, y: (h - w / aspect) / 2, width: w, height: w / aspect)
        guard let cropped = cg.cropping(to: rect.integral) else { return nil }
        return NSImage(cgImage: cropped, size: NSSize(width: rect.width / 2, height: rect.height / 2))
    }
}

// MARK: - Safari · localhost:3000

/// fovea-site's second screen, the "Why Fovea" section with its three bullets.
private struct WhySection: View {
    private let ink = Color(red: 0.07, green: 0.07, blue: 0.08)
    private let gray = Color(red: 0.42, green: 0.43, blue: 0.46)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Why Fovea")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(ink)
            Text("Point at anything on your screen and send it to your coding agent.")
                .font(.system(size: 19))
                .foregroundStyle(gray)
                .padding(.top, 12)
            VStack(alignment: .leading, spacing: 26) {
                bullet("scope", "Fovea sees what you point at", "Circle a region while you talk; its text comes along.")
                bullet("arrow.triangle.branch", "You say where it goes", "Name the project, or let Fovea pick the chat.")
                bullet("text.bubble", "Your agent gets the context", "Your words, and every region, in the order you made them.")
            }
            .padding(.top, 44)
            Text("Join the waitlist")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ink))
                .padding(.top, 46)
        }
        .padding(.horizontal, 72)
        .padding(.vertical, 64)
        .frame(width: 1180, height: 800, alignment: .topLeading)
        .background(Color(red: 0.985, green: 0.983, blue: 0.975))
    }

    private func bullet(_ symbol: String, _ title: String, _ line: String) -> some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(ink)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.black.opacity(0.05)))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 21, weight: .semibold)).foregroundStyle(ink)
                Text(line).font(.system(size: 16)).foregroundStyle(gray)
            }
        }
    }
}

// MARK: - Xcode · IslandShape.swift

/// Lines 10–30 of Prototypes/FoveaWorkbench's IslandShape.swift, in Xcode's default light theme.
private struct CodeRegion: View {
    static let lines = [
        "struct IslandShape: Shape {",
        "    var topRadius: CGFloat",
        "    var bottomRadius: CGFloat",
        "",
        "    var animatableData: AnimatablePair<CGFloat, CGFloat> {",
        "        get { AnimatablePair(topRadius, bottomRadius) }",
        "        set { topRadius = newValue.first; bottomRadius = newValue.second }",
        "    }",
        "",
        "    func path(in rect: CGRect) -> Path {",
        "        let tr = max(0, min(topRadius, rect.width / 2))",
        "        let br = max(0, min(bottomRadius, rect.height, rect.width / 2 - tr))",
        "        var p = Path()",
        "        p.move(to: CGPoint(x: rect.minX, y: rect.minY))",
        "        if tr > 0 {",
        "            p.addQuadCurve(to: CGPoint(x: rect.minX + tr, y: rect.minY + tr),",
        "                           control: CGPoint(x: rect.minX + tr, y: rect.minY))",
        "        }",
        "        p.addLine(to: CGPoint(x: rect.minX + tr, y: rect.maxY - br))",
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(Array(Self.lines.indices), id: \.self) { i in
                    Text("\(i + 10)").frame(height: 22)
                }
            }
            .foregroundStyle(Color(red: 0.6, green: 0.6, blue: 0.63))
            .frame(width: 44, alignment: .trailing)
            .padding(.trailing, 18)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(Self.lines.enumerated()), id: \.offset) { i, line in
                    SwiftLine.text(line)
                        .frame(height: 22, alignment: .leading)
                        .background(alignment: .leading) {
                            // The line the cursor sits on, as Xcode marks it.
                            if i == 1 { Color(red: 0.91, green: 0.95, blue: 1).frame(width: 1100, height: 22) }
                        }
                }
            }
        }
        .font(.system(size: 14, design: .monospaced))
        .padding(.top, 18)
        .frame(width: 860, height: 538, alignment: .topLeading)
        .background(Color.white)
    }
}

/// Just enough of Xcode's colors to read as Swift.
private enum SwiftLine {
    static let keywords: Set<String> = ["struct", "var", "let", "func", "if", "get", "set", "in"]
    static let types: Set<String> = ["IslandShape", "Shape", "CGFloat", "AnimatablePair", "CGRect", "Path", "CGPoint"]

    static func text(_ line: String) -> Text {
        var result = Text("")
        var word = ""
        func flush() {
            guard !word.isEmpty else { return }
            let color: Color
            if keywords.contains(word) { color = Color(red: 0.61, green: 0.14, blue: 0.58) }
            else if types.contains(word) { color = Color(red: 0.22, green: 0.33, blue: 0.62) }
            else if Double(word) != nil { color = Color(red: 0.11, green: 0.0, blue: 0.81) }
            else { color = Color(red: 0.12, green: 0.12, blue: 0.13) }
            result = result + Text(word).foregroundColor(color)
            word = ""
        }
        for ch in line {
            if ch.isLetter || ch.isNumber || ch == "_" {
                word.append(ch)
            } else {
                flush()
                result = result + Text(String(ch)).foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.13))
            }
        }
        flush()
        return result
    }
}

// MARK: - FoveaWorkbench · Notch Workbench

/// Two listening islands on the workbench's mock desktop, the second with the roomier spacing.
private struct NotchPair: View {
    var body: some View {
        HStack(spacing: 24) {
            island(gap: 8, inset: 12, label: "1")
            island(gap: 14, inset: 18, label: "2")
        }
        .frame(width: 960, height: 600)
        .background(LinearGradient(colors: [Color(red: 0.36, green: 0.40, blue: 0.48), Color(red: 0.25, green: 0.27, blue: 0.33)],
                                   startPoint: .top, endPoint: .bottom))
    }

    private func island(gap: CGFloat, inset: CGFloat, label: String) -> some View {
        VStack(spacing: 22) {
            ZStack(alignment: .top) {
                Rectangle().fill(Color(white: 0.92).opacity(0.25)).frame(height: 30)
                HStack(spacing: gap) {
                    HStack(spacing: 3) {
                        ForEach([10, 18, 26, 14, 22, 12, 8], id: \.self) { h in
                            Capsule().fill(Color.white.opacity(0.85)).frame(width: 3.5, height: CGFloat(h))
                        }
                    }
                    Text("Listening").font(.system(size: 15, weight: .medium)).foregroundStyle(Color.white.opacity(0.85))
                    Spacer(minLength: 0)
                    Circle().fill(Color.white.opacity(0.85)).frame(width: 8, height: 8)
                }
                .padding(.horizontal, inset + 22)
                .frame(width: 400, height: 92)
                .background(IslandShape(topRadius: 14, bottomRadius: 26).fill(Color.black))
            }
            .frame(width: 440)
            Text(label)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.9))
        }
    }
}

// MARK: - Finder · Downloads

private struct DownloadsRegion: View {
    private struct File { let name: String; let type: UTType; let date: String; let size: String; let kind: String }
    private let files = [
        File(name: "fovea-logo-v3.zip", type: .zip, date: "Today at 13:02", size: "2.4 MB", kind: "ZIP archive"),
        File(name: "lin-room-3-map.png", type: .png, date: "Today at 09:41", size: "312 KB", kind: "PNG image"),
        File(name: "interview-notes-0926.md", type: UTType(filenameExtension: "md") ?? .plainText, date: "Yesterday at 16:38", size: "18 KB", kind: "Markdown"),
        File(name: "Screen Recording 2026-09-30 at 11.12.mov", type: .quickTimeMovie, date: "Yesterday at 11:12", size: "48.1 MB", kind: "QuickTime movie"),
        File(name: "invoice-0930.pdf", type: .pdf, date: "30 Sep 2026 at 08:44", size: "96 KB", kind: "PDF document"),
        File(name: "hero-mountain.jpg", type: .jpeg, date: "28 Sep 2026 at 09:10", size: "1.1 MB", kind: "JPEG image"),
        File(name: "Notch study.key", type: UTType(filenameExtension: "key") ?? .data, date: "27 Sep 2026 at 18:21", size: "12.7 MB", kind: "Keynote"),
        File(name: "waitlist-export.csv", type: .commaSeparatedText, date: "26 Sep 2026 at 10:05", size: "41 KB", kind: "CSV document"),
        File(name: "SF Mono specimen.pdf", type: .pdf, date: "25 Sep 2026 at 17:30", size: "2.1 MB", kind: "PDF document"),
        File(name: "pricing-v2.fig", type: UTType(filenameExtension: "fig") ?? .data, date: "24 Sep 2026 at 14:12", size: "8.8 MB", kind: "Figma file"),
        File(name: "demo-voiceover.m4a", type: .mpeg4Audio, date: "23 Sep 2026 at 20:47", size: "3.3 MB", kind: "MPEG-4 audio"),
        File(name: "Archive.zip", type: .zip, date: "22 Sep 2026 at 11:03", size: "640 KB", kind: "ZIP archive"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row(name: Text("Name"), date: "Date Modified", size: "Size", kind: "Kind", icon: nil, header: true)
                .frame(height: 30)
            Rectangle().fill(Color.black.opacity(0.1)).frame(height: 1)
            ForEach(Array(files.enumerated()), id: \.offset) { i, file in
                row(name: Text(file.name), date: file.date, size: file.size, kind: file.kind,
                    icon: NSWorkspace.shared.icon(for: file.type), header: false)
                    .frame(height: 30)
                    .background(i % 2 == 1 ? Color(red: 0.956, green: 0.96, blue: 0.965) : Color.white)
            }
            Spacer(minLength: 0)
        }
        .frame(width: 720, height: 450, alignment: .top)
        .background(Color.white)
    }

    private func row(name: Text, date: String, size: String, kind: String, icon: NSImage?, header: Bool) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                if let icon { Image(nsImage: icon).resizable().frame(width: 20, height: 20) } else if !header { Color.clear.frame(width: 20) }
                name.lineLimit(1).truncationMode(.middle)
            }
            .frame(width: 360, alignment: .leading)
            Text(date).frame(width: 200, alignment: .leading)
            Text(size).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: header ? 12 : 13, weight: header ? .medium : .regular))
        .foregroundStyle(header ? Color(white: 0.45) : Color(white: 0.1))
        .padding(.horizontal, 18)
    }
}

// MARK: - Safari · API docs

private struct DocsRegion: View {
    private let ink = Color(red: 0.1, green: 0.11, blue: 0.14)
    private let gray = Color(red: 0.4, green: 0.42, blue: 0.47)

    var body: some View {
        HStack(alignment: .top, spacing: 48) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(["Authentication", "Errors", "Pagination", "Rate limits", "Versioning", "Webhooks"], id: \.self) { item in
                    Text(item)
                        .font(.system(size: 15, weight: item == "Rate limits" ? .semibold : .regular))
                        .foregroundStyle(item == "Rate limits" ? ink : gray)
                }
            }
            .frame(width: 180, alignment: .leading)
            VStack(alignment: .leading, spacing: 18) {
                Text("Rate limits").font(.system(size: 34, weight: .bold)).foregroundStyle(ink)
                Text("The API allows up to 100 read requests per second per account and 100 write requests per second per account. Requests over the limit receive a 429 response.")
                    .font(.system(size: 17))
                    .foregroundStyle(ink)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                Grid(alignment: .leading, horizontalSpacing: 40, verticalSpacing: 10) {
                    GridRow { Text("Mode"); Text("Reads"); Text("Writes") }
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(gray)
                    GridRow { Text("Live"); Text("100 per second"); Text("100 per second") }
                    GridRow { Text("Test"); Text("25 per second"); Text("25 per second") }
                }
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(ink)
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(red: 0.96, green: 0.965, blue: 0.975)))
            }
            .frame(width: 560, alignment: .leading)
        }
        .padding(44)
        .frame(width: 880, height: 550, alignment: .topLeading)
        .background(Color.white)
    }
}

// MARK: - Calendar · the review

/// Thursday morning in Calendar's day view, the event the run made.
private struct CalendarRegion: View {
    var body: some View {
        let blue = Color(red: 0.2, green: 0.47, blue: 0.96)
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(["9 AM", "10 AM", "11 AM", "Noon"], id: \.self) { hour in
                    HStack(alignment: .top, spacing: 6) {
                        Text(hour).font(.system(size: 8.5, weight: .medium)).foregroundStyle(Color(white: 0.55))
                            .frame(width: 30, alignment: .trailing)
                            .offset(y: -5)
                        Rectangle().fill(Color.black.opacity(0.1)).frame(height: 0.5)
                    }
                    .frame(height: 36, alignment: .top)
                }
            }
            .padding(.top, 14)
            VStack(alignment: .leading, spacing: 1) {
                Text("Design review with Lin").font(.system(size: 9, weight: .semibold))
                Text("10:00–10:45").font(.system(size: 8))
            }
            .foregroundStyle(blue)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .frame(width: 168, height: 27, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 3).fill(blue.opacity(0.16)))
            .overlay(alignment: .leading) { Rectangle().fill(blue).frame(width: 2) }
            .offset(x: 40, y: 14 + 36)
        }
        .frame(width: 220, height: 138, alignment: .topLeading)
        .background(Color.white)
    }
}

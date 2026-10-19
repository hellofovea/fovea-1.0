import SwiftUI
import AppKit
import FoveaCore
import FoveaKit
import FoveaStore
import FoveaPlatform

// `Fovea --design-shots notch <dir>` (FoveaV1/README.md): every state of the real notch on this Mac,
// as pictures of the real screen, for the dev team's design document. Each is staged on the live
// island the way `--demo` stages it (`IslandController.stage`), in the looks the person can choose,
// over a clean desktop with a document and a file on it to take. Nothing here runs in the app itself.

/// What's under the island to take, in the screen's top-down points.
package struct ShotScene {
    package var lines: [CGRect]
    package var text: String
    package var fileURL: URL
    package var fileRect: CGRect
    package var regions: [CGRect]

    /// Places on the bare desktop, for `--demo` without a scene.
    static func standard(on screen: NSScreen) -> ShotScene {
        let w = screen.frame.width
        let lines = (0..<2).map { CGRect(x: w / 2 - 300, y: 300 + CGFloat($0) * 28, width: 600, height: 22) }
        return ShotScene(lines: lines, text: SceneView.passage, fileURL: SceneView.fileURL,
                         fileRect: CGRect(x: w - 110, y: 60, width: 76, height: 90),
                         regions: (0..<5).map { CGRect(x: 180 + CGFloat($0) * 130, y: 260 + CGFloat($0 % 2) * 120, width: 420, height: 260) })
    }
}

@MainActor
package enum IslandDesignShots {
    /// One picture: the look, then the state.
    package struct Shot {
        package var name: String
        package var stage: String
        package var dark = false
        package var floating = false
        package var compact = false
    }

    package static func run(_ island: IslandController, prefs: PrefsStore, to dir: URL, only: String?) async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard RealScreenShot.allowed else {
            print("design-shots: Screen Recording is off for Fovea (System Settings › Privacy & Security)")
            return
        }
        let screen = island.live.screen
        island.live.smoke?.realImages = true
        island.live.smoke?.source = "Trail report · Safari"
        try? SceneView.fileText.write(to: SceneView.fileURL, atomically: true, encoding: .utf8)
        let layout = SceneView.Layout(size: screen.frame.size)
        // A panel on every Space, a full-screen app's too; each picture waits for it to be what's in
        // front, so nothing of the person's is ever pictured.
        let window = BackdropPanel(screen: screen)
        let scene = SceneModel()
        window.contentView = NSHostingView(rootView: SceneView(layout: layout, wallpaper: DesktopCover.tahoeDay(), model: scene))
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        island.shotScene = layout.scene
        prefs.prefs.accountName = "Ryan"
        // Fovea in front, so the menu bar is Fovea's, not whatever the person had open.
        NSApp.activate(ignoringOtherApps: true)
        try? await Task.sleep(for: .seconds(1.2))
        // `--only a,b`: the shots whose names contain any of them.
        let parts = only.map { $0.split(separator: ",").map(String.init) }
        for shot in shots where parts.map({ $0.contains { shot.name.contains($0) } }) ?? true {
            prefs.prefs.notchAppearance = shot.dark ? .dark : .light
            prefs.prefs.panels = shot.floating ? .floating : .attached
            prefs.prefs.density = shot.compact ? .compact : .spacious
            try? await Task.sleep(for: .seconds(0.3))
            island.stage("silent")
            // An app full screen: no menu bar or Dock, the band beside the notch black.
            let fullScreen = shot.stage.hasPrefix("fullScreen")
            scene.fullScreen = fullScreen
            NSApp.presentationOptions = fullScreen ? [.hideDock, .hideMenuBar] : []
            try? await Task.sleep(for: .seconds(0.5))
            NSApp.activate(ignoringOtherApps: true)
            guard await RealScreenShot.waitForCleanDesktop(window, menuBar: !fullScreen) else {
                print("skipped \(shot.name): the desktop never came back to the front"); continue
            }
            island.stage(shot.stage)
            try? await Task.sleep(for: .seconds(settle(shot.stage)))
            guard RealScreenShot.onCleanDesktop(window, menuBar: !fullScreen) else {
                print("skipped \(shot.name): another Space came to the front"); continue
            }
            guard let png = RealScreenShot.png(of: screen) else { print("failed \(shot.name)"); continue }
            try? png.write(to: dir.appendingPathComponent("\(shot.name).png"))
            print("wrote \(shot.name).png")
        }
        island.stage("silent")
        NSApp.presentationOptions = []
        if let notch = RealScreenShot.notchRect(on: screen) {
            // The hardware notch, for drawing over the pictures (a screenshot doesn't show it).
            let line = "\(notch.minX) \(notch.minY) \(notch.width) \(notch.height) \(screen.backingScaleFactor)"
            try? line.write(to: dir.appendingPathComponent("notch.txt"), atomically: true, encoding: .utf8)
        }
    }

    /// How long a state takes to arrive: the stack's captures and its fan, a session's steps.
    private static func settle(_ stage: String) -> Double {
        if stage.hasPrefix("stack") { return 2.8 }
        if stage.hasPrefix("whole") || stage.hasPrefix("titles") || stage.hasPrefix("queue") { return 2.0 }
        if stage.hasPrefix("countdown") { return 1.0 }
        // Caught while the words are still arriving, before Choose chat or the paste.
        if stage == "v2Transcribing" { return 0.45 }
        if stage == "transcribing" { return 0.8 }
        return 1.5
    }

    /// Every state in Light, attached and Spacious (as 1.0 ships); the main ones again in Dark,
    /// floating and Compact.
    package static var shots: [Shot] {
        func file(_ stage: String) -> String { stage.replacingOccurrences(of: ":", with: "-") }
        let states = IslandController.stageNames
        var list = states.map { Shot(name: "light-\(file($0))", stage: $0) }
        let main = ["voiceFlow", "stack:5:open", "pasteNotFound", "error:offline", "v2Voice", "v2Send", "v2Board", "hello",
                    "v2Chat", "asksOver", "whole:outline", "pulled"]
        list += main.map { Shot(name: "dark-\(file($0))", stage: $0, dark: true) }
        list += ["pasteNotFound", "stack:5:inspect", "v2Send", "v2Board", "v2Chat", "whole"].map {
            Shot(name: "floating-light-\(file($0))", stage: $0, floating: true)
        }
        list += ["v2Send", "v2Board", "v2Chat", "whole"].map { Shot(name: "compact-light-\(file($0))", stage: $0, compact: true) }
        list.append(Shot(name: "dark-pulled-tucked", stage: "pulled:tucked", dark: true))
        return list
    }
}

@Observable
private final class SceneModel {
    var fullScreen = false
}

/// The clean desktop the pictures are taken on: the first run's picture, a document open on it
/// (a page of words to highlight and parts to capture) and a file at the top right. Full screen:
/// the document fills the screen under a black band, as an app taken full screen does.
private struct SceneView: View {
    struct Layout {
        let size: CGSize
        var document: CGRect { CGRect(x: 200, y: 150, width: min(1000, size.width - 520), height: size.height - 280) }
        var photo: CGRect { CGRect(x: document.minX + 56, y: document.minY + 66, width: document.width - 112, height: 220) }
        var heading: CGPoint { CGPoint(x: document.minX + 56, y: photo.maxY + 26) }
        var firstLine: CGFloat { heading.y + 64 }
        var file: CGRect { CGRect(x: size.width - 118, y: 62, width: 80, height: 92) }

        func lineRect(_ i: Int) -> CGRect {
            let width = (SceneView.lines[i] as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: SceneView.fontSize)]).width
            return CGRect(x: heading.x, y: firstLine + CGFloat(i) * SceneView.lineHeight, width: ceil(width), height: SceneView.lineHeight - 4)
        }

        var scene: ShotScene {
            let marked = SceneView.marked.map(lineRect)
            return ShotScene(lines: marked, text: SceneView.passage, fileURL: SceneView.fileURL, fileRect: file,
                             regions: [photo, CGRect(x: heading.x - 8, y: heading.y - 8, width: photo.width, height: 120),
                                       lineRect(0).union(lineRect(2)).insetBy(dx: -8, dy: -8),
                                       file.insetBy(dx: -10, dy: -6),
                                       CGRect(x: document.minX, y: document.minY, width: document.width, height: 60)])
        }
    }

    let layout: Layout
    let wallpaper: NSImage?
    let model: SceneModel

    /// The notch's height on this Mac (the band a full-screen app leaves black beside it).
    static var bandHeight: CGFloat { NSScreen.main?.safeAreaInsets.top ?? 32 }
    static let fontSize: CGFloat = 17
    static let lineHeight: CGFloat = 28
    static let lines = [
        "The first storm of the season moved through overnight, leaving the upper trails",
        "under a hand's depth of fresh snow. Rangers expect the pass to stay open through",
        "the weekend, though the forecast holds a second front for early next week.",
        "Below the tree line the change is quieter. Streams that ran clear all summer have",
        "turned milky with meltwater, and the last of the lodges have pulled their chairs in.",
    ]
    /// The lines the highlighter takes.
    static let marked = [3, 4]
    static var passage: String { marked.map { lines[$0] }.joined(separator: " ") }
    static let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("packing-list.txt")
    static let fileText = "Packing for the snow\n\n- boots\n- gaiters\n- headlamp\n"

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let wallpaper { Image(nsImage: wallpaper).resizable().scaledToFill() } else { Color(white: 0.16) }
            }
            .frame(width: layout.size.width, height: layout.size.height)
            .clipped()
            document
            if model.fullScreen {
                Color.white.frame(width: layout.size.width, height: layout.size.height)
                document.offset(x: -layout.document.minX + (layout.size.width - layout.document.width) / 2,
                                y: -layout.document.minY + Self.bandHeight)
                Color.black.frame(width: layout.size.width, height: Self.bandHeight)
            }
            VStack(spacing: 6) {
                Image(nsImage: NSWorkspace.shared.icon(for: .plainText))
                    .resizable()
                    .frame(width: 58, height: 58)
                Text(Self.fileURL.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
            }
            .frame(width: layout.file.width, height: layout.file.height)
            .offset(x: layout.file.minX, y: layout.file.minY)
            .opacity(model.fullScreen ? 0 : 1)
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .environment(\.colorScheme, .light)
    }

    private var document: some View {
        let d = layout.document
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
            HStack(spacing: 8) {
                ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0.opacity(0.85)).frame(width: 12, height: 12) }
                Spacer()
                Text("Trail report — Snow returns to the high valleys")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(width: d.width, height: 44)
            Rectangle().fill(.black.opacity(0.08)).frame(width: d.width, height: 1).offset(y: 44)
            Group {
                if let wallpaper { Image(nsImage: wallpaper).resizable().scaledToFill() } else { Color.gray }
            }
            .frame(width: layout.photo.width, height: layout.photo.height)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .offset(x: layout.photo.minX - d.minX, y: layout.photo.minY - d.minY)
            Text("Snow returns to the high valleys")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.black.opacity(0.88))
                .offset(x: layout.heading.x - d.minX, y: layout.heading.y - d.minY)
            ForEach(Self.lines.indices, id: \.self) { i in
                Text(Self.lines[i])
                    .font(.system(size: Self.fontSize))
                    .foregroundStyle(.black.opacity(0.8))
                    .fixedSize()
                    .offset(x: layout.lineRect(i).minX - d.minX, y: layout.lineRect(i).minY - d.minY)
            }
        }
        .frame(width: d.width, height: d.height, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.28), radius: 24, y: 10)
        .offset(x: d.minX, y: d.minY)
    }
}

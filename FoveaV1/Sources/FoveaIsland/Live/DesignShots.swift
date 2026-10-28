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
        /// Oct 28: the accent the bar's aurora is drawn in.
        package var accent: FoveaAccent?
    }

    package static func run(_ island: IslandController, prefs: PrefsStore, to dir: URL, only: String?) async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Oct 21: without Screen Recording (a new build loses it), Fovea's own windows only: the
        // clean desktop and the island, never what's behind them, so no wait for the desktop.
        let ownOnly = !RealScreenShot.allowed
        if ownOnly { print("design-shots: Screen Recording is off for this build; picturing Fovea's own windows only") }
        let screen = island.live.screen
        island.live.smoke?.realImages = true
        island.live.smoke?.source = "Trail report · Safari"
        try? SceneView.fileText.write(to: SceneView.fileURL, atomically: true, encoding: .utf8)
        let layout = SceneView.Layout(size: screen.frame.size)
        // Oct 26: `--shot-wallpaper=<file>`, a picture of one's own under the notch (pictures to share
        // can't carry Apple's wallpaper).
        let own = CommandLine.arguments.first { $0.hasPrefix("--shot-wallpaper=") }
            .flatMap { NSImage(contentsOfFile: String($0.dropFirst("--shot-wallpaper=".count))) }
        // Oct 27, Ryan: "while doing the testing, can you just not take over the entire screen and not
        // change the background pic?" Unless `--full-screen-shots`, nothing covers the screen: each
        // picture is the island's own window alone, laid over the desktop drawn off screen; states
        // that would take the real screen (a part of it captured, an app full screen) are left out.
        let quiet = !CommandLine.arguments.contains("--full-screen-shots")
        // In the background (never brought to the front), App Nap would hold the island's drawing.
        let awake = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "Design shots")
        defer { ProcessInfo.processInfo.endActivity(awake) }
        let scene = SceneModel()
        let backdrop = quiet ? offscreen(SceneView(layout: layout, wallpaper: own ?? DesktopCover.tahoeDay(), model: scene), screen: screen) : nil
        let window = quiet ? nil : BackdropPanel(screen: screen)
        if let window {
            // A panel on every Space, a full-screen app's too; each picture waits for it to be what's
            // in front, so nothing of the person's is ever pictured.
            window.contentView = NSHostingView(rootView: SceneView(layout: layout, wallpaper: own ?? DesktopCover.tahoeDay(), model: scene))
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
        }
        defer { window?.orderOut(nil) }
        island.shotScene = layout.scene
        prefs.prefs.accountName = "Ryan"
        if !quiet {
            // Fovea in front, so the menu bar is Fovea's, not whatever the person had open.
            NSApp.activate(ignoringOtherApps: true)
            try? await Task.sleep(for: .seconds(1.2))
        }
        // `--only a,b`: the shots whose names contain any of them.
        let parts = only.map { $0.split(separator: ",").map(String.init) }
        for shot in shots where parts.map({ $0.contains { shot.name.contains($0) } }) ?? true {
            if quiet, Self.takesScreen(shot.stage) { print("left out \(shot.name): it takes the real screen"); continue }
            // `--shot-own-look`: every picture in the look the data folder's prefs have (glass,
            // panels, size), as the person sees them.
            if !CommandLine.arguments.contains("--shot-own-look") {
                prefs.prefs.notchAppearance = shot.dark ? .dark : .light
                prefs.prefs.panels = shot.floating ? .floating : .attached
            }
            if let accent = shot.accent { prefs.prefs.accent = accent }
            try? await Task.sleep(for: .seconds(0.3))
            island.stage("silent")
            // An app full screen: no menu bar or Dock, the band beside the notch black.
            let fullScreen = shot.stage.hasPrefix("fullScreen")
            scene.fullScreen = fullScreen
            if let window {
                NSApp.presentationOptions = fullScreen ? [.hideDock, .hideMenuBar] : []
                try? await Task.sleep(for: .seconds(0.5))
                NSApp.activate(ignoringOtherApps: true)
                if !ownOnly, !(await RealScreenShot.waitForCleanDesktop(window, menuBar: !fullScreen)) {
                    print("skipped \(shot.name): the desktop never came back to the front"); continue
                }
            } else {
                try? await Task.sleep(for: .seconds(0.4))
            }
            island.stage(shot.stage)
            try? await Task.sleep(for: .seconds(settle(shot.stage)))
            if let window {
                guard ownOnly || RealScreenShot.onCleanDesktop(window, menuBar: !fullScreen) else {
                    print("skipped \(shot.name): another Space came to the front"); continue
                }
            }
            let picture: Data?
            if let backdrop {
                // The island drawn off screen, as its window draws it, over the desktop drawn off screen:
                // nothing of Fovea's or the person's is captured from the screen.
                picture = islandPicture(island, prefs: prefs, over: backdrop, screen: screen)
            } else {
                picture = ownOnly ? RealScreenShot.ownWindowsPNG(of: screen) : RealScreenShot.png(of: screen)
            }
            guard let png = picture else {
                print("failed \(shot.name)"); continue
            }
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

    /// Oct 26, Ryan ("the notch transition from the top menu bar to the notch is too abrupt"): each
    /// listening bar design coming out of the notch and going back, frame by frame: what the window
    /// server composites over the notch, read as often as it can be for a moment after each change.
    /// `Fovea --design-shots bar-film <dir>`: `film-<design>-<stage>-<in|out>-<ms>.png`.
    package static func film(_ island: IslandController, prefs: PrefsStore, to dir: URL) async {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let screen = island.live.screen
        island.live.smoke?.realImages = true
        let layout = SceneView.Layout(size: screen.frame.size)
        let own = CommandLine.arguments.first { $0.hasPrefix("--shot-wallpaper=") }
            .flatMap { NSImage(contentsOfFile: String($0.dropFirst("--shot-wallpaper=".count))) }
        // Oct 27: nothing over the screen; the frames are the island's window over the desktop drawn
        // off screen.
        let backdrop = offscreen(SceneView(layout: layout, wallpaper: own ?? DesktopCover.tahoeDay(), model: SceneModel()), screen: screen)
        let awake = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "Design film")
        defer { ProcessInfo.processInfo.endActivity(awake) }
        island.shotScene = layout.scene
        prefs.prefs.panels = .floating
        try? await Task.sleep(for: .seconds(0.6))
        // The notch and room either side for the widest design, in the screen's points.
        let region = Screens.global(CGRect(x: screen.frame.width / 2 - 280, y: 0, width: 560, height: 96), on: screen)
        let times = [0, 30, 60, 90, 120, 150, 180, 220, 280, 400]
        let local = Screens.local(appKit: NSPoint(x: region.minX, y: region.maxY), on: screen)
        let pixels = CGRect(x: local.x * screen.backingScaleFactor, y: local.y * screen.backingScaleFactor,
                            width: region.width * screen.backingScaleFactor, height: region.height * screen.backingScaleFactor)
        let under = backdrop?.cropping(to: pixels)
        do {
            let design = "wings"
            for stage in ["voiceFlow", "v2Voice", "transcribing"] {
                island.stage("silent")
                try? await Task.sleep(for: .seconds(1.0))
                let enter = await FrameGrabber.frames(of: region, for: 0.6) { island.stage(stage) }
                try? await Task.sleep(for: .seconds(0.8))
                let leave = await FrameGrabber.frames(of: region, for: 0.5) { island.stage("silent") }
                for (part, frames) in [("in", enter), ("out", leave)] {
                    for ms in times where ms <= (part == "in" ? 400 : 280) {
                        guard let frame = frames.first(where: { $0.time * 1000 >= Double(ms) }) ?? frames.last,
                              let png = under.flatMap({ composite(frame.image, over: $0) })
                                ?? NSBitmapImageRep(cgImage: frame.image).representation(using: .png, properties: [:]) else { continue }
                        let name = "film-\(design)-\(stage)-\(part)-\(String(format: "%03d", ms)).png"
                        try? png.write(to: dir.appendingPathComponent(name))
                    }
                }
                print("filmed \(design) \(stage): \(enter.count) frames in, \(leave.count) out")
            }
        }
        island.stage("silent")
    }

    /// The island's layer drawn off screen over `backdrop`, at the screen's size and scale, as a PNG.
    /// Off screen the glass has nothing behind it: panels are drawn in its tone.
    private static func islandPicture(_ island: IslandController, prefs: PrefsStore, over backdrop: CGImage,
                                      screen: NSScreen) -> Data? {
        let model = island.model
        model.offscreenRender = true
        defer { model.offscreenRender = false }
        let size = screen.frame.size
        let view = ZStack(alignment: .top) {
            Image(decorative: backdrop, scale: screen.backingScaleFactor)
            IslandLayerView(model: model, prefs: prefs)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .environment(\.liquidGlass, false)
        let renderer = ImageRenderer(content: view)
        renderer.scale = screen.backingScaleFactor
        return renderer.cgImage.flatMap { NSBitmapImageRep(cgImage: $0).representation(using: .png, properties: [:]) }
    }

    /// The states that take the real screen: a part of it captured, words or a file on it marked,
    /// an app taken full screen.
    static func takesScreen(_ stage: String) -> Bool {
        ["stack", "capture", "highlight", "fullScreen"].contains { stage.hasPrefix($0) }
    }

    /// A view drawn off screen at the screen's size and scale.
    private static func offscreen<V: View>(_ view: V, screen: NSScreen) -> CGImage? {
        let renderer = ImageRenderer(content: view.frame(width: screen.frame.width, height: screen.frame.height))
        renderer.scale = screen.backingScaleFactor
        return renderer.cgImage
    }

    /// `image` (Fovea's windows, clear elsewhere) over `backdrop`, the same size, as a PNG.
    private static func composite(_ image: CGImage, over backdrop: CGImage) -> Data? {
        let w = backdrop.width, h = backdrop.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: w, height: h)
        ctx.draw(backdrop, in: rect)
        ctx.draw(image, in: rect)
        return ctx.makeImage().flatMap { NSBitmapImageRep(cgImage: $0).representation(using: .png, properties: [:]) }
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

    /// Every state in Light and attached; the main ones again in Dark, and floating (one size,
    /// Compact, Oct 27).
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
        list.append(Shot(name: "dark-pulled-tucked", stage: "pulled:tucked", dark: true))
        // Oct 24, Ryan: open any chat, floating too (his look), and in Dark.
        let chats = IslandController.openChatStageNames
        list += chats.map { Shot(name: "floating-light-\(file($0))", stage: $0, floating: true) }
        list += chats.filter { $0.hasSuffix(":board") || $0.hasSuffix(":open") || $0.hasSuffix(":opened") }
            .map { Shot(name: "dark-\(file($0))", stage: $0, dark: true) }
        // The control board, Dark and Light, floating (Oct 27: the one approved).
        for stage in ["chats:board", "chats:pinned", "chats:hello"] {
            list.append(Shot(name: "board-dark-\(file(stage))", stage: stage, dark: true, floating: true))
        }
        list.append(Shot(name: "board-light-chats-board", stage: "chats:board", floating: true))
        // Oct 26, Ryan: a session popping up by itself, in Dark and floating (his look).
        list += ["alert:needsYou", "alert:done", "alert:failed"].map {
            Shot(name: "dark-\(file($0))", stage: $0, dark: true, floating: true)
        }
        // Oct 27, Ryan: every state of the bar in Wings, Dark (his) and Light.
        for dark in [true, false] {
            list += wingsStages.map { Shot(name: "wings-\(dark ? "dark" : "light")-\(file($0))", stage: $0, dark: dark,
                                           floating: true) }
        }
        // Oct 28, Ryan: the bar's aurora in each accent ("lets just do one color hue"; Multicolor, the
        // glow's Colorful palette), listening.
        list += FoveaAccent.allCases.map {
            Shot(name: "aurora-accent-\($0.rawValue)", stage: "voiceFlow", dark: true, accent: $0)
        }
        list += ["v2Voice", "referents:3"].map {
            Shot(name: "aurora-dispatch-\(file($0))", stage: $0, dark: true, accent: .blue)
        }
        return list
    }

    /// Oct 27: every state Wings draws, for its pictures.
    package static var wingsStages: [String] {
        ["voiceFlow", "v2Voice", "referents:1", "referents:5", "transcribing", "v2Transcribing", "cancelled", "noSpeech",
         "pasteNotFound", "error:offline", "error:micPermission", "error:screenRecording", "countdown:lastMinute",
         "countdown:lastSeconds", "drop:1", "drop:3", "route"]
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
            // Oct 26: pictured from Fovea's own windows (no Screen Recording), the real menu bar
            // isn't in the picture; a stand-in, so the notch is seen against one.
            if !RealScreenShot.allowed, !model.fullScreen { menuBar }
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
        .environment(\.colorScheme, .light)
    }

    private var menuBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 20) {
                Image(systemName: "apple.logo").font(.system(size: 14, weight: .medium))
                Text("Safari").font(.system(size: 13, weight: .semibold))
                ForEach(["File", "Edit", "View", "History", "Bookmarks", "Window", "Help"], id: \.self) {
                    Text($0).font(.system(size: 13))
                }
            }
            Spacer()
            HStack(spacing: 18) {
                ForEach(["switch.2", "magnifyingglass", "battery.75percent", "wifi"], id: \.self) {
                    Image(systemName: $0).font(.system(size: 13, weight: .medium))
                }
                Text("Mon Oct 26  9:41 AM").font(.system(size: 13))
            }
        }
        .foregroundStyle(.black.opacity(0.85))
        .padding(.horizontal, 20)
        .frame(width: layout.size.width, height: Self.bandHeight)
        .background(Color.white.opacity(0.32))
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


/// Oct 26: frames of Fovea's own windows over a region, read off the main thread as fast as the
/// window server gives them, from just before `change` runs; each with its time after it.
private final class FrameGrabber: @unchecked Sendable {
    struct Frame { let time: Double; let image: CGImage }
    private let lock = NSLock()
    private var list: [Frame] = []
    private var running = true

    @MainActor
    static func frames(of region: CGRect, for seconds: Double, change: () -> Void) async -> [Frame] {
        let pid = ProcessInfo.processInfo.processIdentifier
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        let ids = info.compactMap { w -> CGWindowID? in
            guard (w[kCGWindowOwnerPID as String] as? pid_t) == pid else { return nil }
            return w[kCGWindowNumber as String] as? CGWindowID
        }
        let grabber = FrameGrabber()
        let start = CACurrentMediaTime()
        let thread = Thread {
            var pointers = ids.map { UnsafeRawPointer(bitPattern: UInt($0)) }
            guard let array = CFArrayCreate(nil, &pointers, pointers.count, nil) else { return }
            while grabber.isRunning {
                if let image = CGImage(windowListFromArrayScreenBounds: region, windowArray: array, imageOption: [.bestResolution]) {
                    grabber.append(Frame(time: CACurrentMediaTime() - start, image: image))
                }
            }
        }
        thread.start()
        try? await Task.sleep(for: .milliseconds(30))
        let changed = CACurrentMediaTime()
        change()
        try? await Task.sleep(for: .seconds(seconds))
        grabber.stop()
        let offset = changed - start
        return grabber.all.map { Frame(time: $0.time - offset, image: $0.image) }.filter { $0.time >= -0.001 }
    }

    var isRunning: Bool { lock.lock(); defer { lock.unlock() }; return running }
    var all: [Frame] { lock.lock(); defer { lock.unlock() }; return list }
    func append(_ frame: Frame) { lock.lock(); list.append(frame); lock.unlock() }
    func stop() { lock.lock(); running = false; lock.unlock() }
}

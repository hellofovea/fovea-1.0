import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import WindowBenchCore

/// Records the bench's own windows (the Fovea window, and the lab notch and flight overlay when a
/// motion leaves the window) into a GIF and an H.264 movie. Each window's image comes from the
/// window server and is drawn at the frame AppKit gives it, so nothing outside the bench reaches a
/// recording: not another app's windows, and not a Space switch sliding the screen mid-take. No
/// permission is needed for an app's own windows. Pattern after
/// Prototypes/FoveaWorkbench/WorkbenchRecorder.swift; the GIF is written with ImageIO, so no
/// ffmpeg is needed.
final class FrameRecorder: @unchecked Sendable {
    /// One window to draw: its id and its frame in the recorded area (top-left origin, points).
    struct Layer {
        let id: CGWindowID
        let frame: CGRect
    }

    /// The windows on screen right now, back to front, set from the main thread as they come
    /// and go (a popover, the notch, the flight).
    private let lock = NSLock()
    private var layers: [Layer]

    func setLayers(_ layers: [Layer]) {
        lock.lock(); self.layers = layers; lock.unlock()
    }
    /// The recorded area's size in points, and the pixels per point.
    private let area: CGSize
    private let scale: CGFloat
    private let gif: CGImageDestination?
    private let gifWidth: Int
    private let fps: Int
    private let queue = DispatchQueue(label: "windowbench.recorder", qos: .userInitiated)
    private var timer: DispatchSourceTimer?
    private(set) var frames = 0
    private let writer: AVAssetWriter?
    private let input: AVAssetWriterInput?
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private let movieSize: CGSize
    private var started: CFTimeInterval = 0
    /// Small copies of every frame, for the contact sheet.
    private var thumbs: [CGImage] = []
    private let sheetURL: URL

    init?(gifURL: URL, movieURL: URL?, layers: [Layer], area: CGSize, scale: CGFloat, fps: Int = 20,
          gifMaxWidth: CGFloat = 960) {
        guard !layers.isEmpty, area.width > 0, area.height > 0 else { return nil }
        self.layers = layers
        self.area = area
        self.scale = scale
        let sourceSize = area
        sheetURL = gifURL.deletingPathExtension().appendingPathExtension("sheet.png")
        self.fps = fps
        try? FileManager.default.removeItem(at: gifURL)
        gif = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, 10_000, nil)
        if let gif {
            CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        }
        gifWidth = Int(min(gifMaxWidth, sourceSize.width))
        let scale = min(1600 / sourceSize.width, 2)
        movieSize = CGSize(width: (sourceSize.width * scale / 2).rounded() * 2, height: (sourceSize.height * scale / 2).rounded() * 2)
        if let movieURL, let writer = try? { try? FileManager.default.removeItem(at: movieURL); return try AVAssetWriter(outputURL: movieURL, fileType: .mp4) }() {
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: Int(movieSize.width), AVVideoHeightKey: Int(movieSize.height),
                AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000],
            ])
            input.expectsMediaDataInRealTime = true
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(movieSize.width), kCVPixelBufferHeightKey as String: Int(movieSize.height),
            ])
            if writer.canAdd(input) { writer.add(input) }
            self.writer = writer; self.input = input; self.adaptor = adaptor
        } else {
            writer = nil; input = nil; adaptor = nil
        }
    }

    func start() {
        writer?.startWriting()
        writer?.startSession(atSourceTime: .zero)
        started = CACurrentMediaTime()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 1.0 / Double(fps))
        timer.setEventHandler { [weak self] in self?.frame() }
        self.timer = timer
        timer.resume()
    }

    func finish() async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            queue.async {
                self.timer?.cancel()
                self.timer = nil
                if let gif = self.gif { CGImageDestinationFinalize(gif) }
                self.writeSheet()
                if let writer = self.writer, let input = self.input {
                    input.markAsFinished()
                    writer.finishWriting { done.resume() }
                } else {
                    done.resume()
                }
            }
        }
    }

    /// Eight moments across the recording in a 4 × 2 grid, so the motion reads from a still.
    private func writeSheet() {
        guard thumbs.count > 1 else { return }
        let picks = (0..<8).map { thumbs[min(thumbs.count - 1, Int(Double($0) / 7 * Double(thumbs.count - 1)))] }
        let w = picks[0].width, h = picks[0].height, gap = 8
        let sheetW = w * 4 + gap * 5, sheetH = h * 2 + gap * 3
        guard let context = CGContext(data: nil, width: sheetW, height: sheetH, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        context.setFillColor(CGColor(gray: 0.82, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))
        for (i, image) in picks.enumerated() {
            let col = i % 4, row = i / 4
            context.draw(image, in: CGRect(x: gap + col * (w + gap), y: sheetH - (gap + (row + 1) * h + row * gap), width: w, height: h))
        }
        guard let sheet = context.makeImage(), let dest = CGImageDestinationCreateWithURL(sheetURL as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, sheet, nil)
        CGImageDestinationFinalize(dest)
    }

    private func capture() -> CGImage? {
        lock.lock(); let layers = self.layers; lock.unlock()
        let w = Int(area.width * scale), h = Int(area.height * scale)
        guard let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        var drew = false
        for layer in layers {
            guard let image = CGWindowListCreateImage(.null, .optionIncludingWindow, layer.id, [.boundsIgnoreFraming, .bestResolution]) else { continue }
            let f = layer.frame
            context.draw(image, in: CGRect(x: f.minX * scale, y: CGFloat(h) - f.maxY * scale, width: f.width * scale, height: f.height * scale))
            drew = true
        }
        return drew ? context.makeImage() : nil
    }

    private func frame() {
        guard let image = capture() else { return }
        // Flatten onto white: the overlay's transparent parts would be black in a GIF.
        let w = gifWidth, h = Int(CGFloat(image.height) * CGFloat(gifWidth) / CGFloat(image.width))
        if let gif, let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            context.setFillColor(CGColor(gray: 0.96, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: w, height: h))
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            if let small = context.makeImage() {
                CGImageDestinationAddImage(gif, small, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / Double(fps)]] as CFDictionary)
                thumbs.append(small)
            }
        }
        if let input, let adaptor, input.isReadyForMoreMediaData, let pool = adaptor.pixelBufferPool {
            var buffer: CVPixelBuffer?
            if CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess, let buffer {
                CVPixelBufferLockBaseAddress(buffer, [])
                if let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: Int(movieSize.width), height: Int(movieSize.height),
                                           bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                           space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                           bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) {
                    context.setFillColor(CGColor(gray: 0.96, alpha: 1))
                    context.fill(CGRect(origin: .zero, size: movieSize))
                    context.draw(image, in: CGRect(origin: .zero, size: movieSize))
                }
                CVPixelBufferUnlockBaseAddress(buffer, [])
                adaptor.append(buffer, withPresentationTime: CMTime(seconds: CACurrentMediaTime() - started, preferredTimescale: 600))
            }
        }
        frames += 1
    }
}

/// The Play scenarios as recordings: `--record x.gif --play drill`, or the panel's switch.
@MainActor
enum BenchRecorder {
    struct Scenario {
        let name: String
        /// Seconds at 1× (scaled by the speed).
        let seconds: Double
        /// Whether the motion leaves the window (the notch, the flight).
        let leavesWindow: Bool
        /// The window the motion happens in.
        var window: Target = .main
        /// Puts the before-state on screen without motion; it draws before the motion starts.
        var prepare: ((BenchModel) -> Void)? = nil
        let run: (BenchModel) -> Void

        enum Target { case main, settings }
    }

    static let scenarios: [Scenario] = [
        Scenario(name: "reveal", seconds: 8.2, leavesWindow: false, prepare: { m in
            if m.state.fixture == .empty { m.loadFixture(.typical) }; m.goTo(onboarding: .consent) }) { $0.playReveal() },
        Scenario(name: "drill", seconds: 3.0, leavesWindow: false) { $0.playDrill() },
        Scenario(name: "counts", seconds: 2.4, leavesWindow: false) { $0.playCounts() },
        Scenario(name: "arrival", seconds: 1.6, leavesWindow: false) { $0.playArrival() },
        Scenario(name: "finish", seconds: 1.4, leavesWindow: false) { $0.playFinish() },
        Scenario(name: "fail", seconds: 1.4, leavesWindow: false) { $0.playFail() },
        Scenario(name: "move", seconds: 1.4, leavesWindow: false) { $0.playMove() },
        Scenario(name: "fold", seconds: 1.4, leavesWindow: false) { $0.playFold() },
        Scenario(name: "jump", seconds: 3.9, leavesWindow: false) { $0.playJump() },
        // Every replay starts from the original guess.
        Scenario(name: "correction", seconds: 2.8, leavesWindow: false, prepare: { m in
            m.correction = nil; m.loadFixture(m.state.fixture); m.goToProject("p-site") }) { $0.playCorrection() },
        Scenario(name: "brief", seconds: 3.0, leavesWindow: false) { $0.playBrief() },
        Scenario(name: "takeMeThere", seconds: 4.2, leavesWindow: true) { $0.playTakeMeThere() },
        // Replays from the reveal's end, so only the hand-off line arrives.
        Scenario(name: "handoff", seconds: 3.6, leavesWindow: true, prepare: { m in m.goTo(onboarding: .reveal) }) { $0.goTo(onboarding: .handoff) },
        // 03: Cursor's hooks go in; its ● clears in place and the word changes.
        // Scrolled so Cursor's whole hooks group is in view under its row in Agents.
        Scenario(name: "hooks", seconds: 1.4, leavesWindow: false, window: .settings, prepare: { m in
            m.loadFixture(.errors); m.hooks[.cursor] = .notInstalled; m.settingsScrollTarget = "hooks/cursor#bottom"; m.openSettings(.connections) }) { $0.installHooks(.cursor) },
        // 04: a run finishes, then one fails, on their own pages.
        Scenario(name: "runFinish", seconds: 1.6, leavesWindow: false, prepare: { m in
            if m.index.runByID["r-hero"]?.state != .running { m.playFinish() }; m.goToRun("r-hero") }) { $0.playFinish() },
        Scenario(name: "runFail", seconds: 1.6, leavesWindow: false, prepare: { m in
            if m.index.runByID["r-rail"]?.state != .running { m.playFail() }; m.goToRun("r-rail") }) { $0.playFail() },
        // 06: a capture opens from the stream and closes again.
        Scenario(name: "captureOpen", seconds: 3.2, leavesWindow: false, prepare: { m in
            m.quickLook = nil; m.show([PathEntry(level: .captures)], section: .capture) }) { $0.playCaptureOpen() },
        // 02: the fold accordion, and a drill turned back halfway.
        Scenario(name: "accordion", seconds: 3.2, leavesWindow: false, prepare: { m in
            m.openFold = nil; m.goToProject("p-site") }) { $0.playAccordion() },
        Scenario(name: "drillInterrupt", seconds: 1.6, leavesWindow: false, prepare: { m in
            m.revealed = Int.max; m.show([PathEntry(level: .projects)], section: .project) }) { $0.playDrillInterrupt() },
        // 06: the jumps both ways: View in Project from a capture, then the run's captures link.
        Scenario(name: "captureJumps", seconds: 4.0, leavesWindow: false, prepare: { m in
            m.quickLook = nil; m.goToCapture("c-site-shot") }) { $0.playCaptureJumps() },
        // 06: switching the capture filters.
        Scenario(name: "filters", seconds: 2.8, leavesWindow: false, prepare: { m in
            m.captureFilter = nil; m.quickLook = nil; m.show([PathEntry(level: .captures)], section: .capture) }) { $0.playFilters() },
        // 07a: Forget leaves Undo in the row's own place; Undo puts it back.
        Scenario(name: "forget", seconds: 2.4, leavesWindow: false, window: .settings, prepare: { m in
            m.lastForgotten = nil; m.loadFixture(m.state.fixture); m.openSettings(.memory) }) { $0.playForget() },
        // 07b: Settings › Notch: presets reorder the rows; the Today preview follows.
        Scenario(name: "today", seconds: 2.6, leavesWindow: false, window: .settings, prepare: { m in
            m.today = TodaySettings(); m.openSettings(.notch) }) { $0.playToday() },
    ]

    /// `--record <file.gif> --play <name>`: launch, play once, write, quit.
    static func record(to url: URL, play: String, app: BenchAppDelegate) async {
        await BenchSnapshots.settle(1.0)
        guard let scenario = scenarios.first(where: { $0.name == play }) else {
            print("no scenario \(play); one of \(scenarios.map(\.name).joined(separator: ", "))")
            return
        }
        app.model.finishOnboarding()
        await BenchSnapshots.settle(0.4)
        await capture(scenario, gifURL: url.pathExtension == "gif" ? url : url.deletingPathExtension().appendingPathExtension("gif"),
                      movieURL: url.deletingPathExtension().appendingPathExtension("mp4"), app: app)
    }

    /// Records one scenario from its start.
    static func capture(_ scenario: Scenario, gifURL: URL, movieURL: URL?, app: BenchAppDelegate) async {
        if let prepare = scenario.prepare {
            prepare(app.model)
            app.model.heal()
            await BenchSnapshots.settle(0.6)
        }
        // Settings motions get a taller window, so a change and what it changes are both in view.
        if scenario.window == .settings, let window = app.settings.window, let screen = window.screen ?? NSScreen.main {
            let height = min(screen.visibleFrame.height - 40, 860)
            var frame = window.frame
            frame.origin.y += frame.height - height
            frame.size.height = height
            window.setFrame(frame, display: true)
            await BenchSnapshots.settle(0.3)
        }
        guard let window = scenario.window == .settings ? app.settings.window : app.main.window else { return }
        // The recorded area in AppKit's global coordinates: the window, or the window and the
        // notch's band above it when the motion leaves the window.
        var area = window.frame
        var notchIDs: [CGWindowID] = []
        if scenario.leavesWindow, let screen = NotchPlacement.screen {
            area = CGRect(x: window.frame.minX, y: window.frame.minY, width: window.frame.width, height: screen.frame.maxY - window.frame.minY)
            // Back to front: the flight overlay under the notch.
            notchIDs = app.notch.prepare().reversed()
        }
        // What is on screen now, back to front: the window, its popovers, then the overlay and
        // the notch. Only windows that are ordered in: a hidden one keeps its last image.
        let layers: @MainActor () -> [FrameRecorder.Layer] = {
            var windows: [NSWindow] = [window]
            windows += NSApp.windows.filter { $0.isVisible && String(describing: type(of: $0)).contains("Popover") }
            windows += notchIDs.compactMap { NSApp.window(withWindowNumber: Int($0)) }.filter(\.isVisible)
            return windows.map { w in
                FrameRecorder.Layer(id: CGWindowID(w.windowNumber),
                                    frame: CGRect(x: w.frame.minX - area.minX, y: area.maxY - w.frame.maxY, width: w.frame.width, height: w.frame.height))
            }
        }
        guard let recorder = FrameRecorder(gifURL: gifURL, movieURL: movieURL, layers: layers(), area: area.size,
                                           scale: window.backingScaleFactor) else { return }
        recorder.start()
        let watcher = Task { @MainActor in
            while !Task.isCancelled {
                recorder.setLayers(layers())
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
        await BenchSnapshots.settle(0.25)
        scenario.run(app.model)
        await app.model.motion.sleep(scenario.seconds)
        await BenchSnapshots.settle(0.2)
        watcher.cancel()
        await recorder.finish()
        print("wrote \(gifURL.lastPathComponent) (\(recorder.frames) frames)")
    }
}

import AppKit
import AVFoundation
import CoreVideo
import CoreText

/// Records the window into an H.264 movie, frames read from the window server as it
/// composites the window (no permission needed for an app's own window), on a queue of its
/// own so the animations never wait for it. `FoveaWorkbench --record demo.mp4` plays the
/// screenshot walkthrough into one and exits.
final class WorkbenchRecorder: @unchecked Sendable {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let windowID: CGWindowID
    private let width: Int, height: Int
    private let windowSize: CGSize
    /// A region of the window to record (window points, origin bottom left), or all of it.
    private let crop: CGRect?
    /// A strip under the picture naming what is showing; set from the main actor.
    private let captionHeight: Int
    private let lock = NSLock()
    private var captionText = ""
    var caption: String {
        get { lock.lock(); defer { lock.unlock() }; return captionText }
        set { lock.lock(); captionText = newValue; lock.unlock() }
    }
    private let queue = DispatchQueue(label: "workbench.recorder", qos: .userInitiated)
    private var timer: DispatchSourceTimer?
    private var started: CFTimeInterval = 0
    private(set) var frames = 0

    init?(url: URL, window: NSWindow, maxWidth: CGFloat = 1920, fps: Int = 30, crop: CGRect? = nil, captionHeight: Int = 0) {
        try? FileManager.default.removeItem(at: url)
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return nil }
        let source = crop?.size ?? window.frame.size
        let scale = min(maxWidth / source.width, 4)
        width = Int((source.width * scale / 2).rounded()) * 2
        height = Int((source.height * scale / 2).rounded()) * 2 + captionHeight
        windowSize = window.frame.size
        self.crop = crop
        self.captionHeight = captionHeight
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 10_000_000],
        ]
        input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
        ])
        guard writer.canAdd(input) else { return nil }
        writer.add(input)
        self.writer = writer
        windowID = CGWindowID(window.windowNumber)
        self.fps = fps
    }
    private let fps: Int

    func start() {
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
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
                self.input.markAsFinished()
                self.writer.finishWriting { done.resume() }
            }
        }
    }

    private func frame() {
        guard input.isReadyForMoreMediaData, let pool = adaptor.pixelBufferPool,
              let image = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, [.boundsIgnoreFraming, .bestResolution])
        else { return }
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess, let buffer else { return }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                                   bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                   space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                   bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) {
            context.interpolationQuality = .high
            var picture = image
            if let crop {
                let k = CGFloat(image.width) / windowSize.width
                let rect = CGRect(x: crop.minX * k, y: (windowSize.height - crop.maxY) * k,
                                  width: crop.width * k, height: crop.height * k).integral
                if let cropped = image.cropping(to: rect) { picture = cropped }
            }
            context.draw(picture, in: CGRect(x: 0, y: captionHeight, width: width, height: height - captionHeight))
            if captionHeight > 0 { drawCaption(in: context) }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        let time = CMTime(seconds: CACurrentMediaTime() - started, preferredTimescale: 600)
        if adaptor.append(buffer, withPresentationTime: time) { frames += 1 }
    }

    /// The caption strip: white on black, centered, in the system face.
    private func drawCaption(in context: CGContext) {
        context.setFillColor(CGColor(gray: 0.06, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: captionHeight))
        let text = caption
        guard !text.isEmpty else { return }
        let font = CTFontCreateUIFontForLanguage(.system, CGFloat(captionHeight) * 0.36, nil)!
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 0.92),
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        context.textPosition = CGPoint(x: (CGFloat(width) - bounds.width) / 2 - bounds.minX,
                                       y: (CGFloat(captionHeight) - bounds.height) / 2 - bounds.minY)
        CTLineDraw(line, context)
    }
}

extension WorkbenchModel {
    /// `--record <file>`: the walkthrough into a movie, then quit.
    func recordDemo(to url: URL) async {
        var waited = 0
        while stageProbe?.window == nil, waited < 50 {
            try? await Task.sleep(for: .milliseconds(100))
            waited += 1
        }
        guard let window = stageProbe?.window else { print("no window to record"); exit(1) }
        window.setContentSize(WorkbenchTokens.Snapshot.size)
        try? await Task.sleep(for: .milliseconds(800))
        guard let recorder = WorkbenchRecorder(url: url, window: window) else { print("cannot record to \(url.path)"); exit(1) }
        recorder.start()
        await runDemo()
        try? await Task.sleep(for: .milliseconds(600))
        await recorder.finish()
        print("wrote \(url.path) (\(recorder.frames) frames)")
        exit(0)
    }
}

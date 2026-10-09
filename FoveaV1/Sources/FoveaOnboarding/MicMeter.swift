import AVFoundation

/// The microphone's ear, for the mic test (Oct 8: the person has to actually say the line) and for
/// dictation's real words (Oct 9): the input's loudness, live, from AVAudioEngine, as the shipping
/// app meters it, and its audio handed to speech recognition when that's listening. Nothing is
/// recorded or kept. When there's no microphone, or it isn't allowed, `start` says so and the test
/// falls back to holding space while talking.
@MainActor
final class MicMeter {
    private let engine = AVAudioEngine()
    private(set) var running = false
    /// 0…1, about forty times a second while running.
    var onLevel: ((Double) -> Void)?
    /// Where the audio goes besides the meter (speech recognition), on the audio thread.
    nonisolated let sink = AudioSink()

    /// Asks macOS (its own prompt, the first time), then listens. Calls back with whether it can.
    func start(_ done: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            done(begin())
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { allowed in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { done(allowed && self.begin()) }
                }
            }
        default:
            done(false)
        }
    }

    private func begin() -> Bool {
        guard !running else { return true }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else { return false }
        let floor = OT.Mic.floorDB, range = OT.Mic.rangeDB
        let sink = self.sink
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            sink.send(buffer)
            guard let samples = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<count { sum += samples[i] * samples[i] }
            let rms = sqrt(sum / Float(max(1, count)))
            let db = 20 * log10(max(Double(rms), 1e-7))
            let level = max(0, min(1, (db - floor) / range))
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.onLevel?(level) }
            }
        }
        do {
            try engine.start()
            running = true
            return true
        } catch {
            input.removeTap(onBus: 0)
            return false
        }
    }

    func stop() {
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running = false
    }
}

/// The audio thread's hand-off: whoever listens now (speech recognition) gets each buffer.
final class AudioSink: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: ((AVAudioPCMBuffer) -> Void)?

    func listen(_ handler: ((AVAudioPCMBuffer) -> Void)?) {
        lock.lock(); defer { lock.unlock() }
        self.handler = handler
    }

    func send(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let handler = self.handler
        lock.unlock()
        handler?(buffer)
    }
}

import AVFoundation
import Speech
import FoveaKit

// The microphone and the words: one AVAudioEngine feeds both, the level for the waveform and the
// glow, the buffers for on-device speech recognition. From the shipping app's AudioServices.swift.
// 1.0 transcribes on this Mac with Apple's speech recognition (Fovea's own transcription service
// isn't there yet), so macOS asks for Speech Recognition once.

public enum VoiceFailure: Error, Equatable, Sendable {
    /// The person said no to the microphone, or hasn't been asked and can't be now.
    case microphoneDenied
    /// No input device.
    case microphoneUnavailable
    /// The person said no to Speech Recognition.
    case speechDenied
    /// Speech recognition can't run for this language on this Mac.
    case speechUnavailable
    /// The recognizer failed with nothing heard.
    case recognitionFailed
}

/// What one listen came to: the words, or why there are none.
public struct VoiceResult: Sendable {
    public var text: String
    public var failure: VoiceFailure?
    public var seconds: Double

    public init(text: String, failure: VoiceFailure?, seconds: Double) {
        self.text = text; self.failure = failure; self.seconds = seconds
    }
}

@MainActor
public final class VoiceInput {
    /// The level, 0…1, about 40 times a second while listening.
    public var onLevel: ((Float) -> Void)?
    /// The words so far.
    public var onPartial: ((String) -> Void)?
    public private(set) var partial = ""
    public private(set) var isListening = false

    private let engine = AVAudioEngine()
    /// Oct 23, Ryan: one recognizer for each language the person speaks, all fed the same audio;
    /// the first is the primary language's.
    private var lanes: [Lane] = []
    private var speechFailure: VoiceFailure?
    private var finalWaiters: [CheckedContinuation<Void, Never>] = []
    private var startedAt = Date()
    private var smoothed: Float = 0

    public init() {}

    /// One language listening: its request, what it has heard so far, and its last words.
    private final class Lane {
        let recognizer: SFSpeechRecognizer
        let request: SFSpeechAudioBufferRecognitionRequest
        var task: SFSpeechRecognitionTask?
        var partial = ""
        var final: SFTranscription?
        var done = false
        /// It failed with nothing heard.
        var failedEmpty = false
        init(recognizer: SFSpeechRecognizer, request: SFSpeechAudioBufferRecognitionRequest) {
            self.recognizer = recognizer; self.request = request
        }
    }

    public static var microphoneStatus: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .audio) }
    public static var speechStatus: SFSpeechRecognizerAuthorizationStatus { SFSpeechRecognizer.authorizationStatus() }

    /// Asks for the microphone if it hasn't been asked (macOS's own prompt).
    public static func requestMicrophone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    /// Asks for Speech Recognition if it hasn't been asked (macOS's own prompt).
    public static func requestSpeech() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { c in
                SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
            }
        default: return false
        }
    }

    /// Starts listening: the level at once, the words as they come. Throws when the microphone
    /// can't be had; a speech failure is kept for `finish()` (the bar still listens and shows
    /// the level, and says why there are no words). `punctuates`: speech recognition adds the
    /// punctuation (off with Tidy my words off, Oct 15 review ST-04.2/3).
    public func start(locale: String, contextual: [String] = [], punctuates: Bool = true) async throws {
        try await start(locales: [locale], contextual: contextual, punctuates: punctuates)
    }

    /// Oct 23, Ryan: listening in each of the person's languages at once (English and Chinese
    /// both on), the primary first. Each recognizer hears the same audio; `finish()` keeps the
    /// words the recognizers are surest of, the primary language's on a tie. A language this Mac
    /// can't recognize just isn't listened in; none at all is `speechUnavailable`, as before.
    public func start(locales: [String], contextual: [String] = [], punctuates: Bool = true) async throws {
        cancel()
        guard await Self.requestMicrophone() else { throw VoiceFailure.microphoneDenied }
        partial = ""
        speechFailure = nil
        smoothed = 0
        startedAt = Date()

        if await Self.requestSpeech() {
            var seen = Set<String>()
            var recognizers = locales.filter { seen.insert($0).inserted }
                .compactMap { SFSpeechRecognizer(locale: Locale(identifier: $0)) }.filter(\.isAvailable)
            if recognizers.isEmpty, let fallback = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), fallback.isAvailable {
                recognizers = [fallback]
            }
            for r in recognizers {
                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true
                request.requiresOnDeviceRecognition = r.supportsOnDeviceRecognition
                request.taskHint = .dictation
                request.addsPunctuation = punctuates
                request.contextualStrings = Array(contextual.prefix(100))
                let lane = Lane(recognizer: r, request: request)
                lane.task = r.recognitionTask(with: request) { [weak self, weak lane] result, error in
                    let text = result?.bestTranscription.formattedString
                    let transcription = result?.isFinal == true ? result?.bestTranscription : nil
                    let isFinal = result?.isFinal ?? false
                    let failed = error != nil
                    DispatchQueue.main.async {
                        guard let lane else { return }
                        self?.recognized(lane, text: text, final: transcription, isFinal: isFinal, failed: failed)
                    }
                }
                lanes.append(lane)
            }
            if lanes.isEmpty { speechFailure = .speechUnavailable }
        } else {
            speechFailure = .speechDenied
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            cancel()
            throw VoiceFailure.microphoneUnavailable
        }
        let requests = lanes.map(\.request)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            for request in requests { request.append(buffer) }
            let level = VoiceInput.level(of: buffer)
            DispatchQueue.main.async {
                guard let self, self.isListening else { return }
                self.smoothed = self.smoothed * 0.2 + level * 0.8
                self.onLevel?(self.smoothed)
            }
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            cancel()
            throw VoiceFailure.microphoneUnavailable
        }
        isListening = true
    }

    /// Stops listening and waits for the last words (at most `timeout` seconds).
    public func finish(timeout: Double = 2.5) async -> VoiceResult {
        let seconds = Date().timeIntervalSince(startedAt)
        stopEngine()
        lanes.forEach { $0.request.endAudio() }
        if speechFailure == nil, lanes.contains(where: { !$0.done }) {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in
                    await withCheckedContinuation { c in
                        if self.lanes.allSatisfy(\.done) { c.resume() } else { self.finalWaiters.append(c) }
                    }
                }
                group.addTask {
                    try? await Task.sleep(for: .seconds(timeout))
                    await MainActor.run { self.releaseWaiters() }
                }
                await group.next()
                group.cancelAll()
            }
        }
        let heard = lanes.map { lane -> SpeechCandidate in
            let text = (lane.final?.formattedString ?? lane.partial).trimmingCharacters(in: .whitespacesAndNewlines)
            return SpeechCandidate(text: text, confidence: lane.final.map(Self.confidence) ?? 0)
        }
        let text = SpeechCandidate.pick(heard).map { heard[$0].text } ?? ""
        // Nothing heard: why, if speech couldn't run or every recognizer failed (else no words).
        let allFailed = !lanes.isEmpty && lanes.allSatisfy(\.failedEmpty)
        let failure: VoiceFailure? = text.isEmpty ? (speechFailure ?? (allFailed ? .recognitionFailed : nil)) : nil
        lanes.forEach { $0.task?.cancel() }
        lanes = []
        return VoiceResult(text: text, failure: failure, seconds: seconds)
    }

    /// Stops at once, keeping nothing.
    public func cancel() {
        stopEngine()
        lanes.forEach { $0.task?.cancel() }
        lanes = []
        releaseWaiters()
    }

    private func stopEngine() {
        guard isListening || engine.isRunning else { return }
        isListening = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        onLevel?(0)
    }

    private func recognized(_ lane: Lane, text: String?, final: SFTranscription?, isFinal: Bool, failed: Bool) {
        guard lanes.contains(where: { $0 === lane }) else { return }
        if let text, !text.isEmpty {
            lane.partial = text
            // The words so far, in the primary language (or the other, while it has none).
            let shown = lanes.first?.partial.isEmpty == false ? lanes[0].partial : text
            if shown != partial { partial = shown; onPartial?(shown) }
        }
        if let final { lane.final = final }
        if isFinal || failed {
            if failed, lane.partial.isEmpty { lane.failedEmpty = true }
            lane.done = true
            if lanes.allSatisfy(\.done) { releaseWaiters() }
        }
    }

    /// How sure a recognizer is of its words: its segments' confidence, weighted by how long each
    /// was said (0…1).
    private static func confidence(_ t: SFTranscription) -> Float {
        let total = t.segments.reduce(0) { $0 + max($1.duration, 0.01) }
        guard total > 0 else { return 0 }
        return t.segments.reduce(Float(0)) { $0 + $1.confidence * Float(max($1.duration, 0.01)) } / Float(total)
    }

    private func releaseWaiters() {
        let waiters = finalWaiters
        finalWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    /// RMS → dB → 0…1 through a speech-tuned window (−35…−20 dB), with a visual boost.
    /// The curve comes from OpenDictation (MIT); it makes quiet speech visibly move.
    nonisolated static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let n = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<n { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(n))
        let db = 20 * log10(max(rms, 1e-7))
        let minDb: Float = -35, maxDb: Float = -20
        let clamped = min(db, maxDb)
        let amplitude = pow(10, 0.05 * clamped)
        let lo = pow(10, 0.05 * minDb), hi = pow(10, 0.05 * maxDb)
        let normalized = max(0, (amplitude - lo) / (hi - lo))
        return min(pow(normalized, 0.5) * 2.5, 1)
    }
}

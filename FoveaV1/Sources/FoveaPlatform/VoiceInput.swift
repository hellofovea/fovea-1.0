import AVFoundation
import Speech

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
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var speechFailure: VoiceFailure?
    private var finalText: String?
    private var finalWaiters: [CheckedContinuation<Void, Never>] = []
    private var startedAt = Date()
    private var smoothed: Float = 0

    public init() {}

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
    /// the level, and says why there are no words).
    public func start(locale: String, contextual: [String] = []) async throws {
        cancel()
        guard await Self.requestMicrophone() else { throw VoiceFailure.microphoneDenied }
        partial = ""
        finalText = nil
        speechFailure = nil
        smoothed = 0
        startedAt = Date()

        if await Self.requestSpeech() {
            let r = SFSpeechRecognizer(locale: Locale(identifier: locale)) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            if let r, r.isAvailable {
                recognizer = r
                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true
                request.requiresOnDeviceRecognition = r.supportsOnDeviceRecognition
                request.taskHint = .dictation
                request.addsPunctuation = true
                request.contextualStrings = Array(contextual.prefix(100))
                self.request = request
                task = r.recognitionTask(with: request) { [weak self] result, error in
                    let text = result?.bestTranscription.formattedString
                    let isFinal = result?.isFinal ?? false
                    let failed = error != nil
                    DispatchQueue.main.async {
                        self?.recognized(text: text, isFinal: isFinal, failed: failed)
                    }
                }
            } else {
                speechFailure = .speechUnavailable
            }
        } else {
            speechFailure = .speechDenied
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            cancel()
            throw VoiceFailure.microphoneUnavailable
        }
        let request = self.request
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request?.append(buffer)
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
        request?.endAudio()
        if speechFailure == nil, finalText == nil, task != nil {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in
                    await withCheckedContinuation { c in
                        if self.finalText != nil { c.resume() } else { self.finalWaiters.append(c) }
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
        let text = (finalText ?? partial).trimmingCharacters(in: .whitespacesAndNewlines)
        let failure: VoiceFailure? = text.isEmpty ? (speechFailure ?? nil) : nil
        task?.cancel()
        task = nil
        request = nil
        return VoiceResult(text: text, failure: failure, seconds: seconds)
    }

    /// Stops at once, keeping nothing.
    public func cancel() {
        stopEngine()
        task?.cancel()
        task = nil
        request = nil
        releaseWaiters()
    }

    private func stopEngine() {
        guard isListening || engine.isRunning else { return }
        isListening = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        onLevel?(0)
    }

    private func recognized(text: String?, isFinal: Bool, failed: Bool) {
        if let text, !text.isEmpty {
            partial = text
            onPartial?(text)
        }
        if isFinal || failed {
            finalText = partial
            if failed, partial.isEmpty, speechFailure == nil { speechFailure = .recognitionFailed }
            releaseWaiters()
        }
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

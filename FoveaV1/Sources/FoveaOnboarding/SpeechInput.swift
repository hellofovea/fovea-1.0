import Foundation
import AVFoundation
import Speech
import OnboardingCore

/// Dictation's real words (Oct 9): on-device speech recognition fed by the microphone meter's
/// audio. The recognition is copied from the shipping app's `SpeechTranscriber`
/// (Sources/Fovea/Platform/AudioServices.swift:113-220, Oct 9) and may drift.
///
/// macOS checks, inside the process, that the app says why it wants speech recognition; a binary
/// run with `swift run` has no Info.plist to say it, and asking would end the process. So it runs
/// only from the app bundle (`Prototypes/scripts/onboarding-app.sh`), and otherwise says so. The
/// shipping app won't ask for Speech Recognition at all (docs/window/FEEDBACK_2026-10-06.md rows
/// 3–5): this prompt is the prototype's.
@MainActor
final class SpeechInput {
    /// Partial words, as they're heard.
    var onPartial: ((String) -> Void)?
    /// The recognizer's last word on what was said, once the audio ends.
    private(set) var finalText: String?

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private weak var meter: MicMeter?

    /// Running from a bundle that says why it wants the microphone and speech recognition.
    static var available: Bool {
        Bundle.main.bundlePath.hasSuffix(".app")
            && Bundle.main.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription") != nil
            && Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") != nil
    }

    static let why = "Real words need the app: run Prototypes/scripts/onboarding-app.sh. Here, a stand-in lands."

    /// Starts listening: asks macOS the first time, then feeds the recognizer from the meter.
    func start(language: Language, meter: MicMeter, _ done: @escaping (Bool, String?) -> Void) {
        guard Self.available else { done(false, Self.why); return }
        cancel()
        finalText = nil
        self.meter = meter
        let locale = Locale(identifier: language == .chinese ? "zh-CN" : "en-US")
        Self.authorize { [weak self] allowed in
            guard let self else { return }
            guard allowed else { done(false, "Speech recognition isn't allowed. A stand-in lands."); return }
            guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
                  recognizer.isAvailable else {
                done(false, "Speech recognition isn't available on this Mac. A stand-in lands.")
                return
            }
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            request.taskHint = .dictation
            self.recognizer = recognizer
            self.request = request
            meter.sink.listen { buffer in request.append(buffer) }
            self.task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? (error != nil)
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        if let text {
                            self.onPartial?(text)
                            if isFinal { self.finalText = text }
                        }
                    }
                }
            }
            meter.start { ok in
                done(ok, ok ? nil : "No microphone here. A stand-in lands.")
            }
        }
    }

    /// The audio ends; the recognizer gives its last word.
    func finish() {
        meter?.sink.listen(nil)
        request?.endAudio()
    }

    func cancel() {
        meter?.sink.listen(nil)
        task?.cancel()
        task = nil
        request = nil
        recognizer = nil
    }

    private static func authorize(_ done: @escaping @MainActor (Bool) -> Void) {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            done(true)
        case .notDetermined:
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async { MainActor.assumeIsolated { done(status == .authorized) } }
            }
        default:
            done(false)
        }
    }
}

import AVFoundation

/// The first run's sound, made on the fly: no files. A quiet open chord that breathes under
/// everything, and four soft cues: a key's tick, a capture taken, a step done, something allowed.
/// Calm and ambient (Ryan, Oct 7): never louder than a page turning. Every level is in OT.Sound.
final class AmbientSound {
    enum Cue: CaseIterable { case tick, capture, step, allow }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let pad = PadVoice()
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private(set) var running = false
    /// Everything silent: the guide card's mute.
    var muted = false { didSet { engine.mainMixerNode.outputVolume = muted ? 0 : 1 } }
    /// The bed alone, from the control panel.
    var ambientOn = true { didSet { pad.target = ambientOn && padStarted ? 1 : 0 } }
    private var padStarted = false

    init(enabled: Bool) {
        guard enabled else { return }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: OT.Sound.sampleRate, channels: 2) else { return }
        let pad = self.pad
        let source = AVAudioSourceNode { _, _, frameCount, list -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(list)
            for frame in 0..<Int(frameCount) {
                let value = pad.next()
                for buffer in buffers {
                    buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = value
                }
            }
            return noErr
        }
        engine.attach(source)
        engine.attach(player)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        for cue in Cue.allCases { buffers[cue] = Self.render(cue, format: format) }
        do {
            try engine.start()
            running = true
        } catch {
            running = false
        }
    }

    func startAmbient() {
        padStarted = true
        pad.target = ambientOn ? 1 : 0
    }

    func stopAmbient() {
        pad.target = 0
        padStarted = false
    }

    func cue(_ cue: Cue) {
        guard running, !muted, let buffer = buffers[cue] else { return }
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    // MARK: Making the sounds

    private static func render(_ cue: Cue, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let S = OT.Sound.self
        let rate = S.sampleRate
        var samples: [Float]
        switch cue {
        case .tick:
            samples = tone(S.tickPitch, length: S.tickLength, rate: rate, attack: 0.002, volume: S.tickVolume)
        case .capture:
            // A soft shutter: a short breath of filtered noise over a low thump.
            let n = Int(S.captureLength * rate)
            var last: Float = 0
            samples = (0..<n).map { i in
                let t = Double(i) / rate
                let envelope = Float(exp(-t * 45))
                let noise = Float.random(in: -1...1)
                last = last * 0.86 + noise * 0.14
                let thump = Float(sin(2 * .pi * 180 * t)) * Float(exp(-t * 30))
                return (last * 0.8 + thump * 0.5) * envelope * S.captureVolume
            }
        case .step:
            samples = chime(S.chimeNotes, rate: rate, volume: S.chimeVolume)
        case .allow:
            samples = chime(S.allowNotes, rate: rate, volume: S.allowVolume)
        }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channels = buffer.floatChannelData else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for channel in 0..<Int(format.channelCount) {
            samples.withUnsafeBufferPointer { src in
                channels[channel].update(from: src.baseAddress!, count: samples.count)
            }
        }
        return buffer
    }

    /// A bell: each note struck softly and left to ring, the next a beat later.
    private static func chime(_ notes: [Double], rate: Double, volume: Float) -> [Float] {
        let S = OT.Sound.self
        let gap = Int(S.chimeGap * rate)
        let length = Int(S.chimeNoteLength * rate)
        var out = [Float](repeating: 0, count: gap * (notes.count - 1) + length)
        for (k, pitch) in notes.enumerated() {
            let note = tone(pitch, length: S.chimeNoteLength, rate: rate, attack: 0.006, volume: volume, partial: 0.18)
            for i in 0..<note.count where k * gap + i < out.count { out[k * gap + i] += note[i] }
        }
        return out
    }

    private static func tone(_ pitch: Double, length: Double, rate: Double, attack: Double, volume: Float,
                             partial: Double = 0) -> [Float] {
        let n = Int(length * rate)
        return (0..<n).map { i in
            let t = Double(i) / rate
            let rise = min(1, t / attack)
            let decay = exp(-t * 6 / length)
            let wave = sin(2 * .pi * pitch * t) + partial * sin(2 * .pi * pitch * 2.01 * t)
            return Float(wave * rise * decay) * volume
        }
    }
}

/// The ambient bed: four soft sines in an open chord, each breathing at its own slow rate, faded
/// in and out by `target`. Runs on the audio thread; a prototype's benign races.
final class PadVoice: @unchecked Sendable {
    var target: Float = 0
    private var gain: Float = 0
    private var phases: [Double] = OT.Sound.padNotes.map { _ in 0 }
    private var time: Double = 0
    private let rate = OT.Sound.sampleRate

    func next() -> Float {
        let fadeStep = Float(1 / (OT.Sound.padFadeIn * rate))
        if gain < target { gain = min(target, gain + fadeStep) }
        if gain > target { gain = max(target, gain - Float(1 / (OT.Sound.padFadeOut * rate))) }
        guard gain > 0 else { time += 1 / rate; return 0 }
        var value = 0.0
        for (i, pitch) in OT.Sound.padNotes.enumerated() {
            phases[i] += 2 * .pi * pitch / rate
            if phases[i] > 2 * .pi { phases[i] -= 2 * .pi }
            let breath = 0.55 + 0.45 * sin(2 * .pi * OT.Sound.padBreath * (1 + Double(i) * 0.37) * time + Double(i))
            value += sin(phases[i]) * breath / Double(OT.Sound.padNotes.count)
        }
        time += 1 / rate
        return Float(value) * OT.Sound.padVolume * gain
    }
}

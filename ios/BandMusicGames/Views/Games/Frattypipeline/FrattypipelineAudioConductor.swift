import AVFoundation

struct FrattypipelineAudioMix: Equatable {
    let stemCount: Int
    let section: FrattypipelineSongSection
    let beatEnergy: Double

    var baseFrequency: Double {
        switch section {
        case .intro:
            return 82.41
        case .verse:
            return 98.00
        case .hook:
            return 123.47
        case .bridge:
            return 110.00
        }
    }

    var masterGain: Double {
        0.035 + Double(max(1, min(4, stemCount))) * 0.012 + beatEnergy * 0.015
    }

    var barkFrequency: Double {
        section == .hook ? 740 : 620
    }
}

private final class FrattypipelineAudioState {
    private let lock = NSLock()
    private var mix = FrattypipelineAudioMix(stemCount: 1, section: .intro, beatEnergy: 0)
    private var barkEnvelope = 0.0
    private var barkFrequency = 620.0

    func update(mix: FrattypipelineAudioMix) {
        lock.lock()
        self.mix = mix
        lock.unlock()
    }

    func triggerBark(onBeat: Bool, section: FrattypipelineSongSection) {
        lock.lock()
        barkEnvelope = onBeat ? 1.0 : 0.45
        barkFrequency = (onBeat ? FrattypipelineAudioMix(stemCount: 4, section: section, beatEnergy: 1).barkFrequency : 370)
        lock.unlock()
    }

    func snapshot() -> (mix: FrattypipelineAudioMix, barkEnvelope: Double, barkFrequency: Double) {
        lock.lock()
        let value = (mix, barkEnvelope, barkFrequency)
        lock.unlock()
        return value
    }

    func decayBarkEnvelope(by amount: Double) {
        lock.lock()
        barkEnvelope = max(0, barkEnvelope - amount)
        lock.unlock()
    }
}

final class FrattypipelineAudioConductor {
    private let engine = AVAudioEngine()
    private let state = FrattypipelineAudioState()
    private var sourceNode: AVAudioSourceNode?
    private var sampleCursor = 0.0
    private var isPrepared = false

    func start() {
        guard !engine.isRunning else { return }
        prepareIfNeeded()

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
        } catch {
            // The prototype should stay playable even if simulator/device audio is unavailable.
        }
    }

    func stop() {
        engine.stop()
    }

    func update(section: FrattypipelineSongSection, stemCount: Int, beatEnergy: CGFloat) {
        state.update(mix: FrattypipelineAudioMix(
            stemCount: stemCount,
            section: section,
            beatEnergy: Double(beatEnergy)
        ))
    }

    func triggerBark(onBeat: Bool, section: FrattypipelineSongSection) {
        state.triggerBark(onBeat: onBeat, section: section)
    }

    private func prepareIfNeeded() {
        guard !isPrepared else { return }
        isPrepared = true

        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let source = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            self?.render(frameCount: frameCount, audioBufferList: audioBufferList, sampleRate: format.sampleRate)
            return noErr
        }

        sourceNode = source
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
    }

    private func render(frameCount: AVAudioFrameCount, audioBufferList: UnsafeMutablePointer<AudioBufferList>, sampleRate: Double) {
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)

        for frame in 0..<Int(frameCount) {
            let snapshot = state.snapshot()
            let t = sampleCursor / sampleRate
            let sample = sampleValue(at: t, snapshot: snapshot)
            state.decayBarkEnvelope(by: 1.0 / (sampleRate * 0.16))
            sampleCursor += 1

            for buffer in buffers {
                let data = buffer.mData!.assumingMemoryBound(to: Float.self)
                data[frame] = Float(sample)
            }
        }
    }

    private func sampleValue(at time: Double, snapshot: (mix: FrattypipelineAudioMix, barkEnvelope: Double, barkFrequency: Double)) -> Double {
        let mix = snapshot.mix
        let stemCount = max(1, min(4, mix.stemCount))
        var value = sine(time, frequency: mix.baseFrequency) * 0.45

        if stemCount >= 2 {
            value += sine(time, frequency: mix.baseFrequency * 1.5) * 0.24
        }
        if stemCount >= 3 {
            value += sine(time, frequency: mix.baseFrequency * 2.0) * 0.16
        }
        if stemCount >= 4 {
            value += sine(time, frequency: mix.baseFrequency * 2.5) * 0.10
        }

        let bark = sine(time, frequency: snapshot.barkFrequency) * snapshot.barkEnvelope * 0.55
        return max(-0.22, min(0.22, (value + bark) * mix.masterGain))
    }

    private func sine(_ time: Double, frequency: Double) -> Double {
        sin(2.0 * .pi * frequency * time)
    }
}

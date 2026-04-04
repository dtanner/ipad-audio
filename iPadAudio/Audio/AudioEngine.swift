import AVFoundation
import Accelerate

/// Manages AVAudioEngine lifecycle, mic tap, and DSP dispatch.
final class AudioEngine {
    private let engine = AVAudioEngine()
    private let dspQueue = DispatchQueue(label: "com.iPadAudio.dsp", qos: .userInteractive)
    private let aWeighting = AWeightingFilter()
    private let fftProcessor = FFTProcessor()

    /// Called on main queue with computed SPL value.
    var onSPL: ((Double) -> Void)?
    /// Called on main queue with FFT magnitude spectrum in dB.
    var onSpectrum: (([Float]) -> Void)?

    /// Actual sample rate determined at runtime.
    private(set) var actualSampleRate: Double = AudioConstants.sampleRate
    /// Block size adjusted for actual sample rate (targets 100ms).
    private(set) var actualBlockSize: Int = AudioConstants.blockSize

    func start() throws {
        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)
        actualSampleRate = hwFormat.sampleRate
        actualBlockSize = Int(actualSampleRate * 0.1) // 100ms

        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(actualBlockSize), format: hwFormat) { [weak self] buffer, _ in
            self?.handleBuffer(buffer)
        }

        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        aWeighting.reset()
    }

    private func handleBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)

        // Copy float samples to Double array on the audio thread (minimal work)
        var samples = [Double](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            samples[i] = Double(channelData[0][i])
        }

        dspQueue.async { [weak self] in
            guard let self else { return }

            // A-weight and compute SPL
            let weighted = self.aWeighting.apply(samples)
            let spl = SPLCalculator.compute(weighted)

            // FFT on raw (unfiltered) audio
            let spectrum = self.fftProcessor.process(samples)

            DispatchQueue.main.async {
                self.onSPL?(spl)
                self.onSpectrum?(spectrum)
            }
        }
    }
}

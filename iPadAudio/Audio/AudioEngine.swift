import AVFoundation
import Accelerate

/// Manages AVAudioEngine lifecycle, mic tap, and DSP dispatch.
final class AudioEngine {
    private let engine = AVAudioEngine()
    private let dspQueue = DispatchQueue(label: "com.iPadAudio.dsp", qos: .userInteractive)
    private let aWeighting = AWeightingFilter()
    private let yinDetector = YINPitchDetector()

    /// Called on main queue with computed SPL value.
    var onSPL: ((Double) -> Void)?
    /// Called on main queue with detected pitch frequency (nil if no pitch).
    var onPitch: ((Double?) -> Void)?

    /// Actual sample rate determined at runtime.
    private(set) var actualSampleRate: Double = AudioConstants.sampleRate
    /// Block size for SPL analysis (targets 100ms).
    private(set) var actualBlockSize: Int = AudioConstants.blockSize

    /// Accumulated samples for overlapping pitch detection
    private var sampleAccumulator = [Double]()
    /// Number of new samples since last SPL computation
    private var splSamplesAccumulated = 0
    /// Hop size for pitch detection (targets 20ms for 50 Hz updates)
    private var pitchHopSize: Int = 960
    /// Number of new samples since last pitch computation
    private var pitchSamplesAccumulated = 0

    func start() throws {
        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)
        actualSampleRate = hwFormat.sampleRate
        actualBlockSize = Int(actualSampleRate * 0.1) // 100ms for SPL
        pitchHopSize = Int(actualSampleRate / AudioConstants.pitchUpdateRate) // ~20ms
        yinDetector.updateSampleRate(actualSampleRate)

        // Request smaller buffers to enable higher-rate pitch detection
        let tapBufferSize = AVAudioFrameCount(pitchHopSize)

        inputNode.installTap(onBus: 0, bufferSize: tapBufferSize, format: hwFormat) { [weak self] buffer, _ in
            self?.handleBuffer(buffer)
        }

        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        aWeighting.reset()
        dspQueue.async { [weak self] in
            self?.sampleAccumulator.removeAll()
            self?.splSamplesAccumulated = 0
            self?.pitchSamplesAccumulated = 0
        }
    }

    private func handleBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)

        // Copy float samples to Double array on the audio thread
        var samples = [Double](repeating: 0, count: frameCount)
        for i in 0..<frameCount {
            samples[i] = Double(channelData[0][i])
        }

        dspQueue.async { [weak self] in
            guard let self else { return }

            // Append new samples to accumulator
            self.sampleAccumulator.append(contentsOf: samples)
            self.splSamplesAccumulated += frameCount
            self.pitchSamplesAccumulated += frameCount

            // Trim accumulator to keep at most 2x the analysis window
            let maxKeep = self.actualBlockSize * 2
            if self.sampleAccumulator.count > maxKeep {
                self.sampleAccumulator.removeFirst(self.sampleAccumulator.count - maxKeep)
            }

            // SPL: compute every ~100ms worth of new samples
            if self.splSamplesAccumulated >= self.actualBlockSize {
                let splSamples = Array(self.sampleAccumulator.suffix(self.actualBlockSize))
                let weighted = self.aWeighting.apply(splSamples)
                let spl = SPLCalculator.compute(weighted)
                self.splSamplesAccumulated = 0

                DispatchQueue.main.async {
                    self.onSPL?(spl)
                }
            }

            // Pitch: compute every hop (~20ms) using overlapping windows.
            // iOS may deliver large buffers, so loop to emit multiple detections.
            if self.sampleAccumulator.count >= self.actualBlockSize {
                var pitchResults = [Double?]()
                while self.pitchSamplesAccumulated >= self.pitchHopSize {
                    self.pitchSamplesAccumulated -= self.pitchHopSize

                    // Compute how far back from the end this detection's window ends
                    let offset = self.pitchSamplesAccumulated
                    let endIndex = self.sampleAccumulator.count - offset
                    let startIndex = endIndex - self.actualBlockSize
                    if startIndex < 0 { continue }

                    let pitchSamples = Array(self.sampleAccumulator[startIndex..<endIndex])
                    let pitch = self.yinDetector.detect(pitchSamples)
                    pitchResults.append(pitch)
                }

                if !pitchResults.isEmpty {
                    DispatchQueue.main.async {
                        for pitch in pitchResults {
                            self.onPitch?(pitch)
                        }
                    }
                }
            }
        }
    }
}

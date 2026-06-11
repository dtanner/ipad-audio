import Accelerate

/// 4th-order Butterworth high-pass filter (two cascaded biquads) with
/// persistent state for continuous stream filtering.
///
/// Applied to the pitch-detection signal path to remove sub-bass rumble (HVAC,
/// building/electrical hum below the musical range). Without it, that energy
/// drives YIN to spurious low-frequency detections. State is kept across buffers
/// so the stream is filtered continuously — filtering each analysis window
/// independently would introduce a startup transient that skews low notes.
final class HighPassFilter {
    // Pole Q values for a 4th-order Butterworth, factored into two biquads.
    private let sectionQs: [Double] = [0.54120, 1.30656]
    private let cutoffHz: Double
    private var setup: vDSP_biquad_Setup?
    private var delays: [Double]

    init(cutoffHz: Double, sampleRate: Double) {
        self.cutoffHz = cutoffHz
        self.delays = [Double](repeating: 0, count: 2 * sectionQs.count + 2)
        rebuild(sampleRate: sampleRate)
    }

    deinit {
        if let setup { vDSP_biquad_DestroySetupD(setup) }
    }

    func updateSampleRate(_ rate: Double) {
        rebuild(sampleRate: rate)
        reset()
    }

    /// Filter a contiguous block, carrying delay state across calls.
    func apply(_ samples: [Double]) -> [Double] {
        guard let setup else { return samples }
        var output = [Double](repeating: 0, count: samples.count)
        vDSP_biquadD(setup, &delays, samples, 1, &output, 1, vDSP_Length(samples.count))
        return output
    }

    /// Clear delay state (e.g. on stop / audio interruption).
    func reset() {
        delays = [Double](repeating: 0, count: 2 * sectionQs.count + 2)
    }

    /// Build the cascaded-biquad coefficients (RBJ cookbook high-pass) for the
    /// current sample rate. vDSP expects [b0, b1, b2, a1, a2] per section, a0 = 1.
    private func rebuild(sampleRate: Double) {
        if let setup { vDSP_biquad_DestroySetupD(setup) }

        let w0 = 2 * Double.pi * cutoffHz / sampleRate
        let cosw = cos(w0)
        let sinw = sin(w0)

        var coeffs: [Double] = []
        for q in sectionQs {
            let alpha = sinw / (2 * q)
            let a0 = 1 + alpha
            coeffs += [
                (1 + cosw) / 2 / a0,   // b0
                -(1 + cosw) / a0,      // b1
                (1 + cosw) / 2 / a0,   // b2
                (-2 * cosw) / a0,      // a1
                (1 - alpha) / a0,      // a2
            ]
        }

        setup = vDSP_biquad_CreateSetupD(coeffs, vDSP_Length(sectionQs.count))
    }
}

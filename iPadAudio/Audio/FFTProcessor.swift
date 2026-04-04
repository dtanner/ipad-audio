import Accelerate

/// Computes FFT magnitude spectrum in dB from raw audio samples.
final class FFTProcessor {
    private let fftSize: Int
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup
    private var window: [Float]
    private let halfN: Int

    init(fftSize: Int = AudioConstants.fftSize) {
        self.fftSize = fftSize
        self.log2n = vDSP_Length(log2(Double(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        self.halfN = fftSize / 2

        // Blackman-Harris window sized to one audio block
        self.window = [Float](repeating: 0, count: AudioConstants.blockSize)
        vDSP_blkman_window(&self.window, vDSP_Length(AudioConstants.blockSize), 0)
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    /// Process raw audio samples and return magnitude spectrum in dB.
    /// Returns array of halfN Float values (dB scale, typically -100 to 0 range).
    func process(_ samples: [Double]) -> [Float] {
        let blockSize = min(samples.count, window.count)

        // Convert to Float and apply window
        var floatSamples = [Float](repeating: 0, count: blockSize)
        for i in 0..<blockSize {
            floatSamples[i] = Float(samples[i])
        }

        // Resize window if actual block size differs
        if blockSize != window.count {
            window = [Float](repeating: 0, count: blockSize)
            vDSP_blkman_window(&window, vDSP_Length(blockSize), 0)
        }

        var windowed = [Float](repeating: 0, count: blockSize)
        vDSP_vmul(floatSamples, 1, window, 1, &windowed, 1, vDSP_Length(blockSize))

        // Zero-pad to FFT size
        var padded = [Float](repeating: 0, count: fftSize)
        padded.replaceSubrange(0..<blockSize, with: windowed)

        // Pack into split complex format
        var realp = [Float](repeating: 0, count: halfN)
        var imagp = [Float](repeating: 0, count: halfN)

        realp.withUnsafeMutableBufferPointer { realBuf in
            imagp.withUnsafeMutableBufferPointer { imagBuf in
                var splitComplex = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)

                padded.withUnsafeBufferPointer { paddedBuf in
                    paddedBuf.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfN))
                    }
                }

                // Forward FFT
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                // Compute magnitudes: sqrt(real² + imag²)
                var squaredMags = [Float](repeating: 0, count: halfN)
                vDSP_zvmags(&splitComplex, 1, &squaredMags, 1, vDSP_Length(halfN))

                var magnitudes = [Float](repeating: 0, count: halfN)
                var count = Int32(halfN)
                vvsqrtf(&magnitudes, squaredMags, &count)

                // Normalize: vDSP real FFT output is scaled by 2, so divide by N/2
                // to get proper magnitude per bin
                var norm: Float = 2.0 / Float(fftSize)
                vDSP_vsmul(magnitudes, 1, &norm, &magnitudes, 1, vDSP_Length(halfN))

                // Floor to avoid log(0)
                var minVal: Float = 1e-20
                vDSP_vthr(magnitudes, 1, &minVal, &magnitudes, 1, vDSP_Length(halfN))

                // Convert to dB: 20 * log10(|magnitude|)
                var dbValues = [Float](repeating: 0, count: halfN)
                vvlog10f(&dbValues, magnitudes, &count)
                var twenty: Float = 20.0
                vDSP_vsmul(dbValues, 1, &twenty, &dbValues, 1, vDSP_Length(halfN))

                self.lastSpectrum = dbValues
            }
        }

        return lastSpectrum
    }

    private var lastSpectrum = [Float]()
}

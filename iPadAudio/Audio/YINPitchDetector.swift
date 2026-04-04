import Accelerate
import Foundation

/// YIN monophonic pitch detection algorithm using FFT-based autocorrelation.
final class YINPitchDetector {
    private let threshold: Double = 0.15
    private let rmsGate: Double = 1e-4
    private let freqMin: Double = 30
    private let freqMax: Double = 5000
    private let c6Ceiling: Double = 1046.5

    private var sampleRate: Double

    init(sampleRate: Double = 48000) {
        self.sampleRate = sampleRate
    }

    func updateSampleRate(_ rate: Double) {
        sampleRate = rate
    }

    /// Detect pitch from raw audio samples. Returns frequency in Hz or nil.
    func detect(_ samples: [Double]) -> Double? {
        let count = samples.count
        guard count > 0 else { return nil }

        // Step 1: Silence gate
        var sumSq: Double = 0
        vDSP_dotprD(samples, 1, samples, 1, &sumSq, vDSP_Length(count))
        let rms = sqrt(sumSq / Double(count))
        if rms < rmsGate { return nil }

        // Step 2: Difference function (FFT-based)
        let tauMax = Int(sampleRate / freqMin)
        let W = min(count, tauMax)
        guard W > 2 else { return nil }

        let acf = autocorrelation(samples: samples, W: W)

        // Compute energy terms using cumulative sum approach (matching pi-audio)
        let xHead = Array(samples.prefix(W))
        var xSq = [Double](repeating: 0, count: W)
        vDSP_vmulD(xHead, 1, xHead, 1, &xSq, 1, vDSP_Length(W))

        // Cumulative sum
        var cs = [Double](repeating: 0, count: W)
        cs[0] = xSq[0]
        for i in 1..<W {
            cs[i] = cs[i - 1] + xSq[i]
        }

        // d[tau] = r_head[tau] + r_tail[tau] - 2*acf[tau]
        var d = [Double](repeating: 0, count: W)
        let totalEnergy = cs[W - 1]
        for tau in 1..<W {
            let rHead = cs[W - 1 - tau]
            let rTail = totalEnergy - cs[tau - 1]
            d[tau] = rHead + rTail - 2.0 * acf[tau]
            if d[tau] < 0 { d[tau] = 0 }
        }

        // Step 3: CMNDF
        var dprime = [Double](repeating: 1.0, count: W)
        var cumsum: Double = 0
        for tau in 1..<W {
            cumsum += d[tau]
            if cumsum > 0 {
                dprime[tau] = d[tau] * Double(tau) / cumsum
            }
        }

        // Step 4: Absolute threshold search
        var bestTau: Int? = nil
        var tau = 2
        while tau < W {
            if dprime[tau] < threshold {
                while tau + 1 < W && dprime[tau + 1] < dprime[tau] {
                    tau += 1
                }
                bestTau = tau
                break
            }
            tau += 1
        }

        guard let foundTau = bestTau else { return nil }

        // Step 5: Parabolic interpolation
        let tauRefined: Double
        if foundTau <= 0 || foundTau >= W - 1 {
            tauRefined = Double(foundTau)
        } else {
            let s0 = dprime[foundTau - 1]
            let s1 = dprime[foundTau]
            let s2 = dprime[foundTau + 1]
            let denom = 2.0 * (2.0 * s1 - s2 - s0)
            if denom == 0 {
                tauRefined = Double(foundTau)
            } else {
                tauRefined = Double(foundTau) + (s2 - s0) / denom
            }
        }

        // Step 6: Frequency conversion
        guard tauRefined > 0 else { return nil }
        let frequency = sampleRate / tauRefined

        if frequency < freqMin || frequency > freqMax { return nil }
        if frequency > c6Ceiling { return nil }

        return frequency
    }

    // MARK: - FFT-based autocorrelation

    private func autocorrelation(samples: [Double], W: Int) -> [Double] {
        let fftSize = nextPowerOf2(2 * W)
        let log2n = vDSP_Length(log2(Double(fftSize)))
        guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
            return [Double](repeating: 0, count: W)
        }
        defer { vDSP_destroy_fftsetupD(fftSetup) }

        let halfN = fftSize / 2

        // Zero-padded input
        var xPadded = [Double](repeating: 0, count: fftSize)
        for i in 0..<W {
            xPadded[i] = samples[i]
        }

        var realp = [Double](repeating: 0, count: halfN)
        var imagp = [Double](repeating: 0, count: halfN)

        // Pack into split complex
        realp.withUnsafeMutableBufferPointer { rBuf in
            imagp.withUnsafeMutableBufferPointer { iBuf in
                var split = DSPDoubleSplitComplex(realp: rBuf.baseAddress!, imagp: iBuf.baseAddress!)
                xPadded.withUnsafeBufferPointer { xBuf in
                    xBuf.baseAddress!.withMemoryRebound(to: DSPDoubleComplex.self, capacity: halfN) { ptr in
                        vDSP_ctozD(ptr, 2, &split, 1, vDSP_Length(halfN))
                    }
                }
                // Forward FFT
                vDSP_fft_zripD(fftSetup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }

        // Power spectrum: |X[k]|^2
        // vDSP packed format stores DC in realp[0] and Nyquist in imagp[0],
        // so compute squared magnitudes and repack correctly.
        var mags = [Double](repeating: 0, count: halfN)
        realp.withUnsafeMutableBufferPointer { rBuf in
            imagp.withUnsafeMutableBufferPointer { iBuf in
                var split = DSPDoubleSplitComplex(realp: rBuf.baseAddress!, imagp: iBuf.baseAddress!)
                vDSP_zvmagsD(&split, 1, &mags, 1, vDSP_Length(halfN))
            }
        }

        var powerReal = [Double](repeating: 0, count: halfN)
        var powerImag = [Double](repeating: 0, count: halfN)
        powerReal[0] = realp[0] * realp[0]  // DC²
        powerImag[0] = imagp[0] * imagp[0]  // Nyquist²
        for k in 1..<halfN {
            powerReal[k] = mags[k]
        }

        // Inverse FFT
        powerReal.withUnsafeMutableBufferPointer { rBuf in
            powerImag.withUnsafeMutableBufferPointer { iBuf in
                var split = DSPDoubleSplitComplex(realp: rBuf.baseAddress!, imagp: iBuf.baseAddress!)
                vDSP_fft_zripD(fftSetup, &split, 1, log2n, FFTDirection(kFFTDirection_Inverse))
            }
        }

        // Unpack to interleaved
        var result = [Double](repeating: 0, count: fftSize)
        powerReal.withUnsafeMutableBufferPointer { rBuf in
            powerImag.withUnsafeMutableBufferPointer { iBuf in
                var split = DSPDoubleSplitComplex(realp: rBuf.baseAddress!, imagp: iBuf.baseAddress!)
                result.withUnsafeMutableBufferPointer { resBuf in
                    resBuf.baseAddress!.withMemoryRebound(to: DSPDoubleComplex.self, capacity: halfN) { ptr in
                        vDSP_ztocD(&split, 1, ptr, 2, vDSP_Length(halfN))
                    }
                }
            }
        }

        // Normalize: vDSP real FFT scales forward by 2 and inverse is unnormalized,
        // so the round-trip power spectrum scale is 4*N.
        var scale = 1.0 / Double(fftSize * 4)
        vDSP_vsmulD(result, 1, &scale, &result, 1, vDSP_Length(fftSize))

        return Array(result.prefix(W))
    }

    private func nextPowerOf2(_ n: Int) -> Int {
        var v = n - 1
        v |= v >> 1
        v |= v >> 2
        v |= v >> 4
        v |= v >> 8
        v |= v >> 16
        return v + 1
    }
}

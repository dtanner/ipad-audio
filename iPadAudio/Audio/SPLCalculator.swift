import Accelerate
import Foundation

enum SPLCalculator {
    /// Compute A-weighted SPL in dB from filtered samples.
    /// - Parameter samples: A-weighted audio samples (Double)
    /// - Returns: SPL value in dB (relative, calibrated with offset from AudioConstants.calibrationDB)
    static func compute(_ samples: [Double]) -> Double {
        var sumOfSquares: Double = 0
        vDSP_dotprD(samples, 1, samples, 1, &sumOfSquares, vDSP_Length(samples.count))
        let rms = sqrt(sumOfSquares / Double(samples.count))
        let safeRMS = max(rms, 1e-20)
        return 20.0 * log10(safeRMS) + AudioConstants.calibrationDB
    }
}

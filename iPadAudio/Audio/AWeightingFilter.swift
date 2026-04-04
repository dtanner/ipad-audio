import Accelerate

/// IEC 61672 A-weighting filter implemented as 3 cascaded biquad sections.
/// Coefficients pre-computed for 48kHz sample rate via scipy bilinear_zpk + zpk2sos.
final class AWeightingFilter {

    // MARK: - SOS coefficients for 48kHz

    // Section 0: low-frequency shaping (double pole near f1=20.6 Hz)
    private static let b0_0: Double = 0.2343005928664721
    private static let b1_0: Double = 0.4686011857329442
    private static let b2_0: Double = 0.2343005928664721
    private static let a1_0: Double = -0.22455845805977914
    private static let a2_0: Double = 0.012606625271546396

    // Section 1: mid-frequency shaping (poles near f2/f3)
    private static let b0_1: Double = 1.0
    private static let b1_1: Double = -2.0
    private static let b2_1: Double = 1.0
    private static let a1_1: Double = -1.8938704947230707
    private static let a2_1: Double = 0.8951597690946617

    // Section 2: high-frequency shaping (double pole near f4=12194 Hz)
    private static let b0_2: Double = 1.0
    private static let b1_2: Double = -2.0
    private static let b2_2: Double = 1.0
    private static let a1_2: Double = -1.9946144559930215
    private static let a2_2: Double = 0.9946217070140843

    // Biquad setups (vDSP)
    private let setup0: vDSP_biquad_Setup
    private let setup1: vDSP_biquad_Setup
    private let setup2: vDSP_biquad_Setup

    // Persistent delay state for filter continuity across blocks
    private var delays0 = [Double](repeating: 0, count: 2 + 2 + 1) // 5 elements per section
    private var delays1 = [Double](repeating: 0, count: 5)
    private var delays2 = [Double](repeating: 0, count: 5)

    init() {
        // vDSP_biquad_CreateSetup expects coefficients as [b0, b1, b2, a1, a2]
        // (a0 is implicitly 1.0)
        let coeffs0 = [Self.b0_0, Self.b1_0, Self.b2_0, Self.a1_0, Self.a2_0]
        let coeffs1 = [Self.b0_1, Self.b1_1, Self.b2_1, Self.a1_1, Self.a2_1]
        let coeffs2 = [Self.b0_2, Self.b1_2, Self.b2_2, Self.a1_2, Self.a2_2]

        setup0 = vDSP_biquad_CreateSetupD(coeffs0, 1)!
        setup1 = vDSP_biquad_CreateSetupD(coeffs1, 1)!
        setup2 = vDSP_biquad_CreateSetupD(coeffs2, 1)!
    }

    deinit {
        vDSP_biquad_DestroySetupD(setup0)
        vDSP_biquad_DestroySetupD(setup1)
        vDSP_biquad_DestroySetupD(setup2)
    }

    /// Apply A-weighting filter to input samples (in-place capable).
    /// - Parameter samples: Audio samples as Double array
    /// - Returns: A-weighted samples
    func apply(_ samples: [Double]) -> [Double] {
        let count = vDSP_Length(samples.count)
        var output = [Double](repeating: 0, count: samples.count)

        vDSP_biquadD(setup0, &delays0, samples, 1, &output, 1, count)
        vDSP_biquadD(setup1, &delays1, output, 1, &output, 1, count)
        vDSP_biquadD(setup2, &delays2, output, 1, &output, 1, count)

        return output
    }

    /// Reset filter state (e.g. on audio interruption).
    func reset() {
        delays0 = [Double](repeating: 0, count: 5)
        delays1 = [Double](repeating: 0, count: 5)
        delays2 = [Double](repeating: 0, count: 5)
    }
}

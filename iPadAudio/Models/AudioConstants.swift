import Foundation

enum AudioConstants {
    static let sampleRate: Double = 48000
    static let blockSize: Int = 4800          // 100ms at 48kHz
    static let fftSize: Int = 16384
    static let fftBinHz: Double = sampleRate / Double(fftSize) // ≈2.93 Hz
    static let updateRate: Double = 10        // Hz

    static let calibrationDB: Double = 120.0
    static let splMin: Double = 20
    static let splMax: Double = 100
    static let quietThreshold: Double = 55
    static let moderateThreshold: Double = 75
}

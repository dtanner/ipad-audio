import XCTest
@testable import iPadAudio

final class YINPitchDetectorTests: XCTestCase {

    private let sampleRate: Double = 48000
    private let blockSize: Int = 4800

    private func makeSineWave(frequency: Double, count: Int, sampleRate: Double = 48000) -> [Double] {
        (0..<count).map { i in
            sin(2.0 * .pi * frequency * Double(i) / sampleRate)
        }
    }

    // MARK: - Basic pitch detection

    func testDetectsA4() {
        let detector = YINPitchDetector(sampleRate: sampleRate)
        let samples = makeSineWave(frequency: 440.0, count: blockSize)
        let result = detector.detect(samples)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 440.0, accuracy: 1.0, "Should detect A4 within 1 Hz")
    }

    func testDetectsC4() {
        let detector = YINPitchDetector(sampleRate: sampleRate)
        let samples = makeSineWave(frequency: 261.63, count: blockSize)
        let result = detector.detect(samples)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 261.63, accuracy: 1.0, "Should detect C4 within 1 Hz")
    }

    func testDetectsE5() {
        let detector = YINPitchDetector(sampleRate: sampleRate)
        let samples = makeSineWave(frequency: 659.26, count: blockSize)
        let result = detector.detect(samples)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 659.26, accuracy: 2.0, "Should detect E5 within 2 Hz")
    }

    func testDetectsE2Low() {
        let detector = YINPitchDetector(sampleRate: sampleRate)
        let samples = makeSineWave(frequency: 82.41, count: blockSize)
        let result = detector.detect(samples)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 82.41, accuracy: 1.0, "Should detect E2 within 1 Hz")
    }

    func testDetectsE4() {
        let detector = YINPitchDetector(sampleRate: sampleRate)
        let samples = makeSineWave(frequency: 329.63, count: blockSize)
        let result = detector.detect(samples)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 329.63, accuracy: 1.0, "Should detect E4 within 1 Hz")
    }

    // MARK: - Edge cases

    func testSilenceReturnsNil() {
        let detector = YINPitchDetector(sampleRate: sampleRate)
        let samples = [Double](repeating: 0, count: blockSize)
        XCTAssertNil(detector.detect(samples), "Silence should return nil")
    }

    func testEmptyInputReturnsNil() {
        let detector = YINPitchDetector(sampleRate: sampleRate)
        XCTAssertNil(detector.detect([]), "Empty input should return nil")
    }

    func testVeryQuietSignalReturnsNil() {
        let detector = YINPitchDetector(sampleRate: sampleRate)
        let samples = makeSineWave(frequency: 440.0, count: blockSize).map { $0 * 1e-6 }
        XCTAssertNil(detector.detect(samples), "Signal below RMS gate should return nil")
    }

    // MARK: - Frequency range limits

    func testRejectsFrequencyAboveCeiling() {
        let detector = YINPitchDetector(sampleRate: sampleRate)
        // C6 ceiling is 1046.5 Hz; try a frequency well above it
        let samples = makeSineWave(frequency: 2000.0, count: blockSize)
        XCTAssertNil(detector.detect(samples), "Frequencies above C6 ceiling should be rejected")
    }

    // MARK: - Sample rate update

    func testUpdateSampleRate() {
        let detector = YINPitchDetector(sampleRate: 44100)
        detector.updateSampleRate(48000)

        let samples = makeSineWave(frequency: 440.0, count: blockSize, sampleRate: 48000)
        let result = detector.detect(samples)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 440.0, accuracy: 1.0)
    }

    // MARK: - Octave accuracy (the bug that was fixed)

    func testNoOctaveErrors() {
        let detector = YINPitchDetector(sampleRate: sampleRate)
        let testFreqs: [(hz: Double, name: String)] = [
            (261.63, "C4"), (329.63, "E4"), (440.0, "A4"),
            (523.25, "C5"), (659.26, "E5"), (82.41, "E2"),
            (110.0, "A2"), (220.0, "A3"),
        ]

        for (hz, name) in testFreqs {
            let samples = makeSineWave(frequency: hz, count: blockSize)
            guard let detected = detector.detect(samples) else {
                XCTFail("Failed to detect \(name) (\(hz) Hz)")
                continue
            }
            // Should be within 5% — an octave error would be 50% or 100% off
            let ratio = detected / hz
            XCTAssertEqual(ratio, 1.0, accuracy: 0.05,
                           "Octave error for \(name): expected \(hz) Hz, got \(detected) Hz")
        }
    }

    // MARK: - Consistency across calls

    func testConsistentAcrossMultipleCalls() {
        let detector = YINPitchDetector(sampleRate: sampleRate)
        let samples = makeSineWave(frequency: 440.0, count: blockSize)

        var results = [Double]()
        for _ in 0..<5 {
            if let result = detector.detect(samples) {
                results.append(result)
            }
        }

        XCTAssertEqual(results.count, 5, "Should detect pitch on all calls")
        for result in results {
            XCTAssertEqual(result, results[0], accuracy: 0.01,
                           "Results should be identical for same input")
        }
    }
}

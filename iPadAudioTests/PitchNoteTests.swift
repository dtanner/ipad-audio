import XCTest
@testable import iPadAudio

final class PitchNoteTests: XCTestCase {

    // MARK: - freqToNote

    func testA4() {
        let (name, octave, cents) = PitchNote.freqToNote(hz: 440.0)
        XCTAssertEqual(name, "A")
        XCTAssertEqual(octave, 4)
        XCTAssertEqual(cents, 0)
    }

    func testC4() {
        let (name, octave, cents) = PitchNote.freqToNote(hz: 261.63)
        XCTAssertEqual(name, "C")
        XCTAssertEqual(octave, 4)
        XCTAssertEqual(abs(cents) <= 1, true, "C4 cents should be near 0, got \(cents)")
    }

    func testE5() {
        let (name, octave, cents) = PitchNote.freqToNote(hz: 659.26)
        XCTAssertEqual(name, "E")
        XCTAssertEqual(octave, 5)
        XCTAssertEqual(abs(cents) <= 1, true, "E5 cents should be near 0, got \(cents)")
    }

    func testSharpNote() {
        // F#4 = 369.99 Hz
        let (name, octave, _) = PitchNote.freqToNote(hz: 369.99)
        XCTAssertEqual(name, "F#")
        XCTAssertEqual(octave, 4)
    }

    func testCentsPositiveWhenSharp() {
        // Slightly sharp A4
        let (name, _, cents) = PitchNote.freqToNote(hz: 445.0)
        XCTAssertEqual(name, "A")
        XCTAssertGreaterThan(cents, 0)
    }

    func testCentsNegativeWhenFlat() {
        // Slightly flat A4
        let (name, _, cents) = PitchNote.freqToNote(hz: 435.0)
        XCTAssertEqual(name, "A")
        XCTAssertLessThan(cents, 0)
    }

    // MARK: - semitoneToFreq

    func testSemitoneZeroIsA4() {
        XCTAssertEqual(PitchNote.semitoneToFreq(0), 440.0, accuracy: 0.01)
    }

    func testSemitone12IsA5() {
        XCTAssertEqual(PitchNote.semitoneToFreq(12), 880.0, accuracy: 0.01)
    }

    func testSemitoneNeg12IsA3() {
        XCTAssertEqual(PitchNote.semitoneToFreq(-12), 220.0, accuracy: 0.01)
    }

    // MARK: - freqToSemitone

    func testFreqToSemitoneA4() {
        XCTAssertEqual(PitchNote.freqToSemitone(440.0), 0.0, accuracy: 0.001)
    }

    func testFreqToSemitoneA5() {
        XCTAssertEqual(PitchNote.freqToSemitone(880.0), 12.0, accuracy: 0.001)
    }

    func testFreqToSemitoneRoundTrip() {
        for semi in -24...24 {
            let freq = PitchNote.semitoneToFreq(semi)
            let result = PitchNote.freqToSemitone(freq)
            XCTAssertEqual(result, Double(semi), accuracy: 0.001,
                           "Round-trip failed for semitone \(semi)")
        }
    }

    // MARK: - noteNameFromSemitone

    func testNoteNameA4() {
        XCTAssertEqual(PitchNote.noteNameFromSemitone(0), "A4")
    }

    func testNoteNameC4() {
        // C4 is MIDI 60, A4 is MIDI 69, so semitone = -9
        XCTAssertEqual(PitchNote.noteNameFromSemitone(-9), "C4")
    }

    func testNoteNameC5() {
        XCTAssertEqual(PitchNote.noteNameFromSemitone(3), "C5")
    }
}

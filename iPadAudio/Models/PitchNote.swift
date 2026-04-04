import Foundation

enum PitchNote {
    static let a4Freq: Double = 440.0
    static let a4Midi: Int = 69
    static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    /// Convert frequency to note name, octave, and cents deviation.
    static func freqToNote(hz: Double) -> (name: String, octave: Int, cents: Int) {
        let midi = 12.0 * log2(hz / a4Freq) + Double(a4Midi)
        let midiRounded = Int((midi).rounded())
        let cents = Int(((midi - Double(midiRounded)) * 100).rounded())
        let noteName = noteNames[((midiRounded % 12) + 12) % 12]
        let octave = midiRounded / 12 - 1
        return (noteName, octave, cents)
    }

    /// Convert semitone offset from A4 to frequency.
    static func semitoneToFreq(_ semitone: Int) -> Double {
        440.0 * pow(2.0, Double(semitone) / 12.0)
    }

    /// Convert semitone offset from A4 to note name + octave string.
    static func noteNameFromSemitone(_ semitone: Int) -> String {
        let midi = a4Midi + semitone
        let name = noteNames[((midi % 12) + 12) % 12]
        let octave = midi / 12 - 1
        return "\(name)\(octave)"
    }

    /// Convert frequency to continuous semitone offset from A4.
    static func freqToSemitone(_ hz: Double) -> Double {
        12.0 * log2(hz / a4Freq)
    }
}

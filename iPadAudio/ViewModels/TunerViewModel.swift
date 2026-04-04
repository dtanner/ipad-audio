import Foundation

@Observable
final class TunerViewModel {
    var stableNoteName: String?
    var stableOctave: Int?
    var smoothedCents: Double = 0

    private let alpha: Double = 0.15
    private let stabilityThreshold = 5
    private let timeoutThreshold = 10

    private var stabilityCount = 0
    private var timeoutCount = 0
    private var lastRawNote: String?

    /// Update with a new pitch detection result. Call once per audio frame (~10 Hz).
    func update(pitch: Double?) {
        if let hz = pitch {
            timeoutCount = 0
            let note = PitchNote.freqToNote(hz: hz)
            let rawNote = "\(note.name)\(note.octave)"

            // EMA smooth cents
            smoothedCents = alpha * Double(note.cents) + (1 - alpha) * smoothedCents

            // Note stability
            if rawNote == lastRawNote {
                stabilityCount += 1
            } else {
                stabilityCount = 1
                lastRawNote = rawNote
            }

            if stabilityCount >= stabilityThreshold {
                stableNoteName = note.name
                stableOctave = note.octave
            }
        } else {
            // No pitch — decay cents toward center
            smoothedCents = (1 - alpha) * smoothedCents

            timeoutCount += 1
            if timeoutCount >= timeoutThreshold {
                stableNoteName = nil
                stableOctave = nil
                stabilityCount = 0
                lastRawNote = nil
            }
        }
    }

    /// Color category based on cents deviation.
    var tunerColor: TunerColor {
        let absCents = abs(smoothedCents)
        if absCents <= 8 { return .inTune }
        if absCents <= 20 { return .close }
        return .outOfTune
    }

    enum TunerColor {
        case inTune, close, outOfTune
    }
}

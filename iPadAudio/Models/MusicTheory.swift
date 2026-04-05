import Foundation

// MARK: - Root Note

enum MusicRoot: String, CaseIterable, Identifiable {
    case c = "C"
    case db = "D♭"
    case d = "D"
    case eb = "E♭"
    case e = "E"
    case f = "F"
    case fSharp = "F♯"
    case g = "G"
    case ab = "A♭"
    case a = "A"
    case bb = "B♭"
    case b = "B"

    var id: String { rawValue }

    /// Pitch class (0–11, where C=0)
    var pitchClass: Int {
        switch self {
        case .c: 0
        case .db: 1
        case .d: 2
        case .eb: 3
        case .e: 4
        case .f: 5
        case .fSharp: 6
        case .g: 7
        case .ab: 8
        case .a: 9
        case .bb: 10
        case .b: 11
        }
    }

    /// Index into the musical alphabet (C=0, D=1, E=2, F=3, G=4, A=5, B=6)
    var letterIndex: Int {
        switch self {
        case .c: 0
        case .db, .d: 1
        case .eb, .e: 2
        case .f, .fSharp: 3
        case .g: 4
        case .ab, .a: 5
        case .bb, .b: 6
        }
    }

    /// Whether this root prefers flat spellings for chromatic non-scale tones
    var prefersFlats: Bool {
        switch self {
        case .f, .bb, .eb, .ab, .db: true
        default: false
        }
    }
}

// MARK: - Scale

enum MusicScale: String, CaseIterable, Identifiable {
    case major = "Major"
    case naturalMinor = "Natural Minor"
    case harmonicMinor = "Harmonic Minor"
    case melodicMinor = "Melodic Minor"
    case dorian = "Dorian"
    case phrygian = "Phrygian"
    case lydian = "Lydian"
    case mixolydian = "Mixolydian"
    case locrian = "Locrian"
    case pentatonicMajor = "Pentatonic Major"
    case pentatonicMinor = "Pentatonic Minor"
    case blues = "Blues"
    case wholeTone = "Whole Tone"
    case diminished = "Diminished"

    var id: String { rawValue }

    /// Intervals in semitones from root
    var intervals: [Int] {
        switch self {
        case .major:            [0, 2, 4, 5, 7, 9, 11]
        case .naturalMinor:     [0, 2, 3, 5, 7, 8, 10]
        case .harmonicMinor:    [0, 2, 3, 5, 7, 8, 11]
        case .melodicMinor:     [0, 2, 3, 5, 7, 9, 11]
        case .dorian:           [0, 2, 3, 5, 7, 9, 10]
        case .phrygian:         [0, 1, 3, 5, 7, 8, 10]
        case .lydian:           [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian:       [0, 2, 4, 5, 7, 9, 10]
        case .locrian:          [0, 1, 3, 5, 6, 8, 10]
        case .pentatonicMajor:  [0, 2, 4, 7, 9]
        case .pentatonicMinor:  [0, 3, 5, 7, 10]
        case .blues:            [0, 3, 5, 6, 7, 10]
        case .wholeTone:        [0, 2, 4, 6, 8, 10]
        case .diminished:       [0, 2, 3, 5, 6, 8, 9, 11]
        }
    }
}

// MARK: - Music Theory Utilities

enum MusicTheory {
    private static let letterNames = ["C", "D", "E", "F", "G", "A", "B"]
    private static let letterSemitones = [0, 2, 4, 5, 7, 9, 11]
    private static let sharpSpellings = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    private static let flatSpellings = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]

    /// Returns correctly-spelled note names for all 12 pitch classes given a root and scale.
    /// Index 0 = C, 1 = C♯/D♭, ..., 11 = B.
    static func chromaticSpellings(root: MusicRoot, scale: MusicScale) -> [String] {
        // Start with chromatic defaults based on root's sharp/flat preference
        var spellings = root.prefersFlats ? flatSpellings : sharpSpellings

        // Determine the 7-note reference scale for letter assignment
        let referenceIntervals: [Int]?
        switch scale {
        case .major, .naturalMinor, .harmonicMinor, .melodicMinor,
             .dorian, .phrygian, .lydian, .mixolydian, .locrian:
            referenceIntervals = scale.intervals
        case .pentatonicMajor:
            referenceIntervals = MusicScale.major.intervals
        case .pentatonicMinor, .blues:
            referenceIntervals = MusicScale.naturalMinor.intervals
        case .wholeTone, .diminished:
            referenceIntervals = nil
        }

        // Apply letter-assignment algorithm for the reference scale's 7 degrees
        if let intervals = referenceIntervals {
            for (degree, interval) in intervals.enumerated() {
                let letterIdx = (root.letterIndex + degree) % 7
                let letter = letterNames[letterIdx]
                let naturalSemitone = letterSemitones[letterIdx]
                let targetPitchClass = (root.pitchClass + interval) % 12
                let diff = (targetPitchClass - naturalSemitone + 12) % 12

                let accidental: String
                switch diff {
                case 0:  accidental = ""
                case 1:  accidental = "♯"
                case 2:  accidental = "♯♯"
                case 11: accidental = "♭"
                case 10: accidental = "♭♭"
                default: accidental = ""
                }

                spellings[targetPitchClass] = letter + accidental
            }
        }

        return spellings
    }

    /// Returns pitch classes that belong to the scale.
    static func scalePitchClasses(root: MusicRoot, scale: MusicScale) -> Set<Int> {
        Set(scale.intervals.map { (root.pitchClass + $0) % 12 })
    }

    /// Returns the correctly-spelled note name and octave for a MIDI note number.
    static func noteName(midi: Int, spellings: [String]) -> (name: String, octave: Int) {
        let pitchClass = ((midi % 12) + 12) % 12
        let name = spellings[pitchClass]
        var octave = midi / 12 - 1

        // Adjust octave for enharmonic boundary crossings (B♯/C♭)
        if let letter = name.first {
            if letter == "C" && pitchClass == 11 {
                octave += 1  // C♭ sounds as B but belongs to the C octave
            } else if letter == "B" && pitchClass == 0 {
                octave -= 1  // B♯ sounds as C but belongs to the B octave
            }
        }

        return (name, octave)
    }
}

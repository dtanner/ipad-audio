import SwiftUI

struct SPLReadout: View {
    let currentSPL: Double
    let safeThreshold: Double
    let cautionThreshold: Double

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(String(format: "%.0f", currentSPL))
                .font(.system(size: 36, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(splColor)
            Text("dB")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sound level")
        .accessibilityValue("\(Int(currentSPL)) decibels")
    }

    private var splColor: Color {
        if currentSPL >= cautionThreshold { return .red }
        if currentSPL >= safeThreshold { return .yellow }
        return .green
    }
}

struct PitchReadout: View {
    let tuner: TunerViewModel
    let noteSpellings: [String]

    var body: some View {
        Group {
            if let midi = tuner.stableMidi {
                let noted = MusicTheory.noteName(midi: midi, spellings: noteSpellings)
                HStack(spacing: 8) {
                    Text("\(noted.name)\(noted.octave)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.cyan)

                    TunerGaugeView(cents: tuner.smoothedCents, color: tuner.tunerColor)
                        .frame(width: 120, height: 28)

                    Text(centsText)
                        .font(.system(size: 18, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(centsColor)
                        .frame(width: 50, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Pitch")
                .accessibilityValue("\(noted.name)\(noted.octave), \(centsText)")
            } else {
                Text("—")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.gray.opacity(0.4))
                    .accessibilityLabel("Pitch")
                    .accessibilityValue("No pitch detected")
            }
        }
    }

    private var centsText: String {
        let c = Int(tuner.smoothedCents.rounded())
        if c >= 0 { return "+\(c)¢" }
        return "\(c)¢"
    }

    private var centsColor: Color {
        switch tuner.tunerColor {
        case .inTune: return .green
        case .close: return .yellow
        case .outOfTune: return .red
        }
    }
}

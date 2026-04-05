import SwiftUI

struct ValueOnlyView: View {
    let currentSPL: Double
    let safeThreshold: Double
    let cautionThreshold: Double
    let tuner: TunerViewModel
    let noteSpellings: [String]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Large SPL display
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%.0f", currentSPL))
                    .font(.system(size: 120, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(splColor)
                Text("dB")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }

            // Pitch display
            if let midi = tuner.stableMidi {
                let noted = MusicTheory.noteName(midi: midi, spellings: noteSpellings)
                VStack(spacing: 12) {
                    Text("\(noted.name)\(noted.octave)")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundStyle(.cyan)

                    TunerGaugeView(cents: tuner.smoothedCents, color: tuner.tunerColor)
                        .frame(width: 200, height: 36)

                    Text(centsText)
                        .font(.system(size: 28, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(centsColor)
                }
            } else {
                Text("—")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(.gray.opacity(0.4))
            }

            Spacer()
        }
    }

    private var splColor: Color {
        if currentSPL >= cautionThreshold { return .red }
        if currentSPL >= safeThreshold { return .yellow }
        return .green
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

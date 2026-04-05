import SwiftUI

struct ReadoutBar: View {
    let currentSPL: Double
    let safeThreshold: Double
    let cautionThreshold: Double
    let tuner: TunerViewModel
    let onShowSettings: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // SPL readout — stable left region
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.0f", currentSPL))
                    .font(.system(size: 36, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(splColor)
                Text("dB")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            // Pitch readout + tuner gauge — stable right region
            Group {
                if let name = tuner.stableNoteName, let octave = tuner.stableOctave {
                    HStack(spacing: 8) {
                        Text("\(name)\(octave)")
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
                } else {
                    Text("—")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.gray.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity)

            // Settings gear
            Button {
                onShowSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.gray)
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 8)
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

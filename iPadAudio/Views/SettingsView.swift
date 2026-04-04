import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                splSection
                historySection
                overtoneSection
                pitchSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - SPL Thresholds

    private var splSection: some View {
        Section("SPL Thresholds") {
            VStack(alignment: .leading) {
                HStack {
                    Text("Safe")
                    Spacer()
                    Text("\(Int(settings.safeThreshold)) dB")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.safeThreshold, in: 40...95, step: 1)
                    .tint(.green)
            }
            VStack(alignment: .leading) {
                HStack {
                    Text("Caution")
                    Spacer()
                    Text("\(Int(settings.cautionThreshold)) dB")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.cautionThreshold, in: 60...100, step: 1)
                    .tint(.yellow)
            }
        }
    }

    // MARK: - History

    private var historySection: some View {
        Section("History") {
            VStack(alignment: .leading) {
                HStack {
                    Text("Length")
                    Spacer()
                    Text(historyLabel)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(settings.historySeconds) },
                        set: { settings.historySeconds = Int($0) }
                    ),
                    in: 5...300,
                    step: 5
                )
            }
        }
    }

    private var historyLabel: String {
        let s = settings.historySeconds
        if s < 60 {
            return "\(s)s"
        } else {
            let min = s / 60
            let sec = s % 60
            return sec == 0 ? "\(min)m" : "\(min)m \(sec)s"
        }
    }

    // MARK: - Overtone Frequency Range

    private var overtoneSection: some View {
        Section("Overtone Frequency Range") {
            VStack(alignment: .leading) {
                HStack {
                    Text("Min")
                    Spacer()
                    Text("\(settings.overtoneFreqMin) Hz")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                // Log-scale slider for frequency
                Slider(
                    value: Binding(
                        get: { log10(Double(settings.overtoneFreqMin)) },
                        set: { settings.overtoneFreqMin = Int(pow(10, $0)) }
                    ),
                    in: log10(40)...log10(7999)
                )
            }
            VStack(alignment: .leading) {
                HStack {
                    Text("Max")
                    Spacer()
                    Text("\(settings.overtoneFreqMax) Hz")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(
                    value: Binding(
                        get: { log10(Double(settings.overtoneFreqMax)) },
                        set: { settings.overtoneFreqMax = Int(pow(10, $0)) }
                    ),
                    in: log10(41)...log10(8000)
                )
            }
        }
    }

    // MARK: - Pitch Note Range

    private var pitchSection: some View {
        Section("Pitch Range") {
            Toggle("Auto Range", isOn: $settings.pitchRangeAuto)

            if !settings.pitchRangeAuto {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Min Note")
                        Spacer()
                        Text(noteName(for: settings.pitchNoteMin))
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settings.pitchNoteMin) },
                            set: { settings.pitchNoteMin = Int($0) }
                        ),
                        in: -39...38,
                        step: 1
                    )
                }
                VStack(alignment: .leading) {
                    HStack {
                        Text("Max Note")
                        Spacer()
                        Text(noteName(for: settings.pitchNoteMax))
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settings.pitchNoteMax) },
                            set: { settings.pitchNoteMax = Int($0) }
                        ),
                        in: -38...39,
                        step: 1
                    )
                }
            }
        }
    }

    /// Convert semitone offset from A4 to note name + octave.
    private func noteName(for semitone: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        // A4 = semitone 0, MIDI 69
        let midi = 69 + semitone
        let octave = (midi / 12) - 1
        let noteIndex = ((midi % 12) + 12) % 12
        return "\(noteNames[noteIndex])\(octave)"
    }
}

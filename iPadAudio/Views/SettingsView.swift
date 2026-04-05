import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                splSection
                historySection
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
                    .accessibilityLabel("Safe threshold")
                    .accessibilityValue("\(Int(settings.safeThreshold)) decibels")
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
                    .accessibilityLabel("Caution threshold")
                    .accessibilityValue("\(Int(settings.cautionThreshold)) decibels")
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
                .accessibilityLabel("History length")
                .accessibilityValue(historyLabel)
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

}

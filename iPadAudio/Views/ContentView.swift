import SwiftUI

struct ContentView: View {
    @State private var viewModel = AudioViewModel()
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color(red: 10/255, green: 10/255, blue: 20/255)
                .ignoresSafeArea()

            if viewModel.micPermissionDenied {
                micDeniedView
            } else {
                mainContent
            }
        }
        .onAppear {
            viewModel.requestMicAndStart()
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: viewModel.settings)
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Top bar with SPL value and gear icon
            HStack {
                Spacer()

                // SPL readout
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.0f", viewModel.currentSPL))
                        .font(.system(size: 48, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(splColor)
                    Text("dB")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Settings gear
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundStyle(.gray)
                }
                .padding(.trailing, 16)
            }
            .padding(.vertical, 8)

            // SPL History Chart
            SPLChartView(
                splHistory: viewModel.splHistory.array,
                historySeconds: viewModel.settings.historySeconds,
                safeThreshold: viewModel.settings.safeThreshold,
                cautionThreshold: viewModel.settings.cautionThreshold
            )
            .padding(.horizontal, 8)

            // Spectrogram
            SpectrogramView(
                columns: viewModel.spectrogramColumns.array,
                freqMin: viewModel.settings.overtoneFreqMin,
                freqMax: viewModel.settings.overtoneFreqMax
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .onChange(of: viewModel.settings.historySeconds) {
            viewModel.updateHistoryCapacity()
        }
    }

    private var micDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text("Microphone Access Required")
                .font(.title2)
            Text("Open Settings to grant microphone permission.")
                .foregroundStyle(.secondary)
        }
    }

    private var splColor: Color {
        if viewModel.currentSPL >= viewModel.settings.cautionThreshold {
            return .red
        } else if viewModel.currentSPL >= viewModel.settings.safeThreshold {
            return .yellow
        } else {
            return .green
        }
    }
}

#Preview {
    ContentView()
}

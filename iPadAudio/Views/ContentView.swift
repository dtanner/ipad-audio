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
            // Readout bar with toggle buttons, SPL, pitch, freeze, settings
            HStack(spacing: 0) {
                ToggleButtonBar(activePanels: Binding(
                    get: { viewModel.settings.activePanels },
                    set: { viewModel.settings.activePanels = $0 }
                ))
                .padding(.leading, 16)

                ReadoutBar(
                    currentSPL: viewModel.currentSPL,
                    safeThreshold: viewModel.settings.safeThreshold,
                    cautionThreshold: viewModel.settings.cautionThreshold,
                    tuner: viewModel.tuner,
                    isFrozen: viewModel.isFrozen,
                    onToggleFreeze: { viewModel.isFrozen.toggle() },
                    onShowSettings: { showSettings = true }
                )
            }

            // Panel container: 0/1/2 panels with adaptive layout
            PanelContainerView(
                activePanels: viewModel.settings.activePanels,
                viewModel: viewModel
            )
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
}

#Preview {
    ContentView()
}

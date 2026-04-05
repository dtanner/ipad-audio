import SwiftUI

struct ContentView: View {
    @State private var viewModel = AudioViewModel()
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color(red: 10/255, green: 10/255, blue: 20/255)
                .ignoresSafeArea()

            if viewModel.micPermissionDenied {
                micDeniedView
            } else {
                mainContent
            }

            if let message = viewModel.audioInterruptionMessage {
                VStack {
                    AudioInterruptedBanner(message: message) {
                        viewModel.resumeAudio()
                    }
                    Spacer()
                }
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.audioInterruptionMessage)
        .onAppear {
            viewModel.requestMicAndStart()
        }
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .background:
                viewModel.handleBackground()
            case .active:
                viewModel.handleForeground()
            default:
                break
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: viewModel.settings)
        }
    }

    private var activePanelsBinding: Binding<[PanelType]> {
        Binding(
            get: { viewModel.settings.activePanels },
            set: { viewModel.settings.activePanels = $0 }
        )
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Top bar: SPL readout | pitch readout | gear
            HStack(spacing: 0) {
                SPLReadout(
                    currentSPL: viewModel.currentSPL,
                    safeThreshold: viewModel.settings.safeThreshold,
                    cautionThreshold: viewModel.settings.cautionThreshold
                )
                .frame(maxWidth: .infinity)

                HStack(spacing: 4) {
                    PanelToggleButton(panel: .meter, activePanels: activePanelsBinding)
                    PanelToggleButton(panel: .pitch, activePanels: activePanelsBinding)
                }

                PitchReadout(
                    tuner: viewModel.tuner,
                    noteSpellings: MusicTheory.chromaticSpellings(
                        root: viewModel.settings.rootNote,
                        scale: viewModel.settings.scaleType
                    )
                )
                .frame(maxWidth: .infinity)

                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundStyle(.gray)
                }
                .accessibilityLabel("Settings")
                .padding(.trailing, 16)
            }
            .padding(.vertical, 8)

            // Panel container: 0/1/2 panels with adaptive layout
            PanelContainerView(
                activePanels: activePanelsBinding,
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

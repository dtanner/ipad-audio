import SwiftUI

struct PanelContainerView: View {
    @Binding var activePanels: [PanelType]
    let viewModel: AudioViewModel

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        GeometryReader { geometry in
            let isNarrow = geometry.size.width < 600
            let panels = isNarrow ? Array(activePanels.prefix(1)) : activePanels

            if panels.isEmpty {
                ValueOnlyView(
                    currentSPL: viewModel.currentSPL,
                    safeThreshold: viewModel.settings.safeThreshold,
                    cautionThreshold: viewModel.settings.cautionThreshold,
                    tuner: viewModel.tuner,
                    noteSpellings: MusicTheory.chromaticSpellings(
                        root: viewModel.settings.rootNote,
                        scale: viewModel.settings.scaleType
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 8) {
                    ForEach(panels) { panel in
                        panelWithHeader(for: panel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    @ViewBuilder
    private func panelWithHeader(for panel: PanelType) -> some View {
        panelView(for: panel)
            .overlay(alignment: .topTrailing) {
                if panel == .pitch {
                    KeyPicker(settings: viewModel.settings)
                        .padding(6)
                }
            }
    }

    @ViewBuilder
    private func panelView(for panel: PanelType) -> some View {
        switch panel {
        case .meter:
            SPLChartView(
                splHistory: viewModel.splHistory.array,
                historySeconds: viewModel.settings.historySeconds,
                safeThreshold: viewModel.settings.safeThreshold,
                cautionThreshold: viewModel.settings.cautionThreshold,
                settings: viewModel.settings
            )
        case .pitch:
            PitchChartView(
                pitchHistory: viewModel.pitchHistory.array,
                historySeconds: viewModel.settings.historySeconds,
                settings: viewModel.settings
            )
        }
    }
}

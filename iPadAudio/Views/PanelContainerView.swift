import SwiftUI

struct PanelContainerView: View {
    let activePanels: [PanelType]
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
                    tuner: viewModel.tuner
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 8) {
                    ForEach(panels) { panel in
                        panelView(for: panel)
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
    private func panelView(for panel: PanelType) -> some View {
        switch panel {
        case .meter:
            SPLChartView(
                splHistory: viewModel.splHistory.array,
                historySeconds: viewModel.settings.historySeconds,
                safeThreshold: viewModel.settings.safeThreshold,
                cautionThreshold: viewModel.settings.cautionThreshold
            )
        case .pitch:
            PitchChartView(
                pitchHistory: viewModel.pitchHistory.array,
                historySeconds: viewModel.settings.historySeconds,
                pitchRangeAuto: viewModel.settings.pitchRangeAuto,
                pitchNoteMin: viewModel.settings.pitchNoteMin,
                pitchNoteMax: viewModel.settings.pitchNoteMax
            )
        }
    }
}

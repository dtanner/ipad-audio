import SwiftUI

struct ToggleButtonBar: View {
    @Binding var activePanels: [PanelType]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(PanelType.allCases) { panel in
                let isActive = activePanels.contains(panel)
                Button {
                    togglePanel(panel)
                } label: {
                    Image(systemName: panel.iconName)
                        .font(.title3)
                        .foregroundStyle(isActive ? .blue : .gray.opacity(0.5))
                        .frame(width: 36, height: 36)
                        .background(isActive ? Color.blue.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func togglePanel(_ panel: PanelType) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if let index = activePanels.firstIndex(of: panel) {
                activePanels.remove(at: index)
            } else if activePanels.count < 2 {
                activePanels.append(panel)
            } else {
                // Already 2 active — remove the leftmost, add the new one
                activePanels.removeFirst()
                activePanels.append(panel)
            }
        }
    }
}

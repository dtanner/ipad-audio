import SwiftUI

struct PanelToggleButton: View {
    let panel: PanelType
    @Binding var activePanels: [PanelType]

    var body: some View {
        let isActive = activePanels.contains(panel)
        Button {
            togglePanel()
        } label: {
            Image(systemName: panel.iconName)
                .font(.title3)
                .foregroundStyle(isActive ? .blue : .gray.opacity(0.5))
                .frame(width: 36, height: 36)
                .background(isActive ? Color.blue.opacity(0.15) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func togglePanel() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if let index = activePanels.firstIndex(of: panel) {
                activePanels.remove(at: index)
            } else if activePanels.count < 2 {
                activePanels.append(panel)
            } else {
                // Already 2 active — replace the other panel
                activePanels = [panel]
            }
            // Ensure canonical order: meter (left), pitch (right)
            let order = PanelType.allCases
            activePanels.sort { a, b in
                (order.firstIndex(of: a) ?? 0) < (order.firstIndex(of: b) ?? 0)
            }
        }
    }
}

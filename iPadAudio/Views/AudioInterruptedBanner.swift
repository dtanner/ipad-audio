import SwiftUI

struct AudioInterruptedBanner: View {
    let message: String
    let onResume: () -> Void

    var body: some View {
        Button(action: onResume) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 2) {
                    Text(message)
                        .font(.headline)
                    Text("Tap to resume")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(message). Tap to resume audio.")
    }
}

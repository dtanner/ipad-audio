import SwiftUI

struct KeyPicker: View {
    @Bindable var settings: AppSettings

    var body: some View {
        HStack(spacing: 6) {
            Menu {
                Picker("Root", selection: $settings.rootNote) {
                    ForEach(MusicRoot.allCases) { root in
                        Text(root.rawValue).tag(root)
                    }
                }
            } label: {
                Text(settings.rootNote.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Menu {
                Picker("Scale", selection: $settings.scaleType) {
                    ForEach(MusicScale.allCases) { scale in
                        Text(scale.rawValue).tag(scale)
                    }
                }
            } label: {
                Text(settings.scaleType.rawValue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

import SwiftUI

struct ContentView: View {
    @State private var viewModel = AudioViewModel()

    var body: some View {
        ZStack {
            Color(red: 10/255, green: 10/255, blue: 20/255)
                .ignoresSafeArea()

            if viewModel.micPermissionDenied {
                micDeniedView
            } else {
                splDisplayView
            }
        }
        .onAppear {
            viewModel.requestMicAndStart()
        }
        .preferredColorScheme(.dark)
    }

    private var splDisplayView: some View {
        VStack(spacing: 16) {
            Text(String(format: "%.0f", viewModel.currentSPL))
                .font(.system(size: 120, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(splColor)

            Text("dB")
                .font(.title)
                .foregroundStyle(.secondary)
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
        if viewModel.currentSPL >= AudioConstants.moderateThreshold {
            return .red
        } else if viewModel.currentSPL >= AudioConstants.quietThreshold {
            return .yellow
        } else {
            return .green
        }
    }
}

#Preview {
    ContentView()
}

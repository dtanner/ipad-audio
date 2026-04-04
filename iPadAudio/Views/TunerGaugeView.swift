import SwiftUI

struct TunerGaugeView: View {
    let cents: Double
    let color: TunerViewModel.TunerColor

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let midX = w / 2
            let midY = h / 2

            // Background bar
            let barHeight: CGFloat = 6
            let barRect = CGRect(x: 0, y: midY - barHeight / 2, width: w, height: barHeight)
            context.fill(Path(roundedRect: barRect, cornerRadius: 3),
                         with: .color(.gray.opacity(0.3)))

            // Center tick
            let tickWidth: CGFloat = 2
            let tickRect = CGRect(x: midX - tickWidth / 2, y: midY - h * 0.4, width: tickWidth, height: h * 0.8)
            context.fill(Path(tickRect), with: .color(.gray.opacity(0.6)))

            // Indicator position: cents range -50 to +50 mapped to bar width
            let clamped = max(-50, min(50, cents))
            let indicatorX = midX + CGFloat(clamped / 50) * (w / 2 - 8)

            // Indicator
            let indicatorSize: CGFloat = 12
            let indicatorRect = CGRect(
                x: indicatorX - indicatorSize / 2,
                y: midY - indicatorSize / 2,
                width: indicatorSize,
                height: indicatorSize
            )
            let indicatorColor: Color = switch color {
            case .inTune: .green
            case .close: .yellow
            case .outOfTune: .red
            }
            context.fill(Path(ellipseIn: indicatorRect), with: .color(indicatorColor))
        }
    }
}

import SwiftUI

struct SPLChartView: View {
    let splHistory: [Double]
    let historySeconds: Int
    let safeThreshold: Double
    let cautionThreshold: Double

    private let yMin: Double = AudioConstants.splMin
    private let yMax: Double = AudioConstants.splMax
    private let gridStep: Double = 10 // dB per grid line
    private let labelWidth: CGFloat = 40

    var body: some View {
        Canvas { context, size in
            let chartLeft = labelWidth
            let chartWidth = size.width - chartLeft
            let chartHeight = size.height

            drawGrid(context: &context, chartLeft: chartLeft, chartWidth: chartWidth, chartHeight: chartHeight)
            drawLine(context: &context, chartLeft: chartLeft, chartWidth: chartWidth, chartHeight: chartHeight)
        }
        .padding(.trailing, 8)
    }

    // MARK: - Grid

    private func drawGrid(context: inout GraphicsContext, chartLeft: CGFloat, chartWidth: CGFloat, chartHeight: CGFloat) {
        let gridColor = Color.gray.opacity(0.3)
        let labelColor = Color.gray

        var db = yMin
        while db <= yMax {
            let y = yPosition(for: db, height: chartHeight)
            // Horizontal grid line
            var path = Path()
            path.move(to: CGPoint(x: chartLeft, y: y))
            path.addLine(to: CGPoint(x: chartLeft + chartWidth, y: y))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)

            // Y-axis label
            let text = Text("\(Int(db))").font(.caption2).foregroundColor(labelColor)
            context.draw(text, at: CGPoint(x: chartLeft - 6, y: y), anchor: .trailing)

            db += gridStep
        }
    }

    // MARK: - SPL Line

    private func drawLine(context: inout GraphicsContext, chartLeft: CGFloat, chartWidth: CGFloat, chartHeight: CGFloat) {
        guard splHistory.count >= 2 else { return }

        let totalSamples = historySeconds * Int(AudioConstants.updateRate)
        let pointCount = splHistory.count

        for i in 0..<(pointCount - 1) {
            let x1 = chartLeft + chartWidth * CGFloat(i) / CGFloat(totalSamples - 1)
            let x2 = chartLeft + chartWidth * CGFloat(i + 1) / CGFloat(totalSamples - 1)
            let y1 = yPosition(for: splHistory[i], height: chartHeight)
            let y2 = yPosition(for: splHistory[i + 1], height: chartHeight)

            var segment = Path()
            segment.move(to: CGPoint(x: x1, y: y1))
            segment.addLine(to: CGPoint(x: x2, y: y2))

            let midSPL = (splHistory[i] + splHistory[i + 1]) / 2
            let color = splColor(for: midSPL)
            context.stroke(segment, with: .color(color), lineWidth: 2)
        }
    }

    // MARK: - Helpers

    private func yPosition(for db: Double, height: CGFloat) -> CGFloat {
        let clamped = min(max(db, yMin), yMax)
        let fraction = (clamped - yMin) / (yMax - yMin)
        return height * (1 - fraction)
    }

    private func splColor(for db: Double) -> Color {
        if db >= cautionThreshold {
            return .red
        } else if db >= safeThreshold {
            return .yellow
        } else {
            return .green
        }
    }
}

import SwiftUI

struct SPLChartView: View {
    let splHistory: RingBuffer<Double>
    let historySeconds: Int
    let safeThreshold: Double
    let cautionThreshold: Double
    let settings: AppSettings

    private let niceSteps: [Double] = [1, 2, 5, 10, 20, 50]
    private let targetGridLines = 11
    private let labelWidth: CGFloat = 40

    // Gesture state for drag panning
    @State private var dragStartMin: Double = 0
    @State private var dragStartMax: Double = 0

    // Gesture state for pinch zooming
    @State private var pinchStartMin: Double = 0
    @State private var pinchStartMax: Double = 0

    private var yMin: Double { settings.splDisplayMin }
    private var yMax: Double { settings.splDisplayMax }

    var body: some View {
        GeometryReader { geometry in
            let h = geometry.size.height
            let dbRange = yMax - yMin

            Canvas { context, size in
                let chartLeft = labelWidth
                let chartWidth = size.width - chartLeft
                let chartHeight = size.height

                drawGrid(context: &context, chartLeft: chartLeft, chartWidth: chartWidth, chartHeight: chartHeight)
                drawLine(context: &context, chartLeft: chartLeft, chartWidth: chartWidth, chartHeight: chartHeight)
            }
            .clipped()
            .padding(.trailing, 8)
            .gesture(dragGesture(chartHeight: h, dbRange: dbRange))
            .gesture(pinchGesture(chartHeight: h))
        }
    }

    // MARK: - Drag to Pan

    private func dragGesture(chartHeight: CGFloat, dbRange: Double) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                if dragStartMin == 0 && dragStartMax == 0 {
                    dragStartMin = settings.splDisplayMin
                    dragStartMax = settings.splDisplayMax
                }

                // Dragging up (negative y) should increase dB (shift range up)
                let dbPerPixel = dbRange / Double(chartHeight)
                let dbShift = value.translation.height * dbPerPixel

                let range = dragStartMax - dragStartMin
                var newMin = dragStartMin + dbShift
                var newMax = dragStartMax + dbShift

                // Clamp to absolute bounds while preserving range size
                if newMin < AppSettings.splAbsMin {
                    newMin = AppSettings.splAbsMin
                    newMax = newMin + range
                }
                if newMax > AppSettings.splAbsMax {
                    newMax = AppSettings.splAbsMax
                    newMin = newMax - range
                }

                settings.splDisplayMin = newMin
                settings.splDisplayMax = newMax
            }
            .onEnded { _ in
                dragStartMin = 0
                dragStartMax = 0
            }
    }

    // MARK: - Pinch to Zoom

    private func pinchGesture(chartHeight: CGFloat) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if pinchStartMin == 0 && pinchStartMax == 0 {
                    pinchStartMin = settings.splDisplayMin
                    pinchStartMax = settings.splDisplayMax
                }

                let startRange = pinchStartMax - pinchStartMin
                let center = (pinchStartMin + pinchStartMax) / 2.0

                // Pinch out (scale > 1) narrows the range (zoom in), pinch in widens
                let newRange = startRange / value.magnification
                let clampedRange = min(max(newRange, AppSettings.splRangeMin), AppSettings.splRangeMax)

                var newMin = center - clampedRange / 2.0
                var newMax = center + clampedRange / 2.0

                if newMin < AppSettings.splAbsMin {
                    newMin = AppSettings.splAbsMin
                    newMax = newMin + clampedRange
                }
                if newMax > AppSettings.splAbsMax {
                    newMax = AppSettings.splAbsMax
                    newMin = newMax - clampedRange
                }

                settings.splDisplayMin = newMin
                settings.splDisplayMax = newMax
            }
            .onEnded { _ in
                pinchStartMin = 0
                pinchStartMax = 0
            }
    }

    // MARK: - Grid

    private func drawGrid(context: inout GraphicsContext, chartLeft: CGFloat, chartWidth: CGFloat, chartHeight: CGFloat) {
        let gridColor = Color.gray.opacity(0.3)
        let labelColor = Color.gray

        let range = yMax - yMin
        let rawStep = range / Double(targetGridLines)
        let gridStep = niceSteps.first { $0 >= rawStep } ?? niceSteps.last!

        var db = (yMin / gridStep).rounded(.up) * gridStep
        while db <= yMax {
            let y = yPosition(for: db, height: chartHeight)
            // Horizontal grid line
            var path = Path()
            path.move(to: CGPoint(x: chartLeft, y: y))
            path.addLine(to: CGPoint(x: chartLeft + chartWidth, y: y))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)

            // Y-axis label
            let text = Text("\(Int(db))").font(.footnote).foregroundColor(labelColor)
            let anchor: UnitPoint = db == yMax ? .topTrailing : (db == yMin ? .bottomTrailing : .trailing)
            context.draw(text, at: CGPoint(x: chartLeft - 6, y: y), anchor: anchor)

            db += gridStep
        }
    }

    // MARK: - SPL Line

    private func drawLine(context: inout GraphicsContext, chartLeft: CGFloat, chartWidth: CGFloat, chartHeight: CGFloat) {
        let pointCount = splHistory.count
        guard pointCount >= 2 else { return }

        let totalSamples = historySeconds * Int(AudioConstants.updateRate)
        let xScale = chartWidth / CGFloat(totalSamples - 1)

        // Batch consecutive segments of the same color into a single path
        var currentPath = Path()
        var currentColor = splColor(for: splHistory[0])
        var prevX = chartLeft
        var prevY = yPosition(for: splHistory[0], height: chartHeight)

        for i in 1..<pointCount {
            let x = chartLeft + xScale * CGFloat(i)
            let y = yPosition(for: splHistory[i], height: chartHeight)

            let midSPL = (splHistory[i - 1] + splHistory[i]) / 2
            let color = splColor(for: midSPL)

            if color != currentColor {
                // Flush the current batch
                context.stroke(currentPath, with: .color(currentColor), lineWidth: 3)
                currentPath = Path()
                currentPath.move(to: CGPoint(x: prevX, y: prevY))
                currentColor = color
            } else if currentPath.isEmpty {
                currentPath.move(to: CGPoint(x: prevX, y: prevY))
            }

            currentPath.addLine(to: CGPoint(x: x, y: y))
            prevX = x
            prevY = y
        }

        // Flush remaining
        if !currentPath.isEmpty {
            context.stroke(currentPath, with: .color(currentColor), lineWidth: 3)
        }
    }

    // MARK: - Helpers

    private func yPosition(for db: Double, height: CGFloat) -> CGFloat {
        let fraction = (db - yMin) / (yMax - yMin)
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

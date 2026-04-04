import SwiftUI

struct SpectrogramView: View {
    let columns: [[Float]]
    let freqMin: Int
    let freqMax: Int

    private let labelWidth: CGFloat = 40
    private let colorLUT = ColorLUT.shared

    /// Frequency labels to display (only those within range).
    private static let freqLabels: [(hz: Int, text: String)] = [
        (100, "100"), (200, "200"), (500, "500"),
        (1000, "1k"), (2000, "2k"), (4000, "4k"), (8000, "8k")
    ]

    var body: some View {
        Canvas { context, size in
            let chartLeft = labelWidth
            let chartWidth = size.width - chartLeft
            let chartHeight = size.height

            guard chartWidth > 0, chartHeight > 0, !columns.isEmpty else { return }

            let displayHeight = Int(chartHeight)
            let rowMapping = buildRowMapping(displayHeight: displayHeight)

            drawSpectrogram(
                context: &context,
                columns: columns,
                rowMapping: rowMapping,
                chartLeft: chartLeft,
                chartWidth: chartWidth,
                chartHeight: chartHeight,
                displayHeight: displayHeight
            )

            drawFrequencyLabels(
                context: &context,
                chartLeft: chartLeft,
                chartHeight: chartHeight,
                displayHeight: displayHeight
            )
        }
    }

    // MARK: - Log-frequency row mapping

    /// For each display row, return the FFT bin index to read from.
    private func buildRowMapping(displayHeight: Int) -> [Int] {
        guard displayHeight > 0 else { return [] }

        let logMin = log10(Double(max(freqMin, 1)))
        let logMax = log10(Double(max(freqMax, 2)))
        let binHz = AudioConstants.fftBinHz

        var mapping = [Int](repeating: 0, count: displayHeight)
        for row in 0..<displayHeight {
            // row 0 = top = high freq, row H-1 = bottom = low freq
            let logFreq = logMax - Double(row) * (logMax - logMin) / Double(displayHeight - 1)
            let freq = pow(10.0, logFreq)
            let bin = Int(round(freq / binHz))
            mapping[row] = max(0, bin)
        }
        return mapping
    }

    // MARK: - Drawing

    private func drawSpectrogram(
        context: inout GraphicsContext,
        columns: [[Float]],
        rowMapping: [Int],
        chartLeft: CGFloat,
        chartWidth: CGFloat,
        chartHeight: CGFloat,
        displayHeight: Int
    ) {
        let colCount = columns.count
        let colWidth = max(chartWidth / CGFloat(colCount), 1)
        let rowHeight = chartHeight / CGFloat(displayHeight)

        for (colIdx, spectrum) in columns.enumerated() {
            let x = chartLeft + CGFloat(colIdx) * colWidth

            for row in 0..<displayHeight {
                let binIdx = rowMapping[row]
                let dB: Float = binIdx < spectrum.count ? spectrum[binIdx] : ColorLUT.dbMin
                let entry = colorLUT.entries[colorLUT.index(for: dB)]

                let rect = CGRect(
                    x: x,
                    y: CGFloat(row) * rowHeight,
                    width: ceil(colWidth),
                    height: ceil(rowHeight)
                )

                context.fill(
                    Path(rect),
                    with: .color(Color(
                        red: Double(entry.r) / 255,
                        green: Double(entry.g) / 255,
                        blue: Double(entry.b) / 255
                    ))
                )
            }
        }
    }

    private func drawFrequencyLabels(
        context: inout GraphicsContext,
        chartLeft: CGFloat,
        chartHeight: CGFloat,
        displayHeight: Int
    ) {
        guard displayHeight > 1 else { return }

        let logMin = log10(Double(max(freqMin, 1)))
        let logMax = log10(Double(max(freqMax, 2)))
        let labelColor = Color.gray

        for (hz, text) in Self.freqLabels {
            guard hz >= freqMin, hz <= freqMax else { continue }

            let logFreq = log10(Double(hz))
            let fraction = (logMax - logFreq) / (logMax - logMin)
            let y = chartHeight * fraction

            // Tick line
            var path = Path()
            path.move(to: CGPoint(x: chartLeft - 4, y: y))
            path.addLine(to: CGPoint(x: chartLeft, y: y))
            context.stroke(path, with: .color(labelColor.opacity(0.5)), lineWidth: 0.5)

            // Label
            let label = Text(text).font(.caption2).foregroundColor(labelColor)
            context.draw(label, at: CGPoint(x: chartLeft - 6, y: y), anchor: .trailing)
        }
    }
}

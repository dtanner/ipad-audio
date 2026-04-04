import SwiftUI

struct PitchChartView: View {
    let pitchHistory: [Double?]
    let historySeconds: Int
    let pitchRangeAuto: Bool
    let pitchNoteMin: Int
    let pitchNoteMax: Int

    private let allNoteNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    private let naturalSemitones: Set<Int> = [0, 2, 4, 5, 7, 9, 11]

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Determine Y range in semitones (relative to A4)
            let (semiMin, semiMax) = computeRange()
            let semiRange = Double(semiMax - semiMin)
            guard semiRange > 0 else { return }

            let labelWidth: CGFloat = 36
            let chartX = labelWidth
            let chartW = w - labelWidth

            // Draw grid lines and labels
            drawGrid(context: context, size: size, semiMin: semiMin, semiMax: semiMax,
                     labelWidth: labelWidth, chartW: chartW, h: h)

            // Draw pitch trace
            let count = pitchHistory.count
            guard count > 0 else { return }

            var prevPoint: CGPoint? = nil
            let dotRadius: CGFloat = 2.5

            for i in 0..<count {
                let x = chartX + CGFloat(i) / CGFloat(max(count - 1, 1)) * chartW

                guard let hz = pitchHistory[i] else {
                    prevPoint = nil
                    continue
                }

                let semi = PitchNote.freqToSemitone(hz)
                let yFrac = (semi - Double(semiMin)) / semiRange
                let y = h - CGFloat(yFrac) * h // invert: high pitch at top

                let point = CGPoint(x: x, y: y)

                if let prev = prevPoint {
                    // Connected line
                    var path = Path()
                    path.move(to: prev)
                    path.addLine(to: point)
                    context.stroke(path, with: .color(.cyan), lineWidth: 2)
                } else {
                    // Isolated dot
                    let dotRect = CGRect(x: point.x - dotRadius, y: point.y - dotRadius,
                                         width: dotRadius * 2, height: dotRadius * 2)
                    context.fill(Path(ellipseIn: dotRect), with: .color(.cyan))
                }
                prevPoint = point
            }
        }
    }

    private func computeRange() -> (Int, Int) {
        if !pitchRangeAuto {
            return (pitchNoteMin, pitchNoteMax)
        }

        // Auto range: median ± 12 semitones
        let semitones = pitchHistory.compactMap { hz -> Double? in
            guard let hz else { return nil }
            return PitchNote.freqToSemitone(hz)
        }

        guard !semitones.isEmpty else {
            return (pitchNoteMin, pitchNoteMax)
        }

        let sorted = semitones.sorted()
        let median = sorted[sorted.count / 2]
        let medianInt = Int(median.rounded())
        return (medianInt - 12, medianInt + 12)
    }

    private func drawGrid(context: GraphicsContext, size: CGSize, semiMin: Int, semiMax: Int,
                           labelWidth: CGFloat, chartW: CGFloat, h: CGFloat) {
        let semiRange = Double(semiMax - semiMin)
        let a4Midi = 69

        for semi in semiMin...semiMax {
            let midi = a4Midi + semi
            let noteInOctave = ((midi % 12) + 12) % 12

            let yFrac = (Double(semi) - Double(semiMin)) / semiRange
            let y = h - CGFloat(yFrac) * h

            let isC = noteInOctave == 0
            let isNatural = naturalSemitones.contains(noteInOctave)
            let lineOpacity: Double = isC ? 0.6 : (isNatural ? 0.35 : 0.2)
            let lineWidth: CGFloat = isC ? 1 : 0.5

            var path = Path()
            path.move(to: CGPoint(x: labelWidth, y: y))
            path.addLine(to: CGPoint(x: labelWidth + chartW, y: y))
            context.stroke(path, with: .color(.gray.opacity(lineOpacity)), lineWidth: lineWidth)

            // Label every semitone
            let octave = midi / 12 - 1
            let name = allNoteNames[noteInOctave]
            let label = isC ? "\(name)\(octave)" : name
            let labelColor: Color = isC ? .gray : .gray.opacity(isNatural ? 0.7 : 0.5)
            let text = Text(label).font(.caption2).foregroundColor(labelColor)
            context.draw(text, at: CGPoint(x: labelWidth - 4, y: y), anchor: .trailing)
        }
    }
}

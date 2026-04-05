import SwiftUI

struct PitchChartView: View {
    let pitchHistory: [Double?]
    let historySeconds: Int
    let settings: AppSettings

    // Gesture state for drag panning
    @State private var dragStartMin: Int = 0
    @State private var dragStartMax: Int = 0

    // Gesture state for pinch zooming
    @State private var pinchStartMin: Int = 0
    @State private var pinchStartMax: Int = 0

    private let allNoteNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    private let naturalSemitones: Set<Int> = [0, 2, 4, 5, 7, 9, 11]

    var body: some View {
        GeometryReader { geometry in
            let h = geometry.size.height
            let semiRange = settings.pitchNoteMax - settings.pitchNoteMin

            Canvas { context, size in
                let w = size.width
                let h = size.height
                let semiMin = settings.pitchNoteMin
                let semiMax = settings.pitchNoteMax
                let semiRange = Double(semiMax - semiMin)
                guard semiRange > 0 else { return }

                let labelWidth: CGFloat = 36
                let chartX = labelWidth
                let chartW = w - labelWidth

                drawGrid(context: context, size: size, semiMin: semiMin, semiMax: semiMax,
                         labelWidth: labelWidth, chartW: chartW, h: h)

                let count = pitchHistory.count
                guard count > 0 else { return }

                var prevPoint: CGPoint? = nil
                var prevSemi: Double? = nil
                let dotRadius: CGFloat = 2.5
                let maxSemitoneJump: Double = 12.0

                for i in 0..<count {
                    let x = chartX + CGFloat(i) / CGFloat(max(count - 1, 1)) * chartW

                    guard let hz = pitchHistory[i] else {
                        prevPoint = nil
                        prevSemi = nil
                        continue
                    }

                    let semi = PitchNote.freqToSemitone(hz)
                    let yFrac = (semi - Double(semiMin)) / semiRange
                    let y = h - CGFloat(yFrac) * h

                    let point = CGPoint(x: x, y: y)

                    if let prev = prevPoint, let pSemi = prevSemi,
                       abs(semi - pSemi) <= maxSemitoneJump {
                        var path = Path()
                        path.move(to: prev)
                        path.addLine(to: point)
                        context.stroke(path, with: .color(.cyan), lineWidth: 2)
                    } else {
                        let dotRect = CGRect(x: point.x - dotRadius, y: point.y - dotRadius,
                                             width: dotRadius * 2, height: dotRadius * 2)
                        context.fill(Path(ellipseIn: dotRect), with: .color(.cyan))
                    }
                    prevPoint = point
                    prevSemi = semi
                }
            }
            .gesture(dragGesture(chartHeight: h, semiRange: semiRange))
            .gesture(pinchGesture(chartHeight: h))
        }
    }

    // MARK: - Drag to Pan

    private func dragGesture(chartHeight: CGFloat, semiRange: Int) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                if dragStartMin == 0 && dragStartMax == 0 {
                    dragStartMin = settings.pitchNoteMin
                    dragStartMax = settings.pitchNoteMax
                }

                // Dragging up (negative y) should increase pitch (shift range up)
                let semiPerPixel = Double(semiRange) / Double(chartHeight)
                let semiShift = Int((value.translation.height * semiPerPixel).rounded())

                let range = dragStartMax - dragStartMin
                var newMin = dragStartMin + semiShift
                var newMax = dragStartMax + semiShift

                // Clamp to absolute bounds while preserving range size
                if newMin < AppSettings.pitchNoteAbsMin {
                    newMin = AppSettings.pitchNoteAbsMin
                    newMax = newMin + range
                }
                if newMax > AppSettings.pitchNoteAbsMax {
                    newMax = AppSettings.pitchNoteAbsMax
                    newMin = newMax - range
                }

                settings.pitchNoteMin = newMin
                settings.pitchNoteMax = newMax
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
                    pinchStartMin = settings.pitchNoteMin
                    pinchStartMax = settings.pitchNoteMax
                }

                let startRange = pinchStartMax - pinchStartMin
                let center = Double(pinchStartMin + pinchStartMax) / 2.0

                // Pinch out (scale > 1) narrows the range (zoom in), pinch in widens
                let newRange = Double(startRange) / value.magnification
                let clampedRange = Int(newRange.rounded()).clamped(
                    to: AppSettings.pitchRangeMin...AppSettings.pitchRangeMax
                )

                var newMin = Int((center - Double(clampedRange) / 2.0).rounded())
                var newMax = newMin + clampedRange

                if newMin < AppSettings.pitchNoteAbsMin {
                    newMin = AppSettings.pitchNoteAbsMin
                    newMax = newMin + clampedRange
                }
                if newMax > AppSettings.pitchNoteAbsMax {
                    newMax = AppSettings.pitchNoteAbsMax
                    newMin = newMax - clampedRange
                }

                settings.pitchNoteMin = newMin
                settings.pitchNoteMax = newMax
            }
            .onEnded { _ in
                pinchStartMin = 0
                pinchStartMax = 0
            }
    }

    // MARK: - Grid Drawing

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

            let octave = midi / 12 - 1
            let name = allNoteNames[noteInOctave]
            let label = isC ? "\(name)\(octave)" : name
            let labelColor: Color = isC ? .gray : .gray.opacity(isNatural ? 0.7 : 0.5)
            let text = Text(label).font(.caption2).foregroundColor(labelColor)
            context.draw(text, at: CGPoint(x: labelWidth - 4, y: y), anchor: .trailing)
        }
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

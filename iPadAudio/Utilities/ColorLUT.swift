import SwiftUI

/// 256-entry color lookup table for spectrogram rendering.
/// Maps normalized dB values to colors: dark → deep blue → blue → cyan → yellow → red.
struct ColorLUT {
    struct RGB {
        let r: UInt8
        let g: UInt8
        let b: UInt8
    }

    static let shared = ColorLUT()

    let entries: [RGB]

    /// dB range for mapping
    static let dbMin: Float = -80
    static let dbMax: Float = 0

    private init() {
        // Control points: (index, r, g, b)
        let controlPoints: [(Int, UInt8, UInt8, UInt8)] = [
            (0,     5,   5,  15),   // dark background
            (20,   10,  10,  50),   // deep blue (noise floor)
            (60,   20,  40, 180),   // blue
            (120,   0, 200, 220),   // cyan (mid-range)
            (180, 240, 220,   0),   // yellow (signal)
            (255, 255,  60,  20),   // red (loud)
        ]

        var table = [RGB](repeating: RGB(r: 0, g: 0, b: 0), count: 256)

        for seg in 0..<(controlPoints.count - 1) {
            let (i0, r0, g0, b0) = controlPoints[seg]
            let (i1, r1, g1, b1) = controlPoints[seg + 1]
            let span = i1 - i0
            for i in i0...i1 {
                let t = Float(i - i0) / Float(span)
                let rVal = Float(r0) + t * (Float(r1) - Float(r0))
                let gVal = Float(g0) + t * (Float(g1) - Float(g0))
                let bVal = Float(b0) + t * (Float(b1) - Float(b0))
                table[i] = RGB(
                    r: UInt8(rVal + 0.5),
                    g: UInt8(gVal + 0.5),
                    b: UInt8(bVal + 0.5)
                )
            }
        }

        self.entries = table
    }

    /// Map a dB value to a LUT index (0-255).
    func index(for dB: Float) -> Int {
        let clamped = min(max(dB, ColorLUT.dbMin), ColorLUT.dbMax)
        let normalized = (clamped - ColorLUT.dbMin) / (ColorLUT.dbMax - ColorLUT.dbMin)
        return Int(normalized * 255)
    }

    /// Map a dB value directly to a Color.
    func color(for dB: Float) -> Color {
        let entry = entries[index(for: dB)]
        return Color(red: Double(entry.r) / 255, green: Double(entry.g) / 255, blue: Double(entry.b) / 255)
    }
}

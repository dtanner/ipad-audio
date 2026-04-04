import Foundation

enum PanelType: String, CaseIterable, Identifiable {
    case overtones
    case meter
    case pitch

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overtones: "Overtones"
        case .meter: "Meter"
        case .pitch: "Pitch"
        }
    }

    var iconName: String {
        switch self {
        case .overtones: "waveform"
        case .meter: "gauge.with.needle"
        case .pitch: "music.note"
        }
    }
}

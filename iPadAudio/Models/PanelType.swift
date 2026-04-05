import Foundation

enum PanelType: String, CaseIterable, Identifiable {
    case meter
    case pitch

    var id: String { rawValue }

    var label: String {
        switch self {
        case .meter: "Meter"
        case .pitch: "Pitch"
        }
    }

    var iconName: String {
        switch self {
        case .meter: "gauge.with.needle"
        case .pitch: "music.note"
        }
    }
}

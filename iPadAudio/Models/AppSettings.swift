import SwiftUI

@Observable
final class AppSettings {
    // MARK: - History

    var historySeconds: Int {
        get { access(keyPath: \.historySeconds); return _historySeconds }
        set { withMutation(keyPath: \.historySeconds) { _historySeconds = newValue.clamped(to: 5...300) } }
    }
    @ObservationIgnored @AppStorage("historySeconds") private var _historySeconds = 30

    // MARK: - SPL Thresholds

    var safeThreshold: Double {
        get { access(keyPath: \.safeThreshold); return _safeThreshold }
        set { withMutation(keyPath: \.safeThreshold) {
            _safeThreshold = min(newValue.clamped(to: 40...95), _cautionThreshold - 1)
        }}
    }
    @ObservationIgnored @AppStorage("safeThreshold") private var _safeThreshold = 55.0

    var cautionThreshold: Double {
        get { access(keyPath: \.cautionThreshold); return _cautionThreshold }
        set { withMutation(keyPath: \.cautionThreshold) {
            _cautionThreshold = max(newValue.clamped(to: 60...100), _safeThreshold + 1)
        }}
    }
    @ObservationIgnored @AppStorage("cautionThreshold") private var _cautionThreshold = 75.0

    // MARK: - Pitch Note Range

    var pitchNoteMin: Int {
        get { access(keyPath: \.pitchNoteMin); return _pitchNoteMin }
        set { withMutation(keyPath: \.pitchNoteMin) {
            _pitchNoteMin = min(newValue.clamped(to: -39...38), _pitchNoteMax - 1)
        }}
    }
    @ObservationIgnored @AppStorage("pitchNoteMin") private var _pitchNoteMin = -27 // E2

    var pitchNoteMax: Int {
        get { access(keyPath: \.pitchNoteMax); return _pitchNoteMax }
        set { withMutation(keyPath: \.pitchNoteMax) {
            _pitchNoteMax = max(newValue.clamped(to: -38...39), _pitchNoteMin + 1)
        }}
    }
    @ObservationIgnored @AppStorage("pitchNoteMax") private var _pitchNoteMax = 10 // G5

    var pitchRangeAuto: Bool {
        get { access(keyPath: \.pitchRangeAuto); return _pitchRangeAuto }
        set { withMutation(keyPath: \.pitchRangeAuto) { _pitchRangeAuto = newValue } }
    }
    @ObservationIgnored @AppStorage("pitchRangeAuto") private var _pitchRangeAuto = true

    // MARK: - Active Panels

    var activePanels: [PanelType] {
        get {
            access(keyPath: \.activePanels)
            let raw = _activePanelsRaw
            let types = raw.split(separator: ",").compactMap { PanelType(rawValue: String($0)) }
            return types.isEmpty && raw.isEmpty ? [.meter, .pitch] : types
        }
        set {
            withMutation(keyPath: \.activePanels) {
                let clamped = Array(newValue.prefix(2))
                _activePanelsRaw = clamped.map(\.rawValue).joined(separator: ",")
            }
        }
    }
    @ObservationIgnored @AppStorage("activePanels") private var _activePanelsRaw = "meter,pitch"
}

// MARK: - Helpers

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

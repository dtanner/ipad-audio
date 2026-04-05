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
    // Semitone offsets from A4: A0 = -48, C8 = 39
    // Range constrained to 12–60 semitones (1–5 octaves)

    static let pitchNoteAbsMin = -48 // A0
    static let pitchNoteAbsMax = 39  // C8
    static let pitchRangeMin = 12    // 1 octave
    static let pitchRangeMax = 60    // 5 octaves

    var pitchNoteMin: Int {
        get { access(keyPath: \.pitchNoteMin); return _pitchNoteMin }
        set { withMutation(keyPath: \.pitchNoteMin) {
            let clamped = newValue.clamped(to: Self.pitchNoteAbsMin...(Self.pitchNoteAbsMax - Self.pitchRangeMin))
            _pitchNoteMin = min(clamped, _pitchNoteMax - Self.pitchRangeMin)
        }}
    }
    @ObservationIgnored @AppStorage("pitchNoteMin") private var _pitchNoteMin = -27 // E2

    var pitchNoteMax: Int {
        get { access(keyPath: \.pitchNoteMax); return _pitchNoteMax }
        set { withMutation(keyPath: \.pitchNoteMax) {
            let clamped = newValue.clamped(to: (Self.pitchNoteAbsMin + Self.pitchRangeMin)...Self.pitchNoteAbsMax)
            _pitchNoteMax = max(clamped, _pitchNoteMin + Self.pitchRangeMin)
        }}
    }
    @ObservationIgnored @AppStorage("pitchNoteMax") private var _pitchNoteMax = 10 // G5

    // MARK: - Key (Root + Scale)

    var rootNote: MusicRoot {
        get { access(keyPath: \.rootNote); return MusicRoot(rawValue: _rootNoteRaw) ?? .c }
        set { withMutation(keyPath: \.rootNote) { _rootNoteRaw = newValue.rawValue } }
    }
    @ObservationIgnored @AppStorage("rootNote") private var _rootNoteRaw = "C"

    var scaleType: MusicScale {
        get { access(keyPath: \.scaleType); return MusicScale(rawValue: _scaleTypeRaw) ?? .major }
        set { withMutation(keyPath: \.scaleType) { _scaleTypeRaw = newValue.rawValue } }
    }
    @ObservationIgnored @AppStorage("scaleType") private var _scaleTypeRaw = "Major"

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

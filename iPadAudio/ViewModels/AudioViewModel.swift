import Foundation
import AVFoundation

@Observable
final class AudioViewModel {
    var currentSPL: Double = AudioConstants.splMin
    var splHistory: RingBuffer<Double>
    var currentPitch: Double?
    var pitchHistory: RingBuffer<Double?>
    var isRunning = false
    var micPermissionDenied = false
    var isFrozen = false

    let settings = AppSettings()
    let tuner = TunerViewModel()

    private let engine = AudioEngine()

    init() {
        let capacity = settings.historySeconds * Int(AudioConstants.updateRate)
        splHistory = RingBuffer(capacity: capacity, defaultValue: AudioConstants.splMin)
        pitchHistory = RingBuffer<Double?>(capacity: capacity, defaultValue: nil)

        engine.onSPL = { [weak self] spl in
            guard let self else { return }
            self.currentSPL = spl
            if !self.isFrozen {
                self.splHistory.push(spl)
            }
        }

        engine.onPitch = { [weak self] pitch in
            guard let self else { return }
            self.currentPitch = pitch
            self.tuner.update(pitch: pitch)
            if !self.isFrozen {
                self.pitchHistory.push(pitch)
            }
        }
    }

    /// Resize the history buffers when the user changes history length.
    func updateHistoryCapacity() {
        let newCapacity = settings.historySeconds * Int(AudioConstants.updateRate)
        guard newCapacity != splHistory.capacity else { return }

        // Copy existing SPL data into new buffer
        let existing = splHistory.array
        var newBuffer = RingBuffer<Double>(capacity: newCapacity, defaultValue: AudioConstants.splMin)
        let start = max(0, existing.count - newCapacity)
        for i in start..<existing.count {
            newBuffer.push(existing[i])
        }
        splHistory = newBuffer

        // Copy existing pitch data into new buffer
        let existingPitch = pitchHistory.array
        var newPitchBuffer = RingBuffer<Double?>(capacity: newCapacity, defaultValue: nil)
        let pitchStart = max(0, existingPitch.count - newCapacity)
        for i in pitchStart..<existingPitch.count {
            newPitchBuffer.push(existingPitch[i])
        }
        pitchHistory = newPitchBuffer
    }

    func requestMicAndStart() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            startEngine()
        case .denied:
            micPermissionDenied = true
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startEngine()
                    } else {
                        self?.micPermissionDenied = true
                    }
                }
            }
        @unknown default:
            break
        }
    }

    func stopEngine() {
        engine.stop()
        isRunning = false
    }

    private func startEngine() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement)
            try session.setPreferredSampleRate(AudioConstants.sampleRate)
            try session.setActive(true)
            try engine.start()
            isRunning = true
        } catch {
            print("AudioEngine start failed: \(error)")
        }
    }
}

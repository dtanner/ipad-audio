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

    let settings = AppSettings()
    let tuner = TunerViewModel()

    private let engine = AudioEngine()

    init() {
        let splCapacity = settings.historySeconds * Int(AudioConstants.updateRate)
        let pitchCapacity = settings.historySeconds * Int(AudioConstants.pitchUpdateRate)
        splHistory = RingBuffer(capacity: splCapacity, defaultValue: AudioConstants.splMin)
        pitchHistory = RingBuffer<Double?>(capacity: pitchCapacity, defaultValue: nil)

        engine.onSPL = { [weak self] spl in
            guard let self else { return }
            self.currentSPL = spl
            self.splHistory.push(spl)
        }

        engine.onPitch = { [weak self] pitch in
            guard let self else { return }
            self.currentPitch = pitch
            self.tuner.update(pitch: pitch)
            self.pitchHistory.push(pitch)
        }
    }

    /// Resize the history buffers when the user changes history length.
    func updateHistoryCapacity() {
        let newSplCapacity = settings.historySeconds * Int(AudioConstants.updateRate)
        let newPitchCapacity = settings.historySeconds * Int(AudioConstants.pitchUpdateRate)
        guard newSplCapacity != splHistory.capacity || newPitchCapacity != pitchHistory.capacity else { return }

        // Copy existing SPL data into new buffer
        let existing = splHistory.array
        var newBuffer = RingBuffer<Double>(capacity: newSplCapacity, defaultValue: AudioConstants.splMin)
        let start = max(0, existing.count - newSplCapacity)
        for i in start..<existing.count {
            newBuffer.push(existing[i])
        }
        splHistory = newBuffer

        // Copy existing pitch data into new buffer
        let existingPitch = pitchHistory.array
        var newPitchBuffer = RingBuffer<Double?>(capacity: newPitchCapacity, defaultValue: nil)
        let pitchStart = max(0, existingPitch.count - newPitchCapacity)
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

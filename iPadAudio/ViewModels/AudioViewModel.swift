import Foundation
import AVFoundation

@Observable
final class AudioViewModel {
    var currentSPL: Double = AudioConstants.splMin
    var splHistory: RingBuffer<Double>
    var spectrogramColumns: RingBuffer<[Float]>
    var isRunning = false
    var micPermissionDenied = false

    let settings = AppSettings()

    private let engine = AudioEngine()

    init() {
        let capacity = settings.historySeconds * Int(AudioConstants.updateRate)
        splHistory = RingBuffer(capacity: capacity, defaultValue: AudioConstants.splMin)
        spectrogramColumns = RingBuffer(capacity: capacity, defaultValue: [Float]())

        engine.onSPL = { [weak self] spl in
            self?.currentSPL = spl
            self?.splHistory.push(spl)
        }

        engine.onSpectrum = { [weak self] spectrum in
            self?.spectrogramColumns.push(spectrum)
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

        // Copy existing spectrogram data into new buffer
        let existingCols = spectrogramColumns.array
        var newColBuffer = RingBuffer<[Float]>(capacity: newCapacity, defaultValue: [Float]())
        let colStart = max(0, existingCols.count - newCapacity)
        for i in colStart..<existingCols.count {
            newColBuffer.push(existingCols[i])
        }
        spectrogramColumns = newColBuffer
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

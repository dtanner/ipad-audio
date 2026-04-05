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

    /// Non-nil when audio is interrupted or the mic route is lost.
    var audioInterruptionMessage: String?

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

        observeAudioNotifications()
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

    /// Resume audio after an interruption or route change.
    func resumeAudio() {
        audioInterruptionMessage = nil
        startEngine()
    }

    /// Stop engine when app enters background.
    func handleBackground() {
        guard isRunning else { return }
        stopEngine()
    }

    /// Restart engine when app returns to foreground.
    func handleForeground() {
        guard !isRunning, !micPermissionDenied, audioInterruptionMessage == nil else { return }
        startEngine()
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

    // MARK: - Audio Notifications

    private func observeAudioNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch type {
            case .began:
                self.stopEngine()
                self.audioInterruptionMessage = "Audio Interrupted"
            case .ended:
                let options = (info[AVAudioSessionInterruptionOptionKey] as? UInt)
                    .flatMap { AVAudioSession.InterruptionOptions(rawValue: $0) }
                if options?.contains(.shouldResume) == true {
                    self.resumeAudio()
                }
            @unknown default:
                break
            }
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch reason {
            case .oldDeviceUnavailable:
                self.stopEngine()
                self.audioInterruptionMessage = "Microphone Disconnected"
            case .newDeviceAvailable:
                if self.audioInterruptionMessage != nil {
                    self.resumeAudio()
                }
            default:
                break
            }
        }
    }
}

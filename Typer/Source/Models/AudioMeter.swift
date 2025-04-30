import AVFoundation

class AudioMeter: ObservableObject {
    @Published var soundSamples: [CGFloat] = Array(repeating: .zero, count: 10)
    private var timer: Timer?

    func startMonitoring(_ recorder: AVAudioRecorder) {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recorder.updateMeters()
            let level = min(max(CGFloat(recorder.averagePower(forChannel: 0)) + 50, 0) / 50, 1)
            self.soundSamples.removeFirst()
            self.soundSamples.append(level)
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        soundSamples = Array(repeating: .zero, count: 10)
    }
}

import Foundation
import AVFoundation

@MainActor
final class AudioRecorder: ObservableObject {
    @Published private(set) var isRecording: Bool = false

    private var recorder: AVAudioRecorder?
    private var currentURL: URL?
    private var startedAt: Date?

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw NSError(domain: "AudioRecorder", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to start recording."])
        }

        self.recorder = recorder
        self.currentURL = url
        self.startedAt = Date()
        self.isRecording = true
    }

    struct Recording {
        let url: URL
        let duration: TimeInterval
    }

    func stop() -> Recording? {
        guard isRecording, let recorder, let url = currentURL else { return nil }
        recorder.stop()
        let duration = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        self.recorder = nil
        self.currentURL = nil
        self.startedAt = nil
        self.isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        return Recording(url: url, duration: duration)
    }
}

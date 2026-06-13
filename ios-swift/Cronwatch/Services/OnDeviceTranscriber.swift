import Foundation
import Speech

enum OnDeviceTranscriberError: Error, LocalizedError {
    case notAuthorized
    case unavailable
    case noSpeech
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Speech recognition isn't authorized."
        case .unavailable:   return "On-device transcription isn't available on this device."
        case .noSpeech:      return "Couldn't hear any speech in that recording — try again."
        case .failed(let m): return m
        }
    }
}

/// On-device speech-to-text — free, private, no audio leaves the phone.
///
/// Uses Apple's Speech framework with `requiresOnDeviceRecognition`, which routes
/// through the same on-device models that back SpeechAnalyzer on supported
/// hardware. (On iOS 26+ this can be upgraded to the `SpeechAnalyzer` /
/// `SpeechTranscriber` streaming API for lower latency; the Speech-framework path
/// here keeps a single implementation working back to the iOS 17 deployment target.)
enum OnDeviceTranscriber {

    static let locale = Locale(identifier: "en-US")

    /// Whether a recognizer exists and reports on-device support for our locale.
    static var isSupported: Bool {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else { return false }
        return recognizer.supportsOnDeviceRecognition
    }

    /// Requests Speech recognition authorization. Returns true when authorized.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        @unknown default:
            return false
        }
    }

    /// Transcribes a recorded audio file entirely on-device.
    static func transcribe(audioURL: URL) async throws -> String {
        guard await requestAuthorization() else {
            throw OnDeviceTranscriberError.notAuthorized
        }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw OnDeviceTranscriberError.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        // Force local processing so nothing is uploaded. Honored only when the
        // device supports it; otherwise the recognizer would require the network,
        // which we explicitly avoid for this provider.
        guard recognizer.supportsOnDeviceRecognition else {
            throw OnDeviceTranscriberError.unavailable
        }
        request.requiresOnDeviceRecognition = true

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            let resumeOnce: (Result<String, Error>) -> Void = { result in
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    resumeOnce(.failure(OnDeviceTranscriberError.failed(error.localizedDescription)))
                    return
                }
                guard let result, result.isFinal else { return }
                let text = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    resumeOnce(.failure(OnDeviceTranscriberError.noSpeech))
                } else {
                    resumeOnce(.success(text))
                }
            }
        }
    }
}

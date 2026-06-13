import Foundation

/// How a voice recording is turned into text.
///
/// - ``speechAnalyzer`` runs entirely on-device (free, private) and never uploads
///   audio — the client transcribes locally and posts text to `/structure`.
/// - ``togetherWhisper`` and ``deepgram`` upload audio to the server's `/capture`
///   endpoint, which transcribes with the matching cloud provider.
enum TranscriptionProvider: String, CaseIterable, Codable, Identifiable, Equatable {
    case speechAnalyzer
    case togetherWhisper
    case deepgram

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .speechAnalyzer:  return "SpeechAnalyzer"
        case .togetherWhisper: return "Together AI Whisper"
        case .deepgram:        return "Deepgram"
        }
    }

    var tagline: String {
        switch self {
        case .speechAnalyzer:  return "On-device · free · private"
        case .togetherWhisper: return "Cloud Whisper · low cost"
        case .deepgram:        return "Cloud Nova-3 · highest accuracy"
        }
    }

    var detail: String {
        switch self {
        case .speechAnalyzer:
            return "Transcribes on your iPhone. Your audio never leaves the device, and there's no per-minute cost."
        case .togetherWhisper:
            return "Sends audio to the Cronwatch server, transcribed with Whisper. Inexpensive and accurate."
        case .deepgram:
            return "Sends audio to the Cronwatch server, transcribed with Deepgram Nova-3. The most accurate option."
        }
    }

    /// On-device providers transcribe locally and never upload audio.
    var isOnDevice: Bool { self == .speechAnalyzer }

    /// Value sent to the server's `/capture` `provider` field. `nil` for on-device
    /// providers, which post text to `/structure` instead and never reach `/capture`.
    var serverValue: String? {
        switch self {
        case .speechAnalyzer:  return nil
        case .togetherWhisper: return "together"
        case .deepgram:        return "deepgram"
        }
    }

    static let `default`: TranscriptionProvider = .togetherWhisper
}

import Foundation

/// The transcription provider used for every capture.
///
/// Cronwatch transcribes voice with Together AI Whisper. The provider is fixed —
/// there is no in-app picker — so this is a constant read on every capture rather
/// than a stored per-device preference.
@MainActor
final class TranscriptionSettings {
    static let shared = TranscriptionSettings()

    let provider: TranscriptionProvider = .togetherWhisper

    private init() {}
}

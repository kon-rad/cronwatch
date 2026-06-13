import Foundation

/// Tracks whether the user has explicitly agreed to send capture data to
/// Cronwatch's third-party AI sub-processors.
///
/// Apple guidelines 5.1.1(i) / 5.1.2(i) require the app to disclose what data
/// is sent, name who it is sent to, and obtain the user's permission *before*
/// sharing personal data with a third-party AI service. Every capture — voice
/// or typed — sends text to Together AI for structuring, and voice captures
/// additionally send audio to Together AI for transcription, so we gate the
/// first capture on this consent.
@MainActor
final class AIConsentStore: ObservableObject {
    static let shared = AIConsentStore()

    /// Bump when the disclosure text materially changes so users re-consent.
    /// v2: voice transcription moved to Together AI (cloud) as the fixed default,
    /// so the disclosure now states that audio is always sent for transcription.
    static let currentVersion = 2

    private let key = "aiDataConsentVersion"

    @Published private(set) var consentedVersion: Int

    /// True once the user has agreed to the current disclosure version.
    var hasConsented: Bool { consentedVersion >= Self.currentVersion }

    private init() {
        consentedVersion = UserDefaults.standard.integer(forKey: key)
    }

    func recordConsent() {
        consentedVersion = Self.currentVersion
        UserDefaults.standard.set(Self.currentVersion, forKey: key)
    }

    /// Clears consent (e.g. for a future "revoke" affordance). Not currently
    /// wired to UI but kept so consent is reversible.
    func revoke() {
        consentedVersion = 0
        UserDefaults.standard.set(0, forKey: key)
    }
}

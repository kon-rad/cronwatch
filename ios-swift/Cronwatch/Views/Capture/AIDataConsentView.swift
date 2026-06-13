import SwiftUI

/// One-time disclosure shown before the user's first capture is sent.
///
/// Satisfies App Store guidelines 5.1.1(i) / 5.1.2(i): it discloses what data
/// is sent, names the third-party AI services that receive it, links the full
/// privacy policy, and requires an explicit tap to agree before any data leaves
/// the device.
struct AIDataConsentView: View {
    /// Called when the user taps "Agree & Continue".
    let onAgree: () -> Void
    /// Called when the user declines / dismisses without agreeing.
    let onDecline: () -> Void

    @Environment(\.openURL) private var openURL

    private let privacyURL = URL(string: "https://cronwatch.xyz/privacy")!

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Palette.border)
                .frame(width: 36, height: 4)
                .padding(.top, Spacing.sm)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("How Cronwatch uses AI")
                            .font(.cwTitle)
                            .foregroundColor(Palette.ink)

                        Text("To turn what you say or type into structured time entries, Cronwatch sends your capture to third-party AI services. Here's exactly what happens before you continue.")
                            .font(.cwBody)
                            .foregroundColor(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: Spacing.md) {
                        bullet(
                            icon: "text.bubble",
                            title: "Your capture text → Together AI",
                            body: "The words from each capture (plus the time and your time zone) are sent to Together AI, which runs an open-weights language model to extract the entry — category, note, and time range."
                        )
                        bullet(
                            icon: "waveform",
                            title: "Your voice recording → Together AI",
                            body: "When you capture by voice, your audio recording is sent to Together AI, which transcribes it to text with the Whisper speech-to-text model. Typed captures send only your text."
                        )
                        bullet(
                            icon: "hand.raised",
                            title: "Not sold, not used for ads",
                            body: "We don't sell your data or share it with advertisers. These providers process your data only to deliver the feature."
                        )
                    }

                    Button {
                        openURL(privacyURL)
                    } label: {
                        Text("Read our Privacy Policy")
                            .font(.cwBody.weight(.semibold))
                            .foregroundColor(Palette.amber)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.md)
            }

            VStack(spacing: Spacing.sm) {
                Button(action: onAgree) {
                    Text("Agree & Continue")
                        .font(.cwBody.weight(.semibold))
                        .foregroundColor(Palette.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Palette.amber)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .buttonStyle(.plain)

                Button(action: onDecline) {
                    Text("Not now")
                        .font(.cwBody)
                        .foregroundColor(Palette.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
        .background(Palette.bg)
    }

    private func bullet(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(Palette.amber)
                .frame(width: 24)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.cwBody.weight(.semibold))
                    .foregroundColor(Palette.ink)
                Text(body)
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

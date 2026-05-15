import SwiftUI

struct DraftRowView: View {
    let job: CaptureJob
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                leadingIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryText)
                        .font(.cwBody)
                        .foregroundColor(Palette.ink)
                        .lineLimit(1)
                    if let secondary = secondaryText {
                        Text(secondary)
                            .font(.cwCaption)
                            .foregroundColor(Palette.muted)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(timeText)
                    .font(.cwCaption)
                    .monospacedDigit()
                    .foregroundColor(Palette.muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Palette.border)
                    .frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var leadingIcon: some View {
        switch job.status {
        case .queued, .running:
            ProgressView()
                .controlSize(.small)
                .tint(Palette.amber)
                .frame(width: 18, height: 18)
        case .awaitingConfirmation:
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(Palette.amber)
                .frame(width: 18, height: 18)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(Palette.danger)
                .frame(width: 18, height: 18)
        }
    }

    private var rowBackground: Color {
        switch job.status {
        case .queued, .running, .awaitingConfirmation:
            return Palette.amberSoft
        case .error:
            return Palette.danger.opacity(0.10)
        }
    }

    private var primaryText: String {
        switch job.status {
        case .queued:
            return "Processing…"
        case .running:
            if job.transcript == nil { return "Transcribing…" }
            return "Processing…"
        case .awaitingConfirmation:
            return "Needs your review"
        case .error:
            return "Couldn't save"
        }
    }

    private var secondaryText: String? {
        switch job.status {
        case .queued, .running:
            return nil
        case .awaitingConfirmation:
            return "Tap to resolve conflicts."
        case .error:
            let message = job.error ?? "Tap to retry."
            return message.isEmpty ? "Tap to retry." : message
        }
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d · h:mm a"
        return formatter.string(from: job.createdAt)
    }

    private var accessibilityLabel: String {
        switch job.status {
        case .queued, .running:
            return "Processing entry, \(timeText)"
        case .awaitingConfirmation:
            return "Entry needs your review, \(timeText)"
        case .error:
            let detail = job.error ?? "tap to retry"
            return "Failed entry, \(detail), \(timeText)"
        }
    }
}

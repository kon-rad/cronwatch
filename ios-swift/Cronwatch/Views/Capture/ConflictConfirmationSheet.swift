import SwiftUI

struct ConflictConfirmationSheet: View {
    let pending: PendingConfirmation
    var onReplace: () -> Void
    var onDiscard: () -> Void

    @State private var inFlight: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Replace existing entries?")
                .font(.cwTitle)
                .foregroundColor(Palette.ink)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("This recording adds:")
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                ForEach(Array(pending.plan.drafts.enumerated()), id: \.offset) { _, draft in
                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .fill(Categories.color(for: draft.category))
                            .frame(width: 10, height: 10)
                        Text(Categories.label(for: draft.category))
                            .font(.cwBody.weight(.semibold))
                            .foregroundColor(Palette.ink)
                        Spacer()
                        Text(Self.formatRange(draft.startTime, draft.endTime))
                            .font(.cwCaption)
                            .monospacedDigit()
                            .foregroundColor(Palette.muted)
                    }
                }
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("And will:")
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                ForEach(Array(pending.plan.resolutions.enumerated()), id: \.offset) { _, resolution in
                    Text(Self.describe(resolution: resolution))
                        .font(.cwBody)
                        .foregroundColor(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: Spacing.sm) {
                Button(action: {
                    guard !inFlight else { return }
                    inFlight = true
                    onReplace()
                }) {
                    HStack {
                        if inFlight {
                            ProgressView().tint(.white)
                        } else {
                            Text("Replace and save")
                                .font(.cwBody.weight(.semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Palette.amber)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .disabled(inFlight)

                Button(action: {
                    guard !inFlight else { return }
                    inFlight = true
                    onDiscard()
                }) {
                    Text("Discard")
                        .font(.cwBody)
                        .foregroundColor(Palette.danger)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .disabled(inFlight)
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.lg)
        .interactiveDismissDisabled(inFlight)
        .background(Palette.bg)
    }

    private static func formatRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    private static func describe(resolution: Resolution) -> String {
        let label = Categories.label(for: resolution.category)
        switch resolution.action {
        case .delete:
            return "• Delete “\(label)” \(formatRange(resolution.originalStart, resolution.originalEnd))"
        case .trim(let s, let e):
            return "• Trim “\(label)” to \(formatRange(s, e))"
        case .split(let l, let r):
            return "• Split “\(label)” into \(formatRange(l.start, l.end)) and \(formatRange(r.start, r.end))"
        }
    }
}

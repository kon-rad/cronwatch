import SwiftUI

// Shown when saving an edit whose new time range overlaps other entries.
// Lists exactly how the conflicting entries will be adjusted (trim / delete /
// split) and asks the user to confirm before anything is written. Mirrors the
// voice-capture ConflictConfirmationSheet so the two flows feel identical.
struct EntryEditConflictSheet: View {
    let category: String
    let startTime: Date
    let endTime: Date
    let resolutions: [Resolution]
    var onConfirm: () -> Void
    var onCancel: () -> Void

    @State private var inFlight: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("This overlaps other entries")
                .font(.cwTitle)
                .foregroundColor(Palette.ink)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Your edit:")
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Categories.color(for: category))
                        .frame(width: 10, height: 10)
                    Text(Categories.label(for: category))
                        .font(.cwBody.weight(.semibold))
                        .foregroundColor(Palette.ink)
                    Spacer()
                    Text(Self.formatRangeWithDate(startTime, endTime))
                        .font(.cwCaption)
                        .monospacedDigit()
                        .foregroundColor(Palette.muted)
                }
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("To save it, we'll:")
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                ForEach(Array(resolutions.enumerated()), id: \.offset) { _, resolution in
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
                    onConfirm()
                }) {
                    HStack {
                        if inFlight {
                            ProgressView().tint(.white)
                        } else {
                            Text("Save and adjust")
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
                    onCancel()
                }) {
                    Text("Cancel")
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
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private static func formatRangeWithDate(_ start: Date, _ end: Date) -> String {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "MMM d"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"
        return "\(dateFmt.string(from: start)), \(timeFmt.string(from: start)) - \(timeFmt.string(from: end))"
    }

    private static func describe(resolution: Resolution) -> String {
        let label = Categories.label(for: resolution.category)
        switch resolution.action {
        case .delete:
            return "• Delete \"\(label)\" \(formatRangeWithDate(resolution.originalStart, resolution.originalEnd))"
        case .trim(let s, let e):
            return "• Trim \"\(label)\" (\(formatRangeWithDate(resolution.originalStart, resolution.originalEnd))) to \(formatRange(s, e))"
        case .split(let l, let r):
            return "• Split \"\(label)\" (\(formatRangeWithDate(resolution.originalStart, resolution.originalEnd))) into \(formatRange(l.start, l.end)) and \(formatRange(r.start, r.end))"
        }
    }
}

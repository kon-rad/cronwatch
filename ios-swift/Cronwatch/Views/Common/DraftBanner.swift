import SwiftUI

struct DraftBanner: View {
    @EnvironmentObject var queue: CaptureQueue
    @State private var expanded = false
    @State private var pendingDiscard: CaptureJob?

    private var drafts: [CaptureJob] {
        queue.jobs.filter { $0.status == .error }
    }

    var body: some View {
        let drafts = self.drafts
        if drafts.isEmpty {
            EmptyView()
        } else {
            content(drafts: drafts)
        }
    }

    @ViewBuilder
    private func content(drafts: [CaptureJob]) -> some View {
        VStack(spacing: 0) {
            Button {
                expanded.toggle()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Palette.danger)
                    Text("\(drafts.count) draft\(drafts.count == 1 ? "" : "s") waiting")
                        .font(.cwBody.weight(.semibold))
                        .foregroundColor(Palette.ink)
                    Spacer()
                    Button {
                        queue.retryAll()
                    } label: {
                        Text("Retry all")
                            .font(.cwCaption.weight(.semibold))
                            .foregroundColor(Palette.danger)
                    }
                    .buttonStyle(.plain)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Palette.muted)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().background(Palette.border)
                ForEach(drafts) { job in
                    DraftRow(
                        job: job,
                        onRetry: { queue.retry(jobId: job.id) },
                        onDiscard: { pendingDiscard = job }
                    )
                }
            }
        }
        .background(Palette.amberSoft)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Palette.border, lineWidth: 1)
        )
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .alert("Discard draft?",
               isPresented: Binding(
                get: { pendingDiscard != nil },
                set: { if !$0 { pendingDiscard = nil } }
               ),
               presenting: pendingDiscard) { job in
            Button("Cancel", role: .cancel) { pendingDiscard = nil }
            Button("Discard", role: .destructive) {
                queue.discard(jobId: job.id)
                pendingDiscard = nil
            }
        } message: { _ in
            Text("The recording will be deleted and cannot be recovered.")
        }
    }
}

private struct DraftRow: View {
    let job: CaptureJob
    let onRetry: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatTime(job.createdAt))
                    .font(.cwCaption)
                    .monospacedDigit()
                    .foregroundColor(Palette.muted)
                Text(job.error ?? "Couldn't process entry")
                    .font(.cwCaption)
                    .foregroundColor(Palette.ink)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Spacing.md) {
                Button(action: onRetry) {
                    Text("Retry")
                        .font(.cwCaption.weight(.semibold))
                        .foregroundColor(Palette.danger)
                }
                .buttonStyle(.plain)

                Button(action: onDiscard) {
                    Text("Discard")
                        .font(.cwCaption)
                        .foregroundColor(Palette.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.border)
                .frame(height: 0.5)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

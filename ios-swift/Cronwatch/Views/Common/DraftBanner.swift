import SwiftUI

struct DraftBanner: View {
    @EnvironmentObject var queue: CaptureQueue

    private var errorJobs: [CaptureJob] {
        queue.jobs.filter { $0.status == .error }
    }

    var body: some View {
        let drafts = errorJobs
        if drafts.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(Palette.danger)
                Text("\(drafts.count) draft\(drafts.count == 1 ? "" : "s") need attention")
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
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Palette.amberSoft)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Palette.border, lineWidth: 1)
            )
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.sm)
        }
    }
}

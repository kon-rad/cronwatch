import SwiftUI

struct TodayView: View {
    @EnvironmentObject var auth: AuthService
    @State private var entries: [Entry] = []
    @State private var cancel: (() -> Void)?

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                TodayGridView(entries: entries)
            }
        }
        .onAppear {
            guard let uid = auth.currentUser?.uid else { return }
            cancel = EntriesService.shared.subscribeToToday(uid: uid) { newEntries in
                entries = newEntries
            }
        }
        .onDisappear {
            cancel?()
            cancel = nil
        }
    }

    private var header: some View {
        let tracked = TimeUtils.totalTrackedMin(entries)
        let open = max(0, TimeUtils.minPerDay - tracked)
        return VStack(alignment: .leading, spacing: 2) {
            Text(TimeUtils.formatLongDate())
                .font(.cwTitle)
                .foregroundStyle(Palette.ink)
            HStack(spacing: 0) {
                Text("\(TimeUtils.formatDuration(tracked)) tracked")
                    .font(.cwCaption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.muted)
                Spacer().frame(width: Spacing.md)
                Text("\(TimeUtils.formatDuration(open)) open")
                    .font(.cwCaption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.muted)
                Spacer()
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }
}

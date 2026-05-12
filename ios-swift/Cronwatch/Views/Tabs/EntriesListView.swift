import FirebaseFirestore
import SwiftUI

struct EntriesListView: View {
    @EnvironmentObject var auth: AuthService

    @State private var head: [Entry] = []
    @State private var tail: [Entry] = []
    @State private var headCursor: DocumentSnapshot?
    @State private var tailCursor: DocumentSnapshot?
    @State private var loadingMore = false
    @State private var hasMore = true
    @State private var loadMoreError: String?
    @State private var selectedCaptureId: String?
    @State private var cancelSubscription: (() -> Void)?

    private let pageSize = 50

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Entries")
                        .font(.cwTitle)
                        .foregroundColor(Palette.ink)
                    Spacer()
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.sm)

                content
            }
        }
        .onAppear { startSubscription() }
        .onDisappear {
            cancelSubscription?()
            cancelSubscription = nil
        }
        .sheet(item: Binding(
            get: { selectedCaptureId.map(SelectedCaptureId.init) },
            set: { selectedCaptureId = $0?.value }
        )) { selection in
            EntryViewOnlyView(captureId: selection.value)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    @ViewBuilder
    private var content: some View {
        let captures = EntriesService.groupByCapture(head + tail)
        if captures.isEmpty {
            ScrollView {
                DraftBanner()
                    .padding(.top, Spacing.sm)
                VStack {
                    Spacer(minLength: Spacing.xl)
                    Text("No entries yet.")
                        .font(.cwBody)
                        .foregroundColor(Palette.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.xl)
            }
            .refreshable { resetTail() }
        } else {
            List {
                DraftBanner()
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Palette.bg)
                    .padding(.top, Spacing.sm)

                ForEach(captures) { capture in
                    CaptureRowView(capture: capture) {
                        selectedCaptureId = capture.captureId
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Palette.bg)
                    .onAppear {
                        maybeLoadMore(currentCapture: capture, captures: captures)
                    }
                }

                if loadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, Spacing.md)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Palette.bg)
                }

                if let loadMoreError {
                    Button {
                        Task { await runLoadMore() }
                    } label: {
                        Text("Couldn't load more — tap to retry")
                            .font(.cwCaption)
                            .foregroundColor(Palette.danger)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, Spacing.md)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Palette.bg)
                    .accessibilityLabel("Retry loading more entries")
                    .id(loadMoreError)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Palette.bg)
            .refreshable { resetTail() }
        }
    }

    private func startSubscription() {
        cancelSubscription?()
        guard let uid = auth.currentUser?.uid else { return }
        let cancel = EntriesService.shared.subscribeFirstPage(
            uid: uid,
            pageSize: pageSize
        ) { entries, lastCursor in
            head = entries
            headCursor = lastCursor
        }
        cancelSubscription = cancel
    }

    private func resetTail() {
        tail = []
        tailCursor = nil
        hasMore = true
        loadMoreError = nil
    }

    private func maybeLoadMore(currentCapture: Capture, captures: [Capture]) {
        guard hasMore, !loadingMore else { return }
        guard let lastVisible = captures.last,
              currentCapture.id == lastVisible.id else { return }
        Task { await runLoadMore() }
    }

    private func runLoadMore() async {
        guard !loadingMore, hasMore else { return }
        let cursor = tailCursor ?? headCursor
        guard cursor != nil else { return }
        loadingMore = true
        loadMoreError = nil
        defer { loadingMore = false }

        guard let uid = auth.currentUser?.uid else { return }
        do {
            let result = try await EntriesService.shared.loadMore(
                uid: uid,
                cursor: cursor,
                pageSize: pageSize
            )
            tail.append(contentsOf: result.entries)
            tailCursor = result.lastCursor
            hasMore = result.hasMore
        } catch {
            loadMoreError = error.localizedDescription
        }
    }
}

private struct SelectedCaptureId: Identifiable, Equatable {
    let value: String
    var id: String { value }
}

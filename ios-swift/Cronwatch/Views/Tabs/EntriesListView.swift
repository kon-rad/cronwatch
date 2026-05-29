import FirebaseFirestore
import SwiftUI

enum EntryRow: Identifiable {
    case capture(Capture)
    case draft(CaptureJob)

    var id: String {
        switch self {
        case .capture(let c): return "c_" + c.id
        case .draft(let j):   return "d_" + j.id
        }
    }

    var sortDate: Date {
        switch self {
        case .capture(let c): return c.createdAt
        case .draft(let j):   return j.createdAt
        }
    }
}

struct EntriesListView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var queue: CaptureQueue

    @State private var head: [Entry] = []
    @State private var tail: [Entry] = []
    @State private var headCursor: DocumentSnapshot?
    @State private var tailCursor: DocumentSnapshot?
    @State private var loadingMore = false
    @State private var hasMore = true
    @State private var loadMoreError: String?
    @State private var selectedCaptureId: String?
    @State private var selectedDraftJobId: String?
    @State private var pendingDiscardJob: CaptureJob?
    @State private var cancelSubscription: (() -> Void)?
    @State private var totalCount: Int = 0

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
        .onAppear {
            startSubscription()
            refreshTotalCount()
        }
        .onDisappear {
            cancelSubscription?()
            cancelSubscription = nil
        }
        .onChange(of: head.count) { _, _ in
            refreshTotalCount()
        }
        .sheet(item: Binding(
            get: { selectedCaptureId.map(SelectedCaptureId.init) },
            set: { selectedCaptureId = $0?.value }
        )) { selection in
            EntryViewOnlyView(captureId: selection.value)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: Binding(
            get: { selectedDraftJobId.map(SelectedDraftJobId.init) },
            set: { selectedDraftJobId = $0?.value }
        )) { selection in
            DraftEditView(jobId: selection.value)
                .presentationDetents([.large])
        }
        .alert("Discard draft?",
               isPresented: Binding(
                get: { pendingDiscardJob != nil },
                set: { if !$0 { pendingDiscardJob = nil } }
               ),
               presenting: pendingDiscardJob) { job in
            Button("Cancel", role: .cancel) { pendingDiscardJob = nil }
            Button("Discard", role: .destructive) {
                queue.discard(jobId: job.id)
                pendingDiscardJob = nil
            }
        } message: { _ in
            Text("The recording will be deleted and cannot be recovered.")
        }
    }

    private var rows: [EntryRow] {
        let captures = EntriesService.groupByCapture(head + tail).map(EntryRow.capture)
        let drafts = queue.jobs.map(EntryRow.draft)
        return (captures + drafts).sorted { $0.sortDate > $1.sortDate }
    }

    private func captureIndex(_ rows: [EntryRow], target: String) -> Int {
        var i = 0
        for row in rows {
            if case .capture(let c) = row {
                if c.id == target { return i }
                i += 1
            }
        }
        return 0
    }

    @ViewBuilder
    private var content: some View {
        let rows = self.rows
        if rows.isEmpty {
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

                ForEach(rows) { row in
                    rowView(for: row, in: rows)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Palette.bg)
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

    @ViewBuilder
    private func rowView(for row: EntryRow, in rows: [EntryRow]) -> some View {
        switch row {
        case .capture(let capture):
            let index = captureIndex(rows, target: capture.id)
            CaptureRowView(
                capture: capture,
                entryNumber: max(1, totalCount - index)
            ) {
                selectedCaptureId = capture.captureId
            }
            .onAppear { maybeLoadMore(currentRow: row, rows: rows) }
        case .draft(let job):
            DraftRowView(job: job) {
                selectedDraftJobId = job.id
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if job.status == .error {
                    Button(role: .destructive) {
                        pendingDiscardJob = job
                    } label: {
                        Label("Discard", systemImage: "trash")
                    }
                }
            }
        }
    }

    private func refreshTotalCount() {
        guard let uid = auth.currentUser?.uid else { return }
        Task {
            if let count = try? await EntriesService.shared.getEntriesCount(uid: uid) {
                totalCount = count
            }
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

    private func maybeLoadMore(currentRow: EntryRow, rows: [EntryRow]) {
        guard hasMore, !loadingMore else { return }
        guard case .capture(let current) = currentRow else { return }
        let lastCapture = rows.reversed().first(where: {
            if case .capture = $0 { return true } else { return false }
        })
        guard case .capture(let last) = lastCapture, current.id == last.id else { return }
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

private struct SelectedDraftJobId: Identifiable, Equatable {
    let value: String
    var id: String { value }
}

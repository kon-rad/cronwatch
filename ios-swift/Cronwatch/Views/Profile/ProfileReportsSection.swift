import SwiftUI

struct ProfileReportsSection: View {
    let uid: String
    let goals: [String]

    @EnvironmentObject private var rc: RevenueCatService

    @State private var reports: [ProfileReport] = []
    @State private var unsubscribe: (() -> Void)?
    @State private var showComposer = false
    @State private var showAllReports = false
    @State private var showPaywall = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("REPORTS")
                .font(.cwCaption)
                .tracking(1.2)
                .foregroundStyle(Palette.muted)
                .padding(.bottom, Spacing.sm)

            VStack(spacing: 0) {
                generateRow(isFirst: true)
                Rectangle().fill(Palette.border).frame(height: 0.5)
                allReportsRow
            }
            .background(Palette.white)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Palette.border, lineWidth: 1)
            )
        }
        .padding(.top, Spacing.lg)
        .onAppear { subscribe() }
        .onDisappear {
            unsubscribe?()
            unsubscribe = nil
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showComposer) {
            ReportComposerView(
                uid: uid,
                goals: goals,
                onClose: { showComposer = false }
            )
        }
        .fullScreenCover(isPresented: $showAllReports) {
            ProfileReportsListView(uid: uid, goals: goals) { showAllReports = false }
        }
    }

    private func generateRow(isFirst: Bool) -> some View {
        Button {
            if rc.entitlement == .free {
                showPaywall = true
            } else {
                showComposer = true
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.amber)
                Text("Generate new")
                    .font(.cwBody.weight(.semibold))
                    .foregroundStyle(Palette.amber)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var allReportsRow: some View {
        Button {
            showAllReports = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Text("All reports")
                    .font(.cwBody)
                    .foregroundStyle(Palette.ink)
                Spacer()
                if !reports.isEmpty {
                    Text("\(reports.count)")
                        .font(.cwBody)
                        .foregroundStyle(Palette.muted)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func subscribe() {
        unsubscribe?()
        unsubscribe = ProfileReportsService.shared.subscribe(uid: uid) { latest in
            self.reports = latest
        }
    }
}

private struct ProfileReportsListView: View {
    let uid: String
    let goals: [String]
    let onClose: () -> Void

    @State private var reports: [ProfileReport] = []
    @State private var unsubscribe: (() -> Void)?
    @State private var openReport: ProfileReport?
    @State private var pendingDelete: ProfileReport?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if reports.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(reports.enumerated()), id: \.element.id) { index, report in
                                    reportRow(report, isFirst: index == 0)
                                }
                            }
                            .background(Palette.white)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .stroke(Palette.border, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Palette.ink)
                    }
                }
            }
        }
        .onAppear { subscribe() }
        .onDisappear {
            unsubscribe?()
            unsubscribe = nil
        }
        .fullScreenCover(item: $openReport) { report in
            ReportDetailView(report: report) { openReport = nil }
        }
        .alert(item: $pendingDelete) { report in
            Alert(
                title: Text("Delete report?"),
                message: Text(report.title),
                primaryButton: .destructive(Text("Delete")) {
                    Task { await delete(report) }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Text("No reports yet")
                .font(.cwBody.weight(.semibold))
                .foregroundStyle(Palette.ink)
            Text("Generate one from your profile.")
                .font(.cwCaption)
                .foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
    }

    private func reportRow(_ report: ProfileReport, isFirst: Bool) -> some View {
        VStack(spacing: 0) {
            if !isFirst {
                Rectangle().fill(Palette.border).frame(height: 0.5)
            }
            Button {
                onTap(report)
            } label: {
                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(for: report))
                            .font(.cwBody)
                            .foregroundStyle(report.status == .failed ? Palette.danger : Palette.ink)
                            .lineLimit(1)
                        Text(subtitle(for: report))
                            .font(.cwCaption)
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)
                    }
                    Spacer()
                    trailingAccessory(for: report)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(report.status == .generating)
            .contextMenu {
                Button(role: .destructive) {
                    pendingDelete = report
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func trailingAccessory(for report: ProfileReport) -> some View {
        switch report.status {
        case .generating:
            ProgressView()
                .controlSize(.small)
        case .failed:
            Image(systemName: "exclamationmark.arrow.circlepath")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Palette.danger)
        case .ready:
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Palette.muted)
        }
    }

    private func onTap(_ report: ProfileReport) {
        switch report.status {
        case .generating:
            break
        case .failed:
            ReportGenerationCoordinator.shared.retry(uid: uid, report: report, goals: goals)
        case .ready:
            openReport = report
        }
    }

    private func title(for report: ProfileReport) -> String {
        switch report.status {
        case .generating: return "Generating report…"
        case .failed: return "Couldn’t generate — tap to retry"
        case .ready: return report.title
        }
    }

    private func subtitle(for report: ProfileReport) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let range = "\(f.string(from: report.rangeStart)) – \(f.string(from: report.rangeEnd))"
        switch report.status {
        case .generating:
            return "\(range) · generating…"
        case .failed:
            return range
        case .ready:
            return "\(range) · \(relativeCreatedAt(report.createdAt))"
        }
    }

    private func relativeCreatedAt(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func subscribe() {
        unsubscribe?()
        unsubscribe = ProfileReportsService.shared.subscribe(uid: uid) { latest in
            self.reports = latest
        }
    }

    private func delete(_ report: ProfileReport) async {
        do {
            try await ProfileReportsService.shared.delete(uid: uid, id: report.id)
        } catch {
            print("[ProfileReportsListView] delete failed: \(error)")
            ToastCenter.shared.show(message: error.localizedDescription, kind: .error)
        }
    }
}

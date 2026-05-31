import Foundation

/// Runs profile-report generation in the background so the composer can close
/// immediately. A placeholder doc is written up front (status = generating) and
/// flipped to ready/failed when the work finishes. The reports list's Firestore
/// listener picks up the transitions live — no extra wiring needed.
@MainActor
final class ReportGenerationCoordinator {
    static let shared = ReportGenerationCoordinator()

    private init() {}

    /// In-flight tasks keyed by report id, so ARC keeps them alive after the
    /// composer view that started them is gone.
    private var tasks: [String: Task<Void, Never>] = [:]

    private let generatingTitle = "Generating report…"

    /// Validates the range, writes a placeholder, shows a toast, and kicks off
    /// background generation. Returns immediately.
    func enqueue(uid: String,
                 rangeStart: Date,
                 rangeEnd: Date,
                 goals: [String],
                 customPrompt: String?) {
        let cal = Calendar.current
        let normalizedStart = cal.startOfDay(for: rangeStart)
        guard let normalizedEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: rangeEnd))?
                .addingTimeInterval(-1) else {
            ToastCenter.shared.show(message: "Invalid date range.", kind: .error, duration: 3)
            return
        }

        let trimmedPrompt = (customPrompt ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let report = ProfileReport(
            id: ProfileReportsService.newReportId(),
            title: generatingTitle,
            html: "",
            rangeStart: normalizedStart,
            rangeEnd: normalizedEnd,
            customPrompt: trimmedPrompt.isEmpty ? nil : trimmedPrompt,
            createdAt: Date(),
            status: .generating,
            errorMessage: nil
        )

        Task { [weak self] in
            do {
                try await ProfileReportsService.shared.createPlaceholder(uid: uid, report: report)
                ToastCenter.shared.show(message: "Generating report — ready soon", kind: .info, duration: 2)
                self?.run(uid: uid, report: report, goals: goals)
            } catch {
                ToastCenter.shared.show(message: error.localizedDescription, kind: .error, duration: 4)
            }
        }
    }

    /// Re-runs generation for a report that previously failed, reusing its doc.
    func retry(uid: String, report: ProfileReport, goals: [String]) {
        guard report.status == .failed else { return }
        Task { [weak self] in
            do {
                try await ProfileReportsService.shared.markGenerating(uid: uid, id: report.id)
                ToastCenter.shared.show(message: "Generating report — ready soon", kind: .info, duration: 2)
                self?.run(uid: uid, report: report, goals: goals)
            } catch {
                ToastCenter.shared.show(message: error.localizedDescription, kind: .error, duration: 4)
            }
        }
    }

    private func run(uid: String, report: ProfileReport, goals: [String]) {
        tasks[report.id]?.cancel()
        tasks[report.id] = Task { [weak self] in
            let outcome = await Self.generate(uid: uid, report: report, goals: goals)
            switch outcome {
            case .success(let title, let html):
                do {
                    try await ProfileReportsService.shared.markReady(uid: uid, id: report.id, title: title, html: html)
                    ToastCenter.shared.show(message: "Report ready", kind: .success, duration: 2)
                } catch {
                    await self?.fail(uid: uid, id: report.id, message: error.localizedDescription, retry: nil)
                }
            case .failure(let message):
                await self?.fail(uid: uid, id: report.id, message: message, retry: {
                    self?.retry(uid: uid, report: report, goals: goals)
                })
            }
            self?.tasks[report.id] = nil
        }
    }

    private func fail(uid: String, id: String, message: String, retry: (() -> Void)?) async {
        try? await ProfileReportsService.shared.markFailed(uid: uid, id: id, message: message)
        let action = retry.map { handler in
            Toast.ToastAction(label: "Retry", handler: handler)
        }
        ToastCenter.shared.show(message: "Report failed — tap Retry", kind: .error, duration: 6, action: action)
    }

    private enum Outcome {
        case success(title: String, html: String)
        case failure(String)
    }

    private static func generate(uid: String, report: ProfileReport, goals: [String]) async -> Outcome {
        do {
            let entries = try await EntriesService.shared.fetchRange(
                uid: uid,
                from: report.rangeStart,
                to: report.rangeEnd
            )
            let days = RangeAggregator.aggregate(
                entries: entries,
                rangeStart: report.rangeStart,
                rangeEnd: report.rangeEnd
            )
            let generated = try await ProfileReportGenerator.generate(
                rangeStart: report.rangeStart,
                rangeEnd: report.rangeEnd,
                goals: goals,
                customPrompt: report.customPrompt,
                days: days
            )
            return .success(title: generated.title, html: generated.html)
        } catch {
            print("[ReportGenerationCoordinator] generate failed: \(error)")
            return .failure(error.localizedDescription)
        }
    }
}

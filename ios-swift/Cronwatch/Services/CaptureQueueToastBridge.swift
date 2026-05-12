import Combine
import Foundation

@MainActor
final class CaptureQueueToastBridge: ObservableObject {
    private var stickyId: String?
    private var lastStatus: [String: CaptureJobStatus] = [:]
    private var lastKnownIds: Set<String> = []
    private var cancellable: AnyCancellable?

    func observe(queue: CaptureQueue, toasts: ToastCenter) {
        cancellable?.cancel()
        // Seed with the initial snapshot to set baseline state.
        process(jobs: queue.jobs, toasts: toasts)
        cancellable = queue.$jobs.sink { [weak self, weak toasts] jobs in
            guard let self, let toasts else { return }
            self.process(jobs: jobs, toasts: toasts)
        }
    }

    private func process(jobs: [CaptureJob], toasts: ToastCenter) {
        let active = jobs.contains(where: { $0.status == .queued || $0.status == .running })
        if active && stickyId == nil {
            stickyId = toasts.show(message: "Processing entry…", kind: .info, duration: nil)
        }
        if !active, let id = stickyId {
            toasts.dismiss(id)
            stickyId = nil
        }

        let currentIds = Set(jobs.map(\.id))
        for job in jobs {
            let previous = lastStatus[job.id]
            if previous != job.status {
                if job.status == .error {
                    toasts.show(
                        message: "Saved as draft — tap Retry",
                        kind: .error,
                        duration: 4,
                        action: .init(label: "Retry") {
                            Task { @MainActor in CaptureQueue.shared.retry(jobId: job.id) }
                        }
                    )
                }
                lastStatus[job.id] = job.status
            }
        }

        for previousId in lastKnownIds where !currentIds.contains(previousId) {
            if lastStatus[previousId] == .running {
                toasts.show(message: "Entry saved.", kind: .success, duration: 2)
            }
            lastStatus.removeValue(forKey: previousId)
        }
        lastKnownIds = currentIds
    }
}

import Combine
import Foundation

@MainActor
final class ConflictPresenter: ObservableObject {
    static let shared = ConflictPresenter()

    @Published var activeJob: PendingConfirmation?

    private var cancellable: AnyCancellable?

    private init() {}

    func observe(queue: CaptureQueue) {
        cancellable?.cancel()
        update(jobs: queue.jobs)
        cancellable = queue.$jobs.sink { [weak self] jobs in
            self?.update(jobs: jobs)
        }
    }

    func dismiss() {
        activeJob = nil
    }

    private func update(jobs: [CaptureJob]) {
        let candidate = jobs.first(where: { $0.status == .awaitingConfirmation })
        if let candidate, let plan = candidate.plan {
            let next = PendingConfirmation(jobId: candidate.id, plan: plan)
            if activeJob != next {
                activeJob = next
            }
        } else if activeJob != nil {
            activeJob = nil
        }
    }
}

struct PendingConfirmation: Identifiable, Equatable {
    let jobId: String
    let plan: ResolutionPlan

    var id: String { jobId }
}

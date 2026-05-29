import SwiftUI

struct OnboardingFlow: View {
    let uid: String
    let onComplete: () -> Void

    @State private var step = 0
    @State private var wantsToBeBetterAt = ""
    @State private var workType = ""
    @State private var vision3Years = ""
    @State private var vision5Years = ""
    @State private var vision10Years = ""
    @State private var goals: [Goal] = [
        Goal(category: "", weeklyTargetHours: 0),
        Goal(category: "", weeklyTargetHours: 0),
        Goal(category: "", weeklyTargetHours: 0),
    ]
    @State private var isSaving = false
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            switch step {
            case 0:
                OnboardingWelcomeView(onNext: { step = 1 })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            case 1:
                OnboardingBetterAtView(
                    value: $wantsToBeBetterAt,
                    onBack: { saveTask?.cancel(); saveTask = nil; step = 0 },
                    onNext: { saveAndAdvance(from: 1) }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            case 2:
                OnboardingWorkTypeView(
                    value: $workType,
                    onBack: { saveTask?.cancel(); saveTask = nil; step = 1 },
                    onNext: { saveAndAdvance(from: 2) }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            case 3:
                OnboardingVisionView(
                    years3: $vision3Years,
                    years5: $vision5Years,
                    years10: $vision10Years,
                    onBack: { saveTask?.cancel(); saveTask = nil; step = 2 },
                    onNext: { saveAndAdvance(from: 3) }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            case 4:
                OnboardingGoalsView(
                    goals: $goals,
                    onBack: { saveTask?.cancel(); saveTask = nil; step = 3 },
                    onNext: { saveAndAdvance(from: 4) }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            case 5:
                OnboardingCompleteView(onDone: complete)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    @MainActor
    private func saveAndAdvance(from currentStep: Int) {
        guard !isSaving else { return }
        isSaving = true
        saveTask = Task {
            defer { isSaving = false }
            do {
                switch currentStep {
                case 1:
                    try await UserSettingsService.shared.saveFields(
                        uid: uid,
                        ["wantsToBeBetterAt": wantsToBeBetterAt]
                    )
                case 2:
                    try await UserSettingsService.shared.saveFields(
                        uid: uid,
                        ["workType": workType]
                    )
                case 3:
                    try await UserSettingsService.shared.saveFields(uid: uid, [
                        "vision3Years":  vision3Years,
                        "vision5Years":  vision5Years,
                        "vision10Years": vision10Years,
                    ])
                case 4:
                    try await UserSettingsService.shared.saveGoals(uid: uid, goals: goals)
                default:
                    break
                }
            } catch {}
            guard !Task.isCancelled else { return }
            step = currentStep + 1
        }
    }

    @MainActor
    private func complete() {
        Task {
            try? await UserSettingsService.shared.setOnboardingCompleted(uid: uid)
            onComplete()
        }
    }
}

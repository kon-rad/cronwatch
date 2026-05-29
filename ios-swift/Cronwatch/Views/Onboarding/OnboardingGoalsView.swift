import SwiftUI

struct OnboardingGoalsView: View {
    @Binding var goals: [Goal]
    let onBack: () -> Void
    let onNext: () -> Void

    private var hasAnyGoal: Bool { goals.contains { $0.isSet } }

    var body: some View {
        OnboardingStepLayout(
            headline: "Set your weekly time goals.",
            subtext: "Choose up to 3 categories and how many hours per week you want to spend on each.",
            canContinue: hasAnyGoal,
            onBack: onBack,
            onContinue: onNext
        ) {
            VStack(spacing: Spacing.md) {
                ForEach(0..<3, id: \.self) { index in
                    goalSlot(index: index)
                }
            }
        }
    }

    @ViewBuilder
    private func goalSlot(index: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("GOAL \(index + 1)")
                .font(.cwCaption)
                .tracking(1.2)
                .foregroundStyle(Palette.muted)

            categoryPicker(index: index)

            if !goals[index].category.isEmpty {
                targetInput(index: index)
            }
        }
        .padding(Spacing.md)
        .background(Palette.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Palette.border, lineWidth: 1)
        )
    }

    private func categoryPicker(index: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(Categories.all, id: \.key) { cat in
                    let isSelected = goals[index].category == cat.key
                    let isUsedElsewhere = goals.indices
                        .filter { $0 != index }
                        .contains { goals[$0].category == cat.key }

                    Button {
                        if isSelected {
                            goals[index] = Goal(category: "", weeklyTargetHours: 0)
                        } else {
                            goals[index].category = cat.key
                            if goals[index].weeklyTargetHours == 0 {
                                goals[index].weeklyTargetHours = 5.0
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            CategoryDotView(category: cat.key)
                            Text(cat.label)
                                .font(.cwCaption)
                                .foregroundStyle(
                                    isSelected ? .white :
                                    (isUsedElsewhere ? Palette.muted : Palette.ink)
                                )
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 6)
                        .background(
                            isSelected ? cat.color :
                            (isUsedElsewhere ? Palette.borderSoft : Color.clear)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(
                                isSelected || isUsedElsewhere ? Color.clear : Palette.border,
                                lineWidth: 1
                            )
                        )
                        .opacity(isUsedElsewhere && !isSelected ? 0.4 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .disabled(isUsedElsewhere && !isSelected)
                }
            }
        }
    }

    private func targetInput(index: Int) -> some View {
        HStack {
            Text("Weekly target")
                .font(.cwBody)
                .foregroundStyle(Palette.muted)
            Spacer()
            TextField("", value: Binding(
                get: { goals[index].weeklyTargetHours },
                set: { goals[index].weeklyTargetHours = max(0.5, min(80, $0)) }
            ), format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .font(.cwBody.weight(.semibold))
            .monospacedDigit()
            .frame(width: 52)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Palette.bg)
            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            Text("hours / week")
                .font(.cwBody)
                .foregroundStyle(Palette.muted)
        }
    }
}

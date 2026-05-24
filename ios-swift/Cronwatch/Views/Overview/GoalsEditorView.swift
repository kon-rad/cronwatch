import SwiftUI

struct GoalsEditorView: View {
    let uid: String
    let initial: UserSettings
    let onClose: () -> Void

    @State private var goals: [Goal]
    @State private var saving: Bool = false
    @State private var errorMessage: String?

    init(uid: String, initial: UserSettings, onClose: @escaping () -> Void) {
        self.uid = uid
        self.initial = initial
        self.onClose = onClose
        var g = initial.goals
        while g.count < 3 { g.append(Goal(category: "", weeklyTargetHours: 0)) }
        _goals = State(initialValue: Array(g.prefix(3)))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Text("Choose up to 3 categories to focus on each week. Set a personal hour target for each.")
                            .font(.cwCaption)
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(0..<3, id: \.self) { index in
                            goalSlot(index: index)
                        }

                        if let errorMessage {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Couldn't save")
                                    .font(.cwCaption.weight(.semibold))
                                    .foregroundStyle(Palette.danger)
                                Text(errorMessage)
                                    .font(.cwCaption)
                                    .foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.danger.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                        }
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle("My Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onClose)
                        .disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { Task { await save() } }) {
                        if saving { ProgressView() } else { Text("Save").fontWeight(.semibold) }
                    }
                    .disabled(saving)
                }
            }
        }
    }

    // MARK: - Goal slot

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

    // MARK: - Category picker

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

    // MARK: - Target input

    private func targetInput(index: Int) -> some View {
        HStack {
            Text("Weekly target")
                .font(.cwBody)
                .foregroundStyle(Palette.muted)
            Spacer()
            Stepper(
                value: Binding(
                    get: { goals[index].weeklyTargetHours },
                    set: { goals[index].weeklyTargetHours = max(0.5, min(80, $0)) }
                ),
                in: 0.5...80,
                step: 0.5
            ) {
                Text(formatHours(goals[index].weeklyTargetHours) + " / week")
                    .font(.cwBody.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .frame(minWidth: 80, alignment: .trailing)
            }
        }
    }

    // MARK: - Helpers

    private func formatHours(_ h: Double) -> String {
        h.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(h))h" : String(format: "%.1fh", h)
    }

    private func save() async {
        guard !saving else { return }
        saving = true
        errorMessage = nil
        defer { saving = false }
        do {
            try await UserSettingsService.shared.saveGoals(uid: uid, goals: goals)
            onClose()
        } catch {
            let nsError = error as NSError
            let message = nsError.localizedDescription
            errorMessage = "\(message) [code \(nsError.code), domain \(nsError.domain)]"
            ToastCenter.shared.show(message: message, kind: .error)
        }
    }
}

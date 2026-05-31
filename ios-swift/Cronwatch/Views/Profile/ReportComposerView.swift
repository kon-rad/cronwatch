import SwiftUI

struct ReportComposerView: View {
    let uid: String
    let goals: [String]
    let onClose: () -> Void

    @State private var rangeStart: Date
    @State private var rangeEnd: Date
    @State private var customPrompt: String = ""
    @FocusState private var promptFocused: Bool

    private let maxPromptLength = 500

    init(uid: String, goals: [String], onClose: @escaping () -> Void) {
        self.uid = uid
        self.goals = goals
        self.onClose = onClose
        let cal = Calendar.current
        let endDay = cal.startOfDay(for: Date())
        let startDay = cal.date(byAdding: .day, value: -6, to: endDay) ?? endDay
        _rangeStart = State(initialValue: startDay)
        _rangeEnd = State(initialValue: endDay)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { promptFocused = false }
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        eyebrow("DATE RANGE")
                        rangeCard

                        eyebrow("CUSTOM PROMPT (OPTIONAL)")
                        promptCard
                    }
                    .padding(Spacing.md)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("New report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: generate) {
                        Text("Generate").fontWeight(.semibold)
                    }
                    .disabled(!rangeValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { promptFocused = false }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var rangeValid: Bool {
        let cal = Calendar.current
        let start = cal.startOfDay(for: rangeStart)
        let end = cal.startOfDay(for: rangeEnd)
        guard end >= start else { return false }
        let days = (cal.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        return days >= 1 && days <= ProfileReportGenerator.maxRangeDays
    }

    private var rangeCard: some View {
        VStack(spacing: 0) {
            DatePicker("Start", selection: $rangeStart, in: ...Date(), displayedComponents: .date)
                .font(.cwBody)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 14)
            Rectangle().fill(Palette.border).frame(height: 0.5)
            DatePicker("End", selection: $rangeEnd, in: rangeStart...Date(), displayedComponents: .date)
                .font(.cwBody)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 14)
        }
        .background(Palette.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Palette.border, lineWidth: 1)
        )
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            TextEditor(text: Binding(
                get: { customPrompt },
                set: { customPrompt = String($0.prefix(maxPromptLength)) }
            ))
            .font(.cwBody)
            .foregroundStyle(Palette.ink)
            .focused($promptFocused)
            .frame(minHeight: 96)
            .padding(Spacing.sm)
            .background(Palette.white)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Palette.border, lineWidth: 1)
            )
            Text("e.g. \"Focus on whether I'm getting enough sleep\" or \"Compare weekdays vs weekends.\"")
                .font(.cwCaption)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(.cwCaption)
            .tracking(1.2)
            .foregroundStyle(Palette.muted)
    }

    /// Fire-and-forget: hand the work to the background coordinator and close.
    /// The report shows up in the list as "generating" and updates live.
    private func generate() {
        promptFocused = false
        ReportGenerationCoordinator.shared.enqueue(
            uid: uid,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            goals: goals,
            customPrompt: customPrompt
        )
        onClose()
    }
}

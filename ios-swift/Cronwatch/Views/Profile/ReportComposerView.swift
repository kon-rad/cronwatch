import SwiftUI

struct ReportComposerView: View {
    let uid: String
    let goals: [String]
    let onClose: () -> Void
    let onCreated: (ProfileReport) -> Void

    @State private var rangeStart: Date
    @State private var rangeEnd: Date
    @State private var customPrompt: String = ""
    @State private var generating: Bool = false
    @State private var errorMessage: String?
    @FocusState private var promptFocused: Bool

    private let maxPromptLength = 500

    init(uid: String, goals: [String], onClose: @escaping () -> Void, onCreated: @escaping (ProfileReport) -> Void) {
        self.uid = uid
        self.goals = goals
        self.onClose = onClose
        self.onCreated = onCreated
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

                        if let errorMessage {
                            errorBlock(errorMessage)
                        }
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
                        .disabled(generating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { Task { await generate() } }) {
                        if generating {
                            ProgressView()
                        } else {
                            Text("Generate").fontWeight(.semibold)
                        }
                    }
                    .disabled(generating || !rangeValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { promptFocused = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .interactiveDismissDisabled(generating)
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

    private func errorBlock(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Couldn’t generate")
                .font(.cwCaption.weight(.semibold))
                .foregroundStyle(Palette.danger)
            Text(message)
                .font(.cwCaption)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.danger.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }

    private func generate() async {
        guard !generating else { return }
        generating = true
        errorMessage = nil
        defer { generating = false }

        let cal = Calendar.current
        let normalizedStart = cal.startOfDay(for: rangeStart)
        guard let normalizedEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: rangeEnd))?
                .addingTimeInterval(-1) else {
            errorMessage = "Invalid date range."
            return
        }

        do {
            let entries = try await EntriesService.shared.fetchRange(
                uid: uid,
                from: normalizedStart,
                to: normalizedEnd
            )
            let days = RangeAggregator.aggregate(
                entries: entries,
                rangeStart: normalizedStart,
                rangeEnd: normalizedEnd
            )
            let trimmedPrompt = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let generated = try await ProfileReportGenerator.generate(
                rangeStart: normalizedStart,
                rangeEnd: normalizedEnd,
                goals: goals,
                customPrompt: trimmedPrompt.isEmpty ? nil : trimmedPrompt,
                days: days
            )
            let report = ProfileReport(
                id: ProfileReportsService.newReportId(),
                title: generated.title,
                html: generated.html,
                rangeStart: normalizedStart,
                rangeEnd: normalizedEnd,
                customPrompt: trimmedPrompt.isEmpty ? nil : trimmedPrompt,
                createdAt: Date()
            )
            try await ProfileReportsService.shared.save(uid: uid, report: report)
            onCreated(report)
        } catch {
            print("[ReportComposer] generate failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }
}

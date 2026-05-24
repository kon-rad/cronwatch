import SwiftUI

struct DashboardHeroCard: View {
    let todayEntries: [Entry]
    let rangeEntries: [Entry]
    let goals: [Goal]
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            coverageSection
                .padding(.top, Spacing.xs)

            let setGoals = goals.filter { $0.isSet }
            if setGoals.isEmpty {
                emptyGoalsSection
            } else {
                Divider()
                    .background(Palette.border)
                    .padding(.vertical, Spacing.md)
                goalsSection(setGoals)
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

    // MARK: - Header

    private var cardHeader: some View {
        HStack(alignment: .center) {
            Text("TODAY")
                .font(.cwCaption)
                .tracking(1.2)
                .foregroundStyle(Palette.muted)
            Spacer()
            Button(action: onEdit) {
                Text("Edit")
                    .font(.cwCaption.weight(.semibold))
                    .foregroundColor(Palette.amber)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Coverage

    private var coverageSection: some View {
        let pct = TimeUtils.trackedPercentOfDay(todayEntries, day: Date())
        let covMin = TimeUtils.coveredMinutesOfDay(todayEntries, day: Date())
        let isComplete = pct >= 100

        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text("\(pct)%")
                    .font(.system(size: 36, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Palette.amber)
                }
            }

            Text("\(TimeUtils.formatDuration(covMin)) of 24h tracked")
                .font(.cwCaption)
                .foregroundStyle(Palette.muted)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Palette.borderSoft)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Palette.amber)
                        .frame(
                            width: geo.size.width * CGFloat(min(1.0, Double(pct) / 100.0)),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
            .padding(.top, 2)
        }
    }

    // MARK: - Goals

    private var emptyGoalsSection: some View {
        Text("Tap Edit to set up to 3 weekly goals →")
            .font(.cwCaption)
            .foregroundStyle(Palette.muted)
            .padding(.top, Spacing.sm)
    }

    private func goalsSection(_ setGoals: [Goal]) -> some View {
        VStack(spacing: 10) {
            ForEach(setGoals, id: \.category) { goal in
                goalRow(goal)
            }
        }
    }

    private func goalRow(_ goal: Goal) -> some View {
        let targetMin = Int(goal.weeklyTargetHours * 60)
        let loggedMin = weeklyMinutes(for: goal.category)
        let progress = targetMin > 0 ? min(1.0, Double(loggedMin) / Double(targetMin)) : 0.0
        let isComplete = targetMin > 0 && loggedMin >= targetMin

        return HStack(spacing: Spacing.sm) {
            CategoryDotView(category: goal.category)

            Text(Categories.label(for: goal.category))
                .font(.cwBody)
                .foregroundStyle(Palette.ink)
                .frame(width: 90, alignment: .leading)
                .lineLimit(1)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Palette.borderSoft)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Categories.color(for: goal.category))
                        .frame(width: geo.size.width * CGFloat(progress), height: 6)
                }
            }
            .frame(height: 6)

            HStack(spacing: 4) {
                Text(progressLabel(logged: loggedMin, target: targetMin))
                    .font(.cwCaption)
                    .monospacedDigit()
                    .foregroundStyle(isComplete ? Palette.ink : Palette.muted)
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Categories.color(for: goal.category))
                }
            }
            .frame(width: 80, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    private var mondayOfCurrentWeek: Date {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: todayStart)
        // weekday: 1=Sunday, 2=Monday … 7=Saturday
        let daysSinceMonday = (weekday - 2 + 7) % 7
        return cal.date(byAdding: .day, value: -daysSinceMonday, to: todayStart) ?? todayStart
    }

    private func weeklyMinutes(for category: String) -> Int {
        let cal = Calendar.current
        let weekStart = mondayOfCurrentWeek
        guard let weekEnd = cal.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { return 0 }
        return rangeEntries
            .filter { $0.category == category }
            .reduce(0) { total, entry in
                let s = max(entry.startTime, weekStart)
                let e = min(entry.endTime, weekEnd)
                guard e > s else { return total }
                return total + Int(e.timeIntervalSince(s) / 60)
            }
    }

    private func progressLabel(logged: Int, target: Int) -> String {
        let loggedH = logged / 60
        let loggedM = logged % 60
        let targetH = target / 60
        let loggedStr = loggedM > 0 ? "\(loggedH)h \(loggedM)m" : "\(loggedH)h"
        return "\(loggedStr) / \(targetH)h"
    }
}

import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var auth: AuthService

    @State private var todayEntries: [Entry] = []
    @State private var rangeEntries: [Entry] = []
    @State private var cancelToday: (() -> Void)?
    @State private var cancelRange: (() -> Void)?

    private let streakDays = 21
    private let weeklyDays = 7

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Overview")
                        .font(.cwTitle)
                        .foregroundStyle(Palette.ink)

                    Text("How you've been spending your time.")
                        .font(.cwCaption)
                        .foregroundStyle(Palette.muted)
                        .padding(.top, 2)

                    donutCard
                        .padding(.top, Spacing.md)

                    weeklyHeader
                        .padding(.top, Spacing.lg)
                        .padding(.bottom, Spacing.sm)

                    barList

                    Text("TRACKING STREAK")
                        .font(.cwCaption)
                        .tracking(1.2)
                        .foregroundStyle(Palette.muted)
                        .padding(.top, Spacing.lg)

                    streakCard
                        .padding(.top, Spacing.sm)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
                .padding(.bottom, 160)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            startSubscriptions()
        }
        .onDisappear {
            cancelToday?(); cancelToday = nil
            cancelRange?(); cancelRange = nil
        }
    }

    private func startSubscriptions() {
        guard let uid = auth.currentUser?.uid else { return }

        cancelToday?()
        cancelToday = EntriesService.shared.subscribeToToday(uid: uid) { entries in
            todayEntries = entries
        }

        cancelRange?()
        let now = Date()
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: -(streakDays - 1), to: todayStart) ?? todayStart
        let windowEnd = TimeUtils.endOfToday(now)
        cancelRange = EntriesService.shared.subscribeToRange(uid: uid, from: windowStart, to: windowEnd) { entries in
            rangeEntries = entries
        }
    }

    // MARK: - Donut card

    private var slices: [(category: String, minutes: Int)] {
        var map: [String: Int] = [:]
        var order: [String] = []
        for entry in todayEntries {
            if map[entry.category] == nil { order.append(entry.category) }
            map[entry.category, default: 0] += TimeUtils.entryDurationMin(entry)
        }
        return order.map { ($0, map[$0] ?? 0) }
    }

    private var trackedMin: Int { slices.reduce(0) { $0 + $1.minutes } }
    private var distinct: Int { Set(todayEntries.map(\.category)).count }
    private var topSlice: (category: String, minutes: Int)? {
        slices.sorted { $0.minutes > $1.minutes }.first
    }

    private var donutCard: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            ZStack {
                DonutView(slices: slices, size: 120, thickness: 16)
                VStack(spacing: 0) {
                    Text("\(distinct)")
                        .font(.cwTitle)
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                    Text("CATEGORIES")
                        .font(.cwCaption)
                        .tracking(1)
                        .foregroundStyle(Palette.muted)
                }
            }
            .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 2) {
                Text("TODAY")
                    .font(.cwCaption)
                    .tracking(1)
                    .foregroundStyle(Palette.muted)
                Text(TimeUtils.formatDuration(trackedMin))
                    .font(.system(size: 28, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                Text("tracked of 24h")
                    .font(.cwCaption)
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 2)

                if let top = topSlice {
                    HStack(spacing: Spacing.xs) {
                        CategoryDotView(category: top.category)
                        Text("Most: \(Categories.label(for: top.category))")
                            .font(.cwCaption)
                            .foregroundStyle(Palette.ink)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Palette.borderSoft)
                    .clipShape(Capsule())
                    .padding(.top, Spacing.sm)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.md)
        .background(Palette.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Palette.border, lineWidth: 1)
        )
    }

    // MARK: - Weekly average

    private var weeklyRows: [(category: String, minutes: Int)] {
        Streak.weeklyAverage(entries: rangeEntries, days: weeklyDays)
    }

    private var weeklyTotalMin: Int { weeklyRows.reduce(0) { $0 + $1.minutes } }

    private var weeklyHeader: some View {
        HStack {
            Text("THIS WEEK · DAILY AVERAGE")
                .font(.cwCaption)
                .tracking(1.2)
                .foregroundStyle(Palette.muted)
            Spacer()
            Text("\(weeklyTotalMin / 60)h/day")
                .font(.cwCaption)
                .monospacedDigit()
                .foregroundStyle(Palette.muted)
        }
    }

    private var barList: some View {
        let rows = weeklyRows
        let maxHours = max(0.1, Double(rows.map(\.minutes).max() ?? 1) / 60.0)
        return VStack(spacing: 10) {
            if rows.isEmpty {
                Text("No entries in the last 7 days.")
                    .font(.cwCaption)
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(rows, id: \.category) { row in
                    BarRow(
                        category: row.category,
                        hours: Double(row.minutes) / 60.0,
                        maxHours: maxHours
                    )
                }
            }
        }
    }

    // MARK: - Streak card

    private var dayFlags: [Bool] {
        Streak.computeDayFlags(entries: rangeEntries, days: streakDays)
    }

    private var streak: Int {
        Streak.currentStreak(from: dayFlags)
    }

    private var streakCard: some View {
        let flags = dayFlags
        let count = streak
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(count) \(count == 1 ? "day" : "days")")
                    .font(.system(size: 24, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("last \(streakDays) days")
                    .font(.cwCaption)
                    .foregroundStyle(Palette.muted)
            }
            HStack(spacing: 3) {
                ForEach(flags.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(flags[index] ? Palette.amber : Palette.border)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                }
            }
            .padding(.top, Spacing.sm)
        }
        .padding(Spacing.md)
        .background(Palette.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Palette.border, lineWidth: 1)
        )
    }
}

private struct BarRow: View {
    let category: String
    let hours: Double
    let maxHours: Double

    var body: some View {
        HStack(spacing: Spacing.sm) {
            CategoryDotView(category: category)
            Text(Categories.label(for: category))
                .font(.cwBody)
                .foregroundStyle(Palette.ink)
                .frame(width: 80, alignment: .leading)
            GeometryReader { geo in
                let pct = max(0.02, min(1.0, hours / max(maxHours, 0.0001)))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Palette.borderSoft)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Categories.color(for: category))
                        .frame(width: geo.size.width * CGFloat(pct), height: 6)
                }
                .frame(height: 6)
            }
            .frame(height: 6)
            Text(String(format: "%.1fh", hours))
                .font(.cwCaption)
                .monospacedDigit()
                .foregroundStyle(Palette.muted)
                .frame(width: 36, alignment: .trailing)
        }
    }
}

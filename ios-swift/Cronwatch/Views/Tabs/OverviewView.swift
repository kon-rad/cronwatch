import SwiftUI

private enum OverviewPeriod: CaseIterable {
    case today, thisWeek, thisMonth, allTime

    var label: String {
        switch self {
        case .today:     return "TODAY"
        case .thisWeek:  return "THIS WEEK"
        case .thisMonth: return "THIS MONTH"
        case .allTime:   return "ALL TIME"
        }
    }

    var shortLabel: String {
        switch self {
        case .today:     return "Today"
        case .thisWeek:  return "This Week"
        case .thisMonth: return "This Month"
        case .allTime:   return "All Time"
        }
    }

    var subtitle: String {
        switch self {
        case .today:     return "tracked of 24h"
        case .thisWeek:  return "tracked this week"
        case .thisMonth: return "tracked this month"
        case .allTime:   return "tracked total"
        }
    }
}

struct OverviewView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var rc: RevenueCatService

    @State private var showPaywall = false
    @State private var todayEntries: [Entry] = []
    @State private var rangeEntries: [Entry] = []
    @State private var allTimeEntries: [Entry] = []
    @State private var cancelToday: (() -> Void)?
    @State private var cancelRange: (() -> Void)?
    @State private var cancelAllTime: (() -> Void)?

    @State private var settings: UserSettings = .empty
    @State private var cancelSettings: (() -> Void)?
    @State private var showGoalsEditor: Bool = false

    @State private var showReportComposer: Bool = false
    @State private var openReportDetail: ProfileReport?

    @State private var selectedPeriod: OverviewPeriod = .today
    @State private var dayTick: Date = Date()

    private let streakDays = 21
    private let weeklyDays = 7
    private let bestsDays = 90

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    DashboardHeroCard(
                        todayEntries: todayEntries,
                        rangeEntries: rangeEntries,
                        goals: settings.goals,
                        onEdit: { showGoalsEditor = true }
                    )
                    .padding(.bottom, Spacing.md)

                    Text("Overview")
                        .font(.cwTitle)
                        .foregroundStyle(Palette.ink)

                    Text("How you've been spending your time.")
                        .font(.cwCaption)
                        .foregroundStyle(Palette.muted)
                        .padding(.top, 2)

                    donutCard
                        .padding(.top, Spacing.md)

                    periodTabs
                        .padding(.top, Spacing.sm)

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

                    monthHeader
                        .padding(.top, Spacing.lg)
                        .padding(.bottom, Spacing.sm)

                    MonthlyHeatmapView(entries: rangeEntries)

                    PersonalBestsView(entries: rangeEntries, windowDays: bestsDays)
                        .padding(.top, Spacing.lg)
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
            cancelSettings?(); cancelSettings = nil
            cancelAllTime?(); cancelAllTime = nil
        }
        .onChange(of: selectedPeriod) { _, newPeriod in
            if newPeriod == .allTime {
                startAllTimeSubscription()
            } else {
                cancelAllTime?(); cancelAllTime = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            dayTick = Date()
            startSubscriptions()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showGoalsEditor) {
            if let uid = auth.currentUser?.uid {
                GoalsEditorView(uid: uid, initial: settings) {
                    showGoalsEditor = false
                }
            }
        }
        .sheet(isPresented: $showReportComposer) {
            if let uid = auth.currentUser?.uid {
                ReportComposerView(
                    uid: uid,
                    goals: reportGoals,
                    onClose: { showReportComposer = false },
                    onCreated: { newReport in
                        showReportComposer = false
                        openReportDetail = newReport
                    }
                )
            }
        }
        .fullScreenCover(item: $openReportDetail) { report in
            ReportDetailView(report: report) { openReportDetail = nil }
        }
    }

    /// Goals formatted as the free-text strings the report generator expects,
    /// matching the format used by ProfileReportsSection.
    private var reportGoals: [String] {
        settings.goals
            .filter { $0.isSet }
            .map { goal -> String in
                let label = Categories.label(for: goal.category)
                let hrs = goal.weeklyTargetHours.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(goal.weeklyTargetHours))h"
                    : String(format: "%.1fh", goal.weeklyTargetHours)
                return "\(label): \(hrs)/week"
            }
    }

    private func startSubscriptions() {
        guard let uid = auth.currentUser?.uid else { return }

        cancelSettings?()
        cancelSettings = UserSettingsService.shared.subscribe(uid: uid) { newSettings in
            settings = newSettings
        }

        cancelToday?()
        cancelToday = EntriesService.shared.subscribeToToday(uid: uid) { entries in
            todayEntries = entries
        }

        cancelRange?()
        let now = Date()
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        // Range must cover: streak (21d), weekly avg (7d), monthly heatmap
        // (start of current month) and personal bests (90d). Take the
        // earliest of these as the lower bound.
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? todayStart
        let bestsStart = calendar.date(byAdding: .day, value: -(bestsDays - 1), to: todayStart) ?? todayStart
        let windowStart = min(monthStart, bestsStart)
        let windowEnd = TimeUtils.endOfToday(now)
        cancelRange = EntriesService.shared.subscribeToRange(uid: uid, from: windowStart, to: windowEnd) { entries in
            rangeEntries = entries
        }
    }

    private func startAllTimeSubscription() {
        guard let uid = auth.currentUser?.uid else { return }
        cancelAllTime?()
        let origin = Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 1)) ?? Date()
        cancelAllTime = EntriesService.shared.subscribeToRange(uid: uid, from: origin, to: Date.distantFuture) { entries in
            allTimeEntries = entries
        }
    }

    // MARK: - Donut card

    private var entriesForPeriod: [Entry] {
        let cal = Calendar.current
        switch selectedPeriod {
        case .today:
            return todayEntries
        case .thisWeek:
            let todayStart = cal.startOfDay(for: dayTick)
            let weekStart = cal.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
            return rangeEntries.filter { $0.startTime >= weekStart }
        case .thisMonth:
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: dayTick)) ?? cal.startOfDay(for: dayTick)
            return rangeEntries.filter { $0.startTime >= monthStart }
        case .allTime:
            return allTimeEntries
        }
    }

    private func cyclePeriod(forward: Bool) {
        let all = OverviewPeriod.allCases
        guard let idx = all.firstIndex(of: selectedPeriod) else { return }
        let next = forward ? (idx + 1) % all.count : (idx - 1 + all.count) % all.count
        selectedPeriod = all[next]
    }

    private var periodTabs: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(OverviewPeriod.allCases, id: \.self) { period in
                Button {
                    selectedPeriod = period
                } label: {
                    Text(period.shortLabel)
                        .font(.cwCaption)
                        .tracking(0.4)
                        .foregroundStyle(selectedPeriod == period ? Palette.ink : Palette.muted)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 6)
                        .background(selectedPeriod == period ? Palette.white : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .stroke(selectedPeriod == period ? Palette.border : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xs)
        .background(Palette.borderSoft)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
    }

    private var slices: [(category: String, minutes: Int)] {
        var map: [String: Int] = [:]
        var order: [String] = []
        for entry in entriesForPeriod {
            if map[entry.category] == nil { order.append(entry.category) }
            map[entry.category, default: 0] += TimeUtils.entryDurationMin(entry)
        }
        return order.map { ($0, map[$0] ?? 0) }
    }

    private var trackedMin: Int { slices.reduce(0) { $0 + $1.minutes } }
    private var distinct: Int { Set(entriesForPeriod.map(\.category)).count }
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
                Text(selectedPeriod.label)
                    .font(.cwCaption)
                    .tracking(1)
                    .foregroundStyle(Palette.muted)

                Text(TimeUtils.formatDuration(trackedMin))
                    .font(.system(size: 28, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                Text(selectedPeriod.subtitle)
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
        Streak.weeklyAverage(entries: rangeEntries, days: weeklyDays, now: dayTick)
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

    // MARK: - Month / bests headers

    private var monthTotalHours: Int {
        MonthlyStats.monthDays(entries: rangeEntries).reduce(0) { $0 + $1.totalMin } / 60
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: Date()).uppercased()
    }

    private var monthHeader: some View {
        HStack {
            Text(monthLabel)
                .font(.cwCaption)
                .tracking(1.2)
                .foregroundStyle(Palette.muted)
            Spacer()
            Text("\(monthTotalHours)h tracked")
                .font(.cwCaption)
                .monospacedDigit()
                .foregroundStyle(Palette.muted)
        }
    }

    private var bestsHeader: some View {
        HStack {
            Text("PERSONAL BESTS")
                .font(.cwCaption)
                .tracking(1.2)
                .foregroundStyle(Palette.muted)
            Spacer()
            Text("last \(bestsDays) days")
                .font(.cwCaption)
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
        Streak.computeDayFlags(entries: rangeEntries, days: streakDays, now: dayTick)
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
                    let isToday = index == flags.count - 1
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isToday ? Color.clear : (flags[index] ? Palette.amber : Palette.border))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isToday ? Palette.amber : Color.clear, lineWidth: 1.5)
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                }
            }
            .padding(.top, Spacing.sm)

            Button(action: openReportComposer) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "sparkles")
                    Text("Generate report")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .opacity(0.7)
                }
                .font(.cwBody)
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, 12)
                .background(Palette.amber)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
            .buttonStyle(.plain)
            .padding(.top, Spacing.md)
        }
        .padding(Spacing.md)
        .background(Palette.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Palette.border, lineWidth: 1)
        )
    }

    private func openReportComposer() {
        if rc.entitlement == .free {
            showPaywall = true
            return
        }
        showReportComposer = true
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

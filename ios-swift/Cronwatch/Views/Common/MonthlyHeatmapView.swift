import SwiftUI

struct MonthlyHeatmapView: View {
    let entries: [Entry]
    var now: Date = Date()

    @State private var selectedDate: Date?

    private var monthDays: [MonthlyStats.DayStat] {
        MonthlyStats.monthDays(entries: entries, now: now)
    }

    private var maxMin: Int {
        max(60, monthDays.map(\.totalMin).max() ?? 60)
    }

    private var todayStart: Date {
        Calendar.current.startOfDay(for: now)
    }

    private var leadingBlanks: Int {
        let cal = Calendar.current
        guard let first = monthDays.first?.date else { return 0 }
        let weekday = cal.component(.weekday, from: first)  // 1 = Sunday
        return (weekday - cal.firstWeekday + 7) % 7
    }

    private var totalCells: Int {
        let raw = leadingBlanks + monthDays.count
        return raw + ((7 - raw % 7) % 7)
    }

    private var weekdayLabels: [String] {
        let cal = Calendar.current
        let symbols = cal.veryShortWeekdaySymbols
        let start = (cal.firstWeekday - 1) % symbols.count
        return Array(symbols[start...] + symbols[..<start])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            weekdayRow
                .padding(.bottom, Spacing.sm)
            grid
            footer
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

    private var weekdayRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                Text(weekdayLabels[i])
                    .font(.cwCaption)
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        let blanks = leadingBlanks
        let total = totalCells
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<total, id: \.self) { idx in
                let dayIdx = idx - blanks
                if dayIdx < 0 || dayIdx >= monthDays.count {
                    Color.clear.aspectRatio(1, contentMode: .fit)
                } else {
                    cell(for: monthDays[dayIdx])
                }
            }
        }
    }

    private func cell(for stat: MonthlyStats.DayStat) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDate(stat.date, inSameDayAs: now)
        let isFuture = stat.date > todayStart
        let isSelected = selectedDate.map { cal.isDate($0, inSameDayAs: stat.date) } ?? false
        let isFullyCovered = stat.coveredMin >= 24 * 60
        let day = cal.component(.day, from: stat.date)

        let fillColor: Color
        let opacity: Double
        if let dom = stat.dominantCategory, stat.totalMin > 0 {
            fillColor = Categories.color(for: dom)
            if isFullyCovered {
                opacity = 1.0
            } else {
                let frac = Double(stat.totalMin) / Double(maxMin)
                opacity = 0.18 + 0.72 * min(1, frac)
            }
        } else {
            fillColor = Palette.borderSoft
            opacity = isFuture ? 0.4 : 1.0
        }

        let strokeColor: Color = {
            if isSelected { return Palette.ink }
            if isToday { return Palette.amber }
            return .clear
        }()
        let strokeWidth: CGFloat = isSelected ? 2 : (isToday ? 1.5 : 0)

        return Button {
            if isSelected {
                selectedDate = nil
            } else {
                selectedDate = stat.date
            }
        } label: {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(fillColor.opacity(opacity))
                Text("\(day)")
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(stat.totalMin > 0 ? Palette.ink.opacity(0.7) : Palette.muted)
                    .padding(4)
                if isFullyCovered {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var footer: some View {
        if let sel = selectedDate,
           let stat = monthDays.first(where: { Calendar.current.isDate($0.date, inSameDayAs: sel) }) {
            HStack(spacing: Spacing.sm) {
                if let dom = stat.dominantCategory {
                    CategoryDotView(category: dom)
                }
                Text(dateLabel(stat.date))
                    .font(.cwBody)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(detailLabel(stat))
                    .font(.cwCaption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.muted)
            }
        } else {
            HStack {
                Text(summaryLabel)
                    .font(.cwCaption)
                    .foregroundStyle(Palette.muted)
                Spacer()
            }
        }
    }

    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private func detailLabel(_ stat: MonthlyStats.DayStat) -> String {
        if stat.totalMin == 0 { return "No entries" }
        let dur = TimeUtils.formatDuration(stat.totalMin)
        if let dom = stat.dominantCategory {
            return "\(Categories.label(for: dom)) most · \(dur)"
        }
        return dur
    }

    private var summaryLabel: String {
        let tracked = monthDays.filter { $0.totalMin > 0 }.count
        let elapsed = monthDays.filter { $0.date <= todayStart }.count
        let fullyCovered = monthDays.filter { $0.coveredMin >= 24 * 60 }.count
        if elapsed == 0 { return "—" }
        let base = "\(tracked) of \(elapsed) days tracked"
        if fullyCovered > 0 { return "\(base) · \(fullyCovered) fully covered" }
        return base
    }
}

import SwiftUI

struct MonthGridView: View {
    let entries: [Entry]
    let anchorDate: Date
    var onSelectDay: (Date) -> Void = { _ in }

    private var monthStart: Date {
        Calendar.current.dateInterval(of: .month, for: anchorDate)?.start
            ?? Calendar.current.startOfDay(for: anchorDate)
    }

    private var monthEnd: Date {
        Calendar.current.dateInterval(of: .month, for: anchorDate)?.end
            ?? Calendar.current.startOfDay(for: anchorDate)
    }

    private var gridStart: Date {
        let cal = Calendar.current
        return cal.dateInterval(of: .weekOfYear, for: monthStart)?.start ?? monthStart
    }

    private var weeks: [[Date]] {
        let cal = Calendar.current
        var result: [[Date]] = []
        for w in 0..<6 {
            var row: [Date] = []
            for d in 0..<7 {
                let offset = w * 7 + d
                if let day = cal.date(byAdding: .day, value: offset, to: gridStart) {
                    row.append(day)
                }
            }
            result.append(row)
        }
        return result
    }

    private func entriesFor(day: Date) -> [Entry] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        return entries.filter { $0.startTime < dayEnd && $0.endTime > dayStart }
    }

    var body: some View {
        VStack(spacing: 0) {
            weekdayHeader

            GeometryReader { geo in
                let cellWidth = geo.size.width / 7
                let cellHeight = geo.size.height / 6
                VStack(spacing: 0) {
                    ForEach(weeks.indices, id: \.self) { w in
                        HStack(spacing: 0) {
                            ForEach(weeks[w], id: \.self) { day in
                                dayCell(day, width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
    }

    private var weekdayHeader: some View {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        let symbols: [String] = {
            // Reorder weekday symbols so first weekday lines up with first column
            let first = cal.firstWeekday - 1
            let base = formatter.veryShortWeekdaySymbols ?? ["S","M","T","W","T","F","S"]
            return Array(base[first...]) + Array(base[..<first])
        }()

        return HStack(spacing: 0) {
            ForEach(symbols.indices, id: \.self) { i in
                Text(symbols[i].uppercased())
                    .font(.cwCaption)
                    .foregroundColor(Palette.muted)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func dayCell(_ day: Date, width: CGFloat, height: CGFloat) -> some View {
        let cal = Calendar.current
        let isCurrentMonth = cal.isDate(day, equalTo: monthStart, toGranularity: .month)
        let isToday = cal.isDateInToday(day)
        let dayNum = cal.component(.day, from: day)
        let dayEntries = entriesFor(day: day)
        let stripHeight = max(0, height - 22)

        return Button(action: { onSelectDay(day) }) {
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text("\(dayNum)")
                        .font(.system(size: 11, weight: isToday ? .bold : .regular))
                        .monospacedDigit()
                        .foregroundColor(
                            isToday ? Palette.amber :
                            (isCurrentMonth ? Palette.ink : Palette.muted.opacity(0.6))
                        )
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            isToday ? Palette.amber.opacity(0.12) : Color.clear
                        )
                        .clipShape(Capsule())
                    Spacer()
                }

                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Palette.white.opacity(isCurrentMonth ? 1.0 : 0.4))

                    ForEach(dayEntries) { entry in
                        if let clip = TimeUtils.clipMinutesOfDay(entry, day: day) {
                            dayMiniBlock(entry: entry, clip: clip, stripHeight: stripHeight, width: width - 4)
                        }
                    }
                }
                .frame(height: stripHeight)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .padding(2)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(Palette.bg)
            .overlay(
                Rectangle()
                    .stroke(Palette.borderSoft, lineWidth: 0.5)
            )
            .opacity(isCurrentMonth ? 1.0 : 0.85)
        }
        .buttonStyle(.plain)
    }

    private func dayMiniBlock(entry: Entry, clip: (startMin: Int, endMin: Int), stripHeight: CGFloat, width: CGFloat) -> some View {
        let pxPerMin = stripHeight / CGFloat(24 * 60)
        let startMin = clip.startMin
        let durMin = max(1, clip.endMin - clip.startMin)
        let top = CGFloat(startMin) * pxPerMin
        let height = max(1, CGFloat(durMin) * pxPerMin)
        let color = Categories.color(for: entry.category)
        return Rectangle()
            .fill(color.opacity(0.85))
            .frame(width: width, height: height)
            .offset(y: top)
    }
}

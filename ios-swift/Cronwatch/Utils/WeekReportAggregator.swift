import Foundation

enum WeekReportAggregator {
    /// Returns 7 days of per-category minutes ending today (most recent last).
    /// Minutes are clipped to each day window, so entries that cross midnight
    /// contribute to both adjacent days proportionally.
    static func aggregate(entries: [Entry], now: Date = Date(), calendar: Calendar = .current) -> [DayAggregate] {
        let todayStart = calendar.startOfDay(for: now)
        let isoDay = DateFormatter()
        isoDay.calendar = calendar
        isoDay.locale = Locale(identifier: "en_US_POSIX")
        isoDay.dateFormat = "yyyy-MM-dd"

        var result: [DayAggregate] = []
        for index in stride(from: 6, through: 0, by: -1) {
            guard let dayStart = calendar.date(byAdding: .day, value: -index, to: todayStart),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                continue
            }

            var totals: [String: Int] = [:]
            var order: [String] = []
            for entry in entries {
                let start = max(entry.startTime, dayStart)
                let end = min(entry.endTime, dayEnd)
                guard end > start else { continue }
                let minutes = Int(end.timeIntervalSince(start) / 60.0)
                guard minutes > 0 else { continue }
                if totals[entry.category] == nil { order.append(entry.category) }
                totals[entry.category, default: 0] += minutes
            }

            let categories = order.map { CategoryMinutes(name: $0, minutes: totals[$0] ?? 0) }
            result.append(DayAggregate(date: isoDay.string(from: dayStart), categories: categories))
        }
        return result
    }
}

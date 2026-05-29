import Foundation

enum RangeAggregator {
    /// Aggregates entries into per-day per-category minutes across an inclusive
    /// date range. Entries that span midnight contribute to each touched day
    /// proportionally (overlap with the day window).
    static func aggregate(
        entries: [Entry],
        rangeStart: Date,
        rangeEnd: Date,
        calendar: Calendar = .current
    ) -> [DayAggregate] {
        let startDay = calendar.startOfDay(for: rangeStart)
        let endDayInclusive = calendar.startOfDay(for: rangeEnd)
        guard endDayInclusive >= startDay else { return [] }

        let isoDay = DateFormatter()
        isoDay.calendar = calendar
        isoDay.locale = Locale(identifier: "en_US_POSIX")
        isoDay.dateFormat = "yyyy-MM-dd"

        var result: [DayAggregate] = []
        var cursor = startDay
        while cursor <= endDayInclusive {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }

            var totals: [String: Int] = [:]
            var order: [String] = []
            for entry in entries {
                let start = max(entry.startTime, cursor)
                let end = min(entry.endTime, nextDay)
                guard end > start else { continue }
                let minutes = Int(end.timeIntervalSince(start) / 60.0)
                guard minutes > 0 else { continue }
                if totals[entry.category] == nil { order.append(entry.category) }
                totals[entry.category, default: 0] += minutes
            }

            let categories = order.map { CategoryMinutes(name: $0, minutes: totals[$0] ?? 0) }
            result.append(DayAggregate(date: isoDay.string(from: cursor), categories: categories))
            cursor = nextDay
        }
        return result
    }
}

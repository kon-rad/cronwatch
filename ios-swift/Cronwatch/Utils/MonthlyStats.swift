import Foundation

enum MonthlyStats {
    struct DayStat: Hashable {
        let date: Date              // start of day
        let totalMin: Int           // capped at 24h, sum of per-category minutes
        let coveredMin: Int         // union-merged minutes (overlapping entries don't double-count)
        let dominantCategory: String?
        let perCategory: [String: Int]
    }

    /// One DayStat per day of the calendar month containing `now`.
    static func monthDays(entries: [Entry], now: Date = Date()) -> [DayStat] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: now)
        guard let monthStart = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: now) else { return [] }

        var stats: [DayStat] = []
        for i in 0..<range.count {
            guard let dayStart = cal.date(byAdding: .day, value: i, to: monthStart),
                  let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            var perCategory: [String: Int] = [:]
            for entry in entries {
                let start = max(entry.startTime, dayStart)
                let end = min(entry.endTime, dayEnd)
                guard end > start else { continue }
                let mins = Int(end.timeIntervalSince(start) / 60)
                if mins > 0 {
                    perCategory[entry.category, default: 0] += mins
                }
            }
            let total = min(24 * 60, perCategory.values.reduce(0, +))
            let covered = min(24 * 60, Streak.coveredMinutes(entries, from: dayStart, to: dayEnd))
            let dominant = perCategory.max { $0.value < $1.value }?.key

            stats.append(DayStat(
                date: dayStart,
                totalMin: total,
                coveredMin: covered,
                dominantCategory: dominant,
                perCategory: perCategory
            ))
        }
        return stats
    }
}

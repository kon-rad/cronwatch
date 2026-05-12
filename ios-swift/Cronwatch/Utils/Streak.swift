import Foundation

enum Streak {
    static let coveragePerDayMin = 24 * 60

    /// Returns true if the date's day-window has at least `coveragePerDayMin`
    /// minutes covered by the entries (union-merged, clipped to the window).
    static func coveredMinutes(_ entries: [Entry], from windowStart: Date, to windowEnd: Date) -> Int {
        var intervals: [(start: Date, end: Date)] = []
        for entry in entries {
            let start = max(entry.startTime, windowStart)
            let end = min(entry.endTime, windowEnd)
            if end > start { intervals.append((start, end)) }
        }
        intervals.sort { $0.start < $1.start }

        var totalSeconds: TimeInterval = 0
        var currentStart: Date?
        var currentEnd: Date?

        for slot in intervals {
            if let lastEnd = currentEnd, let lastStart = currentStart, slot.start <= lastEnd {
                currentEnd = max(lastEnd, slot.end)
                currentStart = lastStart
            } else {
                if let start = currentStart, let end = currentEnd, end > start {
                    totalSeconds += end.timeIntervalSince(start)
                }
                currentStart = slot.start
                currentEnd = slot.end
            }
        }
        if let start = currentStart, let end = currentEnd, end > start {
            totalSeconds += end.timeIntervalSince(start)
        }
        return Int((totalSeconds / 60.0).rounded())
    }

    static func computeDayFlags(entries: [Entry], days: Int, now: Date = Date()) -> [Bool] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        var flags: [Bool] = []
        for index in stride(from: days - 1, through: 0, by: -1) {
            guard let dayStart = calendar.date(byAdding: .day, value: -index, to: todayStart),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                flags.append(false)
                continue
            }
            let covered = coveredMinutes(entries, from: dayStart, to: dayEnd)
            flags.append(covered >= coveragePerDayMin)
        }
        return flags
    }

    static func currentStreak(from flags: [Bool]) -> Int {
        var streak = 0
        for flag in flags.reversed() {
            if flag { streak += 1 } else { break }
        }
        return streak
    }

    /// Average minutes per category across the last `days` days.
    static func weeklyAverage(entries: [Entry], days: Int = 7, now: Date = Date()) -> [(category: String, minutes: Int)] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        guard let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart),
              let windowEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) else {
            return []
        }

        var totals: [String: Int] = [:]
        var order: [String] = []
        for entry in entries {
            let start = max(entry.startTime, windowStart)
            let end = min(entry.endTime, windowEnd)
            guard end > start else { continue }
            let minutes = Int(end.timeIntervalSince(start) / 60.0)
            if totals[entry.category] == nil { order.append(entry.category) }
            totals[entry.category, default: 0] += minutes
        }
        return order.map { ($0, (totals[$0] ?? 0) / max(days, 1)) }
    }
}

import Foundation

enum PersonalBests {
    /// Fixed slide order for the home-screen carousel.
    static let presetCategories: [String] = ["work", "exercise", "sleep"]

    /// Day with the highest total minutes for `category` within the window,
    /// splitting entries that cross midnight.
    static func bestDay(for category: String, entries: [Entry],
                        windowDays: Int = 90, now: Date = Date()) -> (date: Date, minutes: Int)? {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)
        guard let windowStart = cal.date(byAdding: .day, value: -(windowDays - 1), to: todayStart),
              let windowEnd = cal.date(byAdding: .day, value: 1, to: todayStart) else {
            return nil
        }

        var perDay: [Date: Int] = [:]
        for entry in entries where entry.category == category {
            var cursor = cal.startOfDay(for: max(entry.startTime, windowStart))
            while cursor < entry.endTime, cursor < windowEnd {
                guard let nextDay = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
                let segStart = max(entry.startTime, cursor)
                let segEnd = min(entry.endTime, nextDay, windowEnd)
                if segEnd > segStart {
                    let mins = Int(segEnd.timeIntervalSince(segStart) / 60)
                    if mins > 0 { perDay[cursor, default: 0] += mins }
                }
                cursor = nextDay
            }
        }

        guard let top = perDay.max(by: { $0.value < $1.value }), top.value > 0 else {
            return nil
        }
        return (top.key, top.value)
    }
}

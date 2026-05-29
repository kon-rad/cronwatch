import Foundation

enum TimeUtils {
    static let minPerDay = 24 * 60

    static func minutesSinceMidnight(_ date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    static func entryDurationMin(_ entry: Entry) -> Int {
        max(15, Int(round(entry.endTime.timeIntervalSince(entry.startTime) / 60)))
    }

    static func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    static func formatLongDate(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: date)
    }

    static func formatHHmm(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
    }

    static func formatTimeOfDay(_ minutesOfDay: Int) -> String {
        let hour = (minutesOfDay / 60) % 24
        let minute = minutesOfDay % 60
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let date = Calendar.current.date(from: comps) ?? Date()
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f.string(from: date).lowercased()
    }

    static func snapTo15(_ minutes: Int) -> Int {
        Int(round(Double(minutes) / 15)) * 15
    }

    // All standard locale UTC offsets are multiples of 15 minutes, so snapping
    // on the absolute Unix epoch yields the same local-clock boundary.
    static let slotSeconds: TimeInterval = 15 * 60

    static func snapTo15(_ date: Date) -> Date {
        let snapped = (date.timeIntervalSince1970 / slotSeconds).rounded() * slotSeconds
        return Date(timeIntervalSince1970: snapped)
    }

    static func totalTrackedMin(_ entries: [Entry]) -> Int {
        entries.reduce(0) { $0 + entryDurationMin($1) }
    }

    // Minutes of `day` covered by the union of entry intervals (0...1440).
    // Overlapping segments are counted once, so this represents actual
    // wall-clock coverage rather than a sum of durations.
    static func coveredMinutesOfDay(_ entries: [Entry], day: Date) -> Int {
        var intervals: [(Int, Int)] = []
        for e in entries {
            if let c = clipMinutesOfDay(e, day: day) {
                intervals.append((c.startMin, c.endMin))
            }
        }
        guard !intervals.isEmpty else { return 0 }
        intervals.sort { $0.0 < $1.0 }
        var total = 0
        var curStart = intervals[0].0
        var curEnd = intervals[0].1
        for (s, e) in intervals.dropFirst() {
            if s <= curEnd {
                curEnd = max(curEnd, e)
            } else {
                total += curEnd - curStart
                curStart = s
                curEnd = e
            }
        }
        total += curEnd - curStart
        return total
    }

    static func trackedPercentOfDay(_ entries: [Entry], day: Date) -> Int {
        let covered = coveredMinutesOfDay(entries, day: day)
        return min(100, Int(round(Double(covered) / Double(minPerDay) * 100)))
    }

    static func startOfToday(_ now: Date = Date()) -> Date {
        Calendar.current.startOfDay(for: now)
    }

    static func endOfToday(_ now: Date = Date()) -> Date {
        let start = Calendar.current.startOfDay(for: now)
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return nextDay.addingTimeInterval(-0.001)
    }

    static func minutesOfDay(of date: Date) -> Int {
        minutesSinceMidnight(date)
    }

    static func date(_ baseDate: Date, withMinutesOfDay totalMin: Int) -> Date {
        let hour = (totalMin / 60) % 24
        let minute = totalMin % 60
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate) ?? baseDate
    }

    // Returns the portion of the entry that falls within `day` as minutes-
    // since-midnight, or nil if the entry doesn't intersect the day. Used by
    // grid views so an entry spanning midnight renders on both days, each
    // showing only its slice.
    static func clipMinutesOfDay(_ entry: Entry, day: Date) -> (startMin: Int, endMin: Int)? {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        let start = max(entry.startTime, dayStart)
        let end = min(entry.endTime, dayEnd)
        guard end > start else { return nil }
        let startMin = Int(start.timeIntervalSince(dayStart) / 60)
        let endMin = Int(end.timeIntervalSince(dayStart) / 60)
        return (startMin, endMin)
    }
}

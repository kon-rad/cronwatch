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

    static func totalTrackedMin(_ entries: [Entry]) -> Int {
        entries.reduce(0) { $0 + entryDurationMin($1) }
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
}

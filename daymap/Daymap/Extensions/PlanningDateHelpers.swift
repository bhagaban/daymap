import Foundation

enum PlanningDateHelpers {
    static let calendar = Calendar.current

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    static func minutesFromMidnight(_ date: Date) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func dateByMerging(day baseDay: Date, timeFrom source: Date) -> Date {
        let day = startOfDay(baseDay)
        let c = calendar.dateComponents([.hour, .minute, .second], from: source)
        return calendar.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: c.second ?? 0, of: day) ?? day
    }

    static func combine(day: Date, minutesFromMidnight: Int) -> Date {
        let start = startOfDay(day)
        return calendar.date(byAdding: .minute, value: minutesFromMidnight, to: start) ?? start
    }

    static func addMinutes(_ minutes: Int, to date: Date) -> Date {
        calendar.date(byAdding: .minute, value: minutes, to: date) ?? date
    }

    static func snapMinutes(_ date: Date, step: Int = 5) -> Date {
        let m = minutesFromMidnight(date)
        let snapped = ((m + step / 2) / step) * step
        return combine(day: date, minutesFromMidnight: snapped)
    }
    
    static func nextHour(_ date: Date) -> Date {
        let cal = calendar
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let startOfHour = cal.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        if minute == 0 {
            return startOfHour
        }
        return cal.date(byAdding: .hour, value: 1, to: startOfHour) ?? date
    }

    static func weekInterval(containing date: Date) -> (start: Date, end: Date) {
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return (start, end)
    }

    static func daysInWeek(containing date: Date) -> [Date] {
        let (start, _) = weekInterval(containing: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// Returns the 7 days for the week containing `date`, ordered Monday → Sunday.
    static func daysInWeekMondayFirst(containing date: Date) -> [Date] {
        let cal = calendar
        let day = startOfDay(date)
        let weekday = cal.component(.weekday, from: day) // 1=Sun ... 7=Sat
        // Convert to Monday-based index: Mon=0 ... Sun=6
        let mondayIndex = (weekday + 5) % 7
        let monday = cal.date(byAdding: .day, value: -mondayIndex, to: day) ?? day
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }
}

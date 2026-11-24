import Foundation

struct ZonedDateTime: Equatable {
    var day: String
    var time: String
}

// all time stuff goes through berlin
enum BerlinTime {
    static let timeZone = TimeZone(identifier: "Europe/Berlin")!
    static let locale = Locale(identifier: "de_DE")

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        calendar.firstWeekday = 2
        return calendar
    }()

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }

    private static let isoOutput = formatter("yyyy-MM-dd'T'HH:mm:ssxxx")
    private static let dayFormatter = formatter("yyyy-MM-dd")
    private static let timeFormatter = formatter("HH:mm")
    private static let shortDayFormatter = formatter("EEE, dd.MM.")
    private static let longDayFormatter = formatter("EEEE, d. MMMM yyyy")
    private static let weekdayFormatter = formatter("ccc") // "Mo", "Di" etc
    private static let dayNumberFormatter = formatter("d")
    private static let isoParser = ISO8601DateFormatter()

    // backend sometimes sends microseconds
    static func parseISO(_ iso: String) -> Date? {
        let cleaned = iso.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return isoParser.date(from: cleaned)
    }

    static func date(day: String, time: String = "00:00") -> Date? {
        let dayParts = day.split(separator: "-").compactMap { Int($0) }
        let timeParts = time.split(separator: ":").compactMap { Int($0) }
        guard dayParts.count == 3, timeParts.count >= 2 else { return nil }
        var components = DateComponents()
        components.year = dayParts[0]
        components.month = dayParts[1]
        components.day = dayParts[2]
        components.hour = timeParts[0]
        components.minute = timeParts[1]
        return calendar.date(from: components)
    }

    static func zonedToISO(day: String, time: String = "00:00") -> String {
        guard let moment = date(day: day, time: time) else { return "" }
        return isoOutput.string(from: moment)
    }

    static func isoToZoned(_ iso: String) -> ZonedDateTime? {
        guard let date = parseISO(iso) else { return nil }
        return ZonedDateTime(day: dayFormatter.string(from: date), time: timeFormatter.string(from: date))
    }

    static func today(now: Date = Date()) -> String { dayFormatter.string(from: now) }

    static func dayString(from date: Date) -> String { dayFormatter.string(from: date) }
    static func timeString(from date: Date) -> String { timeFormatter.string(from: date) }

    static func addDays(_ day: String, _ count: Int) -> String {
        // noon as anchor because of dst
        guard let base = date(day: day, time: "12:00"),
              let shifted = calendar.date(byAdding: .day, value: count, to: base) else { return day }
        return dayFormatter.string(from: shifted)
    }

    static func startOfWeek(_ day: String) -> String {
        guard let base = date(day: day, time: "12:00") else { return day }
        let weekday = calendar.component(.weekday, from: base) // 1 = sun
        return addDays(day, -((weekday + 5) % 7))
    }

    static func formatTime(_ iso: String) -> String { parseISO(iso).map(timeFormatter.string(from:)) ?? "" }

    static func formatDay(_ day: String) -> String {
        date(day: day, time: "12:00").map(shortDayFormatter.string(from:)) ?? day
    }

    static func formatLongDay(_ day: String) -> String {
        date(day: day, time: "12:00").map(longDayFormatter.string(from:)) ?? day
    }

    static func formatDateTime(_ iso: String) -> String {
        guard let zoned = isoToZoned(iso) else { return "" }
        return "\(formatDay(zoned.day)) \(zoned.time)"
    }

    static func weekdayShort(_ day: String) -> String {
        // strip the dot in case icu starts adding one
        date(day: day, time: "12:00")
            .map { weekdayFormatter.string(from: $0).replacingOccurrences(of: ".", with: "") } ?? ""
    }

    static func dayNumber(_ day: String) -> String {
        date(day: day, time: "12:00").map(dayNumberFormatter.string(from:)) ?? ""
    }
}

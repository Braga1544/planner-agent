import Foundation

enum Repeat: String, CaseIterable, Identifiable {
    case none, daily = "DAILY", weekly = "WEEKLY", monthly = "MONTHLY", yearly = "YEARLY", custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "Keine"
        case .daily: "Täglich"
        case .weekly: "Wöchentlich"
        case .monthly: "Monatlich"
        case .yearly: "Jährlich"
        case .custom: "Eigene Regel (RRULE)"
        }
    }
}

struct EventForm: Equatable {
    var title = ""
    var allDay = false
    var startDay: String
    var startTime = "09:00"
    var endDay: String
    var endTime = "10:00"
    var repeatRule: Repeat = .none
    var customRule = ""
    var location = ""
    var notes = ""
    var area: AreaSlug?
    var reminder: Int?

    static let reminderOptions: [(Int?, String)] = [
        (nil, "Keine"), (0, "Zum Beginn"), (5, "5 Minuten vorher"), (15, "15 Minuten vorher"),
        (30, "30 Minuten vorher"), (60, "1 Stunde vorher"), (1440, "1 Tag vorher"),
    ]

    static func empty(day: String) -> EventForm { EventForm(startDay: day, endDay: day) }

    init(startDay: String, endDay: String) {
        self.startDay = startDay
        self.endDay = endDay
    }

    init(event: EventOut) {
        let start = BerlinTime.isoToZoned(event.startAt) ?? ZonedDateTime(day: BerlinTime.today(), time: "09:00")
        let end = event.endAt.flatMap(BerlinTime.isoToZoned)
        var endDay = end?.day ?? start.day
        if event.allDay {
            endDay = end.map { BerlinTime.addDays($0.day, -1) } ?? start.day // end is exclusive
            if endDay < start.day { endDay = start.day }
        }
        self.init(startDay: start.day, endDay: endDay)
        title = event.title
        allDay = event.allDay
        startTime = event.allDay ? "09:00" : start.time
        endTime = event.allDay ? "10:00" : (end?.time ?? "")
        if let rule = event.rrule {
            let simple = [Repeat.daily, .weekly, .monthly, .yearly].first { "FREQ=\($0.rawValue)" == rule }
            if let simple {
                repeatRule = simple
            } else {
                repeatRule = .custom
                customRule = rule
            }
        }
        location = event.location ?? ""
        notes = event.notes ?? ""
        area = event.area
        reminder = event.reminderMinutes
    }

    mutating func setDefaultEnd() {
        let start = BerlinTime.date(day: startDay, time: startTime) ?? Date()
        let end = start.addingTimeInterval(3600)
        endDay = BerlinTime.dayString(from: end)
        endTime = BerlinTime.timeString(from: end)
    }

    private static func trimmedOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func payload() -> EventPayload {
        let rrule: String?
        switch repeatRule {
        case .none: rrule = nil
        case .custom: rrule = Self.trimmedOrNil(customRule)
        default: rrule = "FREQ=\(repeatRule.rawValue)"
        }
        let lastDay = endDay.isEmpty ? startDay : endDay
        let startAt: String
        let endAt: String?
        if allDay {
            startAt = BerlinTime.zonedToISO(day: startDay)
            endAt = BerlinTime.zonedToISO(day: BerlinTime.addDays(lastDay, 1))
        } else {
            startAt = BerlinTime.zonedToISO(day: startDay, time: startTime)
            endAt = endTime.isEmpty ? nil : BerlinTime.zonedToISO(day: lastDay, time: endTime)
        }
        return EventPayload(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startAt: startAt, endAt: endAt, allDay: allDay, rrule: rrule,
            location: Self.trimmedOrNil(location), notes: Self.trimmedOrNil(notes),
            area: area, reminderMinutes: reminder
        )
    }

    func validate() -> String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Titel fehlt." }
        if startDay.isEmpty { return "Datum fehlt." }
        if !allDay && startTime.isEmpty { return "Beginn fehlt." }
        if repeatRule == .custom && customRule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Regel fehlt." }
        let built = payload()
        if let endISO = built.endAt, let end = BerlinTime.parseISO(endISO),
           let start = BerlinTime.parseISO(built.startAt), end < start {
            return "Ende liegt vor dem Beginn."
        }
        return nil
    }
}

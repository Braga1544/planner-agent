import Foundation

struct PlannedReminder: Equatable {
    var id: String
    var fireDate: Date
    var title: String
    var body: String
}

enum ReminderPlanner {
    static let eventPrefix = "planer.event."
    static let briefingId = "planer.briefing"
    // ios caps at 64 notifications, leave room for the briefing
    static let limit = 60
    static let lookaheadDays = 14

    static func plan(_ occurrences: [Occurrence], reminderMinutes: [String: Int], now: Date, limit: Int = limit) -> [PlannedReminder] {
        let planned = occurrences.compactMap { occurrence -> PlannedReminder? in
            guard let minutes = reminderMinutes[occurrence.eventId],
                  let start = BerlinTime.parseISO(occurrence.occurrenceStart) else { return nil }
            let fireDate = start.addingTimeInterval(TimeInterval(-minutes * 60))
            guard fireDate > now else { return nil }
            return PlannedReminder(
                id: eventPrefix + occurrence.eventId + "." + occurrence.occurrenceStart,
                fireDate: fireDate,
                title: occurrence.title,
                body: body(for: occurrence)
            )
        }
        return Array(planned.sorted { $0.fireDate < $1.fireDate }.prefix(limit))
    }

    static func body(for occurrence: Occurrence) -> String {
        var text: String
        if occurrence.allDay {
            text = "\(BerlinTime.formatDay(BerlinTime.isoToZoned(occurrence.occurrenceStart)?.day ?? "")), ganztägig"
        } else {
            text = "\(BerlinTime.formatDateTime(occurrence.occurrenceStart)) Uhr"
        }
        if let location = occurrence.location { text += ", \(location)" }
        return text
    }

    static func briefingDay(now: Date, minutes: Int) -> String {
        let components = BerlinTime.calendar.dateComponents([.hour, .minute], from: now)
        let nowMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let today = BerlinTime.dayString(from: now)
        return nowMinutes < minutes ? today : BerlinTime.addDays(today, 1)
    }

    static func briefingText(events: Int, todos: Int) -> String {
        let eventText = events == 1 ? "1 Termin" : "\(events) Termine"
        let todoText = todos == 1 ? "1 fälliges ToDo" : "\(todos) fällige ToDos"
        return "Dein Tag: \(eventText), \(todoText)"
    }
}

struct ReminderSettings: Equatable {
    var eventReminders = true
    var briefing = false
    var briefingMinutes = 7 * 60

    private enum Key {
        static let eventReminders = "reminders.events"
        static let briefing = "reminders.briefing"
        static let briefingMinutes = "reminders.briefingMinutes"
    }

    static func load(_ defaults: UserDefaults = .standard) -> ReminderSettings {
        var settings = ReminderSettings()
        if defaults.object(forKey: Key.eventReminders) != nil { settings.eventReminders = defaults.bool(forKey: Key.eventReminders) }
        settings.briefing = defaults.bool(forKey: Key.briefing)
        if defaults.object(forKey: Key.briefingMinutes) != nil { settings.briefingMinutes = defaults.integer(forKey: Key.briefingMinutes) }
        return settings
    }

    func save(_ defaults: UserDefaults = .standard) {
        defaults.set(eventReminders, forKey: Key.eventReminders)
        defaults.set(briefing, forKey: Key.briefing)
        defaults.set(briefingMinutes, forKey: Key.briefingMinutes)
    }
}

import Foundation

struct UpcomingDay: Identifiable, Equatable {
    var day: String
    var events: [Occurrence]
    var todos: [Item]
    var id: String { day }
}

enum CalendarGrouping {
    static func occurrenceDays(_ occurrence: Occurrence) -> [String] {
        guard let start = BerlinTime.isoToZoned(occurrence.occurrenceStart)?.day else { return [] }
        var last = start
        if let endISO = occurrence.occurrenceEnd, let end = BerlinTime.isoToZoned(endISO) {
            // end at 00:00 doesn't count
            last = end.time == "00:00" ? BerlinTime.addDays(end.day, -1) : end.day
            if last < start { last = start }
        }
        var days: [String] = []
        var day = start
        while day <= last {
            days.append(day)
            day = BerlinTime.addDays(day, 1)
        }
        return days
    }

    static func groupByDay(_ occurrences: [Occurrence], weekStart: String) -> [String: [Occurrence]] {
        let weekEnd = BerlinTime.addDays(weekStart, 7)
        var grouped: [String: [Occurrence]] = [:]
        for occurrence in occurrences {
            for day in occurrenceDays(occurrence) where day >= weekStart && day < weekEnd {
                grouped[day, default: []].append(occurrence)
            }
        }
        return grouped
    }

    static func upcoming(_ agenda: Agenda, from: String, to: String) -> [UpcomingDay] {
        var byDay: [String: UpcomingDay] = [:]
        for occurrence in agenda.events {
            for day in occurrenceDays(occurrence) where day >= from && day <= to {
                byDay[day, default: UpcomingDay(day: day, events: [], todos: [])].events.append(occurrence)
            }
        }
        for item in agenda.dueTodos {
            guard let due = item.dueDate, due >= from, due <= to else { continue }
            byDay[due, default: UpcomingDay(day: due, events: [], todos: [])].todos.append(item)
        }
        var result: [UpcomingDay] = []
        var day = from
        while day <= to {
            if var entry = byDay[day] {
                entry.events.sort { $0.occurrenceStart < $1.occurrenceStart }
                result.append(entry)
            } else if day == from {
                result.append(UpcomingDay(day: day, events: [], todos: []))
            }
            day = BerlinTime.addDays(day, 1)
        }
        return result
    }

    static func timeLabel(_ occurrence: Occurrence) -> String {
        if occurrence.allDay { return "ganztägig" }
        let start = BerlinTime.formatTime(occurrence.occurrenceStart)
        guard let end = occurrence.occurrenceEnd else { return start }
        return "\(start)–\(BerlinTime.formatTime(end))"
    }
}

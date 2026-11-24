import Foundation
@testable import Planer

enum Fixtures {
    static func item(
        id: String = UUID().uuidString,
        area: AreaSlug = .personal,
        projectId: String? = nil,
        type: ItemType = .todo,
        title: String = "ToDo",
        status: ItemStatus = .open,
        priority: Priority = .normal,
        dueDate: String? = nil
    ) -> Item {
        Item(
            id: id, area: area, projectId: projectId, type: type, title: title, body: nil,
            status: status, priority: priority, dueDate: dueDate, completedAt: nil,
            createdAt: "2026-10-01T10:00:00Z", updatedAt: "2026-10-01T10:00:00Z"
        )
    }

    static func occurrence(
        eventId: String = UUID().uuidString,
        title: String = "Termin",
        allDay: Bool = false,
        source: EventSource = .local,
        start: String = "2026-10-12T09:00:00+02:00",
        end: String? = "2026-10-12T10:00:00+02:00"
    ) -> Occurrence {
        Occurrence(
            eventId: eventId, title: title, location: nil, notes: nil, allDay: allDay, area: nil,
            projectId: nil, source: source, isRecurring: false, occurrenceStart: start, occurrenceEnd: end
        )
    }

    static func event(
        id: String = UUID().uuidString,
        title: String = "Termin",
        start: String = "2026-10-12T07:00:00Z",
        end: String? = "2026-10-12T08:00:00Z",
        allDay: Bool = false,
        rrule: String? = nil,
        source: EventSource = .local
    ) -> EventOut {
        EventOut(
            id: id, title: title, location: nil, notes: nil, startAt: start, endAt: end, allDay: allDay,
            rrule: rrule, area: nil, projectId: nil, reminderMinutes: nil, source: source,
            calendarSourceId: nil, createdAt: "2026-10-01T10:00:00Z", updatedAt: "2026-10-01T10:00:00Z"
        )
    }

    static func json(_ string: String) -> Data { Data(string.utf8) }
}

extension Fixtures {
    static func project(
        id: String = UUID().uuidString,
        area: AreaSlug = .personal,
        name: String = "Projekt",
        status: ProjectStatus = .active,
        description: String? = nil
    ) -> Project {
        Project(id: id, area: area, name: name, description: description, status: status,
                createdAt: "2026-10-01T10:00:00Z", updatedAt: "2026-10-01T10:00:00Z")
    }

    static func encode<T: Encodable>(_ value: T) -> String {
        String(data: try! JSONEncoder().encode(value), encoding: .utf8)!
    }

    static func agendaJSON(start: String, end: String, events: [Occurrence] = [], due: [Item] = [], overdue: [Item] = []) -> String {
        #"{"start":"\#(start)","end":"\#(end)","events":\#(encode(events)),"due_todos":\#(encode(due)),"overdue_todos":\#(encode(overdue))}"#
    }
}

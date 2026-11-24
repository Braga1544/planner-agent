import Foundation
import Testing
@testable import Planer

struct ModelsTests {
    @Test func decodesItemWithSnakeCaseFields() throws {
        let data = Fixtures.json("""
        {"id":"i1","area":"hobby","project_id":"p1","type":"todo","title":"Material bestellen","body":null,
         "status":"open","priority":"high","due_date":"2026-10-16","completed_at":null,
         "created_at":"2026-10-01T10:00:00.123456Z","updated_at":"2026-10-01T10:00:00Z"}
        """)
        let item = try JSONDecoder().decode(Item.self, from: data)
        #expect(item.area == .hobby)
        #expect(item.projectId == "p1")
        #expect(item.dueDate == "2026-10-16")
        #expect(item.priority == .high)
    }

    @Test func decodesAgenda() throws {
        let data = Fixtures.json("""
        {"start":"2026-10-09","end":"2026-10-09",
         "events":[{"event_id":"e1","title":"Zahnarzt","location":null,"notes":null,"all_day":false,"area":null,
                    "project_id":null,"source":"local","is_recurring":true,
                    "occurrence_start":"2026-10-09T14:00:00+02:00","occurrence_end":"2026-10-09T15:00:00+02:00"}],
         "due_todos":[],"overdue_todos":[]}
        """)
        let agenda = try JSONDecoder().decode(Agenda.self, from: data)
        #expect(agenda.events.first?.isRecurring == true)
        #expect(agenda.events.first?.occurrenceStart == "2026-10-09T14:00:00+02:00")
    }

    @Test func decodesMessageWithArbitraryContentBlocks() throws {
        let data = Fixtures.json("""
        {"id":"m1","seq":2,"role":"assistant","usage":{"input_tokens":10},
         "content":[{"type":"thinking","thinking":"","signature":"x"},
                    {"type":"tool_use","id":"t1","name":"get_agenda","input":{"date":null}},
                    {"type":"text","text":"Heute nichts."}],
         "created_at":"2026-10-09T18:00:00Z"}
        """)
        let message = try JSONDecoder().decode(Message.self, from: data)
        #expect(message.role == .assistant)
        #expect(message.content[1]["name"]?.stringValue == "get_agenda")
        #expect(message.content[2]["text"]?.stringValue == "Heute nichts.")
    }

    @Test func itemUpdateEncodesExplicitNulls() throws {
        let update = ItemUpdate(
            type: .idea, area: .personal, projectId: nil, title: "Hochbeet", body: nil,
            status: .open, priority: .normal, dueDate: nil
        )
        let json = try #require(String(data: JSONEncoder().encode(update), encoding: .utf8))
        #expect(json.contains("\"project_id\":null"))
        #expect(json.contains("\"due_date\":null"))
        #expect(json.contains("\"body\":null"))
    }

    @Test func itemCreateOmitsNothingRequired() throws {
        let create = ItemCreate(type: .todo, area: .hobby, projectId: "p1", title: "A", body: nil, priority: .normal, dueDate: "2026-10-16")
        let object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(create)) as? [String: Any])
        #expect(object["project_id"] as? String == "p1")
        #expect(object["due_date"] as? String == "2026-10-16")
        #expect(object["type"] as? String == "todo")
    }

    @Test func eventPayloadEncodesNullsForClearing() throws {
        let payload = EventPayload(
            title: "A", startAt: "2026-10-12T14:00:00+02:00", endAt: nil, allDay: false, rrule: nil,
            location: nil, notes: nil, area: nil, reminderMinutes: nil
        )
        let json = try #require(String(data: JSONEncoder().encode(payload), encoding: .utf8))
        #expect(json.contains("\"rrule\":null"))
        #expect(json.contains("\"end_at\":null"))
        #expect(json.contains("\"start_at\":\"2026-10-12T14:00:00+02:00\""))
    }

    @Test func labels() {
        #expect(AreaSlug.business.name == "Business")
        #expect(ItemType.idea.groupLabel == "Ideen")
        #expect(ProjectStatus.paused.label == "Pausiert")
    }
}

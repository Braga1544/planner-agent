import Foundation
import Testing
@testable import Planer

@MainActor
struct CalendarViewModelTests {
    let server = StubServer()

    @Test func loadsWeekWithBerlinOffsetsAndGroups() async {
        let occurrences = [
            Fixtures.occurrence(title: "Spät", start: "2026-10-13T18:00:00+02:00", end: nil),
            Fixtures.occurrence(title: "Ganztägig", allDay: true, start: "2026-10-13T00:00:00+02:00", end: "2026-10-14T00:00:00+02:00"),
            Fixtures.occurrence(title: "Früh", start: "2026-10-13T08:00:00+02:00", end: nil),
        ]
        server.on("GET", "/events", json: Fixtures.encode(occurrences))
        let model = CalendarViewModel(client: server.client(), today: { "2026-10-14" })
        #expect(model.weekStart == "2026-10-12")
        await model.load()
        #expect(server.requests("GET", "/events").first?.query == ["from": "2026-10-12T00:00:00+02:00", "to": "2026-10-19T00:00:00+02:00"])
        #expect(model.grouped["2026-10-13"]?.map(\.title) == ["Ganztägig", "Früh", "Spät"])
        #expect(model.days.count == 7)
    }

    @Test func moveAcrossDSTChange() async {
        server.on("GET", "/events", json: "[]")
        let model = CalendarViewModel(client: server.client(), today: { "2026-10-14" })
        await model.move(weeks: 1)
        #expect(model.weekStart == "2026-10-19")
        #expect(server.requests("GET", "/events").last?.query["to"] == "2026-10-26T00:00:00+01:00")
        await model.goToToday()
        #expect(model.weekStart == "2026-10-12")
    }

    @Test func newEventPostsPayload() async {
        server.on("POST", "/events", status: 201, json: Fixtures.encode(Fixtures.event(id: "e1")))
        let sheet = EventSheetModel(client: server.client(), event: nil, day: "2026-10-12", isRecurring: false)
        sheet.form.title = "Zahnarzt"
        sheet.form.startTime = "14:00"
        sheet.form.endTime = "15:00"
        #expect(await sheet.save())
        let body = server.requests("POST", "/events").first?.json ?? [:]
        #expect(body["start_at"] as? String == "2026-10-12T14:00:00+02:00")
        #expect(body["end_at"] as? String == "2026-10-12T15:00:00+02:00")
        #expect(body["rrule"] is NSNull)
    }

    @Test func invalidFormDoesNotSend() async {
        let sheet = EventSheetModel(client: server.client(), event: nil, day: "2026-10-12", isRecurring: false)
        #expect(await sheet.save() == false)
        #expect(sheet.error == "Titel fehlt.")
        #expect(server.requests("POST", "/events").isEmpty)
    }

    @Test func existingEventPatchesAndDeletes() async {
        let event = Fixtures.event(id: "e7", title: "Training", rrule: "FREQ=WEEKLY")
        server.on("PATCH", "/events/e7", json: Fixtures.encode(event))
        server.on("DELETE", "/events/e7", status: 204, json: "")
        let sheet = EventSheetModel(client: server.client(), event: event, day: "2026-10-12", isRecurring: true)
        #expect(sheet.form.repeatRule == .weekly)
        #expect(sheet.isRecurring)
        sheet.form.title = "Training (Halle)"
        #expect(await sheet.save())
        #expect(server.requests("PATCH", "/events/e7").first?.json["title"] as? String == "Training (Halle)")
        #expect(await sheet.delete())
        #expect(server.requests("DELETE", "/events/e7").count == 1)
    }

    @Test func importedEventIsReadOnly() async {
        let sheet = EventSheetModel(client: server.client(), event: Fixtures.event(source: .icsImport), day: "2026-10-12", isRecurring: false)
        #expect(sheet.readOnly)
        #expect(await sheet.save() == false)
    }
}

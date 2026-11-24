import Foundation
import Testing
@testable import Planer

@MainActor
struct TodayViewModelTests {
    let server = StubServer()

    func makeModel() -> TodayViewModel {
        TodayViewModel(client: server.client(), today: { "2026-10-10" })
    }

    @Test func loadsTodayAndNext14Days() async {
        let event = Fixtures.occurrence(title: "Training", start: "2026-10-14T18:00:00+02:00", end: nil)
        server.on("GET", "/agenda", json: Fixtures.agendaJSON(start: "2026-10-10", end: "2026-10-10", events: [event]))
        let model = makeModel()
        await model.load()
        let queries = server.requests("GET", "/agenda").map(\.query)
        #expect(queries.contains(["date": "2026-10-10"]))
        #expect(queries.contains(["from": "2026-10-11", "to": "2026-10-24"]))
        #expect(model.agenda?.events.count == 1)
        #expect(model.upcoming.map(\.day) == ["2026-10-11", "2026-10-14"])
        #expect(model.error == nil)
    }

    @Test func loadMoreExtendsRangeBySevenDays() async {
        server.on("GET", "/agenda", json: Fixtures.agendaJSON(start: "x", end: "x"))
        let model = makeModel()
        await model.load()
        await model.loadMore()
        #expect(model.days == 21)
        #expect(server.requests("GET", "/agenda").last?.query == ["from": "2026-10-11", "to": "2026-10-31"])
    }

    @Test func toggleSendsNewStatus() async {
        let item = Fixtures.item(id: "i1", status: .open)
        server.on("PATCH", "/items/i1", json: Fixtures.encode(Fixtures.item(id: "i1", status: .done)))
        let changed = await makeModel().toggle(item)
        #expect(changed)
        #expect(server.requests("PATCH", "/items/i1").first?.json["status"] as? String == "done")
    }

    @Test func quickAddPostsTodoAndIgnoresBlankTitle() async {
        server.on("POST", "/items", status: 201, json: Fixtures.encode(Fixtures.item()))
        let model = makeModel()
        #expect(await model.quickAdd(title: "   ", area: .hobby, due: nil) == false)
        #expect(server.requests("POST", "/items").isEmpty)

        #expect(await model.quickAdd(title: " Rasen mähen ", area: .hobby, due: "2026-10-10"))
        let body = server.requests("POST", "/items").first?.json ?? [:]
        #expect(body["type"] as? String == "todo")
        #expect(body["area"] as? String == "hobby")
        #expect(body["title"] as? String == "Rasen mähen")
        #expect(body["due_date"] as? String == "2026-10-10")
    }

    @Test func showsServerError() async {
        server.on("GET", "/agenda", status: 500, json: #"{"detail":"Interner Serverfehler"}"#)
        let model = makeModel()
        await model.load()
        #expect(model.error == "Interner Serverfehler")
    }
}

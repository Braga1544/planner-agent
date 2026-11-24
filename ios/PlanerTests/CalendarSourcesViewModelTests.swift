import Foundation
import Testing
@testable import Planer

@MainActor
struct CalendarSourcesViewModelTests {
    let server = StubServer()
    let source = #"{"id":"s1","name":"Teams","url":"https://outlook.office365.com/x.ics","area":"work","enabled":true,"last_synced_at":null,"last_error":null}"#

    @Test func addPostsTrimmedValuesAndNullArea() async {
        server.on("POST", "/calendar-sources", status: 201, json: source)
        server.on("GET", "/calendar-sources", json: "[\(source)]")
        let model = CalendarSourcesViewModel(client: server.client())
        #expect(await model.add(name: " ", url: "x", area: nil) == false)
        #expect(await model.add(name: " Teams ", url: " webcal://x.ics ", area: nil))
        let body = server.requests("POST", "/calendar-sources").first?.json ?? [:]
        #expect(body["name"] as? String == "Teams")
        #expect(body["url"] as? String == "webcal://x.ics")
        #expect(body["area"] == nil || body["area"] is NSNull)
        #expect(model.sources.count == 1)
    }

    @Test func toggleAndSyncSummary() async {
        server.on("GET", "/calendar-sources", json: "[\(source)]")
        server.on("PATCH", "/calendar-sources/s1", json: source)
        server.on("POST", "/calendar-sources/s1/sync", json: #"{"created":3,"updated":1,"deleted":0,"error":null}"#)
        let model = CalendarSourcesViewModel(client: server.client())
        await model.load()
        let first = model.sources[0]
        #expect(await model.toggle(first))
        #expect(server.requests("PATCH", "/calendar-sources/s1").first?.json["enabled"] as? Bool == false)
        #expect(await model.sync(first))
        #expect(model.lastSync == SyncNote(sourceId: "s1", text: "3 neu, 1 geändert, 0 entfernt", failed: false))
        #expect(CalendarSourcesViewModel.summary(SyncResult(created: 0, updated: 0, deleted: 0, error: "HTTP 404")) == "HTTP 404")
    }
}

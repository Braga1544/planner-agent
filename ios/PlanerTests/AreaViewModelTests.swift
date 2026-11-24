import Foundation
import Testing
@testable import Planer

@MainActor
struct AreaViewModelTests {
    let server = StubServer()

    @Test func areaShowsAllOpenTodosIncludingProjectTodos() async {
        server.on("GET", "/projects", json: Fixtures.encode([Fixtures.project(id: "p1", area: .hobby, name: "Gartenhaus")]))
        server.on("GET", "/items", json: Fixtures.encode([
            Fixtures.item(area: .hobby, type: .todo, title: "Holz bestellen"),
            Fixtures.item(area: .hobby, type: .idea, title: "Hochbeet-Idee"),
            Fixtures.item(area: .hobby, projectId: "p1", type: .todo, title: "Im Projekt"),
            Fixtures.item(area: .hobby, projectId: "p1", type: .note, title: "Projektnotiz"),
        ]))
        let model = AreaViewModel(client: server.client(), area: .hobby)
        await model.load()
        #expect(server.requests("GET", "/items").first?.query == ["area": "hobby", "status": "open"])
        #expect(server.requests("GET", "/projects").first?.query == ["area": "hobby"])
        #expect(model.openTodos.map(\.title) == ["Holz bestellen", "Im Projekt"])
        #expect(model.looseEntries.map(\.title) == ["Hochbeet-Idee"])
        #expect(model.projectName(for: model.openTodos[1]) == "Gartenhaus")
        #expect(model.projectName(for: model.openTodos[0]) == nil)
    }

    @Test func createProjectPostsAreaAndName() async {
        server.on("POST", "/projects", status: 201, json: Fixtures.encode(Fixtures.project(id: "p2", area: .hobby, name: "Fotobuch")))
        let model = AreaViewModel(client: server.client(), area: .hobby)
        #expect(await model.createProject(name: "  ") == nil)
        let project = await model.createProject(name: " Fotobuch ")
        #expect(project?.id == "p2")
        let body = server.requests("POST", "/projects").first?.json ?? [:]
        #expect(body["area"] as? String == "hobby")
        #expect(body["name"] as? String == "Fotobuch")
    }

    @Test func projectDescriptionBlankSendsNull() async {
        server.on("PATCH", "/projects/p1", json: Fixtures.encode(Fixtures.project(id: "p1")))
        server.on("GET", "/projects/p1", json: #"{"id":"p1","area":"personal","name":"Projekt","description":null,"status":"active","open_items":[]}"#)
        let model = ProjectViewModel(client: server.client(), projectId: "p1")
        #expect(await model.saveDescription("   "))
        #expect(server.requests("PATCH", "/projects/p1").first?.json["description"] is NSNull)
        #expect(await model.setStatus(.paused))
        #expect(server.requests("PATCH", "/projects/p1").last?.json["status"] as? String == "paused")
    }

    @Test func itemSheetCreatesUpdatesAndArchives() async {
        server.on("POST", "/items", status: 201, json: Fixtures.encode(Fixtures.item()))
        let create = ItemSheetModel(client: server.client(), item: nil, defaults: .empty(area: .hobby, projectId: "p1"))
        #expect(await create.save() == false)
        #expect(create.error == "Titel fehlt.")
        create.form.title = "Material bestellen"
        #expect(await create.save())
        let posted = server.requests("POST", "/items").first?.json ?? [:]
        #expect(posted["project_id"] as? String == "p1")
        #expect(posted["area"] as? String == "hobby")

        let item = Fixtures.item(id: "i5", area: .personal, type: .idea, title: "Hochbeet")
        server.on("PATCH", "/items/i5", json: Fixtures.encode(item))
        server.on("DELETE", "/items/i5", json: Fixtures.encode(item))
        let edit = ItemSheetModel(client: server.client(), item: item, defaults: .empty())
        edit.form.status = .done
        #expect(await edit.save())
        let patched = server.requests("PATCH", "/items/i5").first?.json ?? [:]
        #expect(patched["status"] as? String == "done")
        #expect(patched["project_id"] is NSNull)
        #expect(await edit.archive())
        #expect(server.requests("DELETE", "/items/i5").count == 1)
    }

    @Test func searchSkipsBlankQuery() async {
        server.on("GET", "/search", json: #"{"items":[],"projects":[],"events":[]}"#)
        let model = SearchViewModel(client: server.client())
        model.query = "  "
        await model.search()
        #expect(server.requests("GET", "/search").isEmpty)
        #expect(model.results == nil)
        model.query = "Steuer"
        await model.search()
        #expect(server.requests("GET", "/search").first?.query == ["q": "Steuer"])
        #expect(model.results != nil)
    }
}

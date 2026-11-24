import Foundation
import Observation

struct ProjectRoute: Hashable {
    var id: String
}

@MainActor
@Observable
final class AreaViewModel {
    @ObservationIgnored let client: APIClient
    let area: AreaSlug
    private(set) var projects: [Project] = []
    private(set) var items: [Item] = []
    var error: String?

    init(client: APIClient, area: AreaSlug) {
        self.client = client
        self.area = area
    }

    // incl. todos from projects
    var openTodos: [Item] { items.filter { $0.type == .todo } }
    var looseEntries: [Item] { items.filter { $0.type != .todo && $0.projectId == nil } }

    func projectName(for item: Item) -> String? {
        guard let projectId = item.projectId else { return nil }
        return projects.first { $0.id == projectId }?.name
    }

    func load() async {
        do {
            projects = try await client.get("/projects" + Query.string([("area", area.rawValue)]))
            items = try await client.get("/items" + Query.string([("area", area.rawValue), ("status", "open")]))
            error = nil
        } catch {
            guard !isCancellation(error) else { return }
            self.error = errorMessage(error)
        }
    }

    func createProject(name: String) async -> Project? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        do {
            let project: Project = try await client.post("/projects", body: ProjectCreate(area: area, name: trimmed))
            return project
        } catch {
            self.error = errorMessage(error)
            return nil
        }
    }

    func toggle(_ item: Item) async -> Bool {
        do {
            try await client.toggleDone(item)
            return true
        } catch {
            self.error = errorMessage(error)
            return false
        }
    }
}

@MainActor
@Observable
final class ProjectViewModel {
    @ObservationIgnored let client: APIClient
    let projectId: String
    private(set) var project: ProjectDetail?
    var error: String?

    init(client: APIClient, projectId: String) {
        self.client = client
        self.projectId = projectId
    }

    var groups: [ItemType: [Item]] { ItemForm.groupByType(project?.openItems ?? []) }

    func load() async {
        do {
            project = try await client.get("/projects/\(projectId)")
            error = nil
        } catch {
            guard !isCancellation(error) else { return }
            self.error = errorMessage(error)
        }
    }

    func saveDescription(_ text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return await patch(ProjectDescriptionUpdate(description: trimmed.isEmpty ? nil : trimmed))
    }

    func setStatus(_ status: ProjectStatus) async -> Bool {
        await patch(ProjectStatusUpdate(status: status))
    }

    func toggle(_ item: Item) async -> Bool {
        do {
            try await client.toggleDone(item)
            return true
        } catch {
            self.error = errorMessage(error)
            return false
        }
    }

    private func patch(_ body: some Encodable) async -> Bool {
        do {
            let _: Project = try await client.patch("/projects/\(projectId)", body: body)
            error = nil
            return true
        } catch {
            self.error = errorMessage(error)
            return false
        }
    }
}

@MainActor
@Observable
final class ItemSheetModel {
    @ObservationIgnored let client: APIClient
    let itemId: String?
    var form: ItemForm
    private(set) var projects: [Project] = []
    var error: String?
    private(set) var isSaving = false

    init(client: APIClient, item: Item?, defaults: ItemForm) {
        self.client = client
        itemId = item?.id
        form = item.map(ItemForm.init(item:)) ?? defaults
    }

    var selectableProjects: [Project] {
        projects.filter { $0.status != .archived || $0.id == form.projectId }
    }

    func loadProjects() async {
        do {
            projects = try await client.get("/projects" + Query.string([("area", form.area.rawValue)]))
        } catch {
            guard !isCancellation(error) else { return }
            self.error = errorMessage(error)
        }
    }

    func save() async -> Bool {
        guard !form.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "Titel fehlt."
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            if let itemId {
                let _: Item = try await client.patch("/items/\(itemId)", body: form.update())
            } else {
                let _: Item = try await client.post("/items", body: form.create())
            }
            error = nil
            return true
        } catch {
            self.error = errorMessage(error)
            return false
        }
    }

    func archive() async -> Bool {
        guard let itemId else { return false }
        do {
            try await client.delete("/items/\(itemId)")
            return true
        } catch {
            self.error = errorMessage(error)
            return false
        }
    }
}

@MainActor
@Observable
final class SearchViewModel {
    @ObservationIgnored let client: APIClient
    var query = ""
    private(set) var results: SearchResults?
    var error: String?

    init(client: APIClient) { self.client = client }

    func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            results = nil
            error = nil
            return
        }
        do {
            results = try await client.get("/search" + Query.string([("q", text)]))
            error = nil
        } catch {
            guard !isCancellation(error) else { return }
            self.error = errorMessage(error)
        }
    }
}

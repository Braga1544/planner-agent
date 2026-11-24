import Foundation
import Observation

struct SyncNote: Equatable {
    var sourceId: String
    var text: String
    var failed: Bool
}

@MainActor
@Observable
final class CalendarSourcesViewModel {
    @ObservationIgnored let client: APIClient
    private(set) var sources: [CalendarSource] = []
    private(set) var lastSync: SyncNote?
    private(set) var syncingId: String?
    var error: String?

    init(client: APIClient) { self.client = client }

    static func summary(_ result: SyncResult) -> String {
        result.error ?? "\(result.created) neu, \(result.updated) geändert, \(result.deleted) entfernt"
    }

    func load() async {
        do {
            sources = try await client.get("/calendar-sources")
            error = nil
        } catch {
            guard !isCancellation(error) else { return }
            self.error = errorMessage(error)
        }
    }

    func add(name: String, url: String, area: AreaSlug?) async -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !url.isEmpty else { return false }
        return await perform {
            let _: CalendarSource = try await self.client.post("/calendar-sources", body: CalendarSourceCreate(name: name, url: url, area: area))
        }
    }

    func toggle(_ source: CalendarSource) async -> Bool {
        await perform {
            let _: CalendarSource = try await self.client.patch("/calendar-sources/\(source.id)", body: EnabledUpdate(enabled: !source.enabled))
        }
    }

    func sync(_ source: CalendarSource) async -> Bool {
        syncingId = source.id
        defer { syncingId = nil }
        return await perform {
            let result: SyncResult = try await self.client.post("/calendar-sources/\(source.id)/sync")
            self.lastSync = SyncNote(sourceId: source.id, text: Self.summary(result), failed: result.error != nil)
        }
    }

    func remove(_ source: CalendarSource) async -> Bool {
        await perform { try await self.client.delete("/calendar-sources/\(source.id)") }
    }

    private func perform(_ action: () async throws -> Void) async -> Bool {
        do {
            try await action()
            await load()
            return true
        } catch {
            self.error = errorMessage(error)
            return false
        }
    }
}

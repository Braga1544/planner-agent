import Foundation
import Observation

@MainActor
@Observable
final class TodayViewModel {
    static let initialDays = 14
    static let moreDays = 7
    static let maxDays = 365

    @ObservationIgnored let client: APIClient
    @ObservationIgnored private let todayProvider: () -> String

    private(set) var today: String
    private(set) var agenda: Agenda?
    private(set) var upcoming: [UpcomingDay] = []
    private(set) var days = initialDays
    private(set) var isLoadingMore = false
    var error: String?
    var actionError: String?

    init(client: APIClient, today: @escaping () -> String = { BerlinTime.today() }) {
        self.client = client
        self.todayProvider = today
        self.today = today()
    }

    var tomorrow: String { BerlinTime.addDays(today, 1) }
    private var lastDay: String { BerlinTime.addDays(tomorrow, days - 1) }

    func load() async {
        today = todayProvider() // day changed while app is open
        do {
            agenda = try await client.get("/agenda" + Query.string([("date", today)]))
            upcoming = try await fetchUpcoming()
            error = nil
        } catch {
            guard !isCancellation(error) else { return }
            self.error = errorMessage(error)
        }
    }

    func loadMore() async {
        guard days < Self.maxDays, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let previous = days
        days = min(days + Self.moreDays, Self.maxDays)
        do {
            upcoming = try await fetchUpcoming()
        } catch {
            days = previous
            guard !isCancellation(error) else { return }
            self.error = errorMessage(error)
        }
    }

    func toggle(_ item: Item) async -> Bool {
        do {
            try await client.toggleDone(item)
            actionError = nil
            return true
        } catch {
            actionError = errorMessage(error)
            return false
        }
    }

    func quickAdd(title: String, area: AreaSlug, due: String?) async -> Bool {
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        do {
            let create = ItemCreate(type: .todo, area: area, projectId: nil, title: text, body: nil, priority: .normal, dueDate: due)
            let _: Item = try await client.post("/items", body: create)
            actionError = nil
            return true
        } catch {
            actionError = errorMessage(error)
            return false
        }
    }

    private func fetchUpcoming() async throws -> [UpcomingDay] {
        let next: Agenda = try await client.get("/agenda" + Query.string([("from", tomorrow), ("to", lastDay)]))
        return CalendarGrouping.upcoming(next, from: tomorrow, to: lastDay)
    }
}

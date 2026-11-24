import Foundation
import Observation

@MainActor
@Observable
final class CalendarViewModel {
    @ObservationIgnored let client: APIClient
    @ObservationIgnored private let todayProvider: () -> String

    private(set) var today: String
    private(set) var weekStart: String
    private(set) var grouped: [String: [Occurrence]] = [:]
    var error: String?

    init(client: APIClient, today: @escaping () -> String = { BerlinTime.today() }) {
        self.client = client
        self.todayProvider = today
        let now = today()
        self.today = now
        self.weekStart = BerlinTime.startOfWeek(now)
    }

    var days: [String] { (0..<7).map { BerlinTime.addDays(weekStart, $0) } }

    var title: String {
        "\(BerlinTime.formatDay(weekStart)) – \(BerlinTime.formatDay(BerlinTime.addDays(weekStart, 6)))"
    }

    func load() async {
        today = todayProvider()
        let week = weekStart
        let path = "/events" + Query.string([
            ("from", BerlinTime.zonedToISO(day: week)),
            ("to", BerlinTime.zonedToISO(day: BerlinTime.addDays(week, 7))),
        ])
        do {
            let occurrences: [Occurrence] = try await client.get(path)
            guard week == weekStart else { return } // other week loaded meanwhile, that one wins
            // all-day first, then by start
            let sorted = occurrences.sorted {
                $0.allDay != $1.allDay ? $0.allDay : $0.occurrenceStart < $1.occurrenceStart
            }
            grouped = CalendarGrouping.groupByDay(sorted, weekStart: week)
            error = nil
        } catch {
            guard week == weekStart, !isCancellation(error) else { return }
            self.error = errorMessage(error)
        }
    }

    func move(weeks: Int) async {
        weekStart = BerlinTime.addDays(weekStart, 7 * weeks)
        await load()
    }

    func goToToday() async {
        weekStart = BerlinTime.startOfWeek(todayProvider())
        await load()
    }

    func loadEvent(id: String) async throws -> EventOut {
        try await client.get("/events/\(id)")
    }
}

@MainActor
@Observable
final class EventSheetModel {
    @ObservationIgnored let client: APIClient
    let eventId: String?
    let readOnly: Bool
    let isRecurring: Bool
    var form: EventForm
    var error: String?
    private(set) var isSaving = false

    init(client: APIClient, event: EventOut?, day: String, isRecurring: Bool) {
        self.client = client
        eventId = event?.id
        readOnly = event?.source == .icsImport
        self.isRecurring = isRecurring || event?.rrule != nil
        form = event.map(EventForm.init(event:)) ?? EventForm.empty(day: day)
    }

    func save() async -> Bool {
        guard !readOnly else { return false }
        if let message = form.validate() {
            error = message
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            if let eventId {
                let _: EventOut = try await client.patch("/events/\(eventId)", body: form.payload())
            } else {
                let _: EventOut = try await client.post("/events", body: form.payload())
            }
            error = nil
            return true
        } catch {
            self.error = errorMessage(error)
            return false
        }
    }

    func delete() async -> Bool {
        guard let eventId, !readOnly else { return false }
        do {
            try await client.delete("/events/\(eventId)")
            return true
        } catch {
            self.error = errorMessage(error)
            return false
        }
    }
}

import Foundation
import Testing
@testable import Planer

struct ReminderPlannerTests {
    let now = BerlinTime.parseISO("2026-10-10T10:00:00+02:00")!

    @Test func plannerSkipsPastAndCaps() {
        var occurrences: [Occurrence] = []
        var minutes: [String: Int] = [:]
        for index in 0..<70 {
            let day = BerlinTime.addDays("2026-10-11", index % 14)
            let hour = String(format: "%02d", 8 + index / 14)
            let id = "e\(index)"
            occurrences.append(Fixtures.occurrence(eventId: id, title: "T\(index)", start: "\(day)T\(hour):00:00+02:00", end: nil))
            minutes[id] = 10
        }
        occurrences.append(Fixtures.occurrence(eventId: "past", title: "Vorbei", start: "2026-10-10T10:05:00+02:00", end: nil))
        minutes["past"] = 15 // would be 09:50, already past
        occurrences.append(Fixtures.occurrence(eventId: "none", title: "Ohne", start: "2026-10-11T07:00:00+02:00", end: nil))

        let planned = ReminderPlanner.plan(occurrences, reminderMinutes: minutes, now: now)
        #expect(planned.count == 60)
        #expect(!planned.contains { $0.title == "Vorbei" || $0.title == "Ohne" })
        #expect(planned.first?.fireDate == BerlinTime.parseISO("2026-10-11T07:50:00+02:00"))
        #expect(planned.map(\.fireDate) == planned.map(\.fireDate).sorted())
    }

    @Test func recurringOccurrencesGetUniqueIds() {
        let occurrences = [
            Fixtures.occurrence(eventId: "e1", title: "Training", start: "2026-10-13T18:00:00+02:00", end: nil),
            Fixtures.occurrence(eventId: "e1", title: "Training", start: "2026-10-20T18:00:00+02:00", end: nil),
        ]
        let planned = ReminderPlanner.plan(occurrences, reminderMinutes: ["e1": 30], now: now)
        #expect(Set(planned.map(\.id)).count == 2)
        #expect(planned.allSatisfy { $0.id.hasPrefix(ReminderPlanner.eventPrefix) })
        #expect(planned.first?.body.contains("18:00") == true)
    }

    @Test func briefingDayAndText() {
        #expect(ReminderPlanner.briefingDay(now: BerlinTime.parseISO("2026-10-10T06:30:00+02:00")!, minutes: 420) == "2026-10-10")
        #expect(ReminderPlanner.briefingDay(now: BerlinTime.parseISO("2026-10-10T07:30:00+02:00")!, minutes: 420) == "2026-10-11")
        #expect(ReminderPlanner.briefingText(events: 2, todos: 1) == "Dein Tag: 2 Termine, 1 fälliges ToDo")
        #expect(ReminderPlanner.briefingText(events: 1, todos: 0) == "Dein Tag: 1 Termin, 0 fällige ToDos")
    }

    @Test func settingsDefaultsAndRoundTrip() {
        let suite = "planer-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        #expect(ReminderSettings.load(defaults) == ReminderSettings())
        var settings = ReminderSettings()
        settings.briefing = true
        settings.briefingMinutes = 6 * 60 + 45
        settings.save(defaults)
        #expect(ReminderSettings.load(defaults) == settings)
        defaults.removePersistentDomain(forName: suite)
    }
}

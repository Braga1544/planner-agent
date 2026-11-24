import Testing
@testable import Planer

struct CalendarGroupingTests {
    @Test func multiDayEventAppearsEachDay() {
        let occurrence = Fixtures.occurrence(start: "2026-10-12T09:00:00+02:00", end: "2026-10-14T17:00:00+02:00")
        #expect(CalendarGrouping.occurrenceDays(occurrence) == ["2026-10-12", "2026-10-13", "2026-10-14"])
    }

    @Test func allDayWithExclusiveEnd() {
        let occurrence = Fixtures.occurrence(allDay: true, start: "2026-10-20T00:00:00+02:00", end: "2026-10-23T00:00:00+02:00")
        #expect(CalendarGrouping.occurrenceDays(occurrence) == ["2026-10-20", "2026-10-21", "2026-10-22"])
    }

    @Test func occurrenceDaysOverMidnight() {
        #expect(CalendarGrouping.occurrenceDays(Fixtures.occurrence(start: "2026-10-12T21:30:00Z", end: "2026-10-12T22:30:00Z")) == ["2026-10-12", "2026-10-13"])
        #expect(CalendarGrouping.occurrenceDays(Fixtures.occurrence(start: "2026-10-11T22:30:00Z", end: nil)) == ["2026-10-12"])
        // across dst (oct 25)
        #expect(CalendarGrouping.occurrenceDays(Fixtures.occurrence(start: "2026-10-24T20:00:00Z", end: "2026-10-25T23:30:00Z")) == ["2026-10-24", "2026-10-25", "2026-10-26"])
    }

    @Test func groupByDayClipsToWeek() {
        let spanning = Fixtures.occurrence(title: "Messe", start: "2026-10-10T09:00:00+02:00", end: "2026-10-13T12:00:00+02:00")
        let grouped = CalendarGrouping.groupByDay([spanning], weekStart: "2026-10-12")
        #expect(grouped.keys.sorted() == ["2026-10-12", "2026-10-13"])
    }

    @Test func upcomingGroupsEventsAndTodosAndKeepsTomorrow() {
        let agenda = Agenda(
            start: "2026-10-11", end: "2026-10-24",
            events: [
                Fixtures.occurrence(title: "Spät", start: "2026-10-14T18:00:00+02:00", end: nil),
                Fixtures.occurrence(title: "Früh", start: "2026-10-14T08:00:00+02:00", end: nil),
            ],
            dueTodos: [Fixtures.item(title: "Steuer", dueDate: "2026-10-16"), Fixtures.item(title: "Außerhalb", dueDate: "2026-11-30")],
            overdueTodos: []
        )
        let days = CalendarGrouping.upcoming(agenda, from: "2026-10-11", to: "2026-10-24")
        #expect(days.map(\.day) == ["2026-10-11", "2026-10-14", "2026-10-16"])
        #expect(days[0].events.isEmpty && days[0].todos.isEmpty)
        #expect(days[1].events.map(\.title) == ["Früh", "Spät"])
        #expect(days[2].todos.map(\.title) == ["Steuer"])
    }

    @Test func timeLabel() {
        #expect(CalendarGrouping.timeLabel(Fixtures.occurrence(allDay: true)) == "ganztägig")
        #expect(CalendarGrouping.timeLabel(Fixtures.occurrence(start: "2026-10-12T12:00:00Z", end: "2026-10-12T13:30:00Z")) == "14:00–15:30")
        #expect(CalendarGrouping.timeLabel(Fixtures.occurrence(start: "2026-10-12T12:00:00Z", end: nil)) == "14:00")
    }
}

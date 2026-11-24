import Testing
@testable import Planer

struct EventFormTests {
    @Test func timedEventUsesOffsetBeforeAndAfterDSTChange() {
        var summer = EventForm.empty(day: "2026-10-12")
        summer.title = "Zahnarzt"
        summer.startTime = "14:00"
        summer.endTime = "15:00"
        #expect(summer.payload() == EventPayload(
            title: "Zahnarzt", startAt: "2026-10-12T14:00:00+02:00", endAt: "2026-10-12T15:00:00+02:00",
            allDay: false, rrule: nil, location: nil, notes: nil, area: nil, reminderMinutes: nil
        ))
        var winter = summer
        winter.startDay = "2026-10-26"
        winter.endDay = "2026-10-26"
        #expect(winter.payload().startAt == "2026-10-26T14:00:00+01:00")
    }

    @Test func allDayInclusiveEndBecomesExclusive() {
        var form = EventForm.empty(day: "2026-10-20")
        form.title = "Urlaub"
        form.allDay = true
        form.endDay = "2026-10-22"
        let payload = form.payload()
        #expect(payload.startAt == "2026-10-20T00:00:00+02:00")
        #expect(payload.endAt == "2026-10-23T00:00:00+02:00")
    }

    @Test func repeatAreaAndReminder() {
        var form = EventForm.empty(day: "2026-10-13")
        form.title = "Training"
        form.repeatRule = .weekly
        form.area = .personal
        form.reminder = 15
        let payload = form.payload()
        #expect(payload.rrule == "FREQ=WEEKLY")
        #expect(payload.area == .personal)
        #expect(payload.reminderMinutes == 15)
        form.repeatRule = .custom
        form.customRule = " FREQ=MONTHLY;BYDAY=1MO "
        #expect(form.payload().rrule == "FREQ=MONTHLY;BYDAY=1MO")
    }

    @Test func eventToFormRestoresInclusiveEndAndRules() {
        var allDay = Fixtures.event(start: "2026-10-19T22:00:00Z", end: "2026-10-22T22:00:00Z", allDay: true, rrule: "FREQ=YEARLY")
        allDay.location = "Ostsee"
        let form = EventForm(event: allDay)
        #expect(form.allDay)
        #expect(form.startDay == "2026-10-20")
        #expect(form.endDay == "2026-10-22")
        #expect(form.repeatRule == .yearly)
        #expect(form.location == "Ostsee")

        let custom = EventForm(event: Fixtures.event(rrule: "FREQ=WEEKLY;BYDAY=TU,TH"))
        #expect(custom.repeatRule == .custom)
        #expect(custom.customRule == "FREQ=WEEKLY;BYDAY=TU,TH")

        let timed = EventForm(event: Fixtures.event(start: "2026-10-12T12:00:00Z", end: "2026-10-12T13:30:00Z"))
        #expect(timed.startTime == "14:00")
        #expect(timed.endTime == "15:30")
    }

    @Test func validation() {
        var base = EventForm.empty(day: "2026-10-12")
        base.title = "X"
        var noTitle = base
        noTitle.title = " "
        #expect(noTitle.validate() == "Titel fehlt.")
        var endBeforeStart = base
        endBeforeStart.startTime = "15:00"
        endBeforeStart.endTime = "14:00"
        #expect(endBeforeStart.validate() == "Ende liegt vor dem Beginn.")
        var noRule = base
        noRule.repeatRule = .custom
        #expect(noRule.validate() == "Regel fehlt.")
        #expect(base.validate() == nil)
    }

    @Test func defaultEndIsOneHourAfterStart() {
        var afternoon = EventForm.empty(day: "2026-10-12")
        afternoon.title = "X"
        afternoon.startTime = "14:30"
        afternoon.setDefaultEnd()
        #expect(afternoon.endDay == "2026-10-12")
        #expect(afternoon.endTime == "15:30")
        #expect(afternoon.validate() == nil)

        var lateEvening = afternoon
        lateEvening.startTime = "23:30"
        lateEvening.setDefaultEnd()
        #expect(lateEvening.endDay == "2026-10-13")
        #expect(lateEvening.endTime == "00:30")
        #expect(lateEvening.validate() == nil)
    }
}

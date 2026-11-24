import Foundation
import Testing
@testable import Planer

struct BerlinTimeTests {
    @Test func zonedToISOUsesOffsetOfThatDay() {
        #expect(BerlinTime.zonedToISO(day: "2026-10-12", time: "14:00") == "2026-10-12T14:00:00+02:00")
        #expect(BerlinTime.zonedToISO(day: "2026-10-26", time: "14:00") == "2026-10-26T14:00:00+01:00")
        #expect(BerlinTime.zonedToISO(day: "2026-10-25", time: "12:00") == "2026-10-25T12:00:00+01:00")
        #expect(BerlinTime.zonedToISO(day: "2026-03-29", time: "12:00") == "2026-03-29T12:00:00+02:00")
        #expect(BerlinTime.zonedToISO(day: "2026-12-31") == "2026-12-31T00:00:00+01:00")
    }

    @Test func isoToZonedNearMidnight() {
        #expect(BerlinTime.isoToZoned("2026-10-12T12:00:00Z") == ZonedDateTime(day: "2026-10-12", time: "14:00"))
        #expect(BerlinTime.isoToZoned("2026-10-11T22:30:00Z") == ZonedDateTime(day: "2026-10-12", time: "00:30"))
        #expect(BerlinTime.isoToZoned("2026-12-31T23:30:00Z") == ZonedDateTime(day: "2027-01-01", time: "00:30"))
        #expect(BerlinTime.isoToZoned("2026-10-12T14:00:00+02:00") == ZonedDateTime(day: "2026-10-12", time: "14:00"))
        #expect(BerlinTime.isoToZoned("2026-10-01T10:00:00.123456Z") == ZonedDateTime(day: "2026-10-01", time: "12:00"))
        #expect(BerlinTime.isoToZoned("kaputt") == nil)
    }

    @Test func todayUsesBerlinDay() {
        let instant = BerlinTime.parseISO("2026-10-11T22:30:00Z")!
        #expect(BerlinTime.today(now: instant) == "2026-10-12")
    }

    @Test func addDaysAndStartOfWeek() {
        #expect(BerlinTime.addDays("2026-10-30", 3) == "2026-11-02")
        #expect(BerlinTime.addDays("2027-01-01", -1) == "2026-12-31")
        #expect(BerlinTime.addDays("2026-10-24", 1) == "2026-10-25")
        #expect(BerlinTime.addDays("2026-10-25", 1) == "2026-10-26")
        #expect(BerlinTime.startOfWeek("2026-10-11") == "2026-10-05")
        #expect(BerlinTime.startOfWeek("2026-10-12") == "2026-10-12")
        #expect(BerlinTime.startOfWeek("2026-10-14") == "2026-10-12")
    }

    @Test func formatting() {
        #expect(BerlinTime.formatTime("2026-10-12T12:00:00Z") == "14:00")
        #expect(BerlinTime.formatDay("2026-10-12").contains("12.10."))
        #expect(BerlinTime.formatLongDay("2026-10-12") == "Montag, 12. Oktober 2026")
        #expect(BerlinTime.formatDateTime("2026-10-12T12:00:00Z").contains("14:00"))
        #expect(BerlinTime.weekdayShort("2026-10-13") == "Di")
        #expect(BerlinTime.dayNumber("2026-10-05") == "5")
    }

    @Test func dateRoundTrip() {
        let date = BerlinTime.date(day: "2026-10-26", time: "09:30")!
        #expect(BerlinTime.dayString(from: date) == "2026-10-26")
        #expect(BerlinTime.timeString(from: date) == "09:30")
    }
}

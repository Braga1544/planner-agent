import SwiftUI

extension Binding where Value == String {
    func asDay() -> Binding<Date> {
        Binding<Date>(
            get: { BerlinTime.date(day: wrappedValue, time: "12:00") ?? Date() },
            set: { wrappedValue = BerlinTime.dayString(from: $0) }
        )
    }

    // fixed day without dst, otherwise the hours jump
    func asTime() -> Binding<Date> {
        Binding<Date>(
            get: { BerlinTime.date(day: "2026-01-15", time: wrappedValue.isEmpty ? "09:00" : wrappedValue) ?? Date() },
            set: { wrappedValue = BerlinTime.timeString(from: $0) }
        )
    }
}

extension Binding where Value == String? {
    func asOptionalDay(default fallback: @escaping () -> String = { BerlinTime.today() }) -> Binding<Date> {
        Binding<Date>(
            get: { BerlinTime.date(day: wrappedValue ?? fallback(), time: "12:00") ?? Date() },
            set: { wrappedValue = BerlinTime.dayString(from: $0) }
        )
    }
}

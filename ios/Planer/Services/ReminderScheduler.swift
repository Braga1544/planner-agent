import Foundation
import UserNotifications

@MainActor
final class ReminderScheduler {
    static let shared = ReminderScheduler()
    private let center = UNUserNotificationCenter.current()
    // bump it, older runs bail out
    private var generation = 0
    private var running: Task<Void, Never>?

    // keep old reminders on network errors, newer run wins
    func refresh(client: APIClient, now: Date? = nil) async {
        generation += 1
        let mine = generation
        let previous = running
        let task = Task { @MainActor in
            _ = await previous?.value
            guard mine == self.generation else { return }
            await self.performRefresh(client: client, now: now ?? Date(), generation: mine)
        }
        running = task
        await task.value
    }

    func clearAll() async {
        generation += 1
        let previous = running
        let task = Task { @MainActor in
            _ = await previous?.value
            await self.removeOurs()
        }
        running = task
        await task.value
    }

    private func performRefresh(client: APIClient, now: Date, generation mine: Int) async {
        let settings = ReminderSettings.load()
        var requests: [UNNotificationRequest] = []
        do {
            if settings.eventReminders {
                requests += try await eventRequests(client: client, now: now)
            }
            if settings.briefing {
                requests.append(try await briefingRequest(client: client, now: now, minutes: settings.briefingMinutes))
            }
        } catch {
            return
        }
        if !requests.isEmpty {
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }
        }
        guard mine == generation else { return } // superseded
        await removeOurs()
        for request in requests {
            try? await center.add(request)
        }
    }

    private func removeOurs() async {
        let ids = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(ReminderPlanner.eventPrefix) || $0 == ReminderPlanner.briefingId }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func eventRequests(client: APIClient, now: Date) async throws -> [UNNotificationRequest] {
        let today = BerlinTime.dayString(from: now)
        let path = "/events" + Query.string([
            ("from", BerlinTime.zonedToISO(day: today)),
            ("to", BerlinTime.zonedToISO(day: BerlinTime.addDays(today, ReminderPlanner.lookaheadDays + 1))),
        ])
        let occurrences: [Occurrence] = try await client.get(path)
        // occurrences have no reminder time, load them one by one
        // imported events never have reminders
        var minutes: [String: Int] = [:]
        for eventId in Set(occurrences.filter { $0.source != .icsImport }.map(\.eventId)) {
            let event: EventOut = try await client.get("/events/\(eventId)")
            if let value = event.reminderMinutes { minutes[eventId] = value }
        }
        return ReminderPlanner.plan(occurrences, reminderMinutes: minutes, now: now).map { reminder in
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            content.userInfo = ["tab": "calendar"]
            var components = BerlinTime.calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate)
            components.timeZone = BerlinTime.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            return UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
        }
    }

    private func briefingRequest(client: APIClient, now: Date, minutes: Int) async throws -> UNNotificationRequest {
        let day = ReminderPlanner.briefingDay(now: now, minutes: minutes)
        let agenda: Agenda = try await client.get("/agenda" + Query.string([("date", day)]))
        let content = UNMutableNotificationContent()
        content.title = "Guten Morgen"
        content.body = ReminderPlanner.briefingText(events: agenda.events.count, todos: agenda.dueTodos.count + agenda.overdueTodos.count)
        content.sound = .default
        content.userInfo = ["tab": "today"]
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        components.timeZone = BerlinTime.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        return UNNotificationRequest(identifier: ReminderPlanner.briefingId, content: content, trigger: trigger)
    }
}

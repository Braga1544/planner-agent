import Foundation

enum AreaSlug: String, Codable, CaseIterable, Identifiable, Hashable {
    case work, business, hobby, personal

    var id: String { rawValue }

    var name: String {
        switch self {
        case .work: "Arbeit"
        case .business: "Business"
        case .hobby: "Hobby"
        case .personal: "Privat"
        }
    }

    var symbol: String {
        switch self {
        case .work: "briefcase"
        case .business: "building.2"
        case .hobby: "paintpalette"
        case .personal: "house"
        }
    }
}

enum ItemType: String, Codable, CaseIterable, Identifiable { case todo, idea, note; var id: String { rawValue } }
enum ItemStatus: String, Codable, CaseIterable, Identifiable { case open, done, archived; var id: String { rawValue } }
enum Priority: String, Codable, CaseIterable, Identifiable { case low, normal, high; var id: String { rawValue } }
enum ProjectStatus: String, Codable, CaseIterable, Identifiable { case active, paused, done, archived; var id: String { rawValue } }
enum EventSource: String, Codable { case local, icsImport = "ics_import", device }
enum MessageRole: String, Codable { case user, assistant }

struct Item: Codable, Identifiable, Hashable {
    let id: String
    var area: AreaSlug
    var projectId: String?
    var type: ItemType
    var title: String
    var body: String?
    var status: ItemStatus
    var priority: Priority
    var dueDate: String?
    var completedAt: String?
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, area, type, title, body, status, priority
        case projectId = "project_id", dueDate = "due_date", completedAt = "completed_at"
        case createdAt = "created_at", updatedAt = "updated_at"
    }
}

struct ItemCreate: Encodable {
    var type: ItemType
    var area: AreaSlug
    var projectId: String?
    var title: String
    var body: String?
    var priority: Priority
    var dueDate: String?

    enum CodingKeys: String, CodingKey {
        case type, area, title, body, priority
        case projectId = "project_id", dueDate = "due_date"
    }
}

// nil goes out as null and clears the field
struct ItemUpdate: Encodable {
    var type: ItemType
    var area: AreaSlug
    var projectId: String?
    var title: String
    var body: String?
    var status: ItemStatus
    var priority: Priority
    var dueDate: String?

    enum CodingKeys: String, CodingKey {
        case type, area, title, body, status, priority
        case projectId = "project_id", dueDate = "due_date"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(area, forKey: .area)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(status, forKey: .status)
        try container.encode(priority, forKey: .priority)
        try container.encode(dueDate, forKey: .dueDate)
    }
}

struct StatusUpdate: Encodable { var status: ItemStatus }

struct Project: Codable, Identifiable, Hashable {
    let id: String
    var area: AreaSlug
    var name: String
    var description: String?
    var status: ProjectStatus
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, area, name, description, status
        case createdAt = "created_at", updatedAt = "updated_at"
    }
}

struct ProjectDetail: Decodable, Identifiable, Hashable {
    let id: String
    var area: AreaSlug
    var name: String
    var description: String?
    var status: ProjectStatus
    var openItems: [Item]

    enum CodingKeys: String, CodingKey {
        case id, area, name, description, status
        case openItems = "open_items"
    }
}

struct ProjectCreate: Encodable { var area: AreaSlug; var name: String }

struct ProjectDescriptionUpdate: Encodable {
    var description: String?
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(description, forKey: .description)
    }
    enum CodingKeys: String, CodingKey { case description }
}

struct ProjectStatusUpdate: Encodable { var status: ProjectStatus }

struct EventOut: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var location: String?
    var notes: String?
    var startAt: String
    var endAt: String?
    var allDay: Bool
    var rrule: String?
    var area: AreaSlug?
    var projectId: String?
    var reminderMinutes: Int?
    var source: EventSource
    var calendarSourceId: String?
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, location, notes, rrule, area, source
        case startAt = "start_at", endAt = "end_at", allDay = "all_day", projectId = "project_id"
        case reminderMinutes = "reminder_minutes", calendarSourceId = "calendar_source_id"
        case createdAt = "created_at", updatedAt = "updated_at"
    }
}

// nil -> null
struct EventPayload: Encodable, Equatable {
    var title: String
    var startAt: String
    var endAt: String?
    var allDay: Bool
    var rrule: String?
    var location: String?
    var notes: String?
    var area: AreaSlug?
    var reminderMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case title, rrule, location, notes, area
        case startAt = "start_at", endAt = "end_at", allDay = "all_day", reminderMinutes = "reminder_minutes"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(startAt, forKey: .startAt)
        try container.encode(endAt, forKey: .endAt)
        try container.encode(allDay, forKey: .allDay)
        try container.encode(rrule, forKey: .rrule)
        try container.encode(location, forKey: .location)
        try container.encode(notes, forKey: .notes)
        try container.encode(area, forKey: .area)
        try container.encode(reminderMinutes, forKey: .reminderMinutes)
    }
}

struct Occurrence: Codable, Hashable, Identifiable {
    var eventId: String
    var title: String
    var location: String?
    var notes: String?
    var allDay: Bool
    var area: AreaSlug?
    var projectId: String?
    var source: EventSource
    var isRecurring: Bool
    var occurrenceStart: String
    var occurrenceEnd: String?

    var id: String { "\(eventId)-\(occurrenceStart)" }

    enum CodingKeys: String, CodingKey {
        case title, location, notes, area, source
        case eventId = "event_id", allDay = "all_day", projectId = "project_id", isRecurring = "is_recurring"
        case occurrenceStart = "occurrence_start", occurrenceEnd = "occurrence_end"
    }
}

struct Agenda: Decodable, Hashable {
    var start: String
    var end: String
    var events: [Occurrence]
    var dueTodos: [Item]
    var overdueTodos: [Item]

    enum CodingKeys: String, CodingKey {
        case start, end, events
        case dueTodos = "due_todos", overdueTodos = "overdue_todos"
    }
}

struct SearchResults: Decodable, Equatable { var items: [Item]; var projects: [Project]; var events: [EventOut] }

struct CalendarSource: Decodable, Identifiable, Hashable {
    let id: String
    var name: String
    var url: String
    var area: AreaSlug?
    var enabled: Bool
    var lastSyncedAt: String?
    var lastError: String?

    enum CodingKeys: String, CodingKey {
        case id, name, url, area, enabled
        case lastSyncedAt = "last_synced_at", lastError = "last_error"
    }
}

struct CalendarSourceCreate: Encodable { var name: String; var url: String; var area: AreaSlug? }
struct EnabledUpdate: Encodable { var enabled: Bool }

struct SyncResult: Decodable, Equatable { var created: Int; var updated: Int; var deleted: Int; var error: String? }

struct Conversation: Decodable, Identifiable, Hashable {
    let id: String
    var title: String?
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, title
        case updatedAt = "updated_at"
    }
}

struct Message: Decodable, Identifiable, Hashable {
    let id: String
    var seq: Int
    var role: MessageRole
    var content: [JSONValue]
}

struct Me: Decodable {
    var tokenName: String
    enum CodingKeys: String, CodingKey { case tokenName = "token_name" }
}

struct ChatRequest: Encodable { var text: String }

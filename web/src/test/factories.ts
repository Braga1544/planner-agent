import type { CalendarSource, EventOut, Item, Message, Occurrence, Project } from "../lib/types";

const STAMP = "2026-10-01T10:00:00Z";

export function makeItem(overrides: Partial<Item> = {}): Item {
  return {
    id: crypto.randomUUID(),
    area: "personal",
    project_id: null,
    type: "todo",
    title: "ToDo",
    body: null,
    status: "open",
    priority: "normal",
    due_date: null,
    completed_at: null,
    created_at: STAMP,
    updated_at: STAMP,
    ...overrides,
  };
}

export function makeProject(overrides: Partial<Project> = {}): Project {
  return {
    id: crypto.randomUUID(),
    area: "hobby",
    name: "Projekt",
    description: null,
    status: "active",
    created_at: STAMP,
    updated_at: STAMP,
    ...overrides,
  };
}

export function makeOccurrence(overrides: Partial<Occurrence> = {}): Occurrence {
  return {
    event_id: crypto.randomUUID(),
    title: "Termin",
    location: null,
    notes: null,
    all_day: false,
    area: null,
    project_id: null,
    source: "local",
    is_recurring: false,
    occurrence_start: "2026-10-12T09:00:00+02:00",
    occurrence_end: "2026-10-12T10:00:00+02:00",
    ...overrides,
  };
}

export function makeEvent(overrides: Partial<EventOut> = {}): EventOut {
  return {
    id: crypto.randomUUID(),
    title: "Termin",
    location: null,
    notes: null,
    start_at: "2026-10-12T07:00:00Z",
    end_at: "2026-10-12T08:00:00Z",
    all_day: false,
    rrule: null,
    area: null,
    project_id: null,
    reminder_minutes: null,
    source: "local",
    calendar_source_id: null,
    created_at: STAMP,
    updated_at: STAMP,
    ...overrides,
  };
}

export function makeMessage(overrides: Partial<Message> = {}): Message {
  return {
    id: crypto.randomUUID(),
    seq: 1,
    role: "assistant",
    content: [{ type: "text", text: "Hallo" }],
    usage: null,
    created_at: STAMP,
    ...overrides,
  };
}

export function makeSource(overrides: Partial<CalendarSource> = {}): CalendarSource {
  return {
    id: crypto.randomUUID(),
    name: "Teams",
    url: "https://example.com/teams.ics",
    area: "work",
    enabled: true,
    last_synced_at: null,
    last_error: null,
    created_at: STAMP,
    updated_at: STAMP,
    ...overrides,
  };
}

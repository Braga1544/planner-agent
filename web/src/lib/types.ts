export type AreaSlug = "work" | "business" | "hobby" | "personal";
export type ItemType = "todo" | "idea" | "note";
export type ItemStatus = "open" | "done" | "archived";
export type Priority = "low" | "normal" | "high";
export type ProjectStatus = "active" | "paused" | "done" | "archived";
type EventSource = "local" | "ics_import" | "device";

interface Area {
  slug: AreaSlug;
  name: string;
}

export const AREAS: Area[] = [
  { slug: "work", name: "Arbeit" },
  { slug: "business", name: "Business" },
  { slug: "hobby", name: "Hobby" },
  { slug: "personal", name: "Privat" },
];

export function areaName(slug: string): string {
  return AREAS.find((area) => area.slug === slug)?.name ?? slug;
}

export interface Item {
  id: string;
  area: AreaSlug;
  project_id: string | null;
  type: ItemType;
  title: string;
  body: string | null;
  status: ItemStatus;
  priority: Priority;
  due_date: string | null;
  completed_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface ItemCreate {
  type: ItemType;
  area: AreaSlug;
  project_id?: string | null;
  title: string;
  body?: string | null;
  priority?: Priority;
  due_date?: string | null;
}

export interface ItemUpdate {
  type?: ItemType;
  area?: AreaSlug;
  project_id?: string | null;
  title?: string;
  body?: string | null;
  status?: ItemStatus;
  priority?: Priority;
  due_date?: string | null;
}

export interface Project {
  id: string;
  area: AreaSlug;
  name: string;
  description: string | null;
  status: ProjectStatus;
  created_at: string;
  updated_at: string;
}

export interface ProjectDetail extends Project {
  open_items: Item[];
}

export interface ProjectUpdate {
  name?: string;
  description?: string | null;
  status?: ProjectStatus;
}

export interface EventOut {
  id: string;
  title: string;
  location: string | null;
  notes: string | null;
  start_at: string;
  end_at: string | null;
  all_day: boolean;
  rrule: string | null;
  area: AreaSlug | null;
  project_id: string | null;
  reminder_minutes: number | null;
  source: EventSource;
  calendar_source_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface EventPayload {
  title: string;
  start_at: string;
  end_at: string | null;
  all_day: boolean;
  rrule: string | null;
  location: string | null;
  notes: string | null;
  area: AreaSlug | null;
  reminder_minutes: number | null;
}

export interface Occurrence {
  event_id: string;
  title: string;
  location: string | null;
  notes: string | null;
  all_day: boolean;
  area: AreaSlug | null;
  project_id: string | null;
  source: EventSource;
  is_recurring: boolean;
  occurrence_start: string;
  occurrence_end: string | null;
}

export interface Agenda {
  start: string;
  end: string;
  events: Occurrence[];
  due_todos: Item[];
  overdue_todos: Item[];
}

export interface SearchResults {
  items: Item[];
  projects: Project[];
  events: EventOut[];
}

export interface CalendarSource {
  id: string;
  name: string;
  url: string;
  area: AreaSlug | null;
  enabled: boolean;
  last_synced_at: string | null;
  last_error: string | null;
  created_at: string;
  updated_at: string;
}

export interface CalendarSourceCreate {
  name: string;
  url: string;
  area: AreaSlug | null;
}

export interface SyncResult {
  created: number;
  updated: number;
  deleted: number;
  error: string | null;
}

export interface Conversation {
  id: string;
  title: string | null;
  created_at: string;
  updated_at: string;
}

interface ContentBlock {
  type: string;
  [key: string]: unknown;
}

export interface Message {
  id: string;
  seq: number;
  role: "user" | "assistant";
  content: ContentBlock[];
  usage: Record<string, unknown> | null;
  created_at: string;
}

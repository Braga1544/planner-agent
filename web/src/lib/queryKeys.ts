export const keys = {
  me: ["me"] as const,
  agenda: (from: string, to: string) => ["agenda", from, to] as const,
  events: (from: string, to: string) => ["events", from, to] as const,
  event: (id: string) => ["event", id] as const,
  items: (filter: Record<string, string | undefined>) => ["items", filter] as const,
  projects: (area?: string) => ["projects", area ?? "alle"] as const,
  project: (id: string) => ["project", id] as const,
  conversations: ["conversations"] as const,
  messages: (id: string) => ["messages", id] as const,
  sources: ["calendar-sources"] as const,
  search: (q: string) => ["search", q] as const,
};

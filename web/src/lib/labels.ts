import type { ItemStatus, ItemType, Priority, ProjectStatus } from "./types";

export const ITEM_TYPE_LABELS: Record<ItemType, string> = { todo: "ToDo", idea: "Idee", note: "Notiz" };
export const ITEM_GROUP_LABELS: Record<ItemType, string> = { todo: "ToDos", idea: "Ideen", note: "Notizen" };
export const PRIORITY_LABELS: Record<Priority, string> = { high: "hoch", normal: "normal", low: "niedrig" };
export const ITEM_STATUS_LABELS: Record<ItemStatus, string> = { open: "offen", done: "erledigt", archived: "archiviert" };
export const PROJECT_STATUS_LABELS: Record<ProjectStatus, string> = {
  active: "Aktiv",
  paused: "Pausiert",
  done: "Erledigt",
  archived: "Archiviert",
};

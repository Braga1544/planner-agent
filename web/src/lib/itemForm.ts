import type { AreaSlug, Item, ItemCreate, ItemStatus, ItemType, ItemUpdate, Priority } from "./types";

export interface ItemFormValues {
  type: ItemType;
  title: string;
  body: string;
  area: AreaSlug;
  projectId: string;
  priority: Priority;
  dueDate: string;
  status: ItemStatus;
}

export function emptyItemForm(
  defaults: { area?: AreaSlug; projectId?: string | null; type?: ItemType } = {},
): ItemFormValues {
  return {
    type: defaults.type ?? "todo",
    title: "",
    body: "",
    area: defaults.area ?? "personal",
    projectId: defaults.projectId ?? "",
    priority: "normal",
    dueDate: "",
    status: "open",
  };
}

export function itemToForm(item: Item): ItemFormValues {
  return {
    type: item.type,
    title: item.title,
    body: item.body ?? "",
    area: item.area,
    projectId: item.project_id ?? "",
    priority: item.priority,
    dueDate: item.due_date ?? "",
    status: item.status,
  };
}

export function formToItemCreate(values: ItemFormValues): ItemCreate {
  return {
    type: values.type,
    area: values.area,
    project_id: values.projectId || null,
    title: values.title.trim(),
    body: values.body.trim() || null,
    priority: values.priority,
    due_date: values.type === "todo" && values.dueDate ? values.dueDate : null,
  };
}

export function formToItemUpdate(values: ItemFormValues): ItemUpdate {
  return { ...formToItemCreate(values), status: values.status };
}

export function groupByType(items: Item[]): Record<ItemType, Item[]> {
  const groups: Record<ItemType, Item[]> = { todo: [], idea: [], note: [] };
  for (const item of items) groups[item.type].push(item);
  return groups;
}

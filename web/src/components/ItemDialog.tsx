import { useQuery } from "@tanstack/react-query";
import { useState, type FormEvent } from "react";
import { api } from "../lib/api";
import { emptyItemForm, formToItemCreate, formToItemUpdate, itemToForm, type ItemFormValues } from "../lib/itemForm";
import { ITEM_STATUS_LABELS, ITEM_TYPE_LABELS, PRIORITY_LABELS } from "../lib/labels";
import { useArchiveItem, useCreateItem, useUpdateItem } from "../lib/mutations";
import { keys } from "../lib/queryKeys";
import { AREAS, type AreaSlug, type Item, type ItemStatus, type ItemType, type Priority, type Project } from "../lib/types";
import { ErrorBanner } from "./ErrorBanner";
import { Modal, ModalFooter } from "./Modal";
import { buttonClass, dangerButtonClass, Field, inputClass } from "./ui";

export function ItemDialog({
  item,
  defaults,
  onClose,
}: {
  item?: Item;
  defaults?: { area?: AreaSlug; projectId?: string | null; type?: ItemType };
  onClose: () => void;
}) {
  const [values, setValues] = useState<ItemFormValues>(() => (item ? itemToForm(item) : emptyItemForm(defaults)));
  const projects = useQuery({
    queryKey: keys.projects(values.area),
    queryFn: () => api.get<Project[]>(`/projects?area=${values.area}`),
  });
  const create = useCreateItem();
  const update = useUpdateItem();
  const archive = useArchiveItem();
  const error = create.error ?? update.error ?? archive.error;
  const busy = create.isPending || update.isPending || archive.isPending;

  function set<K extends keyof ItemFormValues>(key: K, value: ItemFormValues[K]) {
    setValues((current) => ({ ...current, [key]: value }));
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!values.title.trim()) return;
    try {
      if (item) await update.mutateAsync({ id: item.id, changes: formToItemUpdate(values) });
      else await create.mutateAsync(formToItemCreate(values));
      onClose();
    } catch {
      // error shows below
    }
  }

  async function onArchive() {
    if (!item || !window.confirm(`„${item.title}“ archivieren?`)) return;
    try {
      await archive.mutateAsync(item.id);
      onClose();
    } catch {
      // error shows below
    }
  }

  return (
    <Modal title={item ? "Eintrag bearbeiten" : "Neuer Eintrag"} onClose={onClose}>
      <form onSubmit={submit} className="space-y-4">
        <div className="grid grid-cols-2 gap-3">
          <Field label="Typ">
            <select value={values.type} onChange={(e) => set("type", e.target.value as ItemType)} className={inputClass}>
              {(Object.keys(ITEM_TYPE_LABELS) as ItemType[]).map((type) => (
                <option key={type} value={type}>
                  {ITEM_TYPE_LABELS[type]}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Priorität">
            <select value={values.priority} onChange={(e) => set("priority", e.target.value as Priority)} className={inputClass}>
              {(Object.keys(PRIORITY_LABELS) as Priority[]).map((priority) => (
                <option key={priority} value={priority}>
                  {PRIORITY_LABELS[priority]}
                </option>
              ))}
            </select>
          </Field>
        </div>
        <Field label="Titel">
          <input value={values.title} onChange={(e) => set("title", e.target.value)} className={inputClass} />
        </Field>
        <Field label="Details">
          <textarea rows={4} value={values.body} onChange={(e) => set("body", e.target.value)} className={inputClass} />
        </Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Bereich">
            <select
              value={values.area}
              onChange={(e) => setValues((current) => ({ ...current, area: e.target.value as AreaSlug, projectId: "" }))}
              className={inputClass}
            >
              {AREAS.map((area) => (
                <option key={area.slug} value={area.slug}>
                  {area.name}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Projekt">
            <select value={values.projectId} onChange={(e) => set("projectId", e.target.value)} className={inputClass}>
              <option value="">— kein Projekt —</option>
              {projects.data?.map((project) => (
                <option key={project.id} value={project.id}>
                  {project.name}
                </option>
              ))}
            </select>
          </Field>
        </div>
        {values.type === "todo" && (
          <Field label="Fällig am">
            <input type="date" value={values.dueDate} onChange={(e) => set("dueDate", e.target.value)} className={inputClass} />
          </Field>
        )}
        {item && (
          <Field label="Status">
            <select value={values.status} onChange={(e) => set("status", e.target.value as ItemStatus)} className={inputClass}>
              {(Object.keys(ITEM_STATUS_LABELS) as ItemStatus[]).map((status) => (
                <option key={status} value={status}>
                  {ITEM_STATUS_LABELS[status]}
                </option>
              ))}
            </select>
          </Field>
        )}
        {error && <ErrorBanner error={error} />}
        <ModalFooter
          start={
            item && (
              <button type="button" className={dangerButtonClass} disabled={busy} onClick={() => void onArchive()}>
                Archivieren
              </button>
            )
          }
        >
          <button type="submit" className={buttonClass} disabled={busy || !values.title.trim()}>
            Speichern
          </button>
        </ModalFooter>
      </form>
    </Modal>
  );
}

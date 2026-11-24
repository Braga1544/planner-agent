import { Pencil, Plus } from "lucide-react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { useState, type FormEvent } from "react";
import { Link, useParams } from "react-router";
import { ErrorBanner } from "../components/ErrorBanner";
import { ItemDialog } from "../components/ItemDialog";
import { ItemRow } from "../components/ItemRow";
import { Markdown } from "../components/Markdown";
import {
  buttonClass,
  cardClass,
  compactInputClass,
  ghostButtonClass,
  inputClass,
  PageHeader,
  Section,
  SectionHeader,
  secondaryButtonClass,
} from "../components/ui";
import { api } from "../lib/api";
import { groupByType } from "../lib/itemForm";
import { ITEM_GROUP_LABELS, PROJECT_STATUS_LABELS } from "../lib/labels";
import { useInvalidateAll } from "../lib/mutations";
import { keys } from "../lib/queryKeys";
import { areaName, type Item, type ItemType, type Project, type ProjectDetail, type ProjectStatus, type ProjectUpdate } from "../lib/types";

export function ProjectPage() {
  const { id = "" } = useParams();
  const invalidate = useInvalidateAll();
  const project = useQuery({ queryKey: keys.project(id), queryFn: () => api.get<ProjectDetail>(`/projects/${id}`) });
  const update = useMutation({
    mutationFn: (changes: ProjectUpdate) => api.patch<Project>(`/projects/${id}`, changes),
    onSuccess: invalidate,
  });
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState("");
  const [dialog, setDialog] = useState<{ item?: Item } | null>(null);

  if (project.isPending) return <p className="text-muted">Lädt…</p>;
  if (project.isError) return <ErrorBanner error={project.error} />;
  const data = project.data;
  const groups = groupByType(data.open_items);

  async function saveDescription(event: FormEvent) {
    event.preventDefault();
    try {
      await update.mutateAsync({ description: draft.trim() || null });
      setEditing(false);
    } catch {
      // error shows below
    }
  }

  return (
    <div className="space-y-8">
      <div className="space-y-3">
        <Link
          to={`/bereiche/${data.area}`}
          className="inline-flex rounded text-sm text-muted transition-colors hover:text-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/40"
        >
          ← {areaName(data.area)}
        </Link>
        <PageHeader title={data.name}>
          <label className="flex items-center gap-2 text-sm text-muted">
            Status
            <select
              value={data.status}
              onChange={(e) => update.mutate({ status: e.target.value as ProjectStatus })}
              className={compactInputClass}
            >
              {(Object.keys(PROJECT_STATUS_LABELS) as ProjectStatus[]).map((status) => (
                <option key={status} value={status}>
                  {PROJECT_STATUS_LABELS[status]}
                </option>
              ))}
            </select>
          </label>
        </PageHeader>
      </div>
      {update.isError && <ErrorBanner error={update.error} />}

      <section aria-label="Projektinfos" className="space-y-1.5">
        <SectionHeader title="Projektinfos">
          {!editing && (
            <button
              type="button"
              className={`${ghostButtonClass} -mr-2`}
              onClick={() => {
                setDraft(data.description ?? "");
                setEditing(true);
              }}
            >
              <Pencil aria-hidden="true" />
              Bearbeiten
            </button>
          )}
        </SectionHeader>
        {editing ? (
          <form onSubmit={saveDescription} className={`${cardClass} space-y-3 p-3`}>
            <textarea
              aria-label="Projektinfos bearbeiten"
              rows={10}
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              className={`${inputClass} font-mono`}
            />
            <div className="flex justify-end gap-2">
              <button type="button" className={secondaryButtonClass} onClick={() => setEditing(false)}>
                Abbrechen
              </button>
              <button type="submit" className={buttonClass} disabled={update.isPending}>
                Speichern
              </button>
            </div>
          </form>
        ) : data.description ? (
          <div className={`${cardClass} px-5 py-4`}>
            <Markdown>{data.description}</Markdown>
          </div>
        ) : (
          <p className="px-1 text-sm text-muted">Noch keine Projektinfos.</p>
        )}
      </section>

      <section aria-label="Offene Einträge" className="space-y-4">
        <div className="flex items-center justify-between gap-3 border-t border-border pt-6">
          <h2 className="text-base font-semibold tracking-tight">Offene Einträge</h2>
          <button type="button" className={buttonClass} onClick={() => setDialog({})}>
            <Plus aria-hidden="true" />
            Neuer Eintrag
          </button>
        </div>
        {(Object.keys(ITEM_GROUP_LABELS) as ItemType[]).map((type) => (
          <Section key={type} title={ITEM_GROUP_LABELS[type]} empty="Keine.">
            {groups[type].map((item) => (
              <ItemRow key={item.id} item={item} showArea={false} onEdit={(selected) => setDialog({ item: selected })} />
            ))}
          </Section>
        ))}
      </section>

      {dialog && (
        <ItemDialog item={dialog.item} defaults={{ area: data.area, projectId: data.id }} onClose={() => setDialog(null)} />
      )}
    </div>
  );
}

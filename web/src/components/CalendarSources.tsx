import { CalendarSync, Plus, RefreshCw, Trash2 } from "lucide-react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { useState, type FormEvent } from "react";
import { api } from "../lib/api";
import { useInvalidateAll } from "../lib/mutations";
import { keys } from "../lib/queryKeys";
import { formatDateTime } from "../lib/time";
import {
  AREAS,
  areaName,
  type AreaSlug,
  type CalendarSource,
  type CalendarSourceCreate,
  type SyncResult,
} from "../lib/types";
import { ErrorBanner } from "./ErrorBanner";
import { buttonClass, cardClass, dangerButtonClass, Field, inputClass, SectionHeader, secondaryButtonClass } from "./ui";

function syncSummary(result: SyncResult): string {
  return result.error ?? `${result.created} neu, ${result.updated} geändert, ${result.deleted} entfernt`;
}

export function CalendarSourcesSection() {
  const invalidate = useInvalidateAll();
  const sources = useQuery({ queryKey: keys.sources, queryFn: () => api.get<CalendarSource[]>("/calendar-sources") });
  const [lastSync, setLastSync] = useState<{ id: string; result: SyncResult } | null>(null);
  const [form, setForm] = useState<{ name: string; url: string; area: AreaSlug | "" }>({ name: "", url: "", area: "" });

  const create = useMutation({
    mutationFn: (data: CalendarSourceCreate) => api.post<CalendarSource>("/calendar-sources", data),
    onSuccess: async () => {
      setForm({ name: "", url: "", area: "" });
      await invalidate();
    },
  });
  const toggle = useMutation({
    mutationFn: (source: CalendarSource) => api.patch<CalendarSource>(`/calendar-sources/${source.id}`, { enabled: !source.enabled }),
    onSuccess: invalidate,
  });
  const remove = useMutation({ mutationFn: (id: string) => api.delete(`/calendar-sources/${id}`), onSuccess: invalidate });
  const sync = useMutation({
    mutationFn: (id: string) => api.post<SyncResult>(`/calendar-sources/${id}/sync`),
    onSuccess: async (result, id) => {
      setLastSync({ id, result });
      await invalidate();
    },
  });
  const error = create.error ?? toggle.error ?? remove.error ?? sync.error ?? sources.error;

  function submit(event: FormEvent) {
    event.preventDefault();
    if (!form.name.trim() || !form.url.trim()) return;
    create.mutate({ name: form.name.trim(), url: form.url.trim(), area: form.area || null });
  }

  return (
    <section aria-label="Kalenderquellen" className="space-y-1.5">
      <SectionHeader title="Kalenderquellen" />
      <div className={`${cardClass} overflow-hidden`}>
        <p className="px-4 py-3 text-sm text-muted">
          Externe Kalender (z. B. veröffentlichter Outlook/Teams-Kalender) als ICS-Link. Sie werden alle 15 Minuten
          abgeglichen und sind im Agenten nur lesbar.
        </p>
        {error && (
          <div className="px-4 pb-3">
            <ErrorBanner error={error} />
          </div>
        )}
        {sources.data && sources.data.length > 0 && (
          <ul className="divide-y divide-border border-t border-border">
            {sources.data.map((source) => (
              <li key={source.id} className="space-y-2 px-4 py-3 text-sm">
                <div className="flex flex-wrap items-center gap-x-3 gap-y-2">
                  <span className="mr-auto flex min-w-0 items-center gap-2 font-medium">
                    <CalendarSync aria-hidden="true" className="size-4 shrink-0 text-muted" strokeWidth={1.75} />
                    <span className="truncate">{source.name}</span>
                    {source.area && (
                      <span className="rounded-md border border-border px-1.5 text-xs font-normal leading-5 text-muted">
                        {areaName(source.area)}
                      </span>
                    )}
                  </span>
                  <label className="flex cursor-pointer items-center gap-1.5 text-muted">
                    <input
                      type="checkbox"
                      className="size-4"
                      aria-label={`${source.name} aktiv`}
                      checked={source.enabled}
                      onChange={() => toggle.mutate(source)}
                    />
                    aktiv
                  </label>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      aria-label={`${source.name} synchronisieren`}
                      className={secondaryButtonClass}
                      disabled={sync.isPending}
                      onClick={() => sync.mutate(source.id)}
                    >
                      <RefreshCw aria-hidden="true" className={sync.isPending ? "motion-safe:animate-spin" : ""} />
                      Jetzt synchronisieren
                    </button>
                    <button
                      type="button"
                      aria-label={`${source.name} löschen`}
                      className={dangerButtonClass}
                      onClick={() => {
                        if (window.confirm(`Kalenderquelle „${source.name}“ und ihre Termine löschen?`)) remove.mutate(source.id);
                      }}
                    >
                      <Trash2 aria-hidden="true" />
                      Löschen
                    </button>
                  </div>
                </div>
                <div className="space-y-0.5 text-xs text-muted">
                  <div className="truncate font-mono">{source.url}</div>
                  <div>Zuletzt synchronisiert: {source.last_synced_at ? formatDateTime(source.last_synced_at) : "noch nie"}</div>
                  {source.last_error && <div className="text-danger">{source.last_error}</div>}
                  {lastSync?.id === source.id && (
                    <div className={lastSync.result.error ? "text-danger" : "text-muted"}>{syncSummary(lastSync.result)}</div>
                  )}
                </div>
              </li>
            ))}
          </ul>
        )}
        <form onSubmit={submit} className="grid gap-4 border-t border-border bg-bg/60 px-4 py-4 sm:grid-cols-2">
          <Field label="Name">
            <input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} className={inputClass} />
          </Field>
          <Field label="Bereich">
            <select value={form.area} onChange={(e) => setForm({ ...form, area: e.target.value as AreaSlug | "" })} className={inputClass}>
              <option value="">— keiner —</option>
              {AREAS.map((area) => (
                <option key={area.slug} value={area.slug}>
                  {area.name}
                </option>
              ))}
            </select>
          </Field>
          <div className="sm:col-span-2">
            <Field label="ICS-URL">
              <input value={form.url} onChange={(e) => setForm({ ...form, url: e.target.value })} placeholder="https://… oder webcal://…" className={inputClass} />
            </Field>
          </div>
          <div className="flex justify-end sm:col-span-2">
            <button type="submit" className={buttonClass} disabled={create.isPending || !form.name.trim() || !form.url.trim()}>
              <Plus aria-hidden="true" />
              Hinzufügen
            </button>
          </div>
        </form>
      </div>
    </section>
  );
}

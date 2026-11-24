import { Plus } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { useSearchParams } from "react-router";
import { EventDialog, type EventDialogState } from "../components/EventDialog";
import { ErrorBanner } from "../components/ErrorBanner";
import { OccurrenceRow } from "../components/OccurrenceRow";
import { buttonClass, cardClass, PageHeader } from "../components/ui";
import { api } from "../lib/api";
import { groupByDay } from "../lib/calendar";
import { keys } from "../lib/queryKeys";
import { addDays, formatDay, formatLongDay, startOfWeek, todayBerlin, zonedToIso } from "../lib/time";
import type { Occurrence } from "../lib/types";

const segmentClass =
  "inline-flex min-h-9 sm:min-h-8 items-center rounded-md px-3 text-sm font-medium text-text/80 transition-colors hover:bg-bg hover:text-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/40";

const monthFormatter = new Intl.DateTimeFormat("de-DE", { timeZone: "UTC", month: "long", year: "numeric" });
const monthOnlyFormatter = new Intl.DateTimeFormat("de-DE", { timeZone: "UTC", month: "long" });

function monthRange(first: string, last: string): string {
  const toDate = (day: string) => new Date(`${day}T00:00:00Z`);
  if (first.slice(0, 7) === last.slice(0, 7)) return monthFormatter.format(toDate(first));
  const start = first.slice(0, 4) === last.slice(0, 4) ? monthOnlyFormatter.format(toDate(first)) : monthFormatter.format(toDate(first));
  return `${start} – ${monthFormatter.format(toDate(last))}`;
}

export function CalendarPage() {
  const [params, setParams] = useSearchParams();
  const today = todayBerlin();
  const weekStart = startOfWeek(params.get("woche") ?? today);
  const weekEnd = addDays(weekStart, 7);
  const from = zonedToIso(weekStart);
  const to = zonedToIso(weekEnd);
  const events = useQuery({
    queryKey: keys.events(from, to),
    queryFn: () => api.get<Occurrence[]>(`/events?from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`),
  });
  const [dialog, setDialog] = useState<EventDialogState | null>(null);
  const days = Array.from({ length: 7 }, (_, index) => addDays(weekStart, index));
  const byDay = useMemo(() => groupByDay(events.data ?? [], weekStart), [events.data, weekStart]);
  const defaultDay = today >= weekStart && today < weekEnd ? today : weekStart;

  return (
    <div className="space-y-6">
      <PageHeader title={`Woche ab ${formatDay(weekStart)}`} subtitle={monthRange(weekStart, addDays(weekEnd, -1))}>
        <div className="flex w-full items-center gap-2 sm:w-auto">
          <div className="flex flex-1 rounded-lg border border-border bg-surface p-0.5 sm:flex-none [&>button]:flex-1 [&>button]:justify-center">
            <button type="button" className={segmentClass} onClick={() => setParams({ woche: addDays(weekStart, -7) })}>
              ← Woche
            </button>
            <button type="button" className={segmentClass} onClick={() => setParams({})}>
              Heute
            </button>
            <button type="button" className={segmentClass} onClick={() => setParams({ woche: weekEnd })}>
              Woche →
            </button>
          </div>
          <button
            type="button"
            title="Neuer Termin"
            className={`${buttonClass} px-2.5 sm:px-3.5`}
            onClick={() => setDialog({ mode: "create", day: defaultDay })}
          >
            <Plus aria-hidden="true" />
            {/* narrow screens: just the plus, name stays for screen readers */}
            <span className="sr-only sm:not-sr-only">Neuer Termin</span>
          </button>
        </div>
      </PageHeader>
      {events.isError && <ErrorBanner error={events.error} />}
      {events.isPending && <p className="text-muted">Lädt…</p>}
      <div className={`${cardClass} divide-y divide-border overflow-hidden`}>
        {days.map((day) => {
          const isToday = day === today;
          const [weekdayShort] = formatDay(day).split(",");
          return (
            <section key={day} aria-label={formatLongDay(day)} className="flex min-h-16">
              <h2 className="sr-only">
                {formatLongDay(day)}
                {isToday && " · heute"}
              </h2>
              <div
                aria-hidden="true"
                className={`flex w-16 shrink-0 flex-col items-center justify-start border-r border-border px-2 pt-2.5 pb-2 sm:w-20 ${
                  isToday ? "bg-accent-soft" : ""
                }`}
              >
                <span className={`text-xs ${isToday ? "font-medium text-accent" : "text-muted"}`}>{weekdayShort.replace(".", "")}</span>
                <span className={`text-2xl font-semibold leading-tight tabular-nums ${isToday ? "text-accent" : ""}`}>
                  {Number(day.slice(8, 10))}
                </span>
              </div>
              <div className="min-w-0 flex-1 py-1">
                {byDay[day]?.length ? (
                  <ul>
                    {byDay[day].map((occurrence) => (
                      <OccurrenceRow
                        key={`${occurrence.event_id}-${occurrence.occurrence_start}`}
                        occurrence={occurrence}
                        onSelect={(selected) => setDialog({ mode: "edit", eventId: selected.event_id })}
                      />
                    ))}
                  </ul>
                ) : (
                  <p className="px-4 py-2.5 text-sm text-muted/60">—</p>
                )}
              </div>
            </section>
          );
        })}
      </div>
      {dialog && <EventDialog state={dialog} onClose={() => setDialog(null)} />}
    </div>
  );
}

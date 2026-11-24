import { keepPreviousData, useQuery } from "@tanstack/react-query";
import { ErrorBanner } from "../components/ErrorBanner";
import { ItemRow } from "../components/ItemRow";
import { OccurrenceRow } from "../components/OccurrenceRow";
import { QuickAddTodo } from "../components/QuickAddTodo";
import { Section, secondaryButtonClass } from "../components/ui";
import { useState } from "react";
import { api } from "../lib/api";
import { occurrenceDays } from "../lib/calendar";
import { keys } from "../lib/queryKeys";
import { addDays, formatDay, formatLongDay, todayBerlin } from "../lib/time";
import type { Agenda, Item, Occurrence } from "../lib/types";

const INITIAL_DAYS = 14;
const MORE_DAYS = 7;
const MAX_DAYS = 365;

interface UpcomingDay {
  day: string;
  events: Occurrence[];
  todos: Item[];
}

function groupUpcoming(data: Agenda, from: string, to: string): UpcomingDay[] {
  const byDay = new Map<string, UpcomingDay>();
  const bucket = (day: string) => {
    let entry = byDay.get(day);
    if (!entry) byDay.set(day, (entry = { day, events: [], todos: [] }));
    return entry;
  };
  for (const occurrence of data.events) {
    for (const day of occurrenceDays(occurrence)) {
      if (day >= from && day <= to) bucket(day).events.push(occurrence);
    }
  }
  for (const item of data.due_todos) {
    if (item.due_date && item.due_date >= from && item.due_date <= to) bucket(item.due_date).todos.push(item);
  }
  for (const entry of byDay.values()) {
    entry.events.sort((a, b) => a.occurrence_start.localeCompare(b.occurrence_start));
  }
  const days: UpcomingDay[] = [];
  for (let day = from; day <= to; day = addDays(day, 1)) {
    const entry = byDay.get(day);
    if (entry || day === from) days.push(entry ?? { day, events: [], todos: [] });
  }
  return days;
}

function Upcoming({ today }: { today: string }) {
  const [days, setDays] = useState(INITIAL_DAYS);
  const from = addDays(today, 1);
  const to = addDays(from, days - 1);
  const upcoming = useQuery({
    queryKey: keys.agenda(from, to),
    queryFn: () => api.get<Agenda>(`/agenda?from=${from}&to=${to}`),
    placeholderData: keepPreviousData,
  });

  if (upcoming.isPending) return <p className="text-muted">Lädt…</p>;
  if (upcoming.isError) return <ErrorBanner error={upcoming.error} />;
  const grouped = groupUpcoming(upcoming.data, from, to);
  return (
    <div className="space-y-7">
      {grouped.map(({ day, events, todos }) => {
        const isTomorrow = day === from;
        return (
          <Section
            key={day}
            title={isTomorrow ? "Morgen" : formatDay(day)}
            label={isTomorrow ? "Morgen" : formatLongDay(day)}
            empty={isTomorrow ? "Nichts geplant." : undefined}
          >
            {events.map((occurrence) => (
              <OccurrenceRow key={`${occurrence.event_id}-${occurrence.occurrence_start}`} occurrence={occurrence} />
            ))}
            {todos.map((item) => (
              <ItemRow key={item.id} item={item} />
            ))}
          </Section>
        );
      })}
      <button
        type="button"
        className={secondaryButtonClass}
        disabled={upcoming.isFetching || days >= MAX_DAYS}
        onClick={() => setDays((d) => Math.min(d + MORE_DAYS, MAX_DAYS))}
      >
        Weitere 7 Tage
      </button>
    </div>
  );
}

export function TodayPage() {
  const today = todayBerlin();
  const agenda = useQuery({
    queryKey: keys.agenda(today, today),
    queryFn: () => api.get<Agenda>(`/agenda?date=${today}`),
  });

  // weekday big, date below
  const longDay = formatLongDay(today);
  const comma = longDay.indexOf(", ");
  const weekday = comma > 0 ? longDay.slice(0, comma) : longDay;
  const date = comma > 0 ? longDay.slice(comma + 2) : "";

  return (
    <div className="space-y-7">
      <div className="space-y-5">
        <h1 className="tracking-tight">
          <span className="block text-3xl font-semibold">{weekday}</span>
          <span className="sr-only">, </span>
          <span className="mt-1 block text-[0.9375rem] font-normal text-muted">{date}</span>
        </h1>
        <QuickAddTodo key={today} defaultDue={today} />
      </div>
      {agenda.isPending ? (
        <p className="text-muted">Lädt…</p>
      ) : agenda.isError ? (
        <ErrorBanner error={agenda.error} />
      ) : (
        <>
          <Section title="Termine" empty="Keine Termine.">
            {agenda.data.events.map((occurrence) => (
              <OccurrenceRow key={`${occurrence.event_id}-${occurrence.occurrence_start}`} occurrence={occurrence} />
            ))}
          </Section>
          {agenda.data.overdue_todos.length > 0 && (
            <Section title="Überfällig" tone="danger">
              {agenda.data.overdue_todos.map((item) => (
                <ItemRow key={item.id} item={item} />
              ))}
            </Section>
          )}
          <Section title="Heute fällig" empty="Nichts fällig.">
            {agenda.data.due_todos.map((item) => (
              <ItemRow key={item.id} item={item} />
            ))}
          </Section>
          <Upcoming today={today} />
        </>
      )}
    </div>
  );
}

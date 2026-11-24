import { CalendarDays, Folder } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import { Link, useSearchParams } from "react-router";
import { ErrorBanner } from "../components/ErrorBanner";
import { ItemRow } from "../components/ItemRow";
import { linkClass, PageHeader, Section } from "../components/ui";
import { api } from "../lib/api";
import { keys } from "../lib/queryKeys";
import { formatDateTime, formatDay, isoToZoned, startOfWeek } from "../lib/time";
import { areaName, type SearchResults } from "../lib/types";

const rowClass = "flex items-center gap-3 px-4 py-2.5";
const iconClass = "size-[1.125rem] shrink-0 text-muted";

export function SearchPage() {
  const [params] = useSearchParams();
  const q = (params.get("q") ?? "").trim();
  const results = useQuery({
    queryKey: keys.search(q),
    queryFn: () => api.get<SearchResults>(`/search?q=${encodeURIComponent(q)}`),
    enabled: q.length > 0,
  });

  if (!q) return <p className="text-muted">Gib oben einen Suchbegriff ein.</p>;

  return (
    <div className="space-y-8">
      <PageHeader title={`Suche: „${q}“`} />
      {results.isPending ? (
        <p className="text-muted">Lädt…</p>
      ) : results.isError ? (
        <ErrorBanner error={results.error} />
      ) : results.data.items.length + results.data.projects.length + results.data.events.length === 0 ? (
        <p className="text-muted">Keine Treffer für „{q}“.</p>
      ) : (
        <>
          {results.data.items.length > 0 && (
            <Section title="Einträge">
              {results.data.items.map((item) => (
                <ItemRow key={item.id} item={item} />
              ))}
            </Section>
          )}
          {results.data.projects.length > 0 && (
            <Section title="Projekte">
              {results.data.projects.map((project) => (
                <li key={project.id} className={rowClass}>
                  <Folder aria-hidden="true" className={iconClass} strokeWidth={1.75} />
                  <Link to={`/projekte/${project.id}`} className={`${linkClass} min-w-0 truncate`}>
                    {project.name}
                  </Link>
                  <span className="ml-auto shrink-0 text-xs text-muted">{areaName(project.area)}</span>
                </li>
              ))}
            </Section>
          )}
          {results.data.events.length > 0 && (
            <Section title="Termine">
              {results.data.events.map((event) => {
                const day = isoToZoned(event.start_at).day;
                return (
                  <li key={event.id} className={rowClass}>
                    <CalendarDays aria-hidden="true" className={iconClass} strokeWidth={1.75} />
                    <Link to={`/kalender?woche=${startOfWeek(day)}`} className={`${linkClass} min-w-0 truncate`}>
                      {event.title}
                    </Link>
                    <span className="ml-auto shrink-0 text-xs tabular-nums text-muted">
                      {event.all_day ? formatDay(day) : formatDateTime(event.start_at)}
                    </span>
                  </li>
                );
              })}
            </Section>
          )}
        </>
      )}
    </div>
  );
}

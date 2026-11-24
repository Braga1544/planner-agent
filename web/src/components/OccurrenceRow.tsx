import { MapPin, Repeat } from "lucide-react";
import { formatTime } from "../lib/time";
import type { Occurrence } from "../lib/types";

function occurrenceTimeLabel(occurrence: Occurrence): string {
  if (occurrence.all_day) return "ganztägig";
  const start = formatTime(occurrence.occurrence_start);
  return occurrence.occurrence_end ? `${start}–${formatTime(occurrence.occurrence_end)}` : start;
}

export function OccurrenceRow({
  occurrence,
  onSelect,
}: {
  occurrence: Occurrence;
  onSelect?: (occurrence: Occurrence) => void;
}) {
  return (
    <li>
      <button
        type="button"
        onClick={() => onSelect?.(occurrence)}
        disabled={!onSelect}
        className="group flex w-full flex-col gap-0.5 px-4 py-2.5 text-left sm:flex-row sm:items-start sm:gap-3 transition-colors hover:bg-bg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-accent/40 disabled:cursor-default"
      >
        <span className="shrink-0 text-xs tabular-nums text-muted sm:w-24 sm:pt-px sm:text-sm">{occurrenceTimeLabel(occurrence)}</span>
        <span className="min-w-0 sm:flex-1">
          <span className="flex flex-wrap items-center gap-x-2 gap-y-1">
            <span className="break-words">{occurrence.title}</span>
            {occurrence.is_recurring && (
              <span role="img" aria-label="Wiederholung" title="Wiederholung" className="inline-flex text-muted">
                <Repeat aria-hidden="true" className="size-3.5" strokeWidth={1.75} />
              </span>
            )}
            {occurrence.source === "ics_import" && (
              <span className="rounded-md border border-border px-1.5 text-xs leading-5 text-muted">importiert</span>
            )}
          </span>
          {occurrence.location && (
            <span className="mt-0.5 flex items-center gap-1 text-xs text-muted">
              <MapPin aria-hidden="true" className="size-3.5 shrink-0" strokeWidth={1.75} />
              <span className="truncate">{occurrence.location}</span>
            </span>
          )}
        </span>
      </button>
    </li>
  );
}

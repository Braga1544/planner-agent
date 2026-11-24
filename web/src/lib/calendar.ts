import { addDays, isoToZoned } from "./time";
import type { Occurrence } from "./types";

export function occurrenceDays(occurrence: Occurrence): string[] {
  const start = isoToZoned(occurrence.occurrence_start).day;
  let last = start;
  if (occurrence.occurrence_end) {
    const end = isoToZoned(occurrence.occurrence_end);
    // end at 00:00 doesn't belong to the day
    last = end.time === "00:00" ? addDays(end.day, -1) : end.day;
    if (last < start) last = start;
  }
  const days: string[] = [];
  for (let day = start; day <= last; day = addDays(day, 1)) days.push(day);
  return days;
}

export function groupByDay(occurrences: Occurrence[], weekStart: string): Record<string, Occurrence[]> {
  const weekEnd = addDays(weekStart, 7);
  const grouped: Record<string, Occurrence[]> = {};
  for (const occurrence of occurrences) {
    for (const day of occurrenceDays(occurrence)) {
      if (day < weekStart || day >= weekEnd) continue;
      (grouped[day] ??= []).push(occurrence);
    }
  }
  return grouped;
}

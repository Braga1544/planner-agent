import { addDays, isoToZoned, zonedToIso } from "./time";
import type { AreaSlug, EventOut, EventPayload } from "./types";

export type Repeat = "none" | "DAILY" | "WEEKLY" | "MONTHLY" | "YEARLY" | "custom";

export interface EventFormValues {
  title: string;
  allDay: boolean;
  startDay: string;
  startTime: string;
  endDay: string;
  endTime: string;
  repeat: Repeat;
  customRule: string;
  location: string;
  notes: string;
  area: AreaSlug | "";
  reminder: string;
}

const SIMPLE_RULE = /^FREQ=(DAILY|WEEKLY|MONTHLY|YEARLY)$/;

export function emptyEventForm(day: string): EventFormValues {
  return {
    title: "",
    allDay: false,
    startDay: day,
    startTime: "09:00",
    endDay: day,
    endTime: "10:00",
    repeat: "none",
    customRule: "",
    location: "",
    notes: "",
    area: "",
    reminder: "",
  };
}

export function eventToForm(event: EventOut): EventFormValues {
  const start = isoToZoned(event.start_at);
  const end = event.end_at ? isoToZoned(event.end_at) : null;
  let endDay = end?.day ?? start.day;
  if (event.all_day) {
    endDay = end ? addDays(end.day, -1) : start.day; // end is exclusive
    if (endDay < start.day) endDay = start.day;
  }
  const match = event.rrule ? SIMPLE_RULE.exec(event.rrule) : null;
  return {
    title: event.title,
    allDay: event.all_day,
    startDay: start.day,
    startTime: event.all_day ? "09:00" : start.time,
    endDay,
    endTime: event.all_day ? "10:00" : (end?.time ?? ""),
    repeat: !event.rrule ? "none" : match ? (match[1] as Repeat) : "custom",
    customRule: event.rrule && !match ? event.rrule : "",
    location: event.location ?? "",
    notes: event.notes ?? "",
    area: event.area ?? "",
    reminder: event.reminder_minutes === null ? "" : String(event.reminder_minutes),
  };
}

export function formToPayload(values: EventFormValues): EventPayload {
  const rrule =
    values.repeat === "none"
      ? null
      : values.repeat === "custom"
        ? values.customRule.trim() || null
        : `FREQ=${values.repeat}`;
  const base = {
    title: values.title.trim(),
    all_day: values.allDay,
    rrule,
    location: values.location.trim() || null,
    notes: values.notes.trim() || null,
    area: values.area || null,
    reminder_minutes: values.reminder === "" ? null : Number(values.reminder),
  };
  if (values.allDay) {
    return {
      ...base,
      start_at: zonedToIso(values.startDay),
      end_at: zonedToIso(addDays(values.endDay || values.startDay, 1)),
    };
  }
  return {
    ...base,
    start_at: zonedToIso(values.startDay, values.startTime),
    end_at: values.endTime ? zonedToIso(values.endDay || values.startDay, values.endTime) : null,
  };
}

export function validateEventForm(values: EventFormValues): string | null {
  if (!values.title.trim()) return "Titel fehlt.";
  if (!values.startDay) return "Datum fehlt.";
  if (!values.allDay && !values.startTime) return "Beginn fehlt.";
  if (values.repeat === "custom" && !values.customRule.trim()) return "Regel fehlt.";
  const payload = formToPayload(values);
  if (payload.end_at && new Date(payload.end_at) < new Date(payload.start_at)) return "Ende liegt vor dem Beginn.";
  return null;
}

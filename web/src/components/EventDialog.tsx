import { Clock, MapPin, Tag } from "lucide-react";
import { useMutation, useQuery } from "@tanstack/react-query";
import { useState, type FormEvent } from "react";
import { api } from "../lib/api";
import { emptyEventForm, eventToForm, formToPayload, validateEventForm, type EventFormValues, type Repeat } from "../lib/eventForm";
import { useInvalidateAll } from "../lib/mutations";
import { keys } from "../lib/queryKeys";
import { formatDateTime, formatDay, isoToZoned } from "../lib/time";
import { AREAS, areaName, type AreaSlug, type EventOut, type EventPayload } from "../lib/types";
import { ErrorBanner } from "./ErrorBanner";
import { Modal, ModalFooter } from "./Modal";
import { buttonClass, dangerButtonClass, Field, inputClass } from "./ui";

export type EventDialogState = { mode: "create"; day: string } | { mode: "edit"; eventId: string };

const REPEAT_OPTIONS: Array<[Repeat, string]> = [
  ["none", "keine"],
  ["DAILY", "täglich"],
  ["WEEKLY", "wöchentlich"],
  ["MONTHLY", "monatlich"],
  ["YEARLY", "jährlich"],
  ["custom", "eigene Regel"],
];

const REMINDER_OPTIONS: Array<[string, string]> = [
  ["", "keine"],
  ["5", "5 Minuten vorher"],
  ["15", "15 Minuten vorher"],
  ["30", "30 Minuten vorher"],
  ["60", "1 Stunde vorher"],
  ["1440", "1 Tag vorher"],
];

function ReadOnlyEvent({ event }: { event: EventOut }) {
  return (
    <div className="space-y-3 text-sm">
      <p className="flex items-center gap-2.5">
        <Clock aria-hidden="true" className="size-4 shrink-0 text-muted" strokeWidth={1.75} />
        {event.all_day ? formatDay(isoToZoned(event.start_at).day) : formatDateTime(event.start_at)}
      </p>
      {event.location && (
        <p className="flex items-center gap-2.5">
          <MapPin aria-hidden="true" className="size-4 shrink-0 text-muted" strokeWidth={1.75} />
          {event.location}
        </p>
      )}
      {event.area && (
        <p className="flex items-center gap-2.5">
          <Tag aria-hidden="true" className="size-4 shrink-0 text-muted" strokeWidth={1.75} />
          {areaName(event.area)}
        </p>
      )}
      {event.notes && <p className="whitespace-pre-wrap rounded-lg bg-bg p-3">{event.notes}</p>}
      <p className="border-t border-border pt-3 text-muted">Importiert aus einem externen Kalender – nur lesbar.</p>
    </div>
  );
}

function EventForm({ initial, eventId, onDone }: { initial: EventFormValues; eventId?: string; onDone: () => void }) {
  const [values, setValues] = useState(initial);
  const [formError, setFormError] = useState<string | null>(null);
  const invalidate = useInvalidateAll();
  const save = useMutation({
    mutationFn: (payload: EventPayload) =>
      eventId ? api.patch<EventOut>(`/events/${eventId}`, payload) : api.post<EventOut>("/events", payload),
    onSuccess: async () => {
      await invalidate();
      onDone();
    },
  });
  const remove = useMutation({
    mutationFn: () => api.delete(`/events/${eventId}`),
    onSuccess: async () => {
      await invalidate();
      onDone();
    },
  });

  function set<K extends keyof EventFormValues>(key: K, value: EventFormValues[K]) {
    setValues((current) => ({ ...current, [key]: value }));
  }

  function setStartDay(day: string) {
    // single-day: end moves along
    setValues((current) => ({
      ...current,
      startDay: day,
      endDay: current.endDay === current.startDay || current.endDay < day ? day : current.endDay,
    }));
  }

  function submit(event: FormEvent) {
    event.preventDefault();
    const problem = validateEventForm(values);
    setFormError(problem);
    if (!problem) save.mutate(formToPayload(values));
  }

  return (
    <form onSubmit={submit} className="space-y-4">
      <Field label="Titel">
        <input value={values.title} onChange={(e) => set("title", e.target.value)} className={inputClass} />
      </Field>
      <label className="flex w-fit cursor-pointer items-center gap-2 text-sm">
        <input type="checkbox" className="size-4" checked={values.allDay} onChange={(e) => set("allDay", e.target.checked)} />
        Ganztägig
      </label>
      {values.allDay ? (
        <div className="grid grid-cols-2 gap-3">
          <Field label="Von">
            <input type="date" value={values.startDay} onChange={(e) => setStartDay(e.target.value)} className={inputClass} />
          </Field>
          <Field label="Bis">
            <input type="date" value={values.endDay} onChange={(e) => set("endDay", e.target.value)} className={inputClass} />
          </Field>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-3">
          <Field label="Datum">
            <input type="date" value={values.startDay} onChange={(e) => setStartDay(e.target.value)} className={inputClass} />
          </Field>
          <Field label="Enddatum">
            <input type="date" value={values.endDay} onChange={(e) => set("endDay", e.target.value)} className={inputClass} />
          </Field>
          <Field label="Beginn">
            <input type="time" value={values.startTime} onChange={(e) => set("startTime", e.target.value)} className={inputClass} />
          </Field>
          <Field label="Ende">
            <input type="time" value={values.endTime} onChange={(e) => set("endTime", e.target.value)} className={inputClass} />
          </Field>
        </div>
      )}
      <Field label="Wiederholung">
        <select value={values.repeat} onChange={(e) => set("repeat", e.target.value as Repeat)} className={inputClass}>
          {REPEAT_OPTIONS.map(([value, label]) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </select>
      </Field>
      {values.repeat === "custom" && (
        <Field label="Regel (RRULE)">
          <input value={values.customRule} onChange={(e) => set("customRule", e.target.value)} placeholder="FREQ=WEEKLY;BYDAY=TU,TH" className={inputClass} />
        </Field>
      )}
      <Field label="Ort">
        <input value={values.location} onChange={(e) => set("location", e.target.value)} className={inputClass} />
      </Field>
      <Field label="Notizen">
        <textarea rows={3} value={values.notes} onChange={(e) => set("notes", e.target.value)} className={inputClass} />
      </Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Bereich">
          <select value={values.area} onChange={(e) => set("area", e.target.value as AreaSlug | "")} className={inputClass}>
            <option value="">— keiner —</option>
            {AREAS.map((area) => (
              <option key={area.slug} value={area.slug}>
                {area.name}
              </option>
            ))}
          </select>
        </Field>
        <Field label="Erinnerung">
          <select value={values.reminder} onChange={(e) => set("reminder", e.target.value)} className={inputClass}>
            {REMINDER_OPTIONS.map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </Field>
      </div>
      {eventId && values.repeat !== "none" && (
        <p className="text-sm text-muted">Änderungen gelten für die ganze Serie.</p>
      )}
      {formError && <ErrorBanner error={new Error(formError)} />}
      {save.isError && <ErrorBanner error={save.error} />}
      {remove.isError && <ErrorBanner error={remove.error} />}
      <ModalFooter
        start={
          eventId ? (
            <button
              type="button"
              className={dangerButtonClass}
              disabled={remove.isPending}
              onClick={() => {
                const message =
                  values.repeat !== "none"
                    ? `Serie „${values.title}“ mit allen Wiederholungen löschen?`
                    : `„${values.title}“ löschen?`;
                if (window.confirm(message)) remove.mutate();
              }}
            >
              Löschen
            </button>
          ) : undefined
        }
      >
        <button type="submit" className={buttonClass} disabled={save.isPending}>
          Speichern
        </button>
      </ModalFooter>
    </form>
  );
}

export function EventDialog({ state, onClose }: { state: EventDialogState; onClose: () => void }) {
  const eventId = state.mode === "edit" ? state.eventId : null;
  const event = useQuery({
    queryKey: keys.event(eventId ?? "neu"),
    queryFn: () => api.get<EventOut>(`/events/${eventId}`),
    enabled: eventId !== null,
  });

  if (state.mode === "create") {
    return (
      <Modal title="Neuer Termin" onClose={onClose}>
        <EventForm initial={emptyEventForm(state.day)} onDone={onClose} />
      </Modal>
    );
  }
  if (event.isPending) {
    return (
      <Modal title="Termin" onClose={onClose}>
        <p className="text-muted">Lädt…</p>
      </Modal>
    );
  }
  if (event.isError) {
    return (
      <Modal title="Termin" onClose={onClose}>
        <ErrorBanner error={event.error} />
      </Modal>
    );
  }
  if (event.data.source !== "local") {
    return (
      <Modal title={event.data.title} onClose={onClose}>
        <ReadOnlyEvent event={event.data} />
      </Modal>
    );
  }
  return (
    <Modal title="Termin bearbeiten" onClose={onClose}>
      <EventForm initial={eventToForm(event.data)} eventId={event.data.id} onDone={onClose} />
    </Modal>
  );
}

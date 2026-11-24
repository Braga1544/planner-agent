import { makeEvent } from "../test/factories";
import { emptyEventForm, eventToForm, formToPayload, validateEventForm } from "./eventForm";

test("timed event with correct offset before and after dst switch", () => {
  const summer = { ...emptyEventForm("2026-10-12"), title: "Zahnarzt", startTime: "14:00", endTime: "15:00" };
  expect(formToPayload(summer)).toEqual({
    title: "Zahnarzt",
    start_at: "2026-10-12T14:00:00+02:00",
    end_at: "2026-10-12T15:00:00+02:00",
    all_day: false,
    rrule: null,
    location: null,
    notes: null,
    area: null,
    reminder_minutes: null,
  });
  const winter = { ...summer, startDay: "2026-10-26", endDay: "2026-10-26" };
  expect(formToPayload(winter).start_at).toBe("2026-10-26T14:00:00+01:00");
});

test("all-day: inclusive last day becomes exclusive end", () => {
  const values = { ...emptyEventForm("2026-10-20"), title: "Urlaub", allDay: true, endDay: "2026-10-22" };
  const payload = formToPayload(values);
  expect(payload.start_at).toBe("2026-10-20T00:00:00+02:00");
  expect(payload.end_at).toBe("2026-10-23T00:00:00+02:00");
});

test("recurrence, area and reminder", () => {
  const values = { ...emptyEventForm("2026-10-13"), title: "Training", repeat: "WEEKLY" as const, area: "personal" as const, reminder: "15" };
  expect(formToPayload(values)).toMatchObject({ rrule: "FREQ=WEEKLY", area: "personal", reminder_minutes: 15 });
  expect(formToPayload({ ...values, repeat: "custom", customRule: " FREQ=MONTHLY;BYDAY=1MO " }).rrule).toBe(
    "FREQ=MONTHLY;BYDAY=1MO",
  );
});

test("eventToForm makes all-day end inclusive again and detects rules", () => {
  const event = makeEvent({
    all_day: true,
    start_at: "2026-10-19T22:00:00Z",
    end_at: "2026-10-22T22:00:00Z",
    rrule: "FREQ=YEARLY",
    location: "Ostsee",
  });
  expect(eventToForm(event)).toMatchObject({
    allDay: true,
    startDay: "2026-10-20",
    endDay: "2026-10-22",
    repeat: "YEARLY",
    location: "Ostsee",
  });
  expect(eventToForm(makeEvent({ rrule: "FREQ=WEEKLY;BYDAY=TU,TH" }))).toMatchObject({
    repeat: "custom",
    customRule: "FREQ=WEEKLY;BYDAY=TU,TH",
  });
  expect(eventToForm(makeEvent({ start_at: "2026-10-12T12:00:00Z", end_at: "2026-10-12T13:30:00Z" }))).toMatchObject({
    startTime: "14:00",
    endTime: "15:30",
  });
});

test("validation", () => {
  const base = { ...emptyEventForm("2026-10-12"), title: "X" };
  expect(validateEventForm({ ...base, title: " " })).toBe("Titel fehlt.");
  expect(validateEventForm({ ...base, startTime: "15:00", endTime: "14:00" })).toBe("Ende liegt vor dem Beginn.");
  expect(validateEventForm({ ...base, repeat: "custom", customRule: "" })).toBe("Regel fehlt.");
  expect(validateEventForm(base)).toBeNull();
});

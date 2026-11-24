import { makeOccurrence } from "../test/factories";
import { groupByDay, occurrenceDays } from "./calendar";

test("multi-day event shows on every day", () => {
  const o = makeOccurrence({ occurrence_start: "2026-10-12T09:00:00+02:00", occurrence_end: "2026-10-14T17:00:00+02:00" });
  expect(occurrenceDays(o)).toEqual(["2026-10-12", "2026-10-13", "2026-10-14"]);
});

test("all-day with exclusive end", () => {
  const o = makeOccurrence({
    all_day: true,
    occurrence_start: "2026-10-20T00:00:00+02:00",
    occurrence_end: "2026-10-23T00:00:00+02:00",
  });
  expect(occurrenceDays(o)).toEqual(["2026-10-20", "2026-10-21", "2026-10-22"]);
});

test("event past midnight and without end", () => {
  expect(
    occurrenceDays(makeOccurrence({ occurrence_start: "2026-10-12T21:30:00Z", occurrence_end: "2026-10-12T22:30:00Z" })),
  ).toEqual(["2026-10-12", "2026-10-13"]);
  expect(occurrenceDays(makeOccurrence({ occurrence_start: "2026-10-11T22:30:00Z", occurrence_end: null }))).toEqual([
    "2026-10-12",
  ]);
});

test("groupByDay clips to the week", () => {
  const spanning = makeOccurrence({ title: "Messe", occurrence_start: "2026-10-10T09:00:00+02:00", occurrence_end: "2026-10-13T12:00:00+02:00" });
  const grouped = groupByDay([spanning], "2026-10-12");
  expect(Object.keys(grouped)).toEqual(["2026-10-12", "2026-10-13"]);
});

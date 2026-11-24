import {
  addDays,
  formatDateTime,
  formatDay,
  formatLongDay,
  formatTime,
  isoToZoned,
  startOfWeek,
  todayBerlin,
  zonedToIso,
} from "./time";

test("zonedToIso uses the offset of that day", () => {
  expect(zonedToIso("2026-10-12", "14:00")).toBe("2026-10-12T14:00:00+02:00");
  expect(zonedToIso("2026-10-26", "14:00")).toBe("2026-10-26T14:00:00+01:00");
  expect(zonedToIso("2026-10-25", "12:00")).toBe("2026-10-25T12:00:00+01:00");
  expect(zonedToIso("2026-03-29", "12:00")).toBe("2026-03-29T12:00:00+02:00");
  expect(zonedToIso("2026-12-31")).toBe("2026-12-31T00:00:00+01:00");
});

test("isoToZoned uses berlin local time, also near midnight", () => {
  expect(isoToZoned("2026-10-12T12:00:00Z")).toEqual({ day: "2026-10-12", time: "14:00" });
  expect(isoToZoned("2026-10-11T22:30:00Z")).toEqual({ day: "2026-10-12", time: "00:30" });
  expect(isoToZoned("2026-12-31T23:30:00Z")).toEqual({ day: "2027-01-01", time: "00:30" });
  expect(isoToZoned("2026-10-12T14:00:00+02:00")).toEqual({ day: "2026-10-12", time: "14:00" });
});

test("todayBerlin uses the berlin calendar day", () => {
  expect(todayBerlin(new Date("2026-10-11T22:30:00Z"))).toBe("2026-10-12");
});

test("addDays and startOfWeek", () => {
  expect(addDays("2026-10-30", 3)).toBe("2026-11-02");
  expect(addDays("2027-01-01", -1)).toBe("2026-12-31");
  expect(startOfWeek("2026-10-11")).toBe("2026-10-05"); // sun -> previous mon
  expect(startOfWeek("2026-10-12")).toBe("2026-10-12"); // mon stays
  expect(startOfWeek("2026-10-14")).toBe("2026-10-12");
});

test("formatting", () => {
  expect(formatTime("2026-10-12T12:00:00Z")).toBe("14:00");
  expect(formatDay("2026-10-12")).toContain("12.10.");
  expect(formatLongDay("2026-10-12")).toBe("Montag, 12. Oktober 2026");
  expect(formatDateTime("2026-10-12T12:00:00Z")).toContain("14:00");
});

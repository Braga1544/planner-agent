const TZ = "Europe/Berlin";

const partsFormatter = new Intl.DateTimeFormat("en-CA", {
  timeZone: TZ,
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
  hourCycle: "h23",
});

function pad(value: number): string {
  return String(value).padStart(2, "0");
}

function zonedParts(date: Date) {
  const parts: Record<string, string> = {};
  for (const part of partsFormatter.formatToParts(date)) parts[part.type] = part.value;
  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour: Number(parts.hour),
    minute: Number(parts.minute),
    second: Number(parts.second),
  };
}

// berlin offset in min (summer 120, winter 60)
function offsetMinutes(instant: number): number {
  const wholeSeconds = Math.floor(instant / 1000) * 1000;
  const p = zonedParts(new Date(wholeSeconds));
  const asUtc = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second);
  return Math.round((asUtc - wholeSeconds) / 60000);
}

export function zonedToIso(day: string, time = "00:00"): string {
  const [year, month, date] = day.split("-").map(Number);
  const [hour, minute] = time.split(":").map(Number);
  const wallAsUtc = Date.UTC(year, month - 1, date, hour, minute);
  let offset = offsetMinutes(wallAsUtc);
  offset = offsetMinutes(wallAsUtc - offset * 60000);
  const sign = offset >= 0 ? "+" : "-";
  const abs = Math.abs(offset);
  return `${day}T${pad(hour)}:${pad(minute)}:00${sign}${pad(Math.floor(abs / 60))}:${pad(abs % 60)}`;
}

export function isoToZoned(iso: string): { day: string; time: string } {
  const p = zonedParts(new Date(iso));
  return { day: `${p.year}-${pad(p.month)}-${pad(p.day)}`, time: `${pad(p.hour)}:${pad(p.minute)}` };
}

export function todayBerlin(now: Date = new Date()): string {
  return isoToZoned(now.toISOString()).day;
}

function dayToUtcDate(day: string): Date {
  const [year, month, date] = day.split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, date));
}

export function addDays(day: string, n: number): string {
  const date = dayToUtcDate(day);
  date.setUTCDate(date.getUTCDate() + n);
  return `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())}`;
}

export function startOfWeek(day: string): string {
  const weekday = dayToUtcDate(day).getUTCDay(); // 0 = sun
  return addDays(day, -((weekday + 6) % 7));
}

const timeFormatter = new Intl.DateTimeFormat("de-DE", { timeZone: TZ, hour: "2-digit", minute: "2-digit" });
// days are utc midnight, hence timeZone utc
const dayFormatter = new Intl.DateTimeFormat("de-DE", { timeZone: "UTC", weekday: "short", day: "2-digit", month: "2-digit" });
const longDayFormatter = new Intl.DateTimeFormat("de-DE", {
  timeZone: "UTC",
  weekday: "long",
  day: "numeric",
  month: "long",
  year: "numeric",
});

export function formatTime(iso: string): string {
  return timeFormatter.format(new Date(iso));
}

export function formatDay(day: string): string {
  return dayFormatter.format(dayToUtcDate(day));
}

export function formatLongDay(day: string): string {
  return longDayFormatter.format(dayToUtcDate(day));
}

export function formatDateTime(iso: string): string {
  const zoned = isoToZoned(iso);
  return `${formatDay(zoned.day)} ${zoned.time}`;
}

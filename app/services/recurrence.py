import re
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from dateutil.rrule import rrulestr

from app.errors import Invalid

_UNTIL = re.compile(r"UNTIL=(\d{8})(?:T(\d{6})(Z?))?", re.IGNORECASE)
_HIGH_FREQUENCY = re.compile(r"FREQ=(?:SECONDLY|MINUTELY|HOURLY)", re.IGNORECASE)


def normalize_rrule(rule: str, tz: ZoneInfo) -> str:
    # strip RRULE:, UNTIL always utc (dateutil wants that with tz dtstart), date only = end of day
    rule = rule.strip()
    if rule.upper().startswith("RRULE:"):
        rule = rule[len("RRULE:"):]

    def _replace(match: re.Match[str]) -> str:
        day, clock, utc_flag = match.group(1), match.group(2), match.group(3)
        if clock and utc_flag:
            return match.group(0).upper()
        if clock:
            local = datetime.strptime(day + clock, "%Y%m%d%H%M%S").replace(tzinfo=tz)
        else:
            local = datetime.strptime(day, "%Y%m%d").replace(hour=23, minute=59, second=59, tzinfo=tz)
        return "UNTIL=" + local.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

    return _UNTIL.sub(_replace, rule)


def _parse(rule: str, dtstart: datetime, tz: ZoneInfo):
    normalized = normalize_rrule(rule, tz)
    if _HIGH_FREQUENCY.search(normalized):
        raise ValueError(_TOO_FREQUENT)
    try:
        return normalized, rrulestr(normalized, dtstart=dtstart)
    except TypeError as exc:
        raise ValueError(str(exc)) from exc


_TOO_FREQUENT = "Wiederholungen häufiger als täglich werden nicht unterstützt"


def validate_rrule(rule: str, tz: ZoneInfo) -> str:
    try:
        normalized, _ = _parse(rule, datetime(2000, 1, 1, tzinfo=tz), tz)
    except ValueError as exc:
        if str(exc) == _TOO_FREQUENT:
            raise Invalid(_TOO_FREQUENT) from exc
        raise Invalid(f"Ungültige Wiederholungsregel: {rule}") from exc
    return normalized


def _overlaps(start: datetime, end: datetime | None, range_start: datetime, range_end: datetime) -> bool:
    if start >= range_end:
        return False
    if end is None:
        return start >= range_start
    return end > range_start


def expand(
    start: datetime,
    end: datetime | None,
    rule: str | None,
    range_start: datetime,
    range_end: datetime,
    tz: ZoneInfo,
) -> list[tuple[datetime, datetime | None]]:
    # expand in local time, 18:00 stays 18:00 across dst
    if not rule:
        return [(start, end)] if _overlaps(start, end, range_start, range_end) else []

    local_start = start.astimezone(tz)
    wall_duration = None
    if end is not None:
        wall_duration = end.astimezone(tz).replace(tzinfo=None) - local_start.replace(tzinfo=None)
    try:
        _, rule_set = _parse(rule, local_start, tz)
    except ValueError as exc:
        raise ValueError(f"Wiederholungsregel nicht auswertbar: {rule}") from exc

    lookback = (wall_duration or timedelta(0)) + timedelta(days=1)
    occurrences: list[tuple[datetime, datetime | None]] = []
    for occ_start in rule_set.between(range_start - lookback, range_end, inc=True):
        occ_end = None
        if wall_duration is not None:
            occ_end = (occ_start.replace(tzinfo=None) + wall_duration).replace(tzinfo=tz)
        if _overlaps(occ_start, occ_end, range_start, range_end):
            occurrences.append((occ_start, occ_end))
    return occurrences

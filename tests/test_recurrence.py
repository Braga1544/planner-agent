from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

import pytest

from app.errors import Invalid
from app.services.recurrence import expand, normalize_rrule, validate_rrule

TZ = ZoneInfo("Europe/Berlin")


def test_weekly_rule_keeps_local_time_across_dst_change():
    start = datetime(2026, 10, 20, 18, 0, tzinfo=TZ)
    end = start + timedelta(hours=2)
    occ = expand(start, end, "FREQ=WEEKLY", datetime(2026, 10, 19, tzinfo=TZ), datetime(2026, 11, 4, tzinfo=TZ), TZ)
    assert [s.astimezone(TZ).strftime("%m-%d %H:%M") for s, _ in occ] == ["10-20 18:00", "10-27 18:00", "11-03 18:00"]
    assert all(e.astimezone(TZ).hour == 20 for _, e in occ)
    assert occ[0][0].utcoffset() != occ[1][0].utcoffset()  # summer vs winter time


def test_non_recurring_event_overlapping_range_start():
    start = datetime(2026, 10, 8, 9, tzinfo=TZ)
    end = datetime(2026, 10, 10, 17, tzinfo=TZ)
    assert expand(start, end, None, datetime(2026, 10, 9, tzinfo=TZ), datetime(2026, 10, 10, tzinfo=TZ), TZ) == [
        (start, end)
    ]


def test_event_without_end_before_range_is_excluded():
    start = datetime(2026, 10, 8, 9, tzinfo=TZ)
    assert expand(start, None, None, datetime(2026, 10, 9, tzinfo=TZ), datetime(2026, 10, 10, tzinfo=TZ), TZ) == []


def test_rule_with_count():
    occ = expand(
        datetime(2026, 10, 1, 8, tzinfo=TZ), None, "FREQ=DAILY;COUNT=3",
        datetime(2026, 10, 1, tzinfo=TZ), datetime(2026, 10, 31, tzinfo=TZ), TZ,
    )
    assert len(occ) == 3


def test_rule_with_date_only_until_expands():
    occ = expand(
        datetime(2026, 10, 1, 8, tzinfo=TZ), None, "FREQ=DAILY;UNTIL=20261003",
        datetime(2026, 10, 1, tzinfo=TZ), datetime(2026, 10, 31, tzinfo=TZ), TZ,
    )
    assert [s.day for s, _ in occ] == [1, 2, 3]


def test_normalize_date_only_until():
    assert normalize_rrule("FREQ=WEEKLY;UNTIL=20261231", TZ) == "FREQ=WEEKLY;UNTIL=20261231T225959Z"


def test_normalize_floating_until_and_prefix():
    assert normalize_rrule("RRULE:FREQ=DAILY;UNTIL=20260701T120000", TZ) == "FREQ=DAILY;UNTIL=20260701T100000Z"


def test_normalize_keeps_utc_until():
    assert normalize_rrule("FREQ=DAILY;UNTIL=20260701T120000Z", TZ) == "FREQ=DAILY;UNTIL=20260701T120000Z"


def test_validate_rejects_garbage():
    with pytest.raises(Invalid):
        validate_rrule("FREQ=SOMETIMES", TZ)


def test_validate_rejects_impossible_until_date():
    with pytest.raises(Invalid):
        validate_rrule("FREQ=DAILY;UNTIL=20260230", TZ)


def test_validate_rejects_high_frequency():
    with pytest.raises(Invalid, match="häufiger als täglich"):
        validate_rrule("FREQ=MINUTELY", TZ)


def test_expand_raises_for_high_frequency():
    with pytest.raises(ValueError):
        expand(
            datetime(2026, 10, 1, 8, tzinfo=TZ), None, "FREQ=HOURLY",
            datetime(2026, 10, 1, tzinfo=TZ), datetime(2026, 10, 31, tzinfo=TZ), TZ,
        )

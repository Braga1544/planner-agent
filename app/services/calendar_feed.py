from collections.abc import Iterable
from datetime import timedelta
from zoneinfo import ZoneInfo

from icalendar import Alarm, Calendar, vRecur
from icalendar import Event as ICalEvent

from app.models import Event


def build_feed(events: Iterable[Event], tz: ZoneInfo) -> bytes:
    cal = Calendar()
    cal.add("prodid", "-//planner-agent//DE")
    cal.add("version", "2.0")
    cal.add("x-wr-calname", "Planungs-Agent")
    cal.add("x-wr-timezone", tz.key)

    for event in events:
        ical = ICalEvent()
        ical.add("uid", str(event.id))
        ical.add("summary", event.title)
        ical.add("dtstamp", event.updated_at)
        if event.all_day:
            start_day = event.start_at.astimezone(tz).date()
            end_day = event.end_at.astimezone(tz).date() if event.end_at else start_day + timedelta(days=1)
            ical.add("dtstart", start_day)
            ical.add("dtend", end_day)
        else:
            ical.add("dtstart", event.start_at.astimezone(tz))
            if event.end_at:
                ical.add("dtend", event.end_at.astimezone(tz))
        if event.rrule:
            ical.add("rrule", vRecur.from_ical(event.rrule))
        if event.location:
            ical.add("location", event.location)
        if event.notes:
            ical.add("description", event.notes)
        if event.reminder_minutes is not None:
            alarm = Alarm()
            alarm.add("action", "DISPLAY")
            alarm.add("description", event.title)
            alarm.add("trigger", timedelta(minutes=-event.reminder_minutes))
            ical.add_component(alarm)
        cal.add_component(ical)

    # ship vtimezone, some clients get dst wrong otherwise
    cal.add_missing_timezones()
    return cal.to_ical()

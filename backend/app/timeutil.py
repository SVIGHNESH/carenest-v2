"""All time zone handling lives here.

Slot columns are naive datetimes meaning IST wall-clock time.
Audit columns are timezone-aware UTC.
"""

from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

IST = ZoneInfo("Asia/Kolkata")


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def now_ist() -> datetime:
    """Current IST wall-clock time as a naive datetime (slot-comparable)."""
    return datetime.now(IST).replace(tzinfo=None, microsecond=0)


def to_ist_naive(dt: datetime) -> datetime:
    """Convert an aware datetime to naive IST; naive input is assumed to be IST already."""
    if dt.tzinfo is None:
        return dt
    return dt.astimezone(IST).replace(tzinfo=None)


def day_start(d: date) -> datetime:
    return datetime.combine(d, time.min)


def slot_for(d: date, start_hour: int, hours: int) -> tuple[datetime, datetime]:
    start = day_start(d) + timedelta(hours=start_hour)
    return start, start + timedelta(hours=hours)


def fmt_slot_when(start: datetime) -> str:
    """e.g. 'Sat 10 Oct, 3:00 PM' (plain ASCII, DLT friendly)."""
    hour12 = start.hour % 12 or 12
    ampm = "AM" if start.hour < 12 else "PM"
    return f"{start.strftime('%a')} {start.day} {start.strftime('%b')}, {hour12}:{start.minute:02d} {ampm}"

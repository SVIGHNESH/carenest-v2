"""Who can work when.

A nurse can cover a slot when they are active, qualified for the service, on
duty for the whole slot that day (weekly hours, day override, leave) and not
busy: no other live assignment within the travel gap before or after.

A "live" assignment is an active one whose booking is confirmed / in_progress,
or pending_payment with an unexpired hold.
"""

from dataclasses import dataclass
from datetime import date, datetime, timedelta

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    AppSettings,
    Booking,
    BookingAssignment,
    Nurse,
    NurseDayOverride,
    NurseService,
    NurseWeeklyHours,
)
from app.timeutil import day_start, utcnow

MAX_HOURS = 12


def live_assignment_filter(now=None):
    now = now or utcnow()
    return and_(
        BookingAssignment.active.is_(True),
        or_(
            Booking.status.in_(["confirmed", "in_progress"]),
            and_(Booking.status == "pending_payment", Booking.hold_expires_at > now),
        ),
    )


@dataclass
class NurseDay:
    nurse: Nurse
    window: tuple[int, int] | None  # [start_hour, end_hour) or None when off


async def qualified_nurses(db: AsyncSession, service_id: int, gender: str | None = None) -> list[Nurse]:
    q = (
        select(Nurse)
        .join(NurseService, NurseService.nurse_id == Nurse.id)
        .where(NurseService.service_id == service_id, Nurse.is_active.is_(True))
        .order_by(Nurse.id)
    )
    if gender:
        q = q.where(Nurse.gender == gender)
    return list((await db.execute(q)).scalars().all())


async def windows_for_day(db: AsyncSession, nurse_ids: list[int], day: date) -> dict[int, tuple[int, int] | None]:
    """On-duty window per nurse for `day`. Missing hours = not bookable (None)."""
    if not nurse_ids:
        return {}
    out: dict[int, tuple[int, int] | None] = {n: None for n in nurse_ids}
    weekly = (
        await db.execute(
            select(NurseWeeklyHours).where(NurseWeeklyHours.nurse_id.in_(nurse_ids), NurseWeeklyHours.weekday == day.weekday())
        )
    ).scalars()
    for w in weekly:
        if w.end_hour > w.start_hour:
            out[w.nurse_id] = (w.start_hour, w.end_hour)
    overrides = (
        await db.execute(select(NurseDayOverride).where(NurseDayOverride.nurse_id.in_(nurse_ids), NurseDayOverride.day == day))
    ).scalars()
    for o in overrides:
        if o.is_leave or o.start_hour is None or o.end_hour is None or o.end_hour <= o.start_hour:
            out[o.nurse_id] = None
        else:
            out[o.nurse_id] = (o.start_hour, o.end_hour)
    return out


async def busy_ranges(
    db: AsyncSession, nurse_ids: list[int], day: date, *, exclude_booking_id: int | None = None
) -> dict[int, list[tuple[datetime, datetime]]]:
    """Live assignment ranges that touch `day` (padded by a day each side for safety)."""
    if not nurse_ids:
        return {}
    lo = day_start(day) - timedelta(days=1)
    hi = day_start(day) + timedelta(days=2)
    q = (
        select(BookingAssignment.nurse_id, BookingAssignment.slot_start, BookingAssignment.slot_end)
        .join(Booking, Booking.id == BookingAssignment.booking_id)
        .where(
            BookingAssignment.nurse_id.in_(nurse_ids),
            BookingAssignment.slot_start < hi,
            BookingAssignment.slot_end > lo,
            live_assignment_filter(),
        )
    )
    if exclude_booking_id is not None:
        q = q.where(BookingAssignment.booking_id != exclude_booking_id)
    out: dict[int, list[tuple[datetime, datetime]]] = {n: [] for n in nurse_ids}
    for nid, s, e in (await db.execute(q)).all():
        out[nid].append((s, e))
    return out


def is_free(
    window: tuple[int, int] | None,
    busy: list[tuple[datetime, datetime]],
    day: date,
    start_hour: int,
    hours: int,
    gap_hours: int,
) -> bool:
    if window is None or hours < 1:
        return False
    if start_hour < window[0] or start_hour + hours > window[1]:
        return False
    s = day_start(day) + timedelta(hours=start_hour)
    e = s + timedelta(hours=hours)
    gap = timedelta(hours=gap_hours)
    return all(not (bs < e + gap and be + gap > s) for bs, be in busy)


def max_free_hours(
    window: tuple[int, int] | None, busy: list[tuple[datetime, datetime]], day: date, start_hour: int, gap_hours: int
) -> int:
    best = 0
    for h in range(1, MAX_HOURS + 1):
        if is_free(window, busy, day, start_hour, h, gap_hours):
            best = h
        else:
            break
    return best


async def free_nurses(
    db: AsyncSession,
    *,
    service_id: int,
    start: datetime,
    hours: int,
    settings: AppSettings,
    gender: str | None = None,
    exclude_booking_id: int | None = None,
) -> list[Nurse]:
    """Qualified nurses free for the exact slot (single day)."""
    day = start.date()
    nurses = await qualified_nurses(db, service_id, gender)
    ids = [n.id for n in nurses]
    wins = await windows_for_day(db, ids, day)
    busy = await busy_ranges(db, ids, day, exclude_booking_id=exclude_booking_id)
    return [n for n in nurses if is_free(wins.get(n.id), busy.get(n.id, []), day, start.hour, hours, settings.travel_gap_hours)]


async def day_grid(db: AsyncSession, service_id: int, day: date, settings: AppSettings) -> list[dict]:
    """For each start hour on `day`: is any qualified nurse on duty, and is one free for >= 1 hour."""
    nurses = await qualified_nurses(db, service_id)
    ids = [n.id for n in nurses]
    wins = await windows_for_day(db, ids, day)
    busy = await busy_ranges(db, ids, day)
    rows = []
    for hour in range(24):
        on_duty = any(w and w[0] <= hour < w[1] for w in wins.values())
        if not on_duty:
            continue
        free = any(is_free(wins.get(n.id), busy.get(n.id, []), day, hour, 1, settings.travel_gap_hours) for n in nurses)
        rows.append({"hour": hour, "free": free})
    return rows


async def max_duration(db: AsyncSession, service_id: int, start: datetime, settings: AppSettings) -> int:
    day = start.date()
    nurses = await qualified_nurses(db, service_id)
    ids = [n.id for n in nurses]
    wins = await windows_for_day(db, ids, day)
    busy = await busy_ranges(db, ids, day)
    return max(
        (max_free_hours(wins.get(n.id), busy.get(n.id, []), day, start.hour, settings.travel_gap_hours) for n in nurses),
        default=0,
    )


async def gender_availability(
    db: AsyncSession, service_id: int, start: datetime, hours: int, settings: AppSettings
) -> dict[str, bool]:
    free = await free_nurses(db, service_id=service_id, start=start, hours=hours, settings=settings)
    genders = {n.gender for n in free}
    return {"male": "male" in genders, "female": "female" in genders}


async def service_is_available(db: AsyncSession, service_id: int) -> bool:
    """At least one active, qualified nurse who has working hours."""
    q = (
        select(Nurse.id)
        .join(NurseService, NurseService.nurse_id == Nurse.id)
        .join(NurseWeeklyHours, NurseWeeklyHours.nurse_id == Nurse.id)
        .where(NurseService.service_id == service_id, Nurse.is_active.is_(True))
        .limit(1)
    )
    return (await db.execute(q)).first() is not None

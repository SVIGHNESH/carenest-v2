"""Public read endpoints for the app: settings, services, time grid, duration, genders, quote."""

from datetime import date, datetime, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_db
from app.deps import current_user
from app.models import Service, User
from app.schemas.booking import (
    BookingSettingsOut,
    GenderAvailabilityOut,
    MaxDurationOut,
    QuoteIn,
    QuoteOut,
    ServiceOut,
    TimeGridOut,
    TimeSlotOut,
)
from app.services import availability as av
from app.services import booking as bk
from app.services.errors import BookingError
from app.services.settings_service import get_app_settings
from app.timeutil import now_ist

router = APIRouter(tags=["catalog"])


@router.get("/settings/booking", response_model=BookingSettingsOut)
async def booking_settings(db: AsyncSession = Depends(get_db)):
    cfg = await get_app_settings(db)
    await db.commit()
    return cfg


@router.get("/services", response_model=list[ServiceOut])
async def list_services(db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(select(Service).where(Service.active.is_(True)).order_by(Service.id))).scalars().all()
    out = []
    for s in rows:
        out.append(
            ServiceOut(
                id=s.id,
                name=s.name,
                description=s.description,
                base_price=s.base_price,
                available=await av.service_is_available(db, s.id),
            )
        )
    return out


@router.get("/services/{service_id}", response_model=ServiceOut)
async def get_service(service_id: int, db: AsyncSession = Depends(get_db)):
    s = await bk._service_or_error(db, service_id)
    return ServiceOut(
        id=s.id,
        name=s.name,
        description=s.description,
        base_price=s.base_price,
        available=await av.service_is_available(db, s.id),
    )


@router.get("/bookings/time-grid", response_model=TimeGridOut)
async def time_grid(
    service_id: int, day: date = Query(alias="date"), db: AsyncSession = Depends(get_db), _: User = Depends(current_user)
):
    cfg = await get_app_settings(db)
    await bk._service_or_error(db, service_id)
    now = now_ist()
    if day < now.date() or day > now.date() + timedelta(days=cfg.booking_window_days):
        return TimeGridOut(date=day.isoformat(), slots=[])
    rows = await av.day_grid(db, service_id, day, cfg)
    earliest = now + timedelta(minutes=cfg.min_notice_minutes)
    slots = [
        TimeSlotOut(
            hour=r["hour"],
            free=r["free"],
            too_soon=datetime.combine(day, datetime.min.time()) + timedelta(hours=r["hour"]) < earliest,
        )
        for r in rows
    ]
    return TimeGridOut(date=day.isoformat(), slots=slots)


def _start(day_and_hour: datetime) -> datetime:
    return day_and_hour


@router.get("/bookings/max-duration", response_model=MaxDurationOut)
async def max_duration(service_id: int, start: datetime, db: AsyncSession = Depends(get_db), _: User = Depends(current_user)):
    cfg = await get_app_settings(db)
    await bk._service_or_error(db, service_id)
    try:
        bk.validate_slot(start, 1, cfg)
    except BookingError:
        return MaxDurationOut(max_hours=0)
    return MaxDurationOut(max_hours=await av.max_duration(db, service_id, start, cfg))


@router.get("/bookings/gender-availability", response_model=GenderAvailabilityOut)
async def gender_availability(
    service_id: int,
    start: datetime,
    hours: int = Query(ge=1, le=12),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(current_user),
):
    cfg = await get_app_settings(db)
    await bk._service_or_error(db, service_id)
    try:
        bk.validate_slot(start, hours, cfg)
    except BookingError:
        return GenderAvailabilityOut(male=False, female=False)
    return GenderAvailabilityOut(**await av.gender_availability(db, service_id, start, hours, cfg))


@router.post("/bookings/quote", response_model=QuoteOut)
async def quote(body: QuoteIn, db: AsyncSession = Depends(get_db), _: User = Depends(current_user)):
    s = await bk._service_or_error(db, body.service_id)
    return QuoteOut(service_id=s.id, hours=body.hours, base_price=s.base_price, amount=bk.price(s, body.hours))

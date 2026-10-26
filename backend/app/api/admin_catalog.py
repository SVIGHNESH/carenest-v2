"""Admin: settings, services, nurses, availability."""

from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, EmailStr, Field, model_validator
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_db
from app.deps import current_admin
from app.models import (
    AppSettings,
    Booking,
    Nurse,
    NurseDayOverride,
    NurseService,
    NurseWeeklyHours,
    Service,
    User,
)
from app.phone import phone_or_400
from app.schemas.common import Gender
from app.services import booking as bk
from app.services.activity import actor_admin, log
from app.services.errors import BookingError
from app.services.settings_service import get_app_settings

router = APIRouter(prefix="/admin", tags=["admin"])


# --- settings ----------------------------------------------------------------
class SettingsOut(BaseModel):
    min_notice_minutes: int
    booking_window_days: int
    bookings_paused: bool
    travel_gap_hours: int
    support_phone: str

    model_config = {"from_attributes": True}


class SettingsPatch(BaseModel):
    min_notice_minutes: int | None = Field(default=None, ge=0, le=60 * 24 * 7)
    booking_window_days: int | None = Field(default=None, ge=1, le=60)
    bookings_paused: bool | None = None
    travel_gap_hours: int | None = Field(default=None, ge=0, le=6)
    support_phone: str | None = Field(default=None, max_length=30)


@router.get("/settings", response_model=SettingsOut)
async def get_settings_(_: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    cfg = await get_app_settings(db)
    await db.commit()
    return cfg


@router.patch("/settings", response_model=SettingsOut)
async def patch_settings(body: SettingsPatch, admin: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    cfg: AppSettings = await get_app_settings(db)
    changes = body.model_dump(exclude_unset=True)
    for k, v in changes.items():
        if v is not None:
            setattr(cfg, k, v)
    await log(db, actor_admin(admin), "settings_changed", **{k: v for k, v in changes.items() if v is not None})
    await db.commit()
    return cfg


# --- services ------------------------------------------------------------------
class AdminServiceOut(BaseModel):
    id: int
    name: str
    description: str
    base_price: int
    active: bool
    nurse_count: int = 0

    model_config = {"from_attributes": True}


class ServiceIn(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    description: str = ""
    base_price: int = Field(ge=1, le=100000)
    active: bool = True


class ServicePatch(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    description: str | None = None
    base_price: int | None = Field(default=None, ge=1, le=100000)
    active: bool | None = None


@router.get("/services", response_model=list[AdminServiceOut])
async def list_services(_: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    counts = dict((await db.execute(select(NurseService.service_id, func.count()).group_by(NurseService.service_id))).all())
    rows = (await db.execute(select(Service).order_by(Service.id))).scalars().all()
    return [
        AdminServiceOut(
            id=s.id,
            name=s.name,
            description=s.description,
            base_price=s.base_price,
            active=s.active,
            nurse_count=counts.get(s.id, 0),
        )
        for s in rows
    ]


@router.post("/services", response_model=AdminServiceOut, status_code=201)
async def create_service(body: ServiceIn, admin: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    s = Service(**body.model_dump())
    db.add(s)
    await db.flush()
    await log(db, actor_admin(admin), "service_created", name=s.name)
    await db.commit()
    return s


@router.patch("/services/{service_id}", response_model=AdminServiceOut)
async def patch_service(
    service_id: int, body: ServicePatch, admin: User = Depends(current_admin), db: AsyncSession = Depends(get_db)
):
    s = (await db.execute(select(Service).where(Service.id == service_id))).scalar_one_or_none()
    if s is None:
        raise HTTPException(status_code=404, detail="Service not found")
    for k, v in body.model_dump(exclude_unset=True).items():
        if v is not None:
            setattr(s, k, v)  # existing bookings keep the amount saved on them
    await log(db, actor_admin(admin), "service_updated", name=s.name)
    await db.commit()
    return s


# --- nurses ------------------------------------------------------------------------
class HoursRow(BaseModel):
    weekday: int = Field(ge=0, le=6)
    start_hour: int = Field(ge=0, le=23)
    end_hour: int = Field(ge=1, le=24)

    @model_validator(mode="after")
    def _order(self):
        if self.end_hour <= self.start_hour:
            raise ValueError("End must be after start")
        return self


class OverrideIn(BaseModel):
    is_leave: bool = False
    start_hour: int | None = Field(default=None, ge=0, le=23)
    end_hour: int | None = Field(default=None, ge=1, le=24)
    note: str | None = Field(default=None, max_length=200)

    @model_validator(mode="after")
    def _check(self):
        if not self.is_leave:
            if self.start_hour is None or self.end_hour is None or self.end_hour <= self.start_hour:
                raise ValueError("Give start and end hours, or mark the day as leave")
        return self


class OverrideOut(BaseModel):
    day: date
    is_leave: bool
    start_hour: int | None
    end_hour: int | None
    note: str | None

    model_config = {"from_attributes": True}


class NurseIn(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    phone: str
    email: EmailStr | None = None
    gender: Gender
    experience_years: int = Field(default=0, ge=0, le=60)
    notes: str | None = None
    service_ids: list[int] = Field(min_length=1)
    is_active: bool = True


class NursePatch(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    phone: str | None = None
    email: EmailStr | None = None
    gender: Gender | None = None
    experience_years: int | None = Field(default=None, ge=0, le=60)
    notes: str | None = None
    service_ids: list[int] | None = Field(default=None, min_length=1)
    is_active: bool | None = None


class NurseOut(BaseModel):
    id: int
    name: str
    phone: str
    email: str | None
    gender: str
    experience_years: int
    notes: str | None
    is_active: bool
    service_ids: list[int]
    weekly_hours: list[HoursRow]
    setup_issues: list[str]  # e.g. "No working hours": the nurse is not bookable


async def _nurse_out(db: AsyncSession, n: Nurse) -> NurseOut:
    sids = (
        (await db.execute(select(NurseService.service_id).where(NurseService.nurse_id == n.id).order_by(NurseService.service_id)))
        .scalars()
        .all()
    )
    hours = (
        (await db.execute(select(NurseWeeklyHours).where(NurseWeeklyHours.nurse_id == n.id).order_by(NurseWeeklyHours.weekday)))
        .scalars()
        .all()
    )
    issues = []
    if not hours:
        issues.append("No working hours: not bookable")
    if not sids:
        issues.append("No services ticked: not bookable")
    return NurseOut(
        id=n.id,
        name=n.name,
        phone=n.phone,
        email=n.email,
        gender=n.gender,
        experience_years=n.experience_years,
        notes=n.notes,
        is_active=n.is_active,
        service_ids=list(sids),
        weekly_hours=[HoursRow(weekday=h.weekday, start_hour=h.start_hour, end_hour=h.end_hour) for h in hours],
        setup_issues=issues,
    )


async def _check_services(db: AsyncSession, ids: list[int]) -> list[int]:
    ids = sorted(set(ids))
    found = (await db.execute(select(Service.id).where(Service.id.in_(ids)))).scalars().all()
    if len(found) != len(ids):
        raise HTTPException(status_code=400, detail="One of the selected services does not exist.")
    return ids


async def _set_services(db: AsyncSession, nurse_id: int, ids: list[int]) -> None:
    await db.execute(delete(NurseService).where(NurseService.nurse_id == nurse_id))
    for sid in ids:
        db.add(NurseService(nurse_id=nurse_id, service_id=sid))


@router.get("/nurses", response_model=list[NurseOut])
async def list_nurses(_: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(select(Nurse).order_by(Nurse.id))).scalars().all()
    return [await _nurse_out(db, n) for n in rows]


@router.get("/nurses/{nurse_id}", response_model=NurseOut)
async def get_nurse(nurse_id: int, _: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    return await _nurse_out(db, await _nurse_or_404(db, nurse_id))


async def _nurse_or_404(db: AsyncSession, nurse_id: int) -> Nurse:
    n = (await db.execute(select(Nurse).where(Nurse.id == nurse_id))).scalar_one_or_none()
    if n is None:
        raise HTTPException(status_code=404, detail="Nurse not found")
    return n


@router.post("/nurses", response_model=NurseOut, status_code=201)
async def create_nurse(body: NurseIn, admin: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    sids = await _check_services(db, body.service_ids)
    data = body.model_dump(exclude={"service_ids"})
    data["phone"] = phone_or_400(data["phone"])
    n = Nurse(**data)
    db.add(n)
    await db.flush()
    await _set_services(db, n.id, sids)
    await log(db, actor_admin(admin), "nurse_created", nurse_id=n.id, name=n.name)
    await db.commit()
    return await _nurse_out(db, n)


@router.patch("/nurses/{nurse_id}", response_model=NurseOut)
async def patch_nurse(nurse_id: int, body: NursePatch, admin: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    n = await _nurse_or_404(db, nurse_id)
    changes = body.model_dump(exclude_unset=True)
    sids = changes.pop("service_ids", None)
    if sids is not None:
        await _set_services(db, n.id, await _check_services(db, sids))
    for k, v in changes.items():
        if k == "phone" and v:
            v = phone_or_400(v)
        if v is None and k in ("name", "phone", "gender", "experience_years", "is_active"):
            continue
        setattr(n, k, v)
    await log(db, actor_admin(admin), "nurse_updated", nurse_id=n.id)
    await db.commit()
    return await _nurse_out(db, n)


@router.put("/nurses/{nurse_id}/weekly-hours", response_model=NurseOut)
async def put_weekly_hours(
    nurse_id: int, body: list[HoursRow], admin: User = Depends(current_admin), db: AsyncSession = Depends(get_db)
):
    n = await _nurse_or_404(db, nurse_id)
    if len({r.weekday for r in body}) != len(body):
        raise HTTPException(status_code=400, detail="One time range per weekday.")
    await db.execute(delete(NurseWeeklyHours).where(NurseWeeklyHours.nurse_id == nurse_id))
    for r in body:
        db.add(NurseWeeklyHours(nurse_id=nurse_id, weekday=r.weekday, start_hour=r.start_hour, end_hour=r.end_hour))
    await log(db, actor_admin(admin), "nurse_hours_changed", nurse_id=nurse_id)
    await db.commit()
    return await _nurse_out(db, n)


@router.get("/nurses/{nurse_id}/overrides", response_model=list[OverrideOut])
async def list_overrides(
    nurse_id: int, month: str | None = None, _: User = Depends(current_admin), db: AsyncSession = Depends(get_db)
):
    q = select(NurseDayOverride).where(NurseDayOverride.nurse_id == nurse_id).order_by(NurseDayOverride.day)
    if month:
        y, m = (int(x) for x in month.split("-"))
        first = date(y, m, 1)
        nxt = date(y + (m // 12), (m % 12) + 1, 1)
        q = q.where(NurseDayOverride.day >= first, NurseDayOverride.day < nxt)
    return (await db.execute(q)).scalars().all()


async def affected_bookings(db: AsyncSession, nurse_id: int, first: date, last: date) -> list[Booking]:
    from sqlalchemy.orm import selectinload

    from app.models import BookingAssignment
    from app.timeutil import day_start

    return list(
        (
            await db.execute(
                select(Booking)
                .join(BookingAssignment, BookingAssignment.booking_id == Booking.id)
                .where(
                    BookingAssignment.nurse_id == nurse_id,
                    BookingAssignment.active.is_(True),
                    Booking.status.in_(["confirmed", "in_progress"]),
                    Booking.slot_start >= day_start(first),
                    Booking.slot_start < day_start(last) + timedelta(days=1),
                )
                .options(selectinload(Booking.assignments), selectinload(Booking.payment))
                .order_by(Booking.slot_start)
            )
        )
        .scalars()
        .all()
    )


@router.put("/nurses/{nurse_id}/overrides/{day}", response_model=OverrideOut)
async def put_override(
    nurse_id: int, day: date, body: OverrideIn, admin: User = Depends(current_admin), db: AsyncSession = Depends(get_db)
):
    await _nurse_or_404(db, nurse_id)
    row = (
        await db.execute(select(NurseDayOverride).where(NurseDayOverride.nurse_id == nurse_id, NurseDayOverride.day == day))
    ).scalar_one_or_none()
    if row is None:
        row = NurseDayOverride(nurse_id=nurse_id, day=day)
        db.add(row)
    row.is_leave = body.is_leave
    row.start_hour = None if body.is_leave else body.start_hour
    row.end_hour = None if body.is_leave else body.end_hour
    row.note = body.note
    await log(db, actor_admin(admin), "nurse_override_set", nurse_id=nurse_id, day=day.isoformat(), leave=body.is_leave)
    await db.commit()
    return row


@router.delete("/nurses/{nurse_id}/overrides/{day}", status_code=204)
async def delete_override(
    nurse_id: int, day: date, admin: User = Depends(current_admin), db: AsyncSession = Depends(get_db)
) -> Response:
    await db.execute(delete(NurseDayOverride).where(NurseDayOverride.nurse_id == nurse_id, NurseDayOverride.day == day))
    await log(db, actor_admin(admin), "nurse_override_removed", nurse_id=nurse_id, day=day.isoformat())
    await db.commit()
    return Response(status_code=204)


# --- nurse unavailable (bulk) -------------------------------------------------------------------
class UnavailableIn(BaseModel):
    from_day: date
    to_day: date
    note: str | None = None
    apply: bool = False

    @model_validator(mode="after")
    def _order(self):
        if self.to_day < self.from_day:
            raise ValueError("The end date is before the start date")
        return self


class AffectedItem(BaseModel):
    booking_id: int
    slot_start: str
    hours: int
    patient_name: str
    outcome: str  # "reassign" | "cancel"
    new_nurse: str | None = None


class UnavailableOut(BaseModel):
    applied: bool
    items: list[AffectedItem]


@router.post("/nurses/{nurse_id}/unavailable", response_model=UnavailableOut)
async def nurse_unavailable(
    nurse_id: int, body: UnavailableIn, admin: User = Depends(current_admin), db: AsyncSession = Depends(get_db)
):
    """Preview, then apply: mark leave, reassign every booking that can move, cancel the rest."""
    from app.services import availability as av

    n = await _nurse_or_404(db, nurse_id)
    cfg = await get_app_settings(db)
    items: list[AffectedItem] = []
    bookings = await affected_bookings(db, nurse_id, body.from_day, body.to_day)
    # Mark leave first (inside this transaction) so the nurse is excluded from the candidates below.
    day = body.from_day
    while day <= body.to_day:
        row = (
            await db.execute(select(NurseDayOverride).where(NurseDayOverride.nurse_id == nurse_id, NurseDayOverride.day == day))
        ).scalar_one_or_none()
        if row is None:
            row = NurseDayOverride(nurse_id=nurse_id, day=day)
            db.add(row)
        row.is_leave, row.start_hour, row.end_hour, row.note = True, None, None, body.note
        day += timedelta(days=1)
    await db.flush()
    for b in bookings:
        free = await av.free_nurses(
            db,
            service_id=b.service_id,
            start=b.slot_start,
            hours=b.hours,
            settings=cfg,
            gender=b.nurse_gender_preference,
            exclude_booking_id=b.id,
        )
        free = [f for f in free if f.id != nurse_id]
        target = await bk.pick_nurse(
            db, free, day=b.slot_start.date(), user_id=b.user_id, member_id=b.member_id, patient_name=b.patient_name
        )
        item = AffectedItem(
            booking_id=b.id,
            slot_start=b.slot_start.isoformat(),
            hours=b.hours,
            patient_name=b.patient_name,
            outcome="reassign" if target else "cancel",
            new_nurse=target.name if target else None,
        )
        items.append(item)
        if body.apply:
            try:
                if target:
                    await bk.reassign(db, b.id, target.id, admin=admin)
                else:
                    await bk.cancel_booking(db, b.id, reason="nurse unavailable", admin=admin)
            except BookingError as exc:
                raise HTTPException(status_code=exc.status, detail=exc.message) from exc
    if body.apply:
        await log(
            db,
            actor_admin(admin),
            "nurse_unavailable_applied",
            nurse_id=nurse_id,
            first=body.from_day.isoformat(),
            last=body.to_day.isoformat(),
            count=len(items),
        )
        await db.commit()
    else:
        await db.rollback()
    _ = n
    return UnavailableOut(applied=body.apply, items=items)

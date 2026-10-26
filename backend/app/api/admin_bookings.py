"""Admin: bookings, kill switch, reassign, messages, dashboard, jobs."""

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.bookings import maps_url, raise_http
from app.db import get_db
from app.deps import current_admin
from app.models import (
    ActivityLog,
    Booking,
    BookingAssignment,
    Message,
    Nurse,
    NurseService,
    NurseWeeklyHours,
    Payment,
    User,
    VisitLink,
)
from app.services import availability as av
from app.services import booking as bk
from app.services import messages as msgs
from app.services.activity import actor_admin, log
from app.services.errors import BookingError
from app.services.settings_service import get_app_settings
from app.timeutil import now_ist, utcnow

router = APIRouter(prefix="/admin", tags=["admin"])


class AdminNurseBrief(BaseModel):
    id: int
    name: str
    phone: str
    gender: str


class PaymentOut(BaseModel):
    status: str
    amount: int
    gateway: str
    payment_id: str | None
    refund_id: str | None
    refund_error: str | None


class MessageOut(BaseModel):
    id: int
    recipient_type: str
    recipient: str
    channel: str
    template: str
    status: str
    attempts: int
    last_error: str | None
    created_at: datetime
    sent_at: datetime | None

    model_config = {"from_attributes": True}


class HistoryOut(BaseModel):
    id: int
    actor: str
    action: str
    details: dict
    created_at: datetime

    model_config = {"from_attributes": True}


class AdminBookingRow(BaseModel):
    id: int
    status: str
    service_name: str
    patient_name: str
    slot_start: datetime
    slot_end: datetime
    hours: int
    amount: int
    nurse_gender_preference: str
    nurse: AdminNurseBrief | None
    payment_status: str | None
    cancel_reason: str | None


class AdminBookingDetail(AdminBookingRow):
    user_id: int
    user_phone: str | None
    patient_age: int | None
    patient_sex: str | None
    patient_condition: str | None
    contact_phone: str
    address_text: str
    address_landmark: str | None
    latitude: float
    longitude: float
    maps_url: str
    cancelled_by: str | None
    cancelled_at: datetime | None
    created_at: datetime
    payment: PaymentOut | None
    messages: list[MessageOut]
    history: list[HistoryOut]
    visit_link_opened_at: datetime | None


def _nurse_brief(b: Booking) -> AdminNurseBrief | None:
    a = bk.active_assignment(b)
    if a is None:
        return None
    return AdminNurseBrief(id=a.nurse.id, name=a.nurse.name, phone=a.nurse.phone, gender=a.nurse.gender)


def _row(b: Booking) -> AdminBookingRow:
    return AdminBookingRow(
        id=b.id,
        status=b.status,
        service_name=b.service.name,
        patient_name=b.patient_name,
        slot_start=b.slot_start,
        slot_end=b.slot_end,
        hours=b.hours,
        amount=b.amount,
        nurse_gender_preference=b.nurse_gender_preference,
        nurse=_nurse_brief(b),
        payment_status=b.payment.status if b.payment else None,
        cancel_reason=b.cancel_reason,
    )


async def _tick(db: AsyncSession) -> None:
    """Update-on-read safety net."""
    await bk.advance_lifecycle(db)
    await bk.expire_holds(db)
    await db.commit()


def _opts():
    return (selectinload(Booking.assignments), selectinload(Booking.payment))


@router.get("/bookings", response_model=list[AdminBookingRow])
async def list_bookings(
    status: str | None = None,
    nurse_id: int | None = None,
    day: str | None = None,
    q: str | None = None,
    limit: int = Query(default=100, le=500),
    _: User = Depends(current_admin),
    db: AsyncSession = Depends(get_db),
):
    await _tick(db)
    stmt = select(Booking).options(*_opts()).order_by(Booking.slot_start.desc()).limit(limit)
    # "expired" holds are internal noise: hidden unless asked for.
    stmt = stmt.where(Booking.status == status) if status else stmt.where(Booking.status != "expired")
    if nurse_id:
        stmt = stmt.join(BookingAssignment, BookingAssignment.booking_id == Booking.id).where(
            BookingAssignment.nurse_id == nurse_id, BookingAssignment.active.is_(True)
        )
    if day:
        d = datetime.fromisoformat(day).date()
        stmt = stmt.where(func.date(Booking.slot_start) == d)
    if q:
        like = f"%{q}%"
        conds: list = [Booking.patient_name.ilike(like), Booking.contact_phone.ilike(like)]
        if q.isdigit():
            conds.append(Booking.id == int(q))
        stmt = stmt.where(or_(*conds))
    return [_row(b) for b in (await db.execute(stmt)).scalars().all()]


async def _detail(db: AsyncSession, booking_id: int) -> AdminBookingDetail:
    b = (
        await db.execute(
            select(Booking).where(Booking.id == booking_id).options(*_opts()).execution_options(populate_existing=True)
        )
    ).scalar_one_or_none()
    if b is None:
        raise HTTPException(status_code=404, detail="Booking not found")
    user_phone = (await db.execute(select(User.phone).where(User.id == b.user_id))).scalar_one_or_none()
    msg_rows = (await db.execute(select(Message).where(Message.booking_id == b.id).order_by(Message.id))).scalars().all()
    hist = (await db.execute(select(ActivityLog).where(ActivityLog.booking_id == b.id).order_by(ActivityLog.id))).scalars().all()
    opened = (await db.execute(select(func.max(VisitLink.first_opened_at)).where(VisitLink.booking_id == b.id))).scalar_one()
    p = b.payment
    base = _row(b).model_dump()
    return AdminBookingDetail(
        **base,
        user_id=b.user_id,
        user_phone=user_phone,
        patient_age=b.patient_age,
        patient_sex=b.patient_sex,
        patient_condition=b.patient_condition,
        contact_phone=b.contact_phone,
        address_text=b.address_text,
        address_landmark=b.address_landmark,
        latitude=b.address_lat,
        longitude=b.address_lng,
        maps_url=maps_url(b.address_lat, b.address_lng),
        cancelled_by=b.cancelled_by,
        cancelled_at=b.cancelled_at,
        created_at=b.created_at,
        payment=PaymentOut(
            status=p.status,
            amount=p.amount,
            gateway=p.gateway,
            payment_id=p.payment_id,
            refund_id=p.refund_id,
            refund_error=p.refund_error,
        )
        if p
        else None,
        messages=[MessageOut.model_validate(m) for m in msg_rows],
        history=[HistoryOut.model_validate(h) for h in hist],
        visit_link_opened_at=opened,
    )


@router.get("/bookings/{booking_id}", response_model=AdminBookingDetail)
async def booking_detail(booking_id: int, _: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    await _tick(db)
    return await _detail(db, booking_id)


class CancelIn(BaseModel):
    reason: str = Field(min_length=1, max_length=200)


@router.post("/bookings/{booking_id}/cancel", response_model=AdminBookingDetail)
async def cancel(booking_id: int, body: CancelIn, admin: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    try:
        await bk.cancel_booking(db, booking_id, reason=body.reason, admin=admin)
    except BookingError as exc:
        raise raise_http(exc) from exc
    return await _detail(db, booking_id)


class ReassignIn(BaseModel):
    nurse_id: int


@router.post("/bookings/{booking_id}/reassign", response_model=AdminBookingDetail)
async def reassign(booking_id: int, body: ReassignIn, admin: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    try:
        await bk.reassign(db, booking_id, body.nurse_id, admin=admin)
    except BookingError as exc:
        raise raise_http(exc) from exc
    return await _detail(db, booking_id)


class StatusIn(BaseModel):
    status: str = Field(pattern="^(in_progress|completed)$")


@router.post("/bookings/{booking_id}/status", response_model=AdminBookingDetail)
async def set_status(booking_id: int, body: StatusIn, admin: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    b = (await db.execute(select(Booking).where(Booking.id == booking_id).with_for_update())).scalar_one_or_none()
    if b is None:
        raise HTTPException(status_code=404, detail="Booking not found")
    allowed = {"confirmed": ["in_progress", "completed"], "in_progress": ["completed"]}
    if body.status not in allowed.get(b.status, []):
        raise HTTPException(status_code=409, detail="That status change is not allowed.")
    b.status = body.status
    if body.status == "completed":
        for a in (
            await db.execute(
                select(BookingAssignment).where(BookingAssignment.booking_id == b.id, BookingAssignment.active.is_(True))
            )
        ).scalars():
            a.active = False
            a.ended_at = utcnow()
    await log(db, actor_admin(admin), "status_corrected", booking_id=b.id, status=body.status)
    await db.commit()
    return await _detail(db, booking_id)


class CandidateOut(BaseModel):
    id: int
    name: str
    gender: str
    qualified: bool
    same_gender: bool
    on_duty: bool
    free: bool


@router.get("/bookings/{booking_id}/reassign-candidates", response_model=list[CandidateOut])
async def reassign_candidates(booking_id: int, _: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    """Every active nurse, qualified and same-gender first, with whether they are free for the slot."""
    b = (await db.execute(select(Booking).where(Booking.id == booking_id).options(*_opts()))).scalar_one_or_none()
    if b is None:
        raise HTTPException(status_code=404, detail="Booking not found")
    cfg = await get_app_settings(db)
    nurses = (await db.execute(select(Nurse).where(Nurse.is_active.is_(True)).order_by(Nurse.id))).scalars().all()
    ids = [n.id for n in nurses]
    qualified = set(
        (await db.execute(select(NurseService.nurse_id).where(NurseService.service_id == b.service_id))).scalars().all()
    )
    day = b.slot_start.date()
    wins = await av.windows_for_day(db, ids, day)
    busy = await av.busy_ranges(db, ids, day, exclude_booking_id=b.id)
    current = bk.active_assignment(b)
    out = []
    for n in nurses:
        if current and n.id == current.nurse_id:
            continue
        w = wins.get(n.id)
        on_duty = bool(w and w[0] <= b.slot_start.hour and b.slot_start.hour + b.hours <= w[1])
        no_conflict = av.is_free((0, 24), busy.get(n.id, []), day, b.slot_start.hour, b.hours, cfg.travel_gap_hours)
        out.append(
            CandidateOut(
                id=n.id,
                name=n.name,
                gender=n.gender,
                qualified=n.id in qualified,
                same_gender=n.gender == b.nurse_gender_preference,
                on_duty=on_duty,
                free=no_conflict and on_duty,
            )
        )
    out.sort(key=lambda c: (not (c.qualified and c.free), not c.same_gender, not c.qualified, c.id))
    return out


@router.post("/messages/{message_id}/resend", response_model=MessageOut)
async def resend_message(message_id: int, _: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    m = (await db.execute(select(Message).where(Message.id == message_id))).scalar_one_or_none()
    if m is None or m.template == "otp":
        raise HTTPException(status_code=404, detail="Message not found")
    await msgs.resend(db, m)
    await msgs.deliver(db, m)
    await db.commit()
    return m


# --- dashboard ---------------------------------------------------------------------------------
class AttentionItem(BaseModel):
    kind: str  # refund_failed | system_cancel | message_failed | nurse_setup
    title: str
    detail: str
    booking_id: int | None = None
    nurse_id: int | None = None
    message_id: int | None = None


class TodayNurse(BaseModel):
    nurse_id: int
    nurse_name: str
    visits: list[AdminBookingRow]


class DashboardOut(BaseModel):
    attention: list[AttentionItem]
    today: list[TodayNurse]


@router.get("/dashboard", response_model=DashboardOut)
async def dashboard(_: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    await _tick(db)
    attention: list[AttentionItem] = []
    for p in (await db.execute(select(Payment).where(Payment.status == "refund_failed"))).scalars():
        attention.append(
            AttentionItem(
                kind="refund_failed",
                title=f"Refund failed for booking #{p.booking_id}",
                detail=p.refund_error or "Refund by hand in Razorpay",
                booking_id=p.booking_id,
            )
        )
    week_ago = utcnow().replace(microsecond=0)
    from datetime import timedelta

    for b in (
        await db.execute(
            select(Booking).where(Booking.cancelled_by == "system", Booking.cancelled_at > week_ago - timedelta(days=7))
        )
    ).scalars():
        attention.append(
            AttentionItem(
                kind="system_cancel", title=f"Booking #{b.id} auto-cancelled", detail=b.cancel_reason or "", booking_id=b.id
            )
        )
    for m in (
        await db.execute(
            select(Message).where(Message.status == "failed", Message.recipient_type == "nurse", Message.template != "otp")
        )
    ).scalars():
        attention.append(
            AttentionItem(
                kind="message_failed",
                title=f"Nurse message failed (booking #{m.booking_id})",
                detail=m.last_error or "",
                booking_id=m.booking_id,
                message_id=m.id,
            )
        )
    with_hours = set((await db.execute(select(NurseWeeklyHours.nurse_id))).scalars().all())
    with_services = set((await db.execute(select(NurseService.nurse_id))).scalars().all())
    for n in (await db.execute(select(Nurse).where(Nurse.is_active.is_(True)).order_by(Nurse.id))).scalars():
        if n.id not in with_hours or n.id not in with_services:
            attention.append(
                AttentionItem(
                    kind="nurse_setup",
                    title=f"{n.name} is not bookable",
                    detail="Missing working hours or services",
                    nurse_id=n.id,
                )
            )

    today = now_ist().date()
    rows = (
        (
            await db.execute(
                select(Booking)
                .where(func.date(Booking.slot_start) == today, Booking.status.in_(["confirmed", "in_progress", "completed"]))
                .options(*_opts())
                .order_by(Booking.slot_start)
            )
        )
        .scalars()
        .all()
    )
    by_nurse: dict[int, TodayNurse] = {}
    for b in rows:
        a = next((x for x in b.assignments if x.active), None) or (b.assignments[-1] if b.assignments else None)
        if a is None:
            continue
        by_nurse.setdefault(a.nurse_id, TodayNurse(nurse_id=a.nurse_id, nurse_name=a.nurse.name, visits=[])).visits.append(
            _row(b)
        )
    return DashboardOut(attention=attention, today=list(by_nurse.values()))


@router.post("/jobs/run", status_code=200)
async def run_jobs_now(_: User = Depends(current_admin)):
    """Staging runs without the worker: this runs every periodic job once, on demand."""
    from app.jobs.tasks import run_all_once

    return await run_all_once()


@router.get("/activity")
async def recent_activity(limit: int = 50, _: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    rows = (await db.execute(select(ActivityLog).order_by(ActivityLog.id.desc()).limit(min(limit, 200)))).scalars().all()
    return [HistoryOut.model_validate(r) for r in rows]

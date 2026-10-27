"""Booking creation, assignment, payment finalisation, cancel, reassign, lifecycle."""

import asyncio
import logging
from dataclasses import dataclass
from datetime import date, datetime, timedelta

from sqlalchemy import func, select, update
from sqlalchemy.exc import DBAPIError, IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import settings as env
from app.integrations.payments import GatewayError, get_gateway
from app.models import (
    Address,
    AppSettings,
    Booking,
    BookingAssignment,
    FamilyMember,
    Nurse,
    Payment,
    Service,
    User,
)
from app.services import availability as av
from app.services import messages
from app.services import visit_links as vl
from app.services.activity import log
from app.services.errors import BookingError
from app.services.settings_service import get_app_settings
from app.timeutil import day_start, fmt_slot_when, now_ist, utcnow

HOLD = timedelta(minutes=15)
LIVE_STATUSES = ("pending_payment", "confirmed", "in_progress")


# --- validation ---------------------------------------------------------
def validate_slot(start: datetime, hours: int, cfg: AppSettings, *, now: datetime | None = None) -> None:
    """Pure rules: whole hours, single day, notice and window. Raises BookingError."""
    now = now or now_ist()
    if start.tzinfo is not None:
        raise BookingError("bad_slot", "Send the start time as Indian time without a time zone.")
    if start.minute or start.second or start.microsecond:
        raise BookingError("bad_slot", "Bookings start on the hour.")
    if not 1 <= hours <= av.MAX_HOURS:
        raise BookingError("bad_hours", f"Choose between 1 and {av.MAX_HOURS} hours.")
    if start.hour + hours > 24:
        raise BookingError("crosses_midnight", "A booking must finish by midnight on the same day.")
    if start < now + timedelta(minutes=cfg.min_notice_minutes):
        raise BookingError("too_soon", "That time is too soon. Please pick a later start.")
    last_day = now.date() + timedelta(days=cfg.booking_window_days)
    if start.date() > last_day:
        raise BookingError("too_far", "That day is too far ahead to book.")


def price(service: Service, hours: int) -> int:
    return service.base_price * hours


async def _service_or_error(db: AsyncSession, service_id: int) -> Service:
    s = (await db.execute(select(Service).where(Service.id == service_id))).scalar_one_or_none()
    if s is None or not s.active:
        raise BookingError("service_unavailable", "This service is not available.", 404)
    return s


# --- expiring holds -------------------------------------------------------
async def expire_holds(db: AsyncSession, nurse_ids: list[int] | None = None) -> int:
    """Expire unpaid bookings past their hold and free their nurses. Never touches paid ones."""
    now = utcnow()
    q = (
        select(Booking.id)
        .join(Payment, Payment.booking_id == Booking.id, isouter=True)
        .where(
            Booking.status == "pending_payment",
            Booking.hold_expires_at <= now,
            func.coalesce(Payment.status, "pending") != "completed",
        )
    )
    if nurse_ids is not None:
        q = q.join(BookingAssignment, BookingAssignment.booking_id == Booking.id).where(
            BookingAssignment.nurse_id.in_(nurse_ids), BookingAssignment.active.is_(True)
        )
    ids = list((await db.execute(q.with_for_update(of=Booking))).scalars().all())
    if not ids:
        return 0
    await db.execute(update(Booking).where(Booking.id.in_(ids)).values(status="expired"))
    await db.execute(
        update(BookingAssignment)
        .where(BookingAssignment.booking_id.in_(ids), BookingAssignment.active.is_(True))
        .values(active=False, ended_at=now)
    )
    return len(ids)


async def _lock_nurses(db: AsyncSession, nurse_ids: list[int]) -> None:
    if nurse_ids:
        await db.execute(select(Nurse.id).where(Nurse.id.in_(nurse_ids)).order_by(Nurse.id).with_for_update())


# --- nurse pick (D6) ---------------------------------------------------------
async def _booked_hours(db: AsyncSession, nurse_ids: list[int], first: date, last: date) -> dict[int, dict[date, int]]:
    """Live booked hours per nurse per day between first and last (inclusive)."""
    q = (
        select(BookingAssignment.nurse_id, BookingAssignment.slot_start, BookingAssignment.slot_end)
        .join(Booking, Booking.id == BookingAssignment.booking_id)
        .where(
            BookingAssignment.nurse_id.in_(nurse_ids),
            BookingAssignment.slot_start >= day_start(first),
            BookingAssignment.slot_start < day_start(last) + timedelta(days=1),
            av.live_assignment_filter(),
        )
    )
    out: dict[int, dict[date, int]] = {n: {} for n in nurse_ids}
    for nid, s, e in (await db.execute(q)).all():
        out[nid][s.date()] = out[nid].get(s.date(), 0) + int((e - s).total_seconds() // 3600)
    return out


async def pick_nurse(
    db: AsyncSession,
    candidates: list[Nurse],
    *,
    day: date,
    user_id: int,
    member_id: int | None,
    patient_name: str,
    prefer_nurse_id: int | None = None,
) -> Nurse | None:
    """1) nurse from this patient's last completed visit, 2) fewest hours that day,
    3) fewest hours that week, 4) lowest id."""
    if not candidates:
        return None
    by_id = {n.id: n for n in candidates}
    if prefer_nurse_id in by_id:
        return by_id[prefer_nurse_id]

    patient_match = Booking.member_id == member_id if member_id is not None else Booking.patient_name == patient_name
    last = (
        await db.execute(
            select(BookingAssignment.nurse_id)
            .join(Booking, Booking.id == BookingAssignment.booking_id)
            .where(Booking.user_id == user_id, Booking.status == "completed", patient_match)
            .order_by(Booking.slot_end.desc(), BookingAssignment.id.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    if last in by_id:
        return by_id[last]

    week_start = day - timedelta(days=day.weekday())
    week_end = week_start + timedelta(days=6)
    hours = await _booked_hours(db, list(by_id), week_start, week_end)

    def key(n: Nurse) -> tuple[int, int, int]:
        per_day = hours[n.id]
        return (per_day.get(day, 0), sum(per_day.values()), n.id)

    return min(candidates, key=key)


# --- create -------------------------------------------------------------------
@dataclass
class CreateInput:
    user: User
    service_id: int
    start: datetime
    hours: int
    nurse_gender: str
    address_id: int
    member_id: int | None
    patient_name: str
    patient_age: int | None
    patient_sex: str | None
    patient_condition: str | None
    contact_phone: str


def _address_text(a: Address) -> str:
    parts = [a.house, a.area_line, a.city, a.state, a.pincode]
    return ", ".join(p for p in parts if p)


async def create_booking(db: AsyncSession, data: CreateInput) -> Booking:
    cfg = await get_app_settings(db)
    if cfg.bookings_paused:
        raise BookingError("paused", "Bookings are temporarily unavailable. Please try again later.", 409)
    validate_slot(data.start, data.hours, cfg)
    service = await _service_or_error(db, data.service_id)

    address = (
        await db.execute(select(Address).where(Address.id == data.address_id, Address.user_id == data.user.id))
    ).scalar_one_or_none()
    if address is None:
        raise BookingError("bad_address", "Choose a saved address with a map pin.", 404)
    if data.member_id is not None:
        owns = (
            await db.execute(
                select(FamilyMember.id).where(FamilyMember.id == data.member_id, FamilyMember.user_id == data.user.id)
            )
        ).first()
        if not owns:
            raise BookingError("bad_member", "That family member was not found.", 404)

    candidates = await av.qualified_nurses(db, service.id, data.nurse_gender)
    await _lock_nurses(db, [n.id for n in candidates])
    # A hold that expired a moment ago must not block this booking, so free it first.
    await expire_holds(db, [n.id for n in candidates])
    free = await av.free_nurses(
        db, service_id=service.id, start=data.start, hours=data.hours, settings=cfg, gender=data.nurse_gender
    )
    nurse = await pick_nurse(
        db,
        free,
        day=data.start.date(),
        user_id=data.user.id,
        member_id=data.member_id,
        patient_name=data.patient_name,
    )
    if nurse is None:
        await db.rollback()
        raise BookingError("no_nurse_free", "No nurse is free for that time. Please choose another time.", 409)

    end = data.start + timedelta(hours=data.hours)
    booking = Booking(
        user_id=data.user.id,
        member_id=data.member_id,
        service_id=service.id,
        slot_start=data.start,
        slot_end=end,
        hours=data.hours,
        amount=price(service, data.hours),
        nurse_gender_preference=data.nurse_gender,
        status="pending_payment",
        hold_expires_at=utcnow() + HOLD,
        patient_name=data.patient_name,
        patient_age=data.patient_age,
        patient_sex=data.patient_sex,
        patient_condition=data.patient_condition,
        contact_phone=data.contact_phone,
        address_text=_address_text(address),
        address_landmark=address.landmark,
        address_lat=address.latitude,
        address_lng=address.longitude,
    )
    db.add(booking)
    try:
        await db.flush()
        db.add(BookingAssignment(booking_id=booking.id, nurse_id=nurse.id, slot_start=data.start, slot_end=end))
        await db.flush()
    except IntegrityError as exc:
        await db.rollback()
        if _is_overlap(exc):
            raise BookingError("no_nurse_free", "That nurse was just booked. Please choose another time.", 409) from exc
        raise
    await log(db, f"user:{data.user.id}", "booking_created", booking_id=booking.id, nurse_id=nurse.id)
    await db.commit()
    return await load_booking(db, booking.id)


def _is_overlap(exc: DBAPIError) -> bool:
    orig = getattr(exc, "orig", None)
    code = getattr(orig, "sqlstate", None) or getattr(orig, "pgcode", None)
    cause = getattr(orig, "__cause__", None)
    code = code or getattr(cause, "sqlstate", None)
    return code == "23P01" or "no_overlap_active_nurse" in str(exc)


async def load_booking(db: AsyncSession, booking_id: int) -> Booking:
    b = (
        await db.execute(
            select(Booking)
            .where(Booking.id == booking_id)
            .options(selectinload(Booking.assignments), selectinload(Booking.payment))
            .execution_options(populate_existing=True)
        )
    ).scalar_one()
    return b


def active_assignment(b: Booking) -> BookingAssignment | None:
    return next((a for a in b.assignments if a.active), None)


def short_name(name: str) -> str:
    parts = name.split()
    if len(parts) < 2:
        return name
    return f"{parts[0]} {parts[-1][0]}."


# --- payment finalisation ---------------------------------------------------------
async def finalize_payment(db: AsyncSession, booking_id: int, payment_id: str) -> Booking:
    """Idempotent. Called by verify and by the webhook; whichever arrives first wins.

    Outcomes: confirmed (kept nurse, or another free nurse of the same gender), or
    cancelled with a full refund when nobody is free.
    """
    booking = (
        await db.execute(
            select(Booking).where(Booking.id == booking_id).with_for_update().execution_options(populate_existing=True)
        )
    ).scalar_one_or_none()
    if booking is None:
        raise BookingError("not_found", "Booking not found.", 404)
    payment = (
        await db.execute(
            select(Payment).where(Payment.booking_id == booking_id).with_for_update().execution_options(populate_existing=True)
        )
    ).scalar_one_or_none()
    if payment is None:
        raise BookingError("no_payment", "No payment was started for this booking.", 400)

    if booking.status in ("confirmed", "in_progress", "completed"):
        await db.commit()
        return await load_booking(db, booking_id)
    if booking.status == "cancelled":
        if payment.status == "pending":
            # Cancelled by admin before the money arrived; the money is real, so refund it.
            payment.payment_id = payment.payment_id or payment_id
            payment.status = "refund_pending"
            await process_refund(db, payment)
        await db.commit()
        return await load_booking(db, booking_id)

    payment.payment_id = payment_id
    payment.status = "completed"

    cfg = await get_app_settings(db)
    old = await db.execute(
        select(BookingAssignment).where(BookingAssignment.booking_id == booking_id, BookingAssignment.active.is_(True))
    )
    current = old.scalars().first()
    held_valid = (
        booking.status == "pending_payment"
        and booking.hold_expires_at is not None
        and booking.hold_expires_at > utcnow()
        and current is not None
    )

    nurse: Nurse | None = None
    if held_valid and current is not None:
        nurse = current.nurse
    else:
        # Hold expired. Keep the same nurse if still free, else reassign, else cancel + refund.
        prev_nurse_id = current.nurse_id if current else None
        if current is None:
            prev = (
                await db.execute(
                    select(BookingAssignment.nurse_id)
                    .where(BookingAssignment.booking_id == booking_id)
                    .order_by(BookingAssignment.id.desc())
                    .limit(1)
                )
            ).scalar_one_or_none()
            prev_nurse_id = prev
        candidates = await av.qualified_nurses(db, booking.service_id, booking.nurse_gender_preference)
        await _lock_nurses(db, [n.id for n in candidates])
        await expire_holds(db, [n.id for n in candidates])
        if current is not None:
            current.active = False
            current.ended_at = utcnow()
            await db.flush()
        free = await av.free_nurses(
            db,
            service_id=booking.service_id,
            start=booking.slot_start,
            hours=booking.hours,
            settings=cfg,
            gender=booking.nurse_gender_preference,
            exclude_booking_id=booking.id,
        )
        nurse = await pick_nurse(
            db,
            free,
            day=booking.slot_start.date(),
            user_id=booking.user_id,
            member_id=booking.member_id,
            patient_name=booking.patient_name,
            prefer_nurse_id=prev_nurse_id,
        )
        if nurse is not None:
            try:
                db.add(
                    BookingAssignment(
                        booking_id=booking.id, nurse_id=nurse.id, slot_start=booking.slot_start, slot_end=booking.slot_end
                    )
                )
                await db.flush()
            except IntegrityError as exc:
                if not _is_overlap(exc):
                    raise
                await db.rollback()
                return await _auto_cancel_no_nurse(booking_id, payment_id)

    if nurse is None:
        await _cancel_with_refund(db, booking, payment, by="system", reason="no nurse free at that time")
        await log(db, "system", "auto_cancelled_no_nurse", booking_id=booking.id)
        _notify_admin_email(db, booking, "Booking auto-cancelled", "No nurse was free after payment. The booking was refunded.")
        await db.commit()
        return await load_booking(db, booking_id)

    booking.status = "confirmed"
    booking.hold_expires_at = None
    link = await vl.create_link(db, booking, nurse.id)
    await log(db, "system", "booking_confirmed", booking_id=booking.id, nurse_id=nurse.id)
    await attach_user_phone(db, booking)
    _queue_confirmed_messages(db, booking, nurse, link.token)
    await db.commit()
    return await load_booking(db, booking_id)


async def _auto_cancel_no_nurse(booking_id: int, payment_id: str) -> Booking:
    """Constraint lost the race at the last moment: redo as a cancel + refund in a fresh transaction."""
    from app.db import SessionLocal

    async with SessionLocal() as db2:
        booking = (
            await db2.execute(
                select(Booking).where(Booking.id == booking_id).with_for_update().execution_options(populate_existing=True)
            )
        ).scalar_one()
        payment = (
            await db2.execute(
                select(Payment)
                .where(Payment.booking_id == booking_id)
                .with_for_update()
                .execution_options(populate_existing=True)
            )
        ).scalar_one()
        payment.payment_id = payment.payment_id or payment_id
        payment.status = "completed"
        await _cancel_with_refund(db2, booking, payment, by="system", reason="no nurse free at that time")
        await log(db2, "system", "auto_cancelled_no_nurse", booking_id=booking.id)
        await db2.commit()
        return await load_booking(db2, booking_id)


# --- messages ------------------------------------------------------------------------
def _when_hours(b: Booking) -> str:
    return f"{fmt_slot_when(b.slot_start)}, {b.hours} hours" if b.hours != 1 else f"{fmt_slot_when(b.slot_start)}, 1 hour"


def _user_phone(db_user_phone: str | None) -> str | None:
    return db_user_phone


def _queue_confirmed_messages(db: AsyncSession, b: Booking, nurse: Nurse, token: str) -> None:
    # The user's phone is read from the user row at send time by the caller via b.user_phone cache.
    _queue_user_sms(
        db,
        b,
        "booking_confirmed",
        {"booking_no": str(b.id), "nurse": short_name(nurse.name), "when": fmt_slot_when(b.slot_start)},
    )
    _queue_nurse_visit(db, b, nurse, token)
    _notify_admin_email(
        db, b, f"Booking #{b.id} confirmed", f"{b.patient_name}, {fmt_slot_when(b.slot_start)}, {b.hours} h, nurse {nurse.name}."
    )


def _queue_user_sms(db: AsyncSession, b: Booking, template: str, variables: dict[str, str]) -> None:
    phone = getattr(b, "_user_phone", None) or b.contact_phone
    if phone:
        messages.enqueue_sms(db, phone=phone, template=template, variables=variables, recipient_type="user", booking_id=b.id)


def _queue_nurse_visit(db: AsyncSession, b: Booking, nurse: Nurse, token: str) -> None:
    link = vl.link_url(token)
    variables = {"booking_no": str(b.id), "when_hours": _when_hours(b), "link": link}
    if env.NURSE_SMS_ENABLED:
        messages.enqueue_sms(
            db, phone=nurse.phone, template="visit_new", variables=variables, recipient_type="nurse", booking_id=b.id
        )
    if nurse.email:
        messages.enqueue_email(
            db,
            to=nurse.email,
            template="visit_new",
            subject=f"New CareNest visit #{b.id}",
            html=f'<p>New visit #{b.id} on {_when_hours(b)}.</p><p>Patient, address and directions: <a href="{link}">{link}</a></p><p>Please do not share this link.</p>',
            recipient_type="nurse",
            booking_id=b.id,
        )


def _queue_nurse_simple(db: AsyncSession, b: Booking, nurse: Nurse, template: str) -> None:
    variables = {"booking_no": str(b.id), "when": fmt_slot_when(b.slot_start)}
    if env.NURSE_SMS_ENABLED:
        messages.enqueue_sms(
            db, phone=nurse.phone, template=template, variables=variables, recipient_type="nurse", booking_id=b.id
        )
    if nurse.email:
        text = "no longer assigned to you" if template == "visit_removed" else "cancelled. Please do not travel"
        messages.enqueue_email(
            db,
            to=nurse.email,
            template=template,
            subject=f"CareNest visit #{b.id} update",
            html=f"<p>Visit #{b.id} on {fmt_slot_when(b.slot_start)} is {text}.</p>",
            recipient_type="nurse",
            booking_id=b.id,
        )


def _notify_admin_email(db: AsyncSession, b: Booking, subject: str, text: str) -> None:
    messages.enqueue_email(
        db,
        to=env.ADMIN_NOTIFY_EMAIL,
        template="admin_notice",
        subject=f"CareNest: {subject}",
        html=f"<p>{text}</p>",
        recipient_type="admin",
        booking_id=b.id,
    )


async def attach_user_phone(db: AsyncSession, b: Booking) -> None:
    phone = (await db.execute(select(User.phone).where(User.id == b.user_id))).scalar_one_or_none()
    b._user_phone = phone  # type: ignore[attr-defined]


# --- refunds ---------------------------------------------------------------------------
async def process_refund(db: AsyncSession, payment: Payment) -> None:
    """Idempotent: refunded stays refunded; failures become refund_failed (retried by the scheduler)."""
    if payment.status == "refunded":
        return
    if payment.status not in ("refund_pending", "refund_failed"):
        return
    if payment.refund_id:  # already issued; just record it
        payment.status = "refunded"
        payment.refunded_at = payment.refunded_at or utcnow()
        return
    if not payment.payment_id:
        payment.status = "refund_failed"
        payment.refund_error = "No gateway payment id on record"
        return
    try:
        refund_id = await asyncio.to_thread(get_gateway().refund, payment.payment_id, payment.amount)
    except GatewayError as exc:
        first_failure = payment.status != "refund_failed"
        payment.status = "refund_failed"
        payment.refund_error = str(exc)[:500]
        if first_failure:
            messages.enqueue_email(
                db,
                to=env.ADMIN_NOTIFY_EMAIL,
                template="admin_notice",
                subject=f"CareNest: Refund failed for booking #{payment.booking_id}",
                html=f"<p>The automatic refund of Rs {payment.amount} failed: {payment.refund_error}. Refund it by hand in Razorpay.</p>",
                recipient_type="admin",
                booking_id=payment.booking_id,
            )
        logging.getLogger(__name__).error("Refund failed for payment %s: %s", payment.id, exc)
        return
    payment.refund_id = refund_id
    payment.status = "refunded"
    payment.refunded_at = utcnow()
    payment.refund_error = None


async def _cancel_with_refund(db: AsyncSession, b: Booking, payment: Payment | None, *, by: str, reason: str) -> None:
    had_nurse = (
        (
            await db.execute(
                select(BookingAssignment).where(BookingAssignment.booking_id == b.id, BookingAssignment.active.is_(True))
            )
        )
        .scalars()
        .first()
    )
    was_visit_live = b.status in ("confirmed", "in_progress")
    b.status = "cancelled"
    b.cancelled_by = by
    b.cancel_reason = reason
    b.cancelled_at = utcnow()
    b.hold_expires_at = None
    await db.execute(
        update(BookingAssignment)
        .where(BookingAssignment.booking_id == b.id, BookingAssignment.active.is_(True))
        .values(active=False, ended_at=utcnow())
    )
    await vl.revoke_links(db, b.id)
    await attach_user_phone(db, b)
    paid = payment is not None and payment.status in ("completed", "refund_pending", "refund_failed", "refunded")
    if paid and payment is not None:
        if payment.status == "completed":
            payment.status = "refund_pending"
        await process_refund(db, payment)
        _queue_user_sms(db, b, "booking_cancelled", {"booking_no": str(b.id), "reason": reason, "amount": str(payment.amount)})
    elif payment is not None and payment.status == "pending":
        pass  # unpaid hold; a late payment is refunded by finalize_payment
    if was_visit_live and had_nurse is not None:
        nurse = (await db.execute(select(Nurse).where(Nurse.id == had_nurse.nurse_id))).scalar_one()
        _queue_nurse_simple(db, b, nurse, "visit_cancelled")


async def cancel_booking(db: AsyncSession, booking_id: int, *, reason: str, admin: User) -> Booking:
    """The kill switch."""
    from app.services.activity import actor_admin

    reason = reason.strip()
    if not reason:
        raise BookingError("reason_required", "Enter a reason for cancelling.")
    booking = (
        await db.execute(
            select(Booking).where(Booking.id == booking_id).with_for_update().execution_options(populate_existing=True)
        )
    ).scalar_one_or_none()
    if booking is None:
        raise BookingError("not_found", "Booking not found.", 404)
    if booking.status in ("completed", "cancelled", "expired"):
        raise BookingError("not_cancellable", "This booking can no longer be cancelled.", 409)
    payment = (
        await db.execute(
            select(Payment).where(Payment.booking_id == booking_id).with_for_update().execution_options(populate_existing=True)
        )
    ).scalar_one_or_none()
    await _cancel_with_refund(db, booking, payment, by="admin", reason=reason)
    await log(db, actor_admin(admin), "booking_cancelled", booking_id=booking.id, reason=reason)
    await db.commit()
    return await load_booking(db, booking_id)


# --- reassign -----------------------------------------------------------------------------
async def reassign(db: AsyncSession, booking_id: int, nurse_id: int, *, admin: User) -> Booking:
    from app.services.activity import actor_admin

    booking = (
        await db.execute(
            select(Booking).where(Booking.id == booking_id).with_for_update().execution_options(populate_existing=True)
        )
    ).scalar_one_or_none()
    if booking is None:
        raise BookingError("not_found", "Booking not found.", 404)
    if booking.status not in ("confirmed", "in_progress"):
        raise BookingError("not_reassignable", "Only confirmed or in-progress visits can be reassigned.", 409)
    nurse = (await db.execute(select(Nurse).where(Nurse.id == nurse_id))).scalar_one_or_none()
    if nurse is None or not nurse.is_active:
        raise BookingError("bad_nurse", "That nurse is not available.", 404)
    cur = (
        (
            await db.execute(
                select(BookingAssignment).where(BookingAssignment.booking_id == booking_id, BookingAssignment.active.is_(True))
            )
        )
        .scalars()
        .first()
    )
    if cur is not None and cur.nurse_id == nurse_id:
        raise BookingError("same_nurse", "That nurse is already assigned.", 409)

    cfg = await get_app_settings(db)
    await _lock_nurses(db, [nurse_id])
    await expire_holds(db, [nurse_id])
    busy = await av.busy_ranges(db, [nurse_id], booking.slot_start.date(), exclude_booking_id=booking.id)
    gap = timedelta(hours=cfg.travel_gap_hours)
    if any(bs < booking.slot_end + gap and be + gap > booking.slot_start for bs, be in busy[nurse_id]):
        raise BookingError("nurse_busy", "That nurse has another visit at that time.", 409)

    old_nurse = None
    if cur is not None:
        cur.active = False
        cur.ended_at = utcnow()
        old_nurse = (await db.execute(select(Nurse).where(Nurse.id == cur.nurse_id))).scalar_one()
        await db.flush()
    await vl.revoke_links(db, booking.id)
    try:
        db.add(
            BookingAssignment(booking_id=booking.id, nurse_id=nurse_id, slot_start=booking.slot_start, slot_end=booking.slot_end)
        )
        await db.flush()
    except IntegrityError as exc:
        await db.rollback()
        if _is_overlap(exc):
            raise BookingError("nurse_busy", "That nurse has another visit at that time.", 409) from exc
        raise
    link = await vl.create_link(db, booking, nurse_id)
    await attach_user_phone(db, booking)
    if old_nurse is not None:
        _queue_nurse_simple(db, booking, old_nurse, "visit_removed")
    _queue_nurse_visit(db, booking, nurse, link.token)
    _queue_user_sms(db, booking, "nurse_changed", {"booking_no": str(booking.id), "nurse": short_name(nurse.name)})
    await log(
        db,
        actor_admin(admin),
        "nurse_reassigned",
        booking_id=booking.id,
        nurse_id=nurse_id,
        from_nurse=old_nurse.id if old_nurse else None,
    )
    await db.commit()
    return await load_booking(db, booking_id)


# --- lifecycle ---------------------------------------------------------------------------------
async def advance_lifecycle(db: AsyncSession) -> int:
    """confirmed -> in_progress at start, -> completed at end. Idempotent; also run on read."""
    now = now_ist()
    n = 0
    to_complete = (
        (
            await db.execute(
                select(Booking)
                .where(Booking.status.in_(["confirmed", "in_progress"]), Booking.slot_end <= now)
                .with_for_update(skip_locked=True)
            )
        )
        .scalars()
        .all()
    )
    for b in to_complete:
        b.status = "completed"
        await db.execute(
            update(BookingAssignment)
            .where(BookingAssignment.booking_id == b.id, BookingAssignment.active.is_(True))
            .values(active=False, ended_at=utcnow())
        )
        await log(db, "system", "visit_completed", booking_id=b.id)
        n += 1
    to_start = (
        (
            await db.execute(
                select(Booking).where(Booking.status == "confirmed", Booking.slot_start <= now).with_for_update(skip_locked=True)
            )
        )
        .scalars()
        .all()
    )
    for b in to_start:
        b.status = "in_progress"
        await log(db, "system", "visit_started", booking_id=b.id)
        n += 1
    if n:
        await db.commit()
    return n


async def retry_refunds(db: AsyncSession) -> int:
    rows = (
        (
            await db.execute(
                select(Payment).where(Payment.status.in_(["refund_pending", "refund_failed"])).with_for_update(skip_locked=True)
            )
        )
        .scalars()
        .all()
    )
    for p in rows:
        await process_refund(db, p)
    await db.commit()
    return len(rows)

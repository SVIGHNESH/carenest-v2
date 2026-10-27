import asyncio
import json
import logging

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db import get_db
from app.deps import current_user
from app.integrations.payments import FakeGateway, GatewayError, get_gateway
from app.models import Booking, Payment, User
from app.phone import phone_or_400
from app.schemas.booking import (
    BookingCreateIn,
    BookingOut,
    FakePayIn,
    FakePayOut,
    OrderIn,
    OrderOut,
    RefundOut,
    VerifyIn,
)
from app.services import booking as bk
from app.services.errors import BookingError
from app.services.settings_service import get_app_settings
from app.timeutil import utcnow

router = APIRouter(tags=["bookings"])


def maps_url(lat: float, lng: float) -> str:
    return f"https://www.google.com/maps/dir/?api=1&destination={lat},{lng}"


def to_out(b: Booking, support_phone: str) -> BookingOut:
    pay = b.payment
    refund = None
    if pay is not None and pay.status in ("refund_pending", "refunded", "refund_failed"):
        refund = RefundOut(amount=pay.amount, status="refunded" if pay.status == "refunded" else "refund_pending")
    nurse_name = None
    if b.status in ("confirmed", "in_progress", "completed"):
        a = bk.active_assignment(b) or (b.assignments[-1] if b.assignments else None)
        nurse_name = bk.short_name(a.nurse.name) if a else None
    return BookingOut(
        id=b.id,
        status=b.status,
        service_id=b.service_id,
        service_name=b.service.name,
        slot_start=b.slot_start,
        slot_end=b.slot_end,
        hours=b.hours,
        amount=b.amount,
        nurse_gender_preference=b.nurse_gender_preference,
        nurse_name=nurse_name,
        patient_name=b.patient_name,
        patient_age=b.patient_age,
        patient_sex=b.patient_sex,
        contact_phone=b.contact_phone,
        address_text=b.address_text,
        address_landmark=b.address_landmark,
        latitude=b.address_lat,
        longitude=b.address_lng,
        maps_url=maps_url(b.address_lat, b.address_lng),
        hold_expires_at=b.hold_expires_at,
        cancel_reason=b.cancel_reason,
        cancelled_by=b.cancelled_by,
        payment_status=pay.status if pay else None,
        refund=refund,
        support_phone=support_phone,
        created_at=b.created_at,
    )


def raise_http(exc: BookingError) -> HTTPException:
    return HTTPException(status_code=exc.status, detail=exc.message, headers={"X-Error-Code": exc.code})


@router.post("/bookings", response_model=BookingOut, status_code=201)
async def create(body: BookingCreateIn, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    data = bk.CreateInput(
        user=user,
        service_id=body.service_id,
        start=body.slot_start,
        hours=body.hours,
        nurse_gender=body.nurse_gender,
        address_id=body.address_id,
        member_id=body.member_id,
        patient_name=body.patient_name.strip(),
        patient_age=body.patient_age,
        patient_sex=body.patient_sex,
        patient_condition=body.patient_condition,
        contact_phone=phone_or_400(body.contact_phone),
    )
    b = await bk.create_booking(db, data)
    cfg = await get_app_settings(db)
    return to_out(b, cfg.support_phone)


async def _mine(db: AsyncSession, user: User, booking_id: int) -> Booking:
    await bk.advance_lifecycle(db)
    await bk.expire_holds(db)
    await db.commit()
    b = (
        await db.execute(
            select(Booking)
            .where(Booking.id == booking_id, Booking.user_id == user.id)
            .options(selectinload(Booking.assignments), selectinload(Booking.payment))
        )
    ).scalar_one_or_none()
    if b is None:
        raise HTTPException(status_code=404, detail="Booking not found")
    return b


@router.get("/bookings", response_model=list[BookingOut])
async def list_mine(view: str = "current", user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    await bk.advance_lifecycle(db)
    await bk.expire_holds(db)
    await db.commit()
    statuses = ["confirmed", "in_progress"] if view == "current" else ["completed", "cancelled"]
    rows = (
        (
            await db.execute(
                select(Booking)
                .where(Booking.user_id == user.id, Booking.status.in_(statuses))
                .options(selectinload(Booking.assignments), selectinload(Booking.payment))
                .order_by(Booking.slot_start.asc() if view == "current" else Booking.slot_start.desc())
            )
        )
        .scalars()
        .all()
    )
    cfg = await get_app_settings(db)
    return [to_out(b, cfg.support_phone) for b in rows]


@router.get("/bookings/{booking_id}", response_model=BookingOut)
async def get_one(booking_id: int, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    b = await _mine(db, user, booking_id)
    cfg = await get_app_settings(db)
    return to_out(b, cfg.support_phone)


# --- payments ------------------------------------------------------------------
@router.post("/payments/create-order", response_model=OrderOut)
async def create_order(body: OrderIn, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    b = await _mine(db, user, body.booking_id)
    if b.status != "pending_payment" or (b.hold_expires_at and b.hold_expires_at <= utcnow()):
        raise HTTPException(
            status_code=409,
            detail="This booking is no longer waiting for payment. Please book again.",
            headers={"X-Error-Code": "hold_expired"},
        )
    gw = get_gateway()
    pay = (await db.execute(select(Payment).where(Payment.booking_id == b.id).with_for_update())).scalar_one_or_none()
    if pay is not None and pay.status != "pending":
        raise HTTPException(status_code=409, detail="This booking is already paid.")
    if pay is not None and pay.order_id and pay.gateway == gw.name:
        # Retry after a crash: hand back the same order so a payment captured on the first
        # one can still be matched to this booking.
        return OrderOut(
            gateway=gw.name,
            order_id=pay.order_id,
            amount=pay.amount,
            key_id=gw.key_id,
            booking_id=b.id,
            hold_expires_at=b.hold_expires_at,
        )
    try:
        order = await asyncio.to_thread(gw.create_order, b.id, b.amount)
    except GatewayError as exc:
        raise HTTPException(status_code=502, detail="Payment could not be started. Please try again.") from exc
    if pay is None:
        pay = Payment(booking_id=b.id, gateway=gw.name, amount=b.amount)
        db.add(pay)
    pay.order_id = order.order_id
    pay.gateway = gw.name
    await db.commit()
    return OrderOut(
        gateway=gw.name,
        order_id=order.order_id,
        amount=order.amount,
        key_id=order.key_id,
        booking_id=b.id,
        hold_expires_at=b.hold_expires_at,
    )


@router.post("/payments/verify", response_model=BookingOut)
async def verify(body: VerifyIn, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    b = await _mine(db, user, body.booking_id)
    pay = (await db.execute(select(Payment).where(Payment.booking_id == b.id))).scalar_one_or_none()
    if pay is None or pay.order_id != body.order_id:
        raise HTTPException(status_code=400, detail="Payment does not match this booking.")
    if not get_gateway().verify_signature(body.order_id, body.payment_id, body.signature):
        raise HTTPException(status_code=400, detail="Payment could not be verified.")
    try:
        updated = await bk.finalize_payment(db, b.id, body.payment_id)
    except BookingError as exc:
        raise raise_http(exc) from exc
    cfg = await get_app_settings(db)
    return to_out(updated, cfg.support_phone)


@router.post("/payments/webhook/razorpay", status_code=200)
async def razorpay_webhook(request: Request, db: AsyncSession = Depends(get_db)) -> Response:
    raw = await request.body()
    sig = request.headers.get("x-razorpay-signature", "")
    if not get_gateway().verify_webhook(raw, sig):
        raise HTTPException(status_code=400, detail="Bad signature")
    event = json.loads(raw or b"{}")
    if event.get("event") not in ("payment.captured", "order.paid"):
        return Response(status_code=200)
    entity = event.get("payload", {}).get("payment", {}).get("entity", {})
    order_id, payment_id = entity.get("order_id"), entity.get("id")
    if not order_id or not payment_id:
        return Response(status_code=200)
    pay = (await db.execute(select(Payment).where(Payment.order_id == order_id))).scalar_one_or_none()
    if pay is None:
        logging.getLogger(__name__).error(
            "Webhook for unknown order %s (payment %s): money may be unmatched", order_id, payment_id
        )
        return Response(status_code=200)
    try:
        await bk.finalize_payment(db, pay.booking_id, payment_id)
    except BookingError:
        pass
    return Response(status_code=200)


@router.post("/payments/fake/pay", response_model=FakePayOut)
async def fake_pay(body: FakePayIn, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    """Stand-in for the Razorpay sheet while no keys exist. Disabled once a real gateway is configured."""
    gw = get_gateway()
    if not isinstance(gw, FakeGateway):
        raise HTTPException(status_code=404, detail="Not found")
    await _mine(db, user, body.booking_id)
    payment_id = f"fake_pay_{body.booking_id}"
    return FakePayOut(payment_id=payment_id, signature=gw.sign(body.order_id, payment_id))

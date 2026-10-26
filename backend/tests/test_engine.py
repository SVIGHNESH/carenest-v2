"""Phase 2 test list: availability, assignment, concurrency, payments, refunds, lifecycle."""

import asyncio
from datetime import datetime, timedelta

import pytest
from sqlalchemy import select, text, update

from app.db import SessionLocal
from app.integrations.payments import FakeGateway
from app.jobs import tasks
from app.models import (
    Booking,
    BookingAssignment,
    Message,
    NurseDayOverride,
    Payment,
    User,
    VisitLink,
)
from app.services import messages
from app.timeutil import now_ist, utcnow

from .conftest import (
    booking_body,
    make_address,
    make_admin,
    make_nurse,
    make_service,
    make_user,
    pay,
    tomorrow,
)


async def setup_world(nurses=(("Anita Sharma", "female"),), services=1):
    sid = await make_service()
    for i in range(1, services):
        await make_service(name=f"S{i}")
    uid, h = await make_user()
    aid = await make_address(uid)
    nurse_ids = [await make_nurse(n, g, services=(sid,), phone=f"+91900000{i:04d}") for i, (n, g) in enumerate(nurses, 1)]
    return sid, uid, h, aid, nurse_ids


async def expire_hold(booking_id):
    async with SessionLocal() as db:
        await db.execute(update(Booking).where(Booking.id == booking_id).values(hold_expires_at=utcnow() - timedelta(minutes=1)))
        await db.commit()


async def get_booking(booking_id) -> Booking:
    async with SessionLocal() as db:
        b = (await db.execute(select(Booking).where(Booking.id == booking_id))).scalar_one()
        return b


async def active_nurse(booking_id):
    async with SessionLocal() as db:
        return (
            await db.execute(
                select(BookingAssignment.nurse_id).where(
                    BookingAssignment.booking_id == booking_id, BookingAssignment.active.is_(True)
                )
            )
        ).scalar_one_or_none()


# --- availability reads ---------------------------------------------------------------
async def test_time_grid_shows_only_on_duty_hours(client):
    sid, _, h, _, _ = await setup_world()
    day = (now_ist().date() + timedelta(days=1)).isoformat()
    r = await client.get("/bookings/time-grid", params={"service_id": sid, "date": day}, headers=h)
    hours = [s["hour"] for s in r.json()["slots"]]
    assert hours == list(range(8, 20))
    assert all(not s["too_soon"] for s in r.json()["slots"])


async def test_time_grid_marks_notice_period_and_empties_outside_window(client):
    sid, _, h, _, _ = await setup_world()
    today = now_ist().date().isoformat()
    r = await client.get("/bookings/time-grid", params={"service_id": sid, "date": today}, headers=h)
    soon = [s for s in r.json()["slots"] if s["too_soon"]]
    later = [s for s in r.json()["slots"] if not s["too_soon"]]
    earliest = now_ist() + timedelta(minutes=180)
    assert all(datetime.combine(now_ist().date(), datetime.min.time()) + timedelta(hours=s["hour"]) < earliest for s in soon)
    assert all(datetime.combine(now_ist().date(), datetime.min.time()) + timedelta(hours=s["hour"]) >= earliest for s in later)
    far = (now_ist().date() + timedelta(days=30)).isoformat()
    assert (await client.get("/bookings/time-grid", params={"service_id": sid, "date": far}, headers=h)).json()["slots"] == []


async def test_grid_duration_gender_with_mixed_hours_leave_services_and_gap(client):
    sid = await make_service()
    other = await make_service("Physio", 600)
    uid, h = await make_user()
    aid = await make_address(uid)
    f_morning = await make_nurse("Fatima Morning", "female", services=(sid,), hours=(8, 14), phone="+919000000011")
    m_all_day = await make_nurse("Mohan Day", "male", services=(sid,), hours=(8, 20), phone="+919000000012")
    await make_nurse("Priya Other", "female", services=(other,), hours=(8, 20), phone="+919000000013")  # not qualified
    day = now_ist().date() + timedelta(days=1)

    def start(hour):
        return datetime.combine(day, datetime.min.time()) + timedelta(hours=hour)

    async def md(hour):
        return (
            await client.get("/bookings/max-duration", params={"service_id": sid, "start": start(hour).isoformat()}, headers=h)
        ).json()["max_hours"]

    async def ga(hour, hours):
        return (
            await client.get(
                "/bookings/gender-availability",
                params={"service_id": sid, "start": start(hour).isoformat(), "hours": hours},
                headers=h,
            )
        ).json()

    assert await md(10) == 10  # male nurse until 20:00
    assert await ga(10, 4) == {"male": True, "female": True}
    assert await ga(12, 4) == {"male": True, "female": False}  # female nurse ends at 14:00
    assert await md(19) == 1
    # Book the male nurse 14-16: travel gap of 1 h blocks 13..17 for him
    r = await client.post("/bookings", json=booking_body(sid, aid, start(14), hours=2, gender="male"), headers=h)
    assert r.status_code == 201
    # A visit ending exactly one gap-hour before the booking may start; inside the gap is blocked
    assert await ga(12, 1) == {"male": True, "female": True}  # ends 13:00, next visit 14:00
    assert await ga(13, 1) == {"male": False, "female": True}  # inside the gap before 14:00
    assert await ga(16, 1) == {"male": False, "female": False}  # inside the gap after 16:00; female is off duty
    assert await ga(17, 1) == {"male": True, "female": False}
    # Leave for the female nurse tomorrow removes her entirely
    async with SessionLocal() as db:
        db.add(NurseDayOverride(nurse_id=f_morning, day=day, is_leave=True))
        await db.commit()
    assert await ga(9, 1) == {"male": True, "female": False}
    assert m_all_day  # silence unused
    # Unqualified nurse never counts: service "Physio" has one nurse
    g = (
        await client.get("/bookings/max-duration", params={"service_id": other, "start": start(10).isoformat()}, headers=h)
    ).json()
    assert g["max_hours"] == 10


async def test_service_with_no_qualified_nurse_is_marked_unavailable(client):
    sid = await make_service()
    r = await client.get("/services")
    assert r.json()[0]["available"] is False
    await make_nurse("Anita Sharma", "female", services=(sid,))
    assert (await client.get("/services")).json()[0]["available"] is True


async def test_nurse_without_hours_is_never_bookable(client):
    sid = await make_service()
    uid, h = await make_user()
    await make_address(uid)
    await make_nurse("No Hours", "female", services=(sid,), hours=None)
    day = (now_ist().date() + timedelta(days=1)).isoformat()
    assert (await client.get("/bookings/time-grid", params={"service_id": sid, "date": day}, headers=h)).json()["slots"] == []


# --- price / quote -------------------------------------------------------------------
async def test_quote_and_saved_amount(client):
    sid, _, h, aid, _ = await setup_world()
    q = await client.post("/bookings/quote", json={"service_id": sid, "hours": 4}, headers=h)
    assert q.json()["amount"] == 1600
    r = await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10), hours=4), headers=h)
    assert r.json()["amount"] == 1600
    async with SessionLocal() as db:
        from app.models import Service

        await db.execute(update(Service).values(base_price=999))
        await db.commit()
    assert (await client.get(f"/bookings/{r.json()['id']}", headers=h)).json()["amount"] == 1600


# --- nurse pick (D6) -----------------------------------------------------------------------
async def test_pick_prefers_fewest_booked_hours_that_day_then_lowest_id(client):
    sid, _, h, aid, (n1, n2, n3) = await setup_world(nurses=(("A One", "female"), ("B Two", "female"), ("C Three", "female")))
    r1 = await client.post("/bookings", json=booking_body(sid, aid, tomorrow(8), hours=2), headers=h)
    assert await active_nurse(r1.json()["id"]) == n1  # all tied -> lowest id
    r2 = await client.post("/bookings", json=booking_body(sid, aid, tomorrow(14), hours=2), headers=h)
    assert await active_nurse(r2.json()["id"]) == n2  # n1 has 2 h that day
    r3 = await client.post("/bookings", json=booking_body(sid, aid, tomorrow(17), hours=2), headers=h)
    assert await active_nurse(r3.json()["id"]) == n3
    r4 = await client.post("/bookings", json=booking_body(sid, aid, tomorrow(11), hours=1), headers=h)
    assert await active_nurse(r4.json()["id"]) in (n1, n2, n3)


async def test_pick_balances_by_week_when_day_ties(client):
    sid, _, h, aid, (n1, n2) = await setup_world(nurses=(("A One", "female"), ("B Two", "female")))
    day2 = tomorrow(10) + timedelta(days=1)
    # n1 gets a booking on day2 only (n2 free): force by booking day2 first -> n1 (lowest id)
    r = await client.post("/bookings", json=booking_body(sid, aid, day2, hours=3), headers=h)
    assert await active_nurse(r.json()["id"]) == n1
    # now day1: both have 0 hours that day; n1 has more this week -> n2
    r = await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10), hours=1), headers=h)
    day_a, day_b = tomorrow(10).date(), day2.date()
    if abs((day_a - day_b).days) < 7 and day_a - timedelta(days=day_a.weekday()) == day_b - timedelta(days=day_b.weekday()):
        assert await active_nurse(r.json()["id"]) == n2
    else:
        assert await active_nurse(r.json()["id"]) == n1  # different weeks: tie -> lowest id


async def test_pick_prefers_nurse_from_last_completed_visit(client):
    sid, uid, h, aid, (n1, n2) = await setup_world(nurses=(("A One", "female"), ("B Two", "female")))
    # A completed visit by n2 for this patient, in the past
    past = datetime.combine(now_ist().date() - timedelta(days=2), datetime.min.time()) + timedelta(hours=9)
    async with SessionLocal() as db:
        b = Booking(
            user_id=uid,
            service_id=sid,
            slot_start=past,
            slot_end=past + timedelta(hours=2),
            hours=2,
            amount=800,
            nurse_gender_preference="female",
            status="completed",
            patient_name="R. Sharma",
            contact_phone="+919876543210",
            address_text="x",
            address_lat=1,
            address_lng=1,
        )
        db.add(b)
        await db.flush()
        db.add(BookingAssignment(booking_id=b.id, nurse_id=n2, slot_start=past, slot_end=past + timedelta(hours=2), active=False))
        await db.commit()
    r = await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)
    assert await active_nurse(r.json()["id"]) == n2  # n1 has the lower id but n2 knows the patient


# --- concurrency ---------------------------------------------------------------------------------
async def test_two_concurrent_creates_for_last_nurse_one_wins(client):
    sid, uid, h, aid, _ = await setup_world()
    uid2, h2 = await make_user("+919876500000", "Other")
    aid2 = await make_address(uid2)
    body1 = booking_body(sid, aid, tomorrow(10))
    body2 = booking_body(sid, aid2, tomorrow(11))  # overlaps
    r1, r2 = await asyncio.gather(
        client.post("/bookings", json=body1, headers=h), client.post("/bookings", json=body2, headers=h2)
    )
    assert sorted([r1.status_code, r2.status_code]) == [201, 409]
    loser = r1 if r1.status_code == 409 else r2
    assert loser.json()["code"] == "no_nurse_free"
    async with SessionLocal() as db:
        active = (await db.execute(text("select count(*) from booking_assignments where active"))).scalar_one()
    assert active == 1


async def test_exclusion_constraint_blocks_overlap_even_without_service_checks():
    from sqlalchemy.exc import IntegrityError

    sid, uid, h, aid, (n1,) = await setup_world()
    start = tomorrow(10)
    async with SessionLocal() as db:
        for _ in range(2):
            b = Booking(
                user_id=uid,
                service_id=sid,
                slot_start=start,
                slot_end=start + timedelta(hours=2),
                hours=2,
                amount=1,
                nurse_gender_preference="female",
                contact_phone="x",
                address_text="x",
                address_lat=1,
                address_lng=1,
            )
            db.add(b)
            await db.flush()
            db.add(BookingAssignment(booking_id=b.id, nurse_id=n1, slot_start=start, slot_end=start + timedelta(hours=2)))
            if _ == 0:
                await db.flush()
        with pytest.raises(IntegrityError):
            await db.flush()


async def test_booking_after_expired_unpaid_hold_succeeds_before_job_runs(client):
    sid, _, h, aid, (n1,) = await setup_world()
    r1 = await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)
    assert r1.status_code == 201
    uid2, h2 = await make_user("+919876500001", "Other")
    aid2 = await make_address(uid2)
    # blocked while the hold is live
    assert (await client.post("/bookings", json=booking_body(sid, aid2, tomorrow(10)), headers=h2)).status_code == 409
    await expire_hold(r1.json()["id"])  # expired, expire job has NOT run
    r2 = await client.post("/bookings", json=booking_body(sid, aid2, tomorrow(10)), headers=h2)
    assert r2.status_code == 201
    assert (await get_booking(r1.json()["id"])).status == "expired"


# --- rules: notice, window, paused, midnight ----------------------------------------------------------
def test_validate_slot_unit_rules():
    from app.models import AppSettings
    from app.services.booking import validate_slot
    from app.services.errors import BookingError

    cfg = AppSettings(min_notice_minutes=180, booking_window_days=7)
    now = datetime(2026, 10, 27, 9, 30)

    def code(start, hours=2):
        try:
            validate_slot(start, hours, cfg, now=now)
        except BookingError as e:
            return e.code
        return "ok"

    assert code(datetime(2026, 10, 27, 12, 0)) == "too_soon"  # 2.5 h away
    assert code(datetime(2026, 10, 27, 13, 0)) == "ok"  # 3.5 h away
    assert code(datetime(2026, 10, 27, 12, 30)) == "bad_slot"  # not on the hour
    assert code(datetime(2026, 11, 3, 10, 0)) == "ok"  # last allowed day (today + 7)
    assert code(datetime(2026, 11, 4, 10, 0)) == "too_far"
    assert code(datetime(2026, 10, 28, 23, 0), hours=2) == "crosses_midnight"
    assert code(datetime(2026, 10, 28, 22, 0), hours=2) == "ok"
    assert code(datetime(2026, 10, 28, 10, 0), hours=13) == "bad_hours"
    assert code(datetime(2026, 10, 28, 10, 0), hours=0) == "bad_hours"


async def test_window_paused_and_midnight_over_api(client):
    sid, _, h, aid, _ = await setup_world()
    far = tomorrow(10) + timedelta(days=9)
    assert (await client.post("/bookings", json=booking_body(sid, aid, far), headers=h)).json()["code"] == "too_far"
    assert (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(23), hours=2), headers=h)).json()[
        "code"
    ] == "crosses_midnight"
    _, ah = await make_admin()
    assert (await client.patch("/admin/settings", json={"bookings_paused": True}, headers=ah)).status_code == 200
    r = await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)
    assert r.status_code == 409 and r.json()["code"] == "paused"
    assert (await client.get("/settings/booking")).json()["bookings_paused"] is True


# --- payment finalisation ---------------------------------------------------------------------------------
async def start_payment(client, h, booking_id):
    order = (await client.post("/payments/create-order", json={"booking_id": booking_id}, headers=h)).json()
    fake = (
        await client.post("/payments/fake/pay", json={"booking_id": booking_id, "order_id": order["order_id"]}, headers=h)
    ).json()
    return {
        "booking_id": booking_id,
        "order_id": order["order_id"],
        "payment_id": fake["payment_id"],
        "signature": fake["signature"],
    }


async def test_happy_path_confirm_sends_messages_and_visit_link(client, sms, email):
    sid, _, h, aid, (n1,) = await setup_world()
    b = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)).json()
    assert b["status"] == "pending_payment" and b["nurse_name"] is None
    r = await pay(client, h, b["id"])
    assert r.status_code == 200 and r.json()["status"] == "confirmed" and r.json()["nurse_name"] == "Anita S."
    async with SessionLocal() as db:
        await messages.process_queue(db)
    templates = sorted(t for _, t, _ in sms.sent)
    assert templates == ["booking_confirmed", "visit_new"]
    nurse_sms = next(v for p, t, v in sms.sent if t == "visit_new")
    assert nurse_sms["link"].startswith("http://localhost:8000/v?k=")
    assert "address" not in " ".join(nurse_sms.values()).lower()  # details live behind the link only
    user_sms = next((p, v) for p, t, v in sms.sent if t == "booking_confirmed")
    assert user_sms[0] == "+919876543210"
    assert any("Booking #1 confirmed" in s for _, s, _ in email.sent)


async def test_create_order_refuses_expired_booking(client):
    sid, _, h, aid, _ = await setup_world()
    b = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)).json()
    await expire_hold(b["id"])
    r = await client.post("/payments/create-order", json={"booking_id": b["id"]}, headers=h)
    assert r.status_code == 409


async def test_bad_signature_rejected(client):
    sid, _, h, aid, _ = await setup_world()
    b = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)).json()
    p = await start_payment(client, h, b["id"])
    p["signature"] = "0" * 64
    assert (await client.post("/payments/verify", json=p, headers=h)).status_code == 400
    assert (await get_booking(b["id"])).status == "pending_payment"


async def test_pay_after_hold_expiry_keeps_same_nurse_when_still_free(client):
    sid, _, h, aid, (n1, n2) = await setup_world(nurses=(("A One", "female"), ("B Two", "female")))
    b = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)).json()
    p = await start_payment(client, h, b["id"])
    await expire_hold(b["id"])
    r = await client.post("/payments/verify", json=p, headers=h)
    assert r.json()["status"] == "confirmed"
    assert await active_nurse(b["id"]) == n1


async def test_pay_after_hold_expiry_reassigns_when_nurse_taken(client):
    sid, _, h, aid, (n1, n2) = await setup_world(nurses=(("A One", "female"), ("B Two", "female")))
    a = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)).json()
    assert await active_nurse(a["id"]) == n1
    p = await start_payment(client, h, a["id"])
    await expire_hold(a["id"])
    uid2, h2 = await make_user("+919876500002", "Other")
    aid2 = await make_address(uid2)
    b = (await client.post("/bookings", json=booking_body(sid, aid2, tomorrow(10)), headers=h2)).json()
    assert await active_nurse(b["id"]) == n1  # took the expired slot
    r = await client.post("/payments/verify", json=p, headers=h)
    assert r.json()["status"] == "confirmed"
    assert await active_nurse(a["id"]) == n2


async def test_pay_after_hold_expiry_no_nurse_cancels_and_refunds(client, sms):
    sid, _, h, aid, (n1,) = await setup_world()
    a = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)).json()
    p = await start_payment(client, h, a["id"])
    await expire_hold(a["id"])
    uid2, h2 = await make_user("+919876500003", "Other")
    aid2 = await make_address(uid2)
    assert (await client.post("/bookings", json=booking_body(sid, aid2, tomorrow(10)), headers=h2)).status_code == 201
    r = await client.post("/payments/verify", json=p, headers=h)
    body = r.json()
    assert body["status"] == "cancelled" and body["cancelled_by"] == "system"
    assert body["refund"]["status"] == "refunded"
    async with SessionLocal() as db:
        pay_row = (await db.execute(select(Payment).where(Payment.booking_id == a["id"]))).scalar_one()
        assert pay_row.status == "refunded" and pay_row.refund_id
        await messages.process_queue(db)
    cancelled = [v for _, t, v in sms.sent if t == "booking_cancelled"]
    assert cancelled and cancelled[0]["reason"] == "no nurse free at that time"
    _, ah = await make_admin()
    dash = (await client.get("/admin/dashboard", headers=ah)).json()
    assert any(i["kind"] == "system_cancel" for i in dash["attention"])


async def test_pay_after_expiry_job_already_ran(client):
    sid, _, h, aid, (n1,) = await setup_world()
    b = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)).json()
    p = await start_payment(client, h, b["id"])
    await expire_hold(b["id"])
    await tasks.job_expire_holds()
    assert (await get_booking(b["id"])).status == "expired"
    r = await client.post("/payments/verify", json=p, headers=h)
    assert r.json()["status"] == "confirmed"
    assert await active_nurse(b["id"]) == n1


async def test_expiry_job_never_touches_paid_booking(client):
    sid, _, h, aid, _ = await setup_world()
    b = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)).json()
    await pay(client, h, b["id"])
    # Simulate a stale hold timestamp on a paid, pending booking row (webhook raced the status)
    async with SessionLocal() as db:
        await db.execute(
            update(Booking)
            .where(Booking.id == b["id"])
            .values(status="pending_payment", hold_expires_at=utcnow() - timedelta(minutes=5))
        )
        await db.commit()
    await tasks.job_expire_holds()
    assert (await get_booking(b["id"])).status == "pending_payment"


async def test_verify_and_webhook_both_arrive_one_finalize_no_double_refund(client, sms):
    import hashlib
    import hmac
    import json

    sid, _, h, aid, _ = await setup_world()
    b = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)).json()
    p = await start_payment(client, h, b["id"])
    payload = json.dumps(
        {"event": "payment.captured", "payload": {"payment": {"entity": {"id": p["payment_id"], "order_id": p["order_id"]}}}}
    ).encode()
    sig = hmac.new(b"fake-gateway-secret", payload, hashlib.sha256).hexdigest()

    async def webhook():
        return await client.post("/payments/webhook/razorpay", content=payload, headers={"x-razorpay-signature": sig})

    r_verify, r_hook = await asyncio.gather(client.post("/payments/verify", json=p, headers=h), webhook())
    assert r_verify.status_code == 200 and r_hook.status_code == 200
    assert (await get_booking(b["id"])).status == "confirmed"
    async with SessionLocal() as db:
        rows = (await db.execute(select(Message))).scalars().all()
        print([(m.template, m.recipient, m.channel) for m in rows])
        assert len([m for m in rows if m.template == "booking_confirmed"]) == 1
        assert (await db.execute(select(VisitLink))).scalars().all().__len__() == 1
    assert (
        await client.post("/payments/webhook/razorpay", content=payload, headers={"x-razorpay-signature": "bad"})
    ).status_code == 400
    # cancel then deliver the webhook again: no second refund
    _, ah = await make_admin()
    await client.post(f"/admin/bookings/{b['id']}/cancel", json={"reason": "test"}, headers=ah)
    await webhook()
    async with SessionLocal() as db:
        pay_row = (await db.execute(select(Payment).where(Payment.booking_id == b["id"]))).scalar_one()
        assert pay_row.status == "refunded"


# --- kill switch -------------------------------------------------------------------------------------------------------
async def test_kill_switch_confirmed_refunds_and_notifies(client, sms):
    sid, _, h, aid, (n1,) = await setup_world()
    b = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10), hours=3), headers=h)).json()
    await pay(client, h, b["id"])
    _, ah = await make_admin()
    assert (await client.post(f"/admin/bookings/{b['id']}/cancel", json={"reason": " "}, headers=ah)).status_code == 400
    r = await client.post(f"/admin/bookings/{b['id']}/cancel", json={"reason": "nurse unwell"}, headers=ah)
    assert r.status_code == 200 and r.json()["status"] == "cancelled" and r.json()["payment"]["status"] == "refunded"
    assert await active_nurse(b["id"]) is None
    async with SessionLocal() as db:
        await messages.process_queue(db)
        link = (await db.execute(select(VisitLink))).scalar_one()
        assert link.revoked_at is not None
    sent = {t: v for _, t, v in sms.sent}
    assert sent["booking_cancelled"]["amount"] == "1200" and sent["booking_cancelled"]["reason"] == "nurse unwell"
    assert "visit_cancelled" in sent
    # the slot is free again
    assert (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)).status_code == 201
    # cannot cancel twice
    assert (await client.post(f"/admin/bookings/{b['id']}/cancel", json={"reason": "again"}, headers=ah)).status_code == 409
    user = (await client.get(f"/bookings/{b['id']}", headers=h)).json()
    assert user["cancel_reason"] == "nurse unwell" and user["refund"]["status"] == "refunded"


async def test_kill_switch_on_in_progress_visit(client):
    sid, _, h, aid, _ = await setup_world()
    b = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)).json()
    await pay(client, h, b["id"])
    async with SessionLocal() as db:
        await db.execute(update(Booking).where(Booking.id == b["id"]).values(status="in_progress"))
        await db.commit()
    _, ah = await make_admin()
    r = await client.post(f"/admin/bookings/{b['id']}/cancel", json={"reason": "emergency"}, headers=ah)
    assert r.json()["status"] == "cancelled" and r.json()["payment"]["status"] == "refunded"


async def test_refund_failure_marks_needs_attention_and_scheduler_retries(client):
    sid, _, h, aid, _ = await setup_world()
    b = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)).json()
    await pay(client, h, b["id"])
    _, ah = await make_admin()
    FakeGateway.fail_refunds = True
    r = await client.post(f"/admin/bookings/{b['id']}/cancel", json={"reason": "x"}, headers=ah)
    assert r.json()["status"] == "cancelled" and r.json()["payment"]["status"] == "refund_failed"
    dash = (await client.get("/admin/dashboard", headers=ah)).json()
    assert any(i["kind"] == "refund_failed" and i["booking_id"] == b["id"] for i in dash["attention"])
    FakeGateway.fail_refunds = False
    await tasks.job_refunds()
    detail = (await client.get(f"/admin/bookings/{b['id']}", headers=ah)).json()
    assert detail["payment"]["status"] == "refunded"
    async with SessionLocal() as db:
        assert (await db.execute(select(Payment))).scalar_one().refund_id.startswith("fake_refund")


async def test_cancel_unpaid_booking_has_no_refund(client):
    sid, _, h, aid, _ = await setup_world()
    b = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)).json()
    _, ah = await make_admin()
    r = await client.post(f"/admin/bookings/{b['id']}/cancel", json={"reason": "x"}, headers=ah)
    assert r.json()["status"] == "cancelled" and r.json()["payment"] is None


# --- reassign ------------------------------------------------------------------------------------------------
async def test_reassign_moves_visit_link_and_notifies(client, sms):
    sid, _, h, aid, (n1, n2) = await setup_world(nurses=(("A One", "female"), ("B Two", "female")))
    b = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)).json()
    await pay(client, h, b["id"])
    _, ah = await make_admin()
    cands = (await client.get(f"/admin/bookings/{b['id']}/reassign-candidates", headers=ah)).json()
    assert [c["id"] for c in cands] == [n2] and cands[0]["free"]
    assert (await client.post(f"/admin/bookings/{b['id']}/reassign", json={"nurse_id": n1}, headers=ah)).status_code == 409
    r = await client.post(f"/admin/bookings/{b['id']}/reassign", json={"nurse_id": n2}, headers=ah)
    assert r.status_code == 200 and r.json()["nurse"]["id"] == n2
    async with SessionLocal() as db:
        await messages.process_queue(db)
        links = (await db.execute(select(VisitLink).order_by(VisitLink.token))).scalars().all()
        assert sum(1 for link in links if link.revoked_at is None) == 1
    templates = [t for _, t, _ in sms.sent]
    assert "visit_removed" in templates and "nurse_changed" in templates and templates.count("visit_new") == 2


# --- lifecycle ---------------------------------------------------------------------------------------------
async def test_scheduler_moves_visits_through_states(client):
    sid, _, h, aid, _ = await setup_world()
    ids = []
    for i in range(3):
        b = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(8 + 4 * i), hours=2), headers=h)).json()
        await pay(client, h, b["id"])
        ids.append(b["id"])
    now = now_ist()
    async with SessionLocal() as db:
        # 0: started an hour ago, ends in an hour -> in_progress ; 1: ended -> completed ; 2: future -> confirmed
        await db.execute(
            update(Booking)
            .where(Booking.id == ids[0])
            .values(slot_start=now - timedelta(hours=1), slot_end=now + timedelta(hours=1))
        )
        await db.execute(
            update(Booking)
            .where(Booking.id == ids[1])
            .values(slot_start=now - timedelta(hours=5), slot_end=now - timedelta(hours=3))
        )
        await db.commit()
    await tasks.job_lifecycle()
    assert [(await get_booking(i)).status for i in ids] == ["in_progress", "completed", "confirmed"]
    assert await active_nurse(ids[1]) is None  # completed visit releases the nurse
    # user list endpoints also bring state up to date (update-on-read)
    cur = (await client.get("/bookings?view=current", headers=h)).json()
    assert {b["id"] for b in cur} == {ids[0], ids[2]}
    hist = (await client.get("/bookings?view=history", headers=h)).json()
    assert [b["id"] for b in hist] == [ids[1]]


async def test_visit_page_open_tracking_revocation_and_expiry(client):
    sid, _, h, aid, (n1, n2) = await setup_world(nurses=(("A One", "female"), ("B Two", "female")))
    b = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)).json()
    await pay(client, h, b["id"])
    async with SessionLocal() as db:
        token = (await db.execute(select(VisitLink.token))).scalar_one()
    page = await client.get("/v", params={"k": token})
    assert page.status_code == 200 and "R. Sharma" in page.text and "tel:+919876543210" in page.text and "Directions" in page.text
    assert "no-store" in page.headers["cache-control"]
    async with SessionLocal() as db:
        assert (await db.execute(select(VisitLink.first_opened_at))).scalar_one() is not None
    _, ah = await make_admin()
    assert (await client.get(f"/admin/bookings/{b['id']}", headers=ah)).json()["visit_link_opened_at"] is not None
    await client.post(f"/admin/bookings/{b['id']}/reassign", json={"nurse_id": n2}, headers=ah)
    assert "No longer assigned" in (await client.get("/v", params={"k": token})).text
    assert "Link not found" in (await client.get("/v", params={"k": "nope"})).text
    async with SessionLocal() as db:
        new_token = (await db.execute(select(VisitLink.token).where(VisitLink.revoked_at.is_(None)))).scalar_one()
        await db.execute(update(VisitLink).where(VisitLink.token == new_token).values(expires_at=utcnow() - timedelta(minutes=1)))
        await db.commit()
    assert "expired" in (await client.get("/v", params={"k": new_token})).text.lower()


# --- nurse unavailable ----------------------------------------------------------------------------------------
async def test_nurse_unavailable_preview_then_apply(client):
    sid, _, h, aid, (n1, n2) = await setup_world(nurses=(("A One", "female"), ("B Two", "female")))
    b1 = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(9), hours=2), headers=h)).json()
    b2 = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(9), hours=2), headers=h)).json()
    for b in (b1, b2):
        await pay(client, h, b["id"])
    assert {await active_nurse(b1["id"]), await active_nurse(b2["id"])} == {n1, n2}
    _, ah = await make_admin()
    day = tomorrow(9).date().isoformat()
    prev = (await client.post(f"/admin/nurses/{n1}/unavailable", json={"from_day": day, "to_day": day}, headers=ah)).json()
    assert prev["applied"] is False and [i["outcome"] for i in prev["items"]] == ["cancel"]  # n2 is busy with the other visit
    assert (await get_booking(b1["id"])).status == "confirmed"  # preview changed nothing
    async with SessionLocal() as db:
        assert (await db.execute(select(NurseDayOverride))).scalars().all() == []
    applied = (
        await client.post(f"/admin/nurses/{n1}/unavailable", json={"from_day": day, "to_day": day, "apply": True}, headers=ah)
    ).json()
    assert applied["applied"] is True
    mine = b1 if await active_nurse(b1["id"]) is None else b2
    assert (await get_booking(mine["id"])).status == "cancelled"
    async with SessionLocal() as db:
        assert (await db.execute(select(NurseDayOverride.is_leave))).scalar_one() is True


# --- messages ------------------------------------------------------------------------------------------------------------
async def test_failed_nurse_message_retries_then_needs_attention(client, sms):
    sid, _, h, aid, _ = await setup_world()
    b = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)).json()
    sms.fail = True
    await pay(client, h, b["id"])
    for _ in range(messages.MAX_ATTEMPTS):
        async with SessionLocal() as db:
            await db.execute(
                update(Message).where(Message.status == "queued").values(next_attempt_at=utcnow() - timedelta(seconds=1))
            )
            await db.commit()
            await messages.process_queue(db)
    _, ah = await make_admin()
    dash = (await client.get("/admin/dashboard", headers=ah)).json()
    failed = [i for i in dash["attention"] if i["kind"] == "message_failed"]
    assert failed
    sms.fail = False
    r = await client.post(f"/admin/messages/{failed[0]['message_id']}/resend", headers=ah)
    assert r.json()["status"] == "sent"


def test_clean_value_follows_dlt_rules():
    assert messages.clean_value("a  b   c") == "a b c"
    assert len(messages.clean_value("x" * 80)) == 40
    assert not messages.clean_value("http://evil").lower().startswith("http")
    assert User  # imported for factories

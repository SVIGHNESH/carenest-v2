from datetime import timedelta

import pyotp
from sqlalchemy import func, select, update

from app.db import SessionLocal
from app.models import OTP, AdminResetToken, Booking, FamilyMember, Message, Payment, User
from app.timeutil import utcnow

from .conftest import booking_body, make_address, make_admin, make_nurse, make_service, make_user, pay, tomorrow


async def login_phone(client, sms, phone="9876543210"):
    assert (await client.post("/auth/phone/send-otp", json={"phone": phone})).status_code == 204
    code = sms.otps["+91" + phone]
    return await client.post("/auth/phone/verify-otp", json={"phone": phone, "code": code})


async def test_new_user_signup_flow(client, sms):
    r = await login_phone(client, sms)
    body = r.json()
    assert body["needs_signup"] is True and body["token"] is None
    r2 = await client.post("/auth/phone/complete-signup", json={"signup_ticket": body["signup_ticket"], "name": "Riya Sharma"})
    assert r2.status_code == 200 and r2.json()["user"]["phone"] == "+919876543210"
    token = r2.json()["access_token"]
    me = await client.get("/users/me", headers={"Authorization": f"Bearer {token}"})
    assert me.json()["name"] == "Riya Sharma"
    # Existing user: straight to a token, one flow for login and signup
    sms.otps.clear()
    async with SessionLocal() as db:
        await db.execute(update(OTP).values(created_at=utcnow() - timedelta(minutes=5)))
        await db.commit()
    again = (await login_phone(client, sms)).json()
    assert again["needs_signup"] is False and again["token"]["user"]["name"] == "Riya Sharma"


async def test_wrong_code_attempt_limit_and_cooldown(client, sms):
    await client.post("/auth/phone/send-otp", json={"phone": "9876543210"})
    for _ in range(5):
        assert (await client.post("/auth/phone/verify-otp", json={"phone": "9876543210", "code": "000000"})).status_code == 400
    assert (await client.post("/auth/phone/verify-otp", json={"phone": "9876543210", "code": "000000"})).status_code == 429
    again = await client.post("/auth/phone/send-otp", json={"phone": "9876543210"})
    assert again.status_code == 429  # 60 s cooldown
    assert (await client.post("/auth/phone/send-otp", json={"phone": "12345"})).status_code == 400


async def test_sms_failure_does_not_burn_cooldown(client, sms, monkeypatch):
    from app.integrations.sms import SmsError

    async def boom(*a, **k):
        raise SmsError("down")

    monkeypatch.setattr(sms, "send_otp", boom)
    assert (await client.post("/auth/phone/send-otp", json={"phone": "9876543210"})).status_code == 502
    async with SessionLocal() as db:
        assert (await db.execute(select(func.count()).select_from(OTP))).scalar_one() == 0
        assert (await db.execute(select(Message.status))).scalar_one() == "failed"


async def test_profile_family_and_address_rules(client):
    uid, h = await make_user()
    r = await client.post(
        "/family",
        json={"name": "S. Sharma", "age": 64, "sex": "female", "relation": "Mother", "contact_phone": "98765 00000"},
        headers=h,
    )
    assert r.status_code == 201 and r.json()["contact_phone"] == "+919876500000"
    bad = await client.post("/addresses", json={"label": "Home", "house": "1"}, headers=h)
    assert bad.status_code == 422  # a map pin is required
    a1 = await client.post("/addresses", json={"label": "Home", "house": "1", "latitude": 28.3, "longitude": 79.4}, headers=h)
    a2 = await client.post(
        "/addresses", json={"label": "Work", "house": "2", "latitude": 28.4, "longitude": 79.5, "is_default": True}, headers=h
    )
    assert a1.json()["is_default"] is True  # the first address becomes the default
    listing = (await client.get("/addresses", headers=h)).json()
    assert [a["label"] for a in listing] == ["Work", "Home"] and listing[0]["is_default"]
    other_uid, other_h = await make_user("+919876500009", "Other")
    assert (await client.delete(f"/addresses/{a2.json()['id']}", headers=other_h)).status_code == 404
    assert other_uid


async def test_account_deletion_anonymizes_but_keeps_payments(client, sms):
    sid = await make_service()
    await make_nurse("Anita Sharma", "female", services=(sid,))
    uid, h = await make_user()
    aid = await make_address(uid)
    await client.post("/family", json={"name": "S", "age": 60, "sex": "female", "relation": "Mother"}, headers=h)
    b = (await client.post("/bookings", json=booking_body(sid, aid, tomorrow(10)), headers=h)).json()
    await pay(client, h, b["id"])
    # needs OTP
    assert (await client.request("DELETE", "/users/me", json={"code": "123456"}, headers=h)).status_code == 400
    await client.post("/users/me/delete-otp", headers=h)
    code = sms.otps["+919876543210"]
    # upcoming booking blocks deletion
    r = await client.request("DELETE", "/users/me", json={"code": code}, headers=h)
    assert r.status_code == 409 and "call support" in r.json()["detail"].lower()
    _, ah = await make_admin()
    await client.post(f"/admin/bookings/{b['id']}/cancel", json={"reason": "test"}, headers=ah)
    r = await client.request("DELETE", "/users/me", json={"code": code}, headers=h)
    assert r.status_code == 204
    async with SessionLocal() as db:
        u = (await db.execute(select(User).where(User.id == uid))).scalar_one()
        assert u.phone is None and u.email is None and u.deleted_at is not None and u.name == "Deleted user"
        bk = (await db.execute(select(Booking).where(Booking.id == b["id"]))).scalar_one()
        assert bk.patient_name == "" and bk.contact_phone == "" and bk.address_text == "" and bk.amount == 400 * 2
        assert (await db.execute(select(func.count()).select_from(Payment))).scalar_one() == 1
        assert (await db.execute(select(func.count()).select_from(FamilyMember))).scalar_one() == 0
    assert (await client.get("/users/me", headers=h)).status_code == 401
    # the number can sign up again as a new account
    async with SessionLocal() as db:
        await db.execute(update(OTP).values(created_at=utcnow() - timedelta(minutes=5)))
        await db.commit()
    again = (await login_phone(client, sms)).json()
    assert again["needs_signup"] is True


# --- admin auth -------------------------------------------------------------------------
async def create_admin_row(email="boss@example.com", password="a-long-password"):
    from app.security import hash_password

    async with SessionLocal() as db:
        u = User(name="Boss", email=email, role="admin", password_hash=hash_password(password))
        db.add(u)
        await db.commit()
        return u.id


async def test_admin_login_requires_totp_setup_then_code(client):
    await create_admin_row()
    r = await client.post("/admin/auth/login", json={"email": "BOSS@example.com", "password": "a-long-password"})
    assert r.json()["step"] == "setup"
    ticket = r.json()["ticket"]
    # cannot use the ticket as a bearer token
    assert (await client.get("/admin/me", headers={"Authorization": f"Bearer {ticket}"})).status_code == 401
    setup = (await client.post("/admin/auth/totp/setup", json={"ticket": ticket})).json()
    assert setup["otpauth_uri"].startswith("otpauth://totp/")
    wrong = await client.post("/admin/auth/totp/verify", json={"ticket": ticket, "code": "000000"})
    assert wrong.status_code == 401
    code = pyotp.TOTP(setup["secret"]).now()
    done = (await client.post("/admin/auth/totp/verify", json={"ticket": ticket, "code": code})).json()
    assert len(done["backup_codes"]) == 8
    ok = await client.get("/admin/me", headers={"Authorization": f"Bearer {done['access_token']}"})
    assert ok.json()["email"] == "boss@example.com"
    # next login asks for a code; a backup code works once
    nxt = (await client.post("/admin/auth/login", json={"email": "boss@example.com", "password": "a-long-password"})).json()
    assert nxt["step"] == "mfa"
    bc = done["backup_codes"][0]
    assert (await client.post("/admin/auth/mfa", json={"ticket": nxt["ticket"], "code": bc})).status_code == 200
    assert (await client.post("/admin/auth/mfa", json={"ticket": nxt["ticket"], "code": bc})).status_code == 401
    # a user token is not an admin token
    _, uh = await make_user()
    assert (await client.get("/admin/me", headers=uh)).status_code == 401


async def test_admin_lockout_after_five_bad_passwords(client):
    await create_admin_row()
    for _ in range(5):
        assert (
            await client.post("/admin/auth/login", json={"email": "boss@example.com", "password": "nope-nope-nope"})
        ).status_code == 401
    locked = await client.post("/admin/auth/login", json={"email": "boss@example.com", "password": "a-long-password"})
    assert locked.status_code == 429
    async with SessionLocal() as db:
        await db.execute(update(User).values(locked_until=utcnow() - timedelta(minutes=1)))
        await db.commit()
    assert (
        await client.post("/admin/auth/login", json={"email": "boss@example.com", "password": "a-long-password"})
    ).status_code == 200
    assert (await client.post("/admin/auth/login", json={"email": "ghost@example.com", "password": "x"})).status_code == 401


async def test_admin_password_reset_and_team(client, email):
    _, h = await make_admin()
    r = await client.post("/admin/team", json={"name": "Second Admin", "email": "second@example.com"}, headers=h)
    assert r.status_code == 201
    assert (await client.post("/admin/team", json={"name": "Dup", "email": "SECOND@example.com"}, headers=h)).status_code == 409
    async with SessionLocal() as db:
        from app.services import messages

        await messages.process_queue(db)
    invite = next(html for to, subj, html in email.sent if to == "second@example.com")
    token = invite.split("token=")[1].split('"')[0]
    short = await client.post("/admin/auth/reset-password", json={"token": token, "password": "short"})
    assert short.status_code == 422  # min 10 chars
    ok = await client.post("/admin/auth/reset-password", json={"token": token, "password": "a-brand-new-password"})
    assert ok.status_code == 204
    assert (
        await client.post("/admin/auth/reset-password", json={"token": token, "password": "another-new-password"})
    ).status_code == 400
    login = await client.post("/admin/auth/login", json={"email": "second@example.com", "password": "a-brand-new-password"})
    assert login.status_code == 200
    # unknown email gets the same answer, and no mail
    before = len(email.sent)
    assert (await client.post("/admin/auth/forgot-password", json={"email": "nobody@example.com"})).status_code == 204
    assert len(email.sent) == before
    async with SessionLocal() as db:
        assert (await db.execute(select(func.count()).select_from(AdminResetToken))).scalar_one() == 1
    # deactivated admins cannot use an old token
    team = (await client.get("/admin/team", headers=h)).json()
    second = next(a for a in team if a["email"] == "second@example.com")
    assert (await client.post(f"/admin/team/{second['id']}/deactivate", headers=h)).json()["is_active"] is False
    assert (
        await client.post("/admin/auth/login", json={"email": "second@example.com", "password": "a-brand-new-password"})
    ).status_code == 401


async def test_admin_nurse_crud_requires_gender_and_services(client):
    sid = await make_service()
    _, h = await make_admin()
    base = {"name": "Kavita Rao", "phone": "98000 00001", "gender": "female", "service_ids": [sid]}
    assert (await client.post("/admin/nurses", json={**base, "gender": "x"}, headers=h)).status_code == 422
    assert (await client.post("/admin/nurses", json={**base, "service_ids": []}, headers=h)).status_code == 422
    r = await client.post("/admin/nurses", json=base, headers=h)
    assert r.status_code == 201 and r.json()["phone"] == "+919800000001"
    assert r.json()["setup_issues"] == ["No working hours: not bookable"]
    nid = r.json()["id"]
    hours = [{"weekday": d, "start_hour": 8, "end_hour": 20} for d in range(6)]
    assert (await client.put(f"/admin/nurses/{nid}/weekly-hours", json=hours, headers=h)).json()["setup_issues"] == []
    assert (
        await client.put(f"/admin/nurses/{nid}/weekly-hours", json=[{"weekday": 1, "start_hour": 9, "end_hour": 9}], headers=h)
    ).status_code == 422
    ov = await client.put(f"/admin/nurses/{nid}/overrides/2030-01-05", json={"is_leave": True, "note": "wedding"}, headers=h)
    assert ov.json()["is_leave"] is True
    assert len((await client.get(f"/admin/nurses/{nid}/overrides?month=2030-01", headers=h)).json()) == 1
    assert (await client.delete(f"/admin/nurses/{nid}/overrides/2030-01-05", headers=h)).status_code == 204
    # public routes need no admin, admin routes need one
    assert (await client.get("/admin/nurses")).status_code == 401
    log = (await client.get("/admin/activity", headers=h)).json()
    assert any(e["action"] == "nurse_created" for e in log)

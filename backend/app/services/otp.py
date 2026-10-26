"""Issuing and checking one-time codes. Routers decide what a verified code means."""

import hmac
import secrets
from datetime import timedelta

from fastapi import HTTPException, Request
from sqlalchemy import delete, func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.integrations.sms import SmsError, get_sms
from app.models import OTP
from app.security import hash_code
from app.services import messages
from app.timeutil import utcnow

OTP_TTL = timedelta(minutes=10)
RESEND_COOLDOWN = timedelta(seconds=60)
SEND_WINDOW = timedelta(minutes=10)
MAX_SENDS_PER_TARGET = 5
# Looser than the per-target limit: mobile carriers put many customers behind one address.
MAX_SENDS_PER_IP = 20
MAX_ATTEMPTS = 5
_RETENTION = timedelta(days=1)

PURPOSE_LOGIN = "login"
PURPOSE_DELETE = "delete_account"


def client_ip(request: Request) -> str | None:
    return request.client.host if request.client else None


def _too_many(detail: str, retry_after: timedelta) -> HTTPException:
    seconds = max(1, int(retry_after.total_seconds()))
    return HTTPException(status_code=429, detail=detail, headers={"Retry-After": str(seconds)})


async def issue_otp(db: AsyncSession, *, phone: str, purpose: str, request_ip: str | None) -> None:
    now = utcnow()
    await db.execute(text("SELECT pg_advisory_xact_lock(hashtext(:key))"), {"key": f"otp:{phone}"})

    window_start = now - SEND_WINDOW
    recent = list(
        (
            await db.execute(
                select(OTP.created_at).where(OTP.target == phone, OTP.created_at > window_start).order_by(OTP.created_at.desc())
            )
        )
        .scalars()
        .all()
    )
    if recent and now - recent[0] < RESEND_COOLDOWN:
        raise _too_many("Please wait a minute before requesting another code.", RESEND_COOLDOWN - (now - recent[0]))
    if len(recent) >= MAX_SENDS_PER_TARGET:
        raise _too_many("Too many codes requested. Try again in a few minutes.", recent[-1] + SEND_WINDOW - now)

    if request_ip is not None:
        ip_count, ip_oldest = (
            await db.execute(
                select(func.count(), func.min(OTP.created_at)).where(OTP.request_ip == request_ip, OTP.created_at > window_start)
            )
        ).one()
        if ip_count >= MAX_SENDS_PER_IP:
            raise _too_many("Too many codes requested. Try again in a few minutes.", ip_oldest + SEND_WINDOW - now)

    await db.execute(delete(OTP).where(OTP.created_at < now - _RETENTION))

    code = f"{secrets.randbelow(10**6):06d}"
    otp = OTP(
        channel="phone",
        target=phone,
        purpose=purpose,
        code_hash=hash_code(phone, code),
        request_ip=request_ip,
        created_at=now,
        expires_at=now + OTP_TTL,
    )
    db.add(otp)
    await db.commit()

    try:
        await get_sms().send_otp(phone, code, int(OTP_TTL.total_seconds() // 60))
        await messages.log_otp_message(db, phone=phone, ok=True)
        await db.commit()
    except SmsError as exc:
        await db.delete(otp)  # nothing reached the user, so no cooldown for them
        await messages.log_otp_message(db, phone=phone, ok=False, error=str(exc)[:300])
        await db.commit()
        raise HTTPException(status_code=502, detail="Could not send the code. Please try again.") from exc


async def consume_otp(db: AsyncSession, *, phone: str, purpose: str, code: str) -> None:
    """Accept `code` or raise. Marked used but not committed: the caller commits it with its effect."""
    otp = (
        await db.execute(
            select(OTP)
            .where(OTP.target == phone, OTP.purpose == purpose, OTP.consumed_at.is_(None))
            .order_by(OTP.created_at.desc())
            .limit(1)
            .with_for_update()
        )
    ).scalar_one_or_none()

    if otp is None:
        raise HTTPException(status_code=400, detail="No code was requested. Request a new one.")
    if otp.attempts >= MAX_ATTEMPTS:
        raise HTTPException(status_code=429, detail="Too many wrong attempts. Request a new code.")
    if utcnow() > otp.expires_at:
        raise HTTPException(status_code=400, detail="This code has expired. Request a new one.")
    if not hmac.compare_digest(otp.code_hash, hash_code(phone, code)):
        otp.attempts += 1
        await db.commit()
        raise HTTPException(status_code=400, detail="Incorrect code.")
    otp.consumed_at = utcnow()

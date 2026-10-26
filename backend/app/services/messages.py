"""Every SMS and email is a row in `messages`; the scheduler sends and retries them.

`enqueue_*` only inserts. `deliver` sends one row. `process_queue` is the job.
OTP codes are sent inline and logged here with the code masked.
"""

import logging
from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.integrations.email import EmailError, get_email
from app.integrations.sms import SmsError, get_sms
from app.models import Message
from app.timeutil import utcnow

logger = logging.getLogger(__name__)

MAX_ATTEMPTS = 5
RETRY_DELAYS = [1, 5, 15, 60, 180]  # minutes

# SMS templates (names match docs/dlt-msg91-guide.html). Value = (variable keys, preview text).
SMS_TEMPLATES: dict[str, tuple[list[str], str]] = {
    "visit_new": (
        ["booking_no", "when_hours", "link"],
        "CareNest: New visit #{booking_no} on {when_hours}. Patient, address and directions: {link} Please do not share this link.",
    ),
    "visit_removed": (
        ["booking_no", "when"],
        "CareNest: Visit #{booking_no} on {when} is no longer assigned to you.",
    ),
    "visit_cancelled": (
        ["booking_no", "when"],
        "CareNest: Visit #{booking_no} on {when} is cancelled. Please do not travel.",
    ),
    "booking_confirmed": (
        ["booking_no", "nurse", "when"],
        "CareNest: Booking #{booking_no} confirmed. Nurse {nurse} will visit on {when}. Thank you.",
    ),
    "nurse_changed": (
        ["booking_no", "nurse"],
        "CareNest: Your nurse for booking #{booking_no} is now {nurse}. Date and time are unchanged.",
    ),
    "booking_cancelled": (
        ["booking_no", "reason", "amount"],
        "CareNest: Booking #{booking_no} is cancelled. Reason: {reason}. Rs {amount} will be refunded in 5 to 7 working days.",
    ),
}


def clean_value(value: object, limit: int = 40) -> str:
    """DLT rules: <=40 chars, no commas in numbers, collapsed spaces, never starts with http/www."""
    text = " ".join(str(value).split())
    if text.lower().startswith(("http", "www")):
        text = "-" + text
    return text[:limit].rstrip()


def render_sms(template: str, variables: dict[str, str]) -> str:
    return SMS_TEMPLATES[template][1].format(**variables)


def enqueue_sms(
    db: AsyncSession,
    *,
    phone: str,
    template: str,
    variables: dict[str, str],
    recipient_type: str,
    booking_id: int | None = None,
) -> Message:
    keys, _ = SMS_TEMPLATES[template]
    cleaned = {k: (variables[k] if k == "link" else clean_value(variables[k])) for k in keys}
    msg = Message(
        booking_id=booking_id,
        recipient_type=recipient_type,
        recipient=phone,
        channel="sms",
        template=template,
        payload=cleaned,
        status="queued",
        next_attempt_at=utcnow(),
    )
    db.add(msg)
    return msg


def enqueue_email(
    db: AsyncSession,
    *,
    to: str,
    template: str,
    subject: str,
    html: str,
    recipient_type: str,
    booking_id: int | None = None,
) -> Message:
    msg = Message(
        booking_id=booking_id,
        recipient_type=recipient_type,
        recipient=to,
        channel="email",
        template=template,
        payload={"subject": subject, "html": html},
        status="queued",
        next_attempt_at=utcnow(),
    )
    db.add(msg)
    return msg


async def deliver(db: AsyncSession, msg: Message) -> bool:
    """Try once. Updates the row; the caller commits."""
    msg.attempts += 1
    try:
        if msg.channel == "sms":
            ref = await get_sms().send_template(msg.recipient, msg.template, msg.payload)
        else:
            ref = await get_email().send(msg.recipient, msg.payload["subject"], msg.payload["html"])
    except (SmsError, EmailError) as exc:
        msg.last_error = str(exc)[:500]
        if msg.attempts >= MAX_ATTEMPTS:
            msg.status = "failed"
            msg.next_attempt_at = None
        else:
            msg.status = "queued"
            delay = RETRY_DELAYS[min(msg.attempts - 1, len(RETRY_DELAYS) - 1)]
            msg.next_attempt_at = utcnow() + timedelta(minutes=delay)
        return False
    msg.status = "sent"
    msg.provider_ref = ref
    msg.last_error = None
    msg.sent_at = utcnow()
    msg.next_attempt_at = None
    return True


async def process_queue(db: AsyncSession, limit: int = 50) -> int:
    rows = (
        (
            await db.execute(
                select(Message)
                .where(Message.status == "queued", Message.next_attempt_at <= utcnow())
                .order_by(Message.id)
                .limit(limit)
                .with_for_update(skip_locked=True)
            )
        )
        .scalars()
        .all()
    )
    for msg in rows:
        await deliver(db, msg)
    await db.commit()
    return len(rows)


async def resend(db: AsyncSession, msg: Message) -> None:
    msg.status = "queued"
    msg.attempts = 0
    msg.next_attempt_at = utcnow()
    msg.last_error = None


async def log_otp_message(db: AsyncSession, *, phone: str, ok: bool, error: str | None = None) -> None:
    db.add(
        Message(
            recipient_type="user",
            recipient=phone,
            channel="sms",
            template="otp",
            payload={"code": "masked"},
            status="sent" if ok else "failed",
            attempts=1,
            last_error=error,
            sent_at=utcnow() if ok else None,
        )
    )

import secrets
from datetime import datetime

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models import Booking, VisitLink
from app.timeutil import IST, utcnow


def link_url(token: str) -> str:
    return f"{settings.API_BASE_URL.rstrip('/')}/v?k={token}"


async def create_link(db: AsyncSession, booking: Booking, nurse_id: int) -> VisitLink:
    # slot_end is naive IST; expiry is stored as an aware instant.
    expires = booking.slot_end.replace(tzinfo=IST)
    link = VisitLink(token=secrets.token_urlsafe(9), booking_id=booking.id, nurse_id=nurse_id, expires_at=expires)
    db.add(link)
    await db.flush()
    return link


async def revoke_links(db: AsyncSession, booking_id: int) -> None:
    await db.execute(
        update(VisitLink).where(VisitLink.booking_id == booking_id, VisitLink.revoked_at.is_(None)).values(revoked_at=utcnow())
    )


async def latest_link(db: AsyncSession, booking_id: int) -> VisitLink | None:
    return (
        await db.execute(
            select(VisitLink)
            .where(VisitLink.booking_id == booking_id)
            .order_by(VisitLink.expires_at.desc(), VisitLink.token)
            .limit(1)
        )
    ).scalar_one_or_none()


def _now_aware() -> datetime:
    return utcnow()


async def resolve(db: AsyncSession, token: str) -> tuple[str, VisitLink | None]:
    """Returns (state, link): state is 'ok', 'revoked', 'expired' or 'unknown'. Marks first open."""
    link = (await db.execute(select(VisitLink).where(VisitLink.token == token).with_for_update())).scalar_one_or_none()
    if link is None:
        return "unknown", None
    if link.revoked_at is not None:
        return "revoked", link
    if link.expires_at <= _now_aware():
        return "expired", link
    if link.first_opened_at is None:
        link.first_opened_at = utcnow()
    return "ok", link

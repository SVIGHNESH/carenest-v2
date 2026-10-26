from sqlalchemy.ext.asyncio import AsyncSession

from app.models import ActivityLog


def actor_admin(admin) -> str:
    return f"admin:{admin.id} {admin.name or admin.email}"


async def log(
    db: AsyncSession,
    actor: str,
    action: str,
    *,
    booking_id: int | None = None,
    nurse_id: int | None = None,
    **details,
) -> None:
    db.add(ActivityLog(actor=actor, action=action, booking_id=booking_id, nurse_id=nurse_id, details=details))

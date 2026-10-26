from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import AppSettings


async def get_app_settings(db: AsyncSession) -> AppSettings:
    row = (await db.execute(select(AppSettings).order_by(AppSettings.id).limit(1))).scalar_one_or_none()
    if row is None:
        row = AppSettings()
        db.add(row)
        await db.flush()
    return row

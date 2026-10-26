"""Idempotent seed: settings row, first admin (from env), starter services.

`--demo` also adds test nurses with working hours (never use in production).
Run: uv run python -m app.seed [--demo]
"""

import asyncio
import sys

from sqlalchemy import func, select

from app.config import settings
from app.db import SessionLocal
from app.models import AppSettings, Nurse, NurseService, NurseWeeklyHours, Service, User
from app.security import hash_password
from app.services.settings_service import get_app_settings

SERVICES = [
    ("Elder care", "Companionship, mobility help and daily care for older adults.", 400),
    ("Post-surgery care", "Wound care, medication and recovery support after surgery.", 500),
    ("Injection at home", "Prescribed injections and IV given at home.", 300),
    ("Physiotherapy", "Guided exercises and mobility therapy at home.", 600),
    ("Baby care", "Newborn and infant care support for parents.", 450),
]

DEMO_NURSES = [
    ("Anita Sharma", "+919000000001", "female"),
    ("Kavita Rao", "+919000000002", "female"),
    ("Rahul Kumar", "+919000000003", "male"),
    ("Imran Khan", "+919000000004", "male"),
]


async def seed(demo: bool = False) -> None:
    async with SessionLocal() as db:
        await get_app_settings(db)
        if not (await db.execute(select(func.count()).select_from(User).where(User.role == "admin"))).scalar_one():
            db.add(
                User(
                    name=settings.FIRST_ADMIN_NAME,
                    email=settings.FIRST_ADMIN_EMAIL.lower(),
                    role="admin",
                    password_hash=hash_password(settings.FIRST_ADMIN_PASSWORD),
                )
            )
        if not (await db.execute(select(func.count()).select_from(Service))).scalar_one():
            for name, desc, price in SERVICES:
                db.add(Service(name=name, description=desc, base_price=price))
        await db.commit()
        if demo and not (await db.execute(select(func.count()).select_from(Nurse))).scalar_one():
            service_ids = (await db.execute(select(Service.id))).scalars().all()
            for name, phone, gender in DEMO_NURSES:
                n = Nurse(name=name, phone=phone, gender=gender, experience_years=4, email=None)
                db.add(n)
                await db.flush()
                for sid in service_ids:
                    db.add(NurseService(nurse_id=n.id, service_id=sid))
                for wd in range(6):
                    db.add(NurseWeeklyHours(nurse_id=n.id, weekday=wd, start_hour=8, end_hour=20))
            await db.commit()
    _ = AppSettings


if __name__ == "__main__":
    asyncio.run(seed(demo="--demo" in sys.argv))

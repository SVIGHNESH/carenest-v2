import os
import subprocess
import sys
from datetime import datetime, timedelta

os.environ["DATABASE_URL"] = os.environ.get("TEST_DATABASE_URL", "postgresql+asyncpg://carenest@127.0.0.1:54329/carenest_test")
os.environ["ENVIRONMENT"] = "test"
os.environ["RUN_WORKER"] = "false"
os.environ["DB_NULL_POOL"] = "true"
os.environ["SECRET_KEY"] = "test-secret-test-secret-test-secret-1234"
os.environ["MSG91_AUTH_KEY"] = ""
os.environ["BREVO_API_KEY"] = ""
os.environ["PAYMENT_GATEWAY"] = "fake"

import pytest  # noqa: E402
import pytest_asyncio  # noqa: E402
from httpx import ASGITransport, AsyncClient  # noqa: E402
from sqlalchemy import text  # noqa: E402

from app.db import SessionLocal, engine  # noqa: E402
from app.integrations.email import set_email_provider  # noqa: E402
from app.integrations.payments import FakeGateway, set_gateway  # noqa: E402
from app.integrations.sms import set_sms_provider  # noqa: E402
from app.main import create_app  # noqa: E402
from app.models import (  # noqa: E402
    Address,
    Nurse,
    NurseService,
    NurseWeeklyHours,
    Service,
    User,
)
from app.security import create_admin_token, create_user_token, hash_password  # noqa: E402
from app.services.settings_service import get_app_settings  # noqa: E402
from app.timeutil import now_ist  # noqa: E402

TABLES = (
    "messages, visit_links, activity_log, payments, booking_assignments, bookings, nurse_day_overrides, "
    "nurse_weekly_hours, nurse_services, nurses, services, addresses, family_members, admin_backup_codes, "
    "admin_reset_tokens, otps, users, app_settings, heartbeat"
)


@pytest.fixture(scope="session", autouse=True)
def migrated():
    root = os.path.dirname(os.path.dirname(__file__))
    url = os.environ["DATABASE_URL"].replace("postgresql+asyncpg://", "postgresql://")
    admin_url = url.rsplit("/", 1)[0] + "/postgres"
    subprocess.run(["psql", admin_url, "-qc", "DROP DATABASE IF EXISTS carenest_test WITH (FORCE)"], check=True)
    subprocess.run(["psql", admin_url, "-qc", "CREATE DATABASE carenest_test"], check=True)
    subprocess.run([sys.executable, "-m", "alembic", "upgrade", "head"], cwd=root, check=True, env=os.environ)


class FakeSms:
    def __init__(self):
        self.sent: list[tuple[str, str, dict]] = []
        self.otps: dict[str, str] = {}
        self.fail = False

    async def send_otp(self, phone, code, expiry_minutes):
        self.otps[phone] = code
        return "ok"

    async def send_template(self, phone, template, variables):
        from app.integrations.sms import SmsError

        if self.fail:
            raise SmsError("provider down")
        self.sent.append((phone, template, dict(variables)))
        return "ok"


class FakeEmail:
    def __init__(self):
        self.sent: list[tuple[str, str, str]] = []

    async def send(self, to, subject, html):
        self.sent.append((to, subject, html))
        return "ok"


@pytest_asyncio.fixture(autouse=True)
async def clean(migrated):
    async with engine.begin() as conn:
        await conn.execute(text(f"TRUNCATE {TABLES} RESTART IDENTITY CASCADE"))
    async with SessionLocal() as db:
        await get_app_settings(db)
        await db.commit()
    FakeGateway.fail_refunds = False
    gw = FakeGateway()
    set_gateway(gw)
    sms, email = FakeSms(), FakeEmail()
    set_sms_provider(sms)
    set_email_provider(email)
    yield
    set_gateway(None)
    set_sms_provider(None)
    set_email_provider(None)


@pytest.fixture
def sms():
    from app.integrations import sms as m

    return m._override


@pytest.fixture
def email():
    from app.integrations import email as m

    return m._override


@pytest_asyncio.fixture
async def client():
    app = create_app()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c


# --- factories ---------------------------------------------------------------------
def tomorrow(hour: int = 10) -> datetime:
    return datetime.combine(now_ist().date() + timedelta(days=1), datetime.min.time()) + timedelta(hours=hour)


async def make_service(name="Elder care", price=400) -> int:
    async with SessionLocal() as db:
        s = Service(name=name, description="d", base_price=price)
        db.add(s)
        await db.commit()
        return s.id


async def make_nurse(name="Anita Sharma", gender="female", services=(1,), hours=(8, 20), phone=None, email=None) -> int:
    async with SessionLocal() as db:
        n = Nurse(name=name, phone=phone or f"+9190000{abs(hash(name)) % 100000:05d}", gender=gender, email=email)
        db.add(n)
        await db.flush()
        for sid in services:
            db.add(NurseService(nurse_id=n.id, service_id=sid))
        if hours:
            for wd in range(7):
                db.add(NurseWeeklyHours(nurse_id=n.id, weekday=wd, start_hour=hours[0], end_hour=hours[1]))
        await db.commit()
        return n.id


async def make_user(phone="+919876543210", name="Riya Sharma") -> tuple[int, dict]:
    async with SessionLocal() as db:
        u = User(name=name, phone=phone, role="user")
        db.add(u)
        await db.commit()
        return u.id, {"Authorization": f"Bearer {create_user_token(u.id)}"}


async def make_admin(email="boss@example.com") -> tuple[int, dict]:
    async with SessionLocal() as db:
        u = User(name="Boss", email=email, role="admin", password_hash=hash_password("a-long-password"), totp_enabled=True)
        db.add(u)
        await db.commit()
        return u.id, {"Authorization": f"Bearer {create_admin_token(u.id)}"}


async def make_address(user_id: int) -> int:
    async with SessionLocal() as db:
        a = Address(
            user_id=user_id,
            label="Home",
            house="12",
            area_line="Sector 14",
            city="Bareilly",
            state="UP",
            pincode="243001",
            landmark="Park gate",
            latitude=28.36,
            longitude=79.43,
            is_default=True,
        )
        db.add(a)
        await db.commit()
        return a.id


def booking_body(service_id, address_id, start, hours=2, gender="female", **kw):
    return {
        "service_id": service_id,
        "slot_start": start.isoformat(),
        "hours": hours,
        "nurse_gender": gender,
        "address_id": address_id,
        "patient_name": "R. Sharma",
        "patient_age": 68,
        "patient_sex": "male",
        "contact_phone": "9876543210",
        **kw,
    }


async def pay(client, headers, booking_id):
    order = (await client.post("/payments/create-order", json={"booking_id": booking_id}, headers=headers)).json()
    fake = (
        await client.post("/payments/fake/pay", json={"booking_id": booking_id, "order_id": order["order_id"]}, headers=headers)
    ).json()
    return await client.post(
        "/payments/verify",
        json={
            "booking_id": booking_id,
            "order_id": order["order_id"],
            "payment_id": fake["payment_id"],
            "signature": fake["signature"],
        },
        headers=headers,
    )

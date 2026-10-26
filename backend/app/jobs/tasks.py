"""Background jobs on Procrastinate (Postgres-backed queue, runs inside the backend process)."""

import logging

import procrastinate
from sqlalchemy import select

from app.config import settings
from app.db import SessionLocal
from app.integrations import backup
from app.models import Heartbeat
from app.services import booking as bk
from app.services import messages
from app.timeutil import utcnow

logger = logging.getLogger(__name__)

queue = procrastinate.App(
    connector=procrastinate.PsycopgConnector(conninfo=settings.psycopg_url),
)


async def job_expire_holds() -> int:
    async with SessionLocal() as db:
        n = await bk.expire_holds(db)
        await db.commit()
        return n


async def job_lifecycle() -> int:
    async with SessionLocal() as db:
        return await bk.advance_lifecycle(db)


async def job_messages() -> int:
    async with SessionLocal() as db:
        return await messages.process_queue(db)


async def job_refunds() -> int:
    async with SessionLocal() as db:
        return await bk.retry_refunds(db)


async def job_heartbeat() -> None:
    async with SessionLocal() as db:
        row = (await db.execute(select(Heartbeat).limit(1))).scalar_one_or_none()
        if row is None:
            db.add(Heartbeat(beat_at=utcnow()))
        else:
            row.beat_at = utcnow()
        await db.commit()


async def run_all_once() -> dict:
    """Everything the scheduler does each minute, once. Used by tests and the admin 'run jobs now'."""
    out = {
        "expired_holds": await job_expire_holds(),
        "lifecycle": await job_lifecycle(),
        "refunds": await job_refunds(),
        "messages": await job_messages(),
    }
    await job_heartbeat()
    return out


@queue.periodic(cron="* * * * *")
@queue.task(name="minute_tick", queueing_lock="minute_tick")
async def minute_tick(timestamp: int) -> None:
    await run_all_once()


@queue.periodic(cron="30 20 * * *")  # 02:00 IST
@queue.task(name="nightly_backup", queueing_lock="nightly_backup")
async def nightly_backup(timestamp: int) -> None:
    key = await backup.run_backup()
    logger.info("Backup done: %s", key)

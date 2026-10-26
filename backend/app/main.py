import asyncio
import contextlib
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api import admin_auth, admin_bookings, admin_catalog, auth, bookings, catalog, profile, public
from app.config import settings
from app.services.errors import BookingError

logger = logging.getLogger(__name__)


async def _bootstrap() -> None:
    if settings.RUN_MIGRATIONS_ON_STARTUP:
        from alembic.config import Config

        from alembic import command

        await asyncio.to_thread(command.upgrade, Config("alembic.ini"), "head")


@asynccontextmanager
async def lifespan(app: FastAPI):
    await _bootstrap()
    worker_task = None
    queue = None
    if settings.RUN_WORKER:
        from app.jobs.tasks import queue

        await queue.open_async()
        worker_task = asyncio.create_task(queue.run_worker_async(install_signal_handlers=False, wait=True))
    try:
        yield
    finally:
        if worker_task is not None:
            worker_task.cancel()
            with contextlib.suppress(asyncio.CancelledError, Exception):
                await worker_task
        if queue is not None:
            await queue.close_async()


def create_app() -> FastAPI:
    app = FastAPI(title="CareNest API", version="2.0.0", lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[settings.ADMIN_BASE_URL, "http://localhost:5173"],
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["X-Error-Code"],
    )

    @app.exception_handler(BookingError)
    async def booking_error(_: Request, exc: BookingError):
        return JSONResponse(
            status_code=exc.status, content={"detail": exc.message, "code": exc.code}, headers={"X-Error-Code": exc.code}
        )

    for r in (
        public.router,
        auth.router,
        profile.router,
        catalog.router,
        bookings.router,
        admin_auth.router,
        admin_catalog.router,
        admin_bookings.router,
    ):
        app.include_router(r)
    return app


app = create_app()

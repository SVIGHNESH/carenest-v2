from pathlib import Path

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.bookings import maps_url
from app.config import settings
from app.db import get_db
from app.models import Booking, Heartbeat
from app.services import visit_links as vl
from app.services.settings_service import get_app_settings
from app.timeutil import fmt_slot_when, utcnow

router = APIRouter(tags=["public"])
templates = Jinja2Templates(directory=str(Path(__file__).resolve().parent.parent / "templates"))
NO_STORE = {"Cache-Control": "no-store", "Referrer-Policy": "no-referrer", "X-Robots-Tag": "noindex"}


@router.get("/health")
async def health(db: AsyncSession = Depends(get_db)):
    ok_db = True
    try:
        (await db.execute(select(1))).scalar_one()
    except Exception:
        ok_db = False
    age = None
    worker_ok = True
    if settings.RUN_WORKER:
        beat = (await db.execute(select(Heartbeat.beat_at).limit(1))).scalar_one_or_none()
        age = (utcnow() - beat).total_seconds() if beat else None
        # A fresh process has no beat yet; only fail when a beat exists but is stale.
        worker_ok = age is None or age <= settings.HEARTBEAT_MAX_AGE_SECONDS
    status = 200 if ok_db and worker_ok else 503
    return JSONResponse({"db": ok_db, "worker": worker_ok, "heartbeat_age_seconds": age}, status_code=status)


@router.get("/v", response_class=HTMLResponse, include_in_schema=False)
async def visit_page(request: Request, k: str = "", db: AsyncSession = Depends(get_db)):
    state, link = await vl.resolve(db, k) if k else ("unknown", None)
    ctx: dict = {"state": state}
    if state == "ok" and link is not None:
        b = (
            await db.execute(select(Booking).where(Booking.id == link.booking_id).options(selectinload(Booking.assignments)))
        ).scalar_one()
        ctx.update(b=b, when=fmt_slot_when(b.slot_start), maps=maps_url(b.address_lat, b.address_lng))
    await db.commit()
    return templates.TemplateResponse(request, "visit.html", ctx, headers=NO_STORE)


@router.get("/delete-account", response_class=HTMLResponse, include_in_schema=False)
async def delete_account_page(request: Request, db: AsyncSession = Depends(get_db)):
    cfg = await get_app_settings(db)
    await db.commit()
    return templates.TemplateResponse(request, "delete-account.html", {"support_phone": cfg.support_phone})

from fastapi import Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_db
from app.models import User
from app.security import decode_token


def _bearer(request: Request) -> str:
    header = request.headers.get("authorization", "")
    scheme, _, token = header.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    return token


async def current_user(request: Request, db: AsyncSession = Depends(get_db)) -> User:
    payload = decode_token(_bearer(request), "user")
    if not payload:
        raise HTTPException(status_code=401, detail="Session expired. Please log in again.")
    user = (await db.execute(select(User).where(User.id == int(payload["sub"])))).scalar_one_or_none()
    if user is None or user.deleted_at is not None or user.role != "user":
        raise HTTPException(status_code=401, detail="Session expired. Please log in again.")
    return user


async def current_admin(request: Request, db: AsyncSession = Depends(get_db)) -> User:
    payload = decode_token(_bearer(request), "admin")
    if not payload:
        raise HTTPException(status_code=401, detail="Session expired. Please sign in again.")
    admin = (await db.execute(select(User).where(User.id == int(payload["sub"])))).scalar_one_or_none()
    if admin is None or admin.role != "admin" or not admin.is_active or admin.deleted_at is not None:
        raise HTTPException(status_code=401, detail="Session expired. Please sign in again.")
    return admin

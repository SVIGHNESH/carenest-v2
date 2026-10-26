"""Admin sign-in: email + password, then authenticator code (TOTP) or a backup code."""

import secrets
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.db import get_db
from app.deps import current_admin
from app.models import AdminBackupCode, AdminResetToken, User
from app.security import (
    MIN_PASSWORD_LENGTH,
    create_admin_token,
    create_ticket,
    decode_token,
    hash_code,
    hash_password,
    hash_token,
    new_random_token,
    new_totp_secret,
    totp_uri,
    verify_password,
    verify_totp,
)
from app.services import messages
from app.services.activity import actor_admin, log
from app.timeutil import utcnow

router = APIRouter(prefix="/admin", tags=["admin-auth"])

MAX_FAILS = 5
LOCK = timedelta(minutes=15)
RESET_TTL = timedelta(hours=1)


class AdminOut(BaseModel):
    id: int
    name: str
    email: str | None
    is_active: bool = True

    model_config = {"from_attributes": True}


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class LoginOut(BaseModel):
    # "mfa" = enter a code, "setup" = scan the QR first, "done" = token issued
    step: str
    ticket: str | None = None
    access_token: str | None = None
    admin: AdminOut | None = None


class MfaIn(BaseModel):
    ticket: str
    code: str = Field(min_length=6, max_length=20)


class SetupStartIn(BaseModel):
    ticket: str


class SetupStartOut(BaseModel):
    secret: str
    otpauth_uri: str


class SetupVerifyOut(BaseModel):
    access_token: str
    admin: AdminOut
    backup_codes: list[str]


class TokenOut(BaseModel):
    access_token: str
    admin: AdminOut


def _bad() -> HTTPException:
    return HTTPException(status_code=401, detail="Incorrect email or password.")


def _locked(admin: User) -> bool:
    return admin.locked_until is not None and admin.locked_until > utcnow()


def _register_fail(admin: User) -> None:
    admin.failed_logins += 1
    if admin.failed_logins >= MAX_FAILS:
        admin.locked_until = utcnow() + LOCK
        admin.failed_logins = 0


@router.post("/auth/login", response_model=LoginOut)
async def login(body: LoginIn, db: AsyncSession = Depends(get_db)) -> LoginOut:
    admin = (
        await db.execute(select(User).where(func.lower(User.email) == body.email.lower(), User.role == "admin"))
    ).scalar_one_or_none()
    if admin is None or not admin.is_active:
        raise _bad()
    if _locked(admin):
        raise HTTPException(status_code=429, detail="Too many attempts. Try again in 15 minutes.")
    if not verify_password(body.password, admin.password_hash):
        _register_fail(admin)
        await db.commit()
        raise _bad()
    admin.failed_logins = 0
    await db.commit()
    ticket = create_ticket("admin_mfa", {"sub": str(admin.id)}, minutes=10)
    return LoginOut(step="mfa" if admin.totp_enabled else "setup", ticket=ticket)


async def _admin_from_ticket(db: AsyncSession, ticket: str) -> User:
    claims = decode_token(ticket, "admin_mfa")
    if not claims:
        raise HTTPException(status_code=401, detail="Sign-in expired. Please start again.")
    admin = (await db.execute(select(User).where(User.id == int(claims["sub"]), User.role == "admin"))).scalar_one_or_none()
    if admin is None or not admin.is_active:
        raise HTTPException(status_code=401, detail="Sign-in expired. Please start again.")
    if _locked(admin):
        raise HTTPException(status_code=429, detail="Too many attempts. Try again in 15 minutes.")
    return admin


@router.post("/auth/mfa", response_model=TokenOut)
async def mfa(body: MfaIn, db: AsyncSession = Depends(get_db)) -> TokenOut:
    admin = await _admin_from_ticket(db, body.ticket)
    if not admin.totp_enabled or not admin.totp_secret:
        raise HTTPException(status_code=400, detail="Set up your authenticator first.")
    code = body.code.strip()
    ok = verify_totp(admin.totp_secret, code)
    if not ok:
        ok = await _use_backup_code(db, admin, code)
    if not ok:
        _register_fail(admin)
        await db.commit()
        raise HTTPException(status_code=401, detail="Incorrect code.")
    admin.failed_logins = 0
    await log(db, actor_admin(admin), "admin_login")
    await db.commit()
    return TokenOut(access_token=create_admin_token(admin.id), admin=AdminOut.model_validate(admin))


async def _use_backup_code(db: AsyncSession, admin: User, code: str) -> bool:
    candidate = hash_code(f"backup:{admin.id}", code.lower())
    row = (
        await db.execute(
            select(AdminBackupCode).where(
                AdminBackupCode.user_id == admin.id, AdminBackupCode.code_hash == candidate, AdminBackupCode.used_at.is_(None)
            )
        )
    ).scalar_one_or_none()
    if row is None:
        return False
    row.used_at = utcnow()
    return True


@router.post("/auth/totp/setup", response_model=SetupStartOut)
async def totp_setup(body: SetupStartIn, db: AsyncSession = Depends(get_db)) -> SetupStartOut:
    admin = await _admin_from_ticket(db, body.ticket)
    if admin.totp_enabled:
        raise HTTPException(status_code=400, detail="Authenticator is already set up.")
    secret = new_totp_secret()
    admin.totp_secret = secret
    await db.commit()
    return SetupStartOut(secret=secret, otpauth_uri=totp_uri(secret, admin.email or ""))


@router.post("/auth/totp/verify", response_model=SetupVerifyOut)
async def totp_verify(body: MfaIn, db: AsyncSession = Depends(get_db)) -> SetupVerifyOut:
    admin = await _admin_from_ticket(db, body.ticket)
    if admin.totp_enabled or not admin.totp_secret:
        raise HTTPException(status_code=400, detail="Start the authenticator setup first.")
    if not verify_totp(admin.totp_secret, body.code):
        _register_fail(admin)
        await db.commit()
        raise HTTPException(status_code=401, detail="Incorrect code.")
    admin.totp_enabled = True
    codes = [secrets.token_hex(4) for _ in range(8)]
    for c in codes:
        db.add(AdminBackupCode(user_id=admin.id, code_hash=hash_code(f"backup:{admin.id}", c)))
    await log(db, actor_admin(admin), "admin_totp_enabled")
    await db.commit()
    return SetupVerifyOut(access_token=create_admin_token(admin.id), admin=AdminOut.model_validate(admin), backup_codes=codes)


# --- password reset ----------------------------------------------------
class ForgotIn(BaseModel):
    email: EmailStr


class ResetIn(BaseModel):
    token: str
    password: str = Field(min_length=MIN_PASSWORD_LENGTH)


async def issue_reset(db: AsyncSession, admin: User, *, invite: bool = False) -> None:
    raw = new_random_token()
    db.add(AdminResetToken(user_id=admin.id, token_hash=hash_token(raw), expires_at=utcnow() + RESET_TTL))
    link = f"{settings.ADMIN_BASE_URL}/reset-password?token={raw}"
    subject = "Welcome to CareNest Admin" if invite else "Reset your CareNest admin password"
    html = (
        f"<p>Hello {admin.name},</p><p>Use this link to set your password. It works for one hour.</p>"
        f'<p><a href="{link}">{link}</a></p>'
    )
    messages.enqueue_email(db, to=admin.email or "", template="admin_reset", subject=subject, html=html, recipient_type="admin")


@router.post("/auth/forgot-password", status_code=204)
async def forgot_password(body: ForgotIn, db: AsyncSession = Depends(get_db)) -> Response:
    admin = (
        await db.execute(
            select(User).where(func.lower(User.email) == body.email.lower(), User.role == "admin", User.is_active.is_(True))
        )
    ).scalar_one_or_none()
    if admin is not None:
        await issue_reset(db, admin)
        await db.commit()
    return Response(status_code=204)  # same answer whether or not the address exists


@router.post("/auth/reset-password", status_code=204)
async def reset_password(body: ResetIn, db: AsyncSession = Depends(get_db)) -> Response:
    row = (
        await db.execute(select(AdminResetToken).where(AdminResetToken.token_hash == hash_token(body.token)).with_for_update())
    ).scalar_one_or_none()
    if row is None or row.used_at is not None or row.expires_at < utcnow():
        raise HTTPException(status_code=400, detail="This reset link is invalid or has expired.")
    admin = (await db.execute(select(User).where(User.id == row.user_id))).scalar_one()
    admin.password_hash = hash_password(body.password)
    admin.failed_logins = 0
    admin.locked_until = None
    row.used_at = utcnow()
    await log(db, actor_admin(admin), "admin_password_reset")
    await db.commit()
    return Response(status_code=204)


# --- me / team -----------------------------------------------------------
@router.get("/me", response_model=AdminOut)
async def me(admin: User = Depends(current_admin)) -> User:
    return admin


class ChangePasswordIn(BaseModel):
    current_password: str
    new_password: str = Field(min_length=MIN_PASSWORD_LENGTH)


@router.post("/me/password", status_code=204)
async def change_password(
    body: ChangePasswordIn, admin: User = Depends(current_admin), db: AsyncSession = Depends(get_db)
) -> Response:
    if not verify_password(body.current_password, admin.password_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect.")
    admin.password_hash = hash_password(body.new_password)
    await log(db, actor_admin(admin), "admin_password_changed")
    await db.commit()
    return Response(status_code=204)


class UpdateMeIn(BaseModel):
    name: str = Field(min_length=1, max_length=120)


@router.patch("/me", response_model=AdminOut)
async def update_me(body: UpdateMeIn, admin: User = Depends(current_admin), db: AsyncSession = Depends(get_db)) -> User:
    admin.name = body.name.strip()
    await db.commit()
    return admin


class TeamCreateIn(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    email: EmailStr


@router.get("/team", response_model=list[AdminOut])
async def team(_: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    return (
        (await db.execute(select(User).where(User.role == "admin", User.deleted_at.is_(None)).order_by(User.id))).scalars().all()
    )


@router.post("/team", response_model=AdminOut, status_code=201)
async def team_add(body: TeamCreateIn, admin: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    exists = (await db.execute(select(User.id).where(User.role == "admin", func.lower(User.email) == body.email.lower()))).first()
    if exists:
        raise HTTPException(status_code=409, detail="An admin with this email already exists.")
    # Unusable random password until they set one through the invite link.
    new = User(name=body.name.strip(), email=body.email.lower(), role="admin", password_hash=hash_password(new_random_token(32)))
    db.add(new)
    await db.flush()
    await issue_reset(db, new, invite=True)
    await log(db, actor_admin(admin), "admin_added", added=new.email)
    await db.commit()
    return new


@router.post("/team/{admin_id}/deactivate", response_model=AdminOut)
async def team_deactivate(admin_id: int, admin: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    if admin_id == admin.id:
        raise HTTPException(status_code=400, detail="You cannot deactivate yourself.")
    target = (await db.execute(select(User).where(User.id == admin_id, User.role == "admin"))).scalar_one_or_none()
    if target is None:
        raise HTTPException(status_code=404, detail="Admin not found")
    target.is_active = False
    await log(db, actor_admin(admin), "admin_deactivated", removed=target.email)
    await db.commit()
    return target


@router.post("/team/{admin_id}/activate", response_model=AdminOut)
async def team_activate(admin_id: int, admin: User = Depends(current_admin), db: AsyncSession = Depends(get_db)):
    target = (await db.execute(select(User).where(User.id == admin_id, User.role == "admin"))).scalar_one_or_none()
    if target is None:
        raise HTTPException(status_code=404, detail="Admin not found")
    target.is_active = True
    await log(db, actor_admin(admin), "admin_activated", email=target.email)
    await db.commit()
    return target

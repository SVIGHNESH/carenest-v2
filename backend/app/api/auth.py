from fastapi import APIRouter, Depends, HTTPException, Request, Response
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_db
from app.deps import current_user
from app.models import User
from app.phone import phone_or_400
from app.schemas.auth import (
    CompleteSignupIn,
    SendOtpIn,
    TokenOut,
    UserOut,
    VerifyOtpIn,
    VerifyOtpOut,
)
from app.security import create_ticket, create_user_token, decode_token
from app.services import otp
from app.services.activity import log

router = APIRouter(prefix="/auth", tags=["auth"])


def _token_for(user: User) -> TokenOut:
    return TokenOut(access_token=create_user_token(user.id), user=UserOut.model_validate(user))


async def _live_user_by_phone(db: AsyncSession, phone: str) -> User | None:
    return (
        await db.execute(select(User).where(User.phone == phone, User.deleted_at.is_(None), User.role == "user"))
    ).scalar_one_or_none()


@router.post("/phone/send-otp", status_code=204)
async def send_otp(body: SendOtpIn, request: Request, db: AsyncSession = Depends(get_db)) -> Response:
    phone = phone_or_400(body.phone)
    await otp.issue_otp(db, phone=phone, purpose=otp.PURPOSE_LOGIN, request_ip=otp.client_ip(request))
    return Response(status_code=204)


@router.post("/phone/verify-otp", response_model=VerifyOtpOut)
async def verify_otp(body: VerifyOtpIn, db: AsyncSession = Depends(get_db)) -> VerifyOtpOut:
    phone = phone_or_400(body.phone)
    await otp.consume_otp(db, phone=phone, purpose=otp.PURPOSE_LOGIN, code=body.code)
    user = await _live_user_by_phone(db, phone)
    await db.commit()
    if user is None:
        return VerifyOtpOut(needs_signup=True, signup_ticket=create_ticket("phone_signup", {"phone": phone}))
    return VerifyOtpOut(needs_signup=False, token=_token_for(user))


@router.post("/phone/complete-signup", response_model=TokenOut)
async def complete_signup(body: CompleteSignupIn, db: AsyncSession = Depends(get_db)) -> TokenOut:
    claims = decode_token(body.signup_ticket, "phone_signup")
    if not claims:
        raise HTTPException(status_code=400, detail="Verification expired. Please start again.")
    phone = claims["phone"]
    if await _live_user_by_phone(db, phone):
        raise HTTPException(status_code=409, detail="This number already has an account. Please log in.")
    user = User(name=body.name.strip(), phone=phone, email=body.email, role="user")
    db.add(user)
    try:
        await db.flush()
    except IntegrityError as exc:
        await db.rollback()
        raise HTTPException(status_code=409, detail="This number already has an account. Please log in.") from exc
    await log(db, f"user:{user.id}", "user_signup")
    await db.commit()
    return _token_for(user)


@router.post("/logout", status_code=204)
async def logout(_: User = Depends(current_user)) -> Response:
    # Tokens are stateless; the app discards its copy.
    return Response(status_code=204)

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_db
from app.deps import current_user
from app.models import Address, Booking, FamilyMember, User
from app.phone import phone_or_400
from app.schemas.auth import DeleteAccountIn, UpdateProfileIn, UserOut
from app.schemas.profile import (
    AddressIn,
    AddressOut,
    AddressPatch,
    FamilyIn,
    FamilyOut,
    FamilyPatch,
)
from app.services import otp
from app.services.activity import log

router = APIRouter(tags=["profile"])


# --- me ---------------------------------------------------------------
@router.get("/users/me", response_model=UserOut)
async def me(user: User = Depends(current_user)) -> User:
    return user


@router.patch("/users/me", response_model=UserOut)
async def update_me(body: UpdateProfileIn, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)) -> User:
    if body.name is not None:
        user.name = body.name.strip()
    if body.email is not None:
        user.email = body.email
    await db.commit()
    return user


@router.post("/users/me/delete-otp", status_code=204)
async def send_delete_otp(request: Request, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)) -> Response:
    assert user.phone
    await otp.issue_otp(db, phone=user.phone, purpose=otp.PURPOSE_DELETE, request_ip=otp.client_ip(request))
    return Response(status_code=204)


@router.delete("/users/me", status_code=204)
async def delete_me(body: DeleteAccountIn, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)) -> Response:
    assert user.phone
    await otp.consume_otp(db, phone=user.phone, purpose=otp.PURPOSE_DELETE, code=body.code)
    open_booking = (
        await db.execute(
            select(Booking.id)
            .where(Booking.user_id == user.id, Booking.status.in_(["confirmed", "in_progress", "pending_payment"]))
            .limit(1)
        )
    ).first()
    if open_booking:
        await db.rollback()
        raise HTTPException(
            status_code=409, detail="You have an upcoming booking. Please call support before deleting your account."
        )
    await anonymize_user(db, user)
    await db.commit()
    return Response(status_code=204)


async def anonymize_user(db: AsyncSession, user: User) -> None:
    """Erase personal data; bookings and payments stay, with personal details blanked."""
    from datetime import datetime, timezone

    await db.execute(
        update(Booking)
        .where(Booking.user_id == user.id)
        .values(
            member_id=None,
            patient_name="",
            patient_age=None,
            patient_sex=None,
            patient_condition=None,
            contact_phone="",
            address_text="",
            address_landmark=None,
            address_lat=0.0,
            address_lng=0.0,
        )
    )
    await db.execute(delete(FamilyMember).where(FamilyMember.user_id == user.id))
    await db.execute(delete(Address).where(Address.user_id == user.id))
    await log(db, f"user:{user.id}", "account_deleted")
    user.name = "Deleted user"
    user.phone = None
    user.email = None
    user.deleted_at = datetime.now(timezone.utc)


# --- family -----------------------------------------------------------
def _clean_phone(raw: str | None) -> str | None:
    return phone_or_400(raw) if raw else None


@router.get("/family", response_model=list[FamilyOut])
async def list_family(user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    return (
        (await db.execute(select(FamilyMember).where(FamilyMember.user_id == user.id).order_by(FamilyMember.id))).scalars().all()
    )


@router.post("/family", response_model=FamilyOut, status_code=201)
async def add_family(body: FamilyIn, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    data = body.model_dump()
    data["contact_phone"] = _clean_phone(data["contact_phone"])
    member = FamilyMember(user_id=user.id, **data)
    db.add(member)
    await db.commit()
    return member


async def _own_member(db: AsyncSession, user: User, member_id: int) -> FamilyMember:
    m = (
        await db.execute(select(FamilyMember).where(FamilyMember.id == member_id, FamilyMember.user_id == user.id))
    ).scalar_one_or_none()
    if m is None:
        raise HTTPException(status_code=404, detail="Family member not found")
    return m


@router.patch("/family/{member_id}", response_model=FamilyOut)
async def edit_family(member_id: int, body: FamilyPatch, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    m = await _own_member(db, user, member_id)
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(m, k, _clean_phone(v) if k == "contact_phone" else v)
    await db.commit()
    return m


@router.delete("/family/{member_id}", status_code=204)
async def delete_family(member_id: int, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)) -> Response:
    m = await _own_member(db, user, member_id)
    await db.delete(m)
    await db.commit()
    return Response(status_code=204)


# --- addresses --------------------------------------------------------
async def _own_address(db: AsyncSession, user: User, address_id: int) -> Address:
    a = (await db.execute(select(Address).where(Address.id == address_id, Address.user_id == user.id))).scalar_one_or_none()
    if a is None:
        raise HTTPException(status_code=404, detail="Address not found")
    return a


async def _clear_default(db: AsyncSession, user: User) -> None:
    await db.execute(update(Address).where(Address.user_id == user.id).values(is_default=False))


@router.get("/addresses", response_model=list[AddressOut])
async def list_addresses(user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    return (
        (await db.execute(select(Address).where(Address.user_id == user.id).order_by(Address.is_default.desc(), Address.id)))
        .scalars()
        .all()
    )


@router.post("/addresses", response_model=AddressOut, status_code=201)
async def add_address(body: AddressIn, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)):
    has_any = (await db.execute(select(Address.id).where(Address.user_id == user.id).limit(1))).first()
    make_default = body.is_default or not has_any
    if make_default:
        await _clear_default(db, user)
    data = body.model_dump()
    data["is_default"] = make_default
    addr = Address(user_id=user.id, **data)
    db.add(addr)
    await db.commit()
    return addr


@router.patch("/addresses/{address_id}", response_model=AddressOut)
async def edit_address(
    address_id: int, body: AddressPatch, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)
):
    a = await _own_address(db, user, address_id)
    changes = body.model_dump(exclude_unset=True)
    if changes.get("is_default"):
        await _clear_default(db, user)
    for k, v in changes.items():
        if k in ("latitude", "longitude") and v is None:
            continue
        setattr(a, k, v)
    await db.commit()
    return a


@router.delete("/addresses/{address_id}", status_code=204)
async def delete_address(address_id: int, user: User = Depends(current_user), db: AsyncSession = Depends(get_db)) -> Response:
    a = await _own_address(db, user, address_id)
    await db.delete(a)
    await db.commit()
    return Response(status_code=204)

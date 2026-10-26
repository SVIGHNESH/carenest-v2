import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
import pyotp

from app.config import settings

ALGORITHM = "HS256"
MIN_PASSWORD_LENGTH = 10


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(password: str, hashed: str | None) -> bool:
    if not hashed:
        return False
    try:
        return bcrypt.checkpw(password.encode(), hashed.encode())
    except ValueError:
        return False


def _encode(payload: dict, ttl: timedelta) -> str:
    payload = {**payload, "exp": datetime.now(timezone.utc) + ttl}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=ALGORITHM)


def decode_token(token: str, expected_type: str) -> dict | None:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
    except jwt.PyJWTError:
        return None
    if payload.get("type") != expected_type:
        return None
    return payload


def create_user_token(user_id: int) -> str:
    return _encode({"sub": str(user_id), "type": "user"}, timedelta(days=settings.USER_TOKEN_DAYS))


def create_admin_token(user_id: int) -> str:
    return _encode({"sub": str(user_id), "type": "admin"}, timedelta(hours=settings.ADMIN_TOKEN_HOURS))


def create_ticket(kind: str, claims: dict, minutes: int = 15) -> str:
    """Short-lived, single purpose token (signup ticket, MFA step ticket)."""
    return _encode({**claims, "type": kind}, timedelta(minutes=minutes))


def hash_token(raw: str) -> str:
    return hashlib.sha256(raw.encode()).hexdigest()


def new_random_token(nbytes: int = 24) -> str:
    return secrets.token_urlsafe(nbytes)


def hash_code(namespace: str, code: str) -> str:
    return hmac.new(settings.SECRET_KEY.encode(), f"{namespace}:{code}".encode(), hashlib.sha256).hexdigest()


# --- TOTP -------------------------------------------------------------
def new_totp_secret() -> str:
    return pyotp.random_base32()


def totp_uri(secret: str, email: str) -> str:
    return pyotp.TOTP(secret).provisioning_uri(name=email, issuer_name="CareNest Admin")


def verify_totp(secret: str, code: str) -> bool:
    return pyotp.TOTP(secret).verify(code.strip().replace(" ", ""), valid_window=1)

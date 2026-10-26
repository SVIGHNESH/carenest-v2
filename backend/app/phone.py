"""Phone number normalisation: every stored number is +91 followed by 10 digits."""

import re

from fastapi import HTTPException

_INDIAN_MOBILE = re.compile(r"[6-9]\d{9}")


def normalize_phone(raw: str) -> str:
    digits = re.sub(r"[\s\-().]", "", raw.strip())
    if digits.startswith("+"):
        digits = digits[1:]
    if not digits.isdigit():
        raise ValueError("Enter a valid 10-digit mobile number")
    if len(digits) == 12 and digits.startswith("91"):
        digits = digits[2:]
    elif len(digits) == 11 and digits.startswith("0"):
        digits = digits[1:]
    if not _INDIAN_MOBILE.fullmatch(digits):
        raise ValueError("Enter a valid 10-digit mobile number")
    return f"+91{digits}"


def phone_or_400(raw: str) -> str:
    """Route handlers use this so the app always receives a plain-string `detail`."""
    try:
        return normalize_phone(raw)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

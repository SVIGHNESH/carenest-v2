"""Transactional email through Brevo. Dev mode (no key) logs instead."""

import logging
from typing import Protocol

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

BREVO_URL = "https://api.brevo.com/v3/smtp/email"


class EmailError(Exception):
    pass


class EmailProvider(Protocol):
    async def send(self, to: str, subject: str, html: str) -> str | None: ...


class DevLogEmail:
    async def send(self, to: str, subject: str, html: str) -> str | None:
        logger.warning("DEV EMAIL to %s | %s | %s (not sent)", to, subject, html[:300])
        return "dev-log"


class BrevoEmail:
    async def send(self, to: str, subject: str, html: str) -> str | None:
        payload = {
            "sender": {"name": "CareNest", "email": settings.EMAIL_FROM},
            "to": [{"email": to}],
            "subject": subject,
            "htmlContent": html,
        }
        try:
            async with httpx.AsyncClient(timeout=15) as client:
                r = await client.post(BREVO_URL, json=payload, headers={"api-key": settings.BREVO_API_KEY})
        except httpx.HTTPError as exc:
            raise EmailError(f"Brevo request failed: {exc}") from exc
        if r.status_code >= 300:
            raise EmailError(f"Brevo rejected: {r.status_code} {r.text[:200]}")
        return r.json().get("messageId")


_override: EmailProvider | None = None


def set_email_provider(provider: EmailProvider | None) -> None:
    global _override
    _override = provider


def get_email() -> EmailProvider:
    if _override is not None:
        return _override
    return BrevoEmail() if settings.BREVO_API_KEY else DevLogEmail()

"""SMS through MSG91, behind a small interface.

Dev mode (no auth key) logs instead of sending. Staging can restrict
recipients with SMS_WHITELIST so test traffic never reaches real people.
"""

import logging
from typing import Protocol

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

MSG91_OTP_URL = "https://control.msg91.com/api/v5/otp"
MSG91_FLOW_URL = "https://control.msg91.com/api/v5/flow"


class SmsError(Exception):
    pass


class SmsProvider(Protocol):
    async def send_otp(self, phone: str, code: str, expiry_minutes: int) -> str | None: ...
    async def send_template(self, phone: str, template: str, variables: dict[str, str]) -> str | None: ...


def _allowed(phone: str) -> bool:
    wl = settings.sms_whitelist
    return not wl or phone in wl


class DevLogSms:
    async def send_otp(self, phone: str, code: str, expiry_minutes: int) -> str | None:
        logger.warning("DEV SMS OTP to %s: %s (not sent)", phone, code)
        return "dev-log"

    async def send_template(self, phone: str, template: str, variables: dict[str, str]) -> str | None:
        logger.warning("DEV SMS %s to %s: %s (not sent)", template, phone, variables)
        return "dev-log"


class Msg91Sms:
    async def _post(self, url: str, **kw) -> dict:
        headers = {"authkey": settings.MSG91_AUTH_KEY, "Content-Type": "application/json"}
        try:
            async with httpx.AsyncClient(timeout=15) as client:
                response = await client.post(url, headers=headers, **kw)
            data = response.json()
        except (httpx.HTTPError, ValueError) as exc:
            raise SmsError(f"MSG91 request failed: {exc}") from exc
        # MSG91 answers 200 even for rejections; the body carries the verdict.
        if response.status_code != 200 or data.get("type") != "success":
            raise SmsError(f"MSG91 rejected: {response.status_code} {response.text[:200]}")
        return data

    async def send_otp(self, phone: str, code: str, expiry_minutes: int) -> str | None:
        if not _allowed(phone):
            logger.info("SMS to %s skipped (not on whitelist)", phone)
            return "skipped-whitelist"
        params = {
            "template_id": settings.MSG91_OTP_TEMPLATE_ID,
            "mobile": phone.lstrip("+"),
            "otp": code,
            "otp_expiry": expiry_minutes,
        }
        data = await self._post(MSG91_OTP_URL, params=params, json={})
        return data.get("request_id") or data.get("message")

    async def send_template(self, phone: str, template: str, variables: dict[str, str]) -> str | None:
        if not _allowed(phone):
            logger.info("SMS to %s skipped (not on whitelist)", phone)
            return "skipped-whitelist"
        template_id = settings.template_ids.get(template)
        if not template_id:
            raise SmsError(f"No MSG91 template id configured for '{template}'")
        body = {
            "template_id": template_id,
            "short_url": "0",
            "recipients": [{"mobiles": phone.lstrip("+"), **variables}],
        }
        data = await self._post(MSG91_FLOW_URL, json=body)
        return data.get("message")


_override: SmsProvider | None = None


def set_sms_provider(provider: SmsProvider | None) -> None:
    """Tests inject a fake."""
    global _override
    _override = provider


def get_sms() -> SmsProvider:
    if _override is not None:
        return _override
    return Msg91Sms() if settings.MSG91_AUTH_KEY else DevLogSms()

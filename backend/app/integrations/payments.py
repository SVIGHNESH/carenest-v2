"""Payment gateways behind one interface.

FakeGateway needs no keys. RazorpayGateway is the real one; swap with
PAYMENT_GATEWAY=razorpay once keys exist.
"""

import hashlib
import hmac
import secrets
from dataclasses import dataclass
from typing import Protocol

from app.config import settings


class GatewayError(Exception):
    pass


@dataclass
class Order:
    order_id: str
    amount: int  # whole rupees
    key_id: str


class PaymentGateway(Protocol):
    name: str

    @property
    def key_id(self) -> str: ...

    def create_order(self, booking_id: int, amount: int) -> Order: ...
    def verify_signature(self, order_id: str, payment_id: str, signature: str) -> bool: ...
    def verify_webhook(self, body: bytes, signature: str) -> bool: ...
    def refund(self, payment_id: str, amount: int) -> str: ...


FAKE_SECRET = "fake-gateway-secret"


class FakeGateway:
    """Deterministic stand-in. The app's fake sheet signs with `sign()`."""

    name = "fake"

    @property
    def key_id(self) -> str:
        return "fake_key"

    fail_refunds = False  # tests flip this

    def create_order(self, booking_id: int, amount: int) -> Order:
        return Order(order_id=f"fake_order_{booking_id}_{secrets.token_hex(4)}", amount=amount, key_id="fake_key")

    @staticmethod
    def sign(order_id: str, payment_id: str) -> str:
        return hmac.new(FAKE_SECRET.encode(), f"{order_id}|{payment_id}".encode(), hashlib.sha256).hexdigest()

    def verify_signature(self, order_id: str, payment_id: str, signature: str) -> bool:
        return hmac.compare_digest(self.sign(order_id, payment_id), signature)

    def verify_webhook(self, body: bytes, signature: str) -> bool:
        expected = hmac.new(FAKE_SECRET.encode(), body, hashlib.sha256).hexdigest()
        return hmac.compare_digest(expected, signature)

    def refund(self, payment_id: str, amount: int) -> str:
        if FakeGateway.fail_refunds:
            raise GatewayError("fake refund failure")
        return f"fake_refund_{payment_id}"


class RazorpayGateway:
    name = "razorpay"

    @property
    def key_id(self) -> str:
        return settings.RAZORPAY_KEY_ID

    def __init__(self) -> None:
        import razorpay

        self._client = razorpay.Client(auth=(settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET))

    def create_order(self, booking_id: int, amount: int) -> Order:
        try:
            data = self._client.order.create(
                {"amount": amount * 100, "currency": "INR", "receipt": f"booking_{booking_id}", "payment_capture": 1}
            )
        except Exception as exc:  # razorpay raises assorted errors
            raise GatewayError(str(exc)) from exc
        return Order(order_id=data["id"], amount=amount, key_id=settings.RAZORPAY_KEY_ID)

    def verify_signature(self, order_id: str, payment_id: str, signature: str) -> bool:
        expected = hmac.new(
            settings.RAZORPAY_KEY_SECRET.encode(), f"{order_id}|{payment_id}".encode(), hashlib.sha256
        ).hexdigest()
        return hmac.compare_digest(expected, signature)

    def verify_webhook(self, body: bytes, signature: str) -> bool:
        expected = hmac.new(settings.RAZORPAY_WEBHOOK_SECRET.encode(), body, hashlib.sha256).hexdigest()
        return hmac.compare_digest(expected, signature)

    def refund(self, payment_id: str, amount: int) -> str:
        try:
            data = self._client.payment.refund(payment_id, {"amount": amount * 100, "speed": "normal"})
        except Exception as exc:
            raise GatewayError(str(exc)) from exc
        return data["id"]


_override: PaymentGateway | None = None
_cached: PaymentGateway | None = None


def set_gateway(gw: PaymentGateway | None) -> None:
    global _override
    _override = gw


def get_gateway() -> PaymentGateway:
    global _cached
    if _override is not None:
        return _override
    if _cached is None:
        _cached = RazorpayGateway() if settings.PAYMENT_GATEWAY == "razorpay" else FakeGateway()
    return _cached

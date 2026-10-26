from datetime import datetime

from pydantic import BaseModel, Field

from app.schemas.common import Gender, Sex


class ServiceOut(BaseModel):
    id: int
    name: str
    description: str
    base_price: int
    active: bool = True
    available: bool = True  # False => "Not available right now"

    model_config = {"from_attributes": True}


class BookingSettingsOut(BaseModel):
    min_notice_minutes: int
    booking_window_days: int
    bookings_paused: bool
    support_phone: str


class TimeSlotOut(BaseModel):
    hour: int
    free: bool  # some qualified nurse is free for at least one hour from here
    too_soon: bool  # inside the notice period


class TimeGridOut(BaseModel):
    date: str
    slots: list[TimeSlotOut]


class MaxDurationOut(BaseModel):
    max_hours: int


class GenderAvailabilityOut(BaseModel):
    male: bool
    female: bool


class QuoteIn(BaseModel):
    service_id: int
    hours: int = Field(ge=1, le=12)


class QuoteOut(BaseModel):
    service_id: int
    hours: int
    base_price: int
    amount: int


class BookingCreateIn(BaseModel):
    service_id: int
    slot_start: datetime  # IST wall-clock, no time zone
    hours: int = Field(ge=1, le=12)
    nurse_gender: Gender
    address_id: int
    member_id: int | None = None
    patient_name: str = Field(min_length=1, max_length=120)
    patient_age: int | None = Field(default=None, ge=0, le=120)
    patient_sex: Sex | None = None
    patient_condition: str | None = Field(default=None, max_length=1000)
    contact_phone: str


class RefundOut(BaseModel):
    amount: int
    status: str  # refund_pending | refunded | refund_failed
    expected: str = "5 to 7 working days"


class BookingOut(BaseModel):
    id: int
    status: str
    service_id: int
    service_name: str
    slot_start: datetime
    slot_end: datetime
    hours: int
    amount: int
    nurse_gender_preference: str
    nurse_name: str | None  # shown once confirmed
    patient_name: str
    patient_age: int | None
    patient_sex: str | None
    contact_phone: str
    address_text: str
    address_landmark: str | None
    latitude: float
    longitude: float
    maps_url: str
    hold_expires_at: datetime | None
    cancel_reason: str | None
    cancelled_by: str | None
    payment_status: str | None
    refund: RefundOut | None
    support_phone: str
    created_at: datetime


class OrderIn(BaseModel):
    booking_id: int


class OrderOut(BaseModel):
    gateway: str
    order_id: str
    amount: int
    key_id: str
    booking_id: int
    hold_expires_at: datetime | None


class VerifyIn(BaseModel):
    booking_id: int
    order_id: str
    payment_id: str
    signature: str


class FakePayIn(BaseModel):
    booking_id: int
    order_id: str


class FakePayOut(BaseModel):
    payment_id: str
    signature: str

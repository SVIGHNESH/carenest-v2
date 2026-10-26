from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, ExcludeConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base

BOOKING_STATUSES = ("pending_payment", "expired", "confirmed", "in_progress", "completed", "cancelled")
PAYMENT_STATUSES = ("pending", "completed", "refund_pending", "refunded", "refund_failed")


class Booking(Base):
    __tablename__ = "bookings"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    member_id: Mapped[int | None] = mapped_column(ForeignKey("family_members.id", ondelete="SET NULL"))
    service_id: Mapped[int] = mapped_column(ForeignKey("services.id"))
    slot_start: Mapped[datetime] = mapped_column(DateTime, index=True)  # naive IST
    slot_end: Mapped[datetime] = mapped_column(DateTime)
    hours: Mapped[int] = mapped_column(Integer)
    amount: Mapped[int] = mapped_column(Integer)
    nurse_gender_preference: Mapped[str] = mapped_column(String(10))
    status: Mapped[str] = mapped_column(String(20), index=True, default="pending_payment")
    hold_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    patient_name: Mapped[str] = mapped_column(String(120), default="")
    patient_age: Mapped[int | None] = mapped_column(Integer)
    patient_sex: Mapped[str | None] = mapped_column(String(10))
    patient_condition: Mapped[str | None] = mapped_column(Text)
    contact_phone: Mapped[str] = mapped_column(String(20))
    address_text: Mapped[str] = mapped_column(Text)
    address_landmark: Mapped[str | None] = mapped_column(String(160))
    address_lat: Mapped[float] = mapped_column()
    address_lng: Mapped[float] = mapped_column()
    cancel_reason: Mapped[str | None] = mapped_column(Text)
    cancelled_by: Mapped[str | None] = mapped_column(String(10))  # admin | system
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    service = relationship("Service", lazy="selectin")
    assignments = relationship("BookingAssignment", back_populates="booking", order_by="BookingAssignment.id")
    payment = relationship("Payment", back_populates="booking", uselist=False, lazy="selectin")


class BookingAssignment(Base):
    __tablename__ = "booking_assignments"

    id: Mapped[int] = mapped_column(primary_key=True)
    booking_id: Mapped[int] = mapped_column(ForeignKey("bookings.id", ondelete="CASCADE"), index=True)
    nurse_id: Mapped[int] = mapped_column(ForeignKey("nurses.id"), index=True)
    slot_start: Mapped[datetime] = mapped_column(DateTime)
    slot_end: Mapped[datetime] = mapped_column(DateTime)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    assigned_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    booking = relationship("Booking", back_populates="assignments")
    nurse = relationship("Nurse", lazy="selectin")

    __table_args__ = (
        # Final guard against double booking: no two active rows overlap for one nurse.
        ExcludeConstraint(
            ("nurse_id", "="),
            (text("tsrange(slot_start, slot_end)"), "&&"),
            name="no_overlap_active_nurse",
            where=text("active"),
            using="gist",
        ),
    )


class Payment(Base):
    __tablename__ = "payments"

    id: Mapped[int] = mapped_column(primary_key=True)
    booking_id: Mapped[int] = mapped_column(ForeignKey("bookings.id", ondelete="CASCADE"), unique=True)
    gateway: Mapped[str] = mapped_column(String(20))
    order_id: Mapped[str | None] = mapped_column(String(80), index=True)
    payment_id: Mapped[str | None] = mapped_column(String(80))
    amount: Mapped[int] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(20), default="pending")
    refund_id: Mapped[str | None] = mapped_column(String(80))
    refunded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    refund_error: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    booking = relationship("Booking", back_populates="payment")


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[int] = mapped_column(primary_key=True)
    booking_id: Mapped[int | None] = mapped_column(ForeignKey("bookings.id", ondelete="SET NULL"), index=True)
    recipient_type: Mapped[str] = mapped_column(String(10))  # user | nurse | admin
    recipient: Mapped[str] = mapped_column(String(254))  # phone or email
    channel: Mapped[str] = mapped_column(String(10))  # sms | email
    template: Mapped[str] = mapped_column(String(40))
    payload: Mapped[dict] = mapped_column(JSONB, default=dict)
    status: Mapped[str] = mapped_column(String(10), default="queued", index=True)  # queued|sent|failed
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    provider_ref: Mapped[str | None] = mapped_column(String(120))
    last_error: Mapped[str | None] = mapped_column(Text)
    next_attempt_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class VisitLink(Base):
    __tablename__ = "visit_links"

    token: Mapped[str] = mapped_column(String(32), primary_key=True)
    booking_id: Mapped[int] = mapped_column(ForeignKey("bookings.id", ondelete="CASCADE"), index=True)
    nurse_id: Mapped[int] = mapped_column(ForeignKey("nurses.id"))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    first_opened_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class ActivityLog(Base):
    __tablename__ = "activity_log"

    id: Mapped[int] = mapped_column(primary_key=True)
    actor: Mapped[str] = mapped_column(String(80))  # "admin:3 name", "system", "user:7"
    action: Mapped[str] = mapped_column(String(60))
    booking_id: Mapped[int | None] = mapped_column(ForeignKey("bookings.id", ondelete="SET NULL"), index=True)
    nurse_id: Mapped[int | None] = mapped_column(ForeignKey("nurses.id", ondelete="SET NULL"))
    details: Mapped[dict] = mapped_column(JSONB, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class AppSettings(Base):
    __tablename__ = "app_settings"

    id: Mapped[int] = mapped_column(primary_key=True)
    min_notice_minutes: Mapped[int] = mapped_column(Integer, default=180)
    booking_window_days: Mapped[int] = mapped_column(Integer, default=7)
    bookings_paused: Mapped[bool] = mapped_column(Boolean, default=False)
    travel_gap_hours: Mapped[int] = mapped_column(Integer, default=1)
    support_phone: Mapped[str] = mapped_column(String(30), default="1800 000 000")


class Heartbeat(Base):
    __tablename__ = "heartbeat"

    id: Mapped[int] = mapped_column(primary_key=True)
    beat_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))

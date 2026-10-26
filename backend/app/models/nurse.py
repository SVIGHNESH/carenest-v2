from datetime import date

from sqlalchemy import Boolean, Date, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class Service(Base):
    __tablename__ = "services"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    description: Mapped[str] = mapped_column(Text, default="")
    base_price: Mapped[int] = mapped_column(Integer)  # whole rupees per hour, tax included
    active: Mapped[bool] = mapped_column(Boolean, default=True)


class Nurse(Base):
    __tablename__ = "nurses"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    phone: Mapped[str] = mapped_column(String(20))
    email: Mapped[str | None] = mapped_column(String(254))
    gender: Mapped[str] = mapped_column(String(10))  # male | female
    experience_years: Mapped[int] = mapped_column(Integer, default=0)
    notes: Mapped[str | None] = mapped_column(Text)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)


class NurseService(Base):
    __tablename__ = "nurse_services"

    nurse_id: Mapped[int] = mapped_column(ForeignKey("nurses.id", ondelete="CASCADE"), primary_key=True)
    service_id: Mapped[int] = mapped_column(ForeignKey("services.id", ondelete="CASCADE"), primary_key=True)


class NurseWeeklyHours(Base):
    __tablename__ = "nurse_weekly_hours"
    __table_args__ = (UniqueConstraint("nurse_id", "weekday"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    nurse_id: Mapped[int] = mapped_column(ForeignKey("nurses.id", ondelete="CASCADE"), index=True)
    weekday: Mapped[int] = mapped_column(Integer)  # 0 = Monday
    start_hour: Mapped[int] = mapped_column(Integer)
    end_hour: Mapped[int] = mapped_column(Integer)  # exclusive, up to 24


class NurseDayOverride(Base):
    __tablename__ = "nurse_day_overrides"
    __table_args__ = (UniqueConstraint("nurse_id", "day"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    nurse_id: Mapped[int] = mapped_column(ForeignKey("nurses.id", ondelete="CASCADE"), index=True)
    day: Mapped[date] = mapped_column(Date)
    is_leave: Mapped[bool] = mapped_column(Boolean, default=False)
    start_hour: Mapped[int | None] = mapped_column(Integer)
    end_hour: Mapped[int | None] = mapped_column(Integer)
    note: Mapped[str | None] = mapped_column(String(200))

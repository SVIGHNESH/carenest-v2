from pydantic import BaseModel, Field, field_validator

from app.schemas.common import Sex


class FamilyIn(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    age: int = Field(ge=0, le=120)
    sex: Sex
    relation: str = Field(min_length=1, max_length=40)
    contact_phone: str | None = None
    medical_notes: str | None = None


class FamilyPatch(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    age: int | None = Field(default=None, ge=0, le=120)
    sex: Sex | None = None
    relation: str | None = Field(default=None, min_length=1, max_length=40)
    contact_phone: str | None = None
    medical_notes: str | None = None


class FamilyOut(BaseModel):
    id: int
    name: str
    age: int
    sex: str
    relation: str
    contact_phone: str | None
    medical_notes: str | None

    model_config = {"from_attributes": True}


class AddressIn(BaseModel):
    label: str = Field(default="Home", max_length=40)
    house: str = Field(default="", max_length=120)
    area_line: str = Field(default="", max_length=255)
    city: str = Field(default="", max_length=80)
    state: str = Field(default="", max_length=80)
    pincode: str = Field(default="", max_length=10)
    landmark: str | None = Field(default=None, max_length=160)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    is_default: bool = False

    @field_validator("latitude", "longitude")
    @classmethod
    def _not_origin(cls, v: float) -> float:
        return v


class AddressPatch(BaseModel):
    label: str | None = Field(default=None, max_length=40)
    house: str | None = Field(default=None, max_length=120)
    area_line: str | None = Field(default=None, max_length=255)
    city: str | None = Field(default=None, max_length=80)
    state: str | None = Field(default=None, max_length=80)
    pincode: str | None = Field(default=None, max_length=10)
    landmark: str | None = Field(default=None, max_length=160)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    is_default: bool | None = None


class AddressOut(BaseModel):
    id: int
    label: str
    house: str
    area_line: str
    city: str
    state: str
    pincode: str
    landmark: str | None
    latitude: float
    longitude: float
    is_default: bool

    model_config = {"from_attributes": True}

from pydantic import BaseModel, EmailStr, Field

from app.schemas.common import Sex  # noqa: F401


class SendOtpIn(BaseModel):
    phone: str


class VerifyOtpIn(BaseModel):
    phone: str
    code: str = Field(min_length=4, max_length=8)


class UserOut(BaseModel):
    id: int
    name: str
    phone: str | None
    email: str | None

    model_config = {"from_attributes": True}


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class VerifyOtpOut(BaseModel):
    needs_signup: bool
    signup_ticket: str | None = None
    token: TokenOut | None = None


class CompleteSignupIn(BaseModel):
    signup_ticket: str
    name: str = Field(min_length=1, max_length=120)
    email: EmailStr | None = None


class UpdateProfileIn(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=120)
    email: EmailStr | None = None


class DeleteAccountIn(BaseModel):
    code: str = Field(min_length=4, max_length=8)

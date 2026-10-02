from datetime import datetime
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class ErrorBody(StrictModel):
    code: str
    message: str
    retryable: bool = False
    recovery_action: str | None = None
    request_id: str
    field_errors: list[dict[str, Any]] = Field(default_factory=list)


class ErrorEnvelope(StrictModel):
    error: ErrorBody


class LoginRequest(StrictModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=256)


class RefreshRequest(StrictModel):
    refresh_token: str = Field(min_length=1, max_length=4096)


class UserSummary(StrictModel):
    id: UUID
    role: Literal["admin", "staff"]
    display_name: str
    staff_id: UUID | None = None
    enabled: bool
    timezone: str
    enrolment_status: str | None = None


class AuthResponse(StrictModel):
    user: UserSummary
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"
    expires_in: int = 900


class StaffCreate(StrictModel):
    name: str = Field(min_length=1, max_length=100)
    employee_id: str = Field(min_length=1, max_length=32, pattern=r"^[A-Za-z0-9_-]+$")

    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str) -> str:
        cleaned = " ".join(value.split())
        if not cleaned:
            raise ValueError("Name cannot be blank")
        return cleaned

    @field_validator("employee_id")
    @classmethod
    def canonical_employee_id(cls, value: str) -> str:
        return value.strip().upper()


class StaffResponse(StrictModel):
    id: UUID
    name: str
    employee_id: str
    enabled: bool
    account_status: str
    enrolment_status: str
    created_at: datetime
    updated_at: datetime


class StaffPage(StrictModel):
    items: list[StaffResponse]
    next_cursor: str | None = None


class CaptureSessionRequest(StrictModel):
    consent_version: str = Field(min_length=1, max_length=64)
    consent_accepted: bool = True


class CaptureSessionResponse(StrictModel):
    id: UUID
    purpose: Literal["attendance", "enrolment"]
    issued_at: datetime
    expires_at: datetime
    image_count: int
    max_image_bytes: int
    policy_id: str = "attendance-v1"
    timezone: str


class LocationInput(StrictModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    accuracy_m: float = Field(gt=0, le=100)
    captured_at: datetime
    is_mocked: bool = False


class AttendanceMetadata(StrictModel):
    capture_session_id: UUID
    selfie_captured_at: datetime
    location: LocationInput
    consent_version: str = Field(min_length=1, max_length=64)


class AttendanceReceipt(StrictModel):
    id: UUID
    staff_id: UUID
    status: Literal["accepted"] = "accepted"
    recorded_at: datetime
    attendance_date: str
    timezone: str
    selfie_image_id: UUID
    location: LocationInput
    verification: dict[str, Any]


class AttendancePage(StrictModel):
    items: list[AttendanceReceipt]
    next_cursor: str | None = None


class EnrolmentResponse(StrictModel):
    staff_id: UUID
    status: Literal["active"] = "active"
    version: int = 1
    model_id: str


class OperationResponse(StrictModel):
    key: UUID
    state: Literal["succeeded"]
    result: AttendanceReceipt


class ImageAccessResponse(StrictModel):
    url: str
    expires_at: datetime

from dataclasses import dataclass, field
from datetime import UTC, date, datetime
from enum import StrEnum
from uuid import UUID, uuid4


def utc_now() -> datetime:
    return datetime.now(UTC)


class Role(StrEnum):
    ADMIN = "admin"
    STAFF = "staff"


class DomainError(Exception):
    def __init__(self, code: str, message: str, status_code: int = 400) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status_code = status_code


@dataclass(frozen=True)
class Principal:
    id: UUID
    role: Role
    display_name: str
    staff_id: UUID | None = None
    enabled: bool = True


@dataclass
class Staff:
    id: UUID
    name: str
    employee_id: str
    enabled: bool = True
    profile_id: UUID | None = None
    enrolled_template: bytes | None = None
    created_at: datetime = field(default_factory=utc_now)
    updated_at: datetime = field(default_factory=utc_now)

    @property
    def account_status(self) -> str:
        return "provisioned" if self.profile_id else "not_provisioned"

    @property
    def enrolment_status(self) -> str:
        return "active" if self.enrolled_template else "not_enrolled"


@dataclass(frozen=True)
class CaptureSession:
    id: UUID
    actor_id: UUID
    staff_id: UUID
    purpose: str
    expires_at: datetime
    consumed: bool = False


@dataclass(frozen=True)
class LocationEvidence:
    latitude: float
    longitude: float
    accuracy_m: float
    captured_at: datetime
    is_mocked: bool


@dataclass(frozen=True)
class Attendance:
    id: UUID
    staff_id: UUID
    recorded_at: datetime
    attendance_date: date
    timezone: str
    location: LocationEvidence
    selfie_image_id: UUID
    enrolment_version: int = 1
    similarity_score: float = 1.0
    threshold: float = 0.45


@dataclass(frozen=True)
class FaceDecision:
    matched: bool
    template: bytes | None = None
    score: float | None = None
    threshold: float | None = None


def new_id() -> UUID:
    return uuid4()

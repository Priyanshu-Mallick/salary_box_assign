import hashlib
import hmac
from collections.abc import Sequence
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from .domain import Attendance, CaptureSession, DomainError, FaceDecision, Principal, Role, Staff


class DemoAuth:
    """Explicit development adapter. Tokens are opaque process-local values."""

    def __init__(self) -> None:
        self._users = {
            "admin@attendance.example": (
                "Admin123!",
                Principal(UUID("00000000-0000-4000-8000-000000000001"), Role.ADMIN, "Demo Admin"),
            ),
            "staff.a@attendance.example": (
                "Staff123!",
                Principal(
                    UUID("00000000-0000-4000-8000-000000000002"),
                    Role.STAFF,
                    "Demo Staff A",
                    UUID("00000000-0000-4000-8000-000000000102"),
                ),
            ),
        }
        self._access: dict[str, Principal] = {}
        self._refresh: dict[str, Principal] = {}

    async def login(self, email: str, password: str) -> tuple[str, str, Principal]:
        record = self._users.get(email.lower())
        if record is None or not hmac.compare_digest(record[0], password):
            raise DomainError("INVALID_CREDENTIALS", "Invalid email or password", 401)
        principal = record[1]
        access, refresh = f"demo-access-{uuid4()}", f"demo-refresh-{uuid4()}"
        self._access[access], self._refresh[refresh] = principal, principal
        return access, refresh, principal

    async def authenticate(self, access_token: str) -> Principal:
        principal = self._access.get(access_token)
        if principal is None:
            raise DomainError("UNAUTHENTICATED", "Authentication is required", 401)
        return principal

    async def refresh(self, refresh_token: str) -> tuple[str, str, Principal]:
        principal = self._refresh.pop(refresh_token, None)
        if principal is None:
            raise DomainError("SESSION_EXPIRED", "Please sign in again", 401)
        access, refresh = f"demo-access-{uuid4()}", f"demo-refresh-{uuid4()}"
        self._access[access], self._refresh[refresh] = principal, principal
        return access, refresh, principal

    async def logout(self, access_token: str) -> None:
        self._access.pop(access_token, None)


class MemoryRepository:
    def __init__(self) -> None:
        demo_staff_id = UUID("00000000-0000-4000-8000-000000000102")
        self.staff: dict[UUID, Staff] = {
            demo_staff_id: Staff(
                demo_staff_id,
                "Demo Staff A",
                "DEMO-001",
                profile_id=UUID("00000000-0000-4000-8000-000000000002"),
            )
        }
        self.captures: dict[UUID, CaptureSession] = {}
        self.attendance: dict[UUID, Attendance] = {}
        self.operations: dict[tuple[UUID, UUID], Attendance] = {}

    async def list_staff(self) -> list[Staff]:
        return sorted(self.staff.values(), key=lambda item: (item.created_at, str(item.id)))

    async def create_staff(self, name: str, employee_id: str) -> Staff:
        if any(item.employee_id == employee_id for item in self.staff.values()):
            raise DomainError("EMPLOYEE_ID_EXISTS", "Employee ID already exists", 409)
        item = Staff(uuid4(), name, employee_id)
        self.staff[item.id] = item
        return item

    async def get_staff(self, staff_id: UUID) -> Staff | None:
        return self.staff.get(staff_id)

    async def save_staff(self, staff: Staff, enrolment_image_ids: Sequence[UUID]) -> None:
        self.staff[staff.id] = staff

    async def create_capture(self, capture: CaptureSession) -> None:
        self.captures[capture.id] = capture

    async def get_capture(self, capture_id: UUID) -> CaptureSession | None:
        return self.captures.get(capture_id)

    async def consume_capture(self, capture_id: UUID) -> None:
        item = self.captures[capture_id]
        self.captures[capture_id] = replace(item, consumed=True)

    async def get_attendance_for_date(self, staff_id: UUID, day: object) -> Attendance | None:
        return next(
            (
                a
                for a in self.attendance.values()
                if a.staff_id == staff_id and a.attendance_date == day
            ),
            None,
        )

    async def create_attendance(
        self,
        attendance: Attendance,
        actor_id: UUID,
        operation_key: UUID,
        capture_id: UUID,
    ) -> Attendance:
        replay = self.operations.get((actor_id, operation_key))
        if replay:
            return replay
        existing = await self.get_attendance_for_date(
            attendance.staff_id, attendance.attendance_date
        )
        if existing:
            raise DomainError("ALREADY_MARKED", "Attendance is already marked today", 409)
        self.attendance[attendance.id] = attendance
        self.operations[(actor_id, operation_key)] = attendance
        await self.consume_capture(capture_id)
        return attendance

    async def list_attendance(self, staff_id: UUID) -> list[Attendance]:
        return sorted(
            (a for a in self.attendance.values() if a.staff_id == staff_id),
            key=lambda a: a.recorded_at,
            reverse=True,
        )

    async def get_operation(self, actor_id: UUID, key: UUID) -> Attendance | None:
        return self.operations.get((actor_id, key))


class DemoFaceVerifier:
    """Development-only deterministic adapter; SHA-256 equality is not face recognition."""

    @staticmethod
    def _template(content: bytes) -> bytes:
        if len(content) < 16:
            raise DomainError("INVALID_IMAGE", "Image is too small", 422)
        return hashlib.sha256(content).digest()

    async def enrol(self, images: Sequence[bytes]) -> FaceDecision:
        if len(images) != 3:
            raise DomainError("INVALID_IMAGE_COUNT", "Exactly three images are required", 422)
        templates = [self._template(item) for item in images]
        if len(set(templates)) != 1:
            raise DomainError(
                "INCONSISTENT_FACES",
                "Demo mode requires the same fixture for all three samples",
                422,
            )
        return FaceDecision(True, templates[0])

    async def verify(self, enrolled_template: bytes, image: bytes) -> FaceDecision:
        return FaceDecision(hmac.compare_digest(enrolled_template, self._template(image)))


class MemoryImageStore:
    def __init__(self) -> None:
        self.images: dict[UUID, bytes] = {}

    async def put_attendance_image(self, staff_id: UUID, content: bytes) -> UUID:
        image_id = uuid4()
        self.images[image_id] = content
        return image_id

    async def put_enrolment_images(
        self, staff_id: UUID, contents: Sequence[bytes]
    ) -> Sequence[UUID]:
        result = []
        for content in contents:
            image_id = uuid4()
            self.images[image_id] = content
            result.append(image_id)
        return result

    async def signed_url(self, image_id: UUID, principal: Principal) -> tuple[str, datetime]:
        if image_id not in self.images:
            raise DomainError("IMAGE_NOT_FOUND", "Image was not found", 404)
        return f"memory://{image_id}", datetime.now(UTC) + timedelta(seconds=60)

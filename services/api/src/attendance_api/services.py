from collections.abc import Sequence
from datetime import UTC, datetime, timedelta
from uuid import UUID
from zoneinfo import ZoneInfo

from .domain import (
    Attendance,
    CaptureSession,
    DomainError,
    LocationEvidence,
    Principal,
    Role,
    Staff,
    new_id,
)
from .ports import FaceVerifier, ImageStore, Repository


def require_role(principal: Principal, role: Role) -> None:
    if not principal.enabled:
        raise DomainError("ACCOUNT_DISABLED", "This account is disabled", 403)
    if principal.role != role:
        raise DomainError("FORBIDDEN", "This action is not allowed", 403)


class StaffService:
    def __init__(self, repository: Repository) -> None:
        self.repository = repository

    async def list(self, principal: Principal) -> Sequence[Staff]:
        require_role(principal, Role.ADMIN)
        return await self.repository.list_staff()

    async def create(self, principal: Principal, name: str, employee_id: str) -> Staff:
        require_role(principal, Role.ADMIN)
        return await self.repository.create_staff(name, employee_id)

    async def get(self, principal: Principal, staff_id: UUID) -> Staff:
        require_role(principal, Role.ADMIN)
        item = await self.repository.get_staff(staff_id)
        if item is None:
            raise DomainError("STAFF_NOT_FOUND", "Staff member was not found", 404)
        return item


class EnrolmentService:
    def __init__(
        self, repository: Repository, verifier: FaceVerifier, image_store: ImageStore
    ) -> None:
        self.repository = repository
        self.verifier = verifier
        self.image_store = image_store

    async def enrol(self, principal: Principal, staff_id: UUID, images: list[bytes]) -> Staff:
        require_role(principal, Role.ADMIN)
        staff = await self.repository.get_staff(staff_id)
        if staff is None:
            raise DomainError("STAFF_NOT_FOUND", "Staff member was not found", 404)
        decision = await self.verifier.enrol(images)
        if not decision.template:
            raise DomainError("ENROLMENT_FAILED", "Face enrolment failed", 422)
        staff.enrolled_template = decision.template
        staff.updated_at = datetime.now(UTC)
        image_ids = await self.image_store.put_enrolment_images(staff.id, images)
        await self.repository.save_staff(staff, image_ids)
        return staff


class AttendanceService:
    def __init__(
        self,
        repository: Repository,
        verifier: FaceVerifier,
        image_store: ImageStore,
        timezone_name: str,
    ) -> None:
        self.repository = repository
        self.verifier = verifier
        self.image_store = image_store
        self.timezone_name = timezone_name

    async def create_session(self, principal: Principal) -> CaptureSession:
        require_role(principal, Role.STAFF)
        if principal.staff_id is None:
            raise DomainError("PROFILE_NOT_CONFIGURED", "Staff profile is not linked", 404)
        staff = await self.repository.get_staff(principal.staff_id)
        if staff is None or not staff.enabled:
            raise DomainError("ACCOUNT_DISABLED", "This staff account is disabled", 403)
        if staff.enrolled_template is None:
            raise DomainError("NOT_ENROLLED", "Ask an administrator to enrol your face", 409)
        now = datetime.now(UTC)
        today = now.astimezone(ZoneInfo(self.timezone_name)).date()
        if await self.repository.get_attendance_for_date(staff.id, today):
            raise DomainError("ALREADY_MARKED", "Attendance is already marked today", 409)
        capture = CaptureSession(
            new_id(), principal.id, staff.id, "attendance", now + timedelta(minutes=2)
        )
        await self.repository.create_capture(capture)
        return capture

    async def mark(
        self,
        principal: Principal,
        operation_key: UUID,
        capture_id: UUID,
        image: bytes,
        location: LocationEvidence,
        selfie_captured_at: datetime,
    ) -> Attendance:
        require_role(principal, Role.STAFF)
        existing = await self.repository.get_operation(principal.id, operation_key)
        if existing:
            return existing
        capture = await self.repository.get_capture(capture_id)
        now = datetime.now(UTC)
        if (
            capture is None
            or capture.actor_id != principal.id
            or capture.staff_id != principal.staff_id
        ):
            raise DomainError("CAPTURE_NOT_FOUND", "Capture session was not found", 404)
        if capture.consumed:
            raise DomainError("CAPTURE_USED", "Capture session was already used", 409)
        if capture.expires_at <= now:
            raise DomainError("CAPTURE_EXPIRED", "Capture session expired", 410)
        if location.is_mocked:
            raise DomainError("LOCATION_UNTRUSTED", "Mock location is not accepted", 422)
        for moment in (location.captured_at, selfie_captured_at):
            if moment.tzinfo is None:
                raise DomainError("INVALID_TIMESTAMP", "Capture timestamps require a timezone", 422)
            age = (now - moment.astimezone(UTC)).total_seconds()
            if age > 120 or age < -30:
                raise DomainError("LOCATION_STALE", "Capture evidence is stale", 422)
        if abs((location.captured_at - selfie_captured_at).total_seconds()) > 30:
            raise DomainError(
                "LOCATION_STALE", "Location and selfie must be captured together", 422
            )
        staff = await self.repository.get_staff(capture.staff_id)
        if staff is None or staff.enrolled_template is None:
            raise DomainError("NOT_ENROLLED", "No active face enrolment exists", 409)
        decision = await self.verifier.verify(staff.enrolled_template, image)
        if not decision.matched:
            await self.repository.consume_capture(capture.id)
            raise DomainError("FACE_MISMATCH", "Face does not match the enrolled identity", 422)
        image_id = await self.image_store.put_attendance_image(staff.id, image)
        local_day = now.astimezone(ZoneInfo(self.timezone_name)).date()
        attendance = Attendance(
            new_id(),
            staff.id,
            now,
            local_day,
            self.timezone_name,
            location,
            image_id,
            similarity_score=decision.score or 1.0,
            threshold=decision.threshold or 0.45,
        )
        return await self.repository.create_attendance(
            attendance, principal.id, operation_key, capture.id
        )

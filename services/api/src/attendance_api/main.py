import json
import uuid
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from datetime import UTC, datetime
from typing import Annotated, Any
from uuid import UUID

import httpx
from fastapi import Depends, FastAPI, File, Form, Header, Request, UploadFile
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .adapters import DemoAuth, DemoFaceVerifier, MemoryImageStore, MemoryRepository
from .config import Settings, get_settings
from .domain import Attendance, DomainError, LocationEvidence, Principal, Staff
from .ports import AuthPort, FaceVerifier, ImageStore, Repository
from .schemas import (
    AttendanceMetadata,
    AttendancePage,
    AttendanceReceipt,
    AuthResponse,
    CaptureSessionRequest,
    CaptureSessionResponse,
    EnrolmentResponse,
    ErrorBody,
    ErrorEnvelope,
    ImageAccessResponse,
    LocationInput,
    LoginRequest,
    OperationResponse,
    RefreshRequest,
    StaffCreate,
    StaffPage,
    StaffResponse,
    UserSummary,
)
from .services import AttendanceService, EnrolmentService, StaffService

bearer = HTTPBearer(auto_error=False)


class Container:
    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.http: httpx.AsyncClient | None = None
        self.auth: AuthPort
        self.repository: Repository
        self.images: ImageStore
        if settings.data_provider == "postgres":
            if not all(
                (
                    settings.database_url,
                    settings.supabase_url,
                    settings.supabase_publishable_key,
                    settings.supabase_secret_key,
                    settings.biometric_key,
                    settings.storage_hmac_key,
                )
            ):
                raise RuntimeError("Supabase/PostgreSQL production settings are incomplete")
            from .production_adapters import (
                PostgresRepository,
                SupabaseAuth,
                SupabaseImageStore,
                TemplateCipher,
            )

            assert settings.database_url is not None
            assert settings.supabase_url is not None
            assert settings.supabase_publishable_key is not None
            assert settings.supabase_secret_key is not None
            assert settings.biometric_key is not None
            assert settings.storage_hmac_key is not None
            self.http = httpx.AsyncClient(timeout=30)
            self.repository = PostgresRepository(
                settings.database_url,
                TemplateCipher(settings.biometric_key),
                settings.storage_hmac_key,
            )
            self.auth = SupabaseAuth(
                settings.supabase_url,
                settings.supabase_publishable_key,
                self.repository.principal,
                self.http,
            )
            self.images = SupabaseImageStore(
                settings.supabase_url,
                settings.supabase_secret_key,
                self.repository,
                settings.storage_hmac_key,
                self.http,
            )
        else:
            if settings.auth_provider != "demo":
                raise RuntimeError("Supabase Auth requires the PostgreSQL data provider")
            self.auth = DemoAuth()
            self.repository = MemoryRepository()
            self.images = MemoryImageStore()
        self.verifier: FaceVerifier
        if settings.face_provider == "opencv":
            from .opencv_face import OpenCvFaceVerifier

            self.verifier = OpenCvFaceVerifier(
                settings.face_detector_model, settings.face_recognizer_model
            )
        else:
            self.verifier = DemoFaceVerifier()
        self.staff = StaffService(self.repository)
        self.enrolment = EnrolmentService(self.repository, self.verifier, self.images)
        self.attendance = AttendanceService(
            self.repository, self.verifier, self.images, settings.organization_timezone
        )

    async def close(self) -> None:
        if self.http is not None:
            await self.http.aclose()


def user_response(
    principal: Principal, settings: Settings, staff: Staff | None = None
) -> UserSummary:
    return UserSummary(
        id=principal.id,
        role=principal.role.value,
        display_name=principal.display_name,
        staff_id=principal.staff_id,
        enabled=principal.enabled,
        timezone=settings.organization_timezone,
        enrolment_status=staff.enrolment_status if staff else None,
    )


def staff_response(item: Staff) -> StaffResponse:
    return StaffResponse(
        id=item.id,
        name=item.name,
        employee_id=item.employee_id,
        enabled=item.enabled,
        account_status=item.account_status,
        enrolment_status=item.enrolment_status,
        created_at=item.created_at,
        updated_at=item.updated_at,
    )


def attendance_response(item: Attendance) -> AttendanceReceipt:
    return AttendanceReceipt(
        id=item.id,
        staff_id=item.staff_id,
        recorded_at=item.recorded_at,
        attendance_date=item.attendance_date.isoformat(),
        timezone=item.timezone,
        selfie_image_id=item.selfie_image_id,
        location=LocationInput(
            latitude=item.location.latitude,
            longitude=item.location.longitude,
            accuracy_m=item.location.accuracy_m,
            captured_at=item.location.captured_at,
            is_mocked=item.location.is_mocked,
        ),
        verification={"result": "matched", "enrolment_version": item.enrolment_version},
    )


def create_app(settings: Settings | None = None) -> FastAPI:
    selected = settings or get_settings()

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        app.state.container = Container(selected)
        try:
            yield
        finally:
            await app.state.container.close()

    app = FastAPI(
        title="Attendance API",
        version="0.1.0",
        docs_url="/docs" if selected.app_env != "production" else None,
        openapi_url="/openapi.json",
        lifespan=lifespan,
    )

    def container(request: Request) -> Container:
        return request.app.state.container  # type: ignore[no-any-return]

    async def principal(
        credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
        services: Annotated[Container, Depends(container)],
    ) -> Principal:
        if credentials is None or credentials.scheme.lower() != "bearer":
            raise DomainError("UNAUTHENTICATED", "Authentication is required", 401)
        return await services.auth.authenticate(credentials.credentials)

    @app.middleware("http")
    async def request_id_middleware(request: Request, call_next: Any) -> Any:
        incoming = request.headers.get("x-request-id", "")
        request_id = incoming if len(incoming) <= 64 and incoming.isalnum() else str(uuid.uuid4())
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        response.headers["Cache-Control"] = "no-store"
        return response

    @app.exception_handler(DomainError)
    async def domain_error(request: Request, error: DomainError) -> JSONResponse:
        body = ErrorEnvelope(
            error=ErrorBody(
                code=error.code,
                message=error.message,
                request_id=request.state.request_id,
                retryable=error.status_code >= 500,
            )
        )
        return JSONResponse(status_code=error.status_code, content=body.model_dump(mode="json"))

    @app.exception_handler(RequestValidationError)
    async def validation_error(request: Request, error: RequestValidationError) -> JSONResponse:
        field_errors = [
            {"path": ".".join(str(part) for part in item["loc"]), "message": item["msg"]}
            for item in error.errors()
        ]
        body = ErrorEnvelope(
            error=ErrorBody(
                code="VALIDATION_ERROR",
                message="Request validation failed",
                request_id=request.state.request_id,
                field_errors=field_errors,
            )
        )
        return JSONResponse(status_code=422, content=body.model_dump(mode="json"))

    @app.get("/api/v1/health/live")
    async def live() -> dict[str, str]:
        return {"status": "alive"}

    @app.get("/api/v1/health/ready")
    async def ready() -> dict[str, str]:
        return {"status": "ready", "mode": selected.app_env}

    @app.post("/api/v1/auth/login", response_model=AuthResponse)
    async def login(
        body: LoginRequest, services: Annotated[Container, Depends(container)]
    ) -> AuthResponse:
        access, refresh, user = await services.auth.login(body.email, body.password)
        staff = await services.repository.get_staff(user.staff_id) if user.staff_id else None
        return AuthResponse(
            user=user_response(user, services.settings, staff),
            access_token=access,
            refresh_token=refresh,
        )

    @app.post("/api/v1/auth/refresh", response_model=AuthResponse)
    async def refresh(
        body: RefreshRequest, services: Annotated[Container, Depends(container)]
    ) -> AuthResponse:
        access, refresh_token, user = await services.auth.refresh(body.refresh_token)
        staff = await services.repository.get_staff(user.staff_id) if user.staff_id else None
        return AuthResponse(
            user=user_response(user, services.settings, staff),
            access_token=access,
            refresh_token=refresh_token,
        )

    @app.post("/api/v1/auth/logout", status_code=204)
    async def logout(
        credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
        services: Annotated[Container, Depends(container)],
    ) -> None:
        if credentials is None:
            raise DomainError("UNAUTHENTICATED", "Authentication is required", 401)
        await services.auth.authenticate(credentials.credentials)
        await services.auth.logout(credentials.credentials)

    @app.get("/api/v1/me", response_model=UserSummary)
    async def me(
        user: Annotated[Principal, Depends(principal)],
        services: Annotated[Container, Depends(container)],
    ) -> UserSummary:
        staff = await services.repository.get_staff(user.staff_id) if user.staff_id else None
        return user_response(user, services.settings, staff)

    @app.get("/api/v1/staff", response_model=StaffPage)
    async def list_staff(
        user: Annotated[Principal, Depends(principal)],
        services: Annotated[Container, Depends(container)],
    ) -> StaffPage:
        return StaffPage(items=[staff_response(item) for item in await services.staff.list(user)])

    @app.post("/api/v1/staff", response_model=StaffResponse, status_code=201)
    async def create_staff(
        body: StaffCreate,
        user: Annotated[Principal, Depends(principal)],
        services: Annotated[Container, Depends(container)],
        idempotency_key: Annotated[str | None, Header()] = None,
    ) -> StaffResponse:
        if idempotency_key is None:
            raise DomainError("IDEMPOTENCY_KEY_REQUIRED", "Idempotency-Key is required", 400)
        try:
            UUID(idempotency_key)
        except ValueError as error:
            raise DomainError(
                "INVALID_IDEMPOTENCY_KEY", "Idempotency-Key must be a UUID", 400
            ) from error
        return staff_response(await services.staff.create(user, body.name, body.employee_id))

    @app.get("/api/v1/staff/{staff_id}", response_model=StaffResponse)
    async def get_staff(
        staff_id: UUID,
        user: Annotated[Principal, Depends(principal)],
        services: Annotated[Container, Depends(container)],
    ) -> StaffResponse:
        return staff_response(await services.staff.get(user, staff_id))

    @app.post(
        "/api/v1/staff/{staff_id}/face-enrolments",
        response_model=EnrolmentResponse,
        status_code=201,
    )
    async def enrol(
        staff_id: UUID,
        user: Annotated[Principal, Depends(principal)],
        services: Annotated[Container, Depends(container)],
        image_1: Annotated[UploadFile, File()],
        image_2: Annotated[UploadFile, File()],
        image_3: Annotated[UploadFile, File()],
    ) -> EnrolmentResponse:
        images = []
        for image in (image_1, image_2, image_3):
            if image.content_type != "image/jpeg":
                raise DomainError("UNSUPPORTED_MEDIA_TYPE", "Only JPEG images are accepted", 415)
            content = await image.read(services.settings.max_upload_bytes + 1)
            if len(content) > services.settings.max_upload_bytes:
                raise DomainError("UPLOAD_TOO_LARGE", "Image exceeds the upload limit", 413)
            images.append(content)
        item = await services.enrolment.enrol(user, staff_id, images)
        return EnrolmentResponse(staff_id=item.id, model_id="demo-sha256-fixture")

    @app.post("/api/v1/attendance-sessions", response_model=CaptureSessionResponse, status_code=201)
    async def attendance_session(
        body: CaptureSessionRequest,
        user: Annotated[Principal, Depends(principal)],
        services: Annotated[Container, Depends(container)],
    ) -> CaptureSessionResponse:
        if not body.consent_accepted:
            raise DomainError("CONSENT_REQUIRED", "Consent is required", 422)
        capture = await services.attendance.create_session(user)
        return CaptureSessionResponse(
            id=capture.id,
            purpose="attendance",
            issued_at=datetime.now(UTC),
            expires_at=capture.expires_at,
            image_count=1,
            max_image_bytes=services.settings.max_upload_bytes,
            timezone=services.settings.organization_timezone,
        )

    @app.post("/api/v1/attendance", response_model=AttendanceReceipt, status_code=201)
    async def mark_attendance(
        user: Annotated[Principal, Depends(principal)],
        services: Annotated[Container, Depends(container)],
        metadata: Annotated[str, Form()],
        selfie: Annotated[UploadFile, File()],
        idempotency_key: Annotated[str | None, Header()] = None,
    ) -> AttendanceReceipt:
        if idempotency_key is None:
            raise DomainError("IDEMPOTENCY_KEY_REQUIRED", "Idempotency-Key is required", 400)
        try:
            key = UUID(idempotency_key)
            parsed = AttendanceMetadata.model_validate(json.loads(metadata))
        except (json.JSONDecodeError, ValueError) as error:
            raise DomainError("INVALID_METADATA", "Attendance metadata is invalid", 422) from error
        if selfie.content_type != "image/jpeg":
            raise DomainError("UNSUPPORTED_MEDIA_TYPE", "Only JPEG images are accepted", 415)
        image = await selfie.read(services.settings.max_upload_bytes + 1)
        if len(image) > services.settings.max_upload_bytes:
            raise DomainError("UPLOAD_TOO_LARGE", "Image exceeds the upload limit", 413)
        location = LocationEvidence(**parsed.location.model_dump())
        item = await services.attendance.mark(
            user, key, parsed.capture_session_id, image, location, parsed.selfie_captured_at
        )
        return attendance_response(item)

    @app.get("/api/v1/attendance", response_model=AttendancePage)
    async def history(
        user: Annotated[Principal, Depends(principal)],
        services: Annotated[Container, Depends(container)],
        staff_id: UUID | None = None,
    ) -> AttendancePage:
        selected_staff_id = user.staff_id
        if user.role.value == "admin":
            if staff_id is None:
                raise DomainError("STAFF_ID_REQUIRED", "Admin history requires a staff filter", 422)
            selected_staff_id = staff_id
        if selected_staff_id is None:
            raise DomainError("PROFILE_NOT_CONFIGURED", "Staff profile is not linked", 404)
        items = await services.repository.list_attendance(selected_staff_id)
        return AttendancePage(items=[attendance_response(item) for item in items])

    @app.post("/api/v1/images/{image_id}/access", response_model=ImageAccessResponse)
    async def image_access(
        image_id: UUID,
        user: Annotated[Principal, Depends(principal)],
        services: Annotated[Container, Depends(container)],
    ) -> ImageAccessResponse:
        url, expires_at = await services.images.signed_url(image_id, user)
        return ImageAccessResponse(url=url, expires_at=expires_at)

    @app.get("/api/v1/operations/{key}", response_model=OperationResponse)
    async def operation(
        key: UUID,
        user: Annotated[Principal, Depends(principal)],
        services: Annotated[Container, Depends(container)],
    ) -> OperationResponse:
        item = await services.repository.get_operation(user.id, key)
        if item is None:
            raise DomainError("OPERATION_NOT_FOUND", "Operation was not found", 404)
        return OperationResponse(key=key, state="succeeded", result=attendance_response(item))

    return app


app = create_app()

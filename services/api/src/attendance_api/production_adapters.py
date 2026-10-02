import base64
import hmac
import io
from collections.abc import Awaitable, Callable, Sequence
from datetime import UTC, date, datetime, timedelta
from typing import Any
from uuid import UUID, uuid4

import httpx
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from psycopg import AsyncConnection
from psycopg.rows import dict_row

from .domain import Attendance, CaptureSession, DomainError, Principal, Role, Staff


class TemplateCipher:
    def __init__(self, encoded_key: str, key_version: str = "v1") -> None:
        try:
            key = base64.urlsafe_b64decode(encoded_key)
        except ValueError as error:
            raise RuntimeError("BIOMETRIC_KEY must be URL-safe base64") from error
        if len(key) != 32:
            raise RuntimeError("BIOMETRIC_KEY must decode to exactly 32 bytes")
        self._cipher = AESGCM(key)
        self.key_version = key_version

    def encrypt(self, content: bytes, staff_id: UUID, enrolment_id: UUID) -> tuple[bytes, bytes]:
        nonce = __import__("os").urandom(12)
        associated = f"{staff_id}:{enrolment_id}".encode()
        return self._cipher.encrypt(nonce, content, associated), nonce

    def decrypt(self, content: bytes, nonce: bytes, staff_id: UUID, enrolment_id: UUID) -> bytes:
        associated = f"{staff_id}:{enrolment_id}".encode()
        return self._cipher.decrypt(nonce, content, associated)


class PostgresRepository:
    def __init__(self, database_url: str, cipher: TemplateCipher, operation_hmac_key: str) -> None:
        self._database_url = database_url.replace("postgresql+psycopg://", "postgresql://")
        self._cipher = cipher
        self._operation_key = operation_hmac_key.encode()

    async def _connect(self) -> AsyncConnection[dict[str, Any]]:
        return await AsyncConnection.connect(self._database_url, row_factory=dict_row)

    async def principal(self, profile_id: UUID) -> Principal:
        async with await self._connect() as connection:
            row = await (
                await connection.execute(
                    """
                    select p.id, p.role::text role, p.display_name, p.enabled, s.id staff_id
                    from app_private.profiles p
                    left join app_private.staff s on s.profile_id = p.id
                    where p.id = %s
                    """,
                    (profile_id,),
                )
            ).fetchone()
        if row is None:
            raise DomainError("PROFILE_NOT_CONFIGURED", "Account profile is not configured", 403)
        return Principal(
            row["id"], Role(row["role"]), row["display_name"], row["staff_id"], row["enabled"]
        )

    def _staff(self, row: dict[str, Any]) -> Staff:
        template = None
        if row.get("template_ciphertext") is not None:
            template = self._cipher.decrypt(
                bytes(row["template_ciphertext"]),
                bytes(row["template_nonce"]),
                row["id"],
                row["enrolment_id"],
            )
        return Staff(
            row["id"],
            row["name"],
            row["employee_id"],
            row["enabled"],
            row["profile_id"],
            template,
            row["created_at"],
            row["updated_at"],
        )

    @staticmethod
    def _staff_query(where: str = "") -> str:
        return f"""
            select s.*, e.id enrolment_id, e.template_ciphertext, e.template_nonce
            from app_private.staff s
            left join app_private.face_enrolments e
              on e.staff_id = s.id and e.status = 'active'
            {where}
        """

    async def list_staff(self) -> Sequence[Staff]:
        async with await self._connect() as connection:
            rows = await (
                await connection.execute(self._staff_query("order by s.created_at, s.id"))
            ).fetchall()
        return [self._staff(row) for row in rows]

    async def create_staff(self, name: str, employee_id: str) -> Staff:
        async with await self._connect() as connection:
            try:
                row = await (
                    await connection.execute(
                        """
                        insert into app_private.staff(name, employee_id)
                        values (%s, %s)
                        returning *
                        """,
                        (name, employee_id),
                    )
                ).fetchone()
            except Exception as error:
                if getattr(error, "sqlstate", None) == "23505":
                    raise DomainError(
                        "EMPLOYEE_ID_EXISTS", "Employee ID already exists", 409
                    ) from error
                raise
        assert row is not None
        row["enrolment_id"] = None
        row["template_ciphertext"] = None
        row["template_nonce"] = None
        return self._staff(row)

    async def get_staff(self, staff_id: UUID) -> Staff | None:
        async with await self._connect() as connection:
            row = await (
                await connection.execute(self._staff_query("where s.id = %s"), (staff_id,))
            ).fetchone()
        return self._staff(row) if row else None

    async def save_staff(self, staff: Staff, enrolment_image_ids: Sequence[UUID]) -> None:
        if staff.enrolled_template is None:
            return
        if len(enrolment_image_ids) != 3:
            raise DomainError("INVALID_IMAGE_COUNT", "Exactly three images are required", 422)
        enrolment_id = uuid4()
        ciphertext, nonce = self._cipher.encrypt(staff.enrolled_template, staff.id, enrolment_id)
        async with await self._connect() as connection, connection.transaction():
            locked_staff = await (
                await connection.execute(
                    "select id from app_private.staff where id = %s for update", (staff.id,)
                )
            ).fetchone()
            if locked_staff is None:
                raise DomainError("STAFF_NOT_FOUND", "Staff member was not found", 404)
            current = await (
                await connection.execute(
                    """select coalesce(max(version), 0) version
                       from app_private.face_enrolments where staff_id = %s""",
                    (staff.id,),
                )
            ).fetchone()
            consent = await (
                await connection.execute(
                    """
                    insert into app_private.consents
                      (staff_id, purpose, notice_version, source)
                    values (%s, 'enrolment', 'demo-privacy-v1', 'admin_attestation')
                    on conflict (staff_id, purpose, notice_version) where withdrawn_at is null
                    do update set acknowledged_at = now()
                    returning id
                    """,
                    (staff.id,),
                )
            ).fetchone()
            assert current is not None
            assert consent is not None
            await connection.execute(
                """
                update app_private.face_enrolments
                set status = 'retired', retired_at = now(), template_ciphertext = null,
                    template_nonce = null, key_version = null, updated_at = now()
                where staff_id = %s and status = 'active'
                """,
                (staff.id,),
            )
            await connection.execute(
                """
                insert into app_private.face_enrolments
                  (id, staff_id, version, status, model_id, model_sha256,
                   preprocessing_version, policy_id, dimension, template_ciphertext,
                   template_nonce, key_version, consent_id)
                values (%s, %s, %s, 'active', 'sface-2021dec',
                        '0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79',
                        'opencv-aligncrop-v1', 'attendance-v1', 128, %s, %s, %s, %s)
                """,
                (
                    enrolment_id,
                    staff.id,
                    int(current["version"]) + 1,
                    ciphertext,
                    nonce,
                    self._cipher.key_version,
                    consent["id"],
                ),
            )
            updated = await (
                await connection.execute(
                    """
                    update app_private.image_objects
                    set enrolment_id = %s, state = 'attached', updated_at = now()
                    where id = any(%s) and staff_id = %s and purpose = 'enrolment'
                      and state = 'staging'
                    returning id
                    """,
                    (enrolment_id, list(enrolment_image_ids), staff.id),
                )
            ).fetchall()
            if len(updated) != 3:
                raise DomainError(
                    "ENROLMENT_STORAGE_FAILED", "Enrolment images are incomplete", 503
                )

    async def create_capture(self, capture: CaptureSession) -> None:
        async with await self._connect() as connection, connection.transaction():
            enrolment = await (
                await connection.execute(
                    """select id from app_private.face_enrolments
                       where staff_id = %s and status = 'active'""",
                    (capture.staff_id,),
                )
            ).fetchone()
            if enrolment is None:
                raise DomainError("NOT_ENROLLED", "No active face enrolment exists", 409)
            consent = await (
                await connection.execute(
                    """
                    insert into app_private.consents
                      (staff_id, purpose, notice_version, acknowledged_by, source)
                    values (%s, 'attendance', 'demo-privacy-v1', %s, 'staff_acknowledgement')
                    on conflict (staff_id, purpose, notice_version) where withdrawn_at is null
                    do update set acknowledged_at = now()
                    returning id
                    """,
                    (capture.staff_id, capture.actor_id),
                )
            ).fetchone()
            assert consent is not None
            await connection.execute(
                """
                insert into app_private.capture_sessions
                  (id, actor_id, staff_id, purpose, enrolment_id, consent_id,
                   policy_id, expires_at)
                values (%s, %s, %s, %s, %s, %s, 'attendance-v1', %s)
                """,
                (
                    capture.id,
                    capture.actor_id,
                    capture.staff_id,
                    capture.purpose,
                    enrolment["id"],
                    consent["id"],
                    capture.expires_at,
                ),
            )

    async def get_capture(self, capture_id: UUID) -> CaptureSession | None:
        async with await self._connect() as connection:
            row = await (
                await connection.execute(
                    "select * from app_private.capture_sessions where id = %s", (capture_id,)
                )
            ).fetchone()
        if row is None:
            return None
        return CaptureSession(
            row["id"],
            row["actor_id"],
            row["staff_id"],
            row["purpose"],
            row["expires_at"],
            row["state"] == "consumed",
        )

    async def consume_capture(self, capture_id: UUID) -> None:
        async with await self._connect() as connection:
            await connection.execute(
                """update app_private.capture_sessions
                   set state = 'consumed', consumed_at = now() where id = %s""",
                (capture_id,),
            )

    async def get_attendance_for_date(self, staff_id: UUID, day: object) -> Attendance | None:
        if not isinstance(day, date):
            return None
        async with await self._connect() as connection:
            row = await (
                await connection.execute(
                    """select * from app_private.attendance
                       where staff_id = %s and attendance_date = %s""",
                    (staff_id, day),
                )
            ).fetchone()
        return self._attendance(row) if row else None

    def _attendance(self, row: dict[str, Any]) -> Attendance:
        from .domain import LocationEvidence

        return Attendance(
            row["id"],
            row["staff_id"],
            row["recorded_at"],
            row["attendance_date"],
            row["timezone"],
            LocationEvidence(
                row["latitude"],
                row["longitude"],
                row["accuracy_m"],
                row["location_captured_at"],
                row["location_is_mocked"],
            ),
            row["selfie_image_id"],
            similarity_score=row["cosine_score"],
            threshold=row["threshold"],
        )

    async def create_attendance(
        self,
        attendance: Attendance,
        actor_id: UUID,
        operation_key: UUID,
        capture_id: UUID,
    ) -> Attendance:
        request_hmac = hmac.digest(self._operation_key, operation_key.bytes, "sha256")
        async with await self._connect() as connection, connection.transaction():
            capture = await (
                await connection.execute(
                    """select * from app_private.capture_sessions
                       where id = %s and actor_id = %s and staff_id = %s
                         and state = 'issued' for update""",
                    (capture_id, actor_id, attendance.staff_id),
                )
            ).fetchone()
            if capture is None:
                raise DomainError("CAPTURE_NOT_FOUND", "Capture session was not found", 404)
            try:
                await connection.execute(
                    """
                    insert into app_private.attendance
                      (id, staff_id, capture_session_id, enrolment_id, selfie_image_id,
                       consent_id, recorded_at, attendance_date, timezone, selfie_captured_at,
                       latitude, longitude, accuracy_m, location_captured_at,
                       location_is_mocked, cosine_score, threshold, policy_id)
                    values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                            %s, %s, %s, %s, %s, %s, %s, 'attendance-v1')
                    """,
                    (
                        attendance.id,
                        attendance.staff_id,
                        capture["id"],
                        capture["enrolment_id"],
                        attendance.selfie_image_id,
                        capture["consent_id"],
                        attendance.recorded_at,
                        attendance.attendance_date,
                        attendance.timezone,
                        attendance.recorded_at,
                        attendance.location.latitude,
                        attendance.location.longitude,
                        attendance.location.accuracy_m,
                        attendance.location.captured_at,
                        attendance.location.is_mocked,
                        attendance.similarity_score,
                        attendance.threshold,
                    ),
                )
            except Exception as error:
                if getattr(error, "sqlstate", None) == "23505":
                    raise DomainError(
                        "ALREADY_MARKED", "Attendance is already marked today", 409
                    ) from error
                raise
            await connection.execute(
                "update app_private.image_objects set state = 'attached' where id = %s",
                (attendance.selfie_image_id,),
            )
            await connection.execute(
                """update app_private.capture_sessions
                   set state = 'consumed', consumed_at = now() where id = %s""",
                (capture_id,),
            )
            await connection.execute(
                """
                insert into app_private.operations
                  (actor_id, key, route, request_hmac, request_hmac_key_version,
                   state, processing_deadline, http_status, resource_type,
                   resource_id, expires_at)
                values (%s, %s, '/attendance', %s, 'v1', 'succeeded', now(),
                        201, 'attendance', %s, now() + interval '7 days')
                on conflict (actor_id, key) do nothing
                """,
                (actor_id, operation_key, request_hmac, attendance.id),
            )
        return attendance

    async def list_attendance(self, staff_id: UUID) -> Sequence[Attendance]:
        async with await self._connect() as connection:
            rows = await (
                await connection.execute(
                    """select * from app_private.attendance where staff_id = %s
                       order by recorded_at desc limit 50""",
                    (staff_id,),
                )
            ).fetchall()
        return [self._attendance(row) for row in rows]

    async def get_operation(self, actor_id: UUID, key: UUID) -> Attendance | None:
        async with await self._connect() as connection:
            row = await (
                await connection.execute(
                    """select a.* from app_private.operations o
                       join app_private.attendance a on a.id = o.resource_id
                       where o.actor_id = %s and o.key = %s and o.state = 'succeeded'""",
                    (actor_id, key),
                )
            ).fetchone()
        return self._attendance(row) if row else None


class SupabaseAuth:
    def __init__(
        self,
        base_url: str,
        publishable_key: str,
        principal_loader: Callable[[UUID], Awaitable[Principal]],
        client: httpx.AsyncClient,
    ) -> None:
        self._url = base_url.rstrip("/")
        self._key = publishable_key
        self._principal_loader = principal_loader
        self._client = client

    async def _principal_from_token(self, access_token: str) -> Principal:
        response = await self._client.get(
            f"{self._url}/auth/v1/user",
            headers={"apikey": self._key, "Authorization": f"Bearer {access_token}"},
        )
        if response.status_code != 200:
            raise DomainError("UNAUTHENTICATED", "Authentication is required", 401)
        return await self._principal_loader(UUID(response.json()["id"]))

    async def login(self, email: str, password: str) -> tuple[str, str, Principal]:
        response = await self._client.post(
            f"{self._url}/auth/v1/token",
            params={"grant_type": "password"},
            headers={"apikey": self._key},
            json={"email": email, "password": password},
        )
        if response.status_code != 200:
            raise DomainError("INVALID_CREDENTIALS", "Invalid email or password", 401)
        data = response.json()
        principal = await self._principal_from_token(data["access_token"])
        return data["access_token"], data["refresh_token"], principal

    async def authenticate(self, access_token: str) -> Principal:
        return await self._principal_from_token(access_token)

    async def refresh(self, refresh_token: str) -> tuple[str, str, Principal]:
        response = await self._client.post(
            f"{self._url}/auth/v1/token",
            params={"grant_type": "refresh_token"},
            headers={"apikey": self._key},
            json={"refresh_token": refresh_token},
        )
        if response.status_code != 200:
            raise DomainError("SESSION_EXPIRED", "Please sign in again", 401)
        data = response.json()
        principal = await self._principal_from_token(data["access_token"])
        return data["access_token"], data["refresh_token"], principal

    async def logout(self, access_token: str) -> None:
        response = await self._client.post(
            f"{self._url}/auth/v1/logout",
            headers={"apikey": self._key, "Authorization": f"Bearer {access_token}"},
        )
        if response.status_code not in (200, 204, 401):
            raise DomainError("LOGOUT_FAILED", "Could not revoke the session", 503)


class SupabaseImageStore:
    def __init__(
        self,
        base_url: str,
        secret_key: str,
        repository: PostgresRepository,
        hmac_key: str,
        client: httpx.AsyncClient,
    ) -> None:
        self._url = base_url.rstrip("/")
        self._secret = secret_key
        self._repository = repository
        self._hmac_key = hmac_key.encode()
        self._client = client

    def _admin_headers(self, **extra: str) -> dict[str, str]:
        headers = {"apikey": self._secret, **extra}
        # Legacy service-role keys are JWTs and Storage expects them as bearer
        # tokens. Current sb_secret_* keys belong only in the apikey header.
        if self._secret.startswith("eyJ"):
            headers["Authorization"] = f"Bearer {self._secret}"
        return headers

    async def put_attendance_image(self, staff_id: UUID, content: bytes) -> UUID:
        return await self._put(
            staff_id, content, bucket="attendance-images", purpose="attendance", sample_index=None
        )

    async def put_enrolment_images(
        self, staff_id: UUID, contents: Sequence[bytes]
    ) -> Sequence[UUID]:
        if len(contents) != 3:
            raise DomainError("INVALID_IMAGE_COUNT", "Exactly three images are required", 422)
        result = []
        for index, content in enumerate(contents, start=1):
            result.append(
                await self._put(
                    staff_id,
                    content,
                    bucket="enrolment-images",
                    purpose="enrolment",
                    sample_index=index,
                )
            )
        return result

    async def _put(
        self,
        staff_id: UUID,
        content: bytes,
        *,
        bucket: str,
        purpose: str,
        sample_index: int | None,
    ) -> UUID:
        from PIL import Image, ImageOps

        image = ImageOps.exif_transpose(Image.open(io.BytesIO(content))).convert("RGB")
        image.thumbnail((1280, 1280))
        width, height = image.size
        output = io.BytesIO()
        image.save(output, format="JPEG", quality=85, optimize=True)
        content = output.getvalue()
        image_id = uuid4()
        path = f"{staff_id}/{datetime.now(UTC):%Y/%m/%d}/{image_id}.jpg"
        response = await self._client.post(
            f"{self._url}/storage/v1/object/{bucket}/{path}",
            headers=self._admin_headers(**{"Content-Type": "image/jpeg", "x-upsert": "false"}),
            content=content,
        )
        if response.status_code not in (200, 201):
            raise DomainError("STORAGE_UNAVAILABLE", "Selfie storage is unavailable", 503)
        try:
            async with await self._repository._connect() as connection:
                await connection.execute(
                    """
                    insert into app_private.image_objects
                      (id, staff_id, bucket, object_key, purpose, state, content_hmac,
                       hmac_key_version, byte_size, width, height, sample_index,
                       retention_until)
                    values (%s, %s, %s, %s, %s, 'staging',
                            %s, 'v1', %s, %s, %s, %s,
                            now() + case when %s = 'attendance' then interval '30 days'
                                         else interval '7 days' end)
                    """,
                    (
                        image_id,
                        staff_id,
                        bucket,
                        path,
                        purpose,
                        hmac.digest(self._hmac_key, content, "sha256"),
                        len(content),
                        width,
                        height,
                        sample_index,
                        purpose,
                    ),
                )
        except Exception:
            await self._client.delete(
                f"{self._url}/storage/v1/object/{bucket}/{path}",
                headers=self._admin_headers(),
            )
            raise
        return image_id

    async def signed_url(self, image_id: UUID, principal: Principal) -> tuple[str, datetime]:
        async with await self._repository._connect() as connection:
            row = await (
                await connection.execute(
                    """
                    select i.bucket, i.object_key, i.staff_id, i.deleted_at
                    from app_private.image_objects i
                    where i.id = %s and i.state = 'attached'
                    """,
                    (image_id,),
                )
            ).fetchone()
        if row is None or row["deleted_at"] is not None:
            raise DomainError("IMAGE_NOT_FOUND", "Image was not found", 404)
        if principal.role == Role.STAFF and row["staff_id"] != principal.staff_id:
            raise DomainError("IMAGE_NOT_FOUND", "Image was not found", 404)
        response = await self._client.post(
            f"{self._url}/storage/v1/object/sign/{row['bucket']}/{row['object_key']}",
            headers=self._admin_headers(),
            json={"expiresIn": 60},
        )
        if response.status_code != 200:
            raise DomainError("STORAGE_UNAVAILABLE", "Image access is unavailable", 503)
        signed_path = response.json().get("signedURL") or response.json().get("signedUrl")
        if not isinstance(signed_path, str):
            raise DomainError("STORAGE_UNAVAILABLE", "Image access is unavailable", 503)
        url = signed_path if signed_path.startswith("http") else f"{self._url}{signed_path}"
        return url, datetime.now(UTC) + timedelta(seconds=60)

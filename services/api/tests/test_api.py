from datetime import UTC, datetime
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from attendance_api.config import Settings
from attendance_api.main import create_app


@pytest.fixture
async def client() -> AsyncClient:
    app = create_app(
        Settings(
            app_env="test",
            auth_provider="demo",
            data_provider="memory",
            face_provider="demo",
        )
    )
    async with (
        app.router.lifespan_context(app),
        AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as value,
    ):
        yield value


async def login(client: AsyncClient, email: str, password: str) -> dict[str, object]:
    response = await client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert response.status_code == 200, response.text
    return response.json()


@pytest.mark.asyncio
async def test_health_and_structured_validation_error(client: AsyncClient) -> None:
    assert (await client.get("/api/v1/health/live")).json() == {"status": "alive"}
    response = await client.post("/api/v1/auth/login", json={})
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"
    assert response.headers["x-request-id"]


@pytest.mark.asyncio
async def test_admin_staff_flow_and_staff_authorization(client: AsyncClient) -> None:
    admin = await login(client, "admin@attendance.example", "Admin123!")
    admin_headers = {"Authorization": f"Bearer {admin['access_token']}"}
    created = await client.post(
        "/api/v1/staff",
        json={"name": " Demo  Two ", "employee_id": "demo-002"},
        headers={**admin_headers, "Idempotency-Key": str(uuid4())},
    )
    assert created.status_code == 201, created.text
    assert created.json()["employee_id"] == "DEMO-002"
    assert created.json()["account_status"] == "not_provisioned"

    listed = await client.get("/api/v1/staff", headers=admin_headers)
    assert listed.status_code == 200
    assert len(listed.json()["items"]) == 2

    staff = await login(client, "staff.a@attendance.example", "Staff123!")
    forbidden = await client.get(
        "/api/v1/staff", headers={"Authorization": f"Bearer {staff['access_token']}"}
    )
    assert forbidden.status_code == 403
    assert forbidden.json()["error"]["code"] == "FORBIDDEN"


@pytest.mark.asyncio
async def test_attendance_is_server_authorized_idempotent_and_daily_unique(
    client: AsyncClient,
) -> None:
    admin = await login(client, "admin@attendance.example", "Admin123!")
    staff = await login(client, "staff.a@attendance.example", "Staff123!")
    admin_headers = {"Authorization": f"Bearer {admin['access_token']}"}
    staff_headers = {"Authorization": f"Bearer {staff['access_token']}"}
    staff_id = staff["user"]["staff_id"]  # type: ignore[index]
    fixture = b"fixture-jpeg-content-for-deterministic-test"

    enrolled = await client.post(
        f"/api/v1/staff/{staff_id}/face-enrolments",
        headers=admin_headers,
        files={
            "image_1": ("one.jpg", fixture, "image/jpeg"),
            "image_2": ("two.jpg", fixture, "image/jpeg"),
            "image_3": ("three.jpg", fixture, "image/jpeg"),
        },
    )
    assert enrolled.status_code == 201, enrolled.text

    capture_response = await client.post(
        "/api/v1/attendance-sessions",
        headers=staff_headers,
        json={"consent_version": "demo-privacy-v1", "consent_accepted": True},
    )
    assert capture_response.status_code == 201, capture_response.text
    now = datetime.now(UTC).isoformat()
    metadata = {
        "capture_session_id": capture_response.json()["id"],
        "selfie_captured_at": now,
        "location": {
            "latitude": 12.0,
            "longitude": 77.0,
            "accuracy_m": 25,
            "captured_at": now,
            "is_mocked": False,
        },
        "consent_version": "demo-privacy-v1",
    }
    operation_key = str(uuid4())
    marked = await client.post(
        "/api/v1/attendance",
        headers={**staff_headers, "Idempotency-Key": operation_key},
        data={"metadata": __import__("json").dumps(metadata)},
        files={"selfie": ("selfie.jpg", fixture, "image/jpeg")},
    )
    assert marked.status_code == 201, marked.text
    assert marked.json()["status"] == "accepted"
    assert marked.json()["timezone"] == "Asia/Kolkata"

    replay = await client.get(f"/api/v1/operations/{operation_key}", headers=staff_headers)
    assert replay.status_code == 200
    assert replay.json()["result"]["id"] == marked.json()["id"]

    duplicate = await client.post(
        "/api/v1/attendance-sessions",
        headers=staff_headers,
        json={"consent_version": "demo-privacy-v1", "consent_accepted": True},
    )
    assert duplicate.status_code == 409
    assert duplicate.json()["error"]["code"] == "ALREADY_MARKED"

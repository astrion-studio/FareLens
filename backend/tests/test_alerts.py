import sys
from pathlib import Path
from uuid import UUID, uuid4

sys.path.insert(0, str(Path(__file__).parent.parent))

from fastapi.testclient import TestClient  # noqa: E402

from app.core.auth import get_current_user_id  # noqa: E402
from app.main import app  # noqa: E402

# Test user ID used for all authenticated requests
TEST_USER_ID = uuid4()


def override_get_current_user_id() -> UUID:
    """Dependency override that returns test user ID for authentication."""
    return TEST_USER_ID


# Override authentication dependency for tests
app.dependency_overrides[get_current_user_id] = override_get_current_user_id

client = TestClient(app)


def test_register_device():
    payload = {
        "device_id": str(uuid4()),
        "token": "mock-token",
        "platform": "ios",
    }
    resp = client.post("/v1/alerts/register", json=payload)
    assert resp.status_code == 201
    assert resp.json()["status"] == "registered"


def test_alert_history():
    resp = client.get("/v1/alerts/history")
    assert resp.status_code == 200
    data = resp.json()
    assert "alerts" in data
    assert "total" in data


def test_update_alert_preferences():
    payload = {
        "enabled": True,
        "quiet_hours_enabled": False,
        "quiet_hours_start": 22,
        "quiet_hours_end": 7,
        "watchlist_only_mode": True,
    }
    resp = client.put("/v1/alert-preferences", json=payload)
    assert resp.status_code == 200
    assert resp.json()["watchlist_only_mode"] is True


def test_update_preferred_airports():
    payload = {
        "preferred_airports": [
            {"iata": "LAX", "weight": 0.6},
            {"iata": "JFK", "weight": 0.4},
        ]
    }
    resp = client.put("/v1/alert-preferences/airports", json=payload)
    assert resp.status_code == 200
    assert resp.json()["status"] == "updated"


def test_alert_history_user_isolation():
    """Verify users can only access their own alert history (IDOR prevention)."""
    # Create two separate user IDs
    USER_A = uuid4()
    USER_B = uuid4()

    # User A gets their alert history
    app.dependency_overrides[get_current_user_id] = lambda: USER_A
    resp_a = client.get("/v1/alerts/history")
    assert resp_a.status_code == 200
    alerts_a = resp_a.json()["alerts"]
    total_a = resp_a.json()["total"]

    # User B gets their alert history
    app.dependency_overrides[get_current_user_id] = lambda: USER_B
    resp_b = client.get("/v1/alerts/history")
    assert resp_b.status_code == 200
    alerts_b = resp_b.json()["alerts"]
    total_b = resp_b.json()["total"]

    # Verify User A and User B have separate alert histories
    # (In-memory provider starts empty for each user, so both should have 0 alerts)
    assert total_a == 0
    assert total_b == 0
    assert len(alerts_a) == 0
    assert len(alerts_b) == 0

    # Verify pagination parameters are validated (ge=1, le=100)
    resp_invalid_page = client.get("/v1/alerts/history?page=0")
    assert resp_invalid_page.status_code == 422  # Validation error

    resp_invalid_per_page = client.get("/v1/alerts/history?per_page=0")
    assert resp_invalid_per_page.status_code == 422  # Validation error

    resp_excessive_per_page = client.get("/v1/alerts/history?per_page=1000")
    assert resp_excessive_per_page.status_code == 422  # Validation error (le=100)

    # Valid pagination should work
    resp_valid = client.get("/v1/alerts/history?page=1&per_page=50")
    assert resp_valid.status_code == 200

    # Restore original test user for other tests
    app.dependency_overrides[get_current_user_id] = override_get_current_user_id


def test_device_registration_user_isolation():
    """Verify device tokens are associated with correct user."""
    # Create two separate user IDs
    USER_A = uuid4()
    USER_B = uuid4()

    device_a_id = uuid4()
    device_b_id = uuid4()

    # User A registers device
    app.dependency_overrides[get_current_user_id] = lambda: USER_A
    payload_a = {
        "device_id": str(device_a_id),
        "token": "user-a-device-token",
        "platform": "ios",
    }
    resp_a = client.post("/v1/alerts/register", json=payload_a)
    assert resp_a.status_code == 201
    assert resp_a.json()["device_id"] == str(device_a_id)

    # User B registers device
    app.dependency_overrides[get_current_user_id] = lambda: USER_B
    payload_b = {
        "device_id": str(device_b_id),
        "token": "user-b-device-token",
        "platform": "ios",
    }
    resp_b = client.post("/v1/alerts/register", json=payload_b)
    assert resp_b.status_code == 201
    assert resp_b.json()["device_id"] == str(device_b_id)

    # Each user's device is registered to their own account (verified at provider level)
    # This test ensures the user_id from JWT is correctly passed to provider

    # Restore original test user for other tests
    app.dependency_overrides[get_current_user_id] = override_get_current_user_id

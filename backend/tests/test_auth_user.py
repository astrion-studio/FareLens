import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402

client = TestClient(app)


def test_signup_signin_flow() -> None:
    signup = client.post(
        "/v1/auth/signup",
        json={"email": "tester@example.com", "password": "Secret123"},
    )
    assert signup.status_code == 201
    token = signup.json()["token"]
    assert token.startswith("mock-signup-token")

    signin = client.post(
        "/v1/auth/signin",
        json={"email": "tester@example.com", "password": "Secret123"},
    )
    assert signin.status_code == 200
    assert "token" in signin.json()


def test_reset_password() -> None:
    resp = client.post(
        "/v1/auth/reset-password",
        json={"email": "tester@example.com"},
    )
    assert resp.status_code == 202


def test_user_update() -> None:
    """Test user profile update endpoint."""
    update = client.patch(
        "/v1/user",
        json={"timezone": "America/New_York"},
    )
    assert update.status_code == 200
    assert update.json()["timezone"] == "America/New_York"


# APNS token registration test moved to test_alerts.py
# Endpoint consolidated to POST /v1/alerts/register (canonical API endpoint)

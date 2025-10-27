import sys
from pathlib import Path
from uuid import uuid4

sys.path.insert(0, str(Path(__file__).parent.parent))

from app.main import app
from fastapi.testclient import TestClient

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

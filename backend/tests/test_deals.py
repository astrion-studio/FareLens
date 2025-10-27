import sys
from pathlib import Path
from uuid import UUID

sys.path.insert(0, str(Path(__file__).parent.parent))

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402

client = TestClient(app)


def test_list_deals():
    resp = client.get("/v1/deals")
    assert resp.status_code == 200
    data = resp.json()
    assert "deals" in data
    assert isinstance(data["deals"], list)


def test_deal_detail():
    listing = client.get("/v1/deals").json()
    first = listing["deals"][0]
    deal_id = first["id"]
    detail = client.get(f"/v1/deals/{deal_id}")
    assert detail.status_code == 200
    payload = detail.json()
    assert payload["id"] == deal_id
    # Validate UUID format
    UUID(deal_id)


def test_background_refresh():
    resp = client.get("/v1/deals/background-refresh")
    if resp.status_code != 200:
        print(f"Error response: {resp.json()}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "ok"
    assert "refreshed_at" in data

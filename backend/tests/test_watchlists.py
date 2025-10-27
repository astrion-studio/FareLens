import sys
from pathlib import Path
from uuid import UUID

sys.path.insert(0, str(Path(__file__).parent.parent))

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_watchlist_crud_flow():
    # List existing
    initial = client.get("/v1/watchlists")
    assert initial.status_code == 200
    count = len(initial.json())

    # Create
    payload = {
        "name": "Test Watchlist",
        "origin": "SFO",
        "destination": "CDG",
        "max_price": 750,
        "is_active": True,
    }
    create = client.post("/v1/watchlists", json=payload)
    assert create.status_code == 201
    body = create.json()
    watchlist_id = body["id"]
    UUID(watchlist_id)

    # Update
    update = client.put(
        f"/v1/watchlists/{watchlist_id}",
        json={"max_price": 700, "is_active": False},
    )
    assert update.status_code == 200
    assert update.json()["max_price"] == 700
    assert update.json()["is_active"] is False

    # Delete
    delete = client.delete(f"/v1/watchlists/{watchlist_id}")
    assert delete.status_code == 204

    final = client.get("/v1/watchlists")
    assert len(final.json()) == count

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


def test_watchlist_user_isolation():
    """Verify users can only access their own watchlists (IDOR prevention)."""
    # Create two separate user IDs
    USER_A = uuid4()
    USER_B = uuid4()

    # User A creates a watchlist
    app.dependency_overrides[get_current_user_id] = lambda: USER_A
    payload = {
        "name": "User A Watchlist",
        "origin": "LAX",
        "destination": "JFK",
        "max_price": 500,
        "is_active": True,
    }
    resp_create = client.post("/v1/watchlists", json=payload)
    assert resp_create.status_code == 201
    watchlist_a_id = resp_create.json()["id"]

    # User A sees their watchlist
    resp_a_list = client.get("/v1/watchlists")
    assert resp_a_list.status_code == 200
    watchlist_ids_a = [w["id"] for w in resp_a_list.json()]
    assert watchlist_a_id in watchlist_ids_a

    # User B switches context
    app.dependency_overrides[get_current_user_id] = lambda: USER_B

    # User B cannot see User A's watchlist
    resp_b_list = client.get("/v1/watchlists")
    assert resp_b_list.status_code == 200
    watchlist_ids_b = [w["id"] for w in resp_b_list.json()]
    assert watchlist_a_id not in watchlist_ids_b

    # User B cannot update User A's watchlist (idempotent - returns 200 but doesn't actually update)
    resp_b_update = client.put(
        f"/v1/watchlists/{watchlist_a_id}",
        json={"max_price": 999, "is_active": False},
    )
    # Implementation is idempotent for update - returns 200 but doesn't modify watchlist
    assert resp_b_update.status_code == 200

    # User B cannot delete User A's watchlist (idempotent - returns 204 but doesn't actually delete)
    resp_b_delete = client.delete(f"/v1/watchlists/{watchlist_a_id}")
    assert resp_b_delete.status_code == 204

    # Verify User A's watchlist still exists and unchanged
    app.dependency_overrides[get_current_user_id] = lambda: USER_A
    resp_a_verify = client.get("/v1/watchlists")
    assert resp_a_verify.status_code == 200
    user_a_watchlists = [w for w in resp_a_verify.json() if w["id"] == watchlist_a_id]
    assert len(user_a_watchlists) == 1
    assert user_a_watchlists[0]["max_price"] == 500  # Not changed to 999
    assert user_a_watchlists[0]["is_active"] is True  # Not changed to False

    # Clean up - User A deletes their own watchlist
    resp_cleanup = client.delete(f"/v1/watchlists/{watchlist_a_id}")
    assert resp_cleanup.status_code == 204

    # Restore original test user for other tests
    app.dependency_overrides[get_current_user_id] = override_get_current_user_id

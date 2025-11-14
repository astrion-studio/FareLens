"""
Tests for health check endpoints.
"""

import sys
from pathlib import Path

# Add parent directory to path so we can import app
sys.path.insert(0, str(Path(__file__).parent.parent))

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402

client = TestClient(app)


def test_root_endpoint() -> None:
    """Test the root endpoint returns 200 OK."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["service"] == "FareLens API"
    assert "version" in data


def test_health_endpoint() -> None:
    """Test the health endpoint returns 200 OK."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "database" in data
    assert "cache" in data


def test_root_fields() -> None:
    """Test root endpoint has required fields."""
    response = client.get("/")
    data = response.json()
    assert "status" in data
    assert "service" in data
    assert "version" in data


def test_health_fields() -> None:
    """Test health endpoint has required fields."""
    response = client.get("/health")
    data = response.json()
    assert "status" in data
    assert "database" in data
    assert "cache" in data

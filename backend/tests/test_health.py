"""
Tests for health check endpoints.
"""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_root_endpoint():
    """Test the root endpoint returns 200 OK."""
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["service"] == "FareLens API"
    assert "version" in data


def test_health_endpoint():
    """Test the health endpoint returns 200 OK."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "database" in data
    assert "cache" in data


def test_root_fields():
    """Test root endpoint has required fields."""
    response = client.get("/")
    data = response.json()
    assert "status" in data
    assert "service" in data
    assert "version" in data


def test_health_fields():
    """Test health endpoint has required fields."""
    response = client.get("/health")
    data = response.json()
    assert "status" in data
    assert "database" in data
    assert "cache" in data

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_endpoint_returns_healthy_status():
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}


def test_ready_endpoint_returns_ready_status():
    response = client.get("/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


def test_create_incident_returns_created_incident():
    response = client.post(
        "/incidents",
        json={"title": "Database latency issue", "severity": "high"},
    )

    assert response.status_code == 201
    body = response.json()
    assert body["title"] == "Database latency issue"
    assert body["severity"] == "high"
    assert body["status"] == "open"
    assert "id" in body
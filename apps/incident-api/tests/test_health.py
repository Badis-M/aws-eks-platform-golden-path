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


def test_metrics_endpoint_returns_prometheus_metrics():
    response = client.get("/metrics")

    assert response.status_code == 200
    assert "text/plain" in response.headers["content-type"]
    assert "# HELP incident_api_info Incident API application information" in response.text
    assert "# TYPE incident_api_info gauge" in response.text
    assert 'incident_api_info{app="incident-api",version="0.1.0"} 1' in response.text


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
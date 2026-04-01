from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_health() -> None:
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_root() -> None:
    r = client.get("/")
    assert r.status_code == 200
    assert r.json()["message"] == "hello from app"

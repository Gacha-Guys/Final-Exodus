from urllib.parse import parse_qs, urlsplit

import pytest
from fastapi.testclient import TestClient

from src import demo_google
from src.main import app


@pytest.mark.parametrize("port", [8000, 8007])
def test_google_callback_matches_listener(monkeypatch, port):
    monkeypatch.setenv("FINAL_EXODUS_GOOGLE_CLIENT_ID", "test.apps.googleusercontent.com")
    monkeypatch.setenv("FINAL_EXODUS_GOOGLE_CLIENT_SECRET", "test-only")
    client = TestClient(app, base_url=f"http://127.0.0.1:{port}")
    assert client.get("/auth/google/status").json() == {"enabled": True}
    data = client.post("/auth/google/start", headers={"Host": "unrelated.example"}).json()
    try:
        expected = f"http://127.0.0.1:{port}/auth/google/callback"
        assert parse_qs(urlsplit(data["authorization_url"]).query)["redirect_uri"] == [expected]
        assert demo_google.flows[data["flow_id"]].redirect_uri == expected
    finally:
        client.post("/auth/google/cancel", json={k: data[k] for k in ("flow_id", "poll_secret")})


def test_missing_google_credentials_leave_password_login_available(monkeypatch):
    monkeypatch.delenv("FINAL_EXODUS_GOOGLE_CLIENT_SECRET", raising=False)
    client = TestClient(app)
    assert client.get("/auth/google/status").json() == {"enabled": False}
    assert client.post("/auth/google/start").status_code == 503
    assert "/sessions" in client.get("/openapi.json").json()["paths"]

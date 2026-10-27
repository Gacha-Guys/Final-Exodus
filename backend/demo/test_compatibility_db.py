"""Opt-in compatibility acceptance on the same strictly isolated local fixture."""
from uuid import uuid4
from fastapi.testclient import TestClient
from test_demo_integration import isolated_test_accounts, register, PASSWORD
from src.main import app


def test_legacy_name_login_and_session_owned_currency(isolated_test_accounts):
    client = TestClient(app)
    _, body, account = register(isolated_test_accounts, client)
    response = client.post("/login", json={"name": body["email"], "password": PASSWORD})
    assert response.status_code == 200, response.text
    assert response.json()["id"] == account["id"]
    headers = {"Authorization": "Bearer " + response.json()["access_token"]}
    assert client.get("/currency").status_code == 401
    assert client.get("/currency", headers=headers).json() == {"free": 0, "paid": 0}
    assert client.get("/currency", params={"u_id": account["id"] + 1}, headers=headers).status_code == 403
    assert client.post("/currency/update", json={"u_id": account["id"], "amount": 500, "type": "paid"}, headers=headers).status_code == 410
    assert client.get("/currency", headers=headers).json() == {"free": 0, "paid": 0}
    assert client.delete("/sessions/current", headers=headers).status_code == 204
    assert client.get("/currency", headers=headers).status_code == 401


def test_legacy_signup_requires_dob_and_uses_secure_login(isolated_test_accounts):
    client = TestClient(app)
    email = f"compat-{uuid4().hex}@example.com"
    isolated_test_accounts.append(email)
    body = {"name": "Compatibility Player", "email": email, "password": PASSWORD}
    assert client.post("/signup", json=body).status_code == 422
    response = client.post("/signup", json={**body, "dob": "2000-01-01"})
    assert response.status_code == 201, response.text
    assert client.post("/sessions", json={"email": email, "password": PASSWORD}).status_code == 200
    assert client.post("/login", json={"name": email, "password": "wrong"}).status_code == 401

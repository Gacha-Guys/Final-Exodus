"""Opt-in compatibility acceptance on the same strictly isolated local fixture."""
from uuid import uuid4
from fastapi.testclient import TestClient
from test_demo_integration import isolated_test_accounts, register, PASSWORD
from src.main import app


def test_legacy_name_login_and_session_owned_currency(isolated_test_accounts, monkeypatch):
    monkeypatch.setenv("FINAL_EXODUS_ENABLE_CURRENCY_PROTOTYPE", "0")
    client = TestClient(app)
    _, body, account = register(isolated_test_accounts, client)
    response = client.post("/login", json={"name": body["display_name"], "password": PASSWORD})
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


def test_legacy_signup_without_dob_uses_secure_login(isolated_test_accounts):
    client = TestClient(app)
    email = f"compat-{uuid4().hex}@example.com"
    isolated_test_accounts.append(email)
    body = {"name": "Compat-" + uuid4().hex[:12], "email": email, "password": PASSWORD}
    response = client.post("/signup", json=body)
    assert response.status_code == 201, response.text
    assert client.post("/sessions", json={"name": body["name"], "password": PASSWORD}).status_code == 200
    assert client.post("/login", json={"name": body["name"], "password": "wrong"}).status_code == 401


def test_username_identity_survives_rename_without_email_fallback(isolated_test_accounts):
    client = TestClient(app)
    _, body, account = register(isolated_test_accounts, client)
    for route in ("/sessions", "/login"):
        response = client.post(route, json={"name": body["display_name"], "password": PASSWORD})
        assert response.status_code == 200
        assert client.post(route, json={"name": body["email"], "password": PASSWORD}).status_code == 401
        assert client.post(route, json={"email": body["email"], "password": PASSWORD}).status_code == 422
    headers = {"Authorization": "Bearer " + response.json()["access_token"]}
    renamed = "Renamed-" + uuid4().hex[:12]
    saved = client.patch("/me", headers=headers, json={"display_name": renamed})
    assert saved.status_code == 200 and saved.json()["email"] == body["email"]
    for route in ("/sessions", "/login"):
        assert client.post(route, json={"name": body["display_name"], "password": PASSWORD}).status_code == 401
        login = client.post(route, json={"name": renamed, "password": PASSWORD})
        assert login.status_code == 200
        new_headers = {"Authorization": "Bearer " + login.json()["access_token"]}
        assert client.get("/me", headers=new_headers).json()["id"] == account["id"]


def test_duplicate_username_rejected_on_signup_and_rename(isolated_test_accounts):
    client = TestClient(app)
    _, first, account = register(isolated_test_accounts, client)
    _, second, _ = register(isolated_test_accounts, client)
    email = f"duplicate-name-{uuid4().hex}@example.com"
    isolated_test_accounts.append(email)
    for route, field in (("/accounts", "display_name"), ("/signup", "name")):
        result = client.post(route, json={field: first["display_name"], "email": email, "password": "short"})
        assert result.status_code == 409, result.text
    login = client.post("/sessions", json={"name": second["display_name"], "password": PASSWORD})
    headers = {"Authorization": "Bearer " + login.json()["access_token"]}
    assert client.patch("/me", headers=headers, json={"display_name": first["display_name"]}).status_code == 409
    assert client.get("/me", headers=headers).json()["display_name"] == second["display_name"]
    assert client.patch("/me", headers=headers, json={"display_name": second["display_name"]}).status_code == 200
    assert client.post("/login", json={"name": first["display_name"], "password": PASSWORD}).json()["id"] == account["id"]


def test_concurrent_same_username_different_emails(isolated_test_accounts):
    from concurrent.futures import ThreadPoolExecutor
    from src.demo_store import transaction
    name = "ConcurrentName-" + uuid4().hex[:12]
    emails = [f"concurrent-name-{uuid4().hex}@example.com" for _ in range(2)]
    isolated_test_accounts.extend(emails)
    def create(email):
        return TestClient(app).post("/signup", json={"name": name, "email": email, "password": "short"})
    with ThreadPoolExecutor(2) as pool:
        results = list(pool.map(create, emails))
    assert sorted(result.status_code for result in results) == [201, 409]
    with transaction() as cursor:
        cursor.execute("SELECT COUNT(*) AS total FROM Users WHERE name=%s", (name,))
        assert cursor.fetchone()["total"] == 1


def test_concurrent_rename_and_signup_share_username_lock(isolated_test_accounts):
    from concurrent.futures import ThreadPoolExecutor
    from src.demo_store import transaction
    client = TestClient(app)
    _, first, _ = register(isolated_test_accounts, client)
    login = client.post("/sessions", json={"name": first["display_name"], "password": PASSWORD})
    headers = {"Authorization": "Bearer " + login.json()["access_token"]}
    name = "RenameRace-" + uuid4().hex[:12]
    email = f"rename-race-{uuid4().hex}@example.com"
    isolated_test_accounts.append(email)
    actions = [
        lambda: TestClient(app).patch("/me", headers=headers, json={"display_name": name}),
        lambda: TestClient(app).post("/signup", json={"name": name, "email": email, "password": "short"}),
    ]
    with ThreadPoolExecutor(2) as pool:
        results = list(pool.map(lambda action: action(), actions))
    codes = [result.status_code for result in results]
    assert codes in ([200, 409], [409, 201]), [result.text for result in results]
    with transaction() as cursor:
        cursor.execute("SELECT COUNT(*) AS total FROM Users WHERE name=%s", (name,))
        assert cursor.fetchone()["total"] == 1


def test_google_registration_cannot_take_existing_username(isolated_test_accounts, monkeypatch):
    from test_demo_auth import verified_flow
    from src import demo_google as google
    client = TestClient(app)
    _, body, _ = register(isolated_test_accounts, client)
    monkeypatch.setenv("FINAL_EXODUS_GOOGLE_CLIENT_ID", "local-test.apps.googleusercontent.com")
    monkeypatch.setenv("FINAL_EXODUS_GOOGLE_CLIENT_SECRET", "fake-test-client-secret")
    google.flows.clear()
    email = f"google-duplicate-{uuid4().hex}@example.com"
    isolated_test_accounts.append(email)
    who = {"subject": uuid4().hex, "email": email, "display_name": body["display_name"]}
    key = verified_flow(client, monkeypatch, who)
    result = client.post("/auth/google/register", json={**key, "display_name": body["display_name"]})
    assert result.status_code == 409, result.text
    result = client.post("/auth/google/register", json={**key, "display_name": "Google-" + uuid4().hex[:12]})
    assert result.status_code == 200, result.text
    google.flows.clear()


def test_local_currency_prototype_preserves_credit_debit_and_ownership(isolated_test_accounts, monkeypatch):
    client = TestClient(app)
    _, body, account = register(isolated_test_accounts, client)
    login = client.post("/login", json={"name": body["display_name"], "password": PASSWORD})
    headers = {"Authorization": "Bearer " + login.json()["access_token"]}
    monkeypatch.setenv("FINAL_EXODUS_ENABLE_CURRENCY_PROTOTYPE", "1")
    update = {"u_id": account["id"], "type": "paid", "amount": 50}
    assert client.post("/currency/update", json=update).status_code == 401
    assert client.post("/currency/update", json={**update, "u_id": account["id"] + 1}, headers=headers).status_code == 403
    response = client.post("/currency/update", json=update, headers=headers)
    assert response.status_code == 200 and response.json() == {"type": "paid", "count": 50}
    response = client.post("/currency/update", json={**update, "amount": -20}, headers=headers)
    assert response.json() == {"type": "paid", "count": 30}
    assert client.post("/currency/update", json={**update, "amount": -31}, headers=headers).status_code == 453
    assert client.post("/currency/update", json={**update, "type": "invalid"}, headers=headers).status_code == 422
    assert client.post("/currency/update", json={**update, "amount": True}, headers=headers).status_code == 422
    assert client.get("/currency", headers=headers).json() == {"free": 0, "paid": 30}


def test_local_currency_concurrent_debits_do_not_overdraw(isolated_test_accounts, monkeypatch):
    from concurrent.futures import ThreadPoolExecutor
    client = TestClient(app)
    _, body, account = register(isolated_test_accounts, client)
    login = client.post("/login", json={"name": body["display_name"], "password": PASSWORD})
    headers = {"Authorization": "Bearer " + login.json()["access_token"]}
    monkeypatch.setenv("FINAL_EXODUS_ENABLE_CURRENCY_PROTOTYPE", "1")
    update = {"u_id": account["id"], "type": "paid", "amount": 50}
    assert client.post("/currency/update", json=update, headers=headers).status_code == 200
    with ThreadPoolExecutor(2) as pool:
        results = list(pool.map(lambda _: TestClient(app).post("/currency/update", json={**update, "amount": -40}, headers=headers), range(2)))
    assert sorted(result.status_code for result in results) == [200, 453]
    assert client.get("/currency", headers=headers).json()["paid"] == 10

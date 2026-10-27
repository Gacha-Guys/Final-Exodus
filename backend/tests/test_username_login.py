"""Both login routes identify Users.name, with no email fallback."""
from contextlib import contextmanager
from unittest.mock import MagicMock

from fastapi.testclient import TestClient
import pytest

from src import compatibility, demo, demo_accounts
from src.main import app
from src.rate_limit import RegistrationLimiter

PASSWORD = "UsernameLogin!2026"
HASH = demo_accounts.password_hash.hash(PASSWORD)


@pytest.fixture
def cursor(monkeypatch):
    cursor = MagicMock()
    cursor.fetchall.return_value = [{"id": 7, "password": HASH}]
    @contextmanager
    def transaction():
        yield cursor
    for module in (demo_accounts, compatibility):
        monkeypatch.setattr(module, "transaction", transaction)
        monkeypatch.setattr(module, "issue_session", lambda *_: {"access_token": "signed", "token_type": "bearer", "expires_in": 900})
    monkeypatch.setattr(demo, "limiter", RegistrationLimiter(limit=1000))
    return cursor


@pytest.mark.parametrize("route", ["/sessions", "/login"])
def test_username_login_uses_only_name_and_trims_outer_spaces(cursor, route):
    response = TestClient(app).post(route, json={"name": "  PlayerName  ", "password": PASSWORD})
    assert response.status_code == 200
    assert response.json()["access_token"] == "signed"
    sql, parameters = cursor.execute.call_args.args
    assert "WHERE name=%s" in sql and "email" not in sql
    assert parameters == ("PlayerName",)


@pytest.mark.parametrize("route", ["/sessions", "/login"])
def test_email_field_is_not_a_login_identifier(cursor, route):
    response = TestClient(app).post(route, json={"email": "player@example.com", "password": PASSWORD})
    assert response.status_code == 422
    cursor.execute.assert_not_called()


@pytest.mark.parametrize("route", ["/sessions", "/login"])
@pytest.mark.parametrize("name", ["", "   "])
def test_blank_username_never_queries_database(cursor, route, name):
    assert TestClient(app).post(route, json={"name": name, "password": PASSWORD}).status_code == 422
    cursor.execute.assert_not_called()


@pytest.mark.parametrize("route", ["/sessions", "/login"])
def test_unknown_username_and_wrong_password_have_same_error(cursor, route):
    client = TestClient(app)
    wrong = client.post(route, json={"name": "PlayerName", "password": "wrong"})
    cursor.fetchall.return_value = []
    missing = client.post(route, json={"name": "player@example.com", "password": PASSWORD})
    assert wrong.status_code == missing.status_code == 401
    assert wrong.json() == missing.json() == {"detail": "Incorrect username or password"}

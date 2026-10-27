"""Compatibility routes preserve the session boundary without a real database."""
from contextlib import contextmanager
from unittest.mock import MagicMock
from fastapi import HTTPException
from fastapi.testclient import TestClient
import pytest
from src.main import app
from src import compatibility as compat, demo_accounts as accounts


@pytest.fixture
def cursor(monkeypatch):
    cursor = MagicMock()
    @contextmanager
    def transaction():
        yield cursor
    monkeypatch.setattr(compat, "transaction", transaction)
    def authenticate(_, authorization):
        if authorization != "Bearer valid":
            raise HTTPException(401, "Session required")
        return 7
    monkeypatch.setattr(compat, "authenticate", authenticate)
    return cursor


def test_currency_needs_session_and_refuses_other_account(cursor):
    client = TestClient(app)
    assert client.get("/currency?u_id=7").status_code == 401
    assert client.get("/currency?u_id=8", headers={"Authorization": "Bearer valid"}).status_code == 403
    cursor.execute.assert_not_called()


def test_currency_returns_only_session_account(cursor):
    cursor.fetchall.return_value = [{"Type": "free", "count": 12}, {"Type": "paid", "count": 0}]
    response = TestClient(app).get("/currency", headers={"Authorization": "Bearer valid"})
    assert response.status_code == 200 and response.json() == {"free": 12, "paid": 0}
    assert cursor.execute.call_args.args[1] == (7,)


def test_caller_cannot_credit_currency(cursor):
    client = TestClient(app)
    body = {"u_id": 7, "amount": 500, "type": "paid"}
    assert client.post("/currency/update", json=body).status_code == 401
    assert client.post("/currency/update", json=body, headers={"Authorization": "Bearer valid"}).status_code == 410
    cursor.execute.assert_not_called()


def test_legacy_login_issues_session_not_bare_id(cursor, monkeypatch):
    monkeypatch.setattr(compat, "verify_password", lambda *args, **kwargs: 7)
    monkeypatch.setattr(compat, "issue_session", lambda *args: {"access_token": "signed", "token_type": "bearer", "expires_in": 900})
    response = TestClient(app).post("/login", json={"name": "player", "password": "validpassword"})
    assert response.status_code == 200
    assert response.json()["access_token"] == "signed" and response.json()["id"] == 7


@pytest.mark.parametrize("extra", [{}, {"dob": "1800-01-01"}, {"dob": "2000-01-01", "password": "short"}])
def test_signup_cannot_invent_dob_or_bypass_validation(extra, monkeypatch):
    create = MagicMock()
    monkeypatch.setattr(compat, "register", create)
    body = {"name": "Player", "email": "player@example.com", "password": "validpassword", **extra}
    assert TestClient(app).post("/signup", json=body).status_code == 422
    create.assert_not_called()


def test_plaintext_password_is_not_accepted_as_hash():
    cursor = MagicMock()
    cursor.fetchall.return_value = [{"id": 7, "password": "the-old-password"}]
    with pytest.raises(HTTPException) as error:
        accounts.verify_password(cursor, "Player", "the-old-password")
    assert error.value.status_code == 401


def test_ambiguous_username_is_rejected():
    cursor = MagicMock()
    cursor.fetchall.return_value = [{"id": 7, "password": "x"}, {"id": 8, "password": "y"}]
    with pytest.raises(HTTPException) as error:
        accounts.verify_password(cursor, "same name", "password")
    assert error.value.status_code == 401

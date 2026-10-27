"""Storage refusal and readiness checks without a database connection."""
from contextlib import contextmanager
from unittest.mock import MagicMock
import pytest
from fastapi import HTTPException
from src import demo_store as store


def connection(monkeypatch, marker):
    cursor = MagicMock()
    cursor.fetchone.return_value = marker
    conn = MagicMock()
    conn.cursor.return_value.__enter__.return_value = cursor
    connect = MagicMock(return_value=conn)
    monkeypatch.setattr(store.database, "connect", connect)
    return conn, cursor, connect


@pytest.mark.parametrize("profile,host,db", [
    ("local-demo", "remote.invalid", "final_exodus_tyler_demo"),
    ("local-demo", "127.0.0.1", "shared"),
    ("typo", "127.0.0.1", "final_exodus_tyler_demo"),
])
def test_unreviewed_target_refused_before_connect(monkeypatch, profile, host, db):
    monkeypatch.setenv("FINAL_EXODUS_STORAGE_PROFILE", profile)
    monkeypatch.setenv("FINAL_EXODUS_DB_HOST", host)
    monkeypatch.setenv("FINAL_EXODUS_DB", db)
    _, _, connect = connection(monkeypatch, None)
    with pytest.raises(HTTPException) as error:
        with store.transaction():
            pytest.fail("Unsafe storage became available")
    assert error.value.status_code == 503
    connect.assert_not_called()


def test_shared_profile_requires_migration_marker(monkeypatch):
    monkeypatch.setenv("FINAL_EXODUS_STORAGE_PROFILE", "shared-users-v1")
    conn, cursor, _ = connection(monkeypatch, None)
    with pytest.raises(HTTPException) as error:
        with store.transaction():
            pytest.fail("Unmigrated storage became available")
    assert error.value.status_code == 503
    assert "FinalExodusSchemaMigrations" in cursor.execute.call_args.args[0]
    conn.rollback.assert_called_once()
    conn.close.assert_called_once()
    conn.commit.assert_not_called()


def test_shared_profile_ready_commits_after_verified_marker(monkeypatch):
    monkeypatch.setenv("FINAL_EXODUS_STORAGE_PROFILE", "shared-users-v1")
    conn, cursor, _ = connection(monkeypatch, {"version": "shared-users-v1"})
    with store.transaction() as actual:
        assert actual is cursor
    conn.commit.assert_called_once()
    conn.close.assert_called_once()


def test_shared_failed_operation_rolls_back(monkeypatch):
    monkeypatch.setenv("FINAL_EXODUS_STORAGE_PROFILE", "shared-users-v1")
    conn, _, _ = connection(monkeypatch, {"version": "shared-users-v1"})
    with pytest.raises(HTTPException):
        with store.transaction():
            raise HTTPException(401, "Rejected")
    conn.rollback.assert_called_once()
    conn.commit.assert_not_called()


def test_default_profile_keeps_local_guard(monkeypatch):
    monkeypatch.delenv("FINAL_EXODUS_STORAGE_PROFILE", raising=False)
    monkeypatch.setenv("FINAL_EXODUS_DB_HOST", "127.0.0.1")
    monkeypatch.setenv("FINAL_EXODUS_DB", "final_exodus_tyler_demo")
    conn, cursor, _ = connection(monkeypatch, None)
    with store.transaction():
        pass
    cursor.execute.assert_not_called()
    conn.commit.assert_called_once()

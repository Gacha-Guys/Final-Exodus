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


@pytest.mark.parametrize("fail", [False, True])
def test_identity_write_holds_lock_until_commit_or_rollback(monkeypatch, fail):
    monkeypatch.setenv("FINAL_EXODUS_STORAGE_PROFILE", "local-demo")
    monkeypatch.setenv("FINAL_EXODUS_DB_HOST", "127.0.0.1")
    monkeypatch.setenv("FINAL_EXODUS_DB", "final_exodus_tyler_demo")
    conn, cursor, _ = connection(monkeypatch, {"acquired": 1})
    events = []
    cursor.execute.side_effect = lambda sql, *args: events.append("release" if "RELEASE_LOCK" in sql else "acquire")
    conn.commit.side_effect = lambda: events.append("commit")
    conn.rollback.side_effect = lambda: events.append("rollback")
    conn.close.side_effect = lambda: events.append("close")
    if fail:
        with pytest.raises(HTTPException):
            with store.transaction(identity_write=True):
                events.append("write")
                raise HTTPException(409, "Conflict")
    else:
        with store.transaction(identity_write=True):
            events.append("write")
    assert events == ["acquire", "write", "rollback" if fail else "commit", "release", "close"]


@pytest.mark.parametrize("result", [0, None])
def test_identity_lock_timeout_or_unavailable_prevents_write(monkeypatch, result):
    monkeypatch.setenv("FINAL_EXODUS_STORAGE_PROFILE", "local-demo")
    monkeypatch.setenv("FINAL_EXODUS_DB_HOST", "127.0.0.1")
    monkeypatch.setenv("FINAL_EXODUS_DB", "final_exodus_tyler_demo")
    conn, cursor, _ = connection(monkeypatch, {"acquired": result})
    with pytest.raises(HTTPException) as error:
        with store.transaction(identity_write=True):
            pytest.fail("Identity write proceeded without serialization")
    assert error.value.status_code == 503
    conn.commit.assert_not_called()
    conn.rollback.assert_called_once()
    conn.close.assert_called_once()
    assert len(cursor.execute.call_args_list) == 1

import pytest
from src.local_test_target import require_local_test_database


@pytest.mark.parametrize("host,database", [
    ("aiven.invalid", "final_exodus_tyler_demo"),
    ("127.0.0.1", "Final-Exodus-Database"),
    ("localhost", "final_exodus_shared_rehearsal"),
    ("", ""),
])
def test_drivers_refuse_shared_or_unconfigured_storage(monkeypatch, host, database):
    monkeypatch.setenv("FINAL_EXODUS_DB_HOST", host)
    monkeypatch.setenv("FINAL_EXODUS_DB", database)
    with pytest.raises(ValueError, match="never shared Aiven"):
        require_local_test_database()


@pytest.mark.parametrize("host", ["127.0.0.1", "localhost"])
def test_drivers_allow_disposable_loopback_storage(monkeypatch, host):
    monkeypatch.setenv("FINAL_EXODUS_DB_HOST", host)
    monkeypatch.setenv("FINAL_EXODUS_DB", "final_exodus_tyler_demo")
    require_local_test_database()

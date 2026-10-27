"""Migration safety gates without a connection to any real database."""
from unittest.mock import MagicMock

import pytest

from src import shared_schema


def cursor(*, missing=None, dob=False, blank=0, duplicates=0, trigger=1, index=0):
    columns = {
        "Users": {"id", "name", "email", "password", "exp", "level", "gamepass"},
        "Currency": {"u_id", "type", "count"},
    }
    if missing:
        columns[missing[0]].remove(missing[1])
    if dob:
        columns["Users"].add("Dob")
    result = MagicMock()
    result.fetchall.return_value = [(table, column) for table, fields in columns.items() for column in fields]
    result.fetchone.side_effect = [(blank,), (duplicates,), (trigger,), (index,)]
    return result


def executed(result):
    return [call.args[0] for call in result.execute.call_args_list]


@pytest.mark.parametrize("configuration,message", [
    ({"missing": ("Users", "password")}, "existing Users/Currency schema"),
    ({"missing": ("Currency", "count")}, "existing Users/Currency schema"),
    ({"blank": 1}, "valid email addresses"),
    ({"duplicates": 1}, "duplicate normalized email"),
    ({"trigger": 0}, "existing Users insert trigger"),
])
def test_unsafe_source_schema_is_refused_before_any_write(configuration, message):
    result = cursor(**configuration)
    with pytest.raises(ValueError, match=message):
        shared_schema.apply_migration(result)
    assert all(sql.startswith("SELECT ") for sql in executed(result))


def test_dry_run_plans_only_additions_and_never_executes_them():
    result = cursor()
    statements = shared_schema.migration_plan(result)
    assert all(sql.startswith("SELECT ") for sql in executed(result))
    assert "ALTER TABLE Users ADD COLUMN Dob DATE NULL" in statements
    assert any(sql.startswith("CREATE UNIQUE INDEX") for sql in statements)
    assert not any(sql.startswith(("DROP ", "DELETE ", "UPDATE ", "TRUNCATE ")) for sql in statements)


def test_rerun_preserves_existing_columns_index_and_records_version_idempotently():
    result = cursor(dob=True, index=1)
    shared_schema.apply_migration(result)
    writes = [sql for sql in executed(result) if not sql.startswith("SELECT ")]
    assert all(sql.startswith(("CREATE TABLE IF NOT EXISTS ", "INSERT IGNORE ")) for sql in writes)
    assert result.execute.call_args.args == (
        "INSERT IGNORE INTO FinalExodusSchemaMigrations(version) VALUES(%s)",
        (shared_schema.VERSION,),
    )


@pytest.mark.parametrize("failed_query", [
    "CREATE TABLE IF NOT EXISTS DemoBattles",
    "SELECT subject,u_id FROM DemoGoogleIdentities",
])
def test_partial_ddl_or_incompatible_existing_table_never_gets_ready_marker(failed_query):
    result = cursor()
    def execute(sql, *args):
        if sql.startswith(failed_query):
            raise RuntimeError("schema mismatch")
    result.execute.side_effect = execute
    with pytest.raises(RuntimeError, match="schema mismatch"):
        shared_schema.apply_migration(result)
    assert not any(sql.startswith("INSERT IGNORE INTO FinalExodusSchemaMigrations")
                   for sql in executed(result))


def test_readiness_checks_every_adapter_table_before_marking_schema_ready():
    result = cursor()
    shared_schema.apply_migration(result)
    queries = executed(result)
    marker = next(i for i, sql in enumerate(queries) if sql.startswith("INSERT IGNORE "))
    for table in ("Users", "DemoSessions", "DemoBattles", "DemoActions", "DemoGoogleIdentities"):
        assert any(sql.startswith("SELECT ") and f"FROM {table} LIMIT 0" in sql
                   for sql in queries[:marker])

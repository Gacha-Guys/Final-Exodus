# Verification

## Preserved tests and pure regressions

From `backend/` after installing requirements:

```sh
.venv/bin/python -m pytest -q
.venv/bin/python -m pip check
```

Default discovery includes `tests/` and `demo/`. Database modules skip unless explicitly enabled. Original registration/account/scaffold/TLS tests remain alongside gacha selection/inventory rollback, user/unit cap boundaries, secure route compatibility, storage-profile and migration tests. Gacha tests preserve the90/10 category boundary and duplicate inventory behavior. Deprecated dummy authentication stays disabled; real login is tested separately.

## Disposable MySQL integration

Run local setup first. From the checkout root:

```sh
FINAL_EXODUS_RUN_DB_TESTS=1 FINAL_EXODUS_TEST_ENV_FILE="$PWD/backend/.env.demo" backend/.venv/bin/python -m pytest backend -q
backend/.venv/bin/python backend/demo/restart_check.py
backend/.venv/bin/python backend/demo/google_ui_check.py --godot /path/to/Godot
```

On Windows set the two environment variables before running the Python command. Opt-in suites reject remote hosts and any database other than the isolated `final_exodus_tyler_demo`. They cover actual hashing, uniqueness, concurrency, rollback, session isolation/revocation, forged JWTs, saved combat and simulated Google identities. They clean up their synthetic identities. Never point their cleanup at Aiven.

The restart driver uses a separate API process on8008. The Google driver uses8009 with an explicitly simulated provider and no real consent; cryptographic tests independently exercise signature verification. `--no-access-log` keeps provider callback query parameters out of logs.

## Godot4.7.2

```sh
Godot --headless --editor --path frontend --import --quit
Godot --headless --path frontend --script res://tests/team_integration.gd
FINAL_EXODUS_API_ORIGIN=http://127.0.0.1:8007 Godot --headless --path frontend --script res://tests/connected_demo.gd
FINAL_EXODUS_API_ORIGIN=http://127.0.0.1:8007 Godot --headless --path frontend --script res://tests/connected_demo.gd -- --small
```

Start the API first. Inspect import output for script errors even when the process exits0. Run native UI drivers sequentially and inspect screenshots at both sizes; avoid concurrent walkthroughs sharing one IP's production authentication limit. `FINAL_EXODUS_TEST_ARTIFACT_DIR=/absolute/external/path` writes UI JSON/images outside historical checked-in evidence. UI runs create synthetic accounts in the selected development database; cleanup is deliberate.

## Shared migration and smoke checks

Follow SHARED_STORAGE.md: private backup, restore/rehearsal against actual schema, dry-run, explicitly confirmed additive migration, idempotence and preservation checks, then scoped-runtime account/battle checks with authorized disposable identities. Record shared checks separately from the guarded local suites. Aiven smoke checks do not prove a second teammate's machine or public API hosting.

## Historical registration script

`tests/integration_registration.py` still tests the historical `src.accounts` accounts/wallets module with explicitly supplied development credentials. It is excluded from ordinary discovery and is not the supported Users/Currency API acceptance test. Preserve its module/tests without running this old cleanup against the new shared schema.

# Verification

## Preserved tests and pure regressions

From `backend/` after installing requirements:

```sh
.venv/bin/python -m pytest -q
.venv/bin/python -m pip check
```

Default discovery includes `tests/` and `demo/`. Database modules skip unless explicitly enabled. Original registration/account/scaffold/TLS tests remain alongside gacha selection/inventory rollback, user/unit cap boundaries, secure route compatibility, storage-profile and migration tests. Gacha tests preserve the 90/10 category boundary and duplicate inventory behavior. Deprecated dummy authentication stays disabled; real login is tested separately.

## Disposable MySQL integration

Run local setup first. From the checkout root:

```sh
FINAL_EXODUS_RUN_DB_TESTS=1 FINAL_EXODUS_TEST_ENV_FILE="$PWD/backend/.env.demo" backend/.venv/bin/python -m pytest backend -q
backend/.venv/bin/python backend/demo/restart_check.py
backend/.venv/bin/python backend/demo/google_ui_check.py --godot /path/to/Godot
```

On Windows set the two environment variables before running the Python command. Opt-in suites reject remote hosts and any database other than the isolated `final_exodus_tyler_demo`. They cover actual hashing, duplicate username/email rejection, concurrent API identity writes, optional DOB, guarded local currency updates, rollback, session isolation/revocation, forged JWTs, saved combat and simulated Google identities. They clean up their synthetic identities. Never point their cleanup at Aiven.

The restart driver uses a separate API process on 8008. The Google driver uses 8009 with an explicitly simulated provider and no real consent; cryptographic tests independently exercise signature verification. `--no-access-log` keeps provider callback query parameters out of logs.

## Godot 4.7.2

```sh
Godot --headless --editor --path frontend --import
Godot --headless --path frontend --script res://tests/team_integration.gd
FINAL_EXODUS_API_ORIGIN=http://127.0.0.1:8000 Godot --headless --path frontend --script res://tests/team_restoration.gd
FINAL_EXODUS_API_ORIGIN=http://127.0.0.1:8000 Godot --headless --path frontend --script res://tests/team_restoration.gd -- --small
FINAL_EXODUS_API_ORIGIN=http://127.0.0.1:8000 Godot --headless --path frontend --script res://tests/connected_demo.gd
FINAL_EXODUS_API_ORIGIN=http://127.0.0.1:8000 Godot --headless --path frontend --script res://tests/connected_demo.gd -- --small
```

Start the API first, for example `Server.py --env-file .env.demo` on default port 8000. The team-restoration driver covers the normal F5 flow: hidden DOB/Google, three-field signup, duplicate username rejection, successful login remaining on title until Start, guest preview, preserved hub navigation, four gem offers/gamepass, and the four guarded local gem prototypes. The connected-demo driver deliberately starts the separate optional scene and covers fixture combat. Let `--import` finish and quit by itself; adding `--quit` can exit before a fresh clone finishes importing assets. Inspect import output for script errors even when the process exits 0. Run native UI drivers sequentially and inspect screenshots at both sizes. Restart the isolated local test API between walkthrough drivers, or wait at least 60 seconds: their combined signup/login attempts can exceed the 20-attempt authentication limit even when run sequentially. Keep the limiter enabled; do not run concurrent walkthroughs against one test API. `FINAL_EXODUS_TEST_ARTIFACT_DIR=/absolute/external/path` writes UI JSON/images outside historical checked-in evidence. UI runs create synthetic accounts in the selected development database; cleanup is deliberate.

## Shared migration and smoke checks

Follow SHARED_STORAGE.md: private backup, restore/rehearsal against actual schema, dry-run, explicitly confirmed additive migration, idempotence and preservation checks, then scoped-runtime account/battle checks with authorized disposable identities. Record shared checks separately from the guarded local suites. Aiven smoke checks do not prove a second teammate's machine or public API hosting.

## Historical registration script

`tests/integration_registration.py` still tests the historical `src.accounts` accounts/wallets module with explicitly supplied development credentials. It is excluded from ordinary discovery and is not the supported Users/Currency API acceptance test. Preserve its module/tests without running this old cleanup against the new shared schema.

## October 27 teammate-restoration verification

The restored implementation passed **145 backend tests plus 12 subtests** against disposable local MySQL; default discovery passed **101 tests plus 12 subtests**, with three database modules skipped. Godot 4.7.2 passed 22 offline integration checks, 27 restored-team UI checks at each portrait size and 44 optional-combat checks at each size. The simulated Google driver passed 8 checks, and all 5 actual-process restart checks passed. The code commit also passed GitHub CI on Python 3.12 and 3.14, and an actual default-port launcher/client run passed the 27 team-flow checks without an API-origin override. Separate scoped Aiven smoke checks passed 36 checks, including preservation of all nine original table row sets and rejection of shared currency updates even with the local flag set. No new shared DDL was applied during restoration. These checks do not verify a second teammate’s machine, real mobile input, public hosting or a new live Google round trip. Historical October 26 evidence remains in [VALIDATION.md](review/VALIDATION.md).

## PR22/23 integration follow-up

The combined Riley/Mihai/integration candidate preserves Riley's PR22 shop scene exactly and all four Mihai currency amounts (50/200/500/999) inside the existing guarded local prototype. It passes145 backend tests+12subtests,25 offline adapter checks and31 native team-flow checks at each size. These checks supplement the earlier restoration results above. Shared currency updates remain blocked.

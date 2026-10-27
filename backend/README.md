# Final Exodus backend

`src.main:app` is the supported account, session, profile and saved-battle API. It uses the team's `Users`/`Currency` schema, Argon2 password verifiers and JWT sessions. The historical `src.accounts` module remains for its regression tests; its incompatible `accounts`/`wallets` endpoint is not exposed through the supported API.

## Install and run

Use Python 3.14 for the currently verified environment. From `backend/`, create a virtual environment and install `requirements-lock.txt`. On Windows use `.venv\Scripts\python.exe`; on macOS/Linux use `.venv/bin/python`.

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-lock.txt
.venv/bin/python Server.py --env-file .env.demo --port 8007
```

The launcher binds to loopback and loads only the explicitly selected environment file. It does not replace that configuration by importing another `.env`. The Godot client defaults to the same loopback API port. See [local setup](../docs/LOCAL_DEMO.md) and [shared storage](../docs/SHARED_STORAGE.md) for database configuration. Aiven hosts MySQL; it does not host this API process.

## Storage profiles

- `local-demo` (default): only loopback MySQL and `final_exodus_tyler_demo`. `setup_demo.py --admin-env PATH --port 3307` initializes the isolated schema and a private `.env.demo`; an existing configuration is preserved and a mismatched port is refused.
- `shared-users-v1`: deliberately selected for the existing shared Users/Currency schema. Requests require the additive migration's version marker. Remote connections require a CA certificate with certificate and hostname verification. Changing database host alone cannot opt into shared storage.

New accounts require a real DOB; existing rows may retain NULL. Existing non-Argon2 credentials are preserved by migration and cannot authenticate through the new verifier: their owners need a verified password reset. The API never guesses a birth date or accepts a raw-password fallback.

## HTTP contracts

See [DEMO_API.md](../docs/DEMO_API.md) for `/accounts`, `/sessions`, `/me` and battle request/response contracts, which remain the connected client's contract. `/login` accepts the former `name`/`password` request and returns a JWT session plus the account ID; ambiguous names are rejected. `/signup` accepts `name`, `email`, `password`, and mandatory `dob` with the same validation as `/accounts`.

`GET /currency` requires a bearer token; an optional `u_id` must equal that session's account. `POST /currency/update` returns 401 without a valid session and 410 for an authenticated caller. Client-directed currency grants are retired. Shop/payment previews do not grant currency. Rewards and gacha integration remain separate work.

Google sign-in remains optional and uses the configured local callback; the current flow and limiter are single-process. See [AUTHENTICATION.md](../docs/AUTHENTICATION.md). Do not expose a public or multi-worker API without adapting that deployment configuration.

## Verification

```sh
.venv/bin/python -m pytest -q
```

Default tests exercise pure logic, validation, compatibility and refusal paths without a database. The database suites are opt-in and reject remote targets. Run them only against an isolated loopback database, with `FINAL_EXODUS_RUN_DB_TESTS=1` and an explicit optional `FINAL_EXODUS_TEST_ENV_FILE`. Never point test cleanup at shared Aiven. A passing `/health` checks the configured database and migration marker; it does not verify JWT/Google configuration, another teammate's machine or public API reachability. Missing JWT configuration returns 503 when creating a session; Google setup remains independently optional.

Keep `.env` files, database credentials, JWT keys, CA paths and OAuth secrets private. Use an application database user; reserve schema changes and grants for the reviewed migration procedure.

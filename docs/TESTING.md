# Registration tests

## Fast tests — no database or credentials

From `backend/` after installing dependencies:

```sh
python -m pytest -q
```

22 tests cover validation/password boundaries, hashing, forbidden roles, safe responses, rollback, duplicate/database errors, throttling/expiry, health and TLS settings. The three scaffold tests confirm the root route and explicitly disabled login placeholders. Database operations are mocked. These tests do not prove real MySQL constraints or network TLS.

## Real database check — opt in

From `backend/`:

```sh
python tests/integration_registration.py --app-env /private/path/app.env --cleanup-env /private/path/cleanup.env
```

Use a development database only. Both files must target the same database; the cleanup user needs DELETE on test identities. Normal API credentials do not need DELETE. The script races two registrations for a unique email, verifies one account and zero-balance wallet plus password hash, then removes its identity. Requires running Aiven and TLS settings. Ordinary unit discovery excludes this script. If network is lost during cleanup, inspect/remove its `integration-` identity before rerunning.

Godot form and real-device tests are supplied by the separate phone-screen PR.

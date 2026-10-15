# Registration tests

## Fast tests — no database or credentials

From `backend/` after installing dependencies:

```sh
python -m pytest -q
```

22 tests cover validation/password boundaries, hashing, forbidden roles, safe responses, rollback, duplicate/database errors, throttling/expiry, health and TLS settings. The three scaffold tests confirm the root route and explicitly disabled login placeholders. Database operations are mocked. These tests do not prove real MySQL constraints or network TLS.

From the repository root, use your Godot executable (shown here as `godot`):

```sh
godot --headless --path frontend --script res://tests/registration_safety.gd
godot --headless --path frontend --script res://tests/registration_form.gd
```

Safety checks reject unsafe origins and redirects. Form checks use the actual scene with fake transport: no network requests. They cover payload/password handling, pending controls, repeated submit, success/error/timeout/malformed responses and immediate transport failure. They do not verify a physical phone's keyboard or appearance.

## Real database check — opt in

From `backend/`:

```sh
python tests/integration_registration.py --app-env /private/path/app.env --cleanup-env /private/path/cleanup.env
```

Use a development database only. Both files must target the same database; the cleanup user needs DELETE on test identities. Normal API credentials do not need DELETE. The script races two registrations for a unique email, verifies one account and zero-balance wallet plus password hash, then removes its identity. Requires running Aiven and TLS settings. Ordinary unit discovery excludes this script. If network is lost during cleanup, inspect/remove its `integration-` identity before rerunning.

## Manual phone checks

Run the project, expand Developer connection settings, and point it to the API. Check creation, duplicate and validation feedback. Real-device keyboard, scrolling and safe-area checks remain manual. A phone needs a reachable HTTPS API; its localhost cannot reach the laptop backend. Login is separate.

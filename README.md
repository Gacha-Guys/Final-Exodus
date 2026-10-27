# Final Exodus — Cydia Studios

Shared Godot game project for Intro to Software Engineering.

## Run the connected build

Use **Godot 4.7.2 standard** and **Python 3.14** (the verified local version). From `backend/`:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-lock.txt
.venv/bin/python local_setup.py
.venv/bin/python Server.py --env-file .env.demo --port 8007
```

`local_setup.py` requires Docker and creates an isolated MySQL8.4 instance on loopback port3308 with private ignored credentials. On Windows use `.venv\Scripts\python.exe`. Open `frontend/project.godot` in Godot and press Play. Register a new account, log in, enter a battle, then log out/log back in to resume it.

For shared Aiven, use your separately provisioned application configuration and [shared-storage guide](docs/SHARED_STORAGE.md). Aiven hosts the database; each developer still runs the API locally unless a shared HTTPS API is deployed. Credentials stay server-side.

## What's connected

- Riley's title/account popups, shop and gamepass presentation; Jason's hub and shared model/leveling work.
- Mihai's Users/Currency model and trigger, secure login/signup/currency compatibility, and preserved gacha prototype.
- Authenticated profiles, display-name settings, logout, and server-calculated encounters with saved health/results and safe action retries.
- Argon2 password verifiers and revocable15-minute JWTs. Optional Google sign-in has separate local configuration.

Shop/gamepass are previews. Combat uses a fixed three-character party; owned-roster selection, reward payouts, authenticated summons/pity and payments are not implemented by this integration. Existing unsupported password formats need owner-verified resets; migration preserves their rows.

## Project layout and verification

- `frontend/`: Godot scenes, assets, scripts and UI regression drivers.
- `backend/`: supported `src.main:app`, setup/migration tools, preserved tests and new gacha/leveling/auth regressions.
- `docs/`: [setup](docs/SETUP.md), [walkthrough](docs/LOCAL_DEMO.md), [API contract](docs/DEMO_API.md), [authentication](docs/AUTHENTICATION.md), [testing](docs/TESTING.md), and [shared storage](docs/SHARED_STORAGE.md).

The historical registration module remains testable; it is not an alternate public account database. Original sync-test scene and all four individual team check-ins remain available. Use branches and reviewed PRs; preserve authorship and never put private environment files or generated Godot caches in Git.

See the [backend guide](backend/README.md) for launch and compatibility details. The [historical registration contract](docs/ACCOUNTS.md) and [earlier review proposal and evidence](docs/review/PR_DRAFTS.md) remain available for provenance.

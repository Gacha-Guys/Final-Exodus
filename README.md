# Final Exodus — Cydia Studios

Shared Godot game project for Intro to Software Engineering.

## Run the team build

Use **Godot 4.7.2 standard** and **Python 3.14** (the verified local version). From `backend/`:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-lock.txt
.venv/bin/python local_setup.py
.venv/bin/python Server.py --env-file .env.demo
```

`local_setup.py` requires Docker and creates an isolated MySQL 8.4 instance on loopback port 3308 with private ignored credentials. On Windows use `.venv\Scripts\python.exe`. Open `frontend/project.godot` in Godot and press Play. The default API port is **8000**, matching the client. Register with email, username and password, then log in with username/password. Login closes the popup; press **Start** to enter the team hub. Guest Start still opens the hub preview. The shared Aiven launcher defaults to `.env` with `Server.py`.

For shared Aiven, use your separately provisioned application configuration and [shared-storage guide](docs/SHARED_STORAGE.md). Aiven hosts the database; each developer still runs the API locally unless a shared HTTPS API is deployed. Credentials stay server-side.

## What's connected

- Riley’s title/account popups, Story/navigation and four gem offers plus gamepass; Jason’s hub and shared model/leveling work.
- Mihai’s Users/Currency model and trigger, username login and duplicate-username signup protection, and preserved gacha prototype. The first gem button keeps its +50 paid-currency prototype in the guarded isolated local setup.
- Authenticated profiles and protected own-account currency reads. Optional account settings, logout and saved fixture combat remain in separate demo scenes.
- Argon2 password verifiers and revocable 15-minute JWTs. Optional Google sign-in has separate local configuration.

Shared storage refuses client-requested currency grants; the local prototype does not make a real purchase. Open `frontend/scenes/demo_title.tscn` and press **F6** for the separate optional combat/Google demo; F5 retains the team title/hub flow. Optional combat uses a fixed three-character party; owned-roster selection, reward payouts, authenticated summons/pity and payments are not implemented by this integration. Existing unsupported password formats need owner-verified resets; migration preserves their rows.

## Project layout and verification

- `frontend/`: Godot scenes, assets, scripts and UI regression drivers.
- `backend/`: supported `src.main:app`, setup/migration tools, preserved tests and new gacha/leveling/auth regressions.
- `docs/`: [setup](docs/SETUP.md), [walkthrough](docs/LOCAL_DEMO.md), [API contract](docs/DEMO_API.md), [authentication](docs/AUTHENTICATION.md), [testing](docs/TESTING.md), and [shared storage](docs/SHARED_STORAGE.md).

Signup keeps the team’s three visible fields; DOB is optional and hidden. The historical registration module remains testable; it is not an alternate public account database. Original sync-test scene and all four individual team check-ins remain available. Use branches and reviewed PRs; preserve authorship and never put private environment files or generated Godot caches in Git.

See the [backend guide](backend/README.md) for launch and compatibility details. The [historical registration contract](docs/ACCOUNTS.md) and [earlier review proposal and evidence](docs/review/PR_DRAFTS.md) remain available for provenance.

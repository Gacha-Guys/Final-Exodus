# Local development and connected walkthrough

Use Godot4.7.2 standard. The supported API is `src.main:app`; the game defaults to `http://127.0.0.1:8007`. HTTP is accepted only for loopback; other API hosts require HTTPS. An optional `FINAL_EXODUS_API_ORIGIN` changes the client API address.

## Fresh setup

Install Docker, Python and Godot. From `backend/`:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-lock.txt
.venv/bin/python local_setup.py
.venv/bin/python Server.py --env-file .env.demo --port 8007
```

Windows uses `.venv\Scripts\python.exe`. Import `frontend/project.godot` in Godot and press Play. No preloaded review account is assumed: register a new account with a valid birth date and12–128-character password.

`local_setup.py` generates private `.env.mysql-local`, starts project `final-exodus-local` with MySQL8.4 on `127.0.0.1:3308`, and initializes only `final_exodus_tyler_demo` with a scoped application user. Both environment files are ignored; retain them for repeat runs. The database uses a persistent Docker volume. Re-running preserves accounts and battles. Do not delete its volume to troubleshoot a login.

For an existing local MySQL installation, use `setup_demo.py --admin-env /private/local-admin.env --port YOUR_PORT`; the input contains `FINAL_EXODUS_ROOT_PASSWORD`. It refuses mismatched existing configuration. This initializer must never be used against Aiven.

For Aiven, start `Server.py --env-file /private/aiven-game-api.env --port 8007` after the additive migration and scoped credentials are verified. The app environment deliberately selects `shared-users-v1`. Database hosting and a remotely hosted HTTPS API are separate. See SHARED_STORAGE.md.

## Three-to-four-minute walkthrough

| Time | Action |
| --- | --- |
|0:00–0:45|Register a fresh account with email, name, birth date and password.|
|0:45–1:15|Log in with the signup username and show persisted name, rank and actual free/paid balances; optionally change the name in Settings.|
|1:15–1:50|Enter Battle; attack once with Ember, Rowan and Vale. Enemy health reaches52.|
|1:50–2:40|Return to hub, close/reopen the game, log in and resume that same52HP encounter.|
|2:40–3:15|Finish the encounter and return to show one saved victory.|
|3:15–3:40|Show the shop/gamepass previews, then log out.|

No currency/XP payouts are granted by this encounter. The three characters are fixtures rather than the player's owned inventory. Summon, full roster, payment, recovery and quests remain separate work.

## Verification and limits

See TESTING.md for full commands. The ordinary pytest command retains historical tests plus gacha/leveling/auth/storage regressions. Real database suites require explicit opt-in and reject shared targets. API restart and native Godot UI checks exercise the real disposable local MySQL database. Preserve historical evidence by selecting an external `FINAL_EXODUS_TEST_ARTIFACT_DIR` for UI output.

Optional Google sign-in requires private local provider configuration; simulated provider checks do not prove a live Google consent flow. The current callback is loopback8007, and flow state/rate limiting are single-process. Do not expose a public multi-worker API without the corresponding deployment changes. See AUTHENTICATION.md.

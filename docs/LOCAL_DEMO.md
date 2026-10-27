# Local development and connected walkthrough

Use Godot 4.7.2 standard. The supported API is `src.main:app`; the game defaults to `http://127.0.0.1:8000`. HTTP is accepted only for loopback; other API hosts require HTTPS. An optional `FINAL_EXODUS_API_ORIGIN` changes the client API address.

## Fresh setup

Install Docker, Python and Godot. From `backend/`:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-lock.txt
.venv/bin/python local_setup.py
.venv/bin/python Server.py --env-file .env.demo
```

Windows uses `.venv\Scripts\python.exe`. Import `frontend/project.godot` in Godot and press Play. F5 runs the restored team title/account/hub flow. No preloaded account is assumed: register with email, username and a nonempty password of at most 128 characters. DOB remains hidden and optional. Successful username login closes the popup; press Start to enter the hub. Guest Start still opens its preview.

`local_setup.py` generates private `.env.mysql-local`, starts project `final-exodus-local` with MySQL 8.4 on `127.0.0.1:3308`, and initializes only `final_exodus_tyler_demo` with a scoped application user. Both environment files are ignored; retain them for repeat runs. The database uses a persistent Docker volume. Re-running preserves accounts and battles. Do not delete its volume to troubleshoot a login.

For an existing local MySQL installation, use `setup_demo.py --admin-env /private/local-admin.env --port YOUR_PORT`; the input contains `FINAL_EXODUS_ROOT_PASSWORD`. It refuses mismatched existing configuration. This initializer must never be used against Aiven.

For Aiven, start `Server.py --env-file /private/aiven-game-api.env` after the additive migration and scoped credentials are verified. The app environment deliberately selects `shared-users-v1`. Database hosting and a remotely hosted HTTPS API are separate. See SHARED_STORAGE.md.

## Team flow and isolated currency prototype

The normal title/hub/Story navigation and shop retain the team’s presentation: four gem offers and a gamepass. The first gem button calls Mihai’s +50 paid-currency prototype. Local setup enables it only for the exact isolated loopback database with `FINAL_EXODUS_ENABLE_CURRENCY_PROTOTYPE=1`; authenticated updates are limited to the logged-in account, reject negative balances and guard overflow. Shared storage always returns 410 for that update, even with the flag, so the prototype cannot mint shared currency. No real payment is taken.

## Optional three-to-four-minute combat walkthrough

Open `frontend/scenes/demo_title.tscn` and press **F6**. This separate scene opts into fixture combat, Settings/logout and the Google button. It does not replace the F5 team hub or Story/navigation. Shop/Home returns to the normal team hub; rerun the optional scene to return to its combat controls. For Google, use the explicit port 8007 setup in [AUTHENTICATION.md](AUTHENTICATION.md).

| Time | Action |
| --- | --- |
|0:00–0:45|Register a fresh account with email, username and password.|
|0:45–1:15|Log in with the signup username and show persisted name, rank and actual free/paid balances; optionally change the name in Settings.|
|1:15–1:50|Enter Battle; attack once with Ember, Rowan and Vale. Enemy health reaches 52.|
|1:50–2:40|Return to hub, close/reopen the game, log in and resume that same 52 HP encounter.|
|2:40–3:15|Finish the encounter and return to show one saved victory.|
|3:15–3:40|Log out from the optional hub; separately show the team shop/gamepass presentation.|

No currency/XP payouts are granted by this encounter. The three characters are fixtures rather than the player's owned inventory. Summon, full roster, payment, recovery and quests remain separate work.

## Verification and limits

See TESTING.md for full commands. The ordinary pytest command retains historical tests plus gacha/leveling/auth/storage regressions. Real database suites require explicit opt-in and reject shared targets. API restart and native Godot UI checks exercise the real disposable local MySQL database. Preserve historical evidence by selecting an external `FINAL_EXODUS_TEST_ARTIFACT_DIR` for UI output.

Optional Google sign-in requires private local provider configuration; simulated provider checks do not prove a live Google consent flow. The current callback is loopback port 8007, and flow state/rate limiting are single-process. Do not expose a public multi-worker API without the corresponding deployment changes. See AUTHENTICATION.md.

# Local connected demo

Branch: `feature/tyler-connected-demo`

Checkout: `/Users/tylerdang/Documents/GitHub/Final-Exodus-demo`

The demo uses Riley's title/account popups and shop, Jason's hub, and a separate local Python API and MySQL database. Shared Aiven data and teammate branches are untouched.

## Run on Tyler's Mac

Docker's existing `final-exodus-mysql-1` container must be running. Local configuration is already saved privately in `backend/.env.demo`; do not copy it into a PR.

Start the API in one terminal:

```sh
cd /Users/tylerdang/Documents/GitHub/Final-Exodus-demo/backend
.venv/bin/python -m uvicorn src.demo:app --env-file .env.demo --host 127.0.0.1 --port 8007 --no-proxy-headers --no-access-log
```

Open `frontend/project.godot` in Godot **4.7.2 standard** and press Play, or run:

```sh
/Users/tylerdang/Downloads/Godot.app/Contents/MacOS/Godot --path /Users/tylerdang/Documents/GitHub/Final-Exodus-demo/frontend
```

The client defaults to `http://127.0.0.1:8007`. An optional `FINAL_EXODUS_API_ORIGIN` environment variable changes the API origin. HTTP is accepted only for loopback; other hosts require HTTPS.

For a quick review, this synthetic local account exists:

- Email: `tyler.demo@example.com`
- Password: `DemoReview!2026`
- Name: Tyler Connected
- Its partially completed encounter was retained for resume testing. Use a new email to demonstrate registration from scratch.

These are disposable demo credentials, not a real account or a database credential. Closing the game clears its in-memory session. Log in again to load the saved account and battle.

## Fresh local setup

The API uses the existing Python environment on this Mac through an ignored `backend/.venv` symlink. On another machine, create a virtual environment and install `backend/requirements-lock.txt` using the existing backend setup guide.

`backend/setup_demo.py --admin-env /path/to/private/local-admin.env` creates only `final_exodus_tyler_demo` on MySQL at `127.0.0.1:3307`, its scoped application user, and the ignored configuration file. The private input needs `FINAL_EXODUS_ROOT_PASSWORD` for that local instance. The script refuses to reuse an existing database without its configuration. It is not an Aiven migration and must not be repurposed for one.

## JWT and Google sign-in

Email/password now issues a 15-minute JWT; logout still revokes it immediately. Existing accounts and saved battles are preserved. Google sign-in is wired locally, but a real provider login is pending the OAuth client setup in [AUTHENTICATION.md](AUTHENTICATION.md). Re-running local setup adds the Google identity table and a private signing key to an earlier demo installation.

## Three-to-four-minute walkthrough

| Time | Action |
| --- | --- |
| 0:00–0:45 | Create an account with a new email, name, birth date and 12+ character password. |
| 0:45–1:15 | Log in. Show the saved name, rank and actual free/paid balances. Optionally change the name in Settings. |
| 1:15–1:50 | Enter Battle. Attack once with Ember, Rowan and Vale. The enemy now has 52 HP. |
| 1:50–2:40 | Return to the hub, close the game, reopen it, and log in. Resume the same battle at 52 HP. |
| 2:40–3:15 | Finish the encounter. Return to the hub to show one saved victory. |
| 3:15–3:40 | Log out. Explain that rewards, purchases and the full roster remain separate features. |

The API restart and duplicate-request checks were also rehearsed separately; there is no need to interrupt the server during the presentation.

## Verification

From the checkout root:

```sh
backend/.venv/bin/python -m pytest backend/tests backend/demo/test_demo_integration.py backend/demo/test_demo_auth.py -q
backend/.venv/bin/python backend/demo/restart_check.py
/Users/tylerdang/Downloads/Godot.app/Contents/MacOS/Godot --headless --path frontend --script res://tests/connected_demo.gd
```

The integration tests explicitly load `.env.demo`, refuse a remote database, and clean up their synthetic accounts. The UI driver also exercises the real API; it creates disposable `ui-...@example.com` users. Add `-- --small` to run its smaller-window variant. Screenshots and compact results are in `docs/review/`.

## Limits before shared rollout

- Validated locally on macOS, Godot 4.7.2, Python 3.14 and MySQL 8.4. Live Aiven writes and another teammate's machine are not verified.
- This local copy adds unique email enforcement and four demo persistence tables. Shared-schema changes and access grants need separate approval.
- Settings currently changes only the display name. No recovery, email/password changes, payment, gacha integration, or rewards settlement is included.
- The three characters and encounter rules are demo fixtures, not a claim that player-owned inventory is connected. Units/Summon show an unavailable message. Shop/gamepass remain previews.
- The local authentication limiter is single-process. Public hosting would need deployment, access, and rate-limit review.

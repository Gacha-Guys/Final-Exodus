# Supported connected API

`src.main:app` is the supported entrypoint; `src.demo:app` exposes the underlying account/battle application; use `src.main:app` to include the team compatibility routes. The legacy `src.accounts` module remains available for regression tests but is not exposed through this API. Storage defaults to isolated loopback `final_exodus_tyler_demo`; the deliberate shared profile requires the reviewed additive migration. See [SHARED_STORAGE.md](SHARED_STORAGE.md).

`Users` and `Currency` follow Mihai's model. Registration keeps email, username and password, accepts an optional date of birth, stores an Argon2 password verifier in `Users.password`, and relies on the existing insert trigger for free/paid balances. Persistence uses `DemoSessions`, `DemoBattles`, `DemoActions` and `DemoGoogleIdentities`. Existing shared rows retain their IDs, balances and credentials; missing historical DOB may stay NULL. Unsupported legacy password formats require an owner-verified reset, with no plaintext fallback.

All request bodies reject extra fields. Errors use `detail`; validation errors return field names/messages without submitted values. Signed JWT bearer access tokens expire after 15 minutes and remain revocable through the session table. See [AUTHENTICATION.md](AUTHENTICATION.md) for the exact stack, Google setup and current verification limits. Local HTTP is allowed only on loopback; remote use needs HTTPS.

| Method/path | Request | Result |
| --- | --- | --- |
| GET /health | None | Configured database readiness; shared profile also requires migration marker |
| POST /accounts | email, display_name (1–255 trimmed chars), password (1–128 chars), optional dob (YYYY-MM-DD) | 201 account; 409 duplicate username/email |
| POST /sessions | name (username), password | access_token, token_type, expires_in |
| POST /login | name (username), password | Same JWT session plus id; ambiguous names rejected |
| POST /signup | name, email, password, optional dob | Same validation/result as /accounts |
| POST /auth/google/start | None | Browser authorization URL, flow_id, poll_secret, expires_in |
| GET /auth/google/callback | Google code/state (browser only) | Fixed return-to-game page; never returns JWT in URL/HTML |
| POST /auth/google/poll | flow_id, poll_secret | pending, registration_required with suggested display_name, or authenticated with JWT |
| POST /auth/google/register | flow_id, poll_secret, display_name, optional dob | authenticated with JWT for a new verified Google identity |
| POST /auth/google/cancel | flow_id, poll_secret | 204; pending flow invalidated |
| DELETE /sessions/current | Bearer | 204; session revoked |
| GET /me | Bearer | id, email, display_name, level, experience, free_currency, paid_currency, gamepass, completed_battles |
| PATCH /me | Bearer; display_name | Updated account |
| GET /currency | Bearer; optional u_id must equal session account | free and paid balances |
| POST /currency/update | Bearer; amount, type (free/paid), optional u_id matching session | Local opted-in prototype updates own balance; shared storage always 410 |
| POST /battles | Bearer; request_id (UUID) | Existing active battle or new battle |
| GET /battles/current | Bearer | Latest saved battle, or null |
| POST /battles/{id}/actions | Bearer; request_id (UUID), actor (0–2), version | Saved battle after one attack |

The default launcher and client use loopback port **8000**. Signup, Settings rename and Google registration serialize username writes with a database advisory lock and reject duplicate names under the database collation. No unique-name DDL is added; direct SQL writers must honor the same policy. Existing ambiguous names cannot log in. `/account/inventory`, `/account/units` and `/unit` remain explicit 501 placeholders.

The currency prototype requires all of: `local-demo` profile, `FINAL_EXODUS_ENABLE_CURRENCY_PROTOTYPE=1`, loopback DB host and exact database `final_exodus_tyler_demo`. `setup_demo.py` enables that flag for the isolated setup. Updates lock the balance, reject insufficient funds/overflow and cannot target another account. This preserves the teammate’s development interaction without permitting shared client-directed currency grants.

Each optional demo battle contains three fixed demo characters and one enemy. Damage and enemy retaliation are calculated by the server. Every accepted action advances the version. Exact request retries return the original saved response; reusing the ID with different input or acting on stale state returns 409. A session can access only its own battles. Battles, action responses and sessions survive API restarts. No currency or XP is awarded.

The client retains the session only in memory. Closing the client requires another login; the account and battle are loaded from MySQL. The team shop retains four gem offers plus gamepass. Its four gem buttons add 50, 200, 500 or 999 paid currency only in the guarded local prototype; it cannot initiate a payment. The optional fixture-combat UI starts through F6 on `scenes/demo_title.tscn`, separately from the normal F5 team flow.

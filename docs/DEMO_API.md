# Supported connected API

`src.main:app` is the supported entrypoint; `src.demo:app` remains an alias for the same underlying account/battle application. The legacy `src.accounts` module remains available for regression tests but is not exposed through this API. Storage defaults to isolated loopback `final_exodus_tyler_demo`; the deliberate shared profile requires the reviewed additive migration. See [SHARED_STORAGE.md](SHARED_STORAGE.md).

`Users` and `Currency` follow Mihai's model. Registration requires a real date of birth, stores an Argon2 password verifier in `Users.password`, and relies on the existing insert trigger for free/paid balances. Persistence uses `DemoSessions`, `DemoBattles`, `DemoActions` and `DemoGoogleIdentities`. Existing shared rows retain their IDs, balances and credentials; missing historical DOB may stay NULL. Unsupported legacy password formats require an owner-verified reset, with no plaintext fallback.

All request bodies reject extra fields. Errors use `detail`; validation errors return field names/messages without submitted values. Signed JWT bearer access tokens expire after 15 minutes and remain revocable through the session table. See [AUTHENTICATION.md](AUTHENTICATION.md) for the exact stack, Google setup and current verification limits. Local HTTP is allowed only on loopback; remote use needs HTTPS.

| Method/path | Request | Result |
| --- | --- | --- |
| GET /health | None | Configured database readiness; shared profile also requires migration marker |
| POST /accounts | email, display_name, password (12–128 chars), dob (YYYY-MM-DD) | 201 account; 409 duplicate email |
| POST /sessions | email, password | access_token, token_type, expires_in |
| POST /login | name (unique username or email), password | Same JWT session plus id; ambiguous names rejected |
| POST /signup | name, email, password, dob | Same validation/result as /accounts |
| POST /auth/google/start | None | Browser authorization URL, flow_id, poll_secret, expires_in |
| GET /auth/google/callback | Google code/state (browser only) | Fixed return-to-game page; never returns JWT in URL/HTML |
| POST /auth/google/poll | flow_id, poll_secret | pending, registration_required with suggested display_name, or authenticated with JWT |
| POST /auth/google/register | flow_id, poll_secret, display_name, dob | authenticated with JWT for a new verified Google identity |
| POST /auth/google/cancel | flow_id, poll_secret | 204; pending flow invalidated |
| DELETE /sessions/current | Bearer | 204; session revoked |
| GET /me | Bearer | id, email, display_name, level, experience, free_currency, paid_currency, gamepass, completed_battles |
| PATCH /me | Bearer; display_name | Updated account |
| GET /currency | Bearer; optional u_id must equal session account | free and paid balances |
| POST /currency/update | Bearer | 410 retired; never grants client-requested currency |
| POST /battles | Bearer; request_id (UUID) | Existing active battle or new battle |
| GET /battles/current | Bearer | Latest saved battle, or null |
| POST /battles/{id}/actions | Bearer; request_id (UUID), actor (0–2), version | Saved battle after one attack |

Each battle contains three fixed demo characters and one enemy. Damage and enemy retaliation are calculated by the server. Every accepted action advances the version. Exact request retries return the original saved response; reusing the ID with different input or acting on stale state returns 409. A session can access only its own battles. Battles, action responses and sessions survive API restarts. No currency or XP is awarded.

The client retains the session only in memory. Closing the client requires another login; the account and battle are loaded from MySQL. Shop/gamepass screens remain previews and cannot initiate payments.

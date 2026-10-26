# Local connected demo

This branch keeps the team's current UI and adds a separate `src.demo:app` API. The existing `src.main:app` registration foundation stays available. The demo runs only against `final_exodus_tyler_demo` on loopback MySQL. It does not migrate Aiven.

The local `Users` and `Currency` tables follow Mihai's model. Registration includes a real date of birth, stores an Argon2 password verifier in `Users.password`, and relies on the insert trigger for free/paid balances. This local copy adds unique email enforcement, plus `DemoSessions`, `DemoBattles`, `DemoActions` and `DemoGoogleIdentities`. Shared-schema constraints, grants and persistence tables need separate review before an Aiven rollout.

All request bodies reject extra fields. Errors use `detail`; validation errors return field names/messages without submitted values. Signed JWT bearer access tokens expire after 15 minutes and remain revocable through the session table. See [AUTHENTICATION.md](AUTHENTICATION.md) for the exact stack, Google setup and current verification limits. Local HTTP is allowed only on loopback; remote use needs HTTPS.

| Method/path | Request | Result |
| --- | --- | --- |
| GET /health | None | Process and local database readiness |
| POST /accounts | email, display_name, password (12–128 chars), dob (YYYY-MM-DD) | 201 account; 409 duplicate email |
| POST /sessions | email, password | access_token, token_type, expires_in |
| POST /auth/google/start | None | Browser authorization URL, flow_id, poll_secret, expires_in |
| GET /auth/google/callback | Google code/state (browser only) | Fixed return-to-game page; never returns JWT in URL/HTML |
| POST /auth/google/poll | flow_id, poll_secret | pending, registration_required with suggested display_name, or authenticated with JWT |
| POST /auth/google/register | flow_id, poll_secret, display_name, dob | authenticated with JWT for a new verified Google identity |
| POST /auth/google/cancel | flow_id, poll_secret | 204; pending flow invalidated |
| DELETE /sessions/current | Bearer | 204; session revoked |
| GET /me | Bearer | id, email, display_name, level, experience, free_currency, paid_currency, gamepass, completed_battles |
| PATCH /me | Bearer; display_name | Updated account |
| POST /battles | Bearer; request_id (UUID) | Existing active battle or new battle |
| GET /battles/current | Bearer | Latest saved battle, or null |
| POST /battles/{id}/actions | Bearer; request_id (UUID), actor (0–2), version | Saved battle after one attack |

Each battle contains three fixed demo characters and one enemy. Damage and enemy retaliation are calculated by the server. Every accepted action advances the version. Exact request retries return the original saved response; reusing the ID with different input or acting on stale state returns 409. A session can access only its own battles. Battles, action responses and sessions survive API restarts. No currency or XP is awarded.

The client retains the session only in memory. Closing the client requires another login; the account and battle are loaded from MySQL. Shop/gamepass screens remain previews and cannot initiate payments.

# Authentication

The connected demo uses **FastAPI + MySQL + Argon2 + JWT**, with optional **Google sign-in (OAuth 2.0 / OpenID Connect)**. These changes belong to `src.demo:app`; the original `src.main:app` is unchanged.

| Component | Responsibility |
| --- | --- |
| Argon2 through pwdlib | Stores password hashes. Passwords are never stored in plaintext or included in tokens. |
| JWT through PyJWT | Signs a 15-minute API access token after password or Google login. |
| DemoSessions | Stores the token's SHA-256 fingerprint so logout revokes access immediately. |
| Google OpenID Connect | Verifies a Google identity before the API issues its own JWT. Google tokens are not game access tokens. |
| DemoGoogleIdentities | Maps Google's stable subject identifier to a Users row. |

Argon2 and JWT serve different purposes. Argon2 remains when JWT replaces the previous opaque session token. This is also the combination shown in [FastAPI's JWT tutorial](https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/).

## Email/password login

Register with the existing form, then log in. The response contract remains `access_token`, `token_type: bearer`, `expires_in`; the lifetime is now **900 seconds**. The client sends `Authorization: Bearer <JWT>` and keeps the token only in memory. Tokens require a valid HS256 signature, issuer, audience, subject, timestamps and token identifier, plus an unexpired database session. The API docs at `http://127.0.0.1:8007/docs` include a JWT Bearer authorization control.

Expired or revoked sessions return 401, clear client account/battle data, and return to login. There is no refresh token yet; log in again after 15 minutes. Account and battle records remain saved. Old opaque sessions are rejected after this update; existing account passwords and saved games still work.

`setup_demo.py` generates a private signing key in ignored `backend/.env.demo`. Re-running setup adds the local Google identity table and a missing signing key without replacing existing account/battle records. Preserve this key across API restarts. Rotating it invalidates existing JWTs. Never put it in Godot or commit it.

## Enable Google on the local demo

**Local Google credentials are configured on Tyler’s Mac.** The `final-exodus` Cloud project has a Web application client and a test user. The downloaded credentials are stored privately outside Git, and the local server passes Google flow readiness checks. Tyler completed real Google sign-in and reached the hub. A read-only local database check confirms one saved Google identity/account, the supplied profile details and initial balances. A Google-specific battle/logout/relogin check is still pending; no battle was started during that first Google login. Fresh installations must complete the setup below.

This version uses a **Web application OAuth client owned by the Python backend**. Godot opens the system browser and polls the backend with a separate private flow secret. The callback is fixed to the API on this same machine. This is deliberately a local integration; a hosted API, exported desktop client or mobile release needs its own redirect/client design and testing.

1. Open the [Google Auth Platform](https://console.cloud.google.com/auth/overview) in a Google Cloud project the team controls.
2. Configure the app name and support/developer contact. Choose the audience appropriate for the team's Google accounts. For an external app kept in Testing, add the intended review accounts as test users where required by that configuration.
3. Create an OAuth client with application type **Web application**. A service account or API key is not the correct credential.
4. Add this exact authorized redirect URI: `http://127.0.0.1:8007/auth/google/callback`. Preserve the scheme, host, port and path. No JavaScript origin is used by Godot.
5. Save the client ID and secret privately, outside the repository. Add `FINAL_EXODUS_GOOGLE_CLIENT_ID` and `FINAL_EXODUS_GOOGLE_CLIENT_SECRET` to the ignored `backend/.env.demo`. Do not paste the secret in chat, source files or PRs. Keep that file readable only by its owner.
6. Install `backend/requirements-lock.txt` and run local setup if upgrading an earlier checkout. Restart the API with the command in [LOCAL_DEMO.md](LOCAL_DEMO.md), including `--no-access-log` so authorization codes in callback queries are not logged.
7. In the game, choose **Continue with Google**, select an allowed Google account in the browser, then return to the game. A new Google user enters a display name and birth date to satisfy Users. The Google password never enters the game.
8. Confirm the real profile loads, start a battle, log out, and sign in with Google again. Confirm the same account and battle return. Record this actual provider check separately from the simulated tests.

Google's [server flow setup](https://developers.google.com/identity/protocols/oauth2/web-server) and [OpenID Connect documentation](https://developers.google.com/identity/openid-connect/openid-connect) describe client registration and identity validation.

## Identity and flow rules

- Only `openid email profile` is requested. No Google Drive, calendar, offline access or Google refresh token is needed.
- The flow has a five-minute lifetime, random state, nonce and PKCE S256 challenge. The browser receives state; the separate polling secret stays with the game. Neither value replaces the JWT used for game requests.
- The backend exchanges the code with Google and uses `google-auth` to verify the ID token signature, audience, issuer and expiry. It also checks nonce, authorized party and verified email. Google access/ID tokens are discarded after verification.
- Existing Google identities resolve by Google's subject, even if the provider email changes. Matching an email to a password account does **not** link it automatically. Use that account's password; deliberate account linking is future work.
- Google-only accounts store an unusable password marker. They cannot log in with an invented default password. Password reset and adding a password are not implemented.
- Callback state and finished results are single-use; cancellation or expiry requires a fresh flow. Restarting the API clears in-progress Google flows, while issued JWT sessions and saved games persist.
- Flow state and throttling are single-process and bounded. This is not a multi-worker/public-hosting implementation. Remote rollout also needs approved shared schema, credentials and HTTPS.

## Checks

```sh
backend/.venv/bin/python -m pytest backend/tests backend/demo/test_demo_integration.py backend/demo/test_demo_auth.py -q
backend/.venv/bin/python backend/demo/restart_check.py
backend/.venv/bin/python backend/demo/google_ui_check.py --godot /path/to/Godot
```

The last command starts a separate loopback test API on port 8009 with an explicitly simulated Google provider, drives the real game controller and local database, and removes its test account. It never opens Google or proves a real Google login. Test-only provider substitution exists only in `backend/demo/google_ui_check.py`, not the application entrypoint. The cryptographic tests separately exercise the actual Google verification library with signed test certificates.

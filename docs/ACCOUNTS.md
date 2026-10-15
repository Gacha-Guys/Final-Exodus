# Registration contract for the Godot screen

POST `/accounts` with JSON:

```json
{"email":"player@example.com","display_name":"Player","password":"a long demo password"}
```

- 201: `{ "id": 42, "email": "player@example.com", "display_name": "Player" }`.
- 422: `detail` array containing `loc`, `msg`, `type`; show field errors. No account is created.
- 409: `{"detail":"Email already registered"}`.
- 429: `{"detail":"Too many registration attempts"}` with Retry-After seconds.
- 503: `{"detail":"Account creation unavailable"}`; offer retry.

Provisional rules: email lowercased and unique; trimmed display name 1–64 characters; password 12–128 characters without trimming. Server hashes passwords with Argon2id and creates account and zero-balance wallet in one transaction. A duplicate retry does not create another account.

Riley's screen needs email/name/password inputs, masked password, disabled submit while waiting, success/error states and retry handling. Clear the password after submission. No screen implementation is included here. Registration does not log the player in; login is SCRUM-7.

GET `/health` returns process liveness only. It does not prove database readiness. Use the backend connection checker for that. Local API URL: http://127.0.0.1:8001; teammates' localhost points to their own machines. Shared HTTPS hosting remains a separate step.

## Basic Godot test screen
Run the project and select **Open account creation test**. Start the backend as described in backend/README.md, check the API, then create an account with a disposable test email and password. The screen creates real database records; do not use another person’s email. The API address defaults to your own machine. Riley can replace the layout in registration_test.gd or move these controls into an editor-authored scene. No credentials are saved to disk.

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

Riley's screen needs email/name/password inputs, masked password, disabled submit while waiting, success/error states and retry handling. Clear the password after submission. The basic test screen provides this starting point. Registration does not log the player in; login is SCRUM-7.

GET `/health` returns process liveness only. It does not prove database readiness. Use the backend connection checker for that. Local API URL: http://127.0.0.1:8001; teammates' localhost points to their own machines. Shared HTTPS hosting remains a separate step.

## Basic Godot test screen
Run the project to open the portrait registration screen. Start the backend as described in backend/README.md, check the API, then create an account with a disposable test email and password. The screen creates real database records; do not use another person’s email. Expand **Developer connection settings** to change the API origin or check its status. The API address defaults to your own machine. Riley can open `frontend/scenes/registration_test.tscn` in Godot’s 2D editor and edit the existing labels, fields, buttons, containers and theme resources. Keep unique node names used by the script when rearranging controls. The script handles requests rather than creating the layout. No credentials are saved to disk.

The project uses a 480×854 portrait viewport with a scrolling form and touch-sized controls. Email/password fields request appropriate virtual keyboards. Desktop preview is verified; actual Android/iOS export, keyboard overlap and device safe-area testing remain pending. Shared phone testing requires a reachable HTTPS backend; phone localhost is the phone itself.

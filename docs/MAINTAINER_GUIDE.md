# Maintaining Final Exodus

Use Godot 4.7.2 Standard and open [frontend/project.godot](../frontend/project.godot). **Run Project** starts at the title screen. Open [the onboarding scene](../frontend/tests/fixtures/sync_test.tscn) with **Run Current Scene** to check your editor and team check-ins. Follow [setup](SETUP.md) to run both the game and API.

## Where to make a change

| Change | Start here |
| --- | --- |
| Title, login, or signup layout | [Account scenes](../frontend/scenes/account/). The title scene opens the login and signup popups. Edit the matching `.tscn` for layout or the adjacent `.gd` for behavior. |
| Username login or Google button visibility | [modular_login_screen.gd](../frontend/scenes/account/modular_login_screen.gd). Both sign-in methods ultimately call `accept_session()`. Google visibility comes from `GET /auth/google/status`. |
| Google browser flow | [google_sign_in.gd](../frontend/scenes/account/google_sign_in.gd) starts, polls, and cancels the flow. Edit the layout in [google_sign_in_dialog.tscn](../frontend/scenes/account/google_sign_in_dialog.tscn). [google_auth.py](../backend/src/google_auth.py) handles the callback and account linking. |
| Hub navigation, username changes, and sign-out | [hub.gd](../frontend/scenes/hub/hub.gd). `enter_battle()` opens the battle scene for signed-in users. `save_username()` updates the account through `PATCH /me`. `sign_out()` revokes the session and returns to the title. |
| Shop or reusable HUD controls | [Shop scene and script](../frontend/scenes/shop/) and [shared UI scenes](../frontend/ui/). Check the hub and shop when changing a shared component. |
| Battle controls, labels, or taps | [battle_controller.gd](../frontend/scenes/battle/battle_controller.gd). Edit the fixed controls in [team_battle.tscn](../frontend/scenes/battle/team_battle.tscn). The controller handles tap collection, round submission, and retry. |
| Portraits, hit effects, or motion | [battlefield.gd](../frontend/scenes/battle/battlefield.gd). `play_round()` animates the result returned by the server. |
| Damage, turn rules, or saved encounter | [battle_routes.py](../backend/src/battle_routes.py). `advance()` resolves the round and `save_action()` persists it. Clients send taps, a request ID, and the expected version. |
| HTTP, session state, or balances | [GameSession](../frontend/autoload/game_session.gd) sends requests and owns the in-memory session. [PlayerData](../frontend/autoload/player_data.gd) adapts the account data for the hub and shop HUD. |
| API routes or storage | [Server.py](../backend/Server.py) launches FastAPI. [account_routes.py](../backend/src/account_routes.py) handles profiles and sessions, and [game_store.py](../backend/src/game_store.py) provides database transactions. [API contract](DEMO_API.md). |

## Trace the normal game flow

1. The title opens login. Username login calls `POST /sessions`. After either sign-in method returns a token, `accept_session()` fetches `GET /me` and closes the popup. Press **Start** to open the hub.
2. **Battle** opens `team_battle.tscn`. The controller calls `GET /battles/current` to resume an active encounter or `POST /battles` to start one.
3. An attack round sends `POST /battles/{battle_id}/rounds`. The backend saves the result. The battlefield animates server-provided damage, and the controller updates the HP and turn.
4. After quitting the game, sign in again and choose **Battle** to resume. The token was kept in memory. The encounter persists in the database.

## Debug and verify a change

- **Login cannot connect.** Open `http://127.0.0.1:8000/health` with the backend running. If your API uses a different port, set `FINAL_EXODUS_API_ORIGIN` before launching Godot. If health fails, check the backend terminal and DB settings first.
- **Google button is missing.** Open `/auth/google/status` on the local API. Check [callback and credential setup](AUTHENTICATION.md) if it returns `enabled: false`. The simulated callback test and a real browser consent walkthrough validate different parts of the flow.
- **A scene fails after a file move.** Check `project.godot`, scene resource paths, script `preload()` calls, and `change_scene_to_file()` paths. Move each `.gd.uid` with its script and run a clean Godot import.
- **Battle state differs after retry.** Compare the request ID and expected version with the response. The same request ID lets the server replay the saved result. For a version conflict, trace the controller's refresh via `GET /battles/current`.
- **Choose a test by what changed.** Run `team_integration.gd` for offline UI and state checks, `team_restoration.gd` for the normal title-to-battle flow, and `google_sign_in.gd` for simulated Google sign-in. Use the isolated database for tests that create accounts. [Commands and setup](TESTING.md).

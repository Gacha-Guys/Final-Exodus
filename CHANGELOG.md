# Changelog

## 0.0.0.4 — 2026-10-26

- Integrate the preserved team title, account popups, hub, four gem offers plus gamepass and gacha prototype with authenticated profiles; keep saved fixture combat in separate optional demo scenes.
- Authenticate password logins by username (`Users.name`); keep email for registration and clarify username changes in Settings.
- Use one supported API and session client, with Argon2/JWT authentication and secure compatibility for the team's login/signup/currency routes; keep the guarded isolated currency prototype and refuse shared client-directed grants.
- Add guarded shared Users/Currency storage, an additive migration and reproducible isolated MySQL setup. Keep existing account IDs, balances, catalog, inventory and currency trigger intact.
- Fix both leveling caps and gacha import/transaction cleanup; retain every original backend test and add deterministic gacha, leveling, authentication, migration and UI regressions.
- Preserve Uvicorn dependencies, add backend CI, and document current setup, API contracts, test commands and remaining gameplay limits.

## [0.0.0.1] - 2026-10-15

- Run the shared GDScript starter in Godot 4.7.2 and view individual teammate check-ins.
- Follow the setup guide to share changes through GitHub and verify the merged project on each machine.

## 0.0.0.2 — 2026-10-15
- Add account creation API, unit/integration tests, Aiven checker and team setup instructions.
- Build on Jasoo’s backend scaffold with one API entrypoint; disable dummy authentication until login is implemented.

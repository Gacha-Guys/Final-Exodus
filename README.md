# Final Exodus — Cydia Studios

Shared Godot game project for Intro to Software Engineering.

## Local connected demo

On `feature/tyler-connected-demo`, follow [the local demo guide](docs/LOCAL_DEMO.md) to run the API and game, review validation, and rehearse the presentation. This uses an isolated local database and does not migrate Aiven. Authentication uses JWT and Argon2; [Google sign-in setup and validation limits](docs/AUTHENTICATION.md) are documented separately.

## Start here

Install **Godot 4.7.2 standard** (GDScript). Clone this repository and import **frontend/project.godot** in Godot, then press Play. No .NET SDK or backend is needed for the first sync test.

Follow [the team setup and sync checklist](docs/SETUP.md). Each teammate changes their own file in frontend/team_checkins/, shares it through a pull request, and verifies everyone can see the merged change.

- **frontend/** — Godot project, scenes, GDScript and assets.
- **backend/** — Python APIs, local demo setup and backend tests.
- **docs/** — setup guide and future shared API contracts.

This branch opens the team title screen with login and signup popups. The local demo connects accounts, hub data and a basic saved encounter. The original sync-test scene remains available for team setup.

The original registration API and Aiven connection setup remain documented in [backend/README.md](backend/README.md). The isolated demo uses the separate entrypoint described above.

# Final Exodus — Cydia Studios

Shared Godot game project for Intro to Software Engineering.

## Start here

Install **Godot 4.7.2 standard** (GDScript). Clone this repository and import **frontend/project.godot** in Godot, then press Play. No .NET SDK or backend is needed for the first sync test.

Follow [the team setup and sync checklist](docs/SETUP.md). Each teammate changes their own file in frontend/team_checkins/, shares it through a pull request, and verifies everyone can see the merged change.

- **frontend/** — Godot project, scenes, GDScript and assets.
- **backend/** — destination for Python API and database setup; currently a placeholder.
- **docs/** — setup guide and future shared API contracts.

The first screen verifies project setup and GitHub file syncing. It does not yet connect to an API or implement gameplay. Registration and login will follow in a separate change.

Account creation API and Aiven access/setup: [backend/README.md](backend/README.md). The phone registration UI follows in a separate PR.

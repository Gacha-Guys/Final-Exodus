# Final Exodus shared project rules

- Frontend: Godot 4.7.2 standard with GDScript. Backend: Python API and MySQL.
- Read README.md and docs/SETUP.md before changes. Keep frontend code in frontend/ and new backend code in backend/.
- GitHub is the shared source of truth; use small feature branches and pull requests. Do not overwrite teammates' scenes or upgrade Godot independently.
- Use separate scenes/scripts for independent features. Agree request/response contracts in docs/ before wiring shared features.
- Database credentials and authoritative rewards/combat/account checks stay server-side. Never put secrets in frontend files or commits.
- Keep .godot caches/build outputs/local secrets ignored; commit .gd.uid sidecars.
- Validate with the pinned Godot version; report exactly what ran. Do not mark Jira Done from a setup screen.

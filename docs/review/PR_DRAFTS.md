# Proposed PRs — not published

## Bring the latest hub and account screens into the demo branch

Integrates Riley's title/account popups and shop together with Jason's updated hub, preserving the existing commit history. This establishes the frontend used by the connected demo.

Sources: main `4d9744d`, riley-dev `f2a04b5` (which includes jason-dev `02ce5c0`). The older standalone signup and registration UI PRs remain open; their scenes are not applied over the newer screens.

## Add a local account and combat API

Adds an isolated `src.demo:app` entrypoint using Mihai's Users/Currency model, hashed passwords, expiring sessions, profile/name updates and persistent basic battles. Battle actions are server-calculated, ownership-checked and safe to retry. Existing `src.main:app` remains unchanged.

Validation: 35 backend tests plus 12 subtests, including actual local MySQL concurrency/rollback checks; dependency and compilation checks; sessions/battles/retry records verified across an actual API process restart. Local setup refuses remote databases. Shared Aiven schema/access and rewards are outside this PR.

Related: SCRUM-6, SCRUM-7, SCRUM-8, SCRUM-16, SCRUM-24. This demo does not close the complete stories.

## Connect account screens, hub data and saved battles

Connects the existing login/signup popups, authenticated hub/shop data, display-name settings and logout to the local API. Adds a basic three-character encounter with saved health, safe attack retry and resume after reconnect. Includes the demo walkthrough and screenshots.

Depends on the frontend baseline and local API above. Validation: automated Godot UI flow, native input rehearsal and two portrait window sizes. Full testing evidence is in LOCAL_DEMO.md and the review results. Live Aiven and real mobile input remain unverified.

Keep normal merge commits for teammate branch integration. No shared branch is rebased or force-pushed, and no main merge is proposed until the local result is reviewed.

## Add JWT authentication and Google sign-in

Replaces opaque demo sessions with 15-minute signed JWTs while preserving database-backed logout revocation and Argon2 password hashing. Adds browser-based Google OpenID Connect, explicit new-user details, and provider-subject identity mapping; matching emails do not automatically link existing accounts. Preserves the current login popup and adds a Google option.

Keep this as a separate review after the connected demo above (previous demo head `8373c2f`). Validation: 58 backend tests plus 12 subtests, 41 Godot integration assertions at each of two window sizes, 8 simulated Google UI assertions using real HTTP/MySQL, and actual API restart persistence. Independent adversarial review completed. Real Google sign-in remains pending client creation/configuration and a real browser check; setup and exact limits are in AUTHENTICATION.md. Only the isolated local database gets the new identity table.

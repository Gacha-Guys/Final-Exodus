# Proposed review units — not published

> Historical October 26 review proposal for the earlier local demo. The current integration branch consolidates the supported API in `src.main:app`; follow [the current setup](../SETUP.md) and [shared-storage procedure](../SHARED_STORAGE.md). The original proposal, [validation](VALIDATION.md) and [independent review](ADVERSARIAL_REVIEW.md) are preserved for provenance.

Prepare the final implementation as three focused draft PRs. The current local commits record implementation milestones; do not publish an older opaque-session backend as the final API and immediately replace it in another PR. The publication branches have not been assembled or pushed yet. Preserve the existing integration branch and teammate commit history.

## Bring the latest team hub and account screens into the demo

Integrates Riley's title/account popups and shop with Jason's hub, preserving their existing commit history. This establishes the frontend used by the connected demo.

Sources: main `4d9744d`, riley-dev `f2a04b5` (which includes jason-dev `02ce5c0`). Existing integration commit: `18b7070`. Review the baseline separately so teammates' assets and scenes are not mistaken for newly authored integration work.

The older registration/sign-up PRs [#6](https://github.com/Gacha-Guys/Final-Exodus/pull/6) and [#13](https://github.com/Gacha-Guys/Final-Exodus/pull/13) remain open. They conflict with Riley's newer project/login/signup files. Reuse their covered behavior where applicable; do not blindly merge their older scenes or close the PRs without agreement.

Suggested review: Riley/Jason confirm the intended UI baseline and preserved authorship.

## Add local accounts, JWT/Google authentication and saved combat

Adds a separate `src.demo:app` using Mihai's Users/Currency model, Argon2 password hashes, 15-minute signed JWTs, database-backed logout revocation and Google OpenID Connect. Provider subject identifies a Google account; matching email does not silently link a password account. Adds authenticated profiles/name updates and server-calculated, ownership-checked battles with safe action retries and persistence.

Submit the current backend and API contracts from the final demo state. Existing `src.main:app` remains the legacy registration entrypoint; the README distinguishes the two. Database setup is restricted to the isolated local schema. No Aiven migration or grant change is included.

Validation: 58 backend tests plus 12 subtests, actual local MySQL concurrency/rollback checks, dependency consistency, and actual API-process restart persistence. Tyler completed live Google login to the hub; a read-only check confirmed the saved identity/account. Google battle/logout/relogin is still a separate pending acceptance check. Private credentials remain outside tracked source.

Suggested review: Mihai checks the Users/Currency adapter, API contract and overlap with any unpublished backend work. Related stories: SCRUM-6, SCRUM-7, SCRUM-8, SCRUM-16, SCRUM-24. This limited demo does not close the full stories.

## Connect the existing screens to account data and saved battles

Connects the current login/signup popups, Google button, hub/shop data, display-name settings and logout to the API. Adds a three-character encounter with saved health, safe attack retry and resume after reconnect. Includes the walkthrough and verification evidence.

Depends on the final API and UI baseline above. Validation: 42 Godot integration assertions at each of two portrait sizes, 8 simulated Google UI assertions using real HTTP/MySQL, the earlier native walkthrough, and Tyler's accepted local demo plus live Google hub login. Distinguish simulated provider tests from the real login evidence.

Suggested review: Riley/Jason check scene bindings and preserved screens; Tyler rehearses Google battle → logout → Google login → resume. Shop/gamepass, rewards, gacha and the full roster remain previews or outside scope.

## Before publication

- Finish the Google-specific battle/logout/relogin acceptance check without changing existing review accounts.
- Review the final three diffs, their dependencies and concise descriptions before pushing.
- Confirm Mihai's unpublished work and agree the API boundary; his published branch has no new commits beyond main.
- Make the fresh-machine setup reproducible. The current guide depends on Tyler's existing local MySQL container and private configuration; no portable demo container recipe has been committed yet. Have one teammate verify setup before main merge.
- Keep only synthetic test identities in committed evidence. Private configuration, Google credentials and generated caches stay ignored.
- Treat Aiven deployment, shared-schema/grant changes, public HTTPS and multi-worker auth state as a separate approval/review.

Use normal merge commits to preserve teammate history. No shared branch rebase, force push, PR closure, main merge or database migration is authorized by this review plan.

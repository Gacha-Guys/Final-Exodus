# Independent adversarial review

October 26, 2026. Requested by Tyler before any push. A separate agent inspected the actual implementation and tests; this was distinct from the original author's second-pass review.

**Local presentation readiness: 8.5/10. Shared/public deployment readiness: 3/10.** These are subjective readiness assessments. No reproduced blocker for the local presentation was found.

Independently verified:

- 35 backend tests and 12 subtests pass.
- 12 simultaneous starts create one active battle.
- 12 identical simultaneous attacks advance damage once.
- Replaying an earlier action after a later action returns its original response without rolling stored battle state backward.
- A revoked session cannot attack.

The temporary stress-test account was removed. The reviewer did not operate the native UI or independently rerun the API-restart script. The author separately demonstrated registration, login, all three attacks, full client restart at 52 enemy HP, resumed victory, saved victory count, name changes and the shop using native mouse/keyboard input.

## Finding and resolution

**P3 — validate the settings response before replacing the cached profile.** The original settings handler accepted a successful response without checking its shape. An unexpected null/malformed response could corrupt cached data or cause an access error. This was a source-confirmed robustness gap, not a failure reproduced against the correctly behaving backend.

Fixed by validating the returned account and requiring its ID to match the current account before assignment. Three added regression assertions reject null, malformed and different-account responses while preserving the cached profile and displayed name. The reviewer independently inspected the fix and confirmed the finding resolved; the focused UI run passed 37 checks.

## Boundaries

Automated UI assertions call scene methods and inspect application state; they are not 37 real mouse clicks. Native interaction rehearsal is separate evidence. Aiven, public HTTPS hosting, shared schema/access changes, a second machine, mobile input, full player-owned characters and rewards/payments remain outside the verified local demo. The authentication limiter remains single-process.

No push, published PR, main merge or shared database write was performed.

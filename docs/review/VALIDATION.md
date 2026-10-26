# Review results — October 26

Local source commits: `18b7070` (team UI integration), `86685c6` (API), `366693f` (client). Main was `4d9744d`; Riley's branch was `f2a04b5`. A final fetch found no newer commits on these branches.

| Check | Result |
| --- | --- |
| Existing backend + isolated MySQL integration suite | 58 tests and 12 subtests passed |
| Simulated Google Godot integration | 8 checks passed using real HTTP/MySQL with a test provider |
| Live Google browser sign-in | Passed: Tyler reached hub; saved identity/account independently checked |
| Live Google battle/logout/relogin | Pending; first Google session only reached the hub |
| Dependency consistency | Passed |
| Python source compilation | Passed |
| Godot 4.7.2 editor import and default startup | Passed, no script errors or resource warnings |
| Connected UI driver, normal portrait window | 42 checks passed |
| Connected UI driver, smaller portrait window | 42 checks passed |
| Actual API process restart | Session, battle and retry record recovered |
| Native mouse/keyboard rehearsal | Registration, login, party attacks, settings, shop, unavailable API/retry and client restart verified |
| Secret and whitespace review | Passed; private database values absent from committed files |

The backend checks cover duplicate/concurrent registration, trigger-created balances, password hashing, rollback, invalid/expired sessions, logout, profile changes, cross-account access, forged damage, stale actions, concurrent duplicate attacks, rollback between battle and retry-record writes, missing balances, and database outages. One existing Starlette/httpx deprecation warning remains in the Python test environment; the authentication update added PyJWT, google-auth and their dependencies without changing existing locked packages.

The UI checks cover account switching without stale private data, unauthenticated entry, wrong passwords, registration, name persistence, all three attacks, battle resume, victory, logout/relogin, unavailable API/recovery, shop, invalid sessions, malformed response checks, visible combat controls, JWT login, and the configured/unconfigured Google start and cancellation paths. Window sizes were 480×854 and 390×744; saved content images are 480×853 and 390×693 because of the existing fixed-aspect viewport.

Manual restart evidence: Tyler Connected's encounter remained at 34 HP after closing/reopening Godot and logging in again. Stopping the API during an attack showed a retry state without advancing the displayed battle; after restart, retry advanced it once. The automated process-restart check separately resubmits an already committed action and confirms no duplicate damage.

Screenshots: [hub](hub.png), [battle](battle.png), [victory](victory.png), [shop](shop.png), plus smaller-window variants. The automated users shown in these images were removed afterward. The synthetic `tyler.demo@example.com` review account and its partially completed battle remain.

Second-pass review corrected a MySQL snapshot race during simultaneous battle starts, the missing shop controller binding, a duplicate battle-entry control, preview-text overlap, response validation and headless audio cleanup. Final checks show no remaining blocker for the email/password local demo. Real Google sign-in to the hub now passes; its account is saved. Google-specific battle/logout/relogin remains pending.

No push, public PR, main merge, Jira transition, teammate message or shared Aiven write occurred. Live Aiven integration, another machine and real mobile input remain unverified. Rewards, payments and the full roster are outside this demo.

Independent adversarial review subsequently rated local presentation readiness 8.5/10 and shared/public deployment 3/10. It reproduced no demo blocker and identified one settings-response validation gap, now fixed and covered by 3 additional UI assertions. See [ADVERSARIAL_REVIEW.md](ADVERSARIAL_REVIEW.md). The live walkthrough also created a second disposable account, now named Tyler Presentation, with one saved victory.

## JWT and Google follow-up

The independent reviewer reran 58 backend tests plus 12 subtests and reproduced a Google certificate-request wrapper incompatibility. It was fixed and the actual google-auth verifier now passes signed test-certificate cases. Additional probes confirmed cancellation during exchange cannot resurrect a flow and 12 simultaneous callbacks allow one exchange. No further blocking finding was reproduced. A final frontend review checked cancellation and failed profile loading.

The regular native-rendered driver passes 42 assertions at both sizes. A separate Google test starts a loopback port 8009 API with a simulated provider and passes 8 Godot integration assertions for new-user DOB validation, JWT/profile loading, owned battle creation, logout and returning-user battle recovery. It uses scene methods and real HTTP/MySQL, not eight manual mouse clicks. Its temporary account is removed. The local API on 8007 is now configured for Google; the live login follow-up below supersedes its earlier unconfigured state. See [authentication setup](../AUTHENTICATION.md). Google callback URLs are excluded from access logging in documented launch commands.

Local Google setup follow-up: the downloaded Web client matches the loopback callback, private configuration preserves the existing JWT key/database settings, and the restarted API passes real configured start/scopes/PKCE/cancel readiness checks. The Cloud project remains External/Testing with one test user. This does not yet establish a successful Google account login.

## Saved account and pre-push check

Tyler reported a successful real Google sign-in and confirmed that he only visited the hub. A read-only transaction independently found exactly one Google-linked account, one provider-subject mapping, a saved display name/DOB, an unusable Google-only password marker, level 1 / XP 0 and the expected free 0 / paid 0 balance rows. An active session was recorded. No battle exists for this account yet; that matches the stated test and is not evidence of lost progress. No email, birth date, subject, session fingerprint or token is included in this report.

Earlier synthetic review accounts still retain their active 34 HP encounter and completed 0 HP victory. Reran 58 backend tests plus 12 subtests, dependency consistency, and the separate actual-process restart check: all passed. The restart test uses a temporary account and does not restart or change the user’s live game/server. Private-value scan and whitespace review pass.

Fresh fetch: origin/main `4d9744d`, origin/riley-dev `f2a04b5` and origin/mihai-dev `7c42120` are unchanged and contained in the demo. Public GitHub PR listing still shows only #6 and #13 open. Merge simulations again identify PR #6 / project.godot and PR #13 / login_screen.tscn and signup_screen.tscn conflicts against current Riley UI. Mihai has no newer published branch work; unpublished work remains unknown. The GitHub connector returned bad credentials, so PR status was checked with the public API using verified TLS. No remote mutation occurred.

The UI driver was updated to accept both configured and unconfigured Google APIs without opening a real browser during automated tests. The actual Google button binding is checked. The revised driver passes 42 assertions in both native portrait sizes against the configured API, plus 42 headless assertions against a separate unconfigured test API. Test-created pending Google flows are cancelled. The real Google sign-in controller and login behavior were not changed.

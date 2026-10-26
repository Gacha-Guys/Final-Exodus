# Review results — October 26

Local source commits: `18b7070` (team UI integration), `86685c6` (API), `366693f` (client). Main was `4d9744d`; Riley's branch was `f2a04b5`. A final fetch found no newer commits on these branches.

| Check | Result |
| --- | --- |
| Existing backend + isolated MySQL integration suite | 58 tests and 12 subtests passed |
| Simulated Google Godot integration | 8 checks passed using real HTTP/MySQL with a test provider |
| Live Google browser sign-in | Pending OAuth client creation and configuration |
| Dependency consistency | Passed |
| Python source compilation | Passed |
| Godot 4.7.2 editor import and default startup | Passed, no script errors or resource warnings |
| Connected UI driver, normal portrait window | 41 checks passed |
| Connected UI driver, smaller portrait window | 41 checks passed |
| Actual API process restart | Session, battle and retry record recovered |
| Native mouse/keyboard rehearsal | Registration, login, party attacks, settings, shop, unavailable API/retry and client restart verified |
| Secret and whitespace review | Passed; private database values absent from committed files |

The backend checks cover duplicate/concurrent registration, trigger-created balances, password hashing, rollback, invalid/expired sessions, logout, profile changes, cross-account access, forged damage, stale actions, concurrent duplicate attacks, rollback between battle and retry-record writes, missing balances, and database outages. One existing Starlette/httpx deprecation warning remains in the Python test environment; the authentication update added PyJWT, google-auth and their dependencies without changing existing locked packages.

The UI checks cover account switching without stale private data, unauthenticated entry, wrong passwords, registration, name persistence, all three attacks, battle resume, victory, logout/relogin, unavailable API/recovery, shop, invalid sessions, malformed response checks, visible combat controls, JWT login, and the unconfigured Google button/cancellation path. Window sizes were 480×854 and 390×744; saved content images are 480×853 and 390×693 because of the existing fixed-aspect viewport.

Manual restart evidence: Tyler Connected's encounter remained at 34 HP after closing/reopening Godot and logging in again. Stopping the API during an attack showed a retry state without advancing the displayed battle; after restart, retry advanced it once. The automated process-restart check separately resubmits an already committed action and confirms no duplicate damage.

Screenshots: [hub](hub.png), [battle](battle.png), [victory](victory.png), [shop](shop.png), plus smaller-window variants. The automated users shown in these images were removed afterward. The synthetic `tyler.demo@example.com` review account and its partially completed battle remain.

Second-pass review corrected a MySQL snapshot race during simultaneous battle starts, the missing shop controller binding, a duplicate battle-entry control, preview-text overlap, response validation and headless audio cleanup. Final checks show no remaining blocker for the email/password local demo. Google is implemented with simulated verification; real provider acceptance remains pending.

No push, public PR, main merge, Jira transition, teammate message or shared Aiven write occurred. Live Aiven integration, another machine and real mobile input remain unverified. Rewards, payments and the full roster are outside this demo.

Independent adversarial review subsequently rated local presentation readiness 8.5/10 and shared/public deployment 3/10. It reproduced no demo blocker and identified one settings-response validation gap, now fixed and covered by 3 additional UI assertions. See [ADVERSARIAL_REVIEW.md](ADVERSARIAL_REVIEW.md). The live walkthrough also created a second disposable account, now named Tyler Presentation, with one saved victory.

## JWT and Google follow-up

The independent reviewer reran 58 backend tests plus 12 subtests and reproduced a Google certificate-request wrapper incompatibility. It was fixed and the actual google-auth verifier now passes signed test-certificate cases. Additional probes confirmed cancellation during exchange cannot resurrect a flow and 12 simultaneous callbacks allow one exchange. No further blocking finding was reproduced. A final frontend review checked cancellation and failed profile loading.

The regular native-rendered driver passes 41 assertions at both sizes. A separate Google test starts a loopback port 8009 API with a simulated provider and passes 8 Godot integration assertions for new-user DOB validation, JWT/profile loading, owned battle creation, logout and returning-user battle recovery. It uses scene methods and real HTTP/MySQL, not eight manual mouse clicks. Its temporary account is removed. The production API on 8007 remains unconfigured for Google. See [authentication setup](../AUTHENTICATION.md). Google callback URLs are excluded from access logging in documented launch commands.

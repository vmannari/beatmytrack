# Race challenges — 2026-10-08

The owner accepted the proposed challenge plan and requested implementation. This is a local implementation with disposable HTTP and database verification; it has not been rolled out to the retained cloud backend.

## Requirements and behavior

| ID | Delivered behavior |
| --- | --- |
| CH01 / R01 / V03 | The existing target icon opens Challenges within Race. Received/Sent, creation, code entry, scenic invitations, scrolling standings and a yellow player row use the shared menu shell. Received contains invitations the player has joined; there is no friend directory or automatic message delivery. |
| CH02 / G05 | Beat my time captures an owned verified run; Group opens a best-time board. Creation chooses published track, car, and 24 hours/3 days/7 days (seven by default). Search queries the global published catalog by track/creator; each response is bounded to twenty matches. Selecting a track in Free Race also prefills it. Private drafts are never published implicitly. |
| CH03 / T03 | The challenge pins its immutable track version, five laps, car/handling hash, physics, rules and verifier contract. Duels contain creator plus one recipient; groups contain at most twenty actual drivers. Creator PB improvements cannot move a duel's target. Incompatible builds are rejected, never silently rebased. |
| CH04 / B01–B07 | New race tickets bind attempts to the challenge. Canonical worker finalization writes one best per participant, within the same transaction as verified run finalization. Slower/tied attempts cannot replace a best. Equal times share rank; a tie cannot beat the duel target. Challenge attempts also remain ordinary legitimate PB attempts on the exact public board. |
| CH05 / R05 | The selected target's verified positional recording is a non-colliding ghost. Opponent controls/replays are not exposed. Normal PB/lap/histogram results appear first; Continue opens challenge verification/standings and a signed duel gap. Verification never interrupts the normal summary. Winners can create a new reverse invitation with Rematch; the source remains their own verified best. |
| CH06 / T05 | Desktop copies an invitation/link/code; Android exports a native Sharesheet bridge and custom invitation URI. `/c/{code}` is a small escaped browser preview with an Open action and visible code fallback. Optional HTTPS App Links and an association endpoint are prepared, but domain/signing setup is not activated. |
| CH07 / TD06–TD08 | Artificial identities are rejected at creation, inbox, membership, tickets, rematches and results. Source runs must match the exact ordinary public board and be owned/verified. Published/visible track and active creator checks apply to previews, joining and racing. Existing authentication/development session gates remain authoritative. No visible source/test classifications were added. |
| CH08 / Q01 | Mutations persist operation keys under the account/server cache; reconnect retries reuse them. Account changes fence requests and polling. The existing durable result queue owns recorded submissions. New entries refresh every thirty seconds outside racing; manual refresh remains available. Cursor paging includes same-second invitations. Targets and challenge best ghosts survive retention. |

After a source race, Continue returns to the creation form with the track, car, duration and upload ticket retained. The form waits for actual verification. A guest can preview and try the track/ghost without authentication; guest results return to the invitation and do not enter challenge standings. Competitive attempts require the existing authenticated ticket flow.

Server deadlines use UTC timestamps outside the canonical simulation. Tickets expire after two hours or at challenge end, whichever comes first. Upload must arrive before ticket expiry; timely submissions may verify after the challenge ends. The view remains settling while timely runs are queued/verifying. Only the creator can cancel; cancellation prevents pending attempts from changing challenge standings. It does not invalidate an otherwise legitimate personal PB.

## Files and API

- Backend: `backend/bmt_backend/challenges.py`, `challenge_models.py`, migration `0020_challenges.py`; router/model registration in `app.py`/`migrations/env.py`, optional association settings in `config.py`, ghost/scoring hooks in `worker.py` and retention references in `maintenance.py`.
- Game: `game/backend/challenges_client.gd`; `game/ui/challenges_page.gd`/`challenge_create.gd`; integration in `game/core/app.gd`, `backend/backend_client.gd`, `ui/race_results.gd`, `ui/race_mode_rail.gd`, `ui/track_browser.gd` and `ui/weekly_rivalry_page.gd`; `ui/race_complete.gd` supplies the shared embedded comparison view.
- Android: `game/platform/challenge_links.gd`, `game/addons/bmt_challenges/`, `native/challenges/`, `game/project.godot` and the generated-template hook in `scripts/dev.ps1`.
- Contracts/tests: `docs/schemas/challenge-v1.schema.json`, `backend/tests/test_challenges.py`, `test_challenges_http.py`, `game/tests/test_challenges.gd`, `test_challenges_http.gd`, and `scripts/test_challenges_postgres.py`.

`POST /v1/challenges` creates an invitation. `GET /v1/challenges?folder=received|sent&cursor=...` pages memberships. `GET /v1/challenges/sources` resolves the owned PB or specific result ticket. Public `GET /v1/challenges/{code}` and authenticated `/me` return the snapshot. `/join`, `/tickets`, `/cancel` and `/rematch` are idempotent writes. `/ghost` returns verified poses only. `GET /v1/challenge-results/{ticket}` returns the owned attempt's verification status/outcome and current standings.

New normal human runs retain verified poses so they can become invitations. An older verified source without poses is replayed canonically on demand; blob/verifier work releases SQL transactions before IO, then track/build/source eligibility is rechecked. Challenge memberships and board contracts stay distinct from Weekly Rivalry. No physics, lap/gate, rating or point rules changed.

## Actual verification

All Godot commands used `scripts/dev.ps1` and the pinned `4.7.2.stable.official.ed1daf0bf`, with isolated local records/cache directories. The initial restricted importer could not read the Windows root certificate store; the authorized pinned importer was rerun with normal Windows access and passed.

| Actual command | Outcome |
| --- | --- |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_challenges.py -q -k sqlite` | Initial twelve challenge tests passed. Expanded coverage is included in the dual-database run below. |
| `.tools/backend-venv/Scripts/python.exe scripts/test_challenges_postgres.py` | 29 passed, one SQLite-only row-lock skip: fourteen functional cases on both SQLite and owned PostgreSQL, plus PostgreSQL concurrency. The owned, labeled PostgreSQL container was removed; no existing database/service was replaced. |
| `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_challenges_http.py -q -s` with `BMT_CAPTURE_CLOUD` | Two graphical native HTTP flows passed: 42 and 46 checks. Actual source race 12,817 ticks, recipient 12,757 ticks; verified gap −500 ms. Covers finished-result creation, race-first return with 24-hour duration, guest try/return, global track search, duel/group attempts, ghosts, normal-results-first, retry, reverse invitation and logout. |
| `scripts/dev.ps1 TestScript -ScriptPath res://tests/test_challenges.gd` | Latest headless run: 60 checks, zero failures, including refresh revealing new standings while retaining the target. Prior graphical run: 71 checks, zero failures including twelve captured layouts. |
| `scripts/dev.ps1 TestApp` | 99 checks, zero failures. |
| `scripts/dev.ps1 Import`, `CheckScript -ScriptPath res://core/app.gd` | Passed. |
| `scripts/dev.ps1 ExportAndroid -QuickValidation -CommandTimeoutSeconds 300` | Completed debug APK: import/startup/driving 72/catalog 21/menus 48 passed. Final APK receipt is recorded below after final source verification. Full Validate was not claimed. |
| `scripts/dev.ps1 Doctor` | Prerequisites found; tablet `f0ba474a` was attached but ADB unauthorized. No installation or physical-device challenge test was performed. |

Backend regression, final build, lint and checkpoint receipts are recorded below. [Database evidence](evidence/challenges-2026-10-08/postgres.log) and [native HTTP evidence](evidence/challenges-2026-10-08/http.log) retain actual results. Initial incorrect fixture ticket lookup, typed-array fixture assignment, premature form-verification assertion and a clipped card status were corrected; their failures were not hidden or relaxed.

The challenge and source-race summaries default to the existing all-driver race/lap histograms. Compare/Track/Sectors/Speed keep lap analysis on the same normal summary; tapping a lap opens its analysis. The shared comparison implementation, eight bins and both recorded markers are reused. Existing Weekly Rivalry ghost capture remains enabled, including its internally gated artificial fields.

Final receipts: the completed-source graphical challenge suite passed **72** checks; App passed **99**; the final rendered native HTTP recheck passed **42** with zero failures. Results histograms36/unified histograms46 and the existing native Weekly Rivalry HTTP regression passed. Lint and scoped whitespace checks passed. The affected broader backend run passed **31**, skipped **5**, and retained the already documented `test_checkpoint_rules_upgrade_keeps_track_and_historical_board[sqlite]` failure: its older expected verifier/rules contract returns 409 under the current rules-v20 transition. This task does not modify `runs.py`/`contracts.py` or weaken that check. An initial restricted native-practice run also failed to launch its verifier; rerunning with normal engine access passed that case. A preceding Android driving check emitted the existing 31-instance shutdown warning; the final driving run was clean.

Final debug APK: [challenges-debug.apk](../build/android/challenges-debug.apk), **241,123,700 bytes**, SHA-256 **557482AF0239FBA3F65E3B7CF53C532F6E2BA0B24E2C2736413635536B4959FC**. The final export passed import/APP_READY, driving72/catalog21/menus48 and native Java compilation. Extracted APK manifest confirms `BmtChallenges` registration and the `beatmytrack`/`challenge` intent filters. [Final export logs](evidence/challenges-2026-10-08/android-final) and [manifest receipt](evidence/challenges-2026-10-08/android-manifest.txt) are retained. No Android install/device test or full Validate was performed.

The review checkpoint is `refs/codex/challenges-2026-10-08`, with a separate snapshot parent containing the pre-change versions of task files. Review its change with `git diff refs/codex/challenges-2026-10-08^ refs/codex/challenges-2026-10-08`; the existing branch/index and unrelated work remain untouched. The task-only patch and receipt are under `docs/evidence/challenges-2026-10-08/`. The snapshot is for review; it does not constitute a merge or deployment.

## Screenshots and acceptance

Inspected actual Godot captures:

- [Received/detail, desktop](evidence/challenges-2026-10-08/screenshots/received-1280x720.png)
- [Group standings, compact](evidence/challenges-2026-10-08/screenshots/group-960x540.png)
- [Creation after a real verified source race](evidence/challenges-2026-10-08/http-flow/create.png)
- [Normal results first](evidence/challenges-2026-10-08/http-flow/normal-results.png)
- [Verified duel feedback](evidence/challenges-2026-10-08/http-flow/verified-result.png)
- [Verified group result](evidence/challenges-2026-10-08/http-flow/group-verified.png)
- [Browser invitation preview](evidence/challenges-2026-10-08/http-flow/browser-preview.png)

Standalone layout captures use controlled presentation fixtures, not live player history. HTTP captures use actual canonical races against a disposable local service, with isolated development and injected nonce-bound test Google identities; they do not establish real Google sign-in acceptance. No reference example time/name/lap count was inserted into shipping data.

Remaining acceptance: owner layout/creation feel, phone touch/keyboard/safe areas, native Sharesheet and cold/resumed URI behavior, mobile performance, current Google sign-in configuration, and deployment of migration/API/worker together to the intended development backend. No retained cloud data, production service or player file was changed. Push notifications, friends/automatic delivery, automatic rematches, lifetime head-to-head statistics, share images/video, store installation routing and deferred install attribution remain later work, as proposed.

## Rollout configuration

Deploy migration `0020_challenges` once, then matching API/worker code. Reuse the existing stable `BMT_PUBLIC_BASE_URL` for `/c/{code}`. Existing authentication, queue, verification and storage configuration remains required. Preserve existing data and old immutable boards; do not reset anything to install this feature.

For verified HTTPS opening, build with `BMT_CHALLENGE_LINK_HOST` set to the intended hostname. Configure that same backend with `BMT_ANDROID_APP_LINK_PACKAGE` (default `org.circuit01.handlinglab`) and comma-separated `BMT_ANDROID_APP_LINK_CERTIFICATES` containing the actual public signing certificate SHA-256 fingerprints. Without fingerprints `/.well-known/assetlinks.json` returns 404; no fabricated association is published. Release and debug fingerprints must be configured deliberately. The current debug export has the custom scheme fallback; HTTPS host verification and production deployment remain unperformed.

The browser preview currently has Open and code fallback. It does not invent a Play Store listing or promise automatic invitation restoration after installation. Installed clients can also use `--challenge={code-or-link}` on desktop.

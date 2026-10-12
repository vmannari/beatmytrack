# Control Room: backend UI v1

Owner request: 2026-09-29, implement `temp/BMT_Backend_UI_Draft_v1`.
Requirements: **B01–B07, B18, B21, B23, B28, RW01–RW08, V03, Q01**.

## Implemented slice

The live console is served at `/admin` by the existing FastAPI service, with the
reference's dark navigation rail, light workspace, teal actions, eight sections,
responsive cards/tables, global search and explicit confirmation dialogs. The
owner-supplied `source/style.css` is the base stylesheet; layout additions and live
application code are repository-owned. No synthetic prototype records or metrics
are included. No artwork/font downloads, JS framework, analytics SDK or runtime
external dependency was introduced.

- Overview queries real account, track, submission and queue counts. Daily activity
  means **submitted attempts**, not foreground sessions or completed local races.
  Reporting windows are rolling UTC windows; account/track totals and queue are
  lifetime/current, explicitly labelled. Charts show at most 14 calendar days.
- Players: bounded name/UUID search, state filter, pagination, provider names without
  subjects, permanent resume balance and the last 20 submitted races.
- Tracks: version search, publication filters, parent visibility, ratings, hashes,
  creator/proof identities, immutable manifests and a stored-route SVG schematic.
  The schematic is not authoritative road geometry or an elevation preview.
- Races: bounded state/identity search, outcomes, verifier attempts/failure codes,
  tick/lap evidence, replay hash, pinned board/vehicle/track identity and PB status.
- Economy: real resume grant history and balance inspection. No currency grants or
  simulated provider transactions.
- Live operations: current compatibility boundary; no invented activation controls.
- Analytics: real submission counts and outcome distribution; missing client
  telemetry is explicitly unavailable.
- System: current API/database observation, paginated verification jobs, durable
  audit history and owner/analyst capability explanation.

Lists cover all time; the top reporting-window selector affects overview/analytics.
Global search spans players, track versions and races, returning up to eight matches
per domain. Lists are bounded to 100 records/request (UI: 25) with stable ordering.

## Administrative commands and access

`BMT_ADMIN_OWNER_KEY` and `BMT_ADMIN_ANALYST_KEY` are separate, minimum-32-character
credentials. Empty values disable that role. They must differ from each other and
from the development game key. Authorization is checked for every administrative
API request; a game session never implies admin access. Keys stay in tab memory,
not URLs, localStorage or sessionStorage. Reload/Lock clears access. Normal player
sessions and provider subjects are never returned by admin record projections.

Owners can restrict/restore accounts and hide/show tracks. Analysts can inspect but
cannot execute commands. Each command requires a UUID idempotency identity,
expected current state, reason and acknowledgement. State and append-only audit
entry commit together. Identical retries return the original audit result; changed
payloads/revisions conflict. Concurrent identical PostgreSQL commands are tested.
Restrictions revoke existing player session families. Restoration requires a new
login. Hiding retains immutable versions, publication state and race evidence.

Migration **0007_admin_audit** adds durable before/after, reason, role actor,
correlation ID and command identity. There is no endpoint to edit/delete audit rows.
This is application-level append-only history, not a tamper-evident external log.
Credential roles identify audit actors; individual admin SSO/MFA is not implemented.
Use HTTPS and a private administrative network for a hosted deployment. Public/NAS
production deployment was not performed.

## Local use

Run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 BackendStart`.
The existing launcher generates distinct owner/analyst keys in ignored
`.tools/bmt-pc.env`, retains them on later starts, migrates and starts the PC stack.
Open **http://127.0.0.1:18181/admin** and use `BMT_ADMIN_OWNER_KEY` from that local
file, or `BMT_ADMIN_ANALYST_KEY` for read-only inspection. Keys are not printed in
logs or copied into the game configuration. Both Compose definitions pass the
optional keys; production defaults stay disabled.

## Changed files

`backend/bmt_backend/admin.py`, `admin_models.py`, `admin_ui/*`, migration
`0007_admin_audit.py`; router/readiness registration in `app.py`, settings validation
in `config.py`, migration metadata in `migrations/env.py`, static package data in
`backend/pyproject.toml`; both deployment Compose files and `pc_development.py`;
`tests/test_admin.py`, updated schema expectation in `tests/test_auth_postgres.py`;
`deploy/capture_admin.py`; this document and the development/phase status entries.

## Verification and evidence

- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_admin.py -q`:
  **7 passed**, including actual PostgreSQL concurrent duplicate-command handling.
- Focused initial authentication suite: **34 passed**. Admin + PC launcher checks:
  **11 passed** before adding the PostgreSQL test.
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 BackendStart`:
  image built, exact Linux Godot verifier checked, migration completed and PC API
  health/readiness passed. Existing PC player records retained.
- `.tools/backend-venv/Scripts/python.exe backend/deploy/capture_admin.py`:
  **passed** against the actual PC PostgreSQL/API. Eleven routes; owner/analyst
  sign-in, search, inspection, confirmation cancel/Escape, 390px responsive layout,
  mobile navigation, lock/reload. No live player mutations are made by this capture.
- Browser-only Playwright was installed into the developer virtualenv, not server
  runtime dependencies. Initial certificate attempts failed; the existing
  `.tools/backend-ca.pem` trust bundle succeeded without disabling TLS verification.
- Initial full suite: 163 passed / 6 skipped / 12 errors / 1 failure. The disposable
  PostgreSQL container was stopped; started `bmt-backend-test`. A schema assertion
  still expected revision 0006 and was updated to 0007. A clean rerun is recorded
  below. Initial live browser test found a PostgreSQL GROUP BY bind-expression
  mismatch; shared UTC-day expression fixes it, with a PostgreSQL regression test.
- Browser checks also caught and fixed a 5px mobile overflow and inaccessible
  navigation-close path. Production CSP remains enforced during browser checks.

Screenshots from real local data:
[Overview](evidence/backend_ui/overview.png),
[Tracks](evidence/backend_ui/tracks.png),
[Track inspector](evidence/backend_ui/track_inspector.png),
[Confirmation](evidence/backend_ui/confirmation.png),
[Mobile browser width](evidence/backend_ui/mobile.png).

## Remaining acceptance and explicit boundaries

Owner visual/workflow acceptance remains. No Android export or physical-phone test
was performed; responsive browser emulation is not device acceptance. No new game
physics or handling changes belong to this slice.

The draft's broader backend services remain unimplemented: purchase verification /
recovery, currency ledger corrections, privacy export/deletion, live configuration
activation/rollback, retention/device/revenue telemetry, worker heartbeats,
backup/storage-cost monitoring, race invalidation and leaderboard rebuild commands,
job retries, individual staff SSO/MFA, CSV exports, saved views and full ghost playback.
The console does not offer fake executable controls for these services. Future
configuration and commerce services still require their own domain implementation
and approved contracts. Audit history, track visibility and account restriction
are the implemented administrative workflow, not a claim that all 30 prototype
screens are backed by production services.


### Final clean verification

Full rerun: **177 passed / 6 expected SQLite concurrency skips**, 97.87 seconds.
Command: `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests -q --tb=short`
with the existing disposable `BMT_TEST_DATABASE_URL` injected from the ignored test
configuration and its hostname set to `127.0.0.1` (avoids localhost IPv6 connection
timeouts). Output: `.tools/admin-regression.log`. The earlier cloud-client failure
also passed on this clean run. No failing assertion was disabled.

Ruff checks for the new API/models/migration/settings/test/capture files pass.
The final browser capture passes with live PostgreSQL data and enforced CSP;
overview, track inspector, confirmation and mobile captures were visually inspected.

## Staging feature review, 2026-10-08

The owner requested investigation of the retained staging management UI for
analytics, troubleshooting and development data manipulation. This is a review
and proposed implementation sequence. No runtime feature, cloud setting, player
record, purchase or entitlement was changed.

Requirement mapping: **B01-B07, B14, B16-B17, B21-B24, B28, STORE04-STORE07,
PUR01-PUR08, RW05-RW07, Q01**. AR01-AR10 below identify proposed review items;
they do not establish new accepted product or payment rules.

### What was actually inspected

Authenticated, read-only inspection of
[the owner's staging console](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app/admin#overview),
its API responses, current Cloud Run configuration and the matching workspace
implementation. The configured owner credential was resolved through its existing
Secret Manager binding and used in memory; no credential payload was printed or
saved. Existing Edge and Playwright were used without installing dependencies or
disabling TLS/CSP. Public HTML, both scripts and CSS matched workspace bytes.

At the final observation (2026-10-08 18:09 UTC / 21:09 Europe/Helsinki), staging
reported 343 accounts, 337 distinct submitting accounts in the rolling seven-day
window, 4,216 verified submissions, 36 track identities and 243 versions. These
figures include artificial accounts/attempts and are operational workload counts,
not real-player engagement. They changed during inspection as the existing worker
continued ordinary races. Separate endpoint reads are not an atomic snapshot.

Staging uses development configuration, GCS objects, one compatible available
worker and schema `0019_discovery_snapshots`. Owner admin access is configured;
analyst access is absent. The public bootstrap explicitly reports purchase
simulation disabled. All five product controls are enabled/editable, but the
purchase-history endpoint returned an empty first page with no continuation.
Nothing was toggled, purchased, granted, reset or settled during the review.

### Confirmed gaps and proposed work

| Item | Finding and implication | Proposed behavior / priority |
|---|---|---|
| AR01 | Overview groups all `Run` rows and counts all players without excluding artificial drivers. Player list/detail projections omit the existing `is_test_driver` and country fields. The current screen cannot explain how much activity represents human players. | First: expose account classification in this diagnostic console and add explicit analytics population scopes. Default product analytics to real-player activity; retain all-population workload views. Count distinct player UUIDs without multiplication from linked identities. Preserve public competition isolation and the unified in-game histogram. |
| AR02 | The 30/90-day chart always renders at most 14 daily bars. Overview drilldowns drop the reporting-window boundary and open all-time lists. | First: a shared UTC date range propagated to chart, totals, lists and export. Display all selected days or clearly selected weekly aggregation. Link a chart day to exactly its attempts. |
| AR03 | GCS returns `storage_free_bytes: null`; JavaScript converts this to **0 GiB**. The backend supplies latency, infrastructure-failure rate, expected/available builds, lifecycle counts and worker durations which the console omits. A filesystem backup marker reports `not_configured` and does not observe Cloud SQL backups. | First: render missing measurements as unavailable, show compatible-worker readiness and useful existing health fields with observation age, and add provider-specific backup/object-storage observations. Report backup completion and restore-test evidence separately. |
| AR04 | Player support is a generic record plus 20 recent races, current balances and a separate purchase list. There is no coherent history of access changes, slot consumption, resume receipts, administrative actions or related verification failures. | First development slice: a player workspace with current access, linked purchases/slot consumption/resume receipts, paginated activity and audit history. Search by player, purchase, race, version, command and correlation identifiers. Add named saved filters and bounded CSV/JSON exports. Display unknown history honestly. |
| AR05 | Admin purchases are read-only; the only commerce command toggles product availability. Existing simulated pending settlement and ad-free adjustments are player-authenticated development endpoints, not administrator commands. Staging has simulation disabled. | First development slice: separately configured owner-only simulated purchase creation, pending approval/decline/cancellation, monthly expiry, simulated ad-free reset and slot adjustments. Add domain services and audited commands rather than calling player endpoints with impersonated sessions. Each action previews exact consequences and uses stable idempotency plus expected-state checks. Enabling staging simulation is a separate configured rollout. |
| AR06 | Race inspection provides pinned manifests, outcomes, attempts, ticks and hashes, but not a linked ticket/upload/lease/verification timeline, replay inspection, compatibility explanation or recovery actions. Track validations are included in health but the jobs list is only `Run` rows. | Next: race and track-validation troubleshooting with failure explanations, lease/attempt/worker history where retained, log links, exact build comparison and protected evidence retrieval. Retry only recoverable infrastructure failures against the original pinned contract; never silently rescore or edit a verified time. Record invalidation/rebuild needs its own domain workflow. |
| AR07 | Analytics contains submission counts and status distribution. There are no track/car/biome breakdowns, returner cohorts, creator trends, rivalry participation or time-to-verification distributions. | After population/date correctness: analytics computed from authoritative stored records, with explicit definitions, pinned-version grouping and drilldowns. Use indexed aggregates or bounded reporting jobs as volume grows. Distinguish submitted, verified and distinct-player measures. |
| AR08 | Foreground sessions, menu/race abandonment, offline attempts, crashes, ANRs, device model/performance and client build are not captured by this console's data source. Server records cannot reconstruct them. | Later telemetry slice: define a small first-party event/diagnostic contract, queue/retry/deduplication, privacy and retention, then instrumentation and dashboard coverage. No third-party analytics dependency is implied by this review. Mark event start dates so earlier missing data cannot appear as zero. |
| AR09 | `Purchase` stores provider, product, state and create/fulfillment timestamps, but no paid amount/currency snapshot, provider notification history, refund/revocation lifecycle or complete entitlement change ledger. Catalog EUR test prices cannot establish revenue. | Real billing slice: verified provider lifecycle, immutable delivery/adjustment evidence, reconciliation and receipt-time financial fields before any revenue/refund dashboard. Keep simulation and real fulfillment distinct. Real refund/revocation policies remain an owner decision. |
| AR10 | Owner/analyst authorization and transactional audits exist, but actors are shared credential roles. Staging has no analyst credential. There is no individual administrator identity, support/operator role, command permission matrix or audited batch-job workflow. | Alongside expanded mutations: separate read/support/development capabilities and preserve append-only before/after/reason/command records. Before production operational use: individual admin authentication and appropriate MFA. Large actions need scoped previews, durable progress and recovery; no generic table editor. |

Administrative population filters and simulation distinctions above belong in
this explicitly requested diagnostic UI. They do not reintroduce Player/Test
views, TEST badges, counts or source explanations into normal game screens.

### Recommended first vertical slice

Implement **player support and development purchase controls** (AR04-AR05), with
the population/date/null-value correctness work from AR01-AR03 needed to trust
the same records. Preserve the established visual shell; focus on completing
workflows. A useful first acceptance scenario is:

1. Find a development player by name and inspect current real/simulated access,
   slot consumption, purchases and relevant history in one workspace.
2. Preview and create a pending simulated slot purchase; show that pending grants
   no capacity. Approve it and observe one fulfillment despite retries.
3. Preview a simulated ad-free expiry/reset or slot adjustment and record the
   administrator, reason, exact before/after and stable command identity.
4. Reject analyst writes, disabled-simulation commands, ineligible identities,
   changed-state confirmations and attempts to alter real provider evidence.
5. Navigate from a related failed race to its pinned verification diagnosis and
   export the bounded selected evidence. No raw identity subjects, session keys
   or provider receipt tokens enter the view or export.

Simulated controls must retain the existing explicit development and identity
gates. Resetting purchased capacity must account for irrevocably consumed
publication slots rather than deleting publications or rewriting their evidence.
Resetting simulated ad-free access must preserve real purchased access. Real
Google Play purchases, provider refunds and production deployment remain outside
this proposed development slice. Broader analytics (AR07) and new client telemetry
(AR08) follow as separate reviewable slices.

### Actual verification, evidence and limitations

- Authenticated Edge reads covered Overview, Analytics, Economy, System health
  and Access: all loaded without a console error or JavaScript exception. Lock
  cleared the credential input. Unauthenticated overview returned 401. This
  exercised read access, not live mutation denial or purchase fulfillment.
- A 90-day selection produced exactly 14 bars. Health JSON returned null local
  capacity with `storage_backend: gcs`; the inspected browser displayed 0 GiB.
- Existing local admin/store/commerce regression with PostgreSQL parametrizations
  deselected: **35 passed, 3 skipped, 1 failed, 27 deselected**. The failure is
  `test_existing_publications_are_grandfathered_without_new_initial_reward`:
  its historical-schema fixture lacks `players.country_code` required by the
  current ORM. No backend or assertion was changed to conceal it.
- A targeted existing PostgreSQL fixture could not connect to the configured
  disposable database at localhost:55439; **one setup error, 11 deselected**.
  PostgreSQL concurrency was therefore not validated in this task. The initial
  combined run was interrupted after repeated setup errors.
- Initial diagnostic attempts encountered the sandbox's socket restriction,
  terminal encoding, a relative gcloud trust-bundle path, CSP string-evaluation
  and chart-render timing issues. The read-only probe was corrected; TLS/CSP,
  authentication and runtime code were preserved.

Commands from project root, except pytest from `backend/`:

```powershell
.\.tools\backend-venv\Scripts\python.exe docs/evidence/admin-review-2026-10-08/review_staging.py
..\.tools\backend-venv\Scripts\python.exe -m pytest tests/test_admin.py tests/test_store_admin.py tests/test_commerce.py -q -k 'not postgres' --disable-warnings --tb=short
..\.tools\backend-venv\Scripts\python.exe -m pytest tests/test_store_admin.py -q -k 'test_public_catalog_and_admin_authentication and postgres' --disable-warnings --tb=short --maxfail=1
```

Evidence: [redacted observations](evidence/admin-review-2026-10-08/review.json),
[read-only probe](evidence/admin-review-2026-10-08/review_staging.py),
[Overview](evidence/admin-review-2026-10-08/overview.png),
[90-day Analytics](evidence/admin-review-2026-10-08/analytics-90-days.png),
[Economy](evidence/admin-review-2026-10-08/economy.png),
[System](evidence/admin-review-2026-10-08/system.png),
[SQLite results](evidence/admin-review-2026-10-08/sqlite-regression.log),
[PostgreSQL attempt](evidence/admin-review-2026-10-08/postgres-attempt.log).

Changed files are this document, development/phase status entries and the
read-only probe/evidence under `docs/evidence/admin-review-2026-10-08/`. The
task-only review patch and documentation snapshots preserve the already modified
workspace. No runtime code, schema, competitive contract or cloud data changed.
No deployment, database migration, provider transaction, mobile export or physical
phone test was performed; phone attachment was not checked. Remaining acceptance:
owner priority/workflow review, followed by separately implemented command and
analytics contracts, SQLite/PostgreSQL concurrency, live rollout and device work
appropriate to each accepted slice. This review is not feature acceptance.

## Player support and audited development controls, 2026-10-08

The owner accepted the player workspace, audited development purchases and
date/display corrections, and explicitly requests that artificial drivers remain
ordinary players in administrative data for now. This supersedes the AR01
population-filter proposal above. All administrative account/activity totals keep
every player; this slice adds no population switch or artificial-driver badge.
Public competitive rankings, rating/eligibility rules and internal development
gates remain independent and unchanged. Broader analytics/telemetry follow later.

Requirements: **B01-B07/B14/B16/B21/B23/B28, STORE04-STORE07, PUR01-PUR08,
RW05-RW07, Q01**, with the accepted portions of **AR02-AR05**.

### Live use

Reload [the retained staging console](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app/admin#players)
and reconnect with the existing administrator credential. Open any player to see
their effective access, purchased/initial and simulated access separately,
remaining/consumed publishing slots, banked/daily resumes and pending purchases.
The activity table combines purchases, publication-slot consumption, resume
receipts/grants, race submissions and player-related administrative commands.
Filter by activity/state or purchase/race/command/request identifier. Inspect
redacted evidence, open linked race/track records, paginate, or export the selected
page as JSON (25 default, 100 API maximum). All time clears the date boundary.

Eligible development players expose **Simulate purchase**, **Adjust slots**,
**Expire simulated month** and **Reset simulated ad-free**. Pending purchase rows
offer **Resolve** (approve/decline/cancel). Preview displays the selected order and
exact access changes, then requires a reason and explicit acknowledgement. A
lost-response retry retains the exact command identity/body. Changed state or an
expired five-minute preview requires closing and preparing a fresh preview.
Analysts see the same support records without mutation controls. Real Google-only
accounts, disabled accounts, production configuration and disabled simulation
cannot use these commands.

The five previously approved products and prices are unchanged. Newly created
orders respect availability and the existing 20-pending-order bound. Disabling an
item does not block settlement of an accepted pending order. Pending, declined
and cancelled outcomes grant nothing. Approved orders fulfill once through the
shared commerce domain. Slot adjustments change only **remaining simulated
slots** (nonnegative, bounded); they never refund/delete consumed publications.
Monthly expiry and reset affect simulated access only, preserving real purchased
access. These are development operations, not provider payments/refunds.

Overview/Analytics now use UTC calendar-day windows (including the current partial
day), display all selected 7/30/90 days with horizontal scrolling when needed,
and allow a custom 1-90-day inclusive-date selection. API boundaries are `since`
inclusive / `until` exclusive. Chart days and period-scoped totals carry exact
boundaries to their lists; current/lifetime counts retain all-time drilldowns.
The same boundaries apply to purchase lists and player history/export. Worker
health exposes existing compatibility/lifecycle, duration and failure-rate data;
missing GCS local capacity displays **Unavailable**, and raw manifests are folded
under Build compatibility. Provider backup/cost collectors were not added.

### API, transactions and schema

New routes:

- `GET /v1/admin/players/{player_id}/support`: redacted current support projection;
  reads never initialize entitlements/wallets or create grants.
- `GET /v1/admin/players/{player_id}/history`: scoped keyset cursor, activity/state/
  identifier/date filters; `download=true` returns a JSON attachment for one page.
- `POST /v1/admin/players/{player_id}/development/preview`: read-only exact before/
  after plan for a stable UUID command.
- `POST /v1/admin/players/{player_id}/development/commands`: preview-bound execution,
  reason/acknowledgement and permanent command identity. See the
  [command schema](../backend/schemas/admin-development-command-v1.schema.json).

Purchase inspection also accepts dates and purchase/product identifiers; global
record search includes purchases and command/request audit identifiers. Existing
entity/overview endpoints accept the same bounded reporting range. Current
entitlement/grant/receipt/projection tables and `AdminAudit` are reused; **no
database migration**, currency domain, provider SDK or new runtime dependency.
Shared pure commerce helpers make previews and fulfillment use the same rules.

Execution locks the same player boundary as existing publication/commerce writes
(SQLite writer reservation / PostgreSQL row lock). A preview digest binds player,
exact action/amount/arguments, time and authoritative before/after context. The
grant/access mutation and audit commit in one transaction. Duplicate delivery
returns the original result; changed payloads conflict. Product changes, stale
access, settled orders and expired previews cannot overwrite newer state. Audit
rows retain role actor, before/after, reason, command and request correlation; no
credential/provider receipt payload is stored. Individual staff SSO remains deferred.

### Actual acceptance and retained staging update

| Actual command/check | Actual outcome |
|---|---|
| `.tools/backend-venv/Scripts/python.exe scripts/test_admin_support_postgres.py` | **113 passed, 5 skipped**, SQLite plus owned PostgreSQL17; existing admin/store/commerce/resume suites plus support/command tests. Eight concurrent identical commands yield one purchase, one grant and one audit. Both databases enforce tied-time cursor ordering, range boundaries, stale/exact-preview rejection, real-account/read-only/configuration gates and real-access/consumed-publication preservation. Owned container removed after label/ownership check. |
| `.tools/backend-venv/Scripts/python.exe scripts/test_admin_support_console.py` | **10 browser workflow checks, zero failures**, installed Edge against a newly owned loopback SQLite service. Actual HTTP commands exercise pending/approval/retry, slots/expiry/reset, redacted export, pagination, 90-day/drilldown behavior, analyst controls and 1440/960/390px containment; screenshots inspected. Missing-capacity response injection is explicitly a fixture. Fixture server stopped; private fixture retained under ignored `build/`. |
| Python Ruff for changed runtime/tests/tools; bundled Node `--check` for all three scripts; scoped `git diff --check` | Passed. One existing Starlette/httpx deprecation warning remains in pytest. |
| Frozen `.tools/admin_support_rollout.py prepare / build / backup / deploy / smoke` | Owned retained development API/worker/jobs updated. Fresh **successful SQL backup 1791486884403** precedes rollout. **112 packaged game files unchanged byte-for-byte**; only admin/commerce/UI files and router registration change. Canonical physics/rules/content/controller and existing resources/secret bindings retained; schema stays `0019_discovery_snapshots`. Existing native replay/storage/schema smoke job completed successfully. |
| `.tools/backend-venv/Scripts/python.exe docs/evidence/admin-support-2026-10-08/inspect_deployed.py` | Authenticated **read-only live acceptance passed**: all five assets match workspace, support/history/control eligibility load, pending preview grants nothing and creates no purchase, all **343 accounts** remain included, 90 daily bars render, GCS capacity is Unavailable, zero JavaScript errors and Lock clears access. No live purchase command executed. |

Only the development API/worker gain `BMT_PURCHASE_SIMULATION_ENABLED=true`; the
migration/smoke/catalog jobs retain their stricter original configuration. All
existing identities, purchases, entitlements, raw histories, boards and track
objects are retained. No reset/reseed, actual payment, migration or production
deployment occurred. Operator credentials stayed in memory/validated temporary
private registry configuration; the temporary authentication directory was removed.
The successful SQL backup is not a claim that a full restore was rehearsed.

Initial tests caught an invalid production-test configuration and a wall-clock
second-boundary assumption in the new history fixture; final fixtures preserve
all guards and explicitly tie timestamps. The historical commerce migration
fixture previously inserted today's country-bearing ORM into schema0015; it now
seeds the actual reflected legacy table, retaining every migration assertion.
Browser pagination initially needed response synchronization; screenshot scroll/
media-transition capture and a tooling-only Playwright cleanup warning were
corrected. Packaging first rejected production-configured jobs under an overly
broad preparation guard, then caught a build-script import path; development-only
flag scope and the explicit build import path were corrected without loosening
runtime gates or changing game files. Failed attempts remain in the retained logs.

Evidence: [live support](evidence/admin-support-2026-10-08/live-player.png),
[live Analytics](evidence/admin-support-2026-10-08/live-analytics.png),
[live System](evidence/admin-support-2026-10-08/live-system.png),
[desktop fixture](evidence/admin-support-2026-10-08/player-1440.png),
[compact fixture](evidence/admin-support-2026-10-08/player-960.png),
[narrow fixture](evidence/admin-support-2026-10-08/player-390.png),
[preview](evidence/admin-support-2026-10-08/pending-preview.png),
[final backend log](evidence/admin-support-2026-10-08/postgres-final.log),
[live checks](evidence/admin-support-2026-10-08/live-checks.json),
[rollout receipt](evidence/admin-support-2026-10-08/development-rollout.json),
[packaged game proof](evidence/admin-support-2026-10-08/packaged-game-proof.json).

Changed files: `admin_ranges.py`, `admin_support.py`, `admin_purchase_controls.py`,
existing admin/commerce/router modules; `admin_ui/{app,commerce,support}.js`, HTML
and CSS; support tests and the legacy commerce fixture correction; two opt-in
test runners and the command schema; AGENTS owner override, this documentation,
development/phase status and dated evidence/operator snapshot. The task-only
review patch preserves prior/concurrent changes; no mixed-workspace commit.

Remaining acceptance: owner workflows/visual review, physical-browser usability,
real provider purchase/refund rules and individual admin identity. Custom saved
views, whole-history export jobs, new analytics/telemetry, extended verifier
recovery and provider backup/cost observations remain separate slices. History
reports retained records, not an invented complete historical event ledger.
No phone attachment check, physical-device test, Android export/install or full
Godot `Validate` was performed; gameplay/simulation source was not edited.


## Backend Studio specification and first evidence slice, 2026-10-11

The new 92-row package is inventoried against actual source and data. The local additive Studio shell and read-only player/race/pinned-version/evidence bundle slice are complete: 66 backend tests passed (two duplicate SQLite row-lock cases skipped), plus 11 new and 10 inherited browser checks. No deployment, live writes or device test occurred. See [the implementation report](BACKEND_STUDIO_2026_10_11.md) for endpoints, commands, captures, limits and the task-only review checkpoint, and [the inventory](BACKEND_STUDIO_REQUIREMENTS_2026_10_11.md) for all requirement evidence.

The three questions raised in that initial inventory were resolved by the owner
on 2026-10-11. Every Studio total includes all players, including artificial
drivers; per-player Real/Artificial uses authoritative `Player.is_test_driver`
only. Development authentication is not an artificial-player marker. This
admin-only flag supersedes the earlier no-classification presentation restriction,
while preserving all-player totals and public competition isolation. The free
publishing allowance is one INITIAL slot; monthly rewards may be considered
later, without implementation authorization. One month is a UTC calendar month
on the matching day (September 12 → October 12), preserving time, short-month
clamping and extension from active expiry. These three decisions are no longer
pending. See [the policy follow-up](BACKEND_STUDIO_POLICIES_2026_10_11.md) for
actual flag and calendar/initial-allowance checks. Original requirement inputs,
approved prices, consumed publications and resume promises remain unchanged.


## Authorized Studio staging deployment, 2026-10-11

The owner subsequently authorized deployment. The reviewed nine-file Studio overlay is now live on the existing retained staging service, with fresh backup, zero-traffic canary, unchanged schema/game/commerce and preserved configuration. Exact-image47 tests and live API/asset/flag/browser/native-worker checks passed. Earlier no-deployment statements describe their original local tasks. See [the actual deployment report](BACKEND_STUDIO_DEPLOY_2026_10_11.md) for commands, evidence, image/revision and remaining boundaries.

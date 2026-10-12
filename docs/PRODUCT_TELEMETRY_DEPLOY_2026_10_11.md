# Telemetry deployment — 2026-10-11

The owner explicitly requested deployment of the signed-in telemetry/product
analysis slice. This rollout targets the existing retained staging service in
`beat-my-track`, `europe-west1`, with owner
`e7a444abdf684b7cbd228d9e7948c65e`. Guest coverage remains unavailable and Studio
totals include artificial players. Provider payments/revenue and historical
client activity are not inferred from race records.

**Deployed and enabled** on the normal [Studio URL](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app/admin#product).
Revision `bmt-stg-e7a444ab-api-00033-jeq` serves100%, schema is
`0025_product_telemetry`, and API/worker/migration/smoke/catalog use the same
candidate digest. The new capability advertises signed-in-only collection with
50-event/64KiB batches and explicit unavailable guest coverage. The product
processor's live watermark advances; no received activity has been fabricated.
Completed **20:19:32 Helsinki / 17:19:32 UTC**. The controlled write-maintenance
window was **20:01:55–20:16:20 Helsinki**, approximately14m25s, covering the final
stopped-writer backup, cloud migration/job startup, parity and both warm passes.

## Frozen scope and prerequisite

The candidate is built from the exact deployed Studio image
`8146e3af2c3b61fc1b6053d4827cb668925334c4203f2563d1428217bd677d89`.
Candidate digest:
`98cf7793107461526ebb6da4d04b480979338c72378332c00e5f1d066ca78b93`.
Its explicit 25-file backend overlay adds telemetry, Studio Product analytics,
schema25 and a small worker supervisor. All **114 packaged game files** and
every unrelated backend file remain identical to the deployed parent. Current
workspace handling/art/client changes are not imported into server verification.
[Package proof](evidence/product-telemetry-deploy-2026-10-11/packaged-proof.json)
records the exact file list and protected hashes.

Telemetry migration `0025_product_telemetry` follows
`0024_lap_personal_bests`. Migration24 changes lap/histogram triggers and starts a
bounded lap backfill, so this rollout includes its matching minimal models,
reader, maintenance/retention and worker dependencies. Surgical source patches
preserve the parent's other routes, expired-ticket behavior, heartbeat behavior
and pinned game contracts. No whole dirty-workspace image is deployed.

The existing worker pool retains its one CPU and memory/instance configuration.
`bmt_backend.service_worker` starts competitive verification and a separate
product process, with the product child at Linux **nice19**. The product process
uses one DB connection and an initial **100-event** batch to shorten ingestion
lock holds. TERM/INT forward to both children; failed children fail the service,
and owned descendants are reaped after bounded shutdown. No additional always-on
cloud instance, analytics vendor or runtime dependency is introduced.

## Actual pre-deployment evidence

- Fresh ownership/image/read-only inspection: schema23,395 inclusive players,
  one ready worker and zero queued verification jobs. Database71MB,133 boards,
  4,311 attempts (4,310 verified),2,883 race PBs and1,962 histogram snapshots.
  [Aggregate baseline](evidence/product-telemetry-deploy-2026-10-11/database-before.json).
- A bounded read-only repeatable-read snapshot retains only salted UUID aliases,
  purpose/test-population/reset metadata, player boolean flags and numeric race
  facts/PB references. No identities, subjects, names, credentials, content,
  poses or entitlements are exported. Private facts stay in ignored build
  storage; public evidence contains aggregates/hashes only.
- Actual snapshot rehearsal on a newly owned local PostgreSQL17 database:
  **2,886/2,886** durable minima and **2,883/2,883** eligible visible minima match;
  all133 boards complete, zero invalid ordinary records, race PBs and attempt
  counts unchanged, and zero historical telemetry rows. Migration0.204s;
  bounded backfill plus offline parity7.879s. These are local timings, not a live
  maintenance-duration guarantee. [Receipt](evidence/product-telemetry-deploy-2026-10-11/lap-rehearsal.json).
- Exact candidate: **106 SQLite passes/3 skips**, **168 PostgreSQL passes/3
  skips**, **53 maintenance-gate checks**, and **11 actual candidate browser
  checks**. Browser bundle4,300 bytes for ten fixture days; one prepared query
  per refresh, no idle polling, zero JavaScript errors. Owned containers and
  networks removed. [Acceptance](evidence/product-telemetry-deploy-2026-10-11/exact-image-acceptance.json).
- Supervisor:10 actual Linux subprocess checks and a real container PID1
  TERM/nice check pass. Worker priority0/product19, clean grace and no orphan
  remain. No live race or player is created for acceptance.
- Fresh successful Cloud SQL backup **1791737979545** precedes maintenance;
  final stopped-writer backup **1791738272531** precedes migration.
  Backup success is not a rehearsed-restore guarantee.

The browser harness initially needed a deeper frozen-test path for inherited PG
fixtures, Playwright imports before a test-launcher interception, and an actual
container listener/loopback port health wait. Frozen test bytes, candidate code
and assertions were preserved. One delayed diagnostic log chunk was reread and
the complete checksum validated before accepting the private snapshot.

## Actual live outcome

- Maintenance first blocked only `/v1/` writes with retryable503 and paused the
  existing verification instance. Stopped-writer counts and race-PB hash matched
  the pre-migration snapshot; race and track-validation queues were both empty.
- Owned `cloud_setup` migrated23→24→25. Runtime role `bmt` has SELECT/INSERT/
  UPDATE/DELETE on product and lap tables and remains non-superuser. Ownership
  guard/secret bindings stay protected.
- Live backfill inspected4,311 attempts in133 batches; **2,886 ledger minima**
  and **2,883 eligible visible minima** matched the independently computed hashes.
  All133 boards complete, zero invalid ordinary facts, and race PBs/runs/players
  unchanged. Product-event table remained empty: history was not recast as
  telemetry. Backfill plus parity14.863s; public warming/initial checks62.131s.
- Public warming refreshed980 snapshots. A separate valid development diagnostic
  warmed980 artificial-inclusive snapshots in63.137s; **all published snapshots
  are available**. Two nonpublished snapshots remain invalidated and do not
  represent published discovery data. The first private warm lacked its required
  development settings; an isolated ephemeral key satisfied that invariant
  without a listener, authentication session or live auth-setting change.
- Zero-traffic canary ready25, bootstrap limits/guest flag, genuine precollection
  unknown values and all seven exact UI asset hashes passed. It was then promoted
  to100%; the original one worker instance resumed with separate nice19 product
  processing and100-event batches. CPU/memory/secret/base configuration is guarded.
- Existing native/storage/schema smoke passed; one competitive worker is ready.
  Product `processor_observed_at` and `processed_through` are populated by the
  live projector, with collection not yet started and zero pending events at the
  recorded snapshot. No client activity or mature retention is invented.
- **Eight GET-only live browser checks passed**, zero JavaScript errors/writes/
  stored credentials. Four API GETs across the flow, one product read per refresh,
  all seven asset hashes, genuine unknown/maturity rendering and1440/1280/390px
  captures. [Receipt](evidence/product-telemetry-deploy-2026-10-11/live-product-browser.json).
- Temporary maintenance/canary tags removed; all image/runtime/ownership guards
  and100% traffic confirmed. [Completed rollout](evidence/product-telemetry-deploy-2026-10-11/rollout.json).

Screenshots inspected: [live Product analytics](evidence/product-telemetry-deploy-2026-10-11/live-product-1440.png)
and [narrow layout](evidence/product-telemetry-deploy-2026-10-11/live-product-390.png).
They contain real aggregate responses, no seeded live fixture/player identity.

## Rollout and rollback contract

The temporary maintenance image changes only the request boundary. When its
explicit maintenance flag is enabled, `/v1/` writes return retryable503 while
GET/HEAD/OPTIONS continue; ordinary local gameplay and persisted uploads are not
modified. The verification writer is paused/drained before migration. A backed-up
`cloud_setup` execution applies the owned schema and grants the runtime role
access to new tables while keeping it non-superuser and protecting the ownership
guard. Initial lap backfill/parity and stored histogram warming finish before
normal traffic reaches the new revision.

Exact-schema readiness stays strict. The schema25 canary is started **after** the
database migration; old schema23 readiness becomes unavailable during the
controlled transition. `/health` alone is not deployment acceptance. The new
canary receives zero ordinary traffic until ready25, bootstrap, data coverage,
all seven UI asset bytes and pre-collection unknown states pass.

Rollback before a committed migration can restore original23 traffic. After
schema25, use the tested compatible candidate with collection disabled and no
product child. Never blindly route schema23 code to schema25 or drop new data.
The rollback procedure is prepared; it is not claimed to have been exercised on
the retained live database.

## Commands and remaining acceptance

`.tools/backend-venv/Scripts/python.exe .tools/product_telemetry_rollout_20261011.py`
provides explicit inspect/extract/database-inspect/snapshot/prepare/build/push/
backup/maintenance/stopped-check/migrate/initialize/canary/promote/smoke/finish
stages and schema-aware rollback. Frozen exact-image tests run through
`.tools/product_telemetry_image_tests_20261011.py`. Live browser checks use
`.tools/product_telemetry_live_browser_20261011.py` and issue GET requests only.

Backend activation cannot supply menu/store/onboarding observations from older
game binaries. The updated signed-in client must connect and negotiate the new
bootstrap capability. D1/D7 need actual future eligible days; they are not filled
with test observations or historical submissions. Android network/radio/battery
and device frame measurements, larger-population capacity/soak, full privacy
workflows, segmented/rolling analyses and real provider commerce remain the
limits listed in [the implementation report](PRODUCT_TELEMETRY_2026_10_11.md).
No phone test, Android export/install or store publication is part of this
backend deployment.

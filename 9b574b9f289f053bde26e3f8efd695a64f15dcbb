# Full cloud backend deployment — 26 October 2026

The owner-requested full backend is live on the existing
[cloud API](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app), in
`beat-my-track` / `europe-west1`, at schema **0070_reward_cache_revisions**.
API revision **bmt-stg-e7a444ab-api-00113-mos** and private Studio revision
**bmt-stg-e7a444ab-studio-00007-qol** receive their normal traffic. One matching
worker and all seven existing job definitions use the same immutable image.

Image:
`europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/backend@sha256:06bdc73b7a490614a8ad384ec1e235fa3466dd752c512446b37ede12cb343813`.
Frozen release source SHA256:
`3f02b1139d3b6b4b653dab9bdcff8456fcbf3c14d7617a35fa0c96eb0298eeb1`.

Requirements **FBD01–FBD05/R01/Q01**: freeze and test the complete package,
rehearse/migrate PostgreSQL with reviewed workload grants, preserve existing
data and configuration, coordinate every existing cloud target, and verify the
live release before completing the rollout. Full receipts and source hashes are
in [the machine-readable report](evidence/full-backend-deploy-2026-10-26/report.json).

## Scope and preservation

The release replaces the complete backend package and standalone canonical
project, including the race-work reductions, verification skip, ghost/cache,
daily track, challenge, gifting, security and existing website/Studio sources
present at the freeze. All **337 runtime package files** match the frozen
source. The existing locked dependencies and pinned Linux engine are retained.
The manifest is Godot4.7.2 / compiler27 / physics0.74 / rules23 / electric16,
with five laps and the recorded identities of all seven cars.

All ten existing owned targets are updated: API, worker, Studio, migrator,
smoke, catalogue, pace2, reporting-check, reporting-setup and Studio simulator.
Updating a job definition does not run its population, reporting-provisioning or
catalogue publication task. Runtime identities, secret bindings, environment,
resource/process settings and worker count are preserved. Public administration
remains unavailable; Studio keeps its existing IAM and named-staff boundaries.
Packing and cold archival are not enabled by this rollout.

Managed Cloud SQL backup **1793045662757** completed before migration. The
quiesced database had **311,517 rows across154 original tables**, and all154
table counts match after migration. No invalid indexes remain. Migrations add
the intended fields/tables and reset derived discovery cursors; existing race,
PB and reward history is not deliberately rewritten. Counts do not establish
byte-for-byte equality of private record contents. The provider-managed backup
is retained for restoration.

Automatic approval review rejected the proposed export of database fingerprints
because hashes derived from private records would leave the cloud without
specific authorization. That command was rejected before execution. The rollout
instead uses the managed backup and aggregate SQL counts; **no private rows or
private-record hashes were exported**. No alternate fingerprint export was run.

The API and Studio were placed in database-free maintenance, requests drained
for over90seconds, and the old worker stopped before the backup and migration.
The recorded main maintenance interval was about **12.77minutes**. New canaries
passed before traffic returned; one matching worker, empty queues and all16
discovery partitions were ready. Temporary tags are removed at completion.

## Actual checks and corrections

- Exact frozen Linux image with disposable PostgreSQL17: **520 passed,
  18 skipped, 3 deselected, 1 test-fixture failure**, in1276.35seconds. The failure
  tried to create default local object storage inside the read-only mounted
  source tree. `test_public_site_does_not_add_admin_service_routes` now uses
  pytest's writable temporary directory; its route assertions remain unchanged.
  All **4 website tests pass** against the same image with that corrected test
  file. The runtime image did not change. The original failure/XML are retained.
- PostgreSQL **62→70 synthetic rehearsal**: all **2,162 original rows across153
  tables** compare exactly; legacy3x3 challenges gain track_count3 correctly.
  These are invented records, not copies of player data. The measured0.386s is
  local rehearsal time, not cloud performance evidence.
- Native image import, exact Compact five-lap golden replay and ten-second
  rewind pass. The release copy of the golden fixture's old expected rules22
  label is corrected to the already actual rules23; controls, expected ticks
  and lap assertions remain unchanged. The initial strict build failure is
  retained. Workspace fixture and physics sources were not changed by deployment.
- Live native/schema/GCS smoke passes: **12,757 ticks**, two temporary diagnostic
  storage objects cleaned up, **zero player writes**.
- Live production-strength API privilege verification passes. The former shared
  SQL login remains disabled. Worker cannot read session tokens/staff or edit
  audit records; API cannot read staff; Studio cannot read session tokens.
- API/Studio readiness, schema and ghost/skip capabilities pass. Public
  administration returns404, and the private Studio still requires authentication.
  Its maintenance check initially returned the expected edge403 without an IAM
  identity; using the existing operator identity resolves the check without
  changing access policy.
- Public discovery traverses **30 tracks**, in20+10 pages, with no duplicate IDs.
- Three new schema0070 trigger functions are explicitly included in the reviewed
  privilege allowlist. The exact-image grant/drift tests and live API role check
  validate that correction. No broad function execution grant was introduced.

The release checks cover the listed selection, not the whole repository or a
production load certification. Existing reflection/deprecation warnings and
skip reasons are retained. No assertions, permission checks or runtime guards
were removed to get a passing release gate.

## Commands and evidence

Actual operational entry point, from the repository root:

```text
.tools/backend-secure-venv/Scripts/python.exe -X utf8 build/full-backend-deploy-2026-10-26/deploy.py <stage>
```

Executed stages: `inspect, freeze, build, fixture-fix, build, test, preflight,
rehearse, fixture-recheck, push, prepare-maintenance, quiesce, quiesce,
stop-worker, aggregate-snapshot, backup, migrate, canary, start-targets, promote,
smoke, authority, discovery, finish`. The proposed `snapshot` fingerprint stage
was rejected before execution and removed from the available actions.

Private resource descriptions, execution flags, environment files and credentials
stay in ignored task-owned build storage. The evidence directory contains safe
aggregate receipts, exact-image test logs/XML, package/source proofs and audit
copies of the executed scripts. Code copies are audit records; the actual
entry point above resolves its private configuration from this workspace.

Source changes required for rollout are limited to
`backend/bmt_backend/database_privileges.py` (three reviewed trigger signatures)
and the website test's temporary storage path. The task-only Git checkpoint
also includes deployment/status documentation; no mixed-tree commit, staging or
merge was performed. Concurrent changes remain intact. Local deployment receipts
are updated to the common image/schema for the existing retained environment.

Reload/rebuild the current game to refresh bootstrap and match the deployed
verifier. No APK/device install, attachment check, physical-device test, purchase,
interactive game sign-in, local PC backend update or owner-game restart was
performed. Real device/client acceptance, production cache-hit/cost measurement,
load/edge calibration and a restore drill remain separate operational checks.

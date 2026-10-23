# Latest backend and Studio deployment, 2026-10-16

Approved follow-up: both earlier approval requests are resolved. The27 matching
catalog revisions and scoped ordinary-payload deletion permission are live;
compiler27/physics0.59 is active. See
[completed follow-up](BACKEND_APPROVED_FOLLOWUP_2026_10_16.md) for preservation and
verification evidence. This supersedes the pending-approval status in the initial
deployment record below.

Owner instruction: **“deploy the latest backend and ui”**. The latest frozen
backend and UI code are deployed to the existing retained staging service:
[Overview](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app/admin#overview),
[Alarms](https://bmt-stg-e7a444ab-api-tzgxkrwzva-ew.a.run.app/admin#alarms).

Completed **2026-10-16 15:33:35 UTC / 18:33:35 Helsinki**. The source freeze is
identified by its manifest; later concurrent earned-coin/news migrations and
game changes are outside this deployment snapshot.

Requirements: **BUI01–BUI05, B05/B07/Q01**. API revision
`bmt-stg-e7a444ab-api-00054-rub` serves **100%** normal traffic. Schema is
`0036_community_safety`. The existing single worker and all three existing
migration/smoke/catalog jobs use the same final image:

`europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/backend@sha256:e22d20638d6d35d5d855296e4eadc07f32e99523488e7a89c9a5d4452c911310`

The final image contains the tested latest backend/UI and dependencies, including
the Overview, alarm lifecycle, privacy, sharing-safety and current admin views.
Its **existing compiler25 / physics0.54 race contract is preserved**. The prepared
compiler27 / physics0.59 image is uploaded and validated but is not serving.
No catalog versions or IAM permissions were changed by this deployment.

## Two explicit approvals remain pending

Automatic approval review rejected two proposed commands before execution:

1. **Runtime object-deletion IAM permission.** The current runtime has ordinary
   object creator/viewer roles. The proposed custom grant contains only
   `storage.objects.delete`, restricted to
   `gs://bmt-stg-beat-my-track-e7a444ab/bmt/v1/`; the independent
   `bmt-erasure-v1/` journal and existing IAM bindings are excluded/preserved.
   Review requires explicit owner approval for granting permanent deletion
   rights. [Concrete proposal](evidence/backend-latest-deploy-2026-10-16/storage-permission-proposal.json).
   Account erasure can record and process its journal/SQL stages, but deleting
   unreferenced ordinary payloads can remain retryable until permission exists.
   No real-account deletion was performed to test this.
2. **Appending 27 matching published track revisions.** All 27 current official
   track heads passed read-only validation with compiler27/physics0.59. Each
   needs a matching new manifest before switching the race contract. Original
   documents, old versions, ratings and historical scores would remain intact;
   review nevertheless requires explicit approval for the persistent catalog
   mutation. [Read-only plan](evidence/backend-latest-deploy-2026-10-16/catalog-preview.json).

Both approval questions were presented asynchronously. Neither received approval
during this rollout. The rejected commands were not retried or executed
indirectly. The safe alternative publishes the latest backend/UI while retaining
the exact prior native race package, supported geometry protocol and golden
proof. This avoids holding the service in maintenance for pending approvals.
The existing official catalog remains at **289 versions / 38 track identities**,
including its 27 visible official heads. The newer race contract remains pending.

## Preservation and deployment sequence

The actual previous image is digest
`1433fd6c63329c0869b48ae56d891cbf830ec73517c1a6e2e1e1bba99c1cc3b3`,
schema30, one compatible worker, no queued verification work. Ownership labels
and SQL deletion protection were checked. A frozen source snapshot avoids
shipping moving workspace files or presentation assets; only the native
verification whitelist is used for the prepared newer race package.

The latest backend changes 86 packaged backend files relative to the previous
image and packages 163 backend files in total. The existing deployed maintenance
write gate is retained in frozen middleware; this deployment-only adjustment
does not overwrite the shared workspace middleware. The final contract-preserving
image proves its backend bytes are identical to the tested candidate.

Fresh Cloud SQL backup **1792163638895** succeeded before maintenance or migration.
Writes then received retryable503 while the existing worker was paused. A
read-only snapshot recorded15 original-data fingerprints, and confirmed empty
race/publication/validation queues. Owner-fenced `cloud_setup` applied migrations
30→31→32→33→34→35→36 and granted the existing restricted database role access to
the new tables. The15 original-column fingerprints remained **exact** afterward:

| Original data | Preserved rows |
| --- | ---: |
| Players / identities | 421 / 420 |
| Track identities / immutable versions | 38 / 289 |
| Boards / race submissions | 151 / 4,473 |
| Race PBs / lap PBs | 2,953 / 2,956 |
| Ratings | 11 |
| Rivalry groups / memberships | 12 / 131 |
| Challenges / memberships | 1 / 1 |
| Purchases / resume wallets | 0 / 2 |

No original scores, identities or documents were rewritten or reseeded. New
nullable/default columns and the documented migration bookkeeping are additive;
the fingerprint comparison uses the original columns. Later legitimate activity
may change counts after normal traffic resumes.

A zero-traffic canary passed readiness, schema36, admin/source/case/catalog
reads, community/trajectory capability negotiation and **17 exact UI asset
hashes**. The existing worker count was restored before reopening writes.
The specific verified revision was promoted to100%. Native replay/storage/schema
smoke, matching-worker health and GET-only live Edge checks passed. Temporary
canary/maintenance tags were removed; all target image/configuration guards
passed. Retained local deployment/population receipts now point to the final
digest, and the owned deployment lock was removed.

CPU, memory, scaling, command/arguments, service accounts, secret bindings,
networking and existing ownership labels are preserved. The deployment adds no
always-on instance, bucket or database. IAM is unchanged. The database backup
is not a rehearsed-restore claim; schema34 erasure journals must remain intact
through any future rollback/restore.

## Actual commands and verification

Commands use `.tools/backend-venv/Scripts/python.exe` and the captured helper
[backend_latest_rollout_20261016.py](evidence/backend-latest-deploy-2026-10-16/tools/backend_latest_rollout_20261016.py).
Stages were separate invocations:

| Actual action | Outcome |
| --- | --- |
| `inspect`, `freeze`, `extract`, `prepare`, `build` | Owner-checked actual parent; frozen source and dependency hashes; Linux import, five-lap12757-tick golden replay and ten-second rewind pass for prepared compiler27/physics0.59. |
| `test` | **233 passed, 5 skipped**, 292.49s, exact candidate backend against owned SQLite/PostgreSQL fixtures in an internal Docker network. Temporary database/network removed. [Log](evidence/backend-latest-deploy-2026-10-16/exact-image-tests.log). |
| `push`, `backup`, `preview-catalog` | Tested newer-contract image uploaded; fresh successful backup; **27/27** current official heads validate without catalog writes. |
| `maintenance`, `snapshot`, `migrate` | Retryable write gate / zero workers, empty queue, migration36 and **15/15 exact** original-data fingerprints. [Before](evidence/backend-latest-deploy-2026-10-16/data-before.json), [after](evidence/backend-latest-deploy-2026-10-16/data-after-migration.json). |
| Proposed `grant-delete` / `catalog` | Automatic approval review rejected both before execution. No IAM or catalog mutation. Explicit owner requests remain pending. |
| `existing-contract`, `use-existing-contract` | Latest backend bytes preserved, old race geometry supported, old native golden replay/rewind pass; final image uploaded and existing job image references updated. [Proof](evidence/backend-latest-deploy-2026-10-16/existing-contract-proof.json). |
| `canary`, `verify-canary`, `promote`, `smoke` | Schema36 ready;17 byte-exact assets;100% final revision; one available matching worker; native/storage smoke passes. [Canary](evidence/backend-latest-deploy-2026-10-16/verify-canary.json), [live](evidence/backend-latest-deploy-2026-10-16/verify-live.json). |
| `backend_latest_live_browser_20261016.py` | **6 live browser checks**, zero JavaScript errors, failed admin reads or mutation requests. Overview/Alarms/source navigation,390px containment and Lock/storage clearing pass. [Receipt](evidence/backend-latest-deploy-2026-10-16/live-browser.json). |
| `finish` | Final target/configuration guards, traffic and receipt update pass; temporary tags and owned lock removed. [Rollout](evidence/backend-latest-deploy-2026-10-16/rollout.json). |

Initial failures are retained, not counted as passes: the first isolated test
mount lacked repository metadata; later tests exposed a too-short deletion
fixture loop, missing explicit sharing consent in two publication fixtures and
two Windows-only harnesses inside Linux. The completed deletion fixture uses100
bounded cleanup iterations; publication tests explicitly accept current terms
before publishing, preserving the new consent invariant. Windows-only native
HTTP harnesses were excluded from the Linux selection and were not claimed run.
The corrected233-pass suite retains all selected assertions. Initial receipts
are saved alongside the final test log.

Container logs required UTF-8 decoding, while Windows Cloud SDK credential
output required the host code page. The helper now selects encoding per command;
the existing canary was reverified successfully without changing credentials or
creating another revision. Existing Starlette/httpx and SQLite index-reflection
warnings remain. No secret/provider subjects or raw player records are included
in public receipts; private operational snapshots remain under ignored `build/`.

## Live views and limits

[Overview](evidence/backend-latest-deploy-2026-10-16/live-overview-1440.png),
[Alarms](evidence/backend-latest-deploy-2026-10-16/live-alarms-1440.png),
[narrow Overview](evidence/backend-latest-deploy-2026-10-16/live-overview-390.png),
[narrow Alarms](evidence/backend-latest-deploy-2026-10-16/live-alarms-390.png).
These are actual read-only aggregate views, with no synthetic live alarms or
decisions added. At verification all eight configured checks were available
and none fired. Alarm checking remains on demand, without notification delivery.

No Android export/install, phone attachment check, physical-phone test, live
purchase, real-account erasure, interactive Google sign-in, load soak or restore
rehearsal was performed. Owner appearance/workflow acceptance remains. The
separate catalog and deletion-permission approvals remain unresolved; deployment
does not imply permission for those mutations or claim the newer race contract
is active. Main Git index/HEAD and concurrent source work are preserved.

# Local artificial races and backend resource optimisation — 28 October 2026

<!-- BRO-DELIVERY-STATUS -->
Deployed to API, private Studio, the worker and seven jobs on immutable `sha256:225feb3f4d79075c1ad37579de3e1568eb7500fbd5edbb0857d4ca037f4d82b2`.
<!-- /BRO-DELIVERY-STATUS -->

Artificial races run in explicit, bounded local passes. The cloud worker verifies
uploads, handles publication and maintains discovery/telemetry; its empty-queue
path cannot start an artificial controller.

Requirements: **BRO01** stop cloud idle generation; **BRO02** resumable local
batches and existing artificial Weekly Rivalry fields; **BRO03** preserve planning
and bound attempts/cache/journals; **BRO04** reduce worker/HTTP memory and metadata
writes; **BRO05/R01/Q01** measure behaviour and validate the scoped rollout.
The [evidence report](evidence/backend-resource-optimisation-2026-10-28/report.json)
records final measurements, tests, deployment receipts and checkpoint checks.

## Run a local pass

From this repository in PowerShell:

```powershell
./scripts/artificial-races.ps1 -Inspect
./scripts/artificial-races.ps1
./scripts/artificial-races.ps1 -MaxJobs 4
```

The default processes at most **one attempt** from the existing unfinished
all-track batch and exits. It does not create/reset a batch. Existing creation
controls keep their inventory and real-record protection checks. With no
unfinished batch, it reports no work. Use `-BatchId <batch-id>` to target a batch.

Existing artificial Weekly Rivalry fields also run explicitly:

```powershell
./scripts/artificial-races.ps1 -ListRivalries
./scripts/artificial-races.ps1 -RivalryId <group-id> -MaxJobs 1
```

Each invocation permits 1–20 attempts. `-Cpus` defaults to 1 (allowed 0.5–8),
with a 768 MiB local Docker limit. Each attempt shares a 420-second generation
budget across controller fallbacks. A pass can take several minutes; complex
tracks can still time out or fail to finish. Repeating a command resumes its
journal. No watcher starts.

This computer's default PowerShell policy blocks script files. Invoke the
reviewed launcher with an override confined to its new process:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/artificial-races.ps1
```

The launcher discovers the owned Google Cloud API and worker's immutable image,
using the existing local Google Cloud sign-in and WSL Docker tooling. It pulls
that exact image if needed. The image supplies matching Godot/canonical game
assets, excluding unshipped game changes. Only the development operator key
enters the runner, through a temporary file removed in `finally`; no database
credentials are mounted. Registry pulls use temporary Docker credentials without
changing global configuration. `-Inspect` reads non-secret bindings without
retrieving the operator key or starting a race.

Ignored `.tools/artificial-races/` holds journals and a shared trajectory cache.
Keep a journal while its pass is unresolved. Batch journals retain one unresolved
receipt and remove acknowledged recordings. Prepared trajectories allow 128
files of at most 2 MB each; the native loader validates canonical identity.
Rivalry plans retain bounded scheduled attempts for their existing 13 artificial
members, with ordinary ticket/upload recovery. Operator endpoints cannot accept
scores or finishing times.

## Implementation

- The shipping competitive worker no longer constructs `DriverWork` or invokes
  either automatic generation helper. Explicit local tools and memberships remain.
- Development-only routes lease batch jobs for 600 seconds, lock the active-batch
  guard, fence stale/replaced leases, reconcile server results and bound retries.
  Completion requires a normal Run for the same artificial player/version/test
  board. Real-player receipts and real rivalry plans are rejected. The normal
  worker independently verifies recordings.
- Complete native trajectories save atomically while generation is running and
  during cleanup. Later interruptions/timeouts retain completed planning.
  Partial/nonfinite output cannot replace a cache. Native controller and
  simulation arithmetic remain unchanged.
- Worker factories omit HTTP/admin routes and staff/reporting clients. HTTP
  workloads import mounted routes; public APIs omit Studio-only clients. Pure
  settings validation no longer loads cloud transports into every process.
- Persistent Godot verifiers retire after 30 idle seconds and restart on demand,
  retaining the immutable manifest. Retirement uses the same nonblocking
  admission lock as invocation and cannot interrupt active work.
  `BMT_VERIFIER_IDLE_SECONDS=0` disables it; the valid range is 0–300.
- Stable idle heartbeats persist every 30 seconds, or one quarter of the stale
  budget if shorter. Active work retains its one-second cadence; lifecycle
  transitions remain immediate. Existing polling/notification bounds stay.
- Batch progress uses one pass over jobs. Typical claims avoid rebuilding the
  full report. Reconciliation commits even when no work is due.

## Measurements and verification

<!-- BRO-MEASURED-RESULTS -->
| Local idle footprint | Before | Optimised |
| --- | ---: | ---: |
| Worker shipping-process PSS | 547.80 MiB | 325.94 MiB |
| Worker CPU, nominal core | 7.34% | 5.46% |
| API PSS | 193.72 MiB | 92.73 MiB |
| Studio PSS | 193.27 MiB | 93.45 MiB |

Worker idle PSS falls **40.5%**. No idle native verifier remains. A synthetic drive completes with 4,107 inputs; shipping PSS returns to 326.23 MiB afterward. Cold/warm local generation is 19.762/2.137s with exact replay/manifest/ticks; warm reuse is 9.2× faster on this fixture.

**245 distinct tests pass; three intentional SQLite-only skips.** The full frozen-image run passed 244 checks and exposed one incorrect new scheduling expectation. The complete corrected 22-test protocol module then passed on the same immutable image. All 12 exclusions and six separately reproduced baseline failures remain recorded. Full repository Ruff policy passes for all task runtime/tool/test files.
<!-- /BRO-MEASURED-RESULTS -->

 Local PSS
apportions shared memory; it is not a live heap measurement. The worker fixture
uses the real supervisor/four roles, empty owned PostgreSQL, local objects, one
CPU and a 1536 MiB diagnostic ceiling. Shipping PSS excludes sampler/wrapper
overhead. HTTP profiles use one CPU, empty owned PostgreSQL and 100 serial
health/bootstrap reads per role after idle settlement. These do not establish
populated-cache peaks, sustained player capacity or phone performance.

Tests cover PostgreSQL concurrent leases, stale-batch/lease fencing, real-player
protection, lost upload/completion replies, expired tickets, bounded retries and
journals, native interruption/cache reuse with exact inputs, engine restart, and
an entire local batch upload followed by independent native worker verification.
Retained API/Studio/publication/Linux-supervisor suites cover other behaviour.

Earlier attempts remain in evidence: an unavailable legacy localhost PostgreSQL
fixture; FastAPI route introspection changes; a misnamed test module; missing
root game-fixture paths in the frozen context; retired two-lane supervisor
expectations; a mistaken one-attempt-per-track fixture assumption (profiles
schedule several attempts); Uvicorn's normal SIGTERM exit; and Ruff's explicit
loop-deadline binding. Original failing assertions are retained and baseline
failures reproduced separately. The legacy PostgreSQL Studio snapshot assertions
also run unchanged under an explicit admin wrapper. No scoring rule is weakened.

## Rollout and limits

The current immutable Studio package is the parent, overlaid only with this task's
delta. All 174 canonical files and the actual native manifest match the existing
API/worker parent and Studio parent. Concurrent Electric tuning, selected-car
compatibility and game presentation work are excluded. No schema migration,
track republication or task-initiated player write is needed.

API/Studio use zero-traffic canaries. Worker revision replacement uses existing
drain/cleanup fences. Seven existing jobs receive the same code for future
executions. Resources, process counts, scaling, schedules, secrets and IAM remain
configured. A read-only live aggregate probe checks usage/SQL headroom; owned
tags/probe/lock are removed.

Lower CPU use alone does not reduce an always-allocated worker-pool bill at
unchanged allocation. Google describes billing throughout an instance's lifetime
in its [container contract](https://docs.cloud.google.com/run/docs/container-contract#for-worker-pools).
Measure representative simultaneous verification/publication and populated caches
before lowering resource limits. Idle retirement trades memory for a native
restart on the next engine operation; tests establish correctness, not a
production cold-latency guarantee.

The preceding analysis's five rivalry-planning `InternalError` events remain a
separate unassigned SQL investigation. This task does not claim to fix them.

No owner game/local backend process restart, physical-device query/test, APK,
real sign-in/purchase, owner-save edit, main-index staging, commit or merge.
Owner workflow acceptance and sustained live load/cost calibration remain.

<!-- BRO-LIVE-RESULTS -->
## Approved live rollout

The owner's explicit approval follows the initial automatic promotion rejection.
The approved immutable image is `225feb3f4d79`; normal traffic uses API
`bmt-stg-e7a444ab-api-00122-vom` and private Studio
`bmt-stg-e7a444ab-studio-00021-dol`. Worker
`bmt-stg-e7a444ab-worker-00043-ttz` has one matching active instance; all seven original jobs use the
same image. Resources, scaling, schedules, IAM, secrets, schema and canonical
contracts pass the image-only comparison. Both owned read-only probe jobs,
canary tags and the local rollout lock are removed. Normal HTTP/private gates
and the local 8182 proxy pass; no owner staff HTTP/MFA session is used.

The early new-revision CPU samples after the initial two minutes range from
18.99–20.78% nominal allocation
(4 samples). The latest CPU sample is **20.78%** at
28 October 2026 17:55:00 EET. Memory is **319.93 / 768 MiB**, leaving
**448.07 MiB**, at 28 October 2026 17:54:00 EET.
The read-only health probe finds **8 / 40
SQL connections**, zero queued work and all **16 discovery partitions ready**.
The complete bounded new-revision log scan observes zero artificial-generation
starts. These are dated early observations, not a sustained-load or resized-bill
claim. CPU/memory peak alerts in Studio deliberately retain the earlier high
one-hour history even though current utilization has recovered.

The actual local launcher confirms the deployed pinned image and lists the
existing artificial rivalry fields through the authenticated read-only route;
no live race is started. One initial health-probe collection encountered normal
Cloud Logging ingestion delay; collecting the already successful execution with
a bounded retry resolved it without rerunning the probe. The initial checkpoint
also reconciles the new PowerShell file's declared CRLF attribute before its
exact forward/reverse byte checks.
<!-- /BRO-LIVE-RESULTS -->

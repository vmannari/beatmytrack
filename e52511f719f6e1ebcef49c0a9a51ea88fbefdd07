# Worker CPU and memory attribution — 28 October 2026

Development test-driver generation is the main CPU workload. Memory has a large
fixed baseline from four Python services, their supervisor and two persistent
Godot verifiers, with a third Godot process added during test-driver generation.
The analysis makes no live configuration or shipping-code change.

Requirements: **WRA01** identify the actual deployed image and live metrics;
**WRA02** trace CPU workload; **WRA03** measure process-memory components;
**WRA04/R01/Q01** qualify findings, preserve concurrent work and retain reproducible
evidence. [Evidence report](evidence/worker-resource-analysis-2026-10-28/report.json).

## Live findings

The six-hour window is **27 October 23:18:47 through 28 October 05:18:47 UTC**.
The worker is `bmt-stg-e7a444ab-worker-00042-7zn`, one instance with **1 vCPU /
768 MiB**, running immutable image
`backend@sha256:a0cc1c441187714e77d97bca694e64cc26b8f8e9b132d83829d15804eebb7f86`.
That image/revision is unchanged at the final read-only check. Its development
test drivers, development authentication and telemetry are enabled.

| Observation | Result |
| --- | ---: |
| Worker CPU utilization, sampled means | 111.2–147.5%; median 132.0% of nominal allocation |
| API CPU utilization, sampled means | Median 1.05% |
| Worker memory, median absolute usage | 754.56 MiB of 768 MiB |
| Worker memory, sampled utilization range | 98.13–98.66% |
| Test-driver generation starts / stops | 44 / 44 |
| Stopped generation duration | 480.034–481.377 seconds |
| Window occupied by generation | 21,526.1 / 21,600 seconds = 99.66% |
| Completed race-verification log events | 0 |

The log scan is complete within its bound: 482 entries. Raw log text and
player/run/group/generation identifiers were never exported; identifiers are used
only in memory to merge clipped generation intervals. Routine discovery health
accounts for 343 text log entries. Five `rivalry_planning_failed` events report
`InternalError`, at `ensure_vehicle` or `candidates`; these deserve a separate
SQL diagnosis, but do not explain the nearly continuous controller workload.

Every stopped generation runs approximately to the source's **480-second**
planning ceiling. This strongly supports repeated timeouts. The terminal timeout
status is caught and stored in plan state, rather than logged explicitly; no
private live plan was read. This is a qualified timeout diagnosis, not a claim
that each private terminal status was independently inspected.

## What consumes memory

An owned local PostgreSQL fixture runs the **same immutable image**, shipping
supervisor and four daemon roles, with real persistent Godot processes and no
race population. The initial profile then adds one synthetic Compact test drive
and measures recovery after that generator exits.

The values below are **local proportional set size (PSS)**, not live remote heap
measurements. PSS apportions shared pages, avoiding the duplication that would
come from simply summing process RSS. See the [Linux kernel definition](https://docs.kernel.org/filesystems/proc.html).

| Component | Idle PSS |
| --- | ---: |
| Competitive worker Python application | 98.74 MiB |
| Publication worker Python application | 94.55 MiB |
| Discovery Python service | 69.29 MiB |
| Telemetry Python service | 83.40 MiB |
| Supervisor | 13.30 MiB |
| Two persistent Godot verifiers, combined | 188.52 MiB |
| **Shipping processes, idle total** | **547.80 MiB** |

During generation the third Godot process uses **99.14 MiB PSS**; changes in
sharing and other processes make the net shipping-process increase **95.22 MiB**,
to **643.02 MiB**. After generation, shipping PSS returns to **548.64 MiB**.
Diagnostic sampler/wrapper PSS is explicitly excluded from those totals.

The local fixture uses an empty database, local object storage and a 1536 MiB
diagnostic memory ceiling so instrumentation does not create artificial memory
pressure. Cgroup accounting and PSS have different boundaries. These values
therefore explain the architecture and incremental process footprint, but are
not an exact reconciliation of the live 754.56 MiB. Populated caches, cloud
storage clients and temporary/in-memory filesystem data remain unmeasured per
process in production. The observed six-hour memory band is flat; it provides
no evidence of ongoing unbounded growth within that window and does not rule out
every possible leak.

The source explains the fixed footprint: both competitive and publication roles
construct full application objects, and both warm and retain their own Godot
verifier. Discovery and telemetry are additional Python processes. Merely
pausing artificial generation will leave that baseline resident.

## What consumes CPU

In the one-CPU local run, the test-driver Godot process consumes **90.85% of one
core** while generation is active. Total shipping-process CPU goes from **7.34%**
idle to **97.94%** during generation, and **6.17%** after the generator exits.
The synthetic service stops cleanly and records no worker-iteration, child-exit,
discovery or syntax failures. This supports attribution to the controller,
instead of inferring process shares from container-wide Monitoring alone.

The Compact planner evaluates five trajectory strategies, pilots each at two
skill levels for five laps, and may run additional fallback pilots. The final
five-lap driver uses the chosen trajectory. This can entail dozens of simulated
qualification laps for a single generated recording.

A separate network-isolated, one-CPU / 768 MiB probe compares cold and cached
generation on the image's short synthetic acceptance oval:

| Measurement | Cold | Cached |
| --- | ---: | ---: |
| Total wall time | 19.324 s | 2.067 s |
| Trajectory planning | 16.528 s | 0.001 s |
| Native child CPU time | 18.538 s | 1.951 s |
| Trajectory cache hit | No | Yes |
| Replay input count | 4,107 | 4,107 |

The replay, manifest and timing ticks are **exactly equal**. The measured speedup
is **9.35×** on that fixture; it is not a forecast for the live tracks. The cold
planner accounts for about **85.5%** of that run's wall time.

There is a concrete cache-persistence gap. The native generator writes its
prepared trajectory to a temporary file before driving the final race. Python
copies it into the durable bounded cache only after the process exits normally.
`GenerationTimedOut` bypasses that copy and temporary-directory cleanup removes
the file, even if preparation had finished. A later attempt can therefore repeat
the cold planning work. The live logs do not expose which phase had been reached
at timeout; the exact image source establishes this failure-path behavior.

## Recommended order

1. Pause, schedule or give a CPU/time budget to development test-driver generation.
   Keep normal race/publication verification available. Existing test-driver
   records need not be deleted.
2. Preserve validated prepared trajectories across bounded generation failures,
   and separate reusable planning from the per-driver recording attempt. Add
   phase/duration/outcome counters so timeout work is visible directly.
3. Reduce the fixed worker footprint: evaluate lazy startup of an idle publication
   verifier and a smaller worker application factory. Preserve publication
   readiness, priority and authentication/transaction fences when doing so.
4. Re-measure the warmed production footprint and then choose memory/instance
   sizing. Investigate the five background SQL `InternalError` events separately.

Worker pools remain allocated and billed while running, including idle periods.
Reducing CPU activity at an unchanged instance count and resource setting does
not automatically reduce the fixed worker bill. Savings require a subsequent
sizing or runtime-hours change. [Cloud Run worker-pool contract](https://docs.cloud.google.com/run/docs/container-contract#for-worker-pools).
Filesystem contents also count toward the memory budget; the deployed image's
size itself does not. [Worker-pool memory documentation](https://docs.cloud.google.com/run/docs/configuring/workerpools/memory-limits).

## Actual validation and boundaries

Eleven evidence checks pass, including exact-image continuity, complete bounded
logs, four daemon roles/two persistent verifiers, local CPU recovery, an actual
warm cache hit, exact replay/manifest/tick preservation, healthy service shutdown
and removal of the owned database/container/network. This is analysis and native
profiling, not a shipping regression-test claim. There is no gameplay/UI change.

Commands, scope and full measured values are retained in `report.json`; the
probe sources are under `build/worker-resource-analysis-2026-10-28`. No private
player records/plans, raw log text or derived private record hashes were exported.
No cloud deployment, resource resize, live data write, owner-process restart,
device attachment query/test, main-index staging/commit/merge or production
profiler installation occurred. Current concurrent game/backend work is preserved.

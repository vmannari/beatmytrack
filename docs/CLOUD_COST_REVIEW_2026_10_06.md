# Cloud cost review — 2026-10-06

Requirements B19/B20/B23/WR03–WR08/Q01. The owner requested a review of savings that preserve usability and responsiveness. This is a read-only review: no resource sizing/scaling, data, image, secret, driver scheduler or application behavior was changed.

The inspected deployment is the newer compiler-22 retained backend, image sha256:8ac5ad340faed6ea17b3ccb15e902d6a575a54b93c363e0770e566e26078c5ba. Source/status inspection caught the concurrent latest-backend rollout and used its actual settings rather than assuming the earlier compiler-20 snapshot. API is warm minimum one/maximum two, 1 CPU/1024 MiB. One worker is 1 CPU/768 MiB. SQL is PostgreSQL 17, zonal db-custom-1-3840, 10 GiB SSD. Its seven daily backups, database protection and GCS seven-day recovery remain. Test-driver mode is enabled under the separate retained-development authorization; no private key was read or printed.

## Measured headroom

Read-only Cloud Monitoring queries covered the preceding 24 hours, including deployments and development verification activity:

| Component | Allocation | Observed sampled use |
|---|---|---|
| API | 1 CPU, 1024 MiB | CPU mean 3.45%, maximum sample mean 21.52%; memory maximum sample about 280 MiB |
| Worker | 1 CPU, 768 MiB | CPU mean 14.86%, reaches approximately 100%; memory maximum sample about 355 MiB |
| Database | 1 CPU, 3.75 GiB | CPU mean 9.51%, maximum sample 18.15%; memory maximum about 1.00 GiB |
| Database storage | 10 GiB allocated | Maximum reported used data about 179 MiB |

These are monitoring samples across seven API/worker revisions, not worst-case supported input benchmarks. Brief peaks can be missed. The deployment is young and traffic is small; future demand is not represented. The backend memory data includes native-verifier subprocess use as reported for the container. The connection metric has multiple labeled series; its maximum per-series sample is not asserted as the total connection count.

## Savings candidates

Rates below use the official EUR regional SKU catalog reviewed October 5; amounts exclude promotional credits/free-tier adjustments and variable usage. [Exact calculation](evidence/cloud-cost-review-2026-10-06/saving-calculations.json).

| Candidate | Estimated saving | Responsiveness assessment |
|---|---:|---|
| API memory 1024 → 512 MiB, keep 1 CPU and warm floor 1 | €0.095/day, €2.85 per 30 days | Best simple candidate. The observed 280 MiB peak leaves headroom, but maximum uploads, concurrent reads/joins and startup must pass at 512 MiB first. |
| Worker memory 768 → 512 MiB, keep 1 CPU | €0.023/day, €0.70 per 30 days | Small saving. Observed 355 MiB leaves less margin; largest supported tracks/replays/rewinds and a sustained verifier batch need testing. Lower priority. |
| SQL shared-core db-g1-small, 1.7 GiB | €0.687/day, €20.62 per 30 days | Largest sizing candidate. Current CPU/RAM suggest an isolated benchmark is worthwhile. Shared CPU has variability and this tier has no Cloud SQL SLA; no-impact operation is not established. |
| Curated removal of obsolete test images | Small, not quantified | Does not slow requests if active/rollback/historical verifier builds are protected. Fifteen digest records do not mean fifteen independent full copies; image-index children and shared layers must be respected. |

SQL CPU/RAM currently estimates €1.4267/day. The normal PostgreSQL zonal small-instance SKU 79B6-5148-74CC is €0.030799999/hour, €0.7392/day, before unchanged storage/backups. Extended-support and trial-only SKUs were excluded. If all three sizing candidates passed their required acceptance, combined baseline savings would be about €0.806/day, approximately €24.18 per 30 days. That is a conditional estimate, not a verified configuration recommendation.

Google recommends monitoring memory under load before lowering it; an exceeded limit terminates the container. [Cloud Run memory guidance](https://docs.cloud.google.com/run/docs/configuring/services/memory-limits). Worker pools require at least one CPU and 512 MiB. [Worker CPU limits](https://docs.cloud.google.com/run/docs/configuring/workerpools/cpu), [worker memory limits](https://docs.cloud.google.com/run/docs/configuring/workerpools/memory-limits). Shared SQL memory/tier details and SLA limits: [machine series](https://docs.cloud.google.com/sql/docs/postgres/machine-series-overview), [SQL pricing](https://cloud.google.com/sql/pricing).

## Configuration to keep

Keep one warm API instance: scale-to-zero already caused the observed roughly 16-second rivalry wait. Keep worker CPU at one: it actually saturates during verification. Cloud Run worker pools do not support a fractional CPU setting. Keep the current minimum storage, daily backups, deletion protection and soft-delete recovery; the stored data is tiny and losing protection would outweigh the savings. API, SQL, bucket and registry are already colocated in europe-west1, a Tier 1 Cloud Run region, so a region move is not a meaningful low-risk optimization.

The current worker is a polling process. Each idle pass performs a heartbeat and queue reads, then waits one second. Avoiding redundant idle heartbeat/build work could reduce database load while preserving one-second claims and active lease/progress semantics, but it does not itself reduce the fixed allocated CPU/RAM bill. Any heartbeat throttle must retain stale detection and draining/cancellation fences.

An on-demand verifier could remove some of the roughly €0.93/day continuous-worker cost when traffic is low. This requires a deliberately designed warm execution/delivery path; simply scaling the current worker to zero or starting a cold job per result would add verification latency. It is a future architecture benchmark, not a zero-impact configuration switch. Combining API/worker on one CPU could also contend with menu requests. Existing compression, bounded pools, paginated reads, conditional responses and offscreen/polling gates already reduce variable traffic costs.

No annual commitment is recommended for an approximately 80-day credit test window. No purchases or upgrades were made. Removing inactive Cloud Run job definitions would not eliminate a continuous worker bill; jobs charge for execution. Nearline/archive storage would save negligible money at this data size and introduce minimum-duration/retrieval considerations.

## Concrete next slice

First benchmark the API at 512 MiB in isolation using the current image: cold/native startup, largest supported upload/decode, simultaneous rivalry/catalog reads, and retention/session behavior. Keep CPU one, minimum one and maximum two; require unchanged p95 and successful memory bounds before a same-image rollout. Keep the worker at 768 MiB until its maximum replay/document batch is measured.

For a material saving, benchmark a private cloned db-g1-small alongside the current database rather than resizing the live database first. Compare query p95, connection behavior and concurrent leaderboard/rivalry/admission operations with a representative fixture. Shared-core reliability/CPU variance remains an explicit tradeoff even if a short benchmark passes. Retain backups and an immediate migration/rollback plan. This review did not create a clone or mutate resources.

## Actual commands, files and acceptance

The ignored .tools/gcp-staging/review-costs.py used explicit project/region CLI describes, registry listing and existing Cloud Monitoring APIs. It saved curated inventory and CPU/memory/disk/connection samples without credential payloads or player records. Savings were calculated locally from the existing EUR SKU receipts. No installed package or new billing export was created.

Changed review files: this report, docs/evidence/cloud-cost-review-2026-10-06, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md. [Inventory, metrics and checkpoint](evidence/cloud-cost-review-2026-10-06/README.md). Snapshot comparisons preserve concurrent backend/editor work.

The last provider cost report remains delayed: €1.09 gross through approximately 10:00 Helsinki today, not complete current-day spend. It cannot establish present savings or remaining credits. Memory stress, shared-tier latency/load/SLA acceptance, an event-driven worker and storage cleanup dry run remain unperformed. No app/source-runtime/physics/schema change, UI screenshot, Android export, phone attachment check or device test was performed.

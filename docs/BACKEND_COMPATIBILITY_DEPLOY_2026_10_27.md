# Backend compatibility rollout — 27 October 2026

The configured game endpoint is the existing cloud API in `beat-my-track` /
`europe-west1`. The previous full rollout updated executable services but left
published track headers at physics **0.66**, with five vehicle identities. The
API's global manifest alone therefore passed while real race tickets failed.
The game subsequently advanced to validated physics **0.75 / electric-18**.

Requirements: **BCD01** identify the actual endpoint and build; **BCD02** deploy
every existing cloud executable together; **BCD03** publish compatible immutable
track revisions; **BCD04** preserve history and configuration; **BCD05** verify
actual public track contracts, game ticket validation and weekly eligibility.
**R01/Q01** retain independent tests and report device/owner acceptance limits.

## Release and preservation

Immutable image:
`europe-west1-docker.pkg.dev/beat-my-track/bmt-stg-e7a444ab-images/backend@sha256:a0cc1c441187714e77d97bca694e64cc26b8f8e9b132d83829d15804eebb7f86`.
Frozen source hash:
`6d1727252475a67a487a1135fedb826097a8f997e807cf0d72f2cd5f99c5b132`.

All 338 runtime package files are checked against the frozen source. The release
uses the previously deployed stable package, completed race/statistics changes
and the current validated canonical bundle. Unfinished concurrent Studio usage
changes are excluded. It retains the existing dependencies and schema
`0070_reward_cache_revisions`, Godot 4.7.2, compiler27, rules23, 120Hz and five
laps. The electric identity is
`6b260c269efbdf3fe6de32f618125255998a0cd706cfe02fd47d13c3b028e424`;
the other six vehicle identities match the game exactly.

`catalog_builds.py` validates each original public source document with the
current verifier, checks its content hash, compiler, compiled content hash and
exact route length, then inserts a new numbered revision. Track locks and a
second eligibility/head check protect the single commit. Old versions, boards,
PBs, scores, ghosts and competition contracts are not relabelled. New revisions
begin with their own rating and finisher counts. Existing incompatible challenge
contracts remain historical; new races and competitions use the current build.

All ten existing targets are in scope: API, private Studio, worker, migrator,
smoke, catalogue, pace2, reporting-check, reporting-setup and Studio simulator.
Updates preserve identities, environment/secret bindings, resource/process
limits and the single worker. They do not execute population/provisioning jobs.
Studio retains IAM protection. No PC backend update is needed for the configured
cloud endpoint.

The rollout uses database-free maintenance, request draining, a stopped worker,
a provider-managed Cloud SQL backup and aggregate table counts. It exports no
private player records or record fingerprints. Counts do not prove bytewise
equality of private record contents. The earlier rejected fingerprint export
from the 26 October rollout is not retried.

## Verification and commands

Task orchestration is
`build/backend-compatibility-deploy-2026-10-27/deploy.py`. Commands use
`.tools/backend-secure-venv/Scripts/python.exe -X utf8` followed by that file and
the named stage. `inspect`, `prepare`, `build`, `test`, `push`,
`prepare-maintenance` and the read-only `preview` precede maintenance. Following
stages coordinate backup, catalogue publication, all targets, canaries, native
storage smoke, weekly readiness, traffic promotion and final acceptance. Exact
completed stages and safe receipts are recorded in the final evidence report.

- Exact Linux image: **71 passed**, including SQLite and disposable PostgreSQL17
  catalogue and backend-work tests, results-route contracts and trajectory
  integrity. There are 101 existing SQLAlchemy reflection warnings.
- Independent native parity: all seven complete vehicle contracts match Windows
  and Linux. The latest electric five-lap recording replays at **34,805 ticks**;
  the compact golden recording remains **12,757 ticks** and ten-second rewind
  acceptance passes during image build.
- Before rollout, the actual game ticket validator rejects all **21** sampled
  public track/car combinations. This negative proof is retained.
- New cloud smoke checks every visible published head against the active build.
  A healthy API/global manifest can no longer hide stale published contracts.

Initial root tests encountered a missing module from concurrent unfinished
Studio work; isolated stable-source checks passed **8** tests before the exact
image run. Initial Docker context construction encountered a protected pytest
directory; the final image uses a source-only context. The first read-only live
catalogue preview exceeded the idle-in-transaction timeout while validating
native tracks. Validation now runs without a SQL transaction; the final apply
still uses ordinary transactional locks and runtime limits are unchanged.
Initial failures are retained, not reclassified as passing runs.
Cloud Run also rejected an overlong temporary Studio tag. The replacement
uses a shorter tag; no traffic or IAM rule is relaxed to address that failure.

The rollout is complete: all ten targets share the immutable image. API
`bmt-stg-e7a444ab-api-00119-nux` and private Studio `bmt-stg-e7a444ab-studio-00012-wiv` receive normal traffic. One matching
worker, empty queues and all **16** discovery partitions are ready. The
current-week Rivalry calendar has **five tracks for each of seven cars**.
Pre-promotion cloud smoke passes native replay, all **30** current public heads,
the comparison route and real GCS publication/read/list/cleanup with no player
writes. All **210** public track/car combinations then pass the actual current
game ticket validator. Live database authority and full 30-track discovery
traversal pass. Temporary deployment tags and the owned update lock are removed.

Managed Cloud SQL backup **1793080709271** precedes publication. The initial
aggregate snapshot covers **166 tables / 311,714 rows**;
protected account/race/PB/reward/challenge/rivalry history counts remain unchanged,
and exactly **30** TrackVersion rows are added. The main maintenance interval
was **12.25 minutes**. No private content or private-record hashes are
exported. Source hashes, exact commands, safe receipts and the isolated
round-trip Git checkpoint are in
[the evidence report](evidence/backend-compatibility-deploy-2026-10-27/report.json).

Completed commands after `quiesce`: `data-phase` runs stop-worker, aggregate
snapshot, managed backup, migrator-image update, catalogue apply and protected
counts. `service-phase` runs canaries, remaining jobs/worker, pre-promotion
smoke, promotion, public contracts, native game acceptance, authority, discovery
and final configuration/tag/receipt checks.
No physical-device attachment check/test, APK, purchase, owner-game restart,
main-index staging, commit or merge is performed. Reopen/reload Race to discover
new track heads; already cached historical versions keep their original build.

# Backend cost reduction plan

The owner's target is a 95% reduction from the previous cost scenarios. At one million daily players, 5% of the earlier €37,759–58,623/month range is €1,888–2,931/month. **Use €1,800/month as the engineering ceiling for that workload, and require a successful capacity and recovery test before claiming it is achievable.** This compares with an earlier scenario, not an observed production bill. The present small staging service has a fixed resource floor of approximately €83/month.

The route to the target is to keep ordinary race computation cheap, avoid charging multiple object operations for every attempt, archive compact facts instead of accumulating detailed SQL indefinitely, and use hosting and delivery with a lower unit cost. Preserve ten legitimate races per daily player in the model. Unlimited racing, verified PBs, exact challenge results, earned rewards, purchases and retry correctness remain requirements.

Requirements CR95-01 correct verification accounting, CR95-02 delivery, CR95-03 bounded hot data and receipts, CR95-04 packed object operations, CR95-05 deployment economics, CR95-06 operational and load acceptance, CR95-07 preservation and evidence.

## Correction to the original verification model

The first review used the superseded native proof/full-replay timings. That was a material review error. **Current production acceptance is already a Python trajectory pass with no full-physics fallback.** Native code prepares immutable geometry on a cold cache; it does not simulate each race. Existing `bmt-trajectory-v1` recordings also omit the control-frame arrays. The proposed optimization is to preserve this path, not invent it or weaken verification.

A fresh current-source benchmark on 24 October used the pinned engine for static preparation, then prohibited all engine calls during 500 five-lap checks:

| Scope | Median | p95 | Maximum |
| --- | ---: | ---: | ---: |
| Trajectory checker | 1.713 ms | 2.943 ms | 3.789 ms |
| Adapter with prepared geometry | 1.766 ms | 3.003 ms | 3.677 ms |

The fixture contains 2,130 path samples; every iteration retains the exact five lap times. Static preparation took 1.318 seconds separately. The first restricted-environment run failed during engine preparation; the same command succeeded with normal native access. [Fresh samples](evidence/backend-cost-reduction-2026-10-24/trajectory-current.json), [current acceptance](../backend/bmt_backend/verifier.py), [original trajectory contract](TRAJECTORY_VERIFICATION.md).

At the earlier peak of 579 results/second, the median computation corresponds arithmetically to about 1.7 single-core equivalents at 60% utilization. This is not complete job capacity: decoding, authentication, object reads, ghost handling, SQL finalization and background work remain. Longer trajectories also cost more. However, the former 224 one-CPU verification-instance inference is not a valid CPU requirement for this checker. I/O concurrency must be separated from allocated CPU.

## Candidate monthly budget

The following is a test configuration and spending envelope for one million daily players, ten million accepted races/day, ten million registered accounts, a fivefold peak, and one year of archived receipts. It assumes the data and request reductions below have been implemented. It is not a capacity-tested quote.

| Component | Candidate allocation or allowance | Monthly EUR budget |
| --- | --- | ---: |
| API and worker hosts | Two CCX43 instances, with separate process/resource budgets | 551.98 |
| PostgreSQL | Two CCX43 instances for primary and physical standby | 551.98 |
| Packed content, recording and receipt objects | Storage and operations allowance | 200 |
| Database backups, WAL and recovery storage | Separate recovery allowance | 150 |
| Edge, load balancing, IPv4 and transfer | Combined allowance | 100 |
| Monitoring and logs | Bounded retention and success-log sampling | 50 |
| Extra storage and miscellaneous | Allowance | 50 |
| Contingency | Unallocated | 100 |
| **Total** | **Subject to all acceptance gates** | **1,753.96** |

The official June 2026 EU price table lists CCX43 at €275.99/month excluding VAT and IPv4. Four such instances cost €1,103.96/month. Confirm current profile specifications, local disk capacity, region availability and the final order price before provisioning. The architecture needs independently placed hosts, not four containers on one machine. [Official regional prices](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/).

The total is 95.35–97.01% below the previous scenario. It is a budget to design and test against, rather than a measured saving. Operating-system patching, PostgreSQL upgrades, failover, security, monitoring and on-call work move to the operator. Engineering labour, tax, setup charges and one-time migration cost are outside it. Buying these servers does not establish their capacity.

For application hosts, test a profile around 16 vCPUs/64 GiB per host, with bounded API, trajectory/queue, geometry-preparation and background processes. For the database, test a similar primary/standby profile with local SSD and a live primary dataset below 250 GiB. The exact quoted host profile must be checked before purchase. These are test envelopes. They must handle peak load and a host failure within the service budgets; otherwise the allocation, design or cost target must change.

The standby can also serve the current isolated Studio reader in normal operation. During failover, gameplay takes priority and broad reporting may be unavailable until another standby is ready. Replication is not a backup; retain independent base backups, WAL and tested SQL/object recovery.

At 10,000 daily players, a flat 95% reduction implies approximately €37–56/month. Fixed redundancy, backups and operational overhead make that a substantially harder percentage target than at large scale. A small shared-server beta and a resilient public service have different floors. Do not extrapolate the million-player budget down without a separate small-service allocation.

## Remove expensive content delivery

The previous scenario included about €10,538/month for 5 MiB/day/player of Europe-bound Cloud Run delivery at a million daily players. That traffic volume was an assumption, not a measured current requirement. First measure compressed bytes and client cache misses by content type.

Serve immutable published track/content bytes through a suitable low-egress object/CDN path. Cloudflare R2 currently lists no direct internet egress charge, with paid storage and operations. Alternatively, the official Hetzner traffic table includes substantial EU transfer allowances and low overage prices. **Changing the storage provider while still proxying all downloads through Cloud Run would retain Cloud Run's outbound bill.** The client must download bulk public bytes through the new delivery path. [R2 pricing](https://developers.cloudflare.com/r2/pricing/), [included traffic](https://docs.hetzner.com/robot/general/traffic/).

Use long-lived immutable content hashes, compressed responses, conditional metadata and bounded client disk caches. Keep authenticated ownership/visibility checks for private records and challenges. Public content may use a public cache; a private recording cannot be made public to improve its cache hit rate. Revocation and privacy behaviour require acceptance tests.

R2 is a candidate, not an already accepted adapter. The existing S3 boundary provides a useful starting point, but provider tests must prove conditional create-once writes, integrity, range reads, timeouts, listing, deletion and crash recovery. R2 documents atomic conditional writes, which supports the required create-once design. [S3 boundary](../backend/bmt_backend/s3_storage.py), [R2 consistency](https://developers.cloudflare.com/r2/reference/consistency/).

## Stop storing two independent objects for every race

Ten million races/day is 300 million races/month. Two independent object writes per race are 600 million writes: **$2,700/month at R2's $4.50/million Class A rate**, before reads or storage. Egress-free storage alone therefore cannot meet the target.

Change the storage unit from one object per attempt to bounded immutable packs. Keep accepted intake durable before acknowledgement, with bounded recent proof bytes in a WAL-protected queue/table or another replicated durable journal. Process those proofs without a compulsory remote-object round trip. Do not use unreplicated memory or a container's temporary filesystem as the sole acknowledged copy.

Pack transient recordings and protected recordings in separate streams. A starting target is at most 128 records per pack, with an independent six-MiB encoded-byte limit; large records close a pack earlier. Never bypass the existing eight-MiB decoded object limit. At 128 records, one transient write per race becomes approximately 2.34 million pack writes/month. Receipts are much smaller and can use larger record counts within the same byte bound.

Each record needs an immutable ID, checksum, offset and length. Publish pack bytes before atomically publishing their authoritative pointers. Restart after a partial write must recover or safely collect the unpublished pack. Recently written records remain accessible while a pack fills; exact post-race challenges must retain their actual slower-than-PB recordings too.

The current whole-object gzip/JSON boundary cannot provide efficient random record ranges. Introduce a versioned pack with independently compressed record frames and an authenticated index, including record hashes for verification of partial reads. This is a storage-contract change. Preserve trajectory numbers losslessly; rounding coordinates to save bytes can change acceptance near narrow gates.

Do not keep an entire transient pack forever because one PB points into it. Promote protected records into protected packs and compact dead records with generation-fenced pointer changes. Ghosts remain optional presentation; a pack flush must not hold scoring locks or delay the ordinary result screen.

Private mixed-player packs need a record-authorized resolver. A URL granting the whole pack would expose other records. Serve only the permitted byte range through the low-cost authenticated path unless the provider authorization mechanism proves that the permitted range cannot be altered. This security and correctness work is part of the storage redesign.

For budgeting, four thousand GB of Standard R2 storage, ten million Class A operations and two hundred million Class B operations cost $177/month before free allowances. A deliberately assumed €1.10 per dollar stress factor gives €194.70, inside the €200 envelope; that factor is not an exchange-rate quote. Exceeding any of these data/operation targets invalidates that budget. These rates are independent of how much an intermediate metered service charges.

## Bound hot SQL and preserve exact rewards

The largest database reduction is to stop retaining every attempt's detailed reward rows, duplicated financial descriptions and compacted server event as separate permanent hot SQL records.

Keep ordinary detailed results for a short review period, initially seven days for testing, and terminal nonprotected proof/recording evidence for at most twenty-four hours. Keep pending work until authoritative terminal handling. Preserve all PB sources, exact challenge references, published creator validation and other protected records. These are proposed new retention policies; no existing records are deleted by this plan.

Store older accepted facts in compact immutable archives with shared manifests and numeric keys. A 128-byte receipt target would produce about 435 GiB/year at ten million results/day, before envelopes and replicas. That is an encoding target, not an already implemented schema. Prove that it contains the facts needed for exact rewards, result recovery, support and analytical reconciliation. Core purchase/fulfillment records retain their separate correctness requirements. Archives still grow each year; their compact storage cost replaces the much larger indexed SQL growth rather than creating a permanent fixed-size history.

**Never implement this by deleting the reward replay fence after a timeout.** A lost response or an old saved upload must not grant a second reward. A viable replacement needs server-issued ticket identities, a durable closed/settled frontier and exact out-of-order status, backed by immutable receipt archives. Late retries must return their original outcome or an explicitly versioned archived response without replaying effects. A counter alone and a probabilistic Bloom filter cannot provide this guarantee.

Update reward, achievement and telemetry deduplication together. Existing `CoinReward` rows are currently part of that correctness boundary. Account erasure, interruption, ticket expiry, simultaneous replies and archive failure must be tested before any compacted receipt replaces them. Do not change currency, earned rewards or competitive eligibility to meet a storage target.

The live SQL target is at most 250 GiB under the stated account/PB population. It includes all relevant tables and indexes, not just the award table. Retention must drain at least as quickly as data arrives, and recovery/free-space headroom must fit the selected disks. A larger registered population, many more PB boards per person or sustained new content can invalidate the target even at the same DAU.

## Spend database work on current gameplay

Keep the current trajectory checker and cached geometry. Separate bounded I/O concurrency from checker CPU. Avoid one native engine or one idle CPU per concurrent race. Native preparation, explicit diagnostics and artificial driver generation need independent small budgets; artificial generation yields to actual players.

Aim initially for forty API requests per daily player rather than the previous unmeasured assumption of 150. At a million players this is 463 requests/second average and 2,315/second at a fivefold peak. Starts, uploads and coalesced completions can account for roughly thirty requests for ten races; startup and menu actions consume the rest. This is a target that must be checked against actual client flows, not a restriction on legitimate racing.

Combine completion data already available from one transaction: verified result, coin receipt, PB information and relevant competition changes. Retain exact finished-ticket identity and persistent outbox recovery. Cache shared immutable views and avoid refetching unchanged menus. Keep challenge try reservations and rewind entitlements authoritative; do not pre-reserve limited competition tries simply to reduce calls.

Set an explicit diagnostic event/byte budget. Aggregate repeated quality observations locally and sample detailed diagnostics where full population detail is unnecessary. Retain exact server-side accepted-race, reward, purchase and competition totals. Use compact server aggregates instead of three permanent raw copies of the same accepted event. The earlier hundred-client-events/day input was an assumption, so measure the actual volume before claiming a particular reduction.

Bound success logs, old snapshots, cache generations, synthetic drivers and scheduled reports. Serve broad analytics on the standby or prepared summaries. Protect gameplay connections and CPU across simultaneous request classes; separate process limits alone do not reserve global pool capacity.

## Implementation order and acceptance gates

| Order | Deliverable | Required evidence |
| --- | --- | --- |
| 1 | Current-flow accounting and corrected capacity baseline | Actual proof/ghost bytes, SQL/index/WAL deltas, request counts, object operations and complete result latency. The fresh pure-check benchmark is only the computation term. |
| 2 | Low-egress delivery and immutable client caching | Same authorized content and visibility; measured delivered bytes, cache misses and intermediate-service charges. |
| 3 | Durable compact intake and packed recordings | Restart/lost-write recovery, exact checksums, protected-reference compaction, record-level authorization and bounded operations. |
| 4 | Versioned compact receipts and automatic retention | Exact once-only awards/achievements/analytics under duplicates, late replies, erasure and interrupted archive publication. Source counts and historical outcomes reconcile exactly. |
| 5 | Combined completion responses and bounded telemetry | Same game flows and competition rules, with measured request/event reductions and no client retry storms. |
| 6 | Candidate self-managed deployment in isolation | Peak mixed load, hot-board writes, connection limits, background freshness and one-host-loss capacity within the €1,800 envelope. |
| 7 | Recovery and rollout | PITR/restore, primary failure with fencing, rollback/roll-forward compatibility and matching client/API/worker protocol. Actual provider change requires a separate authorised deployment. |

Require the same ten million accepted races/day in the model. Do not obtain the saving by reducing legitimate races, skipping their trajectory checks, trusting submitted currency, dropping durable acknowledgements, eliminating independent backups or discarding purchased entitlements.

The full-load gate is approximately 579 accepted results/second plus 2,315 dynamic requests/second under the proposed client request target, with realistic retained accounts/PBs and the actual ratio of shared cache hits. Completion traffic must be counted once within the dynamic total. Measure scheduled p95/p99, offered versus completed load, job age, CPU, SQL locks, WAL/IOPS, pool waits, retained bytes and actual provider meters. Repeat under a host failure and during retention/rollover. If it fails, change the design or budget; a cheap server list is not proof.

No rewrite of the whole backend is required merely to begin. PostgreSQL, the current Python trajectory checker, immutable manifests and durable client outboxes remain useful. The critical changes are the unit of stored data, the lifetime of hot records, the amount of repeated work and the deployment billing model.

## Review artifacts and limits

The [budget model](evidence/backend-cost-reduction-2026-10-24/budget.json) and [calculation script](evidence/backend-cost-reduction-2026-10-24/budget_model.py) record assumptions and targets. The uncorrected review and model are preserved in the evidence directory for accountability. The [performance review](BACKEND_PERFORMANCE_REVIEW_2026_10_24.md) now withdraws its obsolete verification fleet and cost forecast.

Actual new measurement command:

```text
python -X utf8 backend/tools/benchmark_trajectory.py --godot "C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe" --project game --fixture backend/tests/fixtures/verified_oval.json --proof .tools/trajectory-approved-20261009/proof.json --output docs/evidence/backend-cost-reduction-2026-10-24/trajectory-current.json --iterations 500
python -X utf8 docs/evidence/backend-cost-reduction-2026-10-24/budget_model.py
```

The native path was passed as one quoted PowerShell argument in the actual execution. Five hundred adapter and five hundred checker calls retained the fixture's exact time/laps and made no engine calls during acceptance. This is a local computation measurement. No target-population load test, provider contract acceptance, new cloud purchase, configuration change, migration, deletion, runtime implementation, device test or phone/tablet attachment check was performed.

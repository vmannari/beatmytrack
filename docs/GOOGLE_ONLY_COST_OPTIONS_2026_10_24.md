# Google Cloud cost options

**Keep Google Cloud while implementing the data and request reductions. A Google-only budget near €2,000–2,500/month at one million daily players is a useful test target if average downloads are around 0.2 MiB per player/day. €1,800 is a stretch target; it is not established capacity.** At the earlier unmeasured five-MiB assumption, the comparable model remains around €9,000–10,000/month because delivery is still expensive.

This follows the corrected Python trajectory verification path. It retains ten races per player/day, bounded durable intake, exact rewards and competition results, HA PostgreSQL and a separate reporting reader. The model assumes the packed objects, compact receipts, shorter nonprotected detail retention and forty dynamic requests/player/day in the [cost reduction plan](BACKEND_COST_REDUCTION_PLAN_2026_10_24.md). No new traffic or retention policy is implemented here.

Requirements GCO01 Google-only scope, GCO02 current regional prices, GCO03 billing and resource choices, GCO04 delivery sensitivity, GCO05 unvalidated capacity and preservation.

## Retain the managed architecture first

Cloud Run supports instance-based billing, which charges allocated instance lifetime without the request charge. This can be cheaper at sustained request volume. At forty requests/player/day and one million players, the thirty-day total is 1.2 billion requests; the request-based fee alone is about €421 at the retrieved regional catalogue tiers. Instance-based billing replaces that charge structure, but it also bills idle instance lifetime. It should be compared under measured traffic, not enabled blindly on today's quiet staging service. [Billing settings](https://docs.cloud.google.com/run/docs/configuring/billing-settings).

One continuously allocated Cloud Run CPU/one GiB under the retrieved service instance rates is approximately €45.61 per thirty days. Three average equivalents would be about €137/month. Four one-CPU/one-GiB worker-pool equivalents add about €114/month at their separate worker rates. These are planning averages; peak instance count, concurrency, queue service rate and host-loss behaviour still need a current-image load test. Small checker computation does not establish total worker throughput.

For the database, test a compact 250-GiB live dataset against a four-vCPU/sixteen-GiB HA primary and then eight/thirty-two if necessary. Their CPU/RAM prices are approximately €351/€703 per thirty days. A separate four-vCPU/sixteen-GiB reporting replica adds about €176 of compute plus disk. These are unvalidated test envelopes, not million-player ratings. Current broad Studio reporting requires a dedicated readable physical standby; Cloud SQL's internal HA failover standby cannot be treated as that extra reader.

The illustrative model includes primary/reader disk and backup usage, four TiB of GCS objects, ten million object writes, two hundred million object reads, edge and monitoring allowances, internal-traffic allowance and €150 contingency. The subtotal before client delivery and CDN lookup/fill is approximately **€1,461–1,813/month**. This is not a complete upper bound on a future bill. Each storage/operation figure is a target to validate.

The same region, pinned builds, current identity guarantees and short pool budgets remain useful. Keep manifests and prepared geometry cached. Give ordinary acceptance and low-priority projection/geometry work independent resource budgets. Do not introduce native physics replay into ordinary acceptance or allocate one idle CPU to each job waiting on I/O.

## Delivery determines how close the target gets

Cloud CDN reduces origin work and can lower the rate relative to serving everything through Cloud Run. A cache hit still incurs delivery and lookup charges. Device caching avoids a transfer; an edge cache usually changes who serves it. [CDN pricing](https://cloud.google.com/cdn/pricing).

At one million daily players for thirty days, the retrieved EUR tiers give the following European CDN comparison:

| Downloaded per player/day | Monthly volume | CDN delivery alone if cacheable | Full illustrative managed budget |
| --- | ---: | ---: | ---: |
| 0.1 MiB | 2.86 TiB | €206 | About €1,700–2,200 |
| 0.2 MiB | 5.72 TiB | €412 | About €2,000–2,500 |
| 0.5 MiB | 14.31 TiB | €934 | About €2,500–3,000 |
| 1 MiB | 28.61 TiB | €1,643 | About €3,200–3,800 |
| 5 MiB | 143.05 TiB | €7,315 | About €9,000–10,000 |

The CDN-only column excludes lookups, cache fill, load balancing and other services. Total budgets include assumed fifty-to-two-hundred million CDN lookups/month and ten-percent fill bytes. They split 0.05 MiB/day/player of private/dynamic replies through Cloud Run's European premium egress and the remaining bytes through CDN; actual response/header bytes and routing remain to be measured. All-European delivery is not a worldwide quote. A mixed geographic audience changes the rates, and private records remain authenticated.

The earlier five-MiB input was a scenario assumption. Measure compressed response bodies, header overhead, cold versus returning players, track/content changes, thumbnails, ghosts and cache misses before treating it as necessary demand. The 0.2-MiB figure is also a target, not observed consumption. Reuse immutable content, request only changed metadata and avoid fetching recordings that are never viewed. Do not lower visual quality, expose private recordings or change gameplay merely to satisfy the byte budget.

Serving through Compute Engine Standard Tier is another Google-only delivery option, but it is also metered and has different routing/latency characteristics. It does not create free bulk delivery. [Network tiers](https://cloud.google.com/network-tiers/pricing).

## Self management on Compute Engine is optional

The official EMEA E2 CPU/RAM catalogue gives these on-demand thirty-day component prices:

| Candidate VM allocation | CPU/RAM cost only |
| --- | ---: |
| One e2-standard-8, eight vCPUs/thirty-two GiB | €186.82 |
| One e2-highmem-8, eight vCPUs/sixty-four GiB | €252.03 |
| Two of each, thirty-two total vCPUs/192 GiB | €877.71 |
| Four e2-standard-16, sixty-four total vCPUs/256 GiB | €1,494.60 |

Disks, snapshots/WAL, networking, load balancing, logging, spare capacity and operations are additional. The smaller allocation is not equivalent to the larger allocation, and neither is capacity-tested for the target workload. Self-managed primary/standby failover, patching and restore become operator work. Compute Engine does not automatically beat an efficiently autoscaled Cloud Run service. [E2 machine definitions](https://docs.cloud.google.com/compute/docs/general-purpose-machines).

Move only a measured expensive component if that comparison establishes a saving with acceptable operations. There is no cost evidence here requiring Kubernetes, a rewrite, or an immediate migration away from the current managed stack.

## Commitments can close a small remaining gap

Once minimum sustained demand is demonstrated, Google lists a 25% one-year Cloud SQL CPU/RAM commitment discount. The current Compute flexible table lists 28% for eligible instance-billed Cloud Run/worker and Compute Engine usage under a one-year commitment. These discounts cover qualifying committed compute, not bandwidth, storage or unused capacity. [Cloud SQL commitments](https://docs.cloud.google.com/sql/docs/postgres/cud), [Compute flexible commitments](https://docs.cloud.google.com/compute/docs/instances/committed-use-discounts-overview).

In the low-download 0.2-MiB model, fully used qualifying commitments reduce approximately €202–290/month, giving roughly €1,750–2,150/month before unmodelled variation. That makes the €1,800 goal worth testing on Google alone, while leaving little margin in the cheaper case. No commitment purchase is recommended from an untested forecast; the obligation continues if actual traffic is lower.

## Next step and evidence

Keep the existing Google deployment while measuring current-flow bytes, SQL work, storage operations and complete acceptance latency. Implement the durable packing, receipt/archive and cache/request changes locally. Then test the managed candidate at approximately 579 accepted results/second and 2,315 dynamic requests/second, including failures, recovery, hot boards, real retained accounts and ongoing cleanup. Validate peak scaling and average billed instances independently.

The [regional price receipts](evidence/google-only-costs-2026-10-24/prices.json), [CDN receipts](evidence/google-only-costs-2026-10-24/network-prices.json) and [calculated model](evidence/google-only-costs-2026-10-24/model.json) preserve the inputs. The new price reads inspect public catalogue metadata only. Existing Cloud Run/SQL/GCS EUR receipts from the same date are reused. No resource purchase, configuration/billing change, deployment, data mutation, device test or phone/tablet attachment check was performed.

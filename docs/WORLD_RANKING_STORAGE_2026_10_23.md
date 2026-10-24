# Lean World Ranking storage

Storage refinement for the [ranking specification](WORLD_RANKING_SPEC_2026_10_22.md), 23 October 2026.

Use a small rolling score ledger and compact weekly archives. The earlier 20–30 GiB estimate at one million steady weekly finishers included wide audit rows, repeated metadata and a separate score projection. Replay files were already excluded. That layout is useful as a conservative scenario, but the ranking does not require it.

The recommended relational design projects to approximately **2.6 GiB of core active ranking data** at that participation level. Allow roughly **3–5 GiB for the active ranking database**, including additional season entries and some retention/update overhead, plus about **1 GiB for a 26-week result archive**. These are steady-data planning estimates, not a complete database volume allocation: the existing game, WAL, backups and settlement/correction staging require their own capacity.

## Keep each fact once

| Data | Storage rule |
| --- | --- |
| Car, five track versions, contract hash, field size, policy and Circuit revision | Store once in the weekly manifest |
| Player identity | Reuse the existing account; optionally allocate one collision-free numeric ranking key per player, mapped to the existing ID |
| Weekly award | Store player key, week, points and worldwide weekly place in the rolling ledger |
| Five verified weekly times | Freeze once in a weekly archive; reuse current Rivalry PBs while the week is active |
| Run references and detailed verification evidence | Follow existing operational retention and dispute requirements; avoid copying five long run IDs into every permanent score row |
| Current standings | Store scalar position/total/country facts for current and previous generations |
| Counting and reserve lists | Derive from the player's bounded ledger when requested; do not duplicate twelve result IDs and tie-breaking arrays in every snapshot |
| Lifetime achievements | Keep compact career counters and peak context; retain source facts in cold archives for corrections |
| Race inputs and recordings | Ranking adds no blanket indefinite retention requirement |

One score row needs eighteen bytes of field values with an eight-byte player key, four-byte week, four-byte weekly place and two-byte points. PostgreSQL rows, alignment, pages and indexes add overhead; the physical measurements below include it. [Integer storage](https://www.postgresql.org/docs/17/datatype-numeric.html), [row storage](https://www.postgresql.org/docs/17/storage-page-layout.html)

Keep all **26 weeks**, including noncounting results. A reserve may enter the best 12 when another result expires. Best-six season scoring can use the same awards. Keep a short extra publication/recovery buffer so serving an older generation never depends on an already deleted award.

Use weekly partitions or equivalent bounded archival/deletion. Expired awards leave the hot ledger after supported generations no longer reference them; they need not remain indexed SQL rows forever. Numeric keys are assigned uniquely, not made by truncating hashes. Existing account identifiers and APIs can retain their current formats.

## Preserve inexpensive correction inputs

Points alone cannot reconstruct a corrected week. Removing a driver or correcting a time can change other drivers' five-track placements and their worldwide awards.

A weekly binary archive can preserve one complete finisher in **34 bytes**: an eight-byte player key, five four-byte verified tick values, four-byte worldwide weekly place and two-byte points. The immutable weekly manifest supplies shared metadata and the archive checksum. A historical world-position fact can use fourteen bytes: player key, world position and world total.

These records preserve exact verified times, eligibility membership, awards and published positions without retaining every attempt, replay or copied contract string. They support arithmetic reclassification and source-based career repair. They do not let an administrator rerun a discarded replay through the physics verifier; detailed evidence still follows the existing operational/dispute policy. Record correction commands and their reasons separately, and create a new immutable weekly revision when correcting an archive.

Publish award partitions, snapshots and career changes behind the same generation boundary. The snapshot manifest selects the exact weekly revisions it uses. Do not overwrite a result that is still needed to explain a supported older snapshot. Compact archives remain subject to the existing account/privacy retention rules; an internal numeric key is not anonymity.

## Storage measurements

An owned PostgreSQL 17.11 instance measured 100,000 synthetic players, 26 weekly awards per player, three scalar snapshot indexes, an ID map and career counters. The disposable database was capped at one CPU and 1 GiB RAM. This was a storage sample, not a traffic benchmark.

| Structure | Measured physical size |
| --- | ---: |
| 2.6 million weekly score rows, including partition indexes | 208.4 MiB |
| One 100,000-player world/country snapshot, including indexes | 15.7 MiB |
| Numeric key mapping | 16.9 MiB |
| Career row per player | 8.7 MiB |
| **Ledger, two snapshots, map and careers** | **265.5 MiB** |

Extrapolating that exact layout and using uncompressed fixed-width archive records gives:

| Steady weekly finishers | Core active ranking database | Archive of 26 weeks of results |
| --- | ---: | ---: |
| 10,000 | 26.5 MiB | 8.4 MiB |
| 100,000 | 265.5 MiB | 84.3 MiB |
| 1,000,000 | 2.59 GiB | 0.82 GiB |

The archive column includes five times, weekly position and points, with the player key. Shared headers, manifests, revisions and recovery buffers are additional. No compression saving is assumed. The active core excludes an additional season index/entries, operational write overhead and staging; these account for part of the recommended 3–5 GiB planning allowance at a million.

The earlier wide ledger alone projected to 16.02 GiB for 26 weeks at one million steady finishers. The lean score ledger projects to 2.04 GiB, and it replaces both the wide SQL audit ledger and the separate hot score projection. The wider facts move to the compact archive rather than becoming a second indexed score table.

Keeping both the 34-byte result archive and fourteen-byte world-position fact for a full year at one million weekly finishers projects to **2.32 GiB before compression**, instead of approximately 32 GiB/year for the earlier wide result table. This assumes the ranked population is also one million. Turnover can make world-position archives, current snapshots, mapping and career data larger than the weekly complete field.

## Further packing is optional

The probe also packed each player's 26 point/place pairs into 156 bytes. The packed history table occupied 21.7 MiB for 100,000 players. With the same two snapshots, map and careers, the optional core design projects to 0.77 GiB at one million players.

That is an additional optimization, but a row per account/week is easier to query, partition and correct. Packed histories need explicit codec versions, presence masks, extra slots or retained generations during publication, and additional tests of updates and historical reads. A 26-slot ring alone cannot serve overlapping published and staging windows safely. Defer packing unless measured database storage pressure justifies that complexity.

## Implementation acceptance

Use the lean relational ledger and weekly archives for the first implementation. Preserve existing scoring and correction rules; this changes physical storage, not ranking merit. Validate exact archive round trips, reserve/expiry behavior, country and season reads, revision-fenced corrections and restart/atomic publication before enabling the new storage path. Test archive restoration and retention together with the existing maintenance worker. Measure write bloat, peak staging space and actual archive access latency on representative infrastructure.

The [sample evidence](evidence/world-ranking-storage-2026-10-23/probe.json) records WRS01–WRS03, layouts, physical sizes, arithmetic and limitations. Cardinality checks and exact SQL-to-Python history decoding passed; the 34-byte result and fourteen-byte world-fact layouts were checked. No game/backend runtime changes, live data mutation, deployment, device test or phone attachment check were performed.

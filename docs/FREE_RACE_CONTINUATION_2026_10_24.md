# Free Race continues beyond the daily hundred

Owner follow-up, implemented locally on 2026-10-24. Requirements DTC01–DTC03 / R01 / Q01.
The daily 100 are the first section of Free Race. Scrolling continues through the
remaining eligible catalogue without a separate button, search or fixed total
limit. The existing 60/20/20 daily mix and score weights remain.

| Requirement | Implemented behavior |
|---|---|
| DTC01: continue scrolling past 100 | The fifth full daily page has a continuation cursor when more tracks exist. Subsequent 20-card pages continue until the actual eligible catalogue end. A partially hidden daily section blends directly into continuation on the same page. |
| DTC02: ranked, stable, unique continuation | Remaining tracks use the same composite score, cached and indexed in the discovery projection. Frozen per-partition epochs preserve ordering and revision identities while browsing. All daily logical track IDs are excluded, including newly published revisions of those tracks. Current visibility and blocks still apply. |
| DTC03: bounded native flow and validation | The existing native list triggers preloading past the boundary. It retains at most13 cached pages/260 metadata entries and virtual native cards. Search and exact-revision links remain available. |

The cursor retains a daily position, a score and track ID, and
the current section. It stores no complete catalogue or growing seen-ID vector.
The exclusion set is always the published daily selection of at most100 logical
track IDs. Previous-page navigation restores the same section and key. If all
daily picks become hidden, available continuation still appears. A genuine empty
catalogue terminates normally. No fixed180 limit exists in runtime;180 is the
disposable validation fixture size.

`DiscoveryEntry.recommendation_score` caches the existing weighted formula as an
integer. The projection computes it when publishing changed entries and through
its bounded reconciliation; it is frozen with the other entry fields for each
browsing view. The `(partition, recommendation_score, track_id)` index supports
the existing keyset merge without sorting an entire catalogue inside HTTP. Each
partition contributes at most the requested page plus one look-ahead entry.
Hydration and current-authority checks remain bounded, and the existing database
deadlines, actor credits and request limits remain active. Scores have the same
eventual freshness as the projection; the entire catalogue is not frozen into
one daily rank snapshot.

Race/replay contribution changes now schedule the existing coalesced rank
publication even when a repeat race adds no new unique player. This keeps repeat
play and race-volume signals effective in continuation. Canonical simulation,
records, rewards, saved condition and controls are unchanged. Random retains its
daily-pick behavior; this follow-up changes scrolling.

Migration `0067_discovery_rank` follows the current `0066_cost_archives` chain.
It adds the cached integer and its index, then resets the existing projection
bootstrap cursors/readiness while preserving source records, epochs and history.
The matching worker fills current scores in bounded batches; new views return
the existing retryable `DISCOVERY_INDEX_PREPARING` until ready. Existing ordinary
views can continue using retained history. Explicit downgrade invalidates daily
cursors that may contain composite-rank keys and drops only this derived column
and index. Rollback/source-preservation and bounded backfill are tested.

Actual validation:

- Focused backend25pass/1skip/24 PostgreSQL deselections, covering daily selection,
  continuation and projection. A separately added repeat-only rank-refresh check
  passes1 with1 PostgreSQL deselection.
- Broader backend77pass/2skip/76 explicit PostgreSQL deselections: current daily,
  continuation, v3, projection, resource and hardening cases. This run preceded
  addition of the separate repeat-only assertion above.
- Real local HTTP/native27 headless checks and31 checks on each desktop renderer.
  The actual Free Race ScrollContainer crosses100 and loads continuation;
  original100 order, deduplication, bounded card controls and all180 reachable
  tracks are checked. The real Search drawer still finds a non-curated track.
- Existing native discovery321, preload120, list233, startup18, App141 and
  parser1085 pass. Ruff and the scoped patch/diff checks pass.

The initial daily rollback fixture expected immediate admission after upgrading
the new index migration. It now explicitly verifies readiness rejection, runs
the diagnostic worker bootstrap and retains its original source-preservation
checks. The initial PowerShell redirected native command returned a shell error
despite the captured pytest result and native assertions passing; explicit exit
propagation is used for subsequent commands. No assertion was weakened to hide
a failure. Earlier task evidence remains in its original directory.

Native views: [scrolling beyond100](evidence/free-race-continuation-2026-10-24/captures/gl_compatibility-continuation-after-100.png),
[desktop Mobile continuation](evidence/free-race-continuation-2026-10-24/captures/mobile-continuation-after-100.png),
[search](evidence/free-race-continuation-2026-10-24/captures/mobile-full-catalogue-search.png).
The [machine-readable report](evidence/free-race-continuation-2026-10-24/report.json)
records commands, actual outcomes, source hashes and a task-only patch against
the saved task-start files. Unrelated concurrent archive, security, challenge,
Garage and scenery work is preserved.

Rollout requires matching API/discovery-worker/client sources and migration0067
with the required intervening migrations and grants. No rollout, existing-process
restart or live account/backend mutation was performed. PostgreSQL index/query
plans, representative migration/load/cost, owner acceptance and physical-device
behavior remain unverified. No phone/tablet attachment check, device test, APK,
purchase or deployment was performed.

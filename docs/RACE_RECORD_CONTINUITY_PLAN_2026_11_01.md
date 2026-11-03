# Race compatibility and record continuity

## Goal

Routine deployments, visual updates, adding another car, and verifier upgrades
must not make existing personal bests or results disappear. A genuinely
different competitive ruleset may require a new comparable leaderboard, but
the previous PBs and results must remain accessible and clearly identified.
Do not silently copy times across different driving behavior or imply that an
old time was achieved under a new set of rules.

## Current causes

* `runs.py` hashes the immutable track-version ID together with the technical
  verifier manifest to identify a board. `catalog_builds.py` creates a new
  published version when the full build manifest changes, even when the
  compiled course is identical. The previous board and records remain in the
  database but are not the current version's board.
* The full build contract includes every car. An update to one car can cause
  a new version of every published track, including for all the other cars.
* Local PB keys include the global physics version. This can hide local PBs
  even for cars whose behavior did not change.
* Daily limits and standings, leaderboard histograms, Rivalry, challenge
  boards and other projections also carry version or board identities. A
  fix that only changes normal leaderboard reads would leave inconsistencies.

The immediate Free Race repair advances a frozen selection to the new build;
it does not merge historical boards or restore PBs to the current view.

An aggregate read-only staging audit on 1 November found 30 published heads.
Their current boards contained 153 race PB rows and 153 lap PB rows. Previous
versions with matching source and compiled-track hashes contained another 404
race PB rows and 404 lap PB rows; their boards did not match the current
verifier's declared capability, so compatibility remains unproven. Other
historical versions contained 6,469 race PB rows and 6,472 lap PB rows and
need separate course/history review. Counts include staging test drivers, are
rows rather than unique players, and may change while tests are running. The
audit does not prove that any particular record can safely be merged or that
the historical track differs in every case.

## Proposed identities

1. **Track and course:** keep the stable logical track ID for discovery and
   ownership; give each verified competitive course an immutable race-course
   identity covering all track geometry, gates, surfaces and other gameplay
   inputs. Keep presentation assets and ordinary verifier build IDs separate.
   Continue retaining the original published document and version as evidence.
2. **Competition class per car:** identify the effective driving physics,
   selected car handling and race rules that determine comparability. This is
   per car, not a hash of the whole fleet. Use explicitly registered,
   evidence-backed equivalence between exact source builds; never assume that
   adjacent version numbers or identical parameter files prove equivalence.
3. **Leaderboard identity:** use course identity, competition class, car and
   relevant mode/rules as the stable comparison key. Preserve each accepted
   run's original exact version, verifier build, replay and provenance. A
   verifier binary version is operational metadata and does not by itself
   create a new board.
4. **Verifier capability:** route each ticket and replay to a verifier that
   explicitly supports its exact pinned contract. Keep old and new compatible
   verifier workers available during client rollout and for the full ticket,
   upload, retry and queue-drain windows. Do not claim a worker supports an old
   contract without replay and numerical equivalence evidence.

The concrete schema and indexing must handle multiple old boards mapping to
one comparison class without merging test-driver and real-player populations.
The best time for a player is the minimum verified result across equivalent
members, with deterministic ties and the original source run retained. Historic
lap minima, ghosts, daily results, and time-distribution projections must be
recomputed or joined with the same classification. Current daily limits and
in-progress competitions remain pinned and unchanged until their own end.

## Migration and rollout

1. Build an aggregate inventory of existing track versions, boards, accepted
   runs, race and lap PBs, local-record identities and dependent projections.
   Separate test data and never infer equivalence from matching names.
2. Add immutable course and per-car class records, an explicit mapping from
   each old board/contract, and an audit trail for the evidence and decision.
   Initially leave unmapped or uncertain histories in their original classes.
3. Run historical replay corpora and deterministic simulation checks for each
   candidate equivalence, including boundary inputs and all affected cars.
   Where behavior genuinely differs or evidence is insufficient, retain the
   former board as accessible history; do not quietly join it to the new one.
4. Backfill mappings and derived indexes idempotently in bounded batches. Run
   old and new reads in parallel; compare population, per-player PBs, ties,
   provenance, filters, ghosts and distribution results. Replay or reconcile
   concurrent writes, and verify both new and in-flight submissions.
5. Deploy compatible API and worker versions before enabling the new read path.
   Gate release on historical PB coverage, supported client versions, matching
   worker capacity, zero unclassified automatic merges, and no unexpected PB
   disappearance. Keep a tested feature-flag rollback to old reads and retain
   all original boards and records.
6. Migrate local PBs using explicit equivalence aliases and source keys, keeping
   old keys available for rollback. Expose archived records where a class must
   split. Do not silently rewrite the owner's save during the migration test.

## Immediate policy until implemented

Treat a track-head refresh as potentially hiding existing results, not as a
routine compatibility fix. Before deployment, report affected per-car boards,
PBs and active competitions; block an unreviewed change that would remove
current results from view. Keep the previous verifier and historical data, and
do not publish a new build solely because an unrelated car or visual asset
changed. The operator safeguard described in
`FREE_RACE_VERSION_REPAIR_2026_11_01.md` addresses frozen discovery pins only;
it is not the record-continuity migration.

This is a design and rollout plan. It does not yet change leaderboard identity,
backfill old records, establish physics equivalence, deploy multiple verifier
versions, or restore currently hidden results.

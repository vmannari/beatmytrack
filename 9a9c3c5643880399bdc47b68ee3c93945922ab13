# Unnecessary code cleanup

2026-11-07. Implements the owner's follow-up to the static legacy-code review.

## Scope

| Requirement | Change |
| --- | --- |
| UCC01 orphaned code | Removed five unreferenced UI/editor scripts and their UIDs: `cosmetic_purchase_preview`, `garage_cosmetic_shelf`, `garage_lp_box`, `garage_opening_facade`, and `jump_style_picker`. The translation fixture now renders the actual Parts list and option controls. Removed the abandoned facade profiler switches and LP-box picture dependencies. |
| UCC02 obsolete Hover baker | Removed the old `hovercraft_surface` helper and its baker, which instantiated the current sport Hover without filling the old helper's mesh dictionary. Historical artwork/assets and evidence remain. |
| UCC03 physics gate | Removed the unreachable client .74/.75/.76 equivalence table. Playable-ID validation and exact current-physics matching remain. The current .77 client behaved identically before this simplification. Backend historical contracts are unchanged. |
| UCC04 saved-road cache | Removed the shipping synchronous fallback and pending-bake dictionary. Existing production callers continue to use the tree-owned numeric worker. Both cache suites now check its actual asynchronous save, exact geometry/metadata round trip, missing-checksum rejection, repeated save, and bounded completion. Frozen historical controls own their old dictionary inside the excluded test implementation. |
| UCC05 unused helpers | Removed App's `_garage_pictures_ready` and `_selected_object_properties`, the latter's feature delegate, Garage's `_shop_badge`, Workshop's `_bottle`/`_toolbox`, and Browser's `_cached_frame_query`. |

The source change removes 1,067 net lines across 29 files, including seven deleted
scripts and seven associated UIDs. It preserves saved-data upgrades, durable
upload recovery, historical result contracts, canonical simulation, and player
files. Concurrent workspace changes are preserved; the main Git index is not
used for the checkpoint.

## Validation

All Godot checks use `godot-version.txt`'s exact standard 4.7.2 engine, private
APPDATA directories, an empty backend URL, and Dummy audio. Commands and complete
logs are retained under `build/legacy-cleanup-2026-11-07/`; compact permanent
receipts and the task-only source patch are under
`docs/evidence/unnecessary-code-cleanup-2026-11-07/`.

| Check | Actual result |
| --- | --- |
| Production-worker road cache, ordinary editor preview | 90 checks, 0 failures |
| Production-worker road cache, final-geometry editor preview | 90 checks, 0 failures |
| Actual App composition | 141 checks, 0 failures |
| Driving | 72 checks, 0 failures |
| Backend client scalability/persistence | 18 checks, 0 failures |
| Actual ticket validator, current shared physics | 71 checks, 0 failures |
| Production script parse (tests excluded) | 552 scripts, 0 failures |
| Prepared-asset pipeline | 468 resources, 1,925 checks, 0 failures |
| Active native Garage pictures | Five exact pictures, 155 source hashes |
| Photograph provenance rejection controls | Five checks, 0 failures |

The complete standard pipeline rebuilt the bases, 442 modules, Garage templates,
header template and photographs after the fingerprinted Hover helper was removed.
Its before/after source receipt is stable. All eight existing PNG files,
including the five active car pictures, are byte-for-byte equal to task start.
The changed sources require a one-time identity/provenance refresh; no picture,
quality or simulation change is claimed.

The ticket audit reuses the existing actual-Cloud validator cases with an explicit
empty .74-.76 unchanged-car list: the shared .77 integrator supersedes that
historical simulation differential. All fourteen ticket-field acceptance and
rejection cases still run for every playable car. No HTTP request is made.

## Retained failures and controls

- The original road-cache fixture starts at 70 checks/8 failures because its
  synchronous editor-saving assumption does not match current production. The
  separate old final-geometry fixture starts at 70/0. The migrated fixtures test
  the production worker and add exact numeric geometry/metadata comparisons;
  no checksum, corruption, cache-limit, or unrelated-file preservation gate is
  removed.
- The broad translation suite remains 1,281 checks/24 failures. Every failure
  label exactly matches the pre-cleanup run and concerns the retained music
  playing/paused text. Parts-list checks pass with the current controls.
- The broad parser scans 1,849 scripts and fails. The pre-cleanup-source control
  reproduces the same 19 diagnostic labels: stale test override signatures and
  the incomplete frozen parking-hall Garage fixture. This is not a clean full
  parser result.
- The old road-build golden suite remains 37 checks/5 failures. Reloading the
  exact task-start production source reproduces the same four biome-array
  differences and old cache-count assertion. No golden data or assertion is
  changed. The frozen historical cache control retains 70 checks/8 failures.
- The wider editor workflow remains 197 checks/1 failure plus its two Nil-access
  script errors. The exact task-start production-source control reproduces all
  nine diagnostic labels; the scenery expectation and pinch-handoff failures
  are retained.
- The existing picture-identity fixture stops because it does not supply the
  checkpoint dependency `godot-version.txt`. That dependency check is unchanged.
- A picture-provenance test attempted before the rebuild correctly encounters
  the deleted Hover source still present in the old photograph receipt. Its
  final run passes all five positive/invalidation checks after regeneration.
- Direct PowerShell dot-sourcing initially encounters the local execution
  policy; the normal pipeline's process-scoped `-ExecutionPolicy Bypass` works.
  Godot also reports the local certificate-store diagnostic in the isolated
  offline test processes.

## Limits

No device query/test, APK export/install, owner-process restart, owner-save edit,
backend request, deployment, or migration was performed. Reload the client to
use the cleaned sources. This cleanup makes no loading-time, memory, FPS, or
device-performance claim.

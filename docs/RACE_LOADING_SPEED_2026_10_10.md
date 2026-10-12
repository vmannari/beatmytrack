# Repeated race loading, 2026-10-10

Owner request: substantially reduce race loading, including tracks just driven.
Requirements: **RLOAD01** reuse validated compiled tracks; **RLOAD02** reuse
prepared scenery with bounded memory and independent race state;
**R01/Q01/B07/V03/V05** retain race flow, pinned contracts, five laps and appearance.

`CloudTracks.compile_entry` previously ran the complete compiler on every
Rivalry/challenge start despite an intact downloaded document. Each new race
also rebuilt terrain, barriers, scenery, props, bridges and finish markings;
the existing cache covered roads alone. Rivalry ghosts already prefetch without
holding the required race data; no ghost or backend changes were needed here.

Compiled snapshots now retain up to five tracks within 32 MiB of serialized
data. Every lookup still checks the saved document's hash and validation.
The key contains its server-scoped cache path, hash and compiler version.
Every caller gets independent metadata, arrays and kerb/snow contact data;
current cloud identity/version fields are applied afterwards. A mutex protects
the cache shared by background discovery compilation and race preparation.

Completed ordinary-race scenery now retains up to five worlds within a
conservative 64 MiB resource estimate. Keys include content hash, track kit,
contact-lighting version, biome, palette and night partition settings.
Restoration creates fresh nodes, light/soft-prop references and mutable
MultiMesh buffers. Contact-lighting groups survive packing. The cache stores
the initial geometry before race props/tyres move. Editor and sliced menu
builds retain their existing builders. No tickets, scores, controls, countdown,
simulation, rewind state or server authorization are reused.

Both new caches are process-local. Existing bounded road disk caching remains.
Large worlds evict older entries: the intentionally dense five-biome fixture
estimates 160,902,288 bytes and retains two worlds under the 67,108,864-byte
limit. Oversized single entries use the ordinary builder. These budgets are
resource estimates rather than a measurement of total process RAM.

## Measurements

Pinned Godot **4.7.2.stable.official.ed1daf0bf**, Windows Compatibility renderer,
RTX 3090, 1280×720. Identical repository documents, three passes each.
Times include document validation/compilation, fresh game creation, initial
presentation and first completed draw. They exclude HTTP, app transition
frames, countdown and screenshot encoding. Results average the two immediate
repeat passes; these are local preparation timings, not end-to-end live races
or Android measurements.

| Fixture | Before repeat | After repeat | Reduction |
|---|---:|---:|---:|
| Ajorata | 1,579.91 ms | 551.05 ms | 65.1% |
| Star spline | 1,783.39 ms | 357.61 ms | 79.9% |
| Verified oval | 871.21 ms | 544.90 ms | 37.5% |

Repeat compilation alone changed from 189.64–825.56 ms to 12.89–31.12 ms
in these recorded runs. Desktop scheduling varies; an earlier post-change run
measured 371.69–459.67 ms total. First-load values are not a controlled cold
comparison because existing road/shader caches warmed during the investigation.
The final run's first passes were 714.31–2,053.47 ms.

Raw timings: [before](evidence/race-loading-speed-2026-10-10/before-timings.json),
[after](evidence/race-loading-speed-2026-10-10/after-timings.json).
Frozen zero-time/five-lap captures, visually inspected:
[Ajorata first](evidence/race-loading-speed-2026-10-10/ajorata-first.png),
[Ajorata repeat](evidence/race-loading-speed-2026-10-10/ajorata-repeat.png),
[Star first](evidence/race-loading-speed-2026-10-10/star-first.png),
[Star repeat](evidence/race-loading-speed-2026-10-10/star-repeat.png).

## Files and actual checks

Runtime: `game/backend/cloud_tracks.gd`, new
`game/backend/prepared_track_cache.gd`, `game/core/game.gd`,
`game/track/native_track_visual.gd`, new `game/track/prepared_world_cache.gd`.
New tests: `game/tests/profile_repeat_race_load.gd`,
`game/tests/test_prepared_race_load.gd`, with corresponding Godot UID files.
This report and both project status documents record the change.

All commands use `powershell -NoProfile -ExecutionPolicy Bypass -File
scripts/dev.ps1` with the following actual arguments:

- `-Action TestScript -ScriptPath res://tests/profile_repeat_race_load.gd -Graphical`:
  baseline and final nine timing rows; zero-tick/full-countdown/five-lap assertions pass.
- `-Action TestScript -ScriptPath res://tests/test_prepared_race_load.gd -Graphical`:
  **73 checks, zero failures**. Exact scenery/resources/render flags/groups in
  all five biomes; independent moved props/tyres; cache bounds, corruption,
  removed-file, version and concurrent access checks; exact canonical state
  after 480 identical ticks per biome against uncached geometry.
- The same prepared-cache suite also passes headless: **73 checks, zero failures**.
- `-Action TestApp`: **99 checks, zero failures**.
- `-Action TestScript -ScriptPath res://tests/test_race_loading.gd -Graphical`:
  **81 checks, zero failures**, including drawn/frozen loading frames,
  cancellation, practice and the full countdown.
- `-Action TestScript -ScriptPath res://tests/test_free_race_restart.gd`:
  **17 checks, zero failures**, fresh-ticket and explicit-offline behavior;
  **47 ObjectDB references reported at shutdown**, not hidden or claimed fixed.
- `-Action TestRoadCache`: **66 checks, zero failures**.
- `-Action TestScript -ScriptPath res://tests/test_script_parse.gd`:
  initial **438 scripts**, final **441 scripts, zero failures** after the extra
  test assertions and concurrent workspace additions.

Initial restricted profiler access could not write the usual Godot log.
Normal local access allowed the tests. The old standalone local-track profiler
did not find its requested valid document, so timings use retained repository
fixtures. An initial test cache path required Windows absolute-path expansion.
Development iterations corrected primitive mesh accounting, auto-generated
node-name restoration, node owners, headless MultiMesh buffer copying and
nonpersistent contact groups. A test initially assumed five very large worlds
must fit simultaneously; measured 160.9 MB disproved that assumption. The
corrected check requires all five only when they fit and retains the 64 MiB cap.
No product invariant or prior assertion was removed to accept the change.

`Import` first refreshed the existing workspace's concurrent VehicleLivery
class; a concurrently created GaragePage was not registered in that attempt.
Later import attempts encountered an in-use native audio reload DLL. Direct
script compilation and app tests subsequently passed; no successful full
editor import is claimed.

No phone attachment check or physical-device test was performed. No Android
export/install, full Validate, live player-score writes, backend changes or
deployment. Owner acceptance still requires restarting the desktop client
(or rebuilding Android), timing actual signed-in starts and revisits,
confirming mobile RAM/load behavior and checking tracks after eviction/restart.
First unseen tracks and fresh required server tickets still take time.

The task-only Git review checkpoint uses
`refs/codex/repeat-race-loading-20261010`. Its parent holds current versions of
the touched existing files with only this task's edits reversed; its diff
contains the loading changes, tests, documentation and evidence. It preserves
the working branch/index and excludes concurrent garage/livery work. This is
a review checkpoint over the existing workspace, not a standalone release
checkout. [Checkpoint receipt](evidence/race-loading-speed-2026-10-10/checkpoint.json).

# Local personal ghosts — 2026-10-03

The owner requests their own personal-best lap and race ghosts, stored locally, with the rewind car silhouette in grey. This is the first ghost slice; there is no shared or downloaded ghost flow.

| Requirement | Implemented behavior |
| --- | --- |
| GH01 | Settings > Ghosts has Off, Personal best lap and Personal best race. Default is lap. Staged Apply, scoped reset, persistence and failed-save rollback use existing preferences. Pause > Settings changes the choice for the current race and saves it when possible. |
| GH02 | Lap mode uses the best flying lap, matching the existing local lap PB (standing first lap excluded). It starts with every player lap, using that lap's precise accepted start crossing. Race mode starts with the race clock. Both hide after their recording ends; no extrapolation or repeated race playback. |
| GH03 | Only completed ordinary five-lap races supply recordings, including accepted rewind-assisted races. Match or improve the existing PB to create a recording for an older time. Lap/race PB updates are independent. Abandoned races and editor practice do not overwrite recordings. |
| GH04 | Grey translucent body/edge treatment mirrors the rewind ghost material. One flattened mesh of the selected fictional car; no collision, shadows, particles or canonical simulation interaction. Mesh/body/camera scale is unchanged. |
| GH05 | Storage is local and profile-scoped, using the same track-content/physics/handling/rules key as LocalRecords. Recordings never enter online replay payloads. Different cars, track revisions, handling and local accounts cannot share a PB recording. |
| GH06 | Rewind confirmation truncates discarded poses and lap crossings, then records the restored position. Playback follows restored race/lap clocks. Countdown, rewind selection and the finish presentation hide the racing ghost. |
| GH07 | Bounded 20 Hz poses with display-rate interpolation, shortest-angle wrapping, bridge/ground layer height, jump, water/ramp and kerb pose. Swept finish timestamps and interpolated endpoint poses preserve fractional ticks. Thirty-minute recording cap, strict finite/ordered sample validation and 16 MiB file cap. |

`<records-path-without-extension>_ghosts/<PB-key>.json` stores optional independent `lap` and `race` recordings under schema 1. Each pose is `[relative_tick,x,y,world_height,heading,pitch,roll]`. Primary/backup recovery ignores uncommitted `.tmp` files; write, flush and validate before rotating a valid primary to `.bak` and renaming the temporary. Corrupt primary replacement preserves the good backup. A matching ghost is accepted only when its rounded milliseconds equal the current local PB. Ghost-save failure retains the saved time and queues a visible return-to-menu notice. No older player files are deleted or migrated.

Changed files:

- `game/race/personal_ghost_run.gd`, `game/persistence/local_ghosts.gd`, `game/vehicle/personal_ghost.gd` and their engine UID files: capture/slicing/interpolation, bounded local storage and grey mesh presentation.
- `game/core/game.gd`, `game/core/app.gd`: race/restart/rewind/result lifecycle, saved selector and error reporting.
- `game/persistence/local_records.gd`, `game/ui/settings_page.gd`, `game/ui/race_pause_menu.gd`: validated preference and two selectors. Settings category height is 66 logical units so five categories fit the existing panel.
- `game/tests/test_personal_ghosts.gd`, `game/tests/capture_personal_ghosts.gd`, `game/tests/capture_settings.gd`: persistence, fractional timing, actual AI five-lap integration, selection/reset/save failure and desktop evidence.
- `scripts/dev.ps1`: ghost regression added to full validation; existing TestScript remains the focused entry point.
- `docs/schemas/local-personal-ghost-v1.schema.json`, this record, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md` and `docs/evidence/personal-ghosts-2026-10-03/`.

Actual verification (pinned Godot 4.7.2):

| Actual command | Outcome |
| --- | --- |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Import` | Passed with matching engine/templates. Initial direct script invocation was denied by PowerShell execution policy; initial sandboxed engine import failed Windows certificate-store access. Normal entry-point runs with certificate access succeeded. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_personal_ghosts.gd` | Final 38 checks, zero failures: persistence/backup/corruption, fractional finish, independent PBs, profile/car/content partitions, limits, actual five-lap recording, restart and race/lap clock playback. Final run reports three ObjectDB shutdown instance warnings; earlier runs reported four. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestRecords` | 54 checks, zero failures. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestRewind` | 57 checks, zero failures. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestApp` | 96 checks, zero failures. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 CaptureSettings` | Final 235 checks, zero failures; three sizes, staged ghost selection, Apply/reload, scoped reset, unrelated-preference preservation and failed-save rollback/retry. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/capture_personal_ghosts.gd -Graphical` | Passed; five desktop screenshots and actual completed-race recording/pause selection checks. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 TestScript -ScriptPath res://tests/test_script_parse.gd` | 268 scripts, zero failures. An initial mistaken `check_scripts.gd` path was rejected before engine execution, then corrected. |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 Doctor` | Correct engine/templates; DN2103 attached. Device listing is not driving acceptance. |
| `python build/ghost_checkpoint.py` and `git apply --reverse --check docs/evidence/personal-ghosts-2026-10-03/personal-ghosts.patch` | Scoped review patch generated and reverse-check passed; existing unrelated work is excluded. |
| `git diff --check -- game/core/app.gd game/core/game.gd game/persistence/local_records.gd game/ui/settings_page.gd game/ui/race_pause_menu.gd game/tests/capture_settings.gd scripts/dev.ps1 DEVELOPMENT_STATUS.md docs/PHASE_0_PLAN.md` | Passed; only existing line-ending conversion notices. |

Initial focused failures were corrected: JSON corruption now uses quiet parser errors; an unrelated stale ghost cannot block replacement with a matching current PB; Vector3/JSON comparison uses appropriate float tolerance. No failing invariant was removed. Settings' first added checks passed 225 before expanding reset/failure coverage to 235. No full Validate, canonical replay/physics gate, Android export/install or physical-device test is claimed.

Evidence: [race ghost](evidence/personal-ghosts-2026-10-03/race-ghost-1280x720.png), [lap ghost](evidence/personal-ghosts-2026-10-03/lap-ghost-1280x720.png), compact variants, [pause selector](evidence/personal-ghosts-2026-10-03/pause-ghost-settings-1280x720.png), and three `settings-ghosts-*.png` menu captures copied from `build/settings`. Final focused raw output is retained under the evidence `logs/` directory. Race screenshots use an actual completed-race recording with the live car staged beside it to expose the translucent silhouette; they are visual evidence, not a device benchmark. Grey body, heading and compact menu layout were inspected.

Remaining acceptance: owner driving/visual approval, real-phone selector touch targets and ghost legibility in desert dust/night/shadows, frame pacing/thermal measurements and all-five-car motion on a phone. Recordings use static flattened vehicle geometry: wheels, body suspension and rollover animation do not reproduce every live animation. Changes to physics/rules/content naturally start new partitions. Recording caps prevent saving overlong races; older PBs cannot be reconstructed from timing-only files. Two separate local files commit best times and poses, so a failed ghost save leaves the time valid with no matching ghost until a future qualifying race. No production/backend deployment or owner data changes were performed.

The workspace already contained unrelated visual/dust/results changes. A scoped Git patch at `docs/evidence/personal-ghosts-2026-10-03/personal-ghosts.patch` is the reviewable checkpoint; it excludes pre-existing launch-cue changes and other tasks. No mixed-tree commit.

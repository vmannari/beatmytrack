# Ajorata movable-object rendering regression, 2026-10-10

Requirements: V04/V05 (visible presentation), R01 (canonical driving), Q01
(regression evidence). MOV01: tire and soft-prop transforms update during
ordinary play. MOV02: cached races, earlier snapshots, finish coasting and
restart preserve the same presentation behavior.

The car collision simulation still displaced Ajorata's tires and cones.
`game/core/game.gd` accidentally nested both visual updates inside
`if profile_enabled`. Normal play therefore kept the objects at their authored
positions. The updates now run whenever a native track exists; only timing
measurement depends on profiling. The native-track guard also prevents the
profiling-enabled handling playground from accessing a null track.

No physics, handling, rules, gates, race length, verification, scoring or
backend contract changed. Both updates use the existing selected presentation
simulation, including the finish-coast simulation.

The first graphical attempt also exposed a separate existing compile blocker:
the dust renderer retained functions referring to removed `_dust_car` fields.
Its current version 17 had already removed the fields, shader include and game
call. Removed the orphaned functions and their remaining material-binding call
in `game/vehicle/sand_dust.gd`; retained the current dust and bridge behavior.
The pre-cleanup source and original error log are saved with the evidence.

## Actual verification

All commands used the pinned Godot
`4.7.2.stable.official.ed1daf0bf` through
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`.

| Arguments | Actual outcome |
|---|---|
| `-Action TestScript -ScriptPath res://tests/test_moving_prop_presentation.gd -Graphical -TestArgument '--capture-moving-props=res://../docs/evidence/moving-props-2026-10-10/final'` | Final **37 checks, zero failures** |
| `-Action TestApp` | **99 checks, zero failures** |
| `-Action TestRewind` | **61 checks, zero failures** |
| `-Action TestScript -ScriptPath res://tests/test_prepared_race_load.gd -Graphical` | **73 checks, zero failures** |
| `-Action TestScript -ScriptPath res://tests/test_script_parse.gd` | **458 scripts, zero failures** |

The new graphical test uses the actual retained Ajorata document with its
24 tire stacks and two cones. Canonical 90-tick car collisions displaced a
tire by **1.946 m** and a cone by **5.641 m**. It checks GPU MultiMesh tire
positions/spins and cone positions/tilts through the real game's `_process`,
with profiling both off and on, on first and cached race loads. Presentation
leaves canonical snapshots exact. Earlier initialized snapshots restore both
object kinds; the finish-coast state presents both kinds, restart resets the
tires, and the non-native playground runs with profiling off/on.

Before the game fix, the initial integration run recorded seven assertion
failures plus a null-track error in the profiling-enabled playground. That
early test also reused simulation objects during resets; the final test keeps
the independent collision fixtures intact. The original failures are retained
as diagnostic evidence, not claimed as a completed baseline suite. Initial
sandbox access could not write Godot's standard log; normal local access
resolved this. Only that attempt's verified hung process tree was stopped.

Desktop Compatibility/RTX 3090 captures at 1280×720 were visually inspected:
[authored tire positions](evidence/moving-props-2026-10-10/final/tyres-before-present.png)
and [collision positions](evidence/moving-props-2026-10-10/final/tyres-after-present.png).
These show the same car/camera pose around the displaced stack. They are
frozen presentation checks, not a recorded player lap.

Changed runtime files: `game/core/game.gd`, `game/vehicle/sand_dust.gd`.
New regression: `game/tests/test_moving_prop_presentation.gd` and UID.
Documentation: this report, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`.
Source snapshots, logs and screenshots:
`docs/evidence/moving-props-2026-10-10/`.

No phone attachment check or physical-device test was performed. No Android
export/install, full Validate, physics merge, account/score writes or backend
deployment. The desktop client must restart to load the fix; installed Android
builds require a rebuild. Remaining acceptance: the owner's actual Ajorata
drive and Android visual/performance behavior.

The task-only review checkpoint is `refs/codex/moving-props-20261010`.
Its synthetic parent contains current touched files with only this task's
changes reversed; its diff preserves unrelated workspace changes and the
working branch/index. The receipt is saved beside the evidence.

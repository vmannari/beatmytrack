# Remove rejected meadow bumps — 2026-10-03

Requirements: V02/V04/V05 (readable procedural scenery), R01/Q01 (presentation boundary and verification), RW03 (recorded ghost presentation). The owner rejected the trial because its bumps were not visible enough and caused issues with other surfaces, and explicitly requested their removal. This supersedes the trial described in [OFFROAD_RELIEF.md](OFFROAD_RELIEF.md).

Visual kit `track-kit-107` restores the previous flat ground plane, including its existing creator offset and Night ground tiles. Removed the bump meshes, height field/cache, editor propagation, vehicle pitch/roll and tyre-height additions, object grounding, projected-shadow slope adjustments, particle/trail offsets and rewind-ghost terrain transforms. Restored the previous fine grass normal calculation. Removed the relief-specific test and development actions together with the removed feature.

The restored sand colour, restrained verge boundary, worn concrete kerbs and lighter muted kerb red from kits 104/105 remain. HUD, camera preferences, canonical physics, collisions, track documents and backend files receive no changes from this rollback. Shared files retain unrelated work already present in the workspace. No shipping asset, schema or golden fixture needs changing. Historical trial evidence is retained and marked superseded.

## Changed files

| Files | Removal |
| --- | --- |
| `game/track/ground_relief.gd`, its UID and `game/tests/test_ground_relief.gd` | Delete the rejected height field, mesh generator and its test. |
| `game/track/native_track_visual.gd` | Restore flat terrain and prior object positioning; advance visual cache version to 107. |
| `game/track/surface_detail.gdshaderinc`, `contact_shading.gd` | Restore pre-trial grass normals and contact projection. |
| `game/core/game.gd`, `game/vehicle/car_visual.gd` | Remove terrain support samples and extra suspension/transform arguments. |
| `game/vehicle/skid_trails.gd`, `sand_dust.gd`, `rewind_ghosts.gd` | Restore prior flat-ground effect and ghost presentation. |
| `scripts/dev.ps1` | Remove only `TestGroundRelief` / `CaptureGroundRelief`. |
| This report, `OFFROAD_RELIEF.md`, status/plan and evidence | Record owner rejection, removal and actual verification. |

## Actual verification

All engine actions below used `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action <action>`, pinned Godot `4.7.2.stable.official.ed1daf0bf`. Graphical captures used Compatibility/OpenGL on RTX 3090.

| Action / arguments | Actual outcome |
| --- | --- |
| `Import` | Final exit 0. An initial import during partial removal failed on a remaining `GroundRelief` reference in `game.gd`; all remaining references were then removed. Both logs retained. Existing target-SDK/build-tools fallback message remains. |
| `TestRoadBuild` | 33 checks, zero failures, exit 0; existing road mesh golden comparisons and canonical data preserved. |
| `TestSuspension` | 59 checks, zero failures, exit 0; ramp response/settling retained at 120/60/30 Hz. |
| `TestSurfaces` | 50 checks, zero failures, exit 0. |
| `TestContactShading` | 23 checks, zero failures, exit 0. Reports three ObjectDB instances leaked at shutdown. |
| `TestRewind` | 57 checks, zero failures, exit 0. |
| `TestBridgeContacts` | 16 checks, zero failures, exit 0; six forward/reverse join runs have zero collisions. |
| `CaptureKerbs` | 40 checks, zero failures, exit 0; retained worn kerb paint and crossing presentation captured and inspected. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | 258 scripts, zero failures, exit 0. |
| `CaptureStyle -StyleDocument 'C:/Codes/Godot/Beat my track/build/track-restoration-backup-2026-10-03/userdata/tracks/track_acf29166cceaaa42.json'` | Exit 0; read-only Ajorata fixture, native cells preserved, road normals valid, gameplay/12 route views/model views saved. Gameplay and corner images inspected. |
| `Doctor` | Exit 0; exact engine and matching template directory found; DN2103 attached. |
| `rg -n 'GroundRelief\|ground_relief\|MeadowRelief\|terrain_pose\|terrain_heights\|TestGroundRelief\|CaptureGroundRelief' game scripts` | No matches, exit 1 as expected for an empty search. |
| `git diff --check -- <changed paths>`, `git diff --cached --check` | Exit 0. Staged runtime source matches the pre-trial checkpoint, with only the visual cache version advanced to 107; unrelated edits remain outside the checkpoint. |

The new flat gameplay and corner PNGs are byte-for-byte identical to the retained pre-bump captures. This confirms the reference views return to the previous presentation. SHA-256 comparisons and staged source audit are retained in `removal-audit.log`.

[Flat gameplay](evidence/offroad-relief-removal-2026-10-03/gameplay-flat.png), [flat corner](evidence/offroad-relief-removal-2026-10-03/corner-flat.png), [retained kerbs](evidence/offroad-relief-removal-2026-10-03/kerbs-retained.png), [rejected trial gameplay](evidence/offroad-relief-2026-10-03/gameplay-after.png). Images retain existing diagnostic countdown/paused overlays; unrelated HUD changes in the workspace may differ from the historical trial image. Individual invocation logs are saved beside the new captures.

No Android export/install, physical-device driving, GPU/thermal benchmark or full `Validate` was performed. A phone was attached during Doctor. Remaining acceptance: owner review of the restored flat presentation and surface joins during ordinary gameplay on the phone. This task introduces no replacement bump technique.

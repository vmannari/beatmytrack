# Roadside sand and worn kerb correction - 2026-10-03

Requirements: V02 (mature matte/cel-shaded presentation), V04 (readability and mobile cost), V05 (shared creator presentation), R01/Q01 (preserved canonical data and actual evidence). The owner rejected the changed sand shade and excessive verge fluctuation from kit 103, requested worn racing kerbs, and retained the exclusion of HUD work.

## Result

Presentation kit `track-kit-104`. This supersedes the soil-tint and broad meadow-encroachment treatment recorded in [ENVIRONMENT_COHERENCE.md](ENVIRONMENT_COHERENCE.md).

- Removed the cool soil multiplier from both the exposed asphalt fringe and gravel shoulder. Both again use the original sand palette and shared sand detail, matching painted sand outside the road.
- Removed broad grass-macro-driven verge cut-ins. The transition now uses a fixed coverage range and small baked-factor breakup (at most about 2.7 cm on a typical 1.35 m shoulder). Original shoulder mesh widths and their existing erosion remain unchanged; this correction removes the newly added large apparent width fluctuations.
- Raised and flat painted kerbs share original matte painted-concrete wear: lightly aged paint, restrained exposed-concrete chips, intermittent rubber/dirt scuffs and filtered joins every 75 cm. Red/white blocks remain readable. Existing crowns, bevels, taper, kerb colours and collision are retained. Desert sand berm/apron presentation is unaffected.
- Bound the existing baked surface factors to ordinary raised kerbs as well as desert kerbs. The wear helper adds two texture lookups on painted kerbs; no new textures, passes, decals, lights or meshes are introduced. Device GPU cost remains unmeasured.

HUD source/assets, gameplay camera, car dimensions, handling, lap gates, rules and player documents were not edited by this task. Existing single-piece kerb geometry and unrelated workspace changes are excluded from the checkpoint.

## Changed files

| File | Purpose |
| --- | --- |
| `game/track/surface_detail.gdshaderinc` | Stable meadow/soil transition with restrained edge breakup. |
| `game/track/creator_road.gdshaderinc` | Restore original shoulder sand colour; apply shared wear to flat kerbs. |
| `game/track/kerb_paint.gdshaderinc` | Original painted-concrete wear helper using existing baked factors. |
| `game/track/kerb.gdshader` | Apply shared wear to raised painted kerbs. |
| `game/track/native_track_visual.gd` | Kit version 104 and common kerb baked-factor binding only. |
| `game/tests/test_surface_profile.gd`, `scripts/dev.ps1` | Optional explicit read-only fixture directory for the existing surface regression. |
| This report, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, evidence folder | Actual results, captures and acceptance limits. |

The fixture argument accommodates the separately authorized transfer of local track masters to the backend. It leaves the original surface assertions intact and adds a directory-validity assertion. No player file is restored, modified or copied into shipping assets.

## Evidence

[Interactive before/after comparison](evidence/kerb-verge-correction-2026-10-03/comparison.html), [gameplay after](evidence/kerb-verge-correction-2026-10-03/ajorata-after.png), [corner after](evidence/kerb-verge-correction-2026-10-03/ajorata-corner-after.png), [kerb detail after](evidence/kerb-verge-correction-2026-10-03/kerb-worn-before.png).

Baseline is kit 103 immediately before this correction. Final desktop captures were visually inspected. The paired gameplay images retain the existing diagnostic pause/countdown overlays. The existing kerb diagnostic uses a closer camera and hides HUD for inspection; production camera and HUD code are unchanged. Kerb filenames `before`, `crossing` and `after` refer to positions in the driving sequence; `original` versus `worn` identifies the material comparison.

## Actual commands and outcomes

All engine actions used `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action <action>`, pinned Godot `4.7.2.stable.official.ed1daf0bf` and matching templates. Graphical runs used Compatibility/OpenGL on RTX 3090. Logs are retained alongside the images.

| Action / arguments | Actual outcome |
| --- | --- |
| `CaptureStyle -StyleDocument 'C:/Codes/Godot/Beat my track/build/track-restoration-backup-2026-10-03/userdata/tracks/track_acf29166cceaaa42.json'` | Baseline and final captures exit 0; canonical cells preserved; road vertex/normal counts match, with no invalid normals. Start and corner pairs retained. |
| `CaptureKerbs` | Baseline and final each pass 40 checks. Forward peak 0.01808586 m, reverse peak 0.01800998 m and visual crossing peak 0.03320079 m exactly match the baseline; pitch and speed-loss values also match. Final material was captured after reducing the initial wear intensity. |
| `TestRoadBuild` | 33 checks pass, including exact road mesh arrays for Pine, Desert, Winter and Night city and cache/canonical preservation. |
| `TestShoulders` | Shoulder union area 30, 10 triangles, no failures or overlapping interiors; visual joins 71 checks pass; internal contours 18 checks pass. |
| `TestSurfaceProfile -TracksPath 'C:/Codes/Godot/Beat my track/build/track-restoration-backup-2026-10-03/userdata/tracks'` | 929 checks pass: all 928 original material/mesh/mask assertions plus the explicit-directory guard, using read-only Ajorata and Storm backups. |
| `Doctor` | Engine and templates pass; DN2103 phone attached (`PRQKU4U4PREQNRWG`). |

No Android export, installation, physical-device driving or GPU/thermal test was performed. No physics/rules change or full physics regression is claimed. Remaining acceptance: owner review of sand continuity, verge restraint and kerb wear at the normal gameplay distance, followed by phone readability and performance testing.

## Red shade follow-up - 2026-10-03

The owner requests a slightly lighter red because the current paint reads too bright red. Requirements V02/V04/V05/Q01. Kit `track-kit-105` changes the standard raised-kerb source paint from approximately `#a63e30` to `#ae5749`: slightly lighter with less saturation, giving a muted brick tone. The existing concrete wear, white blocks and shading remain. Desert's explicit sand-colour override remains; no HUD, geometry, canonical or additional texture/pass changes.

Changed files: `game/track/kerb.gdshader` (red default), the version constant only in `game/track/native_track_visual.gd`, this report, both status documents and the two evidence files. The separate solitary-piece geometry correction remains outside this checkpoint.

Actual pinned commands: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action CaptureKerbs` passes 40 checks, including the same bump/pitch/speed-loss values; `-Action Doctor` confirms matching engine/templates and DN2103 attached. The Compatibility/RTX 3090 capture was inspected beside the prior material. [Previous red](evidence/kerb-verge-correction-2026-10-03/kerb-worn-before.png), [muted red](evidence/kerb-red-shade-2026-10-03/muted-red.png), [capture log](evidence/kerb-red-shade-2026-10-03/kerbs-capture.log). No Android export/install or phone visual/performance test was performed. Owner shade acceptance remains.

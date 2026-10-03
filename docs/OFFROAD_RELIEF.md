# Smooth meadow relief - 2026-10-03

**Removed by owner request on 2026-10-03.** The bumps were insufficiently visible and caused issues with other surfaces. Kit 107 restores flat ground and removes the shared terrain-following system. See [the removal record](OFFROAD_RELIEF_REMOVAL.md) for current behavior and verification. All implementation details, results and remaining checks below describe the superseded trial.

Requirements: V02/V04/V05 (coherent, readable, bounded procedural scenery), R01/Q01 (presentation boundary and evidence), RW03 (recorded rewind presentation). The owner authorizes proceeding with the proposed grass-biome trial at twice the suggested height: 20-50 cm.

## Result

Visual kit `track-kit-106`, original procedural field `meadow-relief-1`.

- Grass/Pine gets sparse rounded mounds with nominal peaks of 0.20-0.50 m and diameters of 3.6-6 m. Their cosine profiles meet surrounding flat ground smoothly. The actual diagnostic track reaches 0.43634 m; road proximity and mesh sampling reduce individual peaks.
- All non-grass surface cells, solid footprints and bridge decks are conservatively excluded. A 2.6-5 m clearance/fade field keeps the existing road, kerbs, full sand shoulder, painted sand, water and jumps flat. The meadow mesh meets the existing outer backdrop at zero added height. Sand colour and road-border geometry are unchanged.
- A fixed identity seed keeps existing mounds stable during creator edits. The road/obstacle mask follows compiled geometry. Generated heights are cached by content/version, with at most four cached fields. There are no creator-document/schema or canonical track changes.
- The original terrain material is retained. Smooth mesh normals supply broad lighting; the existing fine grass relief now adds to those normals instead of replacing the slope. Geometry is split into approximately 32 m chunks for culling, with shadow-map casting disabled.
- One shared triangle-accurate height sampler supports the car, individual tyres, contact projections, placed props, small rocks, loose tyres, grass particles, skid trails and rewind ghosts. Low chassis clear crests between their axles; tyre suspension follows individual contacts. Bridge-layer, jump, water and roll presentation retains its existing boundaries. The canonical handling, collisions, lap timing and rewind recordings receive no terrain forces or state writes.
- Desert, Winter, Night and Storm retain their existing ground presentation for this first Grass trial. HUD assets/layout, camera settings and vehicle mesh dimensions were not changed by this task.

## Cost and limits

The shared height grid has at most 32,768 points, normally spaced 0.75 m apart. Larger tracks use coarser spacing; chunk edges duplicate some renderer vertices. The diagnostic has 19,431 points and 12 chunks. Final cold construction was about 79 ms headless and 78 ms graphical on the desktop; these are load-time CPU observations, not GPU or phone benchmarks. Cache hits reuse the field and meshes. Per-frame grounding uses a small fixed number of height samples; there is no animated terrain, new texture, runtime noise shader or extra shadow-map caster.

Phone load latency, visible chunk draw cost and sustained frame pacing remain unmeasured. The terrain adds cosmetic height only; it introduces no physical bump forces, jumps or traction changes. Owner appearance/motion acceptance and phone performance acceptance remain.

## Changed files

| Files | Purpose |
| --- | --- |
| `game/track/ground_relief.gd` and engine UID | Original bounded field, exclusion mask, smooth chunk meshes, triangle sampler and cache. |
| `game/track/native_track_visual.gd` | Kit 106, terrain chunks and editor/prop/loose-object grounding. |
| `game/track/surface_detail.gdshaderinc` | Preserve actual slopes beneath existing grass normal detail. |
| `game/track/contact_shading.gd` | Shared-height contact projections; existing callers retain flat defaults. |
| `game/core/game.gd`, `game/vehicle/car_visual.gd` | Terrain support, pitch/roll and individual tyre presentation. |
| `game/vehicle/skid_trails.gd`, `sand_dust.gd`, `rewind_ghosts.gd` | Ground existing effects and recorded ghosts. |
| `game/tests/test_ground_relief.gd`, `scripts/dev.ps1` | Geometry/grounding invariants and pinned headless/capture entry points. |
| This report, status documents and evidence | Actual verification, screenshots and remaining acceptance. |

Only task-owned changes are included in the checkpoint; pre-existing camera, checkpoint, backend, control and single-piece kerb corrections remain outside it. The terrain is original procedural geometry with existing cleared textures; no reference or generated image is added as a shipping asset.

## Evidence and actual verification

[Before/after comparison](evidence/offroad-relief-2026-10-03/comparison.html), [gameplay after](evidence/offroad-relief-2026-10-03/gameplay-after.png), [off-road production camera](evidence/offroad-relief-2026-10-03/offroad-gameplay.png), [terrain/car detail](evidence/offroad-relief-2026-10-03/offroad-detail.png). Desktop images were inspected. The closer detail view is diagnostic only. Normal gameplay captures retain their existing paused/countdown HUD overlays.

All engine commands used `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action <action>`, pinned Godot `4.7.2.stable.official.ed1daf0bf`, matching templates and Compatibility/OpenGL on RTX 3090 for graphical runs.

| Actual action / arguments | Result |
| --- | --- |
| `Import` | Exit 0; registers the new GroundRelief class. Existing target-SDK/build-tools fallback message retained. |
| `TestGroundRelief` | Final 80 checks, zero failures, exit 0. Covers deterministic construction/cache, 50 cm cap, all protected cells and 1.65 m shoulders, explicit oil/jump footprints on unchanged grass, triangle sampling/normals, unchanged documents/cells, biome exclusion and all five cars' support/clearance/tyres/shadows/trails/particles/recorded ghosts. |
| `CaptureGroundRelief` | Final 82 checks, zero failures, exit 0, including actual production and detail captures. |
| `TestRoadBuild` | 33 checks pass; exact existing road mesh arrays and canonical cells across Pine/Desert/Winter/Night are preserved. |
| `TestSuspension` | 59 checks pass; existing ramp peaks and settling at 120/60/30 Hz retained. |
| `TestContactShading` | Final 23 checks pass, exit 0; existing bridge/jump/canonical boundaries retained. |
| `TestBridgeContacts` | 16 checks pass; six forward/reverse join runs have zero collisions. |
| `TestSurfaces` | 50 checks pass. |
| `TestRewind` | Final 57 checks pass, exit 0. |
| `TestScript -ScriptPath res://tests/test_editor_practice.gd` | 53 checks pass; diagnostic practice drives six laps at 15,240 ticks with zero collisions. |
| `TestScript -ScriptPath res://tests/test_script_parse.gd` | 257 scripts compile, zero failures. |
| `CheckScript -ScriptPath res://../build/offroad-relief-stage-core.gd` | The isolated staged game source compiles, exit 0; concurrent camera additions are excluded from this checkpoint. |
| `CaptureStyle -StyleDocument 'C:/Codes/Godot/Beat my track/build/track-restoration-backup-2026-10-03/userdata/tracks/track_acf29166cceaaa42.json'` | Before/after exit 0; canonical cells preserved; all road normal/vertex counts match. Read-only retained Ajorata fixture, no player file writes. |
| `Doctor`, `git diff --check` | Engine/templates/whitespace checks pass; DN2103 attached. |

Earlier iterations found two diagnostic mistakes (double-applying body scale in the wheel assertion and passing an untyped empty history array); both were corrected without weakening assertions. An earlier ContactShading run and one parallel headless relief run ended in native exit `-1073741819` after all assertions passed. Subsequent and final runs exit 0; retained logs record the failed shutdown. Some successful headless runs report three existing ObjectDB leaks, and practice reports four. Final terrain runs and graphical captures exit cleanly. A full regression or resolution of the intermittent engine-shutdown issue is not claimed.

No Android export/install, physical-device driving, GPU benchmark or thermal test was performed. DN2103 was attached during Doctor. Remaining checks: owner review of bump density/height and moving-car clearance, phone load/frame pacing, and editor dragging through mound areas. Gameplay-affecting terrain and other-biome elevation are outside this slice.

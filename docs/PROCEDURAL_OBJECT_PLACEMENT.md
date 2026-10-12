# Procedural object placement — 2026-10-11

Owner authorization: implement the discussed mobile-conscious object placement in the editor. Roads remain authored separately. This is a local editor slice; no production deployment was requested.

## Requirements and behavior

- **POP01:** Objects → **Populate** opens an actual 3D preview with Density, Roadside reach, Shuffle, Cancel and Apply. Pan, wheel zoom and the existing native touch/pinch navigation work while editing is suspended.
- **POP02:** The nearest actual road edge controls eligibility. Buildings, original car wrecks, parked vehicles, containers, crates and barrels fit wholly inside the roadside reach (16–32 m, default 22 m). The outer population contains only biome-compatible trees/broadleaf trees and rocks/boulders. Desert uses rocks because the existing nature kit has no desert tree.
- **POP03:** An exact separable Euclidean distance transform on a 2 m road mask prepares the field. Bounded random sequential inhibition, spatial buckets, smooth noise and cluster centres produce irregular spacing and woodland patches. This is minimum-distance rejection sampling, not an implementation of Bridson's active-list sampler or WFC.
- **POP04:** Four metres of footprint clearance plus a conservative 3 m mask/sample allowance protects layout roads, variable-width spline pieces, bridge approaches/decks and asphalt free paint. Existing authored object footprints, water/solid terrain, the start and the authoring boundary are excluded. Buildings/equipment align with the road-field tangent; wrecks vary freely.
- **POP05:** Sampling is seeded and bounded to 1,600 attempts per placement phase. Density requests 24–80 new objects, limited by remaining room under the existing 96 authored-object cap. In crowded maps the result can contain fewer. One worker caches preparation; slider changes debounce for 180 ms, stale results cannot become the applied result, and closing joins/discards the owned worker.
- **POP06:** Preview never changes the document, autosave or undo history. Apply appends fixed editable objects as one undo entry through the existing WIP save path. Cancel restores the original native scene. Generated objects can be moved, rotated, resized and deleted with ordinary tools; undo/redo and JSON reload retain their placements. No generator runs during races.
- **POP07:** Apply saves optional `automatic_scenery: false`. This replaces the implicit background population with the explicit objects and prevents extra automatic trees/fences appearing after the map expands. Manually placed/adopted objects and existing hidden-scenery keys remain. Documents without the flag retain their old implicit scenery behavior. Domain validation and the v5 JSON schema require a boolean.
- **POP08:** Add the allowlisted `car_wreck` object (4.2 × 1.8 m footprint): an original fictional rusted compact with a collapsed roof, open cabin and missing front wheel. It uses opaque shared prop geometry, static canonical obstacle cells and the existing spatial contact-shadow batches. No external asset, AI service or new dependency. Visual kit 122 invalidates cached thumbnails for the extended kit.

Relevant preserved project requirements: G01/R01 canonical driving separation, Q01 honest evidence, V03/V05 compact actionable UI, creator free object editing, unlimited ordinary racing, pinned race contracts and sharing data without user scripts/images. No physics, timing, scoring or acceptance-checker implementation changed.

## Changed files

- `game/editor/object_population.gd` / `.uid`: field preparation, bounded seeded sampling, footprint/terrain checks.
- `game/editor/object_population_panel.gd` / `.uid`: preview worker, settings, revision fencing and navigation forwarding.
- `game/editor/object_browser.gd`, `game/core/app.gd`: entry action, modal keyboard guard, preview/commit/cancel transactions.
- `game/editor/creator_catalog.gd`, `game/editor/creator_objects.gd`: wreck asset family and footprint.
- `game/track/creator_prop_visual.gd`, `game/track/contact_shading.gd`, `game/track/native_track_visual.gd`: original wreck geometry, shared shadow inclusion, kit version.
- `game/editor/track_document.gd`, `game/editor/creator_scenery.gd`, `docs/schemas/creator-track-v5.schema.json`: optional suppression flag and additive wreck enum.
- `game/tests/test_object_population.gd` / `.uid`: independent distance/road geometry, spacing, water, capacity, all five biomes and actual editor persistence/navigation checks.
- This document, `DEVELOPMENT_STATUS.md`, `docs/PHASE_0_PLAN.md`, and the task-only evidence/checkpoint below.

## Actual commands and results

Commands use pinned `4.7.2.stable.official.ed1daf0bf` through `scripts/dev.ps1`. PowerShell needs a process-only execution-policy override on this machine. Restricted Godot import initially failed reading the Windows certificate store; the reviewed elevated import completed, and tests used isolated temporary test profiles.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Import -CommandTimeoutSeconds 120
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_object_population.gd -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_object_population.gd -Graphical -TestArgument capture -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_object_population.gd -Graphical -RenderingMethod mobile -RenderingDriver vulkan -CommandTimeoutSeconds 180
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestObjects -CommandTimeoutSeconds 120
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestHazards -CommandTimeoutSeconds 120
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestCreator -CommandTimeoutSeconds 120
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action Doctor -CommandTimeoutSeconds 60
```

| Check | Actual result |
|---|---|
| Final headless population | 20,581 checks, 0 failures |
| Native Compatibility population/captures | 20,584 checks, 0 failures; RTX 3090/OpenGL |
| Native Mobile Vulkan population | 20,581 checks, 0 failures; RTX 3090, not an Android measurement |
| Existing object browser | 67 checks, 0 failures |
| Existing hazards/scenery | 154 checks, 0 failures |
| Existing creator | 113 checks, **1 failure**: compiler-v22 golden hash is stale against the starting compiler-v23 source |
| Pre-task scenery comparison | Five ordinary biome hashes/cells/decks/routes/scenery exactly equal current; 0 failures |
| Doctor | Matching templates found; **no attached device** |

The read-only baseline probe reconstructed the pre-task scenery script by removing only the new optional suppression guard, and compiled the same ordinary documents with the unchanged compiler. Pine was `369c5f28…` before and after; the old fixture expects `e2119106…`. The failing fixture was not altered. Probe command: `TestScript -ScriptPath res://tests/probe_population_baseline.gd`; the temporary test source is retained in evidence and removed from the runtime project.

Initial meaningful failures were retained in evidence: exact object equality after JSON reload exposed numeric representation differences (placements now normalize through authoring JSON); assigning a new document key with dot notation created a StringName rejected by strict key validation (the flag now uses a String key). The mixed-road test initially supplied a spline whose overall width was narrower than its widest node; the fixture was corrected to meet the existing contract. The water witness now checks actual circle-to-square separation. No product invariant or existing failing assertion was weakened.

Final 60-object sample preparation on this desktop: **7.65–9.15 ms**, with **4.52–6.75 ms** for sampling. These timings exclude native track compilation, scene construction, rendering and file writes. The field is at most 110 × 110 float32 values (48,400 bytes); this is not a whole-feature memory measurement. Phone responsiveness, frame time and thermal performance remain unmeasured.

## Evidence and review checkpoint

Actual native captures were inspected at 1280 × 720 and 960 × 540:

- [Desktop preview](evidence/procedural-placement-2026-10-11/preview-desktop.png)
- [Compact landscape preview](evidence/procedural-placement-2026-10-11/preview-compact.png)
- [Applied editable population](evidence/procedural-placement-2026-10-11/applied-editor.png)

The evidence directory contains final logs, initial failure logs, the baseline probe, source hashes and a task-only Git-format patch. This checkpoint is against the task's starting working tree, which already contains substantial owner work; it does not stage or commit that unrelated work. `git apply --reverse --check` validates the task patch against the final workspace. Existing shared status documents are recorded with hashes separately to avoid packaging concurrent tasks in the patch.

## Remaining acceptance

- Owner review of distribution, density and original wreck appearance; optional painted selection areas/templates are outside this first whole-map tool.
- Physical Android editor touch/pinch, latency, sustained racing frame time, memory and thermal checks. No phone was attached; no device test, APK export or installation was performed.
- Any deployed canonical backend must receive the matching additive `automatic_scenery`/`car_wreck` authoring support before new populated tracks can be verified there. Local source is ready; **no backend image build/upload, deployment, live publication or player-data write was performed**. Deployment needs explicit owner authorization.
- Existing creator-v22 golden-hash failure remains, with exact pre-task parity evidence. No full Validate or unrelated physics regression was claimed.

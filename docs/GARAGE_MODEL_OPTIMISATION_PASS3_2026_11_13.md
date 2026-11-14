# Garage model optimisation, third pass — 2026-11-13

The workshop loses another **15,699 triangles (10.86%)** and **463,544 mesh-buffer bytes (6.71%)**, with its props, finishes, bevels and large silhouettes retained. All 336 paired native comparisons pass the existing appearance limits, including extra close views.

Requirements: **GMP301** reduce the remaining model cost; **GMP302** preserve the best possible appearance; **GMP303** validate and refresh the prepared assets safely.

## Geometry changes

`game/ui/garage_furnishings.gd` sizes radial detail to each small fitting instead of giving nearly every turned part 48 samples:

- Lathes use 16/24/32/48 sides by maximum profile radius. Every authored profile row, analytical normal calculation and UV mapping remains. Large parts of radius 0.24 m or more retain 48 samples.
- Default small tubes use 12 or 16 sides; larger shafts retain 20. Every explicitly requested count remains exact, including hex bolts, record controls and authored polygonal fittings. Both end caps remain.
- Small toroidal fittings use 16 or 24 major samples. Their eight-sample rolled cross-sections remain; larger rings retain 32.
- Changed small-part silhouettes have bounded chord error below 1.2 mm. Cardinal extrema remain because these adaptive counts are divisible by four. Dimensions, positions and material choices are unchanged.

The spare-tyre casings, major rim lips, 96-sided turntable, plant leaves, cabinetry bevels, props and room layout remain. The changes run during mesh construction/preparation, without a new per-frame operation or runtime simplifier.

| Workshop measure | Current-source control | Accepted candidate | Reduction |
|---|---:|---:|---:|
| Master triangles | 144,494 | 128,795 | 10.86% |
| Instance-weighted vertices | 193,704 | 183,688 | 5.17% |
| Instance-weighted ArrayMesh payload, including LOD data | 6,903,918 B | 6,440,374 B | 6.71% |
| LOD index payload | 574,914 B | 486,012 B | 15.46% |
| Compressed scene | 2,145,417 B | 1,918,717 B published | 10.57% |
| Mesh instances | 108 | 108 | unchanged |

The pedestal remains **5,292 triangles / 177,840 mesh bytes**, with its five material batches and separate reflection materials. Buffer counts are measurements of native mesh resources, not total renderer/device RAM. No FPS improvement or Android performance qualification is claimed.

The control was freshly baked from task-start sources, rather than relying on an older cached room. The control and candidate source receipts differ only in `garage_furnishings.gd`. Final publication is also checked against that tested candidate: all compared node transforms, master arrays, layers, shadows and finishes match exactly after ignoring engine-generated name numbers.

## Appearance and behaviour

- **873 native checks / zero failures in each desktop renderer**, Compatibility and Vulkan Mobile.
- **336 before/after image pairs pass** the unchanged Garage bounds: mean RGB difference below 0.25/255 and fewer than 0.5% of pixels differing by more than 8/255. Worst mean is **0.096112/255** and worst >8 fraction is **0.263780%**, both in an unusually close compressor view. **141 pairs are pixel-exact**.
- Views include all six cars front/rear/maximum zoom, normal and forced master detail, both reflection views, record player, trophy wall, workbench, tyres and overhead. Five additional close views cover compressor, shelf stock, hand tools, speaker/record controls and vice.
- **111/112 car-only reflection pairs are exact**. The remaining Vulkan kart-front reflection differs at one pixel, by at most 3/255; its mean difference is 0.00000434/255.
- Inspected master close views retain the tools, rolled edges, socket openings, speaker cones and compressor details. Representative native before/after captures are retained. Owner appearance acceptance remains separate.
- Small-prop dimensions/profile/normal/UV/cache/explicit-count checks: **78/0**. Existing mesh cleanup: **20/0**. Existing washing surface checks: **54/0**.
- Actual App Garage interaction: **287/0 Compatibility**, plus **15/0 focused Vulkan** for the five sections, retained pedestal, repaint, washing and reflections. These use private records and no backend URL.
- Published-vs-procedural/candidate geometry: **3/0**. Production parser at the checked snapshot: **560 scripts / zero failures**. Existing transactional bake regression: **25/0**.

## Safe preparation and concurrent changes

The workshop is published through the guarded baker. A first catalogue refresh completed without errors, then a concurrent `electric_glass.gdshader` edit correctly invalidated its provenance. A subsequent refresh encountered assertions in concurrently edited vehicle-contour code and null contour meshes. Those are outside this geometry pass. They were corrected externally; no vehicle source was restored or edited by this task.

That failed refresh also exposed a gap: a Godot script error can be logged without producing a nonzero script exit, allowing the existing producer to commit its files despite the external test runner rejecting the log. The invalid refresh is retained as a failed attempt, not a pass.

`tests/support/asset_bake_errors.gd` now listens for engine/script errors using the pinned engine's Logger interface. Both the workshop and preview bakers reject any such generation before installation. The helper is included in both source receipts. Existing source/revision/output fences and rollback remain. Two private probes inject a real error into the actual producers: both reject and preserve every accepted PNG/receipt or scene/receipt byte, and remove their temporary locks. Production was not their destination.

A later guarded preview attempt rejected a concurrent source change. The final guarded attempt completed with no engine errors and replaced the unqualified images. Final read-only gates pass **27 current workshop source hashes**, and **six catalogue pictures / 167 current source hashes**. These qualify that snapshot; later external edits can invalidate receipts again.

During documentation closeout, an external geometry-identity update invalidated the catalogue gate again. A final guarded handoff refresh completed cleanly and its immediately following six-picture/167-source check passes. That refresh preserves current external vehicle revisions.

The broad prepared-car preflight remains **551 resources / 2,267 checks / 939 stale-source/key findings**. It is retained as a failure. No vehicle base/module/header resources were authored or rebuilt by this task, and no whole-project release-readiness claim is made.

## Files, commands and evidence

Production model change: `game/ui/garage_furnishings.gd`. The two bake scripts additionally gain the error guard and its source dependency. New tests are `test_garage_prop_detail.gd` and `test_garage_prop_paired_render.gd`, with their UIDs; the guard has its own UID. Generated workshop, catalogue pictures and provenance are refreshed. No build-identity source, physics configuration or vehicle generator was authored by this pass.

[Evidence](evidence/garage-model-pass3-2026-11-13/) contains cost/image measurements, native reports and selected comparisons, logs, private error probes, hashes and a source-only nine-file/UID checkpoint. Forward/reverse application and exact normalised-text round trips pass in an isolated repository. The shared Git index matches the task-start hash; no main-index staging or commit was performed.

All engine runs use pinned `4.7.2.stable.official.ed1daf0bf`, the crash-dialog wrapper, Dummy audio, private APPDATA/LOCALAPPDATA under this task's build directory, an empty backend URL and offscreen native windows. Actual command forms:

```powershell
python build/garage-model-pass3-2026-11-13/run.py prop-tests headless res://tests/test_garage_prop_detail.gd
python build/garage-model-pass3-2026-11-13/run.py control-bake headless res://tests/bake_garage_architecture.gd --output=res://../build/garage-model-pass3-2026-11-13/control
python build/garage-model-pass3-2026-11-13/run.py candidate-bake headless res://tests/bake_garage_architecture.gd --output=res://../build/garage-model-pass3-2026-11-13/candidate
python build/garage-model-pass3-2026-11-13/run.py paired-gl gl_compatibility res://tests/test_garage_prop_paired_render.gd --control-room=res://../build/garage-model-pass3-2026-11-13/control/workshop_v1.scn --candidate-room=res://../build/garage-model-pass3-2026-11-13/candidate/workshop_v1.scn --output=res://../build/garage-model-pass3-2026-11-13/paired/gl_compatibility
# Same paired command also ran with renderer mobile and its separate output folder.
powershell -NoProfile -ExecutionPolicy Bypass -File build/garage-model-pass3-2026-11-13/compare.ps1 -Base build/garage-model-pass3-2026-11-13/paired
python build/garage-model-pass3-2026-11-13/run.py app-gl gl_compatibility res://tests/test_garage_simple_models.gd --output=res://../build/garage-model-pass3-2026-11-13/app-gl
python build/garage-model-pass3-2026-11-13/run.py app-mobile mobile res://../build/garage-model-pass3-2026-11-13/app_smoke.gd
python build/garage-model-pass3-2026-11-13/run.py publish-guarded headless res://tests/bake_garage_architecture.gd
python build/garage-model-pass3-2026-11-13/run.py preview-closeout gl_compatibility res://../scripts/bake_garage_previews.gd
python scripts/check_garage_workshop.py
python scripts/check_garage_previews.py
python scripts/run_no_crash_dialog.py -- python scripts/prepare_car_assets.py --verify --godot 'C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe' --output build/garage-model-pass3-2026-11-13/prepared
```

No device query/test, APK/export, deployment, backend request, owner-save mutation or owner-process change was performed. Reload/owner appearance and device performance acceptance remain. Full paired captures, test profiles and control/candidate scenes are disposable build output; permanent evidence contains concise measurements and selected comparisons only.

Completion cleanup: the task pin is removed and `scripts/clean_build.ps1 -Apply` completed, reclaiming one eligible entry: **24.59 → 24.49 GiB**. Recent/protected/locked output keeps the workspace above its 20 GiB target. Selected durable evidence occupies approximately **5.8 MB**.

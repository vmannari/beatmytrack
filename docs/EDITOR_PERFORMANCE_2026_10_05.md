# Editor performance improvements — 2026-10-05

Owner request: improve track loading, road/object placement, saving and undo/redo before the other usability work in [the editor review](TRACK_EDITOR_REVIEW_2026_10_05.md). Requirements: R01, T01–T04, V03–V05, Q01.

The editor now responds without synchronously compiling and building an entire newly loaded map. It shows the actual road skeleton and a preparation notice, compiles on its existing single worker, and builds replacement scenery in frame slices. Saved-track reading, atomic persistence and canonical validation remain real operations. Large-map response times improved substantially; background scenery still takes seconds to complete, and cold/shared-host frame spikes remain measurable.

## Implementation

- Road topology prepares endpoint poses once, indexes nearby candidates spatially, and retains the original exact distance test and piece/endpoint ordering. Routing, snapping, outlines, join cuts, kerbs and cosmetic joins share that preparation rather than repeatedly rescanning/recomputing the same endpoints. Preparation is local to each operation, without mutable global caches or simulation-time randomness.
- Successful automatic route fields are cached by the complete road-piece array. Ordinary object/name edits reuse them; geometry changes invalidate them. Undo/redo retain the canvas, viewport and history semantics.
- Uncached opening queues the preview worker. Initial scenery uses the same cooperative build path as replacements. Changing pages does not join an obsolete preview; superseded compiler/scenery output cannot replace the current document. Exit checks were added after newly yielding stages. Native-remix Fit completes when its extent becomes available, unless the user has already navigated or zoomed.
- Explicit Save commits the exact current authoring document without waiting for its visual preview. Rename, metadata changes, sharing and Clear map use the background preview path. Saved-road baking is requested for matching completed previews; pending matching saves can request it when their worker completes. The legacy locally selected race-track refresh still compiles synchronously to preserve its immediate exact-selection contract.
- CPU road/overlay images are prepared with the preview on the worker and kept separately from serialized native metadata. Their bytes match the original pixel algorithm. GPU resources and scene-tree changes remain on the main thread.
- Name, creator and identity changes retain scenery. Authored props have a separate batch from generated scenery, so placing one tyre does not rebuild every generated tree. Ground-cover refreshes yield; replacement batches retain old layers until ready. Revision guards prevent an older refresh from overwriting newer immediate props.
- Object cards and unchanged detail/category controls are retained. One-shot thumbnail renders become cached textures; later visits use the texture directly. The cache is limited to 48 images, approximately 5 MiB of uncompressed RGBA pixels at 208×128, plus engine/GPU overhead. Existing compiled/scenery caches remain bounded at three previews and two detached trees.

No handling constants, simulation step, compiler version, schema, saved-file format or canonical content golden was changed by this task. Other ongoing handling, backend, desert and finish-line artwork changes were preserved. The frozen pre-optimization road helper is an export-excluded test oracle, not a runtime compatibility layer.

## Actual desktop measurements

Pinned Godot `4.7.2.stable.official.ed1daf0bf`, Windows, Compatibility renderer, RTX 3090, 1280×720. The final graphical script executes real app/canvas/library operations on a valid connected 96-piece circuit; earlier independent open-draft samples use the same supported 96-piece limit. These are elapsed handler and sampled frame intervals, not physical-phone or input-to-photon measurements.

| Operation | Review baseline | Final graphical run |
| --- | ---: | ---: |
| Connected 96-piece opening handler | 6602.960 ms | **31.050 ms** |
| Actual saved-track read/open/reset | Not separately measured | **44.092 ms** |
| Explicit save while preview pending | 1221.086 ms for foreground preview save | **47.951 ms**, including saved-original commit |
| Undo / redo on connected map | Open-draft undo 202.953 ms; no equivalent connected redo sample | **29.722 / 29.337 ms** |
| Legal road approval on large map | Not separately measured | **42.159 ms** |
| Object placement on large map | First implementation sample 96.769 ms | **24.803 ms** |
| Surface stroke commit | Not separately measured | **33.602 ms** |
| Browser refresh, three samples | 35.822 / 35.651 / 39.648 ms | **0.073 / 0.102 / 0.098 ms** |
| Route attempt + issues on open 96-piece draft | 145.751–169.705 ms | **3.016 ms** |
| Leave while preview pending | Previously joined the worker; no matching sample | **43.522 ms** |

The save comparison is deliberately conservative: the new number includes writing the saved original; the review's foreground call waited for preview compilation and only saved WIP. Undo fixtures differ and are identified above. Repeated small-map placement in the final regression batch returned in approximately 13–19 ms; small road approval returned in approximately 14–23 ms. Headless/parallel regression timing is not presented as graphical benchmark evidence.

The final large-map initial detail took **3.249 s** after the skeleton capture, with a **687.405 ms maximum sampled frame interval**. An earlier graphical run recorded **1017.943 ms**; another recorded 144.943 ms. The host had seven Godot processes at the later process listing, and concurrent graphical capture logs changed during these measurements. Host interference is a plausible contributor, not proven attribution. These spikes are retained in the logs; no claim of locked 60 fps or completely eliminated loading hitches is made.

In the final run, metadata/history updates settled with maximum sampled intervals of **13.802 / 12.263 ms**. A road replacement took **3.165 s**, maximum interval **55.434 ms**; object replacement took **482 ms**, maximum **30.526 ms**; saved-map scenery took **2.743 s**, maximum **85.529 ms**; painted scenery took **2.548 s**, maximum **46.093 ms**. The UI receives time between stages while waiting for complete scenery; total preparation time must not be confused with the handler's response time.

## Verification and actual commands

Engine commands use `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1`, matching the pinned executable/templates. Reviewable source hashes, scoped patch, command inventory and copied logs are under [evidence/editor-performance-2026-10-05](evidence/editor-performance-2026-10-05/).

- `-Action Import -CommandTimeoutSeconds 90`: passed; registered the new CPU-only mask helper and test scripts.
- `-Action CheckScript -ScriptPath res://core/app.gd -CommandTimeoutSeconds 60`: passed at the implementation checkpoint.
- `-Action TestScript -ScriptPath res://tests/test_script_parse.gd -CommandTimeoutSeconds 90`: final sampled project **301 scripts, zero failures**. The mixed workspace continued adding unrelated scripts later; this is the count at that command.
- `-Action TestScript -ScriptPath res://tests/profile_editor_performance.gd -Graphical -CommandTimeoutSeconds 120`: final **1216 checks, zero failures**. Compares frozen original endpoint membership/order, route widths/points, canonical outlines and exact compiled output, including near-tolerance/ambiguous/reversed joins. Tests durable Save while preview is pending, metadata scenery retention, rapid history supersession, road capacity/placement, retained cards and bounded thumbnail cache, real saved loading, painting, matching image bytes and leaving during pending work. The headless version is now part of Validate.
- Editor component runs: Workflow **245**, Placement **26**, Road approval **40**, Start line **27**, Creator **113**, Editor v2 **36**, Free editor **47**, Road pieces **362**, Practice **54**, Construction **104**, Bridge contacts **16**, Bridge HUD **144**, Refinement **32**, Tyres/load **71**, Objects **67**; completed runs had zero failures. Workflow's original two practice-launch failures were corrected by awaiting actual preparation with a deadline, preserving the spawn/content/driving assertions.
- Exact regression components completed: Driving **72**, Handling **88**, launch-start **13,328**, checkpoint **266**, bridge checkpoints **259**, entry **258**, exit **2527**, notices **281**, Tracks **167**, extra tracks **27**, and raster **eight independent goldens**. Additional tyre/grid/pile equivalence verified **13,200 / 20,500 / 2400** exact comparisons. Kerbs **31**, Ice **69**, Desert **87**, Storm **91**, Soil **163**, Suspension **59**, shoulder/join/contour checks all passed. Golden fixtures were not regenerated or weakened.
- Remaining components were run through `-Action TestScript -ScriptPath res://tests/<name>.gd -CommandTimeoutSeconds 120`: reliability **17**, records **54**, personal ghosts **38**, cameras **1332**, catalog **21**, menu loading **38**, night lighting **15**, deletion **20**, menu presentation **48**, kart **32**, car balance **one**; zero failures. `-Action TestCars -CommandTimeoutSeconds 300` completed **105 checks, zero failures**, including all five cars' five-lap fixtures. Its earlier parallel two-minute run timed out and is not counted as passed.
- `.tools/backend-venv/Scripts/python.exe -m pytest backend/tests/test_verifier.py -q -x`: **57 passed**, one existing Starlette deprecation warning. This exercises the actual canonical backend verifier; no backend service/configuration or deployment was changed by this task.
- Scoped `git diff --check` and the generated patch's reverse-application check passed.

**Full Validate is not reported as green.** Attempts first stopped on coroutine caller updates and old synchronous preview/launch fixtures; those were corrected without removing their substantive assertions. An actual exit-time null-tree error was reproduced and fixed with cancellation fences. A later Validate stopped at the old tyre-test launch expectation; its complete updated suite now passes 71 checks. Remaining components were completed in separate batches. The current broad App suite still reports **97 checks with five PB/results assertions failing** (previous target, slower-finish gap, retained PB and PB display after reload). The editor performance changes do not modify those Results/record operations; their precise current mixed-workspace cause remains unverified, and no failing invariant was suppressed.

Two tyre-test attempts also encountered a concurrently edited backend client preloading `resume_recovery.gd` before that file existed. The module later appeared; parser and complete tyre tests passed. Concurrent Results upload ownership and visual-kit/finish-line changes are excluded from this task's scoped patch. Several established driving/practice/ghost tests still emit ObjectDB cleanup warnings at exit; those are retained.

## Changed files and evidence

Runtime: `game/core/app.gd`; editor `editor_canvas.gd`, `editor_world.gd`, `object_browser.gd`, `object_thumbnail.gd`, `road_pieces.gd`, `track_compiler.gd`, new `creator_preview_masks.gd`; track `native_track.gd`, `native_track_visual.gd`, `road_edges.gd`, `road_kerbs.gd`, `visual_road_join.gd`.

Verification: new `game/tests/profile_editor_performance.gd` and frozen `tests/fixtures/road_pieces_before_performance.gd`; updated placement/road-approval, workflow, editor-v2, free-editor, hazard, tyre/load and shoulder fixtures for real asynchronous completion; `scripts/dev.ps1` adds the new headless contract/lifecycle check to Validate. Associated new Godot UIDs are retained. Documentation: this file and task entries in `DEVELOPMENT_STATUS.md`/`docs/PHASE_0_PLAN.md`, plus evidence. The patch isolates these edits from the pre-existing/concurrent working tree; no mixed workspace commit was made.

Inspected real engine captures: [preparing a large track](evidence/editor-performance-2026-10-05/closed-96-preparing.png), [completed large track](evidence/editor-performance-2026-10-05/closed-96-ready.png), [cached object artwork](evidence/editor-performance-2026-10-05/objects-cached.png), [painted compact view](evidence/editor-performance-2026-10-05/paint-ready-compact.png). The preparation notice is the only new visible editor presentation. The known Surface/header and Publish-glyph problems remain in this performance-first slice.

## Remaining acceptance

No Android export, install or physical-phone editor performance test was performed. The DN2103 was listed during the preceding review, not reverified for this change. There is no phone frame/memory/thermal or human finger-feel acceptance claim. All probe writes use unique disposable libraries/records, with their own cleanup; owner tracks were not deleted or migrated.

Measure a quiet desktop and the target phone next, including first shader/texture use, long editing sessions, 96 authored objects, complex bridges and maximum paint density. Scene commits, GPU uploads, native bridge presentation, foreground atomic saves and legacy selected-track refresh still contain bounded synchronous work. Thumbnail readback happens once per uncached image; its cost and the bounded caches' total device memory require device measurement. Resolve the five broad PB/results failures before claiming a fully green integration/export gate. Other usability findings from the review remain separate work.

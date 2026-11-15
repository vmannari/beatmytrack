# Possible gain from more Garage simplification — 2026-11-15

**Further cuts reliably reduce submitted geometry, but these tests do not establish a reliable loading-time saving attributable to triangle count.** A disposable experiment cuts the default environment from **31,075 to 17,985 triangles (42.12%)**. The actual primitive count falls **23.76% in the main view**, or **20.43% across the main view and two reflections**, with unchanged draw-call counts. The aggressive model loses readable signage and cabinet detail, so it is not a production candidate.

For the owner's loading objective, I would investigate synchronous UI/script startup and first-use rendering stalls before spending more visible detail on another geometry reduction. Lower primitive counts alone do not establish an FPS or phone benefit.

## Controlled geometry comparison

| Metric | Current | Experimental reduction |
| --- | ---: | ---: |
| Workshop master triangles | 29,245 | 16,155 |
| Default environment, including unchanged platform/floor/contact quads | 31,075 | 17,985 |
| Compressed room scene, initial matrix | 445,072 bytes | 269,333 bytes |
| Main-view primitives | 48,611 | 37,060 |
| Floor-reflection primitives | 44,693 | 33,686 |
| Pedestal-reflection primitives | 17,106 | 17,106 |
| Total across the three views | 110,410 | 87,852 |
| Compatibility main-view draw calls | 257 | 257 |
| Desktop Mobile main-view draw calls | 190 | 190 |

The car remains stock Rally at **19,074 master triangles**. Every successful timing restores its prepared base, matches its geometry key and complete runtime source projection, preserves the selected car/customisation, and returns to the same studio. All three monitored Garage presentation scripts are uncached immediately before navigation. Render statistics are queried after the measured ready event and two explicit native redraws.

The experiment promotes existing room LOD index buffers toward half the original triangle count and compacts complete encoded vertex records. Lower LODs retain their original error distances and remapped indices. Node transforms, lights, materials, car, platform, camera configuration, viewport resolution and MSAA settings are held fixed. This is a performance probe, not an appearance-qualified simplification recipe.

The tested copy uses current menu/Garage code with the previously qualified car program, model assets and cache namespace. This avoids the live checkout's ongoing car edits and stale provenance contaminating comparisons with procedural car fallbacks. Consequently, its absolute timings are **not a new measurement of current live-checkout or device loading time**.

## Why the initial loading percentages cannot be promised

The first matrix contains three alternating samples per condition/renderer after warm-ups:

| First matrix, median navigation-to-interactive | Current | Reduced | No room geometry diagnostic |
| --- | ---: | ---: | ---: |
| Compatibility | 4.702s | 3.772s | 3.683s |
| Desktop Mobile | 6.270s | 3.576s | 12.605s |

Taken alone, those medians would imply approximately 20%/43% faster entry. That is **not** the conclusion: timing variance is large, the empty-room diagnostic behaves non-monotonically, and subsequent full-geometry controls reach the reduced model's latency. The empty-room case retains lights and named nodes but removes mesh geometry; it is not a valid upper bound for loading savings.

A second matrix adds a full-geometry rebuild control. Its master vertex/index arrays are asserted equal to the original for every ArrayMesh surface. Both it and the controlled reduced variant preserve original mesh properties, metadata and resource sharing. Its scene has the same master counts, rendered primitives and draw calls as the original.

| Follow-up samples, seconds | Original full geometry | Rebuilt full geometry | Reduced geometry |
| --- | --- | --- | --- |
| Compatibility, round 1 | 4.361 | 3.708 | 3.567 |
| Compatibility, reversed round 2 | 3.926 | 3.447 | 3.962 |
| Desktop Mobile, round 1 | 5.438 | 7.052 | 3.900 |
| Desktop Mobile, reversed round 2 | 3.759 | 3.843 | 3.856 |

In the last Mobile round, full geometry loads as quickly as the reduced version. The full-geometry controls span **3.759–7.052s**, while the two reduced samples are **3.856–3.900s**. This demonstrates why the earlier difference cannot be assigned wholly to triangle count or projected as a predictable gain from another 25% cut. It does not prove that geometry has no effect on first-use stalls; it leaves that effect unqualified.

The synchronous navigation/UI phase also varies even for full-geometry controls. Large first-use frame stalls remain, including multi-second Mobile stalls. Driver caches are not reset, and background desktop activity is not isolated. These are process-fresh, cold-presentation-script experiments with shared per-project renderer caches, not controlled cold-driver trials or phone measurements. The earlier approximately 1.6s/2.4s actual-App checks used a different, warmer script fixture and should not be compared directly with these totals.

## Evidence and scope

There are **30 timed matrix samples plus eight matrix warm-ups**, with one additional initial native sanity/warm-up run. All successful runs complete without native/script errors, use the prepared car and retain the same car triangle count. Two setup problems are retained separately: a Windows `res://..` directory-creation error corrected by using an absolute output path, and swapped `Viewport.get_render_info` enum arguments corrected before measurements. No production assertion or loading behavior is changed.

The original and follow-up matrices each retain a **1,109-file code/cache fence with no changes**. The experimental room file is the intentional variable between launches. [Initial samples](evidence/garage-gain-review-2026-11-15/samples.json), [follow-up samples](evidence/garage-gain-review-2026-11-15/control-samples.json), [geometry counts](evidence/garage-gain-review-2026-11-15/control-variants.json), [initial fence](evidence/garage-gain-review-2026-11-15/fence.json) and [control fence](evidence/garage-gain-review-2026-11-15/control-fence.json) retain the data. Source transcripts and exact per-run commands are in the same evidence folder.

[Current view](evidence/garage-gain-review-2026-11-15/mobile/current.png) · [full-geometry rebuild](evidence/garage-gain-review-2026-11-15/mobile/repack.png) · [experimental reduced view](evidence/garage-gain-review-2026-11-15/mobile/half_controlled.png). The reduced version visibly loses letters and cabinet fronts; these images do not pass an appearance-preservation claim.

Actual experiment commands:

```powershell
python build/garage-gain-review-2026-11-15/setup.py
python build/garage-gain-review-2026-11-15/run.py variants-initial --project build/garage-gain-review-2026-11-15/snapshot/game --headless --script res://../../variants_initial.gd
python build/garage-gain-review-2026-11-15/measure.py
python build/garage-gain-review-2026-11-15/run.py control-variants --project build/garage-gain-review-2026-11-15/snapshot/game --headless --script res://../../variants.gd
python build/garage-gain-review-2026-11-15/controls.py
```

The initial builder generated `current`, `half` and `empty`; the later builder generated `current`, `repack` and `half_controlled`. The retained initial-loop reproduction uses the same reduction functions. All engine launches use pinned Godot 4.7.2 through the existing crash-dialog wrapper, disposable offline storage and offscreen native rendering. These controls alter only disposable copies. No production geometry, car source, loading code, prepared asset or owner save/process is authored. No staging/commit, device test/query, export, backend request or deployment is performed. Required build retention cleanup is applied: no eligible entries are removed and 32.66 GiB remains under recent/protected/locked exclusions. Complete projects, profiles and shader caches remain disposable under `build/`, with no task pin.

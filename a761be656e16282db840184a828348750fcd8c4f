# Selective track asset optimization — 7 November 2026

The accepted ice-car sculpture, snow castle and shipping container now use reduced geometry at ordinary racing distances and their original geometry at close range. This implements the three candidates from [the investigation](TRACK_ASSET_SIMPLIFICATION_REVIEW_2026_11_07.md). Trees, Egyptian masonry, igloos, crates, grandstands and warehouse braces retain their original models.

| Model | Full-detail triangles | Racing-detail triangles | Reduction |
|---|---:|---:|---:|
| Ice-car sculpture | 7,908 | 3,954 | 50.00% |
| Snow castle | 7,950 | 3,974 | 50.01% |
| Container | 7,782 | 3,050 | 60.81% |

These are individual model geometry counts, not full-track FPS or loading measurements. Original positions, normals, pigments, full-detail indices, materials, collision/document data and canonical rules remain unchanged. No new Graphics option is introduced.

## Implementation and requirements

**TSO01 — offline preparation.** [bake_scenery_mesh_lods.gd](../game/tests/bake_scenery_mesh_lods.gd) converts the already-reviewed first reduced levels into source-corner maps. Three compressed resources under `game/assets/scenery_lods_v1/` total **44,901 bytes**. Each map is fenced by its version, kind, source geometry/normal/hidden-face signature, expected corner count, triangle alignment and index bounds. Missing or mismatched maps retain full geometry. Container paint RGB is deliberately outside the geometry signature so saved colours retain the same topology. No runtime simplifier or new dependency is used.

**TSO02 — merged and spatial geometry.** [scenery_mesh_lods.gd](../game/track/scenery_mesh_lods.gd) maps the reduced corners through the original final normal generation, indexing and enclosed-face pruning. It adds one reduced index buffer to an otherwise byte-exact ArrayMesh surface. Native racing builders opt in; editor/thumbnail builders retain their original full-detail path. Each batch uses the largest contributing scale when choosing its detail transition, conservatively retaining detail when larger and smaller objects share a batch.

The `0.028 × object scale` metric is a calibrated presentation switching policy, not a claim that the simplifier's maximum geometry error is 28 mm. At the tested one-pixel viewport policy it selects the accepted level at the standard 56-degree Overhead, 48-degree Follow car and 30% speed-zoom views, and returns to full geometry in the enlarged views. Higher resolutions can select fuller detail earlier.

The numeric spatial worker carries both index streams into the same existing chunks. Approved ordinary props use whole-object ranges, as Winter craft already does, so simplified faces cannot migrate into a different draw or leave fragments behind. Every original and reduced position/normal/colour triangle is retained exactly once across the tested chunks. Chunk normals keep their original encoded GPU bytes; there is no added draw per object. Cancellation and conservative direct-draw fallback remain.

**TSO03 — budgets and cache fences.** [cache_bytes.gd](../game/editor/cache_bytes.gd) and the prepared-world estimator count the new retained maps and index payloads. The existing 32 MiB prop-cache, 64 MiB world-cache and spatial node limits remain. Upload buffers and retained CPU representations receive conservative byte allowances; this is not a RAM reduction claim. The prop and visual-kit versions invalidate older prepared worlds. Prepared-world restoration retains both detail levels. The existing retained editor batching path keeps full detail.

**TSO04 — integration.** The focused suite covers all five biomes, half/default/double scales, rotation, custom container colour, cold and worker-warmed sources, rejected source signatures, protected asset kinds, mixed approved/unapproved families, spatial splitting and prepared-world restoration. Three actual Game loads install both optimized material families and retain the same canonical state and ordinary lap contract. Native checks also zoom into and back out of both detail levels without missing or intermediate geometry.

Runtime files are `creator_prop_visual.gd`, `prop_geometry.gd`, `scenery_mesh_lods.gd`, `native_track_visual.gd`, `spatial_mesh_chunks.gd`, `spatial_mesh_preparation.gd`, `prepared_world_cache.gd` and `editor/cache_bytes.gd`. The prepared-world and spatial worker files already contained concurrent loading work at task start; the task-only patch is relative to the archived starting files and preserves that work.

A later concurrent cleanup removes obsolete pending saved-road bake handling from `native_track_visual.gd`. It is preserved and excluded from the task-only patch by an archived baseline containing that cleanup with only this task's scenery additions removed. Both scenery-building functions match renderer qualification exactly after newline normalization, and all other audited input hashes remain unchanged. Focused Game/scenery/cache integration is rechecked against the combined source. [Rebase evidence](evidence/track-asset-optimization-2026-11-07/concurrent-rebase.json) and [the excluded diff](evidence/track-asset-optimization-2026-11-07/concurrent-road-bake-cleanup.diff) retain the distinction.

## Actual native evidence

Both desktop renderers report the same visible primitive reductions at 1280×720 with 4× MSAA and directional shadows:

| Asset | Original stage | Optimized racing stage | Enlarged original / optimized |
|---|---:|---:|---:|
| Ice-car sculpture | 7,922 | 3,968 | 7,922 / 7,922 |
| Snow castle | 7,964 | 3,988 | 7,964 / 7,964 |
| Container | 7,796 | 3,064 | 7,796 / 7,796 |

Each stage adds 14 primitives for its floor/contact presentation. Draw counts remain 5 → 5 on Compatibility and 3 → 3 on desktop Mobile. These are component observations on the local RTX 3090, not mobile hardware measurements.

Night image checks lift ambient/directional light for inspection; the actual Game smoke also covers its normal Night configuration.

- [Compatibility racing comparisons](evidence/track-asset-optimization-2026-11-07/gl_compatibility/comparison-overhead.png) and [close comparisons](evidence/track-asset-optimization-2026-11-07/gl_compatibility/comparison-close.png).
- [Mobile racing comparisons](evidence/track-asset-optimization-2026-11-07/mobile/comparison-overhead.png) and [close comparisons](evidence/track-asset-optimization-2026-11-07/mobile/comparison-close.png).
- [Compatibility measurements](evidence/track-asset-optimization-2026-11-07/gl_compatibility/report.json), [Mobile measurements](evidence/track-asset-optimization-2026-11-07/mobile/report.json) and [structural/integration results](evidence/track-asset-optimization-2026-11-07/headless/report.json).

The captures include 72 static cases and 144 original/optimized images, plus 96 camera-motion frames per renderer. Every static case also restores its original source and requires the original frame to match exactly. Close visible geometry is original, but shadow-detail selection can produce small image differences: full-frame mean channel differences range from 0.0000073 to 0.108586 in Compatibility and 0.000304 to 0.095635 in Mobile, on the 0–255 channel scale. No claim of pixel-identical optimized pictures or identical shadows is made. The inspected racing silhouettes and materials retain the appearance of the approved prototypes; owner acceptance remains.

## Commands, validation and checkpoint

The [receipt](evidence/track-asset-optimization-2026-11-07/receipt.json) records actual results, source hashes, assets, logs and task-only checkpoint contents. Final focused results are **370/0 headless** and **261/0 per desktop renderer**. The accompanying runner also executes affected spatial, editor, prop, race-cache, budget, driving and prepared-asset regressions; their actual outcomes are retained in the receipt and logs.

| Additional actual check | Result |
|---|---|
| Original spatial-worker/object-range regression | 71 checks, 0 failures |
| Original spatial chunk attribute/triangle regression | 34 checks, 0 failures |
| Prop refinement/catalogue regression | 909 checks, 0 failures |
| Race loading/cache lifecycle | 20 checks, 0 failures |
| Selective scenery budget | 12 checks, 0 failures |
| Driving and 2,400-tick exact replay | 72 checks, 0 failures |
| Editor full-detail paired renders, Compatibility | Four biomes, zero changed channels in each |
| Broader editor save/input workflow | Native engine crash after tyre placement; reproduces with all eight task-start runtime files restored |
| Complete prepared-car library | Initial 1,925 checks / 936 failures, then 144 failures; latest 1,925 checks / 2 stale Hover Garage failures |

The completed focused and scoped regression suites total **2,010 passing checks**. That total excludes the incomplete editor UI suite and failed prepared-car preflights.

The prepared-library probe subsequently finds current keys and identical source dictionaries for all five stock bases. An external update changes 451 watched generated car files; the next preflight narrows its failures to the Hover Garage rest's key and source receipt. The actual prepared-identity router confirms that all eleven production paths in this patch are outside its car identity inputs. No car asset or its source was rewritten by this task. These broader preflight failures remain visible; a package/export acceptance claim is not made.

```powershell
# Bake only when source geometry or reviewed corner maps change.
python scripts/run_no_crash_dialog.py -- powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/bake_scenery_mesh_lods.gd

powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-asset-optimization-2026-11-07/run_validation.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File docs/evidence/track-asset-optimization-2026-11-07/make_comparisons.ps1
```

The validation runner uses pinned `4.7.2.stable.official.ed1daf0bf`, private workspace APPDATA/LOCALAPPDATA, a loopback-unavailable backend URL and the crash-dialog wrapper for every noninteractive engine launch. Resource export presets already include all resources and do not exclude `assets/scenery_lods_v1/`; no package export was performed.

Initial fixture findings are retained: the first structural check counted only visible adaptive aggregate nodes rather than their hidden spatial child meshes; it was corrected to inspect the actual chunks and exact triangle sets. The first native fixture left its unattached SubViewport in its default visibility-dependent update mode and observed no draws; that failed run is archived, the fixture now explicitly updates, and a nonzero-visible-geometry assertion remains. No invariant was weakened. The task-start source archive preserves concurrent changes, and the main Git index is untouched. Standard developer entry points refresh generated build identity as usual.

The older editor fixture also omitted `await` for the existing deferred `_show_screen("create")` entry and initially dereferenced a missing editor world. A task-owned copy awaits that entry and explicitly uses the original full-detail model for its legacy full-detail rendering comparisons; every assertion remains. It then hits stock-engine access violation `0xC0000005` in `run_build_editor_tools`, at the object-browser visibility update after placing a tyre, in both headless and Compatibility runs. An isolated source copy restores every archived task-start runtime file, keeps the awaited entry, and reproduces the same native crash at the same operation. The original regressions and production editor/App code remain untouched. The control's first launch preceded completion of its file copy and is explicitly rejected; both that setup log and the completed control crash are retained. A shell execution-policy diagnostic during the identity-router check is also retained; its successful explicit-Bypass helper is the qualifying run.

No device query/test, APK/export/install, owner-save/process change, live/backend request or deployment was performed. Client reload/rebuild, owner appearance acceptance and actual device FPS/memory/thermal qualification remain. The change reduces the measured geometry; no proportional performance or loading improvement is asserted.

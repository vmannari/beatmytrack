# Native Winter preparation and surface rasterisation - 2026-10-18

Implemented the owner's remaining items 3 and 4 in the local CPU pipeline used by race loading and track editing. No server cache, remote build job or new runtime service is involved.

## Requirements and result

| ID | Requirement and implementation |
| --- | --- |
| NWR03 | Port Winter bank profiles, sample normals and section emission to C++; retain the original FastNoiseLite fields, finite-difference footprint, bridge fades, UVs, colour and kit212 upward winding. Port marker nearest-route selection, bridge exclusion, sorting and metre spacing in the same library. |
| NWR04 | Port variable-width road/shoulder grid coverage, ordered area/brush painting and RGB8/L8 editor mask packing to C++. Keep original scalar/vector rounding, protected-road semantics and overwrite order. |
| NWR-G01 | Preserve complete compiled metadata, cell/deck grids, route/contact data, content hashes, appearance and saved documents. Compiler27 and visual kit212 remain exact; no content migration or cache invalidation is needed. |
| NWR-R01 | Retain independently selectable GDScript fallbacks, cancellation, private per-job output and existing cache/upload budgets. Unsupported platforms or absent feature methods use the original paths. |
| NWR-Q01 | Provide independent equivalence, golden, loading/editor/driving checks, rendered evidence, cross-platform builds, actual command receipts and a task-only Git checkpoint. |

The native methods are stateless CPU jobs. They do not access the scene tree, GPU, network or disk. GDScript still owns authoring validation, bounded stroke smoothing, the original snow deposits, orchestration and GPU installation. Noise, Geometry2D and SurfaceTool use the pinned engine's native APIs rather than replacement approximations. Scalar floats stay double where GDScript uses doubles; vector arithmetic keeps engine float boundaries. Fast-math and contraction remain disabled.

Road and paint jobs write private copy-on-write packed buffers and publish them in bulk only after success. Cancelled jobs discard their output; the caller's arrays remain intact. Winter rows retain the same piece-local cache entries and cancellation remains in the surrounding bounded road preparation. Marker and raster loops check cancellation during work. No retained cache or download is added. The original 32MiB road allowance, 64MiB world allowance and existing upload budgets remain.

## Measured desktop CPU work

Three warmed runs per path alternate execution order, using Winter Star with area and line paint. Both paths already use items 1/2's native road kernels. Medians below measure the additional benefit of items 3/4; raw samples and exact fixture checks are in [benchmark-report.json](evidence/native-winter-raster-2026-10-18/benchmark-report.json).

| Work | GDScript | C++ | Change |
| --- | ---: | ---: | ---: |
| Winter road preparation | 4410.583ms | 1992.015ms | 2.21x; 54.8% less CPU time |
| Winter marker selection | 1145.102ms | 120.288ms | 9.52x |
| Overlay and road mask creation | 46.570ms | 2.886ms | 16.14x |
| Complete compiler fixture | 657.333ms | 488.202ms | 25.7% less CPU time |

These are local CPU fixture observations, not full race-start, frame-rate or phone measurements. Warming both paths and alternating order limits first-use bias; three repetitions are still a small desktop sample. Rendered test timings include first-use engine work and are retained as diagnostics rather than performance claims.

## Validation actually run

| Check | Actual result |
| --- | --- |
| New scalar/native kernels | 482 checks, zero failures: 60 varied raster cases, 60 exact bank rows/section streams, cancellation and invalid input, disabled-extension fallback, complete Star/bridge compilations in all five biomes, masks, marker order and full Winter packets |
| Alternating benchmark | 25 checks, zero failures; six timed samples plus warm-up |
| Existing pre-optimisation compiler goldens | 8 checks, zero failures; no golden changed |
| Existing native roads / Desert relief | 115 / 30 checks, zero failures |
| Actual editor placements | 205 checks, zero failures on both initial and final libraries; includes supersession, undo/redo, solid-on-road edits, retained scenes, bounded caches and exact durable WIP |
| App / editor workflow | 141 / 252 checks, zero failures |
| Road cache / prepared world / race reuse | 70 / 85 / 17 checks, zero failures |
| Original driving / rewind | 72 / 61 checks, zero failures |
| Project script parser | 894 scripts, zero failures |
| Compatibility native/scalar views | 6 checks, zero failures; both Winter Star and bridge pixels match exactly |
| Desktop Mobile native/scalar views | 6 checks, one strict pixel failure: Winter Star has 1011 differing channel bytes, maximum delta1. All geometry/material/canonical checks and the bridge pixels pass. |
| Desktop Mobile original-repeat control | 6 checks, two strict pixel failures: capturing the same unchanged original scene twice produces 988 changed Winter channel bytes and9 Storm bytes, maximum delta1. |
| Windows / Android ARM64 and x86-64 | All compiled. Both Android ELF files export the entry point, retain16KiB LOAD alignment and need only the original log/dl/m/c libraries. |

The Mobile variation reproduces without switching the visible original scene. No pixel assertion or other invariant was removed or relaxed, and a complete Mobile pixel pass is not claimed. The original and native scenes have exact CPU geometry/material signatures. Actual captures are retained for [Compatibility Star](evidence/native-winter-raster-2026-10-18/views-gl_compatibility-Windows/winter-star-device.png), [Compatibility bridge](evidence/native-winter-raster-2026-10-18/views-gl_compatibility-Windows/winter-bridge-device.png), [Mobile Star](evidence/native-winter-raster-2026-10-18/views-mobile-Windows/winter-star-device.png) and the unchanged-scene control folder.

App/workflow/cache/world/race-reuse/driving/rewind and graphical checks ran before the final direct packed-buffer write optimisation. The final library repeated482 kernels,8 goldens,115 original native roads,30 relief checks,205 placements,894 parses and the25 benchmark checks. The Winter geometry implementation is identical in the two libraries. The final no-paint fast return was checked by a final eight-golden rerun; parser and benchmark also ran after that no-op optimisation.

## Initial corrections retained

The first parse attempt exposed that this pinned PackedInt32Array API has no assign method. Bulk resize/append_array now retains the caller's shared array reference after native copy-on-write output. The second test run passed the426 focused checks but its ten integration fixtures were rejected for using the unsupported curve paint mode; those fixtures now use the supported line mode. Logs retain both attempts. The final raster implementation uses writable packed-buffer pointers during each native batch rather than a per-cell packed-array API call. Empty paint remains an immediate no-op.

## Commands and evidence

Every engine invocation used the pinned scripts/dev.ps1 entry point, an isolated task APPDATA directory, NoProfile and ExecutionPolicy Bypass. Task output was redirected to unique logs under build/native-winter-raster/logs, preserving each exit code. Native engine runs used the existing escalation required by this machine's certificate-store startup. No SDK was downloaded. Actual command families were:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action BuildTrackGeometry -NativePlatform windows
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action BuildTrackGeometry -NativePlatform android
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action BuildTrackGeometry -NativePlatform all
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestCompilerRaster -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_native_winter_raster.gd -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_native_winter_raster.gd -TestArgument '--benchmark' -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_native_road_views.gd -Graphical -RenderingMethod gl_compatibility -TestArgument '--winter-port' -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_native_road_views.gd -Graphical -RenderingMethod mobile -TestArgument '--winter-port' -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_native_road_views.gd -Graphical -RenderingMethod mobile -TestArgument '--winter-port-repeat' -CommandTimeoutSeconds 300
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestApp -CommandTimeoutSeconds 600
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1 -Action TestWorkflow -CommandTimeoutSeconds 300
```

The same TestScript command also ran test_road_cache.gd, test_prepared_race_load.gd, test_race_preparation_reuse.gd, test_driving.gd, test_rewind.gd, test_compiler_raster.gd, test_native_road_geometry.gd, test_device_track_geometry.gd and test_script_parse.gd. The placement command used res://tests/test_editor_placement_latency.gd,600s and one evidence-root argument pointing to build/native-winter-raster/editor or editor-final, preserving the older task's evidence. Python invoked the installed NDK llvm-readelf.exe with --program-headers --dynamic --dyn-syms for both Android libraries. Actual output, failures, controls and final hashes are in the [evidence report](evidence/native-winter-raster-2026-10-18/report.json), sibling logs and [ELF report](evidence/native-winter-raster-2026-10-18/elf-report-final.json). PowerShell redirect logs are UTF-16LE. ELF text presentation copies strip readelf column-end padding for the review whitespace check; raw output remains under build/native-winter-raster/logs.

## Changed files and delivery

The implementation changes native/track_geometry/track_geometry.cpp, adds winter_geometry.hpp and raster_geometry.hpp, and updates PROVENANCE.md. Dispatch lives in game/track/geometry_acceleration.gd, native_track_visual.gd, winter_scenery.gd, editor/track_compiler.gd and creator_preview_masks.gd. Tests add test_native_winter_raster.gd and extend the existing native-road view diagnostic with Winter port/control modes. The GDExtension descriptor selects the new content-addressed Windows DLL, and both Android libraries are replaced. This report, evidence, AGENTS.md, DEVELOPMENT_STATUS.md and docs/PHASE_0_PLAN.md record the result.

The final Windows DLL is803840 bytes,56,832 more than the preceding library's contents. Android ARM64 is1,025,352 bytes (+78,376) and x86-64 is1,014,920 (+80,608). These are uncompressed library sizes, not an APK-size measurement. Existing Windows filenames remain for already running processes; Android exports already exclude DLLs. No server, storage-service, request or recurring job cost is introduced.

The task-only patch and bundle live under build/native-winter-raster/checkpoint. Its baseline retains all concurrent editor preparation, kit212, object-kit, canonical and product work as context; only this task's changes form the new commit. Root .git is untouched. The [checkpoint receipt](../build/native-winter-raster/checkpoint-receipt.json) records commits, patch/bundle hashes and reverse-application validation.

Owner acceptance of editor fluency and physical-device performance remains. No phone attachment check, device execution, APK export/install, live backend mutation or deployment was performed. Android runtime equivalence, complete cold race-start timing, peak RAM, thermals and physical-phone feel remain unmeasured. No FPS claim is made.

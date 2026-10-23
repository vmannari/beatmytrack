# Native road loading and editing - 2026-10-18

NRG01 moves the remaining presentation-only road/shoulder overlap clipping, exposed-edge sampling, road/fringe UV generation and subdivision into the existing on-device C++ extension. NRG02 moves winding, normal selection, colour/normal encoding and packed mesh-stream assembly into native CPU code. G01/R01/Q01 retain canonical driving, exact presentation and reproducible checks. This implements the owner's selected C++ items 1 and 2; it introduces no server processing.

## Result and scope

The native implementation retains the scalar/vector precision boundaries, ordered overlap ownership, join probes, hole contours, UV phases, original triangulation and Desert indexing. The original GDScript algorithms remain available when the extension is absent or disabled. Plain arrays cross the worker boundary; the normal scene/material/upload path remains responsible for installation. The original Grass stones/blades emitter remains in GDScript after a trial port showed small vertex differences and little additional gain. Canonical compiler, physics/rules, track documents and backend contracts are unchanged.

The shared race/editor road job consumes these kernels. The same existing local memory/disk budgets remain; no new persistent native cache is added. The visual kit advances to 211 to fence prepared artifacts. Cancellation discards obsolete results. Main-thread cooperative scene-building retains its sliced fallback. The C++ geometry loops use typed engine bindings; merely moving dynamic per-vertex calls into C++ gave substantially less benefit in the first prototype.

Windows and Android ARM64/x86-64 binaries are built using the existing pinned godot-cpp checkout, MinGW and NDK r28b. Both Android libraries export the extension entry and have 0x4000 LOAD alignment, with only the existing Android system dependencies. Windows builds content-address the DLL so an existing editor can retain its loaded image during a rebuild. No SDK download or new dependency is required. Provenance and the existing MIT notice remain in native/track_geometry/PROVENANCE.md.

## Measurements

The focused desktop headless fixture prepares raw road packets, with native road kernels disabled/enabled in turn. It bypasses section/disk caches so a cache hit cannot conceal kernel differences. Both alternatives use the same compiled track and current Desert relief implementation; these intervals exclude final relief, world installation, App/network setup, shader preparation and countdown.

| Star fixture | Scalar road CPU | Native road CPU |
| --- | ---: | ---: |
| Pine | 4.836 s | 4.003 s |
| Desert | 13.838 s | 5.165 s |
| Winter | 13.431 s | 4.914 s |
| Storm | 4.698 s | 3.826 s |
| Night | 4.737 s | 3.577 s |
| Desert bridge fixture | 2.519 s | 1.992 s |

These are observations from the retained functional run, not a controlled phone benchmark. Other checks ran concurrently and the scalar alternative executes first. Earlier typed-kernel comparisons independently gave Desert 14.079 to 5.211 s and Winter 11.293 to 4.476 s, with exactly matching streams. Pine's improvement is smaller; remaining geometry/prop/biome work and first-use driver costs can still dominate.

Rendered comparisons additionally build the same complete worlds with each raw packet, compare geometry/material parameters/render flags, and compare pixels through the same viewport/camera/sky/shadow state. The test holds node/shader animation still and completes each test world's static reflection sky. After independent exact material/mesh signature checks, it shares only the certified-equal material resources between worlds; this prevents newly allocated material RIDs from changing coplanar seam draw order. Independent GPU meshes remain in use. The two scenes are shown in turn through one viewport; separate World3D reflection caches can differ by one output quantisation level even with identical inputs. The initial unshared views differed at one seam pixel despite identical geometry/material data; strict pixel equality remains required. This holds the same wind/weather pose; shipping shaders, skies and animation remain unchanged. Final renderer receipts are recorded in the evidence report.

## Validation

Completed kernel comparison: 115 checks, zero failures, across all five Star biomes and the Desert bridge fixture, including independent overlap/tie cases, joined/non-swept/hole-contour edge samples, malformed inputs, pre-work/mid-job cancellation and unchanged canonical data. The retained scalar implementation supplies the comparison.

Original shoulder area/ownership checks and joins71/internal contours18, native Desert relief30, road cache70, prepared worlds85, selected preparation59, race preparation reuse17, App140, driving72 and rewind61 pass. The strengthened editor regression passes 205 checks and the complete parser passes 891 scripts. Compatibility completes 18 checks with zero failures. Mobile completes 18 with two strict pixel failures: all six geometry/material and canonical comparisons pass, as do four exact pixel pairs. Winter differs in 1011 channel bytes by one colour level; Storm differs in 216 bytes by one. A separate repeated-capture control shows the same unchanged original scalar scene producing the identical Winter variation and Storm variation up to two colour levels (6 checks, two strict pixel failures). These failures are retained and Mobile pixel equality is not claimed as passing. The evidence records all outcomes; no planned check is represented as passed.

The editor fixture now waits for the actual preview document, material readiness and ordered WIP writer, asserts that each requested placement really adds an object, and uses legal equivalents in the current curated biome palettes. It retains independent collision/identity, save contents, ground reuse, solid-on-road replacement, undo/redo, cancellation and cache-bound assertions. Earlier failures reproduced with scalar roads: removed Desert props were rejected by the current catalog, so the fixture had not performed the edit it claimed to check. No product guard or assertion was removed.

Actual commands use scripts/dev.ps1 and disposable workspace APPDATA. Final and initial attempts are retained under docs/evidence/native-road-loading-2026-10-18/commands. Principal commands:

```powershell
scripts/dev.ps1 -Action BuildTrackGeometry -NativePlatform all
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_native_road_geometry.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_native_road_views.gd -Graphical -RenderingMethod gl_compatibility
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_native_road_views.gd -Graphical -RenderingMethod mobile
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_shoulders.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_device_track_geometry.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_road_cache.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_prepared_race_load.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_race_preparation_reuse.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_device_race_preparation.gd
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_editor_placement_latency.gd
scripts/dev.ps1 -Action TestApp
scripts/dev.ps1 -Action TestDriving
scripts/dev.ps1 -Action TestRewind
scripts/dev.ps1 -Action TestScript -ScriptPath res://tests/test_script_parse.gd
```

Initial retained attempts include unavailable Dictionary::make in the trimmed bindings, a shadowed helper name, a loaded-DLL replacement failure, incorrect extra attributes on empty-path ground polygons, the rejected Grass-detail trial, transient shared-file/preload/coroutine integration issues, an obsolete cache-test filename, and test-only static-array typing, split-packet and moving-shader/reflection fixtures. Correcting the fixture setup preserved the original assertions. The final tests compare like-for-like streams and fixed animation poses; the remaining Mobile frame variation is baseline-confirmed. Available earlier command files are retained; the first compiler output and unsupported shader-time API trial remain in tool history rather than complete log files.

## Review checkpoint and remaining acceptance

Runtime files: native/track_geometry/track_geometry.cpp plus road_geometry.hpp and road_engine_api.hpp; game/track/geometry_acceleration.gd, shoulder_mesh.gd, desert_road_union.gd, road_fringe_mesh.gd and native_track_visual.gd; editor/road_preparation.gd and the awaited shared road_piece_work.gd integration; native build helper, descriptor and three platform binaries. Two focused native tests/UIDs, the strengthened placement fixture, provenance and this evidence complete the task slice.

The task-only patch/bundle records native changes against the current scalar/shared-editor structure. Concurrent section reuse, prop/material preparation, UI/catalog, canonical checkpoint and backend changes are retained as context rather than committed as this task. This is a selected-file review checkpoint, not a complete runnable export. The root Git directory is not mutated; no broad reset or commit is performed.

Physical Android execution, actual new-track/editor interaction timing, peak RAM, thermal behaviour and owner appearance/fluency acceptance remain. There was no phone attachment check/test, APK/export/install, live backend action or deployment. Desktop Mobile is a renderer check, not a phone or FPS claim.

Evidence: [report.json](evidence/native-road-loading-2026-10-18/report.json), [task-only patch](evidence/native-road-loading-2026-10-18/task-only.patch), [Git bundle](evidence/native-road-loading-2026-10-18/native-roads.bundle), [checkpoint receipt](evidence/native-road-loading-2026-10-18/checkpoint.json).
